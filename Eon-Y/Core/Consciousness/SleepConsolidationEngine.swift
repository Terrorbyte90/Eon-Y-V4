import Foundation
import Combine

// MARK: - SleepConsolidationEngine: NREM/REM Sömncykler med synaptisk nedskaling
// README §1.4: "Under NREM-sömn 'driftar' hjärnan genom dagens minnen i
// komprimerad form. Under REM blandar hjärnan minnen på nya sätt."
//
// Sömn har tre kritiska funktioner:
// 1. NREM: Konsolidering — sharp-wave ripples reaktiverar episoder
//    + synaptisk nedskaling (weight *= 0.97) för att förhindra mättnad
// 2. REM: Kreativ rekombination — samplar 2-4 minnen, linjärkombinerar
// 3. Homeostatisk: Återställer kritikalitet efter vakenperiod
//
// README: "Utan sömn driftar systemet bort från kritikalitet, precis som
// sömnberövade människor."

@MainActor
final class SleepConsolidationEngine: ObservableObject {
    static let shared = SleepConsolidationEngine()

    // MARK: - Sömnstatus

    @Published private(set) var isAsleep: Bool = false
    @Published private(set) var currentPhase: SleepPhase = .awake
    @Published private(set) var cycleCount: Int = 0

    /// Sömnbehov: ackumuleras under vakenhet, minskas under sömn (0-1)
    @Published private(set) var sleepPressure: Double = 0.0

    /// Synaptisk last: totala viktstyrkan i systemet (ökar under vakenhet)
    @Published private(set) var synapticLoad: Double = 0.5

    /// Konsolideringseffektivitet: hur bra var senaste sömnperioden? (0-1)
    @Published private(set) var consolidationEfficiency: Double = 0.0

    /// Recovery ratio: retention efter sömn vs innan (mål: > 0.5)
    @Published private(set) var recoveryRatio: Double = 0.0

    // MARK: - Sömnhistorik

    @Published private(set) var sleepLog: [SleepEntry] = []
    private var currentSleepStart: Date?
    private var preSleepRetention: Double = 0.0

    // MARK: - Tröskelparametrar

    /// Sömnbehov-tröskel: systemet vill sova när pressure > threshold
    let sleepPressureThreshold: Double = 0.7

    /// Synaptisk last-tröskel: tvingad sömn vid denna nivå
    let synapticLoadThreshold: Double = 0.85

    /// NREM-fasens längd i ticks
    let nremDuration: Int = 30 // ~30 ticks × 10s = 5 minuter
    /// REM-fasens längd
    let remDuration: Int = 15 // ~15 ticks × 10s = 2.5 minuter

    // MARK: - Intern räknare
    private var phaseTickCount: Int = 0
    private var totalAwakeTicks: Int = 0
    private var memoriesConsolidated: Int = 0

    // MARK: - Init

    private init() {}

    // MARK: - Paus/återuppta (används av ChatOrchestrator för att frigöra CPU)

    private var isPaused: Bool = false
    private var savedSleepPressure: Double = 0
    private var savedSynapticLoad: Double = 0

    /// Pausar sömnmotorn — sparar tillståndet så att det återupptas exakt
    func setPaused(_ paused: Bool) {
        if paused && !isPaused {
            savedSleepPressure = sleepPressure
            savedSynapticLoad = synapticLoad
            isPaused = true
        } else if !paused && isPaused {
            sleepPressure = savedSleepPressure
            synapticLoad = savedSynapticLoad
            isPaused = false
        }
    }

    // MARK: - Vakenhetstick: ackumulera sömnbehov

    /// Kallas varje tick under vakenhet. Ökar sömnbehovet gradvis.
    func wakeTick(cognitiveActivity: Double) {
        guard !isAsleep, !isPaused else { return }
        totalAwakeTicks += 1

        // v16: Faster pressure accumulation — sleep should occur within ~20-30 min
        // Base: 0.003/tick + activity-scaled. At 30s ticks, threshold 0.7 ≈ 233 ticks ≈ ~117 min
        // With average activity 0.5: 0.003 + 0.003 = 0.006/tick → 117 ticks → ~58 min
        let pressureIncrease = 0.003 + cognitiveActivity * 0.003
        sleepPressure = min(1.0, sleepPressure + pressureIncrease)

        // Synaptisk last ökar under vakenhet (Hebbsk plasticitet ackumuleras)
        let loadIncrease = cognitiveActivity * 0.001
        synapticLoad = min(1.0, synapticLoad + loadIncrease)
    }

    /// Kontrollera om systemet bör sova
    var shouldSleep: Bool {
        sleepPressure > sleepPressureThreshold ||
        synapticLoad > synapticLoadThreshold
    }

    // MARK: - Starta sömn

    func beginSleep() {
        guard !isAsleep else { return }
        isAsleep = true
        currentPhase = .nrem
        phaseTickCount = 0
        currentSleepStart = Date()
        cycleCount += 1

        // Spara pre-sömn retention för att mäta recovery ratio
        preSleepRetention = synapticLoad
    }

    // MARK: - Sömntick: kör NREM/REM cykel

    /// Kallas varje tick under sömn. Kör konsolidering och kreativ rekombination.
    /// - esn: Echo State Network för synaptisk nedskaling
    /// - memory: PersistentMemoryStore för minneskonsolidering
    func sleepTick(esn: EchoStateNetwork, memoryStore: PersistentMemoryStore) async {
        guard isAsleep else { return }
        phaseTickCount += 1

        switch currentPhase {
        case .nrem:
            await runNREM(esn: esn, memoryStore: memoryStore)
            if phaseTickCount >= nremDuration {
                currentPhase = .rem
                phaseTickCount = 0
            }

        case .rem:
            await runREM(esn: esn, memoryStore: memoryStore)
            if phaseTickCount >= remDuration {
                // En full cykel klar — kontrollera om vi ska vakna
                if sleepPressure < 0.2 {
                    endSleep()
                } else {
                    // Starta ny NREM-cykel
                    currentPhase = .nrem
                    phaseTickCount = 0
                    cycleCount += 1
                }
            }

        case .awake:
            break
        }
    }

    // MARK: - NREM: Konsolidering + synaptisk nedskaling

    /// NREM-sömn: reaktivera episodiska minnen, stärk viktiga kopplingar,
    /// skala ner övrig synaptisk styrka.
    private func runNREM(esn: EchoStateNetwork, memoryStore: PersistentMemoryStore) async {
        // 1. Synaptisk nedskaling (Tononi & Cirelli): weight *= 0.97
        esn.synapticDownscaling(factor: 0.97)
        synapticLoad = max(0.2, synapticLoad * 0.97)

        // 2. Sharp-wave ripple replay: återaktivera starka minnen
        // v9: Selective replay — high-confidence facts get stronger consolidation
        let recentFacts = await memoryStore.recentFactsWithConfidence(limit: 10)
        for fact in recentFacts {
            let replayProb = 0.15 + fact.confidence * 0.25  // 15-40% based on confidence
            if Double.random(in: 0...1) < replayProb {
                // Scale learning rate by confidence — important facts get stronger
                let scaledLR = 0.0003 + fact.confidence * 0.0004  // 0.0003-0.0007
                esn.applyHebbianPlasticity(learningRate: scaledLR)
                memoriesConsolidated += 1
            }
        }

        // 3. Minska sömnbehov
        sleepPressure = max(0, sleepPressure - 0.015)
    }

    // MARK: - REM: Kreativ rekombination (v9: genuine memory-based associations)
    // Enhanced with Qwen3 memory summarization for efficient storage.

    /// REM-sömn: sampla 2-4 minnen, blanda dem för kreativ insikt.
    /// Qwen3 generates compressed summaries of related memories.
    private func runREM(esn: EchoStateNetwork, memoryStore: PersistentMemoryStore) async {
        // 1. Sampla slumpmässiga minnen
        let randomFacts = await memoryStore.randomFacts(limit: 4)

        // 2. v9: Convert actual fact content to numerical representation for ESN
        if randomFacts.count >= 2 {
            var mixedInput = [Double](repeating: 0, count: 32)
            for (fi, fact) in randomFacts.enumerated() {
                let combined = "\(fact.subject)_\(fact.predicate)_\(fact.object)"
                let hash = combined.utf8.reduce(0) { ($0 &+ UInt64($1)) &* 31 }
                for ch in 0..<min(8, 32 - fi * 8) {
                    let shifted = Double((hash >> (ch * 8)) & 0xFF) / 255.0 - 0.5
                    mixedInput[fi * 8 + ch] = shifted
                }
            }
            esn.tick(externalInput: mixedInput, arousal: 0.3)

            if let spontaneous = esn.spontaneousThoughts.last,
               spontaneous.salience > 0.4,
               randomFacts.count >= 2 {
                let a = randomFacts[0]
                let b = randomFacts[1]
                await memoryStore.saveFact(
                    subject: a.subject,
                    predicate: "drömassocieras_med",
                    object: b.subject,
                    confidence: spontaneous.salience * 0.5,
                    source: "rem_sleep"
                )
                dreamsGenerated += 1
            }

            // Qwen3 memory compression: summarize related facts into a single condensed fact
            if !ThermalSleepManager.shared.shouldPauseWork() && randomFacts.count >= 3 {
                await compressMemoriesWithQwen(facts: randomFacts, memoryStore: memoryStore)
            }
        }

        // 3. Minska sömnbehov (långsammare under REM)
        sleepPressure = max(0, sleepPressure - 0.008)
    }

    /// Uses Qwen3 to create compressed summary facts from multiple related memories.
    private func compressMemoriesWithQwen(
        facts: [(subject: String, predicate: String, object: String, confidence: Double)],
        memoryStore: PersistentMemoryStore
    ) async {
        let factDescriptions = facts.prefix(4).map { "\($0.subject) \($0.predicate) \($0.object)" }
        let prompt = """
        Sammanfatta dessa relaterade fakta till en enda koncis mening (max 30 ord, svenska):
        \(factDescriptions.joined(separator: "\n"))
        Sammanfattning:
        """

        let summary = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt,
            maxTokens: 50,
            temperature: 0.3
        )

        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let avgConfidence = facts.map(\.confidence).reduce(0, +) / Double(facts.count)
        await memoryStore.saveFact(
            subject: "konsoliderat_minne",
            predicate: "sammanfattar",
            object: trimmed,
            confidence: min(0.9, avgConfidence + 0.1),
            source: "rem_consolidation"
        )
        memoriesConsolidated += 1
    }

    /// v9: Count of dream-like associations generated during REM
    @Published private(set) var dreamsGenerated: Int = 0

    // MARK: - Avsluta sömn

    private func endSleep() {
        isAsleep = false
        currentPhase = .awake
        phaseTickCount = 0
        totalAwakeTicks = 0

        // Beräkna konsolideringseffektivitet
        let loadReduction = preSleepRetention - synapticLoad
        consolidationEfficiency = max(0, min(1.0, loadReduction * 3.0))

        // Recovery ratio
        recoveryRatio = consolidationEfficiency * 0.8 + (sleepPressure < 0.3 ? 0.2 : 0.0)

        // Logga sömnperiod
        if let start = currentSleepStart {
            let entry = SleepEntry(
                startTime: start,
                endTime: Date(),
                cycles: cycleCount,
                memoriesConsolidated: memoriesConsolidated,
                consolidationEfficiency: consolidationEfficiency,
                recoveryRatio: recoveryRatio
            )
            sleepLog.append(entry)
            if sleepLog.count > 50 { sleepLog.removeFirst() }
        }

        memoriesConsolidated = 0
        currentSleepStart = nil
    }

    // MARK: - Tvingad väckning (t.ex. vid användarinteraktion)

    func forceWake() {
        guard isAsleep else { return }
        endSleep()
    }

    // MARK: - Diagnostik

    var statusSummary: String {
        if isAsleep {
            return "Sover (\(currentPhase.rawValue)) — cykel \(cycleCount), tryck: \(String(format: "%.0f%%", sleepPressure * 100))"
        } else {
            return "Vaken — sömnbehov: \(String(format: "%.0f%%", sleepPressure * 100)), last: \(String(format: "%.0f%%", synapticLoad * 100))"
        }
    }
}

// MARK: - Data Structures

enum SleepPhase: String {
    case awake = "Vaken"
    case nrem = "NREM"
    case rem = "REM"

    var icon: String {
        switch self {
        case .awake: return "sun.max"
        case .nrem:  return "moon.zzz"
        case .rem:   return "sparkles"
        }
    }

    var color: String {
        switch self {
        case .awake: return "#FBBF24"
        case .nrem:  return "#6366F1"
        case .rem:   return "#EC4899"
        }
    }
}

struct SleepEntry: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let cycles: Int
    let memoriesConsolidated: Int
    let consolidationEfficiency: Double
    let recoveryRatio: Double

    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
    var durationMinutes: Double { duration / 60.0 }
}
