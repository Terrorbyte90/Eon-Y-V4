import SwiftUI

// MARK: - Language Experiment Section

struct LanguageExperimentSection: View {
    @EnvironmentObject var brain: EonBrain
    @State private var experimentInput = ""
    @State private var experimentResult = ""
    @State private var isRunning = false
    @State private var experiments: [(String, String, Date)] = []

    var body: some View {
        VStack(spacing: 14) {
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

    private func runExperiment() {
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

    private func creativeCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
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

    private func generateAnalogy() {
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

    private func analogyCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
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

    private func startDaydream() {
        isDreaming = true
        Task {
            let prompt: String
            switch dreamTheme {
            case "Fri association":
                prompt = "Dagdröm fritt. En kort spontan tankeström på svenska — poetisk, fri. Exakt 2-3 meningar. Sluta efter tredje meningen."
            case "Framtidsvision":
                prompt = "Dagdröm: Hur ser världen ut om 100 år? Skriv visionärt på svenska. Exakt 2-3 meningar. Sluta efter tredje meningen."
            case "Existentiell reflektion":
                prompt = "Reflektera: Vad betyder det att existera och tänka? Skriv filosofiskt på svenska. Exakt 2-3 meningar. Sluta efter tredje meningen."
            case "Kreativ fusion":
                prompt = "Kombinera två orelaterade koncept kreativt på svenska. Exakt 2-3 meningar. Sluta efter tredje meningen."
            default:
                prompt = "Reflektera kort: Vad har du lärt dig? Skriv poetiskt på svenska. Exakt 2-3 meningar. Sluta efter tredje meningen."
            }
            var raw = await NeuralEngineOrchestrator.shared.generate(prompt: prompt, maxTokens: 80)
            // Klipp till max 3 meningar för att undvika rapparkalja
            raw = clampToSentences(raw, max: 3)
            let result = raw
            await MainActor.run {
                daydreamText = result
                dreamHistory.append((result, Date()))
                isDreaming = false
            }
        }
    }

    private func clampToSentences(_ text: String, max maxSentences: Int) -> String {
        let terminators: [Character] = [".", "!", "?"]
        var count = 0
        var result = ""
        for (i, char) in text.enumerated() {
            result.append(char)
            if terminators.contains(char) {
                count += 1
                if count >= maxSentences {
                    // Trim any trailing whitespace/newlines after last sentence
                    return result.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        // If fewer sentences than max, return as-is (trimmed)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dreamCard<Content: View>(tint: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
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
