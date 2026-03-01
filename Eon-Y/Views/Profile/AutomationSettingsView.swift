import SwiftUI
import Combine

// MARK: - AutomationSettingsView
// Visar och konfigurerar Eons autonoma kognitiva cykler.
// Nås via Inställningar → "Automation-inställningar".

struct AutomationSettingsView: View {
    @EnvironmentObject var brain: EonBrain
    @ObservedObject private var autonomy = EonLiveAutonomy.shared
    @ObservedObject private var ica = IntegratedCognitiveArchitecture.shared

    // Phase durations (seconds) — persisted via AppStorage
    @AppStorage("eon_phase_duration_inte") private var intensiveDuration = 40
    @AppStorage("eon_phase_duration_inlä") private var learningDuration = 30
    @AppStorage("eon_phase_duration_språ") private var languageDuration = 25
    @AppStorage("eon_phase_duration_vila") private var restDuration = 25

    // Task toggles
    @AppStorage("eon_auto_hypothesis")    private var hypothesisEnabled = true
    @AppStorage("eon_auto_reasoning")     private var reasoningEnabled = true
    @AppStorage("eon_auto_worldmodel")    private var worldModelEnabled = true
    @AppStorage("eon_auto_language_exp")  private var languageExpEnabled = true
    @AppStorage("eon_auto_sprakbanken")   private var sprakbankenEnabled = true
    @AppStorage("eon_auto_consolidation") private var consolidationEnabled = true
    @AppStorage("eon_auto_selfreflect")   private var selfReflectEnabled = true
    @AppStorage("eon_auto_articles")      private var articlesEnabled = true

    @State private var showResetAlert = false

    // Timer for live phase progress
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(hex: "#0D0D1A").ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    headerBar

                    // Live status
                    liveStatusSection

                    // Phase durations
                    phaseDurationSection

                    // Active tasks
                    taskTogglesSection

                    // ICA Pillars
                    icaPillarSection

                    // Reset
                    resetButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .onReceive(timer) { self.now = $0 }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Automation-inställningar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Kognitiv cykelkonfiguration")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#F59E0B"))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Live Status

    private var liveStatusSection: some View {
        let phase = autonomy.currentPhase
        let elapsed = now.timeIntervalSince(autonomy.phaseStartTime)
        let total = Double(phase.durationSeconds)
        let progress = min(elapsed / total, 1.0)

        return settingsGroup(title: "AKTIV FAS", icon: phase.icon, color: Color(hex: phase.color)) {
            // Current phase with progress
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: phase.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: phase.color))
                    Text(phase.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Cykel #\(autonomy.phaseCycleCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: phase.color).opacity(0.7))
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 14)

                HStack {
                    Text("\(Int(elapsed))s / \(Int(total))s")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Text("Nästa: \(phase.next.rawValue)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color(hex: phase.next.color).opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            Divider().background(Color.white.opacity(0.06))

            // Phase cycle overview
            HStack(spacing: 4) {
                ForEach(EonLiveAutonomy.CognitivePhase.phaseOrder, id: \.rawValue) { p in
                    let isActive = p == phase
                    HStack(spacing: 3) {
                        Image(systemName: p.icon)
                            .font(.system(size: 9))
                        Text("\(p.durationSeconds)s")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(hex: p.color).opacity(isActive ? 0.25 : 0.08))
                    )
                    .foregroundStyle(Color(hex: p.color).opacity(isActive ? 1.0 : 0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Phase Duration Configuration

    private var phaseDurationSection: some View {
        settingsGroup(title: "FASTIDER", icon: "timer", color: Color(hex: "#F59E0B")) {
            durationRow("Intensiv", icon: "bolt.fill", color: "#EF4444", value: $intensiveDuration, range: 10...120)
            Divider().background(Color.white.opacity(0.06))
            durationRow("Inlärning", icon: "book.fill", color: "#3B82F6", value: $learningDuration, range: 10...120)
            Divider().background(Color.white.opacity(0.06))
            durationRow("Språk", icon: "textformat.abc", color: "#14B8A6", value: $languageDuration, range: 10...120)
            Divider().background(Color.white.opacity(0.06))
            durationRow("Vila", icon: "moon.fill", color: "#A78BFA", value: $restDuration, range: 10...120)

            Divider().background(Color.white.opacity(0.06))
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#F59E0B").opacity(0.6))
                Text("Total cykel: \(intensiveDuration + learningDuration + languageDuration + restDuration)s (\(String(format: "%.1f", Double(intensiveDuration + learningDuration + languageDuration + restDuration) / 60.0)) min)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func durationRow(_ label: String, icon: String, color: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: color))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("\(value.wrappedValue)s")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(hex: color))
                .frame(width: 40, alignment: .trailing)
            Stepper("", value: value, in: range, step: 5)
                .labelsHidden()
                .tint(Color(hex: color))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Task Toggles

    private var taskTogglesSection: some View {
        settingsGroup(title: "AUTONOMA UPPGIFTER", icon: "checklist", color: Color(hex: "#10B981")) {
            taskToggle("Hypotestestning", icon: "lightbulb.fill", binding: $hypothesisEnabled, color: Color(hex: "#F59E0B"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Resonemangscykler", icon: "brain", binding: $reasoningEnabled, color: Color(hex: "#7C3AED"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Världsmodelluppdatering", icon: "globe.europe.africa", binding: $worldModelEnabled, color: Color(hex: "#3B82F6"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Språkexperiment", icon: "textformat.abc", binding: $languageExpEnabled, color: Color(hex: "#14B8A6"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Språkbanken-hämtning", icon: "arrow.down.doc", binding: $sprakbankenEnabled, color: Color(hex: "#06B6D4"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Konsolidering", icon: "tray.2.fill", binding: $consolidationEnabled, color: Color(hex: "#8B5CF6"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Självreflektion", icon: "person.crop.circle.badge.questionmark", binding: $selfReflectEnabled, color: Color(hex: "#EC4899"))
            Divider().background(Color.white.opacity(0.06))
            taskToggle("Artikelgenerering", icon: "doc.text.fill", binding: $articlesEnabled, color: Color(hex: "#F97316"))
        }
    }

    private func taskToggle(_ label: String, icon: String, binding: Binding<Bool>, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: binding)
                .tint(color)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - ICA Pillars

    private var icaPillarSection: some View {
        settingsGroup(title: "ICA-PELARE (LIVE)", icon: "square.3.layers.3d", color: Color(hex: "#7C3AED")) {
            ForEach(Array(CognitivePillar.allCases.enumerated()), id: \.element) { idx, pillar in
                if idx > 0 {
                    Divider().background(Color.white.opacity(0.06))
                }
                pillarRow(pillar)
            }
        }
    }

    private func pillarRow(_ pillar: CognitivePillar) -> some View {
        let activity = ica.pillarActivity[pillar] ?? 0.0
        let isActive = ica.activePillars.contains(pillar)

        return HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color(hex: "#10B981") : Color.white.opacity(0.15))
                .frame(width: 6, height: 6)

            Text(pillar.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.5))

            Spacer()

            // Activity bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#7C3AED").opacity(0.6))
                        .frame(width: geo.size.width * min(activity, 1.0))
                }
            }
            .frame(width: 60, height: 4)

            Text("\(Int(activity * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            showResetAlert = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14))
                Text("Återställ till standard")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Color(hex: "#F59E0B"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#F59E0B").opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#F59E0B").opacity(0.25), lineWidth: 0.6))
            )
        }
        .alert("Återställ automation?", isPresented: $showResetAlert) {
            Button("Avbryt", role: .cancel) {}
            Button("Återställ", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Alla fasvaraktigheter och uppgiftsinställningar återställs till standardvärden.")
        }
    }

    private func resetToDefaults() {
        intensiveDuration = 40
        learningDuration = 30
        languageDuration = 25
        restDuration = 25
        hypothesisEnabled = true
        reasoningEnabled = true
        worldModelEnabled = true
        languageExpEnabled = true
        sprakbankenEnabled = true
        consolidationEnabled = true
        selfReflectEnabled = true
        articlesEnabled = true
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
}

#Preview {
    EonPreviewContainer {
        AutomationSettingsView()
    }
}
