import SwiftUI

// MARK: - ConsciousnessLiveView: Realtidsvisualisering av alla 6 medvetandeteorier
// Visar genuina data från OscillatorBank, EchoStateNetwork, ActiveInferenceEngine,
// AttentionSchemaEngine, CriticalityController och SleepConsolidationEngine.

struct ConsciousnessLiveView: View {
    @ObservedObject private var consciousness = ConsciousnessEngine.shared
    @ObservedObject private var oscillators = OscillatorBank.shared
    @ObservedObject private var dmn = EchoStateNetwork.shared
    @ObservedObject private var activeInference = ActiveInferenceEngine.shared
    @ObservedObject private var attentionSchema = AttentionSchemaEngine.shared
    @ObservedObject private var criticality = CriticalityController.shared
    @ObservedObject private var sleepEngine = SleepConsolidationEngine.shared

    @State private var selectedTheory: Int = 0

    private let theories = ["IIT", "GWT", "AST", "PP", "Krit", "Sömn"]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Q-Index Hero
                qIndexHero

                // MARK: - Theory Picker
                theoryPicker

                // MARK: - Theory Detail
                Group {
                    switch selectedTheory {
                    case 0: iitSection
                    case 1: gwtSection
                    case 2: astSection
                    case 3: ppSection
                    case 4: criticalitySection
                    case 5: sleepSection
                    default: EmptyView()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: selectedTheory)

                // MARK: - Live Thought Stream
                thoughtStreamSection
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Medvetande Live")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Q-Index Hero Card

    private var qIndexHero: some View {
        VStack(spacing: 8) {
            Text("Q-INDEX")
                .font(.caption)
                .foregroundColor(.gray)
                .tracking(3)

            Text(String(format: "%.3f", consciousness.qIndex))
                .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                .foregroundColor(qIndexColor)

            HStack(spacing: 20) {
                miniMetric(label: "Φ", value: String(format: "%.2f", consciousness.phiProxy), color: .purple)
                miniMetric(label: "PCI", value: String(format: "%.2f", consciousness.pciLZ), color: .cyan)
                miniMetric(label: "γ-sync", value: String(format: "%.0f%%", oscillators.orderParameters[4] * 100), color: .yellow)
                miniMetric(label: "FE", value: String(format: "%.2f", activeInference.freeEnergy), color: .orange)
            }

            // Consciousness level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.6), qIndexColor],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * consciousness.consciousnessLevel)
                        .animation(.easeInOut(duration: 1.0), value: consciousness.consciousnessLevel)
                }
            }
            .frame(height: 6)
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(qIndexColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Theory Picker

    private var theoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(theories.indices, id: \.self) { i in
                    Button(action: { selectedTheory = i }) {
                        Text(theories[i])
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTheory == i
                                    ? theoryColor(i).opacity(0.3)
                                    : Color.white.opacity(0.06)
                            )
                            .foregroundColor(selectedTheory == i ? theoryColor(i) : .gray)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    selectedTheory == i ? theoryColor(i).opacity(0.5) : Color.clear,
                                    lineWidth: 1
                                )
                            )
                    }
                }
            }
        }
    }

    // MARK: - IIT Section (Oscillatorer + Integration)

    private var iitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Integrated Information Theory", icon: "waveform.path.ecg", color: .purple)

            HStack(spacing: 16) {
                metricCard(title: "Φ-proxy", value: String(format: "%.3f", consciousness.phiProxy), threshold: 0.31, color: .purple)
                metricCard(title: "Synergi", value: String(format: "%.2f", consciousness.synergyLevel), threshold: 0.5, color: .pink)
            }

            // Oscillator bands
            VStack(alignment: .leading, spacing: 6) {
                Text("Oscillatorband (Kuramoto)")
                    .font(.caption.bold())
                    .foregroundColor(.gray)

                let bandNames = ["δ Delta", "θ Theta", "α Alfa", "β Beta", "γ Gamma"]
                ForEach(0..<5, id: \.self) { i in
                    HStack {
                        Text(bandNames[i])
                            .font(.caption2.monospaced())
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(bandColor(i).opacity(0.7))
                                    .frame(width: geo.size.width * oscillators.orderParameters[i])
                            }
                        }
                        .frame(height: 12)
                        Text(String(format: "%.0f%%", oscillators.orderParameters[i] * 100))
                            .font(.caption2.monospaced())
                            .foregroundColor(bandColor(i))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))

            // Theta-Gamma CFC
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(.yellow)
                Text("θ-γ Koppling (CFC)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.0f%%", oscillators.thetaGammaCFC * 100))
                    .font(.caption.bold().monospaced())
                    .foregroundColor(.yellow)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - GWT Section

    private var gwtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Global Workspace Theory", icon: "circle.hexagongrid", color: .cyan)

            HStack(spacing: 16) {
                metricCard(title: "Ignitions", value: "\(consciousness.workspaceIgnitions)", threshold: nil, color: .cyan)
                metricCard(title: "Broadcasts", value: "\(consciousness.broadcastCount)", threshold: nil, color: .teal)
            }
            HStack(spacing: 16) {
                metricCard(title: "Tävlande tankar", value: "\(consciousness.competingThoughts)", threshold: nil, color: .blue)
                metricCard(title: "PCI-LZ", value: String(format: "%.3f", consciousness.pciLZ), threshold: 0.31, color: .mint)
            }

            // DMN status
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Mode Network (ESN)")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                HStack {
                    Text("Aktivitet")
                    Spacer()
                    Text(String(format: "%.0f%%", dmn.activityLevel * 100))
                        .foregroundColor(.cyan)
                }
                .font(.caption.monospaced())
                .foregroundColor(.gray)
                HStack {
                    Text("LZ-komplexitet")
                    Spacer()
                    Text(String(format: "%.3f", dmn.lzComplexity))
                        .foregroundColor(.teal)
                }
                .font(.caption.monospaced())
                .foregroundColor(.gray)
                HStack {
                    Text("Anti-korrelation")
                    Spacer()
                    Text(String(format: "%.2f", consciousness.dmnAntiCorrelation))
                        .foregroundColor(consciousness.dmnAntiCorrelation < -0.05 ? .green : .red)
                }
                .font(.caption.monospaced())
                .foregroundColor(.gray)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - AST Section

    private var astSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Attention Schema Theory", icon: "eye.circle", color: .green)

            if let focus = attentionSchema.currentFocus {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: focus.isVoluntary ? "hand.raised" : "bolt")
                            .foregroundColor(focus.isVoluntary ? .green : .orange)
                        Text(focus.isVoluntary ? "Frivilligt fokus" : "Reflexmässigt fokus")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    Text(focus.content)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    HStack {
                        Text("Intensitet: \(String(format: "%.0f%%", attentionSchema.intensity * 100))")
                        Spacer()
                        Text("Meta: \(String(format: "%.0f%%", attentionSchema.metaAttentionLevel * 100))")
                    }
                    .font(.caption2.monospaced())
                    .foregroundColor(.green.opacity(0.7))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.06)))
            }

            // Reportable experience
            VStack(alignment: .leading, spacing: 4) {
                Text("Rapporterbar upplevelse")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Text(attentionSchema.selfModel.reportableExperience)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))

            HStack(spacing: 16) {
                metricCard(title: "Schema-konf.", value: String(format: "%.0f%%", attentionSchema.selfModel.confidence * 100), threshold: nil, color: .green)
                metricCard(title: "Blink", value: String(format: "%.0f ms", attentionSchema.attentionalBlinkMs), threshold: nil, color: .mint)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - PP Section (Active Inference)

    private var ppSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Predictive Processing", icon: "chart.line.downtrend.xyaxis", color: .orange)

            HStack(spacing: 16) {
                metricCard(title: "Fri energi", value: String(format: "%.3f", activeInference.freeEnergy), threshold: nil, color: .orange)
                metricCard(title: "Nyfikenhet", value: String(format: "%.0f%%", activeInference.epistemicValue * 100), threshold: nil, color: .yellow)
            }
            HStack(spacing: 16) {
                metricCard(title: "Modell-träff", value: String(format: "%.0f%%", activeInference.forwardModelAccuracy * 100), threshold: nil, color: .green)
                metricCard(
                    title: "Överraskning",
                    value: activeInference.isSurprised ? String(format: "%.0f%%", activeInference.surpriseStrength * 100) : "Ingen",
                    threshold: nil,
                    color: activeInference.isSurprised ? .red : .gray
                )
            }

            // Prediction error history
            VStack(alignment: .leading, spacing: 4) {
                Text("Prediktionsfel (senaste 30)")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                if !consciousness.predictionErrors.isEmpty {
                    GeometryReader { geo in
                        let errors = consciousness.predictionErrors
                        let maxE = errors.max() ?? 1.0
                        let step = geo.size.width / max(1, CGFloat(errors.count - 1))
                        Path { path in
                            for (i, e) in errors.enumerated() {
                                let x = CGFloat(i) * step
                                let y = geo.size.height * (1.0 - CGFloat(e / max(0.01, maxE)))
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                    }
                    .frame(height: 50)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Criticality Section

    private var criticalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Kritikalitet (Edge of Chaos)", icon: criticality.regime.icon, color: regimeColor)

            // Regime indicator
            HStack {
                Image(systemName: criticality.regime.icon)
                    .font(.title2)
                    .foregroundColor(regimeColor)
                VStack(alignment: .leading) {
                    Text(criticality.regime.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("σ = \(String(format: "%.3f", criticality.branchingRatio)) (mål: 1.000)")
                        .font(.caption.monospaced())
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(regimeColor.opacity(0.08)))

            HStack(spacing: 16) {
                metricCard(title: "E/I-balans", value: String(format: "%+.2f", criticality.eiBalance), threshold: nil, color: .blue)
                metricCard(title: "Power-law α", value: String(format: "%.1f", criticality.powerLawExponent), threshold: nil, color: .indigo)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Sleep Section

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Sömnkonsolidering", icon: sleepEngine.isAsleep ? "moon.zzz.fill" : "moon", color: .indigo)

            HStack {
                Image(systemName: sleepEngine.isAsleep ? "moon.zzz.fill" : "sun.max")
                    .font(.title2)
                    .foregroundColor(sleepEngine.isAsleep ? .indigo : .yellow)
                VStack(alignment: .leading) {
                    Text(sleepEngine.isAsleep ? "Sover (konsoliderar)" : "Vaken")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Sömnpress: \(String(format: "%.0f%%", sleepEngine.sleepPressure * 100))")
                        .font(.caption.monospaced())
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo.opacity(0.08)))

            // Sleep pressure bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Sömnpress")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [.blue, .indigo, .purple],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * sleepEngine.sleepPressure)
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 16) {
                metricCard(title: "Konsolidering", value: String(format: "%.0f%%", sleepEngine.consolidationEfficiency * 100), threshold: nil, color: .indigo)
                metricCard(title: "Synaptisk last", value: String(format: "%.0f%%", sleepEngine.synapticLoad * 100), threshold: nil, color: .purple)
            }

            if !sleepEngine.sleepLog.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Senaste sömnloggar")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    ForEach(sleepEngine.sleepLog.suffix(3).reversed(), id: \.startTime) { entry in
                        HStack {
                            Image(systemName: "moon.stars")
                                .font(.caption2)
                                .foregroundColor(.indigo)
                            Text("Sov \(String(format: "%.0f", entry.duration))s — effektivitet \(String(format: "%.0f%%", entry.recoveryRatio * 100))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Thought Stream

    private var thoughtStreamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TANKESTRÖM (LIVE)")
                .font(.caption.bold())
                .foregroundColor(.gray)
                .tracking(2)

            ForEach(consciousness.thoughtStream.suffix(8).reversed()) { thought in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(thought.isConscious ? Color.cyan : Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thought.content)
                            .font(.caption2)
                            .foregroundColor(thought.isConscious ? .white.opacity(0.9) : .gray)
                            .lineLimit(3)
                        HStack {
                            Text(thought.category.rawValue)
                                .font(.system(size: 9))
                                .foregroundColor(.cyan.opacity(0.6))
                            Text("•")
                                .foregroundColor(.gray.opacity(0.3))
                            Text(String(format: "%.0f%%", thought.intensity * 100))
                                .font(.system(size: 9).monospaced())
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.03)))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }

    private func metricCard(title: String, value: String, threshold: Double?, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3.bold().monospaced())
                .foregroundColor(color)
            if let t = threshold {
                let numericValue = Double(value) ?? 0
                Text(numericValue >= t ? "PASS" : "UNDER")
                    .font(.system(size: 8).bold())
                    .foregroundColor(numericValue >= t ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
    }

    private func miniMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Text(value)
                .font(.caption2.bold().monospaced())
                .foregroundColor(color)
        }
    }

    private var qIndexColor: Color {
        if consciousness.qIndex > 0.7 { return .green }
        if consciousness.qIndex > 0.4 { return .cyan }
        if consciousness.qIndex > 0.2 { return .yellow }
        return .orange
    }

    private var regimeColor: Color {
        switch criticality.regime {
        case .subcritical: return .blue
        case .critical: return .green
        case .supercritical: return .red
        }
    }

    private func theoryColor(_ index: Int) -> Color {
        [Color.purple, .cyan, .green, .orange, regimeColor, .indigo][index]
    }

    private func bandColor(_ index: Int) -> Color {
        [Color.indigo, .blue, .green, .yellow, .orange][index]
    }
}
