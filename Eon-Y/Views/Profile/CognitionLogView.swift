import SwiftUI

// MARK: - CognitionLogView
// Visar Eons sparade kognitionslogg. Nås via Inställningar.

struct CognitionLogView: View {
    @State private var logText: String = ""
    @State private var isLoading = true
    @State private var showCopied = false
    @State private var showClearAlert = false
    @State private var searchText = ""
    @State private var scrollToBottom = false

    private let logger = CognitionLogger.shared

    var filteredLines: [String] {
        let lines = logText.components(separatedBy: "\n").filter { !$0.isEmpty }
        if searchText.isEmpty { return lines }
        return lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0D1A").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Sökfält
                searchBar

                // Logginnehåll
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "#A78BFA"))
                    Spacer()
                } else if filteredLines.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text(searchText.isEmpty ? "Ingen logg ännu" : "Inga träffar")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                } else {
                    logScrollView
                }

                // Knappar längst ner
                bottomBar
            }
        }
        .task { await loadLog() }
        .alert("Rensa logg?", isPresented: $showClearAlert) {
            Button("Avbryt", role: .cancel) {}
            Button("Rensa", role: .destructive) {
                logger.clear()
                Task { await loadLog() }
            }
        } message: {
            Text("All sparad kognitionsdata raderas permanent.")
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#A78BFA"))
            VStack(alignment: .leading, spacing: 2) {
                Text("KOGNITIONSLOGG")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.2)
                Text("\(filteredLines.count) rader · \(logger.fileSizeString)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Button {
                showClearAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
                    .padding(8)
                    .background(Color(hex: "#EF4444").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.03))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
            TextField("Sök i loggen...", text: $searchText)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { idx, line in
                        logRow(line: line, index: idx)
                            .id(idx)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: scrollToBottom) { _, _ in
                if let last = filteredLines.indices.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private func logRow(line: String, index: Int) -> some View {
        let (color, icon) = styleForLine(line)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.7))
                .frame(width: 14)
                .padding(.top, 3)
            Text(line)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(color.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.015))
        .cornerRadius(4)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Divider().background(Color.white.opacity(0.06))
            HStack(spacing: 12) {
                // Kopiera allt
                Button {
                    UIPasteboard.general.string = logText
                    withAnimation(.spring(response: 0.3)) { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                        Text(showCopied ? "Kopierat!" : "Kopiera allt")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(showCopied ? Color(hex: "#4ADE80") : Color(hex: "#A78BFA"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(showCopied ? Color(hex: "#4ADE80").opacity(0.1) : Color(hex: "#A78BFA").opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(
                                showCopied ? Color(hex: "#4ADE80").opacity(0.3) : Color(hex: "#A78BFA").opacity(0.25),
                                lineWidth: 0.6))
                    )
                }

                // Scrolla till botten
                Button {
                    scrollToBottom.toggle()
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    private func loadLog() async {
        isLoading = true
        let text = await Task.detached(priority: .userInitiated) {
            await CognitionLogger.shared.readAll()
        }.value
        logText = text
        isLoading = false
    }

    private func styleForLine(_ line: String) -> (Color, String) {
        if line.contains("[LOOP]")     { return (Color(hex: "#F97316"), "arrow.triangle.2.circlepath") }
        if line.contains("[INSIKT]")   { return (Color(hex: "#14B8A6"), "lightbulb.fill") }
        if line.contains("[MINNE]")    { return (Color(hex: "#F59E0B"), "memorychip") }
        if line.contains("[REVISION]") { return (Color(hex: "#FBBF24"), "pencil.and.outline") }
        if line.contains("[TANKE]")    { return (Color(hex: "#A78BFA"), "brain.head.profile") }
        if line.hasPrefix("===")       { return (Color.white.opacity(0.5), "doc.text") }
        return (Color.white.opacity(0.45), "circle.fill")
    }
}

#Preview {
    CognitionLogView()
}
