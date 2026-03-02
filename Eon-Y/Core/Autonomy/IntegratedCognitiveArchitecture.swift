import Foundation
import Combine
import NaturalLanguage

// MARK: - IntegratedCognitiveArchitecture (ICA)
// Det verkliga kognitiva systemet där ALLA pelare körs och påverkar varandra.
// Arkitekturen bygger på tre principer:
//
// 1. KAUSAL KOPPLING: Varje pelare läser från och skriver till CognitiveState.
//    En förbättring i Reasoning propagerar automatiskt till Causality och Metacognition.
//
// 2. EVENT-DRIVEN FEEDBACK: Pelare triggar varandra via CognitiveEvents.
//    En ny hypotes triggar automatiskt ReasoningEngine att testa den.
//    En kunskapslucka triggar automatiskt LearningEngine att fylla den.
//
// 3. METAKOGNITIV STYRNING: MetacognitionCore övervakar alla pelare och
//    omdirigerar resurser dit de behövs mest — precis som en professor
//    som vet vad de behöver lära sig härnäst.

@MainActor
final class IntegratedCognitiveArchitecture: ObservableObject {
    static let shared = IntegratedCognitiveArchitecture()

    // MARK: - Tillstånd

    @Published var isRunning = false
    @Published var currentCycle: Int = 0
    @Published var activePillars: Set<CognitivePillar> = []
    @Published var eventLog: [CognitiveEvent] = []
    @Published var pillarActivity: [CognitivePillar: Double] = [:]
    @Published var lastMetacognitiveReport: MetacognitiveReport?
    @Published var lastGapAnalysis: GapAnalysis?
    @Published var pillarInteractions: [PillarInteraction] = []

    private var tasks: [Task<Void, Never>] = []
    // Stark referens — EonBrain är singleton och lever hela appens livstid
    private var brain: EonBrain?

    // Cooldown-tidsstämplar för att förhindra event-spam
    private var lastStagnationEvent: Date = .distantPast
    private var lastGapEventKey: String = ""
    private var lastGapEventDate: Date = .distantPast
    private static let stagnationCooldown: TimeInterval = 300   // 5 min
    private static let gapCooldown: TimeInterval = 180          // 3 min

    // Snapshot för EonBrain.engineActivity (String-keyed)
    var pillarActivitySnapshot: [String: Double] {
        var result: [String: Double] = [:]
        for (pillar, value) in pillarActivity {
            result[pillar.rawValue] = value
        }
        // Lägg till nycklarna som hemvyn förväntar sig
        result["cognitive"]  = pillarActivity[.reasoning] ?? 0
        result["language"]   = pillarActivity[.language] ?? 0
        result["memory"]     = pillarActivity[.knowledge] ?? 0
        result["learning"]   = pillarActivity[.knowledge] ?? 0
        result["autonomy"]   = pillarActivity[.metacognition] ?? 0
        return result
    }

    private init() {
        for pillar in CognitivePillar.allCases { pillarActivity[pillar] = 0.0 }
    }

    // MARK: - Start (v3 Claude Edition — 3 tasks instead of 13)
    // The old ICA launched 13 concurrent loops that duplicated much of EonLiveAutonomy's work.
    // v3 uses only 3 tasks:
    // 1. Lightweight orchestrator (UI sync, event dispatch)
    // 2. Metacognitive + gap engine (combined, runs infrequently)
    // 3. Combined pillar worker (rotates through pillars, one at a time)

    func start(brain: EonBrain) {
        guard !isRunning else { return }
        self.brain = brain
        isRunning = true

        // Task 1: Lightweight orchestrator — UI sync only (no heavy computation)
        tasks.append(Task(priority: .utility) { await self.orchestratorLoop() })

        // Task 2: Metacognition + gap engine (combined, every 60s)
        tasks.append(Task(priority: .background) { await self.metacognitiveAndGapLoop() })

        // Task 3: Combined pillar worker — rotates through pillars one at a time
        tasks.append(Task(priority: .background) { await self.combinedPillarWorker() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        isRunning = false
    }

    // MARK: - Orkestrator (6s) — lightweight UI sync, no heavy computation
    // v3: Increased interval from 2s to 6s, removed heavy computation.
    // EonLiveAutonomy's phased system handles the heavy lifting now.

    private func orchestratorLoop() async {
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 5_000_000_000); continue }
            currentCycle += 1

            let state = CognitiveState.shared
            let ii = state.integratedIntelligence
            let velocity = state.growthVelocity

            // Lightweight: just sync ICA state to brain for UI
            brain.isAutonomouslyActive = true
            brain.integratedIntelligence = ii
            brain.intelligenceGrowthVelocity = velocity

            // Update pillar activity from dimension levels
            for pillar in CognitivePillar.allCases {
                pillarActivity[pillar] = state.dimensionLevel(pillar.primaryDimension)
            }

            // Check and fire events (infrequently — every 5th cycle = ~30s)
            if currentCycle % 5 == 0 {
                await checkAndFireEvents(state: state, brain: brain)
            }

            // v5: Thermal-aware interval: 15s nominal → up to 60s critical
            // UI-synk sköts av EonBrain master tick (10s), orchestrator behöver bara hantera events.
            let thermalState = ProcessInfo.processInfo.thermalState
            let baseInterval: UInt64
            switch thermalState {
            case .nominal:  baseInterval = 15_000_000_000
            case .fair:     baseInterval = 20_000_000_000
            case .serious:  baseInterval = 40_000_000_000
            case .critical: baseInterval = 60_000_000_000
            @unknown default: baseInterval = 15_000_000_000
            }
            // v4.1: Motor speed multiplier — Eon can speed up or slow down orchestration
            let interval = EonMotorController.shared.adjustedInterval(base: baseInterval, motorId: "orchestrator")
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(value, lo), hi)
    }

    private func buildStatusLabel(ii: Double, velocity: Double, state: CognitiveState) -> String {
        let label = ii > 0.8 ? "Expert" : ii > 0.6 ? "Avancerad" : ii > 0.4 ? "Lärande" : "Grundläggande"
        let trend = velocity > 0.001 ? "↑" : velocity < -0.001 ? "↓" : "→"
        let topDim = state.topDimensions(limit: 1).first?.0.rawValue ?? "?"
        return "ICA \(label) \(trend) · II=\(String(format: "%.3f", ii)) · Topp: \(topDim)"
    }

    // MARK: - Event-system

    private func checkAndFireEvents(state: CognitiveState, brain: EonBrain) async {
        let now = Date()

        // Event: Kunskapslucka identifierad — max en gång per 3 min per unik lucka
        if let urgentGap = state.urgentGap {
            let gapKey = "\(urgentGap.dimension.rawValue)_\(Int(urgentGap.currentLevel * 100))"
            let isNewGap = gapKey != lastGapEventKey
            let cooldownPassed = now.timeIntervalSince(lastGapEventDate) > Self.gapCooldown
            if isNewGap || cooldownPassed {
                lastGapEventKey = gapKey
                lastGapEventDate = now
                let event = CognitiveEvent(
                    type: .gapIdentified,
                    source: .metacognition,
                    target: urgentGap.dimension.pillar,
                    payload: "Lucka i \(urgentGap.dimension.rawValue): \(String(format: "%.0f", urgentGap.currentLevel * 100))% → \(String(format: "%.0f", urgentGap.targetLevel * 100))%",
                    priority: urgentGap.urgency > 2.0 ? .high : .medium
                )
                await fireEvent(event, brain: brain)
            }
        }

        // Event: Reasoning milestone → trigger deeper causal analysis
        let reasoningLevel = state.dimensionLevel(.reasoning)
        if reasoningLevel > 0.6 && Int.random(in: 0...10) == 0 {
            let event = CognitiveEvent(
                type: .pillarActivated,
                source: .reasoning,
                target: .causality,
                payload: "Resonemangsnivå \(String(format: "%.2f", reasoningLevel)) → aktiverar djupare kausalanalys",
                priority: .medium
            )
            await fireEvent(event, brain: brain)
        }

        // Event: Knowledge breakthrough — dimension crosses a significant threshold
        for dim in CognitiveDimension.allCases {
            let level = state.dimensionLevel(dim)
            let prevKey = "eon_dim_milestone_\(dim.rawValue)"
            let prevMilestone = UserDefaults.standard.double(forKey: prevKey)
            let milestones = [0.3, 0.5, 0.7, 0.85]
            for milestone in milestones where level >= milestone && prevMilestone < milestone {
                UserDefaults.standard.set(milestone, forKey: prevKey)
                let event = CognitiveEvent(
                    type: .breakthroughAchieved,
                    source: dim.pillar,
                    target: .metacognition,
                    payload: "\(dim.rawValue) nådde \(Int(milestone * 100))% — kognitiv milstolpe!",
                    priority: .high
                )
                await fireEvent(event, brain: brain)
                break
            }
        }

        // Event: Analogy opportunity — two growing dimensions suggest cross-domain insight
        let growingDims = CognitiveDimension.allCases.filter { state.dimensionTrend($0) > 0.005 }
        if growingDims.count >= 2 && Int.random(in: 0...5) == 0 {
            let event = CognitiveEvent(
                type: .analogyFound,
                source: .analogy,
                target: .reasoning,
                payload: "Samväxande dimensioner: \(growingDims.prefix(2).map { $0.rawValue }.joined(separator: " + ")) — potentiell korskoppling",
                priority: .medium
            )
            await fireEvent(event, brain: brain)
        }

        // Event: Stagnation detected — max once per 5 min
        let velocity = state.growthVelocity
        if abs(velocity) < 0.00005 && currentCycle > 20 {
            if now.timeIntervalSince(lastStagnationEvent) > Self.stagnationCooldown {
                lastStagnationEvent = now
                // Target the weakest pillar, not always knowledge
                let weakest = state.weakestDimensions(limit: 1).first?.0 ?? .knowledge
                let event = CognitiveEvent(
                    type: .stagnationDetected,
                    source: .metacognition,
                    target: weakest.pillar,
                    payload: "Stagnation (v=\(String(format: "%.6f", velocity))). Fokuserar på \(weakest.rawValue).",
                    priority: .high
                )
                await fireEvent(event, brain: brain)

                // Also trigger a perturbation: small random boost to weakest dimensions
                let weakDims = state.weakestDimensions(limit: 3)
                for (dim, _) in weakDims {
                    await state.update(dimension: dim, delta: 0.005, source: "stagnation_perturbation")
                }
            }
        }
    }

    private func fireEvent(_ event: CognitiveEvent, brain: EonBrain) async {
        eventLog.append(event)
        if eventLog.count > 200 { eventLog.removeFirst(50) }

        // Logga i brain monologue för UI
        let emoji = event.priority == .high ? "🔴" : event.priority == .medium ? "🟡" : "🟢"
        let monologueText = "\(emoji) ICA[\(event.source.rawValue)→\(event.target.rawValue)]: \(event.payload)"
        brain.innerMonologue.append(MonologueLine(
            text: monologueText,
            type: .loopTrigger
        ))

        // Loggning till fil sker automatiskt via EonBrain.$innerMonologue Combine-observer

        // Registrera interaktion
        pillarInteractions.append(PillarInteraction(
            from: event.source,
            to: event.target,
            type: event.type,
            strength: event.priority == .high ? 0.9 : 0.6
        ))
        if pillarInteractions.count > 100 { pillarInteractions.removeFirst(20) }
    }

    // MARK: - Combined Metacognitive + Gap Engine Loop (60s)
    // v3: Combined two loops into one. Runs metacognition first, then gap analysis.
    // Interval increased from 30-45s to 60s to reduce CPU.

    private func metacognitiveAndGapLoop() async {
        try? await Task.sleep(nanoseconds: 10_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 10_000_000_000); continue }

            // --- Metacognition phase ---
            activePillars.insert(.metacognition)
            let report = await MetacognitionCore.shared.runMetacognitiveCycle()
            lastMetacognitiveReport = report

            for insight in report.insights.prefix(2) {
                let prefix = insight.type == .regression ? "⚠️" : insight.type == .growth ? "📈" : "🧠"
                brain.innerMonologue.append(MonologueLine(
                    text: "\(prefix) META: \(insight.content)",
                    type: .insight
                ))
            }
            for bias in report.detectedBiases where bias.severity == .high {
                brain.innerMonologue.append(MonologueLine(
                    text: "🔍 BIAS[\(bias.type.rawValue)]: \(bias.recommendation)",
                    type: .revision
                ))
            }
            activePillars.remove(.metacognition)

            // Brief pause between metacognition and gap analysis
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            // --- Gap Engine phase ---
            activePillars.insert(.gapEngine)
            let analysis = await IntelligenceGapEngine.shared.analyzeAndIntervene()
            lastGapAnalysis = analysis

            for gap in analysis.prioritizedGaps.prefix(2) {
                brain.innerMonologue.append(MonologueLine(
                    text: "🎯 GAP[\(gap.priorityLabel)]: \(gap.dimension.rawValue) \(String(format: "%.0f", gap.currentLevel * 100))%→\(String(format: "%.0f", gap.targetLevel * 100))%",
                    type: .thought
                ))
            }
            for result in analysis.results where result.improvementDelta > 0.001 {
                brain.innerMonologue.append(MonologueLine(
                    text: "✅ INTERVENTION[\(result.dimension.rawValue)]: +\(String(format: "%.4f", result.improvementDelta))",
                    type: .insight
                ))
                await CognitiveState.shared.update(dimension: result.dimension, delta: result.improvementDelta, source: "gap_engine")
            }
            activePillars.remove(.gapEngine)

            // Thermal-aware interval: 60s nominal → up to 480s critical
            let thermalState = ProcessInfo.processInfo.thermalState
            let baseInterval: UInt64
            switch thermalState {
            case .nominal:  baseInterval = 60_000_000_000
            case .fair:     baseInterval = 120_000_000_000
            case .serious:  baseInterval = 300_000_000_000
            case .critical: baseInterval = 480_000_000_000
            @unknown default: baseInterval = 60_000_000_000
            }
            // v4.1: Motor speed multiplier for metacognition
            let interval = EonMotorController.shared.adjustedInterval(base: baseInterval, motorId: "metacognition")
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Combined Pillar Worker
    // v3: Instead of 9 separate pillar loops (each with its own Task),
    // we use ONE loop that rotates through pillars, one at a time.
    // v5: Language-pelaren throttlad till max 1 gång per 60s (NLTagger → ANE-last).

    private var pillarRotationIndex: Int = 0
    private var lastLanguagePillarDate: Date = .distantPast

    private func combinedPillarWorker() async {
        try? await Task.sleep(nanoseconds: 8_000_000_000)

        let pillarWork: [(CognitivePillar, CognitiveDimension, () async -> Void)] = [
            (.causality,       .causality,           { await self.runCausalWork() }),
            (.knowledge,       .knowledge,            { await self.runKnowledgeWork() }),
            (.hypothesis,      .hypothesisGeneration,  { await self.runHypothesisWork() }),
            (.analogy,         .analogyBuilding,   { await self.runAnalogyWork() }),
            (.worldModel,      .worldModel,            { await self.runWorldModelWork() }),
            (.selfDevelopment, .selfAwareness,         { await self.runSelfDevelopmentWork() }),
            (.language,        .language,              { await self.runLanguageWork() }),
            (.globalWorkspace, .reasoning,             { await self.runGlobalWorkspaceWork() }),
            (.prediction,      .prediction,            { await self.runPredictionWork() }),
        ]

        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 10_000_000_000); continue }

            // D1: Global termisk broms
            if ThermalSleepManager.shared.shouldPauseWork() {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await Task.yield()
                continue
            }

            // Priority-based pillar selection: weaker dimensions get more attention
            // Score = (1 - dimensionLevel) * baseWeight + recencyPenalty
            let state = CognitiveState.shared
            let scored = pillarWork.map { (pillar, dim, work) -> (CognitivePillar, CognitiveDimension, () async -> Void, Double) in
                let level = state.dimensionLevel(dim)
                let need = 1.0 - level // How much this dimension needs work
                // Recency penalty: pillars that ran recently get lower priority
                let lastRun = pillarActivity[pillar] ?? 0
                let recencyBonus = lastRun < 0.3 ? 0.15 : 0 // Boost if hasn't run recently
                // C1: Language-pelaren throttlad — nollprioriteras om < 60s sedan senast
                let languageThrottle: Double = (pillar == .language && Date().timeIntervalSince(lastLanguagePillarDate) < 60) ? -999 : 0
                let priority = need * 1.5 + recencyBonus + Double.random(in: 0...0.1) + languageThrottle
                return (pillar, dim, work, priority)
            }
            let sorted = scored.sorted { $0.3 > $1.3 }
            let (pillar, _, work, _) = sorted.first!

            // Uppdatera Language-timestamp om vi kör Language-pelaren
            if pillar == .language { lastLanguagePillarDate = Date() }

            pillarRotationIndex += 1
            activePillars.insert(pillar)
            await Task.yield() // D3: ge systemet andrum
            await work()
            activePillars.remove(pillar)

            // Track pillar activity
            pillarActivity[pillar] = 1.0
            // Decay all pillar activity
            for key in pillarActivity.keys {
                pillarActivity[key] = (pillarActivity[key] ?? 0) * 0.85
            }

            // Feedback amplification every 9th rotation
            if pillarRotationIndex % 9 == 0 {
                await runFeedbackAmplification(brain: brain)
            }

            // Thermal-aware interval between pillar work: 15s nominal → 120s critical
            let thermalState = ProcessInfo.processInfo.thermalState
            let baseInterval: UInt64
            switch thermalState {
            case .nominal:  baseInterval = 15_000_000_000
            case .fair:     baseInterval = 30_000_000_000
            case .serious:  baseInterval = 90_000_000_000
            case .critical: baseInterval = 120_000_000_000
            @unknown default: baseInterval = 15_000_000_000
            }
            // v4.1: Motor speed multiplier for pillar work
            let interval = EonMotorController.shared.adjustedInterval(base: baseInterval, motorId: "pillars")
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Individual pillar work functions (called from combined worker)

    private func runCausalWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let causalityLevel = state.dimensionLevel(.causality)
        let topics = generateCausalTopics(level: causalityLevel)
        let topic = topics.randomElement() ?? "kognitiv utveckling"
        let depth = Int(state.dimensionLevel(.reasoning) * 5) + 2

        let result = await ReasoningEngine.shared.reason(about: topic, strategy: .causal, depth: depth)
        let gain = result.confidence * 0.005 // Reduced from 0.008
        await state.update(dimension: .causality, delta: gain, source: "causal_pillar")
        await state.update(dimension: .reasoning, delta: gain * 0.4, source: "causal_pillar")
        state.causalChainDepth = result.causalChain.count
        state.activeReasoningChain = result.causalChain

        brain.innerMonologue.append(MonologueLine(
            text: "⛓ KAUSAL[\(String(format: "%.2f", result.confidence))]: \(topic) → \(result.conclusion.prefix(70))...",
            type: .thought
        ))
    }

    private func generateCausalTopics(level: Double) -> [String] {
        if level < 0.4 {
            return ["Varför lär sig barn snabbare?", "Vad orsakar stress?", "Hur påverkar sömn minnet?"]
        } else if level < 0.7 {
            return ["Vad är den kausala kedjan bakom kognitiv bias?",
                    "Hur orsakar inlärning neuroplasticitet?",
                    "Vad driver emergent intelligens i komplexa system?"]
        } else {
            return ["Hur relaterar kausalitet till fri vilja?",
                    "Hur propagerar kausal kunskap genom ett semantiskt nätverk?"]
        }
    }

    private func runKnowledgeWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let learningResult = await LearningEngine.shared.runLearningCycle()
        let overallLevel = await LearningEngine.shared.overallCompetencyLevel()

        await state.update(dimension: .knowledge, delta: 0.004, source: "knowledge_pillar")
        await state.update(dimension: .learning, delta: 0.003, source: "knowledge_pillar")
        state.knowledgeFrontier = learningResult.studiedTopics
        state.consolidatedFacts += learningResult.studiedTopics.count

        brain.innerMonologue.append(MonologueLine(
            text: "📚 KUNSKAP[#\(learningResult.cycleNumber)]: kompetens \(String(format: "%.1f", overallLevel * 100))% · luckor: \(learningResult.gapsIdentified)",
            type: .thought
        ))

        // Knowledge synthesis
        if state.dimensionLevel(.knowledge) > 0.5 {
            let parallels = await synthesizeKnowledgeParallels()
            if let parallel = parallels {
                brain.innerMonologue.append(MonologueLine(text: "🔗 SYNTES: \(parallel)", type: .insight))
                await state.update(dimension: .analogyBuilding, delta: 0.003, source: "synthesis")
            }
        }
    }

    private func synthesizeKnowledgeParallels() async -> String? {
        let articles = await PersistentMemoryStore.shared.randomArticles(limit: 3)
        guard articles.count >= 2 else { return nil }
        let mem = PersistentMemoryStore.shared

        // Extract key concepts from each article using NLP
        var articleConcepts: [[String]] = []
        for article in articles {
            let facts = NLPFactExtractor.extract(from: article.content)
            let concepts = facts.flatMap { [$0.subject, $0.object] }
                .map { $0.lowercased() }
                .filter { $0.count > 3 }
            articleConcepts.append(concepts)
        }

        // Find concept bridges between articles from different domains
        for i in 0..<(articles.count - 1) {
            for j in (i + 1)..<articles.count {
                guard articles[i].domain != articles[j].domain else { continue }
                let concepts1 = Set(articleConcepts[i])
                let concepts2 = Set(articleConcepts[j])
                let shared = concepts1.intersection(concepts2)

                if shared.count >= 2 {
                    // Found a real concept bridge between different domains
                    let bridgeConcepts = shared.prefix(3).joined(separator: ", ")

                    // Save the bridge as a fact for future use
                    await mem.saveFact(
                        subject: articles[i].title,
                        predicate: "konceptbrygga",
                        object: "\(articles[j].title) via \(bridgeConcepts)",
                        confidence: min(0.85, 0.5 + Double(shared.count) * 0.1),
                        source: "knowledge_synthesis"
                    )

                    return "Konceptbrygga: '\(articles[i].title)' (\(articles[i].domain)) ↔ '\(articles[j].title)' (\(articles[j].domain)) via \(bridgeConcepts)"
                }
            }
        }

        // Fallback: simple word overlap
        let words1 = Set(articles[0].content.lowercased().split(separator: " ").map(String.init).filter { $0.count > 5 })
        let words2 = Set(articles[1].content.lowercased().split(separator: " ").map(String.init).filter { $0.count > 5 })
        let shared = words1.intersection(words2)
        guard !shared.isEmpty else { return nil }
        return "'\(articles[0].title)' och '\(articles[1].title)' delar: \(shared.prefix(3).joined(separator: ", "))"
    }

    private func runHypothesisWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let recentTitles = await PersistentMemoryStore.shared.recentArticleTitles(limit: 5)
        let hypothesis = HypothesisEngine.generate(
            articles: recentTitles, knowledgeCount: state.consolidatedFacts,
            stage: brain.developmentalStage, existingHypotheses: []
        )
        state.currentHypothesis = hypothesis.statement
        state.hypothesisConfidence = hypothesis.confidence

        let testResult = await HypothesisEngine.test(hypothesis: hypothesis)
        let gain: Double = testResult.supported ? 0.005 : 0.002
        await state.update(dimension: .hypothesisGeneration, delta: gain, source: "hypothesis_pillar")

        brain.innerMonologue.append(MonologueLine(
            text: testResult.supported
                ? "✅ HYPOTES[\(String(format: "%.0f", testResult.confidence * 100))%]: \(hypothesis.statement.prefix(60))"
                : "❌ AVVISAD: \(testResult.counterEvidence.prefix(60))",
            type: testResult.supported ? .insight : .revision
        ))
    }

    private func runAnalogyWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let topics = ["kognition och evolution", "inlärning och ekologi",
                      "kausalitet och tid", "kreativitet och mutation",
                      "världsmodell och karta"]
        let topic = topics.randomElement()!
        let parts = topic.split(separator: " och ").map(String.init)
        guard parts.count == 2 else { return }

        let result = await ReasoningEngine.shared.reason(about: "Vad har \(parts[0]) gemensamt med \(parts[1])?", strategy: .analogical, depth: 3)
        await state.update(dimension: .analogyBuilding, delta: 0.004, source: "analogy_pillar")
        await state.update(dimension: .creativity, delta: 0.003, source: "analogy_pillar")

        brain.innerMonologue.append(MonologueLine(
            text: "🔗 ANALOGI[\(String(format: "%.2f", result.confidence))]: \(topic) → \(result.conclusion.prefix(60))...",
            type: .insight
        ))
    }

    private func runWorldModelWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let recentFacts = await PersistentMemoryStore.shared.recentFacts(limit: 5)
        let causalLevel = state.dimensionLevel(.causality)
        state.causalGraphDensity = state.dimensionLevel(.worldModel) * 0.7 + causalLevel * 0.3
        state.newCausalLinks = Int(Double(recentFacts.count) * causalLevel)

        await state.update(dimension: .worldModel, delta: 0.004, source: "world_model_pillar")
        await state.update(dimension: .prediction, delta: 0.002, source: "world_model_pillar")

        let insights = ["Kausalstruktur förtätas", "Prediktiva mönster emergerar",
                       "Faktanätverk expanderar", "Kausala kedjor fördjupas"]
        brain.innerMonologue.append(MonologueLine(
            text: "🌍 VÄRLDSMODELL[\(String(format: "%.2f", state.dimensionLevel(.worldModel)))]: \(insights.randomElement()!)",
            type: .insight
        ))
    }

    private func runSelfDevelopmentWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let selfModel = EonSelfModel()
        let reflections = SelfReflectionEngine.generate(
            selfModel: selfModel, stage: brain.developmentalStage,
            phi: brain.phiValue, conversations: brain.conversationCount,
            version: brain.loraVersion
        )
        for reflection in reflections.prefix(1) {
            brain.innerMonologue.append(MonologueLine(text: "🪞 \(reflection)", type: .thought))
        }
        await state.update(dimension: .selfAwareness, delta: 0.004, source: "self_development")
        await state.update(dimension: .metacognition, delta: 0.002, source: "self_development")
    }

    private func runLanguageWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let experiment = LanguageExperimentEngine.generate(stage: brain.developmentalStage, existingExperiments: [])

        // Run the experiment through SwedishLanguageCore for deeper analysis
        let analysis = await SwedishLanguageCore.shared.analyze(experiment.testSentence)
        let morphCount = analysis.morphemes.filter { $0.pos != "unknown" }.count
        let totalCount = max(1, analysis.morphemes.count)
        let recognitionRate = Double(morphCount) / Double(totalCount)

        brain.innerMonologue.append(MonologueLine(
            text: "🗣 SPRÅK[\(String(format: "%.2f", state.dimensionLevel(.language)))]: \(experiment.rule) '\(experiment.baseWord)' → '\(experiment.derivedForm)' · Igenkänning: \(String(format: "%.0f", recognitionRate * 100))%",
            type: .thought
        ))

        // Scale cognitive gains by actual morphological recognition quality
        let langGain = 0.002 + recognitionRate * 0.002
        await state.update(dimension: .language, delta: langGain, source: "language_pillar")
        await state.update(dimension: .comprehension, delta: 0.002, source: "language_pillar")
        await state.update(dimension: .communication, delta: 0.002, source: "language_pillar")

        // If idioms were detected, boost comprehension further
        if !analysis.detectedIdioms.isEmpty {
            brain.innerMonologue.append(MonologueLine(
                text: "🗣 Idiom: '\(analysis.detectedIdioms.first!.phrase)' = \(analysis.detectedIdioms.first!.meaning)",
                type: .insight
            ))
            await state.update(dimension: .comprehension, delta: 0.003, source: "idiom_detection")
        }
    }

    private func runGlobalWorkspaceWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        if let lastThought = brain.innerMonologue.last {
            await GlobalWorkspaceEngine.shared.addThoughtFromText(lastThought.text, source: "ica", priority: state.dimensionLevel(.reasoning))
            await GlobalWorkspaceEngine.shared.runCompetition()
            let integrationLevel = await GlobalWorkspaceEngine.shared.integrationLevel
            state.broadcastStrength = integrationLevel
            state.competingThoughts = await GlobalWorkspaceEngine.shared.thoughtCount
            if let focus = await GlobalWorkspaceEngine.shared.currentFocus {
                state.attentionFocus = String(focus.content.prefix(60))
                await state.update(dimension: .comprehension, delta: integrationLevel * 0.001, source: "gwt")
            }
        }
    }

    private func runPredictionWork() async {
        guard let brain else { return }
        let state = CognitiveState.shared
        let strength = (state.dimensionLevel(.worldModel) + state.dimensionLevel(.causality)) / 2.0
        let ii = state.integratedIntelligence
        let velocity = state.growthVelocity
        let projectedII = ii + velocity * 60.0

        let prediction = strength > 0.7
            ? "Tillväxt \(String(format: "%.5f", velocity))/min → II=\(String(format: "%.3f", projectedII)) om 60 min"
            : "Begränsad prediktion (styrka: \(String(format: "%.2f", strength))). Stärk världsmodell."

        brain.innerMonologue.append(MonologueLine(text: "🔮 PREDIKTION[\(String(format: "%.0f", strength * 100))%]: \(prediction)", type: .insight))
        await state.update(dimension: .prediction, delta: 0.003, source: "prediction_pillar")
    }

    // MARK: - Feedback Amplification (called after full pillar rotation)
    // v3: Reduced boost values to prevent metric inflation

    private func runFeedbackAmplification(brain: EonBrain) async {
        let state = CognitiveState.shared
        let ii = state.integratedIntelligence
        guard ii < 0.85 else { return }

        let loops = state.feedbackLoops
        var amplified = 0
        var suppressedNegative = 0

        for loop in loops {
            let levels = loop.dimensions.compactMap { state.dimensionLevel($0) }
            let minLevel = levels.min() ?? 0
            let avgLevel = levels.reduce(0, +) / Double(levels.count)

            if loop.type == .positive {
                guard minLevel > 0.6 else { continue }
                let boost = loop.strength * 0.001 * (avgLevel - 0.6)
                for dim in loop.dimensions {
                    await state.update(dimension: dim, delta: boost, source: "feedback_amplifier")
                }
                amplified += 1
            } else if loop.type == .negative {
                // Negative feedback loops: identify and counteract
                // If a dimension is stagnating while others grow, give it a targeted boost
                if let weakestDim = loop.dimensions.min(by: { state.dimensionLevel($0) < state.dimensionLevel($1) }) {
                    let weakestLevel = state.dimensionLevel(weakestDim)
                    if weakestLevel < avgLevel - 0.15 { // Significant gap
                        let compensationBoost = loop.strength * 0.002 * (avgLevel - weakestLevel)
                        await state.update(dimension: weakestDim, delta: compensationBoost, source: "negative_loop_compensation")
                        suppressedNegative += 1
                    }
                }
            }
        }

        if amplified > 0 || suppressedNegative > 0 {
            brain.innerMonologue.append(MonologueLine(
                text: "🔄 FEEDBACK: \(amplified) positiva, \(suppressedNegative) kompenserade · II=\(String(format: "%.4f", ii)) · v=\(String(format: "%.6f", state.growthVelocity))/min",
                type: .loopTrigger
            ))
        }
    }
}

// MARK: - Supporting Types

enum CognitivePillar: String, CaseIterable, Hashable {
    case metacognition  = "metacognition"
    case gapEngine      = "gap_engine"
    case causality      = "causality"
    case knowledge      = "knowledge"
    case hypothesis     = "hypothesis"
    case analogy        = "analogy"
    case worldModel     = "world_model"
    case selfDevelopment = "self_development"
    case language       = "language"
    case globalWorkspace = "global_workspace"
    case prediction     = "prediction"
    case reasoning      = "reasoning"

    var primaryDimension: CognitiveDimension {
        switch self {
        case .metacognition:   return .metacognition
        case .gapEngine:       return .adaptivity
        case .causality:       return .causality
        case .knowledge:       return .knowledge
        case .hypothesis:      return .hypothesisGeneration
        case .analogy:         return .analogyBuilding
        case .worldModel:      return .worldModel
        case .selfDevelopment: return .selfAwareness
        case .language:        return .language
        case .globalWorkspace: return .comprehension
        case .prediction:      return .prediction
        case .reasoning:       return .reasoning
        }
    }

    var displayName: String {
        switch self {
        case .metacognition:   return "Metakognition"
        case .gapEngine:       return "Gap-motor"
        case .causality:       return "Kausalitet"
        case .knowledge:       return "Kunskap"
        case .hypothesis:      return "Hypoteser"
        case .analogy:         return "Analogier"
        case .worldModel:      return "Världsmodell"
        case .selfDevelopment: return "Självutveckling"
        case .language:        return "Språk"
        case .globalWorkspace: return "Global Workspace"
        case .prediction:      return "Prediktion"
        case .reasoning:       return "Resonemang"
        }
    }
}

struct CognitiveEvent: Identifiable {
    let id = UUID()
    let type: EventType
    let source: CognitivePillar
    let target: CognitivePillar
    let payload: String
    let priority: EventPriority
    let timestamp: Date = Date()

    enum EventType {
        case gapIdentified, pillarActivated, stagnationDetected,
             hypothesisGenerated, analogyFound, knowledgeAcquired,
             biasDetected, breakthroughAchieved
    }

    enum EventPriority { case low, medium, high }
}

struct PillarInteraction: Identifiable {
    let id = UUID()
    let from: CognitivePillar
    let to: CognitivePillar
    let type: CognitiveEvent.EventType
    let strength: Double
    let timestamp: Date = Date()
}

// MARK: - CognitiveDimension → Pillar mapping

extension CognitiveDimension {
    var pillar: CognitivePillar {
        switch self {
        case .metacognition:        return .metacognition
        case .causality:            return .causality
        case .knowledge, .learning: return .knowledge
        case .hypothesisGeneration: return .hypothesis
        case .analogyBuilding:      return .analogy
        case .worldModel:           return .worldModel
        case .selfAwareness:        return .selfDevelopment
        case .language, .communication, .comprehension: return .language
        case .prediction:           return .prediction
        case .reasoning:            return .reasoning
        default:                    return .metacognition
        }
    }
}
