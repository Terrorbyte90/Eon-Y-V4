import Foundation
import CoreML
import NaturalLanguage

// MARK: - NeuralEngineOrchestrator: Koordinerar alla CoreML-modeller på ANE

actor NeuralEngineOrchestrator {
    static let shared = NeuralEngineOrchestrator()

    private(set) var bertHandler: BertHandler?
    private(set) var gptHandler: GptSw3Handler?
    private(set) var isLoaded: Bool = false
    private(set) var loadError: String?

    // Inference cache: LRU med TTL
    private var embeddingCache: [String: [Float]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 500

    private init() {}

    // MARK: - Loading

    func loadModels() async {
        guard !isLoaded else { return }
        print("[ANE] Laddar modeller...")

        do {
            let bert = BertHandler()
            try await bert.load()
            bertHandler = bert

            let gpt = GptSw3Handler()
            try await gpt.load()
            gptHandler = gpt

            isLoaded = true
            print("[ANE] Alla modeller laddade ✓")
        } catch {
            loadError = error.localizedDescription
            print("[ANE] Laddningsfel: \(error)")
        }
    }

    // MARK: - Embedding (KB-BERT)

    func embed(_ text: String) async -> [Float] {
        let key = text.prefix(100).description
        if let cached = embeddingCache[key] { return cached }

        guard let bert = bertHandler else {
            return fallbackEmbed(text)
        }

        let embedding = await bert.embed(text)
        cacheEmbedding(key: key, value: embedding)
        return embedding
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    // MARK: - Generation (GPT-SW3)

    func generate(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7) async -> String {
        guard let gpt = gptHandler else {
            return await fallbackGenerate(prompt)
        }
        return await gpt.generate(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature)
    }

    func generateStream(prompt: String, maxTokens: Int = 200, temperature: Float = 0.7) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let gpt = gptHandler else {
                    let fallback = await self.fallbackGenerate(prompt)
                    for word in fallback.split(separator: " ") {
                        continuation.yield(String(word) + " ")
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    continuation.finish()
                    return
                }
                await gpt.generateStream(prompt: prompt, maxNewTokens: maxTokens, temperature: temperature) { token in
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - BERT-PLL (Pseudo-Log-Likelihood för validering)

    func bertPLL(sentence: String) async -> Double {
        guard let bert = bertHandler else { return 0.5 }
        return await bert.pseudoLogLikelihood(sentence)
    }

    // MARK: - NER (Named Entity Recognition via BERT)

    func extractEntities(from text: String) async -> [ExtractedEntity] {
        guard let bert = bertHandler else { return [] }
        return await bert.extractEntities(from: text)
    }

    // MARK: - Cache management

    private func cacheEmbedding(key: String, value: [Float]) {
        if cacheOrder.count >= maxCacheSize {
            let evict = cacheOrder.removeFirst()
            embeddingCache.removeValue(forKey: evict)
        }
        embeddingCache[key] = value
        cacheOrder.append(key)
    }

    // MARK: - Fallbacks (när modeller inte är laddade)

    private func fallbackEmbed(_ text: String) -> [Float] {
        // NLEmbedding som fallback
        let embedding = NLEmbedding.wordEmbedding(for: .swedish)
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
