import SwiftUI
import Combine

// MARK: - SuperView: Comprehensive monitoring dashboard
// Accessible by tapping "O" in "EON" on the home screen.
// Shows eyes, emotions, metrics, development, thermal, logs, and recent learning.

struct SuperView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var consciousness = ConsciousnessEngine.shared
    @ObservedObject private var ica = IntegratedCognitiveArchitecture.shared
    @ObservedObject private var thermalManager = ThermalSleepManager.shared
    @ObservedObject private var oscillators = OscillatorBank.shared
    @ObservedObject private var critCtrl = CriticalityController.shared

    // Eye animation state
    @State private var eyePupilOffset: CGSize = .zero
    @State private var eyeBlinkScale: CGFloat = 1.0
    @State private var eyeGlowPulse: CGFloat = 1.0
    @State private var eyeLookTimer: Timer? = nil
    @State private var sleepZOffset: CGFloat = 0
    @State private var sleepZOpacity: Double = 0

    // Glow animation
    @State private var glowPulse: CGFloat = 1.0

    private let accent = Color(hex: "#06B6D4")
    private let violet = Color(hex: "#7C3AED")
    private let teal = Color(hex: "#14B8A6")
    private let gold = Color(hex: "#F59E0B")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    eyeHeader
                    quickMetricsRow
                    developmentSection
                    thermalResourceSection
                    logsSection
                    recentlyLearnedSection
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Close button
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(16)
            }
        }
        .onAppear {
            startEyeAnimation()
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = 1.08
            }
        }
        .onDisappear {
            eyeLookTimer?.invalidate()
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(hex: "#050310").ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.15), Color.clear],
                center: .init(x: 0.3, y: 0.0),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [violet.opacity(0.10), Color.clear],
                center: .init(x: 0.8, y: 0.6),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - A. Eye/Face Header

    private var eyeHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                // Ambient glow behind eyes
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [emotionColor.opacity(0.25), Color.clear],
                            center: .center, startRadius: 0, endRadius: 60
                        )
                    )
                    .frame(width: 200, height: 100)
                    .blur(radius: 20)
                    .scaleEffect(glowPulse)

                if thermalManager.isSleeping {
                    sleepingEyes
                } else {
                    HStack(spacing: 24) {
                        SuperEyeView(
                            pupilOffset: eyePupilOffset,
                            blinkScale: eyeBlinkScale,
                            glowPulse: eyeGlowPulse,
                            irisColor: emotionColor
                        )
                        SuperEyeView(
                            pupilOffset: CGSize(
                                width: eyePupilOffset.width * 0.9,
                                height: eyePupilOffset.height
                            ),
                            blinkScale: eyeBlinkScale,
                            glowPulse: eyeGlowPulse,
                            irisColor: emotionColor
                        )
                    }
                }
            }
            .frame(height: 80)

            // Emotion display
            HStack(spacing: 6) {
                Circle()
                    .fill(emotionColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: emotionColor.opacity(0.8), radius: 4)
                Text(brain.currentEmotion.swedishName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(emotionColor)
            }

            Text("SuperView")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
                .tracking(4)
        }
        .padding(.top, 8)
    }

    private var sleepingEyes: some View {
        HStack(spacing: 24) {
            ZStack {
                // Closed eye — arc shape
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 3)
                Capsule()
                    .stroke(Color(hex: "#A78BFA").opacity(0.5), lineWidth: 1)
                    .frame(width: 44, height: 3)
            }
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 3)
                Capsule()
                    .stroke(Color(hex: "#A78BFA").opacity(0.5), lineWidth: 1)
                    .frame(width: 44, height: 3)
            }
        }
        .overlay(alignment: .topTrailing) {
            Text("zZ")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                .offset(x: 20, y: -20 + sleepZOffset)
                .opacity(sleepZOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        sleepZOffset = -10
                        sleepZOpacity = 1.0
                    }
                }
        }
    }

    // MARK: - B. Quick Metrics Row

    private var quickMetricsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                metricPill(label: "IIT Φ", value: String(format: "%.3f", brain.phiValue), color: violet)
                Spacer(minLength: 4)
                metricPill(label: "GWT", value: String(format: "%.0f%%", brain.broadcastStrength * 100), color: gold)
                Spacer(minLength: 4)
                metricPill(label: "AST", value: String(format: "%.0f%%", attentionSchemaLevel * 100), color: teal)
                Spacer(minLength: 4)
                metricPill(label: "PP", value: String(format: "%.2f", consciousness.pciLZ), color: Color(hex: "#EC4899"))
                Spacer(minLength: 4)
                metricPill(label: "Krit", value: critCtrl.regime == .critical ? "Krit" : critCtrl.regime == .subcritical ? "Sub" : "Sup", color: criticalityColor)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 9))
                        .foregroundStyle(accent.opacity(0.6))
                    Text("Q-index: \(String(format: "%.4f", consciousness.qIndex))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8))
                        .foregroundStyle(growthColor)
                    Text("\(String(format: "%.5f", brain.intelligenceGrowthVelocity))/min")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(growthColor.opacity(0.8))
                }
                Spacer()
                Text("Butlin \(consciousness.butlin14Score)/14")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(12)
        .background(glassCard(tint: accent))
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(color.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - C. Development Stages

    private var developmentSection: some View {
        VStack(spacing: 12) {
            sectionHeader(title: "UTVECKLINGSSTADIER", icon: "chart.bar.fill", color: teal)

            HStack(spacing: 14) {
                developmentGauge(
                    title: "Språk",
                    level: brain.overallLanguageLevel,
                    color: Color(hex: "#14B8A6")
                )
                developmentGauge(
                    title: "Medvetande",
                    level: consciousness.consciousnessLevel,
                    color: Color(hex: "#A78BFA")
                )
            }

            // Stage scale legend
            HStack(spacing: 0) {
                ForEach(Array(stageLabels.enumerated()), id: \.offset) { idx, label in
                    Text(label)
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(maxWidth: .infinity)
                }
            }

            // Growth meters
            HStack(spacing: 14) {
                growthMeter(title: "Språktillväxt", rate: brain.languageGrowthRate, color: teal)
                growthMeter(title: "Medvetandetillväxt", rate: consciousness.qIndex > 0 ? brain.intelligenceGrowthVelocity * 10 : 0, color: violet)
            }
        }
        .padding(12)
        .background(glassCard(tint: teal))
    }

    private func developmentGauge(title: String, level: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))

            ZStack {
                Circle()
                    .stroke(color.opacity(0.1), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: min(1.0, level))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.3), color, color.opacity(0.8)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 4)

                VStack(spacing: 1) {
                    Text(stageForLevel(level))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(String(format: "%.0f%%", level * 100))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func growthMeter(title: String, rate: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.6))

            GeometryReader { geo in
                let w = geo.size.width
                let fill = min(1.0, max(0.0, rate * 100))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.4), color],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: w * fill)
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.5f/min", rate))
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - D. Thermal/Resource Monitor

    private var thermalResourceSection: some View {
        VStack(spacing: 10) {
            sectionHeader(title: "TERMISK & RESURSER", icon: "thermometer.medium", color: thermalColor)

            HStack(spacing: 12) {
                // Temperature estimate
                VStack(spacing: 4) {
                    Image(systemName: thermalIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(thermalColor)
                        .shadow(color: thermalColor.opacity(0.6), radius: 6)
                    Text(estimatedTempString)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(thermalColor)
                    Text(thermalStateLabel)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(thermalColor.opacity(0.6))
                }
                .frame(maxWidth: .infinity)

                // Qwen throttle
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(violet.opacity(0.1), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: thermalManager.qwenThrottleFactor)
                            .stroke(violet, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text(String(format: "%.0f%%", thermalManager.qwenThrottleFactor * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(violet)
                    }
                    Text("Qwen")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(violet.opacity(0.5))
                }
                .frame(maxWidth: .infinity)

                // CPU / GPU / Storage
                VStack(alignment: .leading, spacing: 5) {
                    resourceBar(label: "CPU", value: brain.cpuUsage, color: Color(hex: "#34D399"))
                    resourceBar(label: "GPU", value: estimatedGPUUsage, color: Color(hex: "#38BDF8"))
                    HStack(spacing: 4) {
                        Text("MEM")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(String(format: "%.0f MB", brain.memoryUsageMB))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if thermalManager.isSleeping {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#6366F1"))
                    Text(thermalManager.sleepReason)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color(hex: "#6366F1").opacity(0.8))
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#6366F1").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(glassCard(tint: thermalColor))
    }

    private func resourceBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: 22, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(1.0, value))
                }
            }
            .frame(height: 5)
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 26, alignment: .trailing)
        }
    }

    // MARK: - E. Real-time Logs

    private var logsSection: some View {
        VStack(spacing: 10) {
            sectionHeader(title: "REALTIDSLOGGAR", icon: "text.alignleft", color: Color(hex: "#38BDF8"))

            HStack(alignment: .top, spacing: 10) {
                // Language log
                logColumn(
                    title: "SPRÅK",
                    entries: brain.languageLog.suffix(12).reversed().map { $0 },
                    color: teal
                )

                // Consciousness log
                logColumn(
                    title: "MEDVETANDE",
                    entries: brain.consciousnessThoughts.suffix(12).reversed().map { $0 },
                    color: violet
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 8))
                        .foregroundStyle(gold.opacity(0.6))
                    Text("INRE NARRATIV")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(gold.opacity(0.4))
                    Spacer()
                    Button {
                        let all = brain.innerMonologue.suffix(10).map { cleanLog($0.text) }.joined(separator: "\n")
                        UIPasteboard.general.string = all
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundStyle(gold.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                let thoughts = brain.innerMonologue.suffix(3)
                ForEach(Array(thoughts.reversed()), id: \.id) { line in
                    let cleaned = cleanLog(line.text)
                    Text(cleaned)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = cleaned
                            } label: {
                                Label("Kopiera", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(gold.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(gold.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(12)
        .background(glassCard(tint: Color(hex: "#38BDF8")))
    }

    private func logColumn(title: String, entries: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .shadow(color: color.opacity(0.8), radius: 2)
                Text(title)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(color.opacity(0.5))
                Spacer()
                if !entries.isEmpty {
                    Button {
                        UIPasteboard.general.string = entries.joined(separator: "\n")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 8))
                            .foregroundStyle(color.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    if entries.isEmpty {
                        Text("Väntar på data...")
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(.white.opacity(0.2))
                    } else {
                        ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                            let cleaned = cleanLog(entry)
                            Text(cleaned)
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(max(0.2, 0.7 - Double(idx) * 0.04)))
                                .lineLimit(2)
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.string = cleaned
                                    } label: {
                                        Label("Kopiera", systemImage: "doc.on.doc")
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxHeight: 160)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - F. Recently Learned

    private var recentlyLearnedSection: some View {
        let proxy = LearningEngine.observableProxy
        return VStack(spacing: 10) {
            sectionHeader(title: "NYLIGEN INLÄRT", icon: "sparkles", color: gold)

            if brain.recentLearnedWords.isEmpty {
                Text("Inget nytt inlärt ännu...")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(brain.recentLearnedWords.suffix(20).enumerated()), id: \.offset) { idx, word in
                        Text(word)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(gold.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(gold.opacity(0.2), lineWidth: 0.5)
                            )
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = word
                                } label: {
                                    Label("Kopiera \"\(word)\"", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }
            }

            // Learning stats row
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(proxy.wordsLearnedToday)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#34D399"))
                    Text("Idag")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text("\(brain.vocabularySize)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(teal)
                    Text("Ordförråd")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text("\(brain.idiomKnowledge)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(violet)
                    Text("Idiom")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", brain.sentenceComplexity * 100))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                    Text("Meningar")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(glassCard(tint: gold))
        .onAppear { proxy.refresh() }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.6))
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
            Spacer()
        }
    }

    private func glassCard(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tint.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.15), tint.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }

    private func cleanLog(_ text: String) -> String {
        var s = text
        for prefix in ["🔴", "🟡", "🟢", "⛓", "📚", "🗣", "🌍", "🔗", "🪞", "✅", "❌", "🔮", "🔄", "🧠", "📈", "⚠️", "🎯", "🌡️", "💤", "☀️"] {
            s = s.replacingOccurrences(of: prefix, with: "")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Eye Animation

    private func startEyeAnimation() {
        eyeLookTimer?.invalidate()
        eyeLookTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let maxOffset: CGFloat = 5
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                eyePupilOffset = CGSize(
                    width: CGFloat.random(in: -maxOffset...maxOffset),
                    height: CGFloat.random(in: -maxOffset * 0.5...maxOffset * 0.5)
                )
            }
            if Double.random(in: 0...1) < 0.25 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeIn(duration: 0.06)) { eyeBlinkScale = 0.05 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { eyeBlinkScale = 1.0 }
                    }
                }
            }
        }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            eyeGlowPulse = 1.1
        }
    }

    // MARK: - Computed Properties

    private var emotionColor: Color { EonColor.forEmotion(brain.currentEmotion) }

    private var attentionSchemaLevel: Double {
        AttentionSchemaEngine.shared.metaAttentionLevel
    }

    private var growthColor: Color {
        brain.intelligenceGrowthVelocity > 0.001 ? Color(hex: "#34D399") :
        brain.intelligenceGrowthVelocity < -0.001 ? Color(hex: "#EF4444") : .white.opacity(0.4)
    }

    private var criticalityColor: Color {
        critCtrl.regime == .critical ? Color(hex: "#34D399") :
        critCtrl.regime == .subcritical ? Color(hex: "#FBBF24") : Color(hex: "#EF4444")
    }

    private var thermalColor: Color {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return Color(hex: "#34D399")
        case .fair:     return Color(hex: "#FBBF24")
        case .serious:  return Color(hex: "#F97316")
        case .critical: return Color(hex: "#EF4444")
        @unknown default: return Color(hex: "#34D399")
        }
    }

    private var thermalIcon: String {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return "thermometer.low"
        case .fair:     return "thermometer.medium"
        case .serious:  return "thermometer.high"
        case .critical: return "flame.fill"
        @unknown default: return "thermometer.medium"
        }
    }

    private var thermalStateLabel: String {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return "NOMINAL"
        case .fair:     return "FAIR"
        case .serious:  return "SERIOUS"
        case .critical: return "CRITICAL"
        @unknown default: return "UNKNOWN"
        }
    }

    private var estimatedTempString: String {
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  return "~35°C"
        case .fair:     return "~42°C"
        case .serious:  return "~55°C"
        case .critical: return "~70°C"
        @unknown default: return "?°C"
        }
    }

    private var estimatedGPUUsage: Double {
        let throttle = thermalManager.qwenThrottleFactor
        return min(1.0, (1.0 - throttle) * 0.3 + brain.cpuUsage * 0.5 + 0.15)
    }

    private let stageLabels = ["Sten", "Insekt", "Katt", "Späd", "Ton", "Vux", "Prof", "Spec", "Qualia"]

    private func stageForLevel(_ level: Double) -> String {
        let idx = Int(level * 8.0)
        let clamped = max(0, min(idx, stageLabels.count - 1))
        return stageLabels[clamped]
    }
}

// MARK: - SuperEyeView (pair of eyes for SuperView)

struct SuperEyeView: View {
    let pupilOffset: CGSize
    let blinkScale: CGFloat
    let glowPulse: CGFloat
    let irisColor: Color

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [irisColor.opacity(0.35), Color.clear],
                        center: .center, startRadius: 0, endRadius: 26
                    )
                )
                .frame(width: 52, height: 36)
                .blur(radius: 6)
                .scaleEffect(glowPulse)

            // Sclera
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.72)],
                        center: .center, startRadius: 0, endRadius: 20
                    )
                )
                .frame(width: 40, height: 26)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))
                .shadow(color: irisColor.opacity(0.5), radius: 6)

            // Iris
            Circle()
                .fill(
                    RadialGradient(
                        colors: [irisColor, irisColor.opacity(0.6), Color(hex: "#1E0A3E")],
                        center: .center, startRadius: 0, endRadius: 10
                    )
                )
                .frame(width: 18, height: 18)
                .offset(pupilOffset)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Pupil
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
                .offset(pupilOffset)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Light reflection
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 3, height: 3)
                .offset(CGSize(
                    width: pupilOffset.width + 3,
                    height: pupilOffset.height - 3
                ))
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Eyelid strokes
            Ellipse()
                .trim(from: 0, to: 0.5)
                .stroke(irisColor.opacity(0.5), lineWidth: 1.2)
                .frame(width: 40, height: 26)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            Ellipse()
                .trim(from: 0.5, to: 1.0)
                .stroke(irisColor.opacity(0.3), lineWidth: 0.8)
                .frame(width: 40, height: 26)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))
        }
        .frame(width: 52, height: 40)
    }
}

// MARK: - FlowLayout for word chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}
