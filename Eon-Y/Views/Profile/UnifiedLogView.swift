import SwiftUI

// MARK: - UnifiedLogView
// Samlar alla tre loggar (Kognition / Diagnostik / Sessioner) i en vy med flikar.
// Varje flik har sökfält, färgkodade rader, kopiera-knapp och rensa-knapp.

struct UnifiedLogView: View {
    enum LogTab: String, CaseIterable {
        case cognition   = "Kognition"
        case diagnostics = "Diagnostik"
        case sessions    = "Sessioner"

        var icon: String {
            switch self {
            case .cognition:   return "brain.head.profile"
            case .diagnostics: return "waveform.path.ecg"
            case .sessions:    return "list.bullet.clipboard"
            }
        }

        var color: Color {
            switch self {
            case .cognition:   return .purple
            case .diagnostics: return .orange
            case .sessions:    return .cyan
            }
        }
    }

    var initialTab: LogTab = .cognition
    @State private var selectedTab: LogTab = .cognition
    @State private var searchText: String = ""
    @State private var cognitionLines: [LogLine] = []
    @State private var diagnosticsLines: [LogLine] = []
    @State private var sessionLines: [LogLine] = []
    @State private var isLoading = false
    @State private var copyConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Tab bar
                tabBar

                // Search
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider().background(Color.white.opacity(0.08))

                // Log content
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredLines) { line in
                            logRow(line)
                        }
                    }
                    .padding(.bottom, 100)
                }

                // Bottom toolbar
                bottomToolbar
            }
        }
        .navigationTitle("Loggar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedTab = initialTab
            loadLogs()
        }
        .onChange(of: selectedTab) { _ in loadLogs() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LogTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? tab.color : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab
                            ? tab.color.opacity(0.1)
                            : Color.clear
                    )
                    .overlay(
                        Rectangle()
                            .fill(selectedTab == tab ? tab.color : Color.clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
            }
        }
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Sök i loggar...", text: $searchText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .tint(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Log Row

    private func logRow(_ line: LogLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(line.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
        }
        .background(line.index % 2 == 0 ? Color.clear : Color.white.opacity(0.015))
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            // Kopiera aktuell flik
            Button {
                copyCurrentTab()
            } label: {
                Label(copyConfirm ? "Kopierat!" : "Kopiera flik", systemImage: copyConfirm ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedTab.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(selectedTab.color.opacity(0.12))
                    )
            }

            // Kopiera alla loggar
            Button {
                copyAllLogs()
            } label: {
                Label("Kopiera alla", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(Color.white.opacity(0.07))
                    )
            }

            Spacer()

            // Rensa aktuell flik
            Button {
                clearCurrentTab()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(Color.red.opacity(0.1)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .overlay(Divider().background(Color.white.opacity(0.08)), alignment: .top)
    }

    // MARK: - Filtered Lines

    private var filteredLines: [LogLine] {
        let lines: [LogLine]
        switch selectedTab {
        case .cognition:   lines = cognitionLines
        case .diagnostics: lines = diagnosticsLines
        case .sessions:    lines = sessionLines
        }
        if searchText.isEmpty { return lines }
        return lines.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Loading

    private func loadLogs() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let cog = CognitionLogger.shared.readAll()
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .enumerated()
                .map { LogLine(index: $0.offset, text: $0.element, tab: .cognition) }

            let diag = ResourceDiagnosticsLogger.shared.readAll()
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .enumerated()
                .map { LogLine(index: $0.offset, text: $0.element, tab: .diagnostics) }

            let sess = RunSessionLogger.shared.allSessionsContent()
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .enumerated()
                .map { LogLine(index: $0.offset, text: $0.element, tab: .sessions) }

            await MainActor.run {
                self.cognitionLines = cog
                self.diagnosticsLines = diag
                self.sessionLines = sess
                self.isLoading = false
            }
        }
    }

    private func copyCurrentTab() {
        let text = filteredLines.map { $0.text }.joined(separator: "\n")
        UIPasteboard.general.string = text
        withAnimation { copyConfirm = true }
        Task { try? await Task.sleep(nanoseconds: 2_000_000_000); await MainActor.run { copyConfirm = false } }
    }

    private func copyAllLogs() {
        let all = """
=== EON KOGNITIONSLOGG ===
\(CognitionLogger.shared.readAll())

=== EON DIAGNOSTIK ===
\(ResourceDiagnosticsLogger.shared.readAll())

=== EON SESSIONER ===
\(RunSessionLogger.shared.allSessionsContent())
"""
        UIPasteboard.general.string = all
    }

    private func clearCurrentTab() {
        switch selectedTab {
        case .cognition:
            CognitionLogger.shared.clear()
            cognitionLines = []
        case .diagnostics:
            ResourceDiagnosticsLogger.shared.clear()
            diagnosticsLines = []
        case .sessions:
            sessionLines = []
        }
    }
}

// MARK: - LogLine

private struct LogLine: Identifiable {
    let id = UUID()
    let index: Int
    let text: String
    let tab: UnifiedLogView.LogTab

    var color: Color {
        let t = text.lowercased()
        if t.contains("[insight]") || t.contains("insikt") || t.contains("📖") { return .purple.opacity(0.9) }
        if t.contains("[revision]") || t.contains("korrigerar") { return .orange.opacity(0.85) }
        if t.contains("[memory]") || t.contains("minne") { return .cyan.opacity(0.85) }
        if t.contains("[loop]") || t.contains("⟳") || t.contains("⚡") { return Color(hex: "#34D399").opacity(0.85) }
        if t.contains("error") || t.contains("fel") || t.contains("kritisk") { return .red.opacity(0.85) }
        if t.contains("warn") || t.contains("varning") || t.contains("allvarlig") { return .yellow.opacity(0.85) }
        return .white.opacity(0.55)
    }
}
