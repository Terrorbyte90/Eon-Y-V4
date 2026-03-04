import SwiftUI
import Combine

struct ProfileRootView: View {
    @EnvironmentObject var userProfile: UserProfileEngine
    @EnvironmentObject var brain: EonBrain
    @State private var selectedSection = 0

    // v6: Consciousness engine references for development tracking
    @ObservedObject private var consciousness = ConsciousnessEngine.shared
    @ObservedObject private var oscillators = OscillatorBank.shared
    @ObservedObject private var activeInference = ActiveInferenceEngine.shared
    @ObservedObject private var criticality = CriticalityController.shared
    @ObservedObject private var sleepEngine = SleepConsolidationEngine.shared

    @State private var orbPulse: CGFloat = 1.0

    private let tabs: [(String, String)] = [
        ("Profil",          "person.fill"),
        ("Inställningar",   "gearshape.fill"),
        ("Loggar",          "doc.text.fill"),
        ("Om Eon",          "info.circle.fill"),
    ]

    private let accentColor = Color(hex: "#F59E0B")
    private let secondaryAccent = Color(hex: "#92400E")

    var body: some View {
        ZStack(alignment: .top) {
            profileBackground

            VStack(spacing: 0) {
                profileHeader
                profileTabBar

                // Sektion-innehåll
                switch selectedSection {
                case 0:
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            profileSection
                            Color.clear.frame(height: 20)
                        }
                    }
                case 1:
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            SettingsView()
                            Color.clear.frame(height: 20)
                        }
                    }
                case 2:
                    UnifiedLogView()
                case 3:
                    AboutEonView(embedded: true)
                default:
                    ScrollView(showsIndicators: false) {
                        profileSection
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                orbPulse = 1.06
            }
        }
    }

    // MARK: - Background

    private var profileBackground: some View {
        ZStack {
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [accentColor.opacity(0.25), Color.clear],
                center: .init(x: 0.2, y: 0.05),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [secondaryAccent.opacity(0.15), Color.clear],
                center: .init(x: 0.8, y: 0.5),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    var profileHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [accentColor.opacity(0.5), secondaryAccent.opacity(0.3), Color.clear],
                            center: .center, startRadius: 0, endRadius: 24
                        ))
                        .frame(width: 48, height: 48)
                        .scaleEffect(orbPulse)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Profil")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(profileStatusLabel)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
            }

            // Metrics strip
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: "#34D399"))
                        .frame(width: 4, height: 4)
                        .shadow(color: Color(hex: "#34D399").opacity(0.8), radius: 2)
                    Text("Aktiv sedan \(userProfile.profile.knownSince.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "#34D399").opacity(0.8))
                }
                Spacer()
                HStack(spacing: 10) {
                    Text("\(userProfile.totalConversations) samtal")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.5))
                    Text("\(brain.knowledgeNodeCount) noder")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.5))
                    Text("\(userProfile.uniqueVocabularySize) ord")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.5))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accentColor.opacity(0.04)))
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private var profileStatusLabel: String {
        let convs = userProfile.totalConversations
        if convs > 100 { return "Djup relation — \(convs) konversationer" }
        if convs > 30 { return "Växande förståelse — bygger kunskapsbild" }
        if convs > 5 { return "Lär känna dig — samlar intryck" }
        return "Ny användare — välkommen!"
    }

    // MARK: - Tab Bar

    private var profileTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedSection = i }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[i].1)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tabs[i].0)
                            .font(.system(size: 10, weight: selectedSection == i ? .semibold : .regular, design: .rounded))
                    }
                    .foregroundStyle(selectedSection == i ? accentColor : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedSection == i ? accentColor.opacity(0.1) : Color.clear
                    )
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    // Formatera ordantal: 1 234 → "1,2k" om > 999
    private var wordCountLabel: String {
        let n = userProfile.totalWordCount
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
        return "\(n)"
    }

    // Engagemang: baserat på kommunikationsstil (frågefrekvens + meddelandelängd)
    private var engagementLabel: String {
        let style = userProfile.communicationStyle
        let score = min(1.0, style.questionFrequency * 0.5 + min(1.0, style.avgMessageLength / 40.0) * 0.5)
        return "\(Int(score * 100))%"
    }

    private var userInitials: String {
        let name = userProfile.profile.eonDescription
        let words = name.components(separatedBy: " ").prefix(2)
        return words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
            .isEmpty ? "AN" : words.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    // MARK: - Profile Section

    var profileSection: some View {
        VStack(spacing: 14) {
            UserIdentityCard()
            CommunicationProfileView(style: userProfile.communicationStyle)

            // v15: Session summary (consciousness dev moved to Self-Awareness)
            sessionSummaryCard

            InterestRadarCard(axes: userProfile.interestRadarData, conversations: userProfile.totalConversations, sessions: userProfile.totalSessions)
            ProfileMemoryTimeline(memories: userProfile.topMemories)

            // v15: Relationship card
            relationshipCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 110)
    }

    // MARK: - Session Summary Card (v15)
    var sessionSummaryCard: some View {
        GlassCard(tint: Color(hex: "#38BDF8")) {
            VStack(alignment: .leading, spacing: 12) {
                // v25: Replace EmptyView with session status indicator
                PanelHeader(icon: "clock.badge.checkmark.fill", title: "Sessionsöversikt", color: Color(hex: "#38BDF8")) {
                    Text("S\(userProfile.totalSessions)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                }

                HStack(spacing: 0) {
                    ProfileStatItem(value: "\(userProfile.totalSessions)", label: "Sessioner", color: Color(hex: "#38BDF8"))
                    Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                    ProfileStatItem(value: "\(userProfile.totalConversations)", label: "Meddelanden", color: Color(hex: "#A78BFA"))
                    Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                    ProfileStatItem(value: "\(brain.knowledgeNodeCount)", label: "Kunskapsnoder", color: Color(hex: "#FBBF24"))
                }
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
                )

                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile").font(.system(size: 11)).foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                    Text("Stadium: \(brain.developmentalStage.displayName)")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("II: \(String(format: "%.1f%%", brain.integratedIntelligence * 100))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                }
            }
        }
    }

    // MARK: - Relationship Card (v15)
    var relationshipCard: some View {
        GlassCard(tint: Color(hex: "#EC4899")) {
            VStack(alignment: .leading, spacing: 12) {
                // v25: Replace EmptyView with relationship depth indicator
                PanelHeader(icon: "heart.text.square.fill", title: "Eons relation till dig", color: Color(hex: "#EC4899")) {
                    let depth = min(1.0, Double(userProfile.totalConversations) / 50.0)
                    Text("\(Int(depth * 100))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#EC4899").opacity(0.6))
                }

                let depth = min(1.0, Double(userProfile.totalConversations) / 50.0)
                let trust = min(1.0, depth * 0.6 + userProfile.communicationStyle.directnessPreference * 0.4)
                let engage = min(1.0, userProfile.communicationStyle.questionFrequency * 0.5 + min(1.0, userProfile.communicationStyle.avgMessageLength / 40.0) * 0.5)

                HStack(spacing: 0) {
                    relationMetric(label: "Djup", value: depth, color: Color(hex: "#EC4899"))
                    Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                    relationMetric(label: "Förtroende", value: trust, color: Color(hex: "#A78BFA"))
                    Divider().background(Color.white.opacity(0.1)).frame(height: 30)
                    relationMetric(label: "Engagemang", value: engage, color: Color(hex: "#34D399"))
                }

                Text("Ju mer vi pratar, desto bättre förstår jag dig.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func relationMetric(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

// MARK: - Profile Stat Item

struct ProfileStatItem: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - User Identity Card

struct UserIdentityCard: View {
    @EnvironmentObject var userProfile: UserProfileEngine
    @EnvironmentObject var brain: EonBrain
    @State private var editingDescription = false
    @State private var editText = ""

    var body: some View {
        GlassCard(tint: Color(hex: "#F472B6")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color(hex: "#F472B6").opacity(0.3), Color(hex: "#7C3AED").opacity(0.15)],
                                center: .center, startRadius: 0, endRadius: 28
                            ))
                            .frame(width: 56, height: 56)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "#F472B6"))
                    }
                    .shadow(color: Color(hex: "#F472B6").opacity(0.3), radius: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Du")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Känd sedan \(userProfile.profile.knownSince.formatted(.dateTime.day().month().year()))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("\(userProfile.totalConversations) konversationsturer")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    Spacer()
                }

                Divider().background(Color(hex: "#F472B6").opacity(0.2))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Eons beskrivning av dig")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Spacer()
                        Button {
                            editText = userProfile.profile.eonDescription
                            editingDescription = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#F472B6").opacity(0.7))
                        }
                    }
                    Text(userProfile.profile.eonDescription)
                        .font(.system(size: 13, design: .rounded).italic())
                        .foregroundStyle(Color.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheet(isPresented: $editingDescription) {
            EditDescriptionSheet(text: $editText) {
                userProfile.profile.eonDescription = editText
                userProfile.saveProfile()
            }
        }
    }
}

struct EditDescriptionSheet: View {
    @Binding var text: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                TextEditor(text: $text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(16)
            }
            .navigationTitle("Redigera beskrivning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }.foregroundStyle(Color(hex: "#A78BFA"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { onSave(); dismiss() }.foregroundStyle(Color(hex: "#34D399"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Communication Profile

struct CommunicationProfileView: View {
    let style: CommunicationStyle

    var bars: [(String, Double, String)] {
        [
            ("Svarlängd",    min(style.avgMessageLength / 50.0, 1.0), style.avgMessageLength > 25 ? "Detaljerat" : "Kort"),
            ("Frågor",       style.questionFrequency,                 style.questionFrequency > 0.5 ? "Ofta" : "Ibland"),
            ("Formalitet",   style.formalityScore,                    style.formalityScore > 0.5 ? "Formell" : "Informell"),
            ("Humor",        style.humorAppreciation,                 style.humorAppreciation > 0.5 ? "Uppskattas" : "Neutral"),
            ("Direkthet",    style.directnessPreference,              style.directnessPreference > 0.5 ? "Direkt" : "Nyanserat")
        ]
    }

    var body: some View {
        GlassCard(tint: Color(hex: "#A78BFA")) {
            VStack(alignment: .leading, spacing: 12) {
                // v25: Replace EmptyView with communication style label
                PanelHeader(icon: "person.wave.2.fill", title: "Kommunikationsprofil", color: Color(hex: "#A78BFA")) {
                    Text("Profil")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                }

                ForEach(bars, id: \.0) { label, value, desc in
                    HStack(spacing: 10) {
                        Text(label)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 80, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.07))
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: "#A78BFA").opacity(0.6), Color(hex: "#A78BFA")],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * value)
                                    .animation(.easeInOut(duration: 1.0), value: value)
                            }
                        }
                        .frame(height: 5)

                        Text(desc)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .frame(width: 70, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Interest Radar Card

struct InterestRadarCard: View {
    let axes: [RadarAxis]
    let conversations: Int
    let sessions: Int

    private let accentColor = Color(hex: "#06B6D4")

    var body: some View {
        GlassCard(tint: accentColor) {
            VStack(alignment: .leading, spacing: 14) {
                // v25: Replace EmptyView with conversation count badge
                PanelHeader(icon: "chart.bar.xaxis", title: "Intressen & Aktivitet", color: accentColor) {
                    Text("\(conversations)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.6))
                }

                // Aktivitetsöversikt
                HStack(spacing: 0) {
                    activityStat(value: "\(conversations)", label: "Samtal", icon: "bubble.left.and.bubble.right.fill", color: accentColor)
                    Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                    activityStat(value: "\(sessions)", label: "Sessioner", icon: "calendar.badge.clock", color: Color(hex: "#A78BFA"))
                    Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                    activityStat(value: topInterest, label: "Topintresse", icon: "star.fill", color: Color(hex: "#FBBF24"))
                }
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
                )

                // Intresseaxlar som horisontella staplar
                VStack(spacing: 8) {
                    ForEach(sortedAxes.prefix(6)) { axis in
                        HStack(spacing: 10) {
                            Text(axis.label)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .frame(width: 72, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.06))
                                    Capsule()
                                        .fill(LinearGradient(
                                            colors: [accentColor.opacity(0.5), accentColor],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(width: max(4, geo.size.width * axis.value))
                                        .animation(.easeInOut(duration: 0.8), value: axis.value)
                                }
                            }
                            .frame(height: 6)

                            Text("\(Int(axis.value * 100))%")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(accentColor.opacity(0.7))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var sortedAxes: [RadarAxis] {
        axes.sorted { $0.value > $1.value }
    }

    private var topInterest: String {
        sortedAxes.first?.label ?? "–"
    }

    private func activityStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Profile Memory Timeline

struct ProfileMemoryTimeline: View {
    let memories: [UserMemory]

    var body: some View {
        GlassCard(tint: Color(hex: "#FBBF24")) {
            VStack(alignment: .leading, spacing: 12) {
                // v25: Replace EmptyView with memory count badge
                PanelHeader(icon: "sparkles", title: "Eons minnen om dig", color: Color(hex: "#FBBF24")) {
                    Text("\(memories.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.6))
                }

                if memories.isEmpty {
                    Text("Eon lär känna dig. Minnen byggs upp under konversationer.")
                        .font(.system(size: 12, design: .rounded).italic())
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(memories.prefix(5))) { memory in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color(hex: "#FBBF24").opacity(0.6))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memory.description)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.75))
                                    .lineLimit(2)
                                Text(memory.date.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.28))
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Radar Polygon (kept for compatibility)

struct RadarPolygon: View {
    let values: [Double]
    let color: Color

    private func radarPoint(index: Int, total: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = Double(index) / Double(total) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }

    private func gridPath(level: Double, total: Int, radius: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        let r = radius * CGFloat(level)
        for i in 0..<total {
            let pt = radarPoint(index: i, total: total, radius: r, center: center)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func dataPath(total: Int, radius: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        for i in 0..<total {
            let r = radius * CGFloat(max(values[i], 0.05))
            let pt = radarPoint(index: i, total: total, radius: r, center: center)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let total = values.count
            ZStack {
                gridPath(level: 0.25, total: total, radius: radius, center: center)
                    .stroke(color.opacity(0.12), lineWidth: 0.5)
                gridPath(level: 0.5, total: total, radius: radius, center: center)
                    .stroke(color.opacity(0.12), lineWidth: 0.5)
                gridPath(level: 0.75, total: total, radius: radius, center: center)
                    .stroke(color.opacity(0.12), lineWidth: 0.5)
                gridPath(level: 1.0, total: total, radius: radius, center: center)
                    .stroke(color.opacity(0.12), lineWidth: 0.5)
                dataPath(total: total, radius: radius, center: center)
                    .fill(color.opacity(0.18))
                dataPath(total: total, radius: radius, center: center)
                    .stroke(color, lineWidth: 1.5)
            }
        }
    }
}

#Preview {
    EonPreviewContainer { ProfileRootView() }
}
