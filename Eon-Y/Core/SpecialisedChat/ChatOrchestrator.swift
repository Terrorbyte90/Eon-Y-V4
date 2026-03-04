import Foundation

// MARK: - ChatOrchestrator: Master koordinator för Eons chattintelligens
// Hanterar 5-sekunders tidsbudget, pausar icke-essentiella processer,
// kör parallella agenter och bygger det bästa möjliga svaret.

actor ChatOrchestrator {
    static let shared = ChatOrchestrator()

    // Tidsbudget
    private let normalTimeBudget: TimeInterval = 4.5   // 4.5s av 5s (0.5s marginal)
    private let deepTimeBudget: TimeInterval = 120.0    // 2 min av 5 min

    // Agenter
    private let questionAgent = QuestionUnderstandingAgent()
    private let knowledgeAgent = KnowledgeRetrievalAgent()
    private let selfKnowledge = SelfKnowledgeBase.shared
    private let strategyPlanner = ResponseStrategyPlanner()
    private let composer = ResponseComposer()
    private let qualityGuard = ResponseQualityGuard()
    private let conversationTracker = ConversationTracker.shared
    private let thinkingEngine = ParallelThinkingEngine()

    private init() {}

    // MARK: - Huvudflöde: Normal chatt (max 5 sekunder)

    struct ChatResult: Sendable {
        let response: String
        let confidence: Double
        let strategy: ResponseStrategy
        let knowledgeSources: [String]
        let questionProfile: QuestionProfile
        let thinkingTime: TimeInterval
    }

    func process(
        input: String,
        conversationHistory: [ConversationRecord],
        memories: [ConversationRecord],
        entities: [ExtractedEntity],
        inputEmbedding: [Float],
        consciousness: ConsciousnessContext?
    ) async -> ChatResult {
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(normalTimeBudget)

        // --- Fas 0: Pausa icke-essentiella processer för att frigöra CPU ---
        await pauseNonEssentialEngines()

        // --- Fas 1: Parallella agenter (använd max 2.5s) ---
        // Kör ALLA analyser samtidigt — varje millisekund räknas
        let phase1Deadline = startTime.addingTimeInterval(2.5)

        async let questionProfile = questionAgent.analyze(
            input: input,
            conversationHistory: conversationHistory
        )

        async let knowledgeBundle = knowledgeAgent.retrieve(
            input: input,
            entities: entities,
            inputEmbedding: inputEmbedding,
            deadline: phase1Deadline
        )

        async let conversationContext = conversationTracker.resolveContext(
            input: input,
            history: conversationHistory
        )

        async let selfKnowledgeResult = selfKnowledge.queryRelevant(
            input: input,
            consciousness: consciousness
        )

        // Vänta på alla parallella resultat
        let profile = await questionProfile
        let knowledge = await knowledgeBundle
        let convContext = await conversationContext
        let selfInfo = await selfKnowledgeResult

        // --- Fas 2: Strategiplanering (max 0.3s) ---
        let strategy = await strategyPlanner.plan(
            question: profile,
            knowledge: knowledge,
            selfKnowledge: selfInfo,
            conversationContext: convContext
        )

        // --- Fas 3: Parallellt tänkande om tid finns (max 1.0s) ---
        let remainingTime = deadline.timeIntervalSince(Date())
        var thinkingResults: [ThinkingPath] = []
        if remainingTime > 1.0 && strategy.requiresReasoning {
            thinkingResults = await thinkingEngine.think(
                question: profile,
                knowledge: knowledge,
                timeBudget: min(1.0, remainingTime - 0.5)
            )
        }

        // --- Fas 4: Komponera svar (max 0.5s) ---
        let draft = await composer.compose(
            question: profile,
            knowledge: knowledge,
            selfKnowledge: selfInfo,
            strategy: strategy,
            conversationContext: convContext,
            thinkingResults: thinkingResults
        )

        // --- Fas 5: Kvalitetskontroll (max 0.3s) ---
        let finalResponse = await qualityGuard.validate(
            draft: draft,
            question: profile,
            knowledge: knowledge
        )

        // --- Fas 6: Uppdatera konversationstracker ---
        await conversationTracker.recordTurn(
            userInput: input,
            eonResponse: finalResponse.text,
            topic: profile.coreTopic,
            entities: profile.namedEntities
        )

        // --- Fas 7: Återuppta pausade processer ---
        await resumeEngines()

        let elapsed = Date().timeIntervalSince(startTime)
        print("[ChatOrchestrator] Svar genererat på \(String(format: "%.2f", elapsed))s (strategi: \(strategy.type.rawValue))")

        return ChatResult(
            response: finalResponse.text,
            confidence: finalResponse.confidence,
            strategy: strategy,
            knowledgeSources: knowledge.sources,
            questionProfile: profile,
            thinkingTime: elapsed
        )
    }

    // MARK: - Djupt resonemang (max 5 minuter)

    func processDeep(
        input: String,
        conversationHistory: [ConversationRecord],
        memories: [ConversationRecord],
        entities: [ExtractedEntity],
        inputEmbedding: [Float],
        consciousness: ConsciousnessContext?
    ) async -> ChatResult {
        let startTime = Date()

        await pauseNonEssentialEngines()

        // Djupare analys med längre tidsbudget
        async let questionProfile = questionAgent.analyzeDeep(
            input: input,
            conversationHistory: conversationHistory
        )
        async let knowledgeBundle = knowledgeAgent.retrieveDeep(
            input: input,
            entities: entities,
            inputEmbedding: inputEmbedding
        )
        async let convContext = conversationTracker.resolveContext(
            input: input,
            history: conversationHistory
        )
        async let selfInfo = selfKnowledge.queryRelevant(
            input: input,
            consciousness: consciousness
        )

        let profile = await questionProfile
        let knowledge = await knowledgeBundle
        let context = await convContext
        let self_ = await selfInfo

        let strategy = await strategyPlanner.planDeep(
            question: profile,
            knowledge: knowledge,
            selfKnowledge: self_
        )

        // Djupt tänkande med full tidsbudget
        let thinkingResults = await thinkingEngine.thinkDeep(
            question: profile,
            knowledge: knowledge,
            timeBudget: 30.0  // 30s för djupt resonemang
        )

        let draft = await composer.composeDeep(
            question: profile,
            knowledge: knowledge,
            selfKnowledge: self_,
            strategy: strategy,
            conversationContext: context,
            thinkingResults: thinkingResults
        )

        let finalResponse = await qualityGuard.validateDeep(
            draft: draft,
            question: profile,
            knowledge: knowledge
        )

        await conversationTracker.recordTurn(
            userInput: input,
            eonResponse: finalResponse.text,
            topic: profile.coreTopic,
            entities: profile.namedEntities
        )

        await resumeEngines()

        let elapsed = Date().timeIntervalSince(startTime)
        return ChatResult(
            response: finalResponse.text,
            confidence: finalResponse.confidence,
            strategy: strategy,
            knowledgeSources: knowledge.sources,
            questionProfile: profile,
            thinkingTime: elapsed
        )
    }

    // MARK: - Processhantering

    /// Pausar icke-essentiella motorer för att frigöra CPU under svarstänkande.
    /// Sparar tillståndet så att de kan återupptas exakt där de var.
    private func pauseNonEssentialEngines() async {
        await MainActor.run {
            // Pausa ESN (Default Mode Network) — spontana tankar kan vänta
            EchoStateNetwork.shared.setPaused(true)
            // Pausa sömnkonsolidering — inte brådskande under aktiv konversation
            SleepConsolidationEngine.shared.setPaused(true)
            // Sänk oscillatorbankens uppdateringsfrekvens temporärt
            OscillatorBank.shared.setLowPowerMode(true)
        }
    }

    /// Återupptar pausade motorer exakt där de slutade.
    private func resumeEngines() async {
        await MainActor.run {
            EchoStateNetwork.shared.setPaused(false)
            SleepConsolidationEngine.shared.setPaused(false)
            OscillatorBank.shared.setLowPowerMode(false)
        }
    }
}
