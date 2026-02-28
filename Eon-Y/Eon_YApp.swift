//
//  Eon_YApp.swift
//  Eon-Y
//
//  Created by Ted Svärd on 2026-02-27.
//

import SwiftUI

@main
struct Eon_YApp: App {
    @StateObject private var brain = EonBrain.shared
    @StateObject private var userProfile = UserProfileEngine.shared

    init() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Registrera bakgrundsuppgifter (måste ske synkront vid app-start)
        EonAutonomyCore.shared.registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(brain)
                .environmentObject(userProfile)
                .preferredColorScheme(.dark)
                .task {
                    // Initiera alla subsystem
                    await brain.neuralEngine.loadModels()
                    await brain.swedish.initialize()
                }
        }
    }
}
