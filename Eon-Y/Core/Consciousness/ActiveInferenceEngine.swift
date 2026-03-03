import Foundation
import Accelerate

// MARK: - ActiveInferenceEngine: Prediktiv Processing & Fri Energiminimering
// README §1.3 Teori 4: "Din hjärna gissar hela tiden... Medvetande uppstår ur
// ständig prediktion och korrigering."
//
// Implementerar Karl Fristons Active Inference framework:
// 1. Generativ modell: förutsäger nästa sensoriska input
// 2. Prediktionsfel: skillnaden mellan prediktion och verklighet driver all inlärning
// 3. Fri energi: variational free energy som systemet minimerar
// 4. Nyfikenhetssignal: epistemic value — söker information som minskar osäkerhet
// 5. Forward model: förutsäger konsekvenser av handlingar
//
// v7: Enum-based precision channels, Accelerate-optimized statistics,
//     circular buffer for prediction history, adaptive precision learning per channel.

// MARK: - Precision Channel (replaces String dictionary)
enum PrecisionChannel: Int, CaseIterable {
    case thermal = 0    // Termiska signaler
    case cognitive = 1  // Kognitiva processer
    case memory = 2     // Minnesåterkallning
    case language = 3   // Språkprocessering
    case emotional = 4  // Emotionella signaler

    var initialPrecision: Double {
        switch self {
        case .thermal:   return 0.8
        case .cognitive:  return 0.7
        case .memory:     return 0.6
        case .language:   return 0.7
        case .emotional:  return 0.5
        }
    }

    var label: String {
        switch self {
        case .thermal:   return "Termisk"
        case .cognitive:  return "Kognitiv"
        case .memory:     return "Minne"
        case .language:   return "Språk"
        case .emotional:  return "Emotionell"
        }
    }
}

@MainActor
final class ActiveInferenceEngine: ObservableObject {
    static let shared = ActiveInferenceEngine()

    // MARK: - Generativ modell (prediktioner)

    /// Senaste prediktioner: vad systemet förväntar sig härnäst
    @Published private(set) var predictions: [Prediction] = []

    /// Prediktionsfel: skillnaden mellan förväntat och verkligt
    @Published private(set) var predictionErrors: [Double] = []

    /// Genomsnittligt prediktionsfel (= free energy proxy)
    @Published private(set) var freeEnergy: Double = 0.5

    /// Nyfikenhetssignal: epistemiskt värde — hur mycket ny information finns att hämta
    @Published private(set) var epistemicValue: Double = 0.5

    /// Pragmatiskt värde: hur mycket måluppfyllelse handlingar ger
    @Published private(set) var pragmaticValue: Double = 0.5

    /// Expected Free Energy: kombinerat mått som driver handlingsval
    @Published private(set) var expectedFreeEnergy: Double = 0.5

    /// Forward model accuracy: hur bra är systemets prediktioner?
    @Published private(set) var forwardModelAccuracy: Double = 0.5

    /// Total antal prediktioner som gjorts
    @Published private(set) var predictionsMade: Int = 0

    /// Antal korrekta prediktioner (inom tolerans)
    private var correctPredictions: Int = 0

    // MARK: - Intern modellstatus

    /// Beliefs: systemets nuvarande tro om världens tillstånd
    @Published private(set) var beliefs: [Belief] = []

    /// v7: Enum-based precision weights (replaces String dictionary)
    private var precisionWeights: [Double]  // Indexed by PrecisionChannel.rawValue

    /// Per-channel error accumulators for adaptive precision learning
    private var channelErrorAccumulators: [Double]  // Same indexing

    /// Surprise-ackumulator (för medvetandemetriker)
    @Published private(set) var surpriseAccumulator: Double = 0.0

    /// Brus-robusthet: hur bra klarar systemet brusiga inputs?
    @Published private(set) var noiseRobustness: Double = 0.75

    // MARK: - Historik (circular buffers — avoid O(n) removeFirst)
    private var errorHistory: [Double]      // Circular buffer
    private var errorHistoryIndex: Int = 0
    private var errorHistoryCount: Int = 0
    private let maxHistory = 100

    /// v7: Reusable buffer for Accelerate statistics
    private var statBuffer: [Double]

    // MARK: - Init

    private init() {
        // v7: Pre-allocate all buffers
        precisionWeights = PrecisionChannel.allCases.map { $0.initialPrecision }
        channelErrorAccumulators = [Double](repeating: 0, count: PrecisionChannel.allCases.count)
        errorHistory = [Double](repeating: 0, count: maxHistory)
        statBuffer = [Double](repeating: 0, count: 20)

        // Initiera basbeliefs
        beliefs = [
            Belief(id: "thermal", description: "Termisk stress stiger vid beräkningsintensivt arbete",
                   confidence: 0.8, evidence: 5),
            Belief(id: "conversation", description: "Användaren ställer frågor som kräver kunskap",
                   confidence: 0.6, evidence: 2),
            Belief(id: "learning", description: "Ny kunskap kräver tid att konsolidera",
                   confidence: 0.9, evidence: 10),
            Belief(id: "autonomy", description: "Autonom drift bygger kunskap snabbare",
                   confidence: 0.7, evidence: 3),
        ]
    }

    // MARK: - Huvudtick: prediktera → jämför → uppdatera

    /// Kör en cykel av prediktiv processing.
    /// - sensorInput: verkligt sensoriskt tillstånd (kroppsbudget etc.)
    /// - cognitiveState: aktuellt kognitivt tillstånd
    func tick(sensorInput: SensorSnapshot, cognitiveState: CognitiveSnapshot) {
        // 1. PREDIKTERA: vad förväntar vi oss?
        let prediction = generatePrediction(from: cognitiveState)
        predictions.append(prediction)
        // v7: Batch trim to avoid frequent small removals
        if predictions.count > 60 { predictions.removeFirst(20) }
        predictionsMade += 1

        // 2. JÄMFÖR: beräkna prediktionsfel (precision-viktat)
        let (error, channelErrors) = computePredictionError(predicted: prediction, actual: sensorInput)
        predictionErrors.append(error)
        if predictionErrors.count > maxHistory { predictionErrors.removeFirst() }

        // 3. Uppdatera free energy (glidande medelvärde)
        freeEnergy = freeEnergy * 0.85 + error * 0.15

        // 4. Uppdatera forward model accuracy
        let isAccurate = error < 0.3
        if isAccurate { correctPredictions += 1 }
        forwardModelAccuracy = predictionsMade > 0
            ? Double(correctPredictions) / Double(predictionsMade) : 0.5

        // 5. Beräkna epistemiskt värde (nyfikenhet) — uses Accelerate
        epistemicValue = computeEpistemicValue()

        // 6. Beräkna pragmatiskt värde
        pragmaticValue = computePragmaticValue(cognitiveState: cognitiveState)

        // 7. Expected Free Energy = epistemiskt + pragmatiskt värde
        expectedFreeEnergy = 0.6 * epistemicValue + 0.4 * pragmaticValue

        // 8. Bayesiansk trosuppdatering
        updateBeliefs(error: error, sensorInput: sensorInput)

        // 9. v7: Adaptive precision learning per channel
        updatePrecisionWeights(channelErrors: channelErrors, overallError: error)

        // 10. Surprise
        surpriseAccumulator = surpriseAccumulator * 0.9 + error * 0.1

        // 11. Brus-robusthet — uses circular buffer
        errorHistory[errorHistoryIndex] = error
        errorHistoryIndex = (errorHistoryIndex + 1) % maxHistory
        errorHistoryCount = min(errorHistoryCount + 1, maxHistory)
        if errorHistoryCount >= 10 {
            noiseRobustness = computeNoiseRobustness()
        }
    }

    // MARK: - Generera prediktion

    private func generatePrediction(from cogState: CognitiveSnapshot) -> Prediction {
        // v7: Prediction informed by current beliefs, not just cognitive state
        let thermalBelief = beliefs.first(where: { $0.id == "thermal" })?.confidence ?? 0.5
        let conversationBelief = beliefs.first(where: { $0.id == "conversation" })?.confidence ?? 0.5

        // Om kognitiv last är hög → förvänta ökad termisk stress (scaled by belief)
        let predictedThermalDelta = cogState.cognitiveLoad * 0.3 * thermalBelief
        // Om det finns aktiv konversation → förvänta memory retrieval
        let predictedMemoryActivity = cogState.isConversationActive
            ? 0.4 + conversationBelief * 0.4  // 0.4-0.8 based on conversation belief
            : 0.1 + conversationBelief * 0.1  // 0.1-0.2
        // Om inlärning pågår → förvänta ökad knowledge dimension
        let predictedLearningDelta = cogState.learningMomentum * 0.1
        // Generell prediktionsriktning baserad på trender
        let predictedIIDelta = cogState.growthVelocity * 60.0

        // v9: Language activity prediction — active conversation → high language activity
        let predictedLangActivity = cogState.isConversationActive
            ? 0.5 + cogState.languageDimension * 0.4
            : 0.1 + cogState.languageDimension * 0.2

        // v9: Emotional shift prediction — learning → positive, high load → negative
        let predictedEmoShift = cogState.learningMomentum * 0.3 - cogState.cognitiveLoad * 0.2

        return Prediction(
            predictedThermalChange: predictedThermalDelta,
            predictedMemoryActivity: predictedMemoryActivity,
            predictedLearningGain: predictedLearningDelta,
            predictedIIChange: predictedIIDelta,
            predictedLanguageActivity: predictedLangActivity,
            predictedEmotionalShift: predictedEmoShift,
            confidence: forwardModelAccuracy,
            timestamp: Date()
        )
    }

    // MARK: - Beräkna prediktionsfel

    /// v9: Returns both overall error and per-channel errors for adaptive learning
    /// Now uses all 5 precision channels including language and emotional
    private func computePredictionError(predicted: Prediction, actual: SensorSnapshot) -> (Double, [Double]) {
        var totalError: Double = 0
        var totalPrecision: Double = 0
        var channelErrors = [Double](repeating: 0, count: PrecisionChannel.allCases.count)

        // Termisk kanal
        let thermalError = abs(predicted.predictedThermalChange - actual.thermalDelta)
        let thermalPrecision = precisionWeights[PrecisionChannel.thermal.rawValue]
        totalError += thermalError * thermalPrecision
        totalPrecision += thermalPrecision
        channelErrors[PrecisionChannel.thermal.rawValue] = thermalError

        // Kognitiv kanal
        let cogError = abs(predicted.predictedMemoryActivity - actual.memoryActivity)
        let cogPrecision = precisionWeights[PrecisionChannel.cognitive.rawValue]
        totalError += cogError * cogPrecision
        totalPrecision += cogPrecision
        channelErrors[PrecisionChannel.cognitive.rawValue] = cogError

        // Minneskanal
        let learnError = abs(predicted.predictedLearningGain - actual.learningActivity)
        let learnPrecision = precisionWeights[PrecisionChannel.memory.rawValue]
        totalError += learnError * learnPrecision
        totalPrecision += learnPrecision
        channelErrors[PrecisionChannel.memory.rawValue] = learnError

        // v9: Språkkanal — predikterar språklig aktivitet
        let langError = abs(predicted.predictedLanguageActivity - actual.languageActivity)
        let langPrecision = precisionWeights[PrecisionChannel.language.rawValue]
        totalError += langError * langPrecision
        totalPrecision += langPrecision
        channelErrors[PrecisionChannel.language.rawValue] = langError

        // v9: Emotionell kanal — predikterar valensförändring
        let emoError = abs(predicted.predictedEmotionalShift - actual.emotionalShift)
        let emoPrecision = precisionWeights[PrecisionChannel.emotional.rawValue]
        totalError += emoError * emoPrecision
        totalPrecision += emoPrecision
        channelErrors[PrecisionChannel.emotional.rawValue] = emoError

        // Normalisera
        let normalizedError = totalPrecision > 0 ? min(1.0, totalError / totalPrecision) : 0.5
        return (normalizedError, channelErrors)
    }

    // MARK: - Epistemiskt värde (nyfikenhet) — Accelerate-optimized

    /// v7: Uses Accelerate vDSP for mean/variance computation on circular buffer
    private func computeEpistemicValue() -> Double {
        guard errorHistoryCount >= 5 else { return 0.5 }

        // Use the most recent entries from circular buffer
        let n = min(20, errorHistoryCount)
        // Copy recent values into contiguous buffer
        for i in 0..<n {
            let idx = (errorHistoryIndex - n + i + maxHistory) % maxHistory
            statBuffer[i] = errorHistory[idx]
        }

        // Accelerate: compute mean
        var mean: Double = 0
        vDSP_meanvD(statBuffer, 1, &mean, vDSP_Length(n))

        // Accelerate: compute mean square
        var meanSq: Double = 0
        vDSP_measqvD(statBuffer, 1, &meanSq, vDSP_Length(n))

        // Variance = E[X²] - E[X]²
        let variance = max(0, meanSq - mean * mean)

        // Hög varians = hög epistemic value (mycket att lära)
        let curiosity = sqrt(variance) * 2.0 + mean * 0.5
        return max(0.1, min(0.95, curiosity))
    }

    // MARK: - Pragmatiskt värde

    private func computePragmaticValue(cognitiveState: CognitiveSnapshot) -> Double {
        let growthBonus = max(0, cognitiveState.growthVelocity * 100)
        let knowledgeBonus = min(0.3, Double(cognitiveState.knowledgeCount) / 1000.0)
        return max(0.1, min(0.95, 0.3 + growthBonus + knowledgeBonus))
    }

    // MARK: - Bayesiansk belief-uppdatering

    private func updateBeliefs(error: Double, sensorInput: SensorSnapshot) {
        for i in 0..<beliefs.count {
            let prior = beliefs[i].confidence
            let likelihoodRatio: Double

            switch beliefs[i].id {
            case "thermal":
                likelihoodRatio = sensorInput.thermalDelta > 0.1 ? 1.1 : 0.95
            case "conversation":
                likelihoodRatio = sensorInput.memoryActivity > 0.5 ? 1.15 : 0.90
            case "learning":
                likelihoodRatio = sensorInput.learningActivity > 0.1 ? 1.05 : 0.98
            case "autonomy":
                likelihoodRatio = error < 0.3 ? 1.08 : 0.95
            default:
                likelihoodRatio = 1.0
            }

            let posterior = prior * likelihoodRatio
            beliefs[i].confidence = max(0.01, min(0.99, posterior))
            beliefs[i].evidence += 1
        }
    }

    // MARK: - v7: Adaptive Precision Learning (per-channel)
    // Each channel's precision adjusts independently based on its own prediction accuracy.
    // Channels that predict well get higher precision (more trusted).
    // Channels that predict poorly get lower precision (less trusted).

    private func updatePrecisionWeights(channelErrors: [Double], overallError: Double) {
        for channel in PrecisionChannel.allCases {
            let idx = channel.rawValue
            let channelError = channelErrors[idx]

            // Exponential moving average of channel error
            channelErrorAccumulators[idx] = channelErrorAccumulators[idx] * 0.9 + channelError * 0.1

            // Precision ∝ 1 / accumulated_error — channels with low errors get high precision
            let accError = channelErrorAccumulators[idx]
            if accError < 0.15 {
                // Very accurate channel → increase precision
                precisionWeights[idx] = min(0.95, precisionWeights[idx] * 1.005)
            } else if accError > 0.4 {
                // Poor channel → decrease precision
                precisionWeights[idx] = max(0.15, precisionWeights[idx] * 0.995)
            }
            // Middle range: no change (stable)
        }
    }

    // MARK: - Noise Robustness (Accelerate-optimized)

    private func computeNoiseRobustness() -> Double {
        let n = min(10, errorHistoryCount)
        for i in 0..<n {
            let idx = (errorHistoryIndex - n + i + maxHistory) % maxHistory
            statBuffer[i] = errorHistory[idx]
        }

        var mean: Double = 0
        vDSP_meanvD(statBuffer, 1, &mean, vDSP_Length(n))
        var meanSq: Double = 0
        vDSP_measqvD(statBuffer, 1, &meanSq, vDSP_Length(n))
        let variance = max(0, meanSq - mean * mean)

        return max(0.3, min(0.99, 1.0 - sqrt(variance) * 2.0))
    }

    // MARK: - Surprise-detektion

    /// Returnerar true om systemet är genuint "överraskat" (hög prediktionsfel)
    var isSurprised: Bool {
        guard errorHistoryCount >= 3 else { return false }
        // Check last 3 entries from circular buffer
        var sum: Double = 0
        for i in 0..<3 {
            let idx = (errorHistoryIndex - 3 + i + maxHistory) % maxHistory
            sum += errorHistory[idx]
        }
        return (sum / 3.0) > 0.5
    }

    /// Strength of surprise (0-1)
    var surpriseStrength: Double {
        guard errorHistoryCount > 0 else { return 0 }
        let lastIdx = (errorHistoryIndex - 1 + maxHistory) % maxHistory
        let lastError = errorHistory[lastIdx]
        return min(1.0, max(0, (lastError - 0.3) * 2.5))
    }

    // MARK: - Export prediktionsstatus

    var predictionSummary: String {
        let accuracy = String(format: "%.0f%%", forwardModelAccuracy * 100)
        let fe = String(format: "%.2f", freeEnergy)
        let curiosity = String(format: "%.2f", epistemicValue)
        return "Forward model: \(accuracy) | Free energy: \(fe) | Curiosity: \(curiosity)"
    }

    /// v7: Precision status per channel
    var precisionSummary: String {
        PrecisionChannel.allCases.map { ch in
            "\(ch.label): \(String(format: "%.0f%%", precisionWeights[ch.rawValue] * 100))"
        }.joined(separator: " | ")
    }
}

// MARK: - Data Structures

struct Prediction: Identifiable {
    let id = UUID()
    let predictedThermalChange: Double
    let predictedMemoryActivity: Double
    let predictedLearningGain: Double
    let predictedIIChange: Double
    // v9: Language and emotional prediction channels
    let predictedLanguageActivity: Double
    let predictedEmotionalShift: Double
    let confidence: Double
    let timestamp: Date
}

struct Belief: Identifiable {
    let id: String
    let description: String
    var confidence: Double  // 0-1, Bayesiansk posterior
    var evidence: Int       // Antal observationer
}

/// Snapshot av sensoriskt tillstånd (verkligt, för jämförelse med prediktion)
struct SensorSnapshot {
    let thermalDelta: Double     // Förändring i termisk stress
    let memoryActivity: Double   // Minnesaktivitet (0-1)
    let learningActivity: Double // Inlärningsaktivitet (0-1)
    let cognitiveLoad: Double    // Kognitiv belastning (0-1)
    // v9: Language and emotional sensor channels
    var languageActivity: Double = 0.3   // Språkprocesseringsaktivitet (0-1)
    var emotionalShift: Double = 0.0     // Emotionell valensförändring (-1 till 1)
}

/// Snapshot av kognitivt tillstånd (för att generera prediktioner)
struct CognitiveSnapshot {
    let cognitiveLoad: Double
    let isConversationActive: Bool
    let learningMomentum: Double
    let growthVelocity: Double
    let knowledgeCount: Int
    // v9: Additional cognitive state
    var languageDimension: Double = 0.5    // Språkdimension nivå
    var emotionalValence: Double = 0.0     // Aktuell emotionell valens
}
