import Foundation
import NaturalLanguage
import Accelerate

// MARK: - NeuralEngineOrchestrator: Koordinerar Qwen3-1.7B GGUF på Metal GPU

actor NeuralEngineOrchestrator {
    static let shared = NeuralEngineOrchestrator()

    private(set) var qwenHandler: QwenHandler?
    private(set) var isLoaded: Bool = false
    private(set) var loadError: String?

    // Inference cache: LRU med hash-nyckel
    private var embeddingCache: [Int: [Float]] = [:]
    private var cacheOrder: [Int] = []
    private let maxCacheSize = 500

    private var modelVersion: Int = 1

    // Inaktivitetstimers för lazy unload
    private var lastUse: Date = .distantPast
    private var idleCheckTask: Task<Void, Never>?

    private init() {}

    // MARK: - Compatibility aliases (for code that references bert/gpt)
    var bertLoaded: Bool { qwenHandler != nil }
    var gptLoaded: Bool { qwenHandler != nil }
    var bertHandler: QwenHandler? { qwenHandler }
    var gptHandler: QwenHandler? { qwenHandler }

    // MARK: - Loading

    func loadModels() async {
        guard !isLoaded else { return }
        print("[QWEN] Loading Qwen3-1.7B...")

        do {
            let handler = QwenHandler()
            try await handler.load()
            qwenHandler = handler
            lastUse = Date()
            isLoaded = true
            print("[QWEN] Qwen3-1.7B ready ✓")
        } catch {
            loadError = error.localizedDescription
            print("[QWEN] Load error: \(error)")
        }

        startIdleCheck()
    }

    // MARK: - Idle unload loop

    private func startIdleCheck() {
        idleCheckTask?.cancel()
        idleCheckTask = Task(priority: .background) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 180_000_000_000) // 3 min
                await self.unloadIfIdle()
            }
        }
    }

    func unloadIfIdle() async {
        let now = Date()
        if qwenHandler != nil && now.timeIntervalSince(lastUse) > 600 {
            await qwenHandler?.unload()
            qwenHandler = nil
            isLoaded = false
            print("[QWEN] Unloaded — idle >10 min")
            RunSessionLogger.shared.log("Qwen3 unloaded (idle >10 min)")
        }
    }

    private func ensureLoaded() async {
        guard qwenHandler == nil else { return }
        print("[QWEN] Reloading Qwen3...")
        RunSessionLogger.shared.log("Qwen3 reloading (lazy)")
        let handler = QwenHandler()
        try? await handler.load()
        qwenHandler = handler
        isLoaded = true
        lastUse = Date()
    }

    // MARK: - Embedding

    func embed(_ text: String) async -> [Float] {
        // Thermal gate: skip GPU inference at critical thermal state
        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .critical {
            return fallbackEmbed(text)
        }

        let cacheKey = (text + "\(modelVersion)").hashValue
        if let cached = embeddingCache[cacheKey] { return cached }

        await ensureLoaded()
        lastUse = Date()

        guard let handler = qwenHandler else {
            return fallbackEmbed(text)
        }

        let embedding = await handler.embed(text)
        cacheEmbedding(key: cacheKey, value: embedding)
        return embedding
    }

    // vDSP-accelererad cosine similarity
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = a.count
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(n))
        var normA: Float = 0
        var normB: Float = 0
        vDSP_svesq(a, 1, &normA, vDSP_Length(n))
        vDSP_svesq(b, 1, &normB, vDSP_Length(n))
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    func embedBatch(_ texts: [String]) async -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            results.append(await embed(text))
        }
        return results
    }

    func invalidateCache() {
        embeddingCache.removeAll()
        cacheOrder.removeAll()
        modelVersion += 1
    }

    // MARK: - Generation

    func generate(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7, enableThinking: Bool = false) async -> String {
        // Thermal circuit breaker: skip Qwen entirely when thermal is critical
        if ThermalSleepManager.shared.shouldSkipQwenInference() {
            return await fallbackGenerate(prompt)
        }

        await ensureLoaded()
        lastUse = Date()
        guard let handler = qwenHandler else {
            return await fallbackGenerate(prompt)
        }
        let raw = await handler.generate(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature, enableThinking: enableThinking)
        let deduped = Self.deduplicateSentences(raw)
        let cleaned = Self.cleanOutput(deduped)
        return Self.finalSafetyDedup(cleaned)
    }

    func generateStream(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7, enableThinking: Bool = false) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                // Thermal circuit breaker at orchestrator level
                if ThermalSleepManager.shared.shouldSkipQwenInference() {
                    let fallback = await self.fallbackGenerate(prompt)
                    for word in fallback.split(separator: " ") {
                        continuation.yield(String(word) + " ")
                    }
                    continuation.finish()
                    return
                }

                await self.ensureLoaded()
                self.lastUse = Date()
                guard let handler = await self.qwenHandler else {
                    let fallback = await self.fallbackGenerate(prompt)
                    for word in fallback.split(separator: " ") {
                        continuation.yield(String(word) + " ")
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    continuation.finish()
                    return
                }

                var accumulated = ""
                var ngramCounts: [String: Int] = [:]
                var recentSentences: [String] = []
                var stopped = false

                await handler.generateStream(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature, enableThinking: enableThinking) { token in
                    guard !stopped else { return }
                    accumulated += token

                    // 4-gram repetition detection
                    let words = accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    if words.count >= 4 {
                        let lastNgram = words.suffix(4).joined(separator: " ")
                        ngramCounts[lastNgram, default: 0] += 1
                        if ngramCounts[lastNgram, default: 0] >= 3 {
                            stopped = true
                            return
                        }
                    }

                    // Sentence-level repetition
                    if token.contains(".") || token.contains("!") || token.contains("?") {
                        let sentences = accumulated
                            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                            .filter { $0.count > 15 }
                        if let lastSentence = sentences.last {
                            let priorMatches = recentSentences.filter { Self.sentenceSimilarity($0, lastSentence) > 0.80 }.count
                            if priorMatches >= 1 {
                                stopped = true
                                return
                            }
                            recentSentences.append(lastSentence)
                        }
                    }

                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - PLL

    func bertPLL(sentence: String) async -> Double {
        if ThermalSleepManager.shared.shouldSkipQwenInference() { return 0.5 }
        await ensureLoaded()
        lastUse = Date()
        guard let handler = qwenHandler else { return 0.5 }
        return await handler.pseudoLogLikelihood(sentence)
    }

    // MARK: - NER

    func extractEntities(from text: String) async -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entityType: ExtractedEntity.EntityType
                switch tag {
                case .personalName: entityType = .person
                case .organizationName: entityType = .organization
                case .placeName: entityType = .location
                default: return true
                }
                entities.append(ExtractedEntity(
                    text: String(text[range]),
                    type: entityType,
                    confidence: 0.75
                ))
            }
            return true
        }
        let conceptKeywords = ["algoritm", "system", "teori", "modell", "process", "metod", "teknik", "vetenskap"]
        let words = text.lowercased().split(separator: " ")
        for word in words {
            if conceptKeywords.contains(String(word)) {
                entities.append(ExtractedEntity(text: String(word), type: .concept, confidence: 0.6))
            }
        }
        return entities
    }

    // MARK: - Cache management

    private func cacheEmbedding(key: Int, value: [Float]) {
        if cacheOrder.count >= maxCacheSize {
            let evict = cacheOrder.removeFirst()
            embeddingCache.removeValue(forKey: evict)
        }
        embeddingCache[key] = value
        cacheOrder.append(key)
    }

    // MARK: - Fallbacks

    private var cachedSwedishEmbedding: NLEmbedding?

    private func fallbackEmbed(_ text: String) -> [Float] {
        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .serious || thermal == .critical {
            cachedSwedishEmbedding = nil
            return [Float](repeating: 0, count: 768)
        }
        if cachedSwedishEmbedding == nil {
            cachedSwedishEmbedding = NLEmbedding.wordEmbedding(for: .swedish)
        }
        let embedding = cachedSwedishEmbedding
        let words = text.split(separator: " ").prefix(10)
        var result = [Float](repeating: 0, count: 768)
        var count = 0
        for word in words {
            if let vec = embedding?.vector(for: String(word)) {
                for (i, v) in vec.prefix(768).enumerated() {
                    result[i] += Float(v)
                }
                count += 1
            }
        }
        if count > 0 { result = result.map { $0 / Float(count) } }
        return result
    }

    private func fallbackGenerate(_ prompt: String) async -> String {
        return await NLResponseEngine.generateAsync(for: prompt)
    }

    // MARK: - Anti-repetition utilities

    nonisolated static func deduplicateSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let paragraphDeduped = removeParagraphRepetition(text)
        guard let pattern = try? NSRegularExpression(pattern: "([^.!?]+[.!?]+)", options: []) else { return paragraphDeduped }
        let range = NSRange(paragraphDeduped.startIndex..., in: paragraphDeduped)
        let matches = pattern.matches(in: paragraphDeduped, range: range)
        var seen: [String] = []
        var result: [String] = []
        for match in matches {
            guard let matchRange = Range(match.range, in: paragraphDeduped) else { continue }
            let sentence = String(paragraphDeduped[matchRange])
            let normalized = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalized.count > 10 else {
                result.append(sentence)
                continue
            }
            let isDuplicate = seen.contains { sentenceSimilarity($0, normalized) > 0.75 }
            if !isDuplicate {
                seen.append(normalized)
                result.append(sentence)
            }
        }
        if result.isEmpty { return paragraphDeduped }
        return result.joined()
    }

    nonisolated static func removeParagraphRepetition(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 60 else { return text }
        let len = trimmed.count
        for divisor in 2...5 {
            let blockSize = len / divisor
            guard blockSize > 30 else { continue }
            let blockStartIndex = trimmed.startIndex
            let blockEndIndex = trimmed.index(blockStartIndex, offsetBy: blockSize)
            let firstBlock = String(trimmed[blockStartIndex..<blockEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard firstBlock.count > 30 else { continue }
            let rest = String(trimmed[blockEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let checkLen = min(firstBlock.lowercased().count, rest.lowercased().count)
            guard checkLen > 20 else { continue }
            let firstPart = String(firstBlock.lowercased().prefix(checkLen))
            let restPart = String(rest.lowercased().prefix(checkLen))
            if sentenceSimilarity(firstPart, restPart) > 0.7 {
                return firstBlock
            }
        }
        return text
    }

    nonisolated static func finalSafetyDedup(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 100 else { return text }
        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 15 }
        var seenNormalized: [String] = []
        var uniqueSentences: [String] = []
        var removedCount = 0
        for sentence in sentences {
            let normalized = sentence.lowercased()
            let isExactDup = seenNormalized.contains(normalized)
            let isNearDup = !isExactDup && seenNormalized.contains { sentenceSimilarity($0, normalized) > 0.80 }
            if !isExactDup && !isNearDup {
                seenNormalized.append(normalized)
                uniqueSentences.append(sentence)
            } else {
                removedCount += 1
            }
        }
        if removedCount > 0 {
            return uniqueSentences.joined(separator: ". ") + "."
        }
        let words = trimmed.split(separator: " ").map(String.init)
        if words.count > 12 {
            var trigrams: [String: Int] = [:]
            for i in 0..<(words.count - 2) {
                let trigram = words[i..<(i+3)].joined(separator: " ").lowercased()
                trigrams[trigram, default: 0] += 1
            }
            if let maxRepeat = trigrams.values.max(), maxRepeat >= 4 {
                guard let offender = trigrams.first(where: { $0.value >= 4 })?.key else { return text }
                let offenderWords = offender.split(separator: " ").map(String.init)
                var occurrences = 0
                var cutIndex = words.count
                for i in 0..<(words.count - 2) {
                    let current = words[i..<(i+3)].map { $0.lowercased() }
                    if current == offenderWords {
                        occurrences += 1
                        if occurrences == 2 { cutIndex = i; break }
                    }
                }
                if cutIndex < words.count {
                    let truncated = words[0..<cutIndex].joined(separator: " ")
                    if let lastPeriod = truncated.lastIndex(where: { ".!?".contains($0) }) {
                        return String(truncated[...lastPeriod])
                    }
                    return truncated + "."
                }
            }
        }
        return text
    }

    nonisolated static func sentenceSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        let wordsB = Set(b.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return 0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union)
    }

    nonisolated static func cleanOutput(_ text: String) -> String {
        var result = text
        let leakagePatterns = [
            "ABSOLUTA REGLER", "KÄRNPRINCIPER", "SVARSSTRUKTUR", "SKRIVKVALITET",
            "VIKTIGT:", "[Frågeanalys:", "[Medvetandetillstånd:", "[Kognitiv kontext:",
            "[Relevanta fakta:", "[Kunskapsartiklar:", "[Konversation:", "[Minnen:",
            "[OBS:", "Eon (svar om", "Eon (djupanalys om", "Användare:",
            "UPPREPA ALDRIG", "bryt ALDRIG", "Kognitiv profil:", "II=",
            "KORRIGERING:", "REVISION:", "Reviderat svar",
            "<|im_start|>", "<|im_end|>", "<think>", "</think>"
        ]
        for pattern in leakagePatterns {
            if let range = result.range(of: pattern) {
                let lineEnd = result[range.upperBound...].firstIndex(of: "\n") ?? result.endIndex
                result.removeSubrange(range.lowerBound..<lineEnd)
            }
        }

        let echoPatterns = [
            "det du frågar om",
            "det du frågar",
            "det du undrar om",
            "det du undrar över",
            "kan analyseras från flera perspektiv",
            "kan ses från flera perspektiv",
            "kan betraktas från flera perspektiv"
        ]
        let lines = result.components(separatedBy: "\n")
        var cleanedLines: [String] = []
        for line in lines {
            let lower = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isEcho = echoPatterns.contains { lower.contains($0) }
            if !isEcho || lower.count > 200 {
                cleanedLines.append(line)
            }
        }
        result = cleanedLines.joined(separator: "\n")

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.isEmpty {
            if let lastChar = result.last, lastChar != "." && lastChar != "!" && lastChar != "?" {
                if let lastPeriod = result.lastIndex(where: { ".!?".contains($0) }) {
                    let afterPeriod = result.index(after: lastPeriod)
                    let trailing = String(result[afterPeriod...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if trailing.count > 5 {
                        result = String(result[...lastPeriod])
                    }
                }
            }
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Extracted entity

struct ExtractedEntity: Identifiable {
    let id = UUID()
    let text: String
    let type: EntityType
    let confidence: Double
    var startIndex: Int = 0
    var endIndex: Int = 0

    enum EntityType: String {
        case person = "PER"
        case organization = "ORG"
        case location = "LOC"
        case concept = "CONCEPT"
        case time = "TIME"
        case other = "MISC"
    }
}

import SwiftUI
extension ExtractedEntity.EntityType {
    var swiftUIColor: Color {
        switch self {
        case .person: return EonColor.orange
        case .organization: return EonColor.pillarBERT
        case .location: return EonColor.teal
        case .concept: return EonColor.violetLight
        case .time: return EonColor.cyan
        case .other: return EonColor.textSecondary
        }
    }

    var color: Color { swiftUIColor }
}
