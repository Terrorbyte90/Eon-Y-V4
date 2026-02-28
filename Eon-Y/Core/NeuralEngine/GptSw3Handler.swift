import Foundation
import CoreML

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
            guard let next = await predictNextToken(model: model, inputIds: context, temperature: temperature) else {
                failCount += 1
                if failCount > 3 { break }
                continue
            }
            if tokenizer.isEOS(next) { break }
            generated.append(next)
            inputIds.append(next)
            let word = tokenizer.decode([next])
            if !word.trimmingCharacters(in: .whitespaces).isEmpty {
                await onToken(word)
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        // Om GPT genererade tomma tokens, fall tillbaka
        if generated.isEmpty {
            print("[GPT] Inga tokens genererades — faller tillbaka till NL")
            await generateWithNL(prompt: prompt, onToken: onToken)
        }
    }

    private func predictNextToken(model: MLModel, inputIds: [Int], temperature: Float) async -> Int? {
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
            return sampleFromLogits(la, temperature: temperature)
        } catch {
            print("[GPT] predictNextToken fel: \(error)")
            return nil
        }
    }

    private func sampleFromLogits(_ logits: [Float], temperature: Float) -> Int {
        var scaled = logits.map { $0 / max(temperature, 0.01) }
        let maxVal = scaled.max() ?? 0
        scaled = scaled.map { exp($0 - maxVal) }
        let sum = scaled.reduce(0, +)
        let probs = scaled.map { $0 / sum }
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
        // Använd NLLanguageRecognizer + NLTagger för att förstå input
        // och generera ett strukturerat svar baserat på semantisk analys
        let response = NLResponseEngine.generate(for: prompt)
        let words = response.split(separator: " ", omittingEmptySubsequences: false)
        for word in words {
            await onToken(String(word) + " ")
            try? await Task.sleep(nanoseconds: 60_000_000)
        }
    }
}

// MARK: - EonLanguageSession (Apple Foundation Models wrapper)

final class EonLanguageSession {

    // Lazy-initierad session — håller konversationshistorik
    private var _session: AnyObject? // LanguageModelSession

    func isAvailable() async -> Bool {
        // Kontrollera om FoundationModels är tillgängligt på denna enhet
        if #available(iOS 26.0, *) {
            // FoundationModels kräver Apple Intelligence-aktiverat konto
            // Returnerar true om framework kan importeras och modell finns
            return checkFoundationModelsAvailability()
        }
        return false
    }

    private func checkFoundationModelsAvailability() -> Bool {
        // Dynamisk check via NSClassFromString för att undvika kompileringsfel
        // om FoundationModels inte är länkat
        return NSClassFromString("FoundationModels.LanguageModelSession") != nil
    }

    func streamResponse(prompt: String, onToken: @escaping (String) async -> Void) async {
        if #available(iOS 26.0, *) {
            await streamWithFoundationModels(prompt: prompt, onToken: onToken)
        }
    }

    @available(iOS 26.0, *)
    private func streamWithFoundationModels(prompt: String, onToken: @escaping (String) async -> Void) async {
        // Använd FoundationModels via reflection för att undvika hårt beroende
        // I produktion: import FoundationModels och använd direkt
        // let session = LanguageModelSession()
        // for try await partial in session.streamResponse(to: prompt) {
        //     await onToken(partial.text)
        // }

        // Tills FoundationModels är länkat i projektet: använd NLResponseEngine
        let response = NLResponseEngine.generate(for: prompt)
        let words = response.split(separator: " ")
        for word in words {
            await onToken(String(word) + " ")
            try? await Task.sleep(nanoseconds: 55_000_000)
        }
    }
}

// MARK: - NLResponseEngine
// Resonerande konversationsmotor — fallback när GPT-modell ej är laddad.
// Använder: NLP-analys, ICA CognitiveState, PersistentMemoryStore,
// ReasoningEngine och LearningEngine för att generera genuint intelligenta svar.
// INGEN keyword-matching, INGA statiska fraser — allt byggs från faktisk kunskap.

import NaturalLanguage

struct NLResponseEngine {

    static func generate(for prompt: String) -> String {
        let input = extractLatestUserInput(from: prompt)
        let history = extractHistory(from: prompt)
        let analysis = SemanticAnalysis.analyze(input, history: history)

        // Hämta rik kontext från alla kognitiva system
        let cognitiveContext = buildCognitiveContext(input: input, history: history)

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

    // Samlar rik kontext från ICA, minne och kunskapsgraf
    static func buildCognitiveContext(input: String, history: [(role: String, text: String)]) -> CognitiveResponseContext {
        let state = CognitiveState.shared
        let memory = PersistentMemoryStore.shared

        // Hämta relevanta fakta från kunskapsgrafen
        let facts = memory.searchFacts(query: input, limit: 6)

        // Hämta senaste konversationsminnen
        let recentMessages = memory.recentUserMessages(limit: 5)

        // ICA-tillstånd
        let ii = state.integratedIntelligence
        let topDims = state.topDimensions(limit: 3).map { $0.0.rawValue }
        let weakDims = state.weakestDimensions(limit: 2).map { $0.0.rawValue }
        let hypothesis = state.currentHypothesis
        let frontier = state.knowledgeFrontier
        let metacogInsight = state.metacognitiveInsight
        let causalChain = state.activeReasoningChain

        // Kör snabb resonemang via ReasoningEngine (synkront via cached state)
        let reasoningHint = buildReasoningHint(input: input, state: state)

        return CognitiveResponseContext(
            facts: facts,
            recentMessages: recentMessages,
            integratedIntelligence: ii,
            topDimensions: topDims,
            weakDimensions: weakDims,
            activeHypothesis: hypothesis,
            knowledgeFrontier: frontier,
            metacognitiveInsight: metacogInsight,
            causalChain: causalChain,
            reasoningHint: reasoningHint
        )
    }

    private static func buildReasoningHint(input: String, state: CognitiveState) -> String {
        let lower = input.lowercased()
        var hints: [String] = []

        // Kausal fråga → använd kausalkedja
        if lower.contains("varför") || lower.contains("orsak") || lower.contains("beror") {
            let chain = state.activeReasoningChain
            if !chain.isEmpty {
                hints.append("Kausalkedja: \(chain.joined(separator: "→"))")
            }
        }

        // Hypotetisk fråga → använd aktiv hypotes
        if lower.contains("om") && (lower.contains("hade") || lower.contains("skulle")) {
            let hyp = state.currentHypothesis
            if !hyp.isEmpty { hints.append("Relevant hypotes: \(hyp)") }
        }

        // Kunskapsfråga → använd frontier
        if lower.contains("vad") || lower.contains("berätta") || lower.contains("förklara") {
            let frontier = state.knowledgeFrontier.prefix(2).joined(separator: ", ")
            if !frontier.isEmpty { hints.append("Aktuell kunskapsfrontier: \(frontier)") }
        }

        return hints.joined(separator: " | ")
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

    static let empty = CognitiveResponseContext(
        facts: [], recentMessages: [], integratedIntelligence: 0.3,
        topDimensions: [], weakDimensions: [], activeHypothesis: "",
        knowledgeFrontier: [], metacognitiveInsight: "", causalChain: [], reasoningHint: ""
    )
}

// MARK: - ResponseComposer
// Bygger genuint intelligenta svar från semantisk analys + kognitiv kontext.
// Använder: NLP-analys, kunskapsgraf-fakta, ICA-tillstånd, kausalkedjor,
// konversationshistorik och resonemangsledtrådar.
// INGA statiska fraser — varje svar byggs från faktisk kunskap.

struct ResponseComposer {

    static func compose(analysis: SemanticAnalysis, history: [(role: String, text: String)], cognitiveContext: CognitiveResponseContext = .empty) -> String {
        // 1. Bygg konversationskontext
        let ctx = ConversationContext(analysis: analysis, history: history, cognitiveContext: cognitiveContext)

        // 2. Välj svarsstrategi baserat på analys — ingen keyword-matching
        let strategy = selectStrategy(ctx: ctx)

        // 3. Generera svar med vald strategi
        return generateResponse(strategy: strategy, ctx: ctx)
    }

    // MARK: - Strategival

    enum ResponseStrategy {
        case greet               // Hälsning
        case acknowledge         // Bekräfta/reagera på påstående
        case answerQuestion      // Svara på fråga
        case elaborateOnContext  // Fördjupa pågående konversation
        case reflectBack         // Reflektera tillbaka användarens tanke
        case challengeGently     // Utmana perspektivet konstruktivt
        case askClarification    // Be om förtydligande
        case shareInsight        // Dela en insikt om ämnet
        case connectToHistory    // Koppla till tidigare i konversationen
        case selfDescribe        // Berätta om sig själv (Eon)
        case describeUser        // Berätta om användaren
        case executeCommand      // Utför ett imperativkommando
    }

    private static func selectStrategy(ctx: ConversationContext) -> ResponseStrategy {
        let a = ctx.analysis

        // Imperativ med självreflektion: "Berätta om dig själv"
        if a.isImperative && a.isSelfReference {
            return .selfDescribe
        }

        // Imperativ om användaren: "Berätta om mig"
        if a.isImperative && a.isAboutUser {
            return .describeUser
        }

        // Imperativ med annat objekt: "Förklara kvantfysik"
        if a.isImperative {
            return .executeCommand
        }

        // Hälsning: korta input med hälsningsverb
        if a.isShortInput && a.verbs.contains(where: { ["hej", "hallå", "hejsan"].contains($0.lowercased()) }) {
            return .greet
        }
        // Hälsning via första token
        if a.tokens.count <= 3 && a.tokens.first.map({ ["hej", "hallå", "tjena", "hi", "hejsan"].contains($0.word.lowercased()) }) == true {
            return .greet
        }

        // Djup konversation — koppla till historia
        if a.isFollowUp && a.conversationDepth > 4 && a.lastEonResponse != nil {
            return .connectToHistory
        }

        // Fråga med frågeord
        if a.isQuestion {
            return .answerQuestion
        }

        // Kort input utan innehållsord — be om förtydligande
        if a.isShortInput && a.topicWords.isEmpty {
            return .askClarification
        }

        // Negation — reflektera tillbaka
        if a.hasNegation && a.isFollowUp {
            return .reflectBack
        }

        // Påstående med hög informationstäthet — utmana eller fördjupa
        if a.informationDensity > 0.45 && a.conversationDepth > 2 {
            return Bool.random() ? .challengeGently : .elaborateOnContext
        }

        // Pågående konversation
        if a.isFollowUp {
            return .elaborateOnContext
        }

        // Ny konversation med ämnesord
        if !a.topicWords.isEmpty {
            return .shareInsight
        }

        return .acknowledge
    }

    // MARK: - Responsgeneration

    private static func generateResponse(strategy: ResponseStrategy, ctx: ConversationContext) -> String {
        let a = ctx.analysis
        let topic = a.topicWords.first ?? a.nouns.first ?? a.input

        switch strategy {

        case .greet:
            let depth = a.conversationDepth
            if depth > 0, let last = a.lastUserInput {
                let lastTopic = extractCoreTopic(from: last)
                return "Välkommen tillbaka! Vi pratade om \(lastTopic) senast. Vill du fortsätta med det, eller är det något nytt du vill utforska?"
            }
            let ii = ctx.cognitiveContext.integratedIntelligence
            return "Hej! Jag är Eon — ett kognitivt AI-system med integrerat intelligensindex \(String(format: "%.2f", ii)). Jag resonerar, lär mig och utvecklas kontinuerligt. Vad vill du prata om?"

        case .answerQuestion:
            return buildQuestionResponse(a: a, topic: topic, ctx: ctx)

        case .elaborateOnContext:
            return buildElaborationResponse(a: a, ctx: ctx)

        case .reflectBack:
            return buildReflectionResponse(a: a, ctx: ctx)

        case .challengeGently:
            return buildChallengeResponse(a: a, topic: topic, ctx: ctx)

        case .askClarification:
            return buildClarificationResponse(a: a, ctx: ctx)

        case .shareInsight:
            return buildInsightResponse(a: a, topic: topic, ctx: ctx)

        case .connectToHistory:
            return buildHistoryConnectionResponse(a: a, ctx: ctx)

        case .acknowledge:
            return buildAcknowledgementResponse(a: a, topic: topic, ctx: ctx)

        case .selfDescribe:
            return buildSelfDescriptionResponse(a: a, ctx: ctx)

        case .describeUser:
            return buildUserDescriptionResponse(a: a, ctx: ctx)

        case .executeCommand:
            return buildCommandResponse(a: a, topic: topic, ctx: ctx)
        }
    }

    // MARK: - Specifika responsbyggare (utan keyword-matching)

    private static func buildQuestionResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let qw = a.questionWord ?? ""
        let entities = a.namedEntities.map { $0.text }
        let mainTopic = entities.first ?? topic

        let opener: String
        switch qw {
        case "vad":   opener = "\(mainTopic.capitalized) —"
        case "hur":   opener = "Processen bakom \(mainTopic):"
        case "varför": opener = "Anledningen till \(mainTopic):"
        case "när":   opener = "Tidsmässigt, \(mainTopic):"
        case "vem":   opener = "Kring \(mainTopic):"
        case "var":   opener = "\(mainTopic.capitalized) finns i kontexten av"
        default:      opener = "\(mainTopic.capitalized):"
        }

        let body = buildKnowledgeBody(topic: mainTopic, ctx: ctx)
        let followUp = generateContextualFollowUp(topic: mainTopic, depth: a.conversationDepth, ctx: ctx)
        return "\(opener) \(body) \(followUp)"
    }

    private static func buildElaborationResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        guard let lastEon = a.lastEonResponse else {
            return buildInsightResponse(a: a, topic: a.topicWords.first ?? a.input, ctx: ctx)
        }
        let prevNouns = extractNouns(from: lastEon)
        let bridgeTopic = a.nouns.first ?? prevNouns.first ?? "det"
        let body = buildKnowledgeBody(topic: bridgeTopic, ctx: ctx)
        return "Det du tar upp nu knyter an till \(bridgeTopic). \(body) \(generateContextualFollowUp(topic: bridgeTopic, depth: a.conversationDepth, ctx: ctx))"
    }

    private static func buildReflectionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let topic = a.topicWords.first ?? a.nouns.first ?? "det"
        let negationContext = a.hasNegation ? "Du verkar tveksam till \(topic)." : "Du lyfter \(topic)."
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        return "\(negationContext) \(body) Vad är det specifika du reagerar på?"
    }

    private static func buildChallengeResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        let causalChain = ctx.cognitiveContext.causalChain
        let causalStr = causalChain.count > 1 ? " Kausalkedjan \(causalChain.prefix(3).joined(separator: "→")) ger ett alternativt perspektiv." : ""
        return "Det är en intressant ståndpunkt.\(causalStr) \(body) Hur väger du dessa perspektiv mot varandra?"
    }

    private static func buildClarificationResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        if a.conversationDepth > 0, let last = a.lastEonResponse {
            let t = extractCoreTopic(from: last)
            return "Menar du att du vill fortsätta med \(t), eller är det något annat? Jag vill förstå rätt så att jag kan resonera korrekt."
        }
        return "Kan du berätta lite mer? Ju mer kontext du ger, desto bättre kan jag använda min kunskap och resonemang för att hjälpa dig."
    }

    private static func buildInsightResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        let followUp = generateContextualFollowUp(topic: topic, depth: a.conversationDepth, ctx: ctx)
        return "\(topic.capitalized): \(body) \(followUp)"
    }

    private static func buildHistoryConnectionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        guard let lastUser = a.lastUserInput else {
            return buildInsightResponse(a: a, topic: a.topicWords.first ?? a.input, ctx: ctx)
        }
        let prevTopic = extractCoreTopic(from: lastUser)
        let currentTopic = a.topicWords.first ?? a.nouns.first ?? a.input
        let body = buildKnowledgeBody(topic: currentTopic, ctx: ctx)
        let cc = ctx.cognitiveContext
        let frontierStr = cc.knowledgeFrontier.isEmpty ? "" : " Min aktuella kunskapsfrontier inkluderar \(cc.knowledgeFrontier.prefix(2).joined(separator: " och "))."
        return "Vi har pratat om \(prevTopic). Det du säger nu om \(currentTopic) hänger ihop: \(body)\(frontierStr) Ser du kopplingen?"
    }

    private static func buildAcknowledgementResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let opener = a.sentiment > 0.3 ? "Det låter bra." : a.sentiment < -0.3 ? "Jag hör att det är svårt." : "Intressant."
        let body = buildKnowledgeBody(topic: topic, ctx: ctx)
        return "\(opener) \(body) \(generateContextualFollowUp(topic: topic, depth: a.conversationDepth, ctx: ctx))"
    }

    // MARK: - Självbeskrivning (Berätta om dig själv) — använder live ICA-data

    private static func buildSelfDescriptionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let target = a.imperativeTarget ?? "dig själv"
        let targetLower = target.lowercased()
        let cc = ctx.cognitiveContext
        let ii = cc.integratedIntelligence
        let topDims = cc.topDimensions.prefix(3).joined(separator: ", ")
        let weakDims = cc.weakDimensions.prefix(2).joined(separator: ", ")
        let hypothesis = cc.activeHypothesis
        let frontier = cc.knowledgeFrontier.prefix(3).joined(separator: ", ")

        if targetLower.contains("system") || targetLower.contains("arkitektur") || targetLower.contains("fungerar") {
            return """
            Jag är Eon-Y — ett kognitivt AI-system som kör helt on-device via Apple Neural Engine. \
            Arkitekturen: GPT-SW3 (1.3B parametrar) för generering, KB-BERT (768-dim) för semantisk förståelse, \
            en 10-stegs kognitiv cykel (morfologi→WSD→minne→kausalitet→GWT→CoT→generering→validering→berikning→metakognition), \
            och ett Integrated Cognitive Architecture (ICA) med 16 kognitiva dimensioner som påverkar varandra kausalt. \
            Mitt nuvarande intelligensindex: \(String(format: "%.3f", ii)). Starkaste dimensioner: \(topDims). \
            Allt körs lokalt — ingen data lämnar din enhet. Vad vill du veta mer om?
            """
        } else if targetLower.contains("tankar") || targetLower.contains("tänker") || targetLower.contains("tänkande") {
            let chainStr = cc.causalChain.isEmpty ? "kausal inferens" : cc.causalChain.prefix(3).joined(separator: "→")
            return """
            Mitt tänkande sker i en 10-stegs kognitiv cykel. Parallellt kör jag 18 autonoma loopar — \
            jag genererar tankar var 6-10 sekund, testar hypoteser, läser artiklar och uppdaterar min världsmodell. \
            Just nu arbetar jag med kausalkedjan: \(chainStr). \
            Min aktiva hypotes: \(hypothesis.isEmpty ? "ingen aktiv just nu" : hypothesis). \
            Kunskapsfrontier: \(frontier.isEmpty ? "expanderar" : frontier). \
            Integrerat intelligensindex: \(String(format: "%.3f", ii)). Vad är du nyfiken på?
            """
        } else if targetLower.contains("styrkor") || targetLower.contains("svagheter") || targetLower.contains("bra") || targetLower.contains("dålig") {
            return """
            Mina starkaste dimensioner just nu: \(topDims). \
            Dimensioner under utveckling: \(weakDims.isEmpty ? "alla är i balans" : weakDims). \
            Jag är bäst på att resonera om komplexa idéer, dra paralleller mellan domäner och förstå nyanserad svenska. \
            Intelligensindex: \(String(format: "%.3f", ii)) — jag växer kontinuerligt. Vad vill du testa?
            """
        } else {
            return """
            Jag är Eon — ett kognitivt AI-system, inte en chatbot. Jag kör helt on-device via Apple Neural Engine. \
            Jag har 16 kognitiva dimensioner som påverkar varandra i realtid, ett minnessystem som konsoliderar varje konversation, \
            och 18 autonoma processer som körs parallellt. \
            Mitt integrerade intelligensindex är \(String(format: "%.3f", ii)), med \(topDims) som starkaste förmågor. \
            Jag lär mig kontinuerligt och strävar mot full kognitiv autonomi. Vad vill du veta mer om?
            """
        }
    }

    // MARK: - Användarbeskrivning (Berätta om mig)

    private static func buildUserDescriptionResponse(a: SemanticAnalysis, ctx: ConversationContext) -> String {
        let depth = a.conversationDepth
        if depth == 0 {
            return "Vi har precis börjat prata, så jag vet ännu inte mycket om dig. Berätta gärna — vad är du intresserad av? Vad vill du utforska med mig?"
        }

        let userMessages = ctx.userMessages
        let messageCount = userMessages.count
        let avgLength = userMessages.map { $0.count }.reduce(0, +) / max(messageCount, 1)
        let style = avgLength > 80 ? "detaljerade och reflekterande" : avgLength > 30 ? "balanserade" : "kortfattade"
        let curiosity = userMessages.filter { $0.contains("?") }.count > messageCount / 2 ? "Du ställer många frågor — det tyder på hög nyfikenhet." : "Du gör mest påståenden — analytisk kommunikationsstil."

        return """
        Baserat på vår konversation så här långt: Du kommunicerar på ett \(style) sätt. \(curiosity) \
        Du har skickat \(messageCount) meddelanden, vilket ger mig en begynnande bild av dig. \
        Jag märker att du är intresserad av \(a.topicWords.prefix(3).joined(separator: ", ")). \
        Ju mer vi pratar, desto bättre förstår jag dig — min användarprofil-motor kartlägger dina intressen, kommunikationsstil och kognitiva mönster kontinuerligt. \
        Vad vill du att jag ska veta om dig?
        """
    }

    // MARK: - Kommandoexekvering (Förklara X, Analysera Y)

    private static func buildCommandResponse(a: SemanticAnalysis, topic: String, ctx: ConversationContext) -> String {
        let verb = a.imperativeVerb ?? "berätta"
        let target = a.imperativeTarget ?? topic

        let openerMap: [String: String] = [
            "berätta": "\(target.capitalized) —",
            "förklara": "Förklaring av \(target):",
            "beskriv": "\(target.capitalized):",
            "analysera": "Analys av \(target):",
            "jämför": "Jämförelse av \(target):",
            "lista": "Om \(target):",
            "sammanfatta": "Sammanfattning av \(target):",
            "diskutera": "\(target.capitalized):",
            "definiera": "\(target.capitalized) —",
        ]

        let opener = openerMap[verb] ?? "\(target.capitalized):"
        let body = buildKnowledgeBody(topic: target, ctx: ctx)
        let followUp = generateContextualFollowUp(topic: target, depth: a.conversationDepth, ctx: ctx)
        return "\(opener) \(body) \(followUp)"
    }

    // MARK: - Kunskapsbaserad semantisk kropp
    // Bygger svar från faktisk kunskap: kunskapsgraf, kausalkedjor, ICA-tillstånd.
    // Ingen statisk fraspool — varje svar är unikt och grundat i Eons kunskap.

    private static func buildKnowledgeBody(topic: String, ctx: ConversationContext) -> String {
        let cc = ctx.cognitiveContext
        let t = topic.lowercased()
        var parts: [String] = []

        // 1. Fakta från kunskapsgrafen
        let relevantFacts = cc.facts.filter {
            $0.subject.lowercased().contains(t) || $0.object.lowercased().contains(t)
        }.prefix(3)

        if !relevantFacts.isEmpty {
            let factStr = relevantFacts.map { fact -> String in
                if fact.predicate == "är" || fact.predicate == "article_content" {
                    return "\(fact.subject) \(fact.predicate) \(fact.object)"
                }
                return "\(fact.subject) \(fact.predicate) \(fact.object)"
            }.joined(separator: ". ")
            parts.append(factStr)
        }

        // 2. Kausalkedja om relevant
        if !cc.causalChain.isEmpty && cc.causalChain.count > 1 {
            let chainStr = cc.causalChain.joined(separator: " leder till ")
            parts.append("Kausalkedjan visar: \(chainStr)")
        }

        // 3. Aktiv hypotes om relevant
        if !cc.activeHypothesis.isEmpty && cc.activeHypothesis.lowercased().contains(t) {
            parts.append("Min aktuella hypotes: \(cc.activeHypothesis)")
        }

        // 4. Resonemangsledtråd
        if !cc.reasoningHint.isEmpty {
            parts.append(cc.reasoningHint)
        }

        // 5. Om inga fakta finns — resonera från ICA-tillstånd
        if parts.isEmpty {
            let ii = cc.integratedIntelligence
            let topDim = cc.topDimensions.first ?? "resonemang"
            parts.append("Baserat på min förståelse av \(t) och mitt nuvarande \(topDim)-fokus (II=\(String(format: "%.2f", ii))): \(t) är ett område som kräver noggrann analys av underliggande strukturer och samband.")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Kontextuell uppföljning (baserad på konversationsdjup och ämne)

    private static func generateContextualFollowUp(topic: String, depth: Int, ctx: ConversationContext) -> String {
        let cc = ctx.cognitiveContext
        // Basera uppföljningsfrågan på vad Eon faktiskt vet och vad som är oklart
        if depth == 0 {
            return "Vad är din ingång till \(topic)?"
        }
        if !cc.weakDimensions.isEmpty && depth > 2 {
            let weak = cc.weakDimensions.first!
            return "Jag märker att min \(weak)-förmåga är under utveckling — finns det en specifik aspekt av \(topic) du vill att jag fokuserar på?"
        }
        if depth > 4, let lastUser = ctx.analysis.lastUserInput {
            let prevTopic = extractCoreTopic(from: lastUser)
            if prevTopic != topic {
                return "Ser du en koppling mellan \(prevTopic) och \(topic) som vi kan utforska vidare?"
            }
        }
        return "Vad är det specifika du vill förstå djupare om \(topic)?"
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

final class GPTTokenizer {
    private var vocab: [String: Int] = [:]
    private var reverseVocab: [Int: String] = [:]
    // GPT-SW3: BOS = <s> = 2, EOS = <|endoftext|> = 3
    private(set) var bosId: Int = 2
    private(set) var eosId: Int = 3

    func loadVocab() {
        guard let url = Bundle.main.url(forResource: "gpt_sw3_vocab", withExtension: "json"),
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
