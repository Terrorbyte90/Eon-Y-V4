import Foundation
import NaturalLanguage

// MARK: - QuestionUnderstandingAgent: Djup frågeförståelse
// Går bortom InputAnalyzer: löser pronomen, hanterar flerdelsfrågor,
// detekterar implicita frågor, identifierar vilka kunskapsdomäner som behövs.

struct QuestionProfile: Sendable {
    let originalInput: String
    let resolvedInput: String         // Med pronomen upplösta: "den" → "Flashback"
    let coreTopic: String             // Huvudämne
    let subTopics: [String]           // Underämnen
    let questionType: QuestionType
    let questionParts: [QuestionPart] // Flerdelsfrågor delade
    let namedEntities: [String]       // Namngivna entiteter
    let keyNouns: [String]            // Nyckelsubstantiv
    let requiredDomains: [KnowledgeDomain]  // Vilka kunskapsdomäner behövs?
    let isAboutEon: Bool              // Frågar om Eon själv?
    let isFollowUp: Bool              // Följdfråga?
    let impliedContext: String        // Implicit kontext från historiken
    let emotionalTone: EmotionalTone  // Användarens emotionella ton
    let expectedResponseLength: ResponseLength
    let searchQueries: [String]       // Optimerade sökfrågor för kunskapssökning

    enum QuestionType: String, Sendable {
        case factual = "faktafråga"
        case explanation = "förklaring"
        case opinion = "åsikt"
        case comparison = "jämförelse"
        case howTo = "hur-gör-man"
        case whyExplanation = "varför"
        case definition = "definition"
        case list = "lista"
        case yesNo = "ja-nej"
        case personal = "personlig"
        case creative = "kreativ"
        case selfReference = "om-eon"
        case greeting = "hälsning"
        case followUp = "uppföljning"
        case unknown = "okänt"
    }

    struct QuestionPart: Sendable {
        let text: String
        let type: QuestionType
        let topic: String
    }

    enum KnowledgeDomain: String, Sendable {
        case general = "allmänt"
        case science = "vetenskap"
        case technology = "teknik"
        case history = "historia"
        case geography = "geografi"
        case culture = "kultur"
        case language = "språk"
        case philosophy = "filosofi"
        case selfKnowledge = "självkunskap"
        case currentEvents = "aktuellt"
        case math = "matematik"
        case nature = "natur"
        case society = "samhälle"
        case art = "konst"
        case food = "mat"
        case sports = "sport"
        case health = "hälsa"
        case psychology = "psykologi"
    }

    enum EmotionalTone: String, Sendable {
        case neutral, curious, frustrated, happy, sad, confused, formal, informal, urgent
    }

    enum ResponseLength: Sendable {
        case veryShort   // 1 mening (hälsning, ja/nej)
        case short       // 2-3 meningar
        case medium      // 4-6 meningar
        case long        // 7+ meningar (förklaring, resonemang)
    }
}

actor QuestionUnderstandingAgent {

    // MARK: - Normal analys (max ~0.5s)

    func analyze(input: String, conversationHistory: [ConversationRecord]) -> QuestionProfile {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = input.split(separator: " ").count

        // 1. Extrahera entiteter och substantiv
        let (keyNouns, namedEntities) = extractNounsAndEntities(input)

        // 2. Lös upp pronomen med konversationshistorik
        let resolvedInput = resolvePronouns(input: input, history: conversationHistory, entities: namedEntities)

        // 3. Bestäm frågetyp
        let questionType = classifyQuestion(lower, wordCount: wordCount)

        // 4. Extrahera kärnämne
        let coreTopic = extractCoreTopic(input: resolvedInput, lower: lower, nouns: keyNouns, entities: namedEntities)

        // 5. Dela upp flerdelsfrågor
        let parts = splitMultiPartQuestion(input, type: questionType)

        // 6. Identifiera kunskapsdomäner
        let domains = identifyDomains(input: lower, nouns: keyNouns, entities: namedEntities)

        // 7. Detektera om frågan handlar om Eon
        let isAboutEon = detectSelfReference(lower)

        // 8. Detektera uppföljning
        let isFollowUp = detectFollowUp(input: lower, wordCount: wordCount, history: conversationHistory)

        // 9. Emotionell ton
        let tone = detectEmotionalTone(lower)

        // 10. Förväntad svarslängd
        let length = estimateResponseLength(type: questionType, wordCount: wordCount)

        // 11. Generera optimerade sökfrågor
        let queries = generateSearchQueries(
            input: input, resolved: resolvedInput, topic: coreTopic,
            entities: namedEntities, nouns: keyNouns
        )

        // 12. Implicit kontext
        let implied = extractImpliedContext(history: conversationHistory, isFollowUp: isFollowUp)

        return QuestionProfile(
            originalInput: input,
            resolvedInput: resolvedInput,
            coreTopic: coreTopic,
            subTopics: keyNouns.filter { $0.lowercased() != coreTopic.lowercased() },
            questionType: questionType,
            questionParts: parts,
            namedEntities: namedEntities,
            keyNouns: keyNouns,
            requiredDomains: domains,
            isAboutEon: isAboutEon,
            isFollowUp: isFollowUp,
            impliedContext: implied,
            emotionalTone: tone,
            expectedResponseLength: length,
            searchQueries: queries
        )
    }

    // MARK: - Djup analys (mer tid tillgänglig)

    func analyzeDeep(input: String, conversationHistory: [ConversationRecord]) -> QuestionProfile {
        // Samma som normal men med bredare sökning
        let profile = analyze(input: input, conversationHistory: conversationHistory)
        // I djupläge: fler sökfrågor, djupare pronomenupplösning
        var deepQueries = profile.searchQueries
        // Lägg till synonymer och varianter
        for noun in profile.keyNouns.prefix(3) {
            deepQueries.append(noun)
            // Singular/plural-varianter
            if noun.hasSuffix("er") { deepQueries.append(String(noun.dropLast(2))) }
            if noun.hasSuffix("ar") { deepQueries.append(String(noun.dropLast(2))) }
            if !noun.hasSuffix("s") { deepQueries.append(noun + "s") }
        }
        return QuestionProfile(
            originalInput: profile.originalInput,
            resolvedInput: profile.resolvedInput,
            coreTopic: profile.coreTopic,
            subTopics: profile.subTopics,
            questionType: profile.questionType,
            questionParts: profile.questionParts,
            namedEntities: profile.namedEntities,
            keyNouns: profile.keyNouns,
            requiredDomains: profile.requiredDomains,
            isAboutEon: profile.isAboutEon,
            isFollowUp: profile.isFollowUp,
            impliedContext: profile.impliedContext,
            emotionalTone: profile.emotionalTone,
            expectedResponseLength: .long,
            searchQueries: deepQueries
        )
    }

    // MARK: - Pronomenupplösning

    /// Ersätter pronomen ("den", "det", "han", "hon", "de", "dem") med senaste referenten
    private func resolvePronouns(input: String, history: [ConversationRecord], entities: [String]) -> String {
        let lower = input.lowercased()
        let pronouns: Set<String> = ["den", "det", "de", "dem", "han", "hon", "denne", "detta",
                                      "dessa", "hans", "hennes", "deras", "sin", "sitt", "sina"]
        let inputWords = input.components(separatedBy: .whitespacesAndNewlines)
        let hasPronouns = inputWords.contains { pronouns.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }

        guard hasPronouns && !history.isEmpty else { return input }

        // Hitta senaste ämne/entitet från historiken
        var recentTopics: [String] = []
        for turn in history.suffix(4).reversed() {
            // Extrahera substantiv från senaste turerna
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
            tagger.string = turn.content
            tagger.enumerateTags(in: turn.content.startIndex..<turn.content.endIndex,
                                 unit: .word, scheme: .nameType,
                                 options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                if tag != nil {
                    let entity = String(turn.content[range])
                    if entity.count > 1 && !recentTopics.contains(entity) {
                        recentTopics.append(entity)
                    }
                }
                return true
            }
            // Också titta på substantiv
            tagger.enumerateTags(in: turn.content.startIndex..<turn.content.endIndex,
                                 unit: .word, scheme: .lexicalClass,
                                 options: [.omitWhitespace, .omitPunctuation]) { tag, range in
                if tag == .noun {
                    let word = String(turn.content[range])
                    if word.count > 3 && word.first?.isUppercase == true && !recentTopics.contains(word) {
                        recentTopics.append(word)
                    }
                }
                return true
            }
        }

        guard let mainReferent = recentTopics.first else { return input }

        // Enkel pronomenbyte — ersätt det mest troliga pronomenet
        var resolved = input
        let replacements: [(String, String)] = [
            ("den ", "\(mainReferent) "),
            ("det ", "\(mainReferent) "),
            ("Den ", "\(mainReferent) "),
            ("Det ", "\(mainReferent) "),
        ]
        // Bara ersätt om det ser ut som ett pronomen som refererar bakåt
        if lower.hasPrefix("vad vet du om den") || lower.hasPrefix("vad vet du om det") ||
           lower.hasPrefix("berätta mer om den") || lower.hasPrefix("berätta mer om det") ||
           lower.hasPrefix("vad är det") || lower.hasPrefix("vad är den") ||
           lower.contains("om den?") || lower.contains("om det?") {
            for (old, new) in replacements {
                if resolved.contains(old) {
                    resolved = resolved.replacingOccurrences(of: old, with: new)
                    break
                }
            }
        }

        return resolved
    }

    // MARK: - Frågetypklassificering

    private func classifyQuestion(_ lower: String, wordCount: Int) -> QuestionProfile.QuestionType {
        // Hälsningar
        let greetings = ["hej", "hallå", "tja", "hejsan", "god morgon", "god kväll", "tjena", "morsning"]
        if greetings.contains(where: { lower.hasPrefix($0) }) && wordCount <= 4 { return .greeting }

        // Självrefererande
        let selfPatterns = ["vem är du", "vad är du", "berätta om dig", "hur fungerar du", "vad kan du",
                            "hur smart", "hur intelligent", "är du medveten", "har du känslor",
                            "hur mår du", "vad upplever du", "vad tänker du om dig"]
        if selfPatterns.contains(where: { lower.contains($0) }) { return .selfReference }

        // Definition
        let defPatterns = ["vad är ", "vad betyder ", "vad innebär ", "vad menas med ", "definiera "]
        if defPatterns.contains(where: { lower.hasPrefix($0) }) { return .definition }

        // Jämförelse
        let compPatterns = ["skillnaden mellan", "jämför ", "vad skiljer", "hur skiljer sig", "bättre än",
                            "sämre än", "liknar ", "vs ", " eller "]
        if compPatterns.contains(where: { lower.contains($0) }) && lower.contains("?") { return .comparison }

        // Hur-gör-man
        if lower.hasPrefix("hur ") && (lower.contains("gör") || lower.contains("kan man") || lower.contains("ska")) { return .howTo }

        // Varför
        if lower.hasPrefix("varför ") || lower.contains("varför ") { return .whyExplanation }

        // Lista
        let listPatterns = ["lista ", "räkna upp", "ge exempel", "vilka ", "nämn "]
        if listPatterns.contains(where: { lower.hasPrefix($0) }) { return .list }

        // Ja/Nej
        let ynVerbs: Set<String> = ["är", "kan", "har", "ska", "vet", "finns", "vill", "bör", "måste", "stämmer"]
        let firstWord = String(lower.prefix(while: { $0 != " " }))
        if ynVerbs.contains(firstWord) && lower.contains("?") { return .yesNo }

        // Förklaring
        let explainPatterns = ["förklara", "berätta om", "beskriv", "hur fungerar", "redogör"]
        if explainPatterns.contains(where: { lower.contains($0) }) { return .explanation }

        // Åsikt
        let opinionPatterns = ["tycker du", "anser du", "tror du", "din åsikt", "vad tänker du"]
        if opinionPatterns.contains(where: { lower.contains($0) }) { return .opinion }

        // Kreativ
        let creativePatterns = ["skriv en", "hitta på", "dikt", "berättelse", "fantisera"]
        if creativePatterns.contains(where: { lower.contains($0) }) { return .creative }

        // Personlig/emotionell
        let personalPatterns = ["jag mår", "jag känner", "jag är ledsen", "jag är glad"]
        if personalPatterns.contains(where: { lower.contains($0) }) { return .personal }

        // Kort uppföljning
        if wordCount <= 3 && !lower.contains("?") { return .followUp }

        // Faktafråga (default vid frågetecken)
        if lower.contains("?") { return .factual }

        return .unknown
    }

    // MARK: - Extrahera substantiv och entiteter

    private func extractNounsAndEntities(_ input: String) -> ([String], [String]) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = input

        var nouns: [String] = []
        var entities: [String] = []

        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(input[range])
            if tag == .noun && word.count > 2 { nouns.append(word) }
            return true
        }

        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word,
                             scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag != nil {
                let entity = String(input[range])
                if entity.count > 1 { entities.append(entity) }
            }
            return true
        }

        // Versaler = troliga egennamn (NLTagger missar ibland svenska)
        let words = input.components(separatedBy: .whitespacesAndNewlines)
        for (i, word) in words.enumerated() {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if cleaned.count > 1, cleaned.first?.isUppercase == true, !entities.contains(cleaned) {
                if i > 0 || words.count <= 3 { entities.append(cleaned) }
            }
        }

        return (nouns, entities)
    }

    // MARK: - Kärnämnesextraktion

    private func extractCoreTopic(input: String, lower: String, nouns: [String], entities: [String]) -> String {
        if let entity = entities.first { return entity }

        let stopwords: Set<String> = ["vad", "vem", "var", "när", "hur", "vilken", "vilka", "vilket",
                                       "vet", "du", "om", "kan", "berätta", "förklara", "är", "det",
                                       "att", "en", "ett", "den", "de", "på", "i", "med", "för",
                                       "och", "eller", "av", "till", "från", "har", "hade", "ska",
                                       "skulle", "kunde", "måste", "vill", "jag", "mig", "dig",
                                       "sin", "sitt", "sina", "tycker", "tror", "anser", "inte",
                                       "så", "här", "där", "alla", "allt", "gör", "gå", "göra",
                                       "finns", "mer", "mycket", "också", "bara", "lite"]

        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 && !stopwords.contains($0) }

        // Sista meningsfulla ordet är ofta ämnet i svenska frågor
        if let last = words.last { return last }
        if let noun = nouns.first { return noun }
        return String(input.prefix(30))
    }

    // MARK: - Flerdelsfrågedelning

    private func splitMultiPartQuestion(_ input: String, type: QuestionProfile.QuestionType) -> [QuestionProfile.QuestionPart] {
        // Dela på "och", "samt", "dessutom", eller frågetecken mitt i
        let separators = [" och ", " samt ", " dessutom ", "? "]
        var parts: [String] = [input]

        for sep in separators {
            var newParts: [String] = []
            for part in parts {
                let subParts = part.components(separatedBy: sep)
                newParts.append(contentsOf: subParts.map { $0.trimmingCharacters(in: .whitespaces) })
            }
            parts = newParts.filter { !$0.isEmpty }
        }

        guard parts.count > 1 else {
            return [QuestionProfile.QuestionPart(text: input, type: type, topic: "")]
        }

        return parts.map { part in
            let lower = part.lowercased()
            let partType = classifyQuestion(lower, wordCount: part.split(separator: " ").count)
            return QuestionProfile.QuestionPart(text: part, type: partType, topic: "")
        }
    }

    // MARK: - Domänidentifiering

    private func identifyDomains(input: String, nouns: [String], entities: [String]) -> [QuestionProfile.KnowledgeDomain] {
        let lower = input.lowercased()
        var domains: [QuestionProfile.KnowledgeDomain] = []

        let domainKeywords: [(QuestionProfile.KnowledgeDomain, [String])] = [
            (.science, ["vetenskap", "fysik", "kemi", "biologi", "atom", "molekyl", "experiment", "forskning", "teori"]),
            (.technology, ["dator", "program", "ai", "internet", "teknik", "digital", "mjukvara", "hårdvara", "robot", "algoritm"]),
            (.history, ["historia", "krig", "revolution", "antiken", "medeltid", "kung", "drottning", "imperium", "forntid"]),
            (.geography, ["land", "stad", "kontinent", "hav", "berg", "flod", "population", "geografi", "karta"]),
            (.culture, ["kultur", "tradition", "musik", "film", "bok", "konst", "teater", "festival", "religion"]),
            (.language, ["språk", "grammatik", "ord", "mening", "översätt", "svenska", "engelska", "ordförråd"]),
            (.philosophy, ["filosofi", "moral", "etik", "mening", "existens", "medvetande", "fri vilja", "kunskap"]),
            (.selfKnowledge, ["eon", "du ", "dig ", "medveten", "din ", "ditt ", "dina "]),
            (.math, ["matematik", "räkna", "ekvation", "procent", "summa", "multiplicera", "dividera"]),
            (.nature, ["djur", "växt", "natur", "skog", "hav", "klimat", "miljö", "ekologi"]),
            (.society, ["politik", "samhälle", "ekonomi", "demokrati", "lag", "rättighet", "regering"]),
            (.health, ["hälsa", "sjukdom", "medicin", "kropp", "träning", "kost", "vitamin"]),
            (.psychology, ["psykologi", "beteende", "känsla", "minne", "motivation", "personlighet"]),
            (.food, ["mat", "recept", "laga", "ingrediens", "kök", "smak"]),
            (.sports, ["sport", "fotboll", "hockey", "tävling", "match", "spel", "träna"]),
        ]

        for (domain, keywords) in domainKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                domains.append(domain)
            }
        }

        if domains.isEmpty { domains.append(.general) }
        return domains
    }

    // MARK: - Hjälpfunktioner

    private func detectSelfReference(_ lower: String) -> Bool {
        let patterns = ["vem är du", "vad är du", "om dig", "hur fungerar du", "vad kan du",
                        "din ", "ditt ", "dina ", "du är", "är du ", "eon"]
        return patterns.contains(where: { lower.contains($0) })
    }

    private func detectFollowUp(input: String, wordCount: Int, history: [ConversationRecord]) -> Bool {
        if history.isEmpty { return false }
        if wordCount <= 3 { return true }
        let lower = input.lowercased()
        let followUps = ["ja", "nej", "okej", "varför", "hur då", "berätta mer", "fortsätt",
                         "mer om", "utveckla", "ge exempel", "och sedan"]
        return followUps.contains(where: { lower.hasPrefix($0) })
    }

    private func detectEmotionalTone(_ lower: String) -> QuestionProfile.EmotionalTone {
        if lower.contains("tack") || lower.contains("bra") { return .happy }
        if lower.contains("ledsen") || lower.contains("sorglig") { return .sad }
        if lower.contains("arg") || lower.contains("irriterad") || lower.contains("!") { return .frustrated }
        if lower.contains("undrar") || lower.contains("nyfiken") || lower.contains("?") { return .curious }
        if lower.contains("förstår inte") || lower.contains("förvirrad") { return .confused }
        return .neutral
    }

    private func estimateResponseLength(type: QuestionProfile.QuestionType, wordCount: Int) -> QuestionProfile.ResponseLength {
        switch type {
        case .greeting, .followUp: return .veryShort
        case .yesNo: return .short
        case .definition, .factual, .personal: return .short
        case .opinion, .howTo, .list, .comparison: return .medium
        case .explanation, .whyExplanation, .creative: return .long
        case .selfReference: return .medium
        case .unknown: return wordCount > 10 ? .medium : .short
        }
    }

    private func generateSearchQueries(input: String, resolved: String, topic: String,
                                        entities: [String], nouns: [String]) -> [String] {
        var queries: [String] = []
        // Original + resolved version
        queries.append(input)
        if resolved != input { queries.append(resolved) }
        // Core topic alone
        if topic.count > 2 { queries.append(topic) }
        // Named entities
        for entity in entities.prefix(3) { queries.append(entity) }
        // Key nouns (limited)
        for noun in nouns.prefix(2) where !queries.contains(noun) { queries.append(noun) }
        return queries
    }

    private func extractImpliedContext(history: [ConversationRecord], isFollowUp: Bool) -> String {
        guard isFollowUp, let lastUser = history.last(where: { $0.role == "user" }) else { return "" }
        return "Uppföljning på: \(String(lastUser.content.prefix(100)))"
    }
}
