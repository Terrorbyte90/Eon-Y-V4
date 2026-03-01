import SwiftUI

// MARK: - MindView v2

struct MindView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @State private var selectedTab = 0
    @State private var orbPulse: CGFloat = 1.0
    @State private var ringRot: Double = 0

    private let tabs: [(String, String)] = [
        ("Cykel",    "arrow.triangle.2.circlepath"),
        ("Monolog",  "text.bubble"),
        ("Tankar",   "square.3.layers.3d"),
        ("Framsteg", "chart.line.uptrend.xyaxis"),
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { tl in
            let _ = tl.date
            ZStack(alignment: .top) {
                mindBackground
                VStack(spacing: 0) {
                    mindHeader
                    mindTabBar
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            switch selectedTab {
                            case 0: cycleTab
                            case 1: monologueTab
                            case 2: thoughtGlassTab
                            default: progressTab
                            }
                        }
                        .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
                    }
                    .coordinateSpace(name: "scrollSpace")
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { orbPulse = 1.09 }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { ringRot = 360 }
        }
    }

    // MARK: - Background

    var mindBackground: some View {
        ZStack {
            Color(hex: "#050210").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#7C3AED").opacity(0.12), Color.clear],
                center: .init(x: 0.3, y: 0.0), startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#38BDF8").opacity(0.06), Color.clear],
                center: .init(x: 0.8, y: 0.15), startRadius: 0, endRadius: 350
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    var mindHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            // Orb
            ZStack {
                Circle()
                    .fill(Color(hex: "#7C3AED").opacity(0.18))
                    .frame(width: 44, height: 44)
                    .blur(radius: 8)
                    .scaleEffect(orbPulse)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(
                        AngularGradient(colors: [.clear, Color(hex: "#A78BFA").opacity(0.7), .clear], center: .center),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(ringRot))
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#1A0A35"), Color(hex: "#050210")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(Color(hex: "#7C3AED").opacity(0.5), lineWidth: 0.8))
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.4), radius: 8)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Hjärna")
                    .font(.system(size: 26, weight: .thin, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#E2D9F3"), Color(hex: "#A78BFA")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 8, x: 0, y: 2)
                HStack(spacing: 6) {
                    Circle()
                        .fill(brain.isAutonomouslyActive ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                        .frame(width: 4, height: 4)
                        .scaleEffect(orbPulse)
                    Text(brain.isAutonomouslyActive ? "Autonom · aktiv" : "Standby")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.15))
                    Text("II \(String(format: "%.3f", brain.integratedIntelligence))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                }
            }

            Spacer()

            PhiGaugeMini(phi: brain.phiValue)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 12)
        .background(
            Color(hex: "#050210").opacity(0.9)
                .background(.ultraThinMaterial.opacity(0.2))
                .overlay(
                    LinearGradient(
                        colors: [Color(hex: "#7C3AED").opacity(0.35), Color(hex: "#38BDF8").opacity(0.15), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ).frame(height: 0.5),
                    alignment: .bottom
                )
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Tab Bar

    var mindTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                let (label, icon) = tabs[i]
                let active = selectedTab == i
                Button { withAnimation(.spring(response: 0.28)) { selectedTab = i } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: active ? .semibold : .regular))
                            .foregroundStyle(active ? tabColor(i) : .white.opacity(0.28))
                        Text(label)
                            .font(.system(size: 10, weight: active ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(active ? tabColor(i) : .white.opacity(0.28))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        active
                            ? RoundedRectangle(cornerRadius: 0)
                                .fill(tabColor(i).opacity(0.08))
                            : nil
                    )
                    .overlay(alignment: .bottom) {
                        if active {
                            Rectangle()
                                .fill(tabColor(i))
                                .frame(height: 2)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .animation(.spring(response: 0.3), value: active)
            }
        }
        .background(
            Color(hex: "#050210").opacity(0.85)
                .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5), alignment: .bottom)
        )
    }

    func tabColor(_ i: Int) -> Color {
        [Color(hex: "#A78BFA"), Color(hex: "#F472B6"), Color(hex: "#38BDF8"), Color(hex: "#FBBF24")][i]
    }

    // MARK: - Cycle Tab

    var cycleTab: some View {
        VStack(spacing: 14) {
            CognitiveCycleRingView(steps: brain.thinkingSteps)
            pipelineCard
        }
    }

    var pipelineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                Text("KOGNITIV PIPELINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                let done = brain.thinkingSteps.filter { $0.state == .completed }.count
                let total = brain.thinkingSteps.filter { $0.step != .idle }.count
                Text("\(done)/\(total)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

            // Progress strip
            GeometryReader { g in
                let total = max(1, brain.thinkingSteps.filter { $0.step != .idle }.count)
                let done = brain.thinkingSteps.filter { $0.state == .completed }.count
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.04))
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#7C3AED"), Color(hex: "#38BDF8")],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: g.size.width * CGFloat(done) / CGFloat(total))
                        .animation(.easeInOut(duration: 0.4), value: done)
                }
            }
            .frame(height: 2)

            VStack(spacing: 0) {
                ForEach(brain.thinkingSteps.filter { $0.step != .idle }) { step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step.step.pillarColor.opacity(step.state == .pending ? 0.05 : 0.14))
                                .frame(width: 30, height: 30)
                            if step.state == .active {
                                Circle()
                                    .fill(step.step.pillarColor.opacity(0.25))
                                    .frame(width: 30, height: 30)
                                    .blur(radius: 6)
                                    .scaleEffect(orbPulse)
                            }
                            Image(systemName: step.step.icon)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.15) : step.step.pillarColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.step.label)
                                .font(.system(size: 13, weight: step.state == .active ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.25) : .white.opacity(0.9))
                            if !step.detail.isEmpty && step.state != .pending {
                                Text(step.detail)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(step.step.pillarColor.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Group {
                            if step.state == .active {
                                HStack(spacing: 4) {
                                    Circle().fill(step.step.pillarColor).frame(width: 5, height: 5).scaleEffect(orbPulse)
                                    Text("AKTIV")
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .foregroundStyle(step.step.pillarColor)
                                        .tracking(0.8)
                                }
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(step.step.pillarColor.opacity(0.12)))
                            } else if step.state == .completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                            } else if step.state == .triggered {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#FBBF24").opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(step.state == .active ? step.step.pillarColor.opacity(0.05) : Color.clear)
                    .animation(.easeInOut(duration: 0.25), value: step.state)

                    if step != brain.thinkingSteps.filter({ $0.step != .idle }).last {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5)
                            .padding(.leading, 58)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .background(mCard(Color(hex: "#7C3AED")))
    }

    // MARK: - Monologue Tab

    var monologueTab: some View {
        InnerMonologueView(lines: brain.innerMonologue)
            .frame(minHeight: 500)
    }

    // MARK: - Thought Glass Tab

    var thoughtGlassTab: some View {
        VStack(spacing: 14) {
            ThoughtGlassView(steps: brain.thinkingSteps)
            neuralEngineCard
        }
    }

    var neuralEngineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#38BDF8"))
                Text("NEURAL ENGINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(brain.neuralEngine.isLoaded ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                        .frame(width: 4, height: 4)
                        .scaleEffect(brain.neuralEngine.isLoaded ? 1.0 : orbPulse)
                    Text(brain.neuralEngine.isLoaded ? "REDO" : "LADDAR")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(brain.neuralEngine.isLoaded ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                        .tracking(1)
                }
            }

            HStack(spacing: 10) {
                modelCard("GPT-SW3", "1.3B · ANE", "cpu", Color(hex: "#7C3AED"), brain.neuralEngine.isLoaded)
                modelCard("KB-BERT", "768-dim · INT8", "waveform", Color(hex: "#34D399"), brain.neuralEngine.isLoaded)
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#38BDF8")))
    }

    func modelCard(_ name: String, _ sub: String, _ icon: String, _ color: Color, _ loaded: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(loaded ? 0.15 : 0.05)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color.opacity(loaded ? 1.0 : 0.3))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(loaded ? 0.9 : 0.4))
                Text(sub).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                Text(loaded ? "LADDAD" : "LADDAR").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(loaded ? color : .white.opacity(0.2)).tracking(0.8)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(loaded ? 0.25 : 0.1), lineWidth: 0.6)))
    }

    // MARK: - Progress Tab

    var progressTab: some View {
        VStack(spacing: 14) {
            MindProgressBar()
            phiCard
            engineActivityCard
            cognitiveProfileCard
            memoryCard
            developmentCard
        }
    }

    var phiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(Color(hex: "#A78BFA"))
                    Text("Φ — INTEGRERAD INFORMATION")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.3f", brain.phiValue))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                    Text(brain.phiValue > 0.7 ? "HÖG" : brain.phiValue > 0.5 ? "MEDEL" : "LÅGT")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.5))
                        .tracking(1.5)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#34D399")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * min(brain.phiValue, 1.0), height: 6)
                        .animation(.easeInOut(duration: 1.0), value: brain.phiValue)
                        .shadow(color: Color(hex: "#7C3AED").opacity(0.6), radius: 6)
                }
            }.frame(height: 6)
            HStack(spacing: 0) {
                ForEach(["0.3", "0.5", "0.7", "0.9"], id: \.self) { m in
                    let val = Double(m)!
                    HStack(spacing: 4) {
                        Circle().fill(brain.phiValue >= val ? Color(hex: "#A78BFA") : Color.white.opacity(0.1)).frame(width: 5, height: 5)
                        Text(m).font(.system(size: 9, design: .monospaced)).foregroundStyle(brain.phiValue >= val ? Color(hex: "#A78BFA") : .white.opacity(0.2))
                    }
                    if m != "0.9" { Spacer() }
                }
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#7C3AED")))
    }

    var engineActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 10)).foregroundStyle(Color(hex: "#FB923C"))
                Text("MOTORAKTIVITET")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#34D399")).frame(width: 4, height: 4).scaleEffect(orbPulse)
                    Text("LIVE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(Color(hex: "#34D399")).tracking(1)
                }
            }
            VStack(spacing: 8) {
                ForEach(brain.engineActivity.sorted(by: { $0.value > $1.value }), id: \.key) { key, val in
                    HStack(spacing: 10) {
                        Text(engineName(key))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 72, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.04)).frame(height: 5)
                                Capsule()
                                    .fill(LinearGradient(colors: [engineColor(key), engineColor(key).opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * CGFloat(val), height: 5)
                                    .animation(.easeInOut(duration: 0.5), value: val)
                                    .shadow(color: engineColor(key).opacity(val > 0.4 ? 0.6 : 0), radius: 4)
                            }
                        }.frame(height: 5)
                        Text("\(Int(val * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(engineColor(key))
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#FB923C")))
    }

    var cognitiveProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").font(.system(size: 10)).foregroundStyle(Color(hex: "#34D399"))
                Text("KOGNITIV PROFIL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }
            let dims: [(String, Double, Color)] = [
                ("Resonemang",  min(0.3 + brain.phiValue * 0.6, 0.99),                              Color(hex: "#7C3AED")),
                ("Minne",       min(0.25 + Double(brain.conversationCount) * 0.002, 0.99),           Color(hex: "#38BDF8")),
                ("Kreativitet", min(0.2 + brain.phiValue * 0.5, 0.95),                              Color(hex: "#FBBF24")),
                ("Empati",      min(0.35 + Double(brain.conversationCount) * 0.001, 0.95),           Color(hex: "#34D399")),
                ("Abstraktion", min(0.15 + brain.phiValue * 0.7, 0.99),                             Color(hex: "#A78BFA")),
                ("Språk",       min(0.4 + Double(brain.knowledgeNodeCount) * 0.0005, 0.99),          Color(hex: "#FB923C")),
            ]
            VStack(spacing: 9) {
                ForEach(dims, id: \.0) { name, val, color in
                    HStack(spacing: 10) {
                        Text(name)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 78, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.04)).frame(height: 5)
                                Capsule().fill(color).frame(width: g.size.width * val, height: 5).animation(.easeInOut(duration: 1.2), value: val)
                            }
                        }.frame(height: 5)
                        Text("\(Int(val * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#34D399")))
    }

    var memoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "memorychip").font(.system(size: 10)).foregroundStyle(Color(hex: "#38BDF8"))
                Text("MINNE & KUNSKAP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                mStatCell("\(brain.conversationCount)", "Konversationer", Color(hex: "#38BDF8"))
                mStatCell("\(brain.knowledgeNodeCount)", "Kunskapsnoder", Color(hex: "#FBBF24"))
                mStatCell("\(brain.innerMonologue.count)", "Tankar", Color(hex: "#A78BFA"))
                mStatCell("\(brain.loraVersion)", "LoRA-version", Color(hex: "#34D399"))
                mStatCell(String(format: "%.0f%%", brain.confidence * 100), "Konfidens", Color(hex: "#FB923C"))
                mStatCell(String(format: "%.2f", brain.emotionArousal), "Arousal", Color(hex: "#F472B6"))
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#38BDF8")))
    }

    func mStatCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 8, design: .rounded)).foregroundStyle(.white.opacity(0.3)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.15), lineWidth: 0.5)))
    }

    var developmentCard: some View {
        let stageOrder: [DevelopmentalStage] = [.toddler, .child, .adolescent, .mature]
        let currentIdx = stageOrder.firstIndex(of: brain.developmentalStage) ?? 0

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 10)).foregroundStyle(Color(hex: "#FBBF24"))
                Text("UTVECKLINGSRESA")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                Text(brain.developmentalStage.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(brain.developmentalStage.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(brain.developmentalStage.color.opacity(0.12)))
            }
            VStack(spacing: 0) {
                ForEach(stageOrder.indices, id: \.self) { i in
                    let stage = stageOrder[i]
                    let isPast = i < currentIdx
                    let isCurrent = i == currentIdx
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? stage.color.opacity(0.18) : isPast ? stage.color.opacity(0.08) : Color.white.opacity(0.03))
                                .frame(width: 30, height: 30)
                            Text(stage.icon).font(.system(size: 14))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(stage.displayName) — \(stage.description)")
                                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(isCurrent ? .white : isPast ? .white.opacity(0.45) : .white.opacity(0.2))
                                .fixedSize(horizontal: false, vertical: true)
                            if isCurrent {
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.05)).frame(height: 3)
                                        Capsule()
                                            .fill(stage.color)
                                            .frame(width: g.size.width * brain.developmentalProgress, height: 3)
                                            .animation(.easeInOut(duration: 0.8), value: brain.developmentalProgress)
                                    }
                                }.frame(height: 3)
                            }
                        }
                        Spacer()
                        if isCurrent {
                            Text("\(Int(brain.developmentalProgress * 100))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(stage.color)
                        } else if isPast {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(stage.color.opacity(0.5))
                        }
                    }
                    .padding(.vertical, 6)
                    if i < stageOrder.count - 1 {
                        Rectangle()
                            .fill(i < currentIdx ? Color.white.opacity(0.1) : Color.white.opacity(0.03))
                            .frame(width: 1, height: 10)
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .padding(16)
        .background(mCard(Color(hex: "#FBBF24")))
    }

    // MARK: - Helpers

    func engineName(_ key: String) -> String {
        switch key {
        case "cognitive": return "Kognition"
        case "language":  return "Språk"
        case "memory":    return "Minne"
        case "learning":  return "Inlärning"
        case "autonomy":  return "Autonomi"
        case "hypothesis":return "Hypotes"
        case "worldModel":return "Världsbild"
        default:          return key
        }
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

    func mCard(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.025))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(0.35), color.opacity(0.07)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
    }
}

// MARK: - Cognitive Cycle Ring

struct CognitiveCycleRingView: View {
    let steps: [ThinkingStepStatus]
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0

    let pillars: [(label: String, color: Color, icon: String)] = [
        ("Morfologi",  Color(hex: "#EF4444"), "textformat.abc"),
        ("WSD",        Color(hex: "#A78BFA"), "arrow.triangle.branch"),
        ("Minne",      Color(hex: "#38BDF8"), "memorychip"),
        ("Kausal",     Color(hex: "#FB923C"), "arrow.triangle.turn.up.right.diamond"),
        ("GWT",        Color(hex: "#FBBF24"), "globe"),
        ("CoT",        Color(hex: "#10B981"), "list.bullet.indent"),
        ("GPT",        Color(hex: "#7C3AED"), "cpu"),
        ("Validering", Color(hex: "#F472B6"), "checkmark.shield"),
        ("Graf",       Color(hex: "#34D399"), "point.3.connected.trianglepath.dotted"),
        ("Meta",       Color(hex: "#8B5CF6"), "brain.head.profile"),
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color(hex: "#7C3AED").opacity(0.1), lineWidth: 0.6))

            // Outer ring
            Circle().strokeBorder(Color.white.opacity(0.04), lineWidth: 1).frame(width: 230, height: 230)
            Circle().strokeBorder(Color.white.opacity(0.025), lineWidth: 0.5).frame(width: 160, height: 160)

            // Spinning arc
            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(colors: [.clear, Color(hex: "#7C3AED").opacity(0.7), .clear], center: .center),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 230, height: 230)
                .rotationEffect(.degrees(rotation))

            // Pillar nodes
            ForEach(pillars.indices, id: \.self) { i in
                let angle = Double(i) / Double(pillars.count) * 360 - 90
                let r: CGFloat = 115
                PillarNode(
                    label: pillars[i].label,
                    color: pillars[i].color,
                    icon: pillars[i].icon,
                    state: stepStateFor(index: i)
                )
                .offset(x: cos(angle * .pi / 180) * r, y: sin(angle * .pi / 180) * r)
            }

            // Center
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#7C3AED").opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulse)
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "#1A0A35"), Color(hex: "#050210")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color(hex: "#7C3AED").opacity(0.4), lineWidth: 0.8))
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 12)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }
        }
        .frame(height: 320)
        .onAppear {
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { rotation = 360 }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = 1.1 }
        }
    }

    private func stepStateFor(index: Int) -> StepState {
        let stepCases = ThinkingStep.allCases.filter { $0 != .idle }
        guard index < stepCases.count else { return .pending }
        return steps.first { $0.step == stepCases[index] }?.state ?? .pending
    }
}

struct PillarNode: View {
    let label: String; let color: Color; let icon: String; let state: StepState
    @State private var glowing = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if state == .active {
                    Circle().fill(color.opacity(0.3)).frame(width: 44, height: 44).blur(radius: 10)
                }
                Circle()
                    .fill(color.opacity(state == .active ? 0.2 : state == .completed ? 0.12 : 0.05))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(color.opacity(state == .active ? 0.8 : state == .completed ? 0.4 : 0.15), lineWidth: 0.8))
                    .shadow(color: color.opacity(glowing ? 0.8 : 0), radius: 8)
                Image(systemName: state == .completed ? "checkmark" : icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state == .pending ? .white.opacity(0.15) : color)
            }
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .rounded))
                .foregroundStyle(state == .pending ? .white.opacity(0.15) : color)
                .lineLimit(1)
        }
        .onChange(of: state) { _, newState in
            if newState == .active {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { glowing = true }
            } else {
                withAnimation(.easeOut(duration: 0.3)) { glowing = false }
            }
        }
    }
}

// MARK: - Inner Monologue

struct InnerMonologueView: View {
    let lines: [MonologueLine]
    @State private var filter: MonologueLine.MonologueType? = nil

    var filtered: [MonologueLine] {
        guard let f = filter else { return Array(lines.suffix(60)) }
        return lines.filter { $0.type == f }.suffix(60).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#A78BFA"))
                Text("INNER MONOLOGUE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                Text("\(lines.count) tankar")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(nil, "Alla", Color(hex: "#A78BFA"))
                    filterChip(.thought, "Tanke", MonologueLine.MonologueType.thought.color)
                    filterChip(.insight, "Insikt", MonologueLine.MonologueType.insight.color)
                    filterChip(.memory, "Minne", MonologueLine.MonologueType.memory.color)
                    filterChip(.loopTrigger, "Loop", MonologueLine.MonologueType.loopTrigger.color)
                    filterChip(.revision, "Revision", MonologueLine.MonologueType.revision.color)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5).padding(.horizontal, 16)

            // Lines
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { line in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(line.type.color.opacity(0.15)).frame(width: 24, height: 24)
                                    Image(systemName: line.type.icon).font(.system(size: 9)).foregroundStyle(line.type.color)
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(typeLabel(line.type))
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .foregroundStyle(line.type.color.opacity(0.6))
                                        .tracking(1)
                                    Text(line.text)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .id(line.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))

                            Rectangle().fill(Color.white.opacity(0.03)).frame(height: 0.5).padding(.horizontal, 16)
                        }
                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "brain.head.profile").font(.system(size: 24)).foregroundStyle(Color(hex: "#A78BFA").opacity(0.2))
                                Text("Inga tankar ännu...").font(.system(size: 12, design: .rounded).italic()).foregroundStyle(.white.opacity(0.2))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                        }
                        Color.clear.frame(height: 1).id("mono-end")
                    }
                }
                .frame(minHeight: 300)
                .onChange(of: lines.count) { _, _ in
                    withAnimation { proxy.scrollTo("mono-end") }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                    LinearGradient(colors: [Color(hex: "#A78BFA").opacity(0.3), Color(hex: "#7C3AED").opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.7
                ))
        )
    }

    func filterChip(_ type: MonologueLine.MonologueType?, _ label: String, _ color: Color) -> some View {
        let active = filter == type
        return Button { withAnimation(.spring(response: 0.25)) { filter = type } } label: {
            Text(label)
                .font(.system(size: 10, weight: active ? .semibold : .regular, design: .rounded))
                .foregroundStyle(active ? color : .white.opacity(0.3))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(active ? color.opacity(0.12) : Color.white.opacity(0.04))
                        .overlay(Capsule().strokeBorder(active ? color.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.6))
                )
        }
    }

    func typeLabel(_ t: MonologueLine.MonologueType) -> String {
        switch t {
        case .thought: return "TANKE"
        case .insight: return "INSIKT"
        case .memory: return "MINNE"
        case .loopTrigger: return "LOOP"
        case .revision: return "REVISION"
        }
    }
}

// MARK: - Thought Glass

struct ThoughtGlassView: View {
    let steps: [ThinkingStepStatus]
    @State private var selectedTab = 0
    @State private var selectedStep: ThinkingStepStatus? = nil
    @State private var correctionText = ""
    @State private var correctionSent = false
    @FocusState private var correctionFocused: Bool

    private let tabs = ["Flöde", "Detalj", "Korrigera"]

    var displaySteps: [ThinkingStepStatus] { steps.filter { $0.step != .idle } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#F472B6"))
                Text("THOUGHT GLASS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                if let active = displaySteps.first(where: { $0.state == .active }) {
                    HStack(spacing: 4) {
                        Circle().fill(active.step.pillarColor).frame(width: 4, height: 4)
                        Text(active.step.label)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(active.step.pillarColor.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button { withAnimation(.spring(response: 0.25)) { selectedTab = i } } label: {
                        Text(tabs[i])
                            .font(.system(size: 12, weight: selectedTab == i ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selectedTab == i ? Color(hex: "#F472B6") : .white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTab == i ? Color(hex: "#F472B6").opacity(0.1) : Color.clear)
                    }
                }
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.bottom, 12)

            // Content
            Group {
                switch selectedTab {
                case 0: flowTab
                case 1: detailTab
                default: correctTab
                }
            }
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                    LinearGradient(colors: [Color(hex: "#F472B6").opacity(0.3), Color(hex: "#F472B6").opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.7
                ))
        )
    }

    // MARK: Flöde

    var flowTab: some View {
        VStack(spacing: 0) {
            if displaySteps.isEmpty {
                emptyState
            } else {
                ForEach(displaySteps) { step in
                    HStack(spacing: 12) {
                        ZStack {
                            if step.state == .active {
                                Circle().fill(step.step.pillarColor.opacity(0.2)).frame(width: 28, height: 28).blur(radius: 5)
                            }
                            Circle()
                                .fill(step.step.pillarColor.opacity(step.state == .pending ? 0.05 : 0.14))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(step.step.pillarColor.opacity(step.state == .pending ? 0.1 : 0.4), lineWidth: 0.7))
                            Image(systemName: step.state == .completed ? "checkmark" : step.step.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.15) : step.step.pillarColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.step.label)
                                .font(.system(size: 12, weight: step.state == .active ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.3) : .white.opacity(0.9))
                            if !step.detail.isEmpty && step.state != .pending {
                                Text(step.detail)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(step.step.pillarColor.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if step.confidence > 0 && step.state != .pending {
                            Text("\(Int(step.confidence * 100))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                        Circle()
                            .fill(step.state.color)
                            .frame(width: 6, height: 6)
                            .shadow(color: step.state == .active ? step.state.color.opacity(0.9) : .clear, radius: 4)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(step.state == .active ? step.step.pillarColor.opacity(0.06) : Color.clear)
                    .animation(.easeInOut(duration: 0.25), value: step.state)

                    if step != displaySteps.last {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5).padding(.leading, 56)
                    }
                }
            }
        }
    }

    // MARK: Detalj

    var detailTab: some View {
        VStack(spacing: 0) {
            if displaySteps.isEmpty {
                emptyState
            } else {
                ForEach(displaySteps) { step in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStep = selectedStep?.id == step.id ? nil : step
                        }
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(step.step.pillarColor.opacity(step.state == .pending ? 0.05 : 0.15))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: step.state == .completed ? "checkmark" : step.step.icon)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(step.state == .pending ? .white.opacity(0.15) : step.step.pillarColor)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.step.label)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(step.state == .pending ? .white.opacity(0.3) : .white.opacity(0.9))
                                    Text(step.state.label)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(step.state.color.opacity(0.7))
                                }

                                Spacer()

                                Image(systemName: selectedStep?.id == step.id ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)

                            if selectedStep?.id == step.id {
                                VStack(alignment: .leading, spacing: 10) {
                                    Rectangle().fill(step.step.pillarColor.opacity(0.15)).frame(height: 0.5)

                                    if step.confidence > 0 {
                                        HStack {
                                            Text("Konfidens")
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.4))
                                            Spacer()
                                            Text("\(Int(step.confidence * 100))%")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(step.step.pillarColor)
                                        }
                                    }

                                    if !step.detail.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("DETALJ")
                                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.25))
                                                .tracking(1)
                                            Text(step.detail)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("PELARE")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.25))
                                            .tracking(1)
                                        Text(step.step.pillarDescription)
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.bottom, 12)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .background(selectedStep?.id == step.id ? step.step.pillarColor.opacity(0.05) : Color.clear)
                    }

                    if step != displaySteps.last {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
                    }
                }
            }
        }
    }

    // MARK: Korrigera

    var correctTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Info
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#F472B6").opacity(0.7))
                Text("Skicka en korrigering till Eons kognitiva cykel. Den sparas som ett minne och påverkar framtida resonemang.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#F472B6").opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#F472B6").opacity(0.2), lineWidth: 0.6))
            )

            // Välj steg
            Text("VÄLJ STEG ATT KORRIGERA")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(displaySteps) { step in
                        let sel = selectedStep?.id == step.id
                        Button {
                            withAnimation(.spring(response: 0.25)) { selectedStep = sel ? nil : step }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: step.step.icon).font(.system(size: 10)).foregroundStyle(step.step.pillarColor)
                                Text(step.step.label).font(.system(size: 11, weight: sel ? .semibold : .regular, design: .rounded))
                                    .foregroundStyle(sel ? step.step.pillarColor : .white.opacity(0.4))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(sel ? step.step.pillarColor.opacity(0.15) : Color.white.opacity(0.04))
                                    .overlay(Capsule().strokeBorder(sel ? step.step.pillarColor.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 0.6))
                            )
                        }
                    }
                }
            }

            // Textfält
            VStack(alignment: .leading, spacing: 8) {
                Text("KORRIGERING")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
                    .tracking(1)

                ZStack(alignment: .topLeading) {
                    if correctionText.isEmpty {
                        Text("Beskriv vad som var fel eller vad Eon borde ha gjort annorlunda...")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.2))
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $correctionText)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .padding(10)
                        .focused($correctionFocused)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(correctionFocused ? 0.06 : 0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    correctionFocused
                                        ? Color(hex: "#F472B6").opacity(0.5)
                                        : Color.white.opacity(0.07),
                                    lineWidth: 0.8
                                )
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: correctionFocused)
            }

            // Skicka-knapp
            Button {
                guard !correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let stepLabel = selectedStep?.step.label ?? "Allmänt"
                let fullCorrection = "[\(stepLabel)] \(correctionText)"
                PersistentMemoryStore.shared.saveMessage(
                    role: "correction",
                    content: fullCorrection,
                    sessionId: "corrections"
                )
                withAnimation(.spring(response: 0.3)) { correctionSent = true }
                correctionText = ""
                selectedStep = nil
                correctionFocused = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { correctionSent = false }
                }
            } label: {
                HStack(spacing: 8) {
                    if correctionSent {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 14))
                        Text("Korrigering sparad")
                    } else {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 14))
                        Text("Skicka korrigering")
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(correctionSent ? Color(hex: "#34D399") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(correctionSent ? Color(hex: "#34D399").opacity(0.15) : Color(hex: "#F472B6").opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(correctionSent ? Color(hex: "#34D399").opacity(0.4) : Color(hex: "#F472B6").opacity(0.4), lineWidth: 0.7)
                        )
                )
            }
            .disabled(correctionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || correctionSent)
        }
        .padding(.horizontal, 16)
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "#F472B6").opacity(0.25))
            Text("Kognitiva steg initieras...")
                .font(.system(size: 12, design: .rounded).italic())
                .foregroundStyle(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

// MARK: - Phi Gauge Mini

struct PhiGaugeMini: View {
    let phi: Double
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: min(phi, 1.0) * 0.75)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "#34D399"), Color(hex: "#7C3AED")], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 1.0), value: phi)
                Text("Φ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }
            Text(String(format: "%.2f", phi))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Mind Progress Bar

struct MindProgressBar: View {
    @EnvironmentObject var brain: EonBrain

    // Detaljerad 14-nivå skala — synkroniserad med DevelopmentalStage-trösklarna
    private let levels: [(emoji: String, name: String, threshold: Double)] = [
        ("🪨", "Sten",            0.00),
        ("🦠", "Mikroorganism",   0.05),
        ("🐛", "Insekt",          0.12),
        ("🐟", "Fisk",            0.20),
        ("🐦", "Fågel",           0.28),
        ("🐕", "Hund",            0.36),
        // DevelopmentalStage.toddler (Spädbarn): II < 0.44
        ("👶", "Spädbarn",        0.44),
        // DevelopmentalStage.child (Barn): 0.44–0.60
        ("🧒", "Barn",            0.52),
        // DevelopmentalStage.adolescent (Tonåring): 0.60–0.76
        ("🧑", "Skolbarn",        0.60),
        ("🧑‍🎓", "Tonåring",      0.68),
        // DevelopmentalStage.mature (Vuxen): 0.76+
        ("🧑‍💼", "Vuxen",         0.76),
        ("🎓", "Expert",          0.84),
        ("🧑‍🔬", "Professor",     0.90),
        ("🌟", "Superintelligens",0.96),
    ]

    private var currentLevel: (emoji: String, name: String, threshold: Double) {
        levels.last(where: { brain.integratedIntelligence >= $0.threshold }) ?? levels[0]
    }
    private var nextLevel: (emoji: String, name: String, threshold: Double) {
        levels.first(where: { brain.integratedIntelligence < $0.threshold }) ?? levels.last!
    }
    private var levelProgress: Double {
        let cur = currentLevel.threshold; let nxt = nextLevel.threshold; let range = nxt - cur
        guard range > 0 else { return 1.0 }
        return min(1.0, (brain.integratedIntelligence - cur) / range)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Rubrik
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile").font(.system(size: 10)).foregroundStyle(Color(hex: "#A78BFA"))
                Text("KOGNITIV SAMMANFATTNING")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }

            // Primär nivå — stämmer med DevelopmentalStage
            HStack(spacing: 14) {
                Text(brain.developmentalStage.icon)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(brain.developmentalStage.displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("II \(String(format: "%.3f", brain.integratedIntelligence))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(brain.developmentalStage.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(brain.developmentalStage.color.opacity(0.12)))
                    }
                    Text(brain.developmentalStage.description)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)
                }
            }

            // Progress mot nästa DevelopmentalStage
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.05)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [brain.developmentalStage.color.opacity(0.7), brain.developmentalStage.color],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(brain.developmentalProgress), height: 6)
                        .animation(.easeInOut(duration: 0.8), value: brain.developmentalProgress)
                        .shadow(color: brain.developmentalStage.color.opacity(0.5), radius: 5)
                }
            }.frame(height: 6)

            // Nästa stadium + detaljnivå
            HStack {
                let nextStage = nextDevelopmentalStage(brain.developmentalStage)
                Text("→ \(nextStage.icon) \(nextStage.displayName)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                Spacer()
                Text("\(Int(brain.developmentalProgress * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(brain.developmentalStage.color)
            }

            // Separator
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5)

            // Detaljnivå (14-stegs)
            HStack(spacing: 10) {
                Text(currentLevel.emoji).font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detaljnivå: \(currentLevel.name)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    HStack(spacing: 4) {
                        Text("→ \(nextLevel.emoji) \(nextLevel.name)")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                        Spacer()
                        Text("\(Int(levelProgress * 100))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            if brain.intelligenceGrowthVelocity > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right").font(.system(size: 8))
                    Text(String(format: "+%.5f/min", brain.intelligenceGrowthVelocity))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "#34D399"))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                    LinearGradient(
                        colors: [brain.developmentalStage.color.opacity(0.4), brain.developmentalStage.color.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                ))
        )
    }

    private func nextDevelopmentalStage(_ s: DevelopmentalStage) -> DevelopmentalStage {
        switch s {
        case .toddler: return .child
        case .child: return .adolescent
        case .adolescent: return .mature
        case .mature: return .mature
        }
    }
}

extension StepState {
    var label: String {
        switch self {
        case .pending: return "Väntar"
        case .active: return "Aktiv"
        case .completed: return "Klar"
        case .triggered: return "Loop"
        case .failed: return "Fel"
        }
    }
}

// Pillar description for detail view
extension ThinkingStep {
    var pillarDescription: String {
        switch self {
        case .morphology:    return "Analyserar morfologi, lemmatisering och ordformer i inmatningen via SwedishLanguageCore."
        case .wsd:           return "Word Sense Disambiguation — disambiguerar flertydiga ord baserat på kontext."
        case .memoryRetrieval: return "Söker i SQLite-minnet efter relevanta konversationer och hämtar senaste historiken."
        case .causalGraph:   return "Beräknar KB-BERT 768-dim embedding och extraherar namngivna entiteter."
        case .globalWorkspace: return "Global Workspace Theory — bygger den fullständiga prompten med all kognitiv kontext."
        case .chainOfThought: return "Chain-of-Thought reasoning — loggar tankekedjan i inner monologue."
        case .generation:    return "GPT-SW3 1.3B genererar svar via CoreML/Apple Foundation Models/NL-fallback."
        case .validation:    return "Loop 1 — BERT cosine similarity validerar koherens. WSD-mismatch triggar regenerering."
        case .enrichment:    return "Loop 2 — Extraherade entiteter och fakta sparas tillbaka till kunskapsgrafen."
        case .metacognition: return "Loop 3 — Om konfidens < 60% revideras svaret av MetacognitiveReviser."
        case .idle:          return "Systemet är i viloläge."
        }
    }
}

#Preview {
    EonPreviewContainer { MindView() }
}
