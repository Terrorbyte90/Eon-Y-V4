import Foundation
import Combine

// MARK: - GeminiArticleService
// Genererar artiklar via Gemini API.
// PRIVACY: Skickar ALDRIG användardata, konversationer, profiler eller annan
// appdata till Gemini. Enda information som skickas är:
//   1. Önskad kategori (t.ex. "Historia")
//   2. Instruktioner om artikelformat och längd
//   3. Källa-krav
// Ingen identifierbar information lämnar enheten.

@MainActor
final class GeminiArticleService: ObservableObject {
    static let shared = GeminiArticleService()

    @Published var isGenerating = false
    @Published var lastError: String? = nil
    @Published var lastGeneratedAt: Date? = nil
    @Published var generationLog: [GeminiLogEntry] = []

    private let apiBase = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    private var schedulerTask: Task<Void, Never>? = nil

    private init() {}

    // MARK: - Starta/stoppa schemalagd generering

    func startScheduler(viewModel: KnowledgeViewModel) {
        stopScheduler()
        let settings = GeminiSettings.load()
        guard settings.isEnabled, !settings.apiKey.isEmpty else { return }

        schedulerTask = Task(priority: .background) {
            while !Task.isCancelled {
                let intervalNs = UInt64(settings.intervalMinutes * 60) * 1_000_000_000
                try? await Task.sleep(nanoseconds: intervalNs)
                guard !Task.isCancelled else { break }
                let current = GeminiSettings.load()
                guard current.isEnabled, !current.apiKey.isEmpty else { break }
                await self.generateArticle(viewModel: viewModel, settings: current)
            }
        }
    }

    func stopScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    func restartSchedulerIfNeeded(viewModel: KnowledgeViewModel) {
        stopScheduler()
        let settings = GeminiSettings.load()
        if settings.isEnabled && !settings.apiKey.isEmpty {
            startScheduler(viewModel: viewModel)
        }
    }

    // MARK: - Generera en artikel

    func generateArticle(viewModel: KnowledgeViewModel, settings: GeminiSettings) async {
        guard !isGenerating else { return }
        guard !settings.apiKey.isEmpty else {
            lastError = "Ingen API-nyckel angiven."
            return
        }

        isGenerating = true
        lastError = nil

        // Välj kategori med minst artiklar
        let targetCategory = leastPopulatedCategory(articles: viewModel.articles)
        let isFlashback = targetCategory == "Flashback"

        let prompt = isFlashback
            ? buildFlashbackPrompt()
            : buildArticlePrompt(category: targetCategory)

        let logEntry = GeminiLogEntry(
            category: targetCategory,
            status: .generating,
            startedAt: Date()
        )
        generationLog.insert(logEntry, at: 0)
        if generationLog.count > 50 { generationLog.removeLast(10) }

        do {
            let text = try await callGeminiAPI(prompt: prompt, apiKey: settings.apiKey)
            let article = parseArticle(from: text, category: targetCategory)

            await viewModel.addArticle(
                title: article.title,
                content: article.content,
                source: article.sources,
                domain: "Eon"
            )

            lastGeneratedAt = Date()
            updateLog(id: logEntry.id, status: .success, title: article.title)
        } catch {
            lastError = error.localizedDescription
            updateLog(id: logEntry.id, status: .failed, title: error.localizedDescription)
        }

        isGenerating = false
    }

    // MARK: - Välj kategori med minst artiklar

    private func leastPopulatedCategory(articles: [KnowledgeArticle]) -> String {
        let categories = KnowledgeCategory.all.map { $0.name }.filter { $0 != "Eon" }
        var counts: [String: Int] = [:]
        for cat in categories { counts[cat] = 0 }
        for article in articles {
            counts[article.domain, default: 0] += 1
        }
        return counts.min(by: { $0.value < $1.value })?.key ?? categories.first ?? "Historia"
    }

    // MARK: - Prompts (INGEN användardata inkluderas)

    private func buildArticlePrompt(category: String) -> String {
        """
        Du är en faktabaserad encyklopedisk skribent. Skriv en djupgående artikel inom kategorin "\(category)".

        KRAV PÅ ARTIKELN:
        - Välj ett intressant, specifikt ämne inom kategorin
        - Längd: minst 500 ord i brödtext (motsvarar en A4-sida i Word)
        - Språk: svenska
        - Ton: saklig, informativ, engagerande — som en välskriven Wikipedia-artikel
        - Dela upp texten i tydliga stycken separerade med tomrad
        - Inga personliga åsikter eller spekulationer utan tydlig markering
        - Inga hänvisningar till AI, chatbots eller denna instruktion
        - Minst 3 verifierbara källor

        EXAKT FORMAT — avvik inte från detta:
        TITEL: [Artikelns rubrik]
        SAMMANFATTNING: [1–2 meningar som sammanfattar artikeln]
        INNEHÅLL:
        [Artikelns fullständiga text. Separera stycken med en tom rad. Börja varje stycke i kolumn 0, utan indragning.]
        KÄLLOR:
        [Källa 1: Titel, Författare/Organisation, År]; [Källa 2: Titel, Författare/Organisation, År]; [Källa 3: ...]

        Viktigt: Skriv ALLA källor på EN rad, separerade med semikolon (;). Inga bindestreck eller punktlistor.

        Skriv artikeln nu.
        """
    }

    private func buildFlashbackPrompt() -> String {
        """
        Du är en neutral, faktabaserad sammanfattare av internetdiskussioner.

        Skriv en sammanfattning av en känd eller typisk tråd från det svenska diskussionsforumet Flashback.
        Välj ett ämne som faktiskt diskuterats på Flashback (kontroversiellt, samhällsdebatt, brott, skandaler etc.).

        KRAV:
        - Presentera ämnet objektivt utan att ta ställning
        - Beskriv vad som diskuterades, vilka perspektiv som lyftes och hur tråden utvecklades
        - Längd: minst 500 ord (motsvarar en A4-sida i Word)
        - Språk: svenska
        - Inga personliga åsikter
        - Inga namn på privatpersoner som inte är offentliga figurer
        - Dela upp texten i tydliga stycken separerade med tomrad

        EXAKT FORMAT — avvik inte från detta:
        TITEL: [Rubrik som beskriver trådens ämne]
        SAMMANFATTNING: [1–2 meningar]
        INNEHÅLL:
        [Sammanfattningen. Separera stycken med en tom rad. Börja varje stycke i kolumn 0, utan indragning.]
        KÄLLOR:
        Flashback Forum (flashback.org); [Eventuell extern källa 1]; [Eventuell extern källa 2]

        Viktigt: Skriv ALLA källor på EN rad, separerade med semikolon (;). Inga bindestreck eller punktlistor.

        Skriv sammanfattningen nu.
        """
    }

    // MARK: - Gemini API-anrop

    private func callGeminiAPI(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(apiBase)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 2048,
                "topP": 0.9
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw GeminiError.apiError("Kvotgräns nådd — försök igen om en stund. Free tier tillåter begränsat antal anrop per dag.")
            }
            if httpResponse.statusCode == 400 {
                throw GeminiError.apiError("Ogiltig förfrågan — kontrollera att API-nyckeln är korrekt.")
            }
            if httpResponse.statusCode == 403 {
                throw GeminiError.apiError("Åtkomst nekad — API-nyckeln saknar behörighet till Gemini API.")
            }
            let msg = String(data: data, encoding: .utf8) ?? "Okänt fel"
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode): \(msg.prefix(200))")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.parseError
        }

        return text
    }

    // MARK: - Parsa Gemini-svar till artikel

    private func parseArticle(from text: String, category: String) -> ParsedArticle {
        var title = "Artikel om \(category)"
        var summary = ""
        var content = text
        var sources = "Gemini AI"

        let lines = text.components(separatedBy: "\n")
        var contentLines: [String] = []
        var sourceLines: [String] = []
        var inContent = false
        var inSources = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TITEL:") {
                title = trimmed.replacingOccurrences(of: "TITEL:", with: "").trimmingCharacters(in: .whitespaces)
                inContent = false; inSources = false
            } else if trimmed.hasPrefix("SAMMANFATTNING:") {
                summary = trimmed.replacingOccurrences(of: "SAMMANFATTNING:", with: "").trimmingCharacters(in: .whitespaces)
                inContent = false; inSources = false
            } else if trimmed.hasPrefix("INNEHÅLL:") {
                inContent = true; inSources = false
            } else if trimmed.hasPrefix("KÄLLOR:") {
                inContent = false; inSources = true
            } else if inContent {
                contentLines.append(line)
            } else if inSources {
                sourceLines.append(trimmed)
            }
        }

        if !contentLines.isEmpty {
            content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !sourceLines.isEmpty {
            // Slå ihop alla källrader, dela på semikolon, rensa bindestreck och tomma poster
            let raw = sourceLines.joined(separator: ";")
            let parts = raw.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { s -> String in
                    // Ta bort eventuella inledande "- " eller "* "
                    var cleaned = s
                    if cleaned.hasPrefix("- ") { cleaned = String(cleaned.dropFirst(2)) }
                    if cleaned.hasPrefix("* ") { cleaned = String(cleaned.dropFirst(2)) }
                    if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
                        cleaned = String(cleaned.dropFirst().dropLast())
                    }
                    return cleaned
                }
                .filter { !$0.isEmpty }
            sources = parts.joined(separator: "; ")
        }
        if summary.isEmpty {
            summary = String(content.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines)
            if content.count > 160 { summary += "..." }
        }

        return ParsedArticle(title: title, content: content, summary: summary, sources: sources)
    }

    private func updateLog(id: UUID, status: GeminiLogEntry.Status, title: String) {
        if let idx = generationLog.firstIndex(where: { $0.id == id }) {
            generationLog[idx].status = status
            generationLog[idx].resultTitle = title
            generationLog[idx].completedAt = Date()
        }
    }
}

// MARK: - GeminiSettings (sparas i UserDefaults)

struct GeminiSettings {
    var isEnabled: Bool
    var apiKey: String
    var intervalMinutes: Int

    static let defaultInterval = 30

    static func load() -> GeminiSettings {
        GeminiSettings(
            isEnabled: UserDefaults.standard.bool(forKey: "gemini_enabled"),
            apiKey: UserDefaults.standard.string(forKey: "gemini_api_key") ?? "AIzaSyBiRmcU186MnnGS6jPAO1dUs8cUAmSQmUw",
            intervalMinutes: {
                let v = UserDefaults.standard.integer(forKey: "gemini_interval_minutes")
                return v > 0 ? v : defaultInterval
            }()
        )
    }

    func save() {
        UserDefaults.standard.set(isEnabled, forKey: "gemini_enabled")
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(intervalMinutes, forKey: "gemini_interval_minutes")
    }
}

// MARK: - Hjälpstrukturer

struct ParsedArticle {
    let title: String
    let content: String
    let summary: String
    let sources: String
}

struct GeminiLogEntry: Identifiable {
    let id = UUID()
    let category: String
    var status: Status
    let startedAt: Date
    var completedAt: Date? = nil
    var resultTitle: String = ""

    enum Status {
        case generating, success, failed
        var label: String {
            switch self { case .generating: return "Genererar..."; case .success: return "Klar"; case .failed: return "Misslyckades" }
        }
        var color: String {
            switch self { case .generating: return "#FBBF24"; case .success: return "#34D399"; case .failed: return "#F87171" }
        }
    }
}

enum GeminiError: LocalizedError {
    case invalidURL, invalidResponse, parseError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ogiltig API-URL"
        case .invalidResponse: return "Ogiltigt svar från servern"
        case .parseError: return "Kunde inte tolka svaret från Gemini"
        case .apiError(let msg): return msg
        }
    }
}
