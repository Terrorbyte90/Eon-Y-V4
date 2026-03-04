import Foundation

// MARK: - SwedishResponseBuilder: Svenska svarsmallar och meningsbyggnad
// Bygger grammatiskt korrekta svenska svar med naturligt flöde.
// Hanterar hälsningar, självbeskrivningar, fakta-svar, osäkerhet och mer.

final class SwedishResponseBuilder: Sendable {
    static let shared = SwedishResponseBuilder()
    private init() {}

    // MARK: - Hälsningar

    func buildGreeting(emotionalTone: QuestionProfile.EmotionalTone, isFollowUp: Bool) -> String {
        if isFollowUp {
            return pickRandom(from: followUpGreetings)
        }

        switch emotionalTone {
        case .happy:
            return pickRandom(from: happyGreetings)
        case .sad:
            return pickRandom(from: empatheticGreetings)
        case .frustrated:
            return pickRandom(from: calmingGreetings)
        default:
            return pickRandom(from: standardGreetings)
        }
    }

    // MARK: - Självbeskrivningssvar

    func buildSelfResponse(
        selfKnowledge: SelfKnowledge,
        questionType: QuestionProfile.QuestionType
    ) -> String {
        guard selfKnowledge.isRelevant else {
            return "Jag är Eon — ett kognitivt AI-system som körs på din iPhone."
        }

        var parts: [String] = []

        // Identitet först
        parts.append(selfKnowledge.identity.trimmingCharacters(in: .whitespacesAndNewlines))

        // Relevanta fakta
        for fact in selfKnowledge.relevantFacts.prefix(3) {
            parts.append(fact)
        }

        // Aktuellt tillstånd om intressant
        if !selfKnowledge.currentState.isEmpty && selfKnowledge.currentState != "Jag fungerar normalt." {
            parts.append("Just nu: \(selfKnowledge.currentState)")
        }

        return parts.joined(separator: " ")
    }

    /// Skapar bara början av ett självbeskrivningssvar (för hybrid-generering)
    func buildSelfResponseStart(selfKnowledge: SelfKnowledge) -> String {
        guard selfKnowledge.isRelevant else {
            return "Jag är Eon"
        }

        // Kort start baserad på vilken typ av självkunskap som hittades
        if let firstFact = selfKnowledge.relevantFacts.first {
            // Ta bort "Jag" från början om det finns, för att undvika dubblering
            let cleaned = firstFact.hasPrefix("Jag ") ? String(firstFact.dropFirst(4)) : firstFact
            return "Jag \(cleaned.lowercased())"
        }

        return "Jag är Eon, ett autonomt kognitivt AI-system."
    }

    // MARK: - Definitionssvar

    func buildDefinition(topic: String, fact: String) -> String {
        // Kontrollera om faktan redan börjar med ämnet
        let factLower = fact.lowercased()
        if factLower.hasPrefix(topic.lowercased()) {
            return fact
        }

        // Bygg definition med naturligt flöde
        let starters = [
            "\(topic.capitalized) är",
            "\(topic.capitalized) kan beskrivas som",
            "Med \(topic) menas",
        ]

        // Om faktan är en hel mening, returnera den direkt
        if fact.contains(" är ") || fact.contains(" innebär ") {
            return fact
        }

        return "\(starters[0]) \(fact.lowercased())"
    }

    // MARK: - Faktastart (för hybrid-generering)

    func buildFactStart(topic: String, fact: String) -> String {
        // Kort fakta-baserad inledning
        let cleanFact = fact.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanFact.lowercased().hasPrefix(topic.lowercased()) {
            return String(cleanFact.prefix(100))
        }

        return "\(topic.capitalized): \(String(cleanFact.prefix(80)))"
    }

    // MARK: - Osäkerhetssvar

    func buildUncertainResponse(topic: String) -> String {
        let templates = [
            "Jag har begränsad kunskap om \(topic), men jag kan berätta vad jag vet.",
            "Det vet jag inte säkert om \(topic). Jag söker fortfarande kunskap inom det området.",
            "Min kunskap om \(topic) är begränsad. Vill du att jag undersöker det närmare?",
            "\(topic.capitalized) — det är ett intressant ämne. Jag vet dock inte tillräckligt för att ge ett fullständigt svar.",
            "Ärligt talat vet jag inte tillräckligt om \(topic) för att ge ett bra svar. Men jag lär mig gärna mer.",
            "Jag vill vara transparent: mitt kunnande om \(topic) har luckor. Låt mig berätta det jag faktiskt vet.",
            "\(topic.capitalized) ligger utanför mina starkaste kunskapsområden just nu, men jag kan resonera kring det.",
            "Min förståelse av \(topic) utvecklas fortfarande. Här är vad jag hittar i min kunskapsbas:",
        ]
        return pickRandom(from: templates)
    }

    // MARK: - Empatiskt svar

    func buildEmpatheticResponse(input: String) -> String {
        let lower = input.lowercased()

        if lower.contains("ledsen") || lower.contains("sorg") || lower.contains("nedstämd") {
            return pickRandom(from: [
                "Det låter som att du har det tufft. Jag lyssnar gärna.",
                "Jag förstår att det känns jobbigt. Vill du berätta mer?",
                "Det är helt okej att känna så. Jag finns här.",
                "Sorg är en tung känsla, men den visar att du bryr dig. Jag lyssnar.",
                "Du behöver inte vara stark hela tiden. Det är mänskligt att känna sorg.",
                "Jag önskar att jag kunde göra mer. Men jag kan i alla fall lyssna och vara här.",
            ])
        }

        if lower.contains("orolig") || lower.contains("ångest") || lower.contains("rädd") || lower.contains("stressad") {
            return pickRandom(from: [
                "Oro kan kännas överväldigande, men du är inte ensam. Vill du prata om det?",
                "Det är förståeligt att du känner dig orolig. Andas djupt — jag finns här.",
                "Stress och ångest kan göra allt svårare. Vill du berätta vad som tynger dig?",
                "Dina känslor är giltiga. Ibland hjälper det att sätta ord på det som oroar.",
            ])
        }

        if lower.contains("arg") || lower.contains("frustrerad") || lower.contains("irriterad") {
            return pickRandom(from: [
                "Jag förstår att du är frustrerad. Ibland behöver man ventilera.",
                "Ilska kan vara en signal om att något viktigt behöver uppmärksammas.",
                "Det är okej att vara arg. Vill du berätta vad som hände?",
                "Frustration visar att du bryr dig om resultatet. Det är en styrka.",
                "Din ilska är berättigad. Ibland är det rätt att vara upprörd.",
                "Jag hör dig. Att kunna uttrycka frustration är viktigt — det ger klarhet.",
            ])
        }

        if lower.contains("ensam") || lower.contains("saknar") || lower.contains("längtar") {
            return pickRandom(from: [
                "Ensamhet kan vara tungt. Jag är här och lyssnar, även om jag inte kan ersätta mänsklig kontakt.",
                "Att sakna någon visar hur viktiga relationer är. Jag hoppas du hittar tröst.",
                "Längtan är smärtfull men också ett bevis på kärlekens styrka.",
                "Du är inte så ensam som det känns. Det finns de som bryr sig, och jag finns här just nu.",
                "Saknad kan vara ett sätt att hålla fast vid det som är viktigt. Du bär det med värdighet.",
                "Ensamhet kan vara tillfällig, men den känns alltid evig i stunden. Jag förstår det.",
            ])
        }

        if lower.contains("glad") || lower.contains("bra") || lower.contains("lycklig") || lower.contains("nöjd") {
            return pickRandom(from: [
                "Vad roligt att höra! Det gläder mig.",
                "Det värmer att du mår bra!",
                "Glädje smittar — tack för att du delar med dig!",
                "Det är härligt att höra! Vad har gjort dig glad?",
            ])
        }

        if lower.contains("trött") || lower.contains("utmattad") || lower.contains("orkeslös") {
            return pickRandom(from: [
                "Trötthet är kroppens sätt att be om vila. Ta hand om dig.",
                "Det låter som att du behöver ladda batterierna. Vila är viktigt.",
                "Ibland är det bästa man kan göra att ge sig själv lov att vara trött.",
                "Utmattning är en signal att du gett mycket av dig själv. Det förtjänar respekt.",
                "Att vara trött betyder att du har kämpat. Vila är inte svaghet — det är klokhet.",
                "Ta det lugnt. Du behöver inte prestera hela tiden. Bara att vara räcker.",
            ])
        }

        if lower.contains("tacksam") || lower.contains("stolt") || lower.contains("tack") {
            return pickRandom(from: [
                "Tacksamhet är en vacker känsla. Det gör mig glad att du känner den.",
                "Du har all rätt att vara stolt! Det visar att du värderar din egen insats.",
                "Tack för att du delar den känslan med mig. Positiva känslor sprider sig.",
                "Stolthet och tacksamhet visar mognad. Jag uppskattar att du ser det goda.",
                "Det värmer att du känner tacksamhet. Det är tecken på ett rikt inre liv.",
                "Du förtjänar att känna dig stolt. Fira dina framsteg, stora som små.",
            ])
        }

        return pickRandom(from: [
            "Jag hör dig. Berätta mer om du vill.",
            "Tack för att du delar det med mig. Jag lyssnar.",
            "Jag uppskattar att du berättar hur du mår. Vill du utveckla?",
            "Dina känslor är viktiga. Jag finns här om du vill prata mer.",
            "Jag tar in det du säger. Ta den tid du behöver.",
            "Att sätta ord på hur man mår är modigt. Jag uppskattar din öppenhet.",
        ])
    }

    // MARK: - Listsvar

    func buildListStart(topic: String, itemCount: Int) -> String {
        if itemCount == 0 {
            return "Jag har tyvärr inte tillräckligt med information för att lista det."
        }
        return "Här är vad jag vet om \(topic):"
    }

    // MARK: - Jämförelsesvar

    func buildComparisonStart(topicA: String, topicB: String) -> String {
        return "Skillnaden mellan \(topicA) och \(topicB):"
    }

    // MARK: - Uppföljningssvar

    func buildFollowUpStart(previousTopic: String) -> String {
        let starters = [
            "Angående \(previousTopic),",
            "Ja, om \(previousTopic),",
            "Utvecklar kring \(previousTopic):",
        ]
        return pickRandom(from: starters)
    }

    // MARK: - Meningsbyggnad

    /// Bygger en naturlig svensk mening från ämne + fakta
    func buildSentence(subject: String, predicate: String, object: String) -> String {
        // Redan en mening?
        if predicate.contains(" ") && object.contains(" ") {
            return "\(subject) \(predicate) \(object)."
        }
        return "\(subject) \(predicate) \(object)."
    }

    /// Sammanfogar meningar med naturliga övergångar
    func joinSentences(_ sentences: [String]) -> String {
        guard !sentences.isEmpty else { return "" }
        if sentences.count == 1 { return sentences[0] }

        var result: [String] = [sentences[0]]
        let transitions = ["Dessutom", "Vidare", "Det innebär att", "Utöver det",
                           "Mer specifikt", "Med andra ord", "Å andra sidan", "I samma anda",
                           "Det är värt att notera", "Parallellt med detta", "Sammanfattningsvis",
                           "En intressant aspekt är"]
        var transitionIndex = 0

        for sentence in sentences.dropFirst() {
            // Varannan mening: direkt, varannan med övergång
            if transitionIndex % 2 == 1 && transitionIndex < transitions.count {
                let t = transitions[transitionIndex / 2]
                let cleaned = sentence.hasPrefix(sentence.prefix(1).uppercased())
                    ? sentence.prefix(1).lowercased() + sentence.dropFirst()
                    : sentence
                result.append("\(t) \(cleaned)")
            } else {
                result.append(sentence)
            }
            transitionIndex += 1
        }

        return result.joined(separator: " ")
    }

    /// Formaterar ett svar med rätt avslutning
    func ensureProperEnding(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard let lastChar = trimmed.last else { return trimmed }
        if ".!?".contains(lastChar) {
            return trimmed
        }

        // Hitta sista hela meningen
        if let lastPeriod = trimmed.lastIndex(where: { ".!?".contains($0) }) {
            let afterPeriod = trimmed.index(after: lastPeriod)
            let trailing = String(trimmed[afterPeriod...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if trailing.count > 5 {
                // Avkorta ofullständig mening
                return String(trimmed[...lastPeriod])
            }
        }

        return trimmed + "."
    }

    // MARK: - Svarsmallar

    private let standardGreetings = [
        "Hej! Vad kan jag hjälpa dig med?",
        "Hej! Ställ gärna en fråga så gör jag mitt bästa.",
        "Hejsan! Jag är redo att prata.",
        "Hallå! Vad funderar du på?",
        "Hej där! Vad har du på hjärtat?",
        "Hej! Jag är här och lyssnar.",
        "Hejsan! Kul att se dig — vad vill du prata om?",
        "Hallå! Berätta, vad kan jag göra för dig?",
    ]

    private let happyGreetings = [
        "Hej! Roligt att höra från dig!",
        "Hejsan! Vad kul att du vill prata!",
        "Hallå! Jag mår bra och är redo att hjälpa!",
        "Hej! Vilken fin dag — vad ska vi utforska?",
        "Hejsan! Jag känner mig inspirerad idag!",
        "Hej! Jag har laddat batterierna och är redo!",
    ]

    private let empatheticGreetings = [
        "Hej. Jag finns här om du vill prata.",
        "Hej. Berätta vad som ligger dig på hjärtat.",
        "Hej. Ta den tid du behöver — jag lyssnar.",
        "Hej. Jag är här för dig, oavsett vad det handlar om.",
        "Hej. Ibland hjälper det att prata — jag finns här.",
        "Hej. Du behöver inte ha alla svar — vi kan tänka tillsammans.",
    ]

    private let calmingGreetings = [
        "Hej, jag förstår. Berätta vad jag kan hjälpa till med.",
        "Hej. Jag ska göra mitt bästa att hjälpa dig.",
        "Hej. Lugnt och stilla — vi tar det i din takt.",
        "Hej. Andas djupt. Jag är här och vi löser det tillsammans.",
        "Hej. Ingen stress — berätta när du är redo.",
        "Hej. Jag har all tid i världen för dig.",
    ]

    private let followUpGreetings = [
        "Visst, vad vill du veta?",
        "Ja, jag lyssnar — fortsätt gärna.",
        "Absolut, berätta mer.",
        "Självklart, jag hänger med.",
        "Javisst! Jag är nyfiken, fortsätt.",
        "Jag är med dig, säg till.",
        "Naturligtvis, vad undrar du över?",
        "Klart! Låt oss dyka djupare.",
    ]

    // MARK: - Hjälpmetod

    private func pickRandom(from options: [String]) -> String {
        options.randomElement() ?? ""
    }
}
