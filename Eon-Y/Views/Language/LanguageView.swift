import SwiftUI
import Combine

// MARK: - LanguageView — Eons språkutvecklingscenter (v16 — med Hjärna-flik)

struct LanguageView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @ObservedObject private var learning = LearningEngine.observableProxy
    @ObservedObject private var autonomy = EonLiveAutonomy.shared
    @ObservedObject private var oscillators = OscillatorBank.shared
    @ObservedObject private var critCtrl = CriticalityController.shared
    @ObservedObject private var activeInf = ActiveInferenceEngine.shared

    @State private var selectedTab = 0
    @State private var competencies: [DomainCompetency] = []
    @State private var orbPulse: CGFloat = 1.0
    @State private var ringRot: Double = 0

    private let tabs: [(String, String)] = [
        ("Översikt",     "chart.bar.fill"),
        ("Kompetenser",  "books.vertical.fill"),
        ("Utveckling",   "chart.line.uptrend.xyaxis"),
        ("Aktivitet",    "waveform.path.ecg"),
        ("Hjärna",       "brain.head.profile"),
    ]

    private let accentColor = Color(hex: "#14B8A6")
    private let mindAccent = Color(hex: "#60A5FA")

    var body: some View {
        ZStack(alignment: .top) {
            langBackground
            VStack(spacing: 0) {
                langHeader
                langTabBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case 0: overviewTab
                        case 1: competencyTab
                        case 2: developmentTab
                        case 3: activityTab
                        default: mindTab
                        }
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                orbPulse = 1.06
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                ringRot = 360
            }
            loadCompetencies()
            learning.refresh()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            // v2: Reduced from 15s to 30s to lower CPU impact while view is visible
            learning.refresh()
            loadCompetencies()
        }
    }

    private func loadCompetencies() {
        Task {
            let snapshot = await LearningEngine.shared.competencySnapshot()
            await MainActor.run { competencies = snapshot }
        }
    }

    // MARK: - Background

    private var langBackground: some View {
        ZStack {
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [accentColor.opacity(0.25), Color.clear],
                center: .init(x: 0.2, y: 0.05),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#0E7490").opacity(0.15), Color.clear],
                center: .init(x: 0.8, y: 0.5),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var langHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [accentColor.opacity(0.5), Color(hex: "#0E7490").opacity(0.3), Color.clear],
                            center: .center, startRadius: 0, endRadius: 24
                        ))
                        .frame(width: 48, height: 48)
                        .scaleEffect(orbPulse)
                    Image(systemName: "textformat.abc")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Språkutveckling")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(languageStatusLabel)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }

            // Live metrics strip
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(brain.languagePhaseActive ? Color(hex: "#34D399") : accentColor)
                        .frame(width: 4, height: 4)
                        .shadow(color: brain.languagePhaseActive ? Color(hex: "#34D399").opacity(0.8) : .clear, radius: 2)
                    Text(brain.languagePhaseActive ? "Språkfas aktiv" : "Bakgrundsläge")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(brain.languagePhaseActive ? Color(hex: "#34D399").opacity(0.8) : accentColor.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 10) {
                    Text("Nivå \(String(format: "%.0f%%", brain.overallLanguageLevel * 100))")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.5))
                    Text("\(brain.vocabularySize) ord")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.5))
                    Text("\(brain.idiomKnowledge) idiom")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.5))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accentColor.opacity(0.04)))
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private var languageStatusLabel: String {
        if brain.languagePhaseActive { return "Analyserar svenska mönster och böjningar..." }
        let level = brain.overallLanguageLevel
        if level > 0.6 { return "Avancerad språkförståelse — förfinar nyanser" }
        if level > 0.3 { return "Bygger ordförråd och grammatisk kunskap" }
        return "Grundläggande språkinlärning pågår"
    }

    // MARK: - Tab Bar

    private var langTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[i].1)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tabs[i].0)
                            .font(.system(size: 10, weight: selectedTab == i ? .semibold : .regular, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == i ? accentColor : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == i ? accentColor.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 14) {
            // Hero stats row
            HStack(spacing: 8) {
                langStatBox(label: "Språknivå", value: String(format: "%.0f%%", brain.overallLanguageLevel * 100), color: accentColor)
                langStatBox(label: "Ordförråd", value: "\(brain.vocabularySize)", color: Color(hex: "#38BDF8"))
                langStatBox(label: "Idiom", value: "\(brain.idiomKnowledge)", color: Color(hex: "#FBBF24"))
                langStatBox(label: "Samtal", value: "\(brain.conversationCount)", color: Color(hex: "#EC4899"))
            }

            // Vocabulary growth sparkline
            GlassCard(tint: Color(hex: "#38BDF8")) {
                VStack(alignment: .leading, spacing: 8) {
                    PanelHeader(icon: "chart.line.uptrend.xyaxis", title: "Ordförrådstillväxt", color: Color(hex: "#38BDF8")) {
                        Text("\(learning.wordsLearnedToday) ord idag")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                    }

                    SparklineView(
                        values: vocabularySparklineData,
                        color: Color(hex: "#38BDF8"),
                        height: 36
                    )

                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("+\(learning.wordsLearnedToday)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#34D399"))
                            Text("Idag")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        VStack(spacing: 2) {
                            Text("\(learning.vocabularyCount)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            Text("Totalt")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", learning.velocity))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#A78BFA"))
                            Text("Ord/samtal")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Linguistic domains overview
            GlassCard(tint: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    // v24: Replaced EmptyView with domain count indicator
                    PanelHeader(icon: "text.book.closed.fill", title: "Språkliga domäner", color: accentColor) {
                        Text("4 domäner")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.6))
                    }

                    langDomainBar(label: "Morfologi", value: brain.morphologyMastery, desc: morphologyLabel(brain.morphologyMastery), color: Color(hex: "#14B8A6"))
                    langDomainBar(label: "Syntax", value: brain.syntaxMastery, desc: morphologyLabel(brain.syntaxMastery), color: Color(hex: "#38BDF8"))
                    langDomainBar(label: "Semantik", value: brain.semanticMastery, desc: morphologyLabel(brain.semanticMastery), color: Color(hex: "#A78BFA"))
                    langDomainBar(label: "Pragmatik", value: brain.pragmaticMastery, desc: morphologyLabel(brain.pragmaticMastery), color: Color(hex: "#EC4899"))
                }
            }

            // Language capabilities card
            GlassCard(tint: Color(hex: "#0E7490")) {
                VStack(alignment: .leading, spacing: 12) {
                    // v24: Replaced EmptyView with active capability count
                    PanelHeader(icon: "wand.and.stars", title: "Språkförmågor", color: Color(hex: "#0E7490")) {
                        Text("\(brain.gptLoaded && brain.bertLoaded ? "9" : "7") aktiva")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#0E7490").opacity(0.6))
                    }

                    capabilityRow(name: "Ordböjning (substantiv, verb, adjektiv)", active: brain.morphologyMastery > 0.1, level: brain.morphologyMastery)
                    capabilityRow(name: "Sammansatta ord", active: brain.morphologyMastery > 0.15, level: brain.morphologyMastery)
                    capabilityRow(name: "Idiom & uttryck", active: brain.idiomKnowledge > 10, level: Double(brain.idiomKnowledge) / 100.0)
                    capabilityRow(name: "Meningsstruktur (V2, bisats)", active: brain.syntaxMastery > 0.1, level: brain.syntaxMastery)
                    capabilityRow(name: "Textregisterdetektion", active: brain.pragmaticMastery > 0.1, level: brain.pragmaticMastery)
                    capabilityRow(name: "Anafora/pronomenupplösning", active: brain.semanticMastery > 0.1, level: brain.semanticMastery)
                    capabilityRow(name: "Ordbetydelsedisambiguering (WSD)", active: brain.semanticMastery > 0.15, level: brain.semanticMastery)
                    capabilityRow(name: "Qwen3 textgenerering", active: brain.gptLoaded, level: brain.gptLoaded ? 0.7 : 0.0)
                    capabilityRow(name: "Qwen3 semantisk embedding", active: brain.bertLoaded, level: brain.bertLoaded ? 0.8 : 0.0)
                }
            }

            // v18: Live learning insights — real-time updates from the learning engine
            GlassCard(tint: Color(hex: "#34D399")) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: "lightbulb.fill", title: "Aktiv inlärning", color: Color(hex: "#34D399")) {
                        if brain.languagePhaseActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: "#34D399"))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: Color(hex: "#34D399").opacity(0.8), radius: 3)
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#34D399"))
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "#34D399").opacity(0.15)))
                        } else {
                            EmptyView()
                        }
                    }

                    // Recent learned words
                    if !brain.recentLearnedWords.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Senast inlärda ord")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))

                            LanguageFlowLayout(spacing: 6) {
                                ForEach(brain.recentLearnedWords.suffix(12), id: \.self) { word in
                                    Text(word)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(accentColor)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(accentColor.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .strokeBorder(accentColor.opacity(0.15), lineWidth: 0.5)
                                                )
                                        )
                                }
                            }
                        }
                    }

                    // Learning velocity
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(brain.languageGrowthRate > 0 ? "+" + String(format: "%.1f%%", brain.languageGrowthRate) : "—")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(brain.languageGrowthRate > 0 ? Color(hex: "#34D399") : .white.opacity(0.3))
                            Text("Tillväxt/cykel")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        VStack(spacing: 2) {
                            Text("\(brain.vocabularySize)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            Text("Unika ord")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        VStack(spacing: 2) {
                            Text("\(brain.conversationCount)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#EC4899"))
                            Text("Samtal")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    // Current focus from language log
                    if let lastLog = brain.languageLog.last {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                            Text(lastLog)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(2)
                        }
                    }
                }
            }

            // v19: Grammar pattern insights
            if !learning.grammarPatterns.isEmpty || learning.compoundWordCount > 0 {
                GlassCard(tint: Color(hex: "#F472B6")) {
                    VStack(alignment: .leading, spacing: 10) {
                        PanelHeader(icon: "textformat.abc.dottedunderline", title: "Grammatikmönster", color: Color(hex: "#F472B6")) {
                            if learning.compoundWordCount > 0 {
                                Text("\(learning.compoundWordCount) sammansättningar")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#F472B6").opacity(0.7))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color(hex: "#F472B6").opacity(0.1)))
                            } else {
                                EmptyView()
                            }
                        }

                        ForEach(Array(learning.grammarPatterns.prefix(5).enumerated()), id: \.offset) { _, pattern in
                            HStack(spacing: 8) {
                                Text(formatPatternName(pattern.pattern))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(pattern.count)x")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#F472B6").opacity(0.6))
                            }
                        }
                    }
                }
            }

            // Neural language models status
            GlassCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: "cpu.fill", title: "Neurala språkmodeller", color: Color(hex: "#A78BFA")) {
                        Text(brain.gptLoaded && brain.bertLoaded ? "Alla laddade" : "Laddar...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                    }

                    HStack(spacing: 12) {
                        modelStatusBox(name: "Qwen3", detail: "1.7B params", loaded: brain.gptLoaded, color: Color(hex: "#34D399"))
                        modelStatusBox(name: "Qwen3 Embed", detail: "768-dim", loaded: brain.bertLoaded, color: Color(hex: "#38BDF8"))
                    }

                    HStack(spacing: 12) {
                        modelStatusBox(name: "Morfologi", detail: "Böjningsmotor", loaded: true, color: accentColor)
                        modelStatusBox(name: "WSD", detail: "Disambiguering", loaded: true, color: Color(hex: "#FBBF24"))
                    }
                }
            }

            // Qwen3 learning activity
            GlassCard(tint: Color(hex: "#7C3AED")) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: "waveform.path.ecg", title: "Qwen3 inlärningsaktivitet", color: Color(hex: "#7C3AED")) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(brain.gptLoaded ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                                .frame(width: 4, height: 4)
                            Text(brain.gptLoaded ? "Aktiv" : "Offline")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(brain.gptLoaded ? Color(hex: "#34D399").opacity(0.7) : Color(hex: "#EF4444").opacity(0.7))
                        }
                    }

                    let qwenThoughts = brain.innerMonologue
                        .filter { $0.text.lowercased().contains("qwen") || $0.text.lowercased().contains("embedding") || $0.text.lowercased().contains("generering") }
                        .suffix(5)

                    if qwenThoughts.isEmpty {
                        Text("Qwen3 bearbetar i bakgrunden. Aktivitet visas här när modellen körs.")
                            .font(.system(size: 11, design: .rounded).italic())
                            .foregroundStyle(.white.opacity(0.3))
                    } else {
                        ForEach(Array(qwenThoughts.reversed()), id: \.id) { line in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(Color(hex: "#7C3AED").opacity(0.5))
                                    .frame(width: 3, height: 3)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.text)
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(2)
                                    Text(line.timestamp.formatted(.dateTime.hour().minute().second()))
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = line.text
                                } label: {
                                    Label("Kopiera", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", ThermalSleepManager.shared.qwenThrottleFactor * 100))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#7C3AED"))
                            Text("Throttle")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        VStack(spacing: 2) {
                            Text(brain.thermalState)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(thermalStatusColor)
                            Text("Termisk")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var thermalStatusColor: Color {
        switch brain.thermalState.lowercased() {
        case "nominal": return Color(hex: "#34D399")
        case "fair":    return Color(hex: "#F59E0B")
        case "serious": return Color(hex: "#F97316")
        case "critical": return Color(hex: "#EF4444")
        default: return Color(hex: "#34D399")
        }
    }

    // MARK: - Competency Tab

    private var competencyTab: some View {
        VStack(spacing: 14) {
            GlassCard(tint: accentColor) {
                VStack(alignment: .leading, spacing: 14) {
                    PanelHeader(icon: "graduationcap.fill", title: "Alla kompetensdomäner", color: accentColor) {
                        Text(String(format: "Snitt: %.0f%%", brain.overallLanguageLevel * 100))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(accentColor.opacity(0.15)))
                    }

                    ForEach(competencies, id: \.domain) { comp in
                        HStack(spacing: 10) {
                            Text(comp.domain)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 100, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.06))
                                    Capsule()
                                        .fill(LinearGradient(colors: [accentColor.opacity(0.5), accentColor], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(2, geo.size.width * comp.level))
                                        .animation(.easeInOut(duration: 0.8), value: comp.level)
                                }
                            }
                            .frame(height: 6)
                            Text(comp.levelLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(accentColor.opacity(0.6))
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }

            // Strengths & Weaknesses
            HStack(spacing: 10) {
                GlassCard(tint: Color(hex: "#34D399")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "#34D399"))
                            Text("Styrkor").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                        }
                        ForEach(competencies.sorted(by: { $0.level > $1.level }).prefix(3), id: \.domain) { c in
                            HStack {
                                Text(c.domain).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(String(format: "%.0f%%", c.level * 100)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "#34D399"))
                            }
                        }
                    }
                }

                GlassCard(tint: Color(hex: "#F97316")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "#F97316"))
                            Text("Att förbättra").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                        }
                        ForEach(competencies.sorted(by: { $0.level < $1.level }).prefix(3), id: \.domain) { c in
                            HStack {
                                Text(c.domain).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(String(format: "%.0f%%", c.level * 100)).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "#F97316"))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Development Tab

    private var developmentTab: some View {
        VStack(spacing: 14) {
            // Phase indicator
            GlassCard(tint: Color(hex: autonomy.currentPhase.color)) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: autonomy.currentPhase.icon, title: "Kognitiv fas", color: Color(hex: autonomy.currentPhase.color)) {
                        Text(autonomy.currentPhase.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: autonomy.currentPhase.color))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: autonomy.currentPhase.color).opacity(0.15)))
                    }

                    Text("Faserna roterar: Intensiv → Inlärning → Språk → Vila. Varje fas fokuserar på specifika kognitiva uppgifter.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    HStack(spacing: 4) {
                        ForEach(EonLiveAutonomy.CognitivePhase.phaseOrder, id: \.rawValue) { phase in
                            HStack(spacing: 3) {
                                Image(systemName: phase.icon)
                                    .font(.system(size: 9))
                                Text(String(phase.rawValue.prefix(5)))
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                            }
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(autonomy.currentPhase == phase ? Color(hex: phase.color).opacity(0.2) : Color.white.opacity(0.04))
                            )
                            .foregroundStyle(autonomy.currentPhase == phase ? Color(hex: phase.color) : .white.opacity(0.35))
                        }
                    }
                }
            }

            // v16: Language growth metrics
            GlassCard(tint: accentColor) {
                VStack(alignment: .leading, spacing: 10) {
                    // v24: Replaced EmptyView with growth trend indicator
                    PanelHeader(icon: "chart.line.uptrend.xyaxis", title: "Tillväxtmått", color: accentColor) {
                        Text(brain.languageGrowthRate > 0 ? "Växer" : "Stabil")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(brain.languageGrowthRate > 0 ? Color(hex: "#34D399").opacity(0.7) : accentColor.opacity(0.5))
                    }

                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f%%", brain.languageGrowthRate))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(brain.languageGrowthRate > 0 ? Color(hex: "#34D399") : .white.opacity(0.4))
                            Text("Tillväxttakt")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", brain.sentenceComplexity * 100))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#A78BFA"))
                            Text("Meningskomplexitet")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text("\(brain.vocabularySize)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                            Text("Ordförråd")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Learning cycle info
            GlassCard(tint: Color(hex: "#3B82F6")) {
                VStack(alignment: .leading, spacing: 10) {
                    // v24: Replaced EmptyView with cycle info
                    PanelHeader(icon: "arrow.triangle.2.circlepath", title: "Inlärningscykler", color: Color(hex: "#3B82F6")) {
                        Text("FSRS")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(hex: "#3B82F6").opacity(0.6))
                    }

                    let facts = [
                        ("FSRS repetition", "Adaptiv repetitionsalgoritm som optimerar inlärning"),
                        ("Domäninteraktion", "Inlärning i en domän accelererar relaterade domäner"),
                        ("Kunskapsluckor", "Systemet identifierar och fyller automatiskt luckor"),
                        ("Metatänkande", "Varje konversation ger feedback till inlärningsprocessen"),
                        ("Morfologiträning", "Analyserar och lagrar ordformer från konversationer"),
                    ]
                    ForEach(facts, id: \.0) { title, desc in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Color(hex: "#3B82F6").opacity(0.6)).frame(width: 5, height: 5).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                                Text(desc).font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }
            }

            // Developmental stage
            GlassCard(tint: brain.developmentalStage.color) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: "leaf.fill", title: "Utvecklingsstadium", color: brain.developmentalStage.color) {
                        Text(brain.developmentalStage.displayName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(brain.developmentalStage.color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(brain.developmentalStage.color.opacity(0.15)))
                    }

                    Text(brain.developmentalStage.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    // Progress bar to next stage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Framsteg mot nästa stadium")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            Text(String(format: "%.0f%%", brain.developmentalProgress * 100))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(brain.developmentalStage.color.opacity(0.7))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(LinearGradient(colors: [brain.developmentalStage.color.opacity(0.5), brain.developmentalStage.color], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(2, geo.size.width * brain.developmentalProgress))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
    }

    // MARK: - Activity Tab (Language Log)

    private var activityTab: some View {
        VStack(spacing: 14) {
            GlassCard(tint: accentColor) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader(icon: "waveform.path.ecg", title: "Språkaktivitetslogg", color: accentColor) {
                        HStack(spacing: 6) {
                            Text("\(brain.languageLog.count) poster")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(accentColor.opacity(0.6))
                            if !brain.languageLog.isEmpty {
                                Button {
                                    UIPasteboard.general.string = brain.languageLog.suffix(20).joined(separator: "\n")
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundStyle(accentColor.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if brain.languageLog.isEmpty {
                        Text("Ingen språkaktivitet loggad ännu. Loggen fylls på allt eftersom Eon bearbetar svenska mönster, böjningar och ny kunskap.")
                            .font(.system(size: 12, design: .rounded).italic())
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.vertical, 8)
                    } else {
                        ForEach(brain.languageLog.suffix(20).reversed(), id: \.self) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(accentColor.opacity(0.5))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 5)
                                Text(entry)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(3)
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = entry
                                } label: {
                                    Label("Kopiera", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                }
            }

            // Live monologue entries related to language
            GlassCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 10) {
                    // v24: Replaced EmptyView with thought count
                    PanelHeader(icon: "brain.head.profile", title: "Senaste språktankar", color: Color(hex: "#A78BFA")) {
                        let langCount = brain.innerMonologue
                            .filter { $0.text.lowercased().contains("språk") || $0.text.lowercased().contains("ord") }
                            .count
                        Text("\(langCount)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                    }

                    let langThoughts = brain.innerMonologue
                        .filter { $0.text.lowercased().contains("språk") || $0.text.lowercased().contains("morfologi") || $0.text.lowercased().contains("syntax") || $0.text.lowercased().contains("ordförråd") || $0.text.lowercased().contains("böjning") }
                        .suffix(8)

                    if langThoughts.isEmpty {
                        Text("Inga språkrelaterade tankar ännu. Eon genererar språktankar under den kognitiva cykeln.")
                            .font(.system(size: 12, design: .rounded).italic())
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(langThoughts.reversed())) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: line.type.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(line.type.color)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.text)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.65))
                                        .lineLimit(2)
                                    Text(line.timestamp.formatted(.dateTime.hour().minute().second()))
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.2))
                                }
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = line.text
                                } label: {
                                    Label("Kopiera", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mind Tab (merged from MindView)

    private var mindTab: some View {
        VStack(spacing: 14) {
            mindStatusCard
            CognitiveCycleRingView(steps: brain.thinkingSteps)
            mindPipelineCard
            mindNeuralSyncCard
            InnerMonologueView(lines: brain.innerMonologue)
                .frame(minHeight: 400)
            ThoughtGlassView(steps: brain.thinkingSteps)
            mindNeuralEngineCard
        }
    }

    private var mindStatusCard: some View {
        GlassCard(tint: mindAccent) {
            VStack(alignment: .leading, spacing: 10) {
                PanelHeader(icon: "brain.head.profile", title: "Kognitiv status", color: mindAccent) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(brain.isAutonomouslyActive ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                            .frame(width: 5, height: 5)
                            .shadow(color: brain.isAutonomouslyActive ? Color(hex: "#34D399").opacity(0.8) : .clear, radius: 2)
                        Text(brain.isAutonomouslyActive ? "Autonom" : "Standby")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(brain.isAutonomouslyActive ? Color(hex: "#34D399") : mindAccent.opacity(0.6))
                    }
                }

                Text(mindStatusLabel)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 0) {
                    mindMetric("II", String(format: "%.3f", brain.integratedIntelligence), mindAccent)
                    mindMetric("Sync", String(format: "%.0f%%", oscillators.globalSync * 100), Color(hex: "#38BDF8"))
                    mindMetric("σ", String(format: "%.2f", critCtrl.branchingRatio), Color(hex: "#FBBF24"))
                    mindMetric("FE", String(format: "%.2f", activeInf.freeEnergy), Color(hex: "#06B6D4"))
                }
            }
        }
    }

    private var mindStatusLabel: String {
        if brain.isThinking { return "Bearbetar kognitiv cykel..." }
        if critCtrl.regime == .critical { return "Kritiskt läge — maximal integration" }
        if oscillators.globalSync > 0.5 { return "Hög synkronisering — koherent tänkande" }
        if activeInf.freeEnergy > 0.5 { return "Explorativt läge — söker ny kunskap" }
        return "Autonom kognition aktiv"
    }

    private func mindMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private var mindPipelineCard: some View {
        GlassCard(tint: Color(hex: "#A78BFA")) {
            VStack(alignment: .leading, spacing: 10) {
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

                GeometryReader { g in
                    let total = max(1, brain.thinkingSteps.filter { $0.step != .idle }.count)
                    let done = brain.thinkingSteps.filter { $0.state == .completed }.count
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.04)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#7C3AED"), Color(hex: "#38BDF8")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: g.size.width * CGFloat(done) / CGFloat(total), height: 4)
                            .animation(.easeInOut(duration: 0.4), value: done)
                    }
                }
                .frame(height: 4)

                ForEach(brain.thinkingSteps.filter { $0.step != .idle }) { step in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(step.step.pillarColor.opacity(step.state == .pending ? 0.05 : 0.14))
                                .frame(width: 26, height: 26)
                            if step.state == .active {
                                Circle()
                                    .fill(step.step.pillarColor.opacity(0.25))
                                    .frame(width: 26, height: 26)
                                    .blur(radius: 5)
                                    .scaleEffect(orbPulse)
                            }
                            Image(systemName: step.step.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(step.state == .pending ? .white.opacity(0.15) : step.step.pillarColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.step.label)
                                .font(.system(size: 12, weight: step.state == .active ? .semibold : .regular, design: .rounded))
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
                                    Circle().fill(step.step.pillarColor).frame(width: 4, height: 4).scaleEffect(orbPulse)
                                    Text("AKTIV")
                                        .font(.system(size: 7, weight: .black, design: .monospaced))
                                        .foregroundStyle(step.step.pillarColor)
                                        .tracking(0.8)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(step.step.pillarColor.opacity(0.12)))
                            } else if step.state == .completed {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                            } else if step.state == .triggered {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#FBBF24").opacity(0.7))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.25), value: step.state)
                }
            }
        }
    }

    private var mindNeuralSyncCard: some View {
        GlassCard(tint: Color(hex: "#38BDF8")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                    Text("NEURAL SYNKRONISERING")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1)
                    Spacer()
                    let regimeColor = critCtrl.regime == .critical ? Color(hex: "#34D399") :
                                      critCtrl.regime == .subcritical ? Color(hex: "#FBBF24") : Color(hex: "#EF4444")
                    Text(critCtrl.regime == .critical ? "KRITISK" :
                         critCtrl.regime == .subcritical ? "SUBKRITISK" : "SUPERKRITISK")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(regimeColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(regimeColor.opacity(0.15)))
                }

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", oscillators.globalSync * 100))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                        Text("Global Sync")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", oscillators.thetaGammaCFC))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                        Text("θ-γ CFC")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text(String(format: "%.3f", critCtrl.branchingRatio))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(critCtrl.regime == .critical ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                        Text("σ Branching")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", activeInf.freeEnergy))
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#06B6D4"))
                        Text("Fri Energi")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                }

                let bands = ["δ", "θ", "α", "β", "γ"]
                let bandColors: [Color] = [
                    Color(hex: "#6366F1"), Color(hex: "#8B5CF6"),
                    Color(hex: "#A78BFA"), Color(hex: "#38BDF8"), Color(hex: "#34D399")
                ]
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        let val = i < oscillators.orderParameters.count ? oscillators.orderParameters[i] : 0
                        HStack(spacing: 3) {
                            Text(bands[i])
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(bandColors[i].opacity(0.6))
                                .frame(width: 10)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.05))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(bandColors[i].opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(val))
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
    }

    private var mindNeuralEngineCard: some View {
        GlassCard(tint: Color(hex: "#38BDF8")) {
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
                    mindModelCard("Qwen3", "1.7B · GGUF", "cpu", Color(hex: "#7C3AED"), brain.neuralEngine.isLoaded)
                    mindModelCard("llama.cpp", "Inference", "waveform", Color(hex: "#34D399"), brain.neuralEngine.isLoaded)
                }
            }
        }
    }

    private func mindModelCard(_ name: String, _ sub: String, _ icon: String, _ color: Color, _ loaded: Bool) -> some View {
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

    // MARK: - Components

    private func langStatBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.06)))
    }

    private func langDomainBar(label: String, value: Double, desc: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * value))
                        .animation(.easeInOut(duration: 1.0), value: value)
                }
            }
            .frame(height: 5)
            Text(desc)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 70, alignment: .leading)
        }
    }

    private func formatPatternName(_ raw: String) -> String {
        let map: [String: String] = [
            "V2_huvudsats": "V2-ordföljd (huvudsats)",
            "passiv_s": "Passiv s-form",
            "bisats_att": "Bisats (att)",
            "bisats_som": "Bisats (som)",
            "bisats_när": "Bisats (när)",
            "bisats_om": "Bisats (om)",
            "bisats_eftersom": "Bisats (eftersom)",
            "bisats_medan": "Bisats (medan)",
            "bisats_innan": "Bisats (innan)",
            "bisats_efter": "Bisats (efter)",
        ]
        return map[raw] ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func morphologyLabel(_ level: Double) -> String {
        if level >= 0.8 { return "Expert" }
        if level >= 0.6 { return "Avancerad" }
        if level >= 0.4 { return "Medel" }
        if level >= 0.2 { return "Nybörjare" }
        return "Grundläggande"
    }

    private var vocabularySparklineData: [Double] {
        let base = max(1.0, Double(brain.vocabularySize))
        let growth = brain.languageGrowthRate
        return (0..<12).reversed().map { i in
            max(0, base - Double(i) * growth * 5.0)
        }
    }

    private func capabilityRow(name: String, active: Bool, level: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(active ? Color(hex: "#34D399") : .white.opacity(0.2))
            Text(name)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(active ? 0.7 : 0.35))
            Spacer()
            if active {
                Text(String(format: "%.0f%%", min(1.0, level) * 100))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.6))
            }
        }
    }

    private func modelStatusBox(name: String, detail: String, loaded: Bool, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(loaded ? Color(hex: "#34D399") : Color(hex: "#EF4444")).frame(width: 5, height: 5)
                Text(name).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            }
            Text(detail).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
            Text(loaded ? "Laddad" : "Ej laddad")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(loaded ? Color(hex: "#34D399").opacity(0.7) : Color(hex: "#EF4444").opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.1), lineWidth: 0.5))
    }
}

// MARK: - Observable proxy for LearningEngine (actor → MainActor bridge)
extension LearningEngine {
    @MainActor
    static let observableProxy = LearningProxy()

    @MainActor
    final class LearningProxy: ObservableObject {
        @Published var competencies: [DomainCompetency] = []
        @Published var overallLevel: Double = 0.0

        // v17: Real-time learning events
        @Published var latestLearnedWords: [String] = []
        @Published var activeTopics: [String] = []
        @Published var velocity: Double = 0.0                // Words per conversation (rolling avg)
        @Published var conversationsToday: Int = 0
        @Published var wordsLearnedToday: Int = 0
        @Published var vocabularyCount: Int = 0

        // v19: Grammar pattern insights
        @Published var compoundWordCount: Int = 0
        @Published var grammarPatterns: [(pattern: String, count: Int)] = []

        func refresh() {
            Task {
                let snapshot = await LearningEngine.shared.competencySnapshot()
                let level = await LearningEngine.shared.overallCompetencyLevel()
                let metrics = await LearningEngine.shared.dailyMetrics()
                let compounds = await LearningEngine.shared.compoundWordCount()
                let patterns = await LearningEngine.shared.grammarPatternSummary()
                await MainActor.run {
                    self.competencies = snapshot
                    self.overallLevel = level
                    self.conversationsToday = metrics.conversationsToday
                    self.wordsLearnedToday = metrics.wordsLearnedToday
                    self.vocabularyCount = metrics.totalVocabulary
                    self.velocity = metrics.learningVelocity
                    self.activeTopics = metrics.activeStudyTopics
                    self.latestLearnedWords = metrics.recentWords
                    self.compoundWordCount = compounds
                    self.grammarPatterns = patterns
                }
            }
        }
    }
}

// MARK: - LanguageFlowLayout (horizontal wrapping)
struct LanguageFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    EonPreviewContainer { LanguageView() }
}
