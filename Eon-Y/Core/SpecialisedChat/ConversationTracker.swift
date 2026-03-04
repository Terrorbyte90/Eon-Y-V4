import Foundation

// MARK: - ConversationTracker: Spårar konversationstillstånd
// Håller koll på ämnen, entiteter, referens och kontext över hela konversationen.
// Möjliggör pronomenupplösning, följdfrågedetektering och kontextmedveten respons.

struct ConversationContext: Sendable {
    let recentTopics: [String]          // Senaste 5 ämnena
    let currentTopic: String             // Aktivt ämne
    let turnCount: Int                   // Antal turer i konversationen
    let isNewConversation: Bool          // Ny konversation?
    let recentEntities: [String]         // Senaste entiteterna (namn, platser etc.)
    let conversationSummary: String      // Kort sammanfattning av konversationen
    let topicHistory: [TopicTurn]        // Ämneshistorik
    let emotionalTrajectory: EmotionalTrajectory

    struct TopicTurn: Sendable {
        let topic: String
        let turnIndex: Int
        let wasUserInitiated: Bool
    }

    struct EmotionalTrajectory: Sendable {
        let currentMood: String          // "neutral", "glad", "nyfiken", etc.
        let moodTrend: MoodTrend        // Uppåt, nedåt, stabil

        enum MoodTrend: String, Sendable {
            case improving = "uppåt"
            case declining = "nedåt"
            case stable = "stabil"
            case fluctuating = "fluktuerande"
        }
    }
}

actor ConversationTracker {
    static let shared = ConversationTracker()

    // Intern state
    private var topics: [String] = []
    private var entities: [String] = []
    private var turnCount: Int = 0
    private var topicHistory: [ConversationContext.TopicTurn] = []
    private var userMoods: [String] = []
    private var lastUserInput: String = ""
    private var lastEonResponse: String = ""
    private var conversationStartTime: Date = Date()
    private var turnSummaries: [(user: String, eon: String, topic: String)] = []

    private init() {}

    // MARK: - Kontextupplösning (anropas av ChatOrchestrator)

    func resolveContext(
        input: String,
        history: [ConversationRecord]
    ) -> ConversationContext {
        let isNew = turnCount == 0 || Date().timeIntervalSince(conversationStartTime) > 3600

        if isNew {
            resetForNewConversation()
        }

        // Detektera mood från input
        let mood = detectMood(input.lowercased())
        userMoods.append(mood)

        // Bygg sammanfattning
        let summary = buildSummary()

        // Emotionell bana
        let trajectory = buildEmotionalTrajectory()

        return ConversationContext(
            recentTopics: Array(topics.suffix(5)),
            currentTopic: topics.last ?? "",
            turnCount: turnCount,
            isNewConversation: isNew,
            recentEntities: Array(Set(entities).prefix(10)),
            conversationSummary: summary,
            topicHistory: Array(topicHistory.suffix(10)),
            emotionalTrajectory: trajectory
        )
    }

    // MARK: - Registrera tur (anropas efter att svar genererats)

    func recordTurn(
        userInput: String,
        eonResponse: String,
        topic: String,
        entities newEntities: [String]
    ) {
        turnCount += 1
        lastUserInput = userInput
        lastEonResponse = eonResponse

        // Uppdatera ämnen
        if !topic.isEmpty {
            // Flytta ämnet till toppen om det redan finns
            topics.removeAll { $0.lowercased() == topic.lowercased() }
            topics.append(topic)
            // Behåll max 20 ämnen
            if topics.count > 20 { topics.removeFirst(topics.count - 20) }
        }

        // Uppdatera entiteter
        for entity in newEntities {
            if !entities.contains(entity) {
                entities.append(entity)
            }
        }
        if entities.count > 30 { entities.removeFirst(entities.count - 30) }

        // Spara ämneshistorik
        topicHistory.append(ConversationContext.TopicTurn(
            topic: topic,
            turnIndex: turnCount,
            wasUserInitiated: true
        ))

        // Spara sammanfattning
        turnSummaries.append((
            user: String(userInput.prefix(100)),
            eon: String(eonResponse.prefix(100)),
            topic: topic
        ))
        if turnSummaries.count > 15 { turnSummaries.removeFirst() }
    }

    // MARK: - Hitta senaste referenten för pronomen

    func findReferent(for pronoun: String) -> String? {
        // Returrera senaste relevanta entitet eller ämne
        switch pronoun.lowercased() {
        case "den", "det", "detta", "denna":
            // Senaste ämne eller entitet
            return entities.last ?? topics.last
        case "han":
            return entities.last(where: { isLikelyMaleName($0) })
        case "hon":
            return entities.last(where: { isLikelyFemaleName($0) })
        case "de", "dem", "dessa":
            // Senaste plural-ämne (svårt att avgöra, returnera senaste)
            return topics.last
        default:
            return topics.last
        }
    }

    // MARK: - Senaste konversationssammanfattning för prompt

    func recentContextForPrompt(maxChars: Int = 200) -> String {
        guard !turnSummaries.isEmpty else { return "" }

        var parts: [String] = []
        var remaining = maxChars

        for summary in turnSummaries.suffix(3).reversed() {
            let entry = "Anv: \(summary.user.prefix(60)) → Eon: \(summary.eon.prefix(60))"
            if entry.count < remaining {
                parts.insert(entry, at: 0)
                remaining -= entry.count + 2
            }
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Privata hjälpmetoder

    private func resetForNewConversation() {
        topics.removeAll()
        entities.removeAll()
        turnCount = 0
        topicHistory.removeAll()
        userMoods.removeAll()
        turnSummaries.removeAll()
        conversationStartTime = Date()
    }

    private func detectMood(_ lower: String) -> String {
        if lower.contains("tack") || lower.contains("bra") || lower.contains("!") { return "glad" }
        if lower.contains("ledsen") || lower.contains("tråkig") { return "ledsen" }
        if lower.contains("arg") || lower.contains("irriterad") { return "irriterad" }
        if lower.contains("undrar") || lower.contains("?") { return "nyfiken" }
        if lower.contains("intressant") || lower.contains("spännande") { return "engagerad" }
        if lower.contains("tröt") || lower.contains("orkeslös") { return "trött" }
        return "neutral"
    }

    private func buildSummary() -> String {
        guard !turnSummaries.isEmpty else { return "Ny konversation." }

        let topicSet = Set(turnSummaries.map { $0.topic }).filter { !$0.isEmpty }
        if topicSet.isEmpty { return "Konversation med \(turnCount) turer." }

        return "Konversation om: \(topicSet.joined(separator: ", ")) (\(turnCount) turer)"
    }

    private func buildEmotionalTrajectory() -> ConversationContext.EmotionalTrajectory {
        let current = userMoods.last ?? "neutral"

        let trend: ConversationContext.EmotionalTrajectory.MoodTrend
        if userMoods.count < 2 {
            trend = .stable
        } else {
            let recent = Array(userMoods.suffix(3))
            // v24: Expanded 3→12 per set for better mood trajectory detection
            let positives = Set(["glad", "engagerad", "nyfiken", "lycklig", "nöjd", "tacksam", "exalterad", "motiverad", "inspirerad", "hoppfull", "stolt", "harmonisk"])
            let negatives = Set(["ledsen", "irriterad", "trött", "arg", "frustrerad", "orolig", "stressad", "nedstämd", "besviken", "uppgiven", "ångestfylld", "apatisk"])

            let posCount = recent.filter { positives.contains($0) }.count
            let negCount = recent.filter { negatives.contains($0) }.count

            if posCount > negCount { trend = .improving }
            else if negCount > posCount { trend = .declining }
            else if recent.count == Set(recent).count { trend = .fluctuating }
            else { trend = .stable }
        }

        return ConversationContext.EmotionalTrajectory(
            currentMood: current,
            moodTrend: trend
        )
    }

    // Enkla heuristiker för svenska namn
    private func isLikelyMaleName(_ name: String) -> Bool {
        // v24: Expanded 6→12
        let maleEndings = ["an", "er", "on", "us", "ar", "el", "en", "ard", "rik", "olf", "mund", "ias"]
        let lower = name.lowercased()
        return maleEndings.contains(where: { lower.hasSuffix($0) })
    }

    private func isLikelyFemaleName(_ name: String) -> Bool {
        // v24: Expanded 5→10
        let femaleEndings = ["a", "in", "ia", "ie", "ey", "sa", "na", "da", "ka", "tta"]
        let lower = name.lowercased()
        return femaleEndings.contains(where: { lower.hasSuffix($0) })
    }
}
