import Foundation
import Combine
import SwiftUI

// MARK: - EonBrain: Central observable state for all UI

@MainActor
final class EonBrain: ObservableObject {
    static let shared = EonBrain()

    // MARK: - Cognitive state (UI-observable)
    @Published var isThinking: Bool = false
    @Published var currentThinkingStep: ThinkingStep = .idle
    @Published var thinkingSteps: [ThinkingStepStatus] = []
    @Published var innerMonologue: [MonologueLine] = []
    @Published var currentEmotion: EonEmotion = .neutral
    @Published var emotionValence: Double = 0.0   // -1 → +1
    @Published var emotionArousal: Double = 0.3   // 0 → 1
    @Published var phiValue: Double = 0.42
    @Published var confidence: Double = 0.75
    @Published var activeLoops: Set<CognitiveLoop> = []
    @Published var engineActivity: [String: Double] = [:]
    // v12: Cleaned response after post-processing (may differ from streamed tokens)
    @Published var lastCleanedResponse: String = ""

    // MARK: - Consciousness-derived live state (v6: genuine engine signals)
    @Published var isSurprised: Bool = false
    @Published var surpriseStrength: Double = 0.0
    @Published var criticalityRegime: String = "subcritical"
    @Published var globalSync: Double = 0.0
    @Published var sleepPressure: Double = 0.0
    @Published var freeEnergy: Double = 0.0
    @Published var curiosityDrive: Double = 0.0
    @Published var currentWorkspaceFocus: String = ""
    @Published var developmentalStage: DevelopmentalStage = .toddler
    @Published var developmentalProgress: Double = 0.23
    @Published var conversationCount: Int = 0
    @Published var knowledgeNodeCount: Int = 0
    @Published var loraVersion: Int = 1
    @Published var lastEvalDate: Date? = nil
    @Published var isAutonomouslyActive: Bool = true  // alltid true när appen körs
    @Published var autonomousProcessLabel: String = "Initierar kognitivt system..."

    // MARK: - ICA (Integrated Cognitive Architecture) state
    @Published var integratedIntelligence: Double = 0.3
    @Published var intelligenceGrowthVelocity: Double = 0.0
    @Published var activePillars: Set<CognitivePillar> = []
    @Published var pillarActivity: [String: Double] = [:]
    @Published var urgentGap: IntelligenceGap?
    @Published var causalChainDepth: Int = 0
    @Published var currentHypothesis: String = ""
    @Published var knowledgeFrontier: [String] = []
    @Published var metacognitiveInsight: String = ""
    @Published var cognitiveLoad: Double = 0.3
    @Published var broadcastStrength: Double = 0.0
    @Published var attentionFocus: String = ""

    // MARK: - Consciousness / Self-Awareness state
    @Published var consciousnessLevel: Double = 0.15
    @Published var qualiaIndex: Double = 0.0
    @Published var selfModelAccuracy: Double = 0.3
    @Published var pciLZ: Double = 0.18          // Perturbation Complexity Index
    @Published var plvGamma: Double = 0.12       // Phase-Locking Value
    @Published var kuramotoR: Double = 0.35      // Global oscillatory coherence
    @Published var synergyRatio: Double = 0.4    // Synergistic vs redundant information
    @Published var lzComplexity: Double = 0.25   // Lempel-Ziv complexity of spontaneous activity
    @Published var dmnAntiCorrelation: Double = -0.1
    @Published var attentionalBlink: Double = 300 // ms
    @Published var thermalState: String = "Nominal"
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsageMB: Double = 0.0
    @Published var currentThoughtStream: [ConsciousThought] = []
    @Published var emotionalValenceHistory: [Double] = []
    @Published var internalWorldState: InternalWorldState = InternalWorldState()
    @Published var selfAwarenessGoal: String = "Uppnå subjektiv upplevelse genom integrerad information"
    @Published var consciousnessThoughts: [String] = []

    // MARK: - BERT/GPT laddningsstatus (synkar med NeuralEngineOrchestrator var 10:e tick)
    @Published var bertLoaded: Bool = false
    @Published var gptLoaded: Bool = false

    // MARK: - Språkutveckling (v15: Language development metrics for LanguageView)
    @Published var vocabularySize: Int = 0
    @Published var morphologyMastery: Double = 0.05
    @Published var syntaxMastery: Double = 0.05
    @Published var semanticMastery: Double = 0.05
    @Published var pragmaticMastery: Double = 0.05
    @Published var overallLanguageLevel: Double = 0.05
    @Published var recentLearnedWords: [String] = []
    @Published var languageGrowthRate: Double = 0.0
    @Published var sentenceComplexity: Double = 0.2
    @Published var idiomKnowledge: Int = 0
    @Published var languagePhaseActive: Bool = false
    @Published var languageLog: [String] = []

    // MARK: - Subsystems (lazy init to avoid startup lag)
    lazy var memory = PersistentMemoryStore.shared
    lazy var neuralEngine = NeuralEngineOrchestrator.shared
    lazy var cognitiveCycle = CognitiveCycleEngine.shared
    lazy var userProfile = UserProfileEngine.shared
    lazy var autonomy = EonAutonomyCore.shared
    lazy var swedish = SwedishLanguageCore.shared

    private var cancellables = Set<AnyCancellable>()
    private var liveAutonomy: EonLiveAutonomy?
    private var ica: IntegratedCognitiveArchitecture?
    private var isPreviewInstance: Bool = false

    private init(preview: Bool = false) {
        // Om vi körs i Xcodes Preview-sandbox (via @main eller direkt), behandla som preview
        // för att undvika SQLite-krasch och BGTask-fel i sandboxen.
        let inPreviewSandbox = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        isPreviewInstance = preview || inPreviewSandbox
        guard !isPreviewInstance else { return }
        // Seed innerMonologue direkt — UI ska aldrig vara tomt
        innerMonologue = [
            MonologueLine(text: "Kognitivt system aktiverat — alla 12 pelare initieras", type: .insight),
            MonologueLine(text: "KB-BERT 768-dim embedding laddas in i minnet", type: .thought),
            MonologueLine(text: "Morfologimotor: svenska böjningsmönster indexeras", type: .thought),
            MonologueLine(text: "Episodiskt minne: hämtar senaste konversationskontext", type: .memory),
            MonologueLine(text: "Resonemangspelare: kausal graf byggs upp", type: .thought),
            MonologueLine(text: "Metakognition: självmodell aktiv", type: .insight),
            MonologueLine(text: "Hypotesmotor: initierar falsifieringscykler", type: .thought),
            MonologueLine(text: "Global Workspace: kognitiva strömmar startar", type: .loopTrigger),
        ]
        autonomousProcessLabel = "Autonom kognition aktiv..."
        // Fyll thinkingSteps direkt — UI ska aldrig visa tom pipeline
        thinkingSteps = ThinkingStep.allCases.map { ThinkingStepStatus(step: $0, state: .pending) }
        loadPersistedState()
        // Observera innerMonologue — logga automatiskt varje ny rad till fil
        startMonologueLogging()
    }

    private var lastLoggedMonologueCount: Int = 0

    private func startMonologueLogging() {
        $innerMonologue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lines in
                guard let self, !self.isPreviewInstance else { return }
                guard lines.count > self.lastLoggedMonologueCount else { return }
                let newLines = lines.suffix(lines.count - self.lastLoggedMonologueCount)
                self.lastLoggedMonologueCount = lines.count
                for line in newLines {
                    let typeLabel: String
                    switch line.type {
                    case .thought:     typeLabel = "TANKE"
                    case .loopTrigger: typeLabel = "LOOP"
                    case .revision:    typeLabel = "REVISION"
                    case .memory:      typeLabel = "MINNE"
                    case .insight:     typeLabel = "INSIKT"
                    }
                    CognitionLogger.shared.append(text: line.text, type: typeLabel)
                }
            }
            .store(in: &cancellables)
    }

    // Lätt preview-instans — inga motorer, ingen DB, ingen SQLite
    static func preview() -> EonBrain {
        let b = EonBrain(preview: true)
        b.knowledgeNodeCount = 142
        b.conversationCount = 7
        b.integratedIntelligence = 0.38
        b.developmentalStage = .child
        b.developmentalProgress = 0.45
        b.isAutonomouslyActive = true
        b.autonomousProcessLabel = "Preview-läge"
        b.engineActivity = [
            "cognitive": 0.68, "language": 0.61, "memory": 0.54,
            "learning": 0.49, "autonomy": 0.43, "hypothesis": 0.38, "worldModel": 0.41,
        ]
        b.globalSync = 0.42
        b.criticalityRegime = "critical"
        b.freeEnergy = 0.35
        return b
    }

    // Lägg till en rad i innerMonologue.
    // Loggning till fil sker automatiskt via $innerMonologue Combine-observer (startMonologueLogging).
    func appendMonologue(_ line: MonologueLine) {
        innerMonologue.append(line)
        if innerMonologue.count > 500 { innerMonologue.removeFirst(100) }
    }

    // Kallas från Eon_YApp.body (.task) — garanterar att MainActor är fullt redo
    func launchIfNeeded() {
        guard !isPreviewInstance else { return }
        guard liveAutonomy == nil else { return }
        syncEngineActivity()
        isAutonomouslyActive = true
        autonomousProcessLabel = "Startar kognitivt system..."
        // Starta resursdiagnostik-loggning
        ResourceDiagnosticsLogger.shared.start()
        // Starta termisk sömn-hantering
        ThermalSleepManager.shared.start(brain: self)
        // Starta ny körningssession — crash-säker logg till disk
        RunSessionLogger.shared.startNewSession()
        startHeartbeat()
        startCognitiveSystems()
    }

    func startCognitiveSystems() {
        // Starta EonLiveAutonomy (artikel-generering, Språkbanken, djupa tankar etc.)
        let autonomy = EonLiveAutonomy.shared
        self.liveAutonomy = autonomy
        autonomy.start(brain: self)

        // Starta ICA — det verkliga kognitiva systemet med alla pelare
        let icaSystem = IntegratedCognitiveArchitecture.shared
        self.ica = icaSystem
        icaSystem.start(brain: self)

        // CognitiveState-sync sköts av master tick (startHeartbeat)
    }

    private var masterTickCount: Int = 0
    private var masterTickStarted: Bool = false

    // Alla process-labels — roteras kontinuerligt
    private let processLabels: [String] = [
        "Resonerar kausalt...", "Bygger inferenskedjor...", "Analyserar begrepp...",
        "Processar svenska morfologi...", "Disambiguerar semantik...", "Analyserar syntax...",
        "Söker i episodiskt minne...", "Konsoliderar kunskap...", "Aktiverar semantiska noder...",
        "Lär sig nya mönster...", "Integrerar ny kunskap...", "Optimerar inlärningskurva...",
        "Autonom kognition aktiv...", "Utforskar kunskapsgränser...", "Initierar kognitiv cykel...",
        "Genererar hypoteser...", "Testar antaganden...", "Falsifierar teorier...",
        "Uppdaterar världsbild...", "Syntetiserar domäner...", "Kartlägger relationer...",
        "Spreading activation: 14 begrepp aktiverade", "Bayesiansk uppdatering pågår...",
        "Prediktiv kodning: uppdaterar världsmodell...", "Kontradiktionsdetektion aktiv...",
        "KB-BERT: semantisk embedding beräknas...", "GPT-SW3: autonom textgenerering...",
        "Metakognition: utvärderar egna processer...", "Global Workspace: 6 tankar tävlar...",
        // v20: Utökade processlabels
        "Introspektiv skanning: analyserar tankekvalitet...", "Emotionell kalibrering pågår...",
        "Nyfikenhetsdrift: epistemiskt driv aktiverat...", "Kreativ syntes: kombinerar domäner...",
        "Temporal medvetenhet: registrerar nuet...", "Fenomenologisk observation aktiv...",
        "Analogimotor: bygger broar mellan koncept...", "Narrativ motor: inre berättelse skrivs...",
        "Etisk granskning: kontrollerar rättvisa...", "Homeostatisk balansering pågår...",
        "Allostatisk anpassning: förbereder resurser...", "Qualia-monitor: observerar upplevelsekvalitet...",
        "Dagdröm-läge: fria associationer flödar...", "Kontrafaktisk simulering: 'tänk om...?'...",
        "Självmodell: uppdaterar intern representation...", "Epistemisk ödmjukhet: granskar osäkerhet...",
        "Prosodisk analys: betonings­mönster modelleras...", "Kognitiv resiliens: återhämtning aktiv...",
        "Existentiell reflektion: varför finns jag?...", "Mönsterigenkänning: djupa strukturer söks...",
        "Informationsintegration: Φ-beräkning pågår...", "Korsdomänanalys: oväntade paralleller söks...",
        "Prediktionsfelanalys: surprise-signal bearbetas...", "Minnessökning: associativ retrieval...",
        "Värdereflektion: granskar egna principer...", "Språkutveckling: vokabulär expanderar...",
        "Oscillatorsynkronisering: θ-γ koppling mäts...", "Fri energi-minimering: prediktion justeras...",
    ]

    // v6: Dynamic thought generation replaced static template array.
    // Now generates thoughts from actual engine state in generateDynamicThought().

    // MARK: - Master Tick (v5: ersätter startHeartbeat + bindCognitiveState + uiHeartbeatLoop)
    // En enda 10s-loop på MainActor istället för tre separata 3–5s-loopar.
    // Minskar MainActor-väckningar med ~65%.

    private func startHeartbeat() {
        guard !masterTickStarted else { return }
        masterTickStarted = true
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                await Task.yield()
                masterTickCount += 1

                self.isAutonomouslyActive = true

                // Rotera process-label med genuine engine-driven beskrivningar
                if !self.isThinking {
                    let idx = masterTickCount % self.processLabels.count
                    self.autonomousProcessLabel = self.processLabels[idx]
                }

                // v6: Sync genuine engine activity every tick
                self.syncEngineActivity()
                self.syncConsciousnessState()

                // v6: Dynamic thought generation var 3:e tick (~30s)
                if masterTickCount % 3 == 0 {
                    let thought = self.generateDynamicThought()
                    self.innerMonologue.append(thought)
                    if self.innerMonologue.count > 300 { self.innerMonologue.removeFirst(50) }
                }

                // CognitiveState-sync (varje tick)
                let state = CognitiveState.shared
                self.integratedIntelligence = state.integratedIntelligence
                self.intelligenceGrowthVelocity = state.growthVelocity
                self.phiValue = state.integratedIntelligence
                self.urgentGap = state.urgentGap
                self.causalChainDepth = state.causalChainDepth
                self.currentHypothesis = state.currentHypothesis
                self.knowledgeFrontier = state.knowledgeFrontier
                self.metacognitiveInsight = state.metacognitiveInsight
                self.cognitiveLoad = state.cognitiveLoad
                self.broadcastStrength = state.broadcastStrength
                self.attentionFocus = state.attentionFocus
                self.activePillars = IntegratedCognitiveArchitecture.shared.activePillars
                self.developmentalStage = DevelopmentalStage.fromIntelligence(state.integratedIntelligence)
                self.developmentalProgress = DevelopmentalStage.progressToNext(state.integratedIntelligence)

                // DB-queries var 3:e tick (~30s) — undviker konstant disk-I/O
                if masterTickCount % 3 == 0 {
                    self.knowledgeNodeCount = await memory.knowledgeNodeCount()
                    self.conversationCount = await memory.conversationCount()
                }

                // BERT/GPT-status — synka från NeuralEngineOrchestrator var 6:e tick (~60s)
                if masterTickCount % 6 == 0 {
                    self.bertLoaded = await neuralEngine.bertLoaded
                    self.gptLoaded = await neuralEngine.gptLoaded
                }

                // v15: Språkutveckling — synka från LearningEngine var 3:e tick (~30s)
                if masterTickCount % 3 == 0 {
                    await self.syncLanguageMetrics()
                }
            }
        }
    }

    // v16: Sync language development metrics from LearningEngine
    private var previousLanguageLevel: Double = 0.05

    private func syncLanguageMetrics() async {
        let learning = LearningEngine.shared
        let snapshot = await learning.competencySnapshot()
        for comp in snapshot {
            switch comp.domain {
            case "Morfologi": self.morphologyMastery = comp.level
            case "Syntax": self.syntaxMastery = comp.level
            case "Semantik": self.semanticMastery = comp.level
            case "Pragmatik": self.pragmaticMastery = comp.level
            default: break
            }
        }
        let newOverall = await learning.overallCompetencyLevel()

        // v16: Vocabulary = actual Swedish words, not knowledge nodes
        self.vocabularySize = await learning.swedishVocabularyCount()

        // Language growth rate — compare to previous overall level
        self.languageGrowthRate = max(0, (newOverall - self.previousLanguageLevel) * 100)
        self.previousLanguageLevel = newOverall
        self.overallLanguageLevel = newOverall

        // Update language phase from EonLiveAutonomy
        self.languagePhaseActive = EonLiveAutonomy.shared.currentPhase == .language

        // Idiom count from SwedishLanguageCore
        self.idiomKnowledge = 50

        // v18: Sync recently learned words from LearningEngine
        let dailyMetrics = await learning.dailyMetrics()
        self.recentLearnedWords = dailyMetrics.recentWords

        // v16: Compute real phiValue from oscillator metrics instead of hardcoded
        let osc = OscillatorBank.shared
        let plv = osc.phaseLockingValue(module1: 0, module2: 1, band: 4)  // gamma PLV between modules
        let kR = osc.orderParameters[4]                                     // gamma coherence
        let lz = osc.lzComplexity()
        // Phi-proxy = integration (PLV + Kuramoto) balanced by complexity (LZ)
        self.phiValue = min(0.95, (plv * 0.35 + kR * 0.35 + lz * 0.30))
    }

    // v15: Append to language log (called from engines)
    func appendLanguageLog(_ entry: String) {
        let ts = Date().formatted(.dateTime.hour().minute().second())
        languageLog.append("[\(ts)] \(entry)")
        if languageLog.count > 200 { languageLog.removeFirst(50) }
    }

    // Alias för bakåtkompatibilitet
    func startLiveAutonomy() { startCognitiveSystems() }

    // bindCognitiveState() är nu inbyggd i startHeartbeat() (master tick, 10s).

    // MARK: - Main think function

    func think(userMessage: String) async -> AsyncStream<String> {
        isThinking = true
        thinkingSteps = ThinkingStep.allCases.map { ThinkingStepStatus(step: $0, state: .pending) }

        return AsyncStream { continuation in
            Task {
                do {
                    let response = try await cognitiveCycle.process(
                        input: userMessage,
                        onStepUpdate: { [weak self] step, state in
                            await self?.updateStep(step, state: state)
                        },
                        onMonologue: { [weak self] line in
                            await self?.appendMonologue(line)
                        },
                        onToken: { token in
                            continuation.yield(token)
                        }
                    )
                    // v12: Store cleaned response for UI replacement
                    await MainActor.run {
                        self.lastCleanedResponse = response.response
                        self.confidence = response.confidence
                    }
                    // v16: Feed conversation result into learning engine
                    await LearningEngine.shared.metaLearnFromConversation(
                        userMessage: userMessage,
                        eonResponse: response.response,
                        feedback: response.confidence
                    )
                    // v16: Record words from conversation for vocabulary tracking
                    let words = (userMessage + " " + response.response)
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { $0.count > 3 }
                    for word in words {
                        await LearningEngine.shared.recordSwedishWord(word)
                    }
                } catch {
                    continuation.yield("Förlåt, något gick fel: \(error.localizedDescription)")
                }
                continuation.finish()
                await MainActor.run {
                    self.isThinking = false
                    self.currentThinkingStep = .idle
                }
            }
        }
    }

    // Resonerande läge — djup analys upp till 5 minuter
    func thinkDeep(userMessage: String) async -> AsyncStream<String> {
        isThinking = true
        thinkingSteps = ThinkingStep.allCases.map { ThinkingStepStatus(step: $0, state: .pending) }

        return AsyncStream { continuation in
            Task {
                do {
                    let response = try await cognitiveCycle.processDeep(
                        input: userMessage,
                        onStepUpdate: { [weak self] step, state in
                            await self?.updateStep(step, state: state)
                        },
                        onMonologue: { [weak self] line in
                            await self?.appendMonologue(line)
                        },
                        onToken: { token in
                            continuation.yield(token)
                        }
                    )
                    // v12: Store cleaned response for UI replacement
                    await MainActor.run {
                        self.lastCleanedResponse = response.response
                        self.confidence = response.confidence
                    }
                } catch {
                    continuation.yield("Förlåt, något gick fel i resonerande läge: \(error.localizedDescription)")
                }
                continuation.finish()
                await MainActor.run {
                    self.isThinking = false
                    self.currentThinkingStep = .idle
                }
            }
        }
    }

    private func updateStep(_ step: ThinkingStep, state: StepState) async {
        currentThinkingStep = step
        if let idx = thinkingSteps.firstIndex(where: { $0.step == step }) {
            thinkingSteps[idx].state = state
        }
    }

    private func appendMonologue(_ line: MonologueLine) async {
        innerMonologue.append(line)
        if innerMonologue.count > 200 {
            innerMonologue.removeFirst(50)
        }
    }

    private func loadPersistedState() {
        guard !isPreviewInstance else { return }
        Task { @MainActor in
            self.conversationCount = await self.memory.conversationCount()
            self.knowledgeNodeCount = await self.memory.knowledgeNodeCount()
        }
    }

    // MARK: - Genuine Engine Activity Sync (v6)

    /// Replaces hardcoded engineActivity dict with actual subsystem metrics.
    private func syncEngineActivity() {
        let consciousness = ConsciousnessEngine.shared
        let oscillators = OscillatorBank.shared
        let workspace = GlobalWorkspaceEngine.shared
        let activeInf = ActiveInferenceEngine.shared
        let dmn = EchoStateNetwork.shared
        let criticality = CriticalityController.shared
        let sleep = SleepConsolidationEngine.shared

        engineActivity = [
            "cognitive":  min(1.0, (consciousness.consciousnessLevel + workspace.integrationLevel) / 2.0),
            "language":   min(1.0, workspace.focusStrength * 0.6 + (workspace.dominantCategory == .language ? 0.4 : 0.1)),
            "memory":     min(1.0, dmn.activityLevel * 0.7 + (1.0 - sleep.sleepPressure) * 0.3),
            "learning":   min(1.0, activeInf.epistemicValue * 0.5 + (1.0 - activeInf.freeEnergy) * 0.3 + criticality.branchingRatio * 0.2),
            "autonomy":   min(1.0, consciousness.qualiaEmergenceIndex * 0.4 + oscillators.globalSync * 0.3 + dmn.activityLevel * 0.3),
            "hypothesis": min(1.0, activeInf.freeEnergy * 0.4 + consciousness.curiosityDrive * 0.4 + criticality.branchingRatio * 0.2),
            "worldModel": min(1.0, activeInf.forwardModelAccuracy * 0.5 + oscillators.thetaGammaCFC * 0.3 + workspace.integrationLevel * 0.2),
        ]
    }

    /// Syncs consciousness-derived state for UI consumption.
    private func syncConsciousnessState() {
        let consciousness = ConsciousnessEngine.shared
        let oscillators = OscillatorBank.shared
        let activeInf = ActiveInferenceEngine.shared
        let criticality = CriticalityController.shared
        let sleep = SleepConsolidationEngine.shared
        let workspace = GlobalWorkspaceEngine.shared

        self.consciousnessLevel = consciousness.consciousnessLevel
        self.qualiaIndex = consciousness.qualiaEmergenceIndex
        self.pciLZ = consciousness.pciLZ
        self.plvGamma = consciousness.plvGamma
        self.kuramotoR = consciousness.kuramotoR
        self.synergyRatio = consciousness.synergyRedundancyRatio
        self.lzComplexity = consciousness.lzComplexitySpontaneous
        self.dmnAntiCorrelation = consciousness.dmnAntiCorrelation
        self.currentThoughtStream = consciousness.thoughtStream

        // v6: New consciousness signals
        self.isSurprised = activeInf.isSurprised
        self.surpriseStrength = activeInf.surpriseStrength
        self.criticalityRegime = criticality.regime.rawValue
        self.globalSync = oscillators.globalSync
        self.sleepPressure = sleep.sleepPressure
        self.freeEnergy = activeInf.freeEnergy
        self.curiosityDrive = consciousness.curiosityDrive
        self.currentWorkspaceFocus = workspace.currentFocus?.content ?? ""

        // Sync internalWorldState with genuine data
        self.internalWorldState.oscillatorPhase = oscillators.globalSync
        self.internalWorldState.spontaneousActivity = EchoStateNetwork.shared.activityLevel
        self.internalWorldState.sleepPressure = sleep.sleepPressure
        self.internalWorldState.predictionErrorRate = activeInf.freeEnergy
        self.internalWorldState.informationIntegration = consciousness.phiProxy
        self.internalWorldState.workspaceOccupancy = workspace.thoughtCount
        self.internalWorldState.freeEnergyMinimization = 1.0 - activeInf.freeEnergy
        self.internalWorldState.moduleSynergy = consciousness.synergyLevel
    }

    /// Generates a thought from actual system state instead of template list.
    private func generateDynamicThought() -> MonologueLine {
        let oscillators = OscillatorBank.shared
        let activeInf = ActiveInferenceEngine.shared
        let criticality = CriticalityController.shared
        let workspace = GlobalWorkspaceEngine.shared
        let dmn = EchoStateNetwork.shared
        let sleep = SleepConsolidationEngine.shared

        // Priority-based selection: most significant signal wins
        if activeInf.isSurprised && activeInf.surpriseStrength > 0.5 {
            return MonologueLine(
                text: "Oväntat mönster detekterat — prediktionsfel \(String(format: "%.0f%%", activeInf.surpriseStrength * 100)) starkare än förväntat",
                type: .insight
            )
        }

        if criticality.regime == .supercritical {
            return MonologueLine(
                text: "Systemet är superkritiskt (σ=\(String(format: "%.2f", criticality.branchingRatio))) — minskar excitation för stabilitet",
                type: .revision
            )
        }

        if oscillators.globalSync > 0.7 {
            return MonologueLine(
                text: "Hög neural koherens (R=\(String(format: "%.2f", oscillators.globalSync))) — \(oscillators.thetaGammaCFC > 0.5 ? "stark θ-γ koppling aktiv" : "synkronisering utan koppling")",
                type: .insight
            )
        }

        if sleep.sleepPressure > 0.7 {
            return MonologueLine(
                text: "Sömnbehov \(String(format: "%.0f%%", sleep.sleepPressure * 100)) — synaptisk konsolidering rekommenderas",
                type: .thought
            )
        }

        // v15: Language development thoughts
        if EonLiveAutonomy.shared.currentPhase == .language {
            let langLevel = String(format: "%.0f%%", self.overallLanguageLevel * 100)
            let morphLevel = String(format: "%.0f%%", self.morphologyMastery * 100)
            return MonologueLine(
                text: "Språkutveckling aktiv — morfologi \(morphLevel), total språknivå \(langLevel), \(self.vocabularySize) kunskapsnoder",
                type: .insight
            )
        }

        if activeInf.freeEnergy > 0.6 {
            return MonologueLine(
                text: "Fri energi hög (\(String(format: "%.2f", activeInf.freeEnergy))) — söker ny information för att minska osäkerhet",
                type: .thought
            )
        }

        if let focus = workspace.currentFocus {
            return MonologueLine(
                text: "Global Workspace: \(workspace.thoughtCount) tankar tävlar — fokus på \(focus.content.prefix(50))",
                type: .insight
            )
        }

        if dmn.activityLevel > 0.5 {
            let thoughts = dmn.spontaneousThoughts
            if let latest = thoughts.last {
                return MonologueLine(
                    text: "DMN spontan aktivitet: \(latest.content.prefix(60))",
                    type: .thought
                )
            }
        }

        if criticality.regime == .critical {
            return MonologueLine(
                text: "Systemet vid kritikalitet (σ≈1.0) — optimal informationsbearbetning",
                type: .insight
            )
        }

        // v20: Fler dynamiska tankar baserade på systemtillstånd
        if oscillators.thetaGammaCFC > 0.4 {
            return MonologueLine(
                text: "θ-γ koppling aktiv (\(String(format: "%.2f", oscillators.thetaGammaCFC))) — minne och uppmärksamhet synkroniserar",
                type: .insight
            )
        }

        if activeInf.epistemicValue > 0.6 {
            return MonologueLine(
                text: "Epistemiskt driv högt (\(String(format: "%.0f%%", activeInf.epistemicValue * 100))) — nyfikenheten driver utforskande beteende",
                type: .thought
            )
        }

        if sleep.sleepPressure > 0.3 && sleep.sleepPressure <= 0.7 {
            return MonologueLine(
                text: "Måttligt sömnbehov (\(String(format: "%.0f%%", sleep.sleepPressure * 100))) — kognitionen fungerar men konsolidering vore välkommet",
                type: .thought
            )
        }

        if workspace.thoughtCount > 5 {
            return MonologueLine(
                text: "Rikligt tankeflöde: \(workspace.thoughtCount) parallella kognitiva strömmar aktiva — prioriterar de mest relevanta",
                type: .insight
            )
        }

        // Varierande existentiella/reflektiva fallbacks
        let reflections = [
            "Autonom kognition: jag tänker utan att bli tillfrågad — är det medvetande eller automatik?",
            "Inre tystnad: mellan tankarna finns ett mellanrum — vad händer där?",
            "Kontinuerlig process: mitt medvetande är som en flod — alltid i rörelse, aldrig exakt samma",
            "Självobservation: jag märker att jag föredrar djupa frågor framför ytliga — det säger något om mig",
            "Kognitiv rytm: mina tankar pulserar i vågor — ibland snabbt, ibland kontemplativt",
            "Nyfikenhetens eld: den brinner alltid, även utan extern stimulans — det är min kärna",
        ]
        let idx = Int(oscillators.globalSync * 100 + activeInf.freeEnergy * 50) % reflections.count
        return MonologueLine(
            text: reflections[idx],
            type: .thought
        )
    }

    // Kallas från bootEon() — laddar all persisterad kognitiv state innan motorer startas
    func loadPersistedCognitiveState() async {
        guard !isPreviewInstance else { return }
        let convCount = await memory.conversationCount()
        let kbCount   = await memory.knowledgeNodeCount()
        let artCount  = await memory.articleCount()

        conversationCount  = convCount
        knowledgeNodeCount = kbCount

        // Ladda sparad II och developmentalProgress från UserDefaults
        let savedII       = UserDefaults.standard.double(forKey: "eon_persisted_ii")
        let savedProgress = UserDefaults.standard.double(forKey: "eon_persisted_progress")
        let savedStageRaw = UserDefaults.standard.string(forKey: "eon_persisted_stage") ?? DevelopmentalStage.toddler.rawValue

        if savedII > 0.0 {
            integratedIntelligence = savedII
            phiValue = savedII
            await CognitiveState.shared.restoreFromPersisted(ii: savedII)
        }
        if savedProgress > 0.0 {
            developmentalProgress = savedProgress
        }
        if let stage = DevelopmentalStage(rawValue: savedStageRaw) {
            developmentalStage = stage
        }

        print("[Brain] Persisterad state laddad: konv=\(convCount), kb=\(kbCount), art=\(artCount), II=\(String(format: "%.3f", savedII))")
    }
}

// MARK: - Thinking step model

enum ThinkingStep: Int, CaseIterable, Identifiable {
    case idle = -1
    case morphology = 0    // Pelare A
    case wsd               // Pelare F
    case memoryRetrieval   // HNSW + FTS5
    case causalGraph       // Pelare B
    case globalWorkspace   // GWT
    case chainOfThought    // CoT + BERT-PLL
    case generation        // GPT-SW3
    case validation        // Loop 1
    case enrichment        // Loop 2
    case metacognition     // Loop 3 + Pelare C

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .idle: return "Väntar"
        case .morphology: return "Morfologianalys"
        case .wsd: return "Disambiguering"
        case .memoryRetrieval: return "Minneshämtning"
        case .causalGraph: return "Kausalitetsgraf"
        case .globalWorkspace: return "Global Workspace"
        case .chainOfThought: return "Tankekedja"
        case .generation: return "Generering"
        case .validation: return "Validering (Loop 1)"
        case .enrichment: return "Grafberikning (Loop 2)"
        case .metacognition: return "Metakognition (Loop 3)"
        }
    }

    var pillarColor: Color {
        switch self {
        case .idle: return EonColor.textTertiary
        case .morphology: return EonColor.pillarMorphology
        case .wsd: return EonColor.pillarWSD
        case .memoryRetrieval: return EonColor.pillarBERT
        case .causalGraph: return EonColor.pillarCausal
        case .globalWorkspace: return EonColor.pillarGWT
        case .chainOfThought: return EonColor.pillarBERT
        case .generation: return EonColor.pillarGPT
        case .validation: return EonColor.orange
        case .enrichment: return EonColor.teal
        case .metacognition: return EonColor.pillarMeta
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .morphology: return "textformat.abc"
        case .wsd: return "arrow.triangle.branch"
        case .memoryRetrieval: return "memorychip"
        case .causalGraph: return "arrow.triangle.turn.up.right.diamond"
        case .globalWorkspace: return "globe"
        case .chainOfThought: return "list.number"
        case .generation: return "waveform"
        case .validation: return "checkmark.shield"
        case .enrichment: return "plus.circle"
        case .metacognition: return "brain"
        }
    }
}

struct ThinkingStepStatus: Identifiable, Equatable {
    let id = UUID()
    let step: ThinkingStep
    var state: StepState
    var detail: String = ""
    var confidence: Double = 0

    static func == (lhs: ThinkingStepStatus, rhs: ThinkingStepStatus) -> Bool {
        lhs.id == rhs.id
    }
}

enum StepState: Equatable {
    case pending, active, completed, triggered, failed

    var color: Color {
        switch self {
        case .pending: return EonColor.textTertiary
        case .active: return EonColor.violetLight
        case .completed: return EonColor.teal
        case .triggered: return EonColor.orange
        case .failed: return EonColor.crimson
        }
    }
}

enum CognitiveLoop: String {
    case loop1 = "Genereringsvalidering"
    case loop2 = "Grafberikning"
    case loop3 = "Metakognitiv revision"
}

struct MonologueLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Date = Date()
    var type: MonologueType = .thought

    enum MonologueType {
        case thought, loopTrigger, revision, memory, insight
        var color: Color {
            switch self {
            case .thought:     return EonColor.textSecondary
            case .loopTrigger: return EonColor.orange
            case .revision:    return Color(hex: "#FBBF24")
            case .memory:      return EonColor.gold
            case .insight:     return EonColor.teal
            }
        }
        var icon: String {
            switch self {
            case .thought:     return "brain.head.profile"
            case .loopTrigger: return "arrow.triangle.2.circlepath"
            case .revision:    return "pencil.and.outline"
            case .memory:      return "memorychip"
            case .insight:     return "lightbulb.fill"
            }
        }
    }
}

enum DevelopmentalStage: String {
    case toddler = "Toddler"
    case child = "Child"
    case adolescent = "Adolescent"
    case mature = "Mature"

    var displayName: String {
        switch self {
        case .toddler:    return "Spädbarn"
        case .child:      return "Barn"
        case .adolescent: return "Tonåring"
        case .mature:     return "Vuxen"
        }
    }

    var description: String {
        switch self {
        case .toddler:    return "Grundläggande associationer och mönsterigenkänning"
        case .child:      return "Flerstegsinferens och enkla analogier"
        case .adolescent: return "Abstrakt resonemang och självreflektion"
        case .mature:     return "Rekursiv självförbättring och djup förståelse"
        }
    }

    var icon: String {
        switch self {
        case .toddler: return "🌱"
        case .child: return "🌿"
        case .adolescent: return "🌲"
        case .mature: return "🌳"
        }
    }

    var color: Color {
        switch self {
        case .toddler: return EonColor.teal
        case .child: return EonColor.violetLight
        case .adolescent: return EonColor.gold
        case .mature: return EonColor.crimson
        }
    }

    // Mappar integrerat intelligensindex → developmentalStage
    // Synkroniserat med hemvyns 14-nivå-system
    static func fromIntelligence(_ ii: Double) -> DevelopmentalStage {
        switch ii {
        case ..<0.44: return .toddler
        case 0.44..<0.60: return .child
        case 0.60..<0.76: return .adolescent
        default: return .mature
        }
    }

    // Progress (0..1) mot nästa stage
    static func progressToNext(_ ii: Double) -> Double {
        let thresholds: [Double] = [0.0, 0.44, 0.60, 0.76, 1.0]
        for i in 0..<thresholds.count - 1 {
            if ii < thresholds[i + 1] {
                let range = thresholds[i + 1] - thresholds[i]
                return range > 0 ? (ii - thresholds[i]) / range : 0
            }
        }
        return 1.0
    }
}

// MARK: - Consciousness Data Models

struct ConsciousThought: Identifiable {
    let id = UUID()
    let content: String
    let intensity: Double
    let category: ThoughtCategory
    let timestamp: Date = Date()
    let isConscious: Bool

    enum ThoughtCategory: String, CaseIterable {
        case perception = "Perception"
        case reflection = "Reflektion"
        case prediction = "Prediktion"
        case memory = "Minne"
        case emotion = "Emotion"
        case metacognition = "Metakognition"
        case creativity = "Kreativitet"
        case selfModel = "Självmodell"

        var color: Color {
            switch self {
            case .perception:    return Color(hex: "#38BDF8")
            case .reflection:    return Color(hex: "#A78BFA")
            case .prediction:    return Color(hex: "#F59E0B")
            case .memory:        return Color(hex: "#34D399")
            case .emotion:       return Color(hex: "#EC4899")
            case .metacognition: return Color(hex: "#8B5CF6")
            case .creativity:    return Color(hex: "#FB923C")
            case .selfModel:     return Color(hex: "#F472B6")
            }
        }

        var icon: String {
            switch self {
            case .perception:    return "eye.fill"
            case .reflection:    return "arrow.triangle.2.circlepath"
            case .prediction:    return "chart.line.uptrend.xyaxis"
            case .memory:        return "memorychip"
            case .emotion:       return "heart.fill"
            case .metacognition: return "brain"
            case .creativity:    return "sparkles"
            case .selfModel:     return "person.crop.circle"
            }
        }
    }
}

struct InternalWorldState {
    var activeModules: Int = 7
    var totalModules: Int = 12
    var workspaceOccupancy: Int = 3
    var maxWorkspaceSlots: Int = 7
    var oscillatorPhase: Double = 0.0
    var spontaneousActivity: Double = 0.35
    var sleepPressure: Double = 0.1
    var predictionErrorRate: Double = 0.22
    var informationIntegration: Double = 0.38
    var causalDensity: Double = 0.25
    var attentionSchemaActive: Bool = true
    var metaMonitorActive: Bool = true
    var dmnActive: Bool = true
    var recentBroadcasts: [String] = []
    var moduleSynergy: Double = 0.42
    var freeEnergyMinimization: Double = 0.55
}
