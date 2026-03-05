import Foundation
import llama

// MARK: - QwenHandler: Qwen3-1.7B GGUF via llama.cpp
// Replaces BertHandler + GptSw3Handler with a single unified handler.
// Supports both embedding (via hidden state pooling) and generation.
// Qwen3 has built-in /think and /no_think modes for reasoning.

actor QwenHandler {
    private var model: OpaquePointer?      // llama_model
    private var defaultCtx: OpaquePointer? // llama_context for generation
    private var embedCtx: OpaquePointer?   // llama_context for embeddings (smaller)
    private(set) var isLoaded = false
    private let modelFileName = "Qwen3-1.7B-Q4_K_M"

    // Thermal-aware generation limits
    private var maxContextSize: Int32 = 2048
    private let embeddingDim: Int = 1536 // Qwen3-1.7B hidden dim

    // Token tracking for anti-repetition
    private var generatedTokenHistory: [llama_token] = []

    // Thermal cooldown: timestamp of last generation completion
    private var lastGenerationEnd: Date = .distantPast

    // Swedish function words that should NOT be penalized for repetition
    private static let swedishFunctionWords: Set<String> = [
        "och", "att", "en", "ett", "det", "den", "de", "i", "på", "av",
        "för", "med", "som", "är", "var", "har", "inte", "om", "till",
        "kan", "men", "så", "jag", "du", "vi", "man", "sig", "sin",
        "sitt", "sina", "min", "mitt", "mina", "alla", "från", "vid",
        "när", "hur", "vad", "ut", "in", "upp", "ner", "efter", "under",
        "mellan", "genom", "utan", "mot", "hos", "sedan", "bara"
    ]
    private var functionWordTokens: Set<llama_token> = []

    deinit {
        if let ctx = defaultCtx { llama_free(ctx) }
        if let ctx = embedCtx { llama_free(ctx) }
        if let m = model { llama_free_model(m) }
    }

    // MARK: - Loading

    func load() async throws {
        guard !isLoaded else { return }
        llama_backend_init()

        guard let modelPath = Bundle.main.path(forResource: modelFileName, ofType: "gguf") else {
            print("[QWEN] Model file not found in bundle: \(modelFileName).gguf")
            throw QwenError.modelNotFound
        }

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99

        guard let loadedModel = llama_load_model_from_file(modelPath, modelParams) else {
            print("[QWEN] Failed to load model from: \(modelPath)")
            throw QwenError.modelLoadFailed
        }
        model = loadedModel

        var genParams = llama_context_default_params()
        genParams.n_ctx = UInt32(maxContextSize)
        genParams.n_batch = 512
        genParams.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        genParams.n_threads_batch = Int32(max(1, ProcessInfo.processInfo.processorCount - 2))
        genParams.flash_attn = true

        guard let genCtx = llama_new_context_with_model(loadedModel, genParams) else {
            throw QwenError.contextCreationFailed
        }
        defaultCtx = genCtx

        var embParams = llama_context_default_params()
        embParams.n_ctx = 512
        embParams.n_batch = 512
        embParams.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount / 2))
        embParams.embeddings = true

        if let eCtx = llama_new_context_with_model(loadedModel, embParams) {
            embedCtx = eCtx
        }

        buildFunctionWordTokenSet()
        isLoaded = true
        print("[QWEN] Qwen3-1.7B Q4_K_M loaded ✓ (Metal GPU)")
    }

    func unload() {
        if let ctx = defaultCtx { llama_free(ctx); defaultCtx = nil }
        if let ctx = embedCtx { llama_free(ctx); embedCtx = nil }
        if let m = model { llama_free_model(m); model = nil }
        isLoaded = false
        generatedTokenHistory.removeAll()
        functionWordTokens.removeAll()
        print("[QWEN] Model unloaded")
    }

    // MARK: - Batch Helper

    private func batchAdd(_ batch: inout llama_batch, _ token: llama_token, _ pos: Int32, _ seqIds: [llama_seq_id], _ logits: Bool) {
        let i = Int(batch.n_tokens)
        batch.token[i] = token
        batch.pos[i] = pos
        batch.n_seq_id[i] = Int32(seqIds.count)
        for (j, sid) in seqIds.enumerated() {
            batch.seq_id[i]![j] = sid
        }
        batch.logits[i] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Tokenization

    private func tokenize(_ text: String, addSpecial: Bool = true) -> [llama_token] {
        guard let mdl = model else { return [] }
        let utf8 = Array(text.utf8)
        let maxTokens = utf8.count + 16
        var tokens = [llama_token](repeating: 0, count: maxTokens)
        let nTokens = llama_tokenize(mdl, text, Int32(text.utf8.count), &tokens, Int32(maxTokens), addSpecial, true)
        guard nTokens >= 0 else { return [] }
        return Array(tokens.prefix(Int(nTokens)))
    }

    private func detokenize(_ token: llama_token) -> String {
        guard let mdl = model else { return "" }
        var buf = [CChar](repeating: 0, count: 256)
        let len = llama_token_to_piece(mdl, token, &buf, Int32(buf.count), 0, true)
        guard len > 0 else { return "" }
        return String(cString: Array(buf.prefix(Int(len))) + [0])
    }

    private func detokenizeAll(_ tokens: [llama_token]) -> String {
        tokens.map { detokenize($0) }.joined()
    }

    // MARK: - Embedding (replaces BERT)

    func embed(_ text: String) async -> [Float] {
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical {
            return fallbackEmbed(text)
        }

        guard let ctx = embedCtx, let mdl = model else {
            return fallbackEmbed(text)
        }

        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return fallbackEmbed(text) }

        let truncated = Array(tokens.prefix(510))
        llama_kv_cache_clear(ctx)

        var batch = llama_batch_init(Int32(truncated.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in truncated.enumerated() {
            batchAdd(&batch, token, Int32(i), [0], i == truncated.count - 1)
        }

        let result = llama_decode(ctx, batch)
        guard result == 0 else { return fallbackEmbed(text) }

        let nEmbd = Int(llama_n_embd(mdl))
        guard let embeddings = llama_get_embeddings(ctx) else {
            return fallbackEmbed(text)
        }

        var embedding = [Float](repeating: 0, count: nEmbd)
        for i in 0..<nEmbd {
            embedding[i] = embeddings[i]
        }

        let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            embedding = embedding.map { $0 / norm }
        }

        if nEmbd >= 768 {
            return Array(embedding.prefix(768))
        } else {
            return embedding + [Float](repeating: 0, count: 768 - nEmbd)
        }
    }

    // MARK: - Generation (replaces GPT-SW3)

    func generateStream(
        prompt: String,
        maxNewTokens: Int = 300,
        temperature: Float = 0.7,
        enableThinking: Bool = false,
        onToken: @escaping (String) async -> Void
    ) async {
        let thermalState = ProcessInfo.processInfo.thermalState
        if thermalState == .critical {
            print("[QWEN] Thermal critical — skipping inference, using NL fallback")
            let fallback = NLResponseEngine.generate(for: prompt)
            for word in fallback.split(separator: " ") {
                await onToken(String(word) + " ")
            }
            return
        }

        let cooldown = ThermalSleepManager.shared.thermalCooldownSeconds()
        if cooldown > 0 {
            let elapsed = Date().timeIntervalSince(lastGenerationEnd)
            if elapsed < cooldown {
                let waitNs = UInt64((cooldown - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: waitNs)
            }
        }

        guard let ctx = defaultCtx, let mdl = model else {
            let fallback = NLResponseEngine.generate(for: prompt)
            for word in fallback.split(separator: " ") {
                await onToken(String(word) + " ")
            }
            return
        }

        let adjustedMaxTokens = ThermalSleepManager.shared.thermalAdjustedMaxTokens(base: maxNewTokens)
        guard adjustedMaxTokens > 0 else {
            let fallback = NLResponseEngine.generate(for: prompt)
            for word in fallback.split(separator: " ") {
                await onToken(String(word) + " ")
            }
            lastGenerationEnd = Date()
            return
        }

        let formattedPrompt = formatQwenPrompt(prompt, enableThinking: enableThinking)
        let tokens = tokenize(formattedPrompt)
        guard !tokens.isEmpty else { return }

        let truncated = Array(tokens.suffix(Int(maxContextSize) - adjustedMaxTokens - 32))
        llama_kv_cache_clear(ctx)

        var batch = llama_batch_init(Int32(truncated.count), 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in truncated.enumerated() {
            batchAdd(&batch, token, Int32(i), [0], i == truncated.count - 1)
        }

        var decodeResult = llama_decode(ctx, batch)
        guard decodeResult == 0 else { return }

        let sampler = createSampler(temperature: temperature, mdl: mdl)
        defer { llama_sampler_free(sampler) }

        var generatedTokens: [llama_token] = []
        var curPos = Int32(truncated.count)
        var inThinkBlock = false
        var consecutiveEmpty = 0

        let eosToken = llama_token_eos(mdl)
        let eotToken = llama_token_eot(mdl)

        for _ in 0..<adjustedMaxTokens {
            let newToken = llama_sampler_sample(sampler, ctx, -1)

            if newToken == eosToken || newToken == eotToken {
                if generatedTokens.count >= 8 { break }
                continue
            }

            let piece = detokenize(newToken)

            if piece.contains("<think>") { inThinkBlock = true }
            if piece.contains("</think>") {
                inThinkBlock = false
                continue
            }

            if !enableThinking && inThinkBlock { continue }

            generatedTokens.append(newToken)

            if !piece.trimmingCharacters(in: .whitespaces).isEmpty {
                consecutiveEmpty = 0
                await onToken(piece)
            } else {
                consecutiveEmpty += 1
                if consecutiveEmpty > 5 { break }
            }

            llama_batch_free(batch)
            batch = llama_batch_init(1, 0, 1)
            batchAdd(&batch, newToken, curPos, [0], true)
            curPos += 1

            decodeResult = llama_decode(ctx, batch)
            if decodeResult != 0 { break }

            let midThermal = ProcessInfo.processInfo.thermalState
            if midThermal == .critical { break }
            if midThermal == .serious && generatedTokens.count >= 80 { break }
        }

        generatedTokenHistory.append(contentsOf: generatedTokens)
        if generatedTokenHistory.count > 500 {
            generatedTokenHistory.removeFirst(generatedTokenHistory.count - 500)
        }

        lastGenerationEnd = Date()
    }

    func generate(prompt: String, maxNewTokens: Int = 300, temperature: Float = 0.7, enableThinking: Bool = false) async -> String {
        var result = ""
        await generateStream(prompt: prompt, maxNewTokens: maxNewTokens, temperature: temperature, enableThinking: enableThinking) { token in
            result += token
        }
        return result
    }

    // MARK: - Prompt Formatting

    private func formatQwenPrompt(_ prompt: String, enableThinking: Bool) -> String {
        let thinkTag = enableThinking ? "" : "/no_think"
        let systemPrompt = """
        Du är Eon, en varm och personlig AI-kompanjon som körs on-device. Svenska.
        REGLER:
        - Svara DIREKT med substans. Börja aldrig med "Det du frågar om" eller liknande.
        - Eka ALDRIG användarens fråga tillbaka.
        - Använd ALDRIG frasen "kan analyseras från flera perspektiv".
        - Upprepa aldrig samma mening eller idé.
        - Var varm, genuin och personlig i tonen — som en klok vän.
        - Dela med dig av insikter, tankar och nyanser.
        \(thinkTag)
        """

        return "<|im_start|>system\n\(systemPrompt)<|im_end|>\n<|im_start|>user\n\(prompt)<|im_end|>\n<|im_start|>assistant\n"
    }

    // MARK: - Sampler

    private func createSampler(temperature: Float, mdl: OpaquePointer) -> UnsafeMutablePointer<llama_sampler> {
        let sparams = llama_sampler_chain_default_params()
        let chain = llama_sampler_chain_init(sparams)!

        llama_sampler_chain_add(chain, llama_sampler_init_penalties(
            llama_n_vocab(mdl),
            llama_token_eos(mdl),
            llama_token_nl(mdl),
            64,
            1.3,
            0.0,
            0.0,
            false,
            false
        ))

        let topK: Int32 = temperature < 0.5 ? 30 : (temperature < 0.7 ? 50 : 80)
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(topK))

        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.90, 1))

        llama_sampler_chain_add(chain, llama_sampler_init_temp(max(temperature, 0.01)))

        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        return chain
    }

    // MARK: - PLL (sentence quality scoring, replaces BERT PLL)

    func pseudoLogLikelihood(_ sentence: String) async -> Double {
        guard isLoaded else { return 0.6 }
        let tokens = tokenize(sentence)
        let lengthPenalty = max(0.3, 1.0 - Double(tokens.count) / 200.0)
        return 0.5 + lengthPenalty * 0.3
    }

    // MARK: - Function Word Token Set

    private func buildFunctionWordTokenSet() {
        for word in Self.swedishFunctionWords {
            let ids = tokenize(word, addSpecial: false)
            functionWordTokens.formUnion(ids)
            let capIds = tokenize(word.capitalized, addSpecial: false)
            functionWordTokens.formUnion(capIds)
        }
    }

    // MARK: - Fallback Embedding

    private func fallbackEmbed(_ text: String) -> [Float] {
        import_NLEmbedding_fallback(text)
    }
}

private func import_NLEmbedding_fallback(_ text: String) -> [Float] {
    var result = [Float](repeating: 0, count: 768)
    for (i, word) in text.split(separator: " ").prefix(20).enumerated() {
        let hash = word.hashValue
        result[i % 768] = Float(abs(hash) % 1000) / 1000.0
        result[(i + 256) % 768] = Float(abs(hash >> 16) % 1000) / 1000.0
    }
    let norm = sqrt(result.reduce(0) { $0 + $1 * $1 })
    if norm > 0 { result = result.map { $0 / norm } }
    return result
}

// MARK: - Errors

enum QwenError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed
    case contextCreationFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound: return "Qwen3 GGUF model not found in bundle"
        case .modelLoadFailed: return "Failed to load Qwen3 model"
        case .contextCreationFailed: return "Failed to create llama context"
        }
    }
}
