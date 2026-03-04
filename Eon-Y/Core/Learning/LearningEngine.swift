import Foundation
import Combine
import NaturalLanguage

// MARK: - LearningEngine
// Eons kontinuerliga inlärningssystem.
// Kombinerar: FSRS spaced repetition, meta-learning, LoRA-simulering,
// kompetensbok per domän, och adaptiv inlärningsschemaläggning.
// Målet: gå från sten till professor autonomt.

actor LearningEngine {
    static let shared = LearningEngine()

    // MARK: - Tillstånd

    private var competencyBook: [String: DomainCompetency] = [:]
    private var fsrsItems: [FSRSItem] = []
    private var learningSchedule: [ScheduledLesson] = []
    private var loraSimVersion: Int = 1
    private var totalLearningCycles: Int = 0
    private var knowledgeGaps: [KnowledgeGap] = []

    private init() {
        let domains = [
            "Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs",
            "Kausalitet", "Analogibyggande", "Metakognition", "Epistemologi",
            "AI & Maskininlärning", "Kognitionsvetenskap", "Filosofi",
            "Historia", "Psykologi", "Naturvetenskap"
        ]
        for domain in domains {
            competencyBook[domain] = DomainCompetency(
                domain: domain,
                level: 0.05,
                knowledgeItems: [],
                lastStudied: Date(timeIntervalSince1970: 0)
            )
        }
        for domain in domains {
            let key = "competency_\(domain)"
            let saved = UserDefaults.standard.double(forKey: key)
            if saved > 0.0 {
                competencyBook[domain]?.level = saved
            }
        }

        // v17: Restore persisted vocabulary and morphology counts
        loadPersistedState()
    }

    // MARK: - Persistence (v17)

    private static let vocabKey = "le_uniqueSwedishWords"
    private static let correctMorphKey = "le_correctMorphologyTests"
    private static let totalMorphKey = "le_totalMorphologyTests"
    private static let lastActiveDateKey = "le_lastActiveDate"
    private static let conversationsTodayKey = "le_conversationsToday"
    private static let wordsLearnedTodayKey = "le_wordsLearnedToday"

    private func loadPersistedState() {
        let ud = UserDefaults.standard
        if let savedWords = ud.array(forKey: Self.vocabKey) as? [String] {
            uniqueSwedishWords = Set(savedWords)
        }
        correctMorphologyTests = ud.integer(forKey: Self.correctMorphKey)
        totalMorphologyTests = ud.integer(forKey: Self.totalMorphKey)

        if let savedDate = ud.object(forKey: Self.lastActiveDateKey) as? Date {
            lastActiveDate = savedDate
        }
        // Reset daily counters if the stored date is not today
        if Calendar.current.isDateInToday(lastActiveDate) {
            conversationsToday = ud.integer(forKey: Self.conversationsTodayKey)
            wordsLearnedToday = ud.integer(forKey: Self.wordsLearnedTodayKey)
        } else {
            conversationsToday = 0
            wordsLearnedToday = 0
        }
    }

    private func persistState() {
        let ud = UserDefaults.standard
        ud.set(Array(uniqueSwedishWords), forKey: Self.vocabKey)
        ud.set(correctMorphologyTests, forKey: Self.correctMorphKey)
        ud.set(totalMorphologyTests, forKey: Self.totalMorphKey)
        ud.set(lastActiveDate, forKey: Self.lastActiveDateKey)
        ud.set(conversationsToday, forKey: Self.conversationsTodayKey)
        ud.set(wordsLearnedToday, forKey: Self.wordsLearnedTodayKey)
    }

    /// Ensure daily counters are reset when the date rolls over
    private func ensureDailyReset() {
        if !Calendar.current.isDateInToday(lastActiveDate) {
            conversationsToday = 0
            wordsLearnedToday = 0
        }
        lastActiveDate = Date()
    }

    // v16: Real competency measurement — combines fact knowledge, FSRS mastery,
    // conversation performance, and active language testing (not just fact counts)
    private var wordsAnalyzed: Set<String> = []           // Swedish words we've morphologically analyzed
    private var correctMorphologyTests: Int = 0           // How many morphology tests passed
    private var totalMorphologyTests: Int = 0
    private var successfulConversations: Int = 0          // Conversations with confidence > 0.6
    private var totalConversations: Int = 0
    private var uniqueSwedishWords: Set<String> = []      // Actual Swedish vocabulary

    // v17: Conversation-driven competency tracking
    private var conversationsToday: Int = 0
    private var wordsLearnedToday: Int = 0
    private var lastActiveDate: Date = Date(timeIntervalSince1970: 0)
    private var recentlyLearnedWords: [String] = []       // Rolling window of last N learned words
    private var activeStudyTopics: [String] = []          // Currently active FSRS topics
    private var learningVelocity: Double = 0.0            // Words per conversation (rolling avg)

    func syncCompetenciesFromDatabase() async {
        let memory = PersistentMemoryStore.shared

        // 1. Count domain-specific facts (still useful as one signal among many)
        let domainKeywords: [String: [String]] = [
            "Morfologi": ["morfologi", "böjning", "ordklass", "böjningsform", "avledning", "supinum", "imperativ", "passiv", "nominalisering", "sammansättning", "lemma", "suffix", "prefix", "tempus", "presens", "preteritum"],
            "Syntax": ["syntax", "mening", "sats", "ordföljd", "fras", "topikalisering", "bisats", "huvudsats", "subjekt", "predikat", "infinitiv", "partisip", "V2", "inversjon"],
            "Semantik": ["semantik", "betydelse", "definition", "saldo_sense", "primär_betydelse", "polysemi", "synonym", "antonym", "hypernym", "hyponym", "meronym"],
            "Pragmatik": ["pragmatik", "talakt", "implikatur", "kontext", "presupposition", "artighet", "register", "ironi", "sarkasm", "grice"],
            "Diskurs": ["diskurs", "koherens", "kohesion", "konnektiv", "anafor", "katafor", "retori", "textstruktur", "narrativ", "genre"],
            "Kausalitet": ["kausalitet", "orsak", "slutsats", "kausal", "konsekvens", "korrelation", "verkan"],
            "AI & Maskininlärning": ["ai", "neural", "modell", "transformer", "bert", "gpt", "maskininlärning", "algoritm", "embedding"],
            "Kognitionsvetenskap": ["kognition", "medvetande", "perception", "uppmärksamhet", "arbetsminne", "tänkande", "varseblivning"],
            "Metakognition": ["metakognition", "självreflektion", "självmedvetenhet", "kalibrering", "strategi"],
            "Filosofi": ["filosofi", "epistemologi", "ontologi", "medvetande", "fenomenologi", "existens", "etik"],
            "Historia": ["historia", "historisk", "krig", "konflikt", "revolution", "civilisation", "medeltid"],
            "Psykologi": ["psykologi", "känsla", "beteende", "inlärning", "emotion", "motivation", "personlighet"],
            "Naturvetenskap": ["naturvetenskap", "fysik", "kemi", "biologi", "evolution", "astronomi", "kvant"],
            "Analogibyggande": ["analogi", "liknelse", "metafor", "parallell", "jämförelse", "mappning", "strukturell"],
        ]

        for (domain, keywords) in domainKeywords {
            var totalFacts = 0
            var uniqueSubjects: Set<String> = []
            for keyword in keywords {
                let facts = await memory.searchFacts(query: keyword, limit: 30)
                totalFacts += facts.count
                for fact in facts { uniqueSubjects.insert(fact.subject) }
            }

            // Knowledge score: logarithmic from facts (30% weight)
            let factScore = totalFacts > 0 ? min(0.30, 0.06 * log2(Double(totalFacts) + 1)) : 0.0

            // FSRS mastery score: active study (25% weight)
            let domainFSRSItems = fsrsItems.filter { $0.domain == domain }
            let reviewedItems = domainFSRSItems.filter { $0.reviewCount > 0 }
            let avgStability = reviewedItems.isEmpty ? 0.0 :
                reviewedItems.reduce(0.0) { $0 + $1.stability } / Double(reviewedItems.count)
            let fsrsScore = min(0.25, avgStability * 0.05 + Double(reviewedItems.count) * 0.015)

            // Conversation performance score: how well we use this domain (25% weight)
            let convScore: Double
            if totalConversations > 0 {
                convScore = min(0.25, Double(successfulConversations) / Double(totalConversations) * 0.25)
            } else {
                convScore = 0.0
            }

            // Language-specific bonus: morphology test accuracy (20% weight for language domains)
            let langBonus: Double
            if ["Morfologi", "Syntax", "Semantik", "Pragmatik", "Diskurs"].contains(domain) {
                if totalMorphologyTests > 0 {
                    let accuracy = Double(correctMorphologyTests) / Double(totalMorphologyTests)
                    langBonus = min(0.20, accuracy * 0.20)
                } else {
                    langBonus = 0.0
                }
                // Vocabulary size bonus for language domains
                let vocabBonus = min(0.05, Double(uniqueSwedishWords.count) / 5000.0 * 0.05)
                let newLevel = min(0.95, factScore + fsrsScore + convScore + langBonus + vocabBonus)
                if var comp = competencyBook[domain] {
                    let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                    let growthBonus = recentlyStudied ? 0.003 : 0.0
                    comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                    competencyBook[domain] = comp
                    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
                }
            } else {
                let newLevel = min(0.90, factScore + fsrsScore + convScore)
                if var comp = competencyBook[domain] {
                    let recentlyStudied = comp.lastStudied.timeIntervalSinceNow > -3600
                    let growthBonus = recentlyStudied ? 0.003 : 0.0
                    comp.level = min(0.95, max(comp.level, newLevel) + growthBonus)
                    competencyBook[domain] = comp
                    UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
                }
            }
        }
    }

    // v16: Record morphology test result (called from EonLiveAutonomy)
    func recordMorphologyTest(word: String, passed: Bool) {
        totalMorphologyTests += 1
        if passed { correctMorphologyTests += 1 }
        wordsAnalyzed.insert(word.lowercased())
        persistState()
    }

    // v16: Record a Swedish word in actual vocabulary
    func recordSwedishWord(_ word: String) {
        let lower = word.lowercased()
        let isNew = uniqueSwedishWords.insert(lower).inserted
        if isNew {
            ensureDailyReset()
            wordsLearnedToday += 1
            recentlyLearnedWords.append(lower)
            if recentlyLearnedWords.count > 50 {
                recentlyLearnedWords = Array(recentlyLearnedWords.suffix(50))
            }
            persistState()
        }
    }

    // v16: Get actual Swedish vocabulary count (not knowledge node count)
    func swedishVocabularyCount() -> Int {
        uniqueSwedishWords.count
    }

    // MARK: - Conversation-Driven Learning (v17)

    /// Extract Swedish words from both user and Eon messages, identify new vocabulary,
    /// and record them for competency tracking and FSRS scheduling.
    func learnFromConversation(userMessage: String, eonResponse: String) async {
        ensureDailyReset()
        conversationsToday += 1

        let allText = userMessage + " " + eonResponse
        let extractedWords = extractSwedishWords(from: allText)

        var newWordsThisConversation: [String] = []
        for word in extractedWords {
            let lower = word.lowercased()
            if !uniqueSwedishWords.contains(lower) {
                uniqueSwedishWords.insert(lower)
                newWordsThisConversation.append(lower)
                wordsLearnedToday += 1
            }
        }

        // Update recently learned words (rolling window of 50)
        recentlyLearnedWords.append(contentsOf: newWordsThisConversation)
        if recentlyLearnedWords.count > 50 {
            recentlyLearnedWords = Array(recentlyLearnedWords.suffix(50))
        }

        // Update learning velocity (exponential moving average)
        let wordsThisRound = Double(newWordsThisConversation.count)
        learningVelocity = learningVelocity * 0.8 + wordsThisRound * 0.2

        // v19: Learn grammar patterns from the conversation
        learnGrammarPatterns(from: allText)

        // v23: Learn collocations and idioms for natural language acquisition
        learnCollocations(from: allText)
        detectAndLearnIdioms(from: allText)

        // v23: Adaptive learning — harder text = more competency gain
        let complexity = analyzeSentenceComplexity(allText)
        let complexityBonus = max(0, complexity - 0.3) * 0.003  // Bonus for complex conversations

        // Detect domain from conversation and boost competency for language domains
        let domain = detectDomain(from: allText)
        if var comp = competencyBook[domain] {
            let vocabBoost = min(0.005, Double(newWordsThisConversation.count) * 0.001)
            comp.level = min(0.95, comp.level + vocabBoost + complexityBonus)
            comp.lastStudied = Date()
            competencyBook[domain] = comp
            UserDefaults.standard.set(comp.level, forKey: "competency_\(domain)")
        }

        // Create FSRS items for new words in language-related domains
        for word in newWordsThisConversation.prefix(5) {
            addFSRSItem(topic: "Ordförråd: \(word)", domain: domain, initialDifficulty: 0.3)
        }

        // Update active study topics from current FSRS due items
        let dueItems = getDueItems()
        activeStudyTopics = Array(dueItems.prefix(10).map { $0.topic })

        // Persist and notify proxy
        persistState()
        await notifyProxy()
    }

    /// Extract Swedish words from text using NLTagger for proper linguistic tokenization
    private func extractSwedishWords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.setLanguage(.swedish, range: text.startIndex..<text.endIndex)

        var words: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .omitOther]
        ) { tag, range in
            let word = String(text[range])
            // v23: Also include determiners and prepositions for grammatical context
            // Keep nouns, verbs, adjectives, adverbs with length > 2 (skip particles/articles)
            if let tag = tag,
               [.noun, .verb, .adjective, .adverb].contains(tag),
               word.count > 2 {
                words.append(word)
            }
            return true
        }
        return words
    }

    // MARK: - Enhanced Autonomous Learning (v23)

    /// Detect collocations (common word pairs) from text to learn natural Swedish phrasing
    private var collocations: [String: Int] = [:]  // "word1|word2" -> frequency

    /// Extract and learn collocations from conversation text
    private func learnCollocations(from text: String) {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
        guard words.count >= 2 else { return }

        for i in 0..<(words.count - 1) {
            let bigram = "\(words[i])|\(words[i + 1])"
            collocations[bigram, default: 0] += 1
        }

        // Prune low-frequency collocations to prevent unbounded growth
        if collocations.count > 500 {
            collocations = collocations.filter { $0.value >= 3 }
        }
    }

    /// Detect Swedish idioms in text and learn them
    private var learnedIdioms: Set<String> = []

    private func detectAndLearnIdioms(from text: String) {
        let lower = text.lowercased()
        let knownIdiomPatterns = [
            "lägga korten på bordet", "ha is i magen", "ta tjuren vid hornen",
            "dra öronen åt sig", "gå på nitar", "kasta in handduken",
            "slå huvudet på spiken", "hugga i sten", "sila mygg och svälja kameler",
            "bita i det sura äpplet", "lägga locket på", "visa var skåpet ska stå",
            "ha tummen mitt i handen", "gå som katten kring het gröt",
            "falla mellan stolarna", "stå på sig", "ta sig vatten över huvudet",
            "vara ute och cykla", "ha rent mjöl i påsen", "dra sig i håret",
        ]

        for idiom in knownIdiomPatterns {
            if lower.contains(idiom) && !learnedIdioms.contains(idiom) {
                learnedIdioms.insert(idiom)
                // Boost pragmatics and discourse competency for idiom recognition
                if var comp = competencyBook["Pragmatik"] {
                    comp.level = min(0.95, comp.level + 0.003)
                    competencyBook["Pragmatik"] = comp
                }
            }
        }
    }

    /// Analyze sentence complexity for learning difficulty assessment
    private func analyzeSentenceComplexity(_ text: String) -> Double {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { $0.trimmingCharacters(in: .whitespaces).count > 5 }
        guard !sentences.isEmpty else { return 0.0 }

        var totalComplexity = 0.0
        for sentence in sentences {
            let words = sentence.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let wordCount = Double(words.count)
            let avgWordLength = words.isEmpty ? 0.0 : words.reduce(0.0) { $0 + Double($1.count) } / wordCount

            // Complexity factors: length, word length, subordinate clauses
            let lengthFactor = min(1.0, wordCount / 25.0)
            let wordLengthFactor = min(1.0, avgWordLength / 8.0)
            let subordinators = ["att", "som", "när", "om", "eftersom", "medan", "innan", "efter", "fastän"]
            let subClauseFactor = min(1.0, Double(subordinators.filter { sentence.lowercased().contains(" \($0) ") }.count) * 0.33)

            totalComplexity += (lengthFactor + wordLengthFactor + subClauseFactor) / 3.0
        }

        return totalComplexity / Double(sentences.count)
    }

    // MARK: - Grammar Pattern Learning (v19)

    /// Tracks Swedish sentence patterns (V2 rule, bisats word order, etc.)
    private var grammarPatterns: [String: Int] = [:]  // pattern -> occurrence count
    private var compoundWordCache: Set<String> = []    // detected compound words

    /// Analyze sentence structure patterns from conversation text
    func learnGrammarPatterns(from text: String) {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])

        for sentence in sentences {
            tagger.string = sentence
            tagger.setLanguage(.swedish, range: sentence.startIndex..<sentence.endIndex)

            var tags: [(String, NLTag)] = []
            tagger.enumerateTags(
                in: sentence.startIndex..<sentence.endIndex,
                unit: .word,
                scheme: .lexicalClass,
                options: [.omitWhitespace, .omitPunctuation, .omitOther]
            ) { tag, range in
                if let tag = tag {
                    tags.append((String(sentence[range]), tag))
                }
                return true
            }

            guard tags.count >= 3 else { continue }

            // Detect V2 (verb-second) pattern in main clauses
            if tags.count >= 2 && tags[1].1 == .verb {
                grammarPatterns["V2_huvudsats", default: 0] += 1
            }

            // Detect bisats (subordinate clause) markers: att, som, när, om, eftersom, etc.
            let bisatsMarkers: Set<String> = ["att", "som", "när", "om", "eftersom", "medan", "innan", "efter", "fastän", "trots", "huruvida", "ifall", "såvida"]
            for (i, (word, _)) in tags.enumerated() {
                if bisatsMarkers.contains(word.lowercased()) && i + 2 < tags.count {
                    grammarPatterns["bisats_\(word.lowercased())", default: 0] += 1
                }
            }

            // Detect compound words (long words that might be compounds)
            for (word, tag) in tags where tag == .noun && word.count >= 8 {
                let lower = word.lowercased()
                if !compoundWordCache.contains(lower) {
                    compoundWordCache.insert(lower)
                    // Boost morphology competency for each new compound detected
                    if var comp = competencyBook["Morfologi"] {
                        comp.level = min(0.95, comp.level + 0.0005)
                        competencyBook["Morfologi"] = comp
                    }
                }
            }

            // Detect passive constructions (word ending in -s that is a verb)
            for (word, tag) in tags where tag == .verb && word.hasSuffix("s") && word.count > 4 {
                grammarPatterns["passiv_s", default: 0] += 1
            }

            // Detect topikalisering (non-subject-initial main clause)
            if tags.count >= 3 && tags[0].1 != .pronoun && tags[0].1 != .noun && tags[1].1 == .verb {
                grammarPatterns["topikalisering", default: 0] += 1
            }

            // Detect adjective agreement (adjective before noun)
            for i in 0..<(tags.count - 1) {
                if tags[i].1 == .adjective && tags[i + 1].1 == .noun {
                    grammarPatterns["adj_attributiv", default: 0] += 1
                }
            }

            // Detect adverb placement patterns
            for i in 0..<(tags.count - 1) {
                if tags[i].1 == .adverb && tags[i + 1].1 == .verb {
                    grammarPatterns["adverb_före_verb", default: 0] += 1
                }
            }
        }

        // Boost syntax competency based on V2 pattern recognition
        if let v2Count = grammarPatterns["V2_huvudsats"], v2Count > 5 {
            if var comp = competencyBook["Syntax"] {
                comp.level = min(0.95, comp.level + 0.001)
                competencyBook["Syntax"] = comp
            }
        }

        // Prune low-frequency patterns to prevent unbounded growth
        if grammarPatterns.count > 50 {
            grammarPatterns = grammarPatterns.filter { $0.value >= 2 }
        }
    }

    /// Get a summary of learned grammar patterns for display
    func grammarPatternSummary() -> [(pattern: String, count: Int)] {
        grammarPatterns.sorted { $0.value > $1.value }
            .prefix(10)
            .map { (pattern: $0.key, count: $0.value) }
    }

    /// Count of detected compound words
    func compoundWordCount() -> Int {
        compoundWordCache.count
    }

    // MARK: - Autonomous Exploration (v17)

    /// Identify the weakest domain, generate study goals, and create FSRS items
    /// for suggested topics automatically. Returns a summary of the exploration.
    func autonomousExplore() async -> AutonomousExploreResult {
        ensureDailyReset()

        // 1. Identify the weakest domain
        let sorted = competencyBook.values.sorted { $0.level < $1.level }
        guard let weakest = sorted.first else {
            return AutonomousExploreResult(domain: "Okänd", studyGoals: [], createdItems: 0)
        }

        // 2. Check prerequisites — if prerequisites are unmet, target those instead
        var targetDomain = weakest.domain
        if let prereqs = prerequisites[weakest.domain] {
            let unmet = prereqs.filter { (competencyBook[$0]?.level ?? 0) < 0.3 }
            if let firstUnmet = unmet.first {
                targetDomain = firstUnmet
            }
        }

        let targetComp = competencyBook[targetDomain] ?? weakest

        // 3. Generate study goals based on current level
        let topics = suggestTopics(for: targetDomain, level: targetComp.level)

        // 4. Filter out topics we already have active FSRS items for
        let existingTopics = Set(fsrsItems.filter { $0.domain == targetDomain }.map { $0.topic })
        let newTopics = topics.filter { !existingTopics.contains($0) }

        // 5. Create FSRS items for new study goals
        var createdCount = 0
        for topic in newTopics {
            let difficulty = max(0.2, 1.0 - targetComp.level)
            addFSRSItem(topic: topic, domain: targetDomain, initialDifficulty: difficulty)
            createdCount += 1
        }

        // 6. Update active study topics
        activeStudyTopics = Array(getDueItems().prefix(10).map { $0.topic })

        // 7. Mark domain as recently studied
        if var comp = competencyBook[targetDomain] {
            comp.lastStudied = Date()
            competencyBook[targetDomain] = comp
        }

        // 8. Record exploration as a fact
        await PersistentMemoryStore.shared.saveFact(
            subject: targetDomain,
            predicate: "autonom_utforskning",
            object: newTopics.joined(separator: ", "),
            confidence: 0.8,
            source: "autonomous_explore"
        )

        persistState()
        await notifyProxy()

        return AutonomousExploreResult(
            domain: targetDomain,
            studyGoals: newTopics,
            createdItems: createdCount
        )
    }

    // MARK: - Proxy Notification (v17)

    /// Push latest state to the MainActor observable proxy
    private func notifyProxy() async {
        let snapshot = competencySnapshot()
        let level = overallCompetencyLevel()
        let recentWords = Array(recentlyLearnedWords.suffix(10))
        let topics = activeStudyTopics
        let velocity = learningVelocity
        let convsToday = conversationsToday
        let wordsToday = wordsLearnedToday
        let vocabCount = uniqueSwedishWords.count
        let compounds = compoundWordCache.count
        let patterns = grammarPatternSummary()

        await MainActor.run {
            let proxy = LearningEngine.observableProxy
            proxy.competencies = snapshot
            proxy.overallLevel = level
            proxy.latestLearnedWords = recentWords
            proxy.activeTopics = topics
            proxy.velocity = velocity
            proxy.conversationsToday = convsToday
            proxy.wordsLearnedToday = wordsToday
            proxy.vocabularyCount = vocabCount
            proxy.compoundWordCount = compounds
            proxy.grammarPatterns = patterns
        }
    }

    // MARK: - Daily Metrics (v17)

    /// Get conversation-driven metrics for today
    func dailyMetrics() -> DailyLearningMetrics {
        DailyLearningMetrics(
            conversationsToday: conversationsToday,
            wordsLearnedToday: wordsLearnedToday,
            lastActiveDate: lastActiveDate,
            totalVocabulary: uniqueSwedishWords.count,
            learningVelocity: learningVelocity,
            activeStudyTopics: activeStudyTopics,
            recentWords: Array(recentlyLearnedWords.suffix(12))
        )
    }

    // MARK: - Domain Interaction Matrix
    // Models how learning in one domain accelerates learning in related domains
    private let domainInteractions: [String: [(target: String, strength: Double)]] = [
        "Morfologi":           [("Syntax", 0.6), ("Semantik", 0.4), ("Diskurs", 0.2)],
        "Syntax":              [("Morfologi", 0.5), ("Pragmatik", 0.4), ("Semantik", 0.3)],
        "Semantik":            [("Pragmatik", 0.5), ("Morfologi", 0.3), ("Kognitionsvetenskap", 0.2)],
        "Pragmatik":           [("Diskurs", 0.6), ("Semantik", 0.4), ("Psykologi", 0.3)],
        "Diskurs":             [("Pragmatik", 0.5), ("Semantik", 0.3)],
        "Kausalitet":          [("Filosofi", 0.5), ("Kognitionsvetenskap", 0.4), ("Naturvetenskap", 0.3)],
        "AI & Maskininlärning":[("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Epistemologi", 0.2)],
        "Kognitionsvetenskap": [("Psykologi", 0.6), ("Metakognition", 0.5), ("AI & Maskininlärning", 0.3)],
        "Metakognition":       [("Kognitionsvetenskap", 0.5), ("Epistemologi", 0.4), ("Psykologi", 0.3)],
        "Filosofi":            [("Epistemologi", 0.7), ("Kausalitet", 0.4), ("Psykologi", 0.2)],
        "Epistemologi":        [("Filosofi", 0.6), ("Metakognition", 0.4), ("Kausalitet", 0.3)],
        "Historia":            [("Filosofi", 0.3), ("Psykologi", 0.2)],
        "Psykologi":           [("Kognitionsvetenskap", 0.5), ("Filosofi", 0.3), ("Metakognition", 0.3)],
        "Naturvetenskap":      [("Kausalitet", 0.4), ("Epistemologi", 0.3)],
        "Analogibyggande":     [("Kognitionsvetenskap", 0.4), ("Kausalitet", 0.3), ("Filosofi", 0.2)],
    ]

    // Track topic depth per domain — how deep we've gone into each topic
    private var topicDepthTracker: [String: [String: Int]] = [:] // domain -> topic -> depth level

    // MARK: - Inlärningscykel

    func runLearningCycle() async -> LearningCycleResult {
        totalLearningCycles += 1

        // 1. Identifiera kunskapsluckor
        let gaps = identifyKnowledgeGaps()
        knowledgeGaps = gaps

        // 2. Välj vad som ska studeras (FSRS-baserat)
        let dueItems = getDueItems()

        // 3. Studera och uppdatera kompetens (adaptive batch size based on gap urgency)
        let batchSize = gaps.first.map { $0.urgency > 1.5 ? 7 : 5 } ?? 5
        var studiedItems: [String] = []
        for item in dueItems.prefix(batchSize) {
            await studyItem(item)
            studiedItems.append(item.topic)
        }

        // 4. Generera ny kunskap från luckor
        let newKnowledge = await generateKnowledgeForGaps(gaps.prefix(3).map { $0 })

        // 5. Propagate cross-domain learning via interaction matrix
        await propagateDomainInteractions(studiedDomains: Set(dueItems.prefix(batchSize).compactMap { $0.domain }))

        // 6. Uppdatera LoRA-simulering
        if totalLearningCycles % 10 == 0 {
            loraSimVersion += 1
        }

        return LearningCycleResult(
            cycleNumber: totalLearningCycles,
            studiedTopics: studiedItems,
            newKnowledge: newKnowledge,
            gapsIdentified: gaps.count,
            loraVersion: loraSimVersion
        )
    }

    /// Propagate learning gains across related domains
    private func propagateDomainInteractions(studiedDomains: Set<String>) async {
        for domain in studiedDomains {
            guard let interactions = domainInteractions[domain],
                  let sourceLevel = competencyBook[domain]?.level else { continue }
            for interaction in interactions {
                guard var target = competencyBook[interaction.target] else { continue }
                // Transfer is proportional to source level, interaction strength, and target room to grow
                let roomToGrow = 1.0 - target.level
                let transfer = sourceLevel * interaction.strength * roomToGrow * 0.003
                if transfer > 0.0005 {
                    target.level = min(0.95, target.level + transfer)
                    competencyBook[interaction.target] = target
                }
            }
        }
    }

    // MARK: - FSRS (Free Spaced Repetition Scheduler)

    private func getDueItems() -> [FSRSItem] {
        let now = Date()
        return fsrsItems.filter { $0.dueDate <= now }.sorted { $0.priority > $1.priority }
    }

    private func studyItem(_ item: FSRSItem) async {
        guard let idx = fsrsItems.firstIndex(where: { $0.id == item.id }) else { return }

        let reviewCount = fsrsItems[idx].reviewCount
        let lastReview = fsrsItems[idx].lastReview
        let daysSinceLast = lastReview.map { Date().timeIntervalSince($0) / 86400 } ?? 1.0

        // Rating based on timeliness of review
        let scheduledInterval = fsrsItems[idx].dueDate.timeIntervalSince(lastReview ?? Date()) / 86400
        let actualInterval = daysSinceLast
        let rating: Double
        if scheduledInterval <= 0 {
            rating = 0.9
        } else {
            let ratio = actualInterval / max(scheduledInterval, 1.0)
            rating = ratio <= 1.2 ? 0.9 : ratio <= 2.0 ? 0.7 : ratio <= 3.0 ? 0.4 : 0.2
        }

        // FSRS-4.5 stability update
        let w = 0.14
        var difficulty = fsrsItems[idx].difficulty
        let newStability = max(0.1, fsrsItems[idx].stability * exp(w * (rating - difficulty)))

        // Adaptive difficulty: difficulty converges toward actual performance
        // High ratings → easier, low ratings → harder
        let difficultyDelta = 0.1 * (0.7 - rating) // rating < 0.7 increases difficulty
        difficulty = min(1.0, max(0.05, difficulty + difficultyDelta))

        // FSRS interval: I = S * 9 * (1 - R_target) + 1
        let targetRetention = 0.9
        let interval = max(1.0, newStability * 9.0 * (1.0 - targetRetention) + 1.0)

        fsrsItems[idx].stability = newStability
        fsrsItems[idx].difficulty = difficulty
        fsrsItems[idx].dueDate = Date().addingTimeInterval(interval * 86400)
        fsrsItems[idx].reviewCount = reviewCount + 1
        fsrsItems[idx].lastReview = Date()

        // Track topic depth: each successful review deepens understanding
        if let domain = fsrsItems[idx].domain, rating >= 0.7 {
            var domainDepth = topicDepthTracker[domain] ?? [:]
            let currentDepth = domainDepth[item.topic] ?? 0
            domainDepth[item.topic] = min(5, currentDepth + 1) // Max depth level 5
            topicDepthTracker[domain] = domainDepth
        }

        // Update competency based on rating, review count, and mastery trajectory
        if let domain = fsrsItems[idx].domain {
            let masteryFactor = min(1.0, Double(reviewCount + 1) / 5.0) // Full mastery after 5 reviews
            let learningBoost = 0.005 * rating * masteryFactor * (1.0 - (competencyBook[domain]?.level ?? 0.3))
            competencyBook[domain]?.level = min(0.99, (competencyBook[domain]?.level ?? 0.05) + learningBoost)
            competencyBook[domain]?.lastStudied = Date()
            if let level = competencyBook[domain]?.level {
                UserDefaults.standard.set(level, forKey: "competency_\(domain)")
            }
        }
    }

    func addFSRSItem(topic: String, domain: String, initialDifficulty: Double = 0.3) {
        let item = FSRSItem(
            topic: topic,
            domain: domain,
            stability: 1.0,
            difficulty: initialDifficulty,
            dueDate: Date().addingTimeInterval(86400),
            reviewCount: 0
        )
        fsrsItems.append(item)
        if fsrsItems.count > 1000 {
            // Priority-based pruning: remove lowest-priority items instead of FIFO
            fsrsItems.sort { $0.priority > $1.priority }
            fsrsItems = Array(fsrsItems.prefix(900))
        }
    }

    // MARK: - Kunskapsluckor

    // Prerequisite chains: domain A should be learned before domain B
    private let prerequisites: [String: [String]] = [
        "Syntax": ["Morfologi"],
        "Pragmatik": ["Semantik", "Syntax"],
        "Diskurs": ["Pragmatik"],
        "Metakognition": ["Kognitionsvetenskap"],
        "Epistemologi": ["Filosofi"],
        "Analogibyggande": ["Semantik", "Kausalitet"],
    ]

    private func identifyKnowledgeGaps() -> [KnowledgeGap] {
        var gaps: [KnowledgeGap] = []

        for (domain, competency) in competencyBook {
            // Dynamic threshold: lower for foundational domains, higher for advanced
            let isFoundational = ["Morfologi", "Semantik", "Filosofi", "Kognitionsvetenskap"].contains(domain)
            let threshold = isFoundational ? 0.6 : 0.5

            if competency.level < threshold {
                var urgency = (threshold - competency.level) * 2.0

                // Boost urgency if this domain is a prerequisite for other domains the user is trying to learn
                if let dependents = domainInteractions[domain] {
                    for dep in dependents {
                        if let depLevel = competencyBook[dep.target]?.level, depLevel > competency.level {
                            // Dependent domain is ahead of prerequisite — urgency boost
                            urgency += dep.strength * 0.5
                        }
                    }
                }

                // Penalize urgency if prerequisites are unmet (learn foundation first)
                if let prereqs = prerequisites[domain] {
                    let unmetPrereqs = prereqs.filter { (competencyBook[$0]?.level ?? 0) < 0.3 }
                    if !unmetPrereqs.isEmpty {
                        urgency *= 0.5 // Halve urgency — learn prereqs first
                    }
                }

                // Factor in staleness: domains not studied recently get urgency boost
                let daysSinceStudied = Date().timeIntervalSince(competency.lastStudied) / 86400
                if daysSinceStudied > 7 { urgency += 0.2 }
                if daysSinceStudied > 30 { urgency += 0.3 }

                gaps.append(KnowledgeGap(
                    domain: domain,
                    currentLevel: competency.level,
                    targetLevel: min(1.0, competency.level + 0.3),
                    urgency: urgency,
                    suggestedTopics: suggestTopics(for: domain, level: competency.level)
                ))
            }
        }

        return gaps.sorted { $0.urgency > $1.urgency }
    }

    private func suggestTopics(for domain: String, level: Double) -> [String] {
        let topicMap: [String: [[String]]] = [
            "Morfologi": [
                ["Grundläggande böjning", "Ordklasser", "Sammansättningar"],
                ["Avledning", "Prefixer", "Suffixer"],
                ["Produktiva mönster", "Oregelbundna former", "Historisk morfologi"]
            ],
            "Syntax": [
                ["Ordföljd i svenska", "Huvudsats vs bisats", "Satsdelar"],
                ["Frasstruktur", "Topikalisering", "Passivkonstruktioner"],
                ["X-bar-teori", "Dependensgrammatik", "Syntaktisk komplexitet"]
            ],
            "Semantik": [
                ["Ordklass och betydelse", "Synonymer och antonymer", "Polysemi"],
                ["Semantiska fält", "Komposition", "Metonymi och metafor"],
                ["Formell semantik", "Lambdakalkyl", "Diskursrepresentation"]
            ],
            "Pragmatik": [
                ["Talakter", "Implikatur", "Konversationsmaximer"],
                ["Presupposition", "Deixis", "Artighet"],
                ["Relevanceteori", "Konversationsanalys", "Pragmatisk inferens"]
            ],
            "Kausalitet": [
                ["Orsak-verkan", "Korrelation vs kausalitet"],
                ["Kausala kedjor", "Kontrafaktisk analys"],
                ["Kausala grafer", "Interventionslogik", "Counterfactuals"]
            ],
            "AI & Maskininlärning": [
                ["Neurala nätverk", "Backpropagation", "Aktiveringar"],
                ["Transformers", "Attention", "BERT/GPT"],
                ["RLHF", "Constitutional AI", "Alignment"]
            ],
            "Kognitionsvetenskap": [
                ["Perception", "Arbetsminne", "Uppmärksamhet"],
                ["Kognitiva scheman", "Dual-process-teori", "Kognitiv belastning"],
                ["Embodied cognition", "Situerat lärande", "Kognitiv arkitektur"]
            ],
            "Metakognition": [
                ["Självmedvetenhet", "Strategival", "Övervakningsprocesser"],
                ["Kalibrering", "Metaminnesteknik", "Reflektion"],
                ["Metakognitiv styrning", "Epistemic feelings", "FOK-omdömen"]
            ],
            "Filosofi": [
                ["Logik", "Argumentation", "Grundläggande etik"],
                ["Epistemologi", "Medvetandefilosofi", "Fri vilja"],
                ["Fenomenologi", "Analytisk filosofi", "Filosofisk logik"]
            ],
            "Epistemologi": [
                ["Kunskap och tro", "Sanning", "Rättfärdigande"],
                ["Skepticism", "Empirism vs rationalism", "Reliabilism"],
                ["Social epistemologi", "Vetenskapsteori", "Bayesiansk epistemologi"]
            ],
            "Historia": [
                ["Antiken", "Medeltiden", "Renässansen"],
                ["Upplysningen", "Industriella revolutionen", "Världskrigen"],
                ["Historiografi", "Historisk metod", "Kontrafaktisk historia"]
            ],
            "Psykologi": [
                ["Grundläggande emotion", "Motivation", "Perception"],
                ["Kognitiv psykologi", "Social psykologi", "Utvecklingspsykologi"],
                ["Neuropsykologi", "Klinisk psykologi", "Psykologisk forskning"]
            ],
            "Naturvetenskap": [
                ["Grundläggande fysik", "Cellbiologi", "Kemi"],
                ["Kvantfysik", "Genetik", "Organisk kemi"],
                ["Kosmologi", "Evolutionsbiologi", "Materialvetenskap"]
            ],
            "Analogibyggande": [
                ["Grundläggande liknelser", "Strukturell mappning"],
                ["Gentners analogiteori", "Fjärranalogier"],
                ["Analogisk transfer", "Kreativ analogianvändning"]
            ],
            "Diskurs": [
                ["Textstruktur", "Koherens", "Referens"],
                ["Diskursmarkörer", "Tema-rema", "Informationsstruktur"],
                ["Kritisk diskursanalys", "Retorisk analys", "Genreteori"]
            ],
        ]

        let levelIdx = level < 0.33 ? 0 : level < 0.66 ? 1 : 2
        return topicMap[domain]?[safe: levelIdx] ?? ["Grundläggande \(domain)", "Fördjupning i \(domain)", "Avancerad \(domain)"]
    }

    private func generateKnowledgeForGaps(_ gaps: [KnowledgeGap]) async -> [String] {
        var generated: [String] = []
        for gap in gaps {
            let topic = gap.suggestedTopics.first ?? "grundläggande \(gap.domain)"
            let knowledge = "\(gap.domain): studerar '\(topic)' (nivå: \(String(format: "%.0f", gap.currentLevel * 100))% → \(String(format: "%.0f", gap.targetLevel * 100))%)"
            generated.append(knowledge)

            // Spara kunskapslucka som faktum i databasen
            await PersistentMemoryStore.shared.saveFact(
                subject: gap.domain,
                predicate: "kunskapslucka",
                object: topic,
                confidence: 0.75,
                source: "learning_engine"
            )

            // Lägg till FSRS-item för varje föreslagen topic
            for suggestedTopic in gap.suggestedTopics.prefix(3) {
                addFSRSItem(topic: suggestedTopic, domain: gap.domain, initialDifficulty: 1.0 - gap.currentLevel)
            }
        }
        return generated
    }

    // MARK: - Meta-learning

    // v24: Error pattern tracking for targeted learning
    private var errorPatterns: [String: Int] = [:]  // topic → error count
    private var domainErrorRate: [String: (errors: Int, total: Int)] = [:]  // domain → (errors, total)

    func metaLearnFromConversation(userMessage: String, eonResponse: String, feedback: Double) async {
        // Detect all relevant domains (not just the best one)
        let primaryDomain = detectDomain(from: userMessage + " " + eonResponse)
        let secondaryDomain = detectDomain(from: userMessage) // Sometimes user's question and response diverge

        // v24: Track error rate per domain for meta-learning insights
        var stats = domainErrorRate[primaryDomain] ?? (errors: 0, total: 0)
        stats.total += 1
        if feedback < 0.5 { stats.errors += 1 }
        domainErrorRate[primaryDomain] = stats

        // Update competency with scaled feedback
        // Good feedback reinforces; bad feedback triggers active learning
        for domain in Set([primaryDomain, secondaryDomain]) {
            if var competency = competencyBook[domain] {
                let delta: Double
                if feedback >= 0.7 {
                    // Strong positive: scale by how far from mastery
                    delta = (feedback - 0.5) * 0.05 * (1.0 - competency.level)
                } else if feedback >= 0.4 {
                    // Neutral: minimal change
                    delta = (feedback - 0.5) * 0.02
                } else {
                    // Negative: competency can decrease (previously only ratcheted up)
                    delta = (feedback - 0.5) * 0.04
                }
                competency.level = min(0.99, max(0.01, competency.level + delta))
                competency.lastStudied = Date()
                competencyBook[domain] = competency
                UserDefaults.standard.set(competency.level, forKey: "competency_\(domain)")
            }
        }

        // Add FSRS items for weak points — with difficulty proportional to failure
        if feedback < 0.5 {
            let topic = extractMainTopic(from: userMessage)
            let difficulty = min(0.95, 0.5 + (0.5 - feedback)) // Worse feedback → harder item
            addFSRSItem(topic: topic, domain: primaryDomain, initialDifficulty: difficulty)

            // v24: Track repeated error patterns — boost difficulty for chronic weak spots
            errorPatterns[topic, default: 0] += 1
            let errorCount = errorPatterns[topic] ?? 1
            if errorCount >= 3 {
                // Chronic error: boost all FSRS items in this topic's difficulty
                for i in 0..<fsrsItems.count {
                    if fsrsItems[i].topic.contains(topic.prefix(15)) {
                        fsrsItems[i].difficulty = min(0.95, fsrsItems[i].difficulty + 0.05)
                        fsrsItems[i].interval = max(1, fsrsItems[i].interval / 2)  // Review sooner
                    }
                }
            }

            // Also save the gap as a fact for future reference
            await PersistentMemoryStore.shared.saveFact(
                subject: primaryDomain,
                predicate: "svagt_område",
                object: topic,
                confidence: 1.0 - feedback,
                source: "meta_learning"
            )

            // v24: Cross-domain error propagation — if domain has high error rate, reduce transfer
            if let rate = domainErrorRate[primaryDomain],
               rate.total >= 5, Double(rate.errors) / Double(rate.total) > 0.5 {
                // High error rate domain: boost its prerequisites
                if let prereqs = prerequisites[primaryDomain] {
                    for prereq in prereqs {
                        addFSRSItem(topic: "Grundkunskap: \(prereq)", domain: prereq,
                                    initialDifficulty: 0.4)
                    }
                }
            }
        }

        // Strong positive feedback → mark topic as well-understood
        if feedback >= 0.8 {
            let topic = extractMainTopic(from: userMessage)
            var domainDepth = topicDepthTracker[primaryDomain] ?? [:]
            domainDepth[topic] = max(domainDepth[topic] ?? 0, 3) // Mark as intermediate+
            topicDepthTracker[primaryDomain] = domainDepth

            // v24: Clear error pattern on strong success
            errorPatterns.removeValue(forKey: topic)
        }

        // v24: Prune error patterns to prevent unbounded growth
        if errorPatterns.count > 100 {
            let sorted = errorPatterns.sorted { $0.value < $1.value }
            errorPatterns = Dictionary(uniqueKeysWithValues: Array(sorted.suffix(50)))
        }
    }

    // MARK: - Statistik

    func competencySnapshot() -> [DomainCompetency] {
        competencyBook.values.sorted { $0.level > $1.level }
    }

    func overallCompetencyLevel() -> Double {
        let levels = competencyBook.values.map { $0.level }
        return levels.isEmpty ? 0.3 : levels.reduce(0, +) / Double(levels.count)
    }

    func topStrengths(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level > $1.level }.prefix(limit))
    }

    func topWeaknesses(limit: Int = 3) -> [DomainCompetency] {
        Array(competencyBook.values.sorted { $0.level < $1.level }.prefix(limit))
    }

    // MARK: - Helpers

    private func detectDomain(from text: String) -> String {
        let lower = text.lowercased()
        // Score each domain based on keyword hits — weighted by specificity
        let domainKeywords: [(String, [(keyword: String, weight: Int)])] = [
            ("Morfologi",          [("morfologi", 3), ("böjning", 2), ("ordklass", 2), ("avledning", 2), ("suffix", 2), ("prefix", 2), ("sammansättning", 2), ("lemma", 2)]),
            ("Syntax",             [("syntax", 3), ("sats", 1), ("ordföljd", 2), ("fras", 1), ("grammatik", 2), ("bisats", 2), ("subjekt", 1), ("predikat", 1)]),
            ("Semantik",           [("semantik", 3), ("betydelse", 2), ("definition", 1), ("begrepp", 1), ("lexikon", 2), ("polysemi", 3), ("synonym", 2)]),
            ("Pragmatik",          [("pragmatik", 3), ("talakt", 3), ("implikatur", 3), ("kommunikation", 1), ("konversation", 1), ("artighet", 2)]),
            ("Diskurs",            [("diskurs", 3), ("koherens", 2), ("retori", 2), ("textstruktur", 2), ("genr", 2), ("narrativ", 2)]),
            ("Kausalitet",         [("orsak", 2), ("kausal", 3), ("kausalitet", 3), ("verkan", 2), ("konsekvens", 2), ("korrelation", 2)]),
            ("AI & Maskininlärning", [("ai", 2), ("neural", 2), ("transformer", 3), ("bert", 3), ("gpt", 3), ("maskininlärning", 3), ("algoritm", 2), ("modell", 1)]),
            ("Kognitionsvetenskap", [("kognition", 3), ("medvetande", 2), ("perception", 2), ("uppmärksamhet", 2), ("arbetsminne", 3), ("tänkande", 1)]),
            ("Metakognition",      [("metakognition", 3), ("självreflektion", 3), ("självmedvetenhet", 3), ("strategi", 1), ("lärande", 1), ("kalibrering", 2)]),
            ("Filosofi",           [("filosofi", 3), ("ontologi", 3), ("etik", 2), ("moral", 2), ("existens", 2), ("fenomenologi", 3)]),
            ("Epistemologi",       [("epistemologi", 3), ("kunskap", 1), ("sanning", 2), ("bevis", 1), ("rättfärdigande", 3), ("skepticism", 3)]),
            ("Historia",           [("historia", 2), ("historisk", 2), ("krig", 1), ("revolution", 2), ("civilisation", 2), ("antiken", 2), ("medeltid", 2)]),
            ("Psykologi",          [("psykologi", 3), ("känsla", 1), ("beteende", 2), ("emotion", 2), ("trauma", 2), ("personlighet", 2), ("motivation", 2)]),
            ("Naturvetenskap",     [("naturvetenskap", 3), ("fysik", 2), ("kemi", 2), ("biologi", 2), ("evolution", 2), ("astronomi", 2), ("kvant", 2)]),
            ("Analogibyggande",    [("analogi", 3), ("liknelse", 2), ("metafor", 2), ("parallell", 1), ("jämförelse", 1), ("mappning", 2)]),
        ]
        var bestDomain = "Kognitionsvetenskap"
        var bestScore = 0
        for (domain, keywords) in domainKeywords {
            let score = keywords.reduce(0) { sum, kw in
                lower.contains(kw.keyword) ? sum + kw.weight : sum
            }
            if score > bestScore {
                bestScore = score
                bestDomain = domain
            }
        }
        return bestDomain
    }

    private func extractMainTopic(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [(word: String, position: Int)] = []
        var verbs: [String] = []
        var position = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = String(text[range])
            if tag == .noun && word.count > 3 {
                nouns.append((word, position))
            } else if tag == .verb && word.count > 3 {
                verbs.append(word)
            }
            position += 1
            return true
        }

        // Prefer longer nouns (more specific) and earlier position
        let scored = nouns.map { noun -> (String, Double) in
            let lengthScore = min(1.0, Double(noun.word.count) / 10.0)
            let positionScore = 1.0 / (1.0 + Double(noun.position) * 0.2) // Earlier = better
            return (noun.word, lengthScore + positionScore)
        }.sorted { $0.1 > $1.1 }

        if let best = scored.first {
            // Combine top noun with verb for richer topic description
            if let verb = verbs.first, verb != best.0 {
                return "\(verb) \(best.0)"
            }
            return best.0
        }
        return String(text.prefix(30).split(separator: " ").filter { $0.count > 4 }.first ?? "okänt ämne")
    }

    /// Get the current depth for a topic in a domain (0 = never studied, 5 = mastered)
    func topicDepth(domain: String, topic: String) -> Int {
        topicDepthTracker[domain]?[topic] ?? 0
    }

    /// Get domains that have stalled (no progress in recent cycles)
    func stalledDomains(staleDays: Double = 7.0) -> [DomainCompetency] {
        let threshold = Date().addingTimeInterval(-staleDays * 86400)
        return competencyBook.values
            .filter { $0.lastStudied < threshold && $0.level < 0.7 }
            .sorted { $0.level < $1.level }
    }
}

// MARK: - Data Models

struct DomainCompetency: Identifiable {
    let id = UUID()
    let domain: String
    var level: Double          // 0..1 (sten=0, professor=1)
    var knowledgeItems: [String]
    var lastStudied: Date

    var levelLabel: String {
        switch level {
        case 0.8...: return "Expert"
        case 0.6..<0.8: return "Avancerad"
        case 0.4..<0.6: return "Medel"
        case 0.2..<0.4: return "Nybörjare"
        default: return "Grundläggande"
        }
    }
}

struct FSRSItem: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String?
    var stability: Double
    var difficulty: Double
    var dueDate: Date
    var reviewCount: Int
    var lastReview: Date?
    nonisolated var priority: Double { stability * (1.0 - difficulty) }
}

struct ScheduledLesson: Identifiable {
    let id = UUID()
    let topic: String
    let domain: String
    let scheduledAt: Date
    var completed: Bool = false
}

struct KnowledgeGap: Identifiable {
    let id = UUID()
    let domain: String
    let currentLevel: Double
    let targetLevel: Double
    let urgency: Double
    let suggestedTopics: [String]
}

struct LearningCycleResult {
    let cycleNumber: Int
    let studiedTopics: [String]
    let newKnowledge: [String]
    let gapsIdentified: Int
    let loraVersion: Int
}

struct AutonomousExploreResult {
    let domain: String
    let studyGoals: [String]
    let createdItems: Int
}

struct DailyLearningMetrics {
    let conversationsToday: Int
    let wordsLearnedToday: Int
    let lastActiveDate: Date
    let totalVocabulary: Int
    let learningVelocity: Double
    let activeStudyTopics: [String]
    let recentWords: [String]
}

// MARK: - Array safe subscript

extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
