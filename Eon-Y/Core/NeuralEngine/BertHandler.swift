import Foundation
import NaturalLanguage

// MARK: - BertHandler: Compatibility wrapper — now backed by QwenHandler
// All BERT functionality is now provided by Qwen3-1.7B via llama.cpp.

typealias BertHandler = QwenHandler

// MARK: - BertTokenizer (kept for any residual references)

final class BertTokenizer: @unchecked Sendable {
    private var vocab: [String: Int] = [:]
    private var reverseVocab: [Int: String] = [:]

    let clsToken = 101
    let sepToken = 102
    let padToken = 0
    let unkToken = 100

    nonisolated init() {}

    struct TokenizedInput {
        let inputIds: [Int]
        let attentionMask: [Int]
    }

    func tokenize(_ text: String, maxLength: Int) -> TokenizedInput {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var ids = [clsToken]
        for word in words {
            if ids.count >= maxLength - 1 { break }
            ids.append(unkToken)
        }
        ids.append(sepToken)
        let mask = [Int](repeating: 1, count: ids.count)
        let paddedIds = ids + [Int](repeating: padToken, count: max(0, maxLength - ids.count))
        let paddedMask = mask + [Int](repeating: 0, count: max(0, maxLength - mask.count))
        return TokenizedInput(
            inputIds: Array(paddedIds.prefix(maxLength)),
            attentionMask: Array(paddedMask.prefix(maxLength))
        )
    }
}
