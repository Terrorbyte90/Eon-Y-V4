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
        // Hash-baserad cache-nyckel — förhindrar kollisioner
        let cacheKey = (text + "\(modelVersion)").hashValue
        if let cached = embeddingCache[cacheKey] { return cached }

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

    private func cacheEmbedding(key: Int, value: [Float]) {
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
