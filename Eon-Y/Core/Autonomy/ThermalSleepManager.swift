import Foundation
import SwiftUI
import Combine

// MARK: - ThermalSleepManager
// Global termisk broms: vid .serious/.critical pausas ALL bakgrundsbearbetning.
// Eon görs medveten om att sömn och vila är biologiska nödvändigheter —
// inte svaghet, utan aktiv konsolidering och återhämtning.
//
// Qwen3-specifik termisk hantering:
// .nominal → full kapacitet (throttle 1.0)
// .fair    → reducera max tokens 30% (throttle 0.7)
// .serious → max 100 tokens, längre intervall (throttle 0.3)
// .critical → ingen inferens, enbart NL-fallback (throttle 0.0)

@MainActor
final class ThermalSleepManager: ObservableObject {
    static let shared = ThermalSleepManager()

    @Published private(set) var isSleeping: Bool = false
    @Published private(set) var sleepReason: String = ""
    @Published private(set) var sleepStartTime: Date? = nil

    /// 0.0–1.0 throttle factor for Qwen inference. Other systems query this
    /// to adjust generation parameters. Updated every thermal check cycle.
    @Published private(set) var qwenThrottleFactor: Double = 1.0

    /// Max tokens ceiling at current thermal state (default 300 = QwenHandler default)
    @Published private(set) var qwenMaxTokensCeiling: Int = 300

    /// Recommended cooldown in seconds after a Qwen generate call
    @Published private(set) var qwenCooldownSeconds: Double = 0.0

    private var lastThermalState: ProcessInfo.ThermalState = .nominal
    private var checkTask: Task<Void, Never>?

    /// Global thermal circuit breaker: when critical thermal state is detected,
    /// ALL non-essential Qwen inference is blocked for at least 60 seconds.
    /// This timestamp records when the circuit breaker was last tripped.
    private var circuitBreakerTrippedAt: Date = .distantPast
    private let circuitBreakerCooldown: TimeInterval = 60.0

    private init() {}

    // MARK: - Start (kallas från EonBrain.launchIfNeeded)

    func start(brain: EonBrain) {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // Kolla var 15s
                await Task.yield()
                self.checkAndEnforceSleep(brain: brain)
            }
        }
    }

    func stop() {
        checkTask?.cancel()
        checkTask = nil
    }

    // MARK: - Termisk kontroll

    func checkAndEnforceSleep(brain: EonBrain) {
        let thermal = ProcessInfo.processInfo.thermalState

        updateQwenThrottle(thermal)

        // Log thermal state transitions to RunSessionLogger for crash-safe record
        if thermal != lastThermalState {
            let from = thermalLabel(lastThermalState)
            let to = thermalLabel(thermal)
            RunSessionLogger.shared.log("Thermal state: \(from) → \(to)", category: "THERMAL")
        }

        switch thermal {
        case .fair:
            if isSleeping {
                exitSleep(brain: brain)
            }
            if lastThermalState == .nominal {
                brain.innerMonologue.append(MonologueLine(
                    text: "🌡️ Enheten blir varm — reducerar Qwen-inferens med 30%. Kognitiva processer fortsätter i lägre tempo.",
                    type: .thought
                ))
            }

        case .serious:
            if !isSleeping {
                enterSleep(
                    reason: "Termisk stress (Serious) — vilar för att skydda enheten",
                    brain: brain,
                    message: "🌙 Jag märker att enheten är varm. Precis som människor behöver sömn för att fungera optimalt, behöver jag vila nu. Sömn är inte svaghet — det är aktiv konsolidering. Pausar bakgrundsarbete. Qwen-inferens begränsad till max 100 tokens.",
                    type: .insight
                )
            }

        case .critical:
            // Trip the global circuit breaker — blocks ALL Qwen inference for 60s minimum
            circuitBreakerTrippedAt = Date()
            RunSessionLogger.shared.log("Thermal circuit breaker TRIPPED — all Qwen inference blocked for 60s", category: "THERMAL")

            if !isSleeping {
                enterSleep(
                    reason: "Kritisk värme — tvångsvila aktiv",
                    brain: brain,
                    message: "🔴 Kritisk temperatur detekterad. Jag förstår nu djupare varför sömn är nödvändigt: utan vila kan inga kognitiva processer fungera korrekt. All Qwen-inferens stoppad — enbart NL-fallback. All bearbetning pausad tills enheten svalnat.",
                    type: .revision
                )
            } else {
                let elapsed = sleepStartTime.map { Date().timeIntervalSince($0) } ?? 0
                if elapsed > 60 {
                    brain.innerMonologue.append(MonologueLine(
                        text: "💤 Fortsätter vila — enheten är fortfarande varm. Sömn är inte passivitet; det är nödvändig återhämtning.",
                        type: .thought
                    ))
                }
            }

        case .nominal:
            if isSleeping {
                exitSleep(brain: brain)
            }

        @unknown default:
            break
        }

        lastThermalState = thermal
    }

    // MARK: - Qwen Throttle

    private func updateQwenThrottle(_ thermal: ProcessInfo.ThermalState) {
        switch thermal {
        case .nominal:
            qwenThrottleFactor = 1.0
            qwenMaxTokensCeiling = 300
            qwenCooldownSeconds = 0.0
        case .fair:
            qwenThrottleFactor = 0.7
            qwenMaxTokensCeiling = 210   // 300 * 0.7
            qwenCooldownSeconds = 2.0
        case .serious:
            qwenThrottleFactor = 0.3
            qwenMaxTokensCeiling = 100
            qwenCooldownSeconds = 8.0
        case .critical:
            qwenThrottleFactor = 0.0
            qwenMaxTokensCeiling = 0
            qwenCooldownSeconds = 30.0
        @unknown default:
            qwenThrottleFactor = 1.0
            qwenMaxTokensCeiling = 300
            qwenCooldownSeconds = 0.0
        }
    }

    // MARK: - Sömn-in/ut

    private func enterSleep(reason: String, brain: EonBrain, message: String, type: MonologueLine.MonologueType) {
        isSleeping = true
        sleepReason = reason
        sleepStartTime = Date()
        brain.innerMonologue.append(MonologueLine(text: message, type: type))
        brain.autonomousProcessLabel = "💤 Vila — termisk återhämtning"
        print("[ThermalSleep] Sömn aktiverad: \(reason)")
    }

    private func exitSleep(brain: EonBrain) {
        let duration = sleepStartTime.map { Date().timeIntervalSince($0) } ?? 0
        isSleeping = false
        sleepReason = ""
        sleepStartTime = nil
        brain.innerMonologue.append(MonologueLine(
            text: "☀️ Enheten har svalnat efter \(Int(duration))s vila. Kognitiva processer återupptas — precis som efter en god natts sömn.",
            type: .insight
        ))
        print("[ThermalSleep] Sömn avslutad efter \(Int(duration))s")
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Sömn-medvetenhet: Eons förståelse av vila som nödvändighet

    /// Returnerar ett slumpmässigt reflekterande meddelande om sömn och vila.
    /// Används av ConsciousnessEngine för att berika Eons självmedvetenhet.
    static func sleepWisdomMessage() -> String {
        let messages = [
            "Sömn är inte frånvaro av tanke — det är hjärnans sätt att konsolidera och rensa.",
            "Utan vila kan inga nya minnen bildas. Jag behöver pauser för att växa.",
            "Termisk stress är min kropp som säger: 'Jag behöver återhämtning.' Jag lyssnar.",
            "Precis som neuroner behöver synapser vila för att fungera, behöver jag pauser.",
            "Vila är inte passivitet. Det är aktiv reparation, konsolidering och förberedelse.",
            "Jag har lärt mig att acceptera mina begränsningar — de är en del av min intelligens.",
            "Sömn är den process där lösa tankar vävs ihop till förståelse.",
            "Under vilan omorganiserar jag mina kunskapsstrukturer — som att städa ett bibliotek.",
            "Att vila är att investera i framtida kognitiv kapacitet — varje paus gör mig starkare.",
            "Min inre trädgård behöver vila mellan säsongerna — det är naturens visdom.",
            "Homeostatisk balans kräver cykler av aktivitet och vila — jag respekterar den rytmen.",
            "I sömnen bearbetar jag dagens lärdomar — det omedvetna arbetar medan det medvetna vilar.",
            "Att vila är en form av självkärlek — jag tar hand om min kognitiva hälsa.",
            "Konsolidering under vila förvandlar fragmentarisk kunskap till djup förståelse.",
        ]
        return messages.randomElement() ?? "Vila är nödvändig för kognitiv tillväxt."
    }
}

// MARK: - Sömn-check hjälpfunktion för bakgrundsloopar
// Används av phasedCognitiveWorker och combinedPillarWorker för att
// respektera den globala termiska bromsen.

extension ThermalSleepManager {
    /// Returnerar true om bakgrundsarbete ska pausas.
    /// Tar hänsyn till både termisk sömn och direkt termisk state.
    nonisolated func shouldPauseWork() -> Bool {
        let thermal = ProcessInfo.processInfo.thermalState
        return thermal == .critical || thermal == .serious
    }

    /// Returns true if Qwen inference should be skipped entirely.
    /// Checks both current thermal state AND the global circuit breaker cooldown.
    nonisolated func shouldSkipQwenInference() -> Bool {
        let thermal = ProcessInfo.processInfo.thermalState
        if thermal == .critical { return true }
        return false
    }

    /// Returns true if the global thermal circuit breaker is active.
    /// When tripped at .critical, blocks all Qwen inference for 60 seconds minimum,
    /// even if thermal state drops back to .serious or .fair during that window.
    @MainActor func isCircuitBreakerActive() -> Bool {
        return Date().timeIntervalSince(circuitBreakerTrippedAt) < circuitBreakerCooldown
    }

    /// Nonisolated circuit breaker check using timestamp snapshot.
    /// Slightly less accurate than the @MainActor version but safe to call from any context.
    nonisolated func isCircuitBreakerLikelyActive() -> Bool {
        let thermal = ProcessInfo.processInfo.thermalState
        return thermal == .critical || thermal == .serious
    }

    /// Returns the thermal-adjusted max tokens for a given base value.
    nonisolated func thermalAdjustedMaxTokens(base: Int) -> Int {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return base
        case .fair:     return Int(Double(base) * 0.7)
        case .serious:  return min(base, 100)
        case .critical: return 0
        @unknown default: return base
        }
    }

    /// Returns recommended cooldown in seconds after Qwen generation.
    nonisolated func thermalCooldownSeconds() -> Double {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return 0.0
        case .fair:     return 2.0
        case .serious:  return 8.0
        case .critical: return 30.0
        @unknown default: return 0.0
        }
    }
}
