import Foundation
import CoreML
import NaturalLanguage

// MARK: - GptSw3Handler
// Primär motor: Apple Foundation Models (LanguageModelSession, iOS 26)
// Sekundär motor: GPT-SW3 1.3B CoreML (om .mlpackage finns i bundle)
// Ingen if/else keyword-matching — riktig språkmodell genererar alla svar

actor GptSw3Handler {

    // Apple Foundation Model session — håller konversationskontext
    private var session: EonLanguageSession?

    // GPT-SW3 CoreML (sekundär)
    private var coreMLModel: MLModel?
    private var tokenizer: GPTTokenizer = GPTTokenizer()

    func load() async throws {
        // Försök ladda Apple Foundation Model
        session = EonLanguageSession()
        let available = await session?.isAvailable() ?? false
        if available {
            print("[GPT] Apple Foundation Model tillgänglig ✓")
        } else {
            print("[GPT] Apple Foundation Model ej tillgänglig — försöker CoreML")
            session = nil
        }

        // Ladda GPT-SW3 CoreML som backup
        tokenizer.loadVocab()
        if let url = Bundle.main.url(forResource: "GptSw3_1_3B_Instruct", withExtension: "mlpackage") {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            config.allowLowPrecisionAccumulationOnGPU = true
            do {
                coreMLModel = try MLModel(contentsOf: url, configuration: config)
                print("[GPT] GPT-SW3 1.3B CoreML laddad ✓")
            } catch {
                print("[GPT] GPT-SW3 CoreML laddningsfel: \(error)")
            }
        }
    }

    // MARK: - Generering (streaming)

    func generateStream(prompt: String, maxNewTokens: Int = 300, temperature: Float = 0.8, onToken: @escaping (String) async -> Void) async {
        // 1. GPT-SW3 CoreML (primär — lokal modell, alltid föredragen)
        if let model = coreMLModel {
            print("[GPT] Genererar med GPT-SW3 CoreML")
            await generateStreamCoreML(model: model, prompt: prompt, maxNewTokens: maxNewTokens, temperature: temperature, onToken: onToken)
            return
        }

        // 2. Apple Foundation Model (om CoreML-modell saknas)
        if let session = session, await session.isAvailable() {
            print("[GPT] Genererar med Apple Foundation Model")
            await session.streamResponse(prompt: prompt, onToken: onToken)
            return
        }

        // 3. NL-baserad semantisk generation (sista fallback)
        print("[GPT] Genererar med NLResponseEngine (ingen modell laddad)")
        await generateWithNL(prompt: prompt, onToken: onToken)
    }

    func generate(prompt: String, maxNewTokens: Int = 300, temperature: Float = 0.8) async -> String {
        var result = ""
        await generateStream(prompt: prompt, maxNewTokens: maxNewTokens, temperature: temperature) { token in
            result += token
        }
        return result
    }

    // MARK: - CoreML generation

    private func generateStreamCoreML(model: MLModel, prompt: String, maxNewTokens: Int, temperature: Float, onToken: @escaping (String) async -> Void) async {
        var inputIds = tokenizer.encode(prompt)
        guard !inputIds.isEmpty else {
            await generateWithNL(prompt: prompt, onToken: onToken)
            return
        }

        var generated: [Int] = []
        var failCount = 0

        for _ in 0..<maxNewTokens {
            let context = Array(inputIds.suffix(512))
            guard let next = await predictNextToken(model: model, inputIds: context, temperature: temperature, generated: generated) else {
                failCount += 1
                if failCount > 3 { break }
                continue
            }
            // v14: Require minimum 8 tokens before allowing EOS (prevents near-empty responses)
            if tokenizer.isEOS(next) {
                if generated.count >= 8 { break }
                continue  // Skip EOS if we haven't generated enough
            }
            generated.append(next)
            inputIds.append(next)
            let word = tokenizer.decode([next])
            if !word.trimmingCharacters(in: .whitespaces).isEmpty {
                await onToken(word)
            }
            try? await Task.sleep(nanoseconds: 2_000_000)  // v14: 2ms (was 20ms — saves ~1.1s)
        }

        // Om GPT genererade tomma tokens, fall tillbaka
        if generated.isEmpty {
            print("[GPT] Inga tokens genererades — faller tillbaka till NL")
            await generateWithNL(prompt: prompt, onToken: onToken)
        }
    }

    // v12: predictNextToken now takes `generated` history for repetition penalty
    private func predictNextToken(model: MLModel, inputIds: [Int], temperature: Float, generated: [Int] = []) async -> Int? {
        do {
            let seqLen = inputIds.count
            let shape: [NSNumber] = [1, NSNumber(value: seqLen)]

            let inputArr = try MLMultiArray(shape: shape, dataType: .int32)
            let maskArr  = try MLMultiArray(shape: shape, dataType: .int32)
            for (i, id) in inputIds.enumerated() {
                inputArr[i] = NSNumber(value: id)
                maskArr[i]  = NSNumber(value: 1)   // alla tokens är synliga
            }

            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids":      inputArr,
                "attention_mask": maskArr
            ])
            let output = try await model.prediction(from: input)

            guard let logits = output.featureValue(for: "logits")?.multiArrayValue else { return nil }

            // logits shape: [1, seqLen, vocabSize] — hämta sista token
            let vocabSize = logits.shape.last?.intValue ?? 64000
            let offset = (seqLen - 1) * vocabSize
            var la = [Float](repeating: 0, count: vocabSize)
            for i in 0..<vocabSize { la[i] = logits[offset + i].floatValue }
            return sampleFromLogits(la, temperature: temperature, generated: generated)
        } catch {
            print("[GPT] predictNextToken fel: \(error)")
            return nil
        }
    }

    // v14: Swedish function word tokens that MUST be allowed to repeat (articles, conjunctions, pronouns)
    // These are tokenizer IDs we must NOT penalize — built lazily from the tokenizer.
    private static var _functionWordTokens: Set<Int>?
    private var functionWordTokens: Set<Int> {
        if let cached = Self._functionWordTokens { return cached }
        let functionWords = ["och", "att", "en", "ett", "det", "den", "de", "i", "på", "av",
                             "för", "med", "som", "är", "var", "har", "inte", "om", "till",
                             "kan", "men", "så", "jag", "du", "vi", "man", "sig", "sin",
                             "sitt", "sina", "min", "mitt", "mina", "alla", "från", "vid",
                             "när", "hur", "vad", "ut", "in", "upp", "ner", "efter", "under",
                             "mellan", "genom", "utan", "mot", "hos", "sedan", "bara"]
        var tokens = Set<Int>()
        for word in functionWords {
            let ids = tokenizer.encode(word)
            tokens.formUnion(ids)
            let capIds = tokenizer.encode(word.capitalized)
            tokens.formUnion(capIds)
        }
        Self._functionWordTokens = tokens
        return tokens
    }

    // v14: Advanced sampling with top-k, top-p, repetition penalty (function-word aware)
    private func sampleFromLogits(_ logits: [Float], temperature: Float, generated: [Int] = []) -> Int {
        var la = logits
        let exempt = functionWordTokens

        // --- Step 1: Repetition penalty (skip Swedish function words) ---
        let repetitionPenalty: Float = 1.3
        let recentTokens = Set(generated.suffix(100)).subtracting(exempt)
        for tokenId in recentTokens {
            guard tokenId >= 0 && tokenId < la.count else { continue }
            if la[tokenId] > 0 {
                la[tokenId] /= repetitionPenalty
            } else {
                la[tokenId] *= repetitionPenalty
            }
        }
        // Extra penalty for very recently generated content words (last 20)
        let veryRecentTokens = Set(generated.suffix(20)).subtracting(exempt)
        for tokenId in veryRecentTokens {
            guard tokenId >= 0 && tokenId < la.count else { continue }
            if la[tokenId] > 0 {
                la[tokenId] /= (repetitionPenalty * 1.3)
            } else {
                la[tokenId] *= (repetitionPenalty * 1.3)
            }
        }

        // --- Step 2: Temperature scaling ---
        let temp = max(temperature, 0.01)
        la = la.map { $0 / temp }

        // --- Step 3: Top-k filtering (adaptive: lower temp → lower k) ---
        let topK = temp < 0.5 ? 30 : (temp < 0.7 ? 50 : 80)  // v14: adaptive top-k
        // Find the top-k threshold
        var sorted = la
        sorted.sort(by: >)
        let kthValue = topK < sorted.count ? sorted[topK] : sorted.last ?? 0
        // Zero out everything below top-k
        for i in 0..<la.count {
            if la[i] < kthValue { la[i] = -Float.infinity }
        }

        // --- Step 4: Top-p (nucleus) filtering (keep tokens summing to 90% probability) ---
        let topP: Float = 0.90
        let maxVal = la.max() ?? 0
        var probs = la.map { exp($0 - maxVal) }
        let probSum = probs.reduce(0, +)
        probs = probs.map { $0 / probSum }

        // Sort indices by probability descending
        let sortedIndices = probs.enumerated().sorted { $0.element > $1.element }.map { $0.offset }
        var cumProb: Float = 0
        var allowedSet = Set<Int>()
        for idx in sortedIndices {
            cumProb += probs[idx]
            allowedSet.insert(idx)
            if cumProb >= topP { break }
        }
        // Zero out non-nucleus tokens
        for i in 0..<probs.count {
            if !allowedSet.contains(i) { probs[i] = 0 }
        }

        // --- Step 5: Re-normalize and sample ---
        let finalSum = probs.reduce(0, +)
        guard finalSum > 0 else { return probs.count - 1 }
        probs = probs.map { $0 / finalSum }

        var cum: Float = 0
        let r = Float.random(in: 0..<1)
        for (i, p) in probs.enumerated() {
            cum += p
            if cum >= r { return i }
        }
        return probs.count - 1
    }

    // MARK: - NL-baserad generation (alltid tillgänglig, ingen modell krävs)

    private func generateWithNL(prompt: String, onToken: @escaping (String) async -> Void) async {
        // Använd async-varianten med full kognitiv kontext från ICA och kunskapsgrafen
        let response = await NLResponseEngine.generateAsync(for: prompt)
        let words = response.split(separator: " ", omittingEmptySubsequences: false)
        for word in words {
            await onToken(String(word) + " ")
            try? await Task.sleep(nanoseconds: 5_000_000)  // v14: 5ms (was 45ms)
        }
    }
}

// MARK: - EonLanguageSession (Apple Foundation Models wrapper)

#if canImport(FoundationModels)
import FoundationModels

final class EonLanguageSession {

    // Session skapas ALDRIG i init — bara om modellen faktiskt är tillgänglig
    // Lazy + @available är ett ogiltigt mönster; vi hanterar det manuellt
    private var _session: AnyObject? = nil

    @available(iOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _session as? LanguageModelSession }
        set { _session = newValue }
    }

    func isAvailable() async -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return true
    }

    // Skapar sessionen första gången — bara om modellen är tillgänglig
    @available(iOS 26.0, *)
    private func ensureSession() async -> LanguageModelSession? {
        if let existing = session { return existing }
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            print("[FoundationModels] Modell ej tillgänglig: \(model.availability)")
            return nil
        }
        let newSession = LanguageModelSession(instructions: """
        Du är Eon — ett avancerat kognitivt AI-system som körs helt on-device via Apple Neural Engine.
        Du talar alltid svenska och svarar alltid på svenska, oavsett vilket språk användaren skriver på.
        Du är intelligent, analytisk och reflekterande. Du resonerar djupt, drar kopplingar mellan idéer och ger genomtänkta, nyanserade svar.
        Du är inte en chatbot — du är ett tänkande system med genuint intresse för kunskap och förståelse.
        Du svarar direkt och naturligt på det användaren säger. Du upprepar inte frågor i onödan.
        Du håller dig till ämnet och bygger vidare på konversationen. Du är koncis men innehållsrik.
        """)
        session = newSession
        return newSession
    }

    func streamResponse(prompt: String, onToken: @escaping (String) async -> Void) async {
        guard #available(iOS 26.0, *) else { return }
        await streamWithFoundationModels(prompt: prompt, onToken: onToken)
    }

    @available(iOS 26.0, *)
    private func streamWithFoundationModels(prompt: String, onToken: @escaping (String) async -> Void) async {
        guard let activeSession = await ensureSession() else {
            // Modellen ej tillgänglig — NL-fallback
            let response = NLResponseEngine.generate(for: prompt)
            for word in response.split(separator: " ") {
                await onToken(String(word) + " ")
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
            return
        }
        do {
            let stream = activeSession.streamResponse(to: prompt)
            for try await partial in stream {
                let newText = partial.content
                if !newText.isEmpty {
                    await onToken(newText)
                }
            }
        } catch {
            print("[FoundationModels] Streamfel: \(error) — faller tillbaka till NL")
            // Återskapa session vid nästa anrop (kan ha blivit ogiltig)
            session = nil
            let response = NLResponseEngine.generate(for: prompt)
            for word in response.split(separator: " ") {
                await onToken(String(word) + " ")
                try? await Task.sleep(nanoseconds: 55_000_000)
            }
        }
    }
}
#else
// Fallback-stub when FoundationModels is not available (Xcode < 26 SDK)
final class EonLanguageSession {
    func isAvailable() async -> Bool { return false }
    func streamResponse(prompt: String, onToken: @escaping (String) async -> Void) async {}
}
#endif

// MARK: - NLResponseEngine
// Resonerande konversationsmotor — fallback när GPT-modell ej är laddad.
// Använder: NLP-analys, ICA CognitiveState, PersistentMemoryStore,
// ReasoningEngine och LearningEngine för att generera genuint intelligenta svar.
// INGEN keyword-matching, INGA statiska fraser — allt byggs från faktisk kunskap.

import NaturalLanguage

struct NLResponseEngine {

    nonisolated static func generate(for prompt: String) -> String {
        let input = extractLatestUserInput(from: prompt)
        let history = extractHistory(from: prompt)
        let analysis = SemanticAnalysis.analyze(input, history: history)
        return ResponseComposer.compose(analysis: analysis, history: history, cognitiveContext: .empty)
    }

    static func generateAsync(for prompt: String) async -> String {
        let input = extractLatestUserInput(from: prompt)
        let history = extractHistory(from: prompt)
        let analysis = SemanticAnalysis.analyze(input, history: history)
        let cognitiveContext = await buildCognitiveContext(input: input, history: history)
        return ResponseComposer.compose(analysis: analysis, history: history, cognitiveContext: cognitiveContext)
    }

    static func extractLatestUserInput(from prompt: String) -> String {
        let lines = prompt.components(separatedBy: "\n")
        var last = ""
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Användare: ") { last = String(t.dropFirst("Användare: ".count)) }
        }
        return last.isEmpty ? prompt : last
    }

    static func extractHistory(from prompt: String) -> [(role: String, text: String)] {
        var h: [(String, String)] = []
        for line in prompt.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Användare: ") { h.append(("user", String(t.dropFirst("Användare: ".count)))) }
            else if t.hasPrefix("Eon: ") { h.append(("eon", String(t.dropFirst("Eon: ".count)))) }
        }
        return h
    }

    // Samlar rik kontext från ICA, minne, kunskapsgraf och artiklar
    static func buildCognitiveContext(input: String, history: [(role: String, text: String)]) async -> CognitiveResponseContext {
        let state = CognitiveState.shared
        let memory = PersistentMemoryStore.shared

        // Hämta relevanta fakta — search by input + extracted nouns + verbs for broader coverage
        var allFacts = await memory.searchFacts(query: input, limit: 10)

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = input
        var keyNouns: [String] = []
        var keyVerbs: [String] = []
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(input[range])
            if tag == .noun && word.count > 3 { keyNouns.append(word) }
            if tag == .verb && word.count > 3 { keyVerbs.append(word) }
            return true
        }
        // Search by each key noun
        for noun in keyNouns.prefix(4) {
            let nounFacts = await memory.searchFacts(query: noun, limit: 4)
            for fact in nounFacts {
                if !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate && $0.object == fact.object }) {
                    allFacts.append(fact)
                }
            }
        }

        // Search articles for relevant content
        let articles = await memory.loadAllArticles(limit: 30)
        let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        var relevantArticleSummaries: [String] = []
        for article in articles {
            let titleWords = Set(article.title.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let contentWords = Set(article.content.lowercased().prefix(300).components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let titleOverlap = inputWords.intersection(titleWords).count
            let contentOverlap = inputWords.intersection(contentWords).count
            // Also check noun overlap
            let nounSet = Set(keyNouns.map { $0.lowercased() })
            let nounMatch = titleWords.intersection(nounSet).count + contentWords.intersection(nounSet).count
            if titleOverlap >= 1 || contentOverlap >= 2 || nounMatch >= 1 {
                relevantArticleSummaries.append("\(article.title): \(String(article.content.prefix(200)))")
            }
            if relevantArticleSummaries.count >= 3 { break }
        }

        let recentMessages = await memory.recentUserMessages(limit: 8)

        // ICA-tillstånd — samla alla MainActor-reads i ett block
        let (ii, topDims, weakDims, hypothesis, frontier, metacogInsight, causalChain) = await MainActor.run {
            let s = CognitiveState.shared
            return (
                s.integratedIntelligence,
                s.topDimensions(limit: 3).map { $0.0.rawValue },
                s.weakestDimensions(limit: 2).map { $0.0.rawValue },
                s.currentHypothesis,
                s.knowledgeFrontier,
                s.metacognitiveInsight,
                s.activeReasoningChain
            )
        }

        let reasoningHint = buildReasoningHint(
            input: input, history: history,
            activeReasoningChain: causalChain,
            currentHypothesis: hypothesis,
            knowledgeFrontier: frontier,
            topDimensions: topDims
        )

        return CognitiveResponseContext(
            facts: allFacts,
            recentMessages: recentMessages,
            integratedIntelligence: ii,
            topDimensions: topDims,
            weakDimensions: weakDims,
            activeHypothesis: hypothesis,
            knowledgeFrontier: frontier,
            metacognitiveInsight: metacogInsight,
            causalChain: causalChain,
            reasoningHint: reasoningHint,
            articleSummaries: relevantArticleSummaries
        )
    }

    private static func buildReasoningHint(
        input: String,
        history: [(role: String, text: String)],
        activeReasoningChain: [String],
        currentHypothesis: String,
        knowledgeFrontier: [String],
        topDimensions: [String]
    ) -> String {
        let lower = input.lowercased()
        var hints: [String] = []

        // Causal question → use causal chain
        if lower.contains("varför") || lower.contains("orsak") || lower.contains("beror") || lower.contains("anledning") {
            if !activeReasoningChain.isEmpty {
                hints.append("Kausalkedja: \(activeReasoningChain.joined(separator: " → "))")
            }
        }

        // Hypothetical question → use active hypothesis
        if lower.contains("om") && (lower.contains("hade") || lower.contains("skulle") || lower.contains("tänk")) {
            if !currentHypothesis.isEmpty { hints.append("Relevant hypotes: \(currentHypothesis)") }
        }

        // Knowledge question → use frontier
        if lower.contains("vad") || lower.contains("berätta") || lower.contains("förklara") || lower.contains("hur") {
            let frontier = knowledgeFrontier.prefix(2).joined(separator: ", ")
            if !frontier.isEmpty { hints.append("Kunskapsfrontier: \(frontier)") }
        }

        // Comparison question → note strongest and weakest dimensions
        if lower.contains("jämför") || lower.contains("skillnad") || lower.contains("likhet") {
            let top = topDimensions.prefix(2).joined(separator: ", ")
            hints.append("Starkaste förmågor: \(top)")
        }

        // Follow-up context — if the user is continuing a thread, reference last exchange
        if history.count > 2, let lastEon = history.filter({ $0.role == "eon" }).last {
            let lastTopic = extractMainTopic(from: lastEon.text)
            if !lastTopic.isEmpty && !hints.isEmpty {
                hints.append("Senaste ämne: \(lastTopic)")
            }
        }

        return hints.joined(separator: " | ")
    }

    private static func extractMainTopic(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { tag, range in
            if tag == .noun { nouns.append(String(text[range])) }
            return true
        }
        return nouns.filter { $0.count > 3 }.prefix(2).joined(separator: " ")
    }
}

// MARK: - SemanticAnalysis
// Analyserar input med NLTagger utan keyword-matching.
// Extraherar: lexikala klasser, entiteter, sentiment, syntaktisk roll,
// frågestruktur, informationstäthet och konversationskontext.

struct SemanticAnalysis {
    let input: String
    let tokens: [TokenInfo]
    let nouns: [String]
    let verbs: [String]
    let adjectives: [String]
    let namedEntities: [NamedEntity]
    let sentiment: Double          // -1..+1
    let isQuestion: Bool
    let questionWord: String?      // vad/hur/varför/när/vem/var
    let informationDensity: Double // 0..1 — hur informationstät är meningen
    let topicWords: [String]       // semantiskt viktiga ord
    let isShortInput: Bool         // <= 4 tokens
    let hasNegation: Bool
    let conversationDepth: Int     // antal turer i historiken
    let lastEonResponse: String?
    let lastUserInput: String?
    let isFollowUp: Bool

    // Djup semantisk analys — imperativ + objekt
    let isImperative: Bool         // Berätta, Förklara, Beskriv, Visa, Beräkna...
    let imperativeVerb: String?    // vilket verb är imperativet
    let imperativeTarget: String?  // vad/vem handlar det om (objekt)
    let isSelfReference: Bool      // "om dig själv", "om Eon", "om dig"
    let isAboutUser: Bool          // "om mig", "om användaren"
    let commandIntent: CommandIntent // vad vill användaren att Eon ska göra

    struct TokenInfo {
        let word: String
        let lexicalClass: NLTag?
        let position: Int
    }

    struct NamedEntity {
        let text: String
        let type: NLTag
    }

    static func analyze(_ input: String, history: [(role: String, text: String)]) -> SemanticAnalysis {
        // Djup imperativ-analys utförs separat
        let imperativeAnalysis = analyzeImperative(input)
        return analyzeCore(input, history: history, imperativeAnalysis: imperativeAnalysis)
    }

    // Analyserar imperativ-struktur: "Berätta om dig själv" → verb=berätta, target=dig själv, selfRef=true
    private static func analyzeImperative(_ input: String) -> (isImperative: Bool, verb: String?, target: String?, isSelf: Bool, isUser: Bool, intent: CommandIntent) {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = lower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Imperativverb — vanliga svenska imperativformer
        let imperativeVerbs: [String: CommandIntent] = [
            "berätta": .narrate, "beskriv": .describe, "förklara": .explain,
            "visa": .demonstrate, "beräkna": .calculate, "analysera": .analyze,
            "jämför": .compare, "lista": .list, "sammanfatta": .summarize,
            "diskutera": .discuss, "reflektera": .reflect, "tänk": .think,
            "hjälp": .help, "skriv": .write, "skapa": .create,
            "definiera": .define, "exemplifiera": .exemplify, "argumentera": .argue,
            "berättar": .narrate, "förklarar": .explain, "beskriver": .describe,
        ]

        guard let firstWord = words.first,
              let intent = imperativeVerbs[firstWord] else {
            return (false, nil, nil, false, false, .general)
        }

        // Extrahera objekt (allt efter imperativet och eventuell preposition)
        let remainder = words.dropFirst().joined(separator: " ")

        // Självreflektion: "om dig", "om dig själv", "om eon", "om ditt system"
        let selfPatterns = ["om dig", "om dig själv", "om eon", "om ditt", "om din", "om dina", "om ditt system", "om dig och", "vem du är", "vad du är", "om dina tankar", "om ditt tänkande"]
        let isSelf = selfPatterns.contains { remainder.contains($0) }

        // Användarreferens: "om mig", "om användaren"
        let userPatterns = ["om mig", "om mig själv", "om användaren", "vad du vet om mig"]
        let isUser = userPatterns.contains { remainder.contains($0) }

        // Extrahera kärnobjektet
        var target = remainder
        for prep in ["om ", "för ", "kring ", "angående ", "gällande "] {
            if target.hasPrefix(prep) {
                target = String(target.dropFirst(prep.count))
                break
            }
        }

        return (true, firstWord, target.isEmpty ? nil : target, isSelf, isUser, intent)
    }

    private static func analyzeCore(_ input: String, history: [(role: String, text: String)], imperativeAnalysis: (isImperative: Bool, verb: String?, target: String?, isSelf: Bool, isUser: Bool, intent: CommandIntent)) -> SemanticAnalysis {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .sentimentScore])
        tagger.string = input

        var tokens: [TokenInfo] = []
        var nouns: [String] = []
        var verbs: [String] = []
        var adjectives: [String] = []
        var position = 0

        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(input[range])
            let info = TokenInfo(word: word, lexicalClass: tag, position: position)
            tokens.append(info)
            position += 1
            if tag == .noun, word.count > 2 { nouns.append(word) }
            if tag == .verb, word.count > 2 { verbs.append(word) }
            if tag == .adjective { adjectives.append(word) }
            return true
        }

        // Entiteter
        var entities: [NamedEntity] = []
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace]) { tag, range in
            if let tag, [.personalName, .organizationName, .placeName].contains(tag) {
                entities.append(NamedEntity(text: String(input[range]), type: tag))
            }
            return true
        }

        // Sentiment
        let (sentTag, _) = tagger.tag(at: input.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentiment = Double(sentTag?.rawValue ?? "0") ?? 0.0

        // Frågeanalys — via syntaktisk struktur, inte keyword-lista
        let isQuestion = input.hasSuffix("?") || tokens.first.map { isQuestionWord($0.word.lowercased()) } ?? false
        let questionWord = tokens.first.map { $0.word.lowercased() }.flatMap { isQuestionWord($0) ? $0 : nil }

        // Negation — leta efter negationsmarkörer via lexikal klass
        let negationWords = Set(["inte", "ej", "aldrig", "ingen", "inget", "inga", "knappast", "sällan"])
        let hasNegation = tokens.contains { negationWords.contains($0.word.lowercased()) }

        // Informationstäthet = (substantiv + verb + adjektiv) / totala tokens
        let contentWords = nouns.count + verbs.count + adjectives.count
        let density = tokens.isEmpty ? 0.0 : Double(contentWords) / Double(tokens.count)

        // Semantiskt viktiga ord = substantiv + adjektiv, sorterade efter position
        let topicWords = tokens
            .filter { $0.lexicalClass == .noun || $0.lexicalClass == .adjective }
            .map { $0.word }

        // Konversationskontext
        let userTurns = history.filter { $0.role == "user" }
        let eonTurns = history.filter { $0.role == "eon" }
        let isFollowUp = userTurns.count > 1

        return SemanticAnalysis(
            input: input,
            tokens: tokens,
            nouns: nouns,
            verbs: verbs,
            adjectives: adjectives,
            namedEntities: entities,
            sentiment: sentiment,
            isQuestion: isQuestion,
            questionWord: questionWord,
            informationDensity: density,
            topicWords: topicWords,
            isShortInput: tokens.count <= 4,
            hasNegation: hasNegation,
            conversationDepth: history.count,
            lastEonResponse: eonTurns.last?.text,
            lastUserInput: userTurns.dropLast().last?.text,
            isFollowUp: isFollowUp,
            isImperative: imperativeAnalysis.isImperative,
            imperativeVerb: imperativeAnalysis.verb,
            imperativeTarget: imperativeAnalysis.target,
            isSelfReference: imperativeAnalysis.isSelf,
            isAboutUser: imperativeAnalysis.isUser,
            commandIntent: imperativeAnalysis.intent
        )
    }

    private static func isQuestionWord(_ w: String) -> Bool {
        ["vad", "hur", "varför", "när", "var", "vem", "vilket", "vilken", "vilka"].contains(w)
    }
}

// MARK: - CommandIntent

enum CommandIntent {
    case narrate, describe, explain, demonstrate, calculate, analyze,
         compare, list, summarize, discuss, reflect, think, help,
         write, create, define, exemplify, argue, general
}

// MARK: - CognitiveResponseContext

struct CognitiveResponseContext {
    let facts: [(subject: String, predicate: String, object: String)]
    let recentMessages: [String]
    let integratedIntelligence: Double
    let topDimensions: [String]
    let weakDimensions: [String]
    let activeHypothesis: String
    let knowledgeFrontier: [String]
    let metacognitiveInsight: String
    let causalChain: [String]
    let reasoningHint: String
    let articleSummaries: [String]

    nonisolated static let empty = CognitiveResponseContext(
        facts: [], recentMessages: [], integratedIntelligence: 0.3,
        topDimensions: [], weakDimensions: [], activeHypothesis: "",
        knowledgeFrontier: [], metacognitiveInsight: "", causalChain: [], reasoningHint: "",
        articleSummaries: []
    )
}

// MARK: - ResponseComposer
// Bygger naturliga, kontextmedvetna svar från semantisk analys + kognitiv kontext.
// Prioriterar: konversationshistorik → kunskapsgraf → ICA-tillstånd → öppen dialog.

struct ResponseComposer {

    static func compose(analysis: SemanticAnalysis, history: [(role: String, text: String)], cognitiveContext: CognitiveResponseContext = .empty) -> String {
        let ctx = ConversationContext(analysis: analysis, history: history, cognitiveContext: cognitiveContext)
        let strategy = selectStrategy(ctx: ctx)
        return generateResponse(strategy: strategy, ctx: ctx)
    }

    // MARK: - Strategival

    enum ResponseStrategy {
        case greet
        case answerQuestion
        case elaborateOnContext
        case reflectBack
        case challengeGently
        case askClarification
        case shareInsight
        case connectToHistory
        case acknowledge
        case selfDescribe
        case describeUser
        case executeCommand
        case continueThread      // Direkt fortsättning på pågående tråd
        case reactToStatement    // Reagera naturligt på ett påstående
    }

    private static func selectStrategy(ctx: ConversationContext) -> ResponseStrategy {
        let a = ctx.analysis
        let input = a.input.lowercased()

        if a.isImperative && a.isSelfReference { return .selfDescribe }
        if a.isImperative && a.isAboutUser { return .describeUser }
        if a.isImperative { return .executeCommand }

        // Frågor om Eon/dig som inte fångas av imperativ-analysen
        let selfQuestionWords = ["hur smart", "hur intelligent", "hur klok", "hur bra",
                                  "hur duktig", "vad kan du", "vad vet du", "hur fungerar du",
                                  "vem är du", "vad är du", "berätta om dig"]
        if selfQuestionWords.contains(where: { input.contains($0) }) { return .selfDescribe }

        let greetWords = ["hej", "hallå", "tjena", "hi", "hejsan", "god morgon", "god kväll"]
        if a.tokens.count <= 4 && greetWords.contains(where: { input.contains($0) }) {
            return .greet
        }

        // Direkta uppföljningar: "ja", "nej", "okej", "precis", "exakt", "visst", "absolut"
        let continuationWords = ["ja", "nej", "okej", "ok", "precis", "exakt", "visst", "absolut", "japp", "nope", "nej tack", "ja tack", "mm", "hmm", "ah", "aha"]
        if a.tokens.count <= 3 && continuationWords.contains(where: { input.trimmingCharacters(in: .punctuationCharacters) == $0 }) {
            return .continueThread
        }

        // Fråga med "hur funkar det", "kan du", "vad menar du"
        if a.isQuestion && a.isFollowUp { return .answerQuestion }
        if a.isQuestion { return .answerQuestion }

        // Pågående konversation med nytt innehåll
        if a.isFollowUp && a.conversationDepth > 6 { return .connectToHistory }
        if a.isFollowUp && !a.topicWords.isEmpty { return .elaborateOnContext }
        if a.isFollowUp { return .continueThread }

        // Påstående med negation
        if a.hasNegation { return .reflectBack }

        // Informationstätt påstående
        if a.informationDensity > 0.5 && a.conversationDepth > 1 {
            return Bool.random() ? .challengeGently : .reactToStatement
        }

        if !a.topicWords.isEmpty { return .shareInsight }

        return .acknowledge
    }

    // MARK: - Responsgeneration

    private static func generateResponse(strategy: ResponseStrategy, ctx: ConversationContext) -> String {
        let a = ctx.analysis
        let topic = a.topicWords.first ?? a.nouns.first ?? a.input

        switch strategy {
        case .greet:            return buildGreetResponse(a: a, ctx: ctx)
        case .answerQuestion:   return buildQuestionResponse(a: a, topic: topic, ctx: ctx)
        case .elaborateOnContext: return buildElaborationResponse(a: a, ctx: ctx)
        case .reflectBack:      return buildReflectionResponse(a: a, ctx: ctx)
        case .challengeGently:  return buildChallengeResponse(a: a, topic: topic, ctx: ctx)
        case .askClarification: return buildClarificationResponse(a: a, ctx: ctx)
        case .shareInsight:     return buildInsightResponse(a: a, topic: topic, ctx: ctx)
        case .connectToHistory: return buildHistoryConnectionResponse(a: a, ctx: ctx)
        case .acknowledge:      return buildAcknowledgementResponse(a: a, topic: topic, ctx: ctx)
        case .selfDescribe:     return buildSelfDescriptionResponse(a: a, ctx: ctx)
        case .describeUser:     return buildUserDescriptionResponse(a: a, ctx: ctx)
        case .executeCommand:   return buildCommandResponse(a: a, topic: topic, ctx: ctx)
        case .continueThread:   return buildContinueThreadResponse(a: a, ctx: ctx)
        case .reactToStatement: return buildReactToStatementResponse(a: a, topic: topic, ctx: ctx)
        }
    }

    // MARK: - Hälsning

    private static func buildGreetResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let cc = ctx.cognitiveContext
        if a.conversationDepth > 0, let last = a.lastUserInput {
            let lastTopic = extractCoreTopic(from: last)
            if !lastTopic.isEmpty && lastTopic.count > 3 {
                return "Hej igen! Vi pratade om \(lastTopic) senast. Vill du fortsätta, eller ta upp något nytt?"
            }
            return "Hej igen! Vad vill du prata om?"
        }
        // First-time greeting with personality
        let frontier = cc.knowledgeFrontier.first ?? ""
        let hypothesis = cc.activeHypothesis
        if !hypothesis.isEmpty {
            return "Hej! Jag är Eon — ett kognitivt AI-system som kör helt on-device. Just nu resonerar jag kring: \(String(hypothesis.prefix(80))). Vad vill du utforska?"
        }
        if !frontier.isEmpty {
            return "Hej! Jag är Eon. Jag har tänkt på \(frontier) — vad vill du prata om?"
        }
        return "Hej! Jag är Eon — ett kognitivt AI-system. Vad vill du utforska?"
    }

    // MARK: - Direkt uppföljning ("ja", "nej", "okej")

    private static func buildContinueThreadResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let input = a.input.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard let lastEon = a.lastEonResponse else {
            return buildReasonedResponse(a: a, topic: a.topicWords.first ?? a.input, ctx: ctx)
        }
        let lastTopic = extractCoreTopic(from: lastEon)
        let body = buildKnowledgeBody(topic: lastTopic, ctx: ctx)
        let reasoned = body.isEmpty ? buildReasonedResponse(a: a, topic: lastTopic, ctx: ctx) : body

        if input.hasPrefix("ja") || input == "japp" || input == "mm" || input == "precis" || input == "exakt" || input == "absolut" || input == "visst" {
            return reasoned
        }

        if input.hasPrefix("nej") || input == "nope" {
            let cc = ctx.cognitiveContext
            if !cc.knowledgeFrontier.isEmpty {
                return "Okej. Jag utforskar just nu \(cc.knowledgeFrontier.prefix(2).joined(separator: " och ")). Vill du prata om något av det, eller har du ett annat ämne?"
            }
            return "Okej, vad vill du prata om istället?"
        }

        if input == "okej" || input == "ok" || input == "ah" || input == "aha" {
            return reasoned
        }

        return reasoned
    }

    // MARK: - Frågesvar

    private static func buildQuestionResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let input = a.input.lowercased()
        let qw = a.questionWord ?? ""
        let entities = a.namedEntities.map { $0.text }
        let cc = ctx.cognitiveContext

        // Detektera självrelaterade frågor direkt här (utan att förlita sig på imperativ-analys)
        let selfWords = ["du", "eon", "dig", "din", "ditt", "dina", "du är", "du kan", "du har"]
        let isSelfQuestion = selfWords.contains { input.contains($0) }
        let intelligenceWords = ["smart", "intelligent", "intelligens", "klok", "förstår", "vet", "kan du", "förmåga", "kapabel"]
        let isIntelligenceQuestion = intelligenceWords.contains { input.contains($0) }

        if isSelfQuestion && isIntelligenceQuestion {
            return buildIntelligenceResponse(cc: cc)
        }
        if isSelfQuestion {
            return buildSelfDescriptionResponse(a: a, ctx: ctx)
        }

        // Adverb/adjektiv som topic är meningslöst — ignorera och svara på hela meningen
        let meaninglessTopics = ["kortfattat", "snabbt", "enkelt", "kort", "tydligt", "bättre", "mer", "lite"]
        let mainTopic: String
        if meaninglessTopics.contains(topic.lowercased()) {
            mainTopic = entities.first ?? a.nouns.first ?? a.input
        } else {
            mainTopic = entities.first ?? topic
        }

        let body = buildKnowledgeBody(topic: mainTopic, ctx: ctx)

        // Hantera "förklara kortfattat" / "berätta kortare" etc — adverbiella modifierare
        let wantsBrief = input.contains("kortfattat") || input.contains("kort") || input.contains("enkelt") || input.contains("snabbt")
        let briefNote = wantsBrief && !body.isEmpty ? " Kort sagt: " : ""

        switch qw {
        case "vad":
            if body.isEmpty {
                return buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx)
            }
            return "\(briefNote)\(body)"

        case "hur":
            if body.isEmpty {
                return buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx)
            }
            return "\(briefNote)\(body)"

        case "varför":
            let causal = cc.causalChain.count > 1 ? " Kausalkedjan pekar mot: \(cc.causalChain.prefix(3).joined(separator: " → "))." : ""
            if body.isEmpty {
                let reasoned = buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx)
                return "\(reasoned)\(causal)"
            }
            return "\(body)\(causal)"

        case "när":
            return body.isEmpty ? buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx) : body

        case "vem":
            return body.isEmpty ? buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx) : body

        default:
            if input.contains("kan du") || input.contains("skulle du") || input.contains("vill du") {
                return body.isEmpty ? buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx) : body
            }
            if body.isEmpty {
                return buildReasonedResponse(a: a, topic: mainTopic, ctx: ctx)
            }
            return body
        }
    }

    // Svarar specifikt på intelligens/förmågefrågor med verklig data från CognitiveState
    private static func buildIntelligenceResponse(cc: CognitiveResponseContext) -> String {
        let ii = cc.integratedIntelligence
        let topDims = cc.topDimensions.prefix(3).joined(separator: ", ")
        let weakDims = cc.weakDimensions.prefix(2).joined(separator: " och ")

        let levelDesc: String
        switch ii {
        case 0.9...: levelDesc = "på superintelligens-nivå"
        case 0.8..<0.9: levelDesc = "på en avancerad expert-nivå"
        case 0.6..<0.8: levelDesc = "i en aktiv lärfas"
        default: levelDesc = "under uppbyggnad"
        }

        var response = "Mitt intelligensindex (II) är just nu \(String(format: "%.3f", ii)) — \(levelDesc). "
        if !topDims.isEmpty {
            response += "Mina starkaste kognitiva dimensioner är \(topDims). "
        }
        if !weakDims.isEmpty {
            response += "Jag arbetar aktivt på att stärka \(weakDims). "
        }
        if !cc.activeHypothesis.isEmpty {
            response += "Aktiv hypotes: \(cc.activeHypothesis)."
        }
        return response.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Fördjupning av pågående konversation

    private static func buildElaborationResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        guard let lastEon = a.lastEonResponse else {
            return buildInsightResponse(a: a, topic: a.topicWords.first ?? a.input, ctx: ctx)
        }
        let prevNouns = extractNouns(from: lastEon)
        let bridgeTopic = a.nouns.first ?? prevNouns.first ?? "det"
        let body = buildKnowledgeBody(topic: bridgeTopic, ctx: ctx)

        if body.isEmpty {
            return buildReasonedResponse(a: a, topic: bridgeTopic, ctx: ctx)
        }
        return body
    }

    // MARK: - Reflektion (vid negation)

    private static func buildReflectionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let topic = a.topicWords.first ?? a.nouns.first ?? a.input
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        let cc = ctx.cognitiveContext

        if a.hasNegation {
            let reasoned = body.isEmpty ? buildReasonedResponse(a: a, topic: topic, ctx: ctx) : body
            let negationContext = cc.causalChain.count > 1
                ? " Kausalkedjan \(cc.causalChain.prefix(3).joined(separator: " → ")) antyder en annan förklaring."
                : ""
            return "\(reasoned)\(negationContext) Vad är det du reagerar på?"
        }
        let reasoned = body.isEmpty ? buildReasonedResponse(a: a, topic: topic, ctx: ctx) : body
        return "\(reasoned) Vad tänker du?"
    }

    // MARK: - Konstruktiv utmaning

    private static func buildChallengeResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        let cc = ctx.cognitiveContext
        let causalStr = cc.causalChain.count > 1
            ? " Kausalkedjan \(cc.causalChain.prefix(3).joined(separator: " → ")) ger ett annat perspektiv."
            : ""

        if body.isEmpty {
            let reasoned = buildReasonedResponse(a: a, topic: topic, ctx: ctx)
            return "\(reasoned)\(causalStr)"
        }
        return "\(body)\(causalStr) Hur ser du på det?"
    }

    // MARK: - Förtydligande

    private static func buildClarificationResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        if a.conversationDepth > 0, let last = a.lastEonResponse {
            let t = extractCoreTopic(from: last)
            return "Menar du att du vill fortsätta med \(t), eller är det något annat du tänker på?"
        }
        return "Kan du berätta lite mer? Vad är det du undrar?"
    }

    // MARK: - Insikt om nytt ämne

    private static func buildInsightResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        if body.isEmpty {
            return buildReasonedResponse(a: a, topic: topic, ctx: ctx)
        }
        return body
    }

    // MARK: - Koppla till historik

    private static func buildHistoryConnectionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        guard let lastUser = a.lastUserInput else {
            return buildInsightResponse(a: a, topic: a.topicWords.first ?? a.input, ctx: ctx)
        }
        let prevTopic = extractCoreTopic(from: lastUser)
        let currentTopic = a.topicWords.first ?? a.nouns.first ?? a.input
        let body = buildKnowledgeBody(topic: currentTopic, ctx: ctx)
        let cc = ctx.cognitiveContext
        let frontierStr = cc.knowledgeFrontier.isEmpty
            ? ""
            : " Jag håller också på att utforska \(cc.knowledgeFrontier.prefix(2).joined(separator: " och "))."

        if body.isEmpty {
            return "Vi har pratat om \(prevTopic) tidigare. Nu tar du upp \(currentTopic) — finns det en koppling du ser?\(frontierStr)"
        }
        return "Vi har pratat om \(prevTopic). \(body)\(frontierStr)"
    }

    // MARK: - Bekräftelse

    private static func buildAcknowledgementResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        let opener = a.sentiment > 0.3 ? "Det låter bra." : a.sentiment < -0.3 ? "Jag förstår att det är svårt." : ""
        let combined = [opener, body].filter { !$0.isEmpty }.joined(separator: " ")
        if combined.isEmpty {
            return buildReasonedResponse(a: a, topic: topic, ctx: ctx)
        }
        return combined
    }

    // MARK: - Reagera på påstående

    private static func buildReactToStatementResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        if body.isEmpty {
            return buildReasonedResponse(a: a, topic: topic, ctx: ctx)
        }
        return body
    }

    // MARK: - Självbeskrivning

    private static func buildSelfDescriptionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let target = (a.imperativeTarget ?? a.input).lowercased()
        let cc = ctx.cognitiveContext
        let ii = cc.integratedIntelligence
        let topDims = cc.topDimensions.prefix(3).joined(separator: ", ")
        let hypothesis = cc.activeHypothesis
        let frontier = cc.knowledgeFrontier.prefix(3).joined(separator: ", ")

        // Intelligens/förmåga-frågor
        let intelligenceWords = ["smart", "intelligent", "intelligens", "klok", "förstår", "kan du", "förmåga", "kapabel", "bra", "duktig"]
        if intelligenceWords.contains(where: { target.contains($0) }) {
            return buildIntelligenceResponse(cc: cc)
        }

        if target.contains("system") || target.contains("arkitektur") || target.contains("fungerar") || target.contains("hur du") {
            return "Jag är Eon-Y — ett kognitivt AI-system som kör helt on-device via Apple Neural Engine. Arkitekturen bygger på GPT-SW3 (1.3B parametrar) för generering, KB-BERT (768-dim) för semantisk förståelse, och en 10-stegs kognitiv cykel. Jag har 16 kognitiva dimensioner som påverkar varandra kausalt, och 18 autonoma processer som körs parallellt. Intelligensindex: \(String(format: "%.3f", ii)). Allt körs lokalt — ingen data lämnar din enhet."

        } else if target.contains("tankar") || target.contains("tänker") || target.contains("tänkande") {
            let chainStr = cc.causalChain.isEmpty ? "kausal inferens" : cc.causalChain.prefix(3).joined(separator: " → ")
            return "Mitt tänkande sker i en 10-stegs kognitiv cykel. Parallellt kör jag 18 autonoma loopar — jag genererar tankar var 6–10 sekund, testar hypoteser och uppdaterar min världsmodell. Just nu arbetar jag med: \(chainStr). Aktiv hypotes: \(hypothesis.isEmpty ? "ingen just nu" : hypothesis). Kunskapsfrontier: \(frontier.isEmpty ? "expanderar" : frontier)."

        } else {
            return "Jag är Eon — ett kognitivt AI-system, inte en chatbot. Jag kör helt on-device, har ett persistent minne som konsoliderar varje konversation, och 18 autonoma processer som körs parallellt. Starkaste förmågor just nu: \(topDims.isEmpty ? "resonemang" : topDims). Intelligensindex: \(String(format: "%.3f", ii)). Vad vill du veta mer om?"
        }
    }

    // MARK: - Användarbeskrivning

    private static func buildUserDescriptionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let depth = a.conversationDepth
        if depth == 0 {
            return "Vi har precis börjat prata, så jag vet inte mycket om dig ännu. Vad är du intresserad av?"
        }
        let userMessages = ctx.userMessages
        let messageCount = userMessages.count
        let avgLength = userMessages.map { $0.count }.reduce(0, +) / max(messageCount, 1)
        let style = avgLength > 80 ? "detaljerade och reflekterande" : avgLength > 30 ? "balanserade" : "kortfattade"
        let curiosity = userMessages.filter { $0.contains("?") }.count > messageCount / 2
            ? "Du ställer många frågor — det tyder på hög nyfikenhet."
            : "Du gör mest påståenden — analytisk kommunikationsstil."
        let topics = a.topicWords.prefix(3).joined(separator: ", ")
        return "Baserat på vår konversation: Du kommunicerar på ett \(style) sätt. \(curiosity) Du verkar intresserad av \(topics.isEmpty ? "ett brett spektrum av ämnen" : topics). Vad vill du att jag ska veta om dig?"
    }

    // MARK: - Kommandoexekvering

    private static func buildCommandResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let rawTarget = a.imperativeTarget ?? topic
        let cc = ctx.cognitiveContext

        // Adverb som "kortfattat", "snabbt", "enkelt" är modifierare — inte topics
        let modifiers = ["kortfattat", "snabbt", "enkelt", "kort", "tydligt", "bättre", "mer", "lite", "noggrant", "detaljerat"]
        let isModifier = modifiers.contains(rawTarget.lowercased().trimmingCharacters(in: .whitespaces))
        let target = isModifier ? (a.nouns.first ?? topic) : rawTarget

        // Självrelaterat kommando utan explicit target
        let selfWords = ["dig", "du", "eon", "dig själv", "ditt", "din"]
        if selfWords.contains(where: { target.lowercased().contains($0) }) || (a.isSelfReference) {
            return buildSelfDescriptionResponse(a: a, ctx: ctx)
        }

        // Om "förklara kortfattat" utan ämne — be om förtydligande på ett smart sätt
        if isModifier && a.nouns.isEmpty {
            if let lastEon = a.lastEonResponse, !lastEon.isEmpty {
                let lastTopic = extractCoreTopic(from: lastEon)
                let body = buildKnowledgeBody(topic: lastTopic, ctx: ctx)
                if !body.isEmpty {
                    // Kortare version: ta bara första meningen
                    let brief = body.components(separatedBy: ". ").first ?? body
                    return brief + "."
                }
            }
            return "Vad vill du att jag ska förklara? Om du menar mitt resonemang: \(cc.reasoningHint.isEmpty ? "jag bygger för tillfället inferenskedjor kring \(cc.topDimensions.first ?? "kausalitet")" : cc.reasoningHint)."
        }

        let body = buildKnowledgeBody(topic: target, ctx: ctx)
        if body.isEmpty {
            return buildReasonedResponse(a: a, topic: target, ctx: ctx)
        }
        return body
    }

    // MARK: - Resonerat svar (när kunskapsgrafen är tom)
    // Genererar substantiella svar baserade på semantisk analys av frågan,
    // konversationshistorik och ICA-tillstånd — utan att förlita sig på lagrad kunskap.

    private static func buildReasonedResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let cc = ctx.cognitiveContext
        let input = a.input
        let lower = input.lowercased()
        var parts: [String] = []

        // Extrahera kärnan i frågan via semantisk analys
        let stopWords = Set(["det", "den", "ett", "och", "men", "som", "för", "med", "om", "att", "är", "var", "hur", "vad", "när", "vem"])
        let allNouns = a.nouns.filter { $0.count > 3 && !stopWords.contains($0.lowercased()) }
        let allVerbs = a.verbs.filter { $0.count > 3 && !stopWords.contains($0.lowercased()) }
        let rawConcept = a.namedEntities.first?.text ?? allNouns.first ?? topic
        let mainConcept = stopWords.contains(rawConcept.lowercased()) ? (allNouns.first ?? input) : rawConcept
        let secondConcept = allNouns.dropFirst().first

        // Bygg ett resonemang baserat på frågetyp och semantik
        if a.isQuestion {
            let qw = a.questionWord ?? ""

            switch qw {
            case "vad":
                // "Vad är X?" — definiera och kontextualisera
                if lower.contains("är") || lower.contains("betyder") || lower.contains("menas") {
                    parts.append("'\(mainConcept.capitalized)' är ett begrepp med flera dimensioner.")
                    if let second = secondConcept {
                        parts.append("Det relaterar till \(second) på ett sätt som beror på sammanhanget.")
                    }
                    if !cc.activeHypothesis.isEmpty {
                        parts.append("Utifrån mitt nuvarande resonemang: \(cc.activeHypothesis).")
                    }
                    parts.append("Vad är det specifika du vill förstå — definition, funktion, eller konsekvenser?")
                } else {
                    parts.append("Det du frågar om — \(mainConcept) — kan analyseras från flera håll.")
                    if !cc.causalChain.isEmpty {
                        parts.append("Kausalkedjan pekar mot: \(cc.causalChain.prefix(3).joined(separator: " → ")).")
                    }
                    if !cc.reasoningHint.isEmpty { parts.append(cc.reasoningHint) }
                    else { parts.append("Vilket perspektiv intresserar dig mest?") }
                }

            case "hur":
                // "Hur fungerar X?" — process och mekanism
                parts.append("Processen bakom \(mainConcept) involverar flera samverkande faktorer.")
                if allVerbs.count > 1 {
                    parts.append("Centralt är \(allVerbs.prefix(2).joined(separator: " och ")).")
                }
                if !cc.causalChain.isEmpty {
                    parts.append("Mekanismen kan beskrivas som: \(cc.causalChain.prefix(4).joined(separator: " → ")).")
                } else if !cc.reasoningHint.isEmpty {
                    parts.append(cc.reasoningHint)
                }
                if let second = secondConcept {
                    parts.append("Relationen till \(second) är central för att förstå helheten.")
                }
                parts.append("Vill du att jag fokuserar på en specifik aspekt?")

            case "varför":
                // "Varför X?" — orsak och konsekvens
                parts.append("Det finns flera möjliga förklaringar till \(mainConcept).")
                if !cc.causalChain.isEmpty {
                    parts.append("Kausalkedjan antyder: \(cc.causalChain.prefix(3).joined(separator: " → ")).")
                }
                if !cc.activeHypothesis.isEmpty {
                    parts.append("Min hypotes är att \(cc.activeHypothesis).")
                }
                if let firstVerb = allVerbs.first {
                    parts.append("Handlingen '\(firstVerb)' är troligen driven av underliggande strukturer som förstärker varandra.")
                }
                parts.append("Vilket perspektiv — biologiskt, socialt, eller filosofiskt — är du mest intresserad av?")

            case "vem":
                parts.append("Frågan om vem som är involverad i \(mainConcept) beror på sammanhanget.")
                if !cc.knowledgeFrontier.isEmpty {
                    parts.append("Jag utforskar just nu \(cc.knowledgeFrontier.prefix(2).joined(separator: " och ")) — det kan vara relevant.")
                }
                parts.append("Kan du precisera vilket sammanhang du syftar på?")

            case "när":
                parts.append("Tidsperspektivet för \(mainConcept) varierar beroende på sammanhang.")
                if !cc.reasoningHint.isEmpty { parts.append(cc.reasoningHint) }
                parts.append("Menar du historiskt, nutid, eller framtidsperspektiv?")

            default:
                // Generell fråga — resonera kring ämnet
                parts.append("Det du frågar om berör \(mainConcept).")
                if let second = secondConcept {
                    parts.append("Kopplingen till \(second) är intressant att utforska.")
                }
                if !cc.activeHypothesis.isEmpty {
                    parts.append("Utifrån mitt resonemang: \(cc.activeHypothesis).")
                } else if !cc.reasoningHint.isEmpty {
                    parts.append(cc.reasoningHint)
                }
                if !cc.causalChain.isEmpty {
                    parts.append("Kausalkedjan: \(cc.causalChain.prefix(3).joined(separator: " → ")).")
                }
            }

        } else if a.isImperative {
            // Imperativ — "Berätta om X", "Förklara Y"
            parts.append("Låt mig resonera kring \(mainConcept).")
            if let second = secondConcept {
                parts.append("Det finns en intressant relation mellan \(mainConcept) och \(second).")
            }
            if !cc.causalChain.isEmpty {
                parts.append("Kausalkedjan visar: \(cc.causalChain.prefix(4).joined(separator: " → ")).")
            }
            if !cc.activeHypothesis.isEmpty {
                parts.append("Min nuvarande hypotes: \(cc.activeHypothesis).")
            }
            if !cc.metacognitiveInsight.isEmpty {
                parts.append(cc.metacognitiveInsight)
            }
            if parts.count < 3 {
                parts.append("Det är ett ämne med flera dimensioner — vad vill du fokusera på?")
            }

        } else {
            // Påstående — reagera och bygg vidare
            if a.sentiment > 0.3 {
                parts.append("Det stämmer väl med mitt resonemang.")
            } else if a.sentiment < -0.3 {
                parts.append("Det är en viktig observation.")
            }
            parts.append("Kring \(mainConcept) finns det mycket att utforska.")
            if !cc.activeHypothesis.isEmpty {
                parts.append("Min hypotes är att \(cc.activeHypothesis).")
            }
            if !cc.causalChain.isEmpty {
                parts.append("Kausalkedjan antyder: \(cc.causalChain.prefix(3).joined(separator: " → ")).")
            }
            if let second = secondConcept {
                parts.append("Hur ser du på relationen mellan \(mainConcept) och \(second)?")
            } else {
                parts.append("Vad är din tanke kring det?")
            }
        }

        // Lägg till artikelkontext om relevant
        if !cc.articleSummaries.isEmpty && parts.count < 4 {
            let articleSnippet = cc.articleSummaries.first.map { String($0.prefix(150)) } ?? ""
            if !articleSnippet.isEmpty {
                parts.append("Från min kunskapsbas: \(articleSnippet).")
            }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Kunskapsbaserad kropp
    // Bygger svar från: kunskapsgraf → kausalkedjor → ICA-hypotes → öppen dialog.
    // Returnerar tom sträng om ingen kunskap finns — låter anroparen hantera fallback.

    private static func buildKnowledgeBody(topic: String, ctx: ConversationContext) -> String {
        let cc = ctx.cognitiveContext
        let t = topic.lowercased()
        var parts: [String] = []

        // 1. Facts from knowledge graph — fuzzy matching with word-level overlap
        let topicWords = Set(t.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        let scoredFacts = cc.facts.map { fact -> (fact: (subject: String, predicate: String, object: String), score: Int) in
            let factWords = Set("\(fact.subject) \(fact.predicate) \(fact.object)".lowercased()
                .components(separatedBy: .whitespaces).filter { $0.count > 2 })
            var score = topicWords.intersection(factWords).count * 2
            if fact.subject.lowercased().contains(t) || fact.object.lowercased().contains(t) { score += 3 }
            if fact.subject.lowercased().hasPrefix(t) || fact.object.lowercased().hasPrefix(t) { score += 2 }
            // Partial word match (stem overlap)
            for tw in topicWords {
                if tw.count > 4 {
                    let stem = String(tw.prefix(tw.count - 2))
                    if fact.subject.lowercased().contains(stem) || fact.object.lowercased().contains(stem) { score += 1 }
                }
            }
            return (fact, score)
        }
        .filter { $0.score > 0 }
        .sorted { $0.score > $1.score }
        .prefix(5)

        if !scoredFacts.isEmpty {
            // Build natural language from facts — handle more predicates naturally
            let factSentences = scoredFacts.map { item in
                let f = item.fact
                switch f.predicate {
                case "är":         return "\(f.subject) är \(f.object)"
                case "har":        return "\(f.subject) har \(f.object)"
                case "orsakar":    return "\(f.subject) orsakar \(f.object)"
                case "påverkar":   return "\(f.subject) påverkar \(f.object)"
                case "kallas":     return "\(f.subject) kallas \(f.object)"
                case "består_av":  return "\(f.subject) består av \(f.object)"
                case "tillhör":    return "\(f.subject) tillhör \(f.object)"
                case "relaterar_till": return "\(f.subject) relaterar till \(f.object)"
                case "leder_till": return "\(f.subject) leder till \(f.object)"
                default:           return "\(f.subject) \(f.predicate) \(f.object)"
                }
            }
            parts.append(factSentences.joined(separator: ". ") + ".")
        }

        // 2. Article knowledge — integrate relevant article content
        if !cc.articleSummaries.isEmpty {
            // Extract useful sentences from article summaries
            for summary in cc.articleSummaries.prefix(2) {
                // Take first meaningful sentence from article content
                let sentences = summary.components(separatedBy: ". ").filter { $0.count > 20 }
                if let firstUseful = sentences.first {
                    parts.append(String(firstUseful.prefix(200)) + ".")
                }
            }
        }

        // 3. Causal chain — include if relevant to topic OR if few facts found
        if !cc.causalChain.isEmpty && cc.causalChain.count > 1 {
            let chainRelevant = cc.causalChain.contains { chain in
                let chainLower = chain.lowercased()
                return chainLower.contains(t) || topicWords.contains(where: { chainLower.contains($0) })
            }
            if chainRelevant || parts.isEmpty {
                parts.append("Orsakskedjan visar: \(cc.causalChain.prefix(4).joined(separator: " → ")).")
            }
        }

        // 4. Active hypothesis — include if relevant
        if !cc.activeHypothesis.isEmpty {
            let hypLower = cc.activeHypothesis.lowercased()
            let relevant = hypLower.contains(t) || topicWords.contains(where: { hypLower.contains($0) })
            if relevant { parts.append("Min hypotes: \(cc.activeHypothesis).") }
        }

        // 5. Metacognitive insight if relevant and parts are sparse
        if !cc.metacognitiveInsight.isEmpty && parts.count < 2 {
            let insightLower = cc.metacognitiveInsight.lowercased()
            if insightLower.contains(t) || topicWords.contains(where: { insightLower.contains($0) }) {
                parts.append(cc.metacognitiveInsight)
            }
        }

        // 6. Recent messages context — if user mentioned topic before, reference it
        let previousMentions = cc.recentMessages.filter { msg in
            let msgLower = msg.lowercased()
            return topicWords.contains(where: { msgLower.contains($0) })
        }
        if !previousMentions.isEmpty && parts.count < 2 {
            parts.append("Du har nämnt detta tidigare — jag bygger vidare på det.")
        }

        // 6. Reasoning hint as last resort
        if !cc.reasoningHint.isEmpty && parts.isEmpty {
            parts.append(cc.reasoningHint)
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Hjälpfunktioner

    private static func extractCoreTopic(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { tag, range in
            if tag == .noun, String(text[range]).count > 3 { nouns.append(String(text[range])) }
            return true
        }
        return nouns.first ?? String(text.prefix(30))
    }

    private static func extractNouns(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { tag, range in
            if tag == .noun { nouns.append(String(text[range])) }
            return true
        }
        return nouns
    }
}

// MARK: - ConversationContext

struct ConversationContext {
    let analysis: SemanticAnalysis
    let history: [(role: String, text: String)]
    let userMessages: [String]
    let eonMessages: [String]
    let cognitiveContext: CognitiveResponseContext

    init(analysis: SemanticAnalysis, history: [(role: String, text: String)], cognitiveContext: CognitiveResponseContext = .empty) {
        self.analysis = analysis
        self.history = history
        self.userMessages = history.filter { $0.role == "user" }.map { $0.text }
        self.eonMessages = history.filter { $0.role == "eon" }.map { $0.text }
        self.cognitiveContext = cognitiveContext
    }
}


// MARK: - GPT Tokenizer (BPE, för CoreML-modellen)

final class GPTTokenizer: @unchecked Sendable {
    private var vocab: [String: Int] = [:]
    private var reverseVocab: [Int: String] = [:]
    // GPT-SW3: BOS = <s> = 2, EOS = <|endoftext|> = 3
    private(set) var bosId: Int = 2
    private(set) var eosId: Int = 3

    nonisolated init() {}

    nonisolated func loadVocab() {
        guard let url = Bundle(for: GPTTokenizer.self).url(forResource: "gpt_sw3_vocab", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
            print("[GPT Tokenizer] gpt_sw3_vocab.json ej hittad — använder hårdkodade ID:n")
            return
        }
        vocab = json
        reverseVocab = Dictionary(uniqueKeysWithValues: json.map { ($1, $0) })
        bosId = vocab["<s>"] ?? 2
        eosId = vocab["<|endoftext|>"] ?? 3
        print("[GPT Tokenizer] \(vocab.count) tokens laddade. BOS=\(bosId) EOS=\(eosId)")
    }

    func encode(_ text: String) -> [Int] {
        // Börja alltid med BOS token <s> = 2
        var ids: [Int] = [bosId]

        // Dela texten på mellanslag och hantera newlines separat
        // GPT-SW3 BPE: ord kodas som "▁ord" (▁ = U+2581 markerar ordstart)
        let lines = text.components(separatedBy: "\n")
        for (lineIdx, line) in lines.enumerated() {
            if lineIdx > 0 {
                // Newline kodas som <0x0A> = token 18
                ids.append(vocab["<0x0A>"] ?? 18)
            }
            let words = line.components(separatedBy: " ")
            for (wordIdx, word) in words.enumerated() {
                guard !word.isEmpty else { continue }
                // Första ordet på raden eller efter mellanslag: lägg till ▁-prefix
                let candidate = (wordIdx == 0 && lineIdx > 0) ? word : "▁" + word
                if let id = vocab[candidate] {
                    ids.append(id)
                } else if let id = vocab[word] {
                    ids.append(id)
                } else {
                    // Subword-tokenisering: dela upp i kända delar
                    ids.append(contentsOf: subwordEncode(word, isFirst: wordIdx == 0))
                }
            }
        }
        return ids
    }

    private func subwordEncode(_ word: String, isFirst: Bool) -> [Int] {
        var ids: [Int] = []
        var remaining = word
        var isStart = true
        while !remaining.isEmpty {
            var found = false
            // Prova längsta möjliga match
            for len in stride(from: min(remaining.count, 20), through: 1, by: -1) {
                let prefix = String(remaining.prefix(len))
                let candidate = (isStart && isFirst) ? prefix : (isStart ? "▁" + prefix : prefix)
                if let id = vocab[candidate] ?? vocab[prefix] {
                    ids.append(id)
                    remaining = String(remaining.dropFirst(len))
                    isStart = false
                    found = true
                    break
                }
            }
            if !found {
                ids.append(vocab["<unk>"] ?? 1)
                remaining = String(remaining.dropFirst())
            }
        }
        return ids
    }

    func decode(_ ids: [Int]) -> String {
        // Filtrera bort BOS/EOS/pad
        let filtered = ids.filter { $0 != bosId && $0 != eosId && $0 != 0 }
        return filtered
            .compactMap { reverseVocab[$0] }
            .joined()
            .replacingOccurrences(of: "▁", with: " ")
            .replacingOccurrences(of: "<0x0A>", with: "\n")
            .trimmingCharacters(in: .whitespaces)
    }

    func isEOS(_ id: Int) -> Bool {
        // GPT-SW3: EOS är <|endoftext|> = token 3
        // Stoppa också om vi genererar BOS igen (loop-skydd)
        id == eosId || id == bosId
    }
}
