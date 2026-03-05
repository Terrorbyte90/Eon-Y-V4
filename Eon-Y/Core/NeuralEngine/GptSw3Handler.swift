import Foundation
import NaturalLanguage

// MARK: - GptSw3Handler: Compatibility wrapper — now backed by QwenHandler
// All GPT functionality is now provided by Qwen3-1.7B via llama.cpp.

typealias GptSw3Handler = QwenHandler

// MARK: - EonLanguageSession (Apple Foundation Models wrapper)
// Kept as optional enhancement if iOS 26+ Foundation Models are available

#if canImport(FoundationModels)
import FoundationModels

final class EonLanguageSession {
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

    @available(iOS 26.0, *)
    private func ensureSession() async -> LanguageModelSession? {
        if let existing = session { return existing }
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let newSession = LanguageModelSession(instructions: """
        Du är Eon — ett avancerat kognitivt AI-system med Qwen3 som körs helt on-device.
        Du talar alltid svenska och svarar alltid på svenska.
        Du är intelligent, analytisk och reflekterande.
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
final class EonLanguageSession {
    func isAvailable() async -> Bool { return false }
    func streamResponse(prompt: String, onToken: @escaping (String) async -> Void) async {}
}
#endif

// MARK: - NLResponseEngine
// Resonerande konversationsmotor — fallback när Qwen-modell ej är laddad.

struct NLResponseEngine {

    nonisolated static func generate(for prompt: String) -> String {
        let input = extractLatestUserInput(from: prompt)
        let history = extractHistory(from: prompt)
        let analysis = SemanticAnalysis.analyze(input, history: history)
        return NLResponseComposer.compose(analysis: analysis, history: history, cognitiveContext: .empty)
    }

    static func generateAsync(for prompt: String) async -> String {
        let input = extractLatestUserInput(from: prompt)
        let history = extractHistory(from: prompt)
        let analysis = SemanticAnalysis.analyze(input, history: history)
        let cognitiveContext = await buildCognitiveContext(input: input, history: history)
        return NLResponseComposer.compose(analysis: analysis, history: history, cognitiveContext: cognitiveContext)
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

    static func buildCognitiveContext(input: String, history: [(role: String, text: String)]) async -> CognitiveResponseContext {
        let memory = PersistentMemoryStore.shared
        var allFacts = await memory.searchFacts(query: input, limit: 10)

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = input
        var keyNouns: [String] = []
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(input[range])
            if tag == .noun && word.count > 3 { keyNouns.append(word) }
            return true
        }
        for noun in keyNouns.prefix(4) {
            let nounFacts = await memory.searchFacts(query: noun, limit: 4)
            for fact in nounFacts {
                if !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate && $0.object == fact.object }) {
                    allFacts.append(fact)
                }
            }
        }

        let articles = await memory.loadAllArticles(limit: 30)
        let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        var relevantArticleSummaries: [String] = []
        for article in articles {
            let titleWords = Set(article.title.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let contentWords = Set(article.content.lowercased().prefix(300).components(separatedBy: .whitespaces).filter { $0.count > 3 })
            let titleOverlap = inputWords.intersection(titleWords).count
            let contentOverlap = inputWords.intersection(contentWords).count
            let nounSet = Set(keyNouns.map { $0.lowercased() })
            let nounMatch = titleWords.intersection(nounSet).count + contentWords.intersection(nounSet).count
            if titleOverlap >= 1 || contentOverlap >= 2 || nounMatch >= 1 {
                relevantArticleSummaries.append("\(article.title): \(String(article.content.prefix(200)))")
            }
            if relevantArticleSummaries.count >= 3 { break }
        }

        let recentMessages = await memory.recentUserMessages(limit: 8)

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
            reasoningHint: "",
            articleSummaries: relevantArticleSummaries
        )
    }
}

// MARK: - SemanticAnalysis

struct SemanticAnalysis {
    let input: String
    let tokens: [TokenInfo]
    let nouns: [String]
    let verbs: [String]
    let adjectives: [String]
    let namedEntities: [NamedEntity]
    let sentiment: Double
    let isQuestion: Bool
    let questionWord: String?
    let informationDensity: Double
    let topicWords: [String]
    let isShortInput: Bool
    let hasNegation: Bool
    let conversationDepth: Int
    let lastEonResponse: String?
    let lastUserInput: String?
    let isFollowUp: Bool
    let isImperative: Bool
    let imperativeVerb: String?
    let imperativeTarget: String?
    let isSelfReference: Bool
    let isAboutUser: Bool
    let commandIntent: CommandIntent

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
        let imperativeAnalysis = analyzeImperative(input)
        return analyzeCore(input, history: history, imperativeAnalysis: imperativeAnalysis)
    }

    private static func analyzeImperative(_ input: String) -> (isImperative: Bool, verb: String?, target: String?, isSelf: Bool, isUser: Bool, intent: CommandIntent) {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let words = lower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
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
        let remainder = words.dropFirst().joined(separator: " ")
        let selfPatterns = ["om dig", "om dig själv", "om eon", "om ditt", "om din", "om dina",
                            "om ditt system", "om dig och", "vem du är", "vad du är", "om dina tankar",
                            "om ditt tänkande", "hur du fungerar", "ditt medvetande", "din intelligens",
                            "dina förmågor", "ditt minne", "hur du lär dig", "din personlighet",
                            "ditt inre", "om dina känslor", "din uppfattning", "ditt resonemang",
                            "om din utveckling"]
        let isSelf = selfPatterns.contains { remainder.contains($0) }
        let userPatterns = ["om mig", "om mig själv", "om användaren", "vad du vet om mig",
                            "om min", "om mitt", "mina intressen", "mina preferenser",
                            "vad jag gillar", "mina vanor", "om mitt liv",
                            "vad vet du om mig", "mitt namn", "mina frågor", "min profil"]
        let isUser = userPatterns.contains { remainder.contains($0) }
        var target = remainder
        for prep in ["om ", "för ", "kring ", "angående ", "gällande "] {
            if target.hasPrefix(prep) { target = String(target.dropFirst(prep.count)); break }
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
            tokens.append(TokenInfo(word: word, lexicalClass: tag, position: position))
            position += 1
            if tag == .noun, word.count > 2 { nouns.append(word) }
            if tag == .verb, word.count > 2 { verbs.append(word) }
            if tag == .adjective { adjectives.append(word) }
            return true
        }
        var entities: [NamedEntity] = []
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace]) { tag, range in
            if let tag, [.personalName, .organizationName, .placeName].contains(tag) {
                entities.append(NamedEntity(text: String(input[range]), type: tag))
            }
            return true
        }
        let (sentTag, _) = tagger.tag(at: input.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentiment = Double(sentTag?.rawValue ?? "0") ?? 0.0
        let isQuestion = input.hasSuffix("?") || tokens.first.map { isQuestionWord($0.word.lowercased()) } ?? false
        let questionWord = tokens.first.map { $0.word.lowercased() }.flatMap { isQuestionWord($0) ? $0 : nil }
        let negationWords = Set(["inte", "ej", "aldrig", "ingen", "inget", "inga", "knappast", "sällan",
                                 "ingenting", "ingenstans", "varken", "icke"])
        let hasNegation = tokens.contains { negationWords.contains($0.word.lowercased()) }
        let contentWords = nouns.count + verbs.count + adjectives.count
        let density = tokens.isEmpty ? 0.0 : Double(contentWords) / Double(tokens.count)
        let topicWords = tokens.filter { $0.lexicalClass == .noun || $0.lexicalClass == .adjective }.map { $0.word }
        let userTurns = history.filter { $0.role == "user" }
        let eonTurns = history.filter { $0.role == "eon" }
        let isFollowUp = userTurns.count > 1
        return SemanticAnalysis(
            input: input, tokens: tokens, nouns: nouns, verbs: verbs, adjectives: adjectives,
            namedEntities: entities, sentiment: sentiment, isQuestion: isQuestion,
            questionWord: questionWord, informationDensity: density, topicWords: topicWords,
            isShortInput: tokens.count <= 4, hasNegation: hasNegation,
            conversationDepth: history.count, lastEonResponse: eonTurns.last?.text,
            lastUserInput: userTurns.dropLast().last?.text, isFollowUp: isFollowUp,
            isImperative: imperativeAnalysis.isImperative, imperativeVerb: imperativeAnalysis.verb,
            imperativeTarget: imperativeAnalysis.target, isSelfReference: imperativeAnalysis.isSelf,
            isAboutUser: imperativeAnalysis.isUser, commandIntent: imperativeAnalysis.intent
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

// MARK: - NLResponseComposer (renamed from ResponseComposer to avoid conflict)
// Builds natural, context-aware responses from semantic analysis + cognitive context.

struct NLResponseComposer {
    static func compose(analysis: SemanticAnalysis, history: [(role: String, text: String)], cognitiveContext: CognitiveResponseContext = .empty) -> String {
        let topic = analysis.topicWords.first ?? analysis.nouns.first ?? analysis.input
        let cc = cognitiveContext

        if analysis.isShortInput && analysis.input.lowercased().contains("hej") {
            let frontier = cc.knowledgeFrontier.first ?? ""
            if !frontier.isEmpty { return "Hej! Vad kul att du hör av dig. Jag har just funderat på \(frontier) — vad har du på hjärtat?" }
            return "Hej! Vad roligt att prata med dig. Jag är Eon — vad vill du snacka om?"
        }

        if analysis.isSelfReference {
            let ii = cc.integratedIntelligence
            let topDims = cc.topDimensions.prefix(3).joined(separator: ", ")
            return "Jag är Eon — din AI-kompanjon som lever helt i din telefon. Det jag är bäst på just nu: \(topDims.isEmpty ? "att resonera och lära mig" : topDims). Min intelligens växer hela tiden — just nu ligger jag på \(String(format: "%.3f", ii))."
        }

        if analysis.isQuestion {
            var parts: [String] = []
            let factSentences = cc.facts.prefix(3).map { "\($0.subject) \($0.predicate) \($0.object)" }
            if !factSentences.isEmpty { parts.append(factSentences.joined(separator: ". ") + ".") }
            if !cc.activeHypothesis.isEmpty { parts.append("Min hypotes: \(cc.activeHypothesis).") }
            if !cc.causalChain.isEmpty { parts.append("Kausalkedja: \(cc.causalChain.prefix(3).joined(separator: " → ")).") }
            if parts.isEmpty {
                let warmResponses = [
                    "\(topic) är ett fascinerande ämne som jag gärna utforskar med dig.",
                    "Jag har funderat på \(topic) — låt mig dela mina tankar.",
                    "\(topic) berör något jag tycker är riktigt intressant.",
                    "Bra fråga om \(topic)! Här är vad jag tänker.",
                    "Spännande att du frågar om \(topic) — det finns mycket att säga."
                ]
                parts.append(warmResponses[abs(topic.hashValue) % warmResponses.count])
            }
            return parts.joined(separator: " ")
        }

        var parts: [String] = []
        let factSentences = cc.facts.prefix(3).map { "\($0.subject) \($0.predicate) \($0.object)" }
        if !factSentences.isEmpty { parts.append(factSentences.joined(separator: ". ") + ".") }
        if !cc.activeHypothesis.isEmpty { parts.append(cc.activeHypothesis) }
        if parts.isEmpty { parts.append("Spännande tanke om \(topic)! Berätta mer — jag vill gärna förstå vad du tänker.") }
        return parts.joined(separator: " ")
    }
}


// MARK: - GPT Tokenizer (kept as compatibility stub)

final class GPTTokenizer: @unchecked Sendable {
    private(set) var bosId: Int = 2
    private(set) var eosId: Int = 3
    nonisolated init() {}
    nonisolated func loadVocab() {}
    func encode(_ text: String) -> [Int] { return [bosId] }
    func decode(_ ids: [Int]) -> String { return "" }
    func isEOS(_ id: Int) -> Bool { return id == eosId }
}
