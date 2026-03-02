import Foundation

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
// README: "Eon drivs av en nyfikenhetssignal — den söker aktivt upp situationer som
// maximerar informationsvinst. Den vill förstå sin värld, inte för att den programmerats
// att vilja det, utan för att det är matematiskt optimalt under Active Inference."

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

    /// Precision-weighted prediction errors: viktigare kanaler har högre precision
    private var precisionWeights: [String: Double] = [:]

    /// Surprise-ackumulator (för medvetandemetriker)
    @Published private(set) var surpriseAccumulator: Double = 0.0

    /// Brus-robusthet: hur bra klarar systemet brusiga inputs?
    @Published private(set) var noiseRobustness: Double = 0.75

    // MARK: - Historik
    private var predictionErrorHistory: [Double] = []
    private let maxHistory = 100

    // MARK: - Init

    private init() {
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

        // Initiera precision weights (hur viktiga olika kanaler är)
        precisionWeights = [
            "thermal": 0.8,    // Termiska signaler är pålitliga
            "memory": 0.6,     // Minnesåterkallning varierar
            "language": 0.7,   // Språkprocessering har viss osäkerhet
            "emotional": 0.5,  // Emotionella signaler är brusiga
            "cognitive": 0.7,  // Kognitiva processer är medelprecisa
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
        if predictions.count > 50 { predictions.removeFirst(10) }
        predictionsMade += 1

        // 2. JÄMFÖR: beräkna prediktionsfel (precision-viktat)
        let error = computePredictionError(predicted: prediction, actual: sensorInput)
        predictionErrors.append(error)
        if predictionErrors.count > maxHistory { predictionErrors.removeFirst() }

        // 3. Uppdatera free energy (glidande medelvärde)
        freeEnergy = freeEnergy * 0.85 + error * 0.15

        // 4. Uppdatera forward model accuracy
        let isAccurate = error < 0.3
        if isAccurate { correctPredictions += 1 }
        forwardModelAccuracy = predictionsMade > 0
            ? Double(correctPredictions) / Double(predictionsMade) : 0.5

        // 5. Beräkna epistemiskt värde (nyfikenhet)
        epistemicValue = computeEpistemicValue(recentErrors: predictionErrors)

        // 6. Beräkna pragmatiskt värde
        pragmaticValue = computePragmaticValue(cognitiveState: cognitiveState)

        // 7. Expected Free Energy = epistemiskt + pragmatiskt värde
        expectedFreeEnergy = 0.6 * epistemicValue + 0.4 * pragmaticValue

        // 8. Bayesiansk trosuppdatering
        updateBeliefs(error: error, sensorInput: sensorInput)

        // 9. Surprise
        surpriseAccumulator = surpriseAccumulator * 0.9 + error * 0.1

        // 10. Brus-robusthet (mäter variation i prediktioner)
        if predictionErrorHistory.count >= 10 {
            let recent = Array(predictionErrors.suffix(10))
            let mean = recent.reduce(0, +) / Double(recent.count)
            let variance = recent.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recent.count)
            noiseRobustness = max(0.3, min(0.99, 1.0 - sqrt(variance) * 2.0))
        }

        predictionErrorHistory.append(error)
        if predictionErrorHistory.count > maxHistory { predictionErrorHistory.removeFirst() }
    }

    // MARK: - Generera prediktion

    private func generatePrediction(from cogState: CognitiveSnapshot) -> Prediction {
        // Prediktion baserad på nuvarande beliefs och kognitiv state:
        // Om kognitiv last är hög → förvänta ökad termisk stress
        let predictedThermalDelta = cogState.cognitiveLoad * 0.3
        // Om det finns aktiv konversation → förvänta memory retrieval
        let predictedMemoryActivity = cogState.isConversationActive ? 0.7 : 0.2
        // Om inlärning pågår → förvänta ökad knowledge dimension
        let predictedLearningDelta = cogState.learningMomentum * 0.1
        // Generell prediktionsriktning baserad på trender
        let predictedIIDelta = cogState.growthVelocity * 60.0 // Per minut → per timme approx

        return Prediction(
            predictedThermalChange: predictedThermalDelta,
            predictedMemoryActivity: predictedMemoryActivity,
            predictedLearningGain: predictedLearningDelta,
            predictedIIChange: predictedIIDelta,
            confidence: forwardModelAccuracy,
            timestamp: Date()
        )
    }

    // MARK: - Beräkna prediktionsfel

    private func computePredictionError(predicted: Prediction, actual: SensorSnapshot) -> Double {
        // Precision-viktat prediktionsfel per kanal
        var totalError: Double = 0
        var totalPrecision: Double = 0

        // Termisk kanal
        let thermalError = abs(predicted.predictedThermalChange - actual.thermalDelta)
        let thermalPrecision = precisionWeights["thermal"] ?? 0.5
        totalError += thermalError * thermalPrecision
        totalPrecision += thermalPrecision

        // Kognitiv kanal
        let cogError = abs(predicted.predictedMemoryActivity - actual.memoryActivity)
        let cogPrecision = precisionWeights["cognitive"] ?? 0.5
        totalError += cogError * cogPrecision
        totalPrecision += cogPrecision

        // Inlärningskanal
        let learnError = abs(predicted.predictedLearningGain - actual.learningActivity)
        let learnPrecision = precisionWeights["memory"] ?? 0.5
        totalError += learnError * learnPrecision
        totalPrecision += learnPrecision

        // Normalisera
        return totalPrecision > 0 ? min(1.0, totalError / totalPrecision) : 0.5
    }

    // MARK: - Epistemiskt värde (nyfikenhet)

    /// Epistemiskt värde: hur mycket ny information kan vinnas?
    /// Högt när prediktionsfelen varierar (= osäkerhet), lågt när de är stabila.
    private func computeEpistemicValue(recentErrors: [Double]) -> Double {
        guard recentErrors.count >= 5 else { return 0.5 }

        let recent = Array(recentErrors.suffix(20))
        let mean = recent.reduce(0, +) / Double(recent.count)
        let variance = recent.map { pow($0 - mean, 2) }.reduce(0, +) / Double(recent.count)

        // Hög varians = hög epistemic value (mycket att lära)
        // Låg varians + högt medelvärde = konsekvent dålig modell (behöver revision)
        // Låg varians + lågt medelvärde = bra modell (lite att lära)
        let curiosity = sqrt(variance) * 2.0 + mean * 0.5
        return max(0.1, min(0.95, curiosity))
    }

    // MARK: - Pragmatiskt värde

    private func computePragmaticValue(cognitiveState: CognitiveSnapshot) -> Double {
        // Pragmatiskt värde: hur väl uppnår systemet sina mål?
        // Hög II-tillväxt = högt pragmatiskt värde
        let growthBonus = max(0, cognitiveState.growthVelocity * 100)
        let knowledgeBonus = min(0.3, Double(cognitiveState.knowledgeCount) / 1000.0)
        return max(0.1, min(0.95, 0.3 + growthBonus + knowledgeBonus))
    }

    // MARK: - Bayesiansk belief-uppdatering

    private func updateBeliefs(error: Double, sensorInput: SensorSnapshot) {
        for i in 0..<beliefs.count {
            // Bayesiansk uppdatering: P(belief|evidence) ∝ P(evidence|belief) × P(belief)
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

        // Uppdatera precision weights baserat på prediktionsnoggrannhet per kanal
        if error < 0.2 {
            // Bra prediktion → öka precision
            for key in precisionWeights.keys {
                precisionWeights[key] = min(0.95, (precisionWeights[key] ?? 0.5) * 1.01)
            }
        } else if error > 0.5 {
            // Dålig prediktion → minska precision (mer osäkerhet)
            for key in precisionWeights.keys {
                precisionWeights[key] = max(0.2, (precisionWeights[key] ?? 0.5) * 0.99)
            }
        }
    }

    // MARK: - Surprise-detektion

    /// Returnerar true om systemet är genuint "överraskat" (hög prediktionsfel)
    var isSurprised: Bool {
        guard predictionErrors.count >= 3 else { return false }
        let lastThree = Array(predictionErrors.suffix(3))
        let mean = lastThree.reduce(0, +) / 3.0
        return mean > 0.5
    }

    /// Strength of surprise (0-1)
    var surpriseStrength: Double {
        guard let lastError = predictionErrors.last else { return 0 }
        return min(1.0, max(0, (lastError - 0.3) * 2.5))
    }

    // MARK: - Export prediktionsstatus

    var predictionSummary: String {
        let accuracy = String(format: "%.0f%%", forwardModelAccuracy * 100)
        let fe = String(format: "%.2f", freeEnergy)
        let curiosity = String(format: "%.2f", epistemicValue)
        return "Forward model: \(accuracy) | Free energy: \(fe) | Curiosity: \(curiosity)"
    }
}

// MARK: - Data Structures

struct Prediction: Identifiable {
    let id = UUID()
    let predictedThermalChange: Double
    let predictedMemoryActivity: Double
    let predictedLearningGain: Double
    let predictedIIChange: Double
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
}

/// Snapshot av kognitivt tillstånd (för att generera prediktioner)
struct CognitiveSnapshot {
    let cognitiveLoad: Double
    let isConversationActive: Bool
    let learningMomentum: Double
    let growthVelocity: Double
    let knowledgeCount: Int
}
