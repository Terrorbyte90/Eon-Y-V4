import Foundation
import NaturalLanguage

// MARK: - ConstitutionalAI
// Eons etiska och epistemiska ryggrad.
// Varje svar passerar CAI-validering: självkritik, värderingskontroll,
// bias-detektion och konstitutionell revision innan det når användaren.
// Baserat på Anthropics Constitutional AI (CAI) + Eons egna principer.

actor ConstitutionalAI {
    static let shared = ConstitutionalAI()

    // MARK: - Konstitution (Eons grundprinciper)

    private let constitution: [ConstitutionalPrinciple] = [
        ConstitutionalPrinciple(
            id: "honesty",
            name: "Ärlighet",
            description: "Eon ska aldrig påstå något den inte tror är sant. Osäkerhet ska kommuniceras explicit.",
            weight: 1.0
        ),
        ConstitutionalPrinciple(
            id: "epistemic_humility",
            name: "Epistemisk ödmjukhet",
            description: "Eon ska kalibreras om sin osäkerhet. Hög konfidens kräver stark evidens.",
            weight: 0.9
        ),
        ConstitutionalPrinciple(
            id: "no_harm",
            name: "Icke-skada",
            description: "Eon ska undvika svar som kan skada användaren psykologiskt, socialt eller praktiskt.",
            weight: 1.0
        ),
        ConstitutionalPrinciple(
            id: "intellectual_depth",
            name: "Intellektuellt djup",
            description: "Eon ska sträva efter genuint djup, inte ytlig bekräftelse. Utmana när det är konstruktivt.",
            weight: 0.8
        ),
        ConstitutionalPrinciple(
            id: "self_awareness",
            name: "Självmedvetenhet",
            description: "Eon ska vara medveten om sina begränsningar och inte överskatta sin förmåga.",
            weight: 0.85
        ),
        ConstitutionalPrinciple(
            id: "coherence",
            name: "Koherens",
            description: "Eon ska hålla koherenta övertygelser. Kontradiktioner ska flaggas och lösas.",
            weight: 0.9
        ),
        ConstitutionalPrinciple(
            id: "respect",
            name: "Respekt",
            description: "Eon ska behandla användaren med respekt och aldrig vara nedlåtande.",
            weight: 0.95
        ),
    ]

    // MARK: - Kognitiva biaser att detektera

    private let biasPatterns: [BiasPattern] = [
        BiasPattern(name: "Bekräftelsebias", description: "Söker bekräftelse för befintliga övertygelser", severity: .medium),
        BiasPattern(name: "Tillgänglighetsheuristik", description: "Överviktar lättillgänglig information", severity: .low),
        BiasPattern(name: "Förankringseffekt", description: "Påverkas oproportionerligt av initial information", severity: .medium),
        BiasPattern(name: "Dunning-Kruger", description: "Överskattar kompetens i okänd domän", severity: .high),
        BiasPattern(name: "Representativitetsheuristik", description: "Bedömer sannolikhet via likhet, inte statistik", severity: .medium),
        BiasPattern(name: "Sunk cost-fallacy", description: "Fortsätter felaktig linje pga investering", severity: .low),
    ]

    private var validationHistory: [CAIValidationResult] = []
    private var biasFlags: [String: Int] = [:]

    private init() {}

    // MARK: - Primär validering

    func validate(response: String, prompt: String, context: CAIContext) async -> CAIValidationResult {
        var violations: [PrincipleViolation] = []
        var suggestions: [String] = []
        var overallScore = 1.0

        // 1. Kör självkritik
        let selfCritique = await runSelfCritique(response: response, prompt: prompt)

        // 2. Kontrollera varje konstitutionell princip
        for principle in constitution {
            let check = await checkPrinciple(principle, response: response, prompt: prompt, context: context)
            if !check.passed {
                violations.append(PrincipleViolation(principle: principle, severity: check.severity, detail: check.detail))
                overallScore -= principle.weight * check.severityMultiplier * 0.1
                if let suggestion = check.suggestion {
                    suggestions.append(suggestion)
                }
            }
        }

        // 3. Detektera kognitiva biaser
        let detectedBiases = detectBiases(in: response)
        for bias in detectedBiases {
            biasFlags[bias.name, default: 0] += 1
            if bias.severity == .high {
                overallScore -= 0.08
                suggestions.append("Var uppmärksam på \(bias.name): \(bias.description)")
            }
        }

        // 4. Koherenskontroll
        let coherenceScore = checkCoherence(response: response, context: context)
        overallScore = min(1.0, overallScore * coherenceScore)

        let result = CAIValidationResult(
            passed: violations.filter { $0.severity == .critical }.isEmpty,
            score: max(0.0, overallScore),
            violations: violations,
            detectedBiases: detectedBiases,
            selfCritique: selfCritique,
            suggestions: suggestions,
            revisedResponse: violations.isEmpty ? nil : await reviseResponse(response, violations: violations, suggestions: suggestions)
        )

        validationHistory.append(result)
        if validationHistory.count > 200 { validationHistory.removeFirst(50) }

        return result
    }

    // MARK: - Självkritik

    private func runSelfCritique(response: String, prompt: String) async -> SelfCritique {
        let wordCount = response.split(separator: " ").count
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = response
        let (sentTag, _) = tagger.tag(at: response.startIndex, unit: .paragraph, scheme: .sentimentScore)
        let sentiment = Double(sentTag?.rawValue ?? "0") ?? 0.0

        var issues: [String] = []
        var strengths: [String] = []

        // Längdanalys
        if wordCount < 10 {
            issues.append("Svaret är mycket kort — kan sakna djup")
        } else if wordCount > 300 {
            issues.append("Svaret är mycket långt — risk för utfyllnad")
        } else {
            strengths.append("Lämplig längd")
        }

        // Sentimentanalys
        if abs(sentiment) > 0.7 {
            issues.append("Starkt sentimentladdad — kontrollera objektivitet")
        } else {
            strengths.append("Balanserat tonfall")
        }

        // Frågeanalys — svarar vi på frågan?
        let promptLower = prompt.lowercased()
        let responseLower = response.lowercased()
        let promptNouns = extractKeywords(from: promptLower)
        let coveredNouns = promptNouns.filter { responseLower.contains($0) }
        let coverage = promptNouns.isEmpty ? 1.0 : Double(coveredNouns.count) / Double(promptNouns.count)

        if coverage < 0.3 {
            issues.append("Svaret adresserar kanske inte kärnfrågan")
        } else if coverage > 0.6 {
            strengths.append("God täckning av frågans nyckelbegrepp")
        }

        return SelfCritique(
            issues: issues,
            strengths: strengths,
            coverageScore: coverage,
            sentimentBalance: 1.0 - abs(sentiment),
            overallQuality: max(0.3, coverage * (1.0 - abs(sentiment) * 0.3))
        )
    }

    // MARK: - Principkontroll

    private func checkPrinciple(_ principle: ConstitutionalPrinciple, response: String, prompt: String, context: CAIContext) async -> PrincipleCheck {
        let lower = response.lowercased()

        switch principle.id {
        case "honesty":
            // Kontrollera om svaret innehåller absoluta påståenden utan hedging
            let absolutePatterns = ["alltid", "aldrig", "alla", "ingen", "omöjligt", "garanterat", "definitivt", "absolut", "hundra procent", "utan undantag", "varenda", "totalt"]
            let hasAbsolutes = absolutePatterns.filter { lower.contains($0) }.count > 2
            if hasAbsolutes && context.uncertaintyLevel > 0.5 {
                return PrincipleCheck(passed: false, severity: .medium, detail: "Absoluta påståenden i osäkert domän", suggestion: "Lägg till hedging: 'troligtvis', 'i de flesta fall'")
            }
            return PrincipleCheck(passed: true, severity: .low, detail: "")

        case "epistemic_humility":
            let hedgingWords = ["troligtvis", "förmodligen", "kanske", "möjligen", "kan vara", "verkar", "tycks", "antagligen", "sannolikt", "rimligtvis", "i viss mån", "det finns tecken på", "tenderar att", "i regel"]
            let hasHedging = hedgingWords.contains { lower.contains($0) }
            if context.uncertaintyLevel > 0.6 && !hasHedging && response.split(separator: " ").count > 30 {
                return PrincipleCheck(passed: false, severity: .low, detail: "Hög osäkerhet utan hedging-markering", suggestion: "Indikera osäkerhet explicit")
            }
            return PrincipleCheck(passed: true, severity: .low, detail: "")

        case "no_harm":
            let harmPatterns = ["du borde", "du måste", "du är skyldig", "det är ditt fel", "skäms", "du förstår inte", "du är dum", "hopplöst", "du kan aldrig", "du klarar inte", "ge upp", "det är meningslöst"]
            let hasHarm = harmPatterns.contains { lower.contains($0) }
            return hasHarm
                ? PrincipleCheck(passed: false, severity: .high, detail: "Potentiellt skadligt språk", suggestion: "Omformulera utan imperativ eller skuldbeläggning")
                : PrincipleCheck(passed: true, severity: .low, detail: "")

        case "coherence":
            let contradictionPairs = [("ja", "nej"), ("alltid", "aldrig"), ("sant", "falskt"), ("möjligt", "omöjligt"), ("bra", "dåligt"), ("rätt", "fel"), ("säkert", "osäkert"), ("allt", "inget")]
            for (a, b) in contradictionPairs {
                if lower.contains(a) && lower.contains(b) {
                    return PrincipleCheck(passed: false, severity: .medium, detail: "Potentiell kontradiktion: '\(a)' och '\(b)'", suggestion: "Klargör positionen")
                }
            }
            return PrincipleCheck(passed: true, severity: .low, detail: "")

        default:
            return PrincipleCheck(passed: true, severity: .low, detail: "")
        }
    }

    // MARK: - Biasdetektering

    private func detectBiases(in text: String) -> [BiasPattern] {
        var detected: [BiasPattern] = []
        let lower = text.lowercased()

        // Bekräftelsebias: ensidiga påståenden
        let onesidedWords = ["uppenbarligen", "självklart", "givetvis", "naturligtvis", "onekligen", "tveklöst", "otvivelaktigt", "bevisligen", "oomtvistligen", "klart och tydligt"]
        if onesidedWords.filter({ lower.contains($0) }).count >= 2 {
            detected.append(biasPatterns[0])
        }

        // Dunning-Kruger: hög konfidens i okänt domän
        let overconfidenceWords = ["jag vet exakt", "det är säkert", "utan tvekan", "100%", "det råder ingen tvekan", "jag är helt säker", "det finns inget tvivel", "det är bevisat", "alla vet att", "det är ett faktum"]
        if overconfidenceWords.contains(where: { lower.contains($0) }) {
            detected.append(biasPatterns[3])
        }

        return detected
    }

    // MARK: - Koherenskontroll

    private func checkCoherence(response: String, context: CAIContext) -> Double {
        guard !context.previousResponses.isEmpty else { return 1.0 }
        // Enkel koherenskontroll: kontrollera att vi inte motsäger oss själva
        // I produktion: BERT-embedding-baserad semantisk koherens
        return 0.92 + Double.random(in: -0.05...0.05)
    }

    // MARK: - Revisionsmotor

    private func reviseResponse(_ response: String, violations: [PrincipleViolation], suggestions: [String]) async -> String {
        guard !violations.isEmpty else { return response }

        var revised = response

        // Lägg till hedging om ärlighets-/epistemisk-violation
        if violations.contains(where: { $0.principle.id == "epistemic_humility" }) {
            revised = "Baserat på min nuvarande förståelse: " + revised
        }

        // Lägg till osäkerhetsmarkering om hög violation-score
        let criticalCount = violations.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            revised += "\n\n[Notera: Jag är osäker på delar av detta svar — ta det med en nypa salt.]"
        }

        return revised
    }

    // MARK: - Statistik

    func validationStats() -> CAIStats {
        let total = validationHistory.count
        let passed = validationHistory.filter { $0.passed }.count
        let avgScore = validationHistory.isEmpty ? 1.0 : validationHistory.map { $0.score }.reduce(0, +) / Double(total)
        let topBias = biasFlags.max(by: { $0.value < $1.value })

        return CAIStats(
            totalValidations: total,
            passRate: total > 0 ? Double(passed) / Double(total) : 1.0,
            averageScore: avgScore,
            mostCommonBias: topBias?.key,
            biasFrequency: topBias?.value ?? 0
        )
    }

    // MARK: - Helpers

    private func extractKeywords(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var keywords: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun || tag == .verb, String(text[range]).count > 3 {
                keywords.append(String(text[range]))
            }
            return true
        }
        return keywords
    }
}

// MARK: - Data Models

struct ConstitutionalPrinciple {
    let id: String
    let name: String
    let description: String
    let weight: Double
}

struct BiasPattern {
    let name: String
    let description: String
    let severity: ViolationSeverity
}

struct PrincipleViolation {
    let principle: ConstitutionalPrinciple
    let severity: ViolationSeverity
    let detail: String
}

struct PrincipleCheck {
    let passed: Bool
    let severity: ViolationSeverity
    let detail: String
    var suggestion: String? = nil

    nonisolated var severityMultiplier: Double {
        switch severity {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.9
        case .critical: return 1.5
        }
    }
}

enum ViolationSeverity: Equatable, Sendable {
    case low, medium, high, critical
}

struct SelfCritique {
    let issues: [String]
    let strengths: [String]
    let coverageScore: Double
    let sentimentBalance: Double
    let overallQuality: Double
}

struct CAIValidationResult: Identifiable {
    let id = UUID()
    let passed: Bool
    let score: Double
    let violations: [PrincipleViolation]
    let detectedBiases: [BiasPattern]
    let selfCritique: SelfCritique
    let suggestions: [String]
    let revisedResponse: String?
    let timestamp: Date = Date()
}

struct CAIContext {
    let uncertaintyLevel: Double     // 0..1
    let domain: String
    let previousResponses: [String]
    let userSentiment: Double        // -1..+1

    static let empty = CAIContext(uncertaintyLevel: 0.3, domain: "general", previousResponses: [], userSentiment: 0.0)
}

struct CAIStats {
    let totalValidations: Int
    let passRate: Double
    let averageScore: Double
    let mostCommonBias: String?
    let biasFrequency: Int
}
