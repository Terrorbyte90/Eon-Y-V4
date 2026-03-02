import SwiftUI

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
