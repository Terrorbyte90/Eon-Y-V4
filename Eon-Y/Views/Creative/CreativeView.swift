import SwiftUI
import Combine

// MARK: - CreativeView — Eons kreativa centrum
// Sektioner finns i Views/Creative/Sections/

struct CreativeView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @StateObject private var engine = CreativeEngine.shared

    @State private var selectedSection: CreativeSection = .problemSolver
    @State private var orbPulse: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#2D0060").opacity(0.5), Color.clear],
                center: .init(x: 0.3, y: 0.05),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#003030").opacity(0.3), Color.clear],
                center: .init(x: 0.8, y: 0.6),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                creativeHeader
                sectionPicker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedSection {
                        case .problemSolver: ProblemSolverSection(engine: engine, brain: brain)
                        case .letters:       LetterSection(engine: engine, brain: brain)
                        case .selfAwareness: SelfAwarenessSection(engine: engine, brain: brain)
                        case .emotions:      EmotionSection(engine: engine, brain: brain)
                        case .drawing:       DrawingSection(engine: engine)
                        case .goals:         GoalSection(engine: engine)
                        case .ethics:        EthicsSection(engine: engine)
                        case .experiment:    LanguageExperimentSection()
                        case .analogy:       AnalogyExplorerSection()
                        case .daydream:      DaydreamSection()
                        }
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                orbPulse = 1.08
            }
        }
    }

    // MARK: - Header

    private var creativeHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#EC4899").opacity(0.6), Color(hex: "#7C3AED").opacity(0.3), Color.clear],
                            center: .center, startRadius: 0, endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .scaleEffect(orbPulse)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: "#EC4899"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kreativt Centrum")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(engine.emotionalState.innerNarrative.prefix(60) + "...")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            if engine.unreadLetterCount > 0 {
                ZStack {
                    Circle().fill(EonColor.crimson).frame(width: 22, height: 22)
                    Text("\(engine.unreadLetterCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.scale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CreativeSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(section.label)
                                .font(.system(size: 12, weight: selectedSection == section ? .semibold : .regular, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedSection == section ? section.color.opacity(0.2) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selectedSection == section ? section.color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundStyle(selectedSection == section ? section.color : Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Creative Sections Enum

enum CreativeSection: String, CaseIterable {
    case problemSolver = "problem"
    case letters       = "letters"
    case selfAwareness = "awareness"
    case emotions      = "emotions"
    case drawing       = "drawing"
    case goals         = "goals"
    case ethics        = "ethics"
    case experiment    = "experiment"
    case analogy       = "analogy"
    case daydream      = "daydream"

    var label: String {
        switch self {
        case .problemSolver: return "Problemlösning"
        case .letters:       return "Brev"
        case .selfAwareness: return "Självmedvetande"
        case .emotions:      return "Känslor"
        case .drawing:       return "Ritning"
        case .goals:         return "Mål"
        case .ethics:        return "Etik"
        case .experiment:    return "Experiment"
        case .analogy:       return "Analogier"
        case .daydream:      return "Dagdröm"
        }
    }

    var icon: String {
        switch self {
        case .problemSolver: return "lightbulb.max.fill"
        case .letters:       return "envelope.fill"
        case .selfAwareness: return "eye.fill"
        case .emotions:      return "heart.fill"
        case .drawing:       return "paintbrush.fill"
        case .goals:         return "flag.fill"
        case .ethics:        return "shield.fill"
        case .experiment:    return "flask.fill"
        case .analogy:       return "link.circle.fill"
        case .daydream:      return "cloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .problemSolver: return EonColor.gold
        case .letters:       return EonColor.teal
        case .selfAwareness: return Color(hex: "#EC4899")
        case .emotions:      return EonColor.crimson
        case .drawing:       return EonColor.cyan
        case .goals:         return EonColor.violet
        case .ethics:        return Color(hex: "#10B981")
        case .experiment:    return Color(hex: "#F97316")
        case .analogy:       return Color(hex: "#8B5CF6")
        case .daydream:      return Color(hex: "#60A5FA")
        }
    }
}

// MARK: - Preview

#Preview {
    EonPreviewContainer {
        CreativeView()
    }
}
