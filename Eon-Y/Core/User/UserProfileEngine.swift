import Foundation
import Combine
import SwiftUI

// MARK: - UserProfileEngine: Bygger kontinuerlig bild av användaren

@MainActor
final class UserProfileEngine: ObservableObject {
    static let shared = UserProfileEngine()

    @Published var profile: UserProfile = UserProfile()
    @Published var interestRadarData: [RadarAxis] = RadarAxis.defaultAxes
    @Published var communicationStyle: CommunicationStyle = CommunicationStyle()
    @Published var domainKnowledge: [DomainKnowledge] = DomainKnowledge.defaults
    @Published var topMemories: [UserMemory] = []
    @Published var wsdProfile: [WSDProfileEntry] = []
    @Published var totalConversations: Int = 0
    @Published var totalSessions: Int = 0
    @Published var totalWordCount: Int = 0
    @Published var uniqueVocabularySize: Int = 0

    private let memory = PersistentMemoryStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var isPreviewInstance: Bool = false

    private init() {
        // Skydda mot Preview-sandbox — UserDefaults är ok men Tasks mot DB kraschar
        let inPreviewSandbox = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isPreviewInstance = inPreviewSandbox
        guard !inPreviewSandbox else { return }
        loadProfile()
        Task { await loadWordStats() }
    }

    // Lätt preview-instans — ingen DB, inga Tasks
    static func preview() -> UserProfileEngine {
        let e = UserProfileEngine()
        e.totalConversations = 7
        e.totalWordCount = 1240
        e.uniqueVocabularySize = 496
        e.profile.eonDescription = "Intresserad av teknik och AI. Föredrar detaljerade svar."
        return e
    }

    private var knownUniqueWords: Set<String> = []

    func loadWordStats() async {
        totalWordCount = await memory.totalWordCount()
        // Use actual unique word tracking if available, otherwise use Heap's law approximation
        // Heap's law: V = K * N^β where K ≈ 20-50 for natural language, β ≈ 0.4-0.6
        if knownUniqueWords.isEmpty {
            // Approximate using Heap's law: V ≈ 30 * N^0.5 (conservative estimate for Swedish)
            let n = Double(totalWordCount)
            uniqueVocabularySize = n > 0 ? Int(30.0 * pow(n, 0.5)) : 0
        } else {
            uniqueVocabularySize = knownUniqueWords.count
        }
    }

    // Track emotional patterns across conversations
    private var emotionHistory: [(emotion: String, date: Date)] = []
    // Track session continuity
    private var currentSessionId: String = UUID().uuidString
    private var sessionStartTime: Date = Date()
    private var sessionMessageCount: Int = 0

    // MARK: - Update after conversation

    func updateAfterConversation(userMessage: String, eonResponse: String, emotion: EonEmotion, confidence: Double) async {
        // Uppdatera domänfrekvens
        let detectedDomains = detectDomains(in: userMessage)
        for domain in detectedDomains {
            if let idx = domainKnowledge.firstIndex(where: { $0.domain == domain }) {
                domainKnowledge[idx].mentionCount += 1
                domainKnowledge[idx].lastMentioned = Date()
                // Update estimated level based on mention frequency and conversation depth
                updateDomainLevel(at: idx)
            }
        }

        // Intresse-decay borttagen — Eon glömmer aldrig sin användare.
        // Radar-data behålls permanent för att bygga en stabil bild av användaren.

        // Uppdatera kommunikationsstil (enhanced)
        updateCommunicationStyle(message: userMessage)

        // Uppdatera radar-data
        updateRadarData(message: userMessage)

        // Track emotion patterns
        emotionHistory.append((emotion.rawValue, Date()))
        if emotionHistory.count > 100 { emotionHistory.removeFirst(50) }

        // Uppdatera konversationsräknare och ordräknare
        totalConversations += 1
        sessionMessageCount += 1
        let userWords = userMessage.lowercased().split(separator: " ").map(String.init)
        let eonWords = eonResponse.lowercased().split(separator: " ").map(String.init)
        let msgWords = userWords.count + eonWords.count
        totalWordCount += msgWords
        for word in userWords where word.count > 2 {
            knownUniqueWords.insert(word)
        }
        uniqueVocabularySize = knownUniqueWords.isEmpty
            ? Int(30.0 * pow(Double(totalWordCount), 0.5))
            : knownUniqueWords.count

        // Uppdatera Eons beskrivning av användaren (enhanced)
        updateEonDescription()

        // Auto-detect response length preference from user behavior
        inferResponsePreferences(userMessage: userMessage, eonResponse: eonResponse)

        // Spara till minne (ej i preview-sandbox)
        guard !isPreviewInstance else { return }
        // Reset session after 30 min inactivity
        if Date().timeIntervalSince(sessionStartTime) > 1800 {
            currentSessionId = UUID().uuidString
            sessionStartTime = Date()
            sessionMessageCount = 0
            totalSessions += 1
        }
        Task {
            await memory.saveMessage(role: "user", content: userMessage, sessionId: currentSessionId, confidence: confidence, emotion: emotion.rawValue)
        }
    }

    /// Infer user preferences from their behavior
    private func inferResponsePreferences(userMessage: String, eonResponse: String) {
        let msgLength = userMessage.split(separator: " ").count
        // Users who write long messages likely want detailed responses
        if msgLength > 40 && profile.preferredResponseLength != .detailed {
            profile.preferredResponseLength = .detailed
        } else if msgLength < 8 && totalConversations > 10 && profile.preferredResponseLength == .detailed {
            // Consistently short messages suggest preference for brevity
            profile.preferredResponseLength = .balanced
        }
    }

    /// Update domain knowledge level based on accumulated mentions
    private func updateDomainLevel(at idx: Int) {
        let mentions = domainKnowledge[idx].mentionCount
        let newLevel: DomainKnowledge.KnowledgeLevel
        switch mentions {
        case 0..<3:   newLevel = .novice
        case 3..<10:  newLevel = .beginner
        case 10..<25: newLevel = .intermediate
        case 25..<50: newLevel = .advanced
        default:      newLevel = .expert
        }
        domainKnowledge[idx].estimatedLevel = newLevel
    }

    // MARK: - Domain detection

    private func detectDomains(in text: String) -> [String] {
        let domainKeywords: [String: [(keyword: String, weight: Int)]] = [
            "Teknik": [("kod", 2), ("programmering", 3), ("algoritm", 3), ("dator", 2), ("app", 2), ("software", 3),
                       ("ai", 2), ("maskininlärning", 3), ("neural", 2), ("databas", 2), ("server", 2), ("swift", 3),
                       ("python", 3), ("javascript", 3), ("api", 2), ("ramverk", 2), ("bugg", 2)],
            "Vetenskap": [("forskning", 3), ("studie", 2), ("experiment", 3), ("teori", 2), ("hypotes", 3),
                         ("biologi", 3), ("fysik", 3), ("kemi", 3), ("molekyl", 2), ("evolution", 3), ("gen", 2)],
            "Historia": [("historia", 3), ("historisk", 2), ("forntid", 2), ("krig", 2), ("revolution", 2),
                        ("antiken", 3), ("medeltid", 3), ("civilisation", 2), ("monarki", 2), ("arkeologi", 3)],
            "Psykologi": [("psykologi", 3), ("beteende", 2), ("emotion", 2), ("känsla", 2), ("ångest", 2),
                         ("depression", 2), ("terapi", 2), ("kognitiv", 2), ("personlighet", 2), ("trauma", 2)],
            "Ekonomi": [("ekonomi", 3), ("pengar", 2), ("investering", 3), ("aktier", 2), ("marknad", 2),
                       ("inflation", 2), ("budget", 2), ("finans", 3), ("skatt", 2), ("handel", 2)],
            "Kultur": [("kultur", 3), ("konst", 2), ("musik", 2), ("film", 2), ("litteratur", 3),
                      ("teater", 2), ("design", 2), ("arkitektur", 2), ("museum", 2), ("poesi", 2)],
            "Språk": [("språk", 2), ("grammatik", 3), ("ord", 1), ("svenska", 2), ("engelska", 2),
                     ("lingvistik", 3), ("etymologi", 3), ("dialekt", 2), ("uttal", 2), ("ordförråd", 2)],
            "Filosofi": [("filosofi", 3), ("etik", 2), ("moral", 2), ("existens", 2), ("medvetande", 2),
                        ("fri vilja", 3), ("ontologi", 3), ("epistemologi", 3), ("logik", 2)],
            "Matematik": [("matematik", 3), ("ekvation", 3), ("algebra", 3), ("geometri", 3), ("statistik", 3),
                         ("kalkyl", 2), ("bevis", 2), ("tal", 1), ("formel", 2)],
        ]

        let lower = text.lowercased()
        return domainKeywords.compactMap { domain, keywords in
            let score = keywords.reduce(0) { sum, kw in lower.contains(kw.keyword) ? sum + kw.weight : sum }
            return score >= 2 ? domain : nil // Require minimum score of 2 (not just any single-word match)
        }
    }

    // MARK: - Communication style update

    private func updateCommunicationStyle(message: String) {
        let lower = message.lowercased()
        let wordCount = message.split(separator: " ").count
        let hasQuestion = message.contains("?")

        // Formality detection — expanded word lists
        let formalWords = ["emellertid", "således", "beträffande", "avseende", "vederbörande",
                          "härav", "därtill", "emedan", "härmed", "dock", "icke"]
        let informalWords = ["typ", "liksom", "asså", "va", "grejen", "kul", "gött", "nice",
                           "fett", "soft", "skit", "lol", "haha"]

        let formalHits = formalWords.filter { lower.contains($0) }.count
        let informalHits = informalWords.filter { lower.contains($0) }.count

        // Rolling average for message length (more responsive: 0.85/0.15)
        communicationStyle.avgMessageLength = communicationStyle.avgMessageLength * 0.85 + Double(wordCount) * 0.15

        // Question frequency with decay for non-question messages
        if hasQuestion {
            communicationStyle.questionFrequency = min(1.0, communicationStyle.questionFrequency + 0.06)
        } else {
            communicationStyle.questionFrequency = max(0.0, communicationStyle.questionFrequency - 0.01) // Gentle decay
        }

        // Formality: bidirectional — formal words increase, informal decrease
        if formalHits > 0 {
            communicationStyle.formalityScore = min(1.0, communicationStyle.formalityScore + Double(formalHits) * 0.03)
        }
        if informalHits > 0 {
            communicationStyle.formalityScore = max(0.0, communicationStyle.formalityScore - Double(informalHits) * 0.03)
        }

        // Humor detection
        let humorSignals = ["haha", "lol", "😂", "🤣", "xD", "skämt", "rolig"]
        if humorSignals.contains(where: { lower.contains($0) }) {
            communicationStyle.humorAppreciation = min(1.0, communicationStyle.humorAppreciation + 0.04)
        }

        // Directness: short imperative messages suggest directness
        if wordCount < 6 && !hasQuestion {
            communicationStyle.directnessPreference = min(1.0, communicationStyle.directnessPreference + 0.02)
        } else if wordCount > 20 {
            communicationStyle.directnessPreference = max(0.0, communicationStyle.directnessPreference - 0.01)
        }
    }

    // MARK: - Radar update

    private func updateRadarData(message: String) {
        let domains = detectDomains(in: message)
        for domain in domains {
            if let idx = interestRadarData.firstIndex(where: { $0.label == domain }) {
                interestRadarData[idx].value = min(1.0, interestRadarData[idx].value + 0.02)
            }
        }
    }

    // MARK: - Eon's description of user

    private func updateEonDescription() {
        let topDomains = domainKnowledge.sorted { $0.mentionCount > $1.mentionCount }.prefix(3).map { $0.domain }

        // Length preference description
        let lengthDesc: String
        switch communicationStyle.avgMessageLength {
        case ..<8:   lengthDesc = "korta och koncisa"
        case 8..<20: lengthDesc = "balanserade"
        default:     lengthDesc = "detaljerade och utförliga"
        }

        // Formality description
        let formalityDesc: String
        switch communicationStyle.formalityScore {
        case ..<0.3: formalityDesc = "Informell kommunikationsstil"
        case 0.3..<0.6: formalityDesc = "Balanserad ton"
        default:     formalityDesc = "Formell kommunikationsstil"
        }

        // Personality traits from behavior
        var traits: [String] = []
        if communicationStyle.questionFrequency > 0.5 { traits.append("nyfiken och frågvis") }
        if communicationStyle.directnessPreference > 0.6 { traits.append("direkt och handlingskraftig") }
        if communicationStyle.humorAppreciation > 0.5 { traits.append("uppskattar humor") }
        if uniqueVocabularySize > 500 { traits.append("rikt ordförråd") }

        // Emotional pattern
        let recentEmotions = emotionHistory.suffix(10).map { $0.emotion }
        let emotionDesc: String
        if recentEmotions.filter({ $0 == "nyfiken" || $0 == "glad" }).count > 5 {
            emotionDesc = "Generellt positiv och engagerad"
        } else if recentEmotions.filter({ $0 == "fundersam" || $0 == "orolig" }).count > 5 {
            emotionDesc = "Reflekterande och eftertänksam"
        } else {
            emotionDesc = ""
        }

        // Build dynamic description
        var desc = "Intresserad av \(topDomains.joined(separator: ", ")). "
        desc += "Föredrar \(lengthDesc) svar. "
        desc += "\(formalityDesc). "
        if !traits.isEmpty { desc += "Personlighet: \(traits.joined(separator: ", ")). " }
        if !emotionDesc.isEmpty { desc += emotionDesc + ". " }
        desc += "\(totalConversations) konversationer, \(uniqueVocabularySize) unika ord."

        profile.eonDescription = desc
    }

    // MARK: - Load/save

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: "eon_user_profile"),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = saved
        }
        totalConversations = UserDefaults.standard.integer(forKey: "eon_total_conversations")
        totalSessions = UserDefaults.standard.integer(forKey: "eon_total_sessions")
        // Restore communication style
        communicationStyle.formalityScore = UserDefaults.standard.double(forKey: "eon_formality_score")
        communicationStyle.questionFrequency = UserDefaults.standard.double(forKey: "eon_question_freq")
        communicationStyle.humorAppreciation = UserDefaults.standard.double(forKey: "eon_humor_score")
        if communicationStyle.formalityScore == 0 && totalConversations == 0 {
            communicationStyle.formalityScore = 0.4 // Default
        }
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "eon_user_profile")
        }
        UserDefaults.standard.set(totalConversations, forKey: "eon_total_conversations")
        UserDefaults.standard.set(totalSessions, forKey: "eon_total_sessions")
        UserDefaults.standard.set(communicationStyle.formalityScore, forKey: "eon_formality_score")
        UserDefaults.standard.set(communicationStyle.questionFrequency, forKey: "eon_question_freq")
        UserDefaults.standard.set(communicationStyle.humorAppreciation, forKey: "eon_humor_score")
    }
}

// MARK: - Data models

struct UserProfile: Codable {
    var eonDescription: String = "Jag lär känna dig fortfarande..."
    var knownSince: Date = Date()
    var preferredResponseLength: ResponseLength = .detailed
    var preferredTone: Tone = .semiFormal

    enum ResponseLength: String, Codable, CaseIterable {
        case brief = "Kort"
        case balanced = "Balanserat"
        case detailed = "Detaljerat"
    }

    enum Tone: String, Codable, CaseIterable {
        case formal = "Formellt"
        case semiFormal = "Halvformellt"
        case casual = "Informellt"
    }
}

struct RadarAxis: Identifiable {
    let id = UUID()
    var label: String
    var value: Double // 0-1

    static let defaultAxes: [RadarAxis] = [
        RadarAxis(label: "Teknik", value: 0.1),
        RadarAxis(label: "Vetenskap", value: 0.1),
        RadarAxis(label: "Historia", value: 0.1),
        RadarAxis(label: "Psykologi", value: 0.1),
        RadarAxis(label: "Ekonomi", value: 0.1),
        RadarAxis(label: "Kultur", value: 0.1),
        RadarAxis(label: "Språk", value: 0.1),
        RadarAxis(label: "Filosofi", value: 0.1)
    ]
}

struct CommunicationStyle {
    var avgMessageLength: Double = 15.0
    var questionFrequency: Double = 0.3
    var formalityScore: Double = 0.4
    var humorAppreciation: Double = 0.5
    var directnessPreference: Double = 0.7
}

struct DomainKnowledge: Identifiable {
    let id = UUID()
    var domain: String
    var estimatedLevel: KnowledgeLevel
    var mentionCount: Int = 0
    var lastMentioned: Date = Date()

    enum KnowledgeLevel: Int, CaseIterable {
        case novice = 0, beginner, intermediate, advanced, expert

        var label: String {
            switch self {
            case .novice: return "Nybörjare"
            case .beginner: return "Grundläggande"
            case .intermediate: return "Mellannivå"
            case .advanced: return "Avancerad"
            case .expert: return "Expert"
            }
        }

        var color: Color {
            let colors: [Color] = [
                Color(hex: "#93C5FD"),
                Color(hex: "#60A5FA"),
                Color(hex: "#818CF8"),
                Color(hex: "#7C3AED"),
                Color(hex: "#4C1D95")
            ]
            return colors[rawValue]
        }
    }

    static let defaults: [DomainKnowledge] = [
        DomainKnowledge(domain: "Teknik", estimatedLevel: .intermediate),
        DomainKnowledge(domain: "Vetenskap", estimatedLevel: .beginner),
        DomainKnowledge(domain: "Historia", estimatedLevel: .beginner),
        DomainKnowledge(domain: "Psykologi", estimatedLevel: .novice),
        DomainKnowledge(domain: "Ekonomi", estimatedLevel: .novice),
        DomainKnowledge(domain: "Kultur", estimatedLevel: .beginner),
        DomainKnowledge(domain: "Språk", estimatedLevel: .intermediate),
        DomainKnowledge(domain: "Filosofi", estimatedLevel: .novice),
        DomainKnowledge(domain: "Matematik", estimatedLevel: .novice),
        DomainKnowledge(domain: "Biologi", estimatedLevel: .novice),
        DomainKnowledge(domain: "Fysik", estimatedLevel: .novice),
        DomainKnowledge(domain: "Litteratur", estimatedLevel: .novice)
    ]
}

struct UserMemory: Identifiable {
    let id = UUID()
    let description: String
    let date: Date
    let emotionalWeight: Double
    let domain: String
}

struct WSDProfileEntry: Identifiable {
    let id = UUID()
    let word: String
    let preferredSense: String
    let confidence: Double
    let occurrenceCount: Int
}
