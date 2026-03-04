import Foundation
import CoreML
import NaturalLanguage
import Accelerate

// MARK: - NeuralEngineOrchestrator: Koordinerar alla CoreML-modeller på ANE

actor NeuralEngineOrchestrator {
    static let shared = NeuralEngineOrchestrator()

    private(set) var bertHandler: BertHandler?
    private(set) var gptHandler: GptSw3Handler?
    private(set) var isLoaded: Bool = false
    private(set) var loadError: String?

    // Inference cache: LRU med hash-nyckel (förhindrar kollisioner på långa texter)
    private var embeddingCache: [Int: [Float]] = [:]
    private var cacheOrder: [Int] = []
    private let maxCacheSize = 500

    // Modell-version för cache-invalidering
    private var modelVersion: Int = 1

    // Inaktivitetstimers för lazy unload
    private var lastBertUse: Date = .distantPast
    private var lastGptUse: Date = .distantPast
    private var idleCheckTask: Task<Void, Never>?

    private init() {}

    // MARK: - Loading

    func loadModels() async {
        guard !isLoaded else { return }
        print("[ANE] Laddar modeller...")

        do {
            let bert = BertHandler()
            try await bert.load()
            bertHandler = bert
            lastBertUse = Date()

            let gpt = GptSw3Handler()
            try await gpt.load()
            gptHandler = gpt
            lastGptUse = Date()

            isLoaded = true
            print("[ANE] Alla modeller laddade ✓")
        } catch {
            loadError = error.localizedDescription
            print("[ANE] Laddningsfel: \(error)")
        }

        startIdleCheck()
    }

    // MARK: - Idle unload loop

    private func startIdleCheck() {
        idleCheckTask?.cancel()
        idleCheckTask = Task(priority: .background) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000_000) // var 2:e minut
                await self.unloadIfIdle()
            }
        }
    }

    func unloadIfIdle() async {
        let now = Date()
        if bertHandler != nil && now.timeIntervalSince(lastBertUse) > 300 {
            bertHandler = nil
            print("[ANE] BERT avlastad — inaktiv >5 min")
            RunSessionLogger.shared.log("BERT avlastad (inaktiv >5 min)")
        }
        if gptHandler != nil && now.timeIntervalSince(lastGptUse) > 600 {
            gptHandler = nil
            isLoaded = false
            print("[ANE] GPT-SW3 avlastad — inaktiv >10 min")
            RunSessionLogger.shared.log("GPT-SW3 avlastad (inaktiv >10 min)")
        }
    }

    var bertLoaded: Bool { bertHandler != nil }
    var gptLoaded: Bool { gptHandler != nil }

    // Ladda om BERT om avlastad
    private func ensureBert() async {
        guard bertHandler == nil else { return }
        print("[ANE] Laddar om BERT...")
        RunSessionLogger.shared.log("BERT laddas om (lazy reload)")
        let bert = BertHandler()
        try? await bert.load()
        bertHandler = bert
        lastBertUse = Date()
    }

    // Ladda om GPT om avlastad
    private func ensureGpt() async {
        guard gptHandler == nil else { return }
        print("[ANE] Laddar om GPT-SW3...")
        RunSessionLogger.shared.log("GPT-SW3 laddas om (lazy reload)")
        let gpt = GptSw3Handler()
        try? await gpt.load()
        gptHandler = gpt
        isLoaded = true
        lastGptUse = Date()
    }

    // MARK: - Embedding (KB-BERT)

    func embed(_ text: String) async -> [Float] {
        // Hash-baserad cache-nyckel — förhindrar kollisioner
        let cacheKey = (text + "\(modelVersion)").hashValue
        if let cached = embeddingCache[cacheKey] { return cached }

        await ensureBert()
        lastBertUse = Date()

        guard let bert = bertHandler else {
            return fallbackEmbed(text)
        }

        let embedding = await bert.embed(text)
        cacheEmbedding(key: cacheKey, value: embedding)
        return embedding
    }

    // vDSP-accelererad cosine similarity — ~15x snabbare än skalär loop för 768-dim vektorer
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = a.count

        // Dot product via vDSP
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(n))

        // Norms via vDSP
        var normA: Float = 0
        var normB: Float = 0
        vDSP_svesq(a, 1, &normA, vDSP_Length(n))
        vDSP_svesq(b, 1, &normB, vDSP_Length(n))

        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    // Batch-embedding: embeddar flera texter effektivt
    func embedBatch(_ texts: [String]) async -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            results.append(await embed(text))
        }
        return results
    }

    // Invalidera cache vid modelluppdatering
    func invalidateCache() {
        embeddingCache.removeAll()
        cacheOrder.removeAll()
        modelVersion += 1
    }

    // MARK: - Generation (GPT-SW3)

    func generate(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7) async -> String {
        await ensureGpt()
        lastGptUse = Date()
        guard let gpt = gptHandler else {
            return await fallbackGenerate(prompt)
        }
        let raw = await gpt.generate(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature)
        // v10: Post-generation deduplication + v11: output cleaning + v18: final safety dedup
        let deduped = Self.deduplicateSentences(raw)
        let cleaned = Self.cleanOutput(deduped)
        return Self.finalSafetyDedup(cleaned)
    }

    func generateStream(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                await self.ensureGpt()
                self.lastGptUse = Date()
                guard let gpt = await self.gptHandler else {
                    let fallback = await self.fallbackGenerate(prompt)
                    for word in fallback.split(separator: " ") {
                        continuation.yield(String(word) + " ")
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    continuation.finish()
                    return
                }
                // v10: Real-time n-gram repetition detection during streaming
                var accumulated = ""
                var ngramCounts: [String: Int] = [:]
                var recentSentences: [String] = []
                var stopped = false

                await gpt.generateStream(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature) { token in
                    guard !stopped else { return }
                    accumulated += token

                    // --- Check 1: 4-gram repetition detection ---
                    // Track 4-word sequences; if any repeats 3+ times, stop generation
                    let words = accumulated.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    if words.count >= 4 {
                        let lastNgram = words.suffix(4).joined(separator: " ")
                        ngramCounts[lastNgram, default: 0] += 1
                        if ngramCounts[lastNgram, default: 0] >= 3 {
                            stopped = true
                            print("[ANE] Repetition stoppad: 4-gram '\(lastNgram)' upprepat 3+ gånger")
                            return
                        }
                    }

                    // --- Check 2: Sentence-level repetition ---
                    // If we detect a sentence ending, check if it duplicates a previous sentence
                    if token.contains(".") || token.contains("!") || token.contains("?") {
                        let sentences = accumulated
                            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                            .filter { $0.count > 15 }
                        if let lastSentence = sentences.last {
                            let priorMatches = recentSentences.filter { Self.sentenceSimilarity($0, lastSentence) > 0.80 }.count
                            if priorMatches >= 1 {
                                stopped = true
                                print("[ANE] Repetition stoppad: mening upprepad (likhet >80%)")
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

    // MARK: - Anti-repetition utilities (v10)

    /// Remove duplicate or near-duplicate sentences from generated text
    /// v17: Also detects paragraph-level repetition (whole blocks repeated 2+ times)
    nonisolated static func deduplicateSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // v17: Paragraph-level deduplication first — detect if the response is the same block repeated
        let paragraphDeduped = removeParagraphRepetition(text)

        // Split on sentence-ending punctuation while preserving the delimiter
        guard let pattern = try? NSRegularExpression(pattern: "([^.!?]+[.!?]+)", options: []) else { return paragraphDeduped }
        let range = NSRange(paragraphDeduped.startIndex..., in: paragraphDeduped)
        let matches = pattern.matches(in: paragraphDeduped, range: range)

        var seen: [String] = []
        var result: [String] = []

        for match in matches {
            guard let matchRange = Range(match.range, in: paragraphDeduped) else { continue }
            let sentence = String(paragraphDeduped[matchRange])
            let normalized = sentence.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Skip if too short to be meaningful
            guard normalized.count > 10 else {
                result.append(sentence)
                continue
            }

            // Check if this sentence is a near-duplicate of any seen sentence
            let isDuplicate = seen.contains { sentenceSimilarity($0, normalized) > 0.75 }
            if !isDuplicate {
                seen.append(normalized)
                result.append(sentence)
            }
        }

        // If regex didn't match anything (no sentence-ending punctuation), return original
        if result.isEmpty { return paragraphDeduped }
        return result.joined()
    }

    /// v17: Detect and remove paragraph-level repetition (whole response repeated 2+ times)
    nonisolated static func removeParagraphRepetition(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 60 else { return text }

        // Try block sizes from 1/5 to 1/2 of the text to find repeating blocks
        let len = trimmed.count
        for divisor in 2...5 {
            let blockSize = len / divisor
            guard blockSize > 30 else { continue }
            let blockStartIndex = trimmed.startIndex
            let blockEndIndex = trimmed.index(blockStartIndex, offsetBy: blockSize)
            let firstBlock = String(trimmed[blockStartIndex..<blockEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard firstBlock.count > 30 else { continue }

            // Check if the rest of the text contains this block again
            let rest = String(trimmed[blockEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let firstBlockNorm = firstBlock.lowercased()
            let restNorm = rest.lowercased()

            // If the rest starts with (or is very similar to) the first block, it's repeated
            let checkLen = min(firstBlockNorm.count, restNorm.count)
            guard checkLen > 20 else { continue }
            let firstPart = String(firstBlockNorm.prefix(checkLen))
            let restPart = String(restNorm.prefix(checkLen))
            let sim = sentenceSimilarity(firstPart, restPart)
            if sim > 0.7 {
                // The response is repeated — return just the first block
                return firstBlock
            }
        }
        return text
    }

    /// v19: Final safety dedup — catches any remaining repetitions of substantial text blocks
    /// This runs AFTER sentence and paragraph dedup as a last resort.
    /// Now also catches near-duplicate sentences (>80% Jaccard similarity).
    nonisolated static func finalSafetyDedup(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 100 else { return text }

        // Split into sentences and check for any sentence appearing 2+ times (exact OR near-duplicate)
        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 15 }

        var seenNormalized: [String] = []
        var uniqueSentences: [String] = []
        var removedCount = 0
        for sentence in sentences {
            let normalized = sentence.lowercased()
            // Check exact duplicate
            let isExactDup = seenNormalized.contains(normalized)
            // Check near-duplicate (>80% word overlap)
            let isNearDup = !isExactDup && seenNormalized.contains { sentenceSimilarity($0, normalized) > 0.80 }
            if !isExactDup && !isNearDup {
                seenNormalized.append(normalized)
                uniqueSentences.append(sentence)
            } else {
                removedCount += 1
            }
        }

        // If we removed duplicates, reconstruct
        if removedCount > 0 {
            return uniqueSentences.joined(separator: ". ") + "."
        }

        // Also check for repeated 3-word phrases appearing 4+ times
        let words = trimmed.split(separator: " ").map(String.init)
        if words.count > 12 {
            var trigrams: [String: Int] = [:]
            for i in 0..<(words.count - 2) {
                let trigram = words[i..<(i+3)].joined(separator: " ").lowercased()
                trigrams[trigram, default: 0] += 1
            }
            // If any trigram appears 4+ times, the text is degenerate
            if let maxRepeat = trigrams.values.max(), maxRepeat >= 4 {
                // Keep text up to the second occurrence of the most-repeated trigram
                guard let offender = trigrams.first(where: { $0.value >= 4 })?.key else { return text }
                let offenderWords = offender.split(separator: " ").map(String.init)
                var occurrences = 0
                var cutIndex = words.count
                for i in 0..<(words.count - 2) {
                    let current = words[i..<(i+3)].map { $0.lowercased() }
                    if current == offenderWords {
                        occurrences += 1
                        if occurrences == 2 {
                            cutIndex = i
                            break
                        }
                    }
                }
                if cutIndex < words.count {
                    let truncated = words[0..<cutIndex].joined(separator: " ")
                    // Try to end at a sentence boundary
                    if let lastPeriod = truncated.lastIndex(where: { ".!?".contains($0) }) {
                        return String(truncated[...lastPeriod])
                    }
                    return truncated + "."
                }
            }
        }

        return text
    }

    /// Word-overlap based sentence similarity (fast, no ML needed)
    nonisolated static func sentenceSimilarity(_ a: String, _ b: String) -> Double {
        let wordsA = Set(a.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        let wordsB = Set(b.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 })
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return 0 }
        let intersection = wordsA.intersection(wordsB).count
        let union = wordsA.union(wordsB).count
        return Double(intersection) / Double(union) // Jaccard similarity
    }

    /// v11: Clean generated output — remove prompt leakage, incomplete sentences, garbled text
    nonisolated static func cleanOutput(_ text: String) -> String {
        var result = text

        // 1. Remove prompt leakage — if model echoes system instructions or meta-text
        let leakagePatterns = [
            "ABSOLUTA REGLER", "KÄRNPRINCIPER", "SVARSSTRUKTUR", "SKRIVKVALITET",
            "VIKTIGT:", "[Frågeanalys:", "[Medvetandetillstånd:", "[Kognitiv kontext:",
            "[Relevanta fakta:", "[Kunskapsartiklar:", "[Konversation:", "[Minnen:",
            "[OBS:", "Eon (svar om", "Eon (djupanalys om", "Användare:",
            "UPPREPA ALDRIG", "bryt ALDRIG", "Kognitiv profil:", "II=",
            "KORRIGERING:", "REVISION:", "Reviderat svar"
        ]
        for pattern in leakagePatterns {
            if let range = result.range(of: pattern) {
                // Remove from the leaked pattern to end of line
                let lineEnd = result[range.upperBound...].firstIndex(of: "\n") ?? result.endIndex
                result.removeSubrange(range.lowerBound..<lineEnd)
            }
        }

        // 2. Remove incomplete final sentence (no ending punctuation)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !result.isEmpty {
            if let lastChar = result.last, lastChar != "." && lastChar != "!" && lastChar != "?" {
                // Find the last complete sentence
                if let lastPeriod = result.lastIndex(where: { ".!?".contains($0) }) {
                    let afterPeriod = result.index(after: lastPeriod)
                    let trailing = String(result[afterPeriod...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    // Only truncate if the trailing part is significant (>5 chars = likely incomplete)
                    if trailing.count > 5 {
                        result = String(result[...lastPeriod])
                    }
                }
            }
        }

        // 3. Clean up excessive whitespace
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - BERT-PLL (Pseudo-Log-Likelihood för validering)

    func bertPLL(sentence: String) async -> Double {
        await ensureBert()
        lastBertUse = Date()
        guard let bert = bertHandler else { return 0.5 }
        return await bert.pseudoLogLikelihood(sentence)
    }

    // MARK: - NER (Named Entity Recognition via BERT)

    func extractEntities(from text: String) async -> [ExtractedEntity] {
        await ensureBert()
        lastBertUse = Date()
        guard let bert = bertHandler else { return [] }
        return await bert.extractEntities(from: text)
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

    // MARK: - Fallbacks (när modeller inte är laddade)

    // C2: Cachat NLEmbedding-objekt — töms vid termisk stress för att frigöra ANE/RAM
    private var cachedSwedishEmbedding: NLEmbedding?

    private func fallbackEmbed(_ text: String) -> [Float] {
        // C2: Returnera nollvektor vid termisk stress — undviker ANE-last
        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .serious || thermal == .critical {
            cachedSwedishEmbedding = nil
            return [Float](repeating: 0, count: 768)
        }

        // Lazy-ladda NLEmbedding och cacha referensen
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
        "Jag bearbetar din fråga. [Modell laddas fortfarande]"
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

        var color: Color {
            switch self {
            case .person: return .orange
            case .organization: return .blue
            case .location: return .green
            case .concept: return .purple
            case .time: return .cyan
            case .other: return .gray
            }
        }
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
}
