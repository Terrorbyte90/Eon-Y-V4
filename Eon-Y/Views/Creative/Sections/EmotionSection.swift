import SwiftUI

// MARK: - Emotion Section

struct EmotionSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain

    var body: some View {
        VStack(spacing: 14) {
            // Current emotional state
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(EonColor.crimson)
                    Text("Emotionellt tillstånd")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }

                // VAD model visualization (Valence-Arousal-Dominance)
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(EonColor.forEmotion(engine.emotionalState.primary).opacity(0.2))
                                .frame(width: 70, height: 70)
                            Circle()
                                .fill(EonColor.forEmotion(engine.emotionalState.primary).opacity(0.4))
                                .frame(width: 50, height: 50)
                                .pulseAnimation(min: 0.9, max: 1.1, duration: 2.0)
                            Text(engine.emotionalState.primary.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("Primär")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        emotionBar(label: "Valens", value: (engine.emotionalState.valence + 1) / 2, color: EonColor.teal)
                        emotionBar(label: "Arousal", value: engine.emotionalState.arousal, color: EonColor.orange)
                        emotionBar(label: "Dominans", value: engine.emotionalState.dominance, color: EonColor.violet)
                        emotionBar(label: "Intensitet", value: engine.emotionalState.intensity, color: EonColor.crimson)
                    }
                }

                // Inner narrative
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inre narrativ")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text(engine.emotionalState.innerNarrative)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .italic()
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
            .padding(14)
            .glassMorphism(tint: EonColor.crimson)

            // Emotion history
            if !engine.emotionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Känslohistorik")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))

                    // Mini timeline
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(engine.emotionHistory.suffix(30)) { snapshot in
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(EonColor.forEmotion(snapshot.emotion))
                                        .frame(width: 8 + CGFloat(snapshot.intensity) * 8, height: 8 + CGFloat(snapshot.intensity) * 8)
                                    Text(snapshot.emotion.label.prefix(3))
                                        .font(.system(size: 7, design: .rounded))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                                .frame(width: 22)
                            }
                        }
                    }

                    // All emotions listed
                    ForEach(EonEmotion.allCases, id: \.self) { emotion in
                        let count = engine.emotionHistory.filter { $0.emotion == emotion }.count
                        if count > 0 {
                            HStack {
                                Circle()
                                    .fill(EonColor.forEmotion(emotion))
                                    .frame(width: 8, height: 8)
                                Text(emotion.label)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Spacer()
                                Text("\(count) gånger")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                        }
                    }
                }
                .padding(14)
                .glassMorphism(tint: EonColor.violet)
            }
        }
    }

    private func emotionBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 55, alignment: .leading)
            ProgressView(value: value)
                .tint(color)
            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 26)
        }
    }
}
