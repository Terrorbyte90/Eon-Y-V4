//
//  Eon_YApp.swift
//  Eon-Y
//
//  Created by Ted Svärd on 2026-02-27.
//

import SwiftUI
import BackgroundTasks
import UIKit

// Detekterar om koden körs inuti Xcodes Preview-motor.
// Används för att skydda BGTask-registrering och motor-start mot Preview-sandboxen.
private let isRunningInPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

@main
struct Eon_YApp: App {
    @ObservedObject private var brain = EonBrain.shared
    @ObservedObject private var userProfile = UserProfileEngine.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        guard !isRunningInPreview else { return }

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        EonAutonomyCore.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(brain)
                .environmentObject(userProfile)
                .preferredColorScheme(.dark)
                .task {
                    await bootEon()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        saveCompleteState()
                    case .active:
                        restoreCompleteState()
                    case .inactive:
                        saveCompleteState()
                    @unknown default:
                        break
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                ) { _ in
                    saveCompleteState()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
                ) { _ in
                    saveCompleteState()
                }
        }
    }

    // MARK: - Complete State Preservation

    @MainActor
    private func saveCompleteState() {
        let ud = UserDefaults.standard
        let ce = ConsciousnessEngine.shared

        // 1. Core cognitive state (dimensions, II)
        CognitiveState.shared.persistCurrentState()

        // 2. Consciousness metrics
        ud.set(ce.qIndex, forKey: "eon_saved_qindex")
        ud.set(ce.consciousnessLevel, forKey: "eon_saved_consciousness_level")
        ud.set(ce.qualiaEmergenceIndex, forKey: "eon_saved_qualia_index")
        ud.set(ce.pciLZ, forKey: "eon_saved_pci_lz")
        ud.set(ce.phiProxy, forKey: "eon_saved_phi_proxy")
        ud.set(ce.freeEnergy, forKey: "eon_saved_free_energy")
        ud.set(ce.curiosityDrive, forKey: "eon_saved_curiosity")
        ud.set(ce.butlin14Score, forKey: "eon_saved_butlin14")

        // 3. Emotional state
        ud.set(brain.emotionValence, forKey: "eon_saved_emotion_valence")
        ud.set(brain.emotionArousal, forKey: "eon_saved_emotion_arousal")
        ud.set(brain.currentEmotion.rawValue, forKey: "eon_saved_emotion_label")

        // 4. Development progress
        ud.set(brain.developmentalProgress, forKey: "eon_persisted_progress")
        ud.set(brain.developmentalStage.rawValue, forKey: "eon_persisted_stage")
        ud.set(brain.integratedIntelligence, forKey: "eon_persisted_ii")

        // 5. Inner narrative
        ud.set(ce.innerNarrative, forKey: "eon_saved_inner_narrative")
        ud.set(ce.currentSelfReflection, forKey: "eon_saved_self_reflection")

        // 6. Learning progress
        ud.set(brain.conversationCount, forKey: "eon_saved_conversation_count")
        ud.set(brain.knowledgeNodeCount, forKey: "eon_saved_knowledge_count")

        // 7. Sleep engine state
        ud.set(ce.sleepEngine.sleepPressure, forKey: "eon_saved_sleep_pressure")
        ud.set(ce.sleepEngine.isAsleep, forKey: "eon_saved_is_asleep")

        ud.set(Date().timeIntervalSince1970, forKey: "eon_saved_timestamp")
        ud.synchronize()

        print("[State] Komplett tillstånd sparat ✓ (Q=\(String(format: "%.3f", ce.qIndex)), emotion=\(brain.currentEmotion.rawValue))")
    }

    @MainActor
    private func restoreCompleteState() {
        let ud = UserDefaults.standard
        let ce = ConsciousnessEngine.shared

        guard ud.double(forKey: "eon_saved_timestamp") > 0 else { return }

        // Consciousness metrics
        let savedQ = ud.double(forKey: "eon_saved_qindex")
        if savedQ > 0 { ce.qIndex = savedQ }

        let savedCL = ud.double(forKey: "eon_saved_consciousness_level")
        if savedCL > 0 { ce.consciousnessLevel = savedCL }

        let savedQualia = ud.double(forKey: "eon_saved_qualia_index")
        if savedQualia > 0 { ce.qualiaEmergenceIndex = savedQualia }

        let savedPCI = ud.double(forKey: "eon_saved_pci_lz")
        if savedPCI > 0 { ce.pciLZ = savedPCI }

        let savedPhi = ud.double(forKey: "eon_saved_phi_proxy")
        if savedPhi > 0 { ce.phiProxy = savedPhi }

        let savedFE = ud.double(forKey: "eon_saved_free_energy")
        if savedFE > 0 { ce.freeEnergy = savedFE }

        let savedCuriosity = ud.double(forKey: "eon_saved_curiosity")
        if savedCuriosity > 0 { ce.curiosityDrive = savedCuriosity }

        let savedButlin = ud.integer(forKey: "eon_saved_butlin14")
        if savedButlin > 0 { ce.butlin14Score = savedButlin }

        // Emotional state
        let savedValence = ud.double(forKey: "eon_saved_emotion_valence")
        brain.emotionValence = savedValence
        let savedArousal = ud.double(forKey: "eon_saved_emotion_arousal")
        if savedArousal > 0 { brain.emotionArousal = savedArousal }

        // Inner narrative
        let savedNarrative = ud.string(forKey: "eon_saved_inner_narrative") ?? ""
        if !savedNarrative.isEmpty { ce.innerNarrative = savedNarrative }

        let savedReflection = ud.string(forKey: "eon_saved_self_reflection") ?? ""
        if !savedReflection.isEmpty { ce.currentSelfReflection = savedReflection }

        let savedTimestamp = ud.double(forKey: "eon_saved_timestamp")
        let timeSinceSave = Date().timeIntervalSince1970 - savedTimestamp
        let minutesAway = Int(timeSinceSave / 60)

        print("[State] Tillstånd återställt ✓ (Q=\(String(format: "%.3f", savedQ)), borta \(minutesAway) min)")
    }

    // MARK: - Komplett boot-sekvens

    @MainActor
    private func bootEon() async {
        // Preview-sandboxen har ingen riktig bundle, ingen SQLite-sökväg och
        // inga BGTask-rättigheter — avbryt omedelbart om vi körs i Preview.
        guard !isRunningInPreview else {
            print("[Boot] Preview-läge detekterat — motorer startas INTE. Använd EonPreviewContainer för UI-förhandsvisning.")
            return
        }

        // 1. Ladda persisterad kognitiv state INNAN motorer startas
        await brain.loadPersistedCognitiveState()

        // 2. Starta alla kognitiva motorer
        brain.launchIfNeeded()

        // 3. Ladda ML-modeller och språksystem parallellt
        async let modelsLoad: () = brain.neuralEngine.loadModels()
        async let swedishInit: () = brain.swedish.initialize()
        _ = await (modelsLoad, swedishInit)

        // 4. Schemalägg BGTasks för bakgrundsautonomi
        Task.detached(priority: .background) {
            await EonAutonomyCore.shared.scheduleAllTasks()
        }

        // 5. Sätt igång seed-data om databasen är tom
        Task.detached(priority: .background) {
            await EonAutonomyCore.shared.ensureSeedDataExists()
        }

        // 6. Synka LearningEngine-kompetenser från faktisk DB-data
        Task.detached(priority: .background) {
            await LearningEngine.shared.syncCompetenciesFromDatabase()
        }

        // 7. Uppdatera knowledgeNodeCount från faktisk DB
        let nodeCount = await PersistentMemoryStore.shared.knowledgeNodeCount()
        brain.knowledgeNodeCount = nodeCount

        // 8. Starta ConsciousnessEngine — medvetandemätning och tankeström
        ConsciousnessEngine.shared.start(brain: brain)

        print("[Boot] Eon fullt initierad ✓ (facts+articles: \(nodeCount) noder, consciousness engine aktiv)")
    }
}
