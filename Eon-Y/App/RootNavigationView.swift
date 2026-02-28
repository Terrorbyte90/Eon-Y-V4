import SwiftUI

enum EonTab: Int, CaseIterable {
    case home = 0
    case chat
    case mind
    case knowledge
    case profile

    var label: String {
        switch self {
        case .home:      return "Hem"
        case .chat:      return "Chatt"
        case .mind:      return "Hjärna"
        case .knowledge: return "Kunskap"
        case .profile:   return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "circle.hexagongrid.fill"
        case .chat:      return "bubble.left.and.bubble.right.fill"
        case .mind:      return "brain.head.profile"
        case .knowledge: return "books.vertical.fill"
        case .profile:   return "person.crop.circle.fill"
        }
    }

    var activeColor: Color {
        switch self {
        case .home:      return Color(hex: "#A78BFA")
        case .chat:      return Color(hex: "#34D399")
        case .mind:      return Color(hex: "#60A5FA")
        case .knowledge: return Color(hex: "#FBBF24")
        case .profile:   return Color(hex: "#F472B6")
        }
    }

    var glowColor: Color { activeColor.opacity(0.6) }
}

struct RootNavigationView: View {
    @EnvironmentObject var brain: EonBrain
    @State private var selectedTab: EonTab = .chat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color(hex: "#07050F").ignoresSafeArea()

                // Content fills screen, safeAreaInset reserves space for tab bar
                TabContentView(selectedTab: $selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        // Transparent spacer = exact tab bar height so content never hides behind it
                        Color.clear.frame(height: 60 + max(geo.safeAreaInsets.bottom, 16) + 4)
                    }

                // Floating tab bar overlays at bottom
                EonTabBar(selectedTab: $selectedTab, safeBottom: geo.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tab Content

struct TabContentView: View {
    @Binding var selectedTab: EonTab

    var body: some View {
        ZStack {
            EonPulseHomeView()
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)

            ChatView()
                .opacity(selectedTab == .chat ? 1 : 0)
                .allowsHitTesting(selectedTab == .chat)

            MindView()
                .opacity(selectedTab == .mind ? 1 : 0)
                .allowsHitTesting(selectedTab == .mind)

            KnowledgeView()
                .opacity(selectedTab == .knowledge ? 1 : 0)
                .allowsHitTesting(selectedTab == .knowledge)

            ProfileRootView()
                .opacity(selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(selectedTab == .profile)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Glass Tab Bar (App Store style)

struct EonTabBar: View {
    @Binding var selectedTab: EonTab
    @EnvironmentObject var brain: EonBrain
    let safeBottom: CGFloat

    @State private var tabActivity: [EonTab: Double] = [:]

    private let barHeight: CGFloat = 60
    private let horizontalPadding: CGFloat = 20
    private let bottomPadding: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                // Glass pill background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 24, y: 8)
                    .shadow(color: selectedTab.glowColor.opacity(0.15), radius: 16)

                // Tab items
                HStack(spacing: 0) {
                    ForEach(EonTab.allCases, id: \.self) { tab in
                        EonTabItem(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            activity: tabActivity[tab] ?? 0
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: barHeight)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, max(safeBottom, 16) + bottomPadding)
        }
        .onReceive(brain.$engineActivity) { activity in
            tabActivity[.mind]      = activity["cognitive"] ?? 0
            tabActivity[.chat]      = activity["language"] ?? 0
            tabActivity[.knowledge] = activity["memory"] ?? 0
        }
    }
}

// MARK: - Tab Item

struct EonTabItem: View {
    let tab: EonTab
    let isSelected: Bool
    let activity: Double
    let action: () -> Void

    @State private var bounceScale: CGFloat = 1.0
    @State private var glowPulse: Double = 0.4

    var body: some View {
        Button(action: {
            action()
            bounce()
        }) {
            VStack(spacing: 3) {
                ZStack {
                    // Activity glow ring
                    if activity > 0.15 {
                        Circle()
                            .fill(tab.activeColor.opacity(activity * 0.25))
                            .frame(width: 40, height: 40)
                            .blur(radius: 10)
                    }

                    // Selected pill background
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tab.activeColor.opacity(0.18))
                            .frame(width: 42, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(tab.activeColor.opacity(0.3), lineWidth: 0.5)
                            )
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 20 : 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? tab.activeColor : Color.white.opacity(0.38))
                        .scaleEffect(bounceScale)
                        .shadow(color: isSelected ? tab.glowColor : .clear, radius: 6)
                }
                .frame(width: 44, height: 32)

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? tab.activeColor : Color.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func bounce() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) {
            bounceScale = 1.22
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                bounceScale = 1.0
            }
        }
    }
}

// MARK: - Preview Container (shared across all views)

struct EonPreviewContainer<Content: View>: View {
    @StateObject private var brain = EonBrain.shared
    @StateObject private var profile = UserProfileEngine.shared
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .environmentObject(brain)
            .environmentObject(profile)
            .preferredColorScheme(.dark)
    }
}

#Preview {
    EonPreviewContainer {
        RootNavigationView()
    }
}
