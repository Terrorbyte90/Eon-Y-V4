import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var brain: EonBrain
    @AppStorage("eon_name")                private var eonName = "Eon"
    @AppStorage("eon_personality")         private var personality = "Standard"
    @AppStorage("eon_proactive")           private var proactiveEnabled = true
    @AppStorage("eon_proactive_interval")  private var proactiveInterval = "Dag"
    @AppStorage("eon_cognitive_mode")      private var cognitiveMode = "Djup"
    @AppStorage("eon_loop1")               private var loop1Enabled = true
    @AppStorage("eon_loop3")               private var loop3Enabled = true
    @AppStorage("eon_cai")                 private var caiEnabled = true
    @AppStorage("eon_cot")                 private var cotEnabled = true
    @AppStorage("eon_save_history")        private var saveHistory = true
    @AppStorage("eon_episodic")            private var episodicEnabled = true
    @AppStorage("eon_knowledge_graph")     private var knowledgeGraphEnabled = true
    @AppStorage("eon_nightly")             private var nightlyConsolidation = true
    @AppStorage("eon_lora")                private var loraTraining = true
    @AppStorage("eon_aero")                private var aeroEnabled = true
    @AppStorage("eon_eval")                private var evalEnabled = true
    @AppStorage("eon_rollback")            private var rollbackEnabled = true
    @AppStorage("eon_sprakbanken")         private var sprakbankenSync = true
    @AppStorage("eon_thoughtglass")        private var thoughtGlassEnabled = true
    @AppStorage("eon_articles_per_interval") private var articlesPerInterval = 1
    @AppStorage("eon_article_interval_minutes") private var articleIntervalMinutes = 60
    @AppStorage("eon_confidence")          private var showConfidence = true
    @AppStorage("eon_dev_mode")            private var devMode = false

    @State private var showResetAlert = false
    @State private var showCognitionLog = false
    @State private var showDiagnosticsLog = false
    @State private var showAutomationSettings = false
    @State private var showAboutEon = false

    let personalities = ["Standard", "Torr", "Varm", "Formell", "Lekfull"]
    let cognitiveModes = ["Djup", "Balanserat", "Snabbt"]
    let proactiveIntervals = ["Dag", "Vecka", "Aldrig"]
    let articleIntervalOptions = [15, 30, 60, 120, 240, 480]

    var body: some View {
        VStack(spacing: 14) {
            // Eon
            settingsGroup(title: "EON", icon: "brain.head.profile", color: Color(hex: "#A78BFA")) {
                settingRow {
                    Label("Namn", systemImage: "person.circle")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    TextField("Eon", text: $eonName)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Divider().background(Color.white.opacity(0.06))
                settingRow {
                    Label("Personlighet", systemImage: "theatermasks")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $personality) {
                        ForEach(personalities, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "#A78BFA"))
                }
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Proaktiva meddelanden", icon: "bolt.circle", binding: $proactiveEnabled, color: Color(hex: "#A78BFA"))
                if proactiveEnabled {
                    Divider().background(Color.white.opacity(0.06))
                    settingRow {
                        Label("Max 1 per", systemImage: "clock")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: $proactiveInterval) {
                            ForEach(proactiveIntervals, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Color(hex: "#A78BFA"))
                    }
                }
            }

            // Intelligens
            settingsGroup(title: "INTELLIGENS", icon: "sparkles", color: Color(hex: "#7C3AED")) {
                settingRow {
                    Label("Kognitivt läge", systemImage: "cpu")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $cognitiveMode) {
                        ForEach(cognitiveModes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "#7C3AED"))
                }
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Chain-of-Thought", icon: "list.number", binding: $cotEnabled, color: Color(hex: "#7C3AED"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Validerings-loop", icon: "checkmark.shield", binding: $loop1Enabled, color: Color(hex: "#7C3AED"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Metacognitiv revision", icon: "brain", binding: $loop3Enabled, color: Color(hex: "#7C3AED"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Constitutional AI", icon: "shield.lefthalf.filled", binding: $caiEnabled, color: Color(hex: "#7C3AED"))
            }

            // Minne
            settingsGroup(title: "MINNE", icon: "memorychip", color: Color(hex: "#3B82F6")) {
                settingToggle("Spara konversationshistorik", icon: "clock.arrow.circlepath", binding: $saveHistory, color: Color(hex: "#3B82F6"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Episodiskt minne", icon: "film", binding: $episodicEnabled, color: Color(hex: "#3B82F6"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Kunskapsgraf", icon: "circle.hexagongrid", binding: $knowledgeGraphEnabled, color: Color(hex: "#3B82F6"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Nattlig konsolidering", icon: "moon.stars", binding: $nightlyConsolidation, color: Color(hex: "#3B82F6"))
            }

            // Autonom evolution
            settingsGroup(title: "AUTONOM EVOLUTION", icon: "arrow.triangle.2.circlepath", color: Color(hex: "#F59E0B")) {
                settingToggle("LoRA-träning", icon: "cpu.fill", binding: $loraTraining, color: Color(hex: "#F59E0B"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("AERO-cykler", icon: "arrow.triangle.2.circlepath.circle", binding: $aeroEnabled, color: Color(hex: "#F59E0B"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Eon-Eval benchmark", icon: "chart.bar", binding: $evalEnabled, color: Color(hex: "#F59E0B"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Automatisk rollback", icon: "arrow.uturn.backward.circle", binding: $rollbackEnabled, color: Color(hex: "#F59E0B"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Språkbanken-sync", icon: "globe.europe.africa", binding: $sprakbankenSync, color: Color(hex: "#F59E0B"))
            }

            // Artikelgenerering
            settingsGroup(title: "ARTIKELGENERERING", icon: "doc.text.fill", color: Color(hex: "#14B8A6")) {
                settingRow {
                    Label("Artiklar per intervall", systemImage: "doc.badge.plus")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Stepper("\(articlesPerInterval)", value: $articlesPerInterval, in: 1...20)
                        .tint(Color(hex: "#14B8A6"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#14B8A6"))
                }
                Divider().background(Color.white.opacity(0.06))
                settingRow {
                    Label("Intervall", systemImage: "timer")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: $articleIntervalMinutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 timme").tag(60)
                        Text("2 timmar").tag(120)
                        Text("4 timmar").tag(240)
                        Text("8 timmar").tag(480)
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "#14B8A6"))
                }
                Divider().background(Color.white.opacity(0.06))
                settingRow {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#14B8A6").opacity(0.6))
                        Text("Eon skriver \(articlesPerInterval) artikel\(articlesPerInterval > 1 ? "ar" : "") var \(articleIntervalMinutes >= 60 ? "\(articleIntervalMinutes / 60) timme\(articleIntervalMinutes / 60 > 1 ? "r" : "")" : "\(articleIntervalMinutes) min") autonomt")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // UI
            settingsGroup(title: "GRÄNSSNITT", icon: "eye", color: Color(hex: "#EC4899")) {
                settingToggle("Thought Glass", icon: "square.3.layers.3d", binding: $thoughtGlassEnabled, color: Color(hex: "#EC4899"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Konfidenspoäng", icon: "shield.fill", binding: $showConfidence, color: Color(hex: "#EC4899"))
                Divider().background(Color.white.opacity(0.06))
                settingToggle("Utvecklarläge", icon: "terminal", binding: $devMode, color: Color(hex: "#EC4899"))
            }

            // Automation-inställningar
            Button {
                showAutomationSettings = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F59E0B").opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automation-inställningar")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Faser, uppgifter & cykelkonfiguration")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#F59E0B").opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 0.6))
                )
            }
            .sheet(isPresented: $showAutomationSettings) {
                AutomationSettingsView()
                    .environmentObject(brain)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }

            // Kognitionslogg
            Button {
                showCognitionLog = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#A78BFA").opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kognitionslogg")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Alla Eons tankar sparade lokalt")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#A78BFA").opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 0.6))
                )
            }
            .sheet(isPresented: $showCognitionLog) {
                CognitionLogView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }

            // Resursdiagnostik
            Button {
                showDiagnosticsLog = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#EF4444").opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resursdiagnostik")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("CPU/värme/ANE/GPU — orsaker & rapport")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(ResourceDiagnosticsLogger.shared.fileSizeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#EF4444").opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: "#EF4444").opacity(0.2), lineWidth: 0.6))
                )
            }
            .sheet(isPresented: $showDiagnosticsLog) {
                DiagnosticsLogView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }

            // Om Eon
            Button {
                showAboutEon = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#A78BFA").opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Om Eon")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Arkitektur, motorer & vetenskapliga teorier")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#A78BFA").opacity(0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 0.6))
                )
            }
            .sheet(isPresented: $showAboutEon) {
                AboutEonView()
            }

            // Reset
            Button {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Återställ Eon")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color(hex: "#EF4444"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#EF4444").opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: "#EF4444").opacity(0.25), lineWidth: 0.6))
                )
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 110)
        .alert("Återställ Eon?", isPresented: $showResetAlert) {
            Button("Avbryt", role: .cancel) {}
            Button("Återställ", role: .destructive) {}
        } message: {
            Text("All inlärning, minnen och personalisering raderas permanent.")
        }
    }

    // MARK: - Helpers

    func settingsGroup<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color.opacity(0.8))
                    .tracking(1.2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color.opacity(0.15), lineWidth: 0.6))
            )
        }
    }

    func settingRow<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        HStack { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
    }

    func settingToggle(_ label: String, icon: String, binding: Binding<Bool>, color: Color) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: binding)
                .tint(color)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

#Preview {
    EonPreviewContainer {
        ScrollView { SettingsView() }
    }
}
