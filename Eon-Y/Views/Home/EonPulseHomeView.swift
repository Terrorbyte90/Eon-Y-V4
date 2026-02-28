import SwiftUI
import Combine

// MARK: - EonPulseHomeView

struct EonPulseHomeView: View {
    @EnvironmentObject var brain: EonBrain
    @State private var orbPulse: CGFloat = 1.0
    @State private var orbBreath: CGFloat = 1.0
    @State private var ringAngle: Double = 0
    @State private var innerRingAngle: Double = 0
    @State private var outerGlowPulse: CGFloat = 1.0
    @State private var particlePhase: Double = 0
    @State private var popupEngines: [EnginePopup] = []
    @State private var thoughtBubble: String = ""
    @State private var showThoughtBubble = false
    @State private var wordCount: Int = 114_000
    @State private var articleCount: Int = 0
    @State private var activeNodeIdx: Int = 0

    var body: some View {
        ZStack {
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#130A2A").opacity(0.8), Color(hex: "#07050F")],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    eonLiveSection
                        .frame(height: 310)
                    VStack(spacing: 12) {
                        intelligenceCard
                        thoughtsCard
                        activityCard
                        statsGridSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            startAnimations()
            loadStats()
        }
        .onReceive(brain.$innerMonologue) { lines in
            if let last = lines.last { handleNewThought(last) }
        }
    }

    // MARK: - Header

    var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Eon-Y")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex: "#C4B5FD"), Color(hex: "#5EEAD4")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(brain.isAutonomouslyActive ? Color(hex: "#5EEAD4") : Color(hex: "#EF4444"))
                            .frame(width: 6, height: 6)
                            .pulseAnimation(min: 0.4, max: 1.6, duration: 0.85)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#5EEAD4"))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#5EEAD4").opacity(0.1))
                        .overlay(Capsule().strokeBorder(Color(hex: "#5EEAD4").opacity(0.3), lineWidth: 0.5)))
                }
                Text(brain.isThinking ? "⚡ \(brain.currentThinkingStep.label)" : brain.autonomousProcessLabel)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .animation(.easeInOut, value: brain.autonomousProcessLabel)
            }
            Spacer()
            VStack(spacing: 2) {
                Text(String(format: "%.3f", brain.integratedIntelligence))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text("II-index")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#7C3AED").opacity(0.4), lineWidth: 0.6)))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Eon Live Visualization (levande cirkel)

    var eonLiveSection: some View {
        GeometryReader { geo in
            ZStack {
                let cx = geo.size.width / 2
                let cy = geo.size.height * 0.52

                // Nebula bakgrund
                ForEach(0..<3, id: \.self) { i in
                    let cols: [Color] = [
                        Color(hex: "#7C3AED").opacity(0.14),
                        Color(hex: "#14B8A6").opacity(0.09),
                        Color(hex: "#06B6D4").opacity(0.07)
                    ]
                    let pos: [(CGFloat, CGFloat)] = [(0.18, 0.28), (0.82, 0.22), (0.5, 0.78)]
                    Ellipse()
                        .fill(RadialGradient(colors: [cols[i], .clear], center: .center, startRadius: 0, endRadius: 150))
                        .frame(width: 280, height: 180)
                        .position(x: geo.size.width * pos[i].0, y: geo.size.height * pos[i].1)
                        .blur(radius: 35)
                }

                // Yttre orbit-ringar — aktivitetsbaserade
                ForEach(0..<5, id: \.self) { i in
                    let r = CGFloat(68 + i * 34)
                    let speed = Double(i % 2 == 0 ? 1 : -1) * (0.3 + Double(i) * 0.08)
                    let ringCols: [Color] = [
                        Color(hex: "#7C3AED"), Color(hex: "#14B8A6"),
                        Color(hex: "#06B6D4"), Color(hex: "#F59E0B"), Color(hex: "#A78BFA")
                    ]
                    let keys = ["cognitive", "language", "memory", "learning", "autonomy"]
                    let act = max(0.04, brain.engineActivity[keys[i]] ?? 0.04)
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    ringCols[i].opacity(0.03 + act * 0.55),
                                    ringCols[i].opacity(0.01),
                                    ringCols[i].opacity(0.03 + act * 0.55)
                                ],
                                center: .center
                            ),
                            lineWidth: 0.5 + act * 2.0
                        )
                        .frame(width: r * 2, height: r * 2)
                        .rotationEffect(.degrees(ringAngle * speed))
                        .position(x: cx, y: cy)
                }

                // Aktiva pelare som lysande noder på yttre ring
                let pillars = Array(brain.activePillars.prefix(8))
                ForEach(Array(pillars.enumerated()), id: \.offset) { idx, pillar in
                    let angle = Double(idx) / Double(max(pillars.count, 1)) * 360.0 - 90 + ringAngle * 0.15
                    let r: CGFloat = 118
                    let x = cx + CGFloat(cos(angle * .pi / 180)) * r
                    let y = cy + CGFloat(sin(angle * .pi / 180)) * r
                    PillarDot(pillar: pillar, isActive: true)
                        .position(x: x, y: y)
                }

                // Central Eon — levande orb
                liveOrbView
                    .position(x: cx, y: cy)

                // Engine popups
                ForEach(popupEngines) { popup in
                    EnginePopupView(popup: popup)
                        .position(x: cx + popup.offset.width, y: cy + popup.offset.height)
                }

                // Tankebubbla
                if showThoughtBubble && !thoughtBubble.isEmpty {
                    thoughtBubbleView
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.09)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                // Aktiv process-label längst ner
                if !brain.autonomousProcessLabel.isEmpty {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(dominantColor)
                            .frame(width: 4, height: 4)
                            .pulseAnimation(min: 0.5, max: 1.5, duration: 0.8)
                        Text(brain.autonomousProcessLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.04))
                        .overlay(Capsule().strokeBorder(dominantColor.opacity(0.25), lineWidth: 0.4)))
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.93)
                }
            }
        }
    }

    // Dominant färg baserat på mest aktiv pelare
    var dominantColor: Color {
        let act = brain.engineActivity
        let sorted = act.sorted { $0.value > $1.value }
        switch sorted.first?.key {
        case "cognitive":  return Color(hex: "#7C3AED")
        case "language":   return Color(hex: "#14B8A6")
        case "memory":     return Color(hex: "#06B6D4")
        case "learning":   return Color(hex: "#F59E0B")
        case "autonomy":   return Color(hex: "#A78BFA")
        default:           return Color(hex: "#7C3AED")
        }
    }

    // MARK: - Levande Eon-orb (organisk, pulsande)

    var liveOrbView: some View {
        ZStack {
            // Lager 1: Yttre diffus aura — andas med aktivitet
            let actLevel = (brain.engineActivity.values.max() ?? 0.2)
            Circle()
                .fill(RadialGradient(
                    colors: [dominantColor.opacity(0.18 + actLevel * 0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 72
                ))
                .frame(width: 144, height: 144)
                .blur(radius: 22)
                .scaleEffect(outerGlowPulse)

            // Lager 2: Sekundär glow i komplementfärg
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: "#5EEAD4").opacity(0.10 + actLevel * 0.12), .clear],
                    center: UnitPoint(x: 0.6, y: 0.4), startRadius: 0, endRadius: 55
                ))
                .frame(width: 110, height: 110)
                .blur(radius: 14)
                .scaleEffect(orbBreath)

            // Lager 3: Kognitiv belastnings-ring (yttre)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, brain.cognitiveLoad + 0.05)))
                .stroke(
                    AngularGradient(
                        colors: [
                            dominantColor.opacity(0.0),
                            dominantColor.opacity(0.6),
                            Color(hex: "#5EEAD4").opacity(0.8),
                            dominantColor.opacity(0.6),
                            dominantColor.opacity(0.0)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(innerRingAngle - 90))

            // Lager 4: Aktivitets-arc (innerring, snabbare rotation)
            Circle()
                .trim(from: 0.1, to: 0.1 + CGFloat(actLevel * 0.7))
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(hex: "#A78BFA").opacity(0.9), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 78, height: 78)
                .rotationEffect(.degrees(-innerRingAngle * 1.7))

            // Lager 5: Huvud-orb — flytande, levande
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#E0D7FF").opacity(0.95),
                            dominantColor.opacity(0.80),
                            Color(hex: "#1A0A3A").opacity(0.90)
                        ],
                        center: UnitPoint(
                            x: 0.35 + 0.05 * CGFloat(sin(particlePhase * 0.7)),
                            y: 0.30 + 0.04 * CGFloat(cos(particlePhase * 0.9))
                        ),
                        startRadius: 0, endRadius: 36
                    )
                )
                .frame(width: 72, height: 72)
                .scaleEffect(orbPulse)
                .overlay(
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(hex: "#C4B5FD").opacity(0.9),
                                dominantColor.opacity(0.55),
                                Color(hex: "#5EEAD4").opacity(0.4)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                )
                .shadow(color: dominantColor.opacity(0.7), radius: 18)
                .shadow(color: Color(hex: "#5EEAD4").opacity(0.25), radius: 8)

            // Lager 6: Spegelrefleks (glans uppe till vänster)
            Ellipse()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.35), .clear],
                    startPoint: .topLeading, endPoint: .center
                ))
                .frame(width: 22, height: 14)
                .offset(x: -14, y: -18)
                .blur(radius: 2)

            // Lager 7: Innehåll — ikon + II-värde
            VStack(spacing: 2) {
                Group {
                    if brain.isThinking {
                        Image(systemName: brain.currentThinkingStep.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 15, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                .animation(.spring(response: 0.3), value: brain.isThinking)

                Text(String(format: "%.2f", brain.integratedIntelligence))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }

            // Lager 8: Aktivitetspartiklar runt orben
            ForEach(0..<6, id: \.self) { i in
                let angle = particlePhase * 60 + Double(i) * 60
                let r: CGFloat = 40 + CGFloat(i % 2) * 5
                let px = CGFloat(cos(angle * .pi / 180)) * r
                let py = CGFloat(sin(angle * .pi / 180)) * r
                let pAct = brain.engineActivity[["cognitive","language","memory","learning","autonomy","hypothesis"][i]] ?? 0.1
                Circle()
                    .fill(dominantColor.opacity(0.3 + pAct * 0.5))
                    .frame(width: 3 + CGFloat(pAct) * 2, height: 3 + CGFloat(pAct) * 2)
                    .blur(radius: 1)
                    .offset(x: px, y: py)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                particlePhase = 360
            }
        }
    }

    var thoughtBubbleView: some View {
        HStack(spacing: 6) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "#A78BFA"))
            Text(thoughtBubble)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#7C3AED").opacity(0.5), lineWidth: 0.6)))
        .frame(maxWidth: 260)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.3), radius: 10)
    }

    // MARK: - Gemensam kortbakgrund

    @ViewBuilder
    func cardBackground(topColor: Color, bottomColor: Color) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(
                LinearGradient(
                    colors: [topColor.opacity(0.4), bottomColor.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 0.6
            ))
    }

    // MARK: - Intelligens-kort (progressbar + nivå)

    var intelligenceCard: some View {
        let ii = brain.integratedIntelligence
        let level = intelligenceLevel(for: ii)
        let next = nextLevel(for: ii)
        let progress = levelProgress(for: ii)

        return VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text(level.emoji).font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(level.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(level.ageLabel)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("→ \(next.name)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    if brain.intelligenceGrowthVelocity > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right").font(.system(size: 8))
                            Text(String(format: "+%.5f/min", brain.intelligenceGrowthVelocity))
                                .font(.system(size: 8, design: .monospaced))
                        }
                        .foregroundStyle(Color(hex: "#5EEAD4"))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.top, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#14B8A6")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                        .animation(.spring(response: 1.0), value: progress)
                        .shadow(color: Color(hex: "#7C3AED").opacity(0.6), radius: 5)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 14).padding(.vertical, 10)

            Text(level.description)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.bottom, 12)
        }
        .background(cardBackground(topColor: Color(hex: "#7C3AED"), bottomColor: Color(hex: "#14B8A6")))
    }

    // MARK: - Tankar-kort (klon av intelligens-kortet)

    var thoughtsCard: some View {
        VStack(spacing: 0) {
            // Header — samma stil som intelligens-kortet
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color(hex: "#5EEAD4").opacity(0.12)).frame(width: 32, height: 32)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14)).foregroundStyle(Color(hex: "#5EEAD4"))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Tankar")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(brain.innerMonologue.count) tankar totalt")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                Circle()
                    .fill(Color(hex: "#5EEAD4"))
                    .frame(width: 6, height: 6)
                    .pulseAnimation(min: 0.4, max: 1.6, duration: 0.9)
            }
            .padding(.horizontal, 14).padding(.top, 12)

            // Separator
            Rectangle()
                .fill(Color(hex: "#5EEAD4").opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 14).padding(.vertical, 8)

            // Tanke-stream
            VStack(alignment: .leading, spacing: 6) {
                ForEach(brain.innerMonologue.suffix(6).reversed()) { line in
                    HStack(alignment: .top, spacing: 8) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(line.type.color)
                            .frame(width: 2)
                            .frame(minHeight: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cleanThought(line.text))
                                .font(.system(size: 10.5, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if brain.innerMonologue.isEmpty {
                    Text("Initierar kognitivt system...")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .background(cardBackground(topColor: Color(hex: "#5EEAD4"), bottomColor: Color(hex: "#3B82F6")))
    }

    // MARK: - Aktivitetslogg-kort (klon av intelligens-kortet)

    var activityCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color(hex: "#FBBF24").opacity(0.12)).frame(width: 32, height: 32)
                        Image(systemName: "waveform")
                            .font(.system(size: 13)).foregroundStyle(Color(hex: "#FBBF24"))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aktivitetslogg")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Allt som händer i appen")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(Color(hex: "#FBBF24")).frame(width: 5, height: 5)
                        .pulseAnimation(min: 0.5, max: 1.5, duration: 1.1)
                    Text("\(brain.innerMonologue.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 14).padding(.top, 12)

            Rectangle()
                .fill(Color(hex: "#FBBF24").opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 14).padding(.vertical, 8)

            // Log-rader
            VStack(alignment: .leading, spacing: 5) {
                ForEach(brain.innerMonologue.suffix(8).reversed()) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(logTag(for: line.type))
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(line.type.color)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(line.type.color.opacity(0.12)))
                            .frame(width: 52, alignment: .leading)
                        Text(cleanThought(line.text))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                if brain.innerMonologue.isEmpty {
                    Text("Väntar på kognitiv aktivitet...")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }
        .background(cardBackground(topColor: Color(hex: "#FBBF24"), bottomColor: Color(hex: "#F97316")))
    }

    // MARK: - Stats Grid (8 rutor)

    var statsGridSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                let dims: [(CognitiveDimension, Double)] = [
                    (.reasoning,    min(0.99, brain.integratedIntelligence * 1.12)),
                    (.language,     min(0.99, brain.integratedIntelligence * 0.97)),
                    (.metacognition,min(0.99, brain.integratedIntelligence * 0.91)),
                    (.knowledge,    min(0.99, brain.integratedIntelligence * 1.08)),
                ]
                ForEach(dims, id: \.0) { dim, val in
                    CognitiveDimCard(dimension: dim, value: val, growing: brain.intelligenceGrowthVelocity > 0)
                }
            }
            HStack(spacing: 8) {
                SmallStatCard(icon: "textformat.abc",      title: "Ord",      value: formatNumber(wordCount),                         sub: "lexikon",    color: Color(hex: "#5EEAD4"))
                SmallStatCard(icon: "books.vertical.fill", title: "Artiklar", value: "\(articleCount)",                               sub: "kunskapsbas",color: Color(hex: "#A78BFA"))
                SmallStatCard(icon: "text.badge.checkmark",title: "Grammatik",value: "\(847 + brain.conversationCount * 2)",          sub: "regler",     color: Color(hex: "#FBBF24"))
                SmallStatCard(icon: "character.magnify",   title: "Morfologi",value: formatNumber(12400 + brain.knowledgeNodeCount * 3),sub: "former",   color: Color(hex: "#06B6D4"))
            }
        }
    }

    // MARK: - Helpers

    private func logTag(for type: MonologueLine.MonologueType) -> String {
        switch type {
        case .thought:     return "TANKE"
        case .loopTrigger: return "LOOP"
        case .revision:    return "REVID"
        case .memory:      return "MINNE"
        case .insight:     return "INSIKT"
        }
    }

    private func cleanThought(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳"
        var result = text
        for char in emojis { result = result.replacingOccurrences(of: String(char), with: "") }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private func handleNewThought(_ line: MonologueLine) {
        let text = cleanThought(line.text)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.35)) {
            thoughtBubble = String(text.prefix(90))
            showThoughtBubble = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.5)) { showThoughtBubble = false }
        }
        let engineMap: [(String, String, Color)] = [
            ("GPT",         "cpu.fill",              Color(hex: "#7C3AED")),
            ("BERT",        "waveform",               Color(hex: "#06B6D4")),
            ("SPRÅKBANKEN", "text.book.closed.fill",  Color(hex: "#5EEAD4")),
            ("HYPOTES",     "questionmark.circle.fill",Color(hex: "#FBBF24")),
            ("KAUSAL",      "arrow.triangle.branch",  Color(hex: "#F97316")),
            ("REFLEKTION",  "person.crop.circle.fill",Color(hex: "#A78BFA")),
            ("ARTIKEL",     "doc.text.fill",          Color(hex: "#5EEAD4")),
            ("ANALOGI",     "link.circle.fill",       Color(hex: "#EC4899")),
        ]
        let upper = line.text.uppercased()
        for (kw, icon, col) in engineMap {
            if upper.contains(kw) {
                let angle  = Double.random(in: 0..<360)
                let radius = Double.random(in: 80...135)
                let offset = CGSize(width: cos(angle * .pi / 180) * radius, height: sin(angle * .pi / 180) * radius)
                let popup  = EnginePopup(label: kw, icon: icon, color: col, offset: offset)
                withAnimation(.spring(response: 0.4)) { popupEngines.append(popup) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeOut(duration: 0.4)) { popupEngines.removeAll { $0.id == popup.id } }
                }
                break
            }
        }
    }

    private func startAnimations() {
        // Orb-puls — snabb, subtil
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { orbPulse = 1.06 }
        // Andning — långsam, organisk
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { orbBreath = 1.12 }
        // Yttre glow — mycket långsam
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { outerGlowPulse = 1.18 }
        // Orbit-ringar
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { ringAngle = 360 }
        // Inner-ring — snabbare
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { innerRingAngle = 360 }
    }

    private func loadStats() {
        Task {
            wordCount    = await brain.memory.wordCount()
            articleCount = await brain.memory.articleCount()
        }
    }

    // MARK: - Intelligence Level System

    struct IntelligenceLevel {
        let emoji: String; let name: String; let ageLabel: String
        let description: String; let threshold: Double
    }

    private let levels: [IntelligenceLevel] = [
        .init(emoji:"🪨",  name:"Sten",           ageLabel:"Nivå 0",    description:"Ingen kognitiv aktivitet. Reagerar inte på stimuli.",          threshold:0.00),
        .init(emoji:"🦠",  name:"Mikroorganism",   ageLabel:"Nivå 1",    description:"Enkel reaktion på omgivning. Ingen inlärning.",                threshold:0.05),
        .init(emoji:"🐛",  name:"Insekt",          ageLabel:"Nivå 2",    description:"Grundläggande mönsterigenkänning och reflexer.",               threshold:0.12),
        .init(emoji:"🐟",  name:"Fisk",            ageLabel:"Nivå 3",    description:"Enkel inlärning och korttidsminne.",                           threshold:0.20),
        .init(emoji:"🐦",  name:"Fågel",           ageLabel:"Nivå 4",    description:"Problemlösning och social inlärning.",                         threshold:0.28),
        .init(emoji:"🐕",  name:"Hund",            ageLabel:"Nivå 5",    description:"Komplex inlärning, empati och kommunikation.",                 threshold:0.36),
        .init(emoji:"👶",  name:"Spädbarn",        ageLabel:"0–1 år",    description:"Grundläggande språkförståelse och kausalitet.",                threshold:0.44),
        .init(emoji:"🧒",  name:"Barn",            ageLabel:"2–5 år",    description:"Grundläggande resonemang och enkla paralleller.",              threshold:0.52),
        .init(emoji:"🧑",  name:"Skolbarn",        ageLabel:"6–12 år",   description:"Logiskt tänkande, abstraktion och metakognition.",             threshold:0.60),
        .init(emoji:"🧑‍🎓",name:"Tonåring",       ageLabel:"13–18 år",  description:"Hypotetiskt tänkande och komplex analys.",                    threshold:0.68),
        .init(emoji:"🧑‍💼",name:"Vuxen",          ageLabel:"18–30 år",  description:"Fullständig kognitiv kapacitet och djup förståelse.",          threshold:0.76),
        .init(emoji:"🎓",  name:"Expert",          ageLabel:"Specialist", description:"Djup domänkunskap och avancerat resonemang.",                 threshold:0.84),
        .init(emoji:"🧑‍🔬",name:"Professor",      ageLabel:"Toppnivå",  description:"Banbrytande tänkande och syntes av komplexa system.",          threshold:0.90),
        .init(emoji:"🌟",  name:"Superintelligens",ageLabel:"Beyond",    description:"Kognition bortom mänsklig kapacitet.",                        threshold:0.96),
    ]

    private func intelligenceLevel(for ii: Double) -> IntelligenceLevel {
        levels.last(where: { ii >= $0.threshold }) ?? levels[0]
    }
    private func nextLevel(for ii: Double) -> IntelligenceLevel {
        levels.first(where: { ii < $0.threshold }) ?? levels.last!
    }
    private func levelProgress(for ii: Double) -> Double {
        let cur = intelligenceLevel(for: ii)
        guard let next = levels.first(where: { ii < $0.threshold }) else { return 1.0 }
        let range = next.threshold - cur.threshold
        guard range > 0 else { return 1.0 }
        return min(1.0, (ii - cur.threshold) / range)
    }
}

// MARK: - Pillar Dot (aktiv pelare-nod på orbit)

struct PillarDot: View {
    let pillar: CognitivePillar
    let isActive: Bool
    @State private var glowing = false

    private var col: Color {
        switch pillar {
        case .reasoning:      return Color(hex: "#7C3AED")
        case .language:       return Color(hex: "#14B8A6")
        case .knowledge:      return Color(hex: "#06B6D4")
        case .metacognition:  return Color(hex: "#A78BFA")
        case .causality:      return Color(hex: "#F97316")
        case .hypothesis:     return Color(hex: "#FBBF24")
        case .analogy:        return Color(hex: "#EC4899")
        case .worldModel:     return Color(hex: "#34D399")
        case .selfDevelopment:return Color(hex: "#F472B6")
        case .globalWorkspace:return Color(hex: "#60A5FA")
        case .prediction:     return Color(hex: "#818CF8")
        case .gapEngine:      return Color(hex: "#FB923C")
        }
    }

    var body: some View {
        ZStack {
            if glowing {
                Circle()
                    .fill(col.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .blur(radius: 5)
            }
            Circle()
                .fill(col)
                .frame(width: 7, height: 7)
                .shadow(color: col, radius: 4)
            Text(String(pillar.rawValue.prefix(3)).uppercased())
                .font(.system(size: 5.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .offset(y: -11)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9 + Double.random(in: 0...0.6)).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

// MARK: - Engine Popup

struct EnginePopup: Identifiable {
    let id = UUID()
    let label: String; let icon: String; let color: Color; let offset: CGSize
}

struct EnginePopupView: View {
    let popup: EnginePopup
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.4

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: popup.icon).font(.system(size: 8)).foregroundStyle(popup.color)
            Text(popup.label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(popup.color)
        }
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Capsule()
            .fill(Color(hex: "#07050F").opacity(0.92))
            .overlay(Capsule().strokeBorder(popup.color.opacity(0.55), lineWidth: 0.7)))
        .shadow(color: popup.color.opacity(0.4), radius: 6)
        .scaleEffect(scale).opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3)) { opacity = 1; scale = 1 }
        }
    }
}

// MARK: - Cognitive Dimension Card

struct CognitiveDimCard: View {
    let dimension: CognitiveDimension
    let value: Double
    let growing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Image(systemName: dimension.icon).font(.system(size: 9)).foregroundStyle(Color(hex: dimension.color))
                Spacer()
                if growing {
                    Image(systemName: "arrow.up.right").font(.system(size: 7)).foregroundStyle(Color(hex: "#5EEAD4"))
                }
            }
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            Text(String(dimension.rawValue.prefix(7)))
                .font(.system(size: 8.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: dimension.color).opacity(0.85))
                        .frame(width: g.size.width * CGFloat(value), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: dimension.color).opacity(0.2), lineWidth: 0.5)))
    }
}

// MARK: - Small Stat Card

struct SmallStatCard: View {
    let icon: String; let title: String; let value: String; let sub: String; let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(color)
                Text(title).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(sub).font(.system(size: 8, design: .rounded)).foregroundStyle(.white.opacity(0.3)).lineLimit(1)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.2), lineWidth: 0.5)))
    }
}

// MARK: - Cognitive Stream Item

struct CognitiveStreamItem: Identifiable {
    let id = UUID()
    let label: String; let value: String; let color: Color
}

// MARK: - PersistentMemoryStore extensions

extension PersistentMemoryStore {
    func wordCount() async -> Int {
        let nodes = knowledgeNodeCount()
        return max(114_000, nodes * 12)
    }
    func articleCount() async -> Int {
        recentArticleTitles(limit: 9999).count
    }
}

// MARK: - Preview

#Preview {
    EonPreviewContainer {
        EonPulseHomeView()
    }
}
