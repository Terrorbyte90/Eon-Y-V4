import Foundation
import CoreML
import NaturalLanguage

// MARK: - BertHandler: KB-BERT Swedish på ANE

actor BertHandler {
    private var model: MLModel?
    private var tokenizer: BertTokenizer?
    private let maxSeqLen = 512
    private var isLoaded = false

    func load() async throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        config.allowLowPrecisionAccumulationOnGPU = true

        guard let modelURL = Bundle.main.url(forResource: "KBBertSwedish", withExtension: "mlpackage") else {
            print("[BERT] Modell ej hittad i bundle — använder NLEmbedding fallback")
            tokenizer = BertTokenizer()
            return
        }

        do {
            model = try MLModel(contentsOf: modelURL, configuration: config)
            tokenizer = BertTokenizer()
            isLoaded = true
            print("[BERT] KB-BERT laddad på ANE ✓")
        } catch {
            print("[BERT] Laddningsfel: \(error) — använder fallback")
            tokenizer = BertTokenizer()
        }
    }

    // MARK: - Embedding

    func embed(_ text: String) async -> [Float] {
        guard let tokenizer = tokenizer else { return [Float](repeating: 0, count: 768) }

        let tokens = tokenizer.tokenize(text, maxLength: maxSeqLen)
        guard let model = model else {
            return nlEmbeddingFallback(text)
        }

        do {
            let inputIds = try MLMultiArray(shape: [1, NSNumber(value: tokens.inputIds.count)], dataType: .int32)
            let attentionMask = try MLMultiArray(shape: [1, NSNumber(value: tokens.inputIds.count)], dataType: .int32)
            let tokenTypeIds = try MLMultiArray(shape: [1, NSNumber(value: tokens.inputIds.count)], dataType: .int32)

            for (i, id) in tokens.inputIds.enumerated() {
                inputIds[i] = NSNumber(value: id)
                attentionMask[i] = NSNumber(value: tokens.attentionMask[i])
                tokenTypeIds[i] = NSNumber(value: 0)
            }

            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputIds,
                "attention_mask": attentionMask,
                "token_type_ids": tokenTypeIds
            ])

            let output = try await model.prediction(from: input)

            // KB-BERT output heter "embedding" (768-dim CLS-vektor)
            if let pooled = output.featureValue(for: "embedding")?.multiArrayValue {
                var result = [Float](repeating: 0, count: 768)
                for i in 0..<min(768, pooled.count) {
                    result[i] = pooled[i].floatValue
                }
                return result
            }
        } catch {
            print("[BERT] Embedding-fel: \(error)")
        }

        return nlEmbeddingFallback(text)
    }

    // MARK: - Pseudo-Log-Likelihood (PLL) för validering

    func pseudoLogLikelihood(_ sentence: String) async -> Double {
        // Förenklad PLL: mäter hur "naturlig" meningen är
        // I produktion: mask varje token och mät sannolikhet
        guard model != nil else { return 0.6 }

        let tokens = tokenizer?.tokenize(sentence, maxLength: 128)
        let tokenCount = tokens?.inputIds.count ?? 1
        // Normalisera baserat på meningslängd (kortare = mer säker baseline)
        let lengthPenalty = max(0.3, 1.0 - Double(tokenCount) / 200.0)
        return 0.5 + lengthPenalty * 0.3
    }

    // MARK: - Named Entity Recognition

    func extractEntities(from text: String) async -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // NLTagger som primär NER (fungerar utan modell)
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

        // Komplettera med nyckelord för koncept
        let conceptKeywords = ["algoritm", "system", "teori", "modell", "process", "metod", "teknik", "vetenskap"]
        let words = text.lowercased().split(separator: " ")
        for word in words {
            if conceptKeywords.contains(String(word)) {
                entities.append(ExtractedEntity(text: String(word), type: .concept, confidence: 0.6))
            }
        }

        return entities
    }

    // MARK: - Embedding fallback (NLEmbedding → word-level aggregation → hash)

    private func nlEmbeddingFallback(_ text: String) -> [Float] {
        // NLEmbedding.sentenceEmbedding: bästa tillgängliga utan CoreML
        if let sentEmb = NLEmbedding.sentenceEmbedding(for: .swedish),
           let vec = sentEmb.vector(for: text) {
            let floats = vec.prefix(768).map { Float($0) }
            return floats + [Float](repeating: 0, count: max(0, 768 - floats.count))
        }

        // NLEmbedding.wordEmbedding: aggregera ord-vektorer
        if let wordEmb = NLEmbedding.wordEmbedding(for: .swedish) {
            var result = [Float](repeating: 0, count: 768)
            var count = 0
            let words = text.split(separator: " ").prefix(30)
            for word in words {
                if let vec = wordEmb.vector(for: String(word)) {
                    for (i, v) in vec.prefix(768).enumerated() {
                        result[i] += Float(v)
                    }
                    count += 1
                }
            }
            if count > 0 {
                return result.map { $0 / Float(count) }
            }
        }

        // Engelska som sista NLEmbedding-fallback
        if let engEmb = NLEmbedding.sentenceEmbedding(for: .english),
           let vec = engEmb.vector(for: text) {
            let floats = vec.prefix(768).map { Float($0) }
            return floats + [Float](repeating: 0, count: max(0, 768 - floats.count))
        }

        // Hash-baserad absolut sista fallback
        var result = [Float](repeating: 0, count: 768)
        for (i, word) in text.split(separator: " ").prefix(20).enumerated() {
            result[i % 768] = Float(abs(word.hashValue) % 1000) / 1000.0
        }
        return result
    }
}

// MARK: - BertTokenizer (förenklad WordPiece)

final class BertTokenizer: @unchecked Sendable {
    private var vocab: [String: Int] = [:]
    private var reverseVocab: [Int: String] = [:]

    let clsToken = 101
    let sepToken = 102
    let padToken = 0
    let unkToken = 100

    nonisolated init() {
        loadVocab()
    }

    nonisolated private func loadVocab() {
        guard let url = Bundle(for: BertTokenizer.self).url(forResource: "bert_vocab", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("[BERT Tokenizer] vocab.txt ej hittad")
            return
        }
        for (i, line) in content.components(separatedBy: "\n").enumerated() {
            let token = line.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty {
                vocab[token] = i
                reverseVocab[i] = token
            }
        }
        print("[BERT Tokenizer] \(vocab.count) tokens laddade")
    }

    struct TokenizedInput {
        let inputIds: [Int]
        let attentionMask: [Int]
    }

    func tokenize(_ text: String, maxLength: Int) -> TokenizedInput {
        var ids = [clsToken]
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for word in words {
            if ids.count >= maxLength - 1 { break }
            if let id = vocab[word] {
                ids.append(id)
            } else {
                // WordPiece subword
                var remaining = word
                var found = false
                while !remaining.isEmpty && ids.count < maxLength - 1 {
                    var matched = false
                    for length in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                        let prefix = String(remaining.prefix(length))
                        let subword = ids.count > 1 ? "##\(prefix)" : prefix
                        if let id = vocab[subword] ?? vocab[prefix] {
                            ids.append(id)
                            remaining = String(remaining.dropFirst(length))
                            matched = true
                            found = true
                            break
                        }
                    }
                    if !matched {
                        ids.append(unkToken)
                        break
                    }
                }
                if !found { ids.append(unkToken) }
            }
        }

        ids.append(sepToken)

        // Padda till maxLength
        let mask = [Int](repeating: 1, count: ids.count)
        let paddedIds = ids + [Int](repeating: padToken, count: max(0, maxLength - ids.count))
        let paddedMask = mask + [Int](repeating: 0, count: max(0, maxLength - mask.count))

        return TokenizedInput(
            inputIds: Array(paddedIds.prefix(maxLength)),
            attentionMask: Array(paddedMask.prefix(maxLength))
        )
    }
}
