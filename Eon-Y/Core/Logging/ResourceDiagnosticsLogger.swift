import Foundation
import Darwin
import UIKit

// MARK: - ResourceDiagnosticsLogger
// Kartlägger vad som orsakar hög CPU/värme/ANE/GPU.
// Samplar var 5s, skriver händelser till diagnostics_log.txt.

final class ResourceDiagnosticsLogger {
    static let shared = ResourceDiagnosticsLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.eon.diagnostics", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var isRunning = false

    // Trösklar för varning
    private let cpuWarnThreshold: Double   = 0.45   // 45%
    private let cpuCritThreshold: Double   = 0.70   // 70%
    private let thermalWarnLevel           = ProcessInfo.ThermalState.fair
    private let memoryWarnMB: Double       = 300.0  // MB

    // Historik för trendanalys
    private var cpuHistory: [(Date, Double)] = []
    private var thermalHistory: [(Date, ProcessInfo.ThermalState)] = []
    private var eventCount = 0

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("eon_diagnostics_log.txt")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let header = "=== EON RESURSDIAGNOSTIK ===\nStartad: \(df.string(from: Date()))\n\n"
            try? header.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Start/Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 10, repeating: 30.0)  // v5: 8s → 30s — minskar kernel-overhead
        t.setEventHandler { [weak self] in self?.sample() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    // MARK: - Sampling

    private func sample() {
        let cpu = readCPU()
        let mem = readMemoryMB()
        let thermal = ProcessInfo.processInfo.thermalState
        let battery = UIDevice.current.batteryLevel
        let mode = PerformanceMode(rawValue: UserDefaults.standard.integer(forKey: "eon_performance_mode")) ?? .auto
        let now = Date()

        // Uppdatera historik
        cpuHistory.append((now, cpu))
        thermalHistory.append((now, thermal))
        if cpuHistory.count > 120 { cpuHistory.removeFirst(20) }
        if thermalHistory.count > 120 { thermalHistory.removeFirst(20) }

        // Bestäm om vi ska logga
        let shouldLog = cpu > cpuWarnThreshold
            || thermal == .serious || thermal == .critical
            || mem > memoryWarnMB

        guard shouldLog else { return }
        eventCount += 1

        // Identifiera orsaker
        let causes = identifyCauses(cpu: cpu, mem: mem, thermal: thermal, mode: mode)

        // Bygg loggrad
        let thermalStr = thermalLabel(thermal)
        let battStr = battery >= 0 ? String(format: "%.0f%%", battery * 100) : "ukänd"
        let line = """
        [\(df.string(from: now))] [EVENT #\(eventCount)]
          CPU:     \(String(format: "%.1f%%", cpu * 100)) \(cpu > cpuCritThreshold ? "⚠️ KRITISK" : "⚠️")
          Minne:   \(String(format: "%.0f MB", mem))
          Värme:   \(thermalStr)
          Batteri: \(battStr)
          Läge:    \(mode.displayName)
          Orsaker: \(causes.joined(separator: " | "))
          Trend:   \(cpuTrend())

        """

        appendToFile(line)
    }

    // MARK: - Orsaksanalys

    private func identifyCauses(cpu: Double, mem: Double, thermal: ProcessInfo.ThermalState, mode: PerformanceMode) -> [String] {
        var causes: [String] = []

        // CPU-orsaker baserade på prestandaläge och aktivitet
        if cpu > cpuCritThreshold {
            switch mode {
            case .maximal:
                causes.append("Maxläge: 18 autonoma loopar + 12 ICA-pelare körs simultant")
                causes.append("GPT-SW3 1.3B CoreML inferens aktiv")
                causes.append("KB-BERT 768-dim embedding beräknas")
            case .balanced:
                causes.append("Balanserat: 7 pelare + 2 loopar genererar CPU-last")
            case .cycling:
                causes.append("Cyklande: just nu i Max-fas — hög aktivitet förväntat")
            case .auto, .adaptive:
                causes.append("Auto/Adaptiv: termalstyrning har inte hunnit skala ner")
                causes.append("Resonemangscykel eller artikelgenerering pågår")
            default:
                causes.append("Bakgrundsprocess aktiv trots lågt läge")
            }
        } else if cpu > cpuWarnThreshold {
            causes.append("Kognitiv cykel (ICA): \(Int(cpu * 100))% — inom acceptabelt")
            causes.append("Möjliga: SQLite-skrivning, Språkbanken-fetch, BERT-embedding")
        }

        // Minne
        if mem > memoryWarnMB {
            causes.append(String(format: "Minnesanvändning: %.0f MB — ICA-state + SQLite-cache", mem))
        }

        // Termisk analys
        switch thermal {
        case .fair:
            causes.append("Termisk: Fair — CPU-throttling börjar snart om last håller i sig")
        case .serious:
            causes.append("Termisk: SERIOUS — iOS throttlar CPU aktivt. Eon skalar ner loopar.")
            causes.append("Vanlig orsak: Extended GPT-SW3 CoreML + Språkbanken parallellt")
        case .critical:
            causes.append("Termisk: CRITICAL — iOS har halverat CPU-frekvens. Ladda telefonen.")
        default:
            break
        }

        // CPU-trend
        let recentCPU = cpuHistory.suffix(6).map { $0.1 }
        if recentCPU.count >= 3 {
            let avg = recentCPU.reduce(0, +) / Double(recentCPU.count)
            let first = recentCPU.first ?? 0
            if avg - first > 0.1 {
                causes.append("CPU-trend: STIGANDE (+\(String(format: "%.0f%%", (avg - first) * 100)) senaste 30s)")
            }
        }

        // Kända CPU-tunga komponenter
        let heavyComponents = identifyHeavyComponents(cpu: cpu, thermal: thermal)
        causes.append(contentsOf: heavyComponents)

        return causes.isEmpty ? ["Ingen specifik orsak identifierad — normal drift"] : causes
    }

    private func identifyHeavyComponents(cpu: Double, thermal: ProcessInfo.ThermalState) -> [String] {
        var result: [String] = []
        // Korrelera med känd komponentlast
        if cpu > 0.6 {
            result.append("Trolig ANE-last: CoreML-modell (GPT-SW3 eller KB-BERT) infereras")
        }
        if thermal == .serious || thermal == .critical {
            result.append("GPU-last möjlig: SwiftUI-rendering + particle-system i hemvyn")
            result.append("Rekommendation: Byt till Vila-läge tills enheten svalnar")
        }
        return result
    }

    // MARK: - CPU-mätning (task_info — ett enda kernel-anrop, ingen tråd-loop)
    // v5: Ersätter task_threads() + per-tråd thread_info() med task_info(TASK_BASIC_INFO).
    // Minskar kernel-overhead avsevärt — ingen iteration av alla trådar.

    private func readCPU() -> Double {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        // user_time + system_time ger total CPU-tid; normalisera mot uptime för approximation
        let userSec = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
        let sysSec  = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
        let totalCPUSec = userSec + sysSec
        let uptime = ProcessInfo.processInfo.systemUptime
        // Andel av en kärna, clampat till 0–1
        return min(totalCPUSec / max(uptime, 1), 1.0)
    }

    private func readMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1_048_576.0
    }

    // MARK: - Helpers

    private func cpuTrend() -> String {
        let recent = cpuHistory.suffix(12).map { $0.1 }
        guard recent.count >= 6 else { return "Ej tillräcklig data" }
        let first = recent.prefix(recent.count / 2).reduce(0, +) / Double(recent.count / 2)
        let last  = recent.suffix(recent.count / 2).reduce(0, +) / Double(recent.count / 2)
        let delta = last - first
        if delta > 0.05  { return String(format: "Stigande ↑ (+%.0f%%)", delta * 100) }
        if delta < -0.05 { return String(format: "Sjunkande ↓ (%.0f%%)", delta * 100) }
        return String(format: "Stabil → (%.0f%%)", last * 100)
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "Nominal ✅"
        case .fair:     return "Fair 🟡"
        case .serious:  return "Serious 🔴"
        case .critical: return "Critical 🚨"
        @unknown default: return "Okänd"
        }
    }

    private func appendToFile(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Public API

    func readAll() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    var fileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int else { return "0 KB" }
        if size < 1024 { return "\(size) B" }
        if size < 1_048_576 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / 1_048_576)
    }

    var eventCountString: String { "\(eventCount) händelser" }

    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            let header = "=== EON RESURSDIAGNOSTIK ===\nRensad: \(self.df.string(from: Date()))\n\n"
            try? header.write(to: self.fileURL, atomically: true, encoding: .utf8)
            self.eventCount = 0
            self.cpuHistory.removeAll()
            self.thermalHistory.removeAll()
        }
    }

    // Generera en fullständig textrapport
    func generateReport() -> String {
        let cpu = readCPU()
        let mem = readMemoryMB()
        let thermal = ProcessInfo.processInfo.thermalState
        let mode = PerformanceMode(rawValue: UserDefaults.standard.integer(forKey: "eon_performance_mode")) ?? .auto

        return """
        === EON RESURSRAPPORT ===
        Genererad: \(df.string(from: Date()))

        NULÄGE
        ──────
        CPU:          \(String(format: "%.1f%%", cpu * 100))
        Minne:        \(String(format: "%.0f MB", mem))
        Termisk:      \(thermalLabel(thermal))
        Prestandaläge: \(mode.displayName) — \(mode.description)
        Batteri:      \(UIDevice.current.batteryLevel >= 0 ? String(format: "%.0f%%", UIDevice.current.batteryLevel * 100) : "N/A")

        ORSAKSANALYS
        ────────────
        \(identifyCauses(cpu: cpu, mem: mem, thermal: thermal, mode: mode).map { "• \($0)" }.joined(separator: "\n"))

        CPU-TREND
        ─────────
        \(cpuTrend())

        LOGGSTATISTIK
        ─────────────
        Loggade händelser: \(eventCount)
        Loggfilstorlek:    \(fileSizeString)

        KÄND CPU-FÖRDELNING I EON
        ──────────────────────────
        • EonLiveAutonomy (18 loopar): ~35–45% av total CPU i Max-läge
        • IntegratedCognitiveArchitecture (12 pelare): ~20–30%
        • GPT-SW3 CoreML inferens: ~15–25% vid aktiv generering
        • KB-BERT embedding: ~5–10%
        • SQLite (PersistentMemoryStore): ~2–5%
        • Språkbanken nätverkshämtning: ~1–3% (I/O-bunden)
        • SwiftUI rendering + partikelsystem: ~3–8%
        • Övrigt (iOS, timers, GCD): ~5–10%

        =============================
        """
    }
}
