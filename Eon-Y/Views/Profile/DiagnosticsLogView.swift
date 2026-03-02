import SwiftUI

struct DiagnosticsLogView: View {
    @State private var reportText: String = ""
    @State private var logText: String = ""
    @State private var isLoading = true
    @State private var showClearAlert = false
    @State private var copyDone = false
    @State private var showReport = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0A14").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                segmentedPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                Divider().background(Color.white.opacity(0.06)).padding(.top, 10)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color(hex: "#EF4444"))
                    Spacer()
                } else if showReport {
                    reportScroll
                } else {
                    logScroll
                }

                bottomBar
            }
        }
        .onAppear { loadData() }
        .alert("Rensa diagnostiklogg?", isPresented: $showClearAlert) {
            Button("Rensa", role: .destructive) {
                ResourceDiagnosticsLogger.shared.clear()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { loadData() }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("All insamlad diagnostikdata raderas permanent.")
        }
    }

    // MARK: - Header

    var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#EF4444"))
            VStack(alignment: .leading, spacing: 1) {
                Text("RESURSDIAGNOSTIK")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(1.5)
                Text("\(ResourceDiagnosticsLogger.shared.eventCountString) · \(ResourceDiagnosticsLogger.shared.fileSizeString)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
            Button {
                withAnimation { isLoading = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { loadData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Segment

    var segmentedPicker: some View {
        HStack(spacing: 0) {
            segBtn("Logghändelser", icon: "list.bullet", selected: !showReport) {
                withAnimation(.easeInOut(duration: 0.2)) { showReport = false }
            }
            segBtn("Fullständig rapport", icon: "doc.text.magnifyingglass", selected: showReport) {
                withAnimation(.easeInOut(duration: 0.2)) { showReport = true }
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func segBtn(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(title).font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.4))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color(hex: "#EF4444").opacity(0.2) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Log scroll

    var logScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if logText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(hex: "#34D399"))
                        Text("Ingen hög CPU/värme registrerad ännu")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Loggaren kör var 5s och registrerar händelser\nnär CPU > 45% eller temperaturen stiger")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(logLines(), id: \.self) { line in
                        logRow(line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func logLines() -> [String] {
        logText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    @ViewBuilder
    private func logRow(_ line: String) -> some View {
        let isEvent = line.hasPrefix("[20")
        let isCritical = line.contains("KRITISK") || line.contains("CRITICAL") || line.contains("SERIOUS")
        let isWarning = line.contains("⚠️") || line.contains("Termisk") || line.contains("Stigande ↑")
        let isOk = line.contains("✅") || line.contains("NOMINAL")
        let isOrsakLabel = line.hasPrefix("  Orsaker:")
        let isComponentLabel = line.hasPrefix("  ") && !isOrsakLabel

        HStack(alignment: .top, spacing: 6) {
            if isEvent {
                Text("◉")
                    .font(.system(size: 8))
                    .foregroundStyle(isCritical ? Color(hex: "#EF4444") : Color(hex: "#F59E0B"))
                    .padding(.top, 3)
            }
            Text(line)
                .font(.system(size: isEvent ? 10 : 9, weight: isEvent ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(
                    isCritical ? Color(hex: "#EF4444") :
                    isWarning  ? Color(hex: "#F59E0B") :
                    isOk       ? Color(hex: "#34D399") :
                    isOrsakLabel ? Color(hex: "#A78BFA") :
                    isComponentLabel ? Color.white.opacity(0.6) :
                    Color.white.opacity(0.45)
                )
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
        if isEvent {
            Divider().background(Color.white.opacity(0.06))
        }
    }

    // MARK: - Report scroll

    var reportScroll: some View {
        ScrollView {
            Text(reportText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Bottom bar

    var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                let text = showReport ? reportText : logText
                UIPasteboard.general.string = text
                withAnimation { copyDone = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copyDone = false }
                }
            } label: {
                Label(copyDone ? "Kopierat!" : "Kopiera allt", systemImage: copyDone ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(copyDone ? Color(hex: "#34D399") : .white.opacity(0.75))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showClearAlert = true
            } label: {
                Label("Rensa", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(hex: "#EF4444").opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(hex: "#0A0A14").opacity(0.95))
    }

    // MARK: - Load

    private func loadData() {
        Task.detached(priority: .userInitiated) {
            let log = await ResourceDiagnosticsLogger.shared.readAll()
            let report = await ResourceDiagnosticsLogger.shared.generateReport()
            await MainActor.run {
                logText = log
                reportText = report
                withAnimation { isLoading = false }
            }
        }
    }
}
