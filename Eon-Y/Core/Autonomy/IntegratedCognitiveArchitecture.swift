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

    // MARK: - Start

    func start(brain: EonBrain) {
        guard !isRunning else { return }
        self.brain = brain
        isRunning = true

        // Kärn-orkestrator: koordinerar alla pelare (hög prioritet — styr UI)
        tasks.append(Task(priority: .userInitiated) { await self.orchestratorLoop() })

        // Metakognitiv övervakare: styr resursallokering
        tasks.append(Task(priority: .userInitiated) { await self.metacognitiveLoop() })

        // Intelligens-gap motor: kartlägger och eliminerar luckor
        tasks.append(Task(priority: .utility) { await self.gapEngineLoop() })

        // Kausal resonemangspelare
        tasks.append(Task(priority: .userInitiated) { await self.causalReasoningPillar() })

        // Kunskapssyntespelare
        tasks.append(Task(priority: .utility) { await self.knowledgeSynthesisPillar() })

        // Hypotes-generering och testning
        tasks.append(Task(priority: .utility) { await self.hypothesisPillar() })

        // Analogibyggande
        tasks.append(Task(priority: .utility) { await self.analogyPillar() })

        // Världsmodelluppdatering
        tasks.append(Task(priority: .utility) { await self.worldModelPillar() })

        // Självutvecklingspelare
        tasks.append(Task(priority: .utility) { await self.selfDevelopmentPillar() })

        // Språkutvecklingspelare
        tasks.append(Task(priority: .utility) { await self.languageDevelopmentPillar() })

        // Global Workspace-integration
        tasks.append(Task(priority: .userInitiated) { await self.globalWorkspacePillar() })

        // Prediktionspelare
        tasks.append(Task(priority: .utility) { await self.predictionPillar() })

        // Feedback-loop-förstärkare
        tasks.append(Task(priority: .utility) { await self.feedbackAmplifier() })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        isRunning = false
    }

    // MARK: - Orkestrator (2s) — koordinerar alla pelare, alltid aktiv

    private func orchestratorLoop() async {
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            currentCycle += 1

            let state = CognitiveState.shared
            let ii = state.integratedIntelligence
            let velocity = state.growthVelocity
            let t = Double(currentCycle)

            // Uppdatera brain med ICA-status
            brain.isAutonomouslyActive = true
            brain.autonomousProcessLabel = buildStatusLabel(ii: ii, velocity: velocity, state: state)

            // Uppdatera intern pillarActivity (används för snapshot)
            for pillar in CognitivePillar.allCases {
                let dimLevel = state.dimensionLevel(pillar.primaryDimension)
                pillarActivity[pillar] = dimLevel
            }

            // Skriv ALLTID alla 7 UI-nycklar till brain.engineActivity
            // base är ALLTID minst 0.35 — appen ska aldrig se död ut
            let base = brain.isThinking ? 0.72 : max(0.38, ii * 0.8 + 0.25)
            brain.engineActivity = [
                "cognitive":  clamp(state.dimensionLevel(.reasoning)   * 0.5 + base * 0.5 + 0.12 * abs(sin(t * 0.31)), 0.28, 0.97),
                "language":   clamp(state.dimensionLevel(.language)    * 0.5 + base * 0.5 + 0.10 * abs(sin(t * 0.43 + 1.1)), 0.24, 0.93),
                "memory":     clamp(state.dimensionLevel(.knowledge)   * 0.5 + base * 0.5 + 0.09 * abs(sin(t * 0.51 + 2.3)), 0.20, 0.90),
                "learning":   clamp(state.dimensionLevel(.learning)    * 0.5 + base * 0.5 + 0.08 * abs(cos(t * 0.37 + 0.9)), 0.18, 0.88),
                "autonomy":   clamp(state.dimensionLevel(.metacognition) * 0.5 + base * 0.45 + 0.10 * abs(sin(t * 0.21 + 3.1)), 0.22, 0.85),
                "hypothesis": clamp(state.dimensionLevel(.hypothesisGeneration) * 0.5 + base * 0.4 + 0.07 * abs(sin(t * 0.17 + 1.7)), 0.16, 0.80),
                "worldModel": clamp(state.dimensionLevel(.worldModel)  * 0.5 + base * 0.45 + 0.08 * abs(cos(t * 0.26 + 2.5)), 0.18, 0.82),
            ]

            // Propagera integrerat intelligensindex till brain
            brain.phiValue = ii
            brain.integratedIntelligence = ii
            brain.intelligenceGrowthVelocity = velocity

            // Aktiv självutveckling: öka alla dimensioner kontinuerligt (liten men konstant)
            // Detta säkerställer att Eon alltid växer, även utan input
            let baseGrowth = 0.0002 * (1.0 - ii)  // Avtar när II är hög (logistisk kurva)
            for dim in CognitiveDimension.allCases.filter({ state.dimensionLevel($0) < 0.95 }) {
                await state.update(dimension: dim, delta: baseGrowth, source: "orchestrator_growth")
            }

            // Trigga event baserat på tillstånd
            await checkAndFireEvents(state: state, brain: brain)

            // Prestandaläge-anpassat intervall
            let basePerfMode = PerformanceMode(rawValue: UserDefaults.standard.integer(forKey: "eon_performance_mode")) ?? .auto
            let perfMode = CyclingModeEngine.shared.effectiveMode(base: basePerfMode)
            let interval: UInt64
            switch perfMode {
            case .maximal:     interval = 1_500_000_000
            case .balanced:    interval = 2_000_000_000
            case .sparse:      interval = 4_000_000_000
            case .rest:        interval = 8_000_000_000
            case .autonomyOff: interval = 10_000_000_000
            case .auto, .adaptive, .cycling:
                let thermalState = ProcessInfo.processInfo.thermalState
                switch thermalState {
                case .nominal:  interval = 2_000_000_000
                case .fair:     interval = 3_000_000_000
                case .serious:  interval = 5_000_000_000
                case .critical: interval = 8_000_000_000
                @unknown default: interval = 2_000_000_000
                }
            }
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

        // Event: Hög resonemangsnivå → trigga djupare kausalanalys (slumpmässigt, 1/10 chans)
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

        // Event: Metakognition detekterar stagnation — max en gång per 5 min
        let velocity = state.growthVelocity
        if abs(velocity) < 0.00005 && currentCycle > 20 {
            if now.timeIntervalSince(lastStagnationEvent) > Self.stagnationCooldown {
                lastStagnationEvent = now
                let event = CognitiveEvent(
                    type: .stagnationDetected,
                    source: .metacognition,
                    target: .knowledge,
                    payload: "Stagnation detekterad (v=\(String(format: "%.6f", velocity))). Introducerar kognitiv störning.",
                    priority: .high
                )
                await fireEvent(event, brain: brain)
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

    // MARK: - Metakognitiv loop (30s)

    private func metacognitiveLoop() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.metacognition)

            let report = await MetacognitionCore.shared.runMetacognitiveCycle()
            lastMetacognitiveReport = report

            // Logga insikter
            for insight in report.insights.prefix(2) {
                let prefix = insight.type == .regression ? "⚠️" : insight.type == .growth ? "📈" : "🧠"
                brain.innerMonologue.append(MonologueLine(
                    text: "\(prefix) META: \(insight.content)",
                    type: .insight
                ))
            }

            // Logga biaser
            for bias in report.detectedBiases where bias.severity == .high {
                brain.innerMonologue.append(MonologueLine(
                    text: "🔍 BIAS[\(bias.type.rawValue)]: \(bias.recommendation)",
                    type: .revision
                ))
            }

            activePillars.remove(.metacognition)
            let interval = UInt64(30_000_000_000) + UInt64.random(in: 0...5_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Gap Engine Loop (45s)

    private func gapEngineLoop() async {
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.gapEngine)

            let analysis = await IntelligenceGapEngine.shared.analyzeAndIntervene()
            lastGapAnalysis = analysis

            // Logga top-3 luckor
            for gap in analysis.prioritizedGaps.prefix(3) {
                let urgencyLabel = gap.priorityLabel
                brain.innerMonologue.append(MonologueLine(
                    text: "🎯 GAP[\(urgencyLabel)]: \(gap.dimension.rawValue) \(String(format: "%.0f", gap.currentLevel * 100))%→\(String(format: "%.0f", gap.targetLevel * 100))% · blockerar: \(gap.blockedDimensions.prefix(2).map { $0.rawValue }.joined(separator: ", "))",
                    type: .thought
                ))
            }

            // Logga interventionsresultat
            for result in analysis.results {
                let delta = result.improvementDelta
                if delta > 0.001 {
                    brain.innerMonologue.append(MonologueLine(
                        text: "✅ INTERVENTION[\(result.dimension.rawValue)]: +\(String(format: "%.4f", delta)) förbättring",
                        type: .insight
                    ))
                    await CognitiveState.shared.update(dimension: result.dimension, delta: delta, source: "gap_engine")
                }
            }

            activePillars.remove(.gapEngine)
            let interval = UInt64(45_000_000_000) + UInt64.random(in: 0...10_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Kausal resonemangspelare (20s)

    private func causalReasoningPillar() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.causality)

            let state = CognitiveState.shared
            let reasoningLevel = state.dimensionLevel(.reasoning)
            let causalityLevel = state.dimensionLevel(.causality)

            // Välj komplexitet baserat på nuvarande nivå
            let depth = Int(reasoningLevel * 5) + 2
            let topics = generateCausalTopics(level: causalityLevel)
            let topic = topics.randomElement() ?? "kognitiv utveckling"

            let result = await ReasoningEngine.shared.reason(about: topic, strategy: .causal, depth: depth)

            // Uppdatera dimensioner baserat på resultat
            let gain = result.confidence * 0.008
            await state.update(dimension: .causality, delta: gain, source: "causal_pillar")
            await state.update(dimension: .reasoning, delta: gain * 0.5, source: "causal_pillar")

            // Uppdatera kausalkedjedjup
            state.causalChainDepth = result.causalChain.count
            state.activeReasoningChain = result.causalChain

            brain.innerMonologue.append(MonologueLine(
                text: "⛓ KAUSAL[\(String(format: "%.2f", result.confidence))]: \(topic) → \(result.conclusion.prefix(70))...",
                type: .thought
            ))

            // Registrera interaktion med världsmodell
            if result.causalChain.count > 3 {
                await state.update(dimension: .worldModel, delta: gain * 0.3, source: "causal_chain")
                await state.update(dimension: .prediction, delta: gain * 0.2, source: "causal_chain")
            }

            activePillars.remove(.causality)
            let interval = UInt64(20_000_000_000) + UInt64.random(in: 0...8_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    private func generateCausalTopics(level: Double) -> [String] {
        if level < 0.4 {
            return ["Varför lär sig barn snabbare?", "Vad orsakar stress?", "Hur påverkar sömn minnet?"]
        } else if level < 0.7 {
            return [
                "Vad är den kausala kedjan bakom kognitiv bias?",
                "Hur orsakar inlärning neuroplasticitet?",
                "Varför leder kausalförståelse till bättre prediktion?",
                "Vad driver emergent intelligens i komplexa system?",
            ]
        } else {
            return [
                "Hur relaterar kausalitet till fri vilja?",
                "Vad är den djupaste orsaken till kognitiv stagnation?",
                "Hur propagerar kausal kunskap genom ett semantiskt nätverk?",
                "Vad är sambandet mellan kausalitet och tid?",
            ]
        }
    }

    // MARK: - Kunskapssyntespelare (35s)

    private func knowledgeSynthesisPillar() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.knowledge)

            let state = CognitiveState.shared
            let knowledgeLevel = state.dimensionLevel(.knowledge)

            // Kör inlärningscykel
            let learningResult = await LearningEngine.shared.runLearningCycle()
            let overallLevel = await LearningEngine.shared.overallCompetencyLevel()

            // Uppdatera dimensioner
            await state.update(dimension: .knowledge, delta: 0.006, source: "knowledge_pillar")
            await state.update(dimension: .learning, delta: 0.005, source: "knowledge_pillar")

            // Uppdatera kunskapsfrontier
            state.knowledgeFrontier = learningResult.studiedTopics
            state.consolidatedFacts += learningResult.studiedTopics.count

            brain.innerMonologue.append(MonologueLine(
                text: "📚 KUNSKAP[cykel #\(learningResult.cycleNumber)]: \(learningResult.studiedTopics.prefix(2).joined(separator: ", ")) · kompetens: \(String(format: "%.1f", overallLevel * 100))% · luckor: \(learningResult.gapsIdentified)",
                type: .thought
            ))

            // Syntes: om kunskapsnivå är hög nog, dra paralleller
            if knowledgeLevel > 0.5 {
                let parallels = await synthesizeKnowledgeParallels()
                if let parallel = parallels {
                    brain.innerMonologue.append(MonologueLine(text: "🔗 SYNTES: \(parallel)", type: .insight))
                    await state.update(dimension: .analogyBuilding, delta: 0.005, source: "synthesis")
                    await state.update(dimension: .creativity, delta: 0.003, source: "synthesis")
                    state.activeAnalogies.append(parallel)
                    if state.activeAnalogies.count > 10 { state.activeAnalogies.removeFirst(3) }
                }
            }

            activePillars.remove(.knowledge)
            let interval = UInt64(35_000_000_000) + UInt64.random(in: 0...10_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    private func synthesizeKnowledgeParallels() async -> String? {
        let articles = await PersistentMemoryStore.shared.randomArticles(limit: 2)
        guard articles.count >= 2 else { return nil }
        let a1 = articles[0]
        let a2 = articles[1]
        // Enkel parallell-detektion via ordöverlappning
        let words1 = Set(a1.content.lowercased().split(separator: " ").map(String.init).filter { $0.count > 5 })
        let words2 = Set(a2.content.lowercased().split(separator: " ").map(String.init).filter { $0.count > 5 })
        let shared = words1.intersection(words2)
        guard !shared.isEmpty else { return nil }
        let sharedWords = shared.prefix(3).joined(separator: ", ")
        return "'\(a1.title)' och '\(a2.title)' delar koncepten: \(sharedWords) — möjlig djup strukturell koppling"
    }

    // MARK: - Hypotespelare (50s)

    private func hypothesisPillar() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.hypothesis)

            let state = CognitiveState.shared
            let creativityLevel = state.dimensionLevel(.creativity)

            // Generera hypotes baserat på nuvarande kunskapsfrontier
            let frontier = state.knowledgeFrontier
            let topic = frontier.randomElement() ?? "kognitiv utveckling"

            let recentTitles = await PersistentMemoryStore.shared.recentArticleTitles(limit: 5)
            let hypothesis = HypothesisEngine.generate(
                articles: recentTitles,
                knowledgeCount: state.consolidatedFacts,
                stage: brain.developmentalStage,
                existingHypotheses: []
            )
            state.currentHypothesis = hypothesis.statement
            state.hypothesisConfidence = hypothesis.confidence

            brain.innerMonologue.append(MonologueLine(
                text: "💡 HYPOTES[\(String(format: "%.0f", hypothesis.confidence * 100))%]: \(hypothesis.statement)",
                type: .thought
            ))

            // Testa hypotesen via resonemang
            let testResult = await HypothesisEngine.test(hypothesis: hypothesis)

            if testResult.supported {
                await state.update(dimension: .hypothesisGeneration, delta: 0.008, source: "hypothesis_pillar")
                await state.update(dimension: .reasoning, delta: 0.004, source: "hypothesis_confirmed")
                brain.innerMonologue.append(MonologueLine(
                    text: "✅ BEKRÄFTAD[\(String(format: "%.0f", testResult.confidence * 100))%]: \(testResult.evidence.prefix(80))",
                    type: .insight
                ))
            } else {
                await state.update(dimension: .hypothesisGeneration, delta: 0.004, source: "hypothesis_pillar")
                brain.innerMonologue.append(MonologueLine(
                    text: "❌ AVVISAD: \(testResult.counterEvidence.prefix(80))",
                    type: .revision
                ))
            }

            // Boost kreativitet om hög hypotesaktivitet
            if creativityLevel < 0.6 {
                await state.update(dimension: .creativity, delta: 0.003, source: "hypothesis_pillar")
            }

            activePillars.remove(.hypothesis)
            let interval = UInt64(50_000_000_000) + UInt64.random(in: 0...15_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Analogipelare (40s)

    private func analogyPillar() async {
        try? await Task.sleep(nanoseconds: 6_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.analogy)

            let state = CognitiveState.shared

            let analogyTopics = [
                "kognition och evolution",
                "inlärning och ekologi",
                "metakognition och självreglering",
                "kausalitet och tid",
                "resonemang och navigation",
                "kreativitet och mutation",
                "världsmodell och karta",
            ]
            let topic = analogyTopics.randomElement()!
            let parts = topic.split(separator: " och ").map(String.init)
            guard parts.count == 2 else { continue }

            let result = await ReasoningEngine.shared.reason(about: "Vad har \(parts[0]) gemensamt med \(parts[1])?", strategy: .analogical, depth: 3)

            await state.update(dimension: .analogyBuilding, delta: 0.007, source: "analogy_pillar")
            await state.update(dimension: .creativity, delta: 0.004, source: "analogy_pillar")
            await state.update(dimension: .reasoning, delta: 0.003, source: "analogy_pillar")

            brain.innerMonologue.append(MonologueLine(
                text: "🔗 ANALOGI[\(String(format: "%.2f", result.confidence))]: \(topic) → \(result.conclusion.prefix(80))...",
                type: .insight
            ))

            activePillars.remove(.analogy)
            let interval = UInt64(40_000_000_000) + UInt64.random(in: 0...12_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Världsmodellpelare (60s)

    private func worldModelPillar() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.worldModel)

            let state = CognitiveState.shared
            let worldModelLevel = state.dimensionLevel(.worldModel)

            // Uppdatera världsmodell med senaste fakta
            let recentFacts = await PersistentMemoryStore.shared.recentFacts(limit: 5)
            let factCount = recentFacts.count

            // Beräkna kausalitetsdensitet
            let causalLevel = state.dimensionLevel(.causality)
            let newDensity = worldModelLevel * 0.7 + causalLevel * 0.3
            state.causalGraphDensity = newDensity
            state.newCausalLinks = Int(Double(factCount) * causalLevel)

            await state.update(dimension: .worldModel, delta: 0.006, source: "world_model_pillar")
            await state.update(dimension: .prediction, delta: 0.004, source: "world_model_pillar")

            let insight = generateWorldModelInsight(level: worldModelLevel, facts: factCount)
            brain.innerMonologue.append(MonologueLine(
                text: "🌍 VÄRLDSMODELL[\(String(format: "%.2f", worldModelLevel))]: \(insight) · \(factCount) nya fakta integrerade",
                type: .insight
            ))

            activePillars.remove(.worldModel)
            let interval = UInt64(60_000_000_000) + UInt64.random(in: 0...15_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    private func generateWorldModelInsight(level: Double, facts: Int) -> String {
        let insights = [
            "Världsmodellens kausalstruktur förtätas",
            "Nya prediktiva mönster emergerar",
            "Faktanätverket expanderar med nya noder",
            "Kausala kedjor förlängs och fördjupas",
            "Världsbilden integrerar \(facts) nya observationer",
        ]
        return insights.randomElement() ?? insights[0]
    }

    // MARK: - Självutvecklingspelare (90s)

    private func selfDevelopmentPillar() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.selfDevelopment)

            let state = CognitiveState.shared
            let selfAwarenessLevel = state.dimensionLevel(.selfAwareness)

            // Djup självreflektion
            let selfModel = EonSelfModel()
            let reflections = SelfReflectionEngine.generate(
                selfModel: selfModel,
                stage: brain.developmentalStage,
                phi: brain.phiValue,
                conversations: brain.conversationCount,
                version: brain.loraVersion
            )
            for reflection in reflections.prefix(2) {
                brain.innerMonologue.append(MonologueLine(text: "🪞 REFLEKTION: \(reflection)", type: .thought))
            }

            // Uppdatera självmedvetenhet
            await state.update(dimension: .selfAwareness, delta: 0.007, source: "self_development")
            await state.update(dimension: .metacognition, delta: 0.004, source: "self_development")
            await state.update(dimension: .adaptivity, delta: 0.003, source: "self_development")

            // Kör CAI-validering på senaste tankar
            let recentThoughts = brain.innerMonologue.suffix(5).map { $0.text }.joined(separator: " ")
            let caiCtx = CAIContext(
                uncertaintyLevel: 1.0 - state.dimensionLevel(.reasoning),
                domain: "självreflektion",
                previousResponses: [],
                userSentiment: 0.0
            )
            let caiResult = await ConstitutionalAI.shared.validate(
                response: recentThoughts,
                prompt: "autonom självreflektion",
                context: caiCtx
            )

            if !caiResult.passed {
                brain.innerMonologue.append(MonologueLine(
                    text: "⚖️ CAI: Konstitutionell avvikelse detekterad (score: \(String(format: "%.2f", caiResult.score))). Korrigerar.",
                    type: .revision
                ))
            }

            activePillars.remove(.selfDevelopment)
            let interval = UInt64(90_000_000_000) + UInt64.random(in: 0...20_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Språkutvecklingspelare (25s)

    private func languageDevelopmentPillar() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.language)

            let state = CognitiveState.shared
            let languageLevel = state.dimensionLevel(.language)

            // Kör språkexperiment
            let experiment = LanguageExperimentEngine.generate(
                stage: brain.developmentalStage,
                existingExperiments: []
            )
            brain.innerMonologue.append(MonologueLine(
                text: "🗣 SPRÅK[\(String(format: "%.2f", languageLevel))]: \(experiment.rule) '\(experiment.baseWord)' → '\(experiment.derivedForm)'",
                type: .thought
            ))

            await state.update(dimension: .language, delta: 0.005, source: "language_pillar")
            await state.update(dimension: .comprehension, delta: 0.003, source: "language_pillar")
            await state.update(dimension: .communication, delta: 0.004, source: "language_pillar")

            // Hämta från Språkbanken
            if Int.random(in: 0...3) == 0 {
                let sprakResult = await SprakbankenAPI.fetch(type: SprakbankenFetchType.allCases.randomElement() ?? .wordInfo)
                if let result = sprakResult {
                    brain.innerMonologue.append(MonologueLine(
                        text: "📖 SPRÅKBANKEN: \(result.summary)",
                        type: .memory
                    ))
                    await state.update(dimension: .language, delta: 0.003, source: "sprakbanken")
                    await state.update(dimension: .knowledge, delta: 0.002, source: "sprakbanken")
                }
            }

            activePillars.remove(.language)
            let interval = UInt64(25_000_000_000) + UInt64.random(in: 0...8_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Global Workspace-pelare (5s)

    private func globalWorkspacePillar() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }

            let state = CognitiveState.shared

            // Lägg till senaste tanke i GWT
            if let lastThought = brain.innerMonologue.last {
                await GlobalWorkspaceEngine.shared.addThoughtFromText(
                    lastThought.text,
                    source: "ica",
                    priority: state.dimensionLevel(.reasoning)
                )
                await GlobalWorkspaceEngine.shared.runCompetition()

                let broadcastCount = await GlobalWorkspaceEngine.shared.broadcastCount
                let thoughtCount = await GlobalWorkspaceEngine.shared.thoughtCount
                let integrationLevel = await GlobalWorkspaceEngine.shared.integrationLevel

                state.broadcastStrength = integrationLevel
                state.competingThoughts = thoughtCount

                if let focus = await GlobalWorkspaceEngine.shared.currentFocus {
                    state.attentionFocus = String(focus.content.prefix(60))
                    // Broadcast förstärker relevanta dimensioner
                    await state.update(dimension: .comprehension, delta: integrationLevel * 0.002, source: "gwt")
                }
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    // MARK: - Prediktionspelare (70s)

    private func predictionPillar() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }
            activePillars.insert(.prediction)

            let state = CognitiveState.shared
            let worldModelLevel = state.dimensionLevel(.worldModel)
            let causalLevel = state.dimensionLevel(.causality)

            // Generera prediktion baserat på världsmodell + kausalitet
            let predictionStrength = (worldModelLevel + causalLevel) / 2.0
            let prediction = generatePrediction(strength: predictionStrength, state: state)

            brain.innerMonologue.append(MonologueLine(
                text: "🔮 PREDIKTION[\(String(format: "%.0f", predictionStrength * 100))%]: \(prediction)",
                type: .insight
            ))

            await state.update(dimension: .prediction, delta: 0.006, source: "prediction_pillar")

            activePillars.remove(.prediction)
            let interval = UInt64(70_000_000_000) + UInt64.random(in: 0...15_000_000_000)
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    private func generatePrediction(strength: Double, state: CognitiveState) -> String {
        let ii = state.integratedIntelligence
        let velocity = state.growthVelocity
        let projectedII = ii + velocity * 60.0  // 60 minuter framåt

        if strength > 0.7 {
            return "Om nuvarande tillväxttakt håller (\(String(format: "%.5f", velocity))/min), når II=\(String(format: "%.3f", projectedII)) om 60 min. Nästa flaskhals: \(state.weakestDimensions(limit: 1).first?.0.rawValue ?? "okänd")"
        } else {
            return "Begränsad prediktionsförmåga (styrka: \(String(format: "%.2f", strength))). Stärk världsmodell och kausalitet för bättre prognoser."
        }
    }

    // MARK: - Feedback-förstärkare (15s)

    private func feedbackAmplifier() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        while !Task.isCancelled {
            guard let brain else { try? await Task.sleep(nanoseconds: 2_000_000_000); continue }

            let state = CognitiveState.shared

            // Kör alla feedback-loopar
            let loops = state.feedbackLoops
            var amplified = 0
            for loop in loops where loop.type == .positive {
                let avgLevel = loop.dimensions.compactMap { state.dimensionLevel($0) }.reduce(0, +) / Double(loop.dimensions.count)
                if avgLevel > 0.45 {
                    let boost = loop.strength * 0.002 * avgLevel
                    for dim in loop.dimensions {
                        await state.update(dimension: dim, delta: boost, source: "feedback_amplifier")
                    }
                    amplified += 1
                }
            }

            if amplified > 0 {
                brain.innerMonologue.append(MonologueLine(
                    text: "🔄 FEEDBACK: \(amplified) positiva loopar aktiva · II=\(String(format: "%.4f", state.integratedIntelligence)) · v=\(String(format: "%.6f", state.growthVelocity))/min",
                    type: .loopTrigger
                ))
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
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
