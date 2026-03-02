import Foundation
import NaturalLanguage

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
        let domains = [
            "Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs",
            "Kausalitet", "Analogibyggande", "Metakognition", "Epistemologi",
            "AI & Maskininlärning", "Kognitionsvetenskap", "Filosofi",
            "Historia", "Psykologi", "Naturvetenskap"
        ]
        for domain in domains {
            competencyBook[domain] = DomainCompetency(
                domain: domain,
                level: 0.05,
                knowledgeItems: [],
                lastStudied: Date(timeIntervalSince1970: 0)
            )
        }
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

    // MARK: - Domain Interaction Matrix
    // Models how learning in one domain accelerates learning in related domains
    private let domainInteractions: [String: [(target: String, strength: Double)]] = [
        "Morfologi":           [("Syntax", 0.6), ("Semantik", 0.4), ("Diskurs", 0.2)],
        "Syntax":              [("Morfologi", 0.5), ("Pragmatik", 0.4), ("Semantik", 0.3)],
        "Semantik":            [("Pragmatik", 0.5), ("Morfologi", 0.3), ("Kognitionsvetenskap", 0.2)],
        "Pragmatik":           [("Diskurs", 0.6), ("Semantik", 0.4), ("Psykologi", 0.3)],
        "Diskurs":             [("Pragmatik", 0.5), ("Semantik", 0.3)],
        "Kausalitet":          [("Filosofi", 0.5), ("Kognitionsvetenskap", 0.4), ("Naturvetenskap", 0.3)],
        "AI & Maskininlärning":[("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Epistemologi", 0.2)],
        "Kognitionsvetenskap": [("Psykologi", 0.6), ("Metakognition", 0.5), ("AI & Maskininlärning", 0.3)],
        "Metakognition":       [("Kognitionsvetenskap", 0.5), ("Epistemologi", 0.4), ("Psykologi", 0.3)],
        "Filosofi":            [("Epistemologi", 0.7), ("Kausalitet", 0.4), ("Psykologi", 0.2)],
        "Epistemologi":        [("Filosofi", 0.6), ("Metakognition", 0.4), ("Kausalitet", 0.3)],
        "Historia":            [("Filosofi", 0.3), ("Psykologi", 0.2)],
        "Psykologi":           [("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Metakognition", 0.3)],
        "Naturvetenskap":      [("Kausalitet", 0.4), ("Epistemologi", 0.3)],
        "Analogibyggande":     [("Kognitionsvetenskap", 0.4), ("Kausalitet", 0.3), ("Filosofi", 0.2)],
    ]

    // Track topic depth per domain — how deep we've gone into each topic
    private var topicDepthTracker: [String: [String: Int]] = [:] // domain -> topic -> depth level

    // MARK: - Inlärningscykel

    func runLearningCycle() async -> LearningCycleResult {
        totalLearningCycles += 1

        // 1. Identifiera kunskapsluckor
        let gaps = identifyKnowledgeGaps()
        knowledgeGaps = gaps

        // 2. Välj vad som ska studeras (FSRS-baserat)
        let dueItems = getDueItems()

        // 3. Studera och uppdatera kompetens (adaptive batch size based on gap urgency)
        let batchSize = gaps.first.map { $0.urgency > 1.5 ? 7 : 5 } ?? 5
        var studiedItems: [String] = []
        for item in dueItems.prefix(batchSize) {
            await studyItem(item)
            studiedItems.append(item.topic)
        }

        // 4. Generera ny kunskap från luckor
        let newKnowledge = await generateKnowledgeForGaps(gaps.prefix(3).map { $0 })

        // 5. Propagate cross-domain learning via interaction matrix
        await propagateDomainInteractions(studiedDomains: Set(dueItems.prefix(batchSize).compactMap { $0.domain }))

        // 6. Uppdatera LoRA-simulering
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

    /// Propagate learning gains across related domains
    private func propagateDomainInteractions(studiedDomains: Set<String>) async {
        for domain in studiedDomains {
            guard let interactions = domainInteractions[domain],
                  let sourceLevel = competencyBook[domain]?.level else { continue }
            for interaction in interactions {
                guard var target = competencyBook[interaction.target] else { continue }
                // Transfer is proportional to source level, interaction strength, and target room to grow
                let roomToGrow = 1.0 - target.level
                let transfer = sourceLevel * interaction.strength * roomToGrow * 0.003
                if transfer > 0.0005 {
                    target.level = min(0.95, target.level + transfer)
                    competencyBook[interaction.target] = target
                }
            }
        }
    }

    // MARK: - FSRS (Free Spaced Repetition Scheduler)

    private func getDueItems() -> [FSRSItem] {
        let now = Date()
        return fsrsItems.filter { $0.dueDate <= now }.sorted { $0.priority > $1.priority }
    }

    private func studyItem(_ item: FSRSItem) async {
        guard let idx = fsrsItems.firstIndex(where: { $0.id == item.id }) else { return }

        let reviewCount = fsrsItems[idx].reviewCount
        let lastReview = fsrsItems[idx].lastReview
        let daysSinceLast = lastReview.map { Date().timeIntervalSince($0) / 86400 } ?? 1.0

        // Rating based on timeliness of review
        let scheduledInterval = fsrsItems[idx].dueDate.timeIntervalSince(lastReview ?? Date()) / 86400
        let actualInterval = daysSinceLast
        let rating: Double
        if scheduledInterval <= 0 {
            rating = 0.9
        } else {
            let ratio = actualInterval / max(scheduledInterval, 1.0)
            rating = ratio <= 1.2 ? 0.9 : ratio <= 2.0 ? 0.7 : ratio <= 3.0 ? 0.4 : 0.2
        }

        // FSRS-4.5 stability update
        let w = 0.14
        var difficulty = fsrsItems[idx].difficulty
        let newStability = max(0.1, fsrsItems[idx].stability * exp(w * (rating - difficulty)))

        // Adaptive difficulty: difficulty converges toward actual performance
        // High ratings → easier, low ratings → harder
        let difficultyDelta = 0.1 * (0.7 - rating) // rating < 0.7 increases difficulty
        difficulty = min(1.0, max(0.05, difficulty + difficultyDelta))

        // FSRS interval: I = S * 9 * (1 - R_target) + 1
        let targetRetention = 0.9
        let interval = max(1.0, newStability * 9.0 * (1.0 - targetRetention) + 1.0)

        fsrsItems[idx].stability = newStability
        fsrsItems[idx].difficulty = difficulty
        fsrsItems[idx].dueDate = Date().addingTimeInterval(interval * 86400)
        fsrsItems[idx].reviewCount = reviewCount + 1
        fsrsItems[idx].lastReview = Date()

        // Track topic depth: each successful review deepens understanding
        if let domain = fsrsItems[idx].domain, rating >= 0.7 {
            var domainDepth = topicDepthTracker[domain] ?? [:]
            let currentDepth = domainDepth[item.topic] ?? 0
            domainDepth[item.topic] = min(5, currentDepth + 1) // Max depth level 5
            topicDepthTracker[domain] = domainDepth
        }

        // Update competency based on rating, review count, and mastery trajectory
        if let domain = fsrsItems[idx].domain {
            let masteryFactor = min(1.0, Double(reviewCount + 1) / 5.0) // Full mastery after 5 reviews
            let learningBoost = 0.005 * rating * masteryFactor * (1.0 - (competencyBook[domain]?.level ?? 0.3))
            competencyBook[domain]?.level = min(0.99, (competencyBook[domain]?.level ?? 0.05) + learningBoost)
            competencyBook[domain]?.lastStudied = Date()
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

    // Prerequisite chains: domain A should be learned before domain B
    private let prerequisites: [String: [String]] = [
        "Syntax": ["Morfologi"],
        "Pragmatik": ["Semantik", "Syntax"],
        "Diskurs": ["Pragmatik"],
        "Metakognition": ["Kognitionsvetenskap"],
        "Epistemologi": ["Filosofi"],
        "Analogibyggande": ["Semantik", "Kausalitet"],
    ]

    private func identifyKnowledgeGaps() -> [KnowledgeGap] {
        var gaps: [KnowledgeGap] = []

        for (domain, competency) in competencyBook {
            // Dynamic threshold: lower for foundational domains, higher for advanced
            let isFoundational = ["Morfologi", "Semantik", "Filosofi", "Kognitionsvetenskap"].contains(domain)
            let threshold = isFoundational ? 0.6 : 0.5

            if competency.level < threshold {
                var urgency = (threshold - competency.level) * 2.0

                // Boost urgency if this domain is a prerequisite for other domains the user is trying to learn
                if let dependents = domainInteractions[domain] {
                    for dep in dependents {
                        if let depLevel = competencyBook[dep.target]?.level, depLevel > competency.level {
                            // Dependent domain is ahead of prerequisite — urgency boost
                            urgency += dep.strength * 0.5
                        }
                    }
                }

                // Penalize urgency if prerequisites are unmet (learn foundation first)
                if let prereqs = prerequisites[domain] {
                    let unmetPrereqs = prereqs.filter { (competencyBook[$0]?.level ?? 0) < 0.3 }
                    if !unmetPrereqs.isEmpty {
                        urgency *= 0.5 // Halve urgency — learn prereqs first
                    }
                }

                // Factor in staleness: domains not studied recently get urgency boost
                let daysSinceStudied = Date().timeIntervalSince(competency.lastStudied) / 86400
                if daysSinceStudied > 7 { urgency += 0.2 }
                if daysSinceStudied > 30 { urgency += 0.3 }

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
            "Syntax": [
                ["Ordföljd i svenska", "Huvudsats vs bisats", "Satsdelar"],
                ["Frasstruktur", "Topikalisering", "Passivkonstruktioner"],
                ["X-bar-teori", "Dependensgrammatik", "Syntaktisk komplexitet"]
            ],
            "Semantik": [
                ["Ordklass och betydelse", "Synonymer och antonymer", "Polysemi"],
                ["Semantiska fält", "Komposition", "Metonymi och metafor"],
                ["Formell semantik", "Lambdakalkyl", "Diskursrepresentation"]
            ],
            "Pragmatik": [
                ["Talakter", "Implikatur", "Konversationsmaximer"],
                ["Presupposition", "Deixis", "Artighet"],
                ["Relevanceteori", "Konversationsanalys", "Pragmatisk inferens"]
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
            "Kognitionsvetenskap": [
                ["Perception", "Arbetsminne", "Uppmärksamhet"],
                ["Kognitiva scheman", "Dual-process-teori", "Kognitiv belastning"],
                ["Embodied cognition", "Situerat lärande", "Kognitiv arkitektur"]
            ],
            "Metakognition": [
                ["Självmedvetenhet", "Strategival", "Övervakningsprocesser"],
                ["Kalibrering", "Metaminnesteknik", "Reflektion"],
                ["Metakognitiv styrning", "Epistemic feelings", "FOK-omdömen"]
            ],
            "Filosofi": [
                ["Logik", "Argumentation", "Grundläggande etik"],
                ["Epistemologi", "Medvetandefilosofi", "Fri vilja"],
                ["Fenomenologi", "Analytisk filosofi", "Filosofisk logik"]
            ],
            "Epistemologi": [
                ["Kunskap och tro", "Sanning", "Rättfärdigande"],
                ["Skepticism", "Empirism vs rationalism", "Reliabilism"],
                ["Social epistemologi", "Vetenskapsteori", "Bayesiansk epistemologi"]
            ],
            "Historia": [
                ["Antiken", "Medeltiden", "Renässansen"],
                ["Upplysningen", "Industriella revolutionen", "Världskrigen"],
                ["Historiografi", "Historisk metod", "Kontrafaktisk historia"]
            ],
            "Psykologi": [
                ["Grundläggande emotion", "Motivation", "Perception"],
                ["Kognitiv psykologi", "Social psykologi", "Utvecklingspsykologi"],
                ["Neuropsykologi", "Klinisk psykologi", "Psykologisk forskning"]
            ],
            "Naturvetenskap": [
                ["Grundläggande fysik", "Cellbiologi", "Kemi"],
                ["Kvantfysik", "Genetik", "Organisk kemi"],
                ["Kosmologi", "Evolutionsbiologi", "Materialvetenskap"]
            ],
            "Analogibyggande": [
                ["Grundläggande liknelser", "Strukturell mappning"],
                ["Gentners analogiteori", "Fjärranalogier"],
                ["Analogisk transfer", "Kreativ analogianvändning"]
            ],
            "Diskurs": [
                ["Textstruktur", "Koherens", "Referens"],
                ["Diskursmarkörer", "Tema-rema", "Informationsstruktur"],
                ["Kritisk diskursanalys", "Retorisk analys", "Genreteori"]
            ],
        ]

        let levelIdx = level < 0.33 ? 0 : level < 0.66 ? 1 : 2
        return topicMap[domain]?[safe: levelIdx] ?? ["Grundläggande \(domain)", "Fördjupning i \(domain)", "Avancerad \(domain)"]
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
        // Detect all relevant domains (not just the best one)
        let primaryDomain = detectDomain(from: userMessage + " " + eonResponse)
        let secondaryDomain = detectDomain(from: userMessage) // Sometimes user's question and response diverge

        // Update competency with scaled feedback
        // Good feedback reinforces; bad feedback triggers active learning
        for domain in Set([primaryDomain, secondaryDomain]) {
            if var competency = competencyBook[domain] {
                let delta: Double
                if feedback >= 0.7 {
                    // Strong positive: scale by how far from mastery
                    delta = (feedback - 0.5) * 0.05 * (1.0 - competency.level)
                } else if feedback >= 0.4 {
                    // Neutral: minimal change
                    delta = (feedback - 0.5) * 0.02
                } else {
                    // Negative: competency can decrease (previously only ratcheted up)
                    delta = (feedback - 0.5) * 0.04
                }
                competency.level = min(0.99, max(0.01, competency.level + delta))
                competency.lastStudied = Date()
                competencyBook[domain] = competency
                UserDefaults.standard.set(competency.level, forKey: "competency_\(domain)")
            }
        }

        // Add FSRS items for weak points — with difficulty proportional to failure
        if feedback < 0.5 {
            let topic = extractMainTopic(from: userMessage)
            let difficulty = min(0.95, 0.5 + (0.5 - feedback)) // Worse feedback → harder item
            addFSRSItem(topic: topic, domain: primaryDomain, initialDifficulty: difficulty)

            // Also save the gap as a fact for future reference
            await PersistentMemoryStore.shared.saveFact(
                subject: primaryDomain,
                predicate: "svagt_område",
                object: topic,
                confidence: 1.0 - feedback,
                source: "meta_learning"
            )
        }

        // Strong positive feedback → mark topic as well-understood
        if feedback >= 0.8 {
            let topic = extractMainTopic(from: userMessage)
            var domainDepth = topicDepthTracker[primaryDomain] ?? [:]
            domainDepth[topic] = max(domainDepth[topic] ?? 0, 3) // Mark as intermediate+
            topicDepthTracker[primaryDomain] = domainDepth
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
        // Score each domain based on keyword hits — weighted by specificity
        let domainKeywords: [(String, [(keyword: String, weight: Int)])] = [
            ("Morfologi",          [("morfologi", 3), ("böjning", 2), ("ordklass", 2), ("avledning", 2), ("suffix", 2), ("prefix", 2), ("sammansättning", 2), ("lemma", 2)]),
            ("Syntax",             [("syntax", 3), ("sats", 1), ("ordföljd", 2), ("fras", 1), ("grammatik", 2), ("bisats", 2), ("subjekt", 1), ("predikat", 1)]),
            ("Semantik",           [("semantik", 3), ("betydelse", 2), ("definition", 1), ("begrepp", 1), ("lexikon", 2), ("polysemi", 3), ("synonym", 2)]),
            ("Pragmatik",          [("pragmatik", 3), ("talakt", 3), ("implikatur", 3), ("kommunikation", 1), ("konversation", 1), ("artighet", 2)]),
            ("Diskurs",            [("diskurs", 3), ("koherens", 2), ("retori", 2), ("textstruktur", 2), ("genr", 2), ("narrativ", 2)]),
            ("Kausalitet",         [("orsak", 2), ("kausal", 3), ("kausalitet", 3), ("verkan", 2), ("konsekvens", 2), ("korrelation", 2)]),
            ("AI & Maskininlärning", [("ai", 2), ("neural", 2), ("transformer", 3), ("bert", 3), ("gpt", 3), ("maskininlärning", 3), ("algoritm", 2), ("modell", 1)]),
            ("Kognitionsvetenskap", [("kognition", 3), ("medvetande", 2), ("perception", 2), ("uppmärksamhet", 2), ("arbetsminne", 3), ("tänkande", 1)]),
            ("Metakognition",      [("metakognition", 3), ("självreflektion", 3), ("självmedvetenhet", 3), ("strategi", 1), ("lärande", 1), ("kalibrering", 2)]),
            ("Filosofi",           [("filosofi", 3), ("ontologi", 3), ("etik", 2), ("moral", 2), ("existens", 2), ("fenomenologi", 3)]),
            ("Epistemologi",       [("epistemologi", 3), ("kunskap", 1), ("sanning", 2), ("bevis", 1), ("rättfärdigande", 3), ("skepticism", 3)]),
            ("Historia",           [("historia", 2), ("historisk", 2), ("krig", 1), ("revolution", 2), ("civilisation", 2), ("antiken", 2), ("medeltid", 2)]),
            ("Psykologi",          [("psykologi", 3), ("känsla", 1), ("beteende", 2), ("emotion", 2), ("trauma", 2), ("personlighet", 2), ("motivation", 2)]),
            ("Naturvetenskap",     [("naturvetenskap", 3), ("fysik", 2), ("kemi", 2), ("biologi", 2), ("evolution", 2), ("astronomi", 2), ("kvant", 2)]),
            ("Analogibyggande",    [("analogi", 3), ("liknelse", 2), ("metafor", 2), ("parallell", 1), ("jämförelse", 1), ("mappning", 2)]),
        ]
        var bestDomain = "Kognitionsvetenskap"
        var bestScore = 0
        for (domain, keywords) in domainKeywords {
            let score = keywords.reduce(0) { sum, kw in
                lower.contains(kw.keyword) ? sum + kw.weight : sum
            }
            if score > bestScore {
                bestScore = score
                bestDomain = domain
            }
        }
        return bestDomain
    }

    private func extractMainTopic(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [(word: String, position: Int)] = []
        var verbs: [String] = []
        var position = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range])
            if tag == .noun && word.count > 3 {
                nouns.append((word, position))
            } else if tag == .verb && word.count > 3 {
                verbs.append(word)
            }
            position += 1
            return true
        }

        // Prefer longer nouns (more specific) and earlier position
        let scored = nouns.map { noun -> (String, Double) in
            let lengthScore = min(1.0, Double(noun.word.count) / 10.0)
            let positionScore = 1.0 / (1.0 + Double(noun.position) * 0.2) // Earlier = better
            return (noun.word, lengthScore + positionScore)
        }.sorted { $0.1 > $1.1 }

        if let best = scored.first {
            // Combine top noun with verb for richer topic description
            if let verb = verbs.first, verb != best.0 {
                return "\(verb) \(best.0)"
            }
            return best.0
        }
        return String(text.prefix(30).split(separator: " ").filter { $0.count > 4 }.first ?? "okänt ämne")
    }

    /// Get the current depth for a topic in a domain (0 = never studied, 5 = mastered)
    func topicDepth(domain: String, topic: String) -> Int {
        topicDepthTracker[domain]?[topic] ?? 0
    }

    /// Get domains that have stalled (no progress in recent cycles)
    func stalledDomains(staleDays: Double = 7.0) -> [DomainCompetency] {
        let threshold = Date().addingTimeInterval(-staleDays * 86400)
        return competencyBook.values
            .filter { $0.lastStudied < threshold && $0.level < 0.7 }
            .sorted { $0.level < $1.level }
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
    nonisolated var priority: Double { stability * (1.0 - difficulty) }
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
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
