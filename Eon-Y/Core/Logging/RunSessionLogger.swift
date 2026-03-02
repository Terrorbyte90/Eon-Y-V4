import Foundation
import UIKit

// MARK: - RunSessionLogger
//
// Skriver körningsloggar direkt till disk med FileHandle (ingen buffring).
// Varje appstart skapar en ny sessionsfil: run_YYYY-MM-DD_HH-mm-ss.log
// De senaste 5 sessionerna bevaras — äldre raderas automatiskt.
//
// Crash-säker: varje rad skrivs atomärt med write() — om appen kraschar
// finns allt som hann skrivas kvar på disk.

final class RunSessionLogger {
    static let shared = RunSessionLogger()

    private let logsDir: URL
    private var currentSessionURL: URL?
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.eon.runsession", qos: .utility)
    private let maxSessions = 5

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private let sessionDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private let displayDF: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logsDir = docs.appendingPathComponent("run_sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    // MARK: - Session management

    func startNewSession() {
        queue.async { [weak self] in
            guard let self else { return }

            // Stäng eventuell gammal session
            self.closeCurrentSession()

            // Skapa ny sessionsfil
            let name = "run_\(self.sessionDF.string(from: Date())).log"
            let url = self.logsDir.appendingPathComponent(name)
            FileManager.default.createFile(atPath: url.path, contents: nil)

            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            self.currentSessionURL = url
            self.fileHandle = handle

            // Skriv session-header
            let device = UIDevice.current
            let header = """
            ╔══════════════════════════════════════════════════════════════╗
            ║  EON-Y KÖRNINGSLOGG
            ║  Session:  \(self.displayDF.string(from: Date()))
            ║  Enhet:    \(device.model) · iOS \(device.systemVersion)
            ║  RAM:      \(Int(Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576)) MB
            ╚══════════════════════════════════════════════════════════════╝

            """
            self.writeLine(header)

            // Rensa gamla sessioner
            self.pruneOldSessions()
        }
    }

    func closeCurrentSession() {
        guard let handle = fileHandle else { return }
        let footer = "\n[SESSION AVSLUTAD: \(displayDF.string(from: Date()))]\n"
        if let data = footer.data(using: .utf8) {
            handle.write(data)
        }
        try? handle.close()
        fileHandle = nil
        currentSessionURL = nil
    }

    // MARK: - Logging (crash-säker: skrivs direkt till disk)

    func log(_ text: String, category: String = "SYS") {
        queue.async { [weak self] in
            guard let self, self.fileHandle != nil else { return }
            let ts = self.df.string(from: Date())
            let line = "[\(ts)] [\(category)] \(text)\n"
            self.writeLine(line)
        }
    }

    func logSnapshot(cpu: Double, ramMB: Double, ramPct: Double,
                     gpu: Double, thermal: String, battery: String,
                     mode: String, ii: Double, thoughts: Int,
                     knowledgeNodes: Int, devProgress: Double) {
        queue.async { [weak self] in
            guard let self else { return }
            let ts = self.df.string(from: Date())
            let bar = self.cpuBar(cpu)
            let snap = """
            [\(ts)] [SNAPSHOT]
              CPU:       \(String(format: "%.1f%%", cpu * 100))  \(bar)
              RAM:       \(String(format: "%.0f MB", ramMB)) (\(String(format: "%.1f%%", ramPct * 100)))
              GPU (est): \(String(format: "%.0f%%", gpu * 100))
              Termisk:   \(thermal)
              Batteri:   \(battery)
              Läge:      \(mode)
              II:        \(String(format: "%.4f", ii))
              Tankar:    \(thoughts)  Noder: \(knowledgeNodes)
              Utveckling:\(String(format: "%.1f%%", devProgress * 100))

            """
            self.writeLine(snap)
        }
    }

    // MARK: - Session list & reading

    /// Alla sessionsfiler sorterade nyast först
    func allSessions() -> [SessionInfo] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: logsDir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        return files
            .filter { $0.lastPathComponent.hasPrefix("run_") && $0.pathExtension == "log" }
            .compactMap { url -> SessionInfo? in
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = (attrs?[.size] as? Int) ?? 0
                let created = (attrs?[.creationDate] as? Date) ?? Date()
                let isCurrent = url == currentSessionURL
                return SessionInfo(url: url, created: created, size: size, isCurrent: isCurrent)
            }
            .sorted { $0.created > $1.created }
    }

    func readSession(_ info: SessionInfo) -> String {
        (try? String(contentsOf: info.url, encoding: .utf8)) ?? "(Kunde inte läsa filen)"
    }

    /// Sammanfogar alla sessionsfilers innehåll till en sträng (för UnifiedLogView)
    func allSessionsContent() -> String {
        allSessions()
            .map { "=== Session: \($0.displayName) ===\n\(readSession($0))" }
            .joined(separator: "\n\n")
    }

    func deleteSession(_ info: SessionInfo) {
        guard !info.isCurrent else { return }
        try? FileManager.default.removeItem(at: info.url)
    }

    // MARK: - Private helpers

    private func writeLine(_ text: String) {
        guard let handle = fileHandle,
              let data = text.data(using: .utf8) else { return }
        handle.write(data)
    }

    private func pruneOldSessions() {
        let sessions = allSessions().filter { !$0.isCurrent }
        if sessions.count > maxSessions - 1 {
            let toDelete = sessions.dropFirst(maxSessions - 1)
            for s in toDelete {
                try? FileManager.default.removeItem(at: s.url)
            }
        }
    }

    private func cpuBar(_ v: Double) -> String {
        let filled = Int(min(v, 1.0) * 20)
        let empty = 20 - filled
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: empty) + "]"
    }
}

// MARK: - SessionInfo

struct SessionInfo: Identifiable {
    let id = UUID()
    let url: URL
    let created: Date
    let size: Int
    let isCurrent: Bool

    var displayName: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: created)
    }

    var sizeString: String {
        if size < 1024 { return "\(size) B" }
        if size < 1_048_576 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / 1_048_576)
    }
}
