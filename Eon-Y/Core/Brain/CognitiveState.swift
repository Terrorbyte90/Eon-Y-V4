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

    private init() {
        buildCausalInfluences()
        buildFeedbackLoops()
        Task { @MainActor in await self.startStateMonitor() }
    }

    // MARK: - Uppdatera dimension (kallas av varje pelare)

    func update(dimension: CognitiveDimension, delta: Double, source: String) {
        let old = dimensions[dimension] ?? 0.3
        let new = max(0.01, min(0.99, old + delta))
        dimensions[dimension] = new

        // Spara historik
        dimensionHistory[dimension, default: []].append(new)
        if (dimensionHistory[dimension]?.count ?? 0) > 100 {
            dimensionHistory[dimension]?.removeFirst(20)
        }

        // Propagera kausal påverkan till relaterade dimensioner
        propagateCausalEffect(from: dimension, delta: delta * 0.3)

        // Uppdatera integrerat intelligensindex
        recalculateIntegratedIntelligence()
    }

    func setDimension(_ dimension: CognitiveDimension, value: Double, source: String) {
        let clamped = max(0.01, min(0.99, value))
        let old = dimensions[dimension] ?? 0.3
        dimensions[dimension] = clamped
        propagateCausalEffect(from: dimension, delta: (clamped - old) * 0.3)
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
        let effects = causalInfluences.filter { $0.from == source }
        for effect in effects {
            let propagated = delta * effect.strength
            let old = dimensions[effect.to] ?? 0.3
            dimensions[effect.to] = max(0.01, min(0.99, old + propagated))
        }
    }

    // MARK: - Bygg kausal nätverksstruktur

    private func buildCausalInfluences() {
        // Resonemang → förstärker kausalitet, metakognition, kreativitet
        causalInfluences += [
            CausalInfluence(from: .reasoning, to: .causality, strength: 0.4),
            CausalInfluence(from: .reasoning, to: .metacognition, strength: 0.3),
            CausalInfluence(from: .reasoning, to: .creativity, strength: 0.2),
        ]
        // Inlärning → förstärker kunskap, språk, resonemang
        causalInfluences += [
            CausalInfluence(from: .learning, to: .knowledge, strength: 0.5),
            CausalInfluence(from: .learning, to: .language, strength: 0.3),
            CausalInfluence(from: .learning, to: .reasoning, strength: 0.25),
        ]
        // Metakognition → förstärker ALLT (den viktigaste pelaren)
        causalInfluences += [
            CausalInfluence(from: .metacognition, to: .reasoning, strength: 0.35),
            CausalInfluence(from: .metacognition, to: .learning, strength: 0.4),
            CausalInfluence(from: .metacognition, to: .selfAwareness, strength: 0.5),
            CausalInfluence(from: .metacognition, to: .adaptivity, strength: 0.3),
        ]
        // Kausalitet → förstärker resonemang, världsmodell
        causalInfluences += [
            CausalInfluence(from: .causality, to: .reasoning, strength: 0.35),
            CausalInfluence(from: .causality, to: .worldModel, strength: 0.4),
            CausalInfluence(from: .causality, to: .prediction, strength: 0.45),
        ]
        // Kunskap → förstärker alla kognitiva förmågor
        causalInfluences += [
            CausalInfluence(from: .knowledge, to: .reasoning, strength: 0.3),
            CausalInfluence(from: .knowledge, to: .language, strength: 0.25),
            CausalInfluence(from: .knowledge, to: .creativity, strength: 0.2),
            CausalInfluence(from: .knowledge, to: .worldModel, strength: 0.35),
        ]
        // Självmedvetenhet → förstärker metakognition, adaptivitet
        causalInfluences += [
            CausalInfluence(from: .selfAwareness, to: .metacognition, strength: 0.4),
            CausalInfluence(from: .selfAwareness, to: .adaptivity, strength: 0.35),
        ]
        // Kreativitet → förstärker hypotesgenerering, analogier
        causalInfluences += [
            CausalInfluence(from: .creativity, to: .hypothesisGeneration, strength: 0.45),
            CausalInfluence(from: .creativity, to: .analogyBuilding, strength: 0.4),
        ]
        // Analogier → förstärker resonemang, kreativitet
        causalInfluences += [
            CausalInfluence(from: .analogyBuilding, to: .reasoning, strength: 0.3),
            CausalInfluence(from: .analogyBuilding, to: .creativity, strength: 0.25),
        ]
        // Språk → förstärker kommunikation, förståelse
        causalInfluences += [
            CausalInfluence(from: .language, to: .comprehension, strength: 0.45),
            CausalInfluence(from: .language, to: .communication, strength: 0.5),
        ]
        // Världsmodell → förstärker prediktion, kausalitet
        causalInfluences += [
            CausalInfluence(from: .worldModel, to: .prediction, strength: 0.4),
            CausalInfluence(from: .worldModel, to: .causality, strength: 0.3),
        ]
    }

    private func buildFeedbackLoops() {
        // Positiva återkopplingsloopar (förstärkande)
        feedbackLoops = [
            FeedbackLoop(
                name: "Inlärnings-resonemang-spiral",
                dimensions: [.learning, .reasoning, .knowledge],
                type: .positive,
                strength: 0.6,
                description: "Mer inlärning → bättre resonemang → djupare kunskap → ännu mer inlärning"
            ),
            FeedbackLoop(
                name: "Metakognitiv acceleration",
                dimensions: [.metacognition, .selfAwareness, .adaptivity],
                type: .positive,
                strength: 0.7,
                description: "Bättre självkännedom → bättre metakognition → snabbare adaptation → ännu bättre självkännedom"
            ),
            FeedbackLoop(
                name: "Kausal djupspiral",
                dimensions: [.causality, .worldModel, .prediction],
                type: .positive,
                strength: 0.65,
                description: "Kausalförståelse → rikare världsmodell → bättre prediktion → stärker kausalförståelse"
            ),
            FeedbackLoop(
                name: "Kreativ hypotes-loop",
                dimensions: [.creativity, .hypothesisGeneration, .analogyBuilding],
                type: .positive,
                strength: 0.55,
                description: "Kreativitet genererar hypoteser → analogier bekräftar/avvisar → stärker kreativiteten"
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

        // Auto-persistera kognitiv state var 60s — säkerställer att lärande överlever omstarter
        let lastPersistTs = UserDefaults.standard.double(forKey: "eon_persisted_timestamp")
        if Date().timeIntervalSince1970 - lastPersistTs > 60 {
            persistCurrentState()
            // Spara developmental stage och progress
            UserDefaults.standard.set(DevelopmentalStage.fromIntelligence(newII).rawValue, forKey: "eon_persisted_stage")
            UserDefaults.standard.set(DevelopmentalStage.progressToNext(newII), forKey: "eon_persisted_progress")
        }
    }

    // MARK: - Tillståndsmonitor

    @MainActor
    private func startStateMonitor() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            updateFeedbackLoops()
            identifyBottlenecks()
        }
    }

    private func updateFeedbackLoops() {
        for loop in feedbackLoops {
            let avgLevel = loop.dimensions.compactMap { dimensions[$0] }.reduce(0, +) / Double(loop.dimensions.count)
            if loop.type == .positive && avgLevel > 0.4 {
                // Förstärk alla dimensioner i loopen
                for dim in loop.dimensions {
                    let boost = loop.strength * 0.005 * avgLevel
                    dimensions[dim] = min(0.99, (dimensions[dim] ?? 0.3) + boost)
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
        // Återställ dimensioner från UserDefaults
        if let dimDict = UserDefaults.standard.dictionary(forKey: "eon_persisted_dimensions") as? [String: Double] {
            for (rawValue, val) in dimDict {
                if let dim = CognitiveDimension(rawValue: rawValue) {
                    dimensions[dim] = max(0.01, min(0.99, val))
                }
            }
        } else {
            // Ingen sparad state — starta på låg men deterministisk bas (0.05), byggs upp via riktig inlärning
            let baseLevel = max(0.05, min(0.3, ii * 0.4))
            for dim in CognitiveDimension.allCases {
                dimensions[dim] = baseLevel
            }
        }
        integratedIntelligence = ii
        recalculateIntegratedIntelligence()
        print("[CognitiveState] Återställd från persistens: II=\(String(format: "%.3f", ii))")
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

struct IntelligenceGap: Identifiable {
    let id = UUID()
    let dimension: CognitiveDimension
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let blockedDimensions: [CognitiveDimension]
    let suggestedActions: [String]

    var gapSize: Double { targetLevel - currentLevel }
    var priorityLabel: String {
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
