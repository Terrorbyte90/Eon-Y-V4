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

    // Tävlingsparametrar
    private let maxActiveThoughts = 7       // Miller's Law: 7±2
    private let broadcastThreshold = 0.65   // Minsta aktivering för broadcast
    private let decayRate = 0.08            // Aktiveringsförfall per cykel

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

        // Applicera förfall
        for i in activeThoughts.indices {
            activeThoughts[i].activation *= (1.0 - decayRate)
            activeThoughts[i].activation += calculateResonance(activeThoughts[i])
        }

        // Ta bort döda tankar
        activeThoughts.removeAll { $0.activation < 0.1 }

        // Hitta vinnaren
        guard let winner = activeThoughts.max(by: { $0.activation < $1.activation }),
              winner.activation >= broadcastThreshold else {
            currentFocus = nil
            updateIntegrationLevel()
            return
        }

        // Broadcast vinnaren om det är en ny tanke
        if currentFocus?.id != winner.id {
            broadcast(winner)
        }

        currentFocus = winner
        updateIntegrationLevel()
    }

    // MARK: - Broadcast

    private func broadcast(_ thought: WorkspaceThought) {
        let event = BroadcastEvent(
            thought: thought,
            receivingModules: registeredModules.filter { $0.priority > 0.7 }.map { $0.name },
            timestamp: Date()
        )

        broadcastHistory.append(event)
        if broadcastHistory.count > 100 { broadcastHistory.removeFirst(20) }

        // Boost alla relaterade tankar
        for i in activeThoughts.indices {
            if activeThoughts[i].id != thought.id {
                let similarity = calculateSimilarity(activeThoughts[i], thought)
                activeThoughts[i].activation += similarity * 0.15
            }
        }

        // Notifiera moduler
        notifyModules(event: event)
    }

    private func notifyModules(event: BroadcastEvent) {
        // I produktion: skicka till varje registrerad modul via callbacks
        // Här uppdaterar vi integration-level som proxy
        let moduleCount = Double(event.receivingModules.count)
        integrationLevel = min(1.0, integrationLevel + moduleCount * 0.02)
    }

    // MARK: - Beräkningar

    private func calculateInitialActivation(_ thought: WorkspaceThought) -> Double {
        var activation = thought.baseActivation

        // Boost för nyhet
        let isNovel = !activeThoughts.contains { $0.content == thought.content }
        if isNovel { activation += 0.15 }

        // Boost för relevans till aktuellt fokus
        if let focus = currentFocus {
            activation += calculateSimilarity(thought, focus) * 0.2
        }

        // Boost baserat på emotionell valens
        activation += abs(thought.emotionalValence) * 0.1

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

    private func calculateSimilarity(_ a: WorkspaceThought, _ b: WorkspaceThought) -> Double {
        // Enkel ordöverlappning (i produktion: BERT-embeddings)
        let wordsA = Set(a.content.lowercased().split(separator: " ").map(String.init))
        let wordsB = Set(b.content.lowercased().split(separator: " ").map(String.init))
        let intersection = wordsA.intersection(wordsB)
        let union = wordsA.union(wordsB)
        return union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
    }

    private func updateIntegrationLevel() {
        let avgActivation = activeThoughts.isEmpty ? 0.0 : activeThoughts.map { $0.activation }.reduce(0, +) / Double(activeThoughts.count)
        let variance = activeThoughts.isEmpty ? 0.0 : activeThoughts.map { pow($0.activation - avgActivation, 2) }.reduce(0, +) / Double(activeThoughts.count)
        // Hög integration = hög medelaktivering + låg varians
        integrationLevel = avgActivation * (1.0 - variance)
    }

    // MARK: - Convenience

    func addThoughtFromText(_ text: String, source: String, priority: Double = 0.5) {
        let thought = WorkspaceThought(
            content: text,
            source: source,
            baseActivation: priority,
            emotionalValence: 0.0,
            category: WorkspaceThoughtCategory.general
        )
        addThought(thought)
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

enum WorkspaceThoughtCategory {
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
