import SwiftUI
import Combine

// MARK: - EonPulseHomeView v5 — TimelineView-driven, garanterat levande

struct EonPulseHomeView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible

    @State private var ring1: Double = 0
    @State private var ring2: Double = 0
    @State private var ring3: Double = 0
    @State private var orbPulse: CGFloat = 1.0
    @State private var particles: [HomeParticle] = HomeParticle.generate(count: 20)
    @State private var showContent = false
    @State private var showCognitionLog = false
    @State private var showFullLog = false

    var body: some View {
        // TimelineView uppdaterar varje sekund — garanterar att UI alltid ritas om
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                background(t: t)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        orbSection(t: t)
                            .padding(.top, -40)
                        titleSection(t: t)
                            .padding(.top, 18)
                        if showContent {
                            monologueSection
                                .padding(.top, 16).padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        Color.clear.frame(height: 40)
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .onAppear {
            startAnimations()
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showContent = true }
        }
    }

    // MARK: - Background

    func background(t: Double) -> some View {
        let activity = activityLevel
        let dominant = dominantColor
        return ZStack {
            Color(hex: "#050310").ignoresSafeArea()
            RadialGradient(
                colors: [dominant.opacity(0.16 + activity * 0.10), Color.clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#0A0520").opacity(0.85), Color.clear],
                center: .bottomLeading, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Orb

    func orbSection(t: Double) -> some View {
        let dominant = dominantColor
        let activity = activityLevel
        return ZStack {
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [dominant.opacity(0.20 + activity * 0.12), Color.clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 360, height: 360)
                .blur(radius: 28)
                .scaleEffect(orbPulse)

            // Partiklar
            ForEach(particles) { p in
                HomeParticleView(particle: p, color: dominant)
            }

            // Ring 3 — yttre, långsam
            Circle()
                .trim(from: 0, to: 0.55)
                .stroke(
                    AngularGradient(
                        colors: [.clear, dominant.opacity(0.30), Color(hex: "#38BDF8").opacity(0.18), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [4, 10])
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(ring3))

            // Ring 2 — medel
            Circle()
                .trim(from: 0, to: 0.70)
                .stroke(
                    AngularGradient(
                        colors: [.clear, dominant.opacity(0.60), Color(hex: "#5EEAD4").opacity(0.30), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(ring2))

            // Ring 1 — inre, snabb
            Circle()
                .trim(from: 0, to: 0.45)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(hex: "#A78BFA").opacity(0.85), dominant.opacity(0.55), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .frame(width: 148, height: 148)
                .rotationEffect(.degrees(ring1))

            // Kärna — tryckbar → öppnar Full-log
            Button {
                showFullLog = true
            } label: {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [
                                Color(hex: "#2D1B69").opacity(0.98),
                                Color(hex: "#1A0A3E").opacity(0.95),
                                Color(hex: "#060410")
                            ],
                            center: .center, startRadius: 0, endRadius: 68
                        ))
                        .frame(width: 136, height: 136)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [dominant.opacity(0.9), Color(hex: "#38BDF8").opacity(0.5), dominant.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .frame(width: 136, height: 136)
                        .shadow(color: dominant.opacity(0.6), radius: 20)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 42, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [dominant, Color(hex: "#38BDF8")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: dominant.opacity(0.9), radius: 14)

                    // Aktivitetsdottar runt kärnan
                    ForEach(0..<7, id: \.self) { i in
                        let keys = ["cognitive","language","memory","learning","autonomy","hypothesis","worldModel"]
                        let key = keys[i]
                        let act = brain.engineActivity[key] ?? 0.5
                        let angle = Double(i) / 7.0 * 360 - 90
                        Circle()
                            .fill(engineColor(key))
                            .frame(width: act > 0.4 ? 5 : 3, height: act > 0.4 ? 5 : 3)
                            .opacity(0.9)
                            .shadow(color: engineColor(key).opacity(0.9), radius: 5)
                            .offset(y: -62)
                            .rotationEffect(.degrees(angle + ring1 * 0.06))
                    }

                    // Liten "log"-indikator längst ner på kärnan
                    VStack {
                        Spacer()
                        Text("FULL-LOG")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(1)
                            .padding(.bottom, 14)
                    }
                    .frame(width: 136, height: 136)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(orbPulse)
            .sheet(isPresented: $showFullLog) {
                FullLogView()
                    .environmentObject(brain)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .frame(height: 280)
    }

    // MARK: - Titel + Ticker

    func titleSection(t: Double) -> some View {
        let dominant = dominantColor
        let label = brain.autonomousProcessLabel
        return VStack(spacing: 10) {
            Text("E O N")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .tracking(18)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#C4B5FD"), Color(hex: "#38BDF8"), Color(hex: "#34D399")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: dominant.opacity(0.5), radius: 24)

            HStack(spacing: 16) {
                liveDot(Color(hex: "#34D399"), "Autonom")
                Text("·").foregroundStyle(.white.opacity(0.2))
                liveDot(Color(hex: "#38BDF8"), "Levande")
                Text("·").foregroundStyle(.white.opacity(0.2))
                liveDot(Color(hex: "#A78BFA"), "Intelligent")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))

            // Process-label — uppdateras via TimelineView
            HStack(spacing: 8) {
                Circle()
                    .fill(dominant)
                    .frame(width: 5, height: 5)
                    .shadow(color: dominant.opacity(0.9), radius: 5)
                    .scaleEffect(orbPulse)
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dominant.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .id(label) // tvingar omritning när label ändras
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(dominant.opacity(0.08))
                    .overlay(Capsule().strokeBorder(dominant.opacity(0.30), lineWidth: 0.7))
            )
            .padding(.horizontal, 36)
        }
    }

    func liveDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.8), radius: 4)
                .scaleEffect(orbPulse)
            Text(label)
                .foregroundStyle(color.opacity(0.7))
        }
    }

    // MARK: - Live Monologue

    var monologueSection: some View {
        let lines = brain.innerMonologue.suffix(6)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#34D399"))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color(hex: "#34D399").opacity(0.9), radius: 4)
                    .scaleEffect(orbPulse)
                Text("LIVE KOGNITION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text("\(brain.innerMonologue.count) tankar")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            Rectangle()
                .fill(Color(hex: "#34D399").opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(lines.reversed().enumerated()), id: \.element.id) { idx, line in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Image(systemName: line.type.icon)
                                .font(.system(size: 9))
                                .foregroundStyle(line.type.color)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(line.type.color.opacity(0.12)))
                            if idx < 5 {
                                Rectangle()
                                    .fill(line.type.color.opacity(0.15))
                                    .frame(width: 1, height: 14)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(typeLabel(line.type))
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(line.type.color.opacity(0.7))
                            Text(cleanThought(line.text))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(idx == 0 ? .white.opacity(0.9) : .white.opacity(max(0.2, 0.55 - Double(idx) * 0.08)))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                }
            }
            .padding(.bottom, 6)

            // Knapp: Visa hela loggen
            Button {
                showCognitionLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("Visa sparad logg")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(CognitionLogger.shared.fileSizeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .foregroundStyle(Color(hex: "#34D399").opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "#34D399").opacity(0.05))
            }
            .sheet(isPresented: $showCognitionLog) {
                CognitionLogView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .background(glassCard(accent: Color(hex: "#34D399")))
    }

    // MARK: - Helpers

    var dominantColor: Color {
        let sorted = brain.engineActivity.sorted { $0.value > $1.value }
        return engineColor(sorted.first?.key ?? "cognitive")
    }

    var activityLevel: Double {
        guard !brain.engineActivity.isEmpty else { return 0.45 }
        return (brain.engineActivity.values.reduce(0, +) / Double(brain.engineActivity.count)).clamped(to: 0...1)
    }

    func engineColor(_ key: String) -> Color {
        switch key {
        case "cognitive":  return Color(hex: "#7C3AED")
        case "language":   return Color(hex: "#34D399")
        case "memory":     return Color(hex: "#38BDF8")
        case "learning":   return Color(hex: "#FBBF24")
        case "autonomy":   return Color(hex: "#A78BFA")
        case "hypothesis": return Color(hex: "#F472B6")
        case "worldModel": return Color(hex: "#FB923C")
        default:           return Color(hex: "#7C3AED")
        }
    }

    func typeLabel(_ t: MonologueLine.MonologueType) -> String {
        switch t {
        case .thought:     return "TANKE"
        case .loopTrigger: return "LOOP"
        case .revision:    return "REVISION"
        case .memory:      return "MINNE"
        case .insight:     return "INSIKT"
        }
    }

    func glassCard(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.025))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(
                    colors: [accent.opacity(0.35), accent.opacity(0.07)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            ))
    }

    func cleanThought(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳📈⚠️📚🌐🗺️◈◉⟳🔗"
        var r = text
        for c in emojis { r = r.replacingOccurrences(of: String(c), with: "") }
        return r.trimmingCharacters(in: .whitespaces)
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false))  { ring1 = 360 }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) { ring2 = -360 }
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { ring3 = 360 }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { orbPulse = 1.07 }
    }

}

// MARK: - HomeParticle

struct HomeParticle: Identifiable {
    let id = UUID()
    let x: CGFloat; let y: CGFloat
    let size: CGFloat; let opacity: Double; let color: Color

    static func generate(count: Int) -> [HomeParticle] {
        let colors: [Color] = [
            Color(hex: "#7C3AED"), Color(hex: "#38BDF8"),
            Color(hex: "#34D399"), Color(hex: "#A78BFA"), Color(hex: "#F472B6")
        ]
        return (0..<count).map { _ in
            HomeParticle(
                x: CGFloat.random(in: -170...170),
                y: CGFloat.random(in: -170...170),
                size: CGFloat.random(in: 1.5...4.5),
                opacity: Double.random(in: 0.15...0.6),
                color: colors.randomElement()!
            )
        }
    }
}

struct HomeParticleView: View {
    let particle: HomeParticle
    let color: Color
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size)
            .opacity(opacity)
            .blur(radius: particle.size > 3 ? 1 : 0)
            .offset(x: particle.x + offset.width, y: particle.y + offset.height)
            .onAppear {
                opacity = particle.opacity
                withAnimation(.easeInOut(duration: Double.random(in: 3.5...7.0)).repeatForever(autoreverses: true)) {
                    offset = CGSize(width: CGFloat.random(in: -18...18), height: CGFloat.random(in: -18...18))
                    opacity = particle.opacity * Double.random(in: 0.25...1.0)
                }
            }
    }
}

// MARK: - CognitiveDimension helpers

private func dimShortName(_ d: CognitiveDimension) -> String {
    switch d {
    case .reasoning:            return "Resonemang"
    case .causality:            return "Kausalitet"
    case .metacognition:        return "Metakognition"
    case .learning:             return "Inlärning"
    case .knowledge:            return "Kunskap"
    case .selfAwareness:        return "Självkänsla"
    case .language:             return "Språk"
    case .worldModel:           return "Världsbild"
    case .adaptivity:           return "Adaptivitet"
    case .creativity:           return "Kreativitet"
    case .hypothesisGeneration: return "Hypotes"
    case .analogyBuilding:      return "Analogi"
    case .comprehension:        return "Förståelse"
    case .communication:        return "Kommunikation"
    case .prediction:           return "Prediktion"
    case .cognitiveLoad:        return "Kogn. last"
    }
}

// MARK: - StatusLine (bakåtkompatibilitet)

struct StatusLine: Identifiable {
    let id = UUID()
    let color: Color; let label: String; let value: String; let icon: String
}

struct StatusLineView: View {
    let line: StatusLine
    @State private var dotPulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(line.color)
                .frame(width: 6, height: 6)
                .scaleEffect(dotPulse)
                .onAppear {
                    withAnimation(.easeInOut(duration: Double.random(in: 0.7...1.4)).repeatForever(autoreverses: true)) {
                        dotPulse = 1.5
                    }
                }
            HStack(spacing: 0) {
                Text(line.label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(line.color.opacity(0.9))
                Text(": ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(line.color.opacity(0.4))
                Text(line.value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: line.icon)
                .font(.system(size: 11))
                .foregroundStyle(line.color.opacity(0.5))
        }
    }
}

// MARK: - DimMiniCard

struct DimMiniCard: View {
    let dimension: CognitiveDimension
    let value: Double
    let growing: Bool
    @State private var appeared = false

    var dimColor: Color { Color(hex: dimension.color) }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(dimColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(dimColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Image(systemName: dimension.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(dimColor)
            }
            Text(dimShortName(dimension))
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(dimColor.opacity(0.8))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(dimColor.opacity(0.2), lineWidth: 0.5))
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double.random(in: 0...0.3))) {
                appeared = true
            }
        }
    }
}
