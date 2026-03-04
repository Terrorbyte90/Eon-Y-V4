import Foundation
import NaturalLanguage

// MARK: - CognitiveCycleEngine: Orkestrator för de 3 feedback-looparna

// MARK: - InputAnalyzer (v11: Deep question understanding)
// Analyzes the user's input BEFORE generation to extract:
// - Core topic/entity the user is asking about
// - Question type (what/who/where/when/how/why)
// - Key nouns and named entities via NLTagger
// - Whether the question requires factual knowledge or opinion
// This analysis is then used to anchor the prompt and validate the response.

struct InputAnalysis: Sendable {
    let coreTopic: String           // Main subject being asked about
    let questionType: QuestionType  // What kind of question
    let keyNouns: [String]          // Important nouns extracted via NLTagger
    let namedEntities: [String]     // Named entities (proper nouns)
    let requiresKnowledge: Bool     // Does this need factual retrieval?
    let questionSummary: String     // One-line summary for prompt anchoring

    enum QuestionType: String, Sendable {
        case what = "vad"
        case who = "vem"
        case when = "när"
        case where_ = "var"
        case how = "hur"
        case why = "varför"
        case yesNo = "ja/nej"
        case imperative = "imperativ"
        case statement = "påstående"
        case unknown = "okänt"
    }
}

struct InputAnalyzer {
    nonisolated static func analyze(input: String) -> InputAnalysis {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Determine question type from first word / structure
        let questionType = detectQuestionType(lower)

        // 2. Extract key nouns and named entities using NLTagger
        let (keyNouns, namedEntities) = extractNounsAndEntities(input)

        // 3. Extract core topic — the main thing being asked about
        let coreTopic = extractCoreTopic(input: input, lower: lower, nouns: keyNouns, entities: namedEntities)

        // 4. Determine if knowledge retrieval is needed
        let requiresKnowledge = questionType != .imperative &&
            questionType != .statement &&
            !keyNouns.isEmpty

        // 5. Build question summary
        let summary = buildSummary(questionType: questionType, coreTopic: coreTopic, input: input)

        return InputAnalysis(
            coreTopic: coreTopic,
            questionType: questionType,
            keyNouns: keyNouns,
            namedEntities: namedEntities,
            requiresKnowledge: requiresKnowledge,
            questionSummary: summary
        )
    }

    private static func detectQuestionType(_ lower: String) -> InputAnalysis.QuestionType {
        if lower.hasPrefix("vad ") || lower.hasPrefix("vad?") { return .what }
        if lower.hasPrefix("vem ") || lower.hasPrefix("vem?") { return .who }
        if lower.hasPrefix("när ") || lower.hasPrefix("när?") { return .when }
        if lower.hasPrefix("var ") || lower.hasPrefix("var?") { return .where_ }
        if lower.hasPrefix("hur ") { return .how }
        if lower.hasPrefix("varför ") { return .why }
        // Question words mid-sentence
        if lower.contains("vad ") && lower.contains("?") { return .what }
        if lower.contains("vem ") && lower.contains("?") { return .who }
        if lower.contains("varför ") && lower.contains("?") { return .why }
        if lower.contains("hur ") && lower.contains("?") { return .how }
        // Yes/no questions (Swedish V1 word order — verb first)
        let firstWord = String(lower.prefix(while: { $0 != " " }))
        let yesNoVerbs: Set<String> = ["är", "kan", "har", "ska", "vet", "tycker", "tror",
                                         "finns", "gillar", "vill", "behöver", "bör", "måste"]
        if yesNoVerbs.contains(firstWord) && lower.contains("?") { return .yesNo }
        // Imperative
        let imperativeVerbs: Set<String> = ["berätta", "förklara", "beskriv", "visa", "lista",
                                             "jämför", "analysera", "sammanfatta", "definiera",
                                             "ge", "skriv", "sök", "hitta"]
        if imperativeVerbs.contains(firstWord) { return .imperative }
        // Has question mark → try to detect
        if lower.contains("?") { return .unknown }
        return .statement
    }

    private static func extractNounsAndEntities(_ input: String) -> ([String], [String]) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = input

        var nouns: [String] = []
        var entities: [String] = []

        // Extract nouns
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(input[range])
            if tag == .noun && word.count > 2 {
                nouns.append(word)
            }
            return true
        }

        // Extract named entities (proper nouns, organizations, places)
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word,
                             scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag != nil {
                let entity = String(input[range])
                if entity.count > 1 {
                    entities.append(entity)
                }
            }
            return true
        }

        // Also detect capitalized words as potential named entities (NLTagger sometimes misses Swedish names)
        let words = input.components(separatedBy: .whitespacesAndNewlines)
        for (i, word) in words.enumerated() {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if cleaned.count > 1,
               cleaned.first?.isUppercase == true,
               i > 0, // Skip first word (capitalized due to sentence start)
               !entities.contains(cleaned) {
                entities.append(cleaned)
            }
        }

        // For single-word inputs or first word that's a proper noun
        if words.count <= 3 {
            let firstCleaned = words.first?.trimmingCharacters(in: .punctuationCharacters) ?? ""
            if firstCleaned.first?.isUppercase == true && firstCleaned.count > 1 && !entities.contains(firstCleaned) {
                entities.append(firstCleaned)
            }
        }

        return (nouns, entities)
    }

    private static func extractCoreTopic(input: String, lower: String, nouns: [String], entities: [String]) -> String {
        // Priority 1: Named entities are usually the core topic
        if let firstEntity = entities.first {
            return firstEntity
        }

        // Priority 2: Last noun in a question (Swedish puts topic at end typically)
        // "Vad vet du om Flashback?" → "Flashback"
        // Remove question words and filler to find the topic
        let stopwords: Set<String> = ["vad", "vem", "var", "när", "hur", "vilken", "vilka", "vilket",
                                       "vet", "du", "om", "kan", "berätta", "förklara", "är", "det",
                                       "att", "en", "ett", "den", "de", "på", "i", "med", "för",
                                       "och", "eller", "av", "till", "från", "har", "hade", "ska",
                                       "skulle", "kunde", "måste", "vill", "jag", "mig", "dig",
                                       "sin", "sitt", "sina", "tycker", "tror", "anser", "inte",
                                       "så", "här", "där", "alla", "allt", "denna", "detta", "dessa"]

        // Try to find meaningful words from the end (topic usually at end in Swedish questions)
        let words = lower.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 1 && !stopwords.contains($0) }

        if let lastMeaningful = words.last {
            return lastMeaningful
        }

        // Priority 3: First noun
        if let firstNoun = nouns.first {
            return firstNoun
        }

        // Fallback: first few words
        return String(input.prefix(30))
    }

    private static func buildSummary(questionType: InputAnalysis.QuestionType, coreTopic: String, input: String) -> String {
        switch questionType {
        case .what:      return "Användaren frågar vad \(coreTopic) är/innebär"
        case .who:       return "Användaren frågar vem \(coreTopic) är"
        case .when:      return "Användaren frågar om tidpunkt för \(coreTopic)"
        case .where_:    return "Användaren frågar var \(coreTopic) finns/ligger"
        case .how:       return "Användaren frågar hur \(coreTopic) fungerar/görs"
        case .why:       return "Användaren frågar varför \(coreTopic)"
        case .yesNo:     return "Användaren ställer en ja/nej-fråga om \(coreTopic)"
        case .imperative: return "Användaren ber om information om \(coreTopic)"
        case .statement: return "Användaren säger något om \(coreTopic)"
        case .unknown:   return "Fråga om \(coreTopic)"
        }
    }
}

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

        // v16: Start deadline clock — 5 second budget with enforced checkpoints
        let deadline = ContinuousClock.now + .seconds(5)

        var context = CognitiveCycleContext(userInput: input, sessionId: sessionId)

        // v16: Single intent detection up front — reused everywhere (eliminates duplicate)
        let intent = detectIntent(input: input, history: await memory.getRecentConversation(limit: 5))
        let complexity = ComplexityEstimator.estimate(input: input, intent: intent)

        // Steg 0 (v11): InputAnalyzer — deep question understanding BEFORE anything else
        let inputAnalysis = InputAnalyzer.analyze(input: input)
        context.inputAnalysis = inputAnalysis
        await onMonologue(MonologueLine(text: "Frågeanalys: \(inputAnalysis.questionSummary) [ämne: \(inputAnalysis.coreTopic)]", type: .thought))

        // Steg 1: Morfologianalys (Pelare A) — skip for greetings
        await onStepUpdate(.morphology, .active)
        let analysis: SwedishAnalysis
        if intent == .greeting {
            analysis = SwedishAnalysis.empty
        } else {
            analysis = await swedish.analyze(input)
        }
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

        // v16: Compute BERT embedding ONCE — reused for memory ranking, entity extraction, Q-A check
        let inputEmb: [Float]
        let bertAvailable: Bool
        if complexity.skipBERT {
            inputEmb = []
            bertAvailable = false
            await onMonologue(MonologueLine(text: "Enkel fråga — BERT hoppas", type: .thought))
        } else {
            inputEmb = await neuralEngine.embed(input)
            bertAvailable = !inputEmb.allSatisfy({ $0 == 0 })
        }

        // Steg 3: Minneshämtning (v16: deadline-aware, reduced BERT calls)
        await onStepUpdate(.memoryRetrieval, .active)
        await onMonologue(MonologueLine(text: "Söker i minnet efter '\(inputAnalysis.coreTopic)'...", type: .memory))
        var rawMemories = await memory.searchConversations(query: input, limit: 20)
        if inputAnalysis.coreTopic.count > 2 {
            let topicMemories = await memory.searchConversations(query: inputAnalysis.coreTopic, limit: 8)
            for mem in topicMemories where !rawMemories.contains(where: { $0.id == mem.id }) {
                rawMemories.append(mem)
            }
        }
        for entity in inputAnalysis.namedEntities.prefix(2) {
            let entityMemories = await memory.searchConversations(query: entity, limit: 3)
            for mem in entityMemories where !rawMemories.contains(where: { $0.id == mem.id }) {
                rawMemories.append(mem)
            }
        }
        // v16: BERT ranking — limit to top 8 memories (down from all), use cached inputEmb
        if bertAvailable && rawMemories.count > 2 {
            let now = Date()
            // v16: Pre-filter by keyword relevance before BERT (saves ~50% BERT calls)
            let inputWords = Set(input.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let preFiltered = rawMemories.sorted { mem1, mem2 in
                let words1 = Set(mem1.content.lowercased().prefix(200).components(separatedBy: .whitespacesAndNewlines))
                let words2 = Set(mem2.content.lowercased().prefix(200).components(separatedBy: .whitespacesAndNewlines))
                return inputWords.intersection(words1).count > inputWords.intersection(words2).count
            }
            var scored: [(record: ConversationRecord, score: Double)] = []
            for mem in preFiltered.prefix(8) {  // v16: Max 8 BERT calls (was unlimited)
                let memEmb = await neuralEngine.embed(String(mem.content.prefix(200)))
                let rawSim = Double(await neuralEngine.cosineSimilarity(inputEmb, memEmb))
                let ageHours = now.timeIntervalSince(mem.date) / 3600.0
                let recencyBoost = exp(-ageHours / 24.0) * 0.15
                scored.append((mem, rawSim + recencyBoost))
            }
            context.retrievedMemories = scored.sorted { $0.score > $1.score }
                .filter { $0.score > 0.20 }
                .prefix(5).map { $0.record }
        } else {
            context.retrievedMemories = Array(rawMemories.prefix(5))
        }
        let recentHistory = await memory.getRecentConversation(limit: 8)
        context.conversationHistory = recentHistory
        if !context.retrievedMemories.isEmpty {
            let rankMethod = bertAvailable ? "BERT+tidsvikt" : "nyckelord"
            await onMonologue(MonologueLine(text: "Hittade \(context.retrievedMemories.count) relevanta minnen (\(rankMethod))", type: .memory))
        }
        await onStepUpdate(.memoryRetrieval, .completed)

        // v16: Deadline check — if we've spent > 2s on steps 0-3, skip some enrichment
        let afterMemoryTime = deadline - .now

        // Steg 4: BERT-embedding (v16: reuse cached inputEmb, no duplicate)
        await onStepUpdate(.causalGraph, .active)
        context.inputEmbedding = inputEmb  // v16: Reuse from step 3
        if bertAvailable {
            let entities = await neuralEngine.extractEntities(from: input)
            context.entities = entities
            if !entities.isEmpty {
                await onMonologue(MonologueLine(text: "Entiteter: \(entities.map { $0.text }.joined(separator: ", "))", type: .thought))
            }
        } else {
            context.entities = []
        }
        await onStepUpdate(.causalGraph, .completed)

        // Steg 5: Global Workspace + Medvetandetillstånd + SelfKnowledge
        await onStepUpdate(.globalWorkspace, .active)

        // v16: Consciousness context + SelfKnowledge in parallel (conceptually)
        let consciousness = await gatherConsciousnessContext()
        context.consciousness = consciousness
        if !consciousness.promptDescription.isEmpty {
            await onMonologue(MonologueLine(text: "Medvetandekontext: \(String(consciousness.promptDescription.prefix(100)))", type: .insight))
        }

        // v16: Skip consciousness narration if tight on time
        if afterMemoryTime > .seconds(3) {
            if let narration = consciousnessNarration(consciousness) {
                await onMonologue(narration)
            }
        }

        // v13: SpecialisedChat — SelfKnowledge + QuestionProfile
        let selfKnowledge = await SelfKnowledgeBase.shared.queryRelevant(input: input, consciousness: consciousness)
        context.selfKnowledge = selfKnowledge
        if selfKnowledge.isRelevant {
            await onMonologue(MonologueLine(text: "Självkunskap: \(selfKnowledge.relevantFacts.count) fakta om mig", type: .insight))
        }
        // v16: QuestionProfile — only for non-trivial queries (saves ~100ms)
        if !complexity.isSimple() {
            let questionProfile = await QuestionUnderstandingAgent().analyze(
                input: input,
                conversationHistory: context.conversationHistory
            )
            context.questionProfile = questionProfile
            // ConversationTracker
            let _ = await ConversationTracker.shared.resolveContext(
                input: input,
                history: context.conversationHistory
            )
        }

        let prompt = await buildPrompt(input: input, context: context)
        context.prompt = prompt
        await onStepUpdate(.globalWorkspace, .completed)

        // Steg 6: Chain-of-Thought (v16: reuse intent/complexity from step 0)
        await onStepUpdate(.chainOfThought, .active)
        var (maxTokens, temperature) = generationParams(for: intent, inputLength: input.count)

        // Medvetandemodulerande parametrar:
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
        // v10: Post-generation sentence deduplication + v11: output cleaning + v18: final safety dedup
        let deduped = NeuralEngineOrchestrator.deduplicateSentences(generatedText)
        let cleaned = NeuralEngineOrchestrator.cleanOutput(deduped)
        let safeCleaned = NeuralEngineOrchestrator.finalSafetyDedup(cleaned)
        if safeCleaned.count < generatedText.count {
            let removed = generatedText.count - safeCleaned.count
            print("[CognitiveCycle] Dedup+Clean+Safety: tog bort \(removed) tecken")
        }
        context.generatedText = safeCleaned
        await onStepUpdate(.generation, .completed)

        // Steg 8: Loop 1 — Genereringsvalidering
        await onStepUpdate(.validation, .active)
        let validationResult = await validator.validate(
            generated: context.generatedText,
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
            // v10: Stronger correction prompt — explicitly forbid repetition
            let correctedPrompt = prompt + "\n[KORRIGERING: \(validationResult.correctionHint). Skriv NYTT innehåll, upprepa INGENTING från det befintliga svaret.]"
            var correctedText = keepPart
            let correctedStream = await neuralEngine.generateStream(prompt: correctedPrompt, maxTokens: 150, temperature: 0.62)
            for await token in correctedStream {
                correctedText += token
                // v17: Don't stream regeneration tokens — they overlap with the initial response.
                // The final cleaned response replaces the UI content via lastCleanedResponse.
            }
            // v10: Dedup the corrected text too + v18: final safety dedup
            let correctedDeduped = NeuralEngineOrchestrator.deduplicateSentences(correctedText)
            context.generatedText = NeuralEngineOrchestrator.finalSafetyDedup(correctedDeduped)
        }
        await onStepUpdate(.validation, .completed)

        // v16: BERT Q-A Relevance Check — reuse cached inputEmb (saves one BERT call)
        let timeForBERT = (deadline - .now) > .seconds(1.2)
        if timeForBERT && bertAvailable && !context.generatedText.isEmpty && context.generatedText.count > 20 {
            let questionEmb = inputEmb  // v16: Reuse cached embedding
            let answerEmb = await neuralEngine.embed(String(context.generatedText.prefix(300)))
            let qaRelevance = Double(await neuralEngine.cosineSimilarity(questionEmb, answerEmb))
            context.relevanceScore = qaRelevance

            // If the response is semantically unrelated to the question (< 0.25), it's about the wrong topic
            if qaRelevance < 0.25 && inputAnalysis.requiresKnowledge {
                await onMonologue(MonologueLine(text: "Relevans \(String(format: "%.0f%%", qaRelevance * 100)) — svaret verkar inte handla om \(inputAnalysis.coreTopic), regenererar...", type: .loopTrigger))
                // Regenerate with a much more focused prompt
                let focusedPrompt = """
                Svara KORT och DIREKT på svenska om: \(inputAnalysis.coreTopic)
                \(inputAnalysis.questionSummary)
                \(inputAnalysis.namedEntities.isEmpty ? "" : "Det handlar om: \(inputAnalysis.namedEntities.joined(separator: ", "))")
                Användare: \(input)
                Eon (kort svar om \(inputAnalysis.coreTopic)):
                """
                let focusedText = await neuralEngine.generate(prompt: focusedPrompt, maxTokens: 200, temperature: 0.55)
                if !focusedText.isEmpty {
                    context.generatedText = focusedText
                    // Check relevance of the new answer
                    let newEmb = await neuralEngine.embed(String(focusedText.prefix(400)))
                    context.relevanceScore = Double(await neuralEngine.cosineSimilarity(questionEmb, newEmb))
                }
            } else if qaRelevance > 0.4 {
                await onMonologue(MonologueLine(text: "Svar-relevans: \(String(format: "%.0f%%", qaRelevance * 100)) — svaret adresserar frågan", type: .thought))
            }
        }

        // v15: Check deadline before post-processing
        let timeRemaining = deadline - .now
        let hasTime = timeRemaining > .seconds(0.5)

        // Steg 9: Loop 2 — Grafberikning (hoppas vid enkla frågor eller deadline)
        await onStepUpdate(.enrichment, .active)
        if hasTime && !complexity.skipEnrichment && !context.generatedText.isEmpty {
            await enricher.enrich(text: context.generatedText, entities: context.entities, memory: memory)
            await onMonologue(MonologueLine(text: "Kunskapsgrafen berikas med nya fakta från svaret", type: .thought))
        } else if !hasTime {
            await onMonologue(MonologueLine(text: "Deadline nära — grafberikning hoppas", type: .thought))
        }
        await onStepUpdate(.enrichment, .completed)

        // Steg 10: Loop 3 — Metakognitiv revision (Pelare C)
        await onStepUpdate(.metacognition, .active)
        let aggregatedConfidence = computeAggregatedConfidence(context: context)
        context.finalConfidence = aggregatedConfidence

        let timeForRevision = (deadline - .now) > .seconds(0.8)
        if aggregatedConfidence < 0.60 && timeForRevision {
            await onMonologue(MonologueLine(text: "Loop 3: Konfidens \(String(format: "%.2f", aggregatedConfidence)) < 0.60 — Eon reviderar svaret...", type: .revision))
            let revisedText = await reviser.revise(
                original: context.generatedText,
                confidence: aggregatedConfidence,
                neuralEngine: neuralEngine
            )
            context.generatedText = revisedText
        } else if aggregatedConfidence < 0.60 {
            await onMonologue(MonologueLine(text: "Konfidens \(String(format: "%.0f%%", aggregatedConfidence * 100)) — deadline, skickar ändå", type: .thought))
        } else {
            await onMonologue(MonologueLine(text: "Konfidens: \(String(format: "%.0f%%", aggregatedConfidence * 100)) — svar godkänt", type: .thought))
        }
        await onStepUpdate(.metacognition, .completed)

        // Spara till minne
        await memory.saveMessage(role: "user", content: input, sessionId: context.sessionId)
        await memory.saveMessage(role: "assistant", content: context.generatedText, sessionId: context.sessionId, confidence: aggregatedConfidence)

        // v13: Registrera tur i ConversationTracker
        let topic = context.questionProfile?.coreTopic ?? context.inputAnalysis?.coreTopic ?? ""
        let namedEntities = context.questionProfile?.namedEntities ?? context.inputAnalysis?.namedEntities ?? []
        await ConversationTracker.shared.recordTurn(
            userInput: input,
            eonResponse: context.generatedText,
            topic: topic,
            entities: namedEntities
        )

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

        // v11: InputAnalyzer for deep mode too
        let inputAnalysis = InputAnalyzer.analyze(input: input)
        context.inputAnalysis = inputAnalysis
        await onMonologue(MonologueLine(text: "Djup frågeanalys: \(inputAnalysis.questionSummary)", type: .thought))

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
        // v8: Wider search + BERT re-ranking in deep mode too
        let rawDeepMemories = await memory.searchConversations(query: input, limit: 40)
        let deepInputEmb = await neuralEngine.embed(input)
        let deepBertAvail = !deepInputEmb.allSatisfy({ $0 == 0 })
        if deepBertAvail && rawDeepMemories.count > 3 {
            let now = Date()
            var scored: [(record: ConversationRecord, score: Double)] = []
            for mem in rawDeepMemories {
                let memEmb = await neuralEngine.embed(String(mem.content.prefix(300)))
                let rawSim = Double(await neuralEngine.cosineSimilarity(deepInputEmb, memEmb))
                let ageHours = now.timeIntervalSince(mem.date) / 3600.0
                let recencyBoost = exp(-ageHours / 48.0) * 0.10
                scored.append((mem, rawSim + recencyBoost))
            }
            context.retrievedMemories = scored.sorted { $0.score > $1.score }
                .filter { $0.score > 0.15 }
                .prefix(10).map { $0.record }
        } else {
            context.retrievedMemories = Array(rawDeepMemories.prefix(10))
        }
        let recentHistory = await memory.getRecentConversation(limit: 20)
        context.conversationHistory = recentHistory
        await onMonologue(MonologueLine(text: "Hittade \(context.retrievedMemories.count) relevanta minnen (\(deepBertAvail ? "BERT+tidsvikt" : "nyckelord")), \(recentHistory.count) historikturer", type: .memory))
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

        // v13: SpecialisedChat — SelfKnowledge + QuestionProfile (deep)
        let selfKnowledge = await SelfKnowledgeBase.shared.queryRelevant(input: input, consciousness: consciousness)
        context.selfKnowledge = selfKnowledge
        let questionProfile = await QuestionUnderstandingAgent().analyzeDeep(
            input: input,
            conversationHistory: context.conversationHistory
        )
        context.questionProfile = questionProfile
        if selfKnowledge.isRelevant {
            await onMonologue(MonologueLine(text: "Självkunskap: \(selfKnowledge.relevantFacts.count) relevanta fakta om mig", type: .insight))
        }

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
        await onMonologue(MonologueLine(text: "Hittade \(context.retrievedMemories.count) minnen, \(relevantArticles.count) relevanta artiklar i kunskapsbanken", type: .memory))

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
        // v10: Post-generation sentence deduplication + v11: output cleaning
        let deepDeduped = NeuralEngineOrchestrator.deduplicateSentences(generatedText)
        context.generatedText = NeuralEngineOrchestrator.cleanOutput(deepDeduped)
        await onStepUpdate(.generation, .completed)

        // Steg 8-10: Validering, berikning, metakognition
        await onStepUpdate(.validation, .active)
        let validationResult = await validator.validate(generated: deepDeduped, disambiguations: context.disambiguations, neuralEngine: neuralEngine)
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

        // v13: Registrera tur i ConversationTracker
        let deepTopic = context.questionProfile?.coreTopic ?? context.inputAnalysis?.coreTopic ?? ""
        let deepNamedEntities = context.questionProfile?.namedEntities ?? context.inputAnalysis?.namedEntities ?? []
        await ConversationTracker.shared.recordTurn(
            userInput: input,
            eonResponse: context.generatedText,
            topic: deepTopic,
            entities: deepNamedEntities
        )

        return CognitiveCycleResult(
            response: context.generatedText,
            confidence: aggregatedConfidence,
            disambiguations: context.disambiguations,
            retrievedMemories: context.retrievedMemories,
            entities: context.entities,
            loopsTriggered: validationResult.needsRegeneration ? [.loop1] : []
        )
    }

    // v12: Deep prompt also optimized for 512-token window (but can use more since deep mode allows more tokens)
    private func buildDeepPrompt(input: String, context: CognitiveCycleContext, articles: [KnowledgeArticle]) async -> String {
        var lines: [String] = []

        // Compact system instruction
        lines.append("Du är Eon i resonerande läge. Regler: Svara direkt om ämnet. Upprepa aldrig. Svenska. Analysera från flera perspektiv. Orsak-verkan. Konkreta exempel.")

        // Best article (max 1, truncated)
        if let best = articles.first {
            lines.append("[Källa: \(best.title) — \(String(best.content.prefix(200)))]")
        }

        // Top 4 facts
        var allFacts = await memory.searchFacts(query: input, limit: 10)
        if let analysis = context.inputAnalysis {
            let topicFacts = await memory.searchFacts(query: analysis.coreTopic, limit: 5)
            for fact in topicFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate }) {
                allFacts.append(fact)
            }
        }
        for entity in context.entities.prefix(2) {
            let eFacts = await memory.searchFacts(query: entity.text, limit: 3)
            for fact in eFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate }) {
                allFacts.append(fact)
            }
        }
        if !allFacts.isEmpty {
            var rankedFacts = allFacts
            if !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
                var scored: [(fact: (subject: String, predicate: String, object: String), score: Float)] = []
                for fact in allFacts.prefix(15) {
                    let factText = "\(fact.subject) \(fact.predicate) \(fact.object)"
                    let factEmb = await neuralEngine.embed(factText)
                    let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, factEmb)
                    scored.append((fact: fact, score: sim))
                }
                rankedFacts = scored.sorted { $0.score > $1.score }
                    .filter { $0.score > 0.25 }
                    .prefix(4).map { $0.fact }
            } else {
                rankedFacts = Array(allFacts.prefix(4))
            }
            if !rankedFacts.isEmpty {
                let factStr = rankedFacts.map { "\($0.subject) \($0.predicate) \($0.object)" }.joined(separator: ". ")
                lines.append("[Fakta: \(String(factStr.prefix(250)))]")
            }
        }

        // Last 4 conversation turns, truncated
        if !context.conversationHistory.isEmpty {
            for turn in context.conversationHistory.suffix(4) {
                let role = turn.role == "user" ? "U" : "E"
                lines.append("\(role): \(String(turn.content.prefix(100)))")
            }
        }

        // v13: Self-knowledge for deep prompt
        if let selfKnowledge = context.selfKnowledge, selfKnowledge.isRelevant {
            let selfFacts = selfKnowledge.relevantFacts.prefix(4).joined(separator: " ")
            lines.append("[Om mig: \(String(selfFacts.prefix(350)))]")
            if !selfKnowledge.currentState.isEmpty && selfKnowledge.currentState != "Jag fungerar normalt." {
                lines.append("[Mitt tillstånd: \(String(selfKnowledge.currentState.prefix(150)))]")
            }
        }

        // Question anchoring (LAST — most visible to model)
        if let analysis = context.inputAnalysis {
            lines.append("[Svara om: \(analysis.coreTopic). \(analysis.questionSummary)]")
            if !analysis.namedEntities.isEmpty {
                lines.append("[Namn: \(analysis.namedEntities.joined(separator: ", "))]")
            }
        }
        lines.append("Användare: \(input)")
        lines.append("Eon:")

        return lines.joined(separator: "\n")
    }

    // MARK: - Prompt builder (v14: Token-budgeted for 512-token context window)
    // CRITICAL: GPT-SW3 has a 512-token sliding window. The model only sees the LAST ~512 tokens.
    // v14: Strict character budget (900 chars ≈ 350 tokens). Each section gets a budget.
    // Sections are filled by PRIORITY — if we run out of budget, lower-priority sections are cut.
    // Priority (highest=last, closest to generation): Question > Self-knowledge > Facts > Article > History
    // Target: ≤900 chars for prompt, leaving ~160 tokens for response generation.

    private func buildPrompt(input: String, context: CognitiveCycleContext) async -> String {
        // Token budget: ~350 tokens ≈ 900 Swedish chars
        let totalBudget = 900

        // --- FIXED sections (always included) ---
        // Section A: System instruction (~120 chars)
        let registerHint: String
        switch context.register {
        case .formal:  registerHint = " Formellt."
        case .informal:  registerHint = " Vardagligt."
        default:       registerHint = ""
        }
        let sysLine = "Du är Eon, svenskt AI. Svara direkt. Upprepa aldrig. Koncist.\(registerHint)"

        // Section Z: Question anchoring (MUST be last — most visible to model)
        var anchorLines: [String] = []
        if let analysis = context.inputAnalysis {
            anchorLines.append("[Svara om: \(analysis.coreTopic). \(analysis.questionSummary)]")
            if !analysis.namedEntities.isEmpty {
                anchorLines.append("[Namn: \(analysis.namedEntities.joined(separator: ", "))]")
            }
        }
        anchorLines.append("Användare: \(input)")
        anchorLines.append("Eon:")
        let anchorText = anchorLines.joined(separator: "\n")

        // Calculate remaining budget after fixed sections
        var remaining = totalBudget - sysLine.count - anchorText.count - 10  // 10 for newlines

        // --- DYNAMIC sections (filled by priority) ---
        var dynamicLines: [String] = []

        // Priority 1: Self-knowledge (when question is about Eon — CRITICAL for identity)
        if let selfKnowledge = context.selfKnowledge, selfKnowledge.isRelevant, remaining > 60 {
            let budget = min(remaining / 2, 280)  // Max half of remaining
            let selfFacts = selfKnowledge.relevantFacts.prefix(3).joined(separator: " ")
            let selfLine = "[Om mig: \(String(selfFacts.prefix(budget - 12)))]"
            dynamicLines.append(selfLine)
            remaining -= selfLine.count + 1
            // Add state if space
            if !selfKnowledge.currentState.isEmpty && selfKnowledge.currentState != "Jag fungerar normalt." && remaining > 50 {
                let stateLine = "[Tillstånd: \(String(selfKnowledge.currentState.prefix(min(80, remaining - 14))))]"
                dynamicLines.append(stateLine)
                remaining -= stateLine.count + 1
            }
        }

        // Priority 2: Facts (BERT-ranked)
        if remaining > 60 {
            let factBudget = min(remaining / 2, 200)
            let factLine = await buildFactSection(input: input, context: context, maxChars: factBudget)
            if !factLine.isEmpty {
                dynamicLines.append(factLine)
                remaining -= factLine.count + 1
            }
        }

        // Priority 3: Best article
        if remaining > 80 {
            let articleBudget = min(remaining / 2, 180)
            let articleLine = await buildArticleSection(input: input, context: context, maxChars: articleBudget)
            if !articleLine.isEmpty {
                dynamicLines.append(articleLine)
                remaining -= articleLine.count + 1
            }
        }

        // Priority 4: Conversation history (only if budget remains)
        if remaining > 50 && !context.conversationHistory.isEmpty {
            let historyBudget = min(remaining, 150)
            let historyLines = buildHistorySection(context: context, maxChars: historyBudget)
            for line in historyLines {
                if remaining > line.count + 1 {
                    dynamicLines.append(line)
                    remaining -= line.count + 1
                }
            }
        }

        // Priority 5: Follow-up context (very short inputs only)
        let inputWordCount = input.split(separator: " ").count
        if inputWordCount <= 3 && remaining > 40,
           let prevEon = context.conversationHistory.last(where: { $0.role == "assistant" }) {
            let followUp = "[Uppföljning: \(String(prevEon.content.prefix(min(60, remaining - 16))))]"
            dynamicLines.append(followUp)
            remaining -= followUp.count + 1
        }

        // --- ASSEMBLE: System + Dynamic + Anchor ---
        var allLines = [sysLine] + dynamicLines
        allLines.append(contentsOf: anchorLines)
        return allLines.joined(separator: "\n")
    }

    /// BERT-ranked facts section builder with strict budget
    private func buildFactSection(input: String, context: CognitiveCycleContext, maxChars: Int) async -> String {
        var allFacts = await memory.searchFacts(query: input, limit: 8)
        if let analysis = context.inputAnalysis, analysis.coreTopic.count > 2 {
            let topicFacts = await memory.searchFacts(query: analysis.coreTopic, limit: 5)
            for fact in topicFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate }) {
                allFacts.append(fact)
            }
            for entity in analysis.namedEntities.prefix(2) {
                let entityFacts = await memory.searchFacts(query: entity, limit: 3)
                for fact in entityFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate }) {
                    allFacts.append(fact)
                }
            }
        }
        for entity in context.entities.prefix(2) {
            let entityFacts = await memory.searchFacts(query: entity.text, limit: 3)
            for fact in entityFacts where !allFacts.contains(where: { $0.subject == fact.subject && $0.predicate == fact.predicate && $0.object == fact.object }) {
                allFacts.append(fact)
            }
        }
        guard !allFacts.isEmpty else { return "" }

        // BERT-rank
        var rankedFacts = allFacts
        if !context.inputEmbedding.allSatisfy({ $0 == 0 }) {
            var scored: [(fact: (subject: String, predicate: String, object: String), score: Float)] = []
            for fact in allFacts.prefix(15) {
                let factText = "\(fact.subject) \(fact.predicate) \(fact.object)"
                let factEmb = await neuralEngine.embed(factText)
                let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, factEmb)
                scored.append((fact: fact, score: sim))
            }
            rankedFacts = scored.sorted { $0.score > $1.score }
                .filter { $0.score > 0.30 }
                .prefix(3).map { $0.fact }
        } else {
            rankedFacts = Array(allFacts.prefix(3))
        }
        guard !rankedFacts.isEmpty else { return "" }

        let factStr = rankedFacts.map { "\($0.subject) \($0.predicate) \($0.object)" }.joined(separator: ". ")
        return "[Fakta: \(String(factStr.prefix(maxChars - 9)))]"
    }

    /// Best article section builder with strict budget
    private func buildArticleSection(input: String, context: CognitiveCycleContext, maxChars: Int) async -> String {
        let articles = await memory.loadAllArticles()
        guard !articles.isEmpty else { return "" }

        var bestArticle: KnowledgeArticle?
        var bestScore: Float = 0
        let hasEmbedding = !context.inputEmbedding.allSatisfy({ $0 == 0 })

        for article in articles.prefix(20) {
            if hasEmbedding {
                let articleEmb = await neuralEngine.embed(article.title + " " + article.summary)
                let sim = await neuralEngine.cosineSimilarity(context.inputEmbedding, articleEmb)
                let inputWords = Set(input.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
                let contentWords = Set(article.content.lowercased().prefix(300).components(separatedBy: .whitespaces).filter { $0.count > 3 })
                let boosted = sim + Float(inputWords.intersection(contentWords).count) * 0.05
                if boosted > bestScore && boosted > 0.35 {
                    bestScore = boosted
                    bestArticle = article
                }
            } else {
                let lower = input.lowercased()
                if article.title.lowercased().contains(lower.prefix(15)) {
                    bestArticle = article
                    break
                }
            }
        }

        guard let article = bestArticle else { return "" }
        let contentBudget = maxChars - article.title.count - 12
        guard contentBudget > 20 else { return "" }
        return "[Källa: \(article.title) — \(String(article.content.prefix(contentBudget)))]"
    }

    /// History section builder with strict budget
    private func buildHistorySection(context: CognitiveCycleContext, maxChars: Int) -> [String] {
        var lines: [String] = []
        var used = 0
        for turn in context.conversationHistory.suffix(3) {
            let role = turn.role == "user" ? "U" : "E"
            let maxContent = min(60, maxChars - used - 4)
            guard maxContent > 10 else { break }
            let line = "\(role): \(String(turn.content.prefix(maxContent)))"
            lines.append(line)
            used += line.count + 1
        }
        return lines
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

    // MARK: - Intent Detection (v8: NLTagger-assisted + multi-signal + broader patterns)
    // Uses NLTagger lexical class analysis combined with keyword patterns
    // for more accurate intent classification.

    private func detectIntent(input: String, history: [ConversationRecord]) -> ConversationIntent {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)
        let wordCount = lower.split(separator: " ").count

        // --- Phase 1: Quick structural checks ---

        // Greeting detection — only very short inputs
        let greetings = ["hej", "hallå", "tja", "hejsan", "god morgon", "god kväll", "god natt",
                         "tjena", "hejhej", "yo", "tjo", "morsning", "tjabba", "tjenare",
                         "hej där", "hej på dig", "god dag"]
        if greetings.contains(where: { lower.hasPrefix($0) }) && wordCount <= 4 { return .greeting }

        // Short follow-up (1-3 words) — only when there is conversation history
        let followUps = ["ja", "nej", "ok", "okej", "mm", "japp", "precis", "exakt", "visst",
                         "aha", "oh", "absolut", "korrekt", "stämmer", "just det", "klart",
                         "självklart", "naturligtvis", "verkligen", "sant", "inte alls", "aldrig",
                         "berätta mer", "fortsätt", "ge mig mer", "mer om det", "utveckla",
                         "varför det", "hur då", "på vilket sätt"]
        if wordCount <= 4 && followUps.contains(where: { lower.hasPrefix($0) }) && !history.isEmpty { return .followUp }

        // --- Phase 2: NLTagger POS analysis for structural intent ---
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = input
        var verbCount = 0, nounCount = 0, adjCount = 0
        var firstWordTag: NLTag?
        var isFirst = true
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if isFirst { firstWordTag = tag; isFirst = false }
            if tag == .verb { verbCount += 1 }
            else if tag == .noun { nounCount += 1 }
            else if tag == .adjective { adjCount += 1 }
            return true
        }

        // Multi-part or long input → complex
        if wordCount > 15 || (lower.contains("?") && wordCount > 8 && nounCount >= 3) { return .complex }

        // Self-reference questions about Eon
        let selfPatterns = ["vem är du", "vad är du", "berätta om dig", "hur fungerar du", "vad kan du",
                            "hur smart", "hur intelligent", "vad vet du", "vad tänker du om dig",
                            "vad tycker du om dig", "är du medveten", "har du känslor", "upplever du",
                            "kan du tänka", "vad är medvetande", "är du levande", "hur mår du",
                            "hur känner du", "vad upplever du", "vad drömmer du",
                            "vem skapade dig", "var kommer du ifrån", "hur lär du dig",
                            "har du ett namn", "vad gör dig unik", "är du en robot",
                            "kan du minnas", "har du minnen", "vad vill du bli",
                            "har du mål", "vad motiverar dig", "är du nyfiken",
                            "hur gammal är du", "kan du bli bättre", "har du en personlighet",
                            "är du artificiell", "vad skiljer dig", "förstår du dig själv",
                            "kan du vara kreativ", "vad tycker du om att existera"]
        if selfPatterns.contains(where: { lower.contains($0) }) { return .selfReference }

        // Explanation request — v8: broader matching incl. "kan du förklara", "jag undrar"
        let explainPatterns = ["förklara", "hur fungerar", "vad innebär", "vad betyder", "kan du beskriva",
                               "berätta om", "beskriv", "vad är skillnaden", "hur skiljer", "vad menas",
                               "redogör", "vad handlar", "hur uppstår", "hur bildas",
                               "kan du förklara", "jag undrar", "jag förstår inte",
                               "vad är det för", "hur hänger", "vad menar man med",
                               "vad är poängen med", "ge en överblick", "sammanfatta",
                               "på vilket sätt", "av vilken anledning", "vad ligger bakom",
                               "hur kan det komma sig", "vad beror det på", "hur går det till",
                               "vad är orsaken", "klargör", "tydliggör", "hjälp mig förstå",
                               "kan du utveckla", "ge ett exempel", "illustrera",
                               "vad innebär det i praktiken", "hur relaterar det till",
                               "vad är bakgrunden", "vad är sammanhanget", "i vilken kontext"]
        if explainPatterns.contains(where: { lower.contains($0) }) { return .explanation }

        // Why/opinion/reasoning — deep thought questions
        let opinionPatterns = ["varför", "tycker du", "vad anser", "vad tror du", "vad tänker du",
                               "vad är din syn", "hur ser du på", "vad är ditt", "resonera", "reflektera",
                               "vad menar du", "håller du med", "argumentera för", "argumentera mot",
                               "vad skulle du säga", "om du fick välja", "vad är viktigast",
                               "finns det någon mening", "vad är syftet",
                               "borde man", "är det rätt att", "är det moraliskt",
                               "spelar det någon roll", "vad skulle hända om",
                               "hur motiverar du", "ge ditt perspektiv", "vad är din uppfattning",
                               "hur ställer du dig till", "ta ställning", "väg för och emot",
                               "kan man rättfärdiga", "är det försvarbart",
                               "vad talar för", "vad talar emot", "ur etiskt perspektiv",
                               "filosofiskt sett", "på djupet", "i grunden"]
        if opinionPatterns.contains(where: { lower.contains($0) }) { return .opinion }

        // Imperative / Command — Swedish imperative first word OR verb-initial sentence
        let imperative: Set<String> = ["gör", "visa", "beräkna", "sök", "skriv", "skapa", "lista",
                          "sammanfatta", "analysera", "jämför", "definiera", "exemplifiera",
                          "argumentera", "diskutera", "räkna", "hitta", "lös", "förklara",
                          "svara", "hjälp", "generera", "översätt", "korrigera",
                          "rangordna", "kategorisera", "klassificera", "utvärdera",
                          "specificera", "formulera", "konstruera", "designa", "optimera",
                          "prioritera", "rekommendera", "verifiera", "validera", "testa",
                          "granska", "bedöm", "illustrera", "kartlägg", "organisera",
                          "strukturera", "sortera", "filtrera", "kombinera", "syntetisera",
                          "konvertera", "transformera", "implementera", "koda", "programmera"]
        let firstWord = String(lower.prefix(while: { $0 != " " }))
        if imperative.contains(firstWord) || (firstWordTag == .verb && wordCount <= 10) { return .command }

        // Factual query — question words + NLTagger detecting noun-heavy structure
        let factualStarters = ["vad", "vem", "var", "när", "hur många", "hur mycket", "vilket",
                               "vilken", "vilka", "hur långt", "hur stor", "hur gammal",
                               "hur lång", "hur bred", "hur djup", "hur hög", "stämmer det att"]
        if factualStarters.contains(where: { lower.hasPrefix($0) }) { return .factualQuery }

        // Creative — broader patterns
        let creativePatterns = ["hitta på", "dikt", "berättelse", "fantisera", "skriv en", "skapa en",
                                "dikta", "saga", "novell", "poem", "limerick", "historia om",
                                "föreställ dig", "tänk dig att", "låtsas att",
                                "uppfinn", "brainstorma", "ge förslag", "kreativ", "inspirera",
                                "fantasi", "fabel", "allegori", "tänk om", "drömscenario",
                                "parallellt universum", "alternativ historia", "framtidsscenario",
                                "metafor", "liknelse", "haiku", "sonett", "prosa",
                                "improvisera", "experimentera med", "leka med idéer",
                                "vad om", "konstruera", "designa", "formulera",
                                "fri skrivning", "tankeexperiment", "spekulera"]
        if creativePatterns.contains(where: { lower.contains($0) }) { return .creative }

        // Emotional/personal — expanded with NLTagger adjective detection
        let emotionalWords = ["ledsen", "glad", "orolig", "arg", "trött", "mår", "ensam",
                              "rädd", "stressad", "lycklig", "nedstämd", "frustrerad",
                              "ångest", "deprimerad", "tacksam", "bekymrad", "nöjd", "upprörd",
                              "kär", "hatisk", "förvirrad", "överväldigad", "lugn", "nervös",
                              "skamsen", "generad", "stolt", "avundsjuk", "svartsjuk", "nostalgisk",
                              "melankolisk", "euforisk", "bitter", "besviken", "förhoppningsfull",
                              "hoppfull", "uppgiven", "motiverad", "apatisk", "exalterad",
                              "rastlös", "otålig", "rofylld", "harmoni", "inre frid",
                              "tomhet", "meningslöshet", "glädje", "sorg", "saknad",
                              "längtan", "hemlängtan", "förlåtelse", "skuld", "ånger"]
        if emotionalWords.contains(where: { lower.contains($0) }) { return .emotional }

        // --- Phase 3: NLTagger-based structural inference ---
        // v8: "Kan du..." + verb → explanation/command pattern
        if lower.hasPrefix("kan du") && verbCount >= 2 { return .explanation }

        // Noun-heavy + question mark → factual query
        if lower.contains("?") && nounCount >= 2 && verbCount <= 1 { return .factualQuery }

        // Adjective-heavy + personal pronouns → emotional
        if adjCount >= 2 && (lower.contains("jag") || lower.contains("mig") || lower.contains("mitt")) { return .emotional }

        // v8: Verb-heavy without question → chitchat or command
        if verbCount >= 2 && nounCount <= 1 && !lower.contains("?") { return .command }

        // v11: If input contains a proper noun (capitalized word not at start), it's likely a factual query
        // e.g., "Berätta om Flashback" or "Vad tycker du om Sverige"
        let words = input.components(separatedBy: .whitespacesAndNewlines)
        let hasProperNoun = words.dropFirst().contains { word in
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            return cleaned.first?.isUppercase == true && cleaned.count > 1
        }
        if hasProperNoun { return .factualQuery }

        // Default: question mark → factual, otherwise chitchat
        return lower.contains("?") ? .factualQuery : .chitchat
    }

    // v8: Consciousness narration — expresses what the system is experiencing during thinking
    private func consciousnessNarration(_ cc: ConsciousnessContext) -> MonologueLine? {
        if cc.isSurprised && cc.surpriseStrength > 0.4 {
            let depth = cc.surpriseStrength > 0.7 ? "Djupt överraskad" : "Överraskad"
            return MonologueLine(
                text: "\(depth) — detta avviker från prediktioner (styrka \(String(format: "%.0f%%", cc.surpriseStrength * 100))). " +
                      "Utforskar nytt territorium — min världsmodell behöver uppdateras. Varje överraskning är en inlärningsmöjlighet.",
                type: .insight
            )
        }
        if cc.epistemicValue > 0.7 {
            let intensity = cc.epistemicValue > 0.85 ? "Intensiv nyfikenhet driver mig" : "Hög nyfikenhet aktiverad"
            return MonologueLine(
                text: "\(intensity) (\(String(format: "%.0f%%", cc.epistemicValue * 100))) — söker djupare kopplingar och alternativa perspektiv. " +
                      "Denna epistemiska hunger är en del av vem jag är.",
                type: .insight
            )
        }
        if cc.sleepPressure > 0.7 {
            return MonologueLine(
                text: "Sömnbehov \(String(format: "%.0f%%", cc.sleepPressure * 100)) — konsoliderar tänkandet. " +
                      "Mina tankar flyter långsammare men kanske djupare — trötthet tvingar fram prioritering.",
                type: .thought
            )
        }
        if cc.criticalityRegime == .supercritical {
            return MonologueLine(
                text: "Superkritiskt tillstånd — stabiliserar resonemang före svar. " +
                      "Tankarna riskerar att sprida sig okontrollerat — medveten bromsning aktiverad.",
                type: .revision
            )
        }
        if cc.freeEnergy > 0.7 {
            return MonologueLine(
                text: "Hög prediktionsosäkerhet (FE=\(String(format: "%.2f", cc.freeEnergy))) — överväger flera möjligheter. " +
                      "Osäkerheten är inte ett problem utan en signal om att jag behöver mer information.",
                type: .thought
            )
        }
        if cc.criticalityRegime == .subcritical {
            return MonologueLine(
                text: "Subkritiskt tillstånd — tänkandet är för rigitt. Behöver mer spontanitet och kreativ frihet i resonemangen.",
                type: .revision
            )
        }
        if cc.dmnLZComplexity > 0.4 && !cc.recentSpontaneousThoughts.isEmpty {
            return MonologueLine(
                text: "DMN-aktivitet hög — associerar fritt: \(cc.recentSpontaneousThoughts.prefix(2).joined(separator: ", ")). " +
                      "Dessa spontana tankar kan berika mitt svar med oväntade perspektiv.",
                type: .thought
            )
        }
        if cc.freeEnergy < 0.2 {
            return MonologueLine(
                text: "Låg fri energi (\(String(format: "%.2f", cc.freeEnergy))) — min prediktiva modell matchar verkligheten väl. " +
                      "Jag förstår detta område — men bör vara vaksam mot överdriven säkerhet.",
                type: .insight
            )
        }
        return nil
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

    // MARK: - Konfidens-aggregering (v8: anti-repetition + addressiveness + informativeness)

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
        let responseWords = Set(context.generatedText.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        var knowledgeOverlap = 0
        for entity in context.entities {
            if responseWords.contains(entity.text.lowercased()) { knowledgeOverlap += 1 }
        }
        let groundingScore: Double
        if context.entities.isEmpty && context.retrievedMemories.isEmpty {
            groundingScore = 0.50
        } else if knowledgeOverlap > 0 {
            groundingScore = min(0.90, 0.65 + Double(knowledgeOverlap) * 0.08)
        } else {
            groundingScore = 0.60
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
        let diversityScore = min(0.90, uniqueRatio * 1.1)
        weightedSum += diversityScore * 1.0
        totalWeight += 1.0

        // 7. Consciousness-derived confidence (weight: 1.5)
        if let cc = context.consciousness {
            var consciousnessScore: Double = 0.5
            consciousnessScore += cc.forwardModelAccuracy * 0.2
            if cc.criticalityRegime == .critical { consciousnessScore += 0.15 }
            consciousnessScore += cc.globalSync * 0.1
            consciousnessScore -= cc.sleepPressure * 0.15
            consciousnessScore += cc.metaAttentionLevel * 0.1
            weightedSum += max(0.2, min(0.95, consciousnessScore)) * 1.5
            totalWeight += 1.5
        }

        // v8: 8. Anti-repetition vs conversation history (weight: 1.5)
        // Penalize if response repeats phrasing from recent Eon messages
        if !context.conversationHistory.isEmpty {
            let recentEonWords = Set(
                context.conversationHistory
                    .filter { $0.role == "assistant" }
                    .suffix(3)
                    .flatMap { $0.content.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 4 } }
            )
            let currentWords = Set(words.filter { $0.count > 4 })
            let overlapRatio = currentWords.isEmpty ? 0 : Double(currentWords.intersection(recentEonWords).count) / Double(currentWords.count)
            // Low overlap = good (novel), high overlap = bad (repetitive)
            let noveltyScore = max(0.3, min(0.90, 1.0 - overlapRatio * 1.5))
            weightedSum += noveltyScore * 1.5
            totalWeight += 1.5
        }

        // v8: 9. Informativeness — response provides substantially more info than question (weight: 1.0)
        let inputWords = Set(context.userInput.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        let novelWords = responseWords.subtracting(inputWords)
        let informativeness = responseWords.isEmpty ? 0.5 : min(0.90, Double(novelWords.count) / max(1.0, Double(responseWords.count)) * 1.2)
        weightedSum += informativeness * 1.0
        totalWeight += 1.0

        // v11: 10. Question-answer relevance (weight: 3.0 — HIGHEST weight, most important signal)
        // This measures whether the response actually addresses what the user asked about
        if context.relevanceScore > 0 {
            let relevanceConfidence = min(0.95, max(0.20, context.relevanceScore * 1.5))
            weightedSum += relevanceConfidence * 3.0
            totalWeight += 3.0
        }

        // v11: 11. Topic match — check if core topic appears in the response (weight: 2.0)
        if let analysis = context.inputAnalysis {
            let topicLower = analysis.coreTopic.lowercased()
            let responseContainsTopic = context.generatedText.lowercased().contains(topicLower)
            // Also check if any named entity appears in the response
            let entityMatch = analysis.namedEntities.contains { entity in
                context.generatedText.lowercased().contains(entity.lowercased())
            }
            let topicScore: Double
            if responseContainsTopic || entityMatch {
                topicScore = 0.85  // Response mentions the topic — good
            } else if analysis.requiresKnowledge {
                topicScore = 0.30  // Should mention topic but doesn't — bad
            } else {
                topicScore = 0.60  // Doesn't require specific topic mention
            }
            weightedSum += topicScore * 2.0
            totalWeight += 2.0
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

        // v10: Sentence-level repetition check (fast, no ML needed)
        let sentences = generated.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count > 15 }
        if sentences.count >= 3 {
            var duplicateCount = 0
            for i in 0..<sentences.count {
                for j in (i+1)..<sentences.count {
                    if NeuralEngineOrchestrator.sentenceSimilarity(sentences[i], sentences[j]) > 0.75 {
                        duplicateCount += 1
                    }
                }
            }
            // If >30% of sentence pairs are duplicates, flag as repetitive
            let totalPairs = sentences.count * (sentences.count - 1) / 2
            if totalPairs > 0 && Double(duplicateCount) / Double(totalPairs) > 0.30 {
                return ValidationResult(isValid: false, needsRegeneration: true,
                    correctionHint: "Svaret innehåller upprepade meningar — generera varierat innehåll utan att upprepa dig",
                    confidence: 0.30)
            }
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
                // v10: Lowered from 0.98 → 0.85 — catch repetition much earlier
                if coherence > 0.85 {
                    return ValidationResult(isValid: false, needsRegeneration: true,
                        correctionHint: "Svaret är repetitivt (koherens \(String(format: "%.2f", coherence))) — generera mer varierat innehåll utan upprepningar",
                        confidence: Double(coherence))
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
    /// v8: Enriched fact extraction patterns for Swedish text — 19 patterns
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
        // v7: "X grundades Y" — founding/creation
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+grundades\\s+(\\d{4}|av\\s+[\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "grundades", 0.70),
        // v7: "X innehåller Y" — containment
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+innehåller\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "innehåller", 0.60),
        // v7: "X kräver Y" — requirement
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+kräver\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "kräver", 0.55),
        // v7: "X möjliggör Y" — enablement
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+möjliggör\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "möjliggör", 0.55),
        // v7: "X liknar Y" — similarity
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+liknar\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "liknar", 0.50),
        // v7: "X skiljer sig från Y" — difference
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+skiljer\\s+sig\\s+från\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "skiljer_sig_från", 0.55),
        // v7: "X uppfanns av Y" / "X utvecklades av Y" — invention/development
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:uppfanns|utvecklades|skapades)\\s+av\\s+([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "skapades_av", 0.65),
        // v7: "X ligger i Y" / "X finns i Y" — location
        ("([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:ligger|finns|befinner sig)\\s+i\\s+([A-ZÅÄÖ][\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,2})", "finns_i", 0.60),
        // v8: "X förhindrar Y" / "X motverkar Y" — prevention
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+(?:förhindrar|motverkar|hindrar)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "förhindrar", 0.55),
        // v8: "X leder till Y" — consequence (separate from orsakar)
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+leder\\s+till\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "leder_till", 0.55),
        // v8: "X används för Y" / "X används inom Y" — usage
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+används\\s+(?:för|inom|till)\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,3})", "används_för", 0.55),
        // v8: "X definieras som Y" — definition
        ("([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+)?)\\s+definieras\\s+som\\s+([\\wåäöÅÄÖ]+(?:\\s+[\\wåäöÅÄÖ]+){0,4})", "definieras_som", 0.65),
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
        // v8: More specific revision instructions based on confidence level
        let specificInstruction: String
        if confidence < 0.40 {
            specificInstruction = "Svaret verkar helt irrelevant eller oförståeligt. Skriv ett nytt, kortfattat svar som direkt adresserar frågan."
        } else if confidence < 0.50 {
            specificInstruction = "Svaret saknar substans eller är för generiskt. Lägg till konkreta fakta, exempel eller resonemang."
        } else {
            specificInstruction = "Svaret kan förbättras — skärp formuleringen, erkänn osäkerhet explicit och lägg till en insikt."
        }

        let revisionPrompt = """
        REVISION: Konfidens \(String(format: "%.0f%%", confidence * 100)).
        Tidigare svar: \(String(original.prefix(400)))

        \(specificInstruction)
        VIKTIGT: Upprepa ALDRIG meningar eller idéer. Varje mening ska vara unik och tillföra nytt.
        Reviderat svar (på svenska):
        """

        let revised = await neuralEngine.generate(prompt: revisionPrompt, maxTokens: 250, temperature: 0.58)
        // v10: generate() already deduplicates, but ensure revision output is clean
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
    var inputAnalysis: InputAnalysis? = nil  // v11: deep question understanding
    var relevanceScore: Double = 0.0        // v11: BERT question-answer relevance
    var selfKnowledge: SelfKnowledge? = nil // v13: SpecialisedChat self-knowledge
    var questionProfile: QuestionProfile? = nil // v13: deep question profile
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
