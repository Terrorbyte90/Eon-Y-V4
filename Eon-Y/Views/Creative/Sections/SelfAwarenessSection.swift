import SwiftUI

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
