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
    @StateObject private var brain = EonBrain.shared
    @StateObject private var userProfile = UserProfileEngine.shared

    init() {
        // BGTask-registrering kraschar i Preview-sandboxen — skydda med guard
        guard !isRunningInPreview else { return }

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
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                ) { _ in
                    // Nödpersistering: spara state när appen lämnar förgrunden
                    // Körs synkront innan iOS kan döda processen
                    CognitiveState.shared.persistCurrentState()
                    UserDefaults.standard.synchronize()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
                ) { _ in
                    CognitiveState.shared.persistCurrentState()
                    UserDefaults.standard.synchronize()
                }
        }
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

        print("[Boot] Eon fullt initierad ✓ (facts+articles: \(nodeCount) noder)")
    }
}
