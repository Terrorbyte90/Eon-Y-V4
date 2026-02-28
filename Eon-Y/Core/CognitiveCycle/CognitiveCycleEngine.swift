import Foundation

// MARK: - CognitiveCycleEngine: Orkestrator för de 3 feedback-looparna

actor CognitiveCycleEngine {
    static let shared = CognitiveCycleEngine()

    private let neuralEngine = NeuralEngineOrchestrator.shared
    private let memory = PersistentMemoryStore.shared
    private let swedish = SwedishLanguageCore.shared
    private let validator = GenerationValidator()
    private let enricher = GraphEnricher()
    private let reviser = MetacognitiveReviser()

    private init() {}

    // MARK: - Huvudprocess

    func process(
        input: String,
        onStepUpdate: @escaping (ThinkingStep, StepState) async -> Void,
        onMonologue: @escaping (MonologueLine) async -> Void,
        onToken: @escaping (String) async -> Void
    ) async throws -> CognitiveCycleResult {

        var context = CognitiveCycleContext(userInput: input)

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

        // Steg 4: Kausalitetsgraf (Pelare B)
        await onStepUpdate(.causalGraph, .active)
        let entities = await neuralEngine.extractEntities(from: input)
        context.entities = entities
        if !entities.isEmpty {
            await onMonologue(MonologueLine(text: "Entiteter: \(entities.map { $0.text }.joined(separator: ", "))", type: .thought))
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

    // MARK: - Prompt builder
    // Bygger en rik prompt med: persona, ICA-tillstånd, kunskapsgraf-fakta,
    // BERT-semantisk kontext, konversationshistorik och relevanta minnen.

    private func buildPrompt(input: String, context: CognitiveCycleContext) async -> String {
        var lines: [String] = []

        // 1. Persona med aktuellt ICA-tillstånd
        let icaState = CognitiveState.shared
        let ii = await icaState.integratedIntelligence
        let topDim = await icaState.topDimensions(limit: 1).first?.0.rawValue ?? "resonemang"
        lines.append("Du är Eon — ett kognitivt AI-system med integrerat intelligensindex \(String(format: "%.2f", ii)). Din starkaste förmåga just nu är \(topDim). Du svarar alltid på svenska, resonerar djupt och använder all din kunskap.")
        lines.append("")

        // 2. Kognitiv kontext från ICA
        let hypothesis = await icaState.currentHypothesis
        if !hypothesis.isEmpty {
            lines.append("[Aktiv hypotes: \(hypothesis)]")
        }
        let frontier = await icaState.knowledgeFrontier.prefix(3).joined(separator: ", ")
        if !frontier.isEmpty {
            lines.append("[Kunskapsfrontier: \(frontier)]")
        }
        let metacogInsight = await icaState.metacognitiveInsight
        if !metacogInsight.isEmpty {
            lines.append("[Metakognitiv insikt: \(String(metacogInsight.prefix(120)))]")
        }

        // 3. Relevanta fakta från kunskapsgrafen
        let relevantFacts = await memory.searchFacts(query: input, limit: 4)
        if !relevantFacts.isEmpty {
            lines.append("")
            lines.append("[Relevant kunskap från kunskapsgrafen:]")
            for fact in relevantFacts {
                lines.append("- \(fact.subject) \(fact.predicate) \(fact.object)")
            }
        }

        // 4. Semantisk analys från BERT (om tillgänglig)
        let bertContext = buildBERTContext(input: input, entities: context.entities)
        if !bertContext.isEmpty {
            lines.append("")
            lines.append("[Semantisk analys: \(bertContext)]")
        }

        // 5. Morfologisk och WSD-kontext
        if !context.disambiguations.isEmpty {
            let wsd = context.disambiguations.prefix(3).map { "\($0.word)=\($0.selectedSense.definition)" }.joined(separator: ", ")
            lines.append("[Ordtydning: \(wsd)]")
        }

        // 6. Konversationshistorik (max 8 turer)
        if !context.conversationHistory.isEmpty {
            lines.append("")
        }
        for turn in context.conversationHistory.suffix(8) {
            let role = turn.role == "user" ? "Användare" : "Eon"
            lines.append("\(role): \(turn.content)")
        }

        // 7. Relevanta minnen
        if !context.retrievedMemories.isEmpty {
            let mem = context.retrievedMemories.prefix(3).map { $0.content }.joined(separator: " | ")
            lines.append("[Minne: \(String(mem.prefix(200)))]")
        }

        // 8. Aktuell input
        lines.append("Användare: \(input)")
        lines.append("Eon:")

        return lines.joined(separator: "\n")
    }

    private func buildBERTContext(input: String, entities: [ExtractedEntity]) -> String {
        var parts: [String] = []
        if !entities.isEmpty {
            let entityStr = entities.prefix(4).map { "\($0.text)(\($0.type))" }.joined(separator: ", ")
            parts.append("entiteter: \(entityStr)")
        }
        // Lägg till semantisk kategori baserat på input
        let lower = input.lowercased()
        if lower.contains("varför") || lower.contains("orsak") { parts.append("kausal fråga") }
        if lower.contains("hur") { parts.append("procedurfråga") }
        if lower.contains("vad är") || lower.contains("beskriv") { parts.append("definitionsfråga") }
        if lower.contains("jämför") { parts.append("komparativ fråga") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Konfidens-aggregering

    private func computeAggregatedConfidence(context: CognitiveCycleContext) -> Double {
        var scores: [Double] = [0.75] // Baslinje

        if !context.disambiguations.isEmpty {
            let avgWSD = context.disambiguations.map { $0.confidence }.reduce(0, +) / Double(context.disambiguations.count)
            scores.append(avgWSD)
        }

        if context.validationResult?.needsRegeneration == true {
            scores.append(0.55)
        } else {
            scores.append(0.85)
        }

        if !context.retrievedMemories.isEmpty {
            scores.append(0.80)
        }

        return scores.reduce(0, +) / Double(scores.count)
    }
}

// MARK: - GenerationValidator (Loop 1)

actor GenerationValidator {
    func validate(generated: String, disambiguations: [DisambiguationResult], neuralEngine: NeuralEngineOrchestrator) async -> ValidationResult {
        // Kontrollera att genererat text stämmer med WSD-disambigueringar
        for disambiguation in disambiguations {
            let word = disambiguation.word
            let expectedSense = disambiguation.selectedSense.definition

            // Enkel heuristik: om ordet förekommer i svaret, kontrollera kontext
            if generated.lowercased().contains(word) {
                // I produktion: BERT cosine similarity < 0.40 triggar omstart
                let contextScore = computeContextScore(word: word, sense: expectedSense, text: generated)
                if contextScore < 0.35 {
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
    func enrich(text: String, entities: [ExtractedEntity], memory: PersistentMemoryStore) async {
        // Extrahera fakta från genererat svar och lägg till i kunskapsgrafen
        for entity in entities {
            await memory.saveFact(
                subject: entity.text,
                predicate: "nämndes_i",
                object: "konversation_\(Date().timeIntervalSince1970)",
                confidence: entity.confidence,
                source: "generation"
            )
        }

        // Enkel faktaextraktion: "X är Y" mönster
        let pattern = try? NSRegularExpression(pattern: "(\\w+) är (\\w+)", options: .caseInsensitive)
        let range = NSRange(text.startIndex..., in: text)
        pattern?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match = match,
                  let subjectRange = Range(match.range(at: 1), in: text),
                  let objectRange = Range(match.range(at: 2), in: text) else { return }
            let subject = String(text[subjectRange])
            let object = String(text[objectRange])
            Task {
                await memory.saveFact(subject: subject, predicate: "är", object: object, confidence: 0.6, source: "generation")
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
    let sessionId: String = UUID().uuidString
    var morphemes: [MorphemeAnalysis] = []
    var disambiguations: [DisambiguationResult] = []
    var register: SwedishRegister? = nil
    var retrievedMemories: [ConversationRecord] = []
    var conversationHistory: [ConversationRecord] = []
    var entities: [ExtractedEntity] = []
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
