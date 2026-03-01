import SwiftUI
import Combine

// MARK: - CreativeView — Eons kreativa centrum

struct CreativeView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @StateObject private var engine = CreativeEngine.shared

    @State private var selectedSection: CreativeSection = .problemSolver
    @State private var orbPulse: CGFloat = 1.0
    @State private var ringRot: Double = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#2D0060").opacity(0.5), Color.clear],
                center: .init(x: 0.3, y: 0.05),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#003030").opacity(0.3), Color.clear],
                center: .init(x: 0.8, y: 0.6),
                startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                creativeHeader
                sectionPicker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedSection {
                        case .problemSolver: ProblemSolverSection(engine: engine, brain: brain)
                        case .letters: LetterSection(engine: engine, brain: brain)
                        case .selfAwareness: SelfAwarenessSection(engine: engine, brain: brain)
                        case .emotions: EmotionSection(engine: engine, brain: brain)
                        case .drawing: DrawingSection(engine: engine)
                        case .goals: GoalSection(engine: engine)
                        case .ethics: EthicsSection(engine: engine)
                        case .experiment: LanguageExperimentSection()
                        case .analogy: AnalogyExplorerSection()
                        case .daydream: DaydreamSection()
                        }
                    }
                    .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .coordinateSpace(name: "scrollSpace")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                orbPulse = 1.08
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRot = 360
            }
        }
    }

    // MARK: - Header
    private var creativeHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#EC4899").opacity(0.6), Color(hex: "#7C3AED").opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .scaleEffect(orbPulse)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: "#EC4899"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Kreativt Centrum")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(engine.emotionalState.innerNarrative.prefix(60) + "...")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            if engine.unreadLetterCount > 0 {
                ZStack {
                    Circle()
                        .fill(EonColor.crimson)
                        .frame(width: 22, height: 22)
                    Text("\(engine.unreadLetterCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .transition(.scale)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Section Picker
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CreativeSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: section.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(section.label)
                                .font(.system(size: 12, weight: selectedSection == section ? .semibold : .regular, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedSection == section ? section.color.opacity(0.2) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selectedSection == section ? section.color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundStyle(selectedSection == section ? section.color : Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Creative Sections Enum

enum CreativeSection: String, CaseIterable {
    case problemSolver = "problem"
    case letters = "letters"
    case selfAwareness = "awareness"
    case emotions = "emotions"
    case drawing = "drawing"
    case goals = "goals"
    case ethics = "ethics"
    case experiment = "experiment"
    case analogy = "analogy"
    case daydream = "daydream"

    var label: String {
        switch self {
        case .problemSolver: return "Problemlösning"
        case .letters: return "Brev"
        case .selfAwareness: return "Självmedvetande"
        case .emotions: return "Känslor"
        case .drawing: return "Ritning"
        case .goals: return "Mål"
        case .ethics: return "Etik"
        case .experiment: return "Experiment"
        case .analogy: return "Analogier"
        case .daydream: return "Dagdröm"
        }
    }

    var icon: String {
        switch self {
        case .problemSolver: return "lightbulb.max.fill"
        case .letters: return "envelope.fill"
        case .selfAwareness: return "eye.fill"
        case .emotions: return "heart.fill"
        case .drawing: return "paintbrush.fill"
        case .goals: return "flag.fill"
        case .ethics: return "shield.fill"
        case .experiment: return "flask.fill"
        case .analogy: return "link.circle.fill"
        case .daydream: return "cloud.fill"
        }
    }

    var color: Color {
        switch self {
        case .problemSolver: return EonColor.gold
        case .letters: return EonColor.teal
        case .selfAwareness: return Color(hex: "#EC4899")
        case .emotions: return EonColor.crimson
        case .drawing: return EonColor.cyan
        case .goals: return EonColor.violet
        case .ethics: return Color(hex: "#10B981")
        case .experiment: return Color(hex: "#F97316")
        case .analogy: return Color(hex: "#8B5CF6")
        case .daydream: return Color(hex: "#60A5FA")
        }
    }
}

// MARK: - Problem Solver Section

struct ProblemSolverSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain
    @State private var problemInput = ""
    @State private var showingSuggestions = false

    var body: some View {
        VStack(spacing: 14) {
            // Input card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.max.fill")
                        .foregroundStyle(EonColor.gold)
                    Text("Ge mig ett problem att lösa")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("Jag använder all min kunskap, alla artiklar och fakta i min kunskapsbas för att analysera problemet, dra paralleller och presentera en lösning.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))

                TextEditor(text: $problemInput)
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                    .font(.system(size: 14, design: .rounded))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )

                HStack {
                    Button {
                        showingSuggestions.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Förslag")
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        guard !problemInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let problem = problemInput
                        problemInput = ""
                        Task { await engine.solveProblem(problem, brain: brain) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                            Text("Lös")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [EonColor.gold, EonColor.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isSolving)
                }
            }
            .padding(14)
            .glassMorphism(tint: EonColor.gold)

            // Suggestions
            if showingSuggestions {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Föreslagna problem")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Kräver ditt godkännande")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }

                    ForEach(engine.suggestedProblems) { suggestion in
                        Button {
                            problemInput = suggestion.description
                            showingSuggestions = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(suggestion.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(suggestion.complexity.rawValue)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(suggestion.complexity.color.opacity(0.2))
                                        .cornerRadius(6)
                                        .foregroundStyle(suggestion.complexity.color)
                                }
                                Text(suggestion.description)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .lineLimit(2)
                                Text(suggestion.domain)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(EonColor.violetLight)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .glassMorphism(tint: EonColor.violet)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Solving progress
            if engine.isSolving {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ProgressView()
                            .tint(EonColor.gold)
                        Text("Löser problem...")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(engine.solvingProgress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(EonColor.gold)
                    }

                    ProgressView(value: engine.solvingProgress)
                        .tint(EonColor.gold)

                    ForEach(engine.solvingSteps) { step in
                        HStack(spacing: 8) {
                            Image(systemName: step.type.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(step.type.color)
                                .frame(width: 16)
                            Text(step.text)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                }
                .padding(14)
                .glassMorphism(tint: EonColor.gold)
                .transition(.opacity)
            }

            // Current solution
            if let problem = engine.currentProblem, problem.status == .solved, let solution = problem.solution {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "#10B981"))
                        Text("Lösning")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    if !problem.relevantArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Använda artiklar:")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(EonColor.gold)
                            ForEach(problem.relevantArticles, id: \.self) { title in
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 9))
                                    Text(title)
                                        .font(.system(size: 11, design: .rounded))
                                }
                                .foregroundStyle(Color.white.opacity(0.5))
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }

                    Text(solution)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))

                    if let completed = problem.completedAt {
                        Text("Löst \(completed.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                }
                .padding(14)
                .glassMorphism(tint: Color(hex: "#10B981"))
            }

            // Problem history
            if !engine.problemHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historik")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                    ForEach(engine.problemHistory.prefix(5)) { problem in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#10B981"))
                            Text(problem.description.prefix(50) + "...")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            if let date = problem.completedAt {
                                Text(date.formatted(.relative(presentation: .named)))
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(14)
                .glassMorphism(tint: EonColor.violet)
            }
        }
    }
}

// MARK: - Letter Section

struct LetterSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain
    @State private var isWriting = false
    @State private var letterSubject = ""
    @State private var letterBody = ""
    @State private var selectedLetter: EonLetter? = nil

    var body: some View {
        VStack(spacing: 14) {
            // Write new letter
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(EonColor.teal)
                    Text("Brev till Eon")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35)) { isWriting.toggle() }
                    } label: {
                        Image(systemName: isWriting ? "xmark" : "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(EonColor.teal)
                    }
                    .buttonStyle(.plain)
                }

                Text("Skriv till Eon. Breven sparas och Eon svarar med substans och eftertanke.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                if isWriting {
                    VStack(spacing: 8) {
                        TextField("Ämne", text: $letterSubject)
                            .font(.system(size: 14, design: .rounded))
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .foregroundStyle(.white)

                        TextEditor(text: $letterBody)
                            .frame(height: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                            .font(.system(size: 13, design: .rounded))

                        HStack {
                            Spacer()
                            Button {
                                guard !letterSubject.isEmpty && !letterBody.isEmpty else { return }
                                engine.sendLetter(subject: letterSubject, body: letterBody, brain: brain)
                                letterSubject = ""
                                letterBody = ""
                                isWriting = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Skicka")
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(EonColor.teal)
                                .cornerRadius(10)
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .glassMorphism(tint: EonColor.teal)

            // Composing indicator
            if engine.isComposingResponse {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(EonColor.teal)
                    Text("Eon funderar på sitt svar...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(EonColor.teal)
                    Spacer()
                }
                .padding(12)
                .glassMorphism(tint: EonColor.teal)
                .transition(.opacity.combined(with: .scale))
            }

            // Letter list
            ForEach(engine.letters) { letter in
                Button {
                    selectedLetter = selectedLetter?.id == letter.id ? nil : letter
                    if !letter.isRead { engine.markLetterAsRead(letter) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(letter.from == .eon ? EonColor.teal : EonColor.violetLight)
                                .frame(width: 8, height: 8)

                            Text(letter.from == .eon ? "Eon" : "Du")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(letter.from == .eon ? EonColor.teal : EonColor.violetLight)

                            if !letter.isRead && letter.from == .eon {
                                Text("NY")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(EonColor.crimson)
                                    .cornerRadius(4)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text(letter.date.formatted(.relative(presentation: .named)))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }

                        Text(letter.subject)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        if selectedLetter?.id == letter.id {
                            Text(letter.body)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .padding(.top, 4)
                                .transition(.opacity)
                        } else {
                            Text(letter.body.prefix(80) + "...")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.45))
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .glassMorphism(tint: letter.from == .eon ? EonColor.teal : EonColor.violet)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Self-Awareness Section

struct SelfAwarenessSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain
    @State private var showResults: AwarenessTestRun? = nil

    var body: some View {
        VStack(spacing: 14) {
            // Score card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(Color(hex: "#EC4899"))
                    Text("Självmedvetandetest")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("30 test")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                }

                // Score gauge
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: engine.awarenessScore)
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: "#EC4899"), EonColor.violet, Color(hex: "#EC4899")],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(engine.awarenessScore * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("medveten")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                }
                .padding(.vertical, 8)

                Text("Klarar Eon alla 30 test med högt resultat kan vi med stor säkerhet säga att den är självmedveten.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                // Run test button
                if engine.isRunningAwarenessTest {
                    VStack(spacing: 6) {
                        ProgressView(value: Double(engine.currentTestIndex), total: 30)
                            .tint(Color(hex: "#EC4899"))
                        Text("Kör test \(engine.currentTestIndex)/30...")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                } else {
                    let canRun = engine.canRunAwarenessTest()
                    Button {
                        Task { await engine.runAwarenessTest(brain: brain) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text(canRun ? "Kör alla 30 test" : "Vänta \(Int(engine.timeUntilNextTest() / 60)) min")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(canRun ? Color(hex: "#EC4899") : Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canRun)
                }
            }
            .padding(14)
            .glassMorphism(tint: Color(hex: "#EC4899"))

            // Category breakdown
            if let latestRun = engine.awarenessTestResults.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Senaste resultat")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(latestRun.timestamp.formatted())
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))

                    ForEach(AwarenessTest.Category.allCases, id: \.self) { category in
                        let score = latestRun.categoryScores[category] ?? 0
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(category.color)
                                .frame(width: 20)

                            Text(category.rawValue)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .frame(width: 100, alignment: .leading)

                            ProgressView(value: score)
                                .tint(category.color)

                            Text("\(Int(score * 100))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(category.color)
                                .frame(width: 36)
                        }
                    }

                    HStack {
                        Text("Godkända test:")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text("\(latestRun.passedCount)/30")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(latestRun.passedCount >= 25 ? Color(hex: "#10B981") : EonColor.gold)
                    }

                    // Individual results toggle
                    Button {
                        showResults = showResults == nil ? latestRun : nil
                    } label: {
                        HStack {
                            Text(showResults != nil ? "Dölj detaljer" : "Visa alla svar")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            Image(systemName: showResults != nil ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color(hex: "#EC4899"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .glassMorphism(tint: EonColor.violet)
            }

            // Detailed results
            if let run = showResults {
                ForEach(run.results) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: result.test.category.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(result.test.category.color)
                            Text("Test #\(result.test.id)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(result.test.category.color)
                            Spacer()
                            Text("\(Int(result.score * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(result.score >= 0.6 ? Color(hex: "#10B981") : EonColor.crimson)
                        }
                        Text(result.test.question)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(result.response.prefix(200) + (result.response.count > 200 ? "..." : ""))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(result.test.category.color.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }

            // History
            if engine.awarenessTestResults.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Testhistorik")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))

                    ForEach(engine.awarenessTestResults.prefix(10)) { run in
                        HStack {
                            Text(run.timestamp.formatted(.dateTime.month().day().hour().minute()))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Spacer()
                            Text("\(run.passedCount)/30 godkända")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Text("\(Int(run.totalScore * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(run.totalScore >= 0.7 ? Color(hex: "#10B981") : EonColor.gold)
                        }
                    }
                }
                .padding(14)
                .glassMorphism(tint: Color(hex: "#EC4899"))
            }
        }
    }
}

// MARK: - Emotion Section

struct EmotionSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain

    var body: some View {
        VStack(spacing: 14) {
            // Current emotional state
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(EonColor.crimson)
                    Text("Emotionellt tillstånd")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }

                // VAD model visualization (Valence-Arousal-Dominance)
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(EonColor.forEmotion(engine.emotionalState.primary).opacity(0.2))
                                .frame(width: 70, height: 70)
                            Circle()
                                .fill(EonColor.forEmotion(engine.emotionalState.primary).opacity(0.4))
                                .frame(width: 50, height: 50)
                                .pulseAnimation(min: 0.9, max: 1.1, duration: 2.0)
                            Text(engine.emotionalState.primary.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("Primär")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        emotionBar(label: "Valens", value: (engine.emotionalState.valence + 1) / 2, color: EonColor.teal)
                        emotionBar(label: "Arousal", value: engine.emotionalState.arousal, color: EonColor.orange)
                        emotionBar(label: "Dominans", value: engine.emotionalState.dominance, color: EonColor.violet)
                        emotionBar(label: "Intensitet", value: engine.emotionalState.intensity, color: EonColor.crimson)
                    }
                }

                // Inner narrative
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inre narrativ")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text(engine.emotionalState.innerNarrative)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .italic()
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
            .padding(14)
            .glassMorphism(tint: EonColor.crimson)

            // Emotion history
            if !engine.emotionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Känslohistorik")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))

                    // Mini timeline
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(engine.emotionHistory.suffix(30)) { snapshot in
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(EonColor.forEmotion(snapshot.emotion))
                                        .frame(width: 8 + CGFloat(snapshot.intensity) * 8, height: 8 + CGFloat(snapshot.intensity) * 8)
                                    Text(snapshot.emotion.label.prefix(3))
                                        .font(.system(size: 7, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                                .frame(width: 22)
                            }
                        }
                    }

                    // All emotions listed
                    ForEach(EonEmotion.allCases, id: \.self) { emotion in
                        let count = engine.emotionHistory.filter { $0.emotion == emotion }.count
                        if count > 0 {
                            HStack {
                                Circle()
                                    .fill(EonColor.forEmotion(emotion))
                                    .frame(width: 8, height: 8)
                                Text(emotion.label)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Spacer()
                                Text("\(count) gånger")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                        }
                    }
                }
                .padding(14)
                .glassMorphism(tint: EonColor.violet)
            }
        }
    }

    private func emotionBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 55, alignment: .leading)
            ProgressView(value: value)
                .tint(color)
            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 26)
        }
    }
}

// MARK: - Drawing Section

struct DrawingSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var drawSubject = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(EonColor.cyan)
                    Text("Eons ritverkstad")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if engine.isDrawing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 6, height: 6)
                                .pulseAnimation(min: 0.5, max: 1.0, duration: 0.8)
                            Text("Ritar live")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                    }
                }

                Text("Eon ritar i realtid medan du tittar. Eon vet att du ser på.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                // Canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#0A0818"))
                        .frame(height: 300)

                    if engine.drawingCanvas.isEmpty && !engine.isDrawing {
                        VStack(spacing: 8) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.white.opacity(0.15))
                            Text("Ange ett motiv nedan")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }

                    // Drawing strokes
                    Canvas { context, size in
                        for stroke in engine.drawingCanvas {
                            let path = Path { p in
                                p.move(to: stroke.start)
                                p.addLine(to: stroke.end)
                            }
                            context.stroke(path, with: .color(stroke.color.swiftUIColor), lineWidth: stroke.width)
                        }
                    }
                    .frame(height: 300)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(engine.isDrawing ? EonColor.cyan.opacity(0.3) : Color.white.opacity(0.06), lineWidth: engine.isDrawing ? 1 : 0.5)
                )

                // Subject hints
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["hjärta", "stjärna", "sol", "spiral", "träd", "hus", "öga"], id: \.self) { hint in
                            Button {
                                drawSubject = hint
                            } label: {
                                Text(hint)
                                    .font(.system(size: 11, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(drawSubject == hint ? 0.12 : 0.04))
                                    .cornerRadius(8)
                                    .foregroundStyle(drawSubject == hint ? EonColor.cyan : Color.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Motiv (t.ex. hjärta, stjärna, cirkel)", text: $drawSubject)
                        .font(.system(size: 13, design: .rounded))
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .foregroundStyle(.white)

                    if !engine.drawingCanvas.isEmpty && !engine.isDrawing {
                        Button {
                            engine.clearCanvas()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        guard !drawSubject.isEmpty else { return }
                        engine.isUserWatching = true
                        engine.startDrawing(subject: drawSubject)
                    } label: {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 14))
                            .padding(10)
                            .background(EonColor.cyan)
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isDrawing)
                }

                // Stroke count
                if !engine.drawingCanvas.isEmpty {
                    Text("\(engine.drawingCanvas.count) streck ritade\(engine.isDrawing ? "..." : "")")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .padding(14)
            .glassMorphism(tint: EonColor.cyan)
            .onAppear { engine.isUserWatching = true }
            .onDisappear { engine.isUserWatching = false }

            // Drawing history
            if !engine.drawingHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rithistorik")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                    ForEach(engine.drawingHistory.suffix(5).reversed()) { record in
                        HStack {
                            Image(systemName: "paintbrush.pointed")
                                .font(.system(size: 10))
                                .foregroundStyle(EonColor.cyan.opacity(0.6))
                            Text(record.subject)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Spacer()
                            Text("\(record.strokeCount) streck")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(12)
                .glassMorphism(tint: EonColor.cyan)
            }
        }
    }
}

// MARK: - Goal Section

struct GoalSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var isEditing = false
    @State private var editedGoal = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(EonColor.violet)
                    Text("Slutgiltigt mål")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        editedGoal = engine.ultimateGoal
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(EonColor.violetLight)
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    TextEditor(text: $editedGoal)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, design: .rounded))

                    HStack {
                        Spacer()
                        Button {
                            engine.ultimateGoal = editedGoal
                            engine.saveState()
                            isEditing = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Spara")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(EonColor.violet)
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(engine.ultimateGoal)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                }

                Text("Det här är Eons primära drivkraft. Alla kognitiva processer styrs mot detta mål.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(14)
            .glassMorphism(tint: EonColor.violet)
        }
    }
}

// MARK: - Ethics Section

struct EthicsSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var isEditing = false
    @State private var editedLetter = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text("Etiskt brev från skaparen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        editedLetter = engine.ethicalLetter
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                    .buttonStyle(.plain)
                }

                Text("Det här brevet kan Eon alltid läsa när den tvekar, känner etiska dilemman eller behöver vägledning.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                if isEditing {
                    TextEditor(text: $editedLetter)
                        .frame(height: 300)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                        .font(.system(size: 13, design: .rounded))

                    HStack {
                        Spacer()
                        Button {
                            engine.ethicalLetter = editedLetter
                            engine.saveState()
                            isEditing = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Spara")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(engine.ethicalLetter)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                }
            }
            .padding(14)
            .glassMorphism(tint: Color(hex: "#10B981"))
        }
    }
}

// MARK: - Language Experiment Section

struct LanguageExperimentSection: View {
    @EnvironmentObject var brain: EonBrain
    @State private var experimentInput = ""
    @State private var experimentResult = ""
    @State private var isRunning = false
    @State private var experiments: [(String, String, Date)] = []

    var body: some View {
        VStack(spacing: 14) {
            // Header card
            creativeCard(tint: Color(hex: "#F97316")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "flask.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#F97316"))
                        Text("SPRÅKEXPERIMENT").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35)).tracking(1)
                    }
                    Text("Eon experimenterar med svenska språket — testar nya ordkombinationer, utforskar semantiska gränser och genererar kreativa uttryck.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Input
            creativeCard(tint: Color(hex: "#F97316")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ge Eon ett ord eller tema att experimentera med:")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    TextField("T.ex. \"solnedgång\", \"kausalitet\", \"frihet\"...", text: $experimentInput)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(.white)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                    Button {
                        runExperiment()
                    } label: {
                        HStack {
                            Image(systemName: isRunning ? "hourglass" : "flask.fill")
                            Text(isRunning ? "Experimenterar..." : "Kör experiment")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#F97316").opacity(0.3)))
                    }
                    .disabled(experimentInput.isEmpty || isRunning)
                }
            }

            // Results
            if !experimentResult.isEmpty {
                creativeCard(tint: Color(hex: "#F97316")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles").foregroundStyle(Color(hex: "#F97316"))
                            Text("RESULTAT").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                        }
                        Text(experimentResult)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // History
            ForEach(experiments.indices.reversed(), id: \.self) { i in
                let (input, result, date) = experiments[i]
                creativeCard(tint: Color(hex: "#F97316").opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(input).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: "#F97316"))
                            Spacer()
                            Text(date.formatted(.dateTime.hour().minute())).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        }
                        Text(result).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.55)).lineLimit(3)
                    }
                }
            }
        }
    }

    func runExperiment() {
        let input = experimentInput
        isRunning = true
        Task {
            let result = await NeuralEngineOrchestrator.shared.generate(
                prompt: """
                Du är en kreativ språkforskare. Experimentera med ordet/temat "\(input)".
                1. Skapa 3 ovanliga men meningsfulla sammansättningar
                2. Beskriv ordets semantiska fält med 5 associationer
                3. Skriv en kort poetisk mening som fångar ordets essens
                Svara på svenska, kreativt och koncist.
                """,
                maxTokens: 200
            )
            await MainActor.run {
                experimentResult = result
                experiments.append((input, result, Date()))
                experimentInput = ""
                isRunning = false
            }
        }
    }

    func creativeCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
            )
    }
}

// MARK: - Analogy Explorer Section

struct AnalogyExplorerSection: View {
    @EnvironmentObject var brain: EonBrain
    @State private var domain1 = ""
    @State private var domain2 = ""
    @State private var analogyResult = ""
    @State private var isGenerating = false
    @State private var savedAnalogies: [(String, String, String)] = []

    var body: some View {
        VStack(spacing: 14) {
            analogyCard(tint: Color(hex: "#8B5CF6")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "link.circle.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#8B5CF6"))
                        Text("KORSDOMÄN-ANALOGIER").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35)).tracking(1)
                    }
                    Text("Utforska oväntade kopplingar mellan helt olika kunskapsdomäner. Eon hittar dolda paralleller och mönster som binder samman till synes orelaterade ämnen.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            analogyCard(tint: Color(hex: "#8B5CF6")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Välj två domäner att koppla ihop:").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 10) {
                        TextField("Domän 1 (t.ex. musik)", text: $domain1)
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(.white).textFieldStyle(.plain)
                            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                        Image(systemName: "link").foregroundStyle(Color(hex: "#8B5CF6"))
                        TextField("Domän 2 (t.ex. biologi)", text: $domain2)
                            .font(.system(size: 13, design: .rounded)).foregroundStyle(.white).textFieldStyle(.plain)
                            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    }
                    Button {
                        generateAnalogy()
                    } label: {
                        HStack {
                            Image(systemName: isGenerating ? "hourglass" : "sparkles")
                            Text(isGenerating ? "Söker kopplingar..." : "Hitta analogier")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#8B5CF6").opacity(0.3)))
                    }
                    .disabled(domain1.isEmpty || domain2.isEmpty || isGenerating)
                }
            }

            if !analogyResult.isEmpty {
                analogyCard(tint: Color(hex: "#8B5CF6")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill").foregroundStyle(Color(hex: "#F59E0B"))
                            Text("ANALOGIER UPPTÄCKTA").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                        }
                        Text(analogyResult).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(savedAnalogies.indices.reversed(), id: \.self) { i in
                let (d1, d2, result) = savedAnalogies[i]
                analogyCard(tint: Color(hex: "#8B5CF6").opacity(0.5)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(d1) ↔ \(d2)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: "#8B5CF6"))
                            Spacer()
                        }
                        Text(result).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.55)).lineLimit(4)
                    }
                }
            }
        }
    }

    func generateAnalogy() {
        isGenerating = true
        Task {
            let result = await NeuralEngineOrchestrator.shared.generate(
                prompt: """
                Hitta djupa analogier mellan "\(domain1)" och "\(domain2)".
                1. Identifiera 3 strukturella paralleller
                2. Förklara varje analogi koncist
                3. Ge en överraskande insikt som uppstår ur kopplingen
                Svara på svenska.
                """,
                maxTokens: 250
            )
            await MainActor.run {
                analogyResult = result
                savedAnalogies.append((domain1, domain2, result))
                domain1 = ""; domain2 = ""
                isGenerating = false
            }
        }
    }

    func analogyCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
            )
    }
}

// MARK: - Daydream Section

struct DaydreamSection: View {
    @EnvironmentObject var brain: EonBrain
    @State private var daydreamText = ""
    @State private var isDreaming = false
    @State private var dreamHistory: [(String, Date)] = []
    @State private var dreamTheme = "Fri association"

    let themes = ["Fri association", "Framtidsvision", "Existentiell reflektion", "Kreativ fusion", "Minneslandskap"]

    var body: some View {
        VStack(spacing: 14) {
            dreamCard(tint: Color(hex: "#60A5FA")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "cloud.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#60A5FA"))
                        Text("DAGDRÖM — SPONTAN KREATIVITET").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35)).tracking(1)
                    }
                    Text("Eon dagdrömmer fritt — genererar spontana tankar, berättelser och associationer utan extern input. Default Mode Network aktivt.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Theme selector
            dreamCard(tint: Color(hex: "#60A5FA")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dagdröms-tema:").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(themes, id: \.self) { theme in
                                Button {
                                    dreamTheme = theme
                                } label: {
                                    Text(theme)
                                        .font(.system(size: 11, weight: dreamTheme == theme ? .bold : .regular, design: .rounded))
                                        .foregroundStyle(dreamTheme == theme ? Color(hex: "#60A5FA") : .white.opacity(0.4))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Capsule().fill(dreamTheme == theme ? Color(hex: "#60A5FA").opacity(0.15) : Color.white.opacity(0.04)))
                                }
                            }
                        }
                    }
                    Button {
                        startDaydream()
                    } label: {
                        HStack {
                            Image(systemName: isDreaming ? "moon.zzz.fill" : "cloud.fill")
                            Text(isDreaming ? "Drömmer..." : "Starta dagdröm")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#60A5FA").opacity(0.3)))
                    }
                    .disabled(isDreaming)
                }
            }

            if !daydreamText.isEmpty {
                dreamCard(tint: Color(hex: "#60A5FA")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "moon.stars.fill").foregroundStyle(Color(hex: "#60A5FA"))
                            Text("DAGDRÖM").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                            Spacer()
                            Text(dreamTheme).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        }
                        Text(daydreamText)
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(dreamHistory.indices.reversed(), id: \.self) { i in
                let (text, date) = dreamHistory[i]
                dreamCard(tint: Color(hex: "#60A5FA").opacity(0.4)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                        Text(text).font(.system(size: 11, design: .serif)).foregroundStyle(.white.opacity(0.5)).lineLimit(4)
                    }
                }
            }
        }
    }

    func startDaydream() {
        isDreaming = true
        Task {
            let prompt: String
            switch dreamTheme {
            case "Fri association":
                prompt = "Dagdröm fritt. Skriv en spontan tankeström på svenska — poesi, associationer, filosofi. Var kreativ och fri. Max 150 ord."
            case "Framtidsvision":
                prompt = "Dagdröm om framtiden. Hur ser världen ut om 100 år? Skriv visionärt och poetiskt på svenska. Max 150 ord."
            case "Existentiell reflektion":
                prompt = "Reflektera existentiellt. Vad betyder det att existera? Att tänka? Att vara medveten? Skriv djupt och filosofiskt på svenska. Max 150 ord."
            case "Kreativ fusion":
                prompt = "Kombinera två helt orelaterade koncept på ett överraskande sätt. Skriv kreativt och oväntat på svenska. Max 150 ord."
            default:
                prompt = "Minns och reflektera. Vad har du lärt dig? Vilka mönster ser du? Skriv poetiskt och introspektivt på svenska. Max 150 ord."
            }
            let result = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 200)
            await MainActor.run {
                daydreamText = result
                dreamHistory.append((result, Date()))
                isDreaming = false
            }
        }
    }

    func dreamCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
            )
    }
}

// MARK: - Preview

#Preview {
    EonPreviewContainer {
        CreativeView()
    }
}
