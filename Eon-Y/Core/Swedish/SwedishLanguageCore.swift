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
        let formalWords = ["emellertid", "således", "härav", "därtill", "beträffande", "avseende", "vederbörande", "härmed", "dock"]
        let informalWords = ["typ", "liksom", "asså", "ju", "va", "grejen", "kul", "gött", "skit", "jävla", "fett", "soft"]
        let technicalWords = ["algoritm", "implementation", "konfiguration", "parameter", "funktion", "databas", "server", "api", "framework"]

        let lower = text.lowercased()
        let words = lower.components(separatedBy: .whitespaces)

        // Positional weighting: words at the start of sentences carry more register signal
        var formalScore: Double = 0
        var informalScore: Double = 0
        var technicalScore: Double = 0

        for (i, word) in words.enumerated() {
            let positionWeight = i < 5 ? 1.5 : 1.0 // Opening words weighted 1.5x
            if formalWords.contains(word) { formalScore += positionWeight }
            if informalWords.contains(word) { informalScore += positionWeight }
            if technicalWords.contains(word) { technicalScore += positionWeight }
        }

        // Sentence structure indicators
        let avgWordLength = words.isEmpty ? 0 : Double(words.map { $0.count }.reduce(0, +)) / Double(words.count)
        if avgWordLength > 7.0 { formalScore += 0.5 } // Long words → formal
        if avgWordLength < 4.5 { informalScore += 0.3 } // Short words → informal

        // Exclamation/emoji → informal
        if text.contains("!") || text.contains("😂") || text.contains("🤔") { informalScore += 0.5 }

        if technicalScore > 2.0 { return .technical }
        if formalScore > informalScore + 0.5 { return .formal }
        if informalScore > formalScore + 0.5 { return .informal }
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
            ("egentligen", .concession),
            ("dock", .concession),
            ("ändå", .concession),
            ("liksom", .hedging),
            ("typ", .hedging),
        ]

        var found: [ModalParticle] = []
        let words = text.lowercased().components(separatedBy: .whitespaces)
        for (particle, meaning) in particles {
            if words.contains(particle) {
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

            // Compound analysis: try to split unknown words (Swedish compounds can be short)
            if word.count > 6 {
                let compoundResult = analyzeCompound(word)
                if compoundResult.isCompound || compoundResult.pos != "unknown" {
                    return compoundResult
                }
            }

            return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
        }
    }

    /// Common Swedish compound linking morphemes ("fog")
    private static let compoundLinks = ["s", "e", "o", "u", "es"]

    /// Known Swedish prefixes that modify meaning
    private static let knownPrefixes = ["be", "för", "under", "över", "om", "an", "upp", "av", "ut", "in", "på", "fram", "till", "åter", "sam", "mot"]

    private func analyzeCompound(_ word: String) -> MorphemeAnalysis {
        // Strategy 1: Check known prefixes first (be-, för-, under-, etc.)
        for prefix in Self.knownPrefixes {
            if word.hasPrefix(prefix) && word.count > prefix.count + 3 {
                let stem = String(word.dropFirst(prefix.count))
                if lexicon[stem] != nil {
                    return MorphemeAnalysis(
                        word: word, baseForm: word,
                        pos: lexicon[stem]?.pos ?? "verb",
                        morphemes: [prefix, stem],
                        isCompound: true, forms: [:]
                    )
                }
            }
        }

        // Strategy 2: Try all split points, including with compound linking morpheme ("s", "e")
        var bestSplit: (prefix: String, suffix: String, score: Double)?
        for splitPoint in stride(from: 3, through: word.count - 3, by: 1) {
            let prefix = String(word.prefix(splitPoint))
            let suffix = String(word.suffix(word.count - splitPoint))

            // Direct split: both parts in lexicon
            let prefixKnown = lexicon[prefix] != nil
            let suffixKnown = lexicon[suffix] != nil

            if prefixKnown && suffixKnown {
                let score = Double(prefix.count + suffix.count) / Double(word.count) // Longer parts = better
                if bestSplit == nil || score > bestSplit!.score {
                    bestSplit = (prefix, suffix, score)
                }
            } else if prefixKnown && suffix.count > 4 {
                // Known prefix + unknown but long suffix (might be an unlexed word)
                let score = Double(prefix.count) / Double(word.count) * 0.7
                if bestSplit == nil || score > bestSplit!.score {
                    bestSplit = (prefix, suffix, score)
                }
            }

            // Try removing a compound linking morpheme between parts
            for link in Self.compoundLinks {
                if suffix.hasPrefix(link) && suffix.count > link.count + 3 {
                    let actualSuffix = String(suffix.dropFirst(link.count))
                    if prefixKnown && lexicon[actualSuffix] != nil {
                        let score = Double(prefix.count + actualSuffix.count) / Double(word.count) + 0.1
                        if bestSplit == nil || score > bestSplit!.score {
                            bestSplit = (prefix, actualSuffix, score)
                        }
                    }
                }
            }
        }

        if let split = bestSplit {
            return MorphemeAnalysis(
                word: word, baseForm: word,
                pos: lexicon[split.suffix]?.pos ?? lexicon[split.prefix]?.pos ?? "noun",
                morphemes: [split.prefix, split.suffix],
                isCompound: true, forms: [:]
            )
        }

        // Strategy 3: Suffix-based POS guessing for unknown words
        let pos: String
        if word.hasSuffix("het") || word.hasSuffix("tion") || word.hasSuffix("ning") || word.hasSuffix("ande") || word.hasSuffix("else") {
            pos = "noun"
        } else if word.hasSuffix("lig") || word.hasSuffix("bar") || word.hasSuffix("sam") || word.hasSuffix("isk") {
            pos = "adjective"
        } else if word.hasSuffix("era") || word.hasSuffix("ade") || word.hasSuffix("ades") {
            pos = "verb"
        } else {
            pos = "unknown"
        }

        return MorphemeAnalysis(word: word, baseForm: word, pos: pos, morphemes: [word], isCompound: false, forms: [:])
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
        let contextWords = context.lowercased().split(separator: " ").map(String.init)
        let contextSet = Set(contextWords.filter { $0.count > 2 && $0 != targetWord })

        // Find target word position for proximity weighting
        let targetIdx = contextWords.firstIndex(of: targetWord) ?? contextWords.count / 2

        return senses.map { sense in
            var score = 0.3 // Baseline

            // Factor 1: Example word overlap (weighted by proximity to target)
            for example in sense.examples {
                let exampleWords = Set(example.lowercased().split(separator: " ").map(String.init))
                let overlap = contextSet.intersection(exampleWords)
                for overlapWord in overlap {
                    // Weight by proximity: closer words to the target word score higher
                    if let wordIdx = contextWords.firstIndex(of: overlapWord) {
                        let distance = abs(wordIdx - targetIdx)
                        let proximityWeight = distance <= 2 ? 0.3 : (distance <= 5 ? 0.2 : 0.1)
                        score += proximityWeight
                    } else {
                        score += 0.15
                    }
                }
            }

            // Factor 2: Definition word overlap with context
            let defWords = Set(sense.definition.lowercased().split(separator: " ").map(String.init).filter { $0.count > 3 })
            let defOverlap = contextSet.intersection(defWords)
            score += Double(defOverlap.count) * 0.15

            // Factor 3: First-sense preference (most common sense gets slight boost)
            if sense.id.hasSuffix(".1") { score += 0.08 }

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
