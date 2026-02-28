import Foundation
import NaturalLanguage

// MARK: - SwedishLanguageCore: Koordinerar alla svenska språkkomponenter

actor SwedishLanguageCore {
    static let shared = SwedishLanguageCore()

    private(set) var morphologyEngine: SwedishMorphologyEngine
    private(set) var wsdEngine: SwedishWSDEngine

    private init() {
        morphologyEngine = SwedishMorphologyEngine()
        wsdEngine = SwedishWSDEngine()
    }

    func initialize() async {
        await morphologyEngine.loadLexicon()
        await wsdEngine.initialize()
        print("[Swedish] Alla svenska komponenter initierade ✓")
    }

    // MARK: - Komplett analys av en mening

    func analyze(_ text: String) async -> SwedishAnalysis {
        let morphemes = await morphologyEngine.analyze(text)
        let disambiguations = await wsdEngine.disambiguate(text)
        let register = detectRegister(text)
        let modalParticles = extractModalParticles(text)

        return SwedishAnalysis(
            originalText: text,
            morphemes: morphemes,
            disambiguations: disambiguations,
            register: register,
            modalParticles: modalParticles
        )
    }

    // MARK: - Register-detektion

    private func detectRegister(_ text: String) -> SwedishRegister {
        let formal = ["emellertid", "således", "härav", "varför", "därtill", "beträffande"]
        let informal = ["typ", "liksom", "asså", "ju", "va", "grejen", "kul", "gött"]
        let technical = ["algoritm", "implementation", "konfiguration", "parameter", "funktion"]

        let lower = text.lowercased()
        let formalCount = formal.filter { lower.contains($0) }.count
        let informalCount = informal.filter { lower.contains($0) }.count
        let technicalCount = technical.filter { lower.contains($0) }.count

        if technicalCount > 1 { return .technical }
        if formalCount > informalCount { return .formal }
        if informalCount > formalCount { return .informal }
        return .neutral
    }

    // MARK: - Modal partiklar (ju, väl, nog, visst)

    private func extractModalParticles(_ text: String) -> [ModalParticle] {
        let particles: [(String, ModalParticle.Meaning)] = [
            ("ju", .sharedKnowledge),
            ("väl", .hedging),
            ("nog", .probability),
            ("visst", .confirmation),
            ("faktiskt", .emphasis),
            ("egentligen", .concession)
        ]

        var found: [ModalParticle] = []
        let lower = text.lowercased()
        for (particle, meaning) in particles {
            if lower.contains(" \(particle) ") || lower.hasSuffix(" \(particle)") {
                found.append(ModalParticle(word: particle, meaning: meaning))
            }
        }
        return found
    }
}

// MARK: - SwedishMorphologyEngine (Pelare A)

actor SwedishMorphologyEngine {
    private var lexicon: [String: LexiconEntry] = [:]
    private var isLoaded = false

    func loadLexicon() async {
        guard let url = Bundle.main.url(forResource: "lexicon_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("[Morfologi] lexicon_seed.json ej hittad")
            return
        }

        do {
            let entries = try JSONDecoder().decode([LexiconEntry].self, from: data)
            for entry in entries {
                lexicon[entry.word] = entry
            }
            isLoaded = true
            print("[Morfologi] \(lexicon.count) ord laddade ✓")
        } catch {
            print("[Morfologi] Parsningsfel: \(error)")
        }
    }

    func analyze(_ text: String) async -> [MorphemeAnalysis] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        return words.compactMap { word in
            if let entry = lexicon[word] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: word,
                    pos: entry.pos,
                    morphemes: [word],
                    isCompound: false,
                    forms: entry.forms
                )
            }

            // Kompositaanalys: försök dela upp sammansatta ord
            if word.count > 8 {
                return analyzeCompound(word)
            }

            return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
        }
    }

    private func analyzeCompound(_ word: String) -> MorphemeAnalysis {
        // Sök efter kända prefix i lexikonet
        for splitPoint in stride(from: 3, through: word.count - 3, by: 1) {
            let prefix = String(word.prefix(splitPoint))
            let suffix = String(word.suffix(word.count - splitPoint))

            if lexicon[prefix] != nil && (lexicon[suffix] != nil || suffix.count > 4) {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: word,
                    pos: lexicon[prefix]?.pos ?? "noun",
                    morphemes: [prefix, suffix],
                    isCompound: true,
                    forms: [:]
                )
            }
        }

        return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
    }
}

// MARK: - SwedishWSDEngine (Pelare F)

actor SwedishWSDEngine {
    // Förenklad SALDO-baserad WSD
    private var senseDatabase: [String: [WordSense]] = [:]

    func initialize() async {
        // Ladda grundläggande disambigueringsdata
        loadBuiltInSenses()
        print("[WSD] Disambigueringsmotor initierad ✓")
    }

    private func loadBuiltInSenses() {
        senseDatabase = [
            "band": [
                WordSense(id: "band.1", definition: "musikgrupp", examples: ["rockband", "spelat i band"], confidence: 0.0),
                WordSense(id: "band.2", definition: "remsa, tejp", examples: ["tejpband", "magnetband"], confidence: 0.0),
                WordSense(id: "band.3", definition: "bindning, förbindning", examples: ["blodband", "vänskapsband"], confidence: 0.0)
            ],
            "rätt": [
                WordSense(id: "rätt.1", definition: "korrekt, riktigt", examples: ["rätt svar", "det är rätt"], confidence: 0.0),
                WordSense(id: "rätt.2", definition: "maträtt", examples: ["varmrätt", "förrätt"], confidence: 0.0),
                WordSense(id: "rätt.3", definition: "juridisk rätt", examples: ["mänskliga rättigheter"], confidence: 0.0)
            ],
            "lös": [
                WordSense(id: "lös.1", definition: "inte fastbunden", examples: ["löst hår", "lös knut"], confidence: 0.0),
                WordSense(id: "lös.2", definition: "lösa upp, lösa problem", examples: ["lösa ekvationen"], confidence: 0.0)
            ],
            "spel": [
                WordSense(id: "spel.1", definition: "datorspel, brädspel", examples: ["spela spel", "tv-spel"], confidence: 0.0),
                WordSense(id: "spel.2", definition: "musikspelande", examples: ["pianospel", "gitarrspel"], confidence: 0.0),
                WordSense(id: "spel.3", definition: "teater, skådespeleri", examples: ["skådespelarens spel"], confidence: 0.0)
            ]
        ]
    }

    func disambiguate(_ text: String) async -> [DisambiguationResult] {
        var results: [DisambiguationResult] = []
        let words = text.lowercased().split(separator: " ").map(String.init)

        for word in words {
            guard let senses = senseDatabase[word] else { continue }

            // Kontextbaserad scoring
            let scoredSenses = scoreSenses(senses, context: text, targetWord: word)
            if let best = scoredSenses.first {
                results.append(DisambiguationResult(
                    word: word,
                    selectedSense: best,
                    allSenses: scoredSenses,
                    confidence: best.confidence
                ))
            }
        }

        return results
    }

    private func scoreSenses(_ senses: [WordSense], context: String, targetWord: String) -> [WordSense] {
        let contextWords = Set(context.lowercased().split(separator: " ").map(String.init))

        return senses.map { sense in
            var score = 0.3 // Baslinje
            // Kontextöverlapp med exempelmeningar
            for example in sense.examples {
                let exampleWords = Set(example.lowercased().split(separator: " ").map(String.init))
                let overlap = contextWords.intersection(exampleWords).count
                score += Double(overlap) * 0.2
            }
            var updated = sense
            updated.confidence = min(0.99, score)
            return updated
        }.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Data models

struct LexiconEntry: Codable {
    let word: String
    let pos: String
    let forms: [String: String]
}

struct MorphemeAnalysis: Identifiable {
    let id = UUID()
    let word: String
    let baseForm: String
    let pos: String
    let morphemes: [String]
    let isCompound: Bool
    let forms: [String: String]

    var description: String {
        if isCompound {
            return "\(word) → \(morphemes.joined(separator: "+"))"
        }
        return "\(word) [\(pos)]"
    }
}

struct WordSense: Identifiable {
    let id: String
    let definition: String
    let examples: [String]
    var confidence: Double
}

struct DisambiguationResult: Identifiable {
    let id = UUID()
    let word: String
    let selectedSense: WordSense
    let allSenses: [WordSense]
    let confidence: Double
}

struct SwedishAnalysis {
    let originalText: String
    let morphemes: [MorphemeAnalysis]
    let disambiguations: [DisambiguationResult]
    let register: SwedishRegister
    let modalParticles: [ModalParticle]
}

enum SwedishRegister {
    case formal, neutral, informal, technical
    var label: String {
        switch self {
        case .formal: return "Formellt"
        case .neutral: return "Neutralt"
        case .informal: return "Informellt"
        case .technical: return "Tekniskt"
        }
    }
}

struct ModalParticle: Identifiable {
    let id = UUID()
    let word: String
    let meaning: Meaning

    enum Meaning {
        case sharedKnowledge  // ju
        case hedging          // väl
        case probability      // nog
        case confirmation     // visst
        case emphasis         // faktiskt
        case concession       // egentligen
    }
}
