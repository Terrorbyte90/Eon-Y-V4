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

    private init() {
        loadProfile()
        Task { await loadWordStats() }
    }

    func loadWordStats() async {
        totalWordCount = await memory.totalWordCount()
        // Vokabulärstorlek: approximation baserat på unika ord i konversationer
        // Genomsnittlig unik-ord-ratio: ~40% av totala ord är unika
        uniqueVocabularySize = Int(Double(totalWordCount) * 0.40)
    }

    // MARK: - Update after conversation

    func updateAfterConversation(userMessage: String, eonResponse: String, emotion: EonEmotion, confidence: Double) async {
        // Uppdatera domänfrekvens
        let detectedDomains = detectDomains(in: userMessage)
        for domain in detectedDomains {
            if let idx = domainKnowledge.firstIndex(where: { $0.domain == domain }) {
                domainKnowledge[idx].mentionCount += 1
                domainKnowledge[idx].lastMentioned = Date()
            }
        }

        // Uppdatera kommunikationsstil
        updateCommunicationStyle(message: userMessage)

        // Uppdatera radar-data
        updateRadarData(message: userMessage)

        // Uppdatera konversationsräknare och ordräknare
        totalConversations += 1
        let msgWords = userMessage.split(separator: " ").count + eonResponse.split(separator: " ").count
        totalWordCount += msgWords
        uniqueVocabularySize = Int(Double(totalWordCount) * 0.40)

        // Uppdatera Eons beskrivning av användaren
        updateEonDescription()

        // Spara till minne
        Task {
            await memory.saveMessage(role: "user", content: userMessage, sessionId: UUID().uuidString, confidence: confidence, emotion: emotion.rawValue)
        }
    }

    // MARK: - Domain detection

    private func detectDomains(in text: String) -> [String] {
        let domainKeywords: [String: [String]] = [
            "Teknik": ["kod", "programmering", "algoritm", "dator", "app", "software", "ai", "maskininlärning"],
            "Vetenskap": ["forskning", "studie", "experiment", "teori", "hypotes", "biologi", "fysik", "kemi"],
            "Historia": ["historia", "historisk", "forntid", "krig", "revolution", "antiken", "medeltid"],
            "Psykologi": ["psykologi", "beteende", "emotion", "känsla", "ångest", "depression", "terapi"],
            "Ekonomi": ["ekonomi", "pengar", "investering", "aktier", "marknad", "inflation", "budget"],
            "Kultur": ["kultur", "konst", "musik", "film", "litteratur", "teater", "design"],
            "Språk": ["språk", "grammatik", "ord", "svenska", "engelska", "lingvistik", "etymologi"],
            "Filosofi": ["filosofi", "etik", "moral", "existens", "medvetande", "fri vilja"]
        ]

        let lower = text.lowercased()
        return domainKeywords.compactMap { domain, keywords in
            keywords.contains(where: { lower.contains($0) }) ? domain : nil
        }
    }

    // MARK: - Communication style update

    private func updateCommunicationStyle(message: String) {
        let wordCount = message.split(separator: " ").count
        let hasQuestion = message.contains("?")
        let hasFormalWords = ["emellertid", "således", "beträffande"].contains(where: { message.lowercased().contains($0) })

        // Rullande medelvärde för meddelandelängd
        let currentAvg = communicationStyle.avgMessageLength
        communicationStyle.avgMessageLength = currentAvg * 0.9 + Double(wordCount) * 0.1

        if hasQuestion { communicationStyle.questionFrequency = min(1.0, communicationStyle.questionFrequency + 0.05) }
        if hasFormalWords { communicationStyle.formalityScore = min(1.0, communicationStyle.formalityScore + 0.03) }
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
        let style = communicationStyle.avgMessageLength > 20 ? "detaljerade" : "korta"

        profile.eonDescription = "Intresserad av \(topDomains.joined(separator: ", ")). Föredrar \(style) svar. Ställer ofta följdfrågor."
    }

    // MARK: - Load/save

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: "eon_user_profile"),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = saved
        }
        totalConversations = UserDefaults.standard.integer(forKey: "eon_total_conversations")
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "eon_user_profile")
        }
        UserDefaults.standard.set(totalConversations, forKey: "eon_total_conversations")
    }
}

// MARK: - Data models

struct UserProfile: Codable {
    var eonDescription: String = "Jag lär känna dig fortfarande..."
    var knownSince: Date = Date()
    var preferredResponseLength: ResponseLength = .detailed
    var preferredTone: Tone = .semiFormai

    enum ResponseLength: String, Codable, CaseIterable {
        case brief = "Kort"
        case balanced = "Balanserat"
        case detailed = "Detaljerat"
    }

    enum Tone: String, Codable, CaseIterable {
        case formal = "Formellt"
        case semiFormai = "Halvformellt"
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
