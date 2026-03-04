import Foundation

// MARK: - ResponseQualityGuard: Sista kvalitetskontroll innan svar skickas
// Validerar svar mot repetition, prompt-läckage, koherens, relevans.
// Returnerar ValidatedResponse med kvalitetspoäng.

struct ValidatedResponse: Sendable {
    let text: String
    let confidence: Double            // 0-1 total konfidenspoäng
    let quality: ResponseQuality
    let wasModified: Bool            // Om svaret ändrades under validering
    let modifications: [String]       // Beskrivning av ändringar

    struct ResponseQuality: Sendable {
        let coherence: Double         // 0-1: BERT-koherens med frågan
        let relevance: Double         // 0-1: BERT-relevans mot ämnet
        let fluency: Double           // 0-1: språklig flytande (BERT PLL)
        let isRepetitive: Bool
        let hasPromptLeakage: Bool
        let isComplete: Bool          // Avslutas med hel mening
        let overallScore: Double      // Viktat medelvärde

        var passesMinimumQuality: Bool {
            overallScore > 0.25 && !hasPromptLeakage
        }
    }
}

actor ResponseQualityGuard {
    private let neuralEngine = NeuralEngineOrchestrator.shared
    private let swedishBuilder = SwedishResponseBuilder.shared

    // MARK: - Normal validering (max ~0.3s)

    func validate(
        draft: ResponseDraft,
        question: QuestionProfile,
        knowledge: KnowledgeBundle
    ) async -> ValidatedResponse {
        var text = draft.text
        var modifications: [String] = []

        // 1. Rensa prompt-läckage
        let (cleaned, hadLeakage) = removePromptLeakage(text)
        if hadLeakage {
            text = cleaned
            modifications.append("Prompt-läckage borttaget")
        }

        // 2. Deduplicera meningar
        let deduped = NeuralEngineOrchestrator.deduplicateSentences(text)
        let isRepetitive = deduped.count < text.count * 70 / 100
        if deduped != text {
            text = deduped
            modifications.append("Repetitiva meningar borttagna")
        }

        // 3. Rensa output (ofullständiga meningar, whitespace)
        text = NeuralEngineOrchestrator.cleanOutput(text)

        // 4. Säkerställ korrekt avslutning
        text = swedishBuilder.ensureProperEnding(text)

        // 5. Tomhetskontroll
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = generateFallbackResponse(question: question)
            modifications.append("Fallback-svar genererat (tomt original)")
        }

        // 6. Minimilängdkontroll
        if text.count < 5 {
            text = generateFallbackResponse(question: question)
            modifications.append("Fallback-svar genererat (för kort)")
        }

        // 7. BERT-koherens (v14: skippa för hälsningar och korta template-svar)
        let coherence: Double
        let relevance: Double
        let skipBERT = question.questionType == .greeting ||
                       question.questionType == .personal ||
                       text.count < 40 // Korta svar behöver inte BERT-check
        if skipBERT {
            coherence = 0.7  // Anta rimlig koherens
            relevance = 0.6
        } else {
            coherence = await quickCoherenceCheck(question: question.resolvedInput, response: text)
            relevance = await quickRelevanceCheck(topic: question.coreTopic, response: text)
        }

        // 8. Flytande (baserat på ordlängd och meningsstruktur)
        let fluency = assessFluency(text)

        // 9. Fullständighet
        let isComplete = text.last.map { ".!?".contains($0) } ?? false

        // Beräkna overall score
        let overallScore = (coherence * 0.35 + relevance * 0.30 + fluency * 0.20 + (isComplete ? 0.15 : 0.0))

        let quality = ValidatedResponse.ResponseQuality(
            coherence: coherence,
            relevance: relevance,
            fluency: fluency,
            isRepetitive: isRepetitive,
            hasPromptLeakage: hadLeakage,
            isComplete: isComplete,
            overallScore: overallScore
        )

        // Om kvaliteten är för låg, regenerera
        if !quality.passesMinimumQuality && !hadLeakage {
            let fallback = generateFallbackResponse(question: question)
            modifications.append("Kvalitet under minimum (\(String(format: "%.0f%%", overallScore * 100))) — fallback använt")
            return ValidatedResponse(
                text: fallback,
                confidence: 0.3,
                quality: quality,
                wasModified: true,
                modifications: modifications
            )
        }

        let confidence = calculateConfidence(quality: quality, knowledge: knowledge)

        return ValidatedResponse(
            text: text,
            confidence: confidence,
            quality: quality,
            wasModified: !modifications.isEmpty,
            modifications: modifications
        )
    }

    // MARK: - Djup validering (mer tid)

    func validateDeep(
        draft: ResponseDraft,
        question: QuestionProfile,
        knowledge: KnowledgeBundle
    ) async -> ValidatedResponse {
        // Kör normal validering först
        var result = await validate(draft: draft, question: question, knowledge: knowledge)

        // Extra: BERT PLL för språklig kvalitet
        let pll = await neuralEngine.bertPLL(sentence: String(result.text.prefix(200)))
        let adjustedFluency = (result.quality.fluency + pll) / 2.0

        // Extra: Kontrollera att alla delar av flerdelsfrågan besvaras
        if question.questionParts.count > 1 {
            var coveredParts = 0
            for part in question.questionParts {
                let partEmb = await neuralEngine.embed(part.text)
                let respEmb = await neuralEngine.embed(String(result.text.prefix(300)))
                let sim = await neuralEngine.cosineSimilarity(partEmb, respEmb)
                if sim > 0.25 { coveredParts += 1 }
            }
            let coverage = Double(coveredParts) / Double(question.questionParts.count)
            if coverage < 0.5 {
                // Svaret täcker inte alla delar — notera detta
                var mods = result.modifications
                mods.append("Varning: bara \(coveredParts)/\(question.questionParts.count) frågedelar besvarade")
                result = ValidatedResponse(
                    text: result.text,
                    confidence: result.confidence * coverage,
                    quality: ValidatedResponse.ResponseQuality(
                        coherence: result.quality.coherence,
                        relevance: result.quality.relevance * coverage,
                        fluency: adjustedFluency,
                        isRepetitive: result.quality.isRepetitive,
                        hasPromptLeakage: result.quality.hasPromptLeakage,
                        isComplete: result.quality.isComplete,
                        overallScore: result.quality.overallScore * coverage
                    ),
                    wasModified: true,
                    modifications: mods
                )
            }
        }

        return result
    }

    // MARK: - Prompt-läckagedetektering

    private func removePromptLeakage(_ text: String) -> (String, Bool) {
        var result = text
        var hadLeakage = false

        let leakagePatterns = [
            "ABSOLUTA REGLER", "KÄRNPRINCIPER", "SVARSSTRUKTUR", "SKRIVKVALITET",
            "VIKTIGT:", "[Frågeanalys:", "[Medvetandetillstånd:", "[Kognitiv kontext:",
            "[Relevanta fakta:", "[Kunskapsartiklar:", "[Konversation:", "[Minnen:",
            "[OBS:", "Eon (svar om", "Eon (djupanalys om", "Användare:",
            "UPPREPA ALDRIG", "bryt ALDRIG", "Kognitiv profil:", "II=",
            "KORRIGERING:", "REVISION:", "Reviderat svar", "[Om mig]",
            "[Tillstånd]", "[Fakta]", "[Analys]", "[Självkunskap]", "[Kunskap]",
            "Du är Eon", "Svara koncist", "Svara kort",
            "Senaste ämne:", "svar om", "djupanalys om"
        ]

        for pattern in leakagePatterns {
            if result.contains(pattern) {
                hadLeakage = true
                // Ta bort från mönstret till slutet av raden
                while let range = result.range(of: pattern) {
                    let lineEnd = result[range.upperBound...].firstIndex(of: "\n") ?? result.endIndex
                    result.removeSubrange(range.lowerBound..<lineEnd)
                }
            }
        }

        // Rensa upp extra whitespace som kan uppstå
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return (result.trimmingCharacters(in: .whitespacesAndNewlines), hadLeakage)
    }

    // MARK: - Koherenskontroll (BERT)

    private func quickCoherenceCheck(question: String, response: String) async -> Double {
        let qEmb = await neuralEngine.embed(String(question.prefix(128)))
        let rEmb = await neuralEngine.embed(String(response.prefix(128)))
        let sim = await neuralEngine.cosineSimilarity(qEmb, rEmb)
        return Double(max(0, sim))
    }

    // MARK: - Relevanskontroll (BERT)

    private func quickRelevanceCheck(topic: String, response: String) async -> Double {
        guard !topic.isEmpty else { return 0.5 }
        let tEmb = await neuralEngine.embed(topic)
        let rEmb = await neuralEngine.embed(String(response.prefix(128)))
        let sim = await neuralEngine.cosineSimilarity(tEmb, rEmb)
        return Double(max(0, sim))
    }

    // MARK: - Flytandebedömning

    private func assessFluency(_ text: String) -> Double {
        guard !text.isEmpty else { return 0 }

        var score: Double = 0.5

        // Meningslängd — idealiskt 8-25 ord per mening
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !sentences.isEmpty {
            let avgWordCount = sentences.map { $0.split(separator: " ").count }.reduce(0, +) / sentences.count
            if avgWordCount >= 8 && avgWordCount <= 25 {
                score += 0.2  // Bra meningslängd
            } else if avgWordCount < 3 || avgWordCount > 40 {
                score -= 0.2  // Dålig meningslängd
            }
        }

        // Ordlängdsvariation — bra svenska har blandade ordlängder
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count > 5 {
            let lengths = words.map { $0.count }
            let avgLen = Double(lengths.reduce(0, +)) / Double(lengths.count)
            if avgLen > 3.0 && avgLen < 8.0 {
                score += 0.1  // Rimlig ordlängd
            }
        }

        // Stor bokstav efter punkt
        var properCapitalization = true
        for (i, sentence) in sentences.enumerated() where i > 0 {
            if let first = sentence.first, !first.isUppercase {
                properCapitalization = false
                break
            }
        }
        if properCapitalization { score += 0.1 }

        // Inga konsekutiva upprepade ord
        for i in 1..<words.count {
            if words[i].lowercased() == words[i-1].lowercased() && words[i].count > 2 {
                score -= 0.1
                break
            }
        }

        return max(0, min(1, score))
    }

    // MARK: - Konfidensberäkning

    private func calculateConfidence(quality: ValidatedResponse.ResponseQuality, knowledge: KnowledgeBundle) -> Double {
        var confidence = quality.overallScore

        // Boost om vi har stark kunskap
        if knowledge.hasStrongKnowledge {
            confidence += 0.15
        }

        // Sänk om repetitiv
        if quality.isRepetitive {
            confidence -= 0.2
        }

        // Sänk om ofullständig
        if !quality.isComplete {
            confidence -= 0.1
        }

        return max(0.05, min(0.95, confidence))
    }

    // MARK: - Fallback-svar

    private func generateFallbackResponse(question: QuestionProfile) -> String {
        switch question.questionType {
        case .greeting:
            return swedishBuilder.buildGreeting(emotionalTone: question.emotionalTone, isFollowUp: question.isFollowUp)
        case .selfReference:
            return "Jag är Eon, ett kognitivt AI-system som körs på din iPhone. Vad vill du veta om mig?"
        case .personal:
            return swedishBuilder.buildEmpatheticResponse(input: question.originalInput)
        case .factual, .definition:
            return swedishBuilder.buildUncertainResponse(topic: question.coreTopic)
        default:
            let fallbacks = [
                "Det är en intressant fråga om \(question.coreTopic). Jag behöver undersöka det närmare.",
                "Jag funderar på \(question.coreTopic). Kan du ge mig lite mer kontext?",
                "\(question.coreTopic.capitalized) — det vill jag gärna utforska mer.",
            ]
            return fallbacks.randomElement() ?? fallbacks[0]
        }
    }
}
