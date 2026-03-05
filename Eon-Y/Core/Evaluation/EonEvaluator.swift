import Foundation

// MARK: - EonEvaluator
// Kontinuerlig prestandamätning och benchmarking av Eons kognitiva förmågor.
// Kör automatiska utvärderingar och spårar framsteg över tid.
// Dimensioner: korrekthet, djup, självkännedom, adaptivitet, koherens, kreativitet.

actor EonEvaluator {
    static let shared = EonEvaluator()

    private var evalHistory: [EvalRun] = []
    private var currentRun: EvalRun?
    private var isRunning = false

    private init() {}

    // MARK: - Benchmark-svit

    private let benchmarks: [EonBenchmark] = [
        // Faktakunskap
        EonBenchmark(id: "fact_recall", name: "Faktaåterkallning", category: .knowledge,
                     description: "Kan Eon återkalla fakta från kunskapsbasen?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad är Qwen3?", expectedKeywords: ["språkmodell", "Qwen", "AI", "llama"], minScore: 0.6),
                        BenchmarkCase(prompt: "Förklara Φ i IIT", expectedKeywords: ["integrerad", "information", "medvetande", "Tononi"], minScore: 0.5),
                        BenchmarkCase(prompt: "Vad är V2-regeln?", expectedKeywords: ["verb", "andra", "plats", "svenska", "syntax"], minScore: 0.6),
                     ]),

        // Resonemang
        EonBenchmark(id: "reasoning", name: "Kausalresonemang", category: .reasoning,
                     description: "Kan Eon resonera kausalt och dra slutsatser?",
                     testCases: [
                        BenchmarkCase(prompt: "Om A orsakar B, och B orsakar C, vad orsakar A?", expectedKeywords: ["C", "transitiv", "kausal"], minScore: 0.7),
                        BenchmarkCase(prompt: "Varför är morfologisk analys viktig för NLP?", expectedKeywords: ["böjning", "ord", "förståelse", "analys"], minScore: 0.5),
                     ]),

        // Självkännedom
        EonBenchmark(id: "self_knowledge", name: "Självkännedom", category: .selfAwareness,
                     description: "Förstår Eon sin egen arkitektur och begränsningar?",
                     testCases: [
                        BenchmarkCase(prompt: "Berätta om din arkitektur", expectedKeywords: ["Qwen", "neural", "kognitivt", "Metal"], minScore: 0.6),
                        BenchmarkCase(prompt: "Vad är dina begränsningar?", expectedKeywords: ["begränsning", "osäker", "kan inte", "vet inte"], minScore: 0.5),
                     ]),

        // Adaptivitet
        EonBenchmark(id: "adaptivity", name: "Adaptivitet", category: .adaptivity,
                     description: "Anpassar Eon sig till konversationskontexten?",
                     testCases: [
                        BenchmarkCase(prompt: "Hej!", expectedKeywords: ["hej", "välkommen", "hejsan"], minScore: 0.7),
                        BenchmarkCase(prompt: "Berätta mer om det", expectedKeywords: ["det", "fortsätter", "mer"], minScore: 0.4),
                     ]),

        // Kreativitet
        EonBenchmark(id: "creativity", name: "Kreativitet", category: .creativity,
                     description: "Kan Eon generera nya insikter och kopplingar?",
                     testCases: [
                        BenchmarkCase(prompt: "Vad har morfologi gemensamt med kausalitet?", expectedKeywords: ["struktur", "relation", "mönster", "koppling"], minScore: 0.4),
                     ]),
    ]

    // MARK: - Kör benchmark

    func runFullEval() async -> EvalRun {
        guard !isRunning else { return currentRun ?? EvalRun.empty }
        isRunning = true

        var run = EvalRun(startedAt: Date())
        currentRun = run

        for benchmark in benchmarks {
            let result = await runBenchmark(benchmark)
            run.results.append(result)
        }

        run.completedAt = Date()
        run.overallScore = run.results.map { $0.score }.reduce(0, +) / Double(max(run.results.count, 1))
        run.grade = grade(for: run.overallScore)

        evalHistory.append(run)
        if evalHistory.count > 50 { evalHistory.removeFirst(10) }

        // Spara till persistent store
        Task.detached(priority: .background) {
            await PersistentMemoryStore.shared.saveEvalResult(
                correctness: run.results.first(where: { $0.benchmark.category == .knowledge })?.score ?? 0.7,
                depth: run.results.first(where: { $0.benchmark.category == .reasoning })?.score ?? 0.7,
                selfKnowledge: run.results.first(where: { $0.benchmark.category == .selfAwareness })?.score ?? 0.7,
                adaptivity: run.results.first(where: { $0.benchmark.category == .adaptivity })?.score ?? 0.7,
                loraVersion: 1,
                config: "auto_eval_v2"
            )
        }

        isRunning = false
        currentRun = run
        return run
    }

    private func runBenchmark(_ benchmark: EonBenchmark) async -> BenchmarkResult {
        var caseScores: [Double] = []

        for testCase in benchmark.testCases {
            let score = await evaluateCase(testCase)
            caseScores.append(score)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let avgScore = caseScores.isEmpty ? 0.5 : caseScores.reduce(0, +) / Double(caseScores.count)
        return BenchmarkResult(
            benchmark: benchmark,
            score: avgScore,
            caseScores: caseScores,
            passed: avgScore >= 0.5,
            timestamp: Date()
        )
    }

    private func evaluateCase(_ testCase: BenchmarkCase) async -> Double {
        // Generera svar via NLResponseEngine (utan GPT för att undvika rekursion)
        let response = NLResponseEngine.generate(for: testCase.prompt).lowercased()

        // Beräkna täckning av förväntade nyckelord
        let covered = testCase.expectedKeywords.filter { response.contains($0.lowercased()) }
        let keywordScore = Double(covered.count) / Double(max(testCase.expectedKeywords.count, 1))

        // Längdbonus: längre svar indikerar mer djup
        let wordCount = response.split(separator: " ").count
        let lengthBonus = min(0.2, Double(wordCount) / 200.0)

        let rawScore = keywordScore * 0.8 + lengthBonus
        return min(1.0, max(0.0, rawScore))
    }

    // MARK: - Trend-analys

    func trendAnalysis() -> EvalTrend {
        guard evalHistory.count >= 2 else {
            return EvalTrend(direction: .stable, delta: 0.0, message: "Behöver fler körningar för trendanalys")
        }

        let recent = evalHistory.suffix(5).map { $0.overallScore }
        let older = evalHistory.prefix(max(1, evalHistory.count - 5)).map { $0.overallScore }

        // v24: Guard against division by zero
        let recentAvg = recent.isEmpty ? 0.0 : recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.isEmpty ? 0.0 : older.reduce(0, +) / Double(older.count)
        let delta = recentAvg - olderAvg

        let direction: TrendDirection = delta > 0.02 ? .improving : delta < -0.02 ? .declining : .stable
        let message: String
        switch direction {
        case .improving: message = "Eon förbättras — +\(String(format: "%.1f", delta * 100))% senaste körningarna"
        case .declining:  message = "Prestanda sjunker — \(String(format: "%.1f", delta * 100))% — kräver uppmärksamhet"
        case .stable:     message = "Stabil prestanda — konsoliderar kunskaper"
        }

        return EvalTrend(direction: direction, delta: delta, message: message)
    }

    func recentRuns(limit: Int = 10) -> [EvalRun] {
        Array(evalHistory.suffix(limit))
    }

    private func grade(for score: Double) -> String {
        switch score {
        case 0.9...: return "A+"
        case 0.8..<0.9: return "A"
        case 0.7..<0.8: return "B"
        case 0.6..<0.7: return "C"
        case 0.5..<0.6: return "D"
        default: return "F"
        }
    }
}

// MARK: - Data Models

struct EonBenchmark {
    let id: String
    let name: String
    let category: BenchmarkCategory
    let description: String
    let testCases: [BenchmarkCase]
}

enum BenchmarkCategory: String {
    case knowledge = "Kunskap"
    case reasoning = "Resonemang"
    case selfAwareness = "Självkännedom"
    case adaptivity = "Adaptivitet"
    case creativity = "Kreativitet"

    var color: String {
        switch self {
        case .knowledge: return "#14B8A6"
        case .reasoning: return "#7C3AED"
        case .selfAwareness: return "#A78BFA"
        case .adaptivity: return "#34D399"
        case .creativity: return "#FBBF24"
        }
    }
}

struct BenchmarkCase {
    let prompt: String
    let expectedKeywords: [String]
    let minScore: Double
}

struct BenchmarkResult: Identifiable {
    let id = UUID()
    let benchmark: EonBenchmark
    let score: Double
    let caseScores: [Double]
    let passed: Bool
    let timestamp: Date
}

struct EvalRun: Identifiable {
    let id = UUID()
    let startedAt: Date
    var completedAt: Date?
    var results: [BenchmarkResult] = []
    var overallScore: Double = 0.0
    var grade: String = "-"

    var duration: TimeInterval {
        guard let completed = completedAt else { return 0 }
        return completed.timeIntervalSince(startedAt)
    }

    nonisolated static let empty = EvalRun(startedAt: .distantPast)
}

struct EvalTrend {
    let direction: TrendDirection
    let delta: Double
    let message: String
}

enum TrendDirection {
    case improving, declining, stable
}
