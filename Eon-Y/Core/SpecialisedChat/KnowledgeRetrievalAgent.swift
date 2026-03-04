import Foundation

// MARK: - KnowledgeRetrievalAgent: Parallell kunskapssökning
// Söker ALLA kunskapskällor samtidigt: fakta, artiklar, minnen, konversationer.
// BERT-rankar resultaten och skapar en kompakt kunskapsbunt.

struct KnowledgeBundle: Sendable {
    let facts: [RankedFact]
    let articles: [RankedArticle]
    let memories: [RankedMemory]
    let hasStrongKnowledge: Bool     // Har vi relevant kunskap att svara med?
    let knowledgeSummary: String     // Kompakt sammanfattning av all relevant kunskap
    let sources: [String]            // Vilka källor bidrog
    let topicCoverage: Double        // 0-1: hur väl täcker kunskapen frågan?

    struct RankedFact: Sendable {
        let subject: String
        let predicate: String
        let object: String
        let relevanceScore: Float
        var naturalLanguage: String { "\(subject) \(predicate) \(object)" }
    }

    struct RankedArticle: Sendable {
        let title: String
        let domain: String
        let content: String
        let relevanceScore: Float
    }

    struct RankedMemory: Sendable {
        let content: String
        let role: String
        let recency: Double  // 0-1: hur nyligt
        let relevanceScore: Float
    }

    /// Bygger den bästa kompakta kontexten för prompten (max ~150 tokens)
    func bestContextForPrompt(maxChars: Int = 500) -> String {
        var parts: [String] = []
        var remaining = maxChars

        // Prioritet 1: Bästa fakta
        for fact in facts.prefix(3) where remaining > 0 {
            let text = fact.naturalLanguage
            if text.count < remaining {
                parts.append(text)
                remaining -= text.count + 2
            }
        }

        // Prioritet 2: Bästa artikel (bara rubrik + kort utdrag)
        if let best = articles.first, remaining > 50 {
            let excerpt = "\(best.title): \(String(best.content.prefix(min(remaining - 10, 120))))"
            parts.append(excerpt)
            remaining -= excerpt.count + 2
        }

        // Prioritet 3: Relevantaste minne
        if let best = memories.first, remaining > 30 {
            parts.append(String(best.content.prefix(min(remaining, 100))))
        }

        return parts.joined(separator: ". ")
    }
}

actor KnowledgeRetrievalAgent {
    private let memory = PersistentMemoryStore.shared
    private let neuralEngine = NeuralEngineOrchestrator.shared

    // MARK: - Normal sökning (max ~1.5s)

    func retrieve(
        input: String,
        entities: [ExtractedEntity],
        inputEmbedding: [Float],
        deadline: Date
    ) async -> KnowledgeBundle {
        let hasBERT = !inputEmbedding.allSatisfy({ $0 == 0 })

        // Kör ALLA sökningar parallellt
        async let factsResult = searchAndRankFacts(input: input, entities: entities, embedding: inputEmbedding, hasBERT: hasBERT)
        async let articlesResult = searchAndRankArticles(input: input, embedding: inputEmbedding, hasBERT: hasBERT, maxArticles: 1)
        async let memoriesResult = searchAndRankMemories(input: input, embedding: inputEmbedding, hasBERT: hasBERT)

        let facts = await factsResult
        let articles = await articlesResult
        let memories = await memoriesResult

        return buildBundle(facts: facts, articles: articles, memories: memories)
    }

    // MARK: - Djup sökning (mer tid)

    func retrieveDeep(
        input: String,
        entities: [ExtractedEntity],
        inputEmbedding: [Float]
    ) async -> KnowledgeBundle {
        let hasBERT = !inputEmbedding.allSatisfy({ $0 == 0 })

        async let factsResult = searchAndRankFacts(input: input, entities: entities, embedding: inputEmbedding, hasBERT: hasBERT, deepMode: true)
        async let articlesResult = searchAndRankArticles(input: input, embedding: inputEmbedding, hasBERT: hasBERT, maxArticles: 3)
        async let memoriesResult = searchAndRankMemories(input: input, embedding: inputEmbedding, hasBERT: hasBERT)

        let facts = await factsResult
        let articles = await articlesResult
        let memories = await memoriesResult

        return buildBundle(facts: facts, articles: articles, memories: memories)
    }

    // MARK: - Fakta-sökning och ranking

    private func searchAndRankFacts(
        input: String,
        entities: [ExtractedEntity],
        embedding: [Float],
        hasBERT: Bool,
        deepMode: Bool = false
    ) async -> [KnowledgeBundle.RankedFact] {
        // Sök med flera frågor parallellt
        var allFacts: [(subject: String, predicate: String, object: String)] = []
        let seen = NSMutableSet()  // Dedup

        // Sök 1: Original input
        let inputFacts = await memory.searchFacts(query: input, limit: deepMode ? 15 : 10)
        for f in inputFacts {
            let key = "\(f.subject)|\(f.predicate)|\(f.object)"
            if !seen.contains(key) { seen.add(key); allFacts.append(f) }
        }

        // Sök 2: Varje entitet
        for entity in entities.prefix(3) {
            let eFacts = await memory.searchFacts(query: entity.text, limit: 5)
            for f in eFacts {
                let key = "\(f.subject)|\(f.predicate)|\(f.object)"
                if !seen.contains(key) { seen.add(key); allFacts.append(f) }
            }
        }

        // Sök 3: Enskilda ord (fångar fakta som exakt matchning missar)
        let inputWords = input.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 3 }
        for word in inputWords.prefix(3) {
            let wFacts = await memory.searchFacts(query: word, limit: 3)
            for f in wFacts {
                let key = "\(f.subject)|\(f.predicate)|\(f.object)"
                if !seen.contains(key) { seen.add(key); allFacts.append(f) }
            }
        }

        guard !allFacts.isEmpty else { return [] }

        // BERT-ranka
        if hasBERT {
            var scored: [KnowledgeBundle.RankedFact] = []
            for fact in allFacts.prefix(20) {
                let factEmb = await neuralEngine.embed(fact.subject + " " + fact.predicate + " " + fact.object)
                let sim = await neuralEngine.cosineSimilarity(embedding, factEmb)
                scored.append(KnowledgeBundle.RankedFact(
                    subject: fact.subject, predicate: fact.predicate,
                    object: fact.object, relevanceScore: sim
                ))
            }
            return scored.sorted { $0.relevanceScore > $1.relevanceScore }
                .filter { $0.relevanceScore > 0.20 }
                .prefix(deepMode ? 8 : 4).map { $0 }
        } else {
            return allFacts.prefix(deepMode ? 6 : 3).map {
                KnowledgeBundle.RankedFact(subject: $0.subject, predicate: $0.predicate,
                                           object: $0.object, relevanceScore: 0.5)
            }
        }
    }

    // MARK: - Artikelsökning

    private func searchAndRankArticles(
        input: String,
        embedding: [Float],
        hasBERT: Bool,
        maxArticles: Int
    ) async -> [KnowledgeBundle.RankedArticle] {
        let articles = await memory.loadAllArticles()
        guard !articles.isEmpty else { return [] }

        if hasBERT {
            var scored: [(article: KnowledgeArticle, score: Float)] = []
            for article in articles.prefix(20) {
                let articleEmb = await neuralEngine.embed(article.title + " " + article.summary)
                let sim = await neuralEngine.cosineSimilarity(embedding, articleEmb)
                // Nyckelords-boost
                let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
                let contentWords = Set(article.content.lowercased().prefix(300).components(separatedBy: .whitespaces).filter { $0.count > 3 })
                let boosted = sim + Float(inputWords.intersection(contentWords).count) * 0.05
                if boosted > 0.30 { scored.append((article, boosted)) }
            }
            return scored.sorted { $0.score > $1.score }
                .prefix(maxArticles)
                .map { KnowledgeBundle.RankedArticle(
                    title: $0.article.title, domain: $0.article.domain,
                    content: $0.article.content, relevanceScore: $0.score
                )}
        } else {
            let lower = input.lowercased()
            return articles.filter { $0.title.lowercased().contains(lower.prefix(15)) }
                .prefix(maxArticles)
                .map { KnowledgeBundle.RankedArticle(
                    title: $0.title, domain: $0.domain,
                    content: $0.content, relevanceScore: 0.5
                )}
        }
    }

    // MARK: - Minnesökning

    private func searchAndRankMemories(
        input: String,
        embedding: [Float],
        hasBERT: Bool
    ) async -> [KnowledgeBundle.RankedMemory] {
        let rawMemories = await memory.searchConversations(query: input, limit: 15)
        guard !rawMemories.isEmpty else { return [] }

        let now = Date()
        if hasBERT {
            var scored: [KnowledgeBundle.RankedMemory] = []
            for mem in rawMemories {
                let memEmb = await neuralEngine.embed(String(mem.content.prefix(200)))
                let sim = await neuralEngine.cosineSimilarity(embedding, memEmb)
                let ageHours = now.timeIntervalSince(mem.date) / 3600.0
                let recency = exp(-ageHours / 24.0)
                let boosted = sim + Float(recency * 0.1)
                scored.append(KnowledgeBundle.RankedMemory(
                    content: mem.content, role: mem.role,
                    recency: recency, relevanceScore: boosted
                ))
            }
            return scored.sorted { $0.relevanceScore > $1.relevanceScore }
                .filter { $0.relevanceScore > 0.25 }
                .prefix(4).map { $0 }
        } else {
            return rawMemories.prefix(3).map {
                let ageHours = now.timeIntervalSince($0.date) / 3600.0
                return KnowledgeBundle.RankedMemory(
                    content: $0.content, role: $0.role,
                    recency: exp(-ageHours / 24.0), relevanceScore: 0.5
                )
            }
        }
    }

    // MARK: - Bygg kunskapsbunt

    private func buildBundle(
        facts: [KnowledgeBundle.RankedFact],
        articles: [KnowledgeBundle.RankedArticle],
        memories: [KnowledgeBundle.RankedMemory]
    ) -> KnowledgeBundle {
        // Beräkna kunskapstäckning
        let hasRelevantFacts = !facts.isEmpty && facts[0].relevanceScore > 0.35
        let hasRelevantArticles = !articles.isEmpty && articles[0].relevanceScore > 0.35
        let hasRelevantMemories = !memories.isEmpty && memories[0].relevanceScore > 0.35

        let hasStrong = hasRelevantFacts || hasRelevantArticles
        let coverage: Double
        if hasRelevantFacts && hasRelevantArticles { coverage = 0.9 }
        else if hasRelevantFacts || hasRelevantArticles { coverage = 0.6 }
        else if hasRelevantMemories { coverage = 0.3 }
        else { coverage = 0.05 }

        // Bygg sammanfattning
        var summary: [String] = []
        for fact in facts.prefix(3) { summary.append(fact.naturalLanguage) }
        if let article = articles.first {
            summary.append("\(article.title): \(String(article.content.prefix(100)))")
        }

        var sources: [String] = []
        if !facts.isEmpty { sources.append("fakta (\(facts.count))") }
        if !articles.isEmpty { sources.append("artiklar (\(articles.count))") }
        if !memories.isEmpty { sources.append("minnen (\(memories.count))") }

        return KnowledgeBundle(
            facts: facts,
            articles: articles,
            memories: memories,
            hasStrongKnowledge: hasStrong,
            knowledgeSummary: summary.joined(separator: ". "),
            sources: sources,
            topicCoverage: coverage
        )
    }
}
