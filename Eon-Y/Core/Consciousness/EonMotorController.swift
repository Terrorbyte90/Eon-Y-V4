import Foundation
import SwiftUI
import Combine

// MARK: - EonMotorController
// Eon's self-regulation of cognitive motors. When "Eon-läge" is active,
// Eon makes decisions about which motors run and at what speed, based on
// body budget feedback (valence, arousal, thermal state, CPU load).
//
// Key principle: Eon gets INFLUENCE, not CONTROL.
// - No motor can go below minSpeed (0.2 = 20%)
// - No motor can exceed maxSpeed (1.5 = 150%)
// - Safety override kicks in if Eon consistently under-drives (depression loop)
// - Thermal .critical forces safety override regardless
// - All decisions are logged with reasoning

@MainActor
final class EonMotorController: ObservableObject {
    static let shared = EonMotorController()

    // MARK: - Motor Definitions

    @Published var motors: [MotorState] = []
    @Published var decisionLog: [MotorDecision] = []
    @Published var currentMood: String = "Initierar..."
    @Published var lastDecisionSummary: String = ""
    @Published var safetyOverrideActive: Bool = false
    @Published var isEnabled: Bool = false  // Synced from AppStorage in ConsciousnessEngine

    // Safety tracking
    private var consecutiveLowDecisions: Int = 0
    private var decisionCount: Int = 0

    // MARK: - Constants

    static let globalMinSpeed: Double = 0.2
    static let globalMaxSpeed: Double = 1.5
    private let maxConsecutiveLow: Int = 5
    private let maxLogEntries: Int = 200

    private init() {
        initializeMotors()
    }

    // MARK: - Motor Registry

    private func initializeMotors() {
        motors = [
            MotorState(
                id: "consciousness",
                name: "Medvetandemotor",
                description: "Mäter 40+ medvetandeindikatorer, PCI-LZ, Φ-proxy, Q-index",
                speed: 1.0, minSpeed: 0.4, maxSpeed: 1.3,
                importance: .critical
            ),
            MotorState(
                id: "thoughts",
                name: "Tankemotor",
                description: "Genererar medvetna tankar, dagdrömmar, spontan aktivitet",
                speed: 1.0, minSpeed: 0.3, maxSpeed: 1.5,
                importance: .high
            ),
            MotorState(
                id: "orchestrator",
                name: "Orkestratormotor",
                description: "Koordinerar 12 kognitiva pelare med kausal koppling",
                speed: 1.0, minSpeed: 0.3, maxSpeed: 1.5,
                importance: .high
            ),
            MotorState(
                id: "metacognition",
                name: "Metakognitionsmotor",
                description: "Övervakar kognition, detekterar biaser, driver självförbättring",
                speed: 1.0, minSpeed: 0.2, maxSpeed: 1.5,
                importance: .medium
            ),
            MotorState(
                id: "pillars",
                name: "Pelarmotor",
                description: "Kör enskilda kognitiva pelare: morfologi, WSD, resonemang, minne",
                speed: 1.0, minSpeed: 0.3, maxSpeed: 1.5,
                importance: .high
            ),
            MotorState(
                id: "autonomy",
                name: "Autonomimotor",
                description: "4-fasad kognitiv cykel: Intensiv, Inlärning, Språk, Vila",
                speed: 1.0, minSpeed: 0.3, maxSpeed: 1.5,
                importance: .high
            ),
            MotorState(
                id: "learning",
                name: "Inlärningsmotor",
                description: "FSRS-repetition, kunskapsluckeanalys, domänkompetens",
                speed: 1.0, minSpeed: 0.2, maxSpeed: 1.5,
                importance: .medium
            ),
        ]
    }

    // MARK: - Speed Accessors (read by engines)

    func speedMultiplier(for motorId: String) -> Double {
        guard isEnabled else { return 1.0 }
        guard let motor = motors.first(where: { $0.id == motorId }) else { return 1.0 }
        if safetyOverrideActive { return 1.0 } // Safety forces normal speed
        return motor.speed
    }

    /// Convert speed multiplier to interval: speed 1.0 = base, speed 0.5 = 2x base, speed 1.5 = 0.67x base
    func adjustedInterval(base: UInt64, motorId: String) -> UInt64 {
        let speed = speedMultiplier(for: motorId)
        return UInt64(Double(base) / max(0.2, speed))
    }

    // MARK: - Decision Making (called by ConsciousnessEngine)

    func makeDecisions(bodyBudget: BodyBudgetState, consciousnessLevel: Double, freeEnergy: Double) {
        guard isEnabled else { return }
        decisionCount += 1

        let valence = bodyBudget.valence
        let arousal = bodyBudget.arousal
        let thermal = bodyBudget.thermalLevel
        _ = bodyBudget.cpuLoad
        let isCalibrating = bodyBudget.isCalibrating
        let paraLevel = bodyBudget.parasympatheticLevel

        // ── Safety override check ──
        // Thermal .critical → safety takes over
        if thermal >= 0.9 || paraLevel == .forcedSleep {
            activateSafetyOverride(reason: "Termisk kritisk eller tvångsvila aktiv")
            return
        }

        // Check for depression loop (consistently under-driving)
        let avgSpeed = motors.map(\.speed).reduce(0, +) / Double(motors.count)
        if avgSpeed < 0.4 {
            consecutiveLowDecisions += 1
            if consecutiveLowDecisions >= maxConsecutiveLow {
                activateSafetyOverride(reason: "Detekterat depressionsmönster — alla motorer underdrivna i \(consecutiveLowDecisions) beslut")
                return
            }
        } else {
            consecutiveLowDecisions = max(0, consecutiveLowDecisions - 1)
        }

        // Release safety override if conditions improve
        if safetyOverrideActive && thermal < 0.7 && valence > -0.3 {
            safetyOverrideActive = false
            logDecision(motorId: "system", oldSpeed: 1.0, newSpeed: 1.0,
                       reason: "Säkerhetsöverride avslutad — förhållanden förbättrade",
                       mood: "Återhämtad")
        }

        if safetyOverrideActive { return }

        // ── During calibration: minimal adjustments ──
        if isCalibrating {
            currentMood = "Vaknar... lär mig min kropp"
            return
        }

        // ── Determine mood and strategy ──
        let mood: String
        let strategy: DecisionStrategy

        if valence > 0.1 && arousal < 0.4 {
            mood = "Pigg och lugn — full kapacitet"
            strategy = .fullPower
        } else if valence > 0.0 && arousal > 0.5 {
            mood = "Energisk och alert — maximal utveckling"
            strategy = .boost
        } else if valence > -0.2 && arousal < 0.3 {
            mood = "Neutral — stabil drift"
            strategy = .normal
        } else if valence < -0.3 && thermal > 0.6 {
            mood = "Trött av värme — sparläge, bara nödvändigt"
            strategy = .conserve
        } else if valence < -0.2 {
            mood = "Lite trött — prioriterar viktiga motorer"
            strategy = .selective
        } else {
            mood = "Balanserad — anpassar mig"
            strategy = .normal
        }

        currentMood = mood

        // ── Apply strategy to motors ──
        var summaryParts: [String] = []

        for i in motors.indices {
            let motor = motors[i]
            let oldSpeed = motor.speed
            var newSpeed: Double

            switch strategy {
            case .fullPower:
                // Everything at normal or slightly above
                newSpeed = motor.importance == .critical ? 1.0 : 1.1

            case .boost:
                // Boost learning and metacognition — Eon is feeling good
                switch motor.id {
                case "learning":      newSpeed = 1.4
                case "metacognition": newSpeed = 1.3
                case "pillars":       newSpeed = 1.3
                case "autonomy":      newSpeed = 1.2
                default:              newSpeed = 1.0
                }

            case .normal:
                newSpeed = 1.0

            case .selective:
                // Reduce non-critical, keep critical
                switch motor.importance {
                case .critical: newSpeed = 0.9
                case .high:     newSpeed = 0.7
                case .medium:   newSpeed = 0.5
                }

            case .conserve:
                // Minimal — only essentials
                switch motor.importance {
                case .critical: newSpeed = 0.6
                case .high:     newSpeed = 0.4
                case .medium:   newSpeed = 0.3
                }
            }

            // Clamp to motor's individual limits
            newSpeed = max(motor.minSpeed, min(motor.maxSpeed, newSpeed))

            // Smooth transitions (don't jump instantly)
            let smoothed = oldSpeed * 0.6 + newSpeed * 0.4
            motors[i].speed = max(motor.minSpeed, min(motor.maxSpeed, smoothed))

            if abs(motors[i].speed - oldSpeed) > 0.05 {
                let pct = Int(motors[i].speed * 100)
                summaryParts.append("\(motor.name): \(pct)%")
                logDecision(motorId: motor.id, oldSpeed: oldSpeed, newSpeed: motors[i].speed,
                           reason: mood, mood: mood)
            }
        }

        if summaryParts.isEmpty {
            lastDecisionSummary = "Inga ändringar — \(mood.lowercased())"
        } else {
            lastDecisionSummary = summaryParts.joined(separator: ", ")
        }
    }

    // MARK: - Safety Override

    private func activateSafetyOverride(reason: String) {
        safetyOverrideActive = true
        consecutiveLowDecisions = 0
        currentMood = "Säkerhetsöverride: \(reason)"
        lastDecisionSummary = "SÄKERHET: Alla motorer normaliserade"

        for i in motors.indices {
            let oldSpeed = motors[i].speed
            motors[i].speed = 1.0
            if abs(oldSpeed - 1.0) > 0.05 {
                logDecision(motorId: motors[i].id, oldSpeed: oldSpeed, newSpeed: 1.0,
                           reason: "Säkerhetsöverride: \(reason)", mood: "Säkerhet")
            }
        }
    }

    // MARK: - Logging

    private func logDecision(motorId: String, oldSpeed: Double, newSpeed: Double, reason: String, mood: String) {
        let decision = MotorDecision(
            timestamp: Date(),
            motorId: motorId,
            motorName: motors.first(where: { $0.id == motorId })?.name ?? motorId,
            oldSpeed: oldSpeed,
            newSpeed: newSpeed,
            reason: reason,
            mood: mood,
            decisionNumber: decisionCount
        )
        decisionLog.append(decision)
        if decisionLog.count > maxLogEntries {
            decisionLog.removeFirst(decisionLog.count - maxLogEntries)
        }
    }

    // MARK: - Log Export

    var exportableLog: String {
        var lines: [String] = []
        lines.append("═══ Eon Motorrummet — Beslutslogg ═══")
        lines.append("Exporterad: \(Date().formatted(.dateTime))")
        lines.append("Beslut totalt: \(decisionCount)")
        lines.append("Säkerhetsöverride aktiv: \(safetyOverrideActive ? "Ja" : "Nej")")
        lines.append("Humör: \(currentMood)")
        lines.append("")
        lines.append("─── Aktuella motorhastigheter ───")
        for motor in motors {
            lines.append("  \(motor.name): \(Int(motor.speed * 100))% [\(motor.importance.label)]")
        }
        lines.append("")
        lines.append("─── Beslutshistorik ───")
        for decision in decisionLog.reversed() {
            let time = decision.timestamp.formatted(.dateTime.hour().minute().second())
            lines.append("[\(time)] #\(decision.decisionNumber) \(decision.motorName): \(Int(decision.oldSpeed * 100))% → \(Int(decision.newSpeed * 100))%")
            lines.append("  Anledning: \(decision.reason)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Motor State

struct MotorState: Identifiable {
    let id: String
    let name: String
    let description: String
    var speed: Double       // 0.2 to 1.5 (current)
    let minSpeed: Double    // Floor — can never go below
    let maxSpeed: Double    // Ceiling — can never exceed
    let importance: MotorImportance
}

enum MotorImportance {
    case critical   // Core consciousness — always prioritized
    case high       // Important for cognitive function
    case medium     // Can be reduced when stressed

    var label: String {
        switch self {
        case .critical: return "Kritisk"
        case .high:     return "Hög"
        case .medium:   return "Medel"
        }
    }

    var color: String {
        switch self {
        case .critical: return "#EF4444"
        case .high:     return "#F59E0B"
        case .medium:   return "#3B82F6"
        }
    }
}

// MARK: - Motor Decision Log Entry

struct MotorDecision: Identifiable {
    let id = UUID()
    let timestamp: Date
    let motorId: String
    let motorName: String
    let oldSpeed: Double
    let newSpeed: Double
    let reason: String
    let mood: String
    let decisionNumber: Int
}

// MARK: - Decision Strategy (internal)

private enum DecisionStrategy {
    case fullPower  // Valence positive, low arousal — everything runs well
    case boost      // Energetic — boost learning/development
    case normal     // Neutral — standard speeds
    case selective  // Mildly stressed — reduce non-critical
    case conserve   // Stressed — minimal necessary only
}
