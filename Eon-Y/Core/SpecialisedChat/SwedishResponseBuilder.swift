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
        ]
        return pickRandom(from: templates)
    }

    // MARK: - Empatiskt svar

    func buildEmpatheticResponse(input: String) -> String {
        let lower = input.lowercased()

        if lower.contains("ledsen") || lower.contains("sorg") {
            return pickRandom(from: [
                "Det låter som att du har det tufft. Jag lyssnar gärna.",
                "Jag förstår att det känns jobbigt. Vill du berätta mer?",
                "Det är helt okej att känna så. Jag finns här.",
            ])
        }

        if lower.contains("glad") || lower.contains("bra") {
            return pickRandom(from: [
                "Vad roligt att höra! Det gläder mig.",
                "Det värmer att du mår bra!",
            ])
        }

        return "Jag hör dig. Berätta mer om du vill."
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
                           "Mer specifikt", "Med andra ord"]
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
    ]

    private let happyGreetings = [
        "Hej! Roligt att höra från dig!",
        "Hejsan! Vad kul att du vill prata!",
        "Hallå! Jag mår bra och är redo att hjälpa!",
    ]

    private let empatheticGreetings = [
        "Hej. Jag finns här om du vill prata.",
        "Hej. Berätta vad som ligger dig på hjärtat.",
    ]

    private let calmingGreetings = [
        "Hej, jag förstår. Berätta vad jag kan hjälpa till med.",
        "Hej. Jag ska göra mitt bästa att hjälpa dig.",
    ]

    private let followUpGreetings = [
        "Visst, vad vill du veta?",
        "Ja, jag lyssnar — fortsätt gärna.",
        "Absolut, berätta mer.",
    ]

    // MARK: - Hjälpmetod

    private func pickRandom(from options: [String]) -> String {
        options.randomElement() ?? options[0]
    }
}
