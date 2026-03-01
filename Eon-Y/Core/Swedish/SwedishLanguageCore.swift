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
        let idioms = detectIdioms(text)
        let clauses = segmentClauses(text)
        let resolvedPronouns = resolveAnaphora(text, morphemes: morphemes)

        return SwedishAnalysis(
            originalText: text,
            morphemes: morphemes,
            disambiguations: disambiguations,
            register: register,
            modalParticles: modalParticles,
            detectedIdioms: idioms,
            clauses: clauses,
            anaphoraResolutions: resolvedPronouns
        )
    }

    // MARK: - Idiom Detection
    // Swedish idioms change meaning of the whole phrase — crucial for understanding

    private static let idiomDatabase: [(pattern: [String], meaning: String, literal: String)] = [
        // Common Swedish idioms
        (["lägga", "korten", "på", "bordet"], "vara ärlig, avslöja sanningen", "put cards on the table"),
        (["det", "finns", "inga", "gratisluncher"], "allt har ett pris", "there are no free lunches"),
        (["ha", "tummen", "mitt", "i", "handen"], "vara klumpig", "have thumb in middle of hand"),
        (["gå", "som", "katten", "kring", "het", "gröt"], "undvika att ta tag i något", "walk like the cat around hot porridge"),
        (["bita", "ihop"], "stå ut med smärta/svårigheter", "bite together"),
        (["dra", "en", "lansen"], "överge, ge upp på", "break a lance"),
        (["ha", "is", "i", "magen"], "vara lugn och tålmodig", "have ice in the stomach"),
        (["kasta", "in", "handduken"], "ge upp", "throw in the towel"),
        (["slå", "huvudet", "på", "spiken"], "ha helt rätt", "hit the nail on the head"),
        (["ta", "tjuren", "vid", "hornen"], "möta problem direkt", "take the bull by the horns"),
        (["det", "var", "droppen"], "den sista provokationen", "it was the drop"),
        (["gå", "som", "på", "räls"], "fungera perfekt", "go as on rails"),
        (["hålla", "tummarna"], "önska lycka till", "hold the thumbs"),
        (["sitta", "i", "samma", "båt"], "ha samma problem", "sit in the same boat"),
        (["lägga", "alla", "ägg", "i", "samma", "korg"], "satsa allt på ett kort", "put all eggs in one basket"),
        (["dra", "sitt", "strå", "till", "stacken"], "bidra med sin del", "pull your straw to the haystack"),
        (["vara", "ute", "och", "cyklar"], "ha fel, missförstå helt", "be out cycling"),
        (["inte", "alla", "hästar", "hemma"], "inte riktigt klok", "not all horses at home"),
        (["ta", "med", "en", "nypa", "salt"], "vara skeptisk", "take with a pinch of salt"),
        (["göra", "en", "höna", "av", "en", "fjäder"], "överdriva", "make a hen of a feather"),
        (["komma", "på", "fall"], "bli lurad, gå i fällan", "come to a fall"),
        (["ha", "rent", "mjöl", "i", "påsen"], "vara oskyldig", "have clean flour in the bag"),
        (["lägga", "benen", "på", "ryggen"], "springa snabbt, fly", "put legs on the back"),
        (["kasta", "pärlor", "för", "svin"], "slösa på oförstående", "cast pearls before swine"),
        (["dra", "alla", "över", "en", "kam"], "generalisera orättvist", "comb everyone the same"),
        (["ligga", "i", "lä"], "vara skyddad", "lie in the lee"),
        (["gå", "i", "fällan"], "bli lurad", "walk into the trap"),
        (["få", "kalla", "fötter"], "bli nervös, ändra sig", "get cold feet"),
        (["stå", "på", "egna", "ben"], "vara självständig", "stand on own legs"),
        (["spela", "med", "öppna", "kort"], "vara ärlig, transparent", "play with open cards"),
        (["ta", "bladet", "från", "munnen"], "tala klarspråk", "take the leaf from the mouth"),
        (["vända", "kappan", "efter", "vinden"], "ändra åsikt opportunistiskt", "turn the cloak after the wind"),
        (["ha", "en", "räv", "bakom", "örat"], "vara slug", "have a fox behind the ear"),
        (["sopa", "under", "mattan"], "dölja problem", "sweep under the carpet"),
    ]

    private func detectIdioms(_ text: String) -> [DetectedIdiom] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var found: [DetectedIdiom] = []

        for (pattern, meaning, literal) in Self.idiomDatabase {
            // Check if all pattern words appear in order (with gaps allowed)
            var patternIdx = 0
            for word in words {
                if patternIdx < pattern.count && word.hasPrefix(pattern[patternIdx].prefix(4)) {
                    patternIdx += 1
                }
            }
            if patternIdx >= pattern.count {
                found.append(DetectedIdiom(
                    phrase: pattern.joined(separator: " "),
                    meaning: meaning,
                    literalTranslation: literal
                ))
            }
        }
        return found
    }

    // MARK: - Clause Segmentation
    // Split Swedish sentences into clauses (huvudsats/bisats)

    private static let subordinators: Set<String> = [
        "att", "som", "om", "när", "medan", "eftersom", "trots", "fast", "innan",
        "efter", "tills", "såvida", "huruvida", "ifall", "emedan", "ehuru",
        "för att", "så att", "även om", "trots att", "i stället för att"
    ]

    private func segmentClauses(_ text: String) -> [ClauseSegment] {
        // Split on punctuation and subordinating conjunctions
        var clauses: [ClauseSegment] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            // Split on commas and subordinators
            let parts = sentence.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for part in parts {
                let lower = part.lowercased()
                let words = lower.components(separatedBy: .whitespaces)
                let firstWord = words.first ?? ""

                let isSubordinate = Self.subordinators.contains(firstWord) ||
                    Self.subordinators.contains(words.prefix(2).joined(separator: " "))
                let clauseType: ClauseSegment.ClauseType = isSubordinate ? .subordinate : .main

                clauses.append(ClauseSegment(
                    text: part,
                    type: clauseType,
                    startWord: firstWord
                ))
            }
        }
        return clauses
    }

    // MARK: - Anaphora Resolution (basic pronoun resolution)
    // Resolves "den", "det", "han", "hon", "de" to their likely referents

    private func resolveAnaphora(_ text: String, morphemes: [MorphemeAnalysis]) -> [AnaphoraResolution] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        let pronouns: Set<String> = ["den", "det", "han", "hon", "de", "dem", "dessa", "detta"]

        // Find all nouns as potential antecedents
        let nouns = morphemes.filter { $0.pos == "noun" || $0.pos == "propernoun" }
        var resolutions: [AnaphoraResolution] = []

        for (idx, word) in words.enumerated() {
            guard pronouns.contains(word) else { continue }

            // Find the closest preceding noun as the likely antecedent
            var bestAntecedent: String?
            var bestDistance = Int.max

            for noun in nouns {
                if let nounIdx = words.firstIndex(of: noun.word.lowercased()), nounIdx < idx {
                    let distance = idx - nounIdx
                    if distance < bestDistance {
                        bestDistance = distance
                        bestAntecedent = noun.word
                    }
                }
            }

            if let antecedent = bestAntecedent, bestDistance <= 10 {
                let confidence = max(0.3, 1.0 - Double(bestDistance) * 0.08)
                resolutions.append(AnaphoraResolution(
                    pronoun: word,
                    antecedent: antecedent,
                    distance: bestDistance,
                    confidence: confidence
                ))
            }
        }
        return resolutions
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

    // Swedish inflection suffixes for stemming back to base forms
    private static let inflectionPatterns: [(suffix: String, baseSuffix: String, pos: String)] = [
        // Verb inflections
        ("ade", "a", "verb"),       // pratade → prata
        ("ades", "a", "verb"),      // pratades → prata
        ("ande", "a", "verb"),      // pratande → prata
        ("ar", "a", "verb"),        // pratar → prata
        ("arna", "a", "verb"),      // pratarna → prata (noun form)
        ("ade", "a", "verb"),       // cyklade → cykla
        ("er", "a", "verb"),        // springer → springa (irregular but common)
        ("de", "", "verb"),         // sprangde → sprang
        ("t", "a", "verb"),         // pratat → prata
        ("s", "", "verb"),          // skrivs → skriv

        // Noun inflections (definite/plural)
        ("en", "", "noun"),         // bilen → bil
        ("et", "", "noun"),         // huset → hus
        ("arna", "a", "noun"),      // bilarna → bila?
        ("erna", "", "noun"),       // männerna → männ
        ("orna", "", "noun"),       // flickorna → flick
        ("ar", "", "noun"),         // bilar → bil
        ("or", "", "noun"),         // flickor → flick
        ("er", "", "noun"),         // platser → plats
        ("na", "", "noun"),         // husen → hus (already covered by -en)
        ("ns", "", "noun"),         // bilens → bil (genitive)
        ("s", "", "noun"),          // bils → bil (genitive)

        // Adjective inflections
        ("are", "", "adjective"),   // snabbare → snabb
        ("ast", "", "adjective"),   // snabbast → snabb
        ("aste", "", "adjective"),  // snabbaste → snabb
        ("a", "", "adjective"),     // snabba → snabb
        ("t", "", "adjective"),     // snabbt → snabb
    ]

    func analyze(_ text: String) async -> [MorphemeAnalysis] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { !$0.isEmpty }

        return words.compactMap { word in
            // Direct lexicon lookup
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

            // Try inflection stripping: remove known suffixes and check lexicon
            if let inflected = resolveInflection(word) {
                return inflected
            }

            // Compound analysis: try to split unknown words
            if word.count > 5 { // Lowered from 6 — Swedish has short compounds like "sjöman" (6)
                let compoundResult = analyzeCompound(word)
                if compoundResult.isCompound || compoundResult.pos != "unknown" {
                    return compoundResult
                }
            }

            return MorphemeAnalysis(word: word, baseForm: word, pos: "unknown", morphemes: [word], isCompound: false, forms: [:])
        }
    }

    /// Try stripping Swedish inflection suffixes to find base form in lexicon
    private func resolveInflection(_ word: String) -> MorphemeAnalysis? {
        for pattern in Self.inflectionPatterns {
            guard word.count > pattern.suffix.count + 2, // Base must be at least 3 chars
                  word.hasSuffix(pattern.suffix) else { continue }
            let stem = String(word.dropLast(pattern.suffix.count)) + pattern.baseSuffix
            if let entry = lexicon[stem] {
                return MorphemeAnalysis(
                    word: word,
                    baseForm: stem,
                    pos: entry.pos.isEmpty ? pattern.pos : entry.pos,
                    morphemes: [stem, pattern.suffix],
                    isCompound: false,
                    forms: entry.forms
                )
            }
        }
        return nil
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
                WordSense(id: "band.1", definition: "musikgrupp", examples: ["rockband", "spelat i band", "bandet spelade"], confidence: 0.0),
                WordSense(id: "band.2", definition: "remsa, tejp", examples: ["tejpband", "magnetband", "löpande band"], confidence: 0.0),
                WordSense(id: "band.3", definition: "bindning, förbindning", examples: ["blodband", "vänskapsband", "familjens band"], confidence: 0.0)
            ],
            "rätt": [
                WordSense(id: "rätt.1", definition: "korrekt, riktigt", examples: ["rätt svar", "det är rätt", "helt rätt"], confidence: 0.0),
                WordSense(id: "rätt.2", definition: "maträtt", examples: ["varmrätt", "förrätt", "huvudrätt", "god rätt"], confidence: 0.0),
                WordSense(id: "rätt.3", definition: "juridisk rätt", examples: ["mänskliga rättigheter", "rätten att", "laglig rätt"], confidence: 0.0)
            ],
            "lös": [
                WordSense(id: "lös.1", definition: "inte fastbunden", examples: ["löst hår", "lös knut", "lös skruv"], confidence: 0.0),
                WordSense(id: "lös.2", definition: "lösa upp, lösa problem", examples: ["lösa ekvationen", "lösa problemet", "lös gåtan"], confidence: 0.0)
            ],
            "spel": [
                WordSense(id: "spel.1", definition: "datorspel, brädspel", examples: ["spela spel", "tv-spel", "dataspel"], confidence: 0.0),
                WordSense(id: "spel.2", definition: "musikspelande", examples: ["pianospel", "gitarrspel", "hennes spel"], confidence: 0.0),
                WordSense(id: "spel.3", definition: "teater, skådespeleri", examples: ["skådespelarens spel", "dramatiskt spel"], confidence: 0.0)
            ],
            "slag": [
                WordSense(id: "slag.1", definition: "fysiskt slag", examples: ["ett hårt slag", "slag i ansiktet"], confidence: 0.0),
                WordSense(id: "slag.2", definition: "typ, sort", examples: ["alla slag", "ett slag av", "olika slag"], confidence: 0.0),
                WordSense(id: "slag.3", definition: "militärt slag", examples: ["slaget vid", "fältslag"], confidence: 0.0)
            ],
            "mål": [
                WordSense(id: "mål.1", definition: "syfte, ändamål", examples: ["uppnå målet", "mitt mål", "långsiktigt mål"], confidence: 0.0),
                WordSense(id: "mål.2", definition: "sportmål", examples: ["göra mål", "målvakt", "poängen gick i mål"], confidence: 0.0),
                WordSense(id: "mål.3", definition: "rättsfall", examples: ["brottmål", "målet i rätten", "civilmål"], confidence: 0.0),
                WordSense(id: "mål.4", definition: "språk, dialekt", examples: ["östgötamål", "skånska mål"], confidence: 0.0)
            ],
            "ställe": [
                WordSense(id: "ställe.1", definition: "plats", examples: ["ett fint ställe", "på det stället"], confidence: 0.0),
                WordSense(id: "ställe.2", definition: "i stället för", examples: ["i stället", "istället för"], confidence: 0.0)
            ],
            "drag": [
                WordSense(id: "drag.1", definition: "egenskap, karaktärsdrag", examples: ["typiska drag", "personlighetsdrag"], confidence: 0.0),
                WordSense(id: "drag.2", definition: "rörelse, att dra", examples: ["ett snabbt drag", "schackdrag"], confidence: 0.0),
                WordSense(id: "drag.3", definition: "luftdrag", examples: ["det drar", "kallt drag"], confidence: 0.0)
            ],
            "fall": [
                WordSense(id: "fall.1", definition: "händelse, situation", examples: ["i detta fall", "i alla fall"], confidence: 0.0),
                WordSense(id: "fall.2", definition: "fysiskt fall", examples: ["falla ner", "ett högt fall"], confidence: 0.0),
                WordSense(id: "fall.3", definition: "sjukdomsfall", examples: ["smittfall", "antalet fall"], confidence: 0.0)
            ],
            "verk": [
                WordSense(id: "verk.1", definition: "konstverk", examples: ["ett stort verk", "litterärt verk", "hans verk"], confidence: 0.0),
                WordSense(id: "verk.2", definition: "myndighet", examples: ["naturvårdsverket", "statligt verk"], confidence: 0.0),
                WordSense(id: "verk.3", definition: "anläggning, fabrik", examples: ["kraftverk", "elverk"], confidence: 0.0)
            ],
            "grund": [
                WordSense(id: "grund.1", definition: "bas, fundament", examples: ["på goda grunder", "grunden för"], confidence: 0.0),
                WordSense(id: "grund.2", definition: "orsak", examples: ["av den grunden", "grund till"], confidence: 0.0),
                WordSense(id: "grund.3", definition: "ytligt vatten", examples: ["gå på grund", "grundet i viken"], confidence: 0.0)
            ],
            "rad": [
                WordSense(id: "rad.1", definition: "linje, serie", examples: ["på rad", "en rad av", "i en rad"], confidence: 0.0),
                WordSense(id: "rad.2", definition: "textrad", examples: ["rad för rad", "första raden"], confidence: 0.0)
            ],
            "rik": [
                WordSense(id: "rik.1", definition: "förmögen", examples: ["en rik man", "bli rik"], confidence: 0.0),
                WordSense(id: "rik.2", definition: "riklig, full av", examples: ["rik på", "vitaminrik", "kunskapsrik"], confidence: 0.0)
            ],
            "värde": [
                WordSense(id: "värde.1", definition: "ekonomiskt värde", examples: ["högt värde", "marknadsvärde"], confidence: 0.0),
                WordSense(id: "värde.2", definition: "moraliskt värde", examples: ["mänskligt värde", "värderingar"], confidence: 0.0),
                WordSense(id: "värde.3", definition: "matematiskt värde", examples: ["variabelns värde", "numeriskt värde"], confidence: 0.0)
            ],
            "del": [
                WordSense(id: "del.1", definition: "bit, stycke", examples: ["en del av", "första delen"], confidence: 0.0),
                WordSense(id: "del.2", definition: "ganska mycket", examples: ["en hel del", "en del människor"], confidence: 0.0)
            ],
            "kraft": [
                WordSense(id: "kraft.1", definition: "fysisk styrka", examples: ["med full kraft", "muskelkraft"], confidence: 0.0),
                WordSense(id: "kraft.2", definition: "energi, el", examples: ["kärnkraft", "vindkraft", "kraftverk"], confidence: 0.0),
                WordSense(id: "kraft.3", definition: "giltighet", examples: ["i kraft", "träda i kraft", "laga kraft"], confidence: 0.0)
            ],
            "kort": [
                WordSense(id: "kort.1", definition: "litet, inte långt", examples: ["kort tid", "kort hår", "kort svar"], confidence: 0.0),
                WordSense(id: "kort.2", definition: "spelkort, kreditkort", examples: ["betala med kort", "spela kort", "bankkort"], confidence: 0.0)
            ],
            "press": [
                WordSense(id: "press.1", definition: "media, tidningar", examples: ["presskonferens", "svensk press", "pressen rapporterade"], confidence: 0.0),
                WordSense(id: "press.2", definition: "tryck, påfrestning", examples: ["under press", "sätta press på"], confidence: 0.0)
            ],
            "brott": [
                WordSense(id: "brott.1", definition: "lagöverträdelse", examples: ["begå brott", "grovt brott", "brottslighet"], confidence: 0.0),
                WordSense(id: "brott.2", definition: "bräckning, avbrott", examples: ["benbrott", "brott mot reglerna"], confidence: 0.0)
            ],
            "ton": [
                WordSense(id: "ton.1", definition: "musikton, ljud", examples: ["en ren ton", "grundton", "tonart"], confidence: 0.0),
                WordSense(id: "ton.2", definition: "stil, attityd", examples: ["hård ton", "tonläge", "tonen i samtalet"], confidence: 0.0),
                WordSense(id: "ton.3", definition: "viktenhet", examples: ["ett ton", "tusen kilo"], confidence: 0.0)
            ],
            "takt": [
                WordSense(id: "takt.1", definition: "rytm, tempo", examples: ["i takt med", "hålla takten"], confidence: 0.0),
                WordSense(id: "takt.2", definition: "hövlighet", examples: ["visa takt", "taktlös"], confidence: 0.0)
            ],
            "rum": [
                WordSense(id: "rum.1", definition: "fysiskt rum, kammare", examples: ["sovrum", "vardagsrum", "ett stort rum"], confidence: 0.0),
                WordSense(id: "rum.2", definition: "utrymme, plats", examples: ["ge rum för", "ta rum", "lämna rum"], confidence: 0.0)
            ],
            "led": [
                WordSense(id: "led.1", definition: "kroppsdel", examples: ["knäled", "handleds"], confidence: 0.0),
                WordSense(id: "led.2", definition: "väg, led", examples: ["vandringsleda", "leden till toppen"], confidence: 0.0),
                WordSense(id: "led.3", definition: "trött, matt", examples: ["led vid", "led på"], confidence: 0.0)
            ],
            "sak": [
                WordSense(id: "sak.1", definition: "föremål, ting", examples: ["en fin sak", "dina saker"], confidence: 0.0),
                WordSense(id: "sak.2", definition: "ärende, fråga", examples: ["en viktig sak", "saken är den"], confidence: 0.0)
            ],
            "skott": [
                WordSense(id: "skott.1", definition: "avfyrning", examples: ["skjuta ett skott", "skottlossning"], confidence: 0.0),
                WordSense(id: "skott.2", definition: "växtskott", examples: ["nya skott", "sidoskott"], confidence: 0.0),
                WordSense(id: "skott.3", definition: "skiljevägg", examples: ["skottet i båten", "brandskott"], confidence: 0.0)
            ],
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
    var detectedIdioms: [DetectedIdiom] = []
    var clauses: [ClauseSegment] = []
    var anaphoraResolutions: [AnaphoraResolution] = []

    /// Quick summary for prompt building
    var analysisSummary: String {
        var parts: [String] = []
        if register != .neutral { parts.append("Register: \(register.label)") }
        if !modalParticles.isEmpty { parts.append("Partiklar: \(modalParticles.map { $0.word }.joined(separator: ", "))") }
        if !detectedIdioms.isEmpty { parts.append("Idiom: \(detectedIdioms.map { $0.meaning }.joined(separator: "; "))") }
        if clauses.count > 1 { parts.append("\(clauses.count) satser") }
        let unknowns = morphemes.filter { $0.pos == "unknown" }.count
        if unknowns > 0 { parts.append("\(unknowns) okända ord") }
        return parts.isEmpty ? "Standard analys" : parts.joined(separator: " · ")
    }
}

struct DetectedIdiom: Identifiable {
    let id = UUID()
    let phrase: String
    let meaning: String
    let literalTranslation: String
}

struct ClauseSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: ClauseType
    let startWord: String

    enum ClauseType {
        case main       // Huvudsats
        case subordinate // Bisats (inleds med subjunktion)
    }
}

struct AnaphoraResolution: Identifiable {
    let id = UUID()
    let pronoun: String
    let antecedent: String
    let distance: Int       // Words between pronoun and antecedent
    let confidence: Double  // 0..1
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
