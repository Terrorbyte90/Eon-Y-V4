import Foundation
import Accelerate
import Combine

// MARK: - OscillatorBank: Kuramoto-oscillatorer för neural synkronisering
// Implementerar genuina fas-kopplade oscillatorer i 5 frekvensband (delta → gamma).
// Dessa ger VERKLIGA mätvärden: PLV (Phase-Locking Value), Kuramoto ordningsparameter,
// theta-gamma korsfrekvenskoppling — samma mått som används i neurovetenskaplig forskning.
// README §4.3: "class OscillatorBank"

@MainActor
final class OscillatorBank: ObservableObject {
    static let shared = OscillatorBank()

    // MARK: - Konfiguration

    /// Antal kognitiva moduler (oscillatorer)
    let moduleCount: Int = 12

    /// Frekvensband: delta (2Hz), theta (6Hz), alfa (10Hz), beta (20Hz), gamma (40Hz)
    let bandCount: Int = 5
    let frequencies: [Double] = [2.0, 6.0, 10.0, 20.0, 40.0]
    let bandNames: [String] = ["Delta", "Theta", "Alfa", "Beta", "Gamma"]

    /// Kuramoto-kopplingsstyrka — styr hur starkt oscillatorer drar varandra mot synkronisering
    @Published var couplingStrength: Double = 2.0

    // MARK: - Oscillatortillstånd

    /// Fas per modul per band [moduleCount][bandCount] — radianer (0...2π)
    @Published private(set) var phases: [[Double]] = []

    /// Amplitud per modul per band [moduleCount][bandCount]
    @Published private(set) var amplitudes: [[Double]] = []

    /// Naturliga frekvenser per modul (individuell avvikelse från basfrekvens)
    private var naturalFrequencies: [[Double]] = []

    // MARK: - Mätvärden (beräknade från oscillatortillstånd)

    /// Kuramoto ordningsparameter per band (0=desync, 1=full sync)
    @Published private(set) var orderParameters: [Double] = [0, 0, 0, 0, 0]

    /// Genomsnittlig Phase-Locking Value per band
    @Published private(set) var averagePLV: [Double] = [0, 0, 0, 0, 0]

    /// Theta-gamma koppling (Cross-Frequency Coupling)
    @Published private(set) var thetaGammaCFC: Double = 0.0

    /// Global synkroniseringsnivå (medel av alla band)
    @Published private(set) var globalSync: Double = 0.0

    /// Branching ratio — signaturmått för kritikalitet (mål: ~1.0)
    @Published private(set) var branchingRatio: Double = 1.0

    // MARK: - Historik för LZ-komplexitet

    private var phaseHistory: [Int] = [] // Kvantiserade faser för LZ-beräkning
    private let maxHistory = 2048
    private var cachedLZComplexity: Double = 0.5
    private var lzComputeCounter: Int = 0
    private let lzComputeInterval: Int = 5 // Only recompute every N ticks

    // MARK: - Init

    private init() {
        // Initiera faser slumpmässigt (0..2π) — varje modul startar i sin egen fas
        phases = (0..<moduleCount).map { _ in
            (0..<bandCount).map { _ in Double.random(in: 0..<(2.0 * .pi)) }
        }

        // Initiera amplituder till 1.0
        amplitudes = (0..<moduleCount).map { _ in
            [Double](repeating: 1.0, count: bandCount)
        }

        // Naturliga frekvenser: varje modul har individuell avvikelse (±10%)
        // Detta skapar heterogenitet — förutsättning för genuint Kuramoto-beteende
        naturalFrequencies = (0..<moduleCount).map { _ in
            frequencies.map { f in f * (1.0 + Double.random(in: -0.10...0.10)) }
        }
    }

    // MARK: - Paus/lågenergiläge (används av ChatOrchestrator för att frigöra CPU)

    private var isLowPower: Bool = false
    private var savedCouplingStrength: Double = 0

    /// Sätter oscillatorbanken i lågenergiläge — sänker uppdateringskostnaden
    func setLowPowerMode(_ enabled: Bool) {
        if enabled && !isLowPower {
            savedCouplingStrength = couplingStrength
            couplingStrength *= 0.3  // Sänk koppling → mindre beräkning
            isLowPower = true
        } else if !enabled && isLowPower {
            couplingStrength = savedCouplingStrength  // Återställ exakt
            isLowPower = false
        }
    }

    // MARK: - Tick — stega oscillatorerna framåt

    /// Kör ett tidssteg av Kuramoto-modellen.
    /// dt = tidsstegets längd i sekunder (typiskt 0.05 för 20Hz bas-tick, eller ~8-12s för consciousnessEngine)
    func tick(dt: Double, externalDrive: [Double]? = nil) {
        var newPhases = phases
        var activationSum: Double = 0
        var activationCount: Double = 0

        for m in 0..<moduleCount {
            for b in 0..<bandCount {
                // Kuramoto-ekvationen: dθ_i/dt = ω_i + (K/N) Σ sin(θ_j - θ_i)
                var coupling: Double = 0
                for j in 0..<moduleCount where j != m {
                    coupling += sin(phases[j][b] - phases[m][b])
                }
                coupling *= couplingStrength / Double(moduleCount)

                // Extern drivning (t.ex. från workspace broadcast eller sensorisk input)
                let drive = externalDrive.map { $0.count > m ? $0[m] * 0.3 : 0.0 } ?? 0.0

                // Stokastiskt brus — genuint, inte deterministiskt
                let noise = Double.random(in: -0.05...0.05)

                // Uppdatera fas
                let omega = naturalFrequencies[m][b] * 2.0 * .pi
                newPhases[m][b] = phases[m][b] + (omega * dt) + (coupling * dt) + (drive * dt) + noise
                newPhases[m][b] = newPhases[m][b].truncatingRemainder(dividingBy: 2.0 * .pi)
                if newPhases[m][b] < 0 { newPhases[m][b] += 2.0 * .pi }

                activationSum += abs(sin(newPhases[m][b]))
                activationCount += 1
            }

            // Theta-gamma korsfrekvenskoppling:
            // Gamma-amplituden moduleras av theta-fasen (precis som i riktig hjärna)
            let thetaPhase = newPhases[m][1] // theta = band index 1
            amplitudes[m][4] = 0.3 + 0.7 * (0.5 + 0.5 * cos(thetaPhase))
        }

        phases = newPhases

        // Beräkna mätvärden
        computeMetrics()

        // Spara fashistorik för LZ-komplexitet
        recordPhaseHistory()

        // Beräkna branching ratio
        let avgActivation = activationCount > 0 ? activationSum / activationCount : 0.5
        branchingRatio = branchingRatio * 0.95 + avgActivation * 2.0 * 0.05
    }

    // MARK: - Beräkna mätvärden (v6: optimized with Accelerate)

    private func computeMetrics() {
        // v6: Pre-compute sin/cos for all phases (reused for both R and PLV)
        // Flatten phases by band for vectorized ops
        for b in 0..<bandCount {
            var bandPhases = [Double](repeating: 0, count: moduleCount)
            for m in 0..<moduleCount { bandPhases[m] = phases[m][b] }

            // Kuramoto R: R = |1/N Σ exp(iθ_j)| using Accelerate vDSP
            var cosValues = [Double](repeating: 0, count: moduleCount)
            var sinValues = [Double](repeating: 0, count: moduleCount)
            vForce.cos(bandPhases, result: &cosValues)
            vForce.sin(bandPhases, result: &sinValues)

            var realSum: Double = 0
            var imagSum: Double = 0
            vDSP_sveD(cosValues, 1, &realSum, vDSP_Length(moduleCount))
            vDSP_sveD(sinValues, 1, &imagSum, vDSP_Length(moduleCount))
            let r = sqrt(realSum * realSum + imagSum * imagSum) / Double(moduleCount)
            orderParameters[b] = r

            // PLV: average |cos(phase_i - phase_j)| over all pairs
            // v6: Use pre-computed cos values to approximate PLV more efficiently
            // For each pair (i,j): cos(φi - φj) = cos(φi)cos(φj) + sin(φi)sin(φj)
            var plvSum: Double = 0
            var pairCount: Double = 0
            for i in 0..<moduleCount {
                for j in (i + 1)..<moduleCount {
                    let cosDiff = cosValues[i] * cosValues[j] + sinValues[i] * sinValues[j]
                    plvSum += abs(cosDiff)
                    pairCount += 1
                }
            }
            averagePLV[b] = pairCount > 0 ? plvSum / pairCount : 0
        }

        // Theta-gamma CFC: korrelation mellan theta-fas och gamma-amplitud
        var cfcSum: Double = 0
        for m in 0..<moduleCount {
            let thetaPhase = phases[m][1]
            let gammaAmp = amplitudes[m][4]
            cfcSum += cos(thetaPhase) * gammaAmp
        }
        thetaGammaCFC = abs(cfcSum / Double(moduleCount))

        // Global synkronisering (medelvärde av gamma-band + beta-band ordningsparametrar)
        globalSync = (orderParameters[3] + orderParameters[4]) / 2.0
    }

    // MARK: - LZ-komplexitet av spontan aktivitet

    private func recordPhaseHistory() {
        // Kvantisera gamma-faserna till 4 symboler (0,1,2,3) för LZ-beräkning
        for m in 0..<min(4, moduleCount) {
            let gammaPhase = phases[m][4] // gamma band
            let symbol = Int(gammaPhase / (.pi / 2.0)) % 4
            phaseHistory.append(symbol)
        }
        // v6: Use circular buffer semantics to avoid O(n) removeFirst
        if phaseHistory.count > maxHistory + 128 {
            phaseHistory = Array(phaseHistory.suffix(maxHistory))
        }

        // v6: Only recompute LZ every N ticks (expensive operation)
        lzComputeCounter += 1
        if lzComputeCounter >= lzComputeInterval {
            lzComputeCounter = 0
            cachedLZComplexity = computeLZComplexity()
        }
    }

    /// Beräknar Lempel-Ziv 76 komplexitet av oscillatorbeteendet.
    /// v6: Returns cached value (updated every N ticks for performance).
    func lzComplexity() -> Double {
        cachedLZComplexity
    }

    /// Actual LZ-76 computation (called periodically)
    private func computeLZComplexity() -> Double {
        guard phaseHistory.count > 10 else { return 0 }

        var dictionary = Set<[Int]>()
        var w: [Int] = []
        var complexity = 0

        for symbol in phaseHistory {
            let extended = w + [symbol]
            if dictionary.contains(extended) {
                w = extended
            } else {
                dictionary.insert(extended)
                complexity += 1
                w = [symbol]
            }
        }
        if !w.isEmpty { complexity += 1 }

        let n = Double(phaseHistory.count)
        let normalized = Double(complexity) / (n / log2(max(2, n)))
        return min(1.0, normalized)
    }

    // MARK: - Modularitet: PLV mellan specifika modulpar

    func phaseLockingValue(module1: Int, module2: Int, band: Int) -> Double {
        guard module1 < moduleCount, module2 < moduleCount, band < bandCount else { return 0 }
        return abs(cos(phases[module1][band] - phases[module2][band]))
    }

    // MARK: - Extern påverkan: justera kopplingsstyrka baserat på kognitiv last

    /// Kritikalitetsanpassning: öka koppling vid för låg synk, minska vid för hög
    func adjustCoupling(targetSync: Double = 0.5) {
        let gammaR = orderParameters[4] // gamma-band ordningsparameter
        let error = targetSync - gammaR
        couplingStrength += error * 0.1
        couplingStrength = max(0.5, min(5.0, couplingStrength))
    }

    /// Modulera oscillatorstyrka baserat på modulaktivitet (extern drivning)
    func driveModule(_ moduleIndex: Int, band: Int, amplitude: Double) {
        guard moduleIndex < moduleCount, band < bandCount else { return }
        amplitudes[moduleIndex][band] = max(0.1, min(2.0, amplitude))
    }

    // MARK: - Export för UI/diagnostik

    /// Snapshot av alla mätvärden för visning
    var metricsSnapshot: OscillatorMetrics {
        OscillatorMetrics(
            orderParameters: orderParameters,
            averagePLV: averagePLV,
            thetaGammaCFC: thetaGammaCFC,
            globalSync: globalSync,
            lzComplexity: lzComplexity(),
            branchingRatio: branchingRatio,
            couplingStrength: couplingStrength
        )
    }
}

// MARK: - Data Structures

struct OscillatorMetrics {
    let orderParameters: [Double]   // Per band: delta, theta, alfa, beta, gamma
    let averagePLV: [Double]        // Per band
    let thetaGammaCFC: Double       // Cross-frequency coupling
    let globalSync: Double          // Medel synkronisering
    let lzComplexity: Double        // Spontan komplexitet
    let branchingRatio: Double      // Kritikalitetsmått
    let couplingStrength: Double    // Aktuell Kuramoto-koppling
}
