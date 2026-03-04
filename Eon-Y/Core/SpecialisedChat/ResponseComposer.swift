import Foundation

// MARK: - ResponseComposer: Bygger Eons svar
// Tar all information (fråga, kunskap, strategi, tänkande) och komponerar
// det bästa möjliga svaret med GPT-SW3 eller template-baserat.

struct ResponseDraft: Sendable {
    let text: String
    let sources: [String]
    let usedKnowledge: Bool
    let usedSelfKnowledge: Bool
    let usedReasoning: Bool
    let promptUsed: String          // För debugging
    let generationMethod: GenerationMethod

    enum GenerationMethod: String, Sendable {
        case gptSW3 = "GPT-SW3"
        case template = "template"
        case hybrid = "hybrid"       // Template start + GPT-SW3 fortsättning
    }
}

actor ResponseComposer {
    private let neuralEngine = NeuralEngineOrchestrator.shared
    private let swedishBuilder = SwedishResponseBuilder.shared

    // MARK: - Normal komposition (max ~0.5s)

    func compose(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy,
        conversationContext: ConversationContext,
        thinkingResults: [ThinkingPath]
    ) async -> ResponseDraft {

        // Steg 1: Välj genereringsmetod
        let method = selectMethod(strategy: strategy, knowledge: knowledge)

        // Steg 2: Bygg prompt (anpassad för 512-token GPT-SW3)
        let prompt = buildCompactPrompt(
            question: question,
            knowledge: knowledge,
            selfKnowledge: selfKnowledge,
            strategy: strategy,
            conversationContext: conversationContext,
            thinkingResults: thinkingResults
        )

        // Steg 3: Generera svar
        let text: String
        switch method {
        case .template:
            text = await generateTemplateResponse(
                question: question,
                knowledge: knowledge,
                selfKnowledge: selfKnowledge,
                strategy: strategy
            )
        case .gptSW3:
            text = await generateGPTResponse(prompt: prompt, strategy: strategy)
        case .hybrid:
            text = await generateHybridResponse(
                question: question,
                knowledge: knowledge,
                selfKnowledge: selfKnowledge,
                strategy: strategy,
                prompt: prompt
            )
        }

        return ResponseDraft(
            text: text,
            sources: knowledge.sources,
            usedKnowledge: strategy.useKnowledge,
            usedSelfKnowledge: strategy.useSelfKnowledge,
            usedReasoning: !thinkingResults.isEmpty,
            promptUsed: prompt,
            generationMethod: method
        )
    }

    // MARK: - Djup komposition (mer tid)

    func composeDeep(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy,
        conversationContext: ConversationContext,
        thinkingResults: [ThinkingPath]
    ) async -> ResponseDraft {

        // Bygg djupare prompt
        let prompt = buildDeepPrompt(
            question: question,
            knowledge: knowledge,
            selfKnowledge: selfKnowledge,
            strategy: strategy,
            thinkingResults: thinkingResults
        )

        // Generera med mer tokens
        let raw = await neuralEngine.generate(
            prompt: prompt,
            maxTokens: strategy.maxResponseTokens,
            temperature: 0.6
        )

        // Integrera tänkande-resultat om de är starka
        var text = raw
        if let bestThinking = thinkingResults.first, bestThinking.confidence > 0.6 {
            text = integrateThinkingIntoResponse(
                response: raw,
                thinking: bestThinking,
                question: question
            )
        }

        return ResponseDraft(
            text: text,
            sources: knowledge.sources,
            usedKnowledge: strategy.useKnowledge,
            usedSelfKnowledge: strategy.useSelfKnowledge,
            usedReasoning: !thinkingResults.isEmpty,
            promptUsed: prompt,
            generationMethod: .gptSW3
        )
    }

    // MARK: - Metod-val

    private func selectMethod(
        strategy: ResponseStrategy,
        knowledge: KnowledgeBundle
    ) -> ResponseDraft.GenerationMethod {
        switch strategy.type {
        case .greeting:
            return .template  // Hälsningar behöver inte GPT-SW3
        case .selfExplanation:
            return .hybrid    // Template-start + GPT-SW3 för naturlighet
        case .factual, .definition:
            if knowledge.hasStrongKnowledge {
                return .hybrid  // Fakta-baserat + GPT-SW3 för språk
            }
            return .gptSW3
        default:
            return .gptSW3
        }
    }

    // MARK: - Kompakt prompt (max ~350 tokens för GPT-SW3:s 512-fönster)

    private func buildCompactPrompt(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy,
        conversationContext: ConversationContext,
        thinkingResults: [ThinkingPath]
    ) -> String {
        var parts: [String] = []
        var charBudget = 900  // ~350 tokens ≈ 900 tecken

        // 1. Systeminstruktion (kort)
        let sysInstruction = "Du är Eon, AI på svenska. Svara koncist och korrekt."
        parts.append(sysInstruction)
        charBudget -= sysInstruction.count

        // 2. Strategiinstruktioner (bara viktigaste)
        if let firstInstruction = strategy.instructions.first, charBudget > 100 {
            let instr = String(firstInstruction.prefix(min(100, charBudget - 20)))
            parts.append(instr)
            charBudget -= instr.count
        }

        // 3. Självkunskap (om relevant)
        if selfKnowledge.isRelevant, charBudget > 100 {
            let selfText = selfKnowledge.relevantFacts.prefix(2)
                .joined(separator: " ")
                .prefix(min(200, charBudget - 20))
            parts.append("[Om mig] \(selfText)")
            charBudget -= selfText.count + 10

            if !selfKnowledge.currentState.isEmpty, charBudget > 50 {
                let state = String(selfKnowledge.currentState.prefix(min(100, charBudget - 10)))
                parts.append("[Tillstånd] \(state)")
                charBudget -= state.count + 12
            }
        }

        // 4. Kunskap (om tillgänglig)
        if strategy.useKnowledge && knowledge.hasStrongKnowledge, charBudget > 80 {
            let context = knowledge.bestContextForPrompt(maxChars: min(250, charBudget - 20))
            if !context.isEmpty {
                parts.append("[Fakta] \(context)")
                charBudget -= context.count + 8
            }
        }

        // 5. Bästa tänkande-resultat
        if let best = thinkingResults.first, best.confidence > 0.4, charBudget > 60 {
            let thought = String(best.conclusion.prefix(min(80, charBudget - 15)))
            parts.append("[Analys] \(thought)")
            charBudget -= thought.count + 10
        }

        // 6. Konversationskontext (om uppföljning)
        if question.isFollowUp && !conversationContext.currentTopic.isEmpty, charBudget > 40 {
            let ctx = "Senaste ämne: \(conversationContext.currentTopic)"
            parts.append(ctx)
            charBudget -= ctx.count
        }

        // 7. Frågan sist (viktigast — syns alltid i GPT-SW3:s fönster)
        let topicLabel = question.coreTopic.isEmpty ? "" : " om \(question.coreTopic)"
        parts.append("Användare: \(question.resolvedInput)")
        parts.append("Eon (svar\(topicLabel)):")

        return parts.joined(separator: "\n")
    }

    // MARK: - Djup prompt

    private func buildDeepPrompt(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy,
        thinkingResults: [ThinkingPath]
    ) -> String {
        var parts: [String] = []

        parts.append("Du är Eon, ett djuptänkande AI-system. Ge ett utförligt och genomtänkt svar.")

        // Instruktioner
        for instr in strategy.instructions.prefix(3) {
            parts.append(String(instr.prefix(120)))
        }

        // All tillgänglig kunskap
        if selfKnowledge.isRelevant {
            let selfText = selfKnowledge.relevantFacts.prefix(4).joined(separator: " ")
            parts.append("[Självkunskap] \(String(selfText.prefix(300)))")
        }

        if knowledge.hasStrongKnowledge {
            let ctx = knowledge.bestContextForPrompt(maxChars: 350)
            parts.append("[Kunskap] \(ctx)")
        }

        // Tänkande-resultat
        for path in thinkingResults.prefix(2) where path.confidence > 0.3 {
            parts.append("[\(path.approach.rawValue)] \(String(path.conclusion.prefix(100)))")
        }

        // Flerdelsfrågor
        if question.questionParts.count > 1 {
            parts.append("Besvara varje del:")
            for (i, part) in question.questionParts.enumerated() {
                parts.append("\(i+1). \(part.text)")
            }
        }

        parts.append("Användare: \(question.resolvedInput)")
        parts.append("Eon (djupanalys om \(question.coreTopic)):")

        return parts.joined(separator: "\n")
    }

    // MARK: - Template-baserad generering

    private func generateTemplateResponse(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy
    ) async -> String {

        switch strategy.type {
        case .greeting:
            return swedishBuilder.buildGreeting(
                emotionalTone: question.emotionalTone,
                isFollowUp: question.isFollowUp
            )

        case .selfExplanation:
            return swedishBuilder.buildSelfResponse(
                selfKnowledge: selfKnowledge,
                questionType: question.questionType
            )

        case .definition:
            if let fact = knowledge.facts.first {
                return swedishBuilder.buildDefinition(
                    topic: question.coreTopic,
                    fact: fact.naturalLanguage
                )
            }
            return swedishBuilder.buildUncertainResponse(topic: question.coreTopic)

        default:
            // Fallback till GPT-SW3
            let prompt = "Du är Eon. Svara kort.\nAnvändare: \(question.resolvedInput)\nEon:"
            return await neuralEngine.generate(prompt: prompt, maxTokens: 100)
        }
    }

    // MARK: - GPT-SW3 generering

    private func generateGPTResponse(prompt: String, strategy: ResponseStrategy) async -> String {
        let temperature: Float
        switch strategy.tone {
        case .academic, .confident: temperature = 0.5
        case .creative, .playful: temperature = 0.85
        case .warm, .empathetic: temperature = 0.7
        default: temperature = 0.65
        }

        return await neuralEngine.generate(
            prompt: prompt,
            maxTokens: strategy.maxResponseTokens,
            temperature: temperature
        )
    }

    // MARK: - Hybrid generering

    private func generateHybridResponse(
        question: QuestionProfile,
        knowledge: KnowledgeBundle,
        selfKnowledge: SelfKnowledge,
        strategy: ResponseStrategy,
        prompt: String
    ) async -> String {
        // Steg 1: Template-baserad start
        let templateStart: String

        if strategy.type == .selfExplanation {
            templateStart = swedishBuilder.buildSelfResponseStart(selfKnowledge: selfKnowledge)
        } else if strategy.type == .factual || strategy.type == .definition {
            if let fact = knowledge.facts.first {
                templateStart = swedishBuilder.buildFactStart(
                    topic: question.coreTopic,
                    fact: fact.naturalLanguage
                )
            } else {
                templateStart = ""
            }
        } else {
            templateStart = ""
        }

        // Steg 2: GPT-SW3 fortsättning
        if !templateStart.isEmpty {
            let continuationPrompt = prompt + " " + templateStart
            let continuation = await neuralEngine.generate(
                prompt: continuationPrompt,
                maxTokens: max(50, strategy.maxResponseTokens - 30),
                temperature: 0.65
            )

            // Rensa continuation så den inte upprepar template-starten
            let cleaned = removeOverlap(base: templateStart, continuation: continuation)
            return templateStart + " " + cleaned
        }

        return await generateGPTResponse(prompt: prompt, strategy: strategy)
    }

    // MARK: - Integrera tänkande i svar

    private func integrateThinkingIntoResponse(
        response: String,
        thinking: ThinkingPath,
        question: QuestionProfile
    ) -> String {
        // Om svaret är kort och tänkandet har bra fakta, lägg till
        guard response.count < 200 else { return response }

        // Kontrollera att tänkandets slutsats inte redan finns i svaret
        let responseLower = response.lowercased()
        let conclusionLower = thinking.conclusion.lowercased()

        // Jaccard-likhet — om redan inkluderat, skippa
        let responseWords = Set(responseLower.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        let conclusionWords = Set(conclusionLower.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 3 })
        let overlap = responseWords.intersection(conclusionWords).count
        let total = responseWords.union(conclusionWords).count
        if total > 0 && Double(overlap) / Double(total) > 0.5 {
            return response  // Redan inkluderat
        }

        // Lägg till kortfattad slutsats
        if let firstFact = thinking.relevantFacts.first, !responseLower.contains(firstFact.lowercased().prefix(20)) {
            return response.trimmingCharacters(in: .whitespacesAndNewlines) + " " + firstFact
        }

        return response
    }

    // MARK: - Hjälpfunktioner

    /// Tar bort överlappning mellan template-start och GPT-continuation
    private func removeOverlap(base: String, continuation: String) -> String {
        let baseWords = base.lowercased().components(separatedBy: .whitespacesAndNewlines).suffix(5)
        let contWords = continuation.components(separatedBy: .whitespacesAndNewlines)

        // Hitta om continuationen börjar med ord som redan finns i basen
        var skipCount = 0
        for (i, word) in contWords.enumerated() {
            if i < 5 && baseWords.contains(word.lowercased()) {
                skipCount = i + 1
            } else {
                break
            }
        }

        if skipCount > 0 {
            return contWords.dropFirst(skipCount).joined(separator: " ")
        }
        return continuation
    }
}
