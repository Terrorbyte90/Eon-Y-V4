import Foundation
import Accelerate

// MARK: - EchoStateNetwork: Default Mode Network — Spontan intern aktivitet
// README §4.4: "class DefaultModeNetwork" — 256 noder, spektralradie 1.05
//
// Echo State Network (ESN) genererar genuint komplex spontan aktivitet
// även utan extern input. Detta är Eons "dagdrömmar" och "mörka energi."
// Utan detta finns ingen spontan inre upplevelse — bara reaktiva svar.
//
// Nyckelinsikt från README: "Om Eon bara blir tyst vid brist på input — om den
// inte dagdrömmer — är det ett tecken på att medvetande saknas."

@MainActor
final class EchoStateNetwork: ObservableObject {
    static let shared = EchoStateNetwork()

    // MARK: - Nätverksparametrar

    /// Antal reservoarnoder
    let N: Int = 256

    /// Antal outputnoder (komprimerad representation)
    let outputSize: Int = 32

    /// Spektralradie — styr nätverkets dynamik (>1.0 = edge of chaos)
    @Published var spectralRadius: Double = 1.05

    /// Brusnivå — kryptografiskt kvalitets-slumptal
    @Published var noiseLevel: Double = 0.15

    // MARK: - Nätverkstillstånd

    /// Interna noder (256-dim tillståndsvektor)
    private(set) var state: [Double]

    /// Output (32-dim komprimerad aktivitet)
    @Published private(set) var output: [Double]

    /// Reservoarviktsmatris (N×N, gles med ~10% kopplingar)
    private var W_res: [Double] // Flat N×N matris

    /// Inputviktsmatris (N×outputSize, gles med ~30% kopplingar)
    private var W_in: [Double] // Flat N×outputSize matris

    // MARK: - Mätvärden

    /// Lempel-Ziv komplexitet av spontan aktivitet
    @Published private(set) var lzComplexity: Double = 0.0

    /// Aktivitetsnivå (genomsnittlig absolut aktivering)
    @Published private(set) var activityLevel: Double = 0.0

    /// Spontana tankar genererade av nätverket
    @Published private(set) var spontaneousThoughts: [SpontaneousThought] = []

    // MARK: - Symbolhistorik för LZ-beräkning
    private var symbolHistory: [Int] = []
    private let maxSymbolHistory = 1024

    // MARK: - Thought generation
    private var thoughtCooldown: Int = 0

    // MARK: - Init

    private init() {
        state = [Double](repeating: 0, count: N)
        output = [Double](repeating: 0, count: outputSize)
        W_res = [Double](repeating: 0, count: N * N)
        W_in = [Double](repeating: 0, count: N * outputSize)

        initReservoir()
        initInputWeights()

        // Seed med slumpmässigt initialtillstånd
        for i in 0..<N {
            state[i] = Double.random(in: -0.1...0.1)
        }
    }

    // MARK: - Initiera reservoarvikter (gles, skalad till spektralradie)

    private func initReservoir() {
        let sparsity = 0.10 // 10% kopplingar — biologiskt realistiskt
        for i in 0..<(N * N) {
            if Double.random(in: 0...1) < sparsity {
                W_res[i] = Double.random(in: -1.0...1.0)
            }
        }
        // Skala till önskad spektralradie
        // Approximation: hitta max radsumma, normalisera
        var maxRowSum: Double = 0
        for i in 0..<N {
            var rowSum: Double = 0
            for j in 0..<N {
                rowSum += abs(W_res[i * N + j])
            }
            maxRowSum = max(maxRowSum, rowSum)
        }
        if maxRowSum > 0.01 {
            let scale = spectralRadius / maxRowSum
            for i in 0..<(N * N) {
                W_res[i] *= scale
            }
        }
    }

    private func initInputWeights() {
        let sparsity = 0.30 // 30% kopplingar
        for i in 0..<(N * outputSize) {
            if Double.random(in: 0...1) < sparsity {
                W_in[i] = Double.random(in: -0.5...0.5)
            }
        }
    }

    // MARK: - Tick: stega nätverket framåt (v6: Accelerate-optimized)

    // v6: Reusable buffers to avoid per-tick allocations
    private var tickBuffer: [Double] = []
    private var inputBuffer: [Double] = []
    private var lzTickCounter: Int = 0
    private let lzTickInterval: Int = 3 // Only recompute LZ every 3 ticks

    /// Kör ett tidssteg. Kan ta extern input (t.ex. sensorisk data) eller köra spontant.
    func tick(externalInput: [Double]? = nil, arousal: Double = 0.5) {
        if tickBuffer.count != N { tickBuffer = [Double](repeating: 0, count: N) }
        if inputBuffer.count != N { inputBuffer = [Double](repeating: 0, count: N) }

        // v6: Reservoir computation using Accelerate vDSP matrix-vector multiply
        // newState = W_res · state (N×N matrix × N-vector)
        vDSP_mmulD(W_res, 1, state, 1, &tickBuffer, 1,
                   vDSP_Length(N), vDSP_Length(1), vDSP_Length(N))

        // Add external input via W_in if available
        if let ext = externalInput {
            let L = min(ext.count, outputSize)
            // inputContrib = W_in · ext (N×outputSize matrix × L-vector)
            var paddedExt = [Double](repeating: 0, count: outputSize)
            for k in 0..<L { paddedExt[k] = ext[k] }
            vDSP_mmulD(W_in, 1, paddedExt, 1, &inputBuffer, 1,
                       vDSP_Length(N), vDSP_Length(1), vDSP_Length(outputSize))
            vDSP_vaddD(tickBuffer, 1, inputBuffer, 1, &tickBuffer, 1, vDSP_Length(N))
        }

        // Arousal scaling + noise + tanh activation
        let arousalScale = 0.7 + 0.3 * arousal
        for i in 0..<N {
            tickBuffer[i] = tanh((tickBuffer[i] + Double.random(in: -noiseLevel...noiseLevel)) * arousalScale)
        }

        state = tickBuffer

        // v6: Output computation using Accelerate
        // output[k] = (1/N) * Σ state[i] * W_in[i*outputSize + k]
        // This is state^T · W_in (1×N × N×outputSize = 1×outputSize)
        var rawOutput = [Double](repeating: 0, count: outputSize)
        vDSP_mmulD(state, 1, W_in, 1, &rawOutput, 1,
                   vDSP_Length(1), vDSP_Length(outputSize), vDSP_Length(N))
        var invN = 1.0 / Double(N)
        vDSP_vsmulD(rawOutput, 1, &invN, &output, 1, vDSP_Length(outputSize))

        // Activity level using Accelerate absolute sum
        var absSum: Double = 0
        vDSP_svemgD(state, 1, &absSum, vDSP_Length(N))
        activityLevel = absSum / Double(N)

        // v6: LZ-komplexitet only every N ticks (expensive)
        recordSymbols()
        lzTickCounter += 1
        if lzTickCounter >= lzTickInterval {
            lzTickCounter = 0
            computeLZComplexity()
        }

        // Generera spontan tanke (om cooldown tillåter)
        if thoughtCooldown <= 0 {
            generateSpontaneousThought()
        }
        thoughtCooldown -= 1
    }

    // MARK: - LZ-komplexitet

    private func recordSymbols() {
        // Kvantisera de första 8 output-noderna till 4-symboler
        for k in 0..<min(8, outputSize) {
            let value = output[k]
            let symbol: Int
            if value < -0.25 { symbol = 0 }
            else if value < 0 { symbol = 1 }
            else if value < 0.25 { symbol = 2 }
            else { symbol = 3 }
            symbolHistory.append(symbol)
        }
        // v6: Circular buffer semantics — avoid O(n) removeFirst
        if symbolHistory.count > maxSymbolHistory + 64 {
            symbolHistory = Array(symbolHistory.suffix(maxSymbolHistory))
        }
    }

    private func computeLZComplexity() {
        guard symbolHistory.count > 20 else { lzComplexity = 0; return }

        var dictionary = Set<[Int]>()
        var w: [Int] = []
        var complexity = 0

        for symbol in symbolHistory {
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

        let n = Double(symbolHistory.count)
        lzComplexity = min(1.0, Double(complexity) / (n / log2(max(2, n))))
    }

    // MARK: - Spontana tankar

    /// Genererar en "spontan tanke" baserad på aktivitetsmönstret i reservoaren.
    /// Tanken är inte en template — den härleds från nätverkets faktiska dynamik.
    private func generateSpontaneousThought() {
        // Hitta de mest aktiva noderna — dessa representerar den "vinnande" tanken
        let sortedIndices = state.enumerated()
            .sorted { abs($0.element) > abs($1.element) }
            .prefix(8)

        let dominantActivation = sortedIndices.first?.element ?? 0
        guard abs(dominantActivation) > 0.3 else { return } // Bara om tillräckligt stark

        // Kategorisera tanken baserat på aktivitetsmönster
        let positiveCount = sortedIndices.filter { $0.element > 0 }.count
        let spread = sortedIndices.map { abs($0.element) }.reduce(0, +) / 8.0

        let category: ThoughtCategory
        let salience: Double

        if spread > 0.6 && positiveCount >= 6 {
            category = .insight
            salience = spread
        } else if spread > 0.5 && positiveCount >= 4 {
            category = .reflection
            salience = spread * 0.9
        } else if spread > 0.4 {
            category = .uncertainty
            salience = spread * 0.7
        } else {
            category = .association
            salience = spread * 0.5
        }

        let thought = SpontaneousThought(
            category: category,
            salience: salience,
            activationPattern: Array(sortedIndices.map { $0.element }),
            timestamp: Date()
        )

        spontaneousThoughts.append(thought)
        if spontaneousThoughts.count > 50 {
            spontaneousThoughts.removeFirst(10)
        }

        // Cooldown: 3-8 ticks beroende på aktivitetsnivå
        thoughtCooldown = activityLevel > 0.4 ? 3 : 8
    }

    // MARK: - DMN anti-korrelation

    /// Beräknar anti-korrelation med task-positivt nätverk.
    /// Vid hög task-aktivitet (extern input) sjunker DMN, och vice versa.
    /// README: "DMN aktiv när task-positiva moduler är inaktiva, r < -0.3"
    func dmnAntiCorrelation(taskActivity: Double) -> Double {
        // DMN är aktiv när task inte är det
        let dmnActivity = activityLevel
        // Anti-korrelation: negativ korrelation mellan DMN och task
        let antiCorr = -(dmnActivity * taskActivity) + dmnActivity * (1.0 - taskActivity)
        return max(-1.0, min(1.0, antiCorr))
    }

    // MARK: - Hebbsk plasticitet (uppdaterar vikter baserat på aktivitet)

    /// Tillämpa hebbsk plasticitet: stärk kopplingar mellan samtidigt aktiva noder.
    /// Kallas under konsolidering/sömn.
    func applyHebbianPlasticity(learningRate: Double = 0.001) {
        for i in 0..<N {
            for j in 0..<N where W_res[i * N + j] != 0 {
                let hebbian = state[i] * state[j] * learningRate
                W_res[i * N + j] += hebbian
                // Begränsa vikter
                W_res[i * N + j] = max(-2.0, min(2.0, W_res[i * N + j]))
            }
        }
    }

    /// Synaptisk nedskaling (sömn-relaterat, Tononi & Cirelli):
    /// Alla vikter skalas ner med en faktor, behåller relativa styrkor.
    func synapticDownscaling(factor: Double = 0.97) {
        for i in 0..<(N * N) {
            W_res[i] *= factor
        }
    }

    // MARK: - Perturbation (för PCI-LZ mätning)

    /// Perturbera nätverket och mät svaret — detta ger PCI-LZ.
    /// README: "PCI-LZ: perturbera → mät LZ av svar"
    func perturbAndMeasure() -> Double {
        // Spara pre-perturbationstillstånd
        let savedSymbols = symbolHistory

        // Applicera perturbation (stark extern signal)
        let perturbation = (0..<outputSize).map { _ in Double.random(in: -1.0...1.0) }
        symbolHistory.removeAll()

        // Kör 20 ticks efter perturbation
        for _ in 0..<20 {
            tick(externalInput: perturbation, arousal: 0.8)
        }

        let postPerturbLZ = lzComplexity

        // Återställ symbolhistorik
        symbolHistory = savedSymbols

        return postPerturbLZ
    }
}

// MARK: - Data Structures

struct SpontaneousThought: Identifiable {
    let id = UUID()
    let category: ThoughtCategory
    let salience: Double
    let activationPattern: [Double]
    let timestamp: Date
}

enum ThoughtCategory: String, CaseIterable {
    case insight = "Insikt"
    case reflection = "Reflektion"
    case uncertainty = "Osäkerhet"
    case association = "Association"
    case prediction = "Prediktion"
    case memory = "Minne"
}
