import SwiftUI
import Combine

struct ResourceView: View {
    @StateObject private var monitor = ResourceMonitor()

    var body: some View {
        VStack(spacing: 14) {
            // Status bar
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.overallStatus.color)
                    .frame(width: 8, height: 8)
                    .pulseAnimation(min: 0.7, max: 1.3, duration: 1.4)
                Text("RESURSSTATUS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .tracking(1.5)
                Spacer()
                Text("↻ var 2s")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .padding(.horizontal, 4)

            thermalSection
            cpuSection
            memorySection
            batterySection
            aneSection
            sparklineSection
            performanceModeSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 110)
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
    }

    // MARK: - Thermal

    var thermalSection: some View {
        GlassCard(tint: Color(hex: "#EF4444")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("TERMISK STATUS", icon: "thermometer", color: Color(hex: "#EF4444"))
                HStack(spacing: 10) {
                    ThermalCard(name: "CPU", temp: monitor.cpuTemp, state: monitor.cpuThermalState)
                    ThermalCard(name: "ANE", temp: monitor.aneTemp, state: monitor.aneThermalState)
                    ThermalCard(name: "GPU", temp: monitor.gpuTemp, state: monitor.gpuThermalState)
                }
                HStack(spacing: 6) {
                    Image(systemName: monitor.throttlingActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(monitor.throttlingActive ? Color(hex: "#F97316") : Color(hex: "#34D399"))
                    Text("Throttling: \(monitor.throttlingActive ? "Aktiv" : "Normal ✓")")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(monitor.throttlingActive ? Color(hex: "#F97316") : Color(hex: "#34D399"))
                }
            }
        }
    }

    // MARK: - CPU

    var cpuSection: some View {
        GlassCard(tint: Color(hex: "#7C3AED")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("CPU-ANVÄNDNING", icon: "cpu", color: Color(hex: "#7C3AED"))
                ForEach(monitor.cpuBreakdown, id: \.label) { item in
                    HStack(spacing: 10) {
                        Text(item.label)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 120, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule().fill(item.color)
                                    .frame(width: geo.size.width * item.value)
                                    .animation(.easeInOut(duration: 0.5), value: item.value)
                            }
                        }
                        .frame(height: 5)
                        Text("\(Int(item.value * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                Divider().background(Color.white.opacity(0.06))
                HStack {
                    Text("Totalt")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    Text("\(Int(monitor.totalCPU * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(monitor.totalCPU > 0.7 ? Color(hex: "#EF4444") : (monitor.totalCPU > 0.4 ? Color(hex: "#F59E0B") : Color(hex: "#34D399")))
                }
            }
        }
    }

    // MARK: - Memory

    var memorySection: some View {
        let items: [(String, Double, Color)] = [
            ("Foundation Model", 850, Color(hex: "#7C3AED")),
            ("KB-BERT",          180, Color(hex: "#3B82F6")),
            ("GPT-SW3",          175, Color(hex: "#7C3AED")),
            ("Kunskapsgraf",     200, Color(hex: "#14B8A6")),
            ("SALDO-cache",       80, Color(hex: "#A78BFA")),
            ("Övrigt",           116, Color.white.opacity(0.3))
        ]
        let total = items.map { $0.1 }.reduce(0, +)
        let maxMem: Double = 8192

        return GlassCard(tint: Color(hex: "#3B82F6")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("MINNE", icon: "memorychip", color: Color(hex: "#3B82F6"))
                ForEach(items, id: \.0) { name, mb, color in
                    HStack(spacing: 10) {
                        Text(name)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 120, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule().fill(color).frame(width: geo.size.width * (mb / maxMem))
                            }
                        }
                        .frame(height: 5)
                        Text("\(Int(mb)) MB")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                Divider().background(Color.white.opacity(0.06))
                HStack {
                    Text("Totalt")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07)).frame(height: 7)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#14B8A6")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * (total / maxMem), height: 7)
                        }
                    }
                    .frame(width: 90, height: 7)
                    Text(String(format: "%.1f / 8 GB", total / 1024))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Battery

    var batterySection: some View {
        GlassCard(tint: Color(hex: "#34D399")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("BATTERI", icon: "battery.75", color: Color(hex: "#34D399"))
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nu")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text(String(format: "%.1fW", monitor.batteryWatts))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(monitor.batteryWatts < 2.0 ? Color(hex: "#34D399") : Color(hex: "#F59E0B"))
                        Text(monitor.batteryWatts < 2.0 ? "låg ✓" : "måttlig")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    Divider().frame(height: 52).background(Color.white.opacity(0.1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Per timme")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text(String(format: "%.1f%%", monitor.batteryPerHour))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("~\(monitor.estimatedHours)h kvar")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    Spacer()
                }
                if let info = monitor.lastBGTaskInfo {
                    HStack(spacing: 5) {
                        Image(systemName: "moon.stars").font(.system(size: 11)).foregroundStyle(Color(hex: "#A78BFA"))
                        Text("BGTask senast: \(info)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                }
            }
        }
    }

    // MARK: - ANE

    var aneSection: some View {
        GlassCard(tint: Color(hex: "#F59E0B")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("ANE-AKTIVITET", icon: "bolt.circle.fill", color: Color(hex: "#F59E0B"))
                HStack(spacing: 0) {
                    ANEStatItem(label: "Inferenser/min", value: "\(monitor.aneInferencesPerMin)", color: Color(hex: "#A78BFA"))
                    Divider().frame(height: 40).background(Color.white.opacity(0.08))
                    ANEStatItem(label: "Latens", value: "\(monitor.aneLatencyMs)ms", color: Color(hex: "#14B8A6"))
                    Divider().frame(height: 40).background(Color.white.opacity(0.08))
                    ANEStatItem(label: "Cache-träffar", value: "\(monitor.aneCacheHitRate)%", color: Color(hex: "#F59E0B"))
                }
                HStack(spacing: 6) {
                    Image(systemName: monitor.speculativeActive ? "bolt.fill" : "bolt")
                        .font(.system(size: 11))
                        .foregroundStyle(monitor.speculativeActive ? Color(hex: "#F59E0B") : Color.white.opacity(0.3))
                    Text(monitor.speculativeActive
                         ? "Speculative Streaming: aktiv (\(String(format: "%.1f", monitor.speculativeBoost))× boost)"
                         : "Speculative Streaming: inaktiv")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(monitor.speculativeActive ? Color(hex: "#F59E0B") : Color.white.opacity(0.3))
                }
            }
        }
    }

    // MARK: - Sparklines

    var sparklineSection: some View {
        GlassCard(tint: Color(hex: "#06B6D4")) {
            VStack(alignment: .leading, spacing: 10) {
                resourceHeader("SENASTE 60 MIN", icon: "chart.line.uptrend.xyaxis", color: Color(hex: "#06B6D4"))
                ForEach([
                    ("CPU", monitor.cpuHistory, Color(hex: "#7C3AED")),
                    ("RAM", monitor.ramHistory, Color(hex: "#14B8A6")),
                    ("ANE", monitor.aneHistory, Color(hex: "#F59E0B"))
                ], id: \.0) { label, values, color in
                    HStack(spacing: 10) {
                        Text(label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.35))
                            .frame(width: 28)
                        SparklineView(values: values, color: color, height: 22)
                    }
                }
            }
        }
    }

    // MARK: - Performance Mode

    var performanceModeSection: some View {
        PerformanceModeSelector()
    }

    // MARK: - Helper

    func resourceHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.8))
                .tracking(1.2)
        }
    }
}

// MARK: - Thermal Card

struct ThermalCard: View {
    let name: String
    let temp: Double
    let state: ThermalState

    var body: some View {
        VStack(spacing: 6) {
            Text(name)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
            Text("\(Int(temp))°C")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(state.color)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(state.color)
                        .frame(height: geo.size.height * min(temp / 80.0, 1.0))
                        .animation(.easeInOut(duration: 0.5), value: temp)
                }
            }
            .frame(width: 22, height: 36)
            Text(state.label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(state.color)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(state.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(state.color.opacity(0.2), lineWidth: 0.5))
        )
    }
}

struct ANEStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Mode Selector

struct PerformanceModeSelector: View {
    @AppStorage("eon_performance_mode") private var selectedMode = 1

    let modes: [(String, String, String, String)] = [
        ("Maximal",    "Alla 10 pelare + 3 loopar", "~8%/h", "~3s"),
        ("Balanserat", "Pelare 1–7 + Loop 2",       "~4%/h", "~1.5s"),
        ("Sparsam",    "Pelare 1–3, ingen Loop 3",  "~2%/h", "~0.8s"),
        ("Vila",       "Enbart Foundation Model",   "~1%/h", "~0.4s")
    ]

    let modeColors: [Color] = [
        Color(hex: "#EF4444"), Color(hex: "#7C3AED"), Color(hex: "#34D399"), Color(hex: "#3B82F6")
    ]

    var body: some View {
        GlassCard(tint: Color(hex: "#A78BFA")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 11)).foregroundStyle(Color(hex: "#A78BFA"))
                    Text("PRESTANDALÄGE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.8))
                        .tracking(1.2)
                }

                ForEach(modes.indices, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedMode = i }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .strokeBorder(selectedMode == i ? modeColors[i] : Color.white.opacity(0.2), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                if selectedMode == i {
                                    Circle().fill(modeColors[i]).frame(width: 9, height: 9)
                                }
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(modes[i].0)
                                    .font(.system(size: 13, weight: selectedMode == i ? .semibold : .regular, design: .rounded))
                                    .foregroundStyle(selectedMode == i ? .white : Color.white.opacity(0.55))
                                Text(modes[i].1)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.3))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(modes[i].2)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                Text(modes[i].3)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#14B8A6"))
                            }
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedMode == i ? modeColors[i].opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(selectedMode == i ? modeColors[i].opacity(0.35) : Color.clear, lineWidth: 0.6)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - ResourceMonitor

enum ThermalState {
    case nominal, fair, serious, critical
    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair:    return "Måttlig"
        case .serious: return "Allvarlig"
        case .critical: return "Kritisk"
        }
    }
    var color: Color {
        switch self {
        case .nominal:  return Color(hex: "#34D399")
        case .fair:     return Color(hex: "#F59E0B")
        case .serious:  return Color(hex: "#F97316")
        case .critical: return Color(hex: "#EF4444")
        }
    }
}

enum OverallStatus {
    case good, warning, critical
    var color: Color {
        switch self {
        case .good:     return Color(hex: "#34D399")
        case .warning:  return Color(hex: "#F59E0B")
        case .critical: return Color(hex: "#EF4444")
        }
    }
}

@MainActor
class ResourceMonitor: ObservableObject {
    @Published var cpuTemp: Double = 38.0
    @Published var aneTemp: Double = 41.0
    @Published var gpuTemp: Double = 36.0
    @Published var cpuThermalState: ThermalState = .nominal
    @Published var aneThermalState: ThermalState = .nominal
    @Published var gpuThermalState: ThermalState = .nominal
    @Published var throttlingActive = false
    @Published var overallStatus: OverallStatus = .good

    @Published var cpuBreakdown: [CPUItem] = [
        CPUItem(label: "Kognitiva motorer", value: 0.18, color: Color(hex: "#7C3AED")),
        CPUItem(label: "Neural Engine",     value: 0.03, color: Color(hex: "#14B8A6")),
        CPUItem(label: "UI-rendering",      value: 0.08, color: Color(hex: "#3B82F6")),
        CPUItem(label: "Bakgrund",          value: 0.01, color: Color.white.opacity(0.3))
    ]
    @Published var totalCPU: Double = 0.30

    @Published var batteryWatts: Double = 1.8
    @Published var batteryPerHour: Double = 4.2
    @Published var estimatedHours: Int = 23
    @Published var lastBGTaskInfo: String? = "igår 03:14, 42 min"

    @Published var aneInferencesPerMin: Int = 12
    @Published var aneLatencyMs: Int = 187
    @Published var aneCacheHitRate: Int = 68
    @Published var speculativeActive = true
    @Published var speculativeBoost: Double = 2.3

    @Published var cpuHistory: [Double] = (0..<20).map { _ in Double.random(in: 0.1...0.35) }
    @Published var ramHistory: [Double] = (0..<20).map { _ in Double.random(in: 0.55...0.65) }
    @Published var aneHistory: [Double] = (0..<20).map { _ in Double.random(in: 0.02...0.15) }

    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateMetrics() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMetrics() {
        cpuTemp = Double.random(in: 35...45)
        aneTemp = Double.random(in: 38...48)
        gpuTemp = Double.random(in: 33...42)
        let newCPU = Double.random(in: 0.15...0.40)
        totalCPU = newCPU
        cpuBreakdown[0].value = Double.random(in: 0.10...0.25)
        cpuBreakdown[2].value = Double.random(in: 0.05...0.12)
        batteryWatts = Double.random(in: 1.5...2.5)
        batteryPerHour = batteryWatts * 2.3
        estimatedHours = Int(100.0 / batteryPerHour)
        aneInferencesPerMin = Int.random(in: 8...18)
        aneLatencyMs = Int.random(in: 150...230)
        aneCacheHitRate = Int.random(in: 60...80)
        cpuHistory.append(newCPU)
        if cpuHistory.count > 20 { cpuHistory.removeFirst() }
        ramHistory.append(Double.random(in: 0.55...0.65))
        if ramHistory.count > 20 { ramHistory.removeFirst() }
        aneHistory.append(Double.random(in: 0.02...0.15))
        if aneHistory.count > 20 { aneHistory.removeFirst() }
    }
}

struct CPUItem {
    let label: String
    var value: Double
    let color: Color
}

#Preview {
    EonPreviewContainer {
        ScrollView { ResourceView() }
            .background(Color(hex: "#07050F"))
    }
}
