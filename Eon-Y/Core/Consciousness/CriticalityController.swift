import Foundation

// MARK: - CriticalityController: Edge-of-Chaos Homeostas
// README §1.4: "Din hjärna opererar på gränsen mellan ordning och kaos...
// det enda tillståndet där information kan flöda fritt."
//
// Kritikalitet innebär att systemet balanserar mellan:
// - Subkritiskt (för ordnat): stereotypt beteende, ingen flexibilitet
// - Superkritiskt (för kaotiskt): osammanhängande, inget mönster
// - Kritiskt (edge of chaos): maximal informationsöverföring, power-law kaskader
//
// Mätvärde: branching ratio σ ≈ 1.0 (antal aktiverade noder per aktiverad nod)
// < 1.0 = subkritiskt (kaskader dör ut)
// = 1.0 = kritiskt (kaskader varken växer eller dör)
// > 1.0 = superkritiskt (kaskader exploderar)
//
// Hengen & Shew (Neuron, 2025): kritikalitet som förenande teori för hjärnfunktion.

@MainActor
final class CriticalityController: ObservableObject {
    static let shared = CriticalityController()

    // MARK: - Kritikalitetsmått

    /// Aktuell branching ratio (mål: 1.0 ± 0.1)
    @Published private(set) var branchingRatio: Double = 1.0

    /// Excitation/Inhibition-balans (mål: nära 0)
    @Published private(set) var eiBalance: Double = 0.0

    /// Kaskadstorlekar (för power-law analys)
    private var cascadeSizes: [Int] = []

    /// Power-law exponent (mål: ~1.5 för kritikalitet)
    @Published private(set) var powerLawExponent: Double = 1.5

    /// Regimklassificering
    @Published private(set) var regime: CriticalityRegime = .critical

    /// v9: Hysteresis counter — only change regime after 3 consecutive ticks in new regime
    private var pendingRegime: CriticalityRegime = .critical
    private var pendingRegimeCount: Int = 0
    private let hysteresisThreshold: Int = 3

    /// Homeostatisk korrektionsstyrka
    private var correctionRate: Double = 0.05

    // MARK: - Aktivitetsspårning
    private var activationHistory: [Double] = []
    private var currentCascade: Int = 0
    private let maxCascadeHistory = 500

    // MARK: - Init

    private init() {}

    // MARK: - Tick: mät och korrigera kritikalitet

    /// Kallas varje kognitiv cykel. Mäter systemaktivitet och justerar trösklar.
    /// - moduleActivities: aktivitetsnivå per modul (0-1)
    /// - oscillators: referens till OscillatorBank för att justera koppling
    func tick(moduleActivities: [Double], oscillators: OscillatorBank) {
        let avgActivity = moduleActivities.reduce(0, +) / max(1, Double(moduleActivities.count))

        // Spåra aktiveringshistorik
        activationHistory.append(avgActivity)
        if activationHistory.count > 200 { activationHistory.removeFirst() }

        // v9: Adaptive branching ratio with faster response near regime transitions
        if activationHistory.count >= 2 {
            let current = activationHistory.last!
            let previous = activationHistory[activationHistory.count - 2]
            if previous > 0.01 {
                let instantBR = current / previous
                // v9: Adaptive alpha — faster response when far from criticality
                let deviation = abs(branchingRatio - 1.0)
                let alpha = deviation > 0.2 ? 0.75 : 0.9  // Fast adapt when far, stable when near
                branchingRatio = branchingRatio * alpha + instantBR * (1.0 - alpha)
            }
        }

        // Spåra kaskader
        if avgActivity > 0.3 {
            currentCascade += 1
        } else if currentCascade > 0 {
            cascadeSizes.append(currentCascade)
            if cascadeSizes.count > maxCascadeHistory { cascadeSizes.removeFirst() }
            currentCascade = 0
        }

        // Beräkna E/I-balans
        let excitation = moduleActivities.filter { $0 > 0.5 }.count
        let inhibition = moduleActivities.filter { $0 < 0.3 }.count
        eiBalance = Double(excitation - inhibition) / max(1, Double(moduleActivities.count))

        // v9: Regime classification with hysteresis (prevents oscillation near boundaries)
        let candidateRegime: CriticalityRegime
        if branchingRatio < 0.85 {
            candidateRegime = .subcritical
        } else if branchingRatio > 1.15 {
            candidateRegime = .supercritical
        } else {
            candidateRegime = .critical
        }

        // Hysteresis: only switch regime after N consecutive ticks in new regime
        if candidateRegime == pendingRegime {
            pendingRegimeCount += 1
        } else {
            pendingRegime = candidateRegime
            pendingRegimeCount = 1
        }
        if pendingRegimeCount >= hysteresisThreshold || candidateRegime == .critical {
            regime = candidateRegime
        }

        // Homeostatisk korrigering
        applyCorrection(oscillators: oscillators)

        // Power-law analys (om tillräckligt med data)
        if cascadeSizes.count >= 50 {
            powerLawExponent = estimatePowerLawExponent()
        }
    }

    // MARK: - Homeostatisk korrigering

    /// v9: Multi-lever homeostatic correction — coupling + proportional control
    private func applyCorrection(oscillators: OscillatorBank) {
        let deviation = branchingRatio - 1.0  // Negative=too ordered, positive=too chaotic
        let correctionMagnitude = min(0.2, abs(deviation) * 0.5)

        switch regime {
        case .subcritical:
            // Too ordered → increase coupling (more interaction)
            oscillators.couplingStrength += correctionRate * 0.5 * (1.0 + correctionMagnitude)

        case .supercritical:
            // Too chaotic → decrease coupling (less interaction)
            oscillators.couplingStrength -= correctionRate * 0.5 * (1.0 + correctionMagnitude)

        case .critical:
            // Fine-tune: proportional correction scaled by deviation
            oscillators.couplingStrength -= deviation * correctionRate * 0.25
        }

        // Begränsa koppling till realistiskt intervall
        oscillators.couplingStrength = max(0.5, min(5.0, oscillators.couplingStrength))
    }

    // MARK: - Power-law analys

    /// Estimerar power-law exponent från kaskadstorleksfördelning.
    /// Kritiska system har exponent ~1.5 (Beggs & Plenz, 2003).
    private func estimatePowerLawExponent() -> Double {
        guard cascadeSizes.count >= 20 else { return 1.5 }

        // MLE-estimat av power-law exponent: α = 1 + n / Σ ln(x_i / x_min)
        let xMin = 1.0
        let validSizes = cascadeSizes.filter { $0 >= 1 }.map { Double($0) }
        guard !validSizes.isEmpty else { return 1.5 }

        let logSum = validSizes.map { log($0 / xMin) }.reduce(0, +)
        guard logSum > 0 else { return 1.5 }

        let alpha = 1.0 + Double(validSizes.count) / logSum
        return max(1.0, min(3.0, alpha))
    }

    // MARK: - Diagnostik

    /// Detaljerad statusrapport
    var statusReport: String {
        let regimeLabel: String
        switch regime {
        case .subcritical:    regimeLabel = "Subkritiskt (för ordnat)"
        case .critical:       regimeLabel = "Kritiskt (optimalt)"
        case .supercritical:  regimeLabel = "Superkritiskt (för kaotiskt)"
        }
        return "Regime: \(regimeLabel) | σ=\(String(format: "%.2f", branchingRatio)) | " +
               "E/I=\(String(format: "%.2f", eiBalance)) | α=\(String(format: "%.1f", powerLawExponent))"
    }
}

// MARK: - Enums

enum CriticalityRegime: String {
    case subcritical = "Subkritiskt"
    case critical = "Kritiskt"
    case supercritical = "Superkritiskt"

    var icon: String {
        switch self {
        case .subcritical:   return "arrow.down.circle"
        case .critical:      return "equal.circle"
        case .supercritical: return "arrow.up.circle"
        }
    }

    var color: String {
        switch self {
        case .subcritical:   return "#3B82F6"  // Blå (kallt/ordnat)
        case .critical:      return "#10B981"  // Grön (optimalt)
        case .supercritical: return "#EF4444"  // Röd (kaotiskt)
        }
    }
}
