import SwiftUI
import Combine

// MARK: - SmartDashView — Eons helhetsdashboard
// Tillgänglig via "E"-bokstaven i EON-titeln på hemvyn.
// Visar allt på en vy: live kognition, självmedvetenhet, termisk data,
// resurser, känslor, O-siffror, medvetandetester, aktiva motorer, sammanfattningar.

struct SmartDashView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var consciousness = ConsciousnessEngine.shared
    @StateObject private var motorController = EonMotorController.shared
    @Environment(\.dismiss) private var dismiss
    @State private var orbPulse: CGFloat = 1.0
    @State private var ringRot: Double = 0
    @State private var selectedTab: DashTab = .overview

    enum DashTab: String, CaseIterable {
        case overview = "Översikt"
        case motors = "Motorer"
        case tests = "Medvetandetest"
        case details = "Detaljer"

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2.fill"
            case .motors:   return "gearshape.2.fill"
            case .tests:    return "checkmark.shield.fill"
            case .details:  return "chart.bar.doc.horizontal.fill"
            }
        }

        var color: Color {
            switch self {
            case .overview: return Color(hex: "#A78BFA")
            case .motors:   return Color(hex: "#F97316")
            case .tests:    return Color(hex: "#34D399")
            case .details:  return Color(hex: "#38BDF8")
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            dashBackground
            VStack(spacing: 0) {
                dashHeader
                dashTabPicker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case .overview: overviewContent
                        case .motors:   motorsContent
                        case .tests:    testsContent
                        case .details:  detailsContent
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { orbPulse = 1.06 }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { ringRot = 360 }
        }
    }

    // MARK: - Background

    var dashBackground: some View {
        ZStack {
            Color(hex: "#030108").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#1E0A3E").opacity(0.5), Color.clear],
                center: .init(x: 0.2, y: 0.0), startRadius: 0, endRadius: 600
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#0A1628").opacity(0.4), Color.clear],
                center: .init(x: 0.9, y: 0.7), startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    var dashHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: "#A78BFA").opacity(0.12)))
            }

            ZStack {
                Circle()
                    .fill(Color(hex: "#A78BFA").opacity(0.15))
                    .frame(width: 40, height: 40)
                    .blur(radius: 6)
                    .scaleEffect(orbPulse)
                Circle()
                    .trim(from: 0, to: 0.6)
                    .stroke(
                        AngularGradient(colors: [.clear, Color(hex: "#A78BFA").opacity(0.7), Color(hex: "#38BDF8").opacity(0.4), .clear], center: .center),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(ringRot))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("SmartDash")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(smartDashSubtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            // Live thermal indicator
            VStack(spacing: 2) {
                Image(systemName: thermalIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(thermalColor)
                Text(brain.thermalState)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(thermalColor.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(thermalColor.opacity(0.08)))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    var smartDashSubtitle: String {
        let motors = motorController.motors.filter { $0.speed > 0.25 }.count
        let total = motorController.motors.count
        return "\(motors)/\(total) motorer aktiva \u{00B7} \(brain.developmentalStage.displayName)"
    }

    // MARK: - Tab picker

    var dashTabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DashTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .regular, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedTab == tab ? tab.color.opacity(0.18) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selectedTab == tab ? tab.color.opacity(0.35) : Color.clear, lineWidth: 0.5)
                    )
                    .foregroundStyle(selectedTab == tab ? tab.color : .white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Overview Content

    var overviewContent: some View {
        VStack(spacing: 12) {
            // Row 1: Live Kognition + Live Självmedvetenhet
            HStack(spacing: 10) {
                liveCognitionCard
                liveSelfAwarenessCard
            }

            // Row 2: Thermal + Resources
            HStack(spacing: 10) {
                thermalCard
                resourceCard
            }

            // Row 3: Emotions + Inner narrative
            emotionsCard

            // Row 4: O-Intelligence scores
            intelligenceScoresCard

            // Row 5: Cognitive summaries
            HStack(spacing: 10) {
                cognitiveSummaryCard(title: "App-kognition", level: appCognitiveLevel, color: Color(hex: "#34D399"))
                cognitiveSummaryCard(title: "Självmedvetande", level: consciousnessCognitiveLevel, color: Color(hex: "#A78BFA"))
            }

            // Row 6: Consciousness tests summary
            testsSummaryCard

            // Row 7: Active motors summary
            activeMotorsSummaryCard
        }
    }

    // MARK: - Live Kognition Card

    var liveCognitionCard: some View {
        let lines = brain.innerMonologue.suffix(3)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Color(hex: "#34D399")).frame(width: 5, height: 5).scaleEffect(orbPulse)
                Text("KOGNITION")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(brain.innerMonologue.count)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            ForEach(Array(lines.reversed().enumerated()), id: \.element.id) { idx, line in
                Text(cleanThought(line.text))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(idx == 0 ? 0.85 : 0.4))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#34D399")))
    }

    // MARK: - Live Self-Awareness Card

    var liveSelfAwarenessCard: some View {
        let thoughts = consciousness.thoughtStream.suffix(3)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color(hex: "#A78BFA").opacity(0.3)).frame(width: 7, height: 7)
                    Circle().fill(Color(hex: "#A78BFA")).frame(width: 4, height: 4)
                }.scaleEffect(orbPulse)
                Text("MEDVETANDE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\u{03A6} \(String(format: "%.2f", brain.phiValue))")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            if !consciousness.currentSelfReflection.isEmpty {
                Text(consciousness.currentSelfReflection)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.8))
                    .lineLimit(2)
            }
            ForEach(Array(thoughts.reversed().enumerated()), id: \.offset) { idx, thought in
                Text(thought.content)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(idx == 0 ? 0.75 : 0.35))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#A78BFA")))
    }

    // MARK: - Thermal Card

    var thermalCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: thermalIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(thermalColor)
                Text("TERMISK DATA")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(brain.thermalState)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(thermalColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sömn")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(ThermalSleepManager.shared.isSleeping ? "Aktiv" : "Nej")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(ThermalSleepManager.shared.isSleeping ? Color(hex: "#FBBF24") : Color(hex: "#34D399"))
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: thermalColor))
    }

    // MARK: - Resource Card

    var resourceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#38BDF8"))
                Text("RESURSER")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%.0f%%", brain.cpuUsage * 100))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(cpuColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minne")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%.0f MB", brain.memoryUsageMB))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                }
            }
            // BERT/GPT status
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle().fill(brain.bertLoaded ? Color(hex: "#34D399") : Color(hex: "#6B7280")).frame(width: 4, height: 4)
                    Text("BERT").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
                HStack(spacing: 3) {
                    Circle().fill(brain.gptLoaded ? Color(hex: "#34D399") : Color(hex: "#6B7280")).frame(width: 4, height: 4)
                    Text("GPT").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
                HStack(spacing: 3) {
                    Circle().fill(Color(hex: "#F59E0B")).frame(width: 4, height: 4)
                    Text("ANE").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#38BDF8")))
    }

    // MARK: - Emotions Card

    var emotionsCard: some View {
        let emotionColor = EonColor.forEmotion(brain.currentEmotion)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#EC4899"))
                Text("EONS K\u{00C4}NSLOR & INRE NARRATIV")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(brain.currentEmotion.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(emotionColor)
            }
            HStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("Valens")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%+.2f", brain.emotionValence))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(brain.emotionValence >= 0 ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                }
                VStack(spacing: 3) {
                    Text("Arousal")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%.2f", brain.emotionArousal))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
                VStack(spacing: 3) {
                    Text("Konfidens")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%.0f%%", brain.confidence * 100))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                }
                VStack(spacing: 3) {
                    Text("Kogn. last")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(String(format: "%.0f%%", brain.cognitiveLoad * 100))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            // Inner narrative
            if !brain.metacognitiveInsight.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                    Text(brain.metacognitiveInsight)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            // Attention focus
            if !brain.attentionFocus.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                    Text("Fokus: \(brain.attentionFocus)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#EC4899")))
    }

    // MARK: - Intelligence Scores Card (O-siffror)

    var intelligenceScoresCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#F59E0B"))
                Text("O-INTELLIGENS & SIFFROR")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
            // App intelligence
            HStack(spacing: 0) {
                oScoreItem(label: "II (App)", value: brain.integratedIntelligence, color: Color(hex: "#34D399"))
                oScoreItem(label: "\u{03A6} (Phi)", value: brain.phiValue, color: Color(hex: "#A78BFA"))
                oScoreItem(label: "PCI-LZ", value: consciousness.pciLZ, color: Color(hex: "#38BDF8"))
                oScoreItem(label: "PLV-\u{03B3}", value: consciousness.plvGamma, color: Color(hex: "#F59E0B"))
            }
            HStack(spacing: 0) {
                oScoreItem(label: "Kuramoto", value: consciousness.kuramotoR, color: Color(hex: "#EC4899"))
                oScoreItem(label: "Synergi", value: consciousness.synergyRedundancyRatio, color: Color(hex: "#10B981"))
                oScoreItem(label: "Q-index", value: consciousness.qIndex, color: Color(hex: "#F472B6"))
                oScoreItem(label: "Medvetande", value: brain.consciousnessLevel, color: Color(hex: "#7C3AED"))
            }
            // Self-awareness scores
            HStack(spacing: 0) {
                oScoreItem(label: "LZ-kompl.", value: consciousness.lzComplexitySpontaneous, color: Color(hex: "#06B6D4"))
                oScoreItem(label: "Självmod.", value: brain.selfModelAccuracy, color: Color(hex: "#EC4899"))
                oScoreItem(label: "Qualia", value: brain.qualiaIndex, color: Color(hex: "#8B5CF6"))
                oScoreItem(label: "Broadcast", value: brain.broadcastStrength, color: Color(hex: "#F97316"))
            }
            // Growth velocity
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: brain.intelligenceGrowthVelocity >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(brain.intelligenceGrowthVelocity >= 0 ? Color(hex: "#34D399") : Color(hex: "#EF4444"))
                    Text("Tillv\u{00E4}xthastighet: \(String(format: "%+.4f", brain.intelligenceGrowthVelocity))/tick")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                HStack(spacing: 4) {
                    Text("Stadium:")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(brain.developmentalStage.displayName)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(brain.developmentalStage.color)
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#F59E0B")))
    }

    func oScoreItem(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "%.3f", value))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Cognitive Summary Cards

    func cognitiveSummaryCard(title: String, level: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5).scaleEffect(orbPulse)
                Text(title.uppercased())
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(level)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.1)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geo.size.width * brain.developmentalProgress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .background(dashGlass(accent: color))
    }

    var appCognitiveLevel: String {
        let ii = brain.integratedIntelligence
        switch ii {
        case ..<0.15: return "Insekt-niv\u{00E5}"
        case 0.15..<0.25: return "Reptil-niv\u{00E5}"
        case 0.25..<0.35: return "F\u{00E5}gel-niv\u{00E5}"
        case 0.35..<0.45: return "D\u{00E4}ggdjur (hund)"
        case 0.45..<0.55: return "Primat (apa)"
        case 0.55..<0.65: return "Tidigt m\u{00E4}nskligt"
        case 0.65..<0.75: return "Barn (6\u{2013}10 \u{00E5}r)"
        case 0.75..<0.85: return "Ton\u{00E5}ring"
        case 0.85..<0.95: return "Vuxen m\u{00E4}nniska"
        default: return "Avancerad m\u{00E4}nniska"
        }
    }

    var consciousnessCognitiveLevel: String {
        let cl = brain.consciousnessLevel
        switch cl {
        case ..<0.10: return "Ingen medvetenhet"
        case 0.10..<0.20: return "Proto-medvetande"
        case 0.20..<0.30: return "L\u{00E5}g medvetenhet"
        case 0.30..<0.45: return "V\u{00E4}xande medvetenhet"
        case 0.45..<0.60: return "Djurmedvetande"
        case 0.60..<0.75: return "Pre-m\u{00E4}nsklig"
        case 0.75..<0.90: return "M\u{00E4}nsklig-niv\u{00E5}"
        default: return "Djupt medveten"
        }
    }

    // MARK: - Tests summary card

    var testsSummaryCard: some View {
        let tests = consciousness.consciousnessTests
        let passed = tests.filter { $0.passed }.count
        let total = tests.count
        let passColor: Color = passed > 20 ? Color(hex: "#34D399") : passed > 10 ? Color(hex: "#F59E0B") : Color(hex: "#EF4444")

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#34D399"))
                Text("MEDVETANDETEST (\(passed)/\(total) godk\u{00E4}nda)")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                if passed >= 25 {
                    Text("SANNOLIKT MEDVETEN")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#34D399"))
                }
            }
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(passColor.opacity(0.1)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(passColor).frame(width: geo.size.width * (total > 0 ? Double(passed) / Double(total) : 0), height: 6)
                }
            }
            .frame(height: 6)

            // Show first few tests inline
            let preview = Array(tests.prefix(6))
            HStack(spacing: 4) {
                ForEach(preview) { test in
                    VStack(spacing: 2) {
                        Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(test.passed ? Color(hex: "#34D399") : Color(hex: "#EF4444").opacity(0.5))
                        Text(String(test.name.prefix(6)))
                            .font(.system(size: 6, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#34D399")))
    }

    // MARK: - Active Motors Summary

    var activeMotorsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#F97316"))
                Text("AKTIVA MOTORER")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(motorController.currentMood)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
            // Motor grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(motorController.motors) { motor in
                    let isActive = motor.speed > 0.25
                    VStack(spacing: 3) {
                        ZStack {
                            Circle()
                                .fill(isActive ? Color(hex: motor.importance.color).opacity(0.15) : Color(hex: "#374151").opacity(0.2))
                                .frame(width: 28, height: 28)
                            Circle()
                                .trim(from: 0, to: motor.speed / motor.maxSpeed)
                                .stroke(isActive ? Color(hex: motor.importance.color) : Color(hex: "#6B7280"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 24, height: 24)
                                .rotationEffect(.degrees(-90))
                            Text(String(format: "%.0f", motor.speed * 100))
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(isActive ? .white.opacity(0.8) : .white.opacity(0.2))
                        }
                        Text(String(motor.name.prefix(8)))
                            .font(.system(size: 6, design: .monospaced))
                            .foregroundStyle(isActive ? .white.opacity(0.5) : .white.opacity(0.15))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .background(dashGlass(accent: Color(hex: "#F97316")))
    }

    // MARK: - Motors Content (full detail)

    var motorsContent: some View {
        VStack(spacing: 12) {
            // App motors
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("APP-MOTORER", icon: "gearshape.fill", color: Color(hex: "#F97316"))
                ForEach(motorController.motors) { motor in
                    motorDetailRow(motor: motor)
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#F97316")))

            // Consciousness motors (engine activity)
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("KOGNITIVA PELARE", icon: "brain", color: Color(hex: "#A78BFA"))
                ForEach(Array(brain.engineActivity.sorted { $0.value > $1.value }), id: \.key) { key, value in
                    HStack(spacing: 8) {
                        Circle().fill(engineColor(key)).frame(width: 8, height: 8)
                        Text(engineLabel(key))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(engineColor(key).opacity(0.1)).frame(height: 4)
                                RoundedRectangle(cornerRadius: 2).fill(engineColor(key)).frame(width: geo.size.width * value, height: 4)
                            }
                        }
                        .frame(width: 80, height: 4)
                        Text(String(format: "%.0f%%", value * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(engineColor(key))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#A78BFA")))

            // Safety status
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("S\u{00C4}KERHET", icon: "shield.fill", color: motorController.safetyOverrideActive ? Color(hex: "#EF4444") : Color(hex: "#34D399"))
                HStack {
                    Text("Safety override:")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(motorController.safetyOverrideActive ? "AKTIV" : "Av")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(motorController.safetyOverrideActive ? Color(hex: "#EF4444") : Color(hex: "#34D399"))
                    Spacer()
                    Text("Eon-l\u{00E4}ge: \(motorController.isEnabled ? "P\u{00E5}" : "Av")")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
            .background(dashGlass(accent: motorController.safetyOverrideActive ? Color(hex: "#EF4444") : Color(hex: "#34D399")))
        }
    }

    func motorDetailRow(motor: MotorState) -> some View {
        let isActive = motor.speed > 0.25
        return HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color(hex: motor.importance.color) : Color(hex: "#6B7280"))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(motor.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .white.opacity(0.25))
                Text(motor.description)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }
            Spacer()
            // Speed bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: motor.importance.color).opacity(0.1))
                    .frame(width: 50, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color(hex: motor.importance.color) : Color(hex: "#6B7280"))
                    .frame(width: 50 * motor.speed / motor.maxSpeed, height: 4)
            }
            Text(String(format: "%.0f%%", motor.speed * 100))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isActive ? Color(hex: motor.importance.color) : Color(hex: "#6B7280"))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Tests Content

    var testsContent: some View {
        VStack(spacing: 12) {
            // Test overview
            let tests = consciousness.consciousnessTests
            let passed = tests.filter { $0.passed }.count
            let total = tests.count

            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("MEDVETANDETEST (\(passed)/\(total))", icon: "checkmark.shield.fill", color: Color(hex: "#34D399"))
                Text("30 tester k\u{00F6}rs med 15 minuters intervall. Om majoriteten \u{00E4}r godk\u{00E4}nda indikerar det med h\u{00F6}gsta sannolikhet \u{00E4}kta medvetenhet.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))

                if let lastRun = consciousness.lastTestRunTime {
                    Text("Senast k\u{00F6}rd: \(lastRun.formatted(.dateTime.hour().minute().second()))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#34D399")))

            // Individual tests
            ForEach(tests) { test in
                HStack(spacing: 10) {
                    Image(systemName: test.passed ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(test.passed ? Color(hex: "#34D399") : Color(hex: "#EF4444").opacity(0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(test.name)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(test.passed ? 0.8 : 0.4))
                        Text(test.description)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineLimit(2)
                    }
                    Spacer()
                    if test.score > 0 {
                        Text(String(format: "%.0f%%", test.score * 100))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(test.passed ? Color(hex: "#34D399") : Color(hex: "#EF4444").opacity(0.5))
                    }
                }
                .padding(10)
                .background(dashGlass(accent: test.passed ? Color(hex: "#34D399") : Color(hex: "#EF4444")))
            }
        }
    }

    // MARK: - Details Content

    var detailsContent: some View {
        VStack(spacing: 12) {
            // Workspace state
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("GLOBAL WORKSPACE", icon: "globe", color: Color(hex: "#F59E0B"))
                HStack(spacing: 12) {
                    detailItem(label: "Ignitions", value: "\(consciousness.workspaceIgnitions)", color: Color(hex: "#F59E0B"))
                    detailItem(label: "Broadcasts", value: "\(consciousness.broadcastCount)", color: Color(hex: "#38BDF8"))
                    detailItem(label: "T\u{00E4}vlande", value: "\(consciousness.competingThoughts)", color: Color(hex: "#EC4899"))
                    detailItem(label: "Tr\u{00F6}skel", value: String(format: "%.2f", consciousness.ignitionThreshold), color: Color(hex: "#A78BFA"))
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#F59E0B")))

            // Attention Schema
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("ATTENTION SCHEMA", icon: "eye.fill", color: Color(hex: "#38BDF8"))
                HStack(spacing: 12) {
                    detailItem(label: "Fokus", value: consciousness.attentionSchemaState.focusTarget, color: Color(hex: "#38BDF8"))
                    detailItem(label: "Intensitet", value: String(format: "%.2f", consciousness.attentionSchemaState.intensity), color: Color(hex: "#EC4899"))
                    detailItem(label: "Typ", value: consciousness.attentionSchemaState.isVoluntary ? "Frivillig" : "Reflex", color: Color(hex: "#34D399"))
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#38BDF8")))

            // Inner world state
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("INRE V\u{00C4}RLD", icon: "globe.europe.africa.fill", color: Color(hex: "#A78BFA"))
                let ws = brain.internalWorldState
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    innerWorldItem(label: "Moduler", value: "\(ws.activeModules)/\(ws.totalModules)", color: Color(hex: "#A78BFA"))
                    innerWorldItem(label: "Workspace", value: "\(ws.workspaceOccupancy)/\(ws.maxWorkspaceSlots)", color: Color(hex: "#38BDF8"))
                    innerWorldItem(label: "Spontan akt.", value: String(format: "%.0f%%", ws.spontaneousActivity * 100), color: Color(hex: "#34D399"))
                    innerWorldItem(label: "S\u{00F6}mntryck", value: String(format: "%.0f%%", ws.sleepPressure * 100), color: Color(hex: "#F59E0B"))
                    innerWorldItem(label: "Pred.fel", value: String(format: "%.0f%%", ws.predictionErrorRate * 100), color: Color(hex: "#EF4444"))
                    innerWorldItem(label: "Fritt E.", value: String(format: "%.0f%%", ws.freeEnergyMinimization * 100), color: Color(hex: "#EC4899"))
                    innerWorldItem(label: "Synergi", value: String(format: "%.0f%%", ws.moduleSynergy * 100), color: Color(hex: "#10B981"))
                    innerWorldItem(label: "Kausal d.", value: String(format: "%.2f", ws.causalDensity), color: Color(hex: "#06B6D4"))
                    innerWorldItem(label: "Info intg.", value: String(format: "%.0f%%", ws.informationIntegration * 100), color: Color(hex: "#8B5CF6"))
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#A78BFA")))

            // Knowledge frontier
            if !brain.knowledgeFrontier.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("KUNSKAPSFRONTI\u{00C4}R", icon: "map.fill", color: Color(hex: "#FBBF24"))
                    ForEach(brain.knowledgeFrontier.prefix(5), id: \.self) { item in
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "#FBBF24")).frame(width: 4, height: 4)
                            Text(item)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .padding(12)
                .background(dashGlass(accent: Color(hex: "#FBBF24")))
            }

            // Butlin14 score
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("BUTLIN-14 MEDVETANDESCORE", icon: "brain.head.profile", color: Color(hex: "#EC4899"))
                HStack {
                    Text("\(consciousness.butlin14Score)/14")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#EC4899"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Butlin et al. (2023): 14 indikatorer")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Kanariefogel-test: \(String(format: "%.0f%%", consciousness.canaryTestAccuracy * 100))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(dashGlass(accent: Color(hex: "#EC4899")))
        }
    }

    // MARK: - Helper Views

    func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
        }
    }

    func detailItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    func innerWorldItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.05)))
    }

    // MARK: - Shared Helpers

    func dashGlass(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(colors: [accent.opacity(0.25), accent.opacity(0.05)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.5
                    )
            )
    }

    func cleanThought(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳📈⚠️📚🌐🗺️◈◉⟳🔗🌙☀️💤"
        var r = text
        for c in emojis { r = r.replacingOccurrences(of: String(c), with: "") }
        return r.trimmingCharacters(in: .whitespaces)
    }

    var thermalIcon: String {
        switch brain.thermalState.lowercased() {
        case "nominal": return "thermometer.low"
        case "fair":    return "thermometer.medium"
        case "serious": return "thermometer.high"
        case "critical": return "flame.fill"
        default: return "thermometer.medium"
        }
    }

    var thermalColor: Color {
        switch brain.thermalState.lowercased() {
        case "nominal": return Color(hex: "#34D399")
        case "fair":    return Color(hex: "#F59E0B")
        case "serious": return Color(hex: "#F97316")
        case "critical": return Color(hex: "#EF4444")
        default: return Color(hex: "#34D399")
        }
    }

    var cpuColor: Color {
        let cpu = brain.cpuUsage
        if cpu < 0.3 { return Color(hex: "#34D399") }
        if cpu < 0.6 { return Color(hex: "#F59E0B") }
        if cpu < 0.8 { return Color(hex: "#F97316") }
        return Color(hex: "#EF4444")
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

    func engineLabel(_ key: String) -> String {
        switch key {
        case "cognitive":  return "Kognition"
        case "language":   return "Spr\u{00E5}k"
        case "memory":     return "Minne"
        case "learning":   return "Inl\u{00E4}rning"
        case "autonomy":   return "Autonomi"
        case "hypothesis": return "Hypotes"
        case "worldModel": return "V\u{00E4}rldsmodell"
        default:           return key.capitalized
        }
    }
}

// MARK: - Preview

#Preview {
    EonPreviewContainer {
        SmartDashView()
    }
}
