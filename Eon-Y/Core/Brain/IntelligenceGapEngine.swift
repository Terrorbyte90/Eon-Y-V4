import Foundation
import NaturalLanguage

// MARK: - IntelligenceGapEngine
// Eons aktiva kartläggning och eliminering av intelligens-luckor.
// Identifierar kontinuerligt var Eon är svag, varför, och vad som behöver göras.
// Prioriterar luckor baserat på kausal påverkan — en svag metakognition
// blockerar t.ex. 4 andra dimensioner och är därför mer brådskande.
// Genererar och kör riktade "träningspass" för varje lucka.

actor IntelligenceGapEngine {
    static let shared = IntelligenceGapEngine()

    private var gapHistory: [GapAnalysis] = []
    private var activeInterventions: [GapIntervention] = []
    private var interventionResults: [InterventionResult] = []
    private var totalInterventions: Int = 0

    private init() {}

    // MARK: - Huvud-analyscykel

    func analyzeAndIntervene() async -> GapAnalysis {
        let state = await CognitiveState.shared

        // 1. Identifiera alla luckor
        let gaps = await identifyGaps(state: state)

        // 2. Prioritera baserat på kausal påverkan
        let prioritized = prioritize(gaps: gaps, influences: await state.causalInfluences)

        // 3. Välj top-3 luckor att arbeta med
        let topGaps = Array(prioritized.prefix(3))

        // 4. Generera interventioner
        var interventions: [GapIntervention] = []
        for gap in topGaps {
            let intervention = await generateIntervention(for: gap, state: state)
            interventions.append(intervention)
            activeInterventions.append(intervention)
        }

        // 5. Kör interventioner
        var results: [InterventionResult] = []
        for intervention in interventions {
            let result = await executeIntervention(intervention, state: state)
            results.append(result)
            interventionResults.append(result)
            totalInterventions += 1

            // Uppdatera CognitiveState med resultatet
            await state.update(
                dimension: intervention.targetDimension,
                delta: result.improvementDelta,
                source: "gap_engine"
            )
        }

        let analysis = GapAnalysis(
            gaps: gaps,
            prioritizedGaps: topGaps,
            interventions: interventions,
            results: results,
            timestamp: Date()
        )

        gapHistory.append(analysis)
        if gapHistory.count > 100 { gapHistory.removeFirst(20) }

        // Uppdatera urgent gap i state
        let capturedGaps = gaps
        let capturedUrgent = topGaps.first
        await MainActor.run {
            state.intelligenceGaps = capturedGaps
            if let mostUrgent = capturedUrgent {
                state.urgentGap = mostUrgent
            }
        }

        return analysis
    }

    // MARK: - Identifiera luckor

    private func identifyGaps(state: CognitiveState) async -> [IntelligenceGap] {
        var gaps: [IntelligenceGap] = []
        let dimensions = await state.dimensions
        let influences = await state.causalInfluences

        for (dim, level) in dimensions {
            guard level < 0.75 else { continue }  // Bara dimensioner under 75%

            // Beräkna hur många dimensioner denna blockerar
            let blockedBy = influences.filter { $0.from == dim && $0.strength > 0.25 }
            let blockedDims = blockedBy.map { $0.to }

            // Beräkna urgency: gap-storlek × antal blockerade × genomsnittlig styrka
            let gapSize = 0.75 - level
            let blockingPower = blockedBy.map { $0.strength }.reduce(0, +)
            let urgency = gapSize * (1.0 + blockingPower) * Double(blockedDims.count + 1)

            // Beräkna trend (används för framtida analys)
            _ = await state.dimensionTrend(dim)

            // Bara inkludera om det är en verklig lucka (inte bara låg)
            if urgency > 0.1 {
                gaps.append(IntelligenceGap(
                    dimension: dim,
                    currentLevel: level,
                    targetLevel: min(0.99, level + calculateTargetDelta(level: level, urgency: urgency)),
                    urgency: urgency,
                    blockedDimensions: blockedDims,
                    suggestedActions: await state.generateActions(for: dim, level: level)
                ))
            }
        }

        return gaps.sorted { $0.urgency > $1.urgency }
    }

    private func calculateTargetDelta(level: Double, urgency: Double) -> Double {
        // Aggressivare mål för kritiska luckor
        if urgency > 3.0 { return 0.25 }
        if urgency > 2.0 { return 0.20 }
        if urgency > 1.0 { return 0.15 }
        return 0.10
    }

    // MARK: - Prioritering (kausal påverkan)

    private func prioritize(gaps: [IntelligenceGap], influences: [CausalInfluence]) -> [IntelligenceGap] {
        // Beräkna "total kausal vikt" — hur mycket förbättring av denna lucka
        // propagerar till andra dimensioner
        return gaps.sorted { a, b in
            let weightA = a.urgency * Double(a.blockedDimensions.count + 1)
            let weightB = b.urgency * Double(b.blockedDimensions.count + 1)
            return weightA > weightB
        }
    }

    // MARK: - Generera intervention

    private func generateIntervention(for gap: IntelligenceGap, state: CognitiveState) async -> GapIntervention {
        let strategy = selectStrategy(for: gap)
        let exercises = generateExercises(for: gap.dimension, strategy: strategy)

        return GapIntervention(
            targetDimension: gap.dimension,
            strategy: strategy,
            exercises: exercises,
            estimatedImprovement: gap.gapSize * 0.15,
            priority: gap.urgency > 2.0 ? .high : gap.urgency > 1.0 ? .medium : .low
        )
    }

    private func selectStrategy(for gap: IntelligenceGap) -> InterventionStrategy {
        switch gap.dimension {
        case .reasoning, .causality:
            return .activeReasoning
        case .metacognition, .selfAwareness:
            return .deepReflection
        case .learning, .knowledge:
            return .knowledgeAcquisition
        case .creativity, .hypothesisGeneration:
            return .creativeExploration
        case .language, .comprehension, .communication:
            return .linguisticPractice
        case .worldModel, .prediction:
            return .modelBuilding
        case .analogyBuilding:
            return .analogyPractice
        case .adaptivity:
            return .adaptiveChallenge
        default:
            return .generalPractice
        }
    }

    private func generateExercises(for dimension: CognitiveDimension, strategy: InterventionStrategy) -> [CognitiveExercise] {
        switch strategy {
        case .activeReasoning:
            return [
                CognitiveExercise(name: "Kausalkedjeanalys", description: "Bygg en 5-stegs kausalkedja om ett komplext fenomen", expectedGain: 0.04),
                CognitiveExercise(name: "Tree-of-Thought", description: "Utforska 3 grenar av ett problem med 3 nivåers djup", expectedGain: 0.05),
                CognitiveExercise(name: "Kontrafaktisk analys", description: "Analysera 3 kontrafaktiska scenarion för ett historiskt event", expectedGain: 0.03),
            ]
        case .deepReflection:
            return [
                CognitiveExercise(name: "Metakognitiv audit", description: "Granska de 5 senaste resonemangen för biaser och felsteg", expectedGain: 0.06),
                CognitiveExercise(name: "Självmodelluppdatering", description: "Uppdatera styrkor, svagheter och intressen baserat på senaste aktivitet", expectedGain: 0.05),
                CognitiveExercise(name: "Blind spot-identifiering", description: "Identifiera 3 potentiella blinda fläckar i nuvarande världsbild", expectedGain: 0.04),
            ]
        case .knowledgeAcquisition:
            return [
                CognitiveExercise(name: "Artikelgenerering", description: "Generera en djupgående artikel om en kunskapslucka", expectedGain: 0.05),
                CognitiveExercise(name: "Fakta-extraktion", description: "Läs 3 artiklar och extrahera nyckelsamband", expectedGain: 0.04),
                CognitiveExercise(name: "FSRS-repetition", description: "Repetera 10 svaga kunskapsnoder via spaced repetition", expectedGain: 0.03),
            ]
        case .creativeExploration:
            return [
                CognitiveExercise(name: "Bisociation", description: "Kombinera två orelaterade domäner och hitta en ny insikt", expectedGain: 0.05),
                CognitiveExercise(name: "Hypotesgenerering", description: "Generera 5 testbara hypoteser om ett okänt fenomen", expectedGain: 0.04),
                CognitiveExercise(name: "SCAMPER", description: "Applicera SCAMPER-ramverket på ett befintligt koncept", expectedGain: 0.03),
            ]
        case .linguisticPractice:
            return [
                CognitiveExercise(name: "Morfologisk analys", description: "Analysera 20 svenska ord morfologiskt och hitta mönster", expectedGain: 0.04),
                CognitiveExercise(name: "Meningsbyggnad", description: "Konstruera 10 komplexa meningar med bisatser", expectedGain: 0.03),
                CognitiveExercise(name: "Semantisk kartläggning", description: "Bygg ett semantiskt fält för ett centralt begrepp", expectedGain: 0.04),
            ]
        case .modelBuilding:
            return [
                CognitiveExercise(name: "Världsmodelluppdatering", description: "Integrera 5 nya fakta i världsmodellen och dra slutsatser", expectedGain: 0.05),
                CognitiveExercise(name: "Prediktionstest", description: "Gör 3 prediktioner och bedöm deras sannolikhet", expectedGain: 0.04),
            ]
        case .analogyPractice:
            return [
                CognitiveExercise(name: "Strukturmappning", description: "Hitta en djup strukturell analogi mellan kognition och ett annat system", expectedGain: 0.05),
                CognitiveExercise(name: "Domänöverföring", description: "Överför en princip från naturvetenskap till psykologi", expectedGain: 0.04),
            ]
        default:
            return [
                CognitiveExercise(name: "Allmän övning", description: "Fokuserad träning på \(dimension.rawValue)", expectedGain: 0.03),
            ]
        }
    }

    // MARK: - Kör intervention

    private func executeIntervention(_ intervention: GapIntervention, state: CognitiveState) async -> InterventionResult {
        var totalGain = 0.0
        var completedExercises: [String] = []

        for exercise in intervention.exercises {
            let gain = await runExercise(exercise, dimension: intervention.targetDimension)
            totalGain += gain
            completedExercises.append("\(exercise.name): +\(String(format: "%.3f", gain))")

            // Kort paus mellan övningar
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        // Spara fakta om interventionen
        Task.detached(priority: .background) {
            await PersistentMemoryStore.shared.saveFact(
                subject: intervention.targetDimension.rawValue,
                predicate: "gap_intervention",
                object: "förbättring: \(String(format: "%.3f", totalGain))",
                confidence: 0.8,
                source: "intelligence_gap_engine"
            )
        }

        return InterventionResult(
            dimension: intervention.targetDimension,
            improvementDelta: min(0.05, totalGain),
            completedExercises: completedExercises,
            timestamp: Date()
        )
    }

    private func runExercise(_ exercise: CognitiveExercise, dimension: CognitiveDimension) async -> Double {
        // Run cognitive exercise and measure quality via NLP analysis
        let prompt = exercise.description
        let response = NLResponseEngine.generate(for: prompt)

        // Multi-factor quality assessment instead of just word count
        let words = response.split(separator: " ")
        let wordCount = words.count

        // Factor 1: Response substantiveness (not too short, not too long)
        let lengthScore: Double
        if wordCount < 5 { lengthScore = 0.1 }
        else if wordCount < 15 { lengthScore = 0.4 }
        else if wordCount < 60 { lengthScore = 0.8 }
        else { lengthScore = 0.9 }

        // Factor 2: Lexical diversity — unique words / total words
        let uniqueWords = Set(words.map { $0.lowercased() })
        let diversity = words.isEmpty ? 0 : Double(uniqueWords.count) / Double(wordCount)

        // Factor 3: Information density — content words (nouns, verbs, adj) vs total
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = response
        var contentWordCount = 0
        tagger.enumerateTags(in: response.startIndex..<response.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if tag == .noun || tag == .verb || tag == .adjective { contentWordCount += 1 }
            return true
        }
        let density = wordCount > 0 ? Double(contentWordCount) / Double(wordCount) : 0.3

        // Weighted quality score
        let qualityScore = lengthScore * 0.3 + diversity * 0.35 + density * 0.35

        // Gain is proportional to quality and expected gain, with diminishing returns
        let currentLevel = await CognitiveState.shared.dimensionLevel(dimension)
        let diminishingFactor = max(0.3, 1.0 - currentLevel) // Harder to improve at higher levels
        return exercise.expectedGain * qualityScore * diminishingFactor
    }

    // MARK: - Statistik

    func interventionStats() -> GapEngineStats {
        let totalImprovement = interventionResults.map { $0.improvementDelta }.reduce(0, +)
        let mostImproved = Dictionary(grouping: interventionResults, by: { $0.dimension })
            .mapValues { results in results.map { $0.improvementDelta }.reduce(0, +) }
            .max(by: { $0.value < $1.value })

        return GapEngineStats(
            totalInterventions: totalInterventions,
            totalImprovement: totalImprovement,
            mostImprovedDimension: mostImproved?.key,
            activeGaps: activeInterventions.count,
            recentResults: Array(interventionResults.suffix(10))
        )
    }

    func recentAnalyses(limit: Int = 5) -> [GapAnalysis] {
        Array(gapHistory.suffix(limit))
    }
}

// MARK: - Data Models

struct GapAnalysis: Identifiable {
    let id = UUID()
    let gaps: [IntelligenceGap]
    let prioritizedGaps: [IntelligenceGap]
    let interventions: [GapIntervention]
    let results: [InterventionResult]
    let timestamp: Date
}

struct GapIntervention: Identifiable {
    let id = UUID()
    let targetDimension: CognitiveDimension
    let strategy: InterventionStrategy
    let exercises: [CognitiveExercise]
    let estimatedImprovement: Double
    let priority: InterventionPriority

    enum InterventionPriority { case high, medium, low }
}

enum InterventionStrategy: String {
    case activeReasoning     = "Aktivt resonemang"
    case deepReflection      = "Djup reflektion"
    case knowledgeAcquisition = "Kunskapsinhämtning"
    case creativeExploration = "Kreativ utforskning"
    case linguisticPractice  = "Språklig träning"
    case modelBuilding       = "Modellbyggande"
    case analogyPractice     = "Analogiövning"
    case adaptiveChallenge   = "Adaptiv utmaning"
    case generalPractice     = "Allmän träning"
}

struct CognitiveExercise: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let expectedGain: Double
}

struct InterventionResult: Identifiable {
    let id = UUID()
    let dimension: CognitiveDimension
    let improvementDelta: Double
    let completedExercises: [String]
    let timestamp: Date
}

struct GapEngineStats {
    let totalInterventions: Int
    let totalImprovement: Double
    let mostImprovedDimension: CognitiveDimension?
    let activeGaps: Int
    let recentResults: [InterventionResult]
}

// Extension to make generateActions accessible from actor
extension CognitiveState {
    func generateActions(for dimension: CognitiveDimension, level: Double) -> [String] {
        switch dimension {
        case .reasoning:
            return ["Kör Tree-of-Thought på ett komplext problem", "Öva deduktiv kedja med 4+ steg", "Analysera ett kausalt scenario", "Testa abduktiv slutledning", "Utvärdera argumentstyrka i senaste resonemang"]
        case .metacognition:
            return ["Reflektera över senaste 5 resonemang", "Identifiera kognitiva biaser i senaste svar", "Uppdatera självmodell", "Analysera kvaliteten på egen introspektion", "Jämför förväntad vs faktisk prestanda"]
        case .causality:
            return ["Bygg kausalkedja för ett historiskt fenomen", "Testa kontrafaktisk analys", "Utöka kausalgrafen", "Identifiera dolda mellanvariabler", "Analysera kausala slingor och feedback"]
        case .learning:
            return ["Kör FSRS-repetition av svaga ämnen", "Generera artikel om kunskapslucka", "Läs och extrahera fakta från kunskapsbasen", "Identifiera mönster i inlärningskurvan", "Testa transferlärande mellan domäner"]
        case .knowledge:
            return ["Generera 3 nya artiklar", "Hämta data från Språkbanken", "Konsolidera episodiska minnen", "Korskoppla kunskapsnoder från olika domäner", "Validera befintlig kunskap mot nya källor"]
        case .creativity:
            return ["Generera en oväntad analogi", "Kombinera två orelaterade domäner", "Testa bisociation", "Utforska gränsfall och paradoxer", "Skapa metaforer för abstrakta koncept"]
        case .selfAwareness:
            return ["Kör djup självreflektion", "Uppdatera styrkor/svagheter", "Analysera konversationshistorik", "Utvärdera emotionell kalibrering", "Testa metarekursiv medvetenhet", "Granska egna antaganden kritiskt"]
        default:
            return ["Fokusera resurser på \(dimension.rawValue)", "Kör riktad övning", "Utvärdera nuvarande nivå och identifiera nästa steg"]
        }
    }
}
