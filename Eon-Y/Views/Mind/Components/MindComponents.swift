import SwiftUI

// MARK: - Phi Gauge Mini

struct PhiGaugeMini: View {
    let phi: Double
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: min(phi, 1.0) * 0.75)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "#34D399"), Color(hex: "#7C3AED")], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 1.0), value: phi)
                Text("Φ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }
            Text(String(format: "%.2f", phi))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Step State Label Extension

extension StepState {
    var label: String {
        switch self {
        case .pending:   return "Väntar"
        case .active:    return "Aktiv"
        case .completed: return "Klar"
        case .triggered: return "Loop"
        case .failed:    return "Fel"
        }
    }
}

// MARK: - Thinking Step Pillar Description

extension ThinkingStep {
    var pillarDescription: String {
        switch self {
        case .morphology:      return "Analyserar morfologi, lemmatisering och ordformer i inmatningen via SwedishLanguageCore."
        case .wsd:             return "Word Sense Disambiguation — disambiguerar flertydiga ord baserat på kontext."
        case .memoryRetrieval: return "Söker i SQLite-minnet efter relevanta konversationer och hämtar senaste historiken."
        case .causalGraph:     return "Beräknar KB-BERT 768-dim embedding och extraherar namngivna entiteter."
        case .globalWorkspace: return "Global Workspace Theory — bygger den fullständiga prompten med all kognitiv kontext."
        case .chainOfThought:  return "Chain-of-Thought reasoning — loggar tankekedjan i inner monologue."
        case .generation:      return "GPT-SW3 1.3B genererar svar via CoreML/Apple Foundation Models/NL-fallback."
        case .validation:      return "Loop 1 — BERT cosine similarity validerar koherens. WSD-mismatch triggar regenerering."
        case .enrichment:      return "Loop 2 — Extraherade entiteter och fakta sparas tillbaka till kunskapsgrafen."
        case .metacognition:   return "Loop 3 — Om konfidens < 60% revideras svaret av MetacognitiveReviser."
        case .idle:            return "Systemet är i viloläge."
        }
    }
}
