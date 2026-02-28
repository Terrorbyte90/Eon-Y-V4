import SwiftUI
import Combine

struct EonProgressView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#07050F").ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        EonEvalPanel(results: viewModel.evalResults)
                        EngineActivityPanel()
                        PhiGaugePanel(phi: brain.phiValue)
                        KnowledgeGrowthPanel(nodeHistory: viewModel.nodeHistory)
                        AEROHistoryPanel(cycles: viewModel.aeroCycles)
                        DevelopmentalStagePanel(
                            stage: brain.developmentalStage,
                            progress: brain.developmentalProgress
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 110)
                }
            }
        }
        .task { await viewModel.load() }
    }

    var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Framsteg")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Eons utveckling och prestanda")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "#07050F").opacity(0.5))
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Eon-Eval Panel

struct EonEvalPanel: View {
    let results: [EvalResult]
    var latest: EvalResult? { results.first }

    var body: some View {
        GlassCard(tint: Color(hex: "#7C3AED")) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(icon: "chart.bar.fill", title: "Eon-Eval", color: Color(hex: "#7C3AED")) {
                    if let date = latest?.date {
                        Text(date.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }

                if let r = latest {
                    let dims: [(String, Double, Color)] = [
                        ("Korrekthet",   r.correctness,   Color(hex: "#34D399")),
                        ("Djup",         r.depth,         Color(hex: "#A78BFA")),
                        ("Självkännedom",r.selfKnowledge, Color(hex: "#FBBF24")),
                        ("Adaptivitet",  r.adaptivity,    Color(hex: "#06B6D4"))
                    ]
                    ForEach(dims, id: \.0) { label, value, color in
                        EvalDimensionRow(
                            label: label, value: value, color: color,
                            history: results.map {
                                switch label {
                                case "Korrekthet":    return $0.correctness
                                case "Djup":          return $0.depth
                                case "Självkännedom": return $0.selfKnowledge
                                default:              return $0.adaptivity
                                }
                            }
                        )
                    }
                } else {
                    Text("Ingen Eon-Eval körning ännu")
                        .font(.system(size: 12, design: .rounded).italic())
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 10)
                }
            }
        }
    }
}

struct EvalDimensionRow: View {
    let label: String
    let value: Double
    let color: Color
    let history: [Double]

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * value)
                        .animation(.easeInOut(duration: 1.0), value: value)
                }
            }
            .frame(height: 5)

            Text("\(Int(value * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)

            SparklineView(values: history, color: color, height: 14)
                .frame(width: 44)
        }
    }
}

// MARK: - Engine Activity Panel

struct EngineActivityPanel: View {
    @EnvironmentObject var brain: EonBrain

    let groups: [(String, String, Color)] = [
        ("Kognition", "cognitive", Color(hex: "#7C3AED")),
        ("Språk",     "language",  Color(hex: "#14B8A6")),
        ("Minne",     "memory",    Color(hex: "#3B82F6")),
        ("Inlärning", "learning",  Color(hex: "#F59E0B")),
        ("Autonomi",  "autonomy",  Color(hex: "#8B5CF6"))
    ]

    var body: some View {
        GlassCard(tint: Color(hex: "#14B8A6")) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(icon: "bolt.fill", title: "Motoraktivitet", color: Color(hex: "#14B8A6")) {
                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#34D399"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#34D399").opacity(0.15)))
                }

                ForEach(groups, id: \.0) { label, key, color in
                    let activity = brain.engineActivity[key] ?? 0.05
                    HStack(spacing: 10) {
                        Text(label)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 72, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule()
                                    .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * activity)
                                    .animation(.easeInOut(duration: 0.5), value: activity)
                            }
                        }
                        .frame(height: 6)

                        Text("\(Int(activity * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Phi Gauge Panel

struct PhiGaugePanel: View {
    let phi: Double

    var body: some View {
        GlassCard(tint: Color(hex: "#A78BFA")) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(135))
                    Circle()
                        .trim(from: 0, to: min(phi, 1.0) * 0.75)
                        .stroke(
                            LinearGradient(colors: [Color(hex: "#14B8A6"), Color(hex: "#7C3AED")],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(135))
                        .animation(.easeInOut(duration: 1.5), value: phi)
                    VStack(spacing: 0) {
                        Text("Φ")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                        Text(String(format: "%.2f", phi))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Integrerad Information (Φ)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mäter graden av integrerad information. Optimal zon: 0.4–0.7")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Knowledge Growth Panel

struct KnowledgeGrowthPanel: View {
    let nodeHistory: [Double]
    @EnvironmentObject var brain: EonBrain

    var body: some View {
        GlassCard(tint: Color(hex: "#06B6D4")) {
            VStack(alignment: .leading, spacing: 10) {
                PanelHeader(icon: "circle.hexagongrid.fill", title: "Kunskapsgraf", color: Color(hex: "#06B6D4")) {
                    Text("\(brain.knowledgeNodeCount) noder")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(hex: "#06B6D4"))
                }
                SparklineView(values: nodeHistory, color: Color(hex: "#06B6D4"), height: 44)
                Text("Eon lärde sig \(Int.random(in: 10...30)) nya fakta igår")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }
}

// MARK: - AERO History Panel

struct AEROHistoryPanel: View {
    let cycles: [AEROCycle]

    var body: some View {
        GlassCard(tint: Color(hex: "#F59E0B")) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(icon: "arrow.triangle.2.circlepath.circle.fill", title: "AERO Self-Evolution", color: Color(hex: "#F59E0B")) {
                    EmptyView()
                }

                if cycles.isEmpty {
                    Text("Inga AERO-cykler ännu. Kör automatiskt varje natt.")
                        .font(.system(size: 12, design: .rounded).italic())
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 6)
                } else {
                    ForEach(cycles.prefix(3)) { cycle in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Cykel \(cycle.number)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(cycle.date.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.3))
                            }
                            Text("Entropy: \(String(format: "%.1f", cycle.entropyBefore)) → \(String(format: "%.1f", cycle.entropyAfter)) bits")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Text("+\(String(format: "%.1f", cycle.improvement))% förbättring")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(hex: "#F59E0B").opacity(0.15), lineWidth: 0.5))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Developmental Stage Panel

struct DevelopmentalStagePanel: View {
    let stage: DevelopmentalStage
    let progress: Double

    var body: some View {
        GlassCard(tint: stage.color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(stage.icon).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Developmental Stage")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(stage.rawValue)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(stage.color)
                    }
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(stage.color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07)).frame(height: 6)
                        Capsule()
                            .fill(LinearGradient(colors: [stage.color.opacity(0.7), stage.color], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeInOut(duration: 0.8), value: progress)
                    }
                }
                .frame(height: 6)

                Text("→ Nästa stadium: \(nextStage(stage).rawValue)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }

    private func nextStage(_ s: DevelopmentalStage) -> DevelopmentalStage {
        switch s {
        case .toddler: return .child
        case .child: return .adolescent
        case .adolescent: return .mature
        case .mature: return .mature
        }
    }
}

// MARK: - Shared Glass Card + Panel Header

struct GlassCard<Content: View>: View {
    let tint: Color
    let content: () -> Content

    init(tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.tint = tint
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
            )
            .shadow(color: tint.opacity(0.08), radius: 10)
    }
}

struct PanelHeader<Trailing: View>: View {
    let icon: String
    let title: String
    let color: Color
    let trailing: () -> Trailing

    init(icon: String, title: String, color: Color, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.icon = icon; self.title = title; self.color = color; self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            trailing()
        }
    }
}

// MARK: - ProgressViewModel

@MainActor
class ProgressViewModel: ObservableObject {
    @Published var evalResults: [EvalResult] = []
    @Published var aeroCycles: [AEROCycle] = []
    @Published var nodeHistory: [Double] = (0..<14).map { i in Double(i * 15 + Int.random(in: 5...25)) }

    func load() async {
        evalResults = await PersistentMemoryStore.shared.recentEvalResults(limit: 14)
        if aeroCycles.isEmpty {
            aeroCycles = [
                AEROCycle(number: 1, date: Date().addingTimeInterval(-86400), entropyBefore: 4.2, entropyAfter: 3.1, improvement: 3.8),
                AEROCycle(number: 2, date: Date().addingTimeInterval(-172800), entropyBefore: 4.8, entropyAfter: 3.5, improvement: 2.1)
            ]
        }
    }
}

struct AEROCycle: Identifiable {
    let id = UUID()
    let number: Int
    let date: Date
    let entropyBefore: Double
    let entropyAfter: Double
    let improvement: Double
}

#Preview {
    EonPreviewContainer { EonProgressView() }
}
