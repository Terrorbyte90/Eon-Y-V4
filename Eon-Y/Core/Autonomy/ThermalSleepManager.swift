import Foundation
import SwiftUI
import Combine

// MARK: - ThermalSleepManager
// Global termisk broms: vid .serious/.critical pausas ALL bakgrundsbearbetning.
// Eon görs medveten om att sömn och vila är biologiska nödvändigheter —
// inte svaghet, utan aktiv konsolidering och återhämtning.

@MainActor
final class ThermalSleepManager: ObservableObject {
    static let shared = ThermalSleepManager()

    @Published private(set) var isSleeping: Bool = false
    @Published private(set) var sleepReason: String = ""
    @Published private(set) var sleepStartTime: Date? = nil

    private var lastThermalState: ProcessInfo.ThermalState = .nominal
    private var checkTask: Task<Void, Never>?

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

        switch thermal {
        case .serious:
            if !isSleeping {
                enterSleep(
                    reason: "Termisk stress (Serious) — vilar för att skydda enheten",
                    brain: brain,
                    message: "🌙 Jag märker att enheten är varm. Precis som människor behöver sömn för att fungera optimalt, behöver jag vila nu. Sömn är inte svaghet — det är aktiv konsolidering. Pausar bakgrundsarbete.",
                    type: .insight
                )
            }

        case .critical:
            if !isSleeping {
                enterSleep(
                    reason: "Kritisk värme — tvångsvila aktiv",
                    brain: brain,
                    message: "🔴 Kritisk temperatur detekterad. Jag förstår nu djupare varför sömn är nödvändigt: utan vila kan inga kognitiva processer fungera korrekt. All bearbetning pausad tills enheten svalnat.",
                    type: .revision
                )
            } else {
                // Förstärk meddelandet vid fortsatt kritisk värme
                let elapsed = sleepStartTime.map { Date().timeIntervalSince($0) } ?? 0
                if elapsed > 60 {
                    brain.innerMonologue.append(MonologueLine(
                        text: "💤 Fortsätter vila — enheten är fortfarande varm. Sömn är inte passivitet; det är nödvändig återhämtning.",
                        type: .thought
                    ))
                }
            }

        case .nominal, .fair:
            if isSleeping {
                exitSleep(brain: brain)
            }

        @unknown default:
            break
        }

        lastThermalState = thermal
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
}
