import Foundation

// MARK: - ResponseStrategyPlanner: Bestämmer HUR Eon ska svara
// Analyserar frågetyp, tillgänglig kunskap, självkunskap och konversationskontext
// för att välja optimal svarsstrategi. Avgör ton, komplexitet, kunskapskällor.

struct ResponseStrategy: Sendable {
    let type: StrategyType
    let requiresReasoning: Bool
    let useKnowledge: Bool
    let useSelfKnowledge: Bool
    let useMemories: Bool
    let tone: ResponseTone
    let complexity: ResponseComplexity
    let instructions: [String]       // Specifika instruktioner till kompositören
    let fallbackApproach: FallbackApproach
    let maxResponseTokens: Int       // Max antal tokens för svaret

    enum StrategyType: String, Sendable {
        case knowledgeAnswer = "kunskap"
        case selfExplanation = "självförklaring"
        case conversational = "konversation"
        case reasoning = "resonemang"
        case creative = "kreativ"
        case greeting = "hälsning"
        case opinion = "åsikt"
        case empathetic = "empatisk"
        case factual = "faktasvar"
        case deepAnalysis = "djupanalys"
        case comparison = "jämförelse"
        case listAnswer = "lista"
        case definition = "definition"
        case followUp = "uppföljning"
    }

    enum ResponseTone: String, Sendable {
        case warm = "varm"
        case neutral = "neutral"
        case academic = "akademisk"
        case playful = "lekfull"
        case empathetic = "empatisk"
        case confident = "säker"
        case curious = "nyfiken"
        case thoughtful = "eftertänksam"
    }

    enum ResponseComplexity: Sendable {
        case simple      // 1-2 meningar
        case moderate    // 3-4 meningar
        case complex     // 5-7 meningar
        case deep        // 8+ meningar, strukturerat
    }

    enum FallbackApproach: Sendable {
        case acknowledgeAndRedirect    // "Det vet jag inte, men..."
        case generalKnowledge          // Använd allmänkunskap
        case askClarification          // "Kan du förtydliga?"
        case honestUncertainty         // "Jag är inte säker, men..."
        case none                      // Ingen fallback behövs
    }
}

actor ResponseStrategyPlanner {

    // MARK: - Normal planering (max ~0.3s)

    func plan(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        conversationContext: ConversationContext
    ) -> ResponseStrategy {

        // Steg 1: Bestäm grundstrategi baserat på frågetyp
        let baseType = determineStrategyType(question: question, selfKnowledge: selfKnowledge)

        // Steg 2: Avgör om resonemang krävs
        let needsReasoning = assessReasoningNeed(
            questionType: question.questionType,
            strategyType: baseType,
            knowledgeCoverage: knowledge.topicCoverage
        )

        // Steg 3: Bestäm ton
        let tone = determineTone(
            emotionalTone: question.emotionalTone,
            questionType: question.questionType,
            isFollowUp: question.isFollowUp,
            context: conversationContext
        )

        // Steg 4: Bestäm komplexitet
        let complexity = determineComplexity(
            expectedLength: question.expectedResponseLength,
            knowledgeCoverage: knowledge.topicCoverage,
            questionType: question.questionType
        )

        // Steg 5: Kunskapskällor
        let useKnowledge = knowledge.hasStrongKnowledge && !question.isAboutEon
        let useSelf = selfKnowledge.isRelevant
        let useMemories = !knowledge.memories.isEmpty && question.isFollowUp

        // Steg 6: Fallback
        let fallback = determineFallback(
            knowledgeCoverage: knowledge.topicCoverage,
            questionType: question.questionType,
            isAboutEon: question.isAboutEon
        )

        // Steg 7: Instruktioner
        let instructions = buildInstructions(
            type: baseType,
            question: question,
            knowledge: knowledge,
            selfKnowledge: selfKnowledge,
            tone: tone,
            complexity: complexity,
            fallback: fallback
        )

        // Steg 8: Max tokens
        let maxTokens = calculateMaxTokens(complexity: complexity, questionType: question.questionType)

        return ResponseStrategy(
            type: baseType,
            requiresReasoning: needsReasoning,
            useKnowledge: useKnowledge,
            useSelfKnowledge: useSelf,
            useMemories: useMemories,
            tone: tone,
            complexity: complexity,
            instructions: instructions,
            fallbackApproach: fallback,
            maxResponseTokens: maxTokens
        )
    }

    // MARK: - Djup planering (mer tid för resonemang)

    func planDeep(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge
    ) -> ResponseStrategy {
        let baseType: ResponseStrategy.StrategyType
        switch question.questionType {
        case .explanation, .whyExplanation, .comparison:
            baseType = .deepAnalysis
        case .selfReference:
            baseType = .selfExplanation
        default:
            baseType = .reasoning
        }

        let instructions = buildDeepInstructions(
            question: question,
            knowledge: knowledge,
            selfKnowledge: selfKnowledge
        )

        return ResponseStrategy(
            type: baseType,
            requiresReasoning: true,
            useKnowledge: knowledge.hasStrongKnowledge,
            useSelfKnowledge: selfKnowledge.isRelevant,
            useMemories: !knowledge.memories.isEmpty,
            tone: .thoughtful,
            complexity: .deep,
            instructions: instructions,
            fallbackApproach: knowledge.topicCoverage < 0.2 ? .honestUncertainty : .none,
            maxResponseTokens: 400
        )
    }

    // MARK: - Strategitypbestämning

    private func determineStrategyType(
        question: QuestionProfile,
        selfKnowledge: SelfKnowledge
    ) -> ResponseStrategy.StrategyType {
        // Prioritetsordning: mest specifika först

        // 1. Hälsning
        if question.questionType == .greeting { return .greeting }

        // 2. Självrefererande
        if question.isAboutEon || selfKnowledge.isRelevant { return .selfExplanation }

        // 3. Uppföljning
        if question.isFollowUp { return .followUp }

        // 4. Baserat på frågetyp
        switch question.questionType {
        case .definition: return .definition
        case .comparison: return .comparison
        case .list: return .listAnswer
        case .explanation, .whyExplanation: return .reasoning
        case .howTo: return .knowledgeAnswer
        case .factual: return .factual
        case .yesNo: return .factual
        case .opinion: return .opinion
        case .creative: return .creative
        case .personal: return .empathetic
        case .selfReference: return .selfExplanation
        case .greeting: return .greeting
        case .followUp: return .followUp
        case .unknown: return .conversational
        }
    }

    // MARK: - Resonemangsbehovsanalys

    private func assessReasoningNeed(
        questionType: QuestionProfile.QuestionType,
        strategyType: ResponseStrategy.StrategyType,
        knowledgeCoverage: Double
    ) -> Bool {
        // Alltid resonera för dessa
        switch questionType {
        case .whyExplanation, .comparison, .opinion:
            return true
        case .explanation, .howTo:
            return knowledgeCoverage < 0.7  // Resonera om kunskapen inte räcker
        default:
            break
        }

        // Resonera om vi inte har full kunskap
        if knowledgeCoverage < 0.3 && strategyType != .greeting && strategyType != .conversational {
            return true
        }

        return false
    }

    // MARK: - Tonbestämning

    private func determineTone(
        emotionalTone: QuestionProfile.EmotionalTone,
        questionType: QuestionProfile.QuestionType,
        isFollowUp: Bool,
        context: ConversationContext
    ) -> ResponseStrategy.ResponseTone {
        // Matcha användarens ton
        switch emotionalTone {
        case .sad, .frustrated:
            return .empathetic
        case .happy:
            return .warm
        case .formal:
            return .academic
        case .informal:
            return .playful
        case .confused:
            return .warm
        case .urgent:
            return .confident
        default:
            break
        }

        // Baserat på frågetyp
        switch questionType {
        case .greeting: return .warm
        case .personal: return .empathetic
        case .creative: return .playful
        case .explanation, .definition: return .academic
        case .selfReference: return .thoughtful
        default: break
        }

        // Konversationslängd-baserad ton
        if context.turnCount > 5 { return .warm }  // Lång konversation → varmare

        return .neutral
    }

    // MARK: - Komplexitetsbestämning

    private func determineComplexity(
        expectedLength: QuestionProfile.ResponseLength,
        knowledgeCoverage: Double,
        questionType: QuestionProfile.QuestionType
    ) -> ResponseStrategy.ResponseComplexity {
        switch expectedLength {
        case .veryShort: return .simple
        case .short: return .simple
        case .medium:
            return knowledgeCoverage > 0.6 ? .moderate : .simple
        case .long:
            return knowledgeCoverage > 0.5 ? .complex : .moderate
        }
    }

    // MARK: - Fallback-bestämning

    private func determineFallback(
        knowledgeCoverage: Double,
        questionType: QuestionProfile.QuestionType,
        isAboutEon: Bool
    ) -> ResponseStrategy.FallbackApproach {
        // Eon vet alltid om sig själv
        if isAboutEon { return .none }

        // Hälsning/konversation behöver ingen kunskap
        if questionType == .greeting || questionType == .personal {
            return .none
        }

        // Baserat på kunskapstäckning
        if knowledgeCoverage > 0.5 { return .none }
        if knowledgeCoverage > 0.2 { return .honestUncertainty }
        if questionType == .factual || questionType == .definition {
            return .generalKnowledge
        }
        return .acknowledgeAndRedirect
    }

    // MARK: - Instruktionsbyggnad

    private func buildInstructions(
        type: ResponseStrategy.StrategyType,
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        tone: ResponseStrategy.ResponseTone,
        complexity: ResponseStrategy.ResponseComplexity,
        fallback: ResponseStrategy.FallbackApproach
    ) -> [String] {
        var instructions: [String] = []

        // Grundläggande instruktion baserat på strategi
        switch type {
        case .greeting:
            instructions.append("Svara kort och vänligt. Visa personlighet.")
        case .selfExplanation:
            instructions.append("Beskriv dig själv naturligt. Använd 'jag' och var ärlig om dina förmågor och begränsningar.")
            if selfKnowledge.isRelevant {
                instructions.append("Inkludera relevant självkunskap: \(selfKnowledge.relevantFacts.prefix(2).joined(separator: "; "))")
            }
            if !selfKnowledge.currentState.isEmpty {
                instructions.append("Nämn ditt aktuella tillstånd om det är intressant: \(selfKnowledge.currentState)")
            }
        case .factual, .knowledgeAnswer, .definition:
            instructions.append("Svara sakligt och direkt. Fakta först.")
            if knowledge.hasStrongKnowledge {
                instructions.append("Basera svaret på: \(knowledge.knowledgeSummary.prefix(200))")
            }
        case .reasoning, .deepAnalysis:
            instructions.append("Resonera steg för steg. Visa ditt tänkande.")
        case .comparison:
            instructions.append("Jämför punkt för punkt. Var balanserad.")
        case .listAnswer:
            instructions.append("Lista tydligt med punkter.")
        case .opinion:
            instructions.append("Ge en genomtänkt åsikt. Visa att du resonerar.")
        case .creative:
            instructions.append("Var kreativ och originell. Släpp loss lite.")
        case .empathetic:
            instructions.append("Visa empati först, sedan hjälp. Lyssna aktivt.")
        case .followUp:
            instructions.append("Koppla tillbaka till föregående ämne. Var koncis.")
        case .conversational:
            instructions.append("Var naturlig och personlig. Ställ gärna en motfråga.")
        }

        // Toninstruktion
        switch tone {
        case .warm: instructions.append("Ton: varm och personlig")
        case .academic: instructions.append("Ton: saklig och informativ")
        case .empathetic: instructions.append("Ton: empatisk och förstående")
        case .playful: instructions.append("Ton: lekfull och engagerande")
        case .thoughtful: instructions.append("Ton: eftertänksam och reflekterande")
        case .confident: instructions.append("Ton: säker och tydlig")
        case .curious: instructions.append("Ton: nyfiken och utforskande")
        case .neutral: break
        }

        // Fallback-instruktion
        switch fallback {
        case .honestUncertainty:
            instructions.append("Om osäker: säg ärligt att du inte är helt säker.")
        case .acknowledgeAndRedirect:
            instructions.append("Erkänn att du har begränsad kunskap i ämnet. Berätta vad du vet.")
        case .generalKnowledge:
            instructions.append("Använd din allmänkunskap om inte specifik kunskap finns.")
        case .askClarification:
            instructions.append("Be om förtydligande om frågan är otydlig.")
        case .none:
            break
        }

        // Längdinstruktion
        switch complexity {
        case .simple: instructions.append("Längd: 1-2 meningar")
        case .moderate: instructions.append("Längd: 3-4 meningar")
        case .complex: instructions.append("Längd: 5-7 meningar")
        case .deep: instructions.append("Längd: 8+ meningar, strukturerat med stycken")
        }

        return instructions
    }

    // MARK: - Djupa instruktioner

    private func buildDeepInstructions(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge
    ) -> [String] {
        var instructions: [String] = []

        instructions.append("DJUPANALYS: Ta tid att tänka igenom detta noggrant.")
        instructions.append("Strukturera svaret med tydliga stycken.")

        if question.questionParts.count > 1 {
            instructions.append("Besvara varje del av frågan separat:")
            for (i, part) in question.questionParts.enumerated() {
                instructions.append("  Del \(i+1): \(part.text)")
            }
        }

        if knowledge.hasStrongKnowledge {
            instructions.append("Du har relevant kunskap — använd den som grund.")
            instructions.append("Kunskap: \(knowledge.knowledgeSummary.prefix(300))")
        } else {
            instructions.append("Begränsad kunskap — resonera utifrån vad du vet och var ärlig om osäkerhet.")
        }

        if selfKnowledge.isRelevant {
            instructions.append("Inkludera självinsikt: \(selfKnowledge.relevantFacts.prefix(3).joined(separator: "; "))")
        }

        instructions.append("Avsluta med en reflekterande slutsats.")

        return instructions
    }

    // MARK: - Max tokens

    private func calculateMaxTokens(
        complexity: ResponseStrategy.ResponseComplexity,
        questionType: QuestionProfile.QuestionType
    ) -> Int {
        switch complexity {
        case .simple: return 60
        case .moderate: return 120
        case .complex: return 200
        case .deep: return 350
        }
    }
}
