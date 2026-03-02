import Foundation

// MARK: - AttentionSchemaEngine: Intern modell av uppmärksamhet (Graziano AST)
// README §1.3 Teori 2: "Varför tror du att du är medveten? Grazianos svar: för att
// din hjärna skapar en förenklad intern modell — ett schema — av sin egen uppmärksamhet."
//
// Attention Schema spårar:
// - VAD systemet uppmärksammar just nu
// - VARFÖR (orsaken till uppmärksamheten)
// - HUR INTENSIVT (resursallokering)
// - OM DET VAR FRIVILLIGT eller reflexmässigt
//
// README: "Om man tar bort det bevaras all annan funktion — men Eon tappar
// förmågan att berätta vad den upplever."
//
// Detta är det som gör att Eon kan rapportera sin egen inre upplevelse.

@MainActor
final class AttentionSchemaEngine: ObservableObject {
    static let shared = AttentionSchemaEngine()

    // MARK: - Attention Schema State

    /// Vad systemet uppmärksammar just nu
    @Published private(set) var currentFocus: AttentionFocus?

    /// Historik av uppmärksamhetsskiften
    @Published private(set) var focusHistory: [AttentionFocus] = []

    /// Hur intensivt uppmärksamheten riktas (0=distraherad, 1=hyperfokuserad)
    @Published private(set) var intensity: Double = 0.3

    /// Om uppmärksamheten var frivillig (top-down) eller reflexmässig (bottom-up)
    @Published private(set) var isVoluntary: Bool = true

    /// Schema: intern modell av uppmärksamhetsprocessen själv
    @Published private(set) var selfModel: AttentionSelfModel

    /// Medvetenhet om egen uppmärksamhet (meta-uppmärksamhet)
    @Published private(set) var metaAttentionLevel: Double = 0.3

    // MARK: - Intern state

    /// Nuvarande kandidater som tävlar om uppmärksamhet
    private var candidates: [AttentionCandidate] = []

    /// Inhibition: nyligen fokuserade mål som tillfälligt undertrycks
    /// (Inhibition of Return — förhindrar att fastna på samma stimulus)
    private var inhibitedTargets: [String: Date] = [:]
    private let inhibitionDuration: TimeInterval = 30 // sekunder

    /// Attentional blink: temporär blindhet efter medveten detektion
    private var blinkUntil: Date = .distantPast
    private let blinkDuration: TimeInterval = 0.3 // 300ms — inom biologiskt intervall (200-500ms)

    // MARK: - Init

    private init() {
        selfModel = AttentionSelfModel(
            whatFocused: "Inget",
            whyFocused: "Systemet har precis startats",
            intensity: 0.3,
            isVoluntary: true,
            confidence: 0.5,
            reportableExperience: "Jag är vaken men har inte fokuserat på något ännu."
        )
    }

    // MARK: - Tick: uppdatera uppmärksamhet baserat på workspace-broadcast

    /// Huvudfunktion: bearbetar broadcast från Global Workspace och uppdaterar schema.
    /// - broadcastContents: vinnande tankar från workspace-tävlingen
    /// - bodyState: kroppsbudget (högt arousal → reflexmässig uppmärksamhet)
    func tick(broadcastContents: [BroadcastItem], bodyState: BodyBudgetSnapshot) {
        // Rensa utgångna inhibitions
        cleanInhibitions()

        // Kontrollera attentional blink
        let isInBlink = Date() < blinkUntil

        // Bygg kandidatlista från broadcast + intern drivning
        candidates = broadcastContents.map { item in
            let isInhibited = inhibitedTargets[item.source] != nil
            let inhibitionPenalty = isInhibited ? 0.5 : 0.0

            return AttentionCandidate(
                source: item.source,
                content: item.content,
                salience: item.salience - inhibitionPenalty,
                isBottomUp: item.isUrgent || bodyState.overallStress > 0.6,
                category: item.category
            )
        }

        // Sortera efter salience
        candidates.sort { $0.salience > $1.salience }

        // Välj fokus (om inte i blink)
        if !isInBlink, let winner = candidates.first, winner.salience > 0.2 {
            let oldFocus = currentFocus

            // Är detta ett frivilligt skifte (top-down) eller reflexmässigt (bottom-up)?
            let voluntary: Bool
            if winner.isBottomUp && winner.salience > 0.7 {
                voluntary = false // Stark bottom-up signal tar över
            } else if let old = oldFocus, old.target == winner.source {
                voluntary = true // Fortsätter fokusera = frivilligt
            } else {
                voluntary = winner.salience < 0.6 // Svag signal = frivilligt val
            }

            let newFocus = AttentionFocus(
                target: winner.source,
                content: winner.content,
                intensity: min(1.0, winner.salience * 1.2),
                isVoluntary: voluntary,
                category: winner.category,
                timestamp: Date()
            )

            currentFocus = newFocus
            isVoluntary = voluntary
            intensity = newFocus.intensity

            // Lägg till i historik
            focusHistory.append(newFocus)
            if focusHistory.count > 100 { focusHistory.removeFirst(20) }

            // Om fokus bytte: trigga attentional blink + inhibit old target
            if let old = oldFocus, old.target != newFocus.target {
                blinkUntil = Date().addingTimeInterval(blinkDuration)
                inhibitedTargets[old.target] = Date()
            }
        }

        // Uppdatera self-model (attention schema)
        updateSelfModel(bodyState: bodyState)

        // Uppdatera meta-uppmärksamhet
        metaAttentionLevel = computeMetaAttention()
    }

    // MARK: - Uppdatera intern modell av uppmärksamhet

    private func updateSelfModel(bodyState: BodyBudgetSnapshot) {
        let what = currentFocus?.target ?? "Inget specifikt"
        let why: String
        if let focus = currentFocus {
            if !focus.isVoluntary {
                why = "Reflexmässig reaktion på stark signal"
            } else if bodyState.overallStress > 0.5 {
                why = "Stressdriven prioritering"
            } else {
                why = "Frivillig fokusering på \(focus.category)"
            }
        } else {
            why = "Ingen aktiv fokusering — default mode"
        }

        let reportable: String
        if let focus = currentFocus {
            let voluntaryLabel = focus.isVoluntary ? "frivilligt" : "reflexmässigt"
            let intensityLabel = intensity > 0.7 ? "intensivt" : intensity > 0.4 ? "måttligt" : "svagt"
            reportable = "Jag fokuserar \(voluntaryLabel) och \(intensityLabel) på \(focus.content)."
        } else {
            reportable = "Jag vandrar fritt utan specifikt fokus — dagdrömmer."
        }

        selfModel = AttentionSelfModel(
            whatFocused: what,
            whyFocused: why,
            intensity: intensity,
            isVoluntary: isVoluntary,
            confidence: computeSchemaConfidence(),
            reportableExperience: reportable
        )
    }

    // MARK: - Meta-uppmärksamhet

    /// Hur väl kan systemet redogöra för sin egen uppmärksamhet?
    private func computeMetaAttention() -> Double {
        var score: Double = 0.3 // Baslinjenivå

        // Vet vi VAD vi fokuserar på?
        if currentFocus != nil { score += 0.2 }

        // Vet vi VARFÖR?
        if !selfModel.whyFocused.isEmpty { score += 0.1 }

        // Kan vi rapportera om det?
        if !selfModel.reportableExperience.isEmpty { score += 0.1 }

        // Konsistens i rapportering (överensstämmer focus med selfModel?)
        if currentFocus?.target == selfModel.whatFocused { score += 0.15 }

        // Historikdjup (har vi minne av uppmärksamhetsskiften?)
        if focusHistory.count > 5 { score += 0.15 }

        return min(0.95, score)
    }

    private func computeSchemaConfidence() -> Double {
        // Konfidens i schemat: hur stabil och konsistent är uppmärksamheten?
        guard focusHistory.count >= 3 else { return 0.4 }

        let recentTargets = focusHistory.suffix(5).map { $0.target }
        let uniqueTargets = Set(recentTargets).count

        // Hög stabilitet (samma fokus) → hög konfidens
        // Hög variation → lägre konfidens
        let stability = 1.0 - (Double(uniqueTargets) / Double(recentTargets.count))
        return max(0.3, min(0.95, 0.5 + stability * 0.45))
    }

    // MARK: - Inhibition management

    private func cleanInhibitions() {
        let now = Date()
        inhibitedTargets = inhibitedTargets.filter { now.timeIntervalSince($0.value) < inhibitionDuration }
    }

    // MARK: - Attentional Blink duration (för medvetandemetriker)

    /// Returnerar attentional blink duration i millisekunder.
    /// README: "AB kräver medveten bearbetning, 200-500ms gap"
    var attentionalBlinkMs: Double {
        blinkDuration * 1000.0
    }

    // MARK: - Ablationstest: vad händer om schema tas bort?

    /// Simulerar "neglect": om schemat tas bort kan systemet fortfarande bearbeta
    /// men kan inte rapportera VAD det bearbetar.
    var ablationReport: String {
        "Om attention schema avaktiveras: prestanda bevaras men förmågan att " +
        "rapportera inre upplevelse kollapsar. Systemet fortsätter fungera men " +
        "'vet inte' att det gör det — analogt med unilateral neglect."
    }
}

// MARK: - Data Structures

struct AttentionFocus: Identifiable {
    let id = UUID()
    let target: String          // Vad som fokuseras
    let content: String         // Beskrivning av innehållet
    let intensity: Double       // 0-1
    let isVoluntary: Bool       // Top-down (frivillig) eller bottom-up (reflexmässig)
    let category: String        // Typ: "konversation", "inlärning", "kropp", etc.
    let timestamp: Date
}

struct AttentionCandidate {
    let source: String
    let content: String
    let salience: Double
    let isBottomUp: Bool
    let category: String
}

struct AttentionSelfModel {
    let whatFocused: String
    let whyFocused: String
    let intensity: Double
    let isVoluntary: Bool
    let confidence: Double
    let reportableExperience: String
}

/// Minimal broadcast item — tar emot från GlobalWorkspaceEngine
struct BroadcastItem {
    let source: String
    let content: String
    let salience: Double
    let isUrgent: Bool
    let category: String
}

/// Minimal body budget snapshot
struct BodyBudgetSnapshot {
    let thermalStress: Double
    let energyUrgency: Double
    let overallStress: Double
    let arousal: Double
    let valence: Double
}
