import SwiftUI

// MARK: - GeminiSettingsView

struct GeminiSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var gemini = GeminiArticleService.shared
    @ObservedObject var viewModel: KnowledgeViewModel

    @State private var isEnabled: Bool = false
    @State private var apiKey: String = ""
    @State private var intervalMinutes: Int = 30
    @State private var showAPIKey: Bool = false
    @State private var showGenerateNow: Bool = false
    @State private var isSaved: Bool = false

    private let intervalOptions = [5, 10, 15, 30, 60, 120, 240, 480]

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#1A0050").opacity(0.4), Color.clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                        toggleSection
                        if isEnabled {
                            apiKeySection
                            intervalSection
                            generateNowSection
                        }
                        privacySection
                        logSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear { loadSettings() }
    }

    // MARK: - Nav bar

    var navBar: some View {
        HStack {
            Button("Avbryt") { dismiss() }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Text("Gemini Artiklar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                saveSettings()
                withAnimation { isSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { isSaved = false }
                    dismiss()
                }
            } label: {
                Text(isSaved ? "Sparat ✓" : "Spara")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSaved ? Color(hex: "#34D399") : Color(hex: "#A78BFA"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "#07050F").opacity(0.7))
                .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5), alignment: .bottom)
        )
    }

    // MARK: - Hero

    var heroSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4285F4").opacity(0.3), Color(hex: "#34A853").opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#4285F4"), Color(hex: "#34A853")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini Artikelgenerering")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Genererar automatiskt artiklar via Google Gemini API i den kategori som har minst innehåll.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(settingsCard())
    }

    // MARK: - Toggle

    var toggleSection: some View {
        VStack(spacing: 0) {
            sectionLabel("AKTIVERING")
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Automatisk generering")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        Text(isEnabled ? "Aktiv — genererar artiklar automatiskt" : "Inaktiv")
                            .font(.system(size: 12))
                            .foregroundStyle(isEnabled ? Color(hex: "#34D399").opacity(0.8) : .white.opacity(0.35))
                    }
                    Spacer()
                    Toggle("", isOn: $isEnabled)
                        .tint(Color(hex: "#A78BFA"))
                        .labelsHidden()
                }
                .padding(16)
            }
            .background(settingsCard())
        }
    }

    // MARK: - API Key

    var apiKeySection: some View {
        VStack(spacing: 0) {
            sectionLabel("GOOGLE GEMINI API-NYCKEL")
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                        .frame(width: 20)

                    Group {
                        if showAPIKey {
                            TextField("AIza...", text: $apiKey)
                        } else {
                            SecureField("AIza...", text: $apiKey)
                        }
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "#A78BFA"))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button {
                        withAnimation { showAPIKey.toggle() }
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    apiKey.isEmpty ? Color.white.opacity(0.1) : Color(hex: "#A78BFA").opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                )

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Hämta din nyckel på aistudio.google.com. Nyckeln lagras lokalt på enheten och skickas aldrig vidare.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(settingsCard())
        }
    }

    // MARK: - Intervall

    var intervalSection: some View {
        VStack(spacing: 0) {
            sectionLabel("GENERERINGSINTERVALL")
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("Generera en artikel var")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(intervalLabel(intervalMinutes))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }

                // Intervall-picker
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(intervalOptions, id: \.self) { mins in
                        Button {
                            withAnimation(.spring(response: 0.25)) { intervalMinutes = mins }
                        } label: {
                            Text(intervalLabel(mins))
                                .font(.system(size: 12, weight: intervalMinutes == mins ? .bold : .regular))
                                .foregroundStyle(intervalMinutes == mins ? Color(hex: "#07050F") : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(intervalMinutes == mins ? Color(hex: "#A78BFA") : Color.white.opacity(0.07))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(settingsCard())
        }
    }

    // MARK: - Generera nu

    var generateNowSection: some View {
        VStack(spacing: 0) {
            sectionLabel("MANUELL GENERERING")
            VStack(spacing: 12) {
                // Status
                if gemini.isGenerating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Color(hex: "#A78BFA"))
                            .scaleEffect(0.8)
                        Text("Genererar artikel...")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

                if let err = gemini.lastError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#F87171"))
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#F87171").opacity(0.9))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "#F87171").opacity(0.08))
                    )
                }

                if let last = gemini.lastGeneratedAt {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#34D399"))
                        Text("Senast genererad: \(last.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Button {
                    let settings = GeminiSettings(
                        isEnabled: isEnabled,
                        apiKey: apiKey,
                        intervalMinutes: intervalMinutes
                    )
                    Task { await gemini.generateArticle(viewModel: viewModel, settings: settings) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Generera artikel nu")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(apiKey.isEmpty || gemini.isGenerating ? .white.opacity(0.3) : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Group {
                            if apiKey.isEmpty || gemini.isGenerating {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                            }
                        }
                    )
                }
                .disabled(apiKey.isEmpty || gemini.isGenerating)
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(settingsCard())
        }
    }

    // MARK: - Privacy

    var privacySection: some View {
        VStack(spacing: 0) {
            sectionLabel("INTEGRITET")
            VStack(alignment: .leading, spacing: 10) {
                privacyRow(icon: "checkmark.shield.fill", color: "#34D399",
                    text: "Ingen användardata skickas till Gemini")
                privacyRow(icon: "checkmark.shield.fill", color: "#34D399",
                    text: "Inga konversationer, profiler eller personuppgifter lämnar enheten")
                privacyRow(icon: "checkmark.shield.fill", color: "#34D399",
                    text: "Gemini får endast veta: önskad kategori + formatinstruktioner")
                privacyRow(icon: "checkmark.shield.fill", color: "#34D399",
                    text: "API-nyckeln lagras krypterat lokalt via UserDefaults")
                privacyRow(icon: "info.circle.fill", color: "#60A5FA",
                    text: "Googles integritetspolicy gäller för API-anrop till Gemini")
            }
            .padding(16)
            .background(settingsCard())
        }
    }

    // MARK: - Log

    var logSection: some View {
        Group {
            if !gemini.generationLog.isEmpty {
                VStack(spacing: 0) {
                    sectionLabel("GENERERINGSLOGG")
                    VStack(spacing: 0) {
                        ForEach(gemini.generationLog.prefix(10)) { entry in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: entry.status.color))
                                    .frame(width: 7, height: 7)
                                    .shadow(color: Color(hex: entry.status.color).opacity(0.6), radius: 3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.resultTitle.isEmpty ? entry.category : entry.resultTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineLimit(1)
                                    Text("\(entry.category) · \(entry.startedAt.formatted(date: .omitted, time: .shortened)) · \(entry.status.label)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .overlay(
                                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5),
                                alignment: .bottom
                            )
                        }
                    }
                    .background(settingsCard())
                }
            }
        }
    }

    // MARK: - Helpers

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.3))
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 6)
    }

    func settingsCard() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
            )
    }

    func privacyRow(icon: String, color: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: color))
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func intervalLabel(_ mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        return h == 1 ? "1 timme" : "\(h) timmar"
    }

    // MARK: - Load / Save

    func loadSettings() {
        let s = GeminiSettings.load()
        isEnabled = s.isEnabled
        apiKey = s.apiKey
        intervalMinutes = s.intervalMinutes
    }

    func saveSettings() {
        let s = GeminiSettings(isEnabled: isEnabled, apiKey: apiKey, intervalMinutes: intervalMinutes)
        s.save()
        gemini.restartSchedulerIfNeeded(viewModel: viewModel)
    }
}
