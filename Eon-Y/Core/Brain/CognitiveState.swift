import Foundation
import Combine

// MARK: - CognitiveState
// Det delade kognitiva tillståndet som binder ALLA pelare samman i realtid.
// Varje pelare läser från och skriver till detta tillstånd.
// Förändringar propagerar automatiskt via Combine-publishers till alla lyssnare.
// Detta är "blodet" som flödar genom hela kognitiva systemet.

@MainActor
final class CognitiveState: ObservableObject {
    static let shared = CognitiveState()

    // MARK: - Kognitiv kapacitet per dimension (0..1)

    @Published var dimensions: [CognitiveDimension: Double] = {
        var d: [CognitiveDimension: Double] = [:]
        for dim in CognitiveDimension.allCases { d[dim] = 0.3 }
        return d
    }()

    // MARK: - Aktiva kognitiva processer

    @Published var activeProcesses: [CognitiveProcess] = []
    @Published var processQueue: [CognitiveProcess] = []

    // MARK: - Intelligens-gaps (luckor som aktivt drivs)

    @Published var intelligenceGaps: [IntelligenceGap] = []
    @Published var currentPriority: CognitiveDimension = .reasoning
    @Published var urgentGap: IntelligenceGap?

    // MARK: - Kausal påverkan (vilka dimensioner driver vilka)

    @Published var causalInfluences: [CausalInfluence] = []
    @Published var feedbackLoops: [FeedbackLoop] = []

    // MARK: - Metakognitiv status

    @Published var metacognitiveInsight: String = ""
    @Published var selfModelAccuracy: Double = 0.5
    @Published var cognitiveLoad: Double = 0.3
    @Published var adaptationRate: Double = 0.5

    // MARK: - Integrerat intelligensindex (IQ-proxy)

    @Published var integratedIntelligence: Double = 0.3
    @Published var intelligenceHistory: [IntelligenceSnapshot] = []
    @Published var growthVelocity: Double = 0.0   // förändring per minut

    // MARK: - Resonemangsstatus

    @Published var activeReasoningChain: [String] = []
    @Published var currentHypothesis: String = ""
    @Published var hypothesisConfidence: Double = 0.5
    @Published var causalChainDepth: Int = 0

    // MARK: - Inlärningsstatus

    @Published var learningMomentum: Double = 0.5
    @Published var knowledgeFrontier: [String] = []   // vad Eon just nu lär sig
    @Published var consolidatedFacts: Int = 0
    @Published var activeAnalogies: [String] = []

    // MARK: - Global Workspace status

    @Published var broadcastStrength: Double = 0.0
    @Published var attentionFocus: String = ""
    @Published var competingThoughts: Int = 0

    // MARK: - Kausal nätverksstatus

    @Published var causalGraphDensity: Double = 0.0
    @Published var newCausalLinks: Int = 0
    @Published var causalDepth: Int = 0

    // MARK: - Interaktionshistorik för cross-pelare påverkan

    private var dimensionHistory: [CognitiveDimension: [Double]] = [:]
    private var lastSnapshot: Date = Date()
    private var lastPersistDate: Date = .distantPast
    // Skyddar mot decay direkt efter uppstart — ger motorer tid att ladda
    private var startupProtectionUntil: Date = Date().addingTimeInterval(90)

    private init() {
        buildCausalInfluences()
        buildFeedbackLoops()
        Task { @MainActor in await self.startStateMonitor() }
    }

    // MARK: - Uppdatera dimension (kallas av varje pelare)
    // v3 Claude Edition: Added diminishing returns — high dimensions get smaller boosts.
    // This prevents runaway inflation where II reaches 0.96 while actual performance is grade F.

    // Räknare för att throttla tunga beräkningar
    private var updatesSinceLastRecalc: Int = 0
    private var pendingPropagations: [(CognitiveDimension, Double)] = []

    func update(dimension: CognitiveDimension, delta: Double, source: String) {
        let old = dimensions[dimension] ?? 0.3

        // Diminishing returns: adapt based on growth phase.
        let velocityBonus = growthVelocity > 0.0005 ? 0.15 : 0.0
        let diminishingFactor = max(0.1, (1.0 - old * 0.9) + velocityBonus)
        let effectiveDelta = delta * diminishingFactor

        let new = max(0.01, min(0.95, old + effectiveDelta))
        dimensions[dimension] = new

        // Spara historik
        dimensionHistory[dimension, default: []].append(new)
        if (dimensionHistory[dimension]?.count ?? 0) > 100 {
            dimensionHistory[dimension]?.removeFirst(20)
        }

        // Samla kausal propagation i batch istället för att köra omedelbart
        let propagationFactor: Double = 0.12
        let historyCount = dimensionHistory[dimension]?.count ?? 0
        if historyCount > 30 {
            let values = dimensionHistory[dimension] ?? []
            let mean = values.reduce(0, +) / Double(max(1, values.count))
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, values.count))
            let stability = max(0, 1.0 - sqrt(variance) * 5.0)
            let factor = 0.10 + stability * 0.08
            pendingPropagations.append((dimension, effectiveDelta * factor))
        } else {
            pendingPropagations.append((dimension, effectiveDelta * propagationFactor))
        }

        updatesSinceLastRecalc += 1

        // Kör tunga beräkningar i batch — max var 5:e uppdatering
        // Undviker att varje litet delta triggar full propagation + II-omberäkning
        if updatesSinceLastRecalc >= 5 {
            flushPendingUpdates()
        }
    }

    /// Kör alla ackumulerade propagationer och omberäkna II
    private func flushPendingUpdates() {
        for (dimension, delta) in pendingPropagations {
            propagateCausalEffect(from: dimension, delta: delta)
        }
        pendingPropagations.removeAll()
        updatesSinceLastRecalc = 0
        recalculateIntegratedIntelligence()
    }

    func setDimension(_ dimension: CognitiveDimension, value: Double, source: String) {
        let clamped = max(0.01, min(0.95, value))
        let old = dimensions[dimension] ?? 0.3
        dimensions[dimension] = clamped
        let delta = clamped - old
        propagateCausalEffect(from: dimension, delta: delta * 0.12)
        dimensionHistory[dimension, default: []].append(clamped)
        if (dimensionHistory[dimension]?.count ?? 0) > 100 {
            dimensionHistory[dimension]?.removeFirst(20)
        }
        recalculateIntegratedIntelligence()
    }

    // MARK: - Lägg till kognitiv process

    func addProcess(_ process: CognitiveProcess) {
        activeProcesses.append(process)
        if activeProcesses.count > 20 { activeProcesses.removeFirst(5) }
    }

    func completeProcess(_ id: UUID, result: String, confidenceDelta: Double) {
        if let idx = activeProcesses.firstIndex(where: { $0.id == id }) {
            activeProcesses[idx].status = .completed
            activeProcesses[idx].result = result
        }
        // Boost relaterad dimension
        if let process = activeProcesses.first(where: { $0.id == id }) {
            update(dimension: process.targetDimension, delta: confidenceDelta, source: process.name)
        }
    }

    // MARK: - Kausal propagering

    private func propagateCausalEffect(from source: CognitiveDimension, delta: Double) {
        // First-order effects: A → B
        let directEffects = causalInfluences.filter { $0.from == source }
        var secondOrderSources: [(CognitiveDimension, Double)] = []

        for effect in directEffects {
            let propagated = delta * effect.strength
            guard abs(propagated) > 0.0005 else { continue } // Skip negligible effects
            let old = dimensions[effect.to] ?? 0.3
            let dimFactor = max(0.1, 1.0 - old * 0.9) // Diminishing returns on propagated too
            let actual = propagated * dimFactor
            dimensions[effect.to] = max(0.01, min(0.95, old + actual))
            secondOrderSources.append((effect.to, actual))
        }

        // Second-order effects: A → B → C (diminished by 0.3x)
        // Only propagate if the primary delta is significant
        if abs(delta) > 0.001 {
            for (secondSource, secondDelta) in secondOrderSources {
                let indirect = causalInfluences.filter { $0.from == secondSource && $0.to != source }
                for effect in indirect {
                    let propagated = secondDelta * effect.strength * 0.3 // Heavy dampening for 2nd order
                    guard abs(propagated) > 0.0003 else { continue }
                    let old = dimensions[effect.to] ?? 0.3
                    dimensions[effect.to] = max(0.01, min(0.95, old + propagated))
                }
            }
        }
    }

    // MARK: - Bygg kausal nätverksstruktur

    private func buildCausalInfluences() {
        // v3 Claude Edition: Reduced ALL causal strengths by ~50% to prevent cascading inflation.
        // Combined with reduced propagation factor (0.15x instead of 0.3x), this prevents
        // the II=0.96 "Exceptional" while Eval gives grade F problem.

        // Resonemang → förstärker kausalitet, metakognition, kreativitet
        causalInfluences += [
            CausalInfluence(from: .reasoning, to: .causality, strength: 0.20),
            CausalInfluence(from: .reasoning, to: .metacognition, strength: 0.15),
            CausalInfluence(from: .reasoning, to: .creativity, strength: 0.10),
        ]
        // Inlärning → förstärker kunskap, språk, resonemang
        causalInfluences += [
            CausalInfluence(from: .learning, to: .knowledge, strength: 0.25),
            CausalInfluence(from: .learning, to: .language, strength: 0.15),
            CausalInfluence(from: .learning, to: .reasoning, strength: 0.12),
        ]
        // Metakognition → förstärker resonemang, inlärning, självmedvetenhet
        causalInfluences += [
            CausalInfluence(from: .metacognition, to: .reasoning, strength: 0.18),
            CausalInfluence(from: .metacognition, to: .learning, strength: 0.20),
            CausalInfluence(from: .metacognition, to: .selfAwareness, strength: 0.25),
            CausalInfluence(from: .metacognition, to: .adaptivity, strength: 0.15),
        ]
        // Kausalitet → förstärker resonemang, världsmodell
        causalInfluences += [
            CausalInfluence(from: .causality, to: .reasoning, strength: 0.18),
            CausalInfluence(from: .causality, to: .worldModel, strength: 0.20),
            CausalInfluence(from: .causality, to: .prediction, strength: 0.22),
        ]
        // Kunskap → förstärker kognitiva förmågor
        causalInfluences += [
            CausalInfluence(from: .knowledge, to: .reasoning, strength: 0.15),
            CausalInfluence(from: .knowledge, to: .language, strength: 0.12),
            CausalInfluence(from: .knowledge, to: .creativity, strength: 0.10),
            CausalInfluence(from: .knowledge, to: .worldModel, strength: 0.18),
        ]
        // Självmedvetenhet → förstärker metakognition, adaptivitet
        causalInfluences += [
            CausalInfluence(from: .selfAwareness, to: .metacognition, strength: 0.20),
            CausalInfluence(from: .selfAwareness, to: .adaptivity, strength: 0.18),
        ]
        // Kreativitet → förstärker hypotesgenerering, analogier
        causalInfluences += [
            CausalInfluence(from: .creativity, to: .hypothesisGeneration, strength: 0.22),
            CausalInfluence(from: .creativity, to: .analogyBuilding, strength: 0.20),
        ]
        // Analogier → förstärker resonemang, kreativitet
        causalInfluences += [
            CausalInfluence(from: .analogyBuilding, to: .reasoning, strength: 0.15),
            CausalInfluence(from: .analogyBuilding, to: .creativity, strength: 0.12),
        ]
        // Språk → förstärker kommunikation, förståelse
        causalInfluences += [
            CausalInfluence(from: .language, to: .comprehension, strength: 0.22),
            CausalInfluence(from: .language, to: .communication, strength: 0.25),
        ]
        // Världsmodell → förstärker prediktion, kausalitet
        causalInfluences += [
            CausalInfluence(from: .worldModel, to: .prediction, strength: 0.20),
            CausalInfluence(from: .worldModel, to: .causality, strength: 0.15),
        ]
    }

    private func buildFeedbackLoops() {
        // v3 Claude Edition: Reduced feedback loop strengths by ~40%
        // to prevent runaway metric inflation.
        feedbackLoops = [
            FeedbackLoop(
                name: "Inlärnings-resonemang-spiral",
                dimensions: [.learning, .reasoning, .knowledge],
                type: .positive,
                strength: 0.35,  // Was 0.6
                description: "Mer inlärning → bättre resonemang → djupare kunskap → ännu mer inlärning"
            ),
            FeedbackLoop(
                name: "Metakognitiv acceleration",
                dimensions: [.metacognition, .selfAwareness, .adaptivity],
                type: .positive,
                strength: 0.40,  // Was 0.7
                description: "Bättre självkännedom → bättre metakognition → snabbare adaptation"
            ),
            FeedbackLoop(
                name: "Kausal djupspiral",
                dimensions: [.causality, .worldModel, .prediction],
                type: .positive,
                strength: 0.35,  // Was 0.65
                description: "Kausalförståelse → rikare världsmodell → bättre prediktion"
            ),
            FeedbackLoop(
                name: "Kreativ hypotes-loop",
                dimensions: [.creativity, .hypothesisGeneration, .analogyBuilding],
                type: .positive,
                strength: 0.30,  // Was 0.55
                description: "Kreativitet genererar hypoteser → analogier bekräftar/avvisar"
            ),
            // Negativ återkoppling (stabiliserande)
            FeedbackLoop(
                name: "Kognitiv belastningsbegränsning",
                dimensions: [.cognitiveLoad, .adaptivity],
                type: .negative,
                strength: 0.4,
                description: "Hög kognitiv belastning → sänker adaptivitet → minskar belastning"
            ),
        ]
    }

    // MARK: - Integrerat intelligensindex

    private func recalculateIntegratedIntelligence() {
        // Viktat medelvärde med metakognition och resonemang som tyngst
        let weights: [CognitiveDimension: Double] = [
            .metacognition: 0.15,
            .reasoning: 0.13,
            .causality: 0.10,
            .learning: 0.10,
            .knowledge: 0.08,
            .selfAwareness: 0.08,
            .language: 0.07,
            .worldModel: 0.07,
            .adaptivity: 0.06,
            .creativity: 0.05,
            .hypothesisGeneration: 0.04,
            .analogyBuilding: 0.04,
            .comprehension: 0.03,
            .communication: 0.03,
            .prediction: 0.03,
            .cognitiveLoad: -0.05,  // Hög belastning sänker index
        ]

        var weighted = 0.0
        var totalWeight = 0.0
        for (dim, weight) in weights {
            if weight > 0 {
                weighted += (dimensions[dim] ?? 0.3) * weight
                totalWeight += weight
            } else {
                weighted += (1.0 - (dimensions[dim] ?? 0.3)) * abs(weight)
                totalWeight += abs(weight)
            }
        }

        let newII = totalWeight > 0 ? weighted / totalWeight : 0.3

        // Beräkna tillväxthastighet
        let oldII = integratedIntelligence
        let timeDelta = Date().timeIntervalSince(lastSnapshot) / 60.0  // minuter
        if timeDelta > 0.1 {
            growthVelocity = (newII - oldII) / timeDelta
            lastSnapshot = Date()
        }

        integratedIntelligence = newII

        // Spara snapshot var 30s
        if intelligenceHistory.count == 0 || intelligenceHistory.last.map({ Date().timeIntervalSince($0.timestamp) > 30 }) == true {
            intelligenceHistory.append(IntelligenceSnapshot(value: newII, timestamp: Date()))
            if intelligenceHistory.count > 200 { intelligenceHistory.removeFirst(50) }
        }

        // v4: Auto-persistera kognitiv state var 30s (was 15s) — reduces disk I/O
        if Date().timeIntervalSince(lastPersistDate) > 30 {
            persistCurrentState()
            lastPersistDate = Date()
            UserDefaults.standard.set(DevelopmentalStage.fromIntelligence(newII).rawValue, forKey: "eon_persisted_stage")
            UserDefaults.standard.set(DevelopmentalStage.progressToNext(newII), forKey: "eon_persisted_progress")
        }
    }

    // MARK: - Tillståndsmonitor

    @MainActor
    private func startStateMonitor() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 12_000_000_000) // v4: 8s → 12s — further CPU reduction
            // Flush eventuella pending propagations som inte nått batch-tröskeln
            if !pendingPropagations.isEmpty { flushPendingUpdates() }
            updateFeedbackLoops()
            applyHomeostaticDecay()
            updateCognitiveLoad()
            identifyBottlenecks()
        }
    }

    // MARK: - Homeostas: dimensioner sjunker sakta mot baslinjen om de inte aktivt tränas
    // Förhindrar att II alltid konvergerar mot 0.99 utan verklig aktivitet.
    private func applyHomeostaticDecay() {
        // Skyddsperiod efter uppstart — låt motorer ladda och återställa state
        guard Date() > startupProtectionUntil else { return }

        // Baseline är dynamisk: aldrig lägre än 80% av sparat II-värde.
        // Det säkerställer att inlärning inte raderas av decay.
        let savedII = UserDefaults.standard.double(forKey: "eon_persisted_ii")
        let baseline: Double = savedII > 0.1 ? max(0.30, savedII * 0.80) : 0.35

        // Mycket låg decay — bara ett litet tryck mot baseline, inte en radering
        let decayRate: Double = 0.00008      // Halverat från tidigare 0.00015

        for dim in CognitiveDimension.allCases where dim != .cognitiveLoad {
            guard let current = dimensions[dim] else { continue }
            if current > baseline {
                let excess = current - baseline
                let decay = decayRate * (1.0 + excess * 1.0)  // Reducerat från 2.0
                dimensions[dim] = max(baseline, current - decay)
            }
        }
    }

    // MARK: - Verklig cognitiveLoad baserad på systemlast
    private func updateCognitiveLoad() {
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalLoad: Double
        switch thermal {
        case .nominal:  thermalLoad = 0.15
        case .fair:     thermalLoad = 0.40
        case .serious:  thermalLoad = 0.70
        case .critical: thermalLoad = 0.90
        @unknown default: thermalLoad = 0.20
        }
        // Blanda termisk last med antal aktiva processer
        let processLoad = min(0.8, Double(activeProcesses.count) * 0.04)
        let newLoad = min(0.95, thermalLoad * 0.7 + processLoad * 0.3)
        // Smooth update
        cognitiveLoad = cognitiveLoad * 0.7 + newLoad * 0.3
        dimensions[.cognitiveLoad] = cognitiveLoad
    }

    private func updateFeedbackLoops() {
        for loop in feedbackLoops {
            let avgLevel = loop.dimensions.compactMap { dimensions[$0] }.reduce(0, +) / Double(loop.dimensions.count)
            if loop.type == .positive && avgLevel > 0.5 {
                // Förstärk dimensioner i loopen — men bara om de är aktivt tränade (> baseline)
                for dim in loop.dimensions {
                    let current = dimensions[dim] ?? 0.35
                    guard current > 0.45 else { continue }  // Kräver verklig aktivitet
                    let boost = loop.strength * 0.003 * (avgLevel - 0.5)  // Reducerat från 0.005
                    dimensions[dim] = min(0.99, current + boost)
                }
            } else if loop.type == .negative {
                // Negativ feedback: hög cognitiveLoad sänker adaptivitet
                let loadLevel = dimensions[.cognitiveLoad] ?? 0.3
                if loadLevel > 0.5 {
                    let suppression = loop.strength * 0.002 * (loadLevel - 0.5)
                    for dim in loop.dimensions where dim != .cognitiveLoad {
                        dimensions[dim] = max(0.1, (dimensions[dim] ?? 0.3) - suppression)
                    }
                }
            }
        }
        recalculateIntegratedIntelligence()
    }

    private func identifyBottlenecks() {
        // Hitta dimensioner som är flaskhalsar (låga och blockerar andra)
        let sorted = dimensions.sorted { $0.value < $1.value }
        if let weakest = sorted.first {
            let isBottleneck = causalInfluences.contains { $0.from == weakest.key && $0.strength > 0.3 }
            if isBottleneck && weakest.value < 0.4 {
                urgentGap = IntelligenceGap(
                    dimension: weakest.key,
                    currentLevel: weakest.value,
                    targetLevel: min(0.99, weakest.value + 0.2),
                    urgency: (0.4 - weakest.value) * 5.0,
                    blockedDimensions: causalInfluences.filter { $0.from == weakest.key }.map { $0.to },
                    suggestedActions: generateActions(for: weakest.key, level: weakest.value)
                )
            }
        }
    }

    // MARK: - Hjälpfunktioner

    func dimensionLevel(_ dim: CognitiveDimension) -> Double {
        dimensions[dim] ?? 0.3
    }

    func topDimensions(limit: Int = 5) -> [(CognitiveDimension, Double)] {
        dimensions.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    func weakestDimensions(limit: Int = 5) -> [(CognitiveDimension, Double)] {
        dimensions.sorted { $0.value < $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    func dimensionTrend(_ dim: CognitiveDimension) -> Double {
        guard let history = dimensionHistory[dim], history.count >= 2 else { return 0 }
        let recent = history.suffix(5)
        let older = history.prefix(max(1, history.count - 5))
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        return recentAvg - olderAvg
    }

    /// Count how many causal influences originate from a given dimension.
    /// Used to identify high-synergy dimensions that affect many others.
    func causalInfluenceCount(from dimension: CognitiveDimension) -> Int {
        causalInfluences.filter { $0.from == dimension }.count
    }

    // MARK: - Persistens: spara och återställ kognitiv state över omstarter

    func persistCurrentState() {
        let ud = UserDefaults.standard
        ud.set(integratedIntelligence, forKey: "eon_persisted_ii")
        // Spara alla dimensioner
        var dimDict: [String: Double] = [:]
        for (dim, val) in dimensions { dimDict[dim.rawValue] = val }
        ud.set(dimDict, forKey: "eon_persisted_dimensions")
        ud.set(Date().timeIntervalSince1970, forKey: "eon_persisted_timestamp")
    }

    func restoreFromPersisted(ii: Double) {
        // Förlängt uppstartsskydd — 90s från nu, ger alla motorer tid att ladda
        startupProtectionUntil = Date().addingTimeInterval(90)

        if let dimDict = UserDefaults.standard.dictionary(forKey: "eon_persisted_dimensions") as? [String: Double],
           !dimDict.isEmpty {
            // Återställ exakt sparade dimensionsvärden
            for (rawValue, val) in dimDict {
                if let dim = CognitiveDimension(rawValue: rawValue) {
                    dimensions[dim] = max(0.01, min(0.99, val))
                }
            }
            print("[CognitiveState] Återställd: \(dimDict.count) dimensioner, II=\(String(format: "%.3f", ii))")
        } else {
            // Ingen sparad state alls — härled dimensioner från II-värdet
            // Undviker att börja på 0.3 om II faktiskt var högre
            let baseLevel = max(0.30, min(0.75, ii * 0.85))
            for dim in CognitiveDimension.allCases where dim != .cognitiveLoad {
                dimensions[dim] = baseLevel
            }
            print("[CognitiveState] Ingen sparad dimensionsdata — härlett från II=\(String(format: "%.3f", ii)), bas=\(String(format: "%.3f", baseLevel))")
        }

        integratedIntelligence = ii
        recalculateIntegratedIntelligence()

        // Spara omedelbart så att ett eventuellt tidigt krasch inte förlorar restore-state
        persistCurrentState()
        lastPersistDate = Date()
    }

    // Snapshot av alla dimensioner för checkpoint-sparning
    func dimensionSnapshot() -> [String: Double] {
        var snap: [String: Double] = [:]
        for (dim, val) in dimensions {
            snap[dim.rawValue] = val
        }
        return snap
    }
}

// MARK: - Data Models

enum CognitiveDimension: String, CaseIterable, Hashable {
    case reasoning          = "Resonemang"
    case causality          = "Kausalitet"
    case metacognition      = "Metakognition"
    case learning           = "Inlärning"
    case knowledge          = "Kunskap"
    case selfAwareness      = "Självmedvetenhet"
    case language           = "Språk"
    case worldModel         = "Världsmodell"
    case adaptivity         = "Adaptivitet"
    case creativity         = "Kreativitet"
    case hypothesisGeneration = "Hypotesgenerering"
    case analogyBuilding    = "Analogibyggande"
    case comprehension      = "Förståelse"
    case communication      = "Kommunikation"
    case prediction         = "Prediktion"
    case cognitiveLoad      = "Kognitiv belastning"

    var icon: String {
        switch self {
        case .reasoning:           return "arrow.triangle.branch"
        case .causality:           return "arrow.left.and.right.circle"
        case .metacognition:       return "brain"
        case .learning:            return "graduationcap"
        case .knowledge:           return "books.vertical"
        case .selfAwareness:       return "person.crop.circle"
        case .language:            return "text.bubble"
        case .worldModel:          return "globe"
        case .adaptivity:          return "arrow.up.arrow.down.circle"
        case .creativity:          return "sparkles"
        case .hypothesisGeneration: return "questionmark.circle"
        case .analogyBuilding:     return "link.circle"
        case .comprehension:       return "eye"
        case .communication:       return "bubble.left.and.bubble.right"
        case .prediction:          return "chart.line.uptrend.xyaxis"
        case .cognitiveLoad:       return "gauge.high"
        }
    }

    var color: String {
        switch self {
        case .reasoning:           return "#7C3AED"
        case .causality:           return "#2563EB"
        case .metacognition:       return "#A78BFA"
        case .learning:            return "#059669"
        case .knowledge:           return "#14B8A6"
        case .selfAwareness:       return "#F472B6"
        case .language:            return "#34D399"
        case .worldModel:          return "#60A5FA"
        case .adaptivity:          return "#FBBF24"
        case .creativity:          return "#F59E0B"
        case .hypothesisGeneration: return "#EC4899"
        case .analogyBuilding:     return "#8B5CF6"
        case .comprehension:       return "#06B6D4"
        case .communication:       return "#10B981"
        case .prediction:          return "#3B82F6"
        case .cognitiveLoad:       return "#EF4444"
        }
    }
}

struct CognitiveProcess: Identifiable {
    let id = UUID()
    let name: String
    let sourcePillar: String
    let targetDimension: CognitiveDimension
    var status: ProcessStatus = .running
    var result: String = ""
    let startedAt: Date = Date()

    enum ProcessStatus { case running, completed, failed }
}

struct IntelligenceGap: Identifiable, Sendable {
    let id = UUID()
    let dimension: CognitiveDimension
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let blockedDimensions: [CognitiveDimension]
    let suggestedActions: [String]

    nonisolated var gapSize: Double { targetLevel - currentLevel }
    nonisolated var priorityLabel: String {
        urgency > 3.0 ? "KRITISK" : urgency > 2.0 ? "HÖG" : urgency > 1.0 ? "MEDEL" : "LÅG"
    }
}

struct CausalInfluence: Identifiable {
    let id = UUID()
    let from: CognitiveDimension
    let to: CognitiveDimension
    let strength: Double   // 0..1
}

struct FeedbackLoop: Identifiable {
    let id = UUID()
    let name: String
    let dimensions: [CognitiveDimension]
    let type: LoopType
    let strength: Double
    let description: String

    enum LoopType { case positive, negative }
}

struct IntelligenceSnapshot: Identifiable {
    let id = UUID()
    let value: Double
    let timestamp: Date
}
