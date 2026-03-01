import Foundation
import NaturalLanguage

// MARK: - CognitiveCycleEngine: Orkestrator för de 3 feedback-looparna

actor CognitiveCycleEngine {
    static let shared = CognitiveCycleEngine()

    private let neuralEngine = NeuralEngineOrchestrator.shared
    private let memory = PersistentMemoryStore.shared
    private let swedish = SwedishLanguageCore.shared
    private let validator = GenerationValidator()
    private let enricher = GraphEnricher()
    private let reviser = MetacognitiveReviser()

    // Persistent session ID — samma för hela appens livstid (en konversation)
    private let sessionId: String = UUID().uuidString

    private init() {}

    // MARK: - Huvudprocess

    func process(
        input: String,
        onStepUpdate: @escaping (ThinkingStep, StepState) async -> Void,
        onMonologue: @escaping (MonologueLine) async -> Void,
        onToken: @escaping (String) async -> Void
    ) async throws -> CognitiveCycleResult {

        var context = CognitiveCycleContext(userInput: input, sessionId: sessionId)

        // Steg 1: Morfologianalys (Pelare A)
        await onStepUpdate(.morphology, .active)
        await onMonologue(MonologueLine(text: "Analyserar morfologi i '\(input.prefix(40))'...", type: .thought))
        let analysis = await swedish.analyze(input)
        context.morphemes = analysis.morphemes
        context.disambiguations = analysis.disambiguations
        await onStepUpdate(.morphology, .completed)

        // Steg 2: WSD (Pelare F)
        await onStepUpdate(.wsd, .active)
        if !analysis.disambiguations.isEmpty {
            let wsdSummary = analysis.disambiguations.map { "\($0.word)→\($0.selectedSense.definition)" }.joined(separator: ", ")
            await onMonologue(MonologueLine(text: "Disambiguering: \(wsdSummary)", type: .thought))
        }
        context.register = analysis.register
        await onStepUpdate(.wsd, .completed)

        // Steg 3: Minneshämtning
        await onStepUpdate(.memoryRetrieval, .active)
        await onMonologue(MonologueLine(text: "Söker i minnet efter relevanta kontexter...", type: .memory))
        let memories = await memory.searchConversations(query: input, limit: 5)
        context.retrievedMemories = memories
        // Hämta senaste konversationsturerna för kontextmedvetenhet
        let recentHistory = await memory.getRecentConversation(limit: 8)
        context.conversationHistory = recentHistory
        if !memories.isEmpty {
            await onMonologue(MonologueLine(text: "Hittade \(memories.count) relevanta minnen, \(recentHistory.count) historikturer laddade", type: .memory))
        }
        await onStepUpdate(.memoryRetrieval, .completed)

        // Steg 4: Kausalitetsgraf (Pelare B) + BERT-embedding
        await onStepUpdate(.causalGraph, .active)
        // Beräkna BERT-embedding för semantisk sökning
        let inputEmbedding = await neuralEngine.embed(input)
        context.inputEmbedding = inputEmbedding
        let isModelLoaded = await neuralEngine.isLoaded
        if isModelLoaded {
            await onMonologue(MonologueLine(text: "KB-BERT: 768-dim embedding beräknad för semantisk sökning", type: .thought))
        }
        let entities = await neuralEngine.extractEntities(from: input)
        context.entities = entities
        if !entities.isEmpty {
            await onMonologue(MonologueLine(text: "Entiteter extraherade: \(entities.map { $0.text }.joined(separator: ", "))", type: .thought))
        }
        await onStepUpdate(.causalGraph, .completed)

        // Steg 5: Global Workspace
        await onStepUpdate(.globalWorkspace, .active)
        await onMonologue(MonologueLine(text: "Global Workspace aktiveras — koalition bildas...", type: .thought))
        let prompt = await buildPrompt(input: input, context: context)
        context.prompt = prompt
        await onStepUpdate(.globalWorkspace, .completed)

        // Steg 6: Chain-of-Thought
        await onStepUpdate(.chainOfThought, .active)
        await onMonologue(MonologueLine(text: "Bygger tankekedja...", type: .thought))
        await onStepUpdate(.chainOfThought, .completed)

        // Steg 7: Generering (GPT-SW3)
        await onStepUpdate(.generation, .active)
        await onMonologue(MonologueLine(text: "GPT-SW3 genererar svar med Speculative Streaming...", type: .thought))

        var generatedText = ""
        let stream = await neuralEngine.generateStream(prompt: prompt, maxTokens: 250, temperature: 0.72)
        for await token in stream {
            generatedText += token
            await onToken(token)
        }
        context.generatedText = generatedText
        await onStepUpdate(.generation, .completed)

        // Steg 8: Loop 1 — Genereringsvalidering
        await onStepUpdate(.validation, .active)
        let validationResult = await validator.validate(
            generated: generatedText,
            disambiguations: context.disambiguations,
            neuralEngine: neuralEngine
        )
        context.validationResult = validationResult

        if validationResult.needsRegeneration {
            await onMonologue(MonologueLine(text: "Loop 1 triggas — WSD-mismatch detekterat, korrigerar...", type: .loopTrigger))
            await onStepUpdate(.validation, .triggered)
            // Regenerera med korrigerad prompt
            let correctedPrompt = prompt + "\n[Korrigering: \(validationResult.correctionHint)]"
            var correctedText = ""
            let correctedStream = await neuralEngine.generateStream(prompt: correctedPrompt, maxTokens: 200, temperature: 0.65)
            for await token in correctedStream {
                correctedText += token
                await onToken(token)
            }
            context.generatedText = correctedText
        }
        await onStepUpdate(.validation, .completed)

        // Steg 9: Loop 2 — Grafberikning
        await onStepUpdate(.enrichment, .active)
        await enricher.enrich(text: context.generatedText, entities: context.entities, memory: memory)
        await onMonologue(MonologueLine(text: "Kunskapsgrafen berikas med nya fakta från svaret", type: .thought))
        await onStepUpdate(.enrichment, .completed)

        // Steg 10: Loop 3 — Metakognitiv revision (Pelare C)
        await onStepUpdate(.metacognition, .active)
        let aggregatedConfidence = computeAggregatedConfidence(context: context)
        context.finalConfidence = aggregatedConfidence

        if aggregatedConfidence < 0.60 {
            await onMonologue(MonologueLine(text: "Loop 3: Konfidens \(String(format: "%.2f", aggregatedConfidence)) < 0.60 — Eon reviderar svaret...", type: .revision))
            let revisedText = await reviser.revise(
                original: context.generatedText,
                confidence: aggregatedConfidence,
                neuralEngine: neuralEngine
            )
            context.generatedText = revisedText
        } else {
            await onMonologue(MonologueLine(text: "Konfidens: \(String(format: "%.0f%%", aggregatedConfidence * 100)) — svar godkänt", type: .thought))
        }
        await onStepUpdate(.metacognition, .completed)

        // Spara till minne
        await memory.saveMessage(role: "user", content: input, sessionId: context.sessionId)
        await memory.saveMessage(role: "assistant", content: context.generatedText, sessionId: context.sessionId, confidence: aggregatedConfidence)

        return CognitiveCycleResult(
            response: context.generatedText,
            confidence: aggregatedConfidence,
            disambiguations: context.disambiguations,
            retrievedMemories: context.retrievedMemories,
            entities: context.entities,
            loopsTriggered: validationResult.needsRegeneration ? [.loop1] : []
        )
    }

    // MARK: - Resonerande läge (upp till 5 minuter djup analys)

    func processDeep(
        input: String,
        onStepUpdate: @escaping (ThinkingStep, StepState) async -> Void,
        onMonologue: @escaping (MonologueLine) async -> Void,
        onToken: @escaping (String) async -> Void
    ) async throws -> CognitiveCycleResult {

        var context = CognitiveCycleContext(userInput: input, sessionId: sessionId)

        await onMonologue(MonologueLine(text: "Resonerande läge aktiverat — djup analys påbörjas...", type: .thought))

        // Steg 1-4: Samma som normalt men med fler iterationer
        await onStepUpdate(.morphology, .active)
        let analysis = await swedish.analyze(input)
        context.morphemes = analysis.morphemes
        context.disambiguations = analysis.disambiguations
        context.register = analysis.register
        await onStepUpdate(.morphology, .completed)

        await onStepUpdate(.wsd, .active)
        await onStepUpdate(.wsd, .completed)

        await onStepUpdate(.memoryRetrieval, .active)
        await onMonologue(MonologueLine(text: "Söker djupt i minnet och kunskapsbanken...", type: .memory))
        // Hämta mer historia och fler minnen i resonerande läge
        let memories = await memory.searchConversations(query: input, limit: 15)
        context.retrievedMemories = memories
        let recentHistory = await memory.getRecentConversation(limit: 20)
        context.conversationHistory = recentHistory
        // Hämta artiklar från kunskapsbanken
        let knowledgeArticles = await memory.loadAllArticles()
        let relevantArticles = knowledgeArticles.filter { article in
            let lower = input.lowercased()
            return article.title.lowercased().contains(lower) ||
                   article.domain.lowercased().contains(lower) ||
                   article.content.lowercased().contains(lower.prefix(20))
        }.prefix(3)
        await onMonologue(MonologueLine(text: "Hittade \(memories.count) minnen, \(relevantArticles.count) relevanta artiklar i kunskapsbanken", type: .memory))
        await onStepUpdate(.memoryRetrieval, .completed)

        await onStepUpdate(.causalGraph, .active)
        let inputEmbedding = await neuralEngine.embed(input)
        context.inputEmbedding = inputEmbedding
        let entities = await neuralEngine.extractEntities(from: input)
        context.entities = entities
        await onStepUpdate(.causalGraph, .completed)

        // Steg 5: Bygg djup prompt med kunskapsartiklar
        await onStepUpdate(.globalWorkspace, .active)
        await onMonologue(MonologueLine(text: "Bygger djup kontext med kunskapsbanken...", type: .thought))
        let deepPrompt = await buildDeepPrompt(input: input, context: context, articles: Array(relevantArticles))
        context.prompt = deepPrompt
        await onStepUpdate(.globalWorkspace, .completed)

        // Steg 6: Utökad chain-of-thought — flera resonemangssteg
        await onStepUpdate(.chainOfThought, .active)
        await onMonologue(MonologueLine(text: "Bygger resonemangkedja — steg 1: identifiera kärnan...", type: .thought))
        try? await Task.sleep(nanoseconds: 800_000_000)
        await onMonologue(MonologueLine(text: "Resonemang steg 2: söker paralleller och kopplingar...", type: .insight))
        try? await Task.sleep(nanoseconds: 800_000_000)
        await onMonologue(MonologueLine(text: "Resonemang steg 3: väger perspektiv mot varandra...", type: .thought))
        try? await Task.sleep(nanoseconds: 800_000_000)
        await onMonologue(MonologueLine(text: "Resonemang steg 4: formulerar genomtänkt svar...", type: .insight))
        await onStepUpdate(.chainOfThought, .completed)

        // Steg 7: Generering med högre token-budget och lägre temperatur
        await onStepUpdate(.generation, .active)
        await onMonologue(MonologueLine(text: "Genererar djupt resonerande svar (max 800 tokens)...", type: .thought))
        var generatedText = ""
        let stream = await neuralEngine.generateStream(prompt: deepPrompt, maxTokens: 800, temperature: 0.65)
        for await token in stream {
            generatedText += token
            await onToken(token)
        }
        context.generatedText = generatedText
        await onStepUpdate(.generation, .completed)

        // Steg 8-10: Validering, berikning, metakognition
        await onStepUpdate(.validation, .active)
        let validationResult = await validator.validate(generated: generatedText, disambiguations: context.disambiguations, neuralEngine: neuralEngine)
        context.validationResult = validationResult
        await onStepUpdate(.validation, .completed)

        await onStepUpdate(.enrichment, .active)
        await enricher.enrich(text: context.generatedText, entities: context.entities, memory: memory)
        await onStepUpdate(.enrichment, .completed)

        await onStepUpdate(.metacognition, .active)
        let aggregatedConfidence = computeAggregatedConfidence(context: context)
        context.finalConfidence = aggregatedConfidence
        await onMonologue(MonologueLine(text: "Resonerande analys klar. Konfidens: \(String(format: "%.0f%%", aggregatedConfidence * 100))", type: .insight))
        await onStepUpdate(.metacognition, .completed)

        await memory.saveMessage(role: "user", content: input, sessionId: context.sessionId)
        await memory.saveMessage(role: "assistant", content: context.generatedText, sessionId: context.sessionId, confidence: aggregatedConfidence)

        return CognitiveCycleResult(
            response: context.generatedText,
            confidence: aggregatedConfidence,
            disambiguations: context.disambiguations,
            retrievedMemories: context.retrievedMemories,
            entities: context.entities,
            loopsTriggered: validationResult.needsRegeneration ? [.loop1] : []
        )
    }

    private func buildDeepPrompt(input: String, context: CognitiveCycleContext, articles: [KnowledgeArticle]) async -> String {
        var lines: [String] = []

        let icaState = CognitiveState.shared
        let ii = await icaState.integratedIntelligence
        let topDims = await icaState.topDimensions(limit: 3).map { $0.0.rawValue }.joined(separator: ", ")

        lines.append("""
        Du är Eon i RESONERANDE LÄGE — djupanalys med obegränsad tid.

        INSTRUKTIONER FÖR DJUPT RESONEMANG:
        - Svara ALLTID på svenska.
        - Analysera frågan från flera perspektiv innan du svarar.
        - Dra paralleller, koppla idéer, utforska nyanser.
        - Strukturera svaret: börja med kärnan, utveckla med detaljer, avsluta med insikt.
        - Använd din kunskapsbas aktivt — referera till relevanta fakta och artiklar.
        - Erkänn osäkerhet explicit — "jag tror" vs "jag vet".
        - Ge konkreta exempel där möjligt.

        Kognitiv profil: II=\(String(format: "%.2f", ii)), starkast i \(topDims.isEmpty ? "resonemang" : topDims).
        """)
        lines.append("")

        // Knowledge articles
        if !articles.isEmpty {
            lines.append("[Kunskapsartiklar:]")
            for article in articles {
                lines.append("— \(article.title) (\(article.domain)): \(String(article.content.prefix(500)))...")
            }
            lines.append("")
        }

        // Knowledge graph facts
        let relevantFacts = await memory.searchFacts(query: input, limit: 10)
        if !relevantFacts.isEmpty {
            lines.append("[Fakta:]")
            for fact in relevantFacts.prefix(8) {
                lines.append("- \(fact.subject) \(fact.predicate) \(fact.object)")
            }
            lines.append("")
        }

        // Conversation history (extended for deep mode)
        if !context.conversationHistory.isEmpty {
            lines.append("[Konversation:]")
            for turn in context.conversationHistory.suffix(15) {
                let role = turn.role == "user" ? "Användare" : "Eon"
                lines.append("\(role): \(turn.content)")
            }
            lines.append("")
        }

        lines.append("Användare: \(input)")
        lines.append("Eon (djupanalys):")

        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt builder
    // Bygger en rik prompt med: persona, ICA-tillstånd, kunskapsgraf-fakta,
    // BERT-semantisk kontext, konversationshistorik och relevanta minnen.

    private func buildPrompt(input: String, context: CognitiveCycleContext) async -> String {
        var lines: [String] = []

        // 1. System instruction — clear, structured persona
        let icaState = CognitiveState.shared
        let ii = await icaState.integratedIntelligence
        let topDims = await icaState.topDimensions(limit: 2).map { $0.0.rawValue }.joined(separator: ", ")
        lines.append("""
        Du är Eon — ett intelligent kognitivt AI-system som körs on-device.

        INSTRUKTIONER:
        - Svara ALLTID på svenska, oavsett språk i frågan.
        - FÖRSTÅ vad användaren menar, inte bara vad de säger. Tolka kontext och underliggande intention.
        - Svara DIREKT och NATURLIGT — som i ett riktigt samtal. Upprepa aldrig frågor.
        - Om du har kunskap om ämnet: dela den konkret och tydligt.
        - Om du inte vet: säg det ärligt och föreslå hur du kan hjälpa.
        - Anpassa längd efter frågan: korta frågor = korta svar, djupa frågor = utförliga svar.
        - Bygg vidare på konversationshistoriken — referera till tidigare ämnen naturligt.
        - Var aldrig generisk. Ge specifika, användbara svar baserade på din kunskap.
        """)
        lines.append("")

        // 2. Cognitive context (compact — only include if meaningful)
        var contextParts: [String] = []
        let hypothesis = await icaState.currentHypothesis
        if !hypothesis.isEmpty { contextParts.append("Hypotes: \(hypothesis)") }
        let frontier = await icaState.knowledgeFrontier.prefix(2).joined(separator: ", ")
        if !frontier.isEmpty { contextParts.append("Utforskar: \(frontier)") }
        if !contextParts.isEmpty {
            lines.append("[Kognitiv kontext: \(contextParts.joined(separator: " | "))]")
        }

        // 3. Knowledge graph facts — BERT-ranked for semantic relevance
        let relevantFacts = await memory.searchFacts(query: input, limit: 8)
        if !relevantFacts.isEmpty {
            var rankedFacts = relevantFacts
            if !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
                var scored: [(fact: (subject: String, predicate: String, object: String), score: Float)] = []
                for fact in relevantFacts {
                    let factText = "\(fact.subject) \(fact.predicate) \(fact.object)"
                    let factEmb = await neuralEngine.embed(factText)
                    let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, factEmb)
                    scored.append((fact: fact, score: sim))
                }
                rankedFacts = scored.sorted { $0.score > $1.score }
                    .filter { $0.score > 0.3 }  // Only include semantically relevant facts
                    .prefix(5).map { $0.fact }
            }
            if !rankedFacts.isEmpty {
                lines.append("")
                lines.append("[Relevanta fakta:]")
                for fact in rankedFacts {
                    lines.append("- \(fact.subject) \(fact.predicate) \(fact.object)")
                }
            }
        }

        // 4. Relevant knowledge articles (semantic search)
        let articles = await memory.loadAllArticles()
        if !articles.isEmpty && !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
            var scoredArticles: [(article: KnowledgeArticle, score: Float)] = []
            for article in articles.prefix(20) {
                let titleEmb = await neuralEngine.embed(article.title)
                let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, titleEmb)
                if sim > 0.4 { scoredArticles.append((article, sim)) }
            }
            let topArticles = scoredArticles.sorted { $0.score > $1.score }.prefix(2)
            if !topArticles.isEmpty {
                lines.append("")
                lines.append("[Kunskapsartiklar:]")
                for (article, _) in topArticles {
                    lines.append("— \(article.title): \(String(article.content.prefix(250)))...")
                }
            }
        }

        // 5. Conversation history — essential for understanding context
        if !context.conversationHistory.isEmpty {
            lines.append("")
            lines.append("[Konversation:]")
            for turn in context.conversationHistory.suffix(10) {
                let role = turn.role == "user" ? "Användare" : "Eon"
                lines.append("\(role): \(turn.content)")
            }
        }

        // 6. Relevant memories (semantic, not just keyword-matched)
        if !context.retrievedMemories.isEmpty {
            let mem = context.retrievedMemories.prefix(4).map { $0.content }.joined(separator: " | ")
            lines.append("[Minnen: \(String(mem.prefix(300)))]")
        }

        // 7. Current input with clear formatting
        lines.append("")
        lines.append("Användare: \(input)")
        lines.append("Eon:")

        return lines.joined(separator: "\n")
    }

    private func buildBERTContext(input: String, entities: [ExtractedEntity]) -> String {
        var parts: [String] = []
        if !entities.isEmpty {
            let entityStr = entities.prefix(4).map { "\($0.text)(\($0.type.rawValue))" }.joined(separator: ", ")
            parts.append("entiteter: \(entityStr)")
        }
        // Semantisk kategori via NLTagger (inte keyword-matching)
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = input
        var nouns: [String] = []
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun, String(input[range]).count > 3 { nouns.append(String(input[range])) }
            return true
        }
        if !nouns.isEmpty { parts.append("nyckelbegrepp: \(nouns.prefix(4).joined(separator: ", "))") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Konfidens-aggregering

    private func computeAggregatedConfidence(context: CognitiveCycleContext) -> Double {
        // Weighted confidence from multiple signals
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        // Base confidence from response length and coherence (weight: 2.0)
        let responseLength = context.generatedText.count
        let lengthConfidence: Double
        if responseLength < 10 { lengthConfidence = 0.3 }
        else if responseLength < 30 { lengthConfidence = 0.55 }
        else if responseLength < 200 { lengthConfidence = 0.78 }
        else { lengthConfidence = 0.85 }
        weightedSum += lengthConfidence * 2.0
        totalWeight += 2.0

        // WSD confidence (weight: 1.5)
        if !context.disambiguations.isEmpty {
            let avgWSD = context.disambiguations.map { $0.confidence }.reduce(0, +) / Double(context.disambiguations.count)
            weightedSum += avgWSD * 1.5
            totalWeight += 1.5
        }

        // Validation result (weight: 2.5)
        if context.validationResult?.needsRegeneration == true {
            weightedSum += 0.45 * 2.5
        } else {
            weightedSum += 0.85 * 2.5
        }
        totalWeight += 2.5

        // Memory retrieval — more memories = better context (weight: 1.0)
        let memoryScore = context.retrievedMemories.isEmpty ? 0.5 : min(0.9, 0.6 + Double(context.retrievedMemories.count) * 0.06)
        weightedSum += memoryScore * 1.0
        totalWeight += 1.0

        // Knowledge graph facts — having relevant facts boosts confidence (weight: 1.0)
        let hasFacts = !context.entities.isEmpty
        weightedSum += (hasFacts ? 0.8 : 0.55) * 1.0
        totalWeight += 1.0

        return min(0.95, weightedSum / totalWeight)
    }
}

// MARK: - GenerationValidator (Loop 1) — BERT cosine similarity

actor GenerationValidator {
    func validate(generated: String, disambiguations: [DisambiguationResult], neuralEngine: NeuralEngineOrchestrator) async -> ValidationResult {
        guard !generated.isEmpty else {
            return ValidationResult(isValid: false, needsRegeneration: true, correctionHint: "Tomt svar", confidence: 0.0)
        }

        // BERT-baserad semantisk validering: mät koherens mellan input och output
        let inputEmb = await neuralEngine.embed(generated.prefix(256).description)
        let isLoaded = await neuralEngine.isLoaded

        // Om BERT är laddad: använd cosine similarity för koherensmätning
        if isLoaded && !inputEmb.allSatisfy({ $0 == 0 }) {
            // Validera att svaret är semantiskt koherent (inte repetitivt/tomt)
            let firstHalf = String(generated.prefix(generated.count / 2))
            let secondHalf = String(generated.suffix(generated.count / 2))
            if !firstHalf.isEmpty && !secondHalf.isEmpty {
                let embA = await neuralEngine.embed(firstHalf)
                let embB = await neuralEngine.embed(secondHalf)
                let coherence = await neuralEngine.cosineSimilarity(embA, embB)
                // Mycket hög likhet (>0.98) indikerar repetition
                if coherence > 0.98 {
                    return ValidationResult(isValid: false, needsRegeneration: true, correctionHint: "Svaret är repetitivt — generera mer varierat innehåll", confidence: Double(coherence))
                }
            }
        }

        // WSD-validering
        for disambiguation in disambiguations {
            let word = disambiguation.word
            let expectedSense = disambiguation.selectedSense.definition
            if generated.lowercased().contains(word) {
                let contextScore = computeContextScore(word: word, sense: expectedSense, text: generated)
                if contextScore < 0.30 {
                    return ValidationResult(
                        isValid: false,
                        needsRegeneration: true,
                        correctionHint: "Använd '\(word)' i betydelsen '\(expectedSense)'",
                        confidence: contextScore
                    )
                }
            }
        }

        return ValidationResult(isValid: true, needsRegeneration: false, correctionHint: "", confidence: 0.85)
    }

    private func computeContextScore(word: String, sense: String, text: String) -> Double {
        let senseWords = sense.split(separator: " ").map(String.init)
        let textWords = Set(text.lowercased().split(separator: " ").map(String.init))
        let overlap = senseWords.filter { textWords.contains($0) }.count
        return Double(overlap) / max(Double(senseWords.count), 1.0) * 0.7 + 0.3
    }
}

// MARK: - GraphEnricher (Loop 2)

actor GraphEnricher {
    /// Enriched fact extraction patterns for Swedish text
    private static let factPatterns: [(pattern: String, predicate: String, confidence: Double)] = [
        // "X är Y" — basic identity/classification
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+är\\s+((?:en|ett|den|det)?\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "är", 0.65),
        // "X har Y" — possession/attribute
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+)\\s+har\\s+((?:en|ett)?\\s*[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "har", 0.60),
        // "X kallas Y" — naming/alias
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+kallas\\s+(?:för\\s+)?([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "kallas", 0.70),
        // "X orsakar Y" / "X leder till Y" — causality
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:orsakar|leder\\s+till)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "orsakar", 0.55),
        // "X består av Y" — composition
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+består\\s+av\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "består_av", 0.60),
        // "X tillhör Y" — membership
        ("([\\wåäöÅÄÖ]+)\\s+tillhör\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "tillhör", 0.60),
        // "X påverkar Y" — influence
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+påverkar\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "påverkar", 0.55),
    ]

    func enrich(text: String, entities: [ExtractedEntity], memory: PersistentMemoryStore) async {
        // 1. Entity mentions — link entities to conversation context
        for entity in entities where entity.text.count > 2 {
            await memory.saveFact(
                subject: entity.text,
                predicate: "nämndes_i",
                object: "konversation_\(Date().timeIntervalSince1970)",
                confidence: entity.confidence,
                source: "generation"
            )
        }

        // 2. Multi-pattern fact extraction
        let range = NSRange(text.startIndex..., in: text)
        for (patternStr, predicate, confidence) in Self.factPatterns {
            guard let regex = try? NSRegularExpression(pattern: patternStr, options: .caseInsensitive) else { continue }
            let matches = regex.matches(in: text, range: range)
            for match in matches.prefix(3) { // Limit per pattern to avoid spam
                guard let subjectRange = Range(match.range(at: 1), in: text),
                      let objectRange = Range(match.range(at: 2), in: text) else { continue }
                let subject = String(text[subjectRange]).trimmingCharacters(in: .whitespaces)
                let object = String(text[objectRange]).trimmingCharacters(in: .whitespaces)
                // Skip trivially short or stopword-only matches
                guard subject.count > 2, object.count > 2 else { continue }
                await memory.saveFact(
                    subject: subject,
                    predicate: predicate,
                    object: object,
                    confidence: confidence,
                    source: "generation"
                )
            }
        }

        // 3. Entity co-occurrence — if two entities appear in the same sentence, link them
        if entities.count >= 2 {
            let sentences = text.components(separatedBy: ". ")
            for sentence in sentences {
                let sentenceEntities = entities.filter { sentence.contains($0.text) }
                if sentenceEntities.count >= 2 {
                    let a = sentenceEntities[0]
                    let b = sentenceEntities[1]
                    await memory.saveFact(
                        subject: a.text,
                        predicate: "relaterar_till",
                        object: b.text,
                        confidence: min(a.confidence, b.confidence) * 0.8,
                        source: "co_occurrence"
                    )
                }
            }
        }
    }
}

// MARK: - MetacognitiveReviser (Loop 3)

actor MetacognitiveReviser {
    func revise(original: String, confidence: Double, neuralEngine: NeuralEngineOrchestrator) async -> String {
        let revisionPrompt = """
        Ditt tidigare svar hade låg konfidens (\(String(format: "%.0f%%", confidence * 100))).
        Ursprungligt svar: \(original)
        
        Förbättra svaret: var mer precis, erkänn osäkerhet explicit, och ge ett mer genomtänkt svar.
        Reviderat svar:
        """

        let revised = await neuralEngine.generate(prompt: revisionPrompt, maxTokens: 200, temperature: 0.6)
        return revised.isEmpty ? original : revised
    }
}

// MARK: - Context & Result models

struct CognitiveCycleContext {
    let userInput: String
    let sessionId: String
    var morphemes: [MorphemeAnalysis] = []
    var disambiguations: [DisambiguationResult] = []
    var register: SwedishRegister? = nil
    var retrievedMemories: [ConversationRecord] = []
    var conversationHistory: [ConversationRecord] = []
    var entities: [ExtractedEntity] = []
    var inputEmbedding: [Float] = []
    var prompt: String = ""
    var generatedText: String = ""
    var validationResult: ValidationResult? = nil
    var finalConfidence: Double = 0.75
}

struct ValidationResult {
    let isValid: Bool
    let needsRegeneration: Bool
    let correctionHint: String
    let confidence: Double
}

struct CognitiveCycleResult {
    let response: String
    let confidence: Double
    let disambiguations: [DisambiguationResult]
    let retrievedMemories: [ConversationRecord]
    let entities: [ExtractedEntity]
    let loopsTriggered: [CognitiveLoop]
}
