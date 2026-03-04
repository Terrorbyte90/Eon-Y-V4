import Foundation

// MARK: - CognitionLogger
// Skriver varje monolog-rad till en lokal textfil på enheten.
// Filen är tillgänglig via CognitionLogView i inställningar.

final class CognitionLogger {
    static let shared = CognitionLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.eon.cognitionlogger", qos: .background)
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "sv_SE")
        return f
    }()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        fileURL = docs.appendingPathComponent("eon_cognition_log.txt")
        // Skapa filen om den inte finns
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let header = "=== EON KOGNITIONSLOGG ===\nStartad: \(dateFormatter.string(from: Date()))\n\n"
            try? header.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    // Convenience alias — används av ConsciousnessEngine och andra system
    func log(_ text: String, type: String = "TANKE") {
        append(text: text, type: type)
    }

    // Lägg till en rad i loggen (asynkront, blockerar inte UI)
    func append(text: String, type: String = "TANKE") {
        queue.async { [weak self] in
            guard let self else { return }
            let timestamp = self.dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(type)] \(text)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: self.fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                // Filen saknas — skapa om
                try? line.write(to: self.fileURL, atomically: true, encoding: .utf8)
            }
        }
    }

    // Läs hela loggen (synkront, kör på bakgrundstråd från anroparen)
    func readAll() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    // Filens URL (för delning etc.)
    var logFileURL: URL { fileURL }

    // Filstorlek som läsbar sträng
    var fileSizeString: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int else { return "0 KB" }
        if size < 1024 { return "\(size) B" }
        if size < 1_048_576 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / 1_048_576)
    }

    // Rensa loggen
    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            let header = "=== EON KOGNITIONSLOGG ===\nRensad: \(self.dateFormatter.string(from: Date()))\n\n"
            try? header.write(to: self.fileURL, atomically: true, encoding: .utf8)
        }
    }
}
