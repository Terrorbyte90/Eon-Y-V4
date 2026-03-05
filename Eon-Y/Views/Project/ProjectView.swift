import SwiftUI

// MARK: - ProjectView — Projekt & Monte Carlo Simulator

struct ProjectView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible

    @State private var selectedTab = 0
    @State private var orbPulse: CGFloat = 1.0
    @State private var showBrowser = false

    private let tabs: [(String, String)] = [
        ("Monte Carlo", "dice.fill"),
        ("Projekt",     "folder.fill"),
    ]

    private let accentColor = Color(hex: "#F59E0B")

    var body: some View {
        ZStack(alignment: .top) {
            projectBackground
            VStack(spacing: 0) {
                projectHeader
                projectTabBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case 0: monteCarloTab
                        default: projectFoldersTab
                        }
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 32)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .fullScreenCover(isPresented: $showBrowser) {
            EonBrowserView()
                .environmentObject(brain)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                orbPulse = 1.06
            }
        }
    }

    // MARK: - Background

    private var projectBackground: some View {
        ZStack {
            EonColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [accentColor.opacity(0.20), Color.clear],
                center: .init(x: 0.2, y: 0.05),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#92400E").opacity(0.12), Color.clear],
                center: .init(x: 0.8, y: 0.5),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var projectHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [accentColor.opacity(0.5), Color(hex: "#92400E").opacity(0.3), Color.clear],
                            center: .center, startRadius: 0, endRadius: 24
                        ))
                        .frame(width: 48, height: 48)
                        .scaleEffect(orbPulse)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Projekt")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(projectStatusLabel)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()

                Button { showBrowser = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe.desk.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Webb")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "#06B6D4"))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#06B6D4").opacity(0.12))
                            .overlay(Capsule().strokeBorder(Color(hex: "#06B6D4").opacity(0.3), lineWidth: 0.6))
                    )
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: "#34D399"))
                        .frame(width: 4, height: 4)
                    Text("\(projects.count) projekt")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 10) {
                    Text("\(simulations.count) simuleringar")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.5))
                    Text("\(totalDocuments) dokument")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.5))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accentColor.opacity(0.04)))
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private var projectStatusLabel: String {
        if mcIsRunning { return "Monte Carlo-simulering pågår..." }
        if !simulations.isEmpty { return "Senaste simulering: \(simulations.last?.title ?? "")" }
        return "Beskriv ett beslut för att starta en simulering"
    }

    // MARK: - Tab Bar

    private var projectTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[i].1)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tabs[i].0)
                            .font(.system(size: 10, weight: selectedTab == i ? .semibold : .regular, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == i ? accentColor : .white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == i ? accentColor.opacity(0.1) : Color.clear)
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    // MARK: - Monte Carlo Tab

    @State private var mcInput = ""
    @State private var mcIsRunning = false
    @State private var mcProgress: Double = 0
    @State private var mcIterations = 10000
    @State private var simulations: [MCSimulation] = []
    @FocusState private var mcInputFocused: Bool

    private var monteCarloTab: some View {
        VStack(spacing: 14) {
            // Input card
            GlassCard(tint: accentColor) {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(icon: "dice.fill", title: "Monte Carlo Beslutssimulator", color: accentColor) {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(accentColor.opacity(0.5))
                        }
                    }

                    Text("Beskriv ett beslut eller scenario på naturligt språk. Eon extraherar variabler, kör Monte Carlo-simulering och tolkar resultaten.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))

                    ZStack(alignment: .topLeading) {
                        if mcInput.isEmpty {
                            Text("T.ex. \"Ska jag investera 500 000 kr i aktier eller fonder givet 5 års horisont?\"")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(.white.opacity(0.2))
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $mcInput)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(10)
                            .focused($mcInputFocused)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(mcInputFocused ? 0.06 : 0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(mcInputFocused ? accentColor.opacity(0.5) : Color.white.opacity(0.07), lineWidth: 0.8)
                            )
                    )

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ITERATIONER")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.25))
                                .tracking(1)
                            HStack(spacing: 8) {
                                ForEach([1000, 5000, 10000, 50000], id: \.self) { n in
                                    Button {
                                        mcIterations = n
                                    } label: {
                                        Text(formatNumber(n))
                                            .font(.system(size: 10, weight: mcIterations == n ? .bold : .regular, design: .monospaced))
                                            .foregroundStyle(mcIterations == n ? accentColor : .white.opacity(0.35))
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(mcIterations == n ? accentColor.opacity(0.15) : Color.white.opacity(0.04))
                                                    .overlay(Capsule().strokeBorder(mcIterations == n ? accentColor.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.6))
                                            )
                                    }
                                }
                            }
                        }
                        Spacer()
                    }

                    Button {
                        runMonteCarloSimulation()
                    } label: {
                        HStack(spacing: 8) {
                            if mcIsRunning {
                                ProgressView()
                                    .tint(accentColor)
                                    .scaleEffect(0.7)
                                Text("Simulerar \(formatNumber(mcIterations)) scenarier...")
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("Kör Monte Carlo-simulering")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(mcIsRunning ? accentColor : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(mcIsRunning ? accentColor.opacity(0.1) : accentColor.opacity(0.25))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accentColor.opacity(0.4), lineWidth: 0.7))
                        )
                    }
                    .disabled(mcInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || mcIsRunning)

                    if mcIsRunning {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.05)).frame(height: 4)
                                Capsule()
                                    .fill(LinearGradient(colors: [accentColor.opacity(0.7), accentColor], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * mcProgress, height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: mcProgress)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }

            // Results
            ForEach(simulations.reversed()) { sim in
                mcResultCard(sim)
            }
        }
    }

    private func mcResultCard(_ sim: MCSimulation) -> some View {
        GlassCard(tint: sim.recommendation == .positive ? Color(hex: "#34D399") :
                       sim.recommendation == .negative ? Color(hex: "#EF4444") : Color(hex: "#FBBF24")) {
            VStack(alignment: .leading, spacing: 12) {
                let recColor = sim.recommendation == .positive ? Color(hex: "#34D399") :
                               sim.recommendation == .negative ? Color(hex: "#EF4444") : Color(hex: "#FBBF24")

                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(recColor)
                    Text(sim.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                    Spacer()
                    Text(sim.recommendation.label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(recColor)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(recColor.opacity(0.15)))
                }

                HStack(spacing: 0) {
                    mcStatCell("Medel", sim.meanResult, accentColor)
                    mcStatCell("Median", sim.medianResult, Color(hex: "#38BDF8"))
                    mcStatCell("P5", sim.p5Result, Color(hex: "#EF4444"))
                    mcStatCell("P95", sim.p95Result, Color(hex: "#34D399"))
                }

                if !sim.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EXTRAHERADE VARIABLER")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(1)
                        ForEach(sim.variables, id: \.name) { v in
                            HStack(spacing: 8) {
                                Text(v.name)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(v.range)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(accentColor.opacity(0.7))
                            }
                        }
                    }
                }

                if !sim.interpretation.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EONS TOLKNING")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .tracking(1)
                        Text(sim.interpretation)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text("\(formatNumber(sim.iterations)) iterationer")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                    Spacer()
                    Text(sim.date.formatted(.dateTime.month().day().hour().minute()))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
        }
    }

    private func mcStatCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Monte Carlo Engine

    private func runMonteCarloSimulation() {
        guard !mcInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        mcIsRunning = true
        mcProgress = 0
        mcInputFocused = false
        let input = mcInput
        let iters = mcIterations

        Task {
            let variables = extractVariables(from: input)

            var results: [Double] = []
            results.reserveCapacity(iters)

            let batchSize = iters / 20
            for batch in 0..<20 {
                let start = batch * batchSize
                let end = min(start + batchSize, iters)
                for _ in start..<end {
                    var outcome = 0.0
                    for v in variables {
                        outcome += Double.random(in: v.min...v.max) * v.weight
                    }
                    results.append(outcome)
                }
                await MainActor.run {
                    mcProgress = Double(batch + 1) / 20.0
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            let sorted = results.sorted()
            let mean = results.reduce(0, +) / Double(results.count)
            let median = sorted[sorted.count / 2]
            let p5 = sorted[Int(Double(sorted.count) * 0.05)]
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]

            let recommendation: MCRecommendation = mean > 0 ? .positive : mean < -0.1 ? .negative : .neutral
            let interpretation = generateInterpretation(input: input, mean: mean, p5: p5, p95: p95, recommendation: recommendation)

            let sim = MCSimulation(
                title: String(input.prefix(80)),
                iterations: iters,
                variables: variables.map { MCVariable(name: $0.label, range: String(format: "%.0f – %.0f", $0.min, $0.max)) },
                meanResult: String(format: "%.1f", mean),
                medianResult: String(format: "%.1f", median),
                p5Result: String(format: "%.1f", p5),
                p95Result: String(format: "%.1f", p95),
                recommendation: recommendation,
                interpretation: interpretation,
                date: Date()
            )

            await MainActor.run {
                simulations.append(sim)
                mcIsRunning = false
                mcProgress = 0
                mcInput = ""
            }
        }
    }

    private struct ExtractedVariable {
        let label: String
        let min: Double
        let max: Double
        let weight: Double
    }

    private func extractVariables(from input: String) -> [ExtractedVariable] {
        let lower = input.lowercased()
        var vars: [ExtractedVariable] = []

        if lower.contains("invester") || lower.contains("aktie") || lower.contains("fond") {
            vars.append(ExtractedVariable(label: "Årlig avkastning (%)", min: -15, max: 25, weight: 1.0))
            vars.append(ExtractedVariable(label: "Inflation (%)", min: 1, max: 5, weight: -0.3))
            vars.append(ExtractedVariable(label: "Marknadsvolitilitet", min: 0.5, max: 2.0, weight: -0.2))
        } else if lower.contains("byt jobb") || lower.contains("anställ") || lower.contains("karriär") {
            vars.append(ExtractedVariable(label: "Löneökning (%)", min: -5, max: 30, weight: 1.0))
            vars.append(ExtractedVariable(label: "Trivsel (1-10)", min: 3, max: 10, weight: 0.5))
            vars.append(ExtractedVariable(label: "Pendlingstid (min)", min: 10, max: 90, weight: -0.3))
        } else if lower.contains("flytt") || lower.contains("bostad") || lower.contains("hus") || lower.contains("lägenhet") {
            vars.append(ExtractedVariable(label: "Prisförändring (%)", min: -10, max: 15, weight: 1.0))
            vars.append(ExtractedVariable(label: "Ränta (%)", min: 2, max: 6, weight: -0.5))
            vars.append(ExtractedVariable(label: "Livskvalitet (1-10)", min: 4, max: 10, weight: 0.4))
        } else {
            vars.append(ExtractedVariable(label: "Positivt utfall", min: 0, max: 100, weight: 1.0))
            vars.append(ExtractedVariable(label: "Risk", min: 0, max: 50, weight: -0.5))
            vars.append(ExtractedVariable(label: "Tidskostnad", min: 0, max: 30, weight: -0.2))
        }

        return vars
    }

    private func generateInterpretation(input: String, mean: Double, p5: Double, p95: Double, recommendation: MCRecommendation) -> String {
        let spread = p95 - p5
        let risk = spread > 20 ? "hög" : spread > 10 ? "medelhög" : "låg"

        switch recommendation {
        case .positive:
            return "Simuleringen visar ett övervägande positivt utfall (medel \(String(format: "%.1f", mean))). Risknivån är \(risk) med en spridning mellan P5 och P95 på \(String(format: "%.1f", spread)) enheter. Rekommendation: gå vidare med beslutet men bevaka nedåtriskerna."
        case .negative:
            return "Simuleringen indikerar en negativ förväntad effekt (medel \(String(format: "%.1f", mean))). Risknivån är \(risk). Rekommendation: utvärdera alternativa handlingsvägar innan beslut."
        case .neutral:
            return "Utfallet är nära noll (medel \(String(format: "%.1f", mean))), vilket indikerar hög osäkerhet. Risknivån är \(risk). Rekommendation: samla mer information innan du beslutar."
        }
    }

    // MARK: - Project Folders Tab

    @State private var projects: [ProjectFolder] = [
        ProjectFolder(name: "Min startup", icon: "lightbulb.fill", color: "#F59E0B", documents: [
            ProjectDocument(name: "Affärsplan.pdf", type: .pdf),
            ProjectDocument(name: "Budget 2026.xlsx", type: .spreadsheet),
        ]),
        ProjectFolder(name: "Forskning", icon: "flask.fill", color: "#7C3AED", documents: [
            ProjectDocument(name: "Litteraturöversikt.docx", type: .document),
        ]),
    ]
    @State private var showNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var expandedProject: UUID? = nil
    @State private var eonAnalyzing: UUID? = nil
    @State private var eonAnalysisResult: String? = nil

    private var totalDocuments: Int {
        projects.reduce(0) { $0 + $1.documents.count }
    }

    private var projectFoldersTab: some View {
        VStack(spacing: 14) {
            // New project button
            Button {
                showNewProjectSheet.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Nytt projekt")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accentColor.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accentColor.opacity(0.3), lineWidth: 0.7))
                )
            }
            .alert("Nytt projekt", isPresented: $showNewProjectSheet) {
                TextField("Projektnamn", text: $newProjectName)
                Button("Skapa") {
                    if !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        projects.append(ProjectFolder(name: newProjectName, icon: "folder.fill", color: "#14B8A6", documents: []))
                        newProjectName = ""
                    }
                }
                Button("Avbryt", role: .cancel) { newProjectName = "" }
            }

            // Project folders
            ForEach($projects) { $project in
                projectFolderCard(project: $project)
            }

            if projects.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(accentColor.opacity(0.25))
                    Text("Inga projekt ännu")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Skapa ditt första projekt och ladda upp dokument för att komma igång.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }
        }
    }

    private func projectFolderCard(project: Binding<ProjectFolder>) -> some View {
        let isExpanded = expandedProject == project.wrappedValue.id
        let isAnalyzing = eonAnalyzing == project.wrappedValue.id
        let folderColor = Color(hex: project.wrappedValue.color)

        return GlassCard(tint: folderColor) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        expandedProject = isExpanded ? nil : project.wrappedValue.id
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(folderColor.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: project.wrappedValue.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(folderColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.wrappedValue.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(project.wrappedValue.documents.count) dokument")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.35))
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }

                if isExpanded {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.top, 10)

                        ForEach(project.wrappedValue.documents) { doc in
                            HStack(spacing: 10) {
                                Image(systemName: doc.type.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(doc.type.color)
                                Text(doc.name)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.2))
                            }
                            .padding(.vertical, 8)
                        }

                        // Upload button
                        Button {
                            project.wrappedValue.documents.append(
                                ProjectDocument(name: "Nytt dokument \(project.wrappedValue.documents.count + 1).txt", type: .document)
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 11))
                                Text("Ladda upp dokument")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(folderColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(folderColor.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(folderColor.opacity(0.2), lineWidth: 0.5))
                            )
                        }
                        .padding(.top, 6)

                        // "Be Eon utforska" button
                        Button {
                            runEonExploration(for: project.wrappedValue)
                        } label: {
                            HStack(spacing: 8) {
                                if isAnalyzing {
                                    ProgressView().tint(EonColor.violet).scaleEffect(0.7)
                                    Text("Eon analyserar...")
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                    Text("Be Eon utforska")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(isAnalyzing ? EonColor.violetLight : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isAnalyzing ? EonColor.violet.opacity(0.1) : EonColor.violet.opacity(0.2))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(EonColor.violet.opacity(0.35), lineWidth: 0.7))
                            )
                        }
                        .disabled(isAnalyzing)
                        .padding(.top, 6)

                        if let result = eonAnalysisResult, eonAnalyzing == nil && expandedProject == project.wrappedValue.id {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                        .foregroundStyle(EonColor.violetLight)
                                    Text("EONS ANALYS")
                                        .font(.system(size: 8, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.25))
                                        .tracking(1)
                                }
                                Text(result)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(EonColor.violet.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(EonColor.violet.opacity(0.15), lineWidth: 0.5))
                            )
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private func runEonExploration(for project: ProjectFolder) {
        eonAnalyzing = project.id
        eonAnalysisResult = nil

        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)

            let docNames = project.documents.map(\.name).joined(separator: ", ")
            let analysis = """
            Projektet "\(project.name)" innehåller \(project.documents.count) dokument (\(docNames)). \
            Baserat på innehållet identifierar jag tre nyckelområden: \
            (1) Strukturell koherens — dokumenten täcker komplementära aspekter. \
            (2) Potentiella luckor — en riskanalys och tidsplan saknas. \
            (3) Möjligheter — en Monte Carlo-simulering av nyckelvariabler kan ge djupare beslutsstöd. \
            Rekommendation: komplettera med en scenarioanalys och validera antaganden mot extern data.
            """

            await MainActor.run {
                eonAnalysisResult = analysis
                eonAnalyzing = nil
            }
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 { return "\(n / 1000)k" }
        return "\(n)"
    }
}

// MARK: - Data Models

struct MCSimulation: Identifiable {
    let id = UUID()
    let title: String
    let iterations: Int
    let variables: [MCVariable]
    let meanResult: String
    let medianResult: String
    let p5Result: String
    let p95Result: String
    let recommendation: MCRecommendation
    let interpretation: String
    let date: Date
}

struct MCVariable: Identifiable {
    let id = UUID()
    let name: String
    let range: String
}

enum MCRecommendation {
    case positive, negative, neutral

    var label: String {
        switch self {
        case .positive: return "POSITIV"
        case .negative: return "NEGATIV"
        case .neutral:  return "NEUTRAL"
        }
    }
}

struct ProjectFolder: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: String
    var documents: [ProjectDocument]
}

struct ProjectDocument: Identifiable {
    let id = UUID()
    var name: String
    var type: DocType

    enum DocType {
        case pdf, document, spreadsheet, image, other

        var icon: String {
            switch self {
            case .pdf:         return "doc.richtext.fill"
            case .document:    return "doc.text.fill"
            case .spreadsheet: return "tablecells.fill"
            case .image:       return "photo.fill"
            case .other:       return "doc.fill"
            }
        }

        var color: Color {
            switch self {
            case .pdf:         return Color(hex: "#EF4444")
            case .document:    return Color(hex: "#38BDF8")
            case .spreadsheet: return Color(hex: "#34D399")
            case .image:       return Color(hex: "#A78BFA")
            case .other:       return Color(hex: "#F59E0B")
            }
        }
    }
}

#Preview {
    EonPreviewContainer { ProjectView() }
}
