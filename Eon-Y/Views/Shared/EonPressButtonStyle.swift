import SwiftUI

// MARK: - EonPressButtonStyle
// Enkel press-feedback via scale utan att konsumera DragGesture-events.
// Används i KnowledgeView, SelfAwarenessView m.fl. för knappar inuti ScrollView.

struct EonPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
