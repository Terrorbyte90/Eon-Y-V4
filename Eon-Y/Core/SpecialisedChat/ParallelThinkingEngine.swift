import Foundation

// MARK: - ParallelThinkingEngine: Parallellt multi-vägs resonemang
// Kör upp till 4 parallella "tankevägar" som angriper frågan från olika vinklar.
// Varje väg producerar en slutsats med konfidenspoäng. Bästa resultaten
// matas vidare till ResponseComposer.

struct ThinkingPath: Sendable {
    let approach: ThinkingApproach
    let conclusion: String
    let confidence: Double          // 0-1
    let reasoning: [String]         // Resonemangskedja
    let relevantFacts: [String]     // Fakta som använts
    let timeTaken: TimeInterval

    enum ThinkingApproach: String, Sendable {
        case factBased = "faktabaserat"
        case analogical = "analogiskt"
        case deductive = "deduktivt"
        case causal = "kausalt"
        case experiential = "erfarenhetsbaserat"
        case creative = "kreativt"
        case comparative = "jämförande"
        case definitional = "definitionsmässigt"
    }
}

actor ParallelThinkingEngine {
    private let neuralEngine = NeuralEngineOrchestrator.shared

    // MARK: - Normal tänkande (max ~1.0s, 2 parallella vägar)

    func think(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        timeBudget: TimeInterval
    ) async -> [ThinkingPath] {
        let startTime = Date()

        // Välj 2 lämpliga ansatser baserat på frågetyp
        let approaches = selectApproaches(
            questionType: question.questionType,
            knowledgeCoverage: knowledge.topicCoverage,
            maxPaths: 2
        )

        // Kör parallellt
        var results: [ThinkingPath] = []
        await withTaskGroup(of: ThinkingPath?.self) { group in
            for approach in approaches {
                group.addTask {
                    let remaining = timeBudget - Date().timeIntervalSince(startTime)
                    guard remaining > 0.1 else { return nil }
                    return await self.executeThinkingPath(
                        approach: approach,
                        question: question,
                        knowledge: knowledge,
                        timeBudget: remaining
                    )
                }
            }

            for await result in group {
                if let path = result {
                    results.append(path)
                }
            }
        }

        // Sortera efter konfidenspoäng
        return results.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Djupt tänkande (max ~30s, 4 parallella vägar)

    func thinkDeep(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        timeBudget: TimeInterval
    ) async -> [ThinkingPath] {
        let startTime = Date()

        // Välj upp till 4 ansatser
        let approaches = selectApproaches(
            questionType: question.questionType,
            knowledgeCoverage: knowledge.topicCoverage,
            maxPaths: 4
        )

        var results: [ThinkingPath] = []
        await withTaskGroup(of: ThinkingPath?.self) { group in
            for approach in approaches {
                group.addTask {
                    let remaining = timeBudget - Date().timeIntervalSince(startTime)
                    guard remaining > 0.5 else { return nil }
                    return await self.executeThinkingPathDeep(
                        approach: approach,
                        question: question,
                        knowledge: knowledge,
                        timeBudget: min(remaining, timeBudget / Double(approaches.count))
                    )
                }
            }

            for await result in group {
                if let path = result {
                    results.append(path)
                }
            }
        }

        return results.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Välj resonemangsansatser

    private func selectApproaches(
        questionType: QuestionProfile.QuestionType,
        knowledgeCoverage: Double,
        maxPaths: Int
    ) -> [ThinkingPath.ThinkingApproach] {
        var approaches: [ThinkingPath.ThinkingApproach] = []

        switch questionType {
        case .factual, .definition:
            approaches = [.factBased, .definitional]
        case .explanation:
            approaches = [.factBased, .causal, .analogical, .deductive]
        case .whyExplanation:
            approaches = [.causal, .deductive, .factBased, .analogical]
        case .comparison:
            approaches = [.comparative, .factBased, .analogical, .deductive]
        case .howTo:
            approaches = [.experiential, .factBased, .deductive]
        case .opinion:
            approaches = [.experiential, .analogical, .causal, .creative]
        case .creative:
            approaches = [.creative, .analogical, .experiential]
        case .selfReference:
            approaches = [.factBased, .experiential]
        default:
            approaches = [.factBased, .experiential]
        }

        // Om kunskapstäckningen är låg, lägg till kreativ/analogisk
        if knowledgeCoverage < 0.3 && !approaches.contains(.analogical) {
            approaches.append(.analogical)
        }

        return Array(approaches.prefix(maxPaths))
    }

    // MARK: - Utför en tankeväg (normal)

    private func executeThinkingPath(
        approach: ThinkingPath.ThinkingApproach,
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        timeBudget: TimeInterval
    ) async -> ThinkingPath {
        let startTime = Date()
        var reasoning: [String] = []
        var relevantFacts: [String] = []
        var confidence: Double = 0.3

        // Samla relevanta fakta
        let topFacts = knowledge.facts.prefix(3).map { $0.naturalLanguage }
        relevantFacts = topFacts

        switch approach {
        case .factBased:
            // Faktabaserat: matcha fakta direkt mot frågan
            if !topFacts.isEmpty {
                reasoning.append("Hittar relevanta fakta om '\(question.coreTopic)'")
                for fact in topFacts {
                    reasoning.append("Fakta: \(fact)")
                }
                confidence = Double(min(topFacts.count, 3)) * 0.25
                // BERT-validera matchning
                if let firstFact = topFacts.first {
                    let sim = await bertSimilarity(question.resolvedInput, firstFact)
                    confidence = max(confidence, Double(sim))
                    reasoning.append("Fakta-relevans: \(String(format: "%.0f%%", sim * 100))")
                }
            } else {
                reasoning.append("Inga direkta fakta hittades om '\(question.coreTopic)'")
                confidence = 0.1
            }

        case .deductive:
            // Deduktivt: dra slutsats från allmänna principer
            reasoning.append("Deduktivt resonemang om '\(question.coreTopic)'")
            if !topFacts.isEmpty {
                reasoning.append("Premiss: \(topFacts[0])")
                if topFacts.count > 1 {
                    reasoning.append("Ytterligare premiss: \(topFacts[1])")
                }
                reasoning.append("Slutsats baserad på tillgängliga premisser")
                confidence = 0.5
            } else {
                reasoning.append("Otillräckliga premisser för deduktiv slutledning")
                confidence = 0.15
            }

        case .causal:
            // Kausalt: orsak-verkan-analys
            reasoning.append("Kausal analys av '\(question.coreTopic)'")
            reasoning.append("Söker orsaker och effekter i kunskapsbasen")
            if knowledge.topicCoverage > 0.4 {
                reasoning.append("Identifierar kausala samband i tillgänglig kunskap")
                confidence = 0.55
            } else {
                reasoning.append("Begränsad information för kausal analys")
                confidence = 0.2
            }

        case .analogical:
            // Analogiskt: hitta liknande koncept
            reasoning.append("Söker analogier och liknande koncept till '\(question.coreTopic)'")
            if let article = knowledge.articles.first {
                reasoning.append("Liknande område: \(article.title)")
                confidence = Double(article.relevanceScore) * 0.7
            } else {
                reasoning.append("Söker efter konceptuella likheter")
                confidence = 0.2
            }

        case .experiential:
            // Erfarenhetsbaserat: från konversationsminnen
            if !knowledge.memories.isEmpty {
                reasoning.append("Hämtar relevanta erfarenheter")
                for mem in knowledge.memories.prefix(2) {
                    reasoning.append("Minne: \(String(mem.content.prefix(80)))")
                }
                confidence = Double(knowledge.memories[0].relevanceScore) * 0.8
            } else {
                reasoning.append("Inga relevanta erfarenheter hittade")
                confidence = 0.1
            }

        case .creative:
            // Kreativt: generera nya kopplingar
            reasoning.append("Kreativt tänkande om '\(question.coreTopic)'")
            reasoning.append("Kombinerar tillgänglig kunskap på nya sätt")
            confidence = 0.3

        case .comparative:
            // Jämförande: identifiera likheter och skillnader
            reasoning.append("Jämförande analys")
            if topFacts.count >= 2 {
                reasoning.append("Jämför: \(topFacts[0]) vs \(topFacts[1])")
                confidence = 0.5
            } else {
                reasoning.append("Behöver mer data för fullständig jämförelse")
                confidence = 0.2
            }

        case .definitional:
            // Definitionsmässigt: exakt definition
            reasoning.append("Söker definition av '\(question.coreTopic)'")
            if !topFacts.isEmpty {
                reasoning.append("Definition baserad på: \(topFacts[0])")
                confidence = Double(knowledge.facts.first?.relevanceScore ?? 0.3)
            } else {
                confidence = 0.15
            }
        }

        // Bygg slutsats
        let conclusion = buildConclusion(
            approach: approach,
            reasoning: reasoning,
            question: question,
            facts: topFacts
        )

        let elapsed = Date().timeIntervalSince(startTime)
        return ThinkingPath(
            approach: approach,
            conclusion: conclusion,
            confidence: min(confidence, 0.95),
            reasoning: reasoning,
            relevantFacts: relevantFacts,
            timeTaken: elapsed
        )
    }

    // MARK: - Utför en tankeväg (djup)

    private func executeThinkingPathDeep(
        approach: ThinkingPath.ThinkingApproach,
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        timeBudget: TimeInterval
    ) async -> ThinkingPath {
        // Djupare version: mer BERT-validering, fler steg
        let startTime = Date()
        var reasoning: [String] = []
        var relevantFacts: [String] = []
        var confidence: Double = 0.3

        let topFacts = knowledge.facts.prefix(5).map { $0.naturalLanguage }
        relevantFacts = topFacts

        // Steg 1: Grundläggande resonemang (samma som normal)
        let basicPath = await executeThinkingPath(
            approach: approach,
            question: question,
            knowledge: knowledge,
            timeBudget: timeBudget * 0.5
        )
        reasoning.append(contentsOf: basicPath.reasoning)
        confidence = basicPath.confidence

        // Steg 2: BERT-validering av varje resonemangssteg
        let remaining = timeBudget - Date().timeIntervalSince(startTime)
        if remaining > 0.5 {
            for fact in topFacts.prefix(3) {
                let sim = await bertSimilarity(question.resolvedInput, fact)
                if sim > 0.4 {
                    reasoning.append("✓ Validerat: '\(String(fact.prefix(50)))' (relevans: \(String(format: "%.0f%%", sim * 100)))")
                }
            }
        }

        // Steg 3: Korsvalidera med artiklar
        if let article = knowledge.articles.first, remaining > 1.0 {
            let articleSim = await bertSimilarity(question.resolvedInput, article.title + " " + String(article.content.prefix(100)))
            if articleSim > 0.3 {
                reasoning.append("Stöds av artikel: '\(article.title)' (relevans: \(String(format: "%.0f%%", articleSim * 100)))")
                confidence = max(confidence, Double(articleSim) * 0.9)
            }
        }

        // Steg 4: Integrera minnen
        for mem in knowledge.memories.prefix(2) {
            let memSim = await bertSimilarity(question.resolvedInput, String(mem.content.prefix(100)))
            if memSim > 0.35 {
                reasoning.append("Erfarenhet stödjer: '\(String(mem.content.prefix(60)))'")
                confidence += Double(memSim) * 0.1
            }
        }

        // Steg 5: Djupare slutsats
        let conclusion = buildDeepConclusion(
            approach: approach,
            reasoning: reasoning,
            question: question,
            facts: topFacts,
            confidence: confidence
        )

        let elapsed = Date().timeIntervalSince(startTime)
        return ThinkingPath(
            approach: approach,
            conclusion: conclusion,
            confidence: min(confidence, 0.95),
            reasoning: reasoning,
            relevantFacts: relevantFacts,
            timeTaken: elapsed
        )
    }

    // MARK: - Slutsatsbyggnad

    private func buildConclusion(
        approach: ThinkingPath.ThinkingApproach,
        reasoning: [String],
        question: QuestionProfile,
        facts: [String]
    ) -> String {
        if facts.isEmpty {
            return "Begränsad information om '\(question.coreTopic)' — behöver resonera utifrån kontext."
        }

        switch approach {
        case .factBased:
            return "Baserat på \(facts.count) fakta om '\(question.coreTopic)': \(facts.first ?? "")"
        case .deductive:
            return "Deduktiv slutsats om '\(question.coreTopic)' baserad på tillgängliga premisser."
        case .causal:
            return "Kausal analys visar samband relaterade till '\(question.coreTopic)'."
        case .analogical:
            return "Genom analogi med liknande koncept kan vi förstå '\(question.coreTopic)'."
        case .experiential:
            return "Baserat på tidigare erfarenheter relaterade till '\(question.coreTopic)'."
        case .creative:
            return "Kreativ koppling: '\(question.coreTopic)' kan ses ur nya perspektiv."
        case .comparative:
            return "Jämförande analys av aspekter relaterade till '\(question.coreTopic)'."
        case .definitional:
            return facts.first ?? "'\(question.coreTopic)' — definition söks."
        }
    }

    private func buildDeepConclusion(
        approach: ThinkingPath.ThinkingApproach,
        reasoning: [String],
        question: QuestionProfile,
        facts: [String],
        confidence: Double
    ) -> String {
        let validatedSteps = reasoning.filter { $0.hasPrefix("✓") }.count
        let base = buildConclusion(approach: approach, reasoning: reasoning, question: question, facts: facts)
        if validatedSteps > 0 {
            return "\(base) (Validerat med \(validatedSteps) BERT-kontroller, konfidenspoäng: \(String(format: "%.0f%%", confidence * 100)))"
        }
        return base
    }

    // MARK: - BERT-hjälp

    private func bertSimilarity(_ a: String, _ b: String) async -> Float {
        let embA = await neuralEngine.embed(String(a.prefix(128)))
        let embB = await neuralEngine.embed(String(b.prefix(128)))
        return await neuralEngine.cosineSimilarity(embA, embB)
    }
}
