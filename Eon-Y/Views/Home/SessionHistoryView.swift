import SwiftUI

// MARK: - SessionHistoryView
// Lista med alla sparade körningssessioner.
// Tryck på en session för att läsa hela loggen.
// Svep åt vänster för att radera (ej aktiv session).

struct SessionHistoryView: View {
    @State private var sessions: [SessionInfo] = []
    @State private var selectedSession: SessionInfo?
    @State private var sessionContent: String = ""
    @State private var isLoading = false
    @State private var copyDone = false
    @State private var searchText = ""

    var body: some View {
        Group {
            if let selected = selectedSession {
                sessionDetailView(selected)
                    .transition(.move(edge: .trailing))
            } else {
                sessionListView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedSession?.id)
        .onAppear { loadSessions() }
    }

    // MARK: - Session list

    var sessionListView: some View {
        VStack(spacing: 0) {
            listHeader
            Divider().background(Color.white.opacity(0.06))

            if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessions) { session in
                        sessionRow(session)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            let s = sessions[i]
                            if !s.isCurrent {
                                RunSessionLogger.shared.deleteSession(s)
                            }
                        }
                        loadSessions()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#A78BFA"))
            Text("KÖRNINGSHISTORIK")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
            Spacer()
            Text("\(sessions.count) sessioner · max 5 sparas")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.12))
            Text("Inga sparade sessioner ännu")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
            Text("Loggar sparas automatiskt under körning.\nStarta appen igen för att skapa en ny session.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.18))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private func sessionRow(_ session: SessionInfo) -> some View {
        Button { openSession(session) } label: {
            HStack(spacing: 12) {
                // Status-ikon
                ZStack {
                    Circle()
                        .fill(session.isCurrent
                              ? Color(hex: "#34D399").opacity(0.15)
                              : Color.white.opacity(0.05))
                        .frame(width: 38, height: 38)
                    Image(systemName: session.isCurrent
                          ? "dot.radiowaves.left.and.right"
                          : "doc.text.magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(session.isCurrent
                                         ? Color(hex: "#34D399")
                                         : Color(hex: "#A78BFA").opacity(0.6))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(session.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                        if session.isCurrent {
                            Text("AKTIV")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color(hex: "#34D399"))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color(hex: "#34D399").opacity(0.12), in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Label(session.sizeString, systemImage: "doc")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.28))
                        if !session.isCurrent {
                            Text("Svep för att radera")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.15))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(session.isCurrent
                          ? Color(hex: "#34D399").opacity(0.06)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(
                                session.isCurrent
                                    ? Color(hex: "#34D399").opacity(0.2)
                                    : Color.white.opacity(0.07),
                                lineWidth: 0.6
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session detail

    private func sessionDetailView(_ session: SessionInfo) -> some View {
        VStack(spacing: 0) {
            detailHeader(session)
            Divider().background(Color.white.opacity(0.06))

            // Sökfält
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                TextField("Sök i loggen...", text: $searchText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))

            Divider().background(Color.white.opacity(0.06))

            if isLoading {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color(hex: "#A78BFA"))
                    Text("Läser logg...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            } else {
                logContentView
            }
        }
        .onAppear { searchText = "" }
    }

    private func detailHeader(_ session: SessionInfo) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation {
                    selectedSession = nil
                    sessionContent = ""
                    searchText = ""
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Tillbaka")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color(hex: "#A78BFA"))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color(hex: "#A78BFA").opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 6) {
                    Text(session.sizeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.28))
                    if session.isCurrent {
                        Text("● AKTIV")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#34D399"))
                    }
                    if !searchText.isEmpty {
                        let count = filteredLines.count
                        Text("\(count) träff\(count == 1 ? "" : "ar")")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                }
            }

            Spacer()

            Button {
                UIPasteboard.general.string = sessionContent
                withAnimation { copyDone = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copyDone = false }
                }
            } label: {
                Label(copyDone ? "✓" : "Kopiera", systemImage: copyDone ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copyDone ? Color(hex: "#34D399") : .white.opacity(0.7))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // Filtrerade rader baserat på söktext
    private var filteredLines: [String] {
        let lines = sessionContent.components(separatedBy: "\n")
        guard !searchText.isEmpty else { return lines }
        return lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var logContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { idx, line in
                        logLine(line, idx: idx)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                if searchText.isEmpty {
                    Button {
                        withAnimation { proxy.scrollTo("bottom") }
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(10)
                            .background(Color(hex: "#A78BFA").opacity(0.2), in: Circle())
                            .overlay(Circle().strokeBorder(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                }
            }
        }
    }

    private func logLine(_ line: String, idx: Int) -> some View {
        let color = lineColor(line)
        return Group {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                Color.clear.frame(height: 4)
            } else if line.hasPrefix("╔") || line.hasPrefix("╚") || line.hasPrefix("║") {
                Text(line)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 1)
            } else if line.contains("[SNAPSHOT]") || line.hasPrefix("──") || line.hasPrefix("─") {
                Text(line)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#7C3AED").opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 1)
            } else {
                Text(highlightSearch(line))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 0.5)
            }
        }
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("[VARNING]") || line.contains("KRITISK") { return Color(hex: "#EF4444").opacity(0.9) }
        if line.contains("[TANKE]")   { return Color(hex: "#A78BFA").opacity(0.75) }
        if line.contains("[LOOP]")    { return Color(hex: "#38BDF8").opacity(0.75) }
        if line.contains("[REVISION]"){ return Color(hex: "#F59E0B").opacity(0.75) }
        if line.contains("[MINNE]")   { return Color(hex: "#34D399").opacity(0.75) }
        if line.contains("[INSIKT]")  { return Color(hex: "#F472B6").opacity(0.75) }
        if line.contains("[SYS]")     { return Color(hex: "#6B7280").opacity(0.75) }
        return .white.opacity(0.55)
    }

    private func highlightSearch(_ line: String) -> AttributedString {
        var attributed = AttributedString(line)
        guard !searchText.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let range = attributed[searchRange].range(of: searchText, options: .caseInsensitive) {
            attributed[range].backgroundColor = Color(hex: "#F59E0B").opacity(0.35)
            attributed[range].foregroundColor = .white
            searchRange = range.upperBound..<attributed.endIndex
        }
        return attributed
    }

    // MARK: - Helpers

    private func loadSessions() {
        sessions = RunSessionLogger.shared.allSessions()
    }

    private func openSession(_ session: SessionInfo) {
        isLoading = true
        selectedSession = session
        Task.detached(priority: .userInitiated) {
            let content = RunSessionLogger.shared.readSession(session)
            await MainActor.run {
                sessionContent = content
                isLoading = false
            }
        }
    }
}
