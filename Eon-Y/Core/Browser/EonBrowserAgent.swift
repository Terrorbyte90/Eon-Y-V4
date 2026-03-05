import Foundation
import Combine
import NaturalLanguage

// MARK: - Models

enum BrowseMode: String, CaseIterable {
    case research = "Forskning"
    case article = "Skapa artikel"
}

struct BrowseStep: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let icon: String
    let message: String
    let detail: String
    let type: StepType

    enum StepType { case thinking, navigating, reading, extracting, writing, done, error }
}

struct BrowseResult {
    let title: String
    let summary: String
    let sources: [String]
    let fullContent: String
    let articleDomain: String?
}

struct PageContent: Sendable {
    let url: String
    let title: String
    let bodyText: String
    let headings: [String]
    let links: [(text: String, href: String)]
    let metaDescription: String
    let tableData: [String]
    let listItems: [String]

    var isEmpty: Bool {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20
    }

    var readableText: String {
        var parts: [String] = []
        if !headings.isEmpty {
            parts.append(headings.joined(separator: " — "))
        }
        parts.append(bodyText)
        if !listItems.isEmpty {
            parts.append(listItems.prefix(10).joined(separator: ". "))
        }
        if !tableData.isEmpty {
            parts.append(tableData.prefix(5).joined(separator: " | "))
        }
        return parts.joined(separator: "\n")
    }
}

struct SearchResult: Sendable {
    let title: String
    let snippet: String
    let url: String
    let index: Int
}

// MARK: - EonBrowserAgent: Autonomous web browsing powered by Qwen3

@MainActor
class EonBrowserAgent: ObservableObject {
    @Published var goal: String = ""
    @Published var mode: BrowseMode = .research
    @Published var articleDomain: String = "AI & Teknik"
    @Published var isBrowsing = false
    @Published var isPaused = false
    @Published var userTookOver = false
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var steps: [BrowseStep] = []
    @Published var result: BrowseResult?
    @Published var progress: Double = 0
    @Published var statusLabel: String = "Redo"

    var onNavigate: ((URL) -> Void)?
    var onExtractContent: ((@escaping (PageContent) -> Void) -> Void)?
    var onRunJS: ((String, @escaping (String?) -> Void) -> Void)?
    var onGoBack: (() -> Void)?

    var pageLoadContinuation: CheckedContinuation<Void, Never>?

    private var collectedContent: [(url: String, title: String, text: String)] = []
    private var visitedURLs: Set<String> = []
    private var failedExtractions = 0
    private var maxPages = 10
    private var pagesVisited = 0

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])

    // MARK: - Public API

    func startBrowsing() {
        guard !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isBrowsing = true
        isPaused = false
        userTookOver = false
        result = nil
        steps.removeAll()
        collectedContent.removeAll()
        visitedURLs.removeAll()
        failedExtractions = 0
        pagesVisited = 0
        progress = 0

        addStep(.thinking, "Analyserar ditt mål", "Förstår vad du vill ha...")
        Task { await planAndExecute() }
    }

    func stopBrowsing() {
        isBrowsing = false
        isPaused = false
        userTookOver = false
        statusLabel = "Avbruten"
        addStep(.done, "Stoppat av användaren", "")
        pageLoadContinuation?.resume()
        pageLoadContinuation = nil
    }

    func takeOver() {
        userTookOver = true
        isPaused = true
        statusLabel = "Du styr"
        addStep(.thinking, "Användaren tar över", "Eon pausad — du kan surfa fritt")
    }

    func handBack() {
        userTookOver = false
        isPaused = false
        statusLabel = "Eon fortsätter..."
        addStep(.thinking, "Eon tar tillbaka kontrollen", "Läser nuvarande sida...")
    }

    // MARK: - Core browsing loop

    private func planAndExecute() async {
        let searchQuery = await generateSearchQuery()
        guard !searchQuery.isEmpty else {
            addStep(.error, "Kunde inte förstå målet", "Försök formulera om din förfrågan.")
            isBrowsing = false
            return
        }

        addStep(.thinking, "Sökstrategi klar", "Söker: \"\(searchQuery)\"")
        statusLabel = "Söker..."

        let searchURL = buildSearchURL(query: searchQuery)
        await navigateAndWaitForLoad(url: searchURL)
        await dismissPageOverlays()

        var searchResults = await extractSearchResults()

        if !searchResults.isEmpty {
            addStep(.extracting, "Hittade \(searchResults.count) sökresultat",
                    searchResults.prefix(3).map(\.title).joined(separator: ", "))
            await browseSearchResults(searchResults)
        } else {
            addStep(.thinking, "Använder länkanalys", "Extraherar relevanta länkar...")
            await browseLinkBased()
        }

        if collectedContent.count < 2 && pagesVisited < maxPages && isBrowsing {
            let altQuery = await generateAlternativeQuery(original: searchQuery)
            if !altQuery.isEmpty && altQuery.lowercased() != searchQuery.lowercased() {
                addStep(.thinking, "Provar alternativ sökning", "Söker: \"\(altQuery)\"")
                let altURL = buildSearchURL(query: altQuery)
                await navigateAndWaitForLoad(url: altURL)
                await dismissPageOverlays()

                searchResults = await extractSearchResults()
                if !searchResults.isEmpty {
                    await browseSearchResults(searchResults)
                } else {
                    await browseLinkBased()
                }
            }
        }

        guard isBrowsing else { return }

        if !collectedContent.isEmpty {
            await generateFinalResult()
            await saveDiscoveredKnowledge()
        } else {
            addStep(.error, "Kunde inte samla tillräckligt med information",
                    "Prova att formulera om din fråga.")
            isBrowsing = false
        }
    }

    // MARK: - Browse structured search results

    private func browseSearchResults(_ results: [SearchResult]) async {
        let ranked = await rankSearchResults(results)

        for sr in ranked {
            guard pagesVisited < maxPages, isBrowsing, failedExtractions < 4 else { break }
            await waitWhilePaused()
            guard isBrowsing else { break }

            let totalChars = collectedContent.map(\.text).joined().count
            if totalChars > 8000 && collectedContent.count >= 3 {
                addStep(.thinking, "Tillräckligt med material (\(collectedContent.count) sidor)", "Sammanställer...")
                break
            }

            guard let url = URL(string: sr.url), !visitedURLs.contains(sr.url) else { continue }

            statusLabel = "Besöker: \(sr.title.prefix(30))..."
            progress = Double(pagesVisited) / Double(maxPages)
            addStep(.navigating, "Öppnar: \(sr.title.prefix(50))", url.host ?? sr.url)

            await navigateAndWaitForLoad(url: url)
            await dismissPageOverlays()
            await expandCollapsedContent()
            await scrollPageDown()
            try? await Task.sleep(nanoseconds: 400_000_000)

            guard let pageContent = await extractWithRetry() else {
                failedExtractions += 1
                addStep(.error, "Kunde inte läsa sidan (\(failedExtractions))", "Hoppar till nästa...")
                continue
            }

            visitedURLs.insert(sr.url)
            if !pageContent.url.isEmpty { visitedURLs.insert(pageContent.url) }

            if pageContent.isEmpty {
                failedExtractions += 1
                addStep(.reading, "Sidan hade lite innehåll", "Nästa resultat...")
                continue
            }

            failedExtractions = max(0, failedExtractions - 1)
            let text = String(pageContent.readableText.prefix(4000))
            let preview = String(text.prefix(90)).replacingOccurrences(of: "\n", with: " ")
            addStep(.reading, "Läste: \(pageContent.title.prefix(50))", "\(preview)...")

            if !isDuplicateContent(text) {
                collectedContent.append((url: pageContent.url, title: pageContent.title, text: text))
            }
            pagesVisited += 1

            if pagesVisited < maxPages && collectedContent.map(\.text).joined().count < 6000 {
                await followDeepLink(on: pageContent)
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    private func followDeepLink(on page: PageContent) async {
        let filtered = filterLinks(page.links)
        guard !filtered.isEmpty else { return }

        if let deepLink = await selectBestLink(from: filtered) {
            guard let deepURL = URL(string: deepLink.href), !visitedURLs.contains(deepLink.href) else { return }

            addStep(.navigating, "Följer djuplänk: \(deepLink.text.prefix(40))", deepURL.host ?? deepLink.href)
            await navigateAndWaitForLoad(url: deepURL)
            await dismissPageOverlays()
            await expandCollapsedContent()
            await scrollPageDown()

            if let deepContent = await extractWithRetry(), !deepContent.isEmpty {
                let deepText = String(deepContent.readableText.prefix(3000))
                if !isDuplicateContent(deepText) {
                    collectedContent.append((url: deepContent.url, title: deepContent.title, text: deepText))
                    addStep(.reading, "Djuplänk: \(deepContent.title.prefix(40))", "")
                }
            }
            visitedURLs.insert(deepLink.href)
            pagesVisited += 1
        }
    }

    // MARK: - Browse link-based (fallback)

    private func browseLinkBased() async {
        while pagesVisited < maxPages && isBrowsing && failedExtractions < 4 {
            await waitWhilePaused()
            guard isBrowsing else { break }

            progress = Double(pagesVisited) / Double(maxPages)
            statusLabel = "Läser sida \(pagesVisited + 1)/\(maxPages)..."

            guard let pageContent = await extractWithRetry() else {
                failedExtractions += 1
                if failedExtractions >= 4 { break }
                continue
            }

            if !pageContent.isEmpty {
                failedExtractions = max(0, failedExtractions - 1)
                let text = String(pageContent.readableText.prefix(4000))
                let preview = String(text.prefix(90)).replacingOccurrences(of: "\n", with: " ")
                addStep(.reading, "Läser: \(pageContent.title.prefix(50))", "\(preview)...")

                if !isDuplicateContent(text) {
                    collectedContent.append((url: pageContent.url, title: pageContent.title, text: text))
                }
                visitedURLs.insert(pageContent.url)
                pagesVisited += 1
            } else {
                failedExtractions += 1
                if failedExtractions >= 4 { break }
            }

            let totalChars = collectedContent.map(\.text).joined().count
            if totalChars > 6000 && pagesVisited >= 3 { break }

            let filtered = filterLinks(pageContent.links)
            guard !filtered.isEmpty else { break }

            if let nextLink = await selectBestLink(from: filtered) {
                addStep(.navigating, "Följer: \(nextLink.text.prefix(40))", nextLink.href)
                if let url = URL(string: nextLink.href) {
                    await navigateAndWaitForLoad(url: url)
                    await dismissPageOverlays()
                    await expandCollapsedContent()
                    await scrollPageDown()
                }
            } else {
                break
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    // MARK: - JS Action Helpers

    private func runJS(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (String?) -> Void = { value in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            guard let onRunJS else {
                resumeOnce(nil)
                return
            }

            onRunJS(script) { result in
                resumeOnce(result)
            }

            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                resumeOnce(nil)
            }
        }
    }

    @discardableResult
    private func clickElement(_ selector: String) async -> Bool {
        let escaped = selector.replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\\", with: "\\\\")
        let result = await runJS("window.eonClickElement('\(escaped)')")
        return result == "true"
    }

    private func scrollPageDown() async {
        _ = await runJS("window.eonScrollDown()")
        try? await Task.sleep(nanoseconds: 600_000_000)
    }

    private func dismissPageOverlays() async {
        _ = await runJS("window.eonDismissOverlays()")
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    private func expandCollapsedContent() async {
        _ = await runJS("window.eonExpandContent()")
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    private func extractSearchResults() async -> [SearchResult] {
        guard let jsonString = await runJS("window.eonExtractSearchResults()") else { return [] }
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return array.compactMap { dict -> SearchResult? in
            guard let title = dict["title"] as? String,
                  let url = dict["url"] as? String,
                  let index = dict["index"] as? Int else { return nil }
            let snippet = dict["snippet"] as? String ?? ""
            return SearchResult(title: title, snippet: snippet, url: url, index: index)
        }
    }

    private func goBack() async {
        onGoBack?()
        try? await Task.sleep(nanoseconds: 1_200_000_000)
    }

    // MARK: - Search result ranking with Qwen

    private func rankSearchResults(_ results: [SearchResult]) async -> [SearchResult] {
        guard results.count > 3 else { return results }
        let top = Array(results.prefix(10))
        let listing = top.enumerated().map { i, r in
            "\(i+1). \(r.title) — \(r.snippet.prefix(80))"
        }.joined(separator: "\n")

        let prompt = """
        MÅL: \(goal)
        
        Sökresultat:
        \(listing)
        
        Ranka de 5 BÄSTA resultaten för målet i prioritetsordning.
        Svara BARA med siffrorna separerade med komma. Exempel: 3,1,5,2,7
        """

        let raw = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 20, temperature: 0.1, enableThinking: false
        )

        let indices = raw.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
            .filter { $0 > 0 && $0 <= top.count }

        guard indices.count >= 2 else { return results }

        var ranked: [SearchResult] = []
        var seen = Set<Int>()
        for idx in indices {
            let zeroIdx = idx - 1
            if !seen.contains(zeroIdx) {
                ranked.append(top[zeroIdx])
                seen.insert(zeroIdx)
            }
        }
        for (i, r) in top.enumerated() where !seen.contains(i) {
            ranked.append(r)
        }
        return ranked
    }

    // MARK: - Smart link selection

    private func selectBestLink(from links: [(text: String, href: String)]) async -> (text: String, href: String)? {
        if let qwenChoice = await selectLinkWithQwen(links: links) {
            return qwenChoice
        }
        return selectLinkWithKeywords(links: links)
    }

    private func selectLinkWithQwen(links: [(text: String, href: String)]) async -> (text: String, href: String)? {
        let top = Array(links.prefix(12))
        let linkList = top.enumerated().map { i, link in
            "\(i+1). [\(link.text.prefix(60))] → \(URL(string: link.href)?.host?.replacingOccurrences(of: "www.", with: "") ?? String(link.href.prefix(40)))"
        }.joined(separator: "\n")

        let prompt = """
        MÅL: \(goal)
        Redan insamlat: \(collectedContent.count) sidor (\(collectedContent.map(\.text).joined().count) tecken)
        
        Tillgängliga länkar:
        \(linkList)
        
        Vilken länk (1-\(top.count)) är MEST relevant för att hitta NY, unik information om målet?
        Undvik sidor som troligen liknar redan besökta.
        Svara med BARA ett nummer (1-\(top.count)), eller 0 om ingen.
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 8, temperature: 0.1, enableThinking: false
        )

        let digits = result.filter(\.isNumber)
        if let num = Int(digits), num > 0, num <= top.count {
            return top[num - 1]
        }
        return nil
    }

    private func selectLinkWithKeywords(links: [(text: String, href: String)]) -> (text: String, href: String)? {
        let goalWords = Set(goal.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        guard !goalWords.isEmpty else { return links.first }

        var bestLink: (text: String, href: String)?
        var bestScore = 0

        for link in links {
            let linkWords = Set(link.text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            let hrefWords = Set(link.href.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
            let score = goalWords.intersection(linkWords).count * 3 + goalWords.intersection(hrefWords).count
            if score > bestScore {
                bestScore = score
                bestLink = link
            }
        }

        return bestScore > 0 ? bestLink : links.first
    }

    // MARK: - Search query generation

    private func generateSearchQuery() async -> String {
        let qwenQuery = await generateSearchQueryWithQwen()
        if !qwenQuery.isEmpty && qwenQuery.split(separator: " ").count >= 2 {
            return qwenQuery
        }
        return generateSearchQueryWithNL()
    }

    private func generateSearchQueryWithQwen() async -> String {
        let modeHint = mode == .article ? "en djupgående kunskapsartikel om" : "bästa information om"
        let prompt = """
        Du är en sökexpert. Generera den PERFEKTA Google-sökfrågan (max 8 ord) för att hitta \(modeHint): \(goal)
        Regler:
        - Använd de mest specifika nyckelorden
        - Inkludera ämnesspecifika termer
        - Optimera för relevanta resultat
        Svara BARA med sökfrågan, inget annat.
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 30, temperature: 0.3, enableThinking: false
        )

        return result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func generateAlternativeQuery(original: String) async -> String {
        let prompt = """
        Sökningen "\(original)" gav inte tillräckligt med resultat om: \(goal)
        Generera en ALTERNATIV sökfråga (max 8 ord) med andra nyckelord och vinklar.
        Svara BARA med sökfrågan.
        """

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: 30, temperature: 0.5, enableThinking: false
        )

        return result
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func generateSearchQueryWithNL() -> String {
        tagger.string = goal
        var nouns: [String] = []
        var entities: [String] = []

        tagger.enumerateTags(in: goal.startIndex..<goal.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(goal[range])
            if tag == .noun && word.count > 2 { nouns.append(word) }
            return true
        }

        tagger.enumerateTags(in: goal.startIndex..<goal.endIndex, unit: .word,
                             scheme: .nameType, options: [.omitWhitespace, .joinNames]) { tag, range in
            if tag != nil { entities.append(String(goal[range])) }
            return true
        }

        let keywords = (entities + nouns).prefix(5)
        return keywords.isEmpty ? String(goal.prefix(60)) : keywords.joined(separator: " ")
    }

    // MARK: - Navigation with page load wait

    private func navigateAndWaitForLoad(url: URL) async {
        addStep(.navigating, "Navigerar", url.host ?? url.absoluteString)
        currentURL = url
        onNavigate?(url)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.pageLoadContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                if self.pageLoadContinuation != nil {
                    self.pageLoadContinuation?.resume()
                    self.pageLoadContinuation = nil
                }
            }
        }

        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    // MARK: - Extraction with retry

    private func extractWithRetry() async -> PageContent? {
        for attempt in 1...3 {
            if let content = await extractWithTimeout() {
                return content
            }
            if attempt < 3 {
                await scrollPageDown()
                await dismissPageOverlays()
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
        return nil
    }

    private func extractWithTimeout() async -> PageContent? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (PageContent?) -> Void = { content in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: content)
            }

            onExtractContent? { content in
                resumeOnce(content)
            }

            Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                resumeOnce(nil)
            }
        }
    }

    // MARK: - Link filtering

    private static let blockedDomains: Set<String> = [
        "facebook.com", "twitter.com", "instagram.com", "tiktok.com", "youtube.com",
        "linkedin.com", "pinterest.com", "reddit.com/r/", "accounts.google",
        "play.google.com", "apps.apple.com", "maps.google", "x.com",
        "snapchat.com", "whatsapp.com", "discord.com", "spotify.com"
    ]

    private static let blockedPaths: Set<String> = [
        "login", "signup", "register", "signin", "auth", "oauth", "cookie", "privacy",
        "terms", "gdpr", "consent", "subscribe", "newsletter", "cart", "checkout",
        "account", "password", "forgot", "#", "javascript:", "mailto:", "tel:",
        "download", "install", "app-store", "play-store"
    ]

    private func filterLinks(_ links: [(text: String, href: String)]) -> [(text: String, href: String)] {
        links.filter { link in
            guard !visitedURLs.contains(link.href),
                  link.href.hasPrefix("http"),
                  link.text.count > 3,
                  link.text.count < 200 else { return false }

            let hrefLower = link.href.lowercased()
            let textLower = link.text.lowercased()

            for blocked in Self.blockedDomains {
                if hrefLower.contains(blocked) { return false }
            }
            for blocked in Self.blockedPaths {
                if hrefLower.contains(blocked) { return false }
            }

            let navWords: Set<String> = ["menu", "meny", "hem", "home", "about", "om oss", "kontakt",
                                          "contact", "logga in", "log in", "sign in", "cookie", "acceptera",
                                          "share", "dela", "print", "skriv ut", "previous", "next",
                                          "föregående", "nästa"]
            if navWords.contains(where: { textLower == $0 || textLower.hasPrefix($0 + " ") }) { return false }

            return true
        }
    }

    // MARK: - Deduplication

    private func isDuplicateContent(_ text: String) -> Bool {
        let newWords = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 4 })
        guard newWords.count > 5 else { return false }

        for existing in collectedContent {
            let existingWords = Set(existing.text.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 4 })
            let overlap = Double(newWords.intersection(existingWords).count) / Double(max(newWords.count, 1))
            if overlap > 0.6 { return true }
        }
        return false
    }

    // MARK: - Result generation

    private func generateFinalResult() async {
        addStep(.writing, "Sammanställer resultat",
                "Analyserar \(collectedContent.count) sidor med \(collectedContent.map(\.text).joined().count) tecken...")
        statusLabel = "Skriver resultat..."
        progress = 0.9

        let combinedContent = collectedContent.map { "[\($0.title)]\n\($0.text)" }.joined(separator: "\n---\n")
        let sources = collectedContent.map(\.url)

        switch mode {
        case .research:
            await generateResearchResult(content: combinedContent, sources: sources)
        case .article:
            await generateArticleResult(content: combinedContent, sources: sources)
        }
    }

    private func generateResearchResult(content: String, sources: [String]) async {
        let qwenResult = await generateWithQwen(
            prompt: """
            Du är en erfaren forskare. Besvara på svenska med fakta och substans:
            
            FRÅGA: \(goal)
            
            INSAMLAD DATA (\(collectedContent.count) källor):
            \(String(content.prefix(3000)))
            
            Instruktioner:
            - Sammanfatta de viktigaste fynden med konkreta fakta
            - Strukturera med tydliga stycken
            - Nämn specifika siffror, namn, datum om tillgängligt
            - Skriv max 500 ord, varmt och engagerande
            """,
            maxTokens: 700
        )

        let summary = qwenResult.isEmpty ? buildNLSummary(from: content) : qwenResult
        let title = await generateTitle() ?? "Resultat: \(String(goal.prefix(30)))"

        result = BrowseResult(title: title, summary: summary, sources: sources,
                              fullContent: content, articleDomain: nil)
        addStep(.done, "Forskning klar!", "\(collectedContent.count) sidor, \(sources.count) källor")
        statusLabel = "Klar"
        progress = 1.0
        isBrowsing = false
    }

    private func generateArticleResult(content: String, sources: [String]) async {
        let qwenResult = await generateWithQwen(
            prompt: """
            Skriv en professionell kunskapsartikel på svenska:
            
            ÄMNE: \(goal)
            KATEGORI: \(articleDomain)
            
            KÄLLMATERIAL (\(collectedContent.count) sidor):
            \(String(content.prefix(3000)))
            
            Format:
            - 400-600 ord
            - Välstrukturerad med inledning, huvudinnehåll och sammanfattning
            - Faktagrundad med konkreta detaljer
            - Pedagogisk och engagerande
            - BARA brödtext, inga rubriker med #
            """,
            maxTokens: 900
        )

        let articleContent = qwenResult.isEmpty ? buildNLSummary(from: content) : qwenResult
        let title = await generateTitle() ?? "\(String(goal.prefix(40)))"
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourcesStr = sources.prefix(4).joined(separator: "; ")

        let article = KnowledgeArticle(
            title: cleanTitle,
            content: articleContent,
            summary: String(articleContent.prefix(140)) + "...",
            domain: articleDomain,
            source: sourcesStr,
            date: Date(),
            isAutonomous: true
        )

        let saved = await PersistentMemoryStore.shared.saveArticle(article)

        result = BrowseResult(title: cleanTitle, summary: articleContent, sources: sources,
                              fullContent: content, articleDomain: articleDomain)
        addStep(.done, saved ? "Artikel sparad i \(articleDomain)!" : "Artikel skapad",
                "\(collectedContent.count) källor")
        statusLabel = "Klar"
        progress = 1.0
        isBrowsing = false
    }

    // MARK: - Save key findings to persistent memory

    private func saveDiscoveredKnowledge() async {
        guard !collectedContent.isEmpty else { return }

        let subject = String(goal.prefix(80))
        for item in collectedContent.prefix(3) {
            let factSnippet = String(item.text.prefix(200))
            await PersistentMemoryStore.shared.saveFact(
                subject: subject,
                predicate: "web_research_found",
                object: "[\(item.title)] \(factSnippet)",
                confidence: 0.6,
                source: item.url
            )
        }
    }

    // MARK: - Qwen wrapper

    private func generateWithQwen(prompt: String, maxTokens: Int) async -> String {
        let thermalState = ProcessInfo.processInfo.thermalState
        guard thermalState != .critical else { return "" }

        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: prompt, maxTokens: maxTokens, temperature: 0.5, enableThinking: true
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateTitle() async -> String? {
        let result = await NeuralEngineOrchestrator.shared.generate(
            prompt: "Skriv en kort och beskrivande rubrik (max 8 ord) för: \(goal)\nSvara BARA med rubriken.",
            maxTokens: 20, temperature: 0.3
        )
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.count > 2 ? cleaned : nil
    }

    // MARK: - NL Fallback summary

    private func buildNLSummary(from content: String) -> String {
        let sentences = content.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 && $0.count < 300 }

        let goalWords = Set(goal.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })

        let scored = sentences.map { sentence -> (String, Int) in
            let words = Set(sentence.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
            return (sentence, goalWords.intersection(words).count)
        }

        let topSentences = scored.sorted { $0.1 > $1.1 }.prefix(8).map(\.0)

        if topSentences.isEmpty {
            return "Eon hittade information men kunde inte sammanfatta den automatiskt. Rådata finns tillgängligt."
        }

        return topSentences.joined(separator: ". ") + "."
    }

    // MARK: - Helpers

    private func buildSearchURL(query: String) -> URL {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)&hl=sv")!
    }

    private func addStep(_ type: BrowseStep.StepType, _ message: String, _ detail: String) {
        steps.append(BrowseStep(icon: type.icon, message: message, detail: detail, type: type))
    }

    private func waitWhilePaused() async {
        while isPaused && isBrowsing {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
}

extension BrowseStep.StepType {
    var icon: String {
        switch self {
        case .thinking:   return "brain.head.profile"
        case .navigating: return "globe"
        case .reading:    return "doc.text.magnifyingglass"
        case .extracting: return "text.magnifyingglass"
        case .writing:    return "pencil.line"
        case .done:       return "checkmark.circle.fill"
        case .error:      return "exclamationmark.triangle.fill"
        }
    }
}
