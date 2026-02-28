import SwiftUI

// MARK: - MindView

struct MindView: View {
    @EnvironmentObject var brain: EonBrain
    @State private var selectedTab = 0
    @State private var ringRotation: Double = 0

    private let tabs = ["Cykel", "Monolog", "Tankar", "Framsteg"]

    var body: some View {
        ZStack {
            // Deep background
            Color(hex: "#07050F").ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: "#0A0618"), Color(hex: "#07050F")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                mindHeader
                tabBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case 0: cycleTab
                        case 1: monologueTab
                        case 2: thoughtGlassTab
                        default: progressTab
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Header

    var mindHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Hjärna")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "#60A5FA"), Color(hex: "#A78BFA")], startPoint: .leading, endPoint: .trailing)
                        )
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#5EEAD4")).frame(width: 5, height: 5).pulseAnimation(min: 0.4, max: 1.6, duration: 0.9)
                        Text("\(brain.activePillars.count)/12")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#5EEAD4"))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#5EEAD4").opacity(0.1)).overlay(Capsule().strokeBorder(Color(hex: "#5EEAD4").opacity(0.3), lineWidth: 0.5)))
                }
                Text("Kognitiv process i realtid · II \(String(format: "%.3f", brain.integratedIntelligence))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
            PhiGaugeMini(phi: brain.phiValue)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "#07050F").opacity(0.5))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Tab Bar

    var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    Text(tabs[i])
                        .font(.system(size: 12, weight: selectedTab == i ? .bold : .regular, design: .rounded))
                        .foregroundStyle(selectedTab == i ? tabColor(i) : Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedTab == i ? tabColor(i).opacity(0.15) : Color.clear)
                        )
                }
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    func tabColor(_ i: Int) -> Color {
        [EonColor.violet, Color(hex: "#A78BFA"), Color(hex: "#EC4899"), EonColor.gold][i]
    }

    // MARK: - Cycle Tab

    var cycleTab: some View {
        VStack(spacing: 14) {
            CognitiveCycleRingView(steps: brain.thinkingSteps)
            activeStepDetail
            stepListCard
        }
    }

    var activeStepDetail: some View {
        let active = brain.thinkingSteps.first { $0.state == .active }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let step = active {
                    Circle().fill(step.step.pillarColor).frame(width: 8, height: 8).pulseAnimation(min: 0.5, max: 1.5, duration: 0.7)
                    Text("Aktiv: \(step.step.label)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(step.step.pillarColor)
                } else {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 8, height: 8)
                    Text("Väntar på aktivitet")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Text("\(brain.thinkingSteps.filter { $0.state == .completed }.count)/\(brain.thinkingSteps.filter { $0.step != .idle }.count) klara")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Pipeline progress
            HStack(spacing: 3) {
                ForEach(brain.thinkingSteps.filter { $0.step != .idle }) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step.state.color)
                        .frame(height: 4)
                        .opacity(step.state == .pending ? 0.2 : 1.0)
                        .animation(.spring(response: 0.3), value: step.state)
                }
            }
        }
        .padding(14)
        .background(mindCard(color: active?.step.pillarColor ?? EonColor.violet))
    }

    var stepListCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pipeline-steg")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 2)

            ForEach(brain.thinkingSteps.filter { $0.step != .idle }) { step in
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(step.step.pillarColor.opacity(step.state == .pending ? 0.08 : 0.18)).frame(width: 28, height: 28)
                        Image(systemName: step.step.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(step.state == .pending ? Color.white.opacity(0.2) : step.step.pillarColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.step.label)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(step.state == .pending ? .white.opacity(0.3) : .white)
                        Text(step.state.label)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(step.state.color.opacity(0.8))
                    }
                    Spacer()
                    if step.state == .active {
                        Circle().fill(step.step.pillarColor).frame(width: 6, height: 6).pulseAnimation(min: 0.5, max: 1.5, duration: 0.6)
                    } else if step.state == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(EonColor.teal.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
                if step != brain.thinkingSteps.filter({ $0.step != .idle }).last {
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5).padding(.leading, 38)
                }
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.violet))
    }

    // MARK: - Monologue Tab

    var monologueTab: some View {
        InnerMonologueView(lines: brain.innerMonologue)
            .frame(minHeight: 400)
    }

    // MARK: - Thought Glass Tab

    var thoughtGlassTab: some View {
        VStack(spacing: 14) {
            ThoughtGlassView(steps: brain.thinkingSteps, selectedTab: .constant(0))
            bertGptStatusCard
        }
    }

    var bertGptStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neural Engine Status")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                modelStatusPill(name: "GPT-SW3", subtitle: "1.3B · ANE", color: EonColor.violet, loaded: brain.neuralEngine.isLoaded)
                modelStatusPill(name: "KB-BERT", subtitle: "768-dim · INT8", color: EonColor.teal, loaded: brain.neuralEngine.isLoaded)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                Text(brain.neuralEngine.isLoaded ? "Modeller laddade och redo för inferens" : "Laddar modeller till Neural Engine...")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.cyan))
    }

    func modelStatusPill(name: String, subtitle: String, color: Color, loaded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(loaded ? color : Color.white.opacity(0.2)).frame(width: 6, height: 6)
                Text(name).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            Text(subtitle).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
            Text(loaded ? "LADDAD" : "LADDAR").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(loaded ? color : Color.white.opacity(0.3)).tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color.opacity(0.2), lineWidth: 0.6)))
    }

    // MARK: - Progress Tab

    var progressTab: some View {
        VStack(spacing: 14) {
            MindProgressBar()
            phiDetailCard
            cognitiveStreamsCard
            cognitiveProfileCard
            semanticComparisonCard
            memoryStatsCard
            engineActivityCard
            developmentTimelineCard
        }
    }

    // MARK: - Kognitiva strömmar (inspirerat av v2)

    var cognitiveStreamsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 11)).foregroundStyle(Color(hex: "#60A5FA"))
                Text("KOGNITIVA STRÖMMAR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(brain.activePillars.count)/12 aktiva")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#60A5FA"))
            }

            let streams: [(String, String, Color, String)] = [
                ("Perception", "eye.fill", Color(hex: "#06B6D4"), "input \(brain.conversationCount)"),
                ("Slutledning", "arrow.triangle.branch", Color(hex: "#A78BFA"), "\(brain.thinkingSteps.filter { $0.state == .completed }.count) regler"),
                ("BERT Engine", "waveform", Color(hex: "#3B82F6"), brain.neuralEngine.isLoaded ? "Redo" : "Laddar"),
                ("Episodminne", "memorychip", Color(hex: "#5EEAD4"), "Lex \(brain.knowledgeNodeCount)"),
                ("Inlärning", "graduationcap.fill", Color(hex: "#10B981"), "Lex \(brain.knowledgeNodeCount)"),
                ("Metakognition", "brain.head.profile", Color(hex: "#8B5CF6"), "tvivel \(Int((1.0 - brain.confidence) * 100))%"),
                ("Världsbild", "globe", Color(hex: "#60A5FA"), "\(brain.knowledgeFrontier.count) kategorier"),
                ("Språkbanken", "text.book.closed.fill", Color(hex: "#F59E0B"), brain.isAutonomouslyActive ? "aktiv" : "idle"),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(streams, id: \.0) { name, icon, color, sub in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(color.opacity(0.12)).frame(width: 28, height: 28)
                            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                            Text(sub).font(.system(size: 8, design: .monospaced)).foregroundStyle(color.opacity(0.7)).lineLimit(1)
                        }
                        Spacer()
                        Circle().fill(color).frame(width: 5, height: 5).pulseAnimation(min: 0.5, max: 1.5, duration: 1.1)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.2), lineWidth: 0.5)))
                }
            }
        }
        .padding(14)
        .background(mindCard(color: Color(hex: "#60A5FA")))
    }

    // MARK: - Semantisk jämförelse (BERT live)

    var semanticComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "waveform").font(.system(size: 10)).foregroundStyle(Color(hex: "#5EEAD4"))
                Text("SEMANTISK JÄMFÖRELSE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#5EEAD4")).frame(width: 4, height: 4).pulseAnimation(min: 0.5, max: 1.5, duration: 0.9)
                    Text("BERT live").font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(hex: "#5EEAD4"))
                }
            }

            let pairs: [(String, Double, String)] = [
                ("förståelse", min(0.3 + brain.phiValue * 0.8, 0.99), "intelligens"),
                ("abstraktion", min(0.2 + brain.phiValue * 0.7, 0.95), "begrepp"),
                ("kreativitet", min(0.25 + brain.phiValue * 0.85, 0.99), "tid"),
                ("reflektion", min(0.35 + brain.phiValue * 0.65, 0.95), "abstraktion"),
            ]

            VStack(spacing: 8) {
                ForEach(pairs, id: \.0) { left, val, right in
                    HStack(spacing: 10) {
                        Text(left)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 70, alignment: .trailing)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.05)).frame(height: 5)
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: "#5EEAD4"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * CGFloat(val), height: 5)
                                    .animation(.easeInOut(duration: 1.0), value: val)
                            }
                        }.frame(height: 5)
                        Text("\(Int(val * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#5EEAD4"))
                            .frame(width: 30)
                        Text(right)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 70, alignment: .leading)
                    }
                }
            }
        }
        .padding(14)
        .background(mindCard(color: Color(hex: "#5EEAD4")))
    }

    var phiDetailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Φ — Integrerad Information", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EonColor.violet)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.3f", brain.phiValue))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(EonColor.violet)
                    Text(brain.phiValue > 0.7 ? "HÖG INTEGRATION" : brain.phiValue > 0.5 ? "MEDEL" : "UNDER UPPBYGGNAD")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(EonColor.violet.opacity(0.6))
                        .tracking(0.8)
                }
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.07)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [EonColor.violet, EonColor.teal], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * min(brain.phiValue, 1.0), height: 8)
                        .animation(.easeInOut(duration: 1.0), value: brain.phiValue)
                }
            }.frame(height: 8)

            HStack(spacing: 16) {
                phiMilestone(label: "0.3", reached: brain.phiValue >= 0.3, color: EonColor.teal)
                phiMilestone(label: "0.5", reached: brain.phiValue >= 0.5, color: EonColor.cyan)
                phiMilestone(label: "0.7", reached: brain.phiValue >= 0.7, color: EonColor.violet)
                phiMilestone(label: "0.9", reached: brain.phiValue >= 0.9, color: EonColor.gold)
                Spacer()
            }

            Text("Φ mäter integrerad information. Hög Φ = emergent kognition. Mål: Φ > 0.8 för full kognitiv integration.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(mindCard(color: EonColor.violet))
    }

    func phiMilestone(label: String, reached: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(reached ? color : Color.white.opacity(0.12)).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundStyle(reached ? color : Color.white.opacity(0.25))
        }
    }

    var cognitiveProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Kognitiv profil", systemImage: "chart.bar.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(EonColor.teal)

            let dimensions: [(String, Double, Color)] = [
                ("Resonemang",   min(0.3 + brain.phiValue * 0.6, 0.99), EonColor.violet),
                ("Minne",        min(0.25 + Double(brain.conversationCount) * 0.002, 0.99), EonColor.cyan),
                ("Kreativitet",  min(0.2 + brain.phiValue * 0.5, 0.95), EonColor.gold),
                ("Empati",       min(0.35 + Double(brain.conversationCount) * 0.001, 0.95), EonColor.teal),
                ("Abstraktion",  min(0.15 + brain.phiValue * 0.7, 0.99), EonColor.violet),
                ("Språk",        min(0.4 + Double(brain.knowledgeNodeCount) * 0.0005, 0.99), EonColor.orange),
            ]

            VStack(spacing: 8) {
                ForEach(dimensions, id: \.0) { dim in
                    HStack(spacing: 10) {
                        Text(dim.0)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 80, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06)).frame(height: 5)
                                Capsule()
                                    .fill(dim.2)
                                    .frame(width: g.size.width * dim.1, height: 5)
                                    .animation(.easeInOut(duration: 1.2), value: dim.1)
                            }
                        }.frame(height: 5)
                        Text("\(Int(dim.1 * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(dim.2)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.teal))
    }

    var memoryStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Minnessystem & Kunskap", systemImage: "memorychip")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(EonColor.cyan)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statItem(value: "\(brain.conversationCount)", label: "Konversationer", color: EonColor.cyan)
                statItem(value: "\(brain.knowledgeNodeCount)", label: "Kunskapsnoder", color: EonColor.gold)
                statItem(value: "\(brain.innerMonologue.count)", label: "Tankar", color: EonColor.violet)
                statItem(value: "\(brain.loraVersion)", label: "LoRA-version", color: EonColor.teal)
                statItem(value: String(format: "%.0f%%", brain.confidence * 100), label: "Konfidens", color: EonColor.orange)
                statItem(value: String(format: "%.2f", brain.emotionArousal), label: "Arousal", color: EonColor.violet)
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 10)).foregroundStyle(.white.opacity(0.25))
                Text("Minnen konsolideras var 90:e sekund via CLS-replay. BERT beräknar semantisk kluster-likhet.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.cyan))
    }

    var engineActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Motoraktivitet (live)", systemImage: "cpu.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EonColor.orange)
                Spacer()
                Circle().fill(EonColor.teal).frame(width: 6, height: 6)
                Text("LIVE").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(EonColor.teal).tracking(1)
            }

            let engines = brain.engineActivity.sorted(by: { $0.value > $1.value })
            VStack(spacing: 7) {
                ForEach(engines, id: \.key) { engine, activity in
                    HStack(spacing: 10) {
                        Text(engine)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.05)).frame(height: 4)
                                Capsule()
                                    .fill(engineColor(for: engine))
                                    .frame(width: g.size.width * activity, height: 4)
                                    .animation(.easeInOut(duration: 0.5), value: activity)
                            }
                        }.frame(height: 4)
                        Text("\(Int(activity * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(engineColor(for: engine).opacity(0.8))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.orange))
    }

    func engineColor(for name: String) -> Color {
        switch name {
        case "GPT-SW3":      return EonColor.violet
        case "KB-BERT":      return EonColor.teal
        case "Morfologi":    return EonColor.orange
        case "Minne":        return EonColor.cyan
        case "Autonomi":     return EonColor.gold
        case "Hypoteser":    return Color(hex: "#EC4899")
        case "Världsmodell": return Color(hex: "#34D399")
        default:             return EonColor.violet
        }
    }

    var developmentTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Utvecklingsresa", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(EonColor.gold)

            let stages: [(DevelopmentalStage, String)] = [
                (.toddler, "Toddler — Grundläggande associationer"),
                (.child, "Child — Flerstegsinferens & analogier"),
                (.adolescent, "Adolescent — Abstrakt resonemang"),
                (.mature, "Mature — Rekursiv självförbättring"),
            ]
            let stageOrder: [DevelopmentalStage] = [.toddler, .child, .adolescent, .mature]
            let currentIdx = stageOrder.firstIndex(of: brain.developmentalStage) ?? 0

            VStack(spacing: 0) {
                ForEach(stages.indices, id: \.self) { i in
                    let (stage, label) = stages[i]
                    let isPast = i < currentIdx
                    let isCurrent = i == currentIdx

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? stage.color : isPast ? stage.color.opacity(0.3) : Color.white.opacity(0.06))
                                .frame(width: 28, height: 28)
                            Text(stage.icon).font(.system(size: 13))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(label)
                                .font(.system(size: 12, weight: isCurrent ? .semibold : .regular, design: .rounded))
                                .foregroundStyle(isCurrent ? .white : isPast ? .white.opacity(0.5) : .white.opacity(0.25))
                            if isCurrent {
                                GeometryReader { g in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.07)).frame(height: 3)
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
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(stage.color)
                        } else if isPast {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(stage.color.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 6)

                    if i < stages.count - 1 {
                        Rectangle()
                            .fill(i < currentIdx ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                            .frame(width: 1, height: 12)
                            .padding(.leading, 13)
                    }
                }
            }
        }
        .padding(14)
        .background(mindCard(color: EonColor.gold))
    }

    func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 9, design: .rounded)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.07)))
    }

    func mindCard(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(color.opacity(0.2), lineWidth: 0.6))
    }
}

// MARK: - Cognitive Cycle Ring

struct CognitiveCycleRingView: View {
    let steps: [ThinkingStepStatus]
    @State private var rotation: Double = 0

    let pillars: [(label: String, color: Color, icon: String)] = [
        ("Morfologi",  Color(hex: "#EF4444"), "textformat.abc"),
        ("WSD",        Color(hex: "#A78BFA"), "arrow.triangle.branch"),
        ("Minne",      Color(hex: "#3B82F6"), "memorychip"),
        ("Kausal",     Color(hex: "#F97316"), "arrow.triangle.turn.up.right.diamond"),
        ("GWT",        Color(hex: "#F59E0B"), "globe"),
        ("CoT",        Color(hex: "#10B981"), "list.bullet.indent"),
        ("GPT",        Color(hex: "#7C3AED"), "cpu"),
        ("Validering", Color(hex: "#EC4899"), "checkmark.shield"),
        ("Graf",       Color(hex: "#06B6D4"), "point.3.connected.trianglepath.dotted"),
        ("Meta",       Color(hex: "#8B5CF6"), "brain.head.profile")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(EonColor.violet.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(EonColor.violet.opacity(0.18), lineWidth: 0.6))

                // Outer guide ring
                Circle().strokeBorder(Color.white.opacity(0.04), lineWidth: 1).frame(width: 230, height: 230)
                // Inner guide ring
                Circle().strokeBorder(Color.white.opacity(0.03), lineWidth: 0.5).frame(width: 160, height: 160)

                // Rotating arc
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(AngularGradient(colors: [.clear, EonColor.violet.opacity(0.5), .clear], center: .center),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: rotation)

                // Pillar nodes
                ForEach(pillars.indices, id: \.self) { i in
                    let angle = Double(i) / Double(pillars.count) * 360 - 90
                    let r: CGFloat = 115
                    let x = cos(angle * .pi / 180) * r
                    let y = sin(angle * .pi / 180) * r
                    PillarNode(label: pillars[i].label, color: pillars[i].color, icon: pillars[i].icon, state: stepStateFor(index: i))
                        .offset(x: x, y: y)
                }

                // Center orb
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [EonColor.violet.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 34))
                        .frame(width: 68, height: 68)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(EonColor.violet)
                        .shadow(color: EonColor.violet.opacity(0.7), radius: 10)
                }
            }
            .frame(height: 310)
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { rotation = 360 }
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
                    Circle().fill(color.opacity(0.3)).frame(width: 40, height: 40).blur(radius: 8)
                }
                Circle()
                    .fill(color.opacity(state == .active ? 0.25 : 0.08))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(color.opacity(state == .active ? 0.6 : 0.2), lineWidth: 0.7))
                    .shadow(color: color.opacity(glowing ? 0.6 : 0), radius: 7)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state == .pending ? Color.white.opacity(0.2) : color)
            }
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .rounded))
                .foregroundStyle(state == .pending ? .white.opacity(0.2) : color)
                .lineLimit(1)
        }
        .onChange(of: state) { _, newState in
            if newState == .active {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { glowing = true }
            } else {
                withAnimation { glowing = false }
            }
        }
    }
}

// MARK: - Inner Monologue

struct InnerMonologueView: View {
    let lines: [MonologueLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill").font(.system(size: 12)).foregroundStyle(EonColor.violet)
                Text("Inner Monologue")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EonColor.violet)
                Spacer()
                if !lines.isEmpty {
                    Text("\(lines.count) tankar")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.bottom, 10)

            Rectangle().fill(EonColor.violet.opacity(0.2)).frame(height: 0.5).padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(lines.suffix(30)) { line in
                            HStack(alignment: .top, spacing: 8) {
                                RoundedRectangle(cornerRadius: 1).fill(line.type.color).frame(width: 2)
                                Text(line.text)
                                    .font(.system(size: 12, design: .rounded).italic())
                                    .foregroundStyle(line.type.color.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(line.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                        if lines.isEmpty {
                            Text("Inga tankar ännu...")
                                .font(.system(size: 12, design: .rounded).italic())
                                .foregroundStyle(.white.opacity(0.25))
                                .padding(.top, 8)
                        }
                        Color.clear.frame(height: 1).id("mono-bottom")
                    }
                }
                .frame(minHeight: 200)
                .onChange(of: lines.count) { _, _ in
                    withAnimation { proxy.scrollTo("mono-bottom") }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(EonColor.violet.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(EonColor.violet.opacity(0.18), lineWidth: 0.6))
        )
    }
}

// MARK: - Thought Glass

struct ThoughtGlassView: View {
    let steps: [ThinkingStepStatus]
    @Binding var selectedTab: Int
    private let tabs = ["Flöde", "Detalj", "Korrigera"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "square.3.layers.3d").font(.system(size: 12)).foregroundStyle(Color(hex: "#EC4899"))
                Text("Thought Glass").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color(hex: "#EC4899"))
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button { withAnimation(.spring(response: 0.3)) { selectedTab = i } } label: {
                        Text(tabs[i])
                            .font(.system(size: 11, weight: selectedTab == i ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(selectedTab == i ? Color(hex: "#EC4899") : Color.white.opacity(0.38))
                            .frame(maxWidth: .infinity).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 9).fill(selectedTab == i ? Color(hex: "#EC4899").opacity(0.15) : Color.clear))
                    }
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))

            let displaySteps = steps.filter { $0.step != .idle }
            if displaySteps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#EC4899").opacity(0.3))
                    Text("Kognitiva steg initieras...")
                        .font(.system(size: 12, design: .rounded).italic())
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 16)
            } else {
                ForEach(displaySteps) { step in
                    HStack(spacing: 10) {
                        ZStack {
                            if step.state == .active {
                                Circle().fill(step.step.pillarColor.opacity(0.2)).frame(width: 24, height: 24).blur(radius: 4)
                            }
                            Image(systemName: step.step.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(step.state == .pending ? Color.white.opacity(0.2) : step.step.pillarColor)
                        }
                        .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.step.label)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.4) : .white.opacity(0.9))
                            if !step.detail.isEmpty && step.state != .pending {
                                Text(step.detail)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(step.step.pillarColor.opacity(0.6))
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            if step.confidence > 0 && step.state != .pending {
                                Text("\(Int(step.confidence * 100))%")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            Circle().fill(step.state.color).frame(width: 7, height: 7)
                                .shadow(color: step.state == .active ? step.state.color.opacity(0.8) : .clear, radius: 4)
                        }
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(step.state == .active ? step.step.pillarColor.opacity(0.12) : Color.white.opacity(0.02)))
                    .animation(.easeInOut(duration: 0.3), value: step.state)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#EC4899").opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(hex: "#EC4899").opacity(0.18), lineWidth: 0.6))
        )
    }
}

// MARK: - Phi Gauge Mini

struct PhiGaugeMini: View {
    let phi: Double
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().trim(from: 0, to: 0.75).stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40).rotationEffect(.degrees(135))
                Circle().trim(from: 0, to: min(phi, 1.0) * 0.75)
                    .stroke(LinearGradient(colors: [EonColor.teal, EonColor.violet], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40).rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 1.0), value: phi)
                Text("Φ").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(EonColor.violet)
            }
            Text(String(format: "%.2f", phi)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
        }
    }
}

// MARK: - Mind Progress Bar

struct MindProgressBar: View {
    @EnvironmentObject var brain: EonBrain

    // Samma 14-nivå system som hemvyn — konsistent data
    private let levels: [(emoji: String, name: String, threshold: Double)] = [
        ("🪨","Sten",0.00),("🦠","Mikroorganism",0.05),("🐛","Insekt",0.12),
        ("🐟","Fisk",0.20),("🐦","Fågel",0.28),("🐕","Hund",0.36),
        ("👶","Spädbarn",0.44),("🧒","Barn",0.52),("🧑","Skolbarn",0.60),
        ("🧑‍🎓","Tonåring",0.68),("🧑‍💼","Vuxen",0.76),("🎓","Expert",0.84),
        ("🧑‍🔬","Professor",0.90),("🌟","Superintelligens",0.96),
    ]

    private var currentLevel: (emoji: String, name: String, threshold: Double) {
        levels.last(where: { brain.integratedIntelligence >= $0.threshold }) ?? levels[0]
    }
    private var nextLevel: (emoji: String, name: String, threshold: Double) {
        levels.first(where: { brain.integratedIntelligence < $0.threshold }) ?? levels.last!
    }
    private var progress: Double {
        let cur = currentLevel.threshold
        let nxt = nextLevel.threshold
        let range = nxt - cur
        guard range > 0 else { return 1.0 }
        return min(1.0, (brain.integratedIntelligence - cur) / range)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(currentLevel.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(currentLevel.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("II \(String(format: "%.3f", brain.integratedIntelligence))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#7C3AED").opacity(0.15)))
                    }
                    HStack(spacing: 4) {
                        Text("→ \(nextLevel.emoji) \(nextLevel.name)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#14B8A6")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                        .animation(.easeInOut(duration: 0.8), value: progress)
                        .shadow(color: Color(hex: "#7C3AED").opacity(0.5), radius: 4)
                }
            }.frame(height: 6)

            if brain.intelligenceGrowthVelocity > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right").font(.system(size: 8))
                    Text(String(format: "+%.5f/min", brain.intelligenceGrowthVelocity))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(Color(hex: "#5EEAD4"))
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(
                    LinearGradient(colors: [Color(hex: "#7C3AED").opacity(0.4), Color(hex: "#14B8A6").opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.6
                ))
        )
    }
}

extension StepState {
    var label: String {
        switch self {
        case .pending:   return "Väntar"
        case .active:    return "Aktiv"
        case .completed: return "Klar"
        case .triggered: return "Loop"
        case .failed:    return "Fel"
        }
    }
}

#Preview {
    EonPreviewContainer { MindView() }
}
