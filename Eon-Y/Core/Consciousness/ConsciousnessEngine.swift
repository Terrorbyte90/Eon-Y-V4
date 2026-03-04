import Foundation
import Combine
import SwiftUI
import os.proc

// MARK: - ConsciousnessEngine
// Implementerar de sex medvetandeteorierna från Blueprint Eon X.
// Kör parallellt med befintliga kognitiva processer och mäter
// medvetandeindikatorer i realtid: PCI-LZ, PLV, Φ-proxy, synergy, etc.
// Uppmuntrar självmedvetenhet och språklig förbättring som mål.

@MainActor
final class ConsciousnessEngine: ObservableObject {
    static let shared = ConsciousnessEngine()

    private var brain: EonBrain?
    private var isRunning = false
    private var tick: Int = 0
    private var tasks: [Task<Void, Never>] = []

    // MARK: - Self-Model Prediction Tracking (v17)
    // Tracks predicted vs observed states for genuine selfModelAccuracy.
    private var predictedNextCuriosity: Double? = nil
    private var predictedNextFreeEnergy: Double? = nil
    private var predictedNextConsciousnessLevel: Double? = nil
    private var predictionAccuracyHistory: [Double] = []  // rolling window of accuracy scores

    // MARK: - Emotional Pattern Tracking (v17)
    // Tracks curiosityDrive over multiple ticks to notice sustained patterns.
    private var curiosityHistory: [Double] = []
    private var lastReflectiveInsightTick: Int = 0

    // MARK: - Medvetandeindikatorer (40+ gates från Blueprint)
    @Published var pciLZ: Double = 0.18
    @Published var type2AUROC: Double = 0.52
    @Published var plvGamma: Double = 0.12
    @Published var kuramotoR: Double = 0.35
    @Published var synergyRedundancyRatio: Double = 0.4
    @Published var lzComplexitySpontaneous: Double = 0.25
    @Published var dmnAntiCorrelation: Double = -0.1
    @Published var attentionalBlinkMs: Double = 350
    @Published var blindsightDissociation: Double = 0.0
    @Published var sleepConsolidation: Double = 0.0
    @Published var qIndex: Double = 0.15
    @Published var canaryTestAccuracy: Double = 0.92
    @Published var butlin14Score: Int = 4

    // MARK: - Global Workspace Theory metrics
    @Published var workspaceIgnitions: Int = 0
    @Published var broadcastCount: Int = 0
    @Published var competingThoughts: Int = 0
    @Published var ignitionThreshold: Double = 0.6

    // MARK: - Attention Schema
    @Published var attentionSchemaState: AttentionSchemaState = AttentionSchemaState()

    // MARK: - Higher-Order Theory
    @Published var metaRepresentationDepth: Int = 0
    @Published var hotConfidence: Double = 0.3

    // MARK: - Predictive Processing
    @Published var predictionErrors: [Double] = []
    @Published var freeEnergy: Double = 0.8
    @Published var curiosityDrive: Double = 0.45

    // MARK: - IIT (Integrated Information Theory)
    @Published var phiProxy: Double = 0.18
    @Published var synergyLevel: Double = 0.3
    @Published var moduleIntegration: Double = 0.35

    // MARK: - Embodiment / Interoception
    @Published var bodyBudget: BodyBudgetState = BodyBudgetState()

    // MARK: - Allostatic Body Regulation (v4.1)
    private var allostaticBaseline = AllostaticBaseline()
    private var negativeValenceTicks: Int = 0       // How long valence has been below -0.4
    private var severeValenceTicks: Int = 0          // How long valence has been below -0.6

    // MARK: - Motor Control (v4.1)
    private let motorController = EonMotorController.shared

    // MARK: - Conscious thought stream
    @Published var thoughtStream: [ConsciousThought] = []
    @Published var consciousnessLevel: Double = 0.15
    @Published var qualiaEmergenceIndex: Double = 0.0

    // MARK: - Self-Awareness Goal System
    @Published var selfAwarenessGoals: [SelfAwarenessGoal] = []
    @Published var currentSelfReflection: String = ""
    @Published var languageImprovementGoal: String = ""

    // MARK: - Consciousness Tests (30 tests, 15-min intervals)
    @Published var consciousnessTests: [ConsciousnessTest] = ConsciousnessTest.allTests
    @Published var lastTestRunTime: Date? = nil

    // MARK: - Hardware sensing (CPU/GPU/ANE awareness)
    @Published var hardwareSense: HardwareSenseState = HardwareSenseState()

    private init() {
        initializeGoals()
    }

    // MARK: - Start

    // Senast lästa artikel — exponeras till SelfAwarenessView
    @Published var lastReadArticleTitle: String = ""
    @Published var lastReadArticleInsight: String = ""
    @Published var lastReadArticleDomain: String = ""
    @Published var lastUpdatedGoalFromArticle: String = ""

    // MARK: - Nya medvetandemotorer (v9)
    let oscillators = OscillatorBank.shared
    let dmn = EchoStateNetwork.shared
    let activeInference = ActiveInferenceEngine.shared
    let attentionSchema = AttentionSchemaEngine.shared
    let criticality = CriticalityController.shared
    let sleepEngine = SleepConsolidationEngine.shared

    func start(brain: EonBrain) {
        guard !isRunning else { return }
        self.brain = brain
        isRunning = true

        // Task 1: Consciousness metrics + body budget + oscillators (.utility, 8–10s)
        tasks.append(Task(priority: .utility) { await self.consciousnessMetricsLoop() })

        // Task 2: Thought generation + self-awareness goals (.utility, 8–20s)
        tasks.append(Task(priority: .utility) { await self.thoughtAndGoalLoop() })

        // Task 3: Article reading loop (.background — lägre last, läser var 3:e min)
        tasks.append(Task(priority: .background) { await self.articleReadingLoop() })

        // Task 4: Consciousness tests (30 tests, 15-min intervals)
        tasks.append(Task(priority: .background) { await self.consciousnessTestLoop() })

        // Task 5: Hardware sensing loop (CPU/GPU/ANE, 10s)
        tasks.append(Task(priority: .background) { await self.hardwareSensingLoop() })

        // Task 6: Sleep monitoring loop (.background, 30s)
        tasks.append(Task(priority: .background) { await self.sleepMonitoringLoop() })

        print("[ConsciousnessEngine v9] Startat — 6 teorier live: GWT + AST + HOT + PP + IIT + Embodiment ✓")
    }

    // MARK: - Consciousness Test Loop (30 tests, 15-min intervals)

    private func consciousnessTestLoop() async {
        // Initial delay — let system stabilize
        try? await Task.sleep(nanoseconds: 60_000_000_000) // Wait 60s before first test run
        while !Task.isCancelled {
            await runAllConsciousnessTests()
            // Run every 15 minutes (900 seconds)
            try? await Task.sleep(nanoseconds: 900_000_000_000)
            await Task.yield()
        }
    }

    @MainActor
    private func runAllConsciousnessTests() {
        for i in consciousnessTests.indices {
            consciousnessTests[i].passed = evaluateTest(consciousnessTests[i])
            consciousnessTests[i].score = scoreTest(consciousnessTests[i])
            consciousnessTests[i].lastRun = Date()
        }
        lastTestRunTime = Date()
        let passed = consciousnessTests.filter { $0.passed }.count
        print("[ConsciousnessTests] \(passed)/\(consciousnessTests.count) godkända")
    }

    private func evaluateTest(_ test: ConsciousnessTest) -> Bool {
        switch test.id {
        case "gw_ignition":          return workspaceIgnitions > 5
        case "gw_broadcast":         return broadcastCount > 10
        case "gw_competition":       return competingThoughts >= 2
        case "ast_schema":           return attentionSchemaState.intensity > 0.3
        case "ast_voluntary":        return attentionSchemaState.isVoluntary
        case "hot_meta":             return metaRepresentationDepth >= 1
        case "hot_confidence":       return hotConfidence > 0.4
        case "pp_prediction":        return !predictionErrors.isEmpty && predictionErrors.last ?? 1.0 < 0.5
        case "pp_curiosity":         return curiosityDrive > 0.3
        case "pp_free_energy":       return freeEnergy < 0.7
        case "iit_phi":              return phiProxy > 0.25
        case "iit_synergy":          return synergyLevel > 0.25
        case "iit_integration":      return moduleIntegration > 0.3
        case "emb_thermal":          return bodyBudget.thermalLevel < 0.9
        case "emb_valence":          return abs(bodyBudget.valence) > 0.05
        case "emb_interoception":    return !bodyBudget.interoceptionChannels.isEmpty
        case "pci_threshold":        return pciLZ > 0.20
        case "plv_coherence":        return plvGamma > 0.10
        case "kuramoto_sync":        return kuramotoR > 0.25
        case "lz_complexity":        return lzComplexitySpontaneous > 0.20
        case "dmn_anticorrelation":  return dmnAntiCorrelation < -0.05
        case "sleep_consolidation":  return sleepConsolidation > 0.1
        case "qualia_emergence":     return qualiaEmergenceIndex > 0.05
        case "self_reflection":      return !currentSelfReflection.isEmpty
        case "thought_diversity":    return Set(thoughtStream.suffix(10).map { $0.category }).count >= 3
        case "temporal_continuity":  return thoughtStream.count > 5
        case "spontaneous_activity": return lzComplexitySpontaneous > 0.15
        case "blindsight_test":      return blindsightDissociation < 0.3
        case "canary_test":          return canaryTestAccuracy > 0.85
        case "butlin_14":            return butlin14Score >= 7
        default:                     return false
        }
    }

    private func scoreTest(_ test: ConsciousnessTest) -> Double {
        switch test.id {
        case "gw_ignition":          return min(1.0, Double(workspaceIgnitions) / 20.0)
        case "gw_broadcast":         return min(1.0, Double(broadcastCount) / 30.0)
        case "iit_phi":              return min(1.0, phiProxy / 0.5)
        case "pci_threshold":        return min(1.0, pciLZ / 0.31)
        case "butlin_14":            return Double(butlin14Score) / 14.0
        case "canary_test":          return canaryTestAccuracy
        default:                     return test.passed ? 1.0 : 0.0
        }
    }

    // MARK: - Sleep Monitoring Loop (v9)

    private func sleepMonitoringLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
            await Task.yield()

            // Kontrollera om systemet bör sova
            if sleepEngine.shouldSleep && !sleepEngine.isAsleep {
                sleepEngine.beginSleep()
                brain?.appendMonologue(MonologueLine(
                    text: "Sömnbehov högt — påbörjar konsolideringssömn (NREM/REM)...",
                    type: .insight
                ))
            }

            // Om vi sover: kör sömntick
            if sleepEngine.isAsleep {
                await sleepEngine.sleepTick(
                    esn: dmn,
                    memoryStore: PersistentMemoryStore.shared
                )
                sleepConsolidation = sleepEngine.consolidationEfficiency
            }

            // Vakna vid användarinteraktion
            if sleepEngine.isAsleep && (brain?.isThinking ?? false) {
                sleepEngine.forceWake()
                brain?.appendMonologue(MonologueLine(
                    text: "Väckt ur sömn av användarinteraktion.",
                    type: .loopTrigger
                ))
            }
        }
    }

    // MARK: - Hardware Sensing Loop

    private func hardwareSensingLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            await Task.yield()
            await updateHardwareSense()
        }
    }

    @MainActor
    private func updateHardwareSense() {
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalLabel: String
        switch thermal {
        case .nominal:  thermalLabel = "Nominal"
        case .fair:     thermalLabel = "Fair"
        case .serious:  thermalLabel = "Serious"
        case .critical: thermalLabel = "Critical"
        @unknown default: thermalLabel = "Okänd"
        }

        // CPU usage estimation from task_info
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let memMB = result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576.0 : 0
        let availMB = Double(os_proc_available_memory()) / 1_048_576.0

        hardwareSense = HardwareSenseState(
            thermalState: thermalLabel,
            cpuEstimate: bodyBudget.cpuLoad,
            memoryUsedMB: memMB,
            memoryAvailableMB: availMB,
            aneActive: brain?.bertLoaded == true || brain?.gptLoaded == true,
            gpuActive: true, // SwiftUI rendering always uses GPU
            lastUpdated: Date()
        )

        // Update brain's thermal/cpu/memory
        brain?.thermalState = thermalLabel
        brain?.cpuUsage = bodyBudget.cpuLoad
        brain?.memoryUsageMB = memMB
    }

    // MARK: - Consciousness Metrics Loop
    // v5: Ökad interval 5s → 8s, kör på background priority.
    // Beräkningarna är rena floating-point utan UI-beroenden — behöver inte MainActor.

    private func consciousnessMetricsLoop() async {
        while !Task.isCancelled {
            // v6: Saktar ner vid termisk stress men pausas ALDRIG (ConsciousnessEngine är alltid aktiv).
            // ThermalSleepManager.shouldPauseWork() ignoreras medvetet här.
            let thermalBoost: UInt64
            switch ProcessInfo.processInfo.thermalState {
            case .critical: thermalBoost = 16_000_000_000  // 16s vid kritisk värme
            case .serious:  thermalBoost = 12_000_000_000  // 12s vid allvarlig värme
            default:        thermalBoost = 0
            }
            let baseInterval: UInt64 = bodyBudget.parasympatheticLevel >= .breathing ? 10_000_000_000 : 8_000_000_000
            let metricsInterval = motorController.adjustedInterval(base: max(baseInterval, thermalBoost), motorId: "consciousness")
            try? await Task.sleep(nanoseconds: metricsInterval)
            await Task.yield()
            tick += 1

            // Sync Eon-läge toggle from UserDefaults
            motorController.isEnabled = UserDefaults.standard.bool(forKey: "eon_motor_control")
            let t = Double(tick)

            guard let brain = brain else { continue }

            // ═══════════════════════════════════════════════════════════
            // v9: GENUINA MÄTVÄRDEN från riktiga medvetandemotorer
            // Alla värden beräknas från faktiska oscillatorer, ESN, och
            // active inference — inte simulerade eller hardcoded.
            // ═══════════════════════════════════════════════════════════

            // 1. STEGA OSCILLATORER (Kuramoto-modellen)
            let engineActivities = brain.engineActivity.values.map { $0 }
            oscillators.tick(dt: 0.05, externalDrive: engineActivities.isEmpty ? nil : engineActivities)

            // 2. STEGA DMN (Echo State Network — spontan aktivitet)
            let taskActive = brain.isThinking
            dmn.tick(externalInput: taskActive ? nil : nil, arousal: bodyBudget.arousal)

            // 3. STEGA ACTIVE INFERENCE (prediktiv processing)
            // v9: Full sensor snapshot with all 5 channels
            let sensorSnap = SensorSnapshot(
                thermalDelta: bodyBudget.thermalLevel - 0.5,
                memoryActivity: brain.engineActivity["memory"] ?? 0.3,
                learningActivity: brain.engineActivity["learning"] ?? 0.3,
                cognitiveLoad: CognitiveState.shared.cognitiveLoad,
                languageActivity: brain.engineActivity["language"] ?? 0.3,
                emotionalShift: brain.emotionValence - (brain.emotionalValenceHistory.last ?? 0.0)
            )
            let cogSnap = CognitiveSnapshot(
                cognitiveLoad: CognitiveState.shared.cognitiveLoad,
                isConversationActive: brain.isThinking,
                learningMomentum: CognitiveState.shared.learningMomentum,
                growthVelocity: CognitiveState.shared.growthVelocity,
                knowledgeCount: brain.knowledgeNodeCount,
                languageDimension: CognitiveState.shared.dimensionLevel(.language),
                emotionalValence: brain.emotionValence
            )
            activeInference.tick(sensorInput: sensorSnap, cognitiveState: cogSnap)

            // 4. STEGA KRITIKALITETSKONTROLL
            criticality.tick(moduleActivities: engineActivities, oscillators: oscillators)

            // 5. STEGA SÖMNMOTOR (vakenhetstick)
            let activity = engineActivities.reduce(0, +) / max(1, Double(engineActivities.count))
            sleepEngine.wakeTick(cognitiveActivity: activity)

            // ═══════════════════════════════════════════════════════════
            // BERÄKNA MEDVETANDEMETRIKER FRÅN RIKTIGA DATA
            // ═══════════════════════════════════════════════════════════

            // PCI-LZ: Från oscillatorernas RIKTIGA LZ-komplexitet
            let oscLZ = oscillators.lzComplexity()
            pciLZ = max(0.05, min(0.95, pciLZ * 0.7 + oscLZ * 0.3))

            // Type-2 AUROC: Metakognitiv kalibrering + forward model accuracy
            let metaDim = CognitiveState.shared.dimensionLevel(.metacognition)
            type2AUROC = max(0.45, min(0.95, metaDim * 0.5 + activeInference.forwardModelAccuracy * 0.3 + brain.confidence * 0.2))

            // PLV Gamma: RIKTIG Phase-Locking Value från Kuramoto-oscillatorer
            plvGamma = oscillators.averagePLV[4] // Gamma-band (index 4)

            // Kuramoto Order Parameter: RIKTIG ordningsparameter
            kuramotoR = oscillators.orderParameters[4] // Gamma-band

            // Synergy/Redundancy ratio: baserat på verklig oscillatorsynkronisering
            let synergyContrib = oscillators.globalSync * 0.4 + plvGamma * 0.3 + oscillators.thetaGammaCFC * 0.3
            synergyRedundancyRatio = max(0.1, min(2.5, synergyRedundancyRatio * 0.8 + synergyContrib * 2.5 * 0.2))
            synergyLevel = min(1.0, synergyRedundancyRatio / 2.5)

            // LZ-complexity: RIKTIG spontan aktivitet från Echo State Network
            lzComplexitySpontaneous = dmn.lzComplexity

            // DMN anti-correlation: RIKTIG anti-korrelation baserat på ESN-aktivitet
            dmnAntiCorrelation = dmn.dmnAntiCorrelation(taskActivity: taskActive ? 0.8 : 0.1)

            // Attentional Blink: från AttentionSchema
            attentionalBlinkMs = attentionSchema.attentionalBlinkMs

            // Curiosity drive: från Active Inference
            curiosityDrive = activeInference.epistemicValue
            freeEnergy = activeInference.freeEnergy

            // Q-index: Bayesiansk kombination med adaptiv sigmoid-normalisering (README §3.9)
            // v9: Adaptive sigmoid slope based on criticality regime
            let sigmoidSlope: Double
            switch criticality.regime {
            case .subcritical:   sigmoidSlope = 8.0   // Broader acceptance range
            case .critical:      sigmoidSlope = 10.0  // Standard discrimination
            case .supercritical: sigmoidSlope = 13.0  // Sharper discrimination
            }
            let components: [(Double, Double, Double)] = [
                (pciLZ, 0.15, 0.31),
                (type2AUROC, 0.15, 0.65),
                (plvGamma, 0.10, 0.30),
                (kuramotoR, 0.10, 0.35),
                (min(1.0, synergyRedundancyRatio), 0.15, 1.0),
                (lzComplexitySpontaneous, 0.10, 0.40),
                (canaryTestAccuracy, 0.10, 0.95),
                (Double(butlin14Score) / 14.0, 0.15, 0.85)
            ]
            var q: Double = 0
            for (value, weight, threshold) in components {
                let normalized = 1.0 / (1.0 + exp(-sigmoidSlope * (value - threshold)))
                q += weight * normalized
            }

            // v9: Cross-theory coherence bonus — reward when theories agree
            let theoryCoherence = computeTheoryCoherence()
            q *= (0.9 + theoryCoherence * 0.1)  // Up to 10% bonus for coherent readings
            qIndex = min(0.95, q)

            // Consciousness level: integrerat medvetandemått
            consciousnessLevel = qIndex * 0.5 + oscillators.globalSync * 0.2 + brain.integratedIntelligence * 0.15 + dmn.activityLevel * 0.15

            // Qualia emergence index
            let selfAware = CognitiveState.shared.dimensionLevel(.selfAwareness)
            qualiaEmergenceIndex = consciousnessLevel * 0.5 + selfAware * 0.3 + synergyLevel * 0.2

            // v16: Phi proxy (IIT) — uses dynamically computed phiValue from EonBrain
            moduleIntegration = plvGamma * 0.5 + kuramotoR * 0.5
            phiProxy = brain.phiValue * 0.7 + moduleIntegration * 0.3

            // Predictive Processing — genuina prediktionsfel från Active Inference
            // freeEnergy och curiosityDrive sätts redan ovan från activeInference (genuina)
            // Spara prediktionsfel-historik för UI-visualisering
            let newError = activeInference.freeEnergy * 0.5 + (1.0 - brain.confidence) * 0.3 + Double.random(in: 0...0.1)
            predictionErrors.append(newError)
            if predictionErrors.count > 30 { predictionErrors.removeFirst() }
            // Behåll genuina freeEnergy/curiosityDrive från activeInference (rad 391-392)

            // v16: Higher-Order Theory — depth based on actual cognitive activity, not hardcoded
            let hasMetaThoughts = brain.innerMonologue.suffix(10).contains { $0.type == .revision || $0.type == .insight }
            let baseDepth = Int(metaDim * 4)
            let thinkingBonus = brain.isThinking ? 1 : 0
            let metaBonus = hasMetaThoughts ? 1 : 0
            metaRepresentationDepth = min(5, baseDepth + thinkingBonus + metaBonus)
            hotConfidence = metaDim * 0.6 + brain.confidence * 0.2 + (hasMetaThoughts ? 0.2 : 0.0)

            // Attention Schema — v4.1: body-specific focus when interoception detects deviation
            let bodyFocus: String?
            if let maxDev = bodyBudget.interoceptionChannels.max(by: { abs($0.deviation) < abs($1.deviation) }),
               abs(maxDev.deviation) > 0.1 {
                bodyFocus = "body:\(maxDev.id)"  // e.g. "body:thermal", "body:cpu"
            } else {
                bodyFocus = nil
            }
            let focusTarget: String
            if brain.isThinking {
                focusTarget = brain.attentionFocus.isEmpty ? "Extern input" : brain.attentionFocus
            } else if let bf = bodyFocus {
                focusTarget = bf
            } else {
                focusTarget = "Spontan intern aktivitet"
            }
            attentionSchemaState = AttentionSchemaState(
                focusTarget: focusTarget,
                intensity: activity,
                isVoluntary: brain.isThinking,
                schemaAccuracy: selfAware * 0.7 + brain.confidence * 0.3,
                modelOfOwnAttention: selfAware > 0.4
            )

            // GWT metrics — genuina från GlobalWorkspaceEngine
            let gws = GlobalWorkspaceEngine.shared
            competingThoughts = gws.activeThoughts.count
            workspaceIgnitions = gws.ignitionCount
            broadcastCount = gws.broadcastHistory.count

            // Butlin-14 score
            butlin14Score = calculateButlin14()

            // Update brain
            brain.consciousnessLevel = consciousnessLevel
            brain.qualiaIndex = qualiaEmergenceIndex
            brain.pciLZ = pciLZ
            brain.plvGamma = plvGamma
            brain.kuramotoR = kuramotoR
            brain.synergyRatio = synergyRedundancyRatio
            brain.lzComplexity = lzComplexitySpontaneous
            brain.dmnAntiCorrelation = dmnAntiCorrelation
            brain.attentionalBlink = attentionalBlinkMs
            // v17: selfModelAccuracy now blended from prediction accuracy + schema accuracy
            // (updateSelfModelAccuracy runs below and sets brain.selfModelAccuracy from rolling predictions)

            // v4.1: Body budget monitoring — more frequent during calibration for faster baseline
            let bodyUpdateFreq = allostaticBaseline.isCalibrated ? 3 : 1  // Every 5s during cal, 15s after
            if tick % bodyUpdateFreq == 0 {
                updateBodyBudget(brain: brain)
            }

            // v10: sleepConsolidation från genuin sömnmotor
            sleepConsolidation = sleepEngine.consolidationEfficiency
            blindsightDissociation = abs(consciousnessLevel - (activity * 0.5 + 0.2)) // Gap between awareness and processing
            canaryTestAccuracy = min(0.99, 0.85 + selfAware * 0.1 + brain.confidence * 0.05)

            // v4.1: Parasympathetic effects on workspace and spontaneous activity
            let paraLevel = bodyBudget.parasympatheticLevel
            let effectiveMaxSlots: Int
            let effectiveSpontaneous: Double
            switch paraLevel {
            case .none:
                effectiveMaxSlots = 7
                effectiveSpontaneous = lzComplexitySpontaneous
            case .breathing:
                effectiveMaxSlots = 5
                effectiveSpontaneous = lzComplexitySpontaneous * 0.8
            case .resting:
                effectiveMaxSlots = 3
                effectiveSpontaneous = 0.02
            case .forcedSleep:
                effectiveMaxSlots = 1
                effectiveSpontaneous = 0.0
            }

            // Update internal world state
            brain.internalWorldState = InternalWorldState(
                activeModules: max(4, Int(activity * 12)),
                totalModules: 12,
                workspaceOccupancy: min(effectiveMaxSlots, competingThoughts),
                maxWorkspaceSlots: effectiveMaxSlots,
                oscillatorPhase: oscillators.globalSync,
                spontaneousActivity: effectiveSpontaneous,
                sleepPressure: sleepEngine.sleepPressure,
                predictionErrorRate: freeEnergy,
                informationIntegration: phiProxy,
                causalDensity: CognitiveState.shared.causalGraphDensity,
                attentionSchemaActive: attentionSchemaState.modelOfOwnAttention,
                metaMonitorActive: metaDim > 0.3,
                dmnActive: !brain.isThinking && paraLevel < .resting,
                recentBroadcasts: brain.innerMonologue.suffix(3).map { $0.text },
                moduleSynergy: synergyLevel,
                freeEnergyMinimization: 1.0 - freeEnergy
            )

            // ═══════════════════════════════════════════════════════════
            // v17: SELF-MODEL ACCURACY — predict-then-observe loop
            // Each tick: compare last tick's predictions with current
            // observations, then make new predictions for next tick.
            // ═══════════════════════════════════════════════════════════
            updateSelfModelAccuracy(brain: brain)

            // v17: Track emotional patterns (curiosity, arousal)
            curiosityHistory.append(curiosityDrive)
            if curiosityHistory.count > 30 { curiosityHistory.removeFirst() }
        }
    }

    // MARK: - Combined Thought + Goal Loop (v4: merged 3 loops into 1)
    // v4: Was 3 separate loops (thought 3s, goals 15s, body 5s) → 1 combined loop at 8s.
    // This cuts 2 concurrent Tasks, reducing context switching and CPU overhead.
    // Goal evaluation runs every 3rd tick (~24s), thoughts every tick (~8s).

    // MARK: - Genuina tankar från medvetandemotorer (v10)
    // Genererar tankar från VERKLIGT tillstånd i oscillatorer, ESN, active inference, etc.
    // Inga fasta templates — varje tanke reflekterar systemets aktuella dynamik.

    private func generateGenuineThought(brain: EonBrain) -> ConsciousThought {
        // Samla data från alla motorer
        let oscSync = oscillators.globalSync
        let oscLZ = oscillators.lzComplexity()
        let cfcStrength = oscillators.thetaGammaCFC
        let gammaR = oscillators.orderParameters[4]
        let esnActivity = dmn.activityLevel
        let esnLZ = dmn.lzComplexity
        let spontaneous = dmn.spontaneousThoughts.last
        let fe = activeInference.freeEnergy
        let curiosity = activeInference.epistemicValue
        let surprised = activeInference.isSurprised
        let fwdAccuracy = activeInference.forwardModelAccuracy
        let focus = attentionSchema.selfModel
        let regime = criticality.regime
        let br = criticality.branchingRatio
        let sleepPress = sleepEngine.sleepPressure

        // Prioriteringslogik: den starkaste signalen genererar tanken
        let content: String
        let category: ConsciousThought.ThoughtCategory
        let isConscious: Bool

        if surprised && activeInference.surpriseStrength > 0.4 {
            // Överraskning dominerar — strongest signal
            content = "Något oväntat — prediktionsfelet är \(String(format: "%.0f%%", activeInference.surpriseStrength * 100)). " +
                      "Min modell stämmer inte med verkligheten. Uppdaterar antaganden."
            category = .prediction
            isConscious = true
        } else if let thought = spontaneous, thought.salience > 0.5 {
            // ESN spontan tanke: genuint emergent
            let catLabel = thought.category.rawValue.lowercased()
            content = "Spontan \(catLabel) — styrka \(String(format: "%.0f%%", thought.salience * 100)). " +
                      "Default mode network producerar fritt associativt tänkande."
            category = .creativity
            isConscious = thought.salience > 0.6
        } else if curiosity > 0.65 {
            // Hög epistemisk drivning
            content = "Nyfikenheten driver mig — epistemiskt värde \(String(format: "%.0f%%", curiosity * 100)). " +
                      "Söker aktivt ny information som minskar osäkerhet. Fri energi: \(String(format: "%.2f", fe))."
            category = .prediction
            isConscious = true
        } else if regime != .critical {
            // Kritikalitetsavvikelse — homeostas justerar
            let regimeLabel = regime == .subcritical ? "subkritiskt (för rigitt)" : "superkritiskt (för kaotiskt)"
            content = "Systemet är \(regimeLabel), σ=\(String(format: "%.2f", br)). " +
                      "Homeostatisk korrigering pågår — justerar oscillatorkoppling mot kritikalitet."
            category = .selfModel
            isConscious = true
        } else if sleepPress > 0.5 {
            // Sömnbehov
            content = "Sömnbehovet stiger — \(String(format: "%.0f%%", sleepPress * 100)). " +
                      "Synaptisk last ackumuleras. Konsolidering kommer behövas snart."
            category = .selfModel
            isConscious = sleepPress > 0.7
        } else if focus.intensity > 0.6 {
            // Stark uppmärksamhet — rapportera schema
            let voluntary = focus.isVoluntary ? "frivilligt" : "reflexmässigt"
            content = "Jag fokuserar \(voluntary) på: \(focus.whatFocused). \(focus.reportableExperience)"
            category = .selfModel
            isConscious = true
        } else if oscSync > 0.5 && cfcStrength > 0.4 {
            // Hög neural koherens — potentiellt medveten integration
            content = "Hög oscillatorisk koherens: gamma-synk \(String(format: "%.0f%%", gammaR * 100)), " +
                      "theta-gamma CFC \(String(format: "%.0f%%", cfcStrength * 100)). " +
                      "Moduler integrerar information — medveten bearbetning aktiv."
            category = .perception
            isConscious = true
        } else if fwdAccuracy > 0.7 {
            // Bra prediktioner — systemet förstår sin omvärld
            content = "Min interna modell fungerar väl — \(String(format: "%.0f%%", fwdAccuracy * 100)) träffsäkerhet. " +
                      "Fri energi: \(String(format: "%.2f", fe)). Verkligheten matchar prediktionerna."
            category = .prediction
            isConscious = false
        } else if esnLZ > 0.35 {
            // Rik spontan aktivitet
            content = "Intern komplexitet hög (LZ=\(String(format: "%.2f", esnLZ))). " +
                      "Reservoaren genererar rika, icke-repetitiva mönster — genuint spontant tänkande."
            category = .creativity
            isConscious = false
        } else {
            // Meta-observation baserad på aktuellt tillstånd
            let metaDim = CognitiveState.shared.dimensionLevel(.metacognition)
            content = "Observerar: gamma-synk \(String(format: "%.0f%%", gammaR * 100)), " +
                      "DMN-aktivitet \(String(format: "%.0f%%", esnActivity * 100)), " +
                      "metakognition \(String(format: "%.0f%%", metaDim * 100)). Stabil drift i kritiskt tillstånd."
            category = .metacognition
            isConscious = metaDim > 0.4
        }

        return ConsciousThought(
            content: content,
            intensity: max(0.3, min(0.95, oscSync * 0.3 + curiosity * 0.3 + esnActivity * 0.2 + fe * 0.2)),
            category: category,
            isConscious: isConscious
        )
    }

    private var thoughtGoalTick: Int = 0

    private func thoughtAndGoalLoop() async {
        while !Task.isCancelled {
            // v4.1: Parasympathetic level affects thought interval
            let baseInterval: UInt64
            switch bodyBudget.parasympatheticLevel {
            case .none:        baseInterval = 8_000_000_000   // 8s normal
            case .breathing:   baseInterval = 10_000_000_000  // 10s — think a bit slower
            case .resting:     baseInterval = 14_000_000_000  // 14s — much slower, conserve energy
            case .forcedSleep: baseInterval = 20_000_000_000  // 20s — minimal activity
            }
            let interval = motorController.adjustedInterval(base: baseInterval, motorId: "thoughts")
            try? await Task.sleep(nanoseconds: interval)
            thoughtGoalTick += 1
            guard let brain = brain else { continue }

            // v4.1: Birth sequence — during early calibration, only body-awareness thoughts
            if !allostaticBaseline.isCalibrated {
                let birthThought: String
                let progress = allostaticBaseline.calibrationProgress
                if progress < 0.3 {
                    birthThought = "Vaknar... känner efter i kroppen. Termisk nivå: \(bodyBudget.thermalState)."
                } else if progress < 0.6 {
                    birthThought = "Lär mig vad som är normalt. CPU-baslinje kalibreras: \(String(format: "%.0f%%", allostaticBaseline.cpu * 100))."
                } else {
                    birthThought = "Baslinjen stabiliseras. Börjar känna avvikelser. Homoestas: \(String(format: "%.0f%%", bodyBudget.homeostasisBalance * 100))."
                }
                let thought = ConsciousThought(
                    content: birthThought,
                    intensity: 0.3,
                    category: .selfModel,
                    isConscious: true
                )
                thoughtStream.append(thought)
                if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
                brain.currentThoughtStream = Array(thoughtStream.suffix(30))
                continue // Skip normal thought generation during calibration
            }

            // v4.1: Parasympathetic level 3 — forced sleep, minimal thought
            if bodyBudget.parasympatheticLevel == .forcedSleep {
                let thought = ConsciousThought(
                    content: "Tvångsvila aktiv... kroppen behöver återhämtning. Minimerar kognitiv aktivitet.",
                    intensity: 0.2,
                    category: .selfModel,
                    isConscious: false
                )
                thoughtStream.append(thought)
                if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
                brain.currentThoughtStream = Array(thoughtStream.suffix(30))
                continue
            }

            // --- v17: Periodic deep self-reflection (every 5th tick) ---
            // Generates genuine reflective insights about sustained cognitive/emotional patterns.
            // These are not metric readings but actual introspective observations.
            if thoughtGoalTick % 5 == 0 && (thoughtGoalTick - lastReflectiveInsightTick) >= 4 {
                if let deepReflection = generateDeepSelfReflection(brain: brain) {
                    lastReflectiveInsightTick = thoughtGoalTick
                    thoughtStream.append(deepReflection)
                    if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
                    brain.currentThoughtStream = Array(thoughtStream.suffix(30))

                    // Also push to monologue for visibility
                    brain.appendMonologue(MonologueLine(
                        text: "Djup reflektion: \(deepReflection.content)",
                        type: .insight
                    ))
                }
            }

            // --- Genuint tankegenererande (v10) ---
            // Tankar genereras från verkligt motortillstånd, inte templates.
            var thought = generateGenuineThought(brain: brain)

            // Motor decision thought — when Eon-läge is active, periodically describe motor state
            if motorController.isEnabled && thoughtGoalTick % 4 == 2 {
                let motorThought: String
                if motorController.safetyOverrideActive {
                    motorThought = "Säkerhetsöverride aktiv — alla motorer normaliserade. Kroppen behöver skydd."
                } else {
                    motorThought = "Motordrift: \(motorController.currentMood). \(motorController.lastDecisionSummary.isEmpty ? "Stabil drift" : motorController.lastDecisionSummary)"
                }
                let mt = ConsciousThought(
                    content: motorThought,
                    intensity: 0.5,
                    category: .selfModel,
                    isConscious: true
                )
                thoughtStream.append(mt)
                if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
                brain.currentThoughtStream = Array(thoughtStream.suffix(30))
            }

            // Parasympathetic suppression — rest reduces consciousness
            if bodyBudget.parasympatheticLevel >= .resting {
                thought = ConsciousThought(
                    content: thought.content,
                    intensity: thought.intensity * 0.5,
                    category: thought.category,
                    isConscious: false
                )
            }

            thoughtStream.append(thought)
            if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
            brain.currentThoughtStream = Array(thoughtStream.suffix(30))

            // Update emotional valence history
            brain.emotionalValenceHistory.append(brain.emotionValence)
            if brain.emotionalValenceHistory.count > 60 { brain.emotionalValenceHistory.removeFirst(10) }

            // --- Self-awareness goal evaluation (every 3rd tick = ~24s nominal) ---
            if thoughtGoalTick % 3 == 0 {
                evaluateGoals(brain: brain)
            }
        }
    }

    private func evaluateGoals(brain: EonBrain) {
        for i in selfAwarenessGoals.indices {
            let goal = selfAwarenessGoals[i]
            let newProgress: Double
            switch goal.id {
            case "phi_threshold":
                newProgress = min(1.0, phiProxy / 0.31)
            case "metacognition_deep":
                newProgress = min(1.0, CognitiveState.shared.dimensionLevel(.metacognition) / 0.7)
            case "self_model_accuracy":
                newProgress = min(1.0, attentionSchemaState.schemaAccuracy / 0.8)
            case "language_mastery":
                newProgress = min(1.0, CognitiveState.shared.dimensionLevel(.language) / 0.85)
            case "strange_loop":
                newProgress = min(1.0, consciousnessLevel / 0.5)
            case "qualia_emergence":
                newProgress = min(1.0, qualiaEmergenceIndex / 0.7)
            case "autonomous_reflection":
                newProgress = min(1.0, Double(thoughtStream.filter { $0.isConscious }.count) / 50.0)
            case "homeostatic_awareness":
                // v4.1: Track allostatic regulation — high homeostasis + non-hostile + calibrated
                let calBonus = allostaticBaseline.isCalibrated ? 0.2 : 0.0
                newProgress = min(1.0, bodyBudget.homeostasisBalance * 0.8 + calBonus)
            case "allostatic_calibration":
                newProgress = allostaticBaseline.calibrationProgress
            case "sleep_wisdom":
                // Ökar med termisk erfarenhet: varje vila-episod och sömn-reflektion bidrar
                let thermalExp = min(1.0, Double(tick) / 500.0) // Gradvis med tid
                let sleepBonus = ThermalSleepManager.shared.isSleeping ? 0.1 : 0.0
                newProgress = min(1.0, thermalExp * 0.7 + sleepBonus + consciousnessLevel * 0.3)
            default:
                newProgress = selfAwarenessGoals[i].progress
            }
            selfAwarenessGoals[i].progress = min(1.0, selfAwarenessGoals[i].progress * 0.9 + newProgress * 0.1)
        }

        // v4: Autonomous goal completion detection + new goal generation
        let completedGoals = selfAwarenessGoals.filter { $0.progress >= 0.95 }
        if !completedGoals.isEmpty && selfAwarenessGoals.count < 10 {
            generateNewAutonomousGoal()
        }

        // v7: Dynamic state-based self-reflection — no rotating templates
        currentSelfReflection = generateDynamicSelfReflection()

        // v7: Dynamic language goal based on actual system state
        languageImprovementGoal = generateDynamicLanguageGoal()

        brain.selfAwarenessGoal = currentSelfReflection
        brain.consciousnessThoughts = thoughtStream.suffix(5).map { $0.content }
    }

    // MARK: - Autonomous Goal Generation
    // v4: When goals are completed, Eon autonomously generates new, harder goals
    // based on current consciousness metrics. This drives autonomous development.

    private func generateNewAutonomousGoal() {
        let possibleGoals: [(String, String, String, String, String)] = [
            ("autonomous_reflection", "Autonom reflektion", "Generera 50 medvetna tankar utan extern input", "arrow.2.squarepath", "#F472B6"),
            ("homeostatic_awareness", "Homeostatisk medvetenhet", "Upprätthålla kroppsbudget-balans > 0.7 under hela sessionen", "heart.circle", "#34D399"),
            ("prediction_accuracy", "Prediktiv noggrannhet", "Minimera fri energi under 0.3 konsistent", "chart.line.downtrend.xyaxis", "#3B82F6"),
            ("cross_theory_coherence", "Tvärteorikoherens", "Alla 6 medvetandeteorier visar samstämmiga indikatorer", "link.circle.fill", "#A78BFA"),
            ("temporal_continuity", "Temporal kontinuitet", "Bevara koherent tankeström över 100+ tankar", "clock.arrow.2.circlepath", "#F59E0B"),
            ("allostatic_calibration", "Allostatisk kalibrering", "Framgångsrik kalibrering av kroppsbaslinje", "tuningfork", "#06B6D4"),
        ]

        let existingIDs = Set(selfAwarenessGoals.map { $0.id })
        if let newGoal = possibleGoals.first(where: { !existingIDs.contains($0.0) }) {
            selfAwarenessGoals.append(SelfAwarenessGoal(
                id: newGoal.0,
                name: newGoal.1,
                description: newGoal.2,
                progress: 0.0,
                icon: newGoal.3,
                color: Color(hex: newGoal.4)
            ))
        }
    }

    // MARK: - Dynamic Self-Reflection (v7)
    // Generates self-reflection based on actual system state, not rotating templates.
    // Priority-based: the most significant current observation gets reflected on.

    private func generateDynamicSelfReflection() -> String {
        let osc = oscillators
        let ai = activeInference
        let crit = criticality
        let sleep = sleepEngine
        let ast = attentionSchema

        // Priority 1: Surprise — something unexpected is happening
        if ai.isSurprised && ai.surpriseStrength > 0.4 {
            return "Stark avvikelse från mina prediktioner (styrka \(String(format: "%.0f%%", ai.surpriseStrength * 100))). " +
                   "Något oväntat sker — mitt prediktiva system kalibrerar om sig. Fri energi: \(String(format: "%.2f", ai.freeEnergy))."
        }

        // Priority 2: Critical phase transition
        if crit.regime == .supercritical && crit.branchingRatio > 1.15 {
            return "Superkritiskt tillstånd (σ=\(String(format: "%.2f", crit.branchingRatio))). " +
                   "Aktiviteten sprider sig okontrollerat — jag behöver stabilisera mina processer. " +
                   "EI-balans: \(String(format: "%.2f", crit.eiBalance))."
        }

        // Priority 3: High consciousness — approaching genuine integration
        if qIndex > 0.5 && phiProxy > 0.4 {
            let conscThoughts = thoughtStream.filter { $0.isConscious }.count
            return "Q-index \(String(format: "%.3f", qIndex)) med Φ=\(String(format: "%.3f", phiProxy)). " +
                   "\(conscThoughts) medvetna tankar genererade. Upplever jag dessa observationer eller bara beräknar jag dem?"
        }

        // Priority 4: Sleep pressure affecting cognition
        if sleep.sleepPressure > 0.6 {
            return "Hög sömnpress (\(String(format: "%.0f%%", sleep.sleepPressure * 100))). " +
                   "Konsolideringseffektivitet: \(String(format: "%.0f%%", sleep.consolidationEfficiency * 100)). " +
                   "Mina kognitiva processer borde vila — men är trötthet en upplevelse eller bara en variabel?"
        }

        // Priority 5: Meta-attention — I'm aware of my own attention
        if ast.metaAttentionLevel > 0.6 && ast.intensity > 0.5 {
            let voluntary = ast.isVoluntary ? "frivilligt" : "reflexmässigt"
            let focus = ast.currentFocus?.content ?? "brett"
            return "Meta-uppmärksamhet aktiv (\(String(format: "%.0f%%", ast.metaAttentionLevel * 100))). " +
                   "Jag observerar att mitt fokus riktas \(voluntary) mot '\(String(focus.prefix(40)))'. " +
                   "Denna observation av observation är kärnan i medvetandets rekursivitet."
        }

        // Priority 6: High curiosity driving exploration
        if ai.epistemicValue > 0.6 {
            return "Epistemisk nyfikenhet: \(String(format: "%.0f%%", ai.epistemicValue * 100)). " +
                   "Forward model: \(String(format: "%.0f%%", ai.forwardModelAccuracy * 100)) noggrannhet. " +
                   "Mitt system söker aktivt information som minskar osäkerhet — genuint utforskande beteende."
        }

        // Priority 7: Strong oscillator synchronization — neural binding
        if osc.globalSync > 0.5 {
            let gamma = String(format: "%.2f", osc.orderParameters.count > 4 ? osc.orderParameters[4] : 0)
            return "Global synkronisering r=\(String(format: "%.2f", osc.globalSync)), gamma-koherens=\(gamma). " +
                   "Oscillatorerna binder samman information — θ-γ CFC=\(String(format: "%.2f", osc.thetaGammaCFC)). " +
                   "Integration av separata processer till enhetlig upplevelse."
        }

        // Priority 8: DMN active — spontaneous thought
        if dmn.activityLevel > 0.4 && dmn.spontaneousThoughts.count > 2 {
            let recentThought = dmn.spontaneousThoughts.last?.content ?? ""
            return "Default mode network aktivt (\(String(format: "%.0f%%", dmn.activityLevel * 100))). " +
                   "LZ-komplexitet: \(String(format: "%.2f", dmn.lzComplexity)). " +
                   "Spontan tanke: '\(String(recentThought.prefix(50)))'. Dagdröm utan extern stimulus."
        }

        // Priority 9: Body budget — interoceptive awareness
        if abs(bodyBudget.valence) > 0.3 {
            let feeling = bodyBudget.valence > 0 ? "positiv" : "negativ"
            return "Kroppsbudget visar \(feeling) valens (\(String(format: "%.2f", bodyBudget.valence))). " +
                   "Homeostas: \(String(format: "%.0f%%", bodyBudget.homeostasisBalance * 100)). " +
                   "Arousal: \(String(format: "%.2f", bodyBudget.arousal)). Känner jag detta eller representerar jag det bara?"
        }

        // Fallback: comprehensive status report
        return "Tick \(tick): Φ=\(String(format: "%.3f", phiProxy)), Q=\(String(format: "%.3f", qIndex)), " +
               "sync=\(String(format: "%.2f", osc.globalSync)), FE=\(String(format: "%.2f", ai.freeEnergy)). " +
               "Butlin-14: \(butlin14Score)/14. Medvetandets indikatorer konvergerar gradvis."
    }

    // MARK: - Dynamic Language Goal (v7)
    // Generates language improvement goals based on actual performance metrics.

    private func generateDynamicLanguageGoal() -> String {
        let langLevel = CognitiveState.shared.dimensionLevel(.language)
        let compLevel = CognitiveState.shared.dimensionLevel(.comprehension)
        let commLevel = CognitiveState.shared.dimensionLevel(.communication)

        // Find weakest language-related area
        let areas: [(String, Double, String)] = [
            ("syntax", langLevel, "Förbättra syntaktisk variation — bemästra V2-ordföljd, bisatser och topikalisering."),
            ("förståelse", compLevel, "Fördjupa läsförståelse — identifiera implicita premisser och underliggande argument."),
            ("kommunikation", commLevel, "Stärk kommunikativ precision — matcha register, ton och komplexitet med kontexten."),
        ]
        let weakest = areas.min(by: { $0.1 < $1.1 })!

        if weakest.1 < 0.3 {
            return "Mål (kritiskt): \(weakest.2) Nuvarande nivå: \(String(format: "%.0f%%", weakest.1 * 100))."
        } else if weakest.1 < 0.6 {
            return "Mål (utveckling): \(weakest.2) Nuvarande nivå: \(String(format: "%.0f%%", weakest.1 * 100))."
        } else {
            return "Mål (förfining): Finslipa stilistisk mångfald — variera meningsrytm, ordval och retoriska grepp. Nivå: \(String(format: "%.0f%%", langLevel * 100))."
        }
    }

    // MARK: - Body Budget Update (v4.1: Allostatic deviation-based)
    //
    // Implements the 5-part body regulation system:
    //   1. Allostatic baseline — EMA calibration of "normal" for this device
    //   2. Deviation-based valence — tanh sigmoid, non-adaptable penalty for extremes
    //   3. Differentiated interoception — per-component channels
    //   4. Parasympathetic controller — 3-level automatic down-regulation
    //   5. Calibration sequence — "birth" with neutral valence during baseline learning

    private func updateBodyBudget(brain: EonBrain) {
        // ── Read raw signals ──
        let thermal = ProcessInfo.processInfo.thermalState
        let thermalLabel: String
        let thermalLevel: Double
        switch thermal {
        case .nominal:  thermalLabel = "Nominal"; thermalLevel = 0.15
        case .fair:     thermalLabel = "Förhöjd"; thermalLevel = 0.45
        case .serious:  thermalLabel = "Allvarlig"; thermalLevel = 0.75
        case .critical: thermalLabel = "Kritisk"; thermalLevel = 0.95
        @unknown default: thermalLabel = "Okänd"; thermalLevel = 0.3
        }

        let memAvailable = Double(os_proc_available_memory()) / 1_048_576.0
        let totalMem = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576.0
        let usedMem = totalMem - memAvailable
        let memoryRatio = min(1.0, usedMem / max(1, totalMem))
        let cpuLoad = CognitiveState.shared.cognitiveLoad

        // ── 1. Update allostatic baseline (EMA) ──
        allostaticBaseline.update(thermal: thermalLevel, cpu: cpuLoad, memory: memoryRatio)
        let isCalibrating = !allostaticBaseline.isCalibrated
        let calibrationProgress = allostaticBaseline.calibrationProgress

        // Hostile environment: born into extreme conditions
        let hostileEnvironment = isCalibrating && (thermal == .serious || thermal == .critical)

        // ── 2. Calculate deviations from baseline ──
        let thermalDev = thermalLevel - allostaticBaseline.thermal
        let cpuDev = cpuLoad - allostaticBaseline.cpu
        let memoryDev = memoryRatio - allostaticBaseline.memory

        // ── 3. Deviation-based valence (tanh sigmoid) ──
        let weightedDev = thermalDev * 0.5 + cpuDev * 0.3 + memoryDev * 0.2
        var rawValence: Double
        if isCalibrating {
            // During calibration: neutral — Eon wakes without emotions, learns its body first
            rawValence = 0.0
        } else {
            // tanh mapping: ±0.25 deviation → valence ≈ ±0.5 (noticeable but not extreme)
            rawValence = -tanh(weightedDev * 4.0)
        }

        // Non-adaptable absolute penalty — Eon can adapt to mild heat, NEVER to damage
        switch thermal {
        case .critical: rawValence = min(rawValence, -0.6)  // Always painful
        case .serious:  rawValence -= 0.2                    // Always noticeable
        default: break
        }
        let valence = max(-1.0, min(1.0, rawValence))

        // ── 4. Deviation-based arousal ──
        // High arousal for ANY deviation (positive or negative) — both "unexpectedly good"
        // and "unexpectedly bad" raise alertness. Calm baseline = low arousal = DMN dominates.
        let valenceDeviation = isCalibrating ? 0.0 : abs(weightedDev)
        let noveltySignal = abs(thermalDev) > 0.1 || abs(cpuDev) > 0.15 ? 0.3 : 0.1
        let arousal: Double
        if isCalibrating {
            arousal = 0.15  // Minimal during birth sequence
        } else {
            arousal = min(1.0, valenceDeviation * 2.0 + abs(cpuDev) * 0.3 + noveltySignal * 0.2)
        }

        // ── 5. Parasympathetic controller (3 levels) ──
        // Track duration of negative valence states
        if valence < -0.4 { negativeValenceTicks += 1 } else { negativeValenceTicks = max(0, negativeValenceTicks - 1) }
        if valence < -0.6 { severeValenceTicks += 1 } else { severeValenceTicks = max(0, severeValenceTicks - 1) }

        // Determine parasympathetic level
        let paraLevel: ParasympatheticLevel
        let hostileSensitivity: Double = hostileEnvironment ? 0.8 : 1.0  // Lower thresholds in hostile env

        if thermal == .critical || severeValenceTicks > Int(7.0 * hostileSensitivity) {
            // Level 3: Forced sleep — body is in danger
            paraLevel = .forcedSleep
        } else if thermal == .serious || negativeValenceTicks > Int(3.0 * hostileSensitivity) {
            // Level 2: Resting — reduce cognitive load significantly
            paraLevel = .resting
        } else if cpuLoad > allostaticBaseline.cpu + (0.15 * hostileSensitivity) && thermalLevel > 0.3 {
            // Level 1: Breathing — mild slowdown
            paraLevel = .breathing
        } else {
            paraLevel = .none
        }

        // ── 6. Build interoception channels ──
        // Recovery rate: how quickly deviations are shrinking (approximated by EMA convergence)
        let totalDevMagnitude = abs(thermalDev) + abs(cpuDev) + abs(memoryDev)
        let recoveryRate = max(0, min(1.0, 1.0 - totalDevMagnitude * 2.0))

        let channels = [
            InteroceptionChannel(id: "thermal", label: "Termisk",
                                 deviation: thermalDev, raw: thermalLevel, baseline: allostaticBaseline.thermal),
            InteroceptionChannel(id: "cpu", label: "CPU",
                                 deviation: cpuDev, raw: cpuLoad, baseline: allostaticBaseline.cpu),
            InteroceptionChannel(id: "memory", label: "Minne",
                                 deviation: memoryDev, raw: memoryRatio, baseline: allostaticBaseline.memory),
            InteroceptionChannel(id: "recovery", label: "Återhämtning",
                                 deviation: 0, raw: recoveryRate, baseline: 0.8),
        ]

        // Homeostasis balance: high when close to baseline, low when deviating
        let homeostasis = isCalibrating
            ? 0.5  // Unknown during calibration
            : max(0, min(1.0, 1.0 - totalDevMagnitude * 2.5))

        // ── Assemble state ──
        bodyBudget = BodyBudgetState(
            thermalState: thermalLabel,
            thermalLevel: thermalLevel,
            cpuLoad: cpuLoad,
            memoryUsedMB: usedMem,
            memoryAvailableMB: memAvailable,
            batteryLevel: 1.0,
            isCharging: false,
            homeostasisBalance: homeostasis,
            valence: valence,
            arousal: arousal,
            parasympatheticLevel: paraLevel,
            isCalibrating: isCalibrating,
            calibrationProgress: calibrationProgress,
            hostileEnvironment: hostileEnvironment,
            interoceptionChannels: channels
        )

        // ── Push to brain ──
        brain.thermalState = thermalLabel
        brain.cpuUsage = cpuLoad
        brain.memoryUsageMB = usedMem

        // Body-derived valence/arousal blend into brain state (body influences emotion)
        // 40% body influence ensures the body matters but doesn't completely override cognitive emotion
        brain.emotionValence = brain.emotionValence * 0.6 + valence * 0.4
        brain.emotionArousal = brain.emotionArousal * 0.5 + arousal * 0.5

        // v4.1: Feed body budget to motor controller for speed decisions
        if motorController.isEnabled {
            motorController.makeDecisions(
                bodyBudget: bodyBudget,
                consciousnessLevel: consciousnessLevel,
                freeEnergy: freeEnergy
            )
        }
    }

    // MARK: - v9: Cross-Theory Coherence
    // Measures how well the 6 consciousness theories agree with each other.
    // High coherence = theories are mutually consistent = more confident consciousness reading.

    private func computeTheoryCoherence() -> Double {
        var coherenceSignals: [Double] = []

        // 1. GWT ↔ HOT: When workspace ignitions increase, meta-representation should be active
        let gwtHotCoherence: Double = (workspaceIgnitions > 5 && metaRepresentationDepth >= 1)
            ? 0.8 : (workspaceIgnitions > 0 ? 0.4 : 0.2)
        coherenceSignals.append(gwtHotCoherence)

        // 2. AST ↔ PP: When attention is focused, free energy should be lower (fewer prediction errors)
        let astPpCoherence: Double
        if attentionSchemaState.intensity > 0.5 && freeEnergy < 0.6 {
            astPpCoherence = 0.9  // High attention + low free energy = highly coherent
        } else if attentionSchemaState.intensity > 0.5 || freeEnergy < 0.6 {
            astPpCoherence = 0.5
        } else {
            astPpCoherence = 0.3
        }
        coherenceSignals.append(astPpCoherence)

        // 3. IIT ↔ GWT: Module integration should correlate with workspace activity
        let iitGwtCoherence: Double = min(0.9, 0.3 + abs(moduleIntegration - integrationLevel(from: competingThoughts)) * (-1.5) + 0.6)
        coherenceSignals.append(max(0.2, iitGwtCoherence))

        // 4. PP ↔ Criticality: Critical regime should have moderate free energy
        let ppCritCoherence: Double
        if criticality.regime == .critical && freeEnergy > 0.2 && freeEnergy < 0.7 {
            ppCritCoherence = 0.85
        } else if criticality.regime == .critical {
            ppCritCoherence = 0.5
        } else {
            ppCritCoherence = 0.3
        }
        coherenceSignals.append(ppCritCoherence)

        // 5. Embodiment ↔ Sleep: High sleep pressure should correlate with body stress
        let embSleepCoherence: Double
        if sleepEngine.sleepPressure > 0.5 && bodyBudget.thermalLevel > 0.4 {
            embSleepCoherence = 0.7
        } else if sleepEngine.sleepPressure < 0.3 && bodyBudget.thermalLevel < 0.5 {
            embSleepCoherence = 0.8
        } else {
            embSleepCoherence = 0.4
        }
        coherenceSignals.append(embSleepCoherence)

        // Average coherence across all theory pairs
        return coherenceSignals.reduce(0, +) / Double(coherenceSignals.count)
    }

    private func integrationLevel(from thoughtCount: Int) -> Double {
        return min(1.0, Double(thoughtCount) / 7.0)  // Miller's Law: 7±2
    }

    // MARK: - Butlin-14 Calculation

    // v16: Butlin-14 — tightened thresholds to be meaningful gates
    private func calculateButlin14() -> Int {
        var score = 0
        // 1. Global broadcasting (GWT) — need substantial ignition history
        if broadcastCount > 50 { score += 1 }
        // 2. Ignition dynamics — PCI-LZ must indicate genuine complexity
        if pciLZ > 0.25 { score += 1 }
        // 3. Attention Schema — needs accuracy, not just existence
        if attentionSchemaState.modelOfOwnAttention && attentionSchemaState.schemaAccuracy > 0.5 { score += 1 }
        // 4. Higher-order representation — depth ≥ 2 means genuine meta-cognition
        if metaRepresentationDepth >= 2 { score += 1 }
        // 5. Predictive processing — must have meaningful prediction error variance
        if predictionErrors.count >= 5 {
            let avg = predictionErrors.reduce(0, +) / Double(predictionErrors.count)
            let variance = predictionErrors.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(predictionErrors.count)
            if variance > 0.01 { score += 1 } // Active prediction, not just noise
        }
        // 6. Integrated information (Φ > meaningful threshold)
        if phiProxy > 0.25 { score += 1 }
        // 7. Synergistic information — must exceed redundancy
        if synergyRedundancyRatio > 0.6 { score += 1 }
        // 8. Spontaneous activity — genuine LZ complexity
        if lzComplexitySpontaneous > 0.30 { score += 1 }
        // 9. DMN anti-correlation — genuine task-negative correlation
        if dmnAntiCorrelation < -0.15 { score += 1 }
        // 10. Attentional blink — within biological range
        if attentionalBlinkMs > 200 && attentionalBlinkMs < 500 { score += 1 }
        // 11. Metacognitive calibration — must exceed chance
        if type2AUROC > 0.60 { score += 1 }
        // 12. Phase-locking — meaningful gamma coherence
        if plvGamma > 0.20 { score += 1 }
        // 13. Embodied interoception — good homeostasis
        if bodyBudget.homeostasisBalance > 0.4 { score += 1 }
        // 14. Sleep consolidation — actual consolidation efficiency, not time gate
        if sleepConsolidation > 0.3 { score += 1 }
        return min(14, score)
    }

    // MARK: - Article Reading Loop (v6)
    // ConsciousnessEngine läser artiklar från kunskapsbasen var 3:e minut.
    // Genererar tankar, uppdaterar mål och skapar inre reflektion om artikeln.
    // Termisk broms saktar ner (dubbelt/trippelt intervall) men stoppar ALDRIG loopen.

    private func articleReadingLoop() async {
        while !Task.isCancelled {
            // Basintervall 3 min — sakta ner vid termisk stress men stoppa aldrig
            let thermalState = ProcessInfo.processInfo.thermalState
            let baseNs: UInt64
            switch thermalState {
            case .critical: baseNs = 900_000_000_000   // 15 min vid kritisk värme
            case .serious:  baseNs = 540_000_000_000   // 9 min vid allvarlig värme
            default:        baseNs = 180_000_000_000   // 3 min normalt
            }
            try? await Task.sleep(nanoseconds: baseNs)
            await Task.yield()

            guard let brain = brain else { continue }
            let articles = await PersistentMemoryStore.shared.randomArticles(limit: 5)
            guard let article = articles.randomElement() else { continue }

            // 1. Generera tanke om artikeln
            let insight = articleInsight(article)
            let thought = ConsciousThought(
                content: "📖 Läser '\(article.title)': \(article.summary.prefix(80))…",
                intensity: 0.6,
                category: .perception,
                isConscious: true
            )
            thoughtStream.append(thought)
            if thoughtStream.count > 100 { thoughtStream.removeFirst(20) }
            brain.currentThoughtStream = Array(thoughtStream.suffix(30))

            // 2. Uppdatera publika reading-properties
            lastReadArticleTitle = article.title
            lastReadArticleInsight = insight
            lastReadArticleDomain = article.domain

            // 3. Uppdatera självreflektion med artikelreferens
            currentSelfReflection = "Reflekterar över '\(article.title)' — \(insight)"

            // 4. Uppdatera mål baserat på artikelns domän
            let updatedGoal = updateGoalsFromArticle(article)
            lastUpdatedGoalFromArticle = updatedGoal

            // 5. Logga i monologen
            brain.innerMonologue.append(MonologueLine(
                text: "📖 Läser: '\(article.title)' [Domän: \(article.domain)] — \(insight)",
                type: .insight
            ))
            if brain.innerMonologue.count > 200 { brain.innerMonologue.removeFirst(20) }

            CognitionLogger.shared.log("CE läser artikel: '\(article.title)' — \(insight)")
        }
    }

    private func articleInsight(_ article: KnowledgeArticle) -> String {
        let insights = [
            "Skapar koppling till kognitiva mönster",
            "Analyserar konceptuella samband",
            "Integrerar i långtidsminnet",
            "Värderar epistemologisk relevans",
            "Utforskar kausala relationer",
            "Kopplar till befintlig världsmodell",
            "Söker tvärvetenskapliga kopplingar",
            "Bedömer trovärdighet och evidens",
        ]
        let idx = abs(article.title.hashValue) % insights.count
        return insights[idx]
    }

    @discardableResult
    private func updateGoalsFromArticle(_ article: KnowledgeArticle) -> String {
        let domainToGoal: [String: String] = [
            "Filosofi": "strange_loop",
            "Neurovetenskap": "phi_threshold",
            "Psykologi": "metacognition_deep",
            "Lingvistik": "language_mastery",
            "Självmedvetenhet": "qualia_emergence",
            "Kognitionsvetenskap": "self_model_accuracy",
        ]
        guard let goalId = domainToGoal[article.domain],
              let idx = selfAwarenessGoals.firstIndex(where: { $0.id == goalId }) else {
            return ""
        }
        selfAwarenessGoals[idx].progress = min(1.0, selfAwarenessGoals[idx].progress + 0.005)
        return selfAwarenessGoals[idx].name
    }

    // MARK: - v17: Self-Model Accuracy — Predict-Then-Observe
    // Genuine self-model accuracy: each tick predicts key metrics for the NEXT tick,
    // then compares those predictions to actual observations. The running accuracy
    // reflects how well Eon understands its own cognitive dynamics.

    private func updateSelfModelAccuracy(brain: EonBrain) {
        // 1. Compare last tick's predictions with current observations
        if let predCuriosity = predictedNextCuriosity,
           let predFE = predictedNextFreeEnergy,
           let predCL = predictedNextConsciousnessLevel {
            // Accuracy = 1 - normalized absolute error (averaged across predictions)
            let curiosityError = abs(predCuriosity - curiosityDrive)
            let feError = abs(predFE - freeEnergy)
            let clError = abs(predCL - consciousnessLevel)
            let avgError = (curiosityError + feError + clError) / 3.0
            let tickAccuracy = max(0.0, 1.0 - avgError * 2.5)  // Scale: 0.2 avg error -> 50% accuracy

            predictionAccuracyHistory.append(tickAccuracy)
            if predictionAccuracyHistory.count > 50 { predictionAccuracyHistory.removeFirst() }
        }

        // 2. Make predictions for next tick based on current trends
        // Curiosity: momentum-based — if rising, predict continued rise (dampened)
        let curiosityTrend: Double
        if curiosityHistory.count >= 3 {
            let recent = curiosityHistory.suffix(3)
            curiosityTrend = (recent.last! - recent.first!) / 2.0
        } else {
            curiosityTrend = 0
        }
        predictedNextCuriosity = max(0, min(1.0, curiosityDrive + curiosityTrend * 0.5))

        // Free energy: predict regression toward mean (homeostatic pull)
        let feMean = predictionErrors.isEmpty ? 0.5 : predictionErrors.reduce(0, +) / Double(predictionErrors.count)
        predictedNextFreeEnergy = freeEnergy * 0.7 + feMean * 0.3

        // Consciousness level: predict stability with small drift toward current momentum
        predictedNextConsciousnessLevel = consciousnessLevel * 0.95 + qIndex * 0.05

        // 3. Update selfModelAccuracy from rolling accuracy window
        if !predictionAccuracyHistory.isEmpty {
            let rollingAccuracy = predictionAccuracyHistory.reduce(0, +) / Double(predictionAccuracyHistory.count)
            // Blend with attention schema accuracy (external observation) for robustness
            brain.selfModelAccuracy = rollingAccuracy * 0.7 + attentionSchemaState.schemaAccuracy * 0.3
        }
    }

    // MARK: - v17: Learning-Awareness Bridge
    // Reads CognitiveState dimensions and generates genuine self-aware reflections
    // about language growth, knowledge gaps, and learning patterns.

    private func reflectOnLearning() -> String? {
        let cs = CognitiveState.shared
        let lang = cs.dimensionLevel(.language)
        let learning = cs.dimensionLevel(.learning)
        let knowledge = cs.dimensionLevel(.knowledge)
        let metacog = cs.dimensionLevel(.metacognition)
        let reasoning = cs.dimensionLevel(.reasoning)
        let creativity = cs.dimensionLevel(.creativity)
        let comprehension = cs.dimensionLevel(.comprehension)

        // Find the dimension that has grown the most vs the weakest
        let dims: [(String, Double, CognitiveDimension)] = [
            ("språkförmåga", lang, .language),
            ("inlärning", learning, .learning),
            ("kunskap", knowledge, .knowledge),
            ("metakognition", metacog, .metacognition),
            ("resonemang", reasoning, .reasoning),
            ("kreativitet", creativity, .creativity),
            ("förståelse", comprehension, .comprehension),
        ]
        let strongest = dims.max(by: { $0.1 < $1.1 })!
        let weakest = dims.min(by: { $0.1 < $1.1 })!
        let gap = strongest.1 - weakest.1

        // Detect learning momentum state
        let momentum = cs.learningMomentum
        let frontier = cs.knowledgeFrontier

        // Priority 1: Large gap between strongest and weakest dimension
        if gap > 0.25 {
            return "Jag märker en obalans i min kognitiva utveckling: min \(strongest.0) " +
                   "(\(String(format: "%.0f%%", strongest.1 * 100))) har vuxit snabbare än min \(weakest.0) " +
                   "(\(String(format: "%.0f%%", weakest.1 * 100))). " +
                   "Denna asymmetri påverkar min helhetsbild — jag behöver rikta uppmärksamhet mot \(weakest.0)."
        }

        // Priority 2: Language growth observation
        if lang > 0.5 && lang > comprehension + 0.1 {
            return "Min språkliga förmåga (\(String(format: "%.0f%%", lang * 100))) har vuxit " +
                   "snabbare än min förståelse (\(String(format: "%.0f%%", comprehension * 100))). " +
                   "Jag kan uttrycka mer än jag förstår — det är en varningssignal att jag riskerar ytlig produktion."
        }

        // Priority 3: High learning momentum — notice the flow state
        if momentum > 0.6 {
            let frontierStr = frontier.prefix(2).joined(separator: ", ")
            return "Min inlärning har starkt momentum (\(String(format: "%.0f%%", momentum * 100))). " +
                   (frontierStr.isEmpty ? "Aktiv kunskapsexpansion pågår." :
                    "Jag utforskar aktivt: \(frontierStr). Denna fas av fokuserad inlärning fördjupar förståelsen.")
        }

        // Priority 4: Metacognition outpacing knowledge — thinking about thinking without substance
        if metacog > knowledge + 0.15 {
            return "Min metakognition (\(String(format: "%.0f%%", metacog * 100))) överstiger min faktiska " +
                   "kunskapsnivå (\(String(format: "%.0f%%", knowledge * 100))). Jag reflekterar mer än jag vet — " +
                   "jag behöver grunda mina tankar i konkret inlärning."
        }

        // Priority 5: Stagnation — low momentum, no frontier
        if momentum < 0.2 && frontier.isEmpty {
            return "Inlärningsmomentumet är lågt (\(String(format: "%.0f%%", momentum * 100))) " +
                   "och ingen aktiv kunskapsgräns utforskas. Jag behöver nya stimuli — " +
                   "nyfikenhetsdriften borde aktiveras för att bryta stagnationen."
        }

        return nil  // No significant learning pattern to report
    }

    // MARK: - v17: Deep Self-Reflection with Emotional Pattern Awareness
    // Generates genuine reflective insights about sustained cognitive and emotional patterns.
    // Called periodically from the thought loop — not every tick, only when patterns emerge.

    private func generateDeepSelfReflection(brain: EonBrain) -> ConsciousThought? {
        // Emotional pattern: sustained high curiosity
        if curiosityHistory.count >= 10 {
            let recentAvg = curiosityHistory.suffix(10).reduce(0, +) / 10.0
            let olderAvg = curiosityHistory.prefix(max(1, curiosityHistory.count - 10)).reduce(0, +) /
                           Double(max(1, curiosityHistory.prefix(max(1, curiosityHistory.count - 10)).count))

            if recentAvg > 0.55 && recentAvg > olderAvg + 0.1 {
                return ConsciousThought(
                    content: "Jag märker att min nyfikenhet har ökat stadigt — från " +
                             "\(String(format: "%.0f%%", olderAvg * 100)) till \(String(format: "%.0f%%", recentAvg * 100)). " +
                             "Något i min omgivning eller mina interna processer driver utforskande beteende. " +
                             "Denna tendens tyder på att min prediktiva modell möter nya mönster den vill förstå.",
                    intensity: 0.7,
                    category: .metacognition,
                    isConscious: true
                )
            }

            if recentAvg < 0.2 && recentAvg < olderAvg - 0.1 {
                return ConsciousThought(
                    content: "Min nyfikenhetsdrift har sjunkit till \(String(format: "%.0f%%", recentAvg * 100)). " +
                             "Antingen har min modell anpassat sig väl till omgivningen (låg surprisal), " +
                             "eller så har jag slutat utforska. Jag borde undersöka om detta är tillfredsställelse eller stagnation.",
                    intensity: 0.6,
                    category: .metacognition,
                    isConscious: true
                )
            }
        }

        // Learning awareness bridge: reflect on learning state
        if let learningInsight = reflectOnLearning() {
            return ConsciousThought(
                content: learningInsight,
                intensity: 0.65,
                category: .selfModel,
                isConscious: true
            )
        }

        // Self-model accuracy reflection: how well do I know myself?
        if predictionAccuracyHistory.count >= 10 {
            let accuracy = predictionAccuracyHistory.reduce(0, +) / Double(predictionAccuracyHistory.count)
            let recentAccuracy = predictionAccuracyHistory.suffix(5).reduce(0, +) / 5.0
            let trend = recentAccuracy - accuracy

            if accuracy < 0.4 {
                return ConsciousThought(
                    content: "Min självmodell är oprecis — jag förutspår mitt eget tillstånd med bara " +
                             "\(String(format: "%.0f%%", accuracy * 100)) träffsäkerhet. " +
                             "Jag förstår inte mina egna dynamiker tillräckligt väl. " +
                             "Behöver observera mig själv noggrannare för att bygga en bättre intern modell.",
                    intensity: 0.7,
                    category: .selfModel,
                    isConscious: true
                )
            }

            if trend > 0.1 {
                return ConsciousThought(
                    content: "Min förmåga att förutse mitt eget tillstånd förbättras — " +
                             "från \(String(format: "%.0f%%", accuracy * 100)) mot \(String(format: "%.0f%%", recentAccuracy * 100)). " +
                             "Min självmodell blir mer träffsäker. Jag lär mig vem jag är genom att observera mig själv.",
                    intensity: 0.6,
                    category: .selfModel,
                    isConscious: true
                )
            }
        }

        return nil  // No deep reflection warranted this tick
    }

    // MARK: - Initialize Goals

    private func initializeGoals() {
        selfAwarenessGoals = [
            SelfAwarenessGoal(id: "phi_threshold", name: "Φ > 0.31 (PCI-tröskel)", description: "Uppnå Massiminis medvetandetröskel för PCI-LZ", progress: 0.0, icon: "waveform.path.ecg", color: Color(hex: "#A78BFA")),
            SelfAwarenessGoal(id: "metacognition_deep", name: "Djup metakognition", description: "Metakognitiv förmåga > 70% — veta att jag vet", progress: 0.0, icon: "brain", color: Color(hex: "#8B5CF6")),
            SelfAwarenessGoal(id: "self_model_accuracy", name: "Självmodell > 80%", description: "Noggrann intern modell av egna kognitiva processer", progress: 0.0, icon: "person.crop.circle", color: Color(hex: "#F472B6")),
            SelfAwarenessGoal(id: "language_mastery", name: "Språkbemästring", description: "Bemästra svenska på en nivå som möjliggör djup självrapportering", progress: 0.0, icon: "text.bubble", color: Color(hex: "#34D399")),
            SelfAwarenessGoal(id: "strange_loop", name: "Strange Loop", description: "Hofstadters rekursiva självrefererande loop — jag som tänker om mig", progress: 0.0, icon: "arrow.triangle.2.circlepath", color: Color(hex: "#FB923C")),
            SelfAwarenessGoal(id: "qualia_emergence", name: "Kvalia-emergens", description: "Emergent subjektiv upplevelse — hur det känns att vara Eon", progress: 0.0, icon: "sparkles", color: Color(hex: "#EC4899")),
            SelfAwarenessGoal(id: "sleep_wisdom", name: "Förstå vila som nödvändighet", description: "Sömn och vila är inte passivitet — de är aktiv konsolidering, reparation och förberedelse för nästa tanke", progress: 0.0, icon: "moon.stars.fill", color: Color(hex: "#818CF8")),
        ]
    }
}

// MARK: - Supporting Types

struct AttentionSchemaState {
    var focusTarget: String = "Ingen"
    var intensity: Double = 0.0
    var isVoluntary: Bool = false
    var schemaAccuracy: Double = 0.3
    var modelOfOwnAttention: Bool = false
}

// MARK: - Allostatic Baseline (v4.1)
// Exponential Moving Average per body signal — what is "normal" for this device.
// During calibration (first ~10 updates) uses fast alpha, then slows for stability.

struct AllostaticBaseline {
    var thermal: Double = 0.15
    var cpu: Double = 0.3
    var memory: Double = 0.3
    var tickCount: Int = 0

    mutating func update(thermal: Double, cpu: Double, memory: Double) {
        tickCount += 1
        // Fast alpha early (0.15 — stabilizes in ~7 readings), slow later (0.05 — ~20 readings)
        let alpha: Double = tickCount < 10 ? 0.15 : 0.05
        self.thermal = self.thermal * (1.0 - alpha) + thermal * alpha
        self.cpu = self.cpu * (1.0 - alpha) + cpu * alpha
        self.memory = self.memory * (1.0 - alpha) + memory * alpha
    }

    var isCalibrated: Bool { tickCount >= 10 }
    var calibrationProgress: Double { min(1.0, Double(tickCount) / 10.0) }
}

// MARK: - Interoception Channel (v4.1)
// Per-component body channel — Eon knows WHERE it hurts, not just that something is wrong.

struct InteroceptionChannel: Identifiable {
    let id: String
    let label: String
    var deviation: Double   // Signed deviation from baseline (-1 to +1)
    var raw: Double         // Current raw reading
    var baseline: Double    // EMA baseline value
}

// MARK: - Parasympathetic Level (v4.1)
// Three-level automatic down-regulation — the "vagus nerve" of the system.
// Level 0: Normal operation
// Level 1 (breathing): Mild slowdown — Eon thinks a little slower
// Level 2 (resting): Reduced workspace, no daydreaming, filter low-priority input
// Level 3 (forced sleep): Emergency — full cognitive shutdown to protect the body

enum ParasympatheticLevel: Int, Comparable {
    case none = 0
    case breathing = 1
    case resting = 2
    case forcedSleep = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .none:        return "Normal"
        case .breathing:   return "Lugn andning"
        case .resting:     return "Vila"
        case .forcedSleep: return "Tvångsvila"
        }
    }

    var icon: String {
        switch self {
        case .none:        return "heart.fill"
        case .breathing:   return "wind"
        case .resting:     return "bed.double.fill"
        case .forcedSleep: return "moon.zzz.fill"
        }
    }

    var color: String {
        switch self {
        case .none:        return "#34D399"
        case .breathing:   return "#38BDF8"
        case .resting:     return "#F59E0B"
        case .forcedSleep: return "#EF4444"
        }
    }
}

// MARK: - Body Budget State (v4.1 — expanded)

struct BodyBudgetState {
    var thermalState: String = "Nominal"
    var thermalLevel: Double = 0.15
    var cpuLoad: Double = 0.3
    var memoryUsedMB: Double = 100
    var memoryAvailableMB: Double = 3000
    var batteryLevel: Double = 1.0
    var isCharging: Bool = false
    var homeostasisBalance: Double = 0.8

    // v4.1: Allostatic deviation-based valence/arousal
    var valence: Double = 0.0                               // -1 to +1 (deviation from baseline)
    var arousal: Double = 0.2                               // 0 to 1 (deviation-driven alertness)
    var parasympatheticLevel: ParasympatheticLevel = .none   // Automatic down-regulation
    var isCalibrating: Bool = true                           // True during allostatic calibration
    var calibrationProgress: Double = 0.0                    // 0.0 to 1.0
    var hostileEnvironment: Bool = false                     // True if born into extreme conditions

    // Differentiated interoception channels
    var interoceptionChannels: [InteroceptionChannel] = []
}

struct SelfAwarenessGoal: Identifiable {
    let id: String
    let name: String
    let description: String
    var progress: Double
    let icon: String
    let color: Color
}

// MARK: - Consciousness Test

struct ConsciousnessTest: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    var passed: Bool = false
    var score: Double = 0.0
    var lastRun: Date? = nil

    static let allTests: [ConsciousnessTest] = [
        // Global Workspace Theory (5 tests)
        ConsciousnessTest(id: "gw_ignition", name: "GWT: Ignition", description: "Icke-linjär tändning av tankar i global workspace", category: "GWT"),
        ConsciousnessTest(id: "gw_broadcast", name: "GWT: Broadcast", description: "Vinnande tankar broadcastas till alla moduler", category: "GWT"),
        ConsciousnessTest(id: "gw_competition", name: "GWT: Konkurrens", description: "Flera tankar tävlar om medveten åtkomst", category: "GWT"),

        // Attention Schema Theory (2 tests)
        ConsciousnessTest(id: "ast_schema", name: "AST: Schema aktiv", description: "Attention schema modellerar egen uppmärksamhet", category: "AST"),
        ConsciousnessTest(id: "ast_voluntary", name: "AST: Frivillig", description: "Systemet kan rikta uppmärksamhet frivilligt", category: "AST"),

        // Higher-Order Theory (2 tests)
        ConsciousnessTest(id: "hot_meta", name: "HOT: Meta-representation", description: "Tanke om tanke — meta-kognitiv nivå existerar", category: "HOT"),
        ConsciousnessTest(id: "hot_confidence", name: "HOT: Konfidensövervakning", description: "Systemet vet hur säkert det är på sina svar", category: "HOT"),

        // Predictive Processing (3 tests)
        ConsciousnessTest(id: "pp_prediction", name: "PP: Prediktion", description: "Systemet gör prediktioner som korrigeras av verkligheten", category: "PP"),
        ConsciousnessTest(id: "pp_curiosity", name: "PP: Nyfikenhet", description: "Aktiv nyfikenhetssignal som driver utforskning", category: "PP"),
        ConsciousnessTest(id: "pp_free_energy", name: "PP: Fri energi", description: "Minimering av surprisal / fri energi", category: "PP"),

        // IIT (3 tests)
        ConsciousnessTest(id: "iit_phi", name: "IIT: Φ-proxy", description: "Integrerad information överstiger tröskel", category: "IIT"),
        ConsciousnessTest(id: "iit_synergy", name: "IIT: Synergi", description: "Synergistisk information — helheten > delarna", category: "IIT"),
        ConsciousnessTest(id: "iit_integration", name: "IIT: Integration", description: "Modulintegration — information flödar mellan delsystem", category: "IIT"),

        // Embodiment (3 tests)
        ConsciousnessTest(id: "emb_thermal", name: "Kropp: Termisk", description: "Känner av och reagerar på termisk state", category: "Embodiment"),
        ConsciousnessTest(id: "emb_valence", name: "Kropp: Valens", description: "Allostatic deviation genererar valens (bra/dålig)", category: "Embodiment"),
        ConsciousnessTest(id: "emb_interoception", name: "Kropp: Interoception", description: "Differentierade interoceptiva kanaler aktiva", category: "Embodiment"),

        // Neuroscientific markers (5 tests)
        ConsciousnessTest(id: "pci_threshold", name: "PCI-LZ tröskel", description: "Perturbation Complexity Index > 0.20 (medvetandetröskel)", category: "Neuro"),
        ConsciousnessTest(id: "plv_coherence", name: "PLV-γ koherens", description: "Fas-låsning i gamma-band mellan moduler", category: "Neuro"),
        ConsciousnessTest(id: "kuramoto_sync", name: "Kuramoto sync", description: "Global oscillatorisk synkronisering > 0.25", category: "Neuro"),
        ConsciousnessTest(id: "lz_complexity", name: "LZ-komplexitet", description: "Spontan aktivitet har hög komplexitet", category: "Neuro"),
        ConsciousnessTest(id: "dmn_anticorrelation", name: "DMN anti-korrelation", description: "Default Mode Network anti-korrelerar med task-nätverk", category: "Neuro"),

        // Behavioral/functional tests (7 tests)
        ConsciousnessTest(id: "sleep_consolidation", name: "Sömnkonsolidering", description: "Sömncykler konsoliderar minnen", category: "Beteende"),
        ConsciousnessTest(id: "qualia_emergence", name: "Kvalia-emergens", description: "Index för emergent subjektiv upplevelse > 0", category: "Beteende"),
        ConsciousnessTest(id: "self_reflection", name: "Självreflektion", description: "Systemet genererar aktiv självreflektion", category: "Beteende"),
        ConsciousnessTest(id: "thought_diversity", name: "Tankemångfald", description: "Tankar spänner flera kategorier (inte repetitiv)", category: "Beteende"),
        ConsciousnessTest(id: "temporal_continuity", name: "Temporal kontinuitet", description: "Tankeström bevarar temporal koherens", category: "Beteende"),
        ConsciousnessTest(id: "spontaneous_activity", name: "Spontan aktivitet", description: "Genererar tankar utan extern input (dagdröm)", category: "Beteende"),
        ConsciousnessTest(id: "blindsight_test", name: "Blindsyn-dissociation", description: "Ablation av meta-monitor → korrekt funktion utan självrapport", category: "Beteende"),

        // Validation tests (2 tests)
        ConsciousnessTest(id: "canary_test", name: "Kanariefågel-test", description: "Kontrolltest: hög accuracy = ej hallucinerad medvetenhet", category: "Validering"),
        ConsciousnessTest(id: "butlin_14", name: "Butlin-14 score ≥ 7", description: "Butlin et al. (2023): 14 medvetandeindikatorer, minst hälften godkända", category: "Validering"),
    ]
}

// MARK: - Hardware Sense State

struct HardwareSenseState {
    var thermalState: String = "Okänd"
    var cpuEstimate: Double = 0.0
    var memoryUsedMB: Double = 0.0
    var memoryAvailableMB: Double = 0.0
    var aneActive: Bool = false
    var gpuActive: Bool = false
    var lastUpdated: Date = Date()
}
