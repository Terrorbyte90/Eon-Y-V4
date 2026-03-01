import Foundation

// MARK: - CrossDomainAnalyzer: Drar paralleller mellan artiklar och domäner

actor CrossDomainAnalyzer {
    static let shared = CrossDomainAnalyzer()

    private let memory = PersistentMemoryStore.shared
    private let neuralEngine = NeuralEngineOrchestrator.shared

    private init() {}

    // MARK: - Article Comprehension

    /// Reads and deeply understands an article, extracting cross-domain connections
    func comprehendArticle(_ article: KnowledgeArticle) async -> ArticleComprehension {
        let content = article.content

        // Extract key concepts from article
        let concepts = extractKeyConcepts(from: content)

        // Extract causal relationships
        let causalRelations = extractCausalRelations(from: content)

        // Find potential cross-domain connections by searching other articles
        let allArticles = await memory.loadAllArticles(limit: 200)
        let crossDomainLinks = await findCrossDomainLinks(
            article: article,
            concepts: concepts,
            allArticles: allArticles.filter { $0.id != article.id }
        )

        // Extract facts from the article for the knowledge graph
        let extractedFacts = extractFactsFromArticle(content: content, domain: article.domain)

        // Store extracted facts
        for fact in extractedFacts {
            await memory.saveFact(
                subject: fact.subject,
                predicate: fact.predicate,
                object: fact.object,
                confidence: fact.confidence,
                source: article.title
            )
        }

        return ArticleComprehension(
            article: article,
            keyConcepts: concepts,
            causalRelations: causalRelations,
            crossDomainLinks: crossDomainLinks,
            extractedFacts: extractedFacts
        )
    }

    /// Batch-read and analyze all articles for cross-domain patterns
    func analyzeAllArticles() async -> [CrossDomainInsight] {
        let articles = await memory.loadAllArticles(limit: 500)
        guard articles.count >= 2 else { return [] }

        var insights: [CrossDomainInsight] = []
        var conceptMap: [String: [String]] = [:] // concept → [article titles]

        // Phase 1: Extract concepts from all articles
        for article in articles {
            let concepts = extractKeyConcepts(from: article.content)
            for concept in concepts {
                conceptMap[concept.lowercased(), default: []].append(article.title)
            }
        }

        // Phase 2: Find shared concepts across domains
        for (concept, titles) in conceptMap where titles.count >= 2 {
            let domains = Set(articles.filter { titles.contains($0.title) }.map { $0.domain })
            if domains.count >= 2 {
                insights.append(CrossDomainInsight(
                    concept: concept,
                    domains: Array(domains),
                    articleTitles: titles,
                    type: .sharedConcept,
                    description: "Begreppet '\(concept)' förekommer i \(domains.count) domäner: \(domains.joined(separator: ", "))"
                ))
            }
        }

        // Phase 3: Find causal chains across articles
        for article in articles.prefix(50) {
            let causes = extractCausalRelations(from: article.content)
            for cause in causes {
                // Check if effects appear as causes in other articles
                for otherArticle in articles where otherArticle.id != article.id {
                    let otherCauses = extractCausalRelations(from: otherArticle.content)
                    for otherCause in otherCauses {
                        if cause.effect.lowercased().contains(otherCause.cause.lowercased()) ||
                           otherCause.cause.lowercased().contains(cause.effect.lowercased()) {
                            insights.append(CrossDomainInsight(
                                concept: "\(cause.cause) → \(cause.effect) → \(otherCause.effect)",
                                domains: [article.domain, otherArticle.domain],
                                articleTitles: [article.title, otherArticle.title],
                                type: .causalChain,
                                description: "Kausalkedja: '\(cause.cause)' i \(article.domain) leder till '\(cause.effect)', som i sin tur orsakar '\(otherCause.effect)' i \(otherArticle.domain)."
                            ))
                        }
                    }
                }
            }
        }

        // Phase 4: Semantic similarity between articles from different domains
        let hasNeuralEngine = await neuralEngine.isLoaded
        if hasNeuralEngine {
            var articleEmbeddings: [(article: KnowledgeArticle, embedding: [Float])] = []
            for article in articles.prefix(40) {
                let emb = await neuralEngine.embed(article.title + " " + article.summary)
                if !emb.allSatisfy({ $0 == 0 }) {
                    articleEmbeddings.append((article, emb))
                }
            }

            for i in 0..<articleEmbeddings.count {
                for j in (i+1)..<articleEmbeddings.count {
                    let a = articleEmbeddings[i]
                    let b = articleEmbeddings[j]
                    guard a.article.domain != b.article.domain else { continue }

                    let similarity = await neuralEngine.cosineSimilarity(a.embedding, b.embedding)
                    if similarity > 0.6 {
                        insights.append(CrossDomainInsight(
                            concept: "Semantisk koppling (likhet: \(String(format: "%.0f%%", similarity * 100)))",
                            domains: [a.article.domain, b.article.domain],
                            articleTitles: [a.article.title, b.article.title],
                            type: .semanticSimilarity,
                            description: "Artiklarna '\(a.article.title)' (\(a.article.domain)) och '\(b.article.title)' (\(b.article.domain)) har stark semantisk likhet trots att de tillhör olika domäner."
                        ))
                    }
                }
            }
        }

        return insights.sorted { $0.articleTitles.count > $1.articleTitles.count }
    }

    // MARK: - Private Helpers

    private func extractKeyConcepts(from text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var concepts: Set<String> = []

        // Extract noun phrases (simple heuristic: capitalized multi-word sequences)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for i in 0..<words.count {
            let word = words[i].trimmingCharacters(in: .punctuationCharacters)
            guard word.count > 3 else { continue }

            // Capitalized words (likely proper nouns or important concepts)
            if word.first?.isUppercase == true && i > 0 {
                concepts.insert(word)
            }

            // Domain-specific terms (words with technical suffixes)
            let lower = word.lowercased()
            let technicalSuffixes = ["tion", "sion", "ologi", "grafi", "ment", "itet", "ism", "ist", "ning", "else"]
            if technicalSuffixes.contains(where: { lower.hasSuffix($0) }) && word.count > 5 {
                concepts.insert(word.lowercased())
            }
        }

        // Extract "X är Y" patterns
        for sentence in sentences {
            let parts = sentence.components(separatedBy: " är ")
            if parts.count >= 2, let subject = parts.first {
                let cleanSubject = subject.components(separatedBy: .whitespaces).suffix(3).joined(separator: " ")
                if cleanSubject.count > 3 {
                    concepts.insert(cleanSubject)
                }
            }
        }

        return Array(concepts).sorted()
    }

    private func extractCausalRelations(from text: String) -> [CausalRelation] {
        var relations: [CausalRelation] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let causalPatterns: [(pattern: String, type: String)] = [
            ("(.*?) leder till (.*)", "leder_till"),
            ("(.*?) orsakar (.*)", "orsakar"),
            ("(.*?) resulterar i (.*)", "resulterar_i"),
            ("(.*?) beror på (.*)", "beror_på"),
            ("(.*?) på grund av (.*)", "på_grund_av"),
            ("(.*?) bidrar till (.*)", "bidrar_till"),
            ("(.*?) möjliggör (.*)", "möjliggör"),
            ("(.*?) förhindrar (.*)", "förhindrar"),
            ("(.*?) påverkar (.*)", "påverkar"),
            ("eftersom (.*?), (.*)", "eftersom"),
            ("(.*?) därför (.*)", "därför"),
        ]

        for sentence in sentences {
            for (pattern, type) in causalPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)),
                   match.numberOfRanges >= 3 {
                    let cause = String(sentence[Range(match.range(at: 1), in: sentence)!])
                        .trimmingCharacters(in: .whitespaces)
                    let effect = String(sentence[Range(match.range(at: 2), in: sentence)!])
                        .trimmingCharacters(in: .whitespaces)

                    if cause.count > 3 && effect.count > 3 && cause.count < 100 && effect.count < 100 {
                        relations.append(CausalRelation(
                            cause: cause,
                            effect: effect,
                            type: type,
                            confidence: 0.6
                        ))
                    }
                }
            }
        }

        return relations
    }

    private func findCrossDomainLinks(
        article: KnowledgeArticle,
        concepts: [String],
        allArticles: [KnowledgeArticle]
    ) async -> [CrossDomainLink] {
        var links: [CrossDomainLink] = []

        for otherArticle in allArticles {
            guard otherArticle.domain != article.domain else { continue }

            var sharedConcepts: [String] = []
            for concept in concepts {
                let lower = concept.lowercased()
                if otherArticle.content.lowercased().contains(lower) ||
                   otherArticle.title.lowercased().contains(lower) {
                    sharedConcepts.append(concept)
                }
            }

            if !sharedConcepts.isEmpty {
                links.append(CrossDomainLink(
                    fromArticle: article.title,
                    toArticle: otherArticle.title,
                    fromDomain: article.domain,
                    toDomain: otherArticle.domain,
                    sharedConcepts: sharedConcepts,
                    strength: min(1.0, Double(sharedConcepts.count) * 0.2)
                ))
            }
        }

        return links.sorted { $0.strength > $1.strength }
    }

    private func extractFactsFromArticle(content: String, domain: String) -> [ExtractedFact] {
        var facts: [ExtractedFact] = []
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 10 && $0.count < 200 }

        // "X är Y" patterns
        for sentence in sentences.prefix(30) {
            let parts = sentence.components(separatedBy: " är ")
            if parts.count >= 2 {
                let subject = parts[0].components(separatedBy: .whitespaces).suffix(4).joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                let object = parts[1].components(separatedBy: .whitespaces).prefix(6).joined(separator: " ")
                    .trimmingCharacters(in: .punctuationCharacters)

                if subject.count > 2 && object.count > 2 {
                    facts.append(ExtractedFact(
                        subject: subject,
                        predicate: "är",
                        object: object,
                        confidence: 0.65
                    ))
                }
            }

            // "X har Y" patterns
            let harParts = sentence.components(separatedBy: " har ")
            if harParts.count >= 2 {
                let subject = harParts[0].components(separatedBy: .whitespaces).suffix(3).joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                let object = harParts[1].components(separatedBy: .whitespaces).prefix(5).joined(separator: " ")
                    .trimmingCharacters(in: .punctuationCharacters)

                if subject.count > 2 && object.count > 2 {
                    facts.append(ExtractedFact(
                        subject: subject,
                        predicate: "har",
                        object: object,
                        confidence: 0.55
                    ))
                }
            }
        }

        return facts
    }
}

// MARK: - Data Models

struct ArticleComprehension {
    let article: KnowledgeArticle
    let keyConcepts: [String]
    let causalRelations: [CausalRelation]
    let crossDomainLinks: [CrossDomainLink]
    let extractedFacts: [ExtractedFact]
}

struct CausalRelation: Identifiable {
    let id = UUID()
    let cause: String
    let effect: String
    let type: String
    let confidence: Double
}

struct CrossDomainLink: Identifiable {
    let id = UUID()
    let fromArticle: String
    let toArticle: String
    let fromDomain: String
    let toDomain: String
    let sharedConcepts: [String]
    let strength: Double
}

struct CrossDomainInsight: Identifiable {
    let id = UUID()
    let concept: String
    let domains: [String]
    let articleTitles: [String]
    let type: InsightType
    let description: String

    enum InsightType: String {
        case sharedConcept = "Delat begrepp"
        case causalChain = "Kausalkedja"
        case semanticSimilarity = "Semantisk likhet"
        case contradiction = "Kontradiktion"
    }
}

struct ExtractedFact {
    let subject: String
    let predicate: String
    let object: String
    let confidence: Double
}
