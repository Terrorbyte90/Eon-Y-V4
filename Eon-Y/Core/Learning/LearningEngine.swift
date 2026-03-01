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
        // Starta på 0.05 — verklig nivå byggs upp från faktisk data, inte slumpmässigt
        for domain in domains {
            competencyBook[domain] = DomainCompetency(
                domain: domain,
                level: 0.05,
                knowledgeItems: [],
                lastStudied: Date(timeIntervalSince1970: 0)
            )
        }
        // Ladda persisterade nivåer från UserDefaults om de finns
        for domain in domains {
            let key = "competency_\(domain)"
            let saved = UserDefaults.standard.double(forKey: key)
            if saved > 0.0 {
                competencyBook[domain]?.level = saved
            }
        }
    }

    // v3 Claude Edition: Improved competency sync with logarithmic scaling
    // and FSRS review bonuses so competency actually grows over time
    func syncCompetenciesFromDatabase() async {
        let memory = PersistentMemoryStore.shared
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass", "böjningsform", "avledning"],
            "Syntax": ["syntax", "mening", "sats", "ordföljd", "fras"],
            "Semantik": ["semantik", "betydelse", "definition", "saldo_sense", "primär_betydelse"],
            "Pragmatik": ["pragmatik", "talakt", "implikatur", "kontext"],
            "Kausalitet": ["kausalitet", "orsak", "slutsats", "kausal"],
            "AI & Maskininlärning": ["ai", "neural", "modell", "transformer", "bert", "gpt"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception", "uppmärksamhet"],
            "Metakognition": ["metakognition", "självreflektion", "självmedvetenhet"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi", "medvetande"],
            "Historia": ["historia", "historisk", "krig", "konflikt"],
            "Psykologi": ["psykologi", "känsla", "beteende", "inlärning"],
            "Naturvetenskap": ["naturvetenskap", "fysik", "kemi", "biologi"]
        ]

        for (domain, keywords) in domainKeywords {
            var totalFacts = 0
            var uniqueSubjects: Set<String> = []
            for keyword in keywords {
                let facts = await memory.searchFacts(query: keyword, limit: 30)
                totalFacts += facts.count
                for fact in facts {
                    uniqueSubjects.insert(fact.subject)
                }
            }

            // Logarithmic scaling: many facts = high competency, diminishing returns
            // This naturally grows as more facts are added to the database
            let factScore = totalFacts > 0 ? min(0.70, 0.10 * log2(Double(totalFacts) + 1)) : 0.0

            // Diversity bonus: knowing many different subjects in a domain matters
            let diversityBonus = uniqueSubjects.count > 0 ? min(0.15, 0.03 * log2(Double(uniqueSubjects.count) + 1)) : 0.0

            // FSRS study bonus: active study drives competency
            let domainFSRSItems = fsrsItems.filter { $0.domain == domain }
            let reviewedItems = domainFSRSItems.filter { $0.reviewCount > 0 }
            let fsrsBonus = min(0.10, Double(reviewedItems.count) * 0.01)

            let newLevel = min(0.90, factScore + diversityBonus + fsrsBonus)
            if var comp = competencyBook[domain] {
                // Ratchet: competency can only increase
                // Plus gradual growth bonus if recently studied
                let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                let growthBonus = recentlyStudied ? 0.003 : 0.0
                comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                competencyBook[domain] = comp
                UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
            }
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

        // FSRS-algoritm: rating baseras på faktisk review-historik, inte slump
        // Rating 1.0 = perfekt, 0.6 = svårt men ihågkommet, 0.0 = glömt
        let reviewCount = fsrsItems[idx].reviewCount
        let lastReview = fsrsItems[idx].lastReview
        let daysSinceLast = lastReview.map { Date().timeIntervalSince($0) / 86400 } ?? 1.0

        // FSRS-4.5 förenklad: rating baseras på hur länge sedan senaste review
        // Om vi studerar i tid → hög rating; om försenat → lägre
        let scheduledInterval = fsrsItems[idx].dueDate.timeIntervalSince(lastReview ?? Date()) / 86400
        let actualInterval = daysSinceLast
        let rating: Double
        if scheduledInterval <= 0 {
            rating = 0.9  // Nytt item, antag bra
        } else {
            let ratio = actualInterval / max(scheduledInterval, 1.0)
            rating = ratio <= 1.2 ? 0.9 : ratio <= 2.0 ? 0.7 : 0.5  // I tid, lite sent, mycket sent
        }

        // FSRS-4.5 stabilitetsfunktion: S_new = S * e^(w * (rating - d))
        // w=0.14 (FSRS-4.5 parameter), d=difficulty
        let w = 0.14
        let difficulty = fsrsItems[idx].difficulty
        let newStability = max(0.1, fsrsItems[idx].stability * exp(w * (rating - difficulty)))

        // FSRS korrekt intervalformel: I = S * (-ln(R_target)) / ln(0.9) ≈ S * 10.5
        // ln(0.9) = -0.10536, så I = S * (-(-0.10536)) / (-0.10536) = S
        // Korrekt: I(r=0.9) = S * ln(0.9) / ln(0.9) = S — men det är inte rätt.
        // FSRS-4.5 spec: I = (R^(1/S) - 1) / (R^(1/S) - R) — förenkling: I = S * 9 * (1-r) + 1
        // Praktisk FSRS-4.5: interval = S * retrievability_factor
        let targetRetention = 0.9
        // Korrekt FSRS: I = S * ln(targetRetention) / ln(0.9) — men ln(0.9)/ln(0.9)=1 alltid.
        // Rätt formel är: I = -S * ln(targetRetention) (eftersom ln(0.9) < 0)
        let interval = max(1.0, newStability * (-log(targetRetention)))

        fsrsItems[idx].stability = newStability
        fsrsItems[idx].dueDate = Date().addingTimeInterval(interval * 86400)
        fsrsItems[idx].reviewCount = reviewCount + 1
        fsrsItems[idx].lastReview = Date()

        // Uppdatera kompetens baserat på faktisk rating och antal reviews
        if let domain = fsrsItems[idx].domain {
            let learningBoost = 0.005 * rating * (1.0 - (competencyBook[domain]?.level ?? 0.3))
            competencyBook[domain]?.level = min(0.99, (competencyBook[domain]?.level ?? 0.05) + learningBoost)
            competencyBook[domain]?.lastStudied = Date()
            // Persistera
            if let level = competencyBook[domain]?.level {
                UserDefaults.standard.set(level, forKey: "competency_\(domain)")
            }
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
            let topic = gap.suggestedTopics.first ?? "grundläggande \(gap.domain)"
            let knowledge = "\(gap.domain): studerar '\(topic)' (nivå: \(String(format: "%.0f", gap.currentLevel * 100))% → \(String(format: "%.0f", gap.targetLevel * 100))%)"
            generated.append(knowledge)

            // Spara kunskapslucka som faktum i databasen
            await PersistentMemoryStore.shared.saveFact(
                subject: gap.domain,
                predicate: "kunskapslucka",
                object: topic,
                confidence: 0.75,
                source: "learning_engine"
            )

            // Lägg till FSRS-item för varje föreslagen topic
            for suggestedTopic in gap.suggestedTopics.prefix(3) {
                addFSRSItem(topic: suggestedTopic, domain: gap.domain, initialDifficulty: 1.0 - gap.currentLevel)
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
        // Poängsätt varje domän baserat på nyckelordsträffar — välj den med högst poäng
        let domainKeywords: [(String, [String])] = [
            ("Morfologi",          ["morfologi", "böjning", "ordklass", "avledning", "suffix", "prefix", "sammansättning"]),
            ("Syntax",             ["syntax", "sats", "mening", "ordföljd", "fras", "grammatik", "bisats"]),
            ("Semantik",           ["semantik", "betydelse", "definition", "begrepp", "ord", "lexikon"]),
            ("Pragmatik",          ["pragmatik", "talakt", "kontext", "implikatur", "kommunikation"]),
            ("Kausalitet",         ["orsak", "kausal", "kausalitet", "verkan", "slutsats", "konsekvens"]),
            ("AI & Maskininlärning", ["ai", "neural", "modell", "transformer", "bert", "gpt", "maskininlärning", "algoritm"]),
            ("Kognitionsvetenskap", ["kognition", "medvetande", "perception", "uppmärksamhet", "minne", "tänkande"]),
            ("Metakognition",      ["metakognition", "självreflektion", "självmedvetenhet", "strategi", "lärande"]),
            ("Filosofi",           ["filosofi", "epistemologi", "ontologi", "etik", "moral", "existens"]),
            ("Historia",           ["historia", "historisk", "krig", "revolution", "civilisation", "antiken"]),
            ("Psykologi",          ["psykologi", "känsla", "beteende", "emotion", "trauma", "personlighet"]),
            ("Naturvetenskap",     ["naturvetenskap", "fysik", "kemi", "biologi", "evolution", "astronomi"]),
            ("Analogibyggande",    ["analogi", "liknelse", "metafor", "parallell", "jämförelse"]),
            ("Epistemologi",       ["epistemologi", "kunskap", "sanning", "bevis", "rättfärdigande"]),
        ]
        var bestDomain = "Kognitionsvetenskap"
        var bestScore = 0
        for (domain, keywords) in domainKeywords {
            let score = keywords.filter { lower.contains($0) }.count
            if score > bestScore {
                bestScore = score
                bestDomain = domain
            }
        }
        return bestDomain
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
