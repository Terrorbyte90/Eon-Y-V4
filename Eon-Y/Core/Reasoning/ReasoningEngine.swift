import Foundation
import NaturalLanguage

// MARK: - ReasoningEngine
// Eons avancerade resonemangssystem.
// Implementerar: kausal inferens, Tree-of-Thought (ToT), Chain-of-Thought (CoT),
// analogibyggande (Gentner), kontrafaktisk analys, deduktion/induktion/abduktion,
// och Peircean semiotik för djup meningsanalys.

actor ReasoningEngine {
    static let shared = ReasoningEngine()

    private var reasoningHistory: [ReasoningTrace] = []
    private var causalGraph: CausalGraph = CausalGraph()
    private var analogyLibrary: [StructuralAnalogy] = []
    private var activeHypotheses: [ActiveHypothesis] = []

    private init() {
        // Kausalgraf byggs upp i reason()-anrop och via enrichCausalGraphFromFacts()
        // Seed-relationer läggs till vid första anrop via lazy init
        let graph = causalGraph
        graph.addRelation(cause: "Inlärning",       effect: "Kompetens",      strength: 0.90)
        graph.addRelation(cause: "Kompetens",       effect: "Prestation",     strength: 0.85)
        graph.addRelation(cause: "Nyfikenhet",      effect: "Inlärning",      strength: 0.80)
        graph.addRelation(cause: "Motivation",      effect: "Nyfikenhet",     strength: 0.75)
        graph.addRelation(cause: "Feedback",        effect: "Inlärning",      strength: 0.70)
        graph.addRelation(cause: "Stress",          effect: "Prestation",     strength: -0.60)
        graph.addRelation(cause: "Sömn",            effect: "Kognition",      strength: 0.85)
        graph.addRelation(cause: "Kognition",       effect: "Resonemang",     strength: 0.90)
        graph.addRelation(cause: "Resonemang",      effect: "Förståelse",     strength: 0.88)
        graph.addRelation(cause: "Förståelse",      effect: "Kunskap",        strength: 0.92)
        graph.addRelation(cause: "Kunskap",         effect: "Kreativitet",    strength: 0.65)
        graph.addRelation(cause: "Kreativitet",     effect: "Innovation",     strength: 0.78)
        graph.addRelation(cause: "Metakognition",   effect: "Inlärning",      strength: 0.82)
        graph.addRelation(cause: "Metakognition",   effect: "Resonemang",     strength: 0.75)
        graph.addRelation(cause: "Kausalitet",      effect: "Förståelse",     strength: 0.80)
        graph.addRelation(cause: "Analogier",       effect: "Kreativitet",    strength: 0.70)
        graph.addRelation(cause: "Språk",           effect: "Tänkande",       strength: 0.85)
        graph.addRelation(cause: "Tänkande",        effect: "Problemlösning", strength: 0.88)
        graph.addRelation(cause: "Uppmärksamhet",   effect: "Inlärning",      strength: 0.78)
        graph.addRelation(cause: "Repetition",      effect: "Minne",          strength: 0.90)
        graph.addRelation(cause: "Minne",           effect: "Kunskap",        strength: 0.85)
        // v7: Additional causal relations — consciousness, emotion, social, biological
        graph.addRelation(cause: "Medvetande",      effect: "Självkännedom",  strength: 0.85)
        graph.addRelation(cause: "Självkännedom",   effect: "Metakognition",  strength: 0.80)
        graph.addRelation(cause: "Emotion",         effect: "Motivation",     strength: 0.75)
        graph.addRelation(cause: "Motivation",      effect: "Inlärning",      strength: 0.70)
        graph.addRelation(cause: "Empati",          effect: "Kommunikation",  strength: 0.72)
        graph.addRelation(cause: "Kommunikation",   effect: "Samarbete",      strength: 0.80)
        graph.addRelation(cause: "Samarbete",       effect: "Innovation",     strength: 0.65)
        graph.addRelation(cause: "Nyfikenhet",      effect: "Utforskning",    strength: 0.85)
        graph.addRelation(cause: "Utforskning",     effect: "Kunskap",        strength: 0.80)
        graph.addRelation(cause: "Övning",          effect: "Kompetens",      strength: 0.90)
        graph.addRelation(cause: "Reflektion",      effect: "Förståelse",     strength: 0.78)
        graph.addRelation(cause: "Kritik",          effect: "Förbättring",    strength: 0.70)
        graph.addRelation(cause: "Medvetande",      effect: "Fri vilja",      strength: 0.55)
        graph.addRelation(cause: "Integration",     effect: "Medvetande",     strength: 0.82)
        graph.addRelation(cause: "Komplexitet",     effect: "Emergens",       strength: 0.75)
        graph.addRelation(cause: "Sömn",            effect: "Konsolidering",  strength: 0.88)
        graph.addRelation(cause: "Konsolidering",   effect: "Minne",          strength: 0.85)
        // v9: Domain-specific causal relations — education, society, biology, technology
        graph.addRelation(cause: "Utbildning",      effect: "Kompetens",      strength: 0.85)
        graph.addRelation(cause: "Läsning",         effect: "Vokabulär",      strength: 0.80)
        graph.addRelation(cause: "Vokabulär",       effect: "Kommunikation",  strength: 0.75)
        graph.addRelation(cause: "Kommunikation",   effect: "Förståelse",     strength: 0.78)
        graph.addRelation(cause: "Självdisciplin",  effect: "Prestation",     strength: 0.72)
        graph.addRelation(cause: "Kreativitet",     effect: "Problemlösning", strength: 0.68)
        graph.addRelation(cause: "Meditation",      effect: "Uppmärksamhet",  strength: 0.70)
        graph.addRelation(cause: "Ångest",          effect: "Kognition",      strength: -0.55)
        graph.addRelation(cause: "Gemenskap",       effect: "Empati",         strength: 0.72)
        graph.addRelation(cause: "Autonomi",        effect: "Motivation",     strength: 0.78)
        graph.addRelation(cause: "Anpassning",      effect: "Överlevnad",     strength: 0.90)
        graph.addRelation(cause: "Emergens",        effect: "Medvetande",     strength: 0.65)
        graph.addRelation(cause: "Prediktionsfel",  effect: "Inlärning",      strength: 0.82)
        graph.addRelation(cause: "Surprise",        effect: "Nyfikenhet",     strength: 0.70)
        graph.addRelation(cause: "Oscillationer",   effect: "Integration",    strength: 0.75)
    }

    // MARK: - Primär resonemangsfunktion

    func reason(about input: String, strategy: ReasoningStrategy = .adaptive, depth: Int = 3) async -> ReasoningResult {
        let trace = ReasoningTrace(input: input, strategy: strategy, startedAt: Date())

        let result: ReasoningResult
        switch strategy {
        case .deductive:     result = await deductiveReason(input: input, depth: depth, trace: trace)
        case .inductive:     result = await inductiveReason(input: input, depth: depth, trace: trace)
        case .abductive:     result = await abductiveReason(input: input, depth: depth, trace: trace)
        case .analogical:    result = await analogicalReason(input: input, depth: depth, trace: trace)
        case .counterfactual:result = await counterfactualReason(input: input, depth: depth, trace: trace)
        case .causal:        result = await causalReason(input: input, depth: depth, trace: trace)
        case .treeOfThought: result = await treeOfThoughtReason(input: input, depth: depth, trace: trace)
        case .adaptive:      result = await adaptiveReason(input: input, depth: depth, trace: trace)
        }

        reasoningHistory.append(trace)
        if reasoningHistory.count > 200 { reasoningHistory.removeFirst(50) }

        return result
    }

    // MARK: - Deduktivt resonemang (A→B, B→C ⟹ A→C)

    private func deductiveReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        // Extrahera premisser
        let premises = extractPremises(from: input)
        steps.append(ReasoningStep(type: .premise, content: "Premisser: \(premises.joined(separator: "; "))", confidence: 0.9))

        // Tillämpa modus ponens
        var conclusions: [String] = []
        guard premises.count >= 2 else {
            return ReasoningResult(strategy: .deductive, steps: steps, conclusion: premises.first ?? input, confidence: 0.5, alternatives: [], causalChain: [])
        }
        for i in 0..<min(premises.count - 1, depth) {
            let nextPremise = (i + 1 < premises.count) ? premises[i + 1] : premises[i]
            let conclusion = deriveConclusion(from: premises[i], and: nextPremise)
            conclusions.append(conclusion)
            steps.append(ReasoningStep(type: .inference, content: "Slutledning \(i+1): \(conclusion)", confidence: 0.8 - Double(i) * 0.05))
        }

        // Kausalkedja
        let causalChain = causalGraph.findChain(from: extractMainConcept(input))
        if !causalChain.isEmpty {
            steps.append(ReasoningStep(type: .causal, content: "Kausalkedja: \(causalChain.joined(separator: " → "))", confidence: 0.75))
        }

        let finalConclusion = conclusions.last ?? "Otillräckliga premisser för deduktion"
        steps.append(ReasoningStep(type: .conclusion, content: finalConclusion, confidence: 0.78))

        // Weighted confidence: heavier weight on conclusion + causal steps
        let stepConfidences = steps.map { $0.confidence }
        let weightedConf = stepConfidences.enumerated().reduce(0.0) { sum, pair in
            let weight = pair.offset == stepConfidences.count - 1 ? 2.0 : 1.0 // Conclusion weighted 2x
            return sum + pair.element * weight
        } / (Double(stepConfidences.count) + 1.0)

        return ReasoningResult(
            strategy: .deductive,
            steps: steps,
            conclusion: finalConclusion,
            confidence: max(0.3, weightedConf),
            alternatives: [],
            causalChain: causalChain
        )
    }

    // MARK: - Induktivt resonemang (specifikt → generellt)

    private func inductiveReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        let observations = extractObservations(from: input)
        steps.append(ReasoningStep(type: .observation, content: "Observationer: \(observations.count) identifierade", confidence: 0.85))

        // Hitta mönster
        let patterns = findPatterns(in: observations)
        for pattern in patterns.prefix(depth) {
            steps.append(ReasoningStep(type: .pattern, content: "Mönster: \(pattern)", confidence: 0.7))
        }

        // Generalisera
        let generalization = generalize(from: observations, patterns: patterns)
        steps.append(ReasoningStep(type: .generalization, content: generalization, confidence: 0.65))

        // Konfidensberäkning baserat på antal observationer
        let confidence = min(0.9, 0.4 + Double(observations.count) * 0.1)

        return ReasoningResult(
            strategy: .inductive,
            steps: steps,
            conclusion: generalization,
            confidence: confidence,
            alternatives: patterns.map { "Alternativt mönster: \($0)" },
            causalChain: []
        )
    }

    // MARK: - Abduktivt resonemang (bästa förklaring)

    private func abductiveReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        let observation = input.trimmingCharacters(in: .whitespaces)
        steps.append(ReasoningStep(type: .observation, content: "Observation: \(observation)", confidence: 1.0))

        // Generera möjliga förklaringar
        let hypotheses = generateHypotheses(for: observation, count: depth)
        for (i, h) in hypotheses.enumerated() {
            steps.append(ReasoningStep(type: .hypothesis, content: "H\(i+1): \(h.statement) (plausibilitet: \(String(format: "%.0f", h.plausibility * 100))%)", confidence: h.plausibility))
        }

        // Välj bästa förklaring (IBE — Inference to the Best Explanation)
        let best = hypotheses.max(by: { $0.plausibility < $1.plausibility })
        let conclusion = best.map { "Bästa förklaring: \($0.statement)" } ?? "Ingen tillfredsställande förklaring hittad"
        steps.append(ReasoningStep(type: .conclusion, content: conclusion, confidence: best?.plausibility ?? 0.4))

        return ReasoningResult(
            strategy: .abductive,
            steps: steps,
            conclusion: conclusion,
            confidence: best?.plausibility ?? 0.4,
            alternatives: hypotheses.dropFirst().map { $0.statement },
            causalChain: []
        )
    }

    // MARK: - Analogibyggande (Gentner's Structure Mapping)

    private func analogicalReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        let sourceConcept = extractMainConcept(input)
        steps.append(ReasoningStep(type: .premise, content: "Källdomän: \(sourceConcept)", confidence: 0.9))

        // Hitta strukturella analogier
        let analogies = findAnalogies(for: sourceConcept)
        for analogy in analogies.prefix(depth) {
            steps.append(ReasoningStep(type: .analogy, content: "Analogi: \(sourceConcept) ↔ \(analogy.target) [struktur: \(analogy.mappings.joined(separator: ", "))]", confidence: analogy.strength))
        }

        // Generera insikt från analogi
        let insight = analogies.first.map { a in
            "Strukturell insikt: \(sourceConcept) och \(a.target) delar \(a.mappings.first ?? "djup struktur'") — detta antyder att \(a.inference)"
        } ?? "Ingen stark analogi hittad för \(sourceConcept)"

        steps.append(ReasoningStep(type: .insight, content: insight, confidence: analogies.first?.strength ?? 0.4))

        return ReasoningResult(
            strategy: .analogical,
            steps: steps,
            conclusion: insight,
            confidence: analogies.first?.strength ?? 0.4,
            alternatives: analogies.dropFirst().map { "Svagare analogi: \($0.target)" },
            causalChain: []
        )
    }

    // MARK: - Kontrafaktisk analys

    private func counterfactualReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        let factual = input
        steps.append(ReasoningStep(type: .premise, content: "Faktum: \(factual)", confidence: 0.95))

        // Generera kontrafaktiska scenarion
        let counterfactuals = generateCounterfactuals(for: factual, count: depth)
        for cf in counterfactuals {
            steps.append(ReasoningStep(type: .counterfactual, content: "Om \(cf.condition), då \(cf.consequence) (sannolikhet: \(String(format: "%.0f", cf.probability * 100))%)", confidence: cf.probability))
        }

        let mostPlausible = counterfactuals.max(by: { $0.probability < $1.probability })
        let conclusion = mostPlausible.map { "Mest plausibelt kontrafaktum: Om \($0.condition), hade \($0.consequence)" } ?? "Kontrafaktisk analys ofullständig"

        steps.append(ReasoningStep(type: .conclusion, content: conclusion, confidence: mostPlausible?.probability ?? 0.5))

        return ReasoningResult(
            strategy: .counterfactual,
            steps: steps,
            conclusion: conclusion,
            confidence: mostPlausible?.probability ?? 0.5,
            alternatives: counterfactuals.map { "Om \($0.condition): \($0.consequence)" },
            causalChain: []
        )
    }

    // MARK: - Kausalresonemang

    private func causalReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []

        let concept = extractMainConcept(input)
        steps.append(ReasoningStep(type: .premise, content: "Analyserar kausalstruktur för: \(concept)", confidence: 0.9))

        // Hitta orsaker
        let causes = causalGraph.findCauses(of: concept)
        if !causes.isEmpty {
            steps.append(ReasoningStep(type: .causal, content: "Orsaker till \(concept): \(causes.joined(separator: ", "))", confidence: 0.8))
        }

        // Hitta effekter
        let effects = causalGraph.findEffects(of: concept)
        if !effects.isEmpty {
            steps.append(ReasoningStep(type: .causal, content: "Effekter av \(concept): \(effects.joined(separator: ", "))", confidence: 0.75))
        }

        // Kausalkedja
        let chain = causalGraph.findChain(from: concept)
        if !chain.isEmpty {
            steps.append(ReasoningStep(type: .causal, content: "Kausalkedja: \(chain.joined(separator: " → "))", confidence: 0.7))
        }

        let conclusion = "Kausalanalys av \(concept): \(causes.count) orsaker, \(effects.count) effekter identifierade"
        steps.append(ReasoningStep(type: .conclusion, content: conclusion, confidence: 0.72))

        return ReasoningResult(
            strategy: .causal,
            steps: steps,
            conclusion: conclusion,
            confidence: 0.72,
            alternatives: [],
            causalChain: chain
        )
    }

    // MARK: - Tree-of-Thought (ToT)

    private func treeOfThoughtReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        var steps: [ReasoningStep] = []
        var tree: [ThoughtNode] = []

        let root = ThoughtNode(content: input, depth: 0, score: 1.0)
        tree.append(root)
        steps.append(ReasoningStep(type: .premise, content: "ToT rot: \(input)", confidence: 1.0))

        // Expandera trädet
        var currentNodes = [root]
        for d in 1...min(depth, 3) {
            var nextNodes: [ThoughtNode] = []
            for node in currentNodes.prefix(3) {
                let children = expandThought(node, branching: 3)
                nextNodes.append(contentsOf: children)
                for child in children {
                    steps.append(ReasoningStep(type: .hypothesis, content: "Nivå \(d): \(child.content) (poäng: \(String(format: "%.2f", child.score)))", confidence: child.score))
                }
            }
            // Välj bästa grenar (beam search)
            currentNodes = nextNodes.sorted { $0.score > $1.score }.prefix(3).map { $0 }
            tree.append(contentsOf: currentNodes)
        }

        // Välj bästa löv
        let bestLeaf = tree.filter { $0.depth == min(depth, 3) }.max(by: { $0.score < $1.score })
        let conclusion = bestLeaf?.content ?? "ToT-sökning konvergerade inte"
        steps.append(ReasoningStep(type: .conclusion, content: "Bästa sökväg: \(conclusion)", confidence: bestLeaf?.score ?? 0.5))

        return ReasoningResult(
            strategy: .treeOfThought,
            steps: steps,
            conclusion: conclusion,
            confidence: bestLeaf?.score ?? 0.5,
            alternatives: currentNodes.map { $0.content },
            causalChain: []
        )
    }

    // MARK: - Adaptivt resonemang (väljer bäst strategi automatiskt)

    private func adaptiveReason(input: String, depth: Int, trace: ReasoningTrace) async -> ReasoningResult {
        let strategy = selectBestStrategy(for: input)
        return await reason(about: input, strategy: strategy, depth: depth)
    }

    // v7: Consciousness-informed adaptive strategy selection
    // Uses NLTagger POS analysis + consciousness state (curiosity, surprise, criticality)
    // to choose the optimal reasoning strategy.
    private func selectBestStrategy(for input: String) -> ReasoningStrategy {
        let lower = input.lowercased()
        let wordCount = lower.split(separator: " ").count

        // --- Phase 1: Keyword-based intent (fast path) ---

        // Causal reasoning — "why" questions
        if lower.contains("varför") || lower.contains("orsak") || lower.contains("beror") ||
           lower.contains("leder till") || lower.contains("konsekvens") ||
           lower.contains("på grund av") || lower.contains("orsaka") { return .causal }

        // Counterfactual — hypothetical scenarios
        if lower.contains("om") && (lower.contains("hade") || lower.contains("skulle")) { return .counterfactual }
        if lower.contains("tänk om") || lower.contains("vad hade hänt") ||
           lower.contains("hypotetiskt") || lower.contains("alternativt") { return .counterfactual }

        // Analogical — comparison and similarity
        if lower.contains("liknar") || lower.contains("jämför") || lower.contains("skillnad") ||
           lower.contains("gemensamt") || lower.contains("precis som") ||
           lower.contains("påminner om") || lower.contains("analogt") { return .analogical }

        // Inductive — patterns and generalizations
        if lower.contains("alla") || lower.contains("generellt") || lower.contains("mönster") ||
           lower.contains("trend") || lower.contains("statistik") || lower.contains("oftast") { return .inductive }

        // Deductive — logical inference
        if lower.contains("slutsats") || lower.contains("bevis") || lower.contains("därför") ||
           lower.contains("logiskt") || lower.contains("givet att") || lower.contains("om vi antar") ||
           lower.contains("alltså") || lower.contains("följaktligen") { return .deductive }

        // Abductive — best explanation
        if lower.contains("förklara") || lower.contains("vad är") || lower.contains("hur kan det") ||
           lower.contains("bästa förklaringen") || lower.contains("troligast") { return .abductive }

        // --- Phase 2: NLTagger structural analysis ---
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = input
        var nounCount = 0, verbCount = 0
        tagger.enumerateTags(in: input.startIndex..<input.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if tag == .noun { nounCount += 1 }
            if tag == .verb { verbCount += 1 }
            return true
        }

        // Noun-heavy inputs → conceptual → analogical (find cross-domain connections)
        if nounCount >= 3 && verbCount <= 1 { return .analogical }

        // For complex multi-sentence inputs, use Tree-of-Thought
        if wordCount > 15 { return .treeOfThought }

        // --- Phase 3: v9 — Consciousness-informed strategy bias ---
        let inference = ActiveInferenceEngine.shared
        let crit = CriticalityController.shared

        // High curiosity → abductive (generate best explanations)
        if inference.epistemicValue > 0.7 { return .abductive }

        // Surprise → causal (find why prediction was wrong)
        if inference.isSurprised && inference.surpriseStrength > 0.4 { return .causal }

        // Subcritical → analogical (rigid thinking needs cross-domain connections)
        if crit.regime == .subcritical { return .analogical }

        // Supercritical → deductive (chaotic thinking needs structure)
        if crit.regime == .supercritical { return .deductive }

        // --- Phase 4: Diversity-based selection ---
        // Ensure we don't over-use any single strategy
        let recentStrategies = reasoningHistory.suffix(10).map { $0.strategy }
        let strategyCounts = Dictionary(recentStrategies.map { ($0, 1) }, uniquingKeysWith: +)
        let allStrategies: [ReasoningStrategy] = [.analogical, .counterfactual, .inductive, .causal, .abductive, .deductive]
        let leastUsed = allStrategies.min(by: { (strategyCounts[$0] ?? 0) < (strategyCounts[$1] ?? 0) })
        return leastUsed ?? .treeOfThought
    }

    // MARK: - Kausalgraf

    // Uppdatera kausalgraf från faktiska SPO-fakta i databasen
    func enrichCausalGraphFromFacts() async {
        // Hämta fakta utanför actor-kontexten (await-anrop)
        let facts = await PersistentMemoryStore.shared.recentFactsWithConfidence(limit: 50)

        // Filtrera kausala relationer lokalt — ingen mutation av actor-property under await
        let causalPredicates = ["orsakar", "leder_till", "påverkar", "förstärker", "hämmar", "möjliggör", "kräver", "ger_upphov_till"]
        let relations: [(cause: String, effect: String, strength: Double)] = facts.compactMap { fact in
            guard causalPredicates.contains(fact.predicate.lowercased()) else { return nil }
            let strength: Double = fact.predicate.contains("hämmar") ? -fact.confidence : fact.confidence
            return (fact.subject, fact.object, strength)
        }

        // Uppdatera grafen synkront inom actor-isoleringen (ingen inout-problematik)
        for rel in relations {
            causalGraph.addRelation(cause: rel.cause, effect: rel.effect, strength: rel.strength)
        }
        if !relations.isEmpty {
            print("[ReasoningEngine] Kausalgraf berikad med \(relations.count) fakta-relationer (totalt \(causalGraph.nodeCount) noder)")
        }
    }

    // MARK: - Hjälpfunktioner

    private func extractPremises(from text: String) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".;,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 5 }
        return Array(sentences.prefix(4))
    }

    private func extractObservations(from text: String) -> [String] {
        extractPremises(from: text)
    }

    private func extractMainConcept(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var nouns: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .noun, String(text[range]).count > 3 { nouns.append(String(text[range])) }
            return true
        }
        return nouns.first ?? String(text.prefix(20))
    }

    private func deriveConclusion(from p1: String, and p2: String) -> String {
        let stopwords: Set<String> = ["och", "i", "att", "det", "en", "ett", "är", "av", "för", "med", "på", "som", "den", "till", "har", "de", "inte", "om", "var",
                                       "denna", "dessa", "alla", "kan", "ska", "hos", "vid", "från", "men", "eller", "där", "här", "sin", "sitt", "sina",
                                       "dock", "också", "samt", "bara", "just", "redan", "sedan", "inom", "mellan", "efter", "under", "genom"]
        let words1 = Set(p1.lowercased().split(separator: " ").map(String.init).filter { $0.count > 3 && !stopwords.contains($0) })
        let words2 = Set(p2.lowercased().split(separator: " ").map(String.init).filter { $0.count > 3 && !stopwords.contains($0) })
        let shared = words1.intersection(words2)

        if shared.isEmpty {
            // Try causal graph for indirect connection
            let concept1 = extractMainConcept(p1)
            let concept2 = extractMainConcept(p2)
            let effects1 = causalGraph.findEffects(of: concept1)
            let causes2 = causalGraph.findCauses(of: concept2)
            let bridge = Set(effects1).intersection(Set(causes2))
            if let bridgeElement = bridge.first {
                return "Indirekt koppling via \(bridgeElement): \(concept1) → \(bridgeElement) → \(concept2)"
            }
            return "Premisserna berör olika aspekter som kan komplettera varandra"
        }
        guard let key = shared.sorted(by: { $0.count > $1.count }).first else {
            return "Premisserna berör olika aspekter som kan komplettera varandra"
        }
        return "Genom \(key): \(String(p1.prefix(40))) kopplas till \(String(p2.prefix(40)))"
    }

    private func findPatterns(in observations: [String]) -> [String] {
        guard observations.count >= 2 else { return ["Otillräckliga observationer"] }
        let allWords = observations.flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        let wordFreq = Dictionary(allWords.map { ($0, 1) }, uniquingKeysWith: +)
        let common = wordFreq.filter { $0.value >= 2 && $0.key.count > 3 }.keys.sorted()
        return common.isEmpty ? ["Inget tydligt mönster"] : common.map { "Återkommande: \($0)" }
    }

    private func generalize(from observations: [String], patterns: [String]) -> String {
        let pattern = patterns.first ?? "okänt mönster"
        return "Generell regel baserad på \(observations.count) observationer: \(pattern) verkar vara ett konsistent mönster"
    }

    private func generateHypotheses(for observation: String, count: Int) -> [Hypothesis] {
        let concept = extractMainConcept(observation)
        let causes = causalGraph.findCauses(of: concept)
        let effects = causalGraph.findEffects(of: concept)

        var hypotheses: [Hypothesis] = []

        // Evidence-based hypothesis from causal graph
        if !causes.isEmpty {
            let causeStr = causes.prefix(2).joined(separator: " och ")
            hypotheses.append(Hypothesis(statement: "\(concept) orsakas primärt av \(causeStr)", plausibility: 0.80))
        }
        if !effects.isEmpty {
            let effectStr = effects.prefix(2).joined(separator: " och ")
            hypotheses.append(Hypothesis(statement: "\(concept) leder till \(effectStr) via kausala mekanismer", plausibility: 0.75))
        }

        // Structural hypothesis
        hypotheses.append(Hypothesis(statement: "\(concept) är ett emergent fenomen som uppstår ur komplexa interaktioner", plausibility: 0.60))

        // Contextual hypothesis
        hypotheses.append(Hypothesis(statement: "\(concept) beror på kontextuella variabler som varierar mellan domäner", plausibility: 0.55))

        // Analogical hypothesis — check if analogies suggest cross-domain links
        let analogies = findAnalogies(for: concept)
        if let first = analogies.first {
            hypotheses.append(Hypothesis(statement: "\(concept) uppvisar liknande mönster som \(first.target) (\(first.inference))", plausibility: first.strength))
        }

        // Null hypothesis
        hypotheses.append(Hypothesis(statement: "Observerade mönster i \(concept) kan förklaras av slumpmässig variation", plausibility: 0.20))

        return Array(hypotheses.sorted { $0.plausibility > $1.plausibility }.prefix(count))
    }

    // v7: Expanded analogy library — 20 domains for richer cross-domain reasoning
    private func findAnalogies(for concept: String) -> [StructuralAnalogy] {
        let library: [String: [StructuralAnalogy]] = [
            "kognition": [
                StructuralAnalogy(source: "kognition", target: "dator", mappings: ["minne↔RAM", "tänkande↔CPU", "inlärning↔programmering"], strength: 0.7, inference: "kognition kan optimeras som mjukvara"),
                StructuralAnalogy(source: "kognition", target: "ekosystem", mappings: ["tankar↔arter", "uppmärksamhet↔resurser", "minne↔näring"], strength: 0.6, inference: "kognitiv mångfald ökar robusthet"),
            ],
            "inlärning": [
                StructuralAnalogy(source: "inlärning", target: "evolution", mappings: ["variation↔hypoteser", "selektion↔feedback", "ärftlighet↔minne"], strength: 0.8, inference: "inlärning är en evolutionär process"),
                StructuralAnalogy(source: "inlärning", target: "trädgård", mappings: ["kunskap↔växter", "studerande↔odling", "glömska↔ogräs"], strength: 0.65, inference: "kunskap kräver kontinuerlig vård"),
            ],
            "språk": [
                StructuralAnalogy(source: "språk", target: "verktyg", mappings: ["grammatik↔regler", "ord↔instrument", "kommunikation↔bygge"], strength: 0.75, inference: "språk är ett verktyg för tankebygge"),
                StructuralAnalogy(source: "språk", target: "flod", mappings: ["dialekter↔biflöden", "förändring↔erosion", "slang↔forsar"], strength: 0.55, inference: "språk flödar och förändras konstant"),
            ],
            "minne": [
                StructuralAnalogy(source: "minne", target: "bibliotek", mappings: ["fakta↔böcker", "sökning↔katalog", "glömska↔damm"], strength: 0.75, inference: "minne organiseras som ett bibliotek med index"),
                StructuralAnalogy(source: "minne", target: "nätverk", mappings: ["associationer↔kopplingar", "hämtning↔sökning"], strength: 0.7, inference: "minne är ett associativt nätverk"),
            ],
            "kreativitet": [
                StructuralAnalogy(source: "kreativitet", target: "mutation", mappings: ["idé↔gen", "inspiration↔mutation", "selektion↔kritik"], strength: 0.7, inference: "kreativitet är kontrollerad variation"),
                StructuralAnalogy(source: "kreativitet", target: "matlagning", mappings: ["idéer↔ingredienser", "kombination↔recept"], strength: 0.6, inference: "kreativitet handlar om nya kombinationer"),
            ],
            "medvetande": [
                StructuralAnalogy(source: "medvetande", target: "teater", mappings: ["tankar↔aktörer", "fokus↔strålkastare", "omedvetet↔kulisser"], strength: 0.7, inference: "medvetande är en scen där tankar uppträder"),
                StructuralAnalogy(source: "medvetande", target: "orkester", mappings: ["moduler↔instrument", "synkronisering↔dirigent", "medvetande↔harmoni"], strength: 0.75, inference: "medvetande emergerar ur synkroniserad mångfald"),
            ],
            "resonemang": [
                StructuralAnalogy(source: "resonemang", target: "navigering", mappings: ["premisser↔karta", "slutsats↔destination", "logik↔kompass"], strength: 0.75, inference: "resonemang navigerar från premisser till slutsatser"),
            ],
            "intelligens": [
                StructuralAnalogy(source: "intelligens", target: "vatten", mappings: ["anpassning↔flöde", "problemlösning↔erosion", "flexibilitet↔form"], strength: 0.6, inference: "intelligens anpassar sig som vatten till terrängen"),
            ],
            "kunskap": [
                StructuralAnalogy(source: "kunskap", target: "karta", mappings: ["fakta↔platser", "kopplingar↔vägar", "luckor↔outforskade områden"], strength: 0.8, inference: "kunskap är en karta som ständigt ritas om"),
            ],
            // v7: New domains
            "emotion": [
                StructuralAnalogy(source: "emotion", target: "väder", mappings: ["humör↔klimat", "affekt↔vind", "temperament↔årstid"], strength: 0.7, inference: "emotioner är inre väder — de passerar men klimatet består"),
                StructuralAnalogy(source: "emotion", target: "kompass", mappings: ["känsla↔riktning", "valens↔polaritet", "arousal↔intensitet"], strength: 0.65, inference: "emotioner ger riktning åt beslut som en inre kompass"),
            ],
            "motivation": [
                StructuralAnalogy(source: "motivation", target: "gravitation", mappings: ["mål↔massa", "attraktion↔drivkraft", "avstånd↔svårighet"], strength: 0.7, inference: "motivation drar oss mot mål som gravitation drar massor"),
                StructuralAnalogy(source: "motivation", target: "eld", mappings: ["passion↔låga", "bränsle↔belöning", "utmattning↔aska"], strength: 0.6, inference: "motivation behöver bränsle för att fortsätta brinna"),
            ],
            "samhälle": [
                StructuralAnalogy(source: "samhälle", target: "organism", mappings: ["institutioner↔organ", "lagar↔DNA", "medborgare↔celler"], strength: 0.75, inference: "samhället fungerar som en superorganism med specialiserade delar"),
            ],
            "evolution": [
                StructuralAnalogy(source: "evolution", target: "algoritm", mappings: ["mutation↔slump", "selektion↔optimering", "fitness↔resultat"], strength: 0.8, inference: "evolution är naturens optimeringsalgoritm"),
            ],
            "tid": [
                StructuralAnalogy(source: "tid", target: "flod", mappings: ["förfluten↔uppströms", "framtid↔nedströms", "nu↔här"], strength: 0.6, inference: "tid flödar oåterkalleligt som en flod"),
                StructuralAnalogy(source: "tid", target: "spiral", mappings: ["repetition↔varv", "utveckling↔stigning", "cykler↔mönster"], strength: 0.65, inference: "tid rör sig i spiraler — cyklisk men aldrig exakt samma"),
            ],
            "frihet": [
                StructuralAnalogy(source: "frihet", target: "rum", mappings: ["val↔rörelse", "begränsning↔vägg", "möjlighet↔riktning"], strength: 0.65, inference: "frihet är handlingsutrymme — att ha fler riktningar att röra sig i"),
            ],
            "kommunikation": [
                StructuralAnalogy(source: "kommunikation", target: "bro", mappings: ["budskap↔last", "förståelse↔anslutning", "missförstånd↔kollaps"], strength: 0.7, inference: "kommunikation bygger broar mellan separata sinnen"),
            ],
            "system": [
                StructuralAnalogy(source: "system", target: "kropp", mappings: ["komponenter↔organ", "flöde↔blod", "feedback↔nervsystem"], strength: 0.75, inference: "system organiserar delar till en fungerande helhet"),
            ],
            "förändring": [
                StructuralAnalogy(source: "förändring", target: "metamorfos", mappings: ["tillstånd↔stadium", "process↔transformation", "resultat↔ny form"], strength: 0.7, inference: "förändring är metamorfos — samma substans i ny form"),
            ],
            "identitet": [
                StructuralAnalogy(source: "identitet", target: "berättelse", mappings: ["upplevelser↔kapitel", "minnen↔teman", "mål↔klimax"], strength: 0.75, inference: "identitet är en narrativ konstruktion — vi berättar oss själva"),
                StructuralAnalogy(source: "identitet", target: "flod", mappings: ["förändring↔flöde", "kontinuitet↔fåra", "utveckling↔delta"], strength: 0.6, inference: "identitet flödar — aldrig exakt samma men alltid sammanhängande"),
            ],
            "etik": [
                StructuralAnalogy(source: "etik", target: "kompass", mappings: ["principer↔poler", "dilemma↔korsväg", "samvete↔nål"], strength: 0.7, inference: "etik ger riktning i moraliska landskap"),
                StructuralAnalogy(source: "etik", target: "ekosystem", mappings: ["rättigheter↔arter", "balans↔biodiversitet", "orättvisa↔utsläpp"], strength: 0.55, inference: "moraliska system behöver balans som ekosystem"),
            ],
            "nyfikenhet": [
                StructuralAnalogy(source: "nyfikenhet", target: "hunger", mappings: ["fråga↔aptit", "svar↔mat", "utforskande↔jakt"], strength: 0.75, inference: "nyfikenhet är intellektuell hunger — den driver oss att söka näring för tanken"),
            ],
            "empati": [
                StructuralAnalogy(source: "empati", target: "spegel", mappings: ["andras känslor↔reflektion", "perspektivtagande↔vinkel", "resonans↔eko"], strength: 0.7, inference: "empati speglar andras inre tillstånd i vår egen upplevelse"),
            ],
            "kausalitet": [
                StructuralAnalogy(source: "kausalitet", target: "dominobrickor", mappings: ["orsak↔knuff", "verkan↔fall", "kedja↔rad"], strength: 0.8, inference: "kausalitet propagerar som dominobrickor — men verkligheten har fler dimensioner"),
                StructuralAnalogy(source: "kausalitet", target: "webbsida", mappings: ["orsaker↔länkar", "effekter↔sidor", "nätverk↔graf"], strength: 0.6, inference: "kausalitet bildar nätverk snarare än enkla kedjor"),
            ],
        ]

        let lower = concept.lowercased()
        // Search for matching analogies across all domains
        var matches: [StructuralAnalogy] = []
        for (key, analogies) in library {
            if lower.contains(key) || key.contains(lower) {
                matches.append(contentsOf: analogies)
            }
        }

        // Also check if concept words overlap with any key
        if matches.isEmpty {
            let conceptWords = Set(lower.components(separatedBy: .whitespaces).filter { $0.count > 3 })
            for (key, analogies) in library {
                if conceptWords.contains(key) { matches.append(contentsOf: analogies) }
            }
        }

        if matches.isEmpty {
            return [StructuralAnalogy(source: concept, target: "system", mappings: ["komponenter↔delar", "funktion↔syfte", "förändring↔utveckling"], strength: 0.4, inference: "\(concept) fungerar som ett system med inbördes beroenden")]
        }

        return Array(matches.prefix(3))
    }

    private func generateCounterfactuals(for fact: String, count: Int) -> [Counterfactual] {
        let concept = extractMainConcept(fact)
        return [
            Counterfactual(condition: "\(concept) inte existerade", consequence: "systemet skulle behöva alternativa mekanismer", probability: 0.7),
            Counterfactual(condition: "\(concept) var dubbelt så starkt", consequence: "effekterna skulle förstärkas exponentiellt", probability: 0.6),
            Counterfactual(condition: "kontexten var annorlunda", consequence: "\(concept) hade haft annan innebörd", probability: 0.65),
        ].prefix(count).map { $0 }
    }

    private func expandThought(_ node: ThoughtNode, branching: Int) -> [ThoughtNode] {
        let concept = extractMainConcept(node.content)
        let causes = causalGraph.findCauses(of: concept)
        let effects = causalGraph.findEffects(of: concept)

        var expansions: [(String, Double)] = []

        // Causal expansion — use actual graph knowledge
        if !causes.isEmpty {
            expansions.append(("\(concept) drivs av \(causes.prefix(2).joined(separator: " och ")) — vilka mekanismer?", 0.92))
        }
        if !effects.isEmpty {
            expansions.append(("Om \(concept) förstärks: effekt på \(effects.prefix(2).joined(separator: ", "))", 0.88))
        }

        // Analogy expansion
        let analogies = findAnalogies(for: concept)
        if let a = analogies.first {
            expansions.append(("Analogi: \(concept) ↔ \(a.target) — \(a.inference)", a.strength))
        }

        // Standard expansions for remaining slots
        expansions.append(("Vad är den djupaste implikationen av \(concept)?", 0.80))
        expansions.append(("Alternativt perspektiv: hur ser \(concept) ut från motsatt ståndpunkt?", 0.75))
        expansions.append(("Kontrafaktiskt: vad om \(concept) inte existerade?", 0.70))

        // Select top branches by score
        let selected = expansions.sorted { $0.1 > $1.1 }.prefix(branching)
        return selected.enumerated().map { _, pair in
            let (content, baseScore) = pair
            return ThoughtNode(content: content, depth: node.depth + 1, score: node.score * baseScore)
        }
    }

    // MARK: - Statistik

    func reasoningStats() -> ReasoningStats {
        let total = reasoningHistory.count
        let byStrategy = Dictionary(grouping: reasoningHistory, by: { $0.strategy })
        let mostUsed = byStrategy.max(by: { $0.value.count < $1.value.count })?.key

        return ReasoningStats(
            totalTraces: total,
            mostUsedStrategy: mostUsed,
            averageDepth: reasoningHistory.isEmpty ? 0 : reasoningHistory.map { Double($0.steps) }.reduce(0, +) / Double(total),
            causalGraphSize: causalGraph.nodeCount
        )
    }
}

// MARK: - Kausalgraf

// CausalGraph är en class (referenstyp) skyddad av NSLock för trådsäkerhet.
// Alla mutationer och läsningar av relations sker under lock.
final class CausalGraph: @unchecked Sendable {
    private var relations: [CausalRelation] = []
    private let lock = NSLock()

    nonisolated init() {}

    nonisolated var nodeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return Set(relations.flatMap { [$0.cause, $0.effect] }).count
    }

    nonisolated func addRelation(cause: String, effect: String, strength: Double) {
        lock.lock()
        defer { lock.unlock() }
        relations.append(CausalRelation(cause: cause, effect: effect, strength: strength))
    }

    nonisolated func findCauses(of concept: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return relations.filter { $0.effect.lowercased() == concept.lowercased() && $0.strength > 0 }.map { $0.cause }
    }

    nonisolated func findEffects(of concept: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return relations.filter { $0.cause.lowercased() == concept.lowercased() && $0.strength > 0 }.map { $0.effect }
    }

    nonisolated func findChain(from concept: String, maxDepth: Int = 4) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var chain = [concept]
        var current = concept
        for _ in 0..<maxDepth {
            guard let next = relations.filter({ $0.cause.lowercased() == current.lowercased() && $0.strength > 0.5 }).max(by: { $0.strength < $1.strength })?.effect else { break }
            if chain.contains(next) { break }
            chain.append(next)
            current = next
        }
        return chain
    }
}

struct CausalRelation {
    let cause: String
    let effect: String
    let strength: Double  // -1..+1 (negativ = hämmar)
}

// MARK: - Data Models

struct ReasoningTrace: Identifiable {
    let id = UUID()
    let input: String
    let strategy: ReasoningStrategy
    let startedAt: Date
    var steps: Int = 0
}

struct ReasoningResult {
    let strategy: ReasoningStrategy
    let steps: [ReasoningStep]
    let conclusion: String
    let confidence: Double
    let alternatives: [String]
    let causalChain: [String]
}

struct ReasoningStep: Identifiable {
    let id = UUID()
    let type: StepType
    let content: String
    let confidence: Double

    enum StepType {
        case premise, inference, observation, pattern, generalization,
             hypothesis, conclusion, causal, counterfactual, analogy,
             insight
    }
}

enum ReasoningStrategy: String {
    case deductive = "Deduktiv"
    case inductive = "Induktiv"
    case abductive = "Abduktiv"
    case analogical = "Analogisk"
    case counterfactual = "Kontrafaktisk"
    case causal = "Kausal"
    case treeOfThought = "Tree-of-Thought"
    case adaptive = "Adaptiv"
}

struct Hypothesis {
    let statement: String
    let plausibility: Double
}

struct StructuralAnalogy {
    let source: String
    let target: String
    let mappings: [String]
    let strength: Double
    let inference: String
}

struct Counterfactual {
    let condition: String
    let consequence: String
    let probability: Double
}

struct ThoughtNode: Identifiable {
    let id = UUID()
    let content: String
    let depth: Int
    let score: Double
}

struct ActiveHypothesis: Identifiable {
    let id = UUID()
    let statement: String
    var confidence: Double
    var evidenceCount: Int = 0
}

struct ReasoningStats {
    let totalTraces: Int
    let mostUsedStrategy: ReasoningStrategy?
    let averageDepth: Double
    let causalGraphSize: Int
}
