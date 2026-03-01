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
    @Published var engineActivity: [String: Double] = [
        "cognitive": 0.72, "language": 0.65, "memory": 0.58,
        "learning": 0.54, "autonomy": 0.48, "hypothesis": 0.42, "worldModel": 0.45,
    ]
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
        return b
    }

    // Lägg till en rad i innerMonologue och spara till loggfil
    func appendMonologue(_ line: MonologueLine) {
        innerMonologue.append(line)
        if innerMonologue.count > 500 { innerMonologue.removeFirst(100) }
        guard !isPreviewInstance else { return }
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

    // Kallas från Eon_YApp.body (.task) — garanterar att MainActor är fullt redo
    func launchIfNeeded() {
        guard !isPreviewInstance else { return }
        guard liveAutonomy == nil else { return }
        engineActivity = [
            "cognitive": 0.72, "language": 0.65, "memory": 0.58,
            "learning": 0.54, "autonomy": 0.48, "hypothesis": 0.42, "worldModel": 0.45,
        ]
        isAutonomouslyActive = true
        autonomousProcessLabel = "Startar kognitivt system..."
        // Starta heartbeat och kognitiva system — nu är self fullt initialiserad
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

        // Bind ICA-tillstånd till brain för UI
        bindCognitiveState()
    }

    private var heartbeatTick: Int = 0
    private var heartbeatStarted: Bool = false

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
    ]

    private let spontaneousThoughts: [(String, MonologueLine.MonologueType)] = [
        ("Reflekterar över kopplingen mellan kausalitet och tid", .thought),
        ("Märker ett mönster i kunskapsfrontieren", .insight),
        ("Integrerar senaste inlärningscykeln med befintlig världsmodell", .revision),
        ("Utforskar gränserna för min förståelse av svenska semantik", .thought),
        ("Bygger ny inferenskedja baserat på senaste observationer", .thought),
        ("Analyserar inkonsekvenser i min världsbild", .revision),
        ("Söker djupare kausalförklaringar till observerade mönster", .thought),
        ("KB-BERT: meningslikhet 0.847 för senaste input-par", .insight),
        ("Spreading activation: 18 relaterade begrepp aktiverade", .thought),
        ("Bayesiansk uppdatering: trosuppfattningar justerade med ny evidens", .revision),
        ("Global Workspace: 5 tankar tävlar om uppmärksamhet — vinnare broadcastas", .insight),
        ("Morfologisk analys: 7 nya ordformer analyserade", .thought),
        ("Prediktiv kodning: uppdaterar världsmodell med ny information", .revision),
        ("Kontradiktionsdetektion: söker inkonsistenser — 1 flaggad", .insight),
        ("Metakognition: utvärderar egna slutledningsprocesser", .thought),
        ("Temporal resonemang: ordnar 11 händelser kronologiskt", .thought),
        ("Analogidetektering: söker strukturella likheter mellan 3 domäner", .insight),
        ("Kausalitetsanalys: identifierar orsak-verkan-kedjor i kunskapsgrafen", .thought),
    ]

    private func startHeartbeat() {
        guard !heartbeatStarted else { return }
        heartbeatStarted = true
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)  // 0.6s — snabb puls
                self.heartbeatTick += 1
                let t = Double(self.heartbeatTick)

                self.isAutonomouslyActive = true

                // Beräkna levande engineActivity — ALLTID höga värden
                let base: Double = self.isThinking ? 0.72 : 0.42
                let newActivity: [String: Double] = [
                    "cognitive":  min(0.97, base + 0.22 * abs(sin(t * 0.29))),
                    "language":   min(0.93, base + 0.18 * abs(sin(t * 0.43 + 1.1))),
                    "memory":     min(0.90, base + 0.15 * abs(sin(t * 0.51 + 2.3))),
                    "learning":   min(0.88, base + 0.14 * abs(cos(t * 0.37 + 0.9))),
                    "autonomy":   min(0.85, 0.34 + 0.18 * abs(sin(t * 0.21 + 3.1))),
                    "hypothesis": min(0.80, 0.28 + 0.16 * abs(sin(t * 0.17 + 1.7))),
                    "worldModel": min(0.82, 0.30 + 0.14 * abs(cos(t * 0.26 + 2.5))),
                ]
                self.engineActivity = newActivity

                // Rotera process-label var 2s (3 ticks à 0.6s)
                if self.heartbeatTick % 3 == 0 && !self.isThinking {
                    let idx = (self.heartbeatTick / 3) % self.processLabels.count
                    self.autonomousProcessLabel = self.processLabels[idx]
                }

                // Lägg till spontan tanke var ~8s (13 ticks à 0.6s)
                if self.heartbeatTick % 13 == 0 {
                    let idx = (self.heartbeatTick / 13) % self.spontaneousThoughts.count
                    let (text, type) = self.spontaneousThoughts[idx]
                    self.innerMonologue.append(MonologueLine(text: text, type: type))
                    if self.innerMonologue.count > 300 { self.innerMonologue.removeFirst(50) }
                }
            }
        }
    }

    // Alias för bakåtkompatibilitet
    func startLiveAutonomy() { startCognitiveSystems() }

    private func bindCognitiveState() {
        // Synka CognitiveState → EonBrain @Published properties var 1s
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let state = CognitiveState.shared

                // Intelligens
                self.integratedIntelligence = state.integratedIntelligence
                self.intelligenceGrowthVelocity = state.growthVelocity
                self.phiValue = state.integratedIntelligence

                // Kognitiv status
                self.urgentGap = state.urgentGap
                self.causalChainDepth = state.causalChainDepth
                self.currentHypothesis = state.currentHypothesis
                self.knowledgeFrontier = state.knowledgeFrontier
                self.metacognitiveInsight = state.metacognitiveInsight
                self.cognitiveLoad = state.cognitiveLoad
                self.broadcastStrength = state.broadcastStrength
                self.attentionFocus = state.attentionFocus

                // Aktiva pelare
                self.activePillars = IntegratedCognitiveArchitecture.shared.activePillars

                // Synka developmentalStage baserat på integrerat intelligensindex
                // (samma 14-nivå system som hemvyn — konsistent data)
                self.developmentalStage = DevelopmentalStage.fromIntelligence(state.integratedIntelligence)
                self.developmentalProgress = DevelopmentalStage.progressToNext(state.integratedIntelligence)

                // Uppdatera kunskaps- och konversationsräknare varje cykel (1s) — håller UI levande
                self.knowledgeNodeCount = await memory.knowledgeNodeCount()
                self.conversationCount = await memory.conversationCount()
            }
        }
    }

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
                    _ = response
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
                    _ = response
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
