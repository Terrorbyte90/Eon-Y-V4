import SwiftUI
import Combine

// ContentView är ersatt av RootNavigationView i App/Eon_YApp.swift
// Denna fil behålls för Xcode-kompatibilitet

struct ContentView: View {
    var body: some View {
        RootNavigationView()
            .environmentObject(EonBrain.shared)
            .environmentObject(UserProfileEngine.shared)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
