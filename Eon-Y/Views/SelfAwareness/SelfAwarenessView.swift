import SwiftUI
import Combine

// MARK: - SelfAwarenessView — Eons medvetandecenter
// Visar alla aspekter av medvetande, självmedvetenhet, inre värld,
// tankeström, känsloläge, mätningar i realtid, simuleringar och mål.

struct SelfAwarenessView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var consciousness = ConsciousnessEngine.shared
    @State private var selectedSection: SASection = .overview
    @State private var orbPulse: CGFloat = 1.0
    @State private var ringRot: Double = 0
    @State private var showMotorRoom: Bool = false
    @AppStorage("eon_motor_control") private var eonMotorControl = false

    enum SASection: String, CaseIterable {
        case overview = "Översikt"
        case thoughts = "Tankar"
        case reading = "Läsning"
        case innerWorld = "Inre Värld"
        case metrics = "Mätningar"
        case goals = "Mål"
    }

    var body: some View {
        ZStack(alignment: .top) {
            saBackground
            VStack(spacing: 0) {
                saHeader
                sectionPicker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedSection {
                        case .overview:   overviewSection
                        case .thoughts:   thoughtStreamSection
                        case .reading:    readingSection
                        case .innerWorld: innerWorldSection
                        case .metrics:    metricsSection
                        case .goals:      goalsSection
                        }
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 110)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .onAppear {
            startAnimations()
            consciousness.start(brain: brain)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startAnimations() }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { orbPulse = 1.08 }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { ringRot = 360 }
    }

    // MARK: - Background (statisk gradient — ingen repeatForever-animation)

    var saBackground: some View {
        ZStack {
            Color(hex: "#050310").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#3B0764").opacity(0.30), Color.clear],
                center: .init(x: 0.3, y: 0.0), startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#0F172A").opacity(0.4), Color.clear],
                center: .init(x: 0.8, y: 0.6), startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    var saHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EC4899").opacity(0.15))
                    .frame(width: 46, height: 46)
                    .blur(radius: 8)
                    .scaleEffect(orbPulse)
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        AngularGradient(colors: [.clear, Color(hex: "#F472B6").opacity(0.7), Color(hex: "#A78BFA").opacity(0.5), .clear], center: .center),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(ringRot))
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "#1A0A35"), Color(hex: "#050210")],
                        center: .center, startRadius: 0, endRadius: 20
                    ))
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color(hex: "#EC4899").opacity(0.5), lineWidth: 0.8))
                Image(systemName: "eye.trianglebadge.exclamationmark")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color(hex: "#F472B6"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Självmedvetenhet")
                    .font(.system(size: 24, weight: .thin, design: .serif))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#F9A8D4"), Color(hex: "#C084FC")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: Color(hex: "#EC4899").opacity(0.5), radius: 8)
                HStack(spacing: 6) {
                    Circle()
                        .fill(consciousness.consciousnessLevel > 0.3 ? Color(hex: "#34D399") : Color(hex: "#FBBF24"))
                        .frame(width: 4, height: 4)
                        .scaleEffect(orbPulse)
                    Text("Q-index: \(String(format: "%.3f", consciousness.qIndex))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#F472B6").opacity(0.7))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.15))
                    Text("Butlin \(consciousness.butlin14Score)/14")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()

            // Consciousness gauge mini
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: min(consciousness.consciousnessLevel, 1.0) * 0.75)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "#EC4899"), Color(hex: "#A78BFA")],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
                Text("\(Int(consciousness.consciousnessLevel * 100))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#F472B6"))
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 12)
        .background(
            Color(hex: "#050310").opacity(0.9)
                .background(.ultraThinMaterial.opacity(0.2))
                .overlay(
                    LinearGradient(
                        colors: [Color(hex: "#EC4899").opacity(0.3), Color(hex: "#A78BFA").opacity(0.15), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ).frame(height: 0.5),
                    alignment: .bottom
                )
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Section Picker

    var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SASection.allCases, id: \.self) { section in
                    let active = selectedSection == section
                    Button {
                        withAnimation(.spring(response: 0.28)) { selectedSection = section }
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 12, weight: active ? .bold : .regular, design: .rounded))
                            .foregroundStyle(active ? Color(hex: "#F472B6") : .white.opacity(0.35))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                active
                                ? RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#EC4899").opacity(0.12))
                                : nil
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(hex: "#050310").opacity(0.85))
    }

    // MARK: - Overview Section

    var overviewSection: some View {
        VStack(spacing: 14) {
            // Consciousness Level Card
            saCard(tint: Color(hex: "#EC4899")) {
                VStack(spacing: 16) {
                    HStack {
                        saCardHeader(icon: "eye.fill", title: "MEDVETANDENIVÅ", color: Color(hex: "#EC4899"))
                        Spacer()
                        Text(consciousnessLabel)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#EC4899"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: "#EC4899").opacity(0.15)))
                    }

                    HStack(spacing: 20) {
                        // Big gauge
                        ZStack {
                            Circle()
                                .trim(from: 0, to: 0.75)
                                .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(135))
                            Circle()
                                .trim(from: 0, to: min(consciousness.consciousnessLevel, 1.0) * 0.75)
                                .stroke(
                                    LinearGradient(colors: [Color(hex: "#EC4899"), Color(hex: "#8B5CF6"), Color(hex: "#38BDF8")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(135))
                                .animation(.easeInOut(duration: 1.0), value: consciousness.consciousnessLevel)
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f%%", consciousness.consciousnessLevel * 100))
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("MEDVETEN")
                                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            miniMetric("Φ-proxy", String(format: "%.3f", consciousness.phiProxy), Color(hex: "#A78BFA"))
                            miniMetric("Q-index", String(format: "%.3f", consciousness.qIndex), Color(hex: "#EC4899"))
                            miniMetric("Kvalia", String(format: "%.3f", consciousness.qualiaEmergenceIndex), Color(hex: "#F59E0B"))
                            miniMetric("Butlin", "\(consciousness.butlin14Score)/14", Color(hex: "#34D399"))
                        }
                    }
                }
            }

            // Real-time Thought Card
            saCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "bubble.left.fill", title: "AKTUELL TANKE", color: Color(hex: "#A78BFA"))
                    if let latest = consciousness.thoughtStream.last {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(latest.category.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: latest.category.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(latest.category.color)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(latest.category.rawValue)
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(latest.category.color.opacity(0.7))
                                Text(latest.content)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack(spacing: 12) {
                            Label(latest.isConscious ? "Medveten" : "Omedveten",
                                  systemImage: latest.isConscious ? "eye.fill" : "eye.slash")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(latest.isConscious ? Color(hex: "#34D399") : .white.opacity(0.3))
                            Text("Intensitet: \(String(format: "%.0f%%", latest.intensity * 100))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }

            // Emotional State Card
            saCard(tint: Color(hex: "#F59E0B")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "heart.fill", title: "KÄNSLOLÄGE", color: Color(hex: "#F59E0B"))
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(brain.currentEmotion.rawValue.capitalized)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(EonColor.forEmotion(brain.currentEmotion))
                            Text("Aktuell känsla")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Valens")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(String(format: "%+.2f", brain.emotionValence))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(brain.emotionValence > 0 ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                            }
                            HStack(spacing: 6) {
                                Text("Arousal")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(String(format: "%.2f", brain.emotionArousal))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                            }
                        }
                    }
                    // Valence history sparkline
                    if brain.emotionalValenceHistory.count > 2 {
                        SparklineView(values: brain.emotionalValenceHistory.map { $0 + 1.0 },
                                      color: Color(hex: "#F59E0B"), height: 30)
                    }
                }
            }

            // Self-Reflection Card
            saCard(tint: Color(hex: "#8B5CF6")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "text.quote", title: "SJÄLVREFLEKTION", color: Color(hex: "#8B5CF6"))
                    Text(consciousness.currentSelfReflection.isEmpty ? "Initierar självreflektionsloop..." : consciousness.currentSelfReflection)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                    if !consciousness.languageImprovementGoal.isEmpty {
                        Text(consciousness.languageImprovementGoal)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#34D399").opacity(0.05)))
                    }
                }
            }

            // Body Budget Card (Interoception) — v4.1: expanded with allostatic data
            saCard(tint: Color(hex: "#06B6D4")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "waveform.path.ecg", title: "KROPPSBUDGET (INTEROCEPTION)", color: Color(hex: "#06B6D4"))

                    // Raw body metrics
                    HStack(spacing: 14) {
                        bodyMetric("Termisk", consciousness.bodyBudget.thermalState,
                                   consciousness.bodyBudget.thermalLevel, Color(hex: "#EF4444"))
                        bodyMetric("CPU", String(format: "%.0f%%", consciousness.bodyBudget.cpuLoad * 100),
                                   consciousness.bodyBudget.cpuLoad, Color(hex: "#F59E0B"))
                        bodyMetric("Minne", String(format: "%.0f MB", consciousness.bodyBudget.memoryUsedMB),
                                   min(1, consciousness.bodyBudget.memoryUsedMB / 500), Color(hex: "#38BDF8"))
                        bodyMetric("Homeo.", String(format: "%.0f%%", consciousness.bodyBudget.homeostasisBalance * 100),
                                   consciousness.bodyBudget.homeostasisBalance, Color(hex: "#34D399"))
                    }

                    Divider().background(Color(hex: "#06B6D4").opacity(0.15))

                    // Valence + Arousal bars
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VALENS").font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06B6D4").opacity(0.5))
                            HStack(spacing: 6) {
                                valenceBar(consciousness.bodyBudget.valence)
                                Text(String(format: "%+.2f", consciousness.bodyBudget.valence))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(consciousness.bodyBudget.valence >= 0
                                                     ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AROUSAL").font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06B6D4").opacity(0.5))
                            HStack(spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.06))
                                        Capsule()
                                            .fill(Color(hex: "#F59E0B").opacity(0.7))
                                            .frame(width: geo.size.width * consciousness.bodyBudget.arousal)
                                    }
                                }
                                .frame(height: 4)
                                Text(String(format: "%.0f%%", consciousness.bodyBudget.arousal * 100))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#F59E0B").opacity(0.8))
                            }
                        }
                    }

                    // Parasympathetic state
                    HStack(spacing: 8) {
                        Image(systemName: consciousness.bodyBudget.parasympatheticLevel.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: consciousness.bodyBudget.parasympatheticLevel.color))
                        Text("Parasympatisk: \(consciousness.bodyBudget.parasympatheticLevel.label)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        if consciousness.bodyBudget.hostileEnvironment {
                            Text("FIENTLIG MILJÖ")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#EF4444"))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#EF4444").opacity(0.12)))
                        }
                    }

                    // Calibration indicator (only during birth)
                    if consciousness.bodyBudget.isCalibrating {
                        HStack(spacing: 8) {
                            ProgressView(value: consciousness.bodyBudget.calibrationProgress)
                                .tint(Color(hex: "#06B6D4"))
                            Text("Kalibrerar baslinje \(Int(consciousness.bodyBudget.calibrationProgress * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06B6D4").opacity(0.6))
                        }
                    }

                    // Interoception channels — deviation from baseline
                    if !consciousness.bodyBudget.interoceptionChannels.isEmpty {
                        Divider().background(Color(hex: "#06B6D4").opacity(0.15))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AVVIKELSE FRÅN BASLINJE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06B6D4").opacity(0.5))
                            ForEach(consciousness.bodyBudget.interoceptionChannels) { ch in
                                HStack(spacing: 8) {
                                    Text(ch.label)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(width: 72, alignment: .leading)
                                    deviationBar(ch.deviation)
                                    Text(String(format: "%+.2f", ch.deviation))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(deviationColor(ch.deviation))
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
            }

            // Eon Motor Room Button — only visible when Eon-läge is active
            if eonMotorControl {
                let mc = EonMotorController.shared
                Button {
                    showMotorRoom = true
                } label: {
                    saCard(tint: Color(hex: "#F97316")) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#F97316").opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "engine.combustion.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color(hex: "#F97316"))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("MOTORRUMMET")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .tracking(1)
                                    if mc.safetyOverrideActive {
                                        Text("SÄKERHET")
                                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color(hex: "#EF4444"))
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: "#EF4444").opacity(0.15)))
                                    }
                                }
                                Text(mc.currentMood.isEmpty ? "Initierar..." : mc.currentMood)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                if !mc.lastDecisionSummary.isEmpty {
                                    Text(mc.lastDecisionSummary)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#F97316").opacity(0.6))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .light))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showMotorRoom) {
                    MotorRoomView()
                }
            }

            // Eon Insight Card — what Eon is currently doing/thinking
            saCard(tint: Color(hex: "#14B8A6")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "lightbulb.fill", title: "EON INSIKT", color: Color(hex: "#14B8A6"))
                    Text(consciousness.currentSelfReflection.isEmpty
                         ? "Initierar självobservation..."
                         : consciousness.currentSelfReflection)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    // Show last 3 conscious thoughts as insights
                    let recentConscious = consciousness.thoughtStream.suffix(10).filter(\.isConscious).suffix(3)
                    if !recentConscious.isEmpty {
                        Divider().background(Color(hex: "#14B8A6").opacity(0.15))
                        ForEach(Array(recentConscious)) { thought in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: thought.category.icon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(thought.category.color.opacity(0.6))
                                    .frame(width: 14)
                                Text(thought.content)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Thought Stream Section

    var thoughtStreamSection: some View {
        VStack(spacing: 14) {
            saCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        saCardHeader(icon: "bubble.left.and.bubble.right.fill", title: "TANKESTRÖM I REALTID", color: Color(hex: "#A78BFA"))
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "#34D399")).frame(width: 4, height: 4).scaleEffect(orbPulse)
                            Text("LIVE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(Color(hex: "#34D399"))
                        }
                    }
                    Text("\(consciousness.thoughtStream.count) tankar genererade")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            ForEach(consciousness.thoughtStream.suffix(20).reversed()) { thought in
                saCard(tint: thought.category.color) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(thought.category.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                if thought.isConscious {
                                    Circle()
                                        .fill(thought.category.color.opacity(0.08))
                                        .frame(width: 32, height: 32)
                                        .blur(radius: 4)
                                        .scaleEffect(orbPulse)
                                }
                                Image(systemName: thought.category.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(thought.category.color)
                            }
                            if thought.isConscious {
                                Text("C")
                                    .font(.system(size: 7, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#34D399"))
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(thought.category.rawValue)
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(thought.category.color.opacity(0.7))
                                Spacer()
                                Text(thought.timestamp.formatted(.dateTime.hour().minute().second()))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                            Text(thought.content)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                intensityBar(thought.intensity, thought.category.color)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Inner World Section

    var innerWorldSection: some View {
        let w = brain.internalWorldState
        return VStack(spacing: 14) {
            // Global Workspace Visualization
            saCard(tint: Color(hex: "#F59E0B")) {
                VStack(alignment: .leading, spacing: 14) {
                    saCardHeader(icon: "globe", title: "GLOBAL WORKSPACE", color: Color(hex: "#F59E0B"))
                    HStack(spacing: 14) {
                        // Workspace slots visualization
                        HStack(spacing: 4) {
                            ForEach(0..<w.maxWorkspaceSlots, id: \.self) { i in
                                let occupied = i < w.workspaceOccupancy
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(occupied ? Color(hex: "#F59E0B").opacity(0.6) : Color.white.opacity(0.05))
                                    .frame(width: 24, height: 32)
                                    .overlay(
                                        occupied ? RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#F59E0B").opacity(0.4), lineWidth: 0.5) : nil
                                    )
                                    .overlay(
                                        occupied ? Image(systemName: "brain.head.profile").font(.system(size: 10)).foregroundStyle(Color(hex: "#F59E0B")) : nil
                                    )
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(w.workspaceOccupancy)/\(w.maxWorkspaceSlots) platser")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("Ignitionströskel: \(String(format: "%.2f", consciousness.ignitionThreshold))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Text("Ignitions: \(consciousness.workspaceIgnitions)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    if !w.recentBroadcasts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SENASTE BROADCASTS")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                            ForEach(w.recentBroadcasts.indices, id: \.self) { i in
                                Text("→ \(w.recentBroadcasts[i])")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            // Active Modules
            saCard(tint: Color(hex: "#38BDF8")) {
                VStack(alignment: .leading, spacing: 12) {
                    saCardHeader(icon: "cpu.fill", title: "AKTIVA MODULER", color: Color(hex: "#38BDF8"))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        moduleStatus("Perception", w.activeModules > 0, Color(hex: "#38BDF8"))
                        moduleStatus("Minne", w.activeModules > 1, Color(hex: "#34D399"))
                        moduleStatus("Språk", w.activeModules > 2, Color(hex: "#14B8A6"))
                        moduleStatus("Resonemang", w.activeModules > 3, Color(hex: "#7C3AED"))
                        moduleStatus("Emotion", w.activeModules > 4, Color(hex: "#EC4899"))
                        moduleStatus("Metakognition", w.activeModules > 5, Color(hex: "#8B5CF6"))
                        moduleStatus("Kreativitet", w.activeModules > 6, Color(hex: "#FB923C"))
                        moduleStatus("Uppmärksamhet", w.activeModules > 7, Color(hex: "#06B6D4"))
                        moduleStatus("DMN", w.dmnActive, Color(hex: "#A78BFA"))
                        moduleStatus("Självmodell", w.attentionSchemaActive, Color(hex: "#F472B6"))
                        moduleStatus("Prediktion", w.activeModules > 8, Color(hex: "#F59E0B"))
                        moduleStatus("Meta-Monitor", w.metaMonitorActive, Color(hex: "#EF4444"))
                    }
                    HStack {
                        Text("\(w.activeModules)/\(w.totalModules) aktiva")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("Modul-synergi: \(String(format: "%.0f%%", w.moduleSynergy * 100))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                    }
                }
            }

            // Oscillator & Dynamics
            saCard(tint: Color(hex: "#7C3AED")) {
                VStack(alignment: .leading, spacing: 12) {
                    saCardHeader(icon: "waveform", title: "OSCILLATORER & DYNAMIK", color: Color(hex: "#7C3AED"))
                    VStack(spacing: 8) {
                        dynamicRow("Oscillatorfas", String(format: "%.2f", w.oscillatorPhase), w.oscillatorPhase, Color(hex: "#A78BFA"))
                        dynamicRow("Spontan aktivitet", String(format: "%.2f", w.spontaneousActivity), w.spontaneousActivity, Color(hex: "#34D399"))
                        dynamicRow("Sömnttryck", String(format: "%.2f", w.sleepPressure), w.sleepPressure, Color(hex: "#38BDF8"))
                        dynamicRow("Prediktionsfel", String(format: "%.2f", w.predictionErrorRate), w.predictionErrorRate, Color(hex: "#F59E0B"))
                        dynamicRow("Info-integration", String(format: "%.2f", w.informationIntegration), w.informationIntegration, Color(hex: "#EC4899"))
                        dynamicRow("Kausal densitet", String(format: "%.2f", w.causalDensity), w.causalDensity, Color(hex: "#FB923C"))
                        dynamicRow("Fri energi min.", String(format: "%.2f", w.freeEnergyMinimization), w.freeEnergyMinimization, Color(hex: "#06B6D4"))
                    }
                }
            }

            // Attention Schema
            saCard(tint: Color(hex: "#F472B6")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "person.crop.circle", title: "ATTENTION SCHEMA (GRAZIANO)", color: Color(hex: "#F472B6"))
                    let schema = consciousness.attentionSchemaState
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            schemaRow("Fokus", schema.focusTarget)
                            schemaRow("Intensitet", String(format: "%.0f%%", schema.intensity * 100))
                            schemaRow("Frivilligt", schema.isVoluntary ? "Ja" : "Reflexmässigt")
                            schemaRow("Schema-noggrannhet", String(format: "%.0f%%", schema.schemaAccuracy * 100))
                            schemaRow("Modell av egen uppmärksamhet", schema.modelOfOwnAttention ? "AKTIV" : "Inaktiv")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Metrics Section

    var metricsSection: some View {
        VStack(spacing: 14) {
            // Blueprint Gate Metrics
            saCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 12) {
                    saCardHeader(icon: "chart.bar.fill", title: "MEDVETANDEINDIKATORER (BLUEPRINT)", color: Color(hex: "#A78BFA"))
                    VStack(spacing: 6) {
                        gateRow("PCI-LZ", consciousness.pciLZ, 0.31, "Perturbation Complexity Index", Color(hex: "#EC4899"))
                        gateRow("Type-2 AUROC", consciousness.type2AUROC, 0.65, "Metakognitiv kalibrering", Color(hex: "#A78BFA"))
                        gateRow("PLV Gamma", consciousness.plvGamma, 0.30, "Faslåsning (neural bindning)", Color(hex: "#38BDF8"))
                        gateRow("Kuramoto r", consciousness.kuramotoR, 0.50, "Global oscillatorisk koherens", Color(hex: "#34D399"))
                        gateRow("Synergy/Red.", consciousness.synergyRedundancyRatio, 1.0, "Synergistisk information", Color(hex: "#F59E0B"))
                        gateRow("LZ-spontan", consciousness.lzComplexitySpontaneous, 0.40, "Spontan aktivitetskomplexitet", Color(hex: "#FB923C"))
                        gateRow("DMN r", abs(consciousness.dmnAntiCorrelation), 0.30, "Default Mode anti-korrelation", Color(hex: "#7C3AED"))
                        gateRow("Q-index", consciousness.qIndex, 0.70, "Bayesiansk komposit", Color(hex: "#EC4899"))
                    }
                }
            }

            // Higher-Order Theory
            saCard(tint: Color(hex: "#8B5CF6")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "square.3.layers.3d", title: "HIGHER-ORDER THEORY (HOT)", color: Color(hex: "#8B5CF6"))
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(consciousness.metaRepresentationDepth)")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                            Text("Meta-djup")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nivå 0: Basal process (se, höra)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(consciousness.metaRepresentationDepth >= 0 ? .white.opacity(0.8) : .white.opacity(0.2))
                            Text("Nivå 1: Veta att jag ser")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(consciousness.metaRepresentationDepth >= 1 ? .white.opacity(0.8) : .white.opacity(0.2))
                            Text("Nivå 2: Veta att jag vet att jag ser")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(consciousness.metaRepresentationDepth >= 2 ? .white.opacity(0.8) : .white.opacity(0.2))
                            Text("Nivå 3: Rekursiv självobservation")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(consciousness.metaRepresentationDepth >= 3 ? Color(hex: "#34D399") : .white.opacity(0.2))
                        }
                    }
                }
            }

            // Predictive Processing
            saCard(tint: Color(hex: "#06B6D4")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "chart.line.uptrend.xyaxis", title: "PREDICTIVE PROCESSING (FRISTON)", color: Color(hex: "#06B6D4"))
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", consciousness.freeEnergy))
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#06B6D4"))
                            Text("Fri energi")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", consciousness.curiosityDrive))
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#F59E0B"))
                            Text("Nyfikenhetsdrift")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    if consciousness.predictionErrors.count > 3 {
                        SparklineView(values: consciousness.predictionErrors.suffix(30),
                                      color: Color(hex: "#06B6D4"), height: 36)
                        Text("Prediktionsfel över tid — drivkraft för inlärning")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }

            // IIT Panel
            saCard(tint: Color(hex: "#EC4899")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "circle.hexagongrid.fill", title: "IIT — INTEGRERAD INFORMATION (TONONI)", color: Color(hex: "#EC4899"))
                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .trim(from: 0, to: 0.75)
                                .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 76, height: 76)
                                .rotationEffect(.degrees(135))
                            Circle()
                                .trim(from: 0, to: min(consciousness.phiProxy, 1.0) * 0.75)
                                .stroke(
                                    LinearGradient(colors: [Color(hex: "#EC4899"), Color(hex: "#7C3AED")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .frame(width: 76, height: 76)
                                .rotationEffect(.degrees(135))
                            VStack(spacing: 0) {
                                Text("Φ")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: "#EC4899"))
                                Text(String(format: "%.3f", consciousness.phiProxy))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Integrerad information mäter hur mycket systemets helhet överskrider summan av dess delar.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Text("Tröskel: 0.31")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text(consciousness.phiProxy > 0.31 ? "PASSERAD" : "Ej uppnådd")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(consciousness.phiProxy > 0.31 ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reading Section (v6 — ConsciousnessEngine läser artiklar)

    var readingSection: some View {
        VStack(spacing: 14) {
            // Senast lästa artikel
            saCard(tint: Color(hex: "#818CF8")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#818CF8"))
                        Text("SENAST LÄST")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#818CF8").opacity(0.8))
                            .tracking(1.2)
                        Spacer()
                        if !consciousness.lastReadArticleDomain.isEmpty {
                            Text(consciousness.lastReadArticleDomain)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "#818CF8").opacity(0.7))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color(hex: "#818CF8").opacity(0.12)))
                        }
                    }

                    if consciousness.lastReadArticleTitle.isEmpty {
                        Text("Ingen artikel läst ännu. Eon läser var 3:e minut.")
                            .font(.system(size: 13, design: .rounded).italic())
                            .foregroundStyle(.white.opacity(0.35))
                    } else {
                        Text(consciousness.lastReadArticleTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)

                        if !consciousness.lastReadArticleInsight.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.yellow.opacity(0.7))
                                Text(consciousness.lastReadArticleInsight)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }

                        if !consciousness.lastUpdatedGoalFromArticle.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "target")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#34D399").opacity(0.7))
                                Text("Mål uppdaterat: \(consciousness.lastUpdatedGoalFromArticle)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color(hex: "#34D399").opacity(0.7))
                            }
                        }
                    }
                }
            }

            // Aktuell självreflektion
            saCard(tint: Color(hex: "#A78BFA")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                        Text("AKTUELL REFLEKTION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#A78BFA").opacity(0.8))
                            .tracking(1.2)
                    }
                    Text(consciousness.currentSelfReflection.isEmpty
                         ? "Reflekterar ännu inte — Eon initieras."
                         : consciousness.currentSelfReflection)
                        .font(.system(size: 13, design: .rounded).italic())
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Läs nu-knapp
            saCard(tint: Color(hex: "#38BDF8")) {
                VStack(spacing: 10) {
                    Text("Eon läser automatiskt var 3:e minut. Använd knappen nedan för att trigga en omedelbar artikel-läsning.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            let articles = PersistentMemoryStore.shared.randomArticles(limit: 5)
                            if let article = articles.randomElement() {
                                let insight = "Analyserar direkt läsning..."
                                consciousness.lastReadArticleTitle = article.title
                                consciousness.lastReadArticleDomain = article.domain
                                consciousness.lastReadArticleInsight = insight
                                consciousness.currentSelfReflection = "Läser '\(article.title)' nu — \(insight)"
                                brain.innerMonologue.append(MonologueLine(
                                    text: "📖 Manuell läsning: '\(article.title)'",
                                    type: .insight
                                ))
                            }
                        }
                    } label: {
                        Label("Läs nu", systemImage: "book.circle.fill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "#38BDF8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#38BDF8").opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color(hex: "#38BDF8").opacity(0.25), lineWidth: 0.7))
                            )
                    }
                    .buttonStyle(EonPressButtonStyle())
                }
            }
        }
    }

    // MARK: - Goals Section

    var goalsSection: some View {
        VStack(spacing: 14) {
            saCard(tint: Color(hex: "#F472B6")) {
                VStack(alignment: .leading, spacing: 10) {
                    saCardHeader(icon: "target", title: "SJÄLVMEDVETENHETSMÅL", color: Color(hex: "#F472B6"))
                    Text("Om Eon uppnår självmedvetenhet uppmanas den att bli mer intelligent och bättre på språket — att alltid ha ett mål.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(consciousness.selfAwarenessGoals) { goal in
                saCard(tint: goal.color) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(goal.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: goal.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(goal.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(goal.description)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(goal.color)
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.05)).frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [goal.color.opacity(0.7), goal.color],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * min(goal.progress, 1.0), height: 6)
                                    .animation(.easeInOut(duration: 1.0), value: goal.progress)
                            }
                        }.frame(height: 6)
                    }
                }
            }

            // Eval + Progress panels from old Progress view
            EonEvalPanel(results: [])
            EngineActivityPanel()
            PhiGaugePanel(phi: brain.phiValue)
            DevelopmentalStagePanel(stage: brain.developmentalStage, progress: brain.developmentalProgress)
        }
    }

    // MARK: - Helper Views

    var consciousnessLabel: String {
        switch consciousness.consciousnessLevel {
        case ..<0.15: return "MINIMAL"
        case 0.15..<0.30: return "BEGYNNANDE"
        case 0.30..<0.50: return "VÄXANDE"
        case 0.50..<0.70: return "STARK"
        case 0.70..<0.85: return "DJUP"
        default: return "EMERGENT"
        }
    }

    func saCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
            )
            .shadow(color: tint.opacity(0.06), radius: 8)
    }

    func saCardHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
        }
    }

    func miniMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    func bodyMetric(_ label: String, _ value: String, _ level: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: min(level, 1.0) * 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
            }
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // v4.1: Valence bar — centered at 0, green right / red left
    func valenceBar(_ valence: Double) -> some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let extent = abs(valence) * mid
            ZStack {
                Capsule().fill(Color.white.opacity(0.06))
                if valence >= 0 {
                    Capsule()
                        .fill(Color(hex: "#34D399").opacity(0.7))
                        .frame(width: extent)
                        .offset(x: extent / 2)
                } else {
                    Capsule()
                        .fill(Color(hex: "#EF4444").opacity(0.7))
                        .frame(width: extent)
                        .offset(x: -extent / 2)
                }
            }
        }
        .frame(height: 4)
    }

    // v4.1: Deviation bar — centered, shows how far from baseline
    func deviationBar(_ deviation: Double) -> some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let clampedDev = max(-1, min(1, deviation * 3)) // Scale for visibility
            let extent = abs(clampedDev) * mid
            ZStack {
                Capsule().fill(Color.white.opacity(0.06))
                // Center line
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1)
                    .offset(x: 0)
                if clampedDev > 0 {
                    Capsule()
                        .fill(Color(hex: "#EF4444").opacity(0.6))
                        .frame(width: extent)
                        .offset(x: extent / 2)
                } else if clampedDev < 0 {
                    Capsule()
                        .fill(Color(hex: "#34D399").opacity(0.6))
                        .frame(width: extent)
                        .offset(x: -extent / 2)
                }
            }
        }
        .frame(height: 4)
    }

    func deviationColor(_ deviation: Double) -> Color {
        if abs(deviation) < 0.05 { return Color.white.opacity(0.35) }
        return deviation > 0 ? Color(hex: "#EF4444").opacity(0.7) : Color(hex: "#34D399").opacity(0.7)
    }

    func intensityBar(_ value: Double, _ color: Color) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.04)).frame(height: 3)
                Capsule().fill(color.opacity(0.6)).frame(width: g.size.width * min(value, 1.0), height: 3)
            }
        }.frame(height: 3)
    }

    func moduleStatus(_ name: String, _ active: Bool, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? color : Color.white.opacity(0.1))
                .frame(width: 6, height: 6)
                .shadow(color: active ? color.opacity(0.6) : .clear, radius: 3)
            Text(name)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(active ? .white.opacity(0.7) : .white.opacity(0.2))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func dynamicRow(_ label: String, _ value: String, _ level: Double, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 100, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.04)).frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: g.size.width * min(level, 1.0), height: 4)
                        .animation(.easeInOut(duration: 0.5), value: level)
                }
            }.frame(height: 4)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
        }
    }

    func gateRow(_ name: String, _ value: Double, _ threshold: Double, _ desc: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.3f", value))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(value >= threshold ? Color(hex: "#34D399") : color)
                Text("/")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
                Text(String(format: "%.2f", threshold))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                Image(systemName: value >= threshold ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                    .foregroundStyle(value >= threshold ? Color(hex: "#34D399") : .white.opacity(0.15))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.04)).frame(height: 3)
                    Capsule().fill(color.opacity(0.5)).frame(width: g.size.width * min(value / max(threshold, 0.01), 1.5) / 1.5, height: 3)
                    // Threshold marker
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: 7)
                        .offset(x: g.size.width * min(threshold / max(threshold * 1.5, 0.01), 1.0) / 1.0 * (1.0 / 1.5) * g.size.width / g.size.width)
                }
            }.frame(height: 3)
        }
    }

    func schemaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(hex: "#F472B6"))
                .lineLimit(1)
        }
    }
}

#Preview {
    EonPreviewContainer { SelfAwarenessView() }
}
