//
//  Eon_YApp.swift
//  Eon-Y
//
//  Created by Ted Svärd on 2026-02-27.
//

import SwiftUI
import BackgroundTasks

@main
struct Eon_YApp: App {
    @StateObject private var brain = EonBrain.shared
    @StateObject private var userProfile = UserProfileEngine.shared

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // BGTask-registrering MÅSTE ske synkront i init() — innan appen är synlig
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
        }
    }

    // MARK: - Komplett boot-sekvens

    @MainActor
    private func bootEon() async {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        if isPreview {
            print("[Boot] ⚠️ XCODE_RUNNING_FOR_PREVIEWS=1 detekterat — kör ändå alla motorer (preview blockerar INTE längre)")
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

        print("[Boot] Eon fullt initierad ✓ (facts+articles: \(nodeCount) noder)")
    }
}
