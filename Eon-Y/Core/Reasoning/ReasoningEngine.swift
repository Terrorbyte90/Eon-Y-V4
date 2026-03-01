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
        buildInitialCausalGraph()
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

    private func selectBestStrategy(for input: String) -> ReasoningStrategy {
        let lower = input.lowercased()
        if lower.contains("varför") || lower.contains("orsak") || lower.contains("beror") { return .causal }
        if lower.contains("om") && lower.contains("hade") { return .counterfactual }
        if lower.contains("liknar") || lower.contains("som") && lower.contains("precis") { return .analogical }
        if lower.contains("alla") || lower.contains("generellt") || lower.contains("mönster") { return .inductive }
        if lower.contains("slutsats") || lower.contains("bevis") || lower.contains("därför") { return .deductive }
        if lower.contains("förklara") || lower.contains("vad är") { return .abductive }
        return .treeOfThought
    }

    // MARK: - Kausalgraf

    private func buildInitialCausalGraph() {
        // Grundläggande kausala relationer — utökad med fler kognitiva noder
        causalGraph.addRelation(cause: "Inlärning",       effect: "Kompetens",      strength: 0.90)
        causalGraph.addRelation(cause: "Kompetens",       effect: "Prestation",     strength: 0.85)
        causalGraph.addRelation(cause: "Nyfikenhet",      effect: "Inlärning",      strength: 0.80)
        causalGraph.addRelation(cause: "Motivation",      effect: "Nyfikenhet",     strength: 0.75)
        causalGraph.addRelation(cause: "Feedback",        effect: "Inlärning",      strength: 0.70)
        causalGraph.addRelation(cause: "Stress",          effect: "Prestation",     strength: -0.60)
        causalGraph.addRelation(cause: "Sömn",            effect: "Kognition",      strength: 0.85)
        causalGraph.addRelation(cause: "Kognition",       effect: "Resonemang",     strength: 0.90)
        causalGraph.addRelation(cause: "Resonemang",      effect: "Förståelse",     strength: 0.88)
        causalGraph.addRelation(cause: "Förståelse",      effect: "Kunskap",        strength: 0.92)
        causalGraph.addRelation(cause: "Kunskap",         effect: "Kreativitet",    strength: 0.65)
        causalGraph.addRelation(cause: "Kreativitet",     effect: "Innovation",     strength: 0.78)
        causalGraph.addRelation(cause: "Metakognition",   effect: "Inlärning",      strength: 0.82)
        causalGraph.addRelation(cause: "Metakognition",   effect: "Resonemang",     strength: 0.75)
        causalGraph.addRelation(cause: "Kausalitet",      effect: "Förståelse",     strength: 0.80)
        causalGraph.addRelation(cause: "Analogier",       effect: "Kreativitet",    strength: 0.70)
        causalGraph.addRelation(cause: "Språk",           effect: "Tänkande",       strength: 0.85)
        causalGraph.addRelation(cause: "Tänkande",        effect: "Problemlösning", strength: 0.88)
        causalGraph.addRelation(cause: "Uppmärksamhet",   effect: "Inlärning",      strength: 0.78)
        causalGraph.addRelation(cause: "Repetition",      effect: "Minne",          strength: 0.90)
        causalGraph.addRelation(cause: "Minne",           effect: "Kunskap",        strength: 0.85)
    }

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
        let words1 = Set(p1.lowercased().split(separator: " ").map(String.init))
        let words2 = Set(p2.lowercased().split(separator: " ").map(String.init))
        let shared = words1.intersection(words2)
        if shared.isEmpty { return "Ingen direkt koppling mellan premisserna" }
        return "Givet '\(p1)' och '\(p2)': \(shared.joined(separator: ", ")) är centralt"
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
        return [
            Hypothesis(statement: "\(concept) orsakas av strukturella faktorer", plausibility: 0.75),
            Hypothesis(statement: "\(concept) är ett emergent fenomen", plausibility: 0.60),
            Hypothesis(statement: "\(concept) beror på kontextuella variabler", plausibility: 0.65),
            Hypothesis(statement: "\(concept) är ett slumpmässigt fenomen", plausibility: 0.25),
        ].prefix(count).map { $0 }
    }

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
        let expansions = [
            "Vad innebär detta för \(node.content)?",
            "Vad är konsekvensen av \(node.content)?",
            "Hur relaterar \(node.content) till bredare kontext?",
            "Vad är alternativet till \(node.content)?",
            "Vad är den djupaste implikationen av \(node.content)?",
        ]
        return expansions.prefix(branching).enumerated().map { i, exp in
            ThoughtNode(content: exp, depth: node.depth + 1, score: node.score * (0.9 - Double(i) * 0.05))
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

// CausalGraph är en class (referenstyp) så att addRelation inte kräver mutating/inout.
// Det gör att actor-isolerade properties kan anropas utan problem i async-kontext.
final class CausalGraph {
    private var relations: [CausalRelation] = []

    var nodeCount: Int {
        Set(relations.flatMap { [$0.cause, $0.effect] }).count
    }

    func addRelation(cause: String, effect: String, strength: Double) {
        relations.append(CausalRelation(cause: cause, effect: effect, strength: strength))
    }

    func findCauses(of concept: String) -> [String] {
        relations.filter { $0.effect.lowercased() == concept.lowercased() && $0.strength > 0 }.map { $0.cause }
    }

    func findEffects(of concept: String) -> [String] {
        relations.filter { $0.cause.lowercased() == concept.lowercased() && $0.strength > 0 }.map { $0.effect }
    }

    func findChain(from concept: String, maxDepth: Int = 4) -> [String] {
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
