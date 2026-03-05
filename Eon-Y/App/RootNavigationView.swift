import SwiftUI

// MARK: - Scroll visibility environment key
// Views publish scroll direction via preference; RootNavigationView reads it to hide/show tab bar.

struct TabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(true)
}

extension EnvironmentValues {
    var tabBarVisible: Binding<Bool> {
        get { self[TabBarVisibilityKey.self] }
        set { self[TabBarVisibilityKey.self] = newValue }
    }
}

// MARK: - EonTab

enum EonTab: Int, CaseIterable {
    case home = 0
    case chat
    case language
    case project
    case selfAwareness
    case knowledge
    case profile

    var label: String {
        switch self {
        case .home:           return "Hem"
        case .chat:           return "Chatt"
        case .language:       return "Språk"
        case .project:        return "Projekt"
        case .selfAwareness:  return "Medvetande"
        case .knowledge:      return "Kunskap"
        case .profile:        return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home:           return "circle.hexagongrid.fill"
        case .chat:           return "bubble.left.and.bubble.right.fill"
        case .language:       return "textformat.abc"
        case .project:        return "folder.fill"
        case .selfAwareness:  return "eye.trianglebadge.exclamationmark"
        case .knowledge:      return "books.vertical.fill"
        case .profile:        return "person.crop.circle.fill"
        }
    }

    var activeColor: Color {
        switch self {
        case .home:           return Color(hex: "#A78BFA")
        case .chat:           return Color(hex: "#34D399")
        case .language:       return Color(hex: "#14B8A6")
        case .project:        return Color(hex: "#F59E0B")
        case .selfAwareness:  return Color(hex: "#F472B6")
        case .knowledge:      return Color(hex: "#FBBF24")
        case .profile:        return Color(hex: "#F472B6")
        }
    }

    var glowColor: Color { activeColor.opacity(0.6) }
}

struct RootNavigationView: View {
    @EnvironmentObject var brain: EonBrain
    @State private var selectedTab: EonTab = .chat
    @State private var tabBarVisible: Bool = true

    var body: some View {
        GeometryReader { geo in
            let tabBarHeight = 52 + geo.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                Color(hex: "#07050F").ignoresSafeArea()

                // Content — reserves exact space for tab bar so nothing hides behind it
                TabContentView(selectedTab: $selectedTab, tabBarVisible: $tabBarVisible)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: tabBarVisible ? tabBarHeight : 0)
                    }

                // Tab bar — pinned to bottom, slides off-screen when hidden
                // Keyboard must not push the tab bar up
                EonTabBar(selectedTab: $selectedTab, safeBottom: geo.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity)
                    .offset(y: tabBarVisible ? 0 : tabBarHeight + 2)
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: tabBarVisible)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
        .onAppear {
            brain.launchIfNeeded()
        }
    }
}

// MARK: - Tab Content

struct TabContentView: View {
    @Binding var selectedTab: EonTab
    @Binding var tabBarVisible: Bool

    // v4: Track visited tabs to keep them mounted after first visit
    // (preserves scroll positions and state), but don't mount all 7 on launch.
    @State private var visitedTabs: Set<EonTab> = [.chat]

    var body: some View {
        ZStack {
            // Chat is always mounted (default tab, has important scroll state)
            ChatView()
                .environment(\.tabBarVisible, $tabBarVisible)
                .opacity(selectedTab == .chat ? 1 : 0)
                .allowsHitTesting(selectedTab == .chat)

            // Other views: only mount after first visit (lazy loading)
            if visitedTabs.contains(.home) {
                EonPulseHomeView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)
            }

            if visitedTabs.contains(.language) {
                LanguageView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .language ? 1 : 0)
                    .allowsHitTesting(selectedTab == .language)
            }

            if visitedTabs.contains(.project) {
                ProjectView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .project ? 1 : 0)
                    .allowsHitTesting(selectedTab == .project)
            }

            if visitedTabs.contains(.selfAwareness) {
                SelfAwarenessView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .selfAwareness ? 1 : 0)
                    .allowsHitTesting(selectedTab == .selfAwareness)
            }

            if visitedTabs.contains(.knowledge) {
                KnowledgeView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .knowledge ? 1 : 0)
                    .allowsHitTesting(selectedTab == .knowledge)
            }

            if visitedTabs.contains(.profile) {
                ProfileRootView()
                    .environment(\.tabBarVisible, $tabBarVisible)
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: selectedTab) { _, newTab in
            // Register tab visit for lazy mounting
            visitedTabs.insert(newTab)
            // Tab-byte: visa alltid tab bar igen
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                tabBarVisible = true
            }
        }
    }
}

// MARK: - Scroll offset tracking

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Attach to any ScrollView's content to auto-hide/show the tab bar.
/// Usage: .scrollTabBarVisibility(tabBarVisible: $tabBarVisible)
struct ScrollTabBarVisibilityModifier: ViewModifier {
    @Binding var tabBarVisible: Bool
    @State private var lastOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: geo.frame(in: .named("scrollSpace")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                let delta = offset - lastOffset
                // Threshold to avoid jitter on tiny movements
                if delta < -8 {
                    // Scrolling down → hide
                    if tabBarVisible {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            tabBarVisible = false
                        }
                    }
                } else if delta > 8 {
                    // Scrolling up → show
                    if !tabBarVisible {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                            tabBarVisible = true
                        }
                    }
                }
                lastOffset = offset
            }
    }
}

extension View {
    func scrollTabBarVisibility(tabBarVisible: Binding<Bool>) -> some View {
        modifier(ScrollTabBarVisibilityModifier(tabBarVisible: tabBarVisible))
    }
}

// MARK: - Glass Tab Bar (App Store style)

struct EonTabBar: View {
    @Binding var selectedTab: EonTab
    @EnvironmentObject var brain: EonBrain
    let safeBottom: CGFloat

    @State private var tabActivity: [EonTab: Double] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Thin separator line at top
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            // Tab items row
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
            .frame(height: 52)
            .padding(.horizontal, 4)

            // Safe area fill — same background, no gap
            Color(hex: "#07050F")
                .frame(height: safeBottom)
        }
        .background(
            Color(hex: "#07050F")
                .opacity(0.96)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, y: -4)
        .onReceive(brain.$engineActivity) { activity in
            tabActivity[.project]        = activity["cognitive"] ?? 0
            tabActivity[.chat]           = activity["language"] ?? 0
            tabActivity[.language]       = activity["language"] ?? 0
            tabActivity[.selfAwareness]  = activity["autonomy"] ?? 0
            tabActivity[.knowledge]      = activity["memory"] ?? 0
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
    @StateObject private var brain = EonBrain.preview()
    @StateObject private var profile = UserProfileEngine.preview()
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
