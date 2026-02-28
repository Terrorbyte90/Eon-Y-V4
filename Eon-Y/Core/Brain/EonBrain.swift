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

    private init() {
        loadPersistedState()
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        Task { @MainActor in
            self.startCognitiveSystems()
        }
    }

    func startCognitiveSystems() {
        // Starta legacy autonomy (artikel-generering, Språkbanken etc.)
        let autonomy = EonLiveAutonomy.shared
        self.liveAutonomy = autonomy
        autonomy.start(brain: self)

        // Starta ICA — det verkliga kognitiva systemet
        let icaSystem = IntegratedCognitiveArchitecture.shared
        self.ica = icaSystem
        icaSystem.start(brain: self)

        // Bind ICA-tillstånd till brain för UI
        bindCognitiveState()
    }

    // Alias för bakåtkompatibilitet
    func startLiveAutonomy() { startCognitiveSystems() }

    private func bindCognitiveState() {
        // Synka CognitiveState → EonBrain @Published properties var 1s
        // Körs på @MainActor (EonBrain är @MainActor) så alla läsningar är säkra
        Task { @MainActor in
            while true {
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

                // Uppdatera kunskaps- och konversationsräknare var 5:e cykel
                if Int(Date().timeIntervalSince1970) % 5 == 0 {
                    self.knowledgeNodeCount = await memory.knowledgeNodeCount()
                    self.conversationCount = await memory.conversationCount()
                }
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
        Task { @MainActor in
            self.conversationCount = await self.memory.conversationCount()
            self.knowledgeNodeCount = await self.memory.knowledgeNodeCount()
        }
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
            case .thought: return EonColor.textSecondary
            case .loopTrigger: return EonColor.orange
            case .revision: return Color(hex: "#FBBF24")
            case .memory: return EonColor.gold
            case .insight: return EonColor.teal
            }
        }
    }
}

enum DevelopmentalStage: String {
    case toddler = "Toddler"
    case child = "Child"
    case adolescent = "Adolescent"
    case mature = "Mature"

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
