import SwiftUI
import Darwin
import UIKit
import Combine

// MARK: - FullLogView
// Öppnas via tryck på hjärnan i hemvyn.
// Visar live-kognition, termisk snapshot var 30s, CPU/RAM/GPU och all övrig körtidsinfo.

struct FullLogView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.dismiss) private var dismiss

    @StateObject private var monitor = FullLogMonitor()
    @State private var copyDone = false
    @State private var autoScroll = true
    @State private var showHistory = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#050310").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(Color.white.opacity(0.06))
                // Tab-väljare: Live / Historik
                tabPicker
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Divider().background(Color.white.opacity(0.06))

                if showHistory {
                    SessionHistoryView()
                } else {
                    liveMetricsBar
                    Divider().background(Color.white.opacity(0.06))
                    logScroll
                }
                bottomBar
            }
        }
        .onAppear { monitor.start(brain: brain) }
        .onDisappear { monitor.stop() }
    }

    var tabPicker: some View {
        HStack(spacing: 0) {
            tabBtn("Live", icon: "waveform", selected: !showHistory) {
                withAnimation(.easeInOut(duration: 0.2)) { showHistory = false }
            }
            tabBtn("Körningshistorik", icon: "clock.arrow.circlepath", selected: showHistory) {
                withAnimation(.easeInOut(duration: 0.2)) { showHistory = true }
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabBtn(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.4))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color(hex: "#A78BFA").opacity(0.2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#A78BFA"))
            VStack(alignment: .leading, spacing: 1) {
                Text("FULL-LOG")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(2)
                Text("\(monitor.entries.count) poster · uppdateras live")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
            // Auto-scroll toggle
            Button {
                withAnimation { autoScroll.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 13))
                    Text(autoScroll ? "Auto" : "Manuell")
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundStyle(autoScroll ? Color(hex: "#34D399") : .white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - Live metrics bar (uppdateras varje sekund via monitor)

    var liveMetricsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                metricChip("CPU", value: String(format: "%.1f%%", monitor.cpu * 100),
                           color: cpuColor(monitor.cpu), icon: "cpu")
                metricChip("RAM", value: String(format: "%.0f MB", monitor.ramMB),
                           color: ramColor(monitor.ramMB), icon: "memorychip")
                metricChip("RAM%", value: String(format: "%.1f%%", monitor.ramPercent * 100),
                           color: ramColor(monitor.ramMB), icon: "memorychip.fill")
                metricChip("GPU", value: String(format: "%.0f%%", monitor.gpuPercent * 100),
                           color: Color(hex: "#F472B6"), icon: "rectangle.3.group")
                metricChip("Termisk", value: monitor.thermalLabel,
                           color: monitor.thermalColor, icon: "thermometer.medium")
                metricChip("Batteri", value: monitor.batteryString,
                           color: Color(hex: "#34D399"), icon: "battery.75percent")
                metricChip("Läge", value: monitor.perfModeLabel,
                           color: Color(hex: "#A78BFA"), icon: "slider.horizontal.3")
                metricChip("II", value: String(format: "%.3f", monitor.integratedIntelligence),
                           color: Color(hex: "#38BDF8"), icon: "brain")
                metricChip("Tankar", value: "\(monitor.monologueCount)",
                           color: Color(hex: "#7C3AED"), icon: "thought.bubble")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.white.opacity(0.02))
    }

    private func metricChip(_ label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.2), lineWidth: 0.5))
    }

    // MARK: - Log scroll

    var logScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(monitor.entries) { entry in
                        logRow(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: monitor.entries.count) { _, _ in
                if autoScroll, let last = monitor.entries.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func logRow(_ entry: FullLogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Tidsstämpel
            Text(entry.timeString)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.22))
                .frame(width: 56, alignment: .leading)
                .padding(.top, 2)

            // Typ-badge
            Text(entry.category.rawValue)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(entry.category.color)
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(entry.category.color.opacity(0.12)))
                .frame(width: 62, alignment: .center)
                .padding(.top, 1)

            // Innehåll
            Text(entry.text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(entry.category.textColor)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(entry.category == .snapshot ? Color.white.opacity(0.025) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            entry.category == .snapshot
            ? RoundedRectangle(cornerRadius: 6).strokeBorder(entry.category.color.opacity(0.15), lineWidth: 0.4)
            : nil
        )
        .padding(.bottom, entry.category == .snapshot ? 4 : 0)
    }

    // MARK: - Bottom bar

    var bottomBar: some View {
        HStack(spacing: 12) {
            if !showHistory {
                Button {
                    let text = monitor.entries.map { "[\($0.timeString)] [\($0.category.rawValue)] \($0.text)" }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                    withAnimation { copyDone = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copyDone = false }
                    }
                } label: {
                    Label(copyDone ? "Kopierat!" : "Kopiera live", systemImage: copyDone ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(copyDone ? Color(hex: "#34D399") : .white.opacity(0.75))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)

                Button { monitor.clear() } label: {
                    Label("Rensa", systemImage: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(hex: "#EF4444").opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { dismiss() } label: {
                Label("Stäng", systemImage: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color(hex: "#A78BFA").opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Color helpers

    private func cpuColor(_ v: Double) -> Color {
        if v > 0.7 { return Color(hex: "#EF4444") }
        if v > 0.45 { return Color(hex: "#F59E0B") }
        return Color(hex: "#34D399")
    }

    private func ramColor(_ mb: Double) -> Color {
        if mb > 500 { return Color(hex: "#EF4444") }
        if mb > 300 { return Color(hex: "#F59E0B") }
        return Color(hex: "#38BDF8")
    }
}

// MARK: - FullLogEntry

struct FullLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let category: LogCategory
    let text: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    enum LogCategory: String {
        case thought   = "TANKE"
        case loop      = "LOOP"
        case revision  = "REVISION"
        case memory    = "MINNE"
        case insight   = "INSIKT"
        case snapshot  = "SNAPSHOT"
        case system    = "SYSTEM"
        case warning   = "VARNING"

        var color: Color {
            switch self {
            case .thought:  return Color(hex: "#A78BFA")
            case .loop:     return Color(hex: "#38BDF8")
            case .revision: return Color(hex: "#F59E0B")
            case .memory:   return Color(hex: "#34D399")
            case .insight:  return Color(hex: "#F472B6")
            case .snapshot: return Color(hex: "#7C3AED")
            case .system:   return Color(hex: "#6B7280")
            case .warning:  return Color(hex: "#EF4444")
            }
        }

        var textColor: Color {
            switch self {
            case .snapshot: return .white.opacity(0.8)
            case .warning:  return Color(hex: "#FCA5A5")
            default:        return .white.opacity(0.65)
            }
        }
    }
}

// MARK: - FullLogMonitor

@MainActor
final class FullLogMonitor: ObservableObject {
    @Published var entries: [FullLogEntry] = []
    @Published var cpu: Double = 0
    @Published var ramMB: Double = 0
    @Published var ramPercent: Double = 0
    @Published var gpuPercent: Double = 0
    @Published var thermalLabel: String = "Nominal"
    @Published var thermalColor: Color = Color(hex: "#34D399")
    @Published var batteryString: String = "N/A"
    @Published var perfModeLabel: String = "Auto"
    @Published var integratedIntelligence: Double = 0
    @Published var monologueCount: Int = 0

    private var metricTimer: Timer?
    private var snapshotTimer: Timer?
    private var monologueCancellable: AnyCancellable?
    private var lastMonologueCount = 0
    private weak var brain: EonBrain?

    private let totalRAMMB: Double = {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576.0
    }()

    func start(brain: EonBrain) {
        self.brain = brain
        let startMsg = "Full-log startad · Enhet: \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion) · RAM: \(Int(Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576)) MB"
        appendEntry(FullLogEntry(date: Date(), category: .system, text: startMsg))

        // Metrics var 1s
        metricTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateMetrics() }
        }
        metricTimer?.fire()

        // Termisk snapshot var 30s
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.appendSnapshot() }
        }
        appendSnapshot()

        // Monolog-observer
        monologueCancellable = brain.$innerMonologue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lines in
                guard let self else { return }
                guard lines.count > self.lastMonologueCount else { return }
                let newLines = lines.suffix(lines.count - self.lastMonologueCount)
                self.lastMonologueCount = lines.count
                self.monologueCount = lines.count
                for line in newLines {
                    let cat: FullLogEntry.LogCategory
                    switch line.type {
                    case .thought:     cat = .thought
                    case .loopTrigger: cat = .loop
                    case .revision:    cat = .revision
                    case .memory:      cat = .memory
                    case .insight:     cat = .insight
                    }
                    self.appendEntry(FullLogEntry(date: Date(), category: cat, text: line.text))
                }
            }
    }

    func stop() {
        metricTimer?.invalidate()
        snapshotTimer?.invalidate()
        monologueCancellable?.cancel()
    }

    func clear() {
        entries.removeAll()
        lastMonologueCount = 0
        appendEntry(FullLogEntry(date: Date(), category: .system, text: "Logg rensad av användaren"))
    }

    // Centralt tillägg: skriver till UI-listan OCH direkt till disk
    private func appendEntry(_ entry: FullLogEntry) {
        entries.append(entry)
        trimIfNeeded()
        RunSessionLogger.shared.log(entry.text, category: entry.category.rawValue)
    }

    // MARK: - Metrics

    private func updateMetrics() {
        cpu = readCPU()
        ramMB = readRAMMB()
        ramPercent = totalRAMMB > 0 ? ramMB / totalRAMMB : 0
        gpuPercent = estimateGPU()
        let thermal = ProcessInfo.processInfo.thermalState
        thermalLabel = thermalString(thermal)
        thermalColor = thermalColorValue(thermal)
        let batt = UIDevice.current.batteryLevel
        batteryString = batt >= 0 ? String(format: "%.0f%%", batt * 100) : "N/A"
        let mode = PerformanceMode(rawValue: UserDefaults.standard.integer(forKey: "eon_performance_mode")) ?? .auto
        perfModeLabel = CyclingModeEngine.shared.effectiveMode(base: mode).displayName
        integratedIntelligence = CognitiveState.shared.integratedIntelligence
        monologueCount = brain?.innerMonologue.count ?? 0

        // Logga varning om hög CPU
        if cpu > 0.70 {
            let msg = String(format: "CPU KRITISK: %.1f%% · Termisk: %@ · Läge: %@", cpu * 100, thermalLabel, perfModeLabel)
            if entries.last?.text != msg {
                appendEntry(FullLogEntry(date: Date(), category: .warning, text: msg))
            }
        }
    }

    // MARK: - Snapshot var 30s

    private func appendSnapshot() {
        let cpuNow = readCPU()
        let ramNow = readRAMMB()
        let ramPct = totalRAMMB > 0 ? ramNow / totalRAMMB * 100 : 0
        let gpuNow = estimateGPU()
        let thermal = ProcessInfo.processInfo.thermalState
        let batt = UIDevice.current.batteryLevel
        let battStr = batt >= 0 ? String(format: "%.0f%%", batt * 100) : "N/A"
        let mode = PerformanceMode(rawValue: UserDefaults.standard.integer(forKey: "eon_performance_mode")) ?? .auto
        let effectiveMode = CyclingModeEngine.shared.effectiveMode(base: mode)
        let ii = CognitiveState.shared.integratedIntelligence
        let thoughts = brain?.innerMonologue.count ?? 0
        let knowledgeNodes = brain?.knowledgeNodeCount ?? 0
        let devProgress = String(format: "%.1f%%", (brain?.developmentalProgress ?? 0) * 100)

        let text = """
        ── SNAPSHOT ─────────────────────────────────────
        CPU:       \(String(format: "%.1f%%", cpuNow * 100))   \(cpuBar(cpuNow))
        RAM:       \(String(format: "%.0f MB", ramNow)) / \(String(format: "%.0f MB", totalRAMMB)) (\(String(format: "%.1f%%", ramPct)))
        GPU (est): \(String(format: "%.0f%%", gpuNow * 100))
        Termisk:   \(thermalString(thermal))  \(thermalEmoji(thermal))
        Batteri:   \(battStr)
        Läge:      \(mode.displayName) → effektivt: \(effectiveMode.displayName)
        II:        \(String(format: "%.4f", ii))
        Tankar:    \(thoughts)  Kunskapsnoder: \(knowledgeNodes)
        Utveckling:\(devProgress)
        ─────────────────────────────────────────────────
        """

        appendEntry(FullLogEntry(date: Date(), category: .snapshot, text: text))

        // Skriv strukturerad snapshot direkt till disk
        RunSessionLogger.shared.logSnapshot(
            cpu: cpuNow, ramMB: ramNow, ramPct: totalRAMMB > 0 ? ramNow / totalRAMMB : 0,
            gpu: gpuNow, thermal: thermalString(thermal) + " " + thermalEmoji(thermal),
            battery: battStr, mode: "\(mode.displayName) → \(effectiveMode.displayName)",
            ii: ii, thoughts: thoughts, knowledgeNodes: knowledgeNodes,
            devProgress: brain?.developmentalProgress ?? 0
        )
    }

    // MARK: - System reads

    private func readCPU() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let list = threadList else { return 0 }
        var total: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
            let r = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(list[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }
            if r == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE)
            }
        }
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list),
                      vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
        return min(total, 1.0)
    }

    private func readRAMMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576.0
    }

    // GPU estimeras via termisk + CPU-last (ingen direkt iOS API)
    private func estimateGPU() -> Double {
        let thermal = ProcessInfo.processInfo.thermalState
        let cpuLoad = cpu
        // SwiftUI-rendering + partikelsystem bidrar till GPU-last
        // Uppskattning baserad på aktivitet och termisk status
        let base: Double
        switch thermal {
        case .nominal:  base = 0.05
        case .fair:     base = 0.15
        case .serious:  base = 0.30
        case .critical: base = 0.45
        @unknown default: base = 0.05
        }
        return min(base + cpuLoad * 0.25, 1.0)
    }

    // MARK: - Helpers

    private func thermalString(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal:  return "Nominal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Okänd"
        }
    }

    private func thermalEmoji(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal:  return "✅"
        case .fair:     return "🟡"
        case .serious:  return "🔴"
        case .critical: return "🚨"
        @unknown default: return "❓"
        }
    }

    private func thermalColorValue(_ s: ProcessInfo.ThermalState) -> Color {
        switch s {
        case .nominal:  return Color(hex: "#34D399")
        case .fair:     return Color(hex: "#F59E0B")
        case .serious:  return Color(hex: "#EF4444")
        case .critical: return Color(hex: "#DC2626")
        @unknown default: return Color(hex: "#6B7280")
        }
    }

    private func cpuBar(_ v: Double) -> String {
        let filled = Int(v * 20)
        let empty = 20 - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }

    private func trimIfNeeded() {
        if entries.count > 2000 { entries.removeFirst(entries.count - 2000) }
    }
}
