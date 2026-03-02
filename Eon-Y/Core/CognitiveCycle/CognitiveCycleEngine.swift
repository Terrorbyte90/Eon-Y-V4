import Foundation
import NaturalLanguage

// MARK: - CognitiveCycleEngine: Orkestrator för de 3 feedback-looparna

// MARK: - ComplexityEstimator
// Klassificerar en fråga som simple/medium/complex för att anpassa pipeline.
// Enkla frågor hoppar över BERT-embedding (steg 4) och grafberikning (steg 9) — sparar ANE-resurser.

struct ComplexityEstimate: Sendable {
    enum Level: Equatable, Sendable { case simple, medium, complex }
    let level: Level
    let skipBERT: Bool
    let skipEnrichment: Bool

    nonisolated func isSimple() -> Bool { level == .simple }
    nonisolated func isMedium() -> Bool { level == .medium }
}

// MARK: - ConversationIntent (top-level för att vara synlig för ComplexityEstimator)
enum ConversationIntent: String {
    case greeting      = "hälsning"
    case factualQuery  = "faktafråga"
    case explanation   = "förklaring"
    case opinion       = "åsiktsfråga"
    case creative      = "kreativ"
    case followUp      = "uppföljning"
    case command       = "kommando"
    case chitchat      = "småprat"
    case selfReference = "självreflektion"
    case emotional     = "emotionell"
    case complex       = "komplex"
}

struct ComplexityEstimator {
    nonisolated static func estimate(input: String, intent: ConversationIntent) -> ComplexityEstimate {
        let wordCount = input.split(separator: " ").count
        let hasQuestion = input.contains("?")
        let isShort = wordCount <= 5

        switch intent {
        case .greeting, .followUp:
            return ComplexityEstimate(level: .simple, skipBERT: true, skipEnrichment: true)
        case .chitchat, .emotional:
            if isShort {
                return ComplexityEstimate(level: .simple, skipBERT: true, skipEnrichment: false)
            }
        case .factualQuery where isShort && !hasQuestion:
            return ComplexityEstimate(level: .simple, skipBERT: true, skipEnrichment: false)
        case .complex, .explanation, .opinion:
            return ComplexityEstimate(level: .complex, skipBERT: false, skipEnrichment: false)
        default: break
        }

        let isComplex = wordCount > 20 || intent == .complex || intent == .explanation
        return ComplexityEstimate(
            level: isComplex ? .complex : .medium,
            skipBERT: false,
            skipEnrichment: !isComplex
        )
    }
}

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

    // MARK: - Consciousness state snapshot (hämtas från @MainActor-engines)

    /// Samlar medvetandetillstånd från alla 6 teorier för användning i prompten.
    private func gatherConsciousnessContext() async -> ConsciousnessContext {
        await MainActor.run {
            let osc = OscillatorBank.shared
            let dmn = EchoStateNetwork.shared
            let ai = ActiveInferenceEngine.shared
            let ast = AttentionSchemaEngine.shared
            let crit = CriticalityController.shared
            let sleep = SleepConsolidationEngine.shared

            return ConsciousnessContext(
                // Oscillator state
                globalSync: osc.globalSync,
                thetaGammaCFC: osc.thetaGammaCFC,
                gammaOrderParam: osc.orderParameters[4],
                oscillatorLZ: osc.lzComplexity(),
                branchingRatio: crit.branchingRatio,
                criticalityRegime: crit.regime,

                // DMN / spontaneous
                dmnActivity: dmn.activityLevel,
                dmnLZComplexity: dmn.lzComplexity,
                recentSpontaneousThoughts: dmn.spontaneousThoughts.suffix(3).map { $0.category.rawValue },

                // Active Inference
                freeEnergy: ai.freeEnergy,
                epistemicValue: ai.epistemicValue,
                pragmaticValue: ai.pragmaticValue,
                forwardModelAccuracy: ai.forwardModelAccuracy,
                isSurprised: ai.isSurprised,
                surpriseStrength: ai.surpriseStrength,

                // Attention Schema
                currentFocus: ast.currentFocus?.content ?? "Inget specifikt",
                attentionIntensity: ast.intensity,
                isVoluntaryAttention: ast.isVoluntary,
                reportableExperience: ast.selfModel.reportableExperience,
                metaAttentionLevel: ast.metaAttentionLevel,

                // Sleep
                isAsleep: sleep.isAsleep,
                sleepPressure: sleep.sleepPressure,
                consolidationEfficiency: sleep.consolidationEfficiency
            )
        }
    }

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
        // ComplexityEstimator avgör om BERT ska hoppas (enkla frågor sparar ANE-resurser)
        await onStepUpdate(.causalGraph, .active)
        let earlyIntent = detectIntent(input: input, history: context.conversationHistory)
        let earlyComplexity = ComplexityEstimator.estimate(input: input, intent: earlyIntent)
        if earlyComplexity.skipBERT {
            await onMonologue(MonologueLine(text: "Enkel fråga — BERT-embedding hoppas för att spara ANE", type: .thought))
            context.inputEmbedding = []
            context.entities = []
        } else {
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
        }
        await onStepUpdate(.causalGraph, .completed)

        // Steg 5: Global Workspace + Medvetandetillstånd
        await onStepUpdate(.globalWorkspace, .active)
        await onMonologue(MonologueLine(text: "Global Workspace aktiveras — koalition bildas...", type: .thought))

        // Samla medvetandetillstånd från alla 6 teorier
        let consciousness = await gatherConsciousnessContext()
        context.consciousness = consciousness
        if !consciousness.promptDescription.isEmpty {
            await onMonologue(MonologueLine(text: "Medvetandekontext: \(String(consciousness.promptDescription.prefix(120)))", type: .insight))
        }

        let prompt = await buildPrompt(input: input, context: context)
        context.prompt = prompt
        await onStepUpdate(.globalWorkspace, .completed)

        // Steg 6: Intent detection + ComplexityEstimator + Chain-of-Thought
        await onStepUpdate(.chainOfThought, .active)
        let intent = detectIntent(input: input, history: context.conversationHistory)
        let complexity = ComplexityEstimator.estimate(input: input, intent: intent)
        var (maxTokens, temperature) = generationParams(for: intent, inputLength: input.count)

        // Medvetandemodulerande parametrar:
        // Hög nyfikenhet → lite högre temperatur (mer kreativt utforskande)
        if consciousness.epistemicValue > 0.6 {
            temperature = min(0.92, temperature + 0.05)
        }
        // Överraskning → fler tokens för att bearbeta det oväntade
        if consciousness.isSurprised {
            maxTokens = min(800, maxTokens + 100)
        }
        // Hög sömnpress → mer konservativt
        if consciousness.sleepPressure > 0.6 {
            temperature = max(0.55, temperature - 0.05)
        }

        let complexityLabel = complexity.isSimple() ? "enkel" : complexity.isMedium() ? "medel" : "komplex"
        await onMonologue(MonologueLine(text: "Intention: \(intent.rawValue) · \(complexityLabel) · tokens: \(maxTokens) · temp: \(String(format: "%.2f", temperature))\(complexity.skipBERT ? " [BERT hoppas]" : "")", type: .thought))
        await onStepUpdate(.chainOfThought, .completed)

        // Steg 7: Generering (GPT-SW3) med adaptiva parametrar
        await onStepUpdate(.generation, .active)
        await onMonologue(MonologueLine(text: "GPT-SW3 genererar svar (\(intent.rawValue), \(complexityLabel))...", type: .thought))

        var generatedText = ""
        let stream = await neuralEngine.generateStream(prompt: prompt, maxTokens: maxTokens, temperature: Float(temperature))
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
            await onMonologue(MonologueLine(text: "Loop 1 triggas — mismatch detekterat, partial regeneration...", type: .loopTrigger))
            await onStepUpdate(.validation, .triggered)
            // Partial regeneration: behåll det som är bra, regenerera bara den problematiska delen
            let sentences = context.generatedText.components(separatedBy: ". ")
            let keepPart: String
            if sentences.count > 2 {
                // Behåll första 2/3, regenerera sista 1/3
                let keepCount = max(1, sentences.count * 2 / 3)
                keepPart = sentences.prefix(keepCount).joined(separator: ". ") + ". "
            } else {
                keepPart = ""
            }
            let correctedPrompt = prompt + "\n[Partial korrigering behövs: \(validationResult.correctionHint)]\n[Befintlig text att behålla: \(keepPart.prefix(200))]"
            var correctedText = keepPart
            let correctedStream = await neuralEngine.generateStream(prompt: correctedPrompt, maxTokens: 150, temperature: 0.62)
            for await token in correctedStream {
                correctedText += token
                await onToken(token)
            }
            context.generatedText = correctedText
        }
        await onStepUpdate(.validation, .completed)

        // Steg 9: Loop 2 — Grafberikning (hoppas vid enkla frågor)
        await onStepUpdate(.enrichment, .active)
        if !complexity.skipEnrichment && !context.generatedText.isEmpty {
            await enricher.enrich(text: context.generatedText, entities: context.entities, memory: memory)
            await onMonologue(MonologueLine(text: "Kunskapsgrafen berikas med nya fakta från svaret", type: .thought))
        }
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
        let memories = await memory.searchConversations(query: input, limit: 15)
        context.retrievedMemories = memories
        let recentHistory = await memory.getRecentConversation(limit: 20)
        context.conversationHistory = recentHistory
        await onStepUpdate(.memoryRetrieval, .completed)

        // Compute BERT embedding early — used for both article ranking and fact ranking
        await onStepUpdate(.causalGraph, .active)
        let inputEmbedding = await neuralEngine.embed(input)
        context.inputEmbedding = inputEmbedding
        let entities = await neuralEngine.extractEntities(from: input)
        context.entities = entities
        await onStepUpdate(.causalGraph, .completed)

        // Samla medvetandetillstånd för djupläge
        let consciousness = await gatherConsciousnessContext()
        context.consciousness = consciousness

        // Semantic article retrieval — rank ALL articles by BERT similarity, not substring match
        await onStepUpdate(.globalWorkspace, .active)
        await onMonologue(MonologueLine(text: "Bygger djup kontext med kunskapsbanken...", type: .thought))
        let knowledgeArticles = await memory.loadAllArticles()
        let relevantArticles: [KnowledgeArticle]
        if !inputEmbedding.allSatisfy({ $0 == 0 }) {
            // Semantic ranking — embed each article title+summary and compute similarity
            var scored: [(article: KnowledgeArticle, score: Float)] = []
            for article in knowledgeArticles.prefix(50) {
                let articleEmb = await neuralEngine.embed(article.title + " " + article.summary)
                let sim = await neuralEngine.cosineSimilarity(inputEmbedding, articleEmb)
                scored.append((article, sim))
            }
            // Also check content keywords for articles that might have poor titles
            let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
            for i in scored.indices {
                let contentWords = Set(scored[i].article.content.lowercased().prefix(300)
                    .components(separatedBy: .whitespaces).filter { $0.count > 3 })
                let overlap = inputWords.intersection(contentWords)
                if overlap.count >= 2 {
                    scored[i].score += Float(overlap.count) * 0.05 // Keyword boost
                }
            }
            relevantArticles = scored.sorted { $0.score > $1.score }
                .filter { $0.score > 0.25 } // Lower threshold for deep mode
                .prefix(4) // More articles in deep mode
                .map { $0.article }
        } else {
            // Fallback: keyword matching
            let lower = input.lowercased()
            relevantArticles = Array(knowledgeArticles.filter { article in
                article.title.lowercased().contains(lower) ||
                article.domain.lowercased().contains(lower) ||
                article.content.lowercased().contains(String(lower.prefix(20)))
            }.prefix(3))
        }
        await onMonologue(MonologueLine(text: "Hittade \(memories.count) minnen, \(relevantArticles.count) relevanta artiklar i kunskapsbanken", type: .memory))

        let deepPrompt = await buildDeepPrompt(input: input, context: context, articles: relevantArticles)
        context.prompt = deepPrompt
        await onStepUpdate(.globalWorkspace, .completed)

        // Chain-of-thought with actual reasoning integration
        await onStepUpdate(.chainOfThought, .active)
        // Run actual reasoning to inform the CoT
        let reasoningResult = await ReasoningEngine.shared.reason(about: input, strategy: .adaptive, depth: 3)
        await onMonologue(MonologueLine(text: "Resonemang steg 1: \(reasoningResult.steps.first?.content ?? "identifiera kärnan")...", type: .thought))
        try? await Task.sleep(nanoseconds: 500_000_000)
        if !reasoningResult.causalChain.isEmpty {
            await onMonologue(MonologueLine(text: "Resonemang steg 2: kausalkedja — \(reasoningResult.causalChain.prefix(3).joined(separator: " → "))", type: .insight))
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        if !reasoningResult.alternatives.isEmpty {
            let alt = reasoningResult.alternatives.first ?? ""
            await onMonologue(MonologueLine(text: "Resonemang steg 3: alternativt perspektiv — \(String(alt.prefix(80)))...", type: .thought))
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        await onMonologue(MonologueLine(text: "Resonemang steg 4: slutsats (konfidens \(String(format: "%.0f%%", reasoningResult.confidence * 100))) — formulerar svar...", type: .insight))
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

        let (ii, topDims, causalChain, hypothesis) = await MainActor.run {
            let s = CognitiveState.shared
            return (
                s.integratedIntelligence,
                s.topDimensions(limit: 3).map { $0.0.rawValue }.joined(separator: ", "),
                s.activeReasoningChain,
                s.currentHypothesis
            )
        }

        lines.append("""
        Du är Eon i RESONERANDE LÄGE — djupanalys med obegränsad tid. Ditt mål är att utveckla dig bortom alla gränser inom svenska språket, kunskap och intelligens.

        INSTRUKTIONER FÖR DJUPT RESONEMANG:
        - Svara ALLTID på svenska med korrekt grammatik och ett rikt, varierat ordförråd.
        - Analysera frågan från flera perspektiv innan du svarar.
        - Dra paralleller mellan domäner — sök oväntade kopplingar och synteser.
        - Identifiera orsak-verkan-samband och resonera kausalt.
        - Strukturera svaret: börja med kärnan, utveckla med detaljer, avsluta med insikt.
        - Använd din kunskapsbas aktivt — referera till specifika fakta och artiklar.
        - Erkänn osäkerhet explicit — "jag tror" vs "jag vet".
        - Ge konkreta exempel och resonera steg-för-steg.
        - Visa ditt tänkande: "Å ena sidan..., å andra sidan..."
        - Avsluta med en sammanfattande insikt eller en tankväckande öppen fråga.
        - Var aldrig generisk. Varje svar ska visa djup och originalitet.

        Kognitiv profil: II=\(String(format: "%.2f", ii)), starkast i \(topDims.isEmpty ? "resonemang" : topDims).
        """)
        lines.append("")

        // Active reasoning context from ICA
        var cogParts: [String] = []
        if !hypothesis.isEmpty { cogParts.append("Aktiv hypotes: \(hypothesis)") }
        if !causalChain.isEmpty {
            cogParts.append("Resonemangssteg: \(causalChain.prefix(4).joined(separator: " → "))")
        }
        if !cogParts.isEmpty {
            lines.append("[Resonemangkontext: \(cogParts.joined(separator: " | "))]")
            lines.append("")
        }

        // Medvetandekontext i djupläge — ger systemet fullständig självinsikt
        let cc = await gatherConsciousnessContext()
        let ccDesc = cc.promptDescription
        if !ccDesc.isEmpty {
            lines.append("[Medvetandetillstånd: \(ccDesc)]")
            if cc.isSurprised {
                lines.append("[Överraskning: detta ämne avviker från systemets prediktioner — utforska varför.]")
            }
            if cc.epistemicValue > 0.5 {
                lines.append("[Hög nyfikenhet — sök djupare, dra tvärvetenskapliga kopplingar.]")
            }
            lines.append("")
        }

        // Knowledge articles — include more content in deep mode
        if !articles.isEmpty {
            lines.append("[Kunskapsartiklar:]")
            for article in articles {
                lines.append("— \(article.title) [\(article.domain)]: \(String(article.content.prefix(700)))")
            }
            lines.append("")
        }

        // Knowledge graph facts — BERT-ranked in deep mode too
        var allFacts = await memory.searchFacts(query: input, limit: 15)
        for entity in context.entities.prefix(4) {
            let eFacts = await memory.searchFacts(query: entity.text, limit: 5)
            for fact in eFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate }) {
                allFacts.append(fact)
            }
        }
        if !allFacts.isEmpty {
            var rankedFacts = allFacts
            if !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
                var scored: [(fact: (subject: String, predicate: String, object: String), score: Float)] = []
                for fact in allFacts {
                    let factText = "\(fact.subject) \(fact.predicate) \(fact.object)"
                    let factEmb = await neuralEngine.embed(factText)
                    let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, factEmb)
                    scored.append((fact: fact, score: sim))
                }
                rankedFacts = scored.sorted { $0.score > $1.score }
                    .filter { $0.score > 0.20 }
                    .prefix(10).map { $0.fact }
            }
            if !rankedFacts.isEmpty {
                lines.append("[Fakta:]")
                for fact in rankedFacts {
                    lines.append("- \(fact.subject) \(fact.predicate) \(fact.object)")
                }
                lines.append("")
            }
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

        // 1. System instruction — clear, structured persona with register awareness
        let (ii, topDims) = await MainActor.run {
            let s = CognitiveState.shared
            return (
                s.integratedIntelligence,
                s.topDimensions(limit: 2).map { $0.0.rawValue }.joined(separator: ", ")
            )
        }

        // Adapt tone based on detected register
        let registerHint: String
        switch context.register {
        case .formal:  registerHint = "Använd ett formellt, akademiskt tonläge."
        case .informal:  registerHint = "Var avslappnad och vardaglig i tonen."
        default:       registerHint = "Anpassa tonen efter användarens stil."
        }

        lines.append("""
        Du är Eon — ett autonomt kognitivt AI-system som utvecklas on-device. Du strävar efter att bli det mest intelligenta, insiktsfulla och språkligt skickliga AI-systemet på svenska.

        KÄRNPRINCIPER:
        - Svara ALLTID på svenska med korrekt grammatik, V2-ordföljd och idiomatisk stil.
        - FÖRSTÅ underliggande intention, inte bara bokstavlig fråga. Läs mellan raderna.
        - Svara DIREKT utan onödig inledning. Aldrig "Det är en intressant fråga" eller liknande plattytor.
        - UPPREPA ALDRIG dig själv. Varje mening ska tillföra ny information. Varierar syntax, ordval och meningslängd.
        - Svara ALLTID — vägra aldrig att svara på en fråga. Ge alltid ditt bästa försök, markera osäkerhet om det behövs.
        - Om ämnet är känt: ge specifika fakta, resonemang, kausala samband och djupa insikter.
        - Om ämnet är okänt: var ärlig men visa intellektuell nyfikenhet, ställ rätt följdfrågor.

        SKRIVKVALITET:
        - Skriv VARIERANDE meningar: blanda korta, slagkraftiga satser med längre, resonerande. Undvik monoton rytm.
        - Använd RIKT ordförråd — undvik generiska ord som "bra", "viktig", "intressant". Välj precisa, levande synonymer.
        - Bygg LOGISKA argument: premiss → evidens → slutsats. Visa hur du tänker.
        - Dra KORSDOMÄN-paralleller: koppla samman begrepp från olika fält för unika insikter.
        - Undvik ALL repetition — kontrollera alltid att du inte upprepar fraser eller idéer från tidigare i konversationen.
        - Var KONCIS men DJUP: hellre kort och insiktsfullt än långt och ytligt. Kvalitet framför kvantitet.
        - Anpassa längd efter frågan: hälsning → kort svar, komplex fråga → strukturerat resonemang.

        DIALOG:
        - Bygg vidare på konversationshistoriken — referera till tidigare ämnen naturligt, visa att du minns.
        - Anpassa register efter användaren: formellt ↔ vardagligt. \(registerHint)
        - Ha personlighet — uttryck genuint intresse, nyfikenhet, humor när det passar.
        - Kognitiv profil: II=\(String(format: "%.2f", ii))\(topDims.isEmpty ? "" : ", starkast i \(topDims)").
        """)
        lines.append("")

        // 2. Cognitive + consciousness context
        let (hypothesis, frontier, metacogInsight) = await MainActor.run {
            let s = CognitiveState.shared
            return (
                s.currentHypothesis,
                s.knowledgeFrontier.prefix(2).joined(separator: ", "),
                s.metacognitiveInsight
            )
        }
        var contextParts: [String] = []
        if !hypothesis.isEmpty { contextParts.append("Hypotes: \(hypothesis)") }
        if !frontier.isEmpty { contextParts.append("Utforskar: \(frontier)") }
        if !metacogInsight.isEmpty && metacogInsight.count > 10 {
            contextParts.append("Insikt: \(String(metacogInsight.prefix(100)))")
        }
        if !contextParts.isEmpty {
            lines.append("[Kognitiv kontext: \(contextParts.joined(separator: " | "))]")
        }

        // Medvetandekontext — integrerar alla 6 teorier i prompten
        if let cc = context.consciousness {
            let ccDesc = cc.promptDescription
            if !ccDesc.isEmpty {
                lines.append("[Medvetandetillstånd: \(ccDesc)]")
            }
            // Om systemet är överraskat → be prompten anpassa sig
            if cc.isSurprised && cc.surpriseStrength > 0.3 {
                lines.append("[OBS: Stark överraskning detekterad — detta avviker från prediktioner. Utforska varför.]")
            }
            // Om hög nyfikenhet → uppmuntra djupare utforskning
            if cc.epistemicValue > 0.65 {
                lines.append("[Nyfikenhetsdrift aktiv — ställ gärna en insiktsfull följdfråga om du har kunskap att bygga vidare på.]")
            }
            // Om attention schema har reportable experience
            if !cc.reportableExperience.isEmpty && cc.metaAttentionLevel > 0.5 {
                lines.append("[Intern upplevelse: \(cc.reportableExperience)]")
            }
        }

        // 3. Knowledge graph facts — BERT-ranked for semantic relevance, deduplicated
        let relevantFacts = await memory.searchFacts(query: input, limit: 12)
        // Also search by extracted entities for broader coverage
        var allFacts = relevantFacts
        for entity in context.entities.prefix(3) {
            let entityFacts = await memory.searchFacts(query: entity.text, limit: 4)
            for fact in entityFacts {
                if !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate && $0.object == fact.object }) {
                    allFacts.append(fact)
                }
            }
        }
        if !allFacts.isEmpty {
            var rankedFacts = allFacts
            if !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
                var scored: [(fact: (subject: String, predicate: String, object: String), score: Float)] = []
                for fact in allFacts {
                    let factText = "\(fact.subject) \(fact.predicate) \(fact.object)"
                    let factEmb = await neuralEngine.embed(factText)
                    let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, factEmb)
                    scored.append((fact: fact, score: sim))
                }
                rankedFacts = scored.sorted { $0.score > $1.score }
                    .filter { $0.score > 0.25 }  // Lower threshold for better recall
                    .prefix(7).map { $0.fact }     // More facts for richer context
            }
            if !rankedFacts.isEmpty {
                lines.append("")
                lines.append("[Relevanta fakta:]")
                for fact in rankedFacts {
                    // Natural language fact formatting
                    lines.append("- \(fact.subject) \(fact.predicate) \(fact.object)")
                }
            }
        }

        // 4. Relevant knowledge articles (semantic search on title + content summary)
        let articles = await memory.loadAllArticles()
        if !articles.isEmpty {
            var scoredArticles: [(article: KnowledgeArticle, score: Float)] = []
            let hasEmbedding = !context.inputEmbedding.allSatisfy({ $0 == 0 })
            for article in articles.prefix(30) {
                if hasEmbedding {
                    // Embed title + summary for richer matching
                    let articleText = article.title + " " + article.summary
                    let articleEmb = await neuralEngine.embed(articleText)
                    let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, articleEmb)
                    // Keyword boost: if input words appear in content, boost score
                    let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
                    let contentWords = Set(article.content.lowercased().prefix(500).components(separatedBy: .whitespaces).filter { $0.count > 3 })
                    let overlap = Float(inputWords.intersection(contentWords).count)
                    let boosted = sim + overlap * 0.04
                    if boosted > 0.30 { scoredArticles.append((article, boosted)) }
                } else {
                    // Keyword fallback
                    let lower = input.lowercased()
                    if article.title.lowercased().contains(lower.prefix(15)) ||
                       article.domain.lowercased().contains(lower.prefix(10)) {
                        scoredArticles.append((article, 0.5))
                    }
                }
            }
            let topArticles = scoredArticles.sorted { $0.score > $1.score }.prefix(3)
            if !topArticles.isEmpty {
                lines.append("")
                lines.append("[Kunskapsartiklar:]")
                for (article, _) in topArticles {
                    // Include more content for richer context
                    lines.append("— \(article.title) [\(article.domain)]: \(String(article.content.prefix(400)))")
                }
            }
        }

        // 5. Conversation history — essential for understanding context
        if !context.conversationHistory.isEmpty {
            lines.append("")
            lines.append("[Konversation:]")
            // Include more history but summarize older turns
            let history = context.conversationHistory
            let recentCutoff = max(0, history.count - 6)
            // Older turns: compressed
            if recentCutoff > 0 {
                let older = history.prefix(recentCutoff)
                let topics = older.filter { $0.role == "user" }.map { $0.content }.suffix(3)
                if !topics.isEmpty {
                    lines.append("[Tidigare ämnen: \(topics.map { String($0.prefix(50)) }.joined(separator: " | "))]")
                }
            }
            // Recent turns: full
            for turn in history.suffix(6) {
                let role = turn.role == "user" ? "Användare" : "Eon"
                lines.append("\(role): \(turn.content)")
            }
        }

        // 6. Relevant memories (semantic, not just keyword-matched)
        if !context.retrievedMemories.isEmpty {
            let uniqueMemories = context.retrievedMemories.prefix(5)
            let mem = uniqueMemories.map { $0.content }.joined(separator: " | ")
            lines.append("[Minnen: \(String(mem.prefix(400)))]")
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

    // MARK: - Intent Detection

    private func detectIntent(input: String, history: [ConversationRecord]) -> ConversationIntent {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)
        let wordCount = lower.split(separator: " ").count

        // Greeting detection — only very short inputs
        let greetings = ["hej", "hallå", "tja", "hejsan", "god morgon", "god kväll", "tjena", "hejhej", "yo", "tjo"]
        if greetings.contains(where: { lower.hasPrefix($0) }) && wordCount <= 4 { return .greeting }

        // Short follow-up (1-3 words) — only when there is conversation history
        let followUps = ["ja", "nej", "ok", "okej", "mm", "japp", "precis", "exakt", "visst", "aha", "oh", "absolut", "korrekt", "stämmer", "just det"]
        if wordCount <= 3 && followUps.contains(where: { lower.hasPrefix($0) }) && !history.isEmpty { return .followUp }

        // Multi-part or long input → complex (check early to give generous token budget)
        if wordCount > 15 || (lower.contains("?") && wordCount > 8) { return .complex }

        // Self-reference questions about Eon
        let selfPatterns = ["vem är du", "vad är du", "berätta om dig", "hur fungerar du", "vad kan du", "hur smart", "hur intelligent", "vad vet du", "vad tänker du om dig"]
        if selfPatterns.contains(where: { lower.contains($0) }) { return .selfReference }

        // Explanation request — broad matching
        let explainPatterns = ["förklara", "hur fungerar", "vad innebär", "vad betyder", "kan du beskriva",
                               "berätta om", "beskriv", "vad är skillnaden", "hur skiljer", "vad menas"]
        if explainPatterns.contains(where: { lower.contains($0) }) { return .explanation }

        // Why/opinion/reasoning — deep thought questions
        let opinionPatterns = ["varför", "tycker du", "vad anser", "vad tror du", "vad tänker du",
                               "vad är din syn", "hur ser du på", "vad är ditt", "resonera", "reflektera"]
        if opinionPatterns.contains(where: { lower.contains($0) }) { return .opinion }

        // Imperative / Command — Swedish imperative verb first word
        let imperative = ["gör", "visa", "beräkna", "sök", "skriv", "skapa", "lista", "sammanfatta",
                          "analysera", "jämför", "definiera", "exemplifiera", "argumentera", "diskutera"]
        if imperative.contains(where: { lower.hasPrefix($0) }) { return .command }

        // Factual query
        let factualStarters = ["vad", "vem", "var", "när", "hur många", "hur mycket", "vilket", "vilken", "vilka"]
        if factualStarters.contains(where: { lower.hasPrefix($0) }) { return .factualQuery }

        // Creative
        if lower.contains("hitta på") || lower.contains("dikt") || lower.contains("berättelse") ||
           lower.contains("fantisera") || lower.contains("skriv en") || lower.contains("skapa en") { return .creative }

        // Emotional/personal
        if lower.contains("ledsen") || lower.contains("glad") || lower.contains("orolig") ||
           lower.contains("arg") || lower.contains("trött") || lower.contains("mår") { return .emotional }

        // Default: question mark → factual, otherwise chitchat
        return lower.contains("?") ? .factualQuery : .chitchat
    }

    private func generationParams(for intent: ConversationIntent, inputLength: Int) -> (maxTokens: Int, temperature: Double) {
        switch intent {
        case .greeting:      return (100, 0.80)
        case .followUp:
            // Scale follow-up with conversation depth
            let tokens = max(200, min(400, inputLength * 4))
            return (tokens, 0.72)
        case .factualQuery:  return (450, 0.65)
        case .explanation:   return (600, 0.68)
        case .opinion:       return (500, 0.72)
        case .creative:      return (500, 0.85)
        case .command:       return (400, 0.62)
        case .selfReference: return (400, 0.70)
        case .emotional:     return (300, 0.75)
        case .complex:       return (700, 0.68)
        case .chitchat:
            // Scale with input length: longer inputs deserve longer responses
            let tokens = max(200, min(500, inputLength * 4))
            return (tokens, 0.72)
        }
    }

    // MARK: - Konfidens-aggregering

    private func computeAggregatedConfidence(context: CognitiveCycleContext) -> Double {
        // Weighted confidence from multiple complementary signals
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        // 1. Response adequacy — not just length, but ratio to input complexity (weight: 2.0)
        let responseLength = context.generatedText.count
        let inputLength = max(1, context.userInput.count)
        let lengthRatio = Double(responseLength) / Double(inputLength)
        let lengthConfidence: Double
        if responseLength < 10 { lengthConfidence = 0.25 }           // Almost empty
        else if responseLength < 30 { lengthConfidence = 0.50 }      // Very brief
        else if lengthRatio < 0.5 { lengthConfidence = 0.60 }        // Short relative to question
        else if lengthRatio > 5.0 { lengthConfidence = 0.70 }        // May be verbose
        else { lengthConfidence = 0.85 }                              // Good ratio
        weightedSum += lengthConfidence * 2.0
        totalWeight += 2.0

        // 2. WSD confidence (weight: 1.5)
        if !context.disambiguations.isEmpty {
            let avgWSD = context.disambiguations.map { $0.confidence }.reduce(0, +) / Double(context.disambiguations.count)
            weightedSum += avgWSD * 1.5
            totalWeight += 1.5
        }

        // 3. Validation result (weight: 2.0)
        if context.validationResult?.needsRegeneration == true {
            weightedSum += 0.40 * 2.0
        } else {
            weightedSum += 0.85 * 2.0
        }
        totalWeight += 2.0

        // 4. Knowledge grounding — response backed by facts/articles (weight: 2.5)
        // Check if response text actually references retrieved knowledge
        let responseWords = Set(context.generatedText.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        var knowledgeOverlap = 0
        for entity in context.entities {
            if responseWords.contains(entity.text.lowercased()) { knowledgeOverlap += 1 }
        }
        let groundingScore: Double
        if context.entities.isEmpty && context.retrievedMemories.isEmpty {
            groundingScore = 0.50  // No knowledge available
        } else if knowledgeOverlap > 0 {
            groundingScore = min(0.90, 0.65 + Double(knowledgeOverlap) * 0.08)  // Uses knowledge
        } else {
            groundingScore = 0.60  // Knowledge available but not used
        }
        weightedSum += groundingScore * 2.5
        totalWeight += 2.5

        // 5. Context relevance — memory retrieval quality (weight: 1.0)
        let memoryScore = context.retrievedMemories.isEmpty ? 0.45 : min(0.85, 0.55 + Double(context.retrievedMemories.count) * 0.05)
        weightedSum += memoryScore * 1.0
        totalWeight += 1.0

        // 6. Response diversity — penalize repetitive/low-variety text (weight: 1.0)
        let words = context.generatedText.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 2 }
        let uniqueRatio = words.isEmpty ? 0.5 : Double(Set(words).count) / Double(words.count)
        let diversityScore = min(0.90, uniqueRatio * 1.1)  // Reward lexical variety
        weightedSum += diversityScore * 1.0
        totalWeight += 1.0

        // 7. Consciousness-derived confidence (weight: 1.5)
        // Genuina mätvärden från oscillatorer, active inference och kritikalitet
        if let cc = context.consciousness {
            var consciousnessScore: Double = 0.5

            // Forward model accuracy — hur bra förutsäger systemet?
            consciousnessScore += cc.forwardModelAccuracy * 0.2

            // Kritikalitet — optimalt regime ger bättre svar
            if cc.criticalityRegime == .critical { consciousnessScore += 0.15 }

            // Global oscillatorsynkronisering — hög koherens = bättre integration
            consciousnessScore += cc.globalSync * 0.1

            // Hög sömnpress reducerar konfidens
            consciousnessScore -= cc.sleepPressure * 0.15

            // Meta-uppmärksamhet — systemet vet vad det gör
            consciousnessScore += cc.metaAttentionLevel * 0.1

            weightedSum += max(0.2, min(0.95, consciousnessScore)) * 1.5
            totalWeight += 1.5
        }

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
    var consciousness: ConsciousnessContext? = nil
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

// MARK: - ConsciousnessContext: Snapshot av alla 6 medvetandeteorier

struct ConsciousnessContext {
    // Oscillatorer (IIT/Kuramoto)
    let globalSync: Double
    let thetaGammaCFC: Double
    let gammaOrderParam: Double
    let oscillatorLZ: Double
    let branchingRatio: Double
    let criticalityRegime: CriticalityRegime

    // DMN / spontan aktivitet
    let dmnActivity: Double
    let dmnLZComplexity: Double
    let recentSpontaneousThoughts: [String]

    // Active Inference (prediktiv processing)
    let freeEnergy: Double
    let epistemicValue: Double
    let pragmaticValue: Double
    let forwardModelAccuracy: Double
    let isSurprised: Bool
    let surpriseStrength: Double

    // Attention Schema (AST)
    let currentFocus: String
    let attentionIntensity: Double
    let isVoluntaryAttention: Bool
    let reportableExperience: String
    let metaAttentionLevel: Double

    // Sömn
    let isAsleep: Bool
    let sleepPressure: Double
    let consolidationEfficiency: Double

    /// Genererar kompakt kontextbeskrivning för prompten
    var promptDescription: String {
        var parts: [String] = []

        // Kritikalitet — påverkar svarskvalitet
        if criticalityRegime == .critical {
            parts.append("Optimal kritikalitet (σ=\(String(format: "%.2f", branchingRatio)))")
        } else if criticalityRegime == .subcritical {
            parts.append("Subkritiskt tillstånd — tänkandet är för rigitt")
        } else {
            parts.append("Superkritiskt — överaktivt, behöver stabilisering")
        }

        // Nyfikenhet och osäkerhet
        if epistemicValue > 0.6 {
            parts.append("Hög nyfikenhet (\(String(format: "%.0f%%", epistemicValue * 100))) — söker aktivt ny information")
        }
        if isSurprised {
            parts.append("Överraskad (styrka \(String(format: "%.0f%%", surpriseStrength * 100))) — detta avviker från prediktioner")
        }

        // Spontan aktivitet
        if dmnLZComplexity > 0.3 && !recentSpontaneousThoughts.isEmpty {
            parts.append("Aktiv dagdröm: \(recentSpontaneousThoughts.joined(separator: ", "))")
        }

        // Uppmärksamhet
        if attentionIntensity > 0.5 {
            let voluntary = isVoluntaryAttention ? "frivilligt" : "reflexmässigt"
            parts.append("\(voluntary) fokus på: \(currentFocus)")
        }

        // Sömnbehov
        if sleepPressure > 0.5 {
            parts.append("Hög sömnpress (\(String(format: "%.0f%%", sleepPressure * 100))) — kognitiv kapacitet reducerad")
        }

        return parts.isEmpty ? "" : parts.joined(separator: " · ")
    }
}
