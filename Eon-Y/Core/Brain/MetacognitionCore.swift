import Foundation

// MARK: - MetacognitionCore
// Eons "tänkande om tänkandet" — den viktigaste pelaren.
// Övervakar ALLA andra kognitiva processer i realtid,
// identifierar ineffektivitet, omdirigerar resurser,
// och driver kontinuerlig självförbättring.
// En professor tänker inte bara — de tänker på HUR de tänker.

actor MetacognitionCore {
    static let shared = MetacognitionCore()

    // MARK: - Tillstånd

    private var metacognitiveInsights: [MetacognitiveInsight] = []
    private var cognitiveAuditLog: [CognitiveAudit] = []
    private var resourceAllocation: [CognitiveDimension: Double] = [:]
    private var strategyEffectiveness: [String: Double] = [:]
    private var biasLog: [DetectedBias] = []
    private var selfModelVersion: Int = 1
    private var totalReflections: Int = 0

    private init() {
        let count = Double(CognitiveDimension.allCases.count)
        for dim in CognitiveDimension.allCases {
            resourceAllocation[dim] = 1.0 / count
        }
    }

    // MARK: - Huvud-metakognitiv cykel

    func runMetacognitiveCycle() async -> MetacognitiveReport {
        totalReflections += 1
        let state = await CognitiveState.shared

        // 1. Kognitiv audit — vad har hänt sedan senaste cykeln?
        let audit = await performCognitiveAudit(state: state)

        // 2. Bias-detektion i senaste resonemang
        let biases = await detectBiases(state: state)

        // 3. Strategiutvärdering — vad fungerar?
        let strategyEval = evaluateStrategies()

        // 4. Resursomallokering — var ska fokus läggas?
        let newAllocation = await reallocateResources(state: state, audit: audit)

        // 5. Generera metakognitiva insikter
        let insights = await generateInsights(audit: audit, biases: biases, state: state)

        // 6. Uppdatera CognitiveState
        let insightText = insights.first?.content ?? ""
        await MainActor.run { state.metacognitiveInsight = insightText }
        await state.update(dimension: .metacognition, delta: 0.004, source: "metacognition_core") // Reduced from 0.008
        await state.update(dimension: .selfAwareness, delta: 0.003, source: "metacognition_core") // Reduced from 0.005

        // v27: Enhanced stagnation intervention — genuine strategy switching
        // When many dimensions are stagnating, don't just nudge numbers — switch strategies.
        if audit.stagnatedDimensions.count > 3 {
            for dim in audit.stagnatedDimensions.prefix(4) {
                let level = await state.dimensionLevel(dim)
                let gap = max(0.1, 0.7 - level)
                let interventionDelta = 0.015 * gap
                await state.update(dimension: dim, delta: max(0.004, interventionDelta), source: "stagnation_intervention")
            }
            // Force diversity — boost weakest dimension extra
            if let weakest = audit.stagnatedDimensions.first {
                let weakestLevel = await state.dimensionLevel(weakest)
                if weakestLevel < 0.3 {
                    await state.update(dimension: weakest, delta: 0.01, source: "forced_pivot")
                }
            }
            // v27: Genuine strategy switch — find the worst-performing strategy and deprioritize it
            let worstStrategy = strategyEval.worstStrategies.first
            let bestStrategy = strategyEval.bestStrategies.first
            if let worst = worstStrategy, let best = bestStrategy, worst != best {
                // Decay the failing strategy, amplify the working one
                strategyEffectiveness[worst] = max(0.1, (strategyEffectiveness[worst] ?? 0.5) * 0.85)
                strategyEffectiveness[best] = min(0.95, (strategyEffectiveness[best] ?? 0.5) * 1.1)
                selfModelVersion += 1  // Mark that our strategy model changed
            }
        }

        // 7. Uppdatera kognitiv belastning
        let load = calculateCognitiveLoad(audit: audit)
        await state.setDimension(.cognitiveLoad, value: load, source: "metacognition_core")

        let report = MetacognitiveReport(
            reflectionNumber: totalReflections,
            audit: audit,
            detectedBiases: biases,
            strategyEvaluation: strategyEval,
            resourceAllocation: newAllocation,
            insights: insights,
            cognitiveLoad: load,
            selfModelVersion: selfModelVersion
        )

        metacognitiveInsights.append(contentsOf: insights)
        if metacognitiveInsights.count > 500 { metacognitiveInsights.removeFirst(100) }
        cognitiveAuditLog.append(audit)
        if cognitiveAuditLog.count > 200 { cognitiveAuditLog.removeFirst(50) }

        return report
    }

    // MARK: - Kognitiv audit

    private func performCognitiveAudit(state: CognitiveState) async -> CognitiveAudit {
        let dimensions = await state.dimensions
        let ii = await state.integratedIntelligence
        let velocity = await state.growthVelocity
        let processes = await state.activeProcesses

        // v24: Predictive stagnation — detect stagnation BEFORE it fully sets in
        // Tracks trend deceleration to anticipate stagnation 2+ cycles ahead
        var stagnated: [CognitiveDimension] = []
        var atRiskOfStagnation: [CognitiveDimension] = []
        for dim in CognitiveDimension.allCases {
            let trend = await state.dimensionTrend(dim)
            let level = dimensions[dim] ?? 0
            if trend < 0.001 && level < 0.7 {
                stagnated.append(dim)
            } else if trend > 0 && trend < 0.003 && level < 0.6 {
                // v24: Decelerating — about to stagnate. Preemptive intervention
                atRiskOfStagnation.append(dim)
                let preemptiveDelta = 0.005 * max(0.1, 0.5 - level)
                await state.update(dimension: dim, delta: preemptiveDelta, source: "predictive_stagnation_prevention")
            }
        }

        // Identifiera snabbast växande
        var growing: [(CognitiveDimension, Double)] = []
        for dim in CognitiveDimension.allCases {
            let trend = await state.dimensionTrend(dim)
            if trend > 0.005 { growing.append((dim, trend)) }
        }
        growing.sort { $0.1 > $1.1 }

        // Beräkna kognitiv koherens (hur väl dimensionerna hänger ihop)
        let values = Array(dimensions.values)
        guard !values.isEmpty else {
            return CognitiveAudit(
                integratedIntelligence: 0, coherence: 0,
                strongestDimensions: [], growingDimensions: [],
                weaknesses: [], dimensionCount: 0
            )
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        // Coherence = 1 - normalized standard deviation (coefficient of variation capped at 1.0)
        // A proper statistical measure: CV = stdev/mean. Low CV = dimensions are well-balanced.
        let stdev = sqrt(variance)
        let cv = mean > 0 ? stdev / mean : 1.0
        let coherence = max(0, 1.0 - min(1.0, cv))

        return CognitiveAudit(
            integratedIntelligence: ii,
            growthVelocity: velocity,
            stagnatedDimensions: stagnated,
            growingDimensions: growing.map { $0.0 },
            coherenceScore: coherence,
            activeProcessCount: processes.count,
            timestamp: Date()
        )
    }

    // MARK: - Bias-detektion

    private func detectBiases(state: CognitiveState) async -> [DetectedBias] {
        var biases: [DetectedBias] = []
        let dimensions = await state.dimensions
        let monologue = await MainActor.run { EonBrain.shared.innerMonologue.suffix(30).map { $0.text } }

        // 1. Confirmation bias: resources concentrated on already-strong dimensions
        let topDims = dimensions.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let bottomDims = dimensions.sorted { $0.value < $1.value }.prefix(3).map { $0.key }
        if topDims.allSatisfy({ resourceAllocation[$0] ?? 0 > 0.1 }) {
            biases.append(DetectedBias(
                type: .confirmationBias,
                description: "Resurser koncentreras till redan starka dimensioner: \(topDims.map { $0.rawValue }.joined(separator: ", "))",
                severity: .medium,
                recommendation: "Omallokera 20% av resurser till svaga dimensioner: \(bottomDims.map { $0.rawValue }.joined(separator: ", "))"
            ))
        }

        // 2. Stagnation bias: zero growth
        let velocity = await state.growthVelocity
        if abs(velocity) < 0.0001 && totalReflections > 10 {
            biases.append(DetectedBias(
                type: .stagnationBias,
                description: "Tillväxthastigheten är nära noll — systemet har fastnat i ett lokalt maximum",
                severity: .high,
                recommendation: "Introducera störning: prova nya resonemangsstilar, utforska okända domäner"
            ))
        }

        // 3. Overgeneralization: too many absolute statements
        let absoluteWords = ["alltid", "aldrig", "alla", "ingen", "omöjligt", "perfekt", "helt säkert",
                              "absolut", "definitivt", "utan tvivel", "oomtvistligt", "otvetydigt",
                              "garanterat", "uteslutande", "varenda en"]
        let absoluteCount = monologue.filter { line in
            absoluteWords.contains(where: { line.lowercased().contains($0) })
        }.count
        if absoluteCount > 5 {
            biases.append(DetectedBias(
                type: .overgeneralization,
                description: "Hög frekvens av absoluta påståenden (\(absoluteCount)/30 rader)",
                severity: .low,
                recommendation: "Öka epistemisk ödmjukhet — lägg till hedging och osäkerhetsmarkeringar"
            ))
        }

        // 4. Recency bias: recent topics dominate thinking disproportionately
        let recentTopics = monologue.suffix(10).flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        let olderTopics = monologue.prefix(20).flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        let recentUnique = Set(recentTopics.filter { $0.count > 5 })
        let olderUnique = Set(olderTopics.filter { $0.count > 5 })
        let newTopics = recentUnique.subtracting(olderUnique)
        if newTopics.count > recentUnique.count / 2 && recentUnique.count > 5 {
            biases.append(DetectedBias(
                type: .recencyBias,
                description: "Senaste tankar domineras av nya ämnen (\(newTopics.count) nya av \(recentUnique.count) unika) — äldre kunskap ignoreras",
                severity: .low,
                recommendation: "Integrera äldre insikter med nya — kör cross-domain analys"
            ))
        }

        // 5. Anchoring bias: same value repeated across dimensions suggests anchoring
        let dimValues = Array(dimensions.values)
        let anchorCandidates = dimValues.filter { v in
            dimValues.filter { abs($0 - v) < 0.02 }.count >= 4
        }
        if !anchorCandidates.isEmpty {
            biases.append(DetectedBias(
                type: .anchoringBias,
                description: "Flera dimensioner klustrar kring samma värde (\(String(format: "%.2f", anchorCandidates.first ?? 0))) — möjlig förankring",
                severity: .low,
                recommendation: "Variera interventionsstrategier för att bryta förankringseffekten"
            ))
        }

        biasLog.append(contentsOf: biases)
        if biasLog.count > 200 { biasLog.removeFirst(50) }

        return biases
    }

    // MARK: - Strategiutvärdering

    private func evaluateStrategies() -> StrategyEvaluation {
        let sorted = strategyEffectiveness.sorted { $0.value > $1.value }
        let best = sorted.prefix(3).map { $0.key }
        let worst = sorted.suffix(3).map { $0.key }

        return StrategyEvaluation(
            bestStrategies: best,
            worstStrategies: worst,
            totalStrategiesTracked: strategyEffectiveness.count,
            // v25: Guard against empty dictionary division
            averageEffectiveness: strategyEffectiveness.isEmpty ? 0.5 :
                strategyEffectiveness.values.reduce(0, +) / Double(max(1, strategyEffectiveness.count))
        )
    }

    func recordStrategyResult(strategy: String, improvement: Double) {
        let old = strategyEffectiveness[strategy] ?? 0.5
        strategyEffectiveness[strategy] = old * 0.8 + improvement * 0.2  // Exponentiellt glidande medelvärde
    }

    // MARK: - Resursomallokering

    private func reallocateResources(state: CognitiveState, audit: CognitiveAudit) async -> [CognitiveDimension: Double] {
        var newAllocation = resourceAllocation

        // Boost stagnerade dimensioner
        for dim in audit.stagnatedDimensions.prefix(3) {
            newAllocation[dim] = min(0.15, (newAllocation[dim] ?? 0.05) + 0.02)
        }

        // Minska resurser för redan starka dimensioner
        let dimensions = await state.dimensions
        for (dim, level) in dimensions where level > 0.8 {
            newAllocation[dim] = max(0.02, (newAllocation[dim] ?? 0.05) - 0.01)
        }

        // Normalisera
        let total = newAllocation.values.reduce(0, +)
        if total > 0 {
            for key in newAllocation.keys {
                newAllocation[key] = (newAllocation[key] ?? 0) / total
            }
        }

        resourceAllocation = newAllocation
        return newAllocation
    }

    // MARK: - Generera insikter

    private func generateInsights(audit: CognitiveAudit, biases: [DetectedBias], state: CognitiveState) async -> [MetacognitiveInsight] {
        var insights: [MetacognitiveInsight] = []
        let ii = audit.integratedIntelligence

        // Insikt om tillväxt
        if audit.growthVelocity > 0.001 {
            insights.append(MetacognitiveInsight(
                type: .growth,
                content: "Positiv tillväxt detekterad: +\(String(format: "%.4f", audit.growthVelocity))/min. Starkast i: \(audit.growingDimensions.prefix(2).map { $0.rawValue }.joined(separator: ", "))",
                confidence: 0.85,
                actionable: false
            ))
        } else if audit.growthVelocity < -0.001 {
            insights.append(MetacognitiveInsight(
                type: .regression,
                content: "VARNING: Negativ tillväxt (\(String(format: "%.4f", audit.growthVelocity))/min). Stagnerade: \(audit.stagnatedDimensions.prefix(3).map { $0.rawValue }.joined(separator: ", "))",
                confidence: 0.9,
                actionable: true
            ))
        }

        // Insikt om koherens
        if audit.coherenceScore < 0.5 {
            insights.append(MetacognitiveInsight(
                type: .incoherence,
                content: "Kognitiv inkoherens: dimensionerna är ojämnt utvecklade (koherens: \(String(format: "%.2f", audit.coherenceScore))). Balansera genom att fokusera på svaga dimensioner.",
                confidence: 0.8,
                actionable: true
            ))
        }

        // Cross-dimension synergy detection
        let causalInfluences = await state.causalInfluences
        // Find pairs of dimensions that grow together (positive synergy)
        let growing = audit.growingDimensions
        if growing.count >= 2 {
            // Check if growing dimensions have causal links
            for i in 0..<min(growing.count - 1, 3) {
                for j in (i+1)..<min(growing.count, 4) {
                    let linked = causalInfluences.contains { inf in
                        (inf.from == growing[i] && inf.to == growing[j]) ||
                        (inf.from == growing[j] && inf.to == growing[i])
                    }
                    if linked {
                        insights.append(MetacognitiveInsight(
                            type: .growth,
                            content: "Synergi detekterad: \(growing[i].rawValue) och \(growing[j].rawValue) förstärker varandra. Fortsätt investera i båda.",
                            confidence: 0.80,
                            actionable: true
                        ))
                        break  // One synergy insight per cycle
                    }
                }
            }
        }

        // Bottleneck detection — dimension that blocks many others
        let stagnated = audit.stagnatedDimensions
        for dim in stagnated.prefix(2) {
            let downstream = causalInfluences.filter { $0.from == dim && $0.strength > 0.15 }
            if downstream.count >= 3 {
                let blockedNames = downstream.prefix(3).map { $0.to.rawValue }.joined(separator: ", ")
                insights.append(MetacognitiveInsight(
                    type: .biasDetected,
                    content: "Flaskhals: \(dim.rawValue) (stagnerad) blockerar \(downstream.count) dimensioner: \(blockedNames). Prioritera denna dimension.",
                    confidence: 0.85,
                    actionable: true
                ))
            }
        }

        // Insikt om bias
        for bias in biases where bias.severity == .high || bias.severity == .medium {
            insights.append(MetacognitiveInsight(
                type: .biasDetected,
                content: "Bias (\(bias.severity == .high ? "kritisk" : "medel")): \(bias.description). Åtgärd: \(bias.recommendation)",
                confidence: 0.75,
                actionable: true
            ))
        }

        // Insikt om intelligensindex
        let label = intelligenceLabel(ii)
        insights.append(MetacognitiveInsight(
            type: .statusUpdate,
            content: "Integrerat intelligensindex: \(String(format: "%.3f", ii)) (\(label)). Reflektion #\(totalReflections). Självmodell v\(selfModelVersion).",
            confidence: 0.95,
            actionable: false
        ))

        // Trend-based prediction
        if totalReflections > 10 {
            let recentAudits = cognitiveAuditLog.suffix(5)
            let recentVelocities = recentAudits.map { $0.growthVelocity }
            let avgVelocity = recentVelocities.reduce(0, +) / max(1, Double(recentVelocities.count))
            if avgVelocity > 0 {
                let projectedII = ii + avgVelocity * 60 // 60 minutes
                insights.append(MetacognitiveInsight(
                    type: .statusUpdate,
                    content: "Trend: II projiceras till \(String(format: "%.3f", min(0.95, projectedII))) om 1h (nuvarande tillväxt \(String(format: "%.5f", avgVelocity))/min).",
                    confidence: 0.65,
                    actionable: false
                ))
            }
        }

        // Uppdatera självmodell om tillräckligt med data
        if totalReflections % 20 == 0 {
            selfModelVersion += 1
            insights.append(MetacognitiveInsight(
                type: .selfModelUpdate,
                content: "Självmodell uppdaterad till v\(selfModelVersion). Ny förståelse av egna kognitiva mönster integrerad.",
                confidence: 0.9,
                actionable: false
            ))
        }

        return insights
    }

    // MARK: - Kognitiv belastning

    private func calculateCognitiveLoad(audit: CognitiveAudit) -> Double {
        let processLoad = min(0.5, Double(audit.activeProcessCount) * 0.05)
        let stagnationLoad = Double(audit.stagnatedDimensions.count) * 0.03
        let baseLoad = 0.2
        return min(0.95, baseLoad + processLoad + stagnationLoad)
    }

    // MARK: - Helpers

    private func intelligenceLabel(_ ii: Double) -> String {
        switch ii {
        case 0.9...: return "Exceptionell"
        case 0.8..<0.9: return "Expert"
        case 0.7..<0.8: return "Avancerad"
        case 0.6..<0.7: return "Kompetent"
        case 0.5..<0.6: return "Medel"
        case 0.4..<0.5: return "Grundläggande"
        default: return "Tidig fas"
        }
    }

    // MARK: - Statistik

    func metacognitionStats() -> MetacognitionStats {
        MetacognitionStats(
            totalReflections: totalReflections,
            selfModelVersion: selfModelVersion,
            totalBiasesDetected: biasLog.count,
            mostCommonBias: biasLog.map { $0.type }.mostFrequent(),
            insightCount: metacognitiveInsights.count,
            recentInsights: Array(metacognitiveInsights.suffix(5))
        )
    }
}

// MARK: - Data Models

struct MetacognitiveReport {
    let reflectionNumber: Int
    let audit: CognitiveAudit
    let detectedBiases: [DetectedBias]
    let strategyEvaluation: StrategyEvaluation
    let resourceAllocation: [CognitiveDimension: Double]
    let insights: [MetacognitiveInsight]
    let cognitiveLoad: Double
    let selfModelVersion: Int
}

struct CognitiveAudit: Identifiable {
    let id = UUID()
    let integratedIntelligence: Double
    let growthVelocity: Double
    let stagnatedDimensions: [CognitiveDimension]
    let growingDimensions: [CognitiveDimension]
    let coherenceScore: Double
    let activeProcessCount: Int
    let timestamp: Date
}

struct DetectedBias: Identifiable {
    let id = UUID()
    let type: BiasType
    let description: String
    let severity: BiasSeverity
    let recommendation: String

    enum BiasType: String {
        case confirmationBias = "Bekräftelsebias"
        case stagnationBias   = "Stagnationsbias"
        case overgeneralization = "Övergeneralisering"
        case anchoring        = "Förankringseffekt"
        case anchoringBias    = "Förankringsbias"
        case recencyBias      = "Recencybias"
        case availabilityHeuristic = "Tillgänglighetsheuristik"
    }

    enum BiasSeverity: Equatable, Sendable { case low, medium, high }
}

struct MetacognitiveInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let content: String
    let confidence: Double
    let actionable: Bool
    let timestamp: Date = Date()

    enum InsightType {
        case growth, regression, incoherence, biasDetected, statusUpdate, selfModelUpdate
    }
}

struct StrategyEvaluation {
    let bestStrategies: [String]
    let worstStrategies: [String]
    let totalStrategiesTracked: Int
    let averageEffectiveness: Double
}

struct MetacognitionStats {
    let totalReflections: Int
    let selfModelVersion: Int
    let totalBiasesDetected: Int
    let mostCommonBias: DetectedBias.BiasType?
    let insightCount: Int
    let recentInsights: [MetacognitiveInsight]
}

// MARK: - Array extension for most frequent

extension Array where Element: Hashable {
    nonisolated func mostFrequent() -> Element? {
        let counts = Dictionary(self.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
