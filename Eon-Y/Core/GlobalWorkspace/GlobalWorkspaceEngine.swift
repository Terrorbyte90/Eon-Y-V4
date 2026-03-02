import Foundation
import Combine

// MARK: - GlobalWorkspaceEngine
// Implementerar Bernard Baars' Global Workspace Theory (GWT).
// Tankar tävlar om tillgång till den globala arbetsytan.
// Vinnande representationer broadcastas till ALLA kognitiva moduler.
// Emergent fokus utan central kontroll — precis som i mänsklig kognition.

@MainActor
final class GlobalWorkspaceEngine: ObservableObject {
    static let shared = GlobalWorkspaceEngine()

    // MARK: - Arbetsyta

    @Published var activeThoughts: [WorkspaceThought] = []
    @Published var broadcastHistory: [BroadcastEvent] = []
    @Published var currentFocus: WorkspaceThought?
    @Published var competitionRound: Int = 0
    @Published var integrationLevel: Double = 0.0

    // Registrerade moduler som tar emot broadcasts
    private var registeredModules: [CognitiveModule] = []

    // Tävlingsparametrar (adaptive)
    private var maxActiveThoughts = 7       // Miller's Law: 7±2 — adjusted based on cognitive load
    private let broadcastThreshold = 0.60   // Minsta aktivering för broadcast (lowered for more broadcasts)
    private let baseDecayRate = 0.08        // Baseline decay rate
    private var consecutiveBroadcasts: Int = 0 // Track consecutive broadcasts for focus detection
    @Published var dominantCategory: WorkspaceThoughtCategory = .general
    @Published var focusStrength: Double = 0.0 // How focused the workspace is (0=scattered, 1=laser)

    private init() {
        setupDefaultModules()
    }

    // MARK: - Modulregistrering

    private func setupDefaultModules() {
        registeredModules = [
            CognitiveModule(id: "memory", name: "Minnessystem", priority: 0.9),
            CognitiveModule(id: "language", name: "Språkmotor", priority: 0.85),
            CognitiveModule(id: "reasoning", name: "Resonemangssystem", priority: 0.88),
            CognitiveModule(id: "emotion", name: "Emotionssystem", priority: 0.75),
            CognitiveModule(id: "metacognition", name: "Metakognition", priority: 0.80),
            CognitiveModule(id: "attention", name: "Uppmärksamhetssystem", priority: 0.92),
            CognitiveModule(id: "creativity", name: "Kreativitetsmotor", priority: 0.70),
        ]
    }

    // MARK: - Lägg till tanke i arbetsytan

    func addThought(_ thought: WorkspaceThought) {
        // Kontrollera kapacitet
        if activeThoughts.count >= maxActiveThoughts {
            // Ta bort svagaste tanken
            if let weakest = activeThoughts.min(by: { $0.activation < $1.activation }) {
                activeThoughts.removeAll { $0.id == weakest.id }
            }
        }

        var newThought = thought
        newThought.activation = calculateInitialActivation(thought)
        activeThoughts.append(newThought)

        // Kör tävling
        runCompetition()
    }

    // MARK: - Tävlingsmekanik

    func runCompetition() {
        competitionRound += 1

        // Phase 0: Thought Coalescence — merge highly similar thoughts into stronger combined ones
        coalesceThoughts()

        // Phase 1: Adaptive decay — older thoughts decay faster, focused thoughts decay slower
        let decayRate = baseDecayRate * (focusStrength > 0.7 ? 0.6 : 1.0) // Slower decay when focused
        for i in activeThoughts.indices {
            let age = Date().timeIntervalSince(activeThoughts[i].timestamp) / 60.0 // minutes
            let ageFactor = 1.0 + min(0.5, age * 0.02) // Older thoughts decay up to 1.5x faster
            activeThoughts[i].activation *= (1.0 - decayRate * ageFactor)
            activeThoughts[i].activation += calculateResonance(activeThoughts[i])
        }

        // Phase 2: Lateral inhibition — competing thoughts suppress each other
        for i in activeThoughts.indices {
            var inhibition: Double = 0
            for j in activeThoughts.indices where i != j {
                let similarity = calculateSimilarity(activeThoughts[i], activeThoughts[j])
                if similarity > 0.35 && activeThoughts[j].activation > activeThoughts[i].activation {
                    // Stronger inhibition for very similar thoughts (prevents redundancy)
                    let inhibitionStrength = similarity > 0.7 ? 0.06 : 0.03
                    inhibition += similarity * inhibitionStrength
                }
            }
            activeThoughts[i].activation = max(0, activeThoughts[i].activation - inhibition)
        }

        // Phase 3: Remove dead thoughts
        activeThoughts.removeAll { $0.activation < 0.08 }

        // Phase 4: Adaptive capacity — expand workspace when diverse, contract when focused
        let categoryCount = Set(activeThoughts.map { $0.category }).count
        maxActiveThoughts = categoryCount >= 4 ? 9 : 7 // Miller's 7±2

        // Update dominant category and focus strength
        updateFocusMetrics()

        // Hitta vinnaren
        guard let winner = activeThoughts.max(by: { $0.activation < $1.activation }),
              winner.activation >= broadcastThreshold else {
            currentFocus = nil
            consecutiveBroadcasts = 0
            updateIntegrationLevel()
            return
        }

        // Broadcast vinnaren om det är en ny tanke
        if currentFocus?.id != winner.id {
            broadcast(winner)
            consecutiveBroadcasts += 1
        }

        currentFocus = winner
        updateIntegrationLevel()
    }

    // MARK: - Thought Coalescence
    // Merge highly similar thoughts into a single stronger thought

    private func coalesceThoughts() {
        guard activeThoughts.count >= 3 else { return }

        var merged = false
        var i = 0
        while i < activeThoughts.count && !merged {
            var j = i + 1
            while j < activeThoughts.count {
                let similarity = calculateSimilarity(activeThoughts[i], activeThoughts[j])
                if similarity > 0.65 { // Very similar — merge
                    // Create merged thought with combined activation and richer content
                    let combined = activeThoughts[i].activation > activeThoughts[j].activation
                        ? activeThoughts[i] : activeThoughts[j]
                    let weaker = activeThoughts[i].activation > activeThoughts[j].activation
                        ? activeThoughts[j] : activeThoughts[i]

                    // Boost the stronger thought with energy from the weaker
                    let mergeBonus = weaker.activation * 0.4
                    activeThoughts[activeThoughts[i].activation > activeThoughts[j].activation ? i : j].activation =
                        min(1.0, combined.activation + mergeBonus)

                    // Remove the weaker thought
                    activeThoughts.remove(at: activeThoughts[i].activation > activeThoughts[j].activation ? j : i)
                    merged = true
                    break
                }
                j += 1
            }
            i += 1
        }
    }

    // MARK: - Focus Metrics

    private func updateFocusMetrics() {
        guard !activeThoughts.isEmpty else {
            focusStrength = 0
            dominantCategory = .general
            return
        }

        // Find dominant category
        var categoryCounts: [WorkspaceThoughtCategory: Double] = [:]
        for thought in activeThoughts {
            categoryCounts[thought.category, default: 0] += thought.activation
        }
        dominantCategory = categoryCounts.max(by: { $0.value < $1.value })?.key ?? .general

        // Focus strength: how much activation is concentrated in the dominant category
        let totalActivation = activeThoughts.map { $0.activation }.reduce(0, +)
        let dominantActivation = categoryCounts[dominantCategory] ?? 0
        focusStrength = totalActivation > 0 ? dominantActivation / totalActivation : 0
    }

    // MARK: - Ignition & Broadcast (v9: non-linear ignition som i README)

    /// Antal ignitions (icke-linjär tändning där tanken plötsligt blir tillgänglig för hela systemet)
    @Published var ignitionCount: Int = 0

    private func broadcast(_ thought: WorkspaceThought) {
        // IGNITION: icke-linjär tändning — tanken "exploderar" i medvetandet
        // README: "en icke-linjär tändning där tanken plötsligt blir tillgänglig för hela systemet"
        ignitionCount += 1

        // Meddela ConsciousnessEngine om ignition
        ConsciousnessEngine.shared.workspaceIgnitions = ignitionCount
        ConsciousnessEngine.shared.broadcastCount = broadcastHistory.count
        ConsciousnessEngine.shared.competingThoughts = activeThoughts.count

        // Select receiving modules based on thought category — targeted broadcast
        let relevantModules = registeredModules.filter { module in
            if module.priority > 0.85 { return true }
            switch thought.category {
            case .reasoning: return ["reasoning", "metacognition", "attention"].contains(module.id)
            case .memory:    return ["memory", "language", "reasoning"].contains(module.id)
            case .language:  return ["language", "memory", "creativity"].contains(module.id)
            case .emotion:   return ["emotion", "metacognition", "memory"].contains(module.id)
            default:         return module.priority > 0.7
            }
        }

        let event = BroadcastEvent(
            thought: thought,
            receivingModules: relevantModules.map { $0.name },
            timestamp: Date()
        )

        broadcastHistory.append(event)
        if broadcastHistory.count > 100 { broadcastHistory.removeFirst(20) }

        // Boost related thoughts — amount proportional to semantic relevance
        for i in activeThoughts.indices {
            if activeThoughts[i].id != thought.id {
                let similarity = calculateSimilarity(activeThoughts[i], thought)
                let boostAmount = similarity * 0.15 * (thought.activation / max(1.0, activeThoughts[i].activation + thought.activation))
                activeThoughts[i].activation = min(1.0, activeThoughts[i].activation + boostAmount)
            }
        }

        // Driva oscillatorer med broadcast-signal (kopplar GWT till neural synkronisering)
        let driveSignal = Array(repeating: thought.activation * 0.5, count: 12)
        OscillatorBank.shared.tick(dt: 0.01, externalDrive: driveSignal)

        // Meddela AttentionSchema om ny broadcast
        let broadcastItem = BroadcastItem(
            source: thought.source,
            content: thought.content,
            salience: thought.activation,
            isUrgent: thought.category == .emotion || thought.activation > 0.8,
            category: thought.category.rawValue
        )
        AttentionSchemaEngine.shared.tick(
            broadcastContents: [broadcastItem],
            bodyState: BodyBudgetSnapshot(
                thermalStress: ConsciousnessEngine.shared.bodyBudget.thermalLevel,
                energyUrgency: 0.3,
                overallStress: ConsciousnessEngine.shared.bodyBudget.thermalLevel * 0.5,
                arousal: ConsciousnessEngine.shared.bodyBudget.arousal,
                valence: ConsciousnessEngine.shared.bodyBudget.valence
            )
        )

        // Notify modules — cross-module feedback
        notifyModules(event: event)
    }

    private func notifyModules(event: BroadcastEvent) {
        // Module feedback: each module's priority contributes to integration
        let totalModulePriority = registeredModules
            .filter { event.receivingModules.contains($0.name) }
            .map { $0.priority }
            .reduce(0, +)
        let feedbackStrength = totalModulePriority / Double(registeredModules.count)
        integrationLevel = min(1.0, integrationLevel * 0.95 + feedbackStrength * 0.1)
    }

    // MARK: - Beräkningar

    private func calculateInitialActivation(_ thought: WorkspaceThought) -> Double {
        var activation = thought.baseActivation

        // Novelty boost — new thoughts get attention
        let isNovel = !activeThoughts.contains { $0.content == thought.content }
        if isNovel { activation += 0.15 }

        // Relevance boost — related to current focus
        if let focus = currentFocus {
            activation += calculateSimilarity(thought, focus) * 0.2
        }

        // Emotional valence boost
        activation += abs(thought.emotionalValence) * 0.1

        // Complexity boost — richer thoughts are more informative
        let words = thought.content.split(separator: " ")
        let uniqueWords = Set(words.map { $0.lowercased() }).filter { $0.count > 3 }
        if uniqueWords.count > 5 {
            let complexityBonus = min(0.12, Double(uniqueWords.count) * 0.01)
            activation += complexityBonus
        }

        // Category-specific boost — certain categories are inherently more urgent
        switch thought.category {
        case .reasoning: activation += 0.05
        case .emotion:   activation += 0.08 // Emotional thoughts demand attention
        case .memory:    activation += 0.03
        default:         break
        }

        return min(1.0, activation)
    }

    private func calculateResonance(_ thought: WorkspaceThought) -> Double {
        // Resonans med andra aktiva tankar
        let resonance = activeThoughts
            .filter { $0.id != thought.id }
            .map { calculateSimilarity(thought, $0) * $0.activation * 0.05 }
            .reduce(0, +)
        return min(0.2, resonance)
    }

    /// Stopwords that should be ignored in similarity computation
    private static let stopwords: Set<String> = [
        "och", "i", "att", "det", "en", "ett", "är", "av", "för", "med", "på", "som",
        "den", "till", "har", "de", "inte", "om", "var", "jag", "man", "kan", "ska",
        "vi", "från", "alla", "vara", "sig", "vad", "så", "men", "hur", "eller",
        "nu", "sin", "här", "där", "när", "han", "hon", "under", "efter", "vid",
        "the", "is", "a", "an", "of", "to", "in", "and", "was", "that",
    ]

    private func calculateSimilarity(_ a: WorkspaceThought, _ b: WorkspaceThought) -> Double {
        // Weighted word overlap — filters stopwords and weights longer (more specific) words higher
        let wordsA = Set(a.content.lowercased().split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !Self.stopwords.contains($0) })
        let wordsB = Set(b.content.lowercased().split(separator: " ")
            .map(String.init)
            .filter { $0.count > 2 && !Self.stopwords.contains($0) })

        guard !wordsA.isEmpty && !wordsB.isEmpty else { return 0 }

        let intersection = wordsA.intersection(wordsB)
        guard !intersection.isEmpty else { return 0 }

        // Weight longer words more heavily (more semantically specific)
        let weightedOverlap = intersection.reduce(0.0) { sum, word in
            sum + min(Double(word.count) / 6.0, 1.5)
        }
        let maxPossible = max(
            wordsA.reduce(0.0) { $0 + min(Double($1.count) / 6.0, 1.5) },
            wordsB.reduce(0.0) { $0 + min(Double($1.count) / 6.0, 1.5) }
        )

        // Category bonus: same-category thoughts are more similar
        let categoryBonus: Double = a.category == b.category ? 0.1 : 0.0

        return min(1.0, (weightedOverlap / max(maxPossible, 1.0)) + categoryBonus)
    }

    private func updateIntegrationLevel() {
        guard !activeThoughts.isEmpty else { integrationLevel = 0; return }

        let avgActivation = activeThoughts.map { $0.activation }.reduce(0, +) / Double(activeThoughts.count)
        let variance = activeThoughts.map { pow($0.activation - avgActivation, 2) }.reduce(0, +) / Double(activeThoughts.count)

        // Semantic coherence: average pairwise similarity between active thoughts
        var coherenceSum: Double = 0
        var pairCount: Double = 0
        if activeThoughts.count >= 2 {
            for i in 0..<activeThoughts.count {
                for j in (i+1)..<activeThoughts.count {
                    coherenceSum += calculateSimilarity(activeThoughts[i], activeThoughts[j])
                    pairCount += 1
                }
            }
        }
        let semanticCoherence = pairCount > 0 ? coherenceSum / pairCount : 0.5

        // Integration = activation × coherence × (1 - variance)
        // High integration = thoughts are active, related, and balanced
        integrationLevel = avgActivation * (0.6 + semanticCoherence * 0.4) * max(0.3, 1.0 - variance)
    }

    // MARK: - Convenience

    func addThoughtFromText(_ text: String, source: String, priority: Double = 0.5) {
        let category = classifyThoughtCategory(text)
        let emotionalValence = estimateEmotionalValence(text)

        let thought = WorkspaceThought(
            content: text,
            source: source,
            baseActivation: priority,
            emotionalValence: emotionalValence,
            category: category
        )
        addThought(thought)
    }

    /// Classify a thought's category based on content keywords
    private func classifyThoughtCategory(_ text: String) -> WorkspaceThoughtCategory {
        let lower = text.lowercased()
        let categorySignals: [(WorkspaceThoughtCategory, [String])] = [
            (.reasoning,  ["resonerar", "slutsats", "kausal", "hypotes", "logik", "bevis", "analys", "samband"]),
            (.memory,     ["minne", "kommer ihåg", "episodisk", "konsolidering", "lagrar", "hämtar", "databas"]),
            (.language,   ["språk", "morfologi", "syntax", "semantik", "ord", "grammatik", "böjning", "mening"]),
            (.emotion,    ["känsla", "emotion", "glad", "ledsen", "orolig", "arg", "mår", "ångest"]),
            (.perception, ["observerar", "uppfattar", "signal", "input", "registrerar", "noterar"]),
        ]
        var bestCategory: WorkspaceThoughtCategory = .general
        var bestScore = 0
        for (category, keywords) in categorySignals {
            let score = keywords.filter { lower.contains($0) }.count
            if score > bestScore { bestScore = score; bestCategory = category }
        }
        return bestCategory
    }

    /// Estimate emotional valence from text (-1 negative to +1 positive)
    private func estimateEmotionalValence(_ text: String) -> Double {
        let lower = text.lowercased()
        let positive = ["framgång", "förbättring", "stark", "lyckas", "bra", "utmärkt", "tillväxt", "positiv", "löst", "framsteg", "✓", "✅"]
        let negative = ["problem", "svag", "stagnation", "misslyckades", "bristfällig", "regression", "fel", "låg", "⚠️", "❌"]
        let posScore = Double(positive.filter { lower.contains($0) }.count) * 0.15
        let negScore = Double(negative.filter { lower.contains($0) }.count) * 0.15
        return min(1.0, max(-1.0, posScore - negScore))
    }

    func clearWorkspace() {
        activeThoughts.removeAll()
        currentFocus = nil
        competitionRound = 0
        integrationLevel = 0.0
    }

    var thoughtCount: Int { activeThoughts.count }
    var broadcastCount: Int { broadcastHistory.count }
}

// MARK: - Data Models

enum WorkspaceThoughtCategory: Equatable {
    case perception, memory, reasoning, language, emotion, general
}

struct WorkspaceThought: Identifiable {
    let id = UUID()
    let content: String
    let source: String
    var baseActivation: Double
    var activation: Double = 0.5
    var emotionalValence: Double   // -1..+1
    let category: WorkspaceThoughtCategory
    let timestamp: Date = Date()
}

struct BroadcastEvent: Identifiable {
    let id = UUID()
    let thought: WorkspaceThought
    let receivingModules: [String]
    let timestamp: Date
}

struct CognitiveModule: Identifiable {
    let id: String
    let name: String
    let priority: Double
    var isActive: Bool = true
}
