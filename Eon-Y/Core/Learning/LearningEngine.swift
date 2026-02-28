import Foundation

// MARK: - LearningEngine
// Eons kontinuerliga inlärningssystem.
// Kombinerar: FSRS spaced repetition, meta-learning, LoRA-simulering,
// kompetensbok per domän, och adaptiv inlärningsschemaläggning.
// Målet: gå från sten till professor autonomt.

actor LearningEngine {
    static let shared = LearningEngine()

    // MARK: - Tillstånd

    private var competencyBook: [String: DomainCompetency] = [:]
    private var fsrsItems: [FSRSItem] = []
    private var learningSchedule: [ScheduledLesson] = []
    private var loraSimVersion: Int = 1
    private var totalLearningCycles: Int = 0
    private var knowledgeGaps: [KnowledgeGap] = []

    private init() {
        initializeCompetencies()
    }

    private func initializeCompetencies() {
        let domains = [
            "Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs",
            "Kausalitet", "Analogibyggande", "Metakognition", "Epistemologi",
            "AI & Maskininlärning", "Kognitionsvetenskap", "Filosofi",
            "Historia", "Psykologi", "Naturvetenskap"
        ]
        for domain in domains {
            competencyBook[domain] = DomainCompetency(
                domain: domain,
                level: Double.random(in: 0.1...0.4),
                knowledgeItems: [],
                lastStudied: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )
        }
    }

    // MARK: - Inlärningscykel

    func runLearningCycle() async -> LearningCycleResult {
        totalLearningCycles += 1

        // 1. Identifiera kunskapsluckor
        let gaps = identifyKnowledgeGaps()
        knowledgeGaps = gaps

        // 2. Välj vad som ska studeras (FSRS-baserat)
        let dueItems = getDueItems()

        // 3. Studera och uppdatera kompetens
        var studiedItems: [String] = []
        for item in dueItems.prefix(5) {
            await studyItem(item)
            studiedItems.append(item.topic)
        }

        // 4. Generera ny kunskap från luckor
        let newKnowledge = await generateKnowledgeForGaps(gaps.prefix(3).map { $0 })

        // 5. Uppdatera LoRA-simulering
        if totalLearningCycles % 10 == 0 {
            loraSimVersion += 1
        }

        return LearningCycleResult(
            cycleNumber: totalLearningCycles,
            studiedTopics: studiedItems,
            newKnowledge: newKnowledge,
            gapsIdentified: gaps.count,
            loraVersion: loraSimVersion
        )
    }

    // MARK: - FSRS (Free Spaced Repetition Scheduler)

    private func getDueItems() -> [FSRSItem] {
        let now = Date()
        return fsrsItems.filter { $0.dueDate <= now }.sorted { $0.priority > $1.priority }
    }

    private func studyItem(_ item: FSRSItem) async {
        guard let idx = fsrsItems.firstIndex(where: { $0.id == item.id }) else { return }

        // FSRS-algoritm: uppdatera stabilitet och nästa repetition
        let rating = Double.random(in: 0.6...1.0)  // Simulerat inlärningsresultat
        let newStability = fsrsItems[idx].stability * (1.0 + 0.1 * rating)
        let interval = max(1.0, newStability * log(0.9) / log(0.9))  // Förenklad FSRS

        fsrsItems[idx].stability = newStability
        fsrsItems[idx].dueDate = Date().addingTimeInterval(interval * 86400)
        fsrsItems[idx].reviewCount += 1
        fsrsItems[idx].lastReview = Date()

        // Uppdatera kompetens
        if let domain = fsrsItems[idx].domain {
            competencyBook[domain]?.level = min(0.99, (competencyBook[domain]?.level ?? 0.3) + 0.01 * rating)
            competencyBook[domain]?.lastStudied = Date()
        }
    }

    func addFSRSItem(topic: String, domain: String, initialDifficulty: Double = 0.3) {
        let item = FSRSItem(
            topic: topic,
            domain: domain,
            stability: 1.0,
            difficulty: initialDifficulty,
            dueDate: Date().addingTimeInterval(86400),
            reviewCount: 0
        )
        fsrsItems.append(item)
        if fsrsItems.count > 1000 { fsrsItems.removeFirst(100) }
    }

    // MARK: - Kunskapsluckor

    private func identifyKnowledgeGaps() -> [KnowledgeGap] {
        var gaps: [KnowledgeGap] = []

        for (domain, competency) in competencyBook {
            if competency.level < 0.5 {
                let urgency = (0.5 - competency.level) * 2.0
                gaps.append(KnowledgeGap(
                    domain: domain,
                    currentLevel: competency.level,
                    targetLevel: min(1.0, competency.level + 0.3),
                    urgency: urgency,
                    suggestedTopics: suggestTopics(for: domain, level: competency.level)
                ))
            }
        }

        return gaps.sorted { $0.urgency > $1.urgency }
    }

    private func suggestTopics(for domain: String, level: Double) -> [String] {
        let topicMap: [String: [[String]]] = [
            "Morfologi": [
                ["Grundläggande böjning", "Ordklasser", "Sammansättningar"],
                ["Avledning", "Prefixer", "Suffixer"],
                ["Produktiva mönster", "Oregelbundna former", "Historisk morfologi"]
            ],
            "Kausalitet": [
                ["Orsak-verkan", "Korrelation vs kausalitet"],
                ["Kausala kedjor", "Kontrafaktisk analys"],
                ["Kausala grafer", "Interventionslogik", "Counterfactuals"]
            ],
            "AI & Maskininlärning": [
                ["Neurala nätverk", "Backpropagation", "Aktiveringar"],
                ["Transformers", "Attention", "BERT/GPT"],
                ["RLHF", "Constitutional AI", "Alignment"]
            ],
        ]

        let levelIdx = level < 0.33 ? 0 : level < 0.66 ? 1 : 2
        return topicMap[domain]?[safe: levelIdx] ?? ["Grundläggande \(domain)", "Avancerad \(domain)"]
    }

    private func generateKnowledgeForGaps(_ gaps: [KnowledgeGap]) async -> [String] {
        var generated: [String] = []
        for gap in gaps {
            let knowledge = "Ny kunskap i \(gap.domain): \(gap.suggestedTopics.first ?? "grundläggande koncept") (nivå: \(String(format: "%.0f", gap.currentLevel * 100))% → \(String(format: "%.0f", gap.targetLevel * 100))%)"
            generated.append(knowledge)

            // Spara i persistent store
            Task.detached(priority: .background) {
                await PersistentMemoryStore.shared.saveFact(
                    subject: gap.domain,
                    predicate: "kunskapslucka_fylld",
                    object: gap.suggestedTopics.first ?? "okänt",
                    confidence: 0.7,
                    source: "learning_engine"
                )
            }
        }
        return generated
    }

    // MARK: - Meta-learning

    func metaLearnFromConversation(userMessage: String, eonResponse: String, feedback: Double) async {
        // Identifiera domän
        let domain = detectDomain(from: userMessage + " " + eonResponse)

        // Uppdatera kompetens baserat på feedback
        if var competency = competencyBook[domain] {
            let delta = (feedback - 0.5) * 0.05
            competency.level = min(0.99, max(0.01, competency.level + delta))
            competencyBook[domain] = competency
        }

        // Lägg till FSRS-item för svaga punkter
        if feedback < 0.5 {
            let topic = extractMainTopic(from: userMessage)
            addFSRSItem(topic: topic, domain: domain, initialDifficulty: 0.7)
        }
    }

    // MARK: - Statistik

    func competencySnapshot() -> [DomainCompetency] {
        competencyBook.values.sorted { $0.level > $1.level }
    }

    func overallCompetencyLevel() -> Double {
        let levels = competencyBook.values.map { $0.level }
        return levels.isEmpty ? 0.3 : levels.reduce(0, +) / Double(levels.count)
    }

    func topStrengths(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level > $1.level }.prefix(limit))
    }

    func topWeaknesses(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level < $1.level }.prefix(limit))
    }

    // MARK: - Helpers

    private func detectDomain(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("morfologi") || lower.contains("böjning") || lower.contains("ord") { return "Morfologi" }
        if lower.contains("ai") || lower.contains("neural") || lower.contains("modell") { return "AI & Maskininlärning" }
        if lower.contains("orsak") || lower.contains("kausal") { return "Kausalitet" }
        if lower.contains("filosofi") || lower.contains("medvetande") { return "Filosofi" }
        if lower.contains("psykologi") || lower.contains("känsla") { return "Psykologi" }
        if lower.contains("historia") || lower.contains("krig") { return "Historia" }
        return "Kognitionsvetenskap"
    }

    private func extractMainTopic(from text: String) -> String {
        let words = text.split(separator: " ").map(String.init).filter { $0.count > 4 }
        return words.first ?? "okänt ämne"
    }
}

// MARK: - Data Models

struct DomainCompetency: Identifiable {
    let id = UUID()
    let domain: String
    var level: Double          // 0..1 (sten=0, professor=1)
    var knowledgeItems: [String]
    var lastStudied: Date

    var levelLabel: String {
        switch level {
        case 0.8...: return "Expert"
        case 0.6..<0.8: return "Avancerad"
        case 0.4..<0.6: return "Medel"
        case 0.2..<0.4: return "Nybörjare"
        default: return "Grundläggande"
        }
    }
}

struct FSRSItem: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String?
    var stability: Double
    var difficulty: Double
    var dueDate: Date
    var reviewCount: Int
    var lastReview: Date?
    var priority: Double { stability * (1.0 - difficulty) }
}

struct ScheduledLesson: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String
    let scheduledAt: Date
    var completed: Bool = false
}

struct KnowledgeGap: Identifiable {
    let id = UUID()
    let domain: String
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let suggestedTopics: [String]
}

struct LearningCycleResult {
    let cycleNumber: Int
    let studiedTopics: [String]
    let newKnowledge: [String]
    let gapsIdentified: Int
    let loraVersion: Int
}

// MARK: - Array safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
