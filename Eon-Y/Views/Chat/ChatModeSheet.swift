import SwiftUI

// MARK: - ChatModeSheet

struct ChatModeSheet: View {
    @Binding var isReasoningMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 3)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Svarsläge")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                ModeOption(
                    title: "Normal",
                    subtitle: "Snabba, direkta svar. Använder kognitiv cykel med GPT + BERT.",
                    icon: "bolt.fill",
                    color: Color(hex: "#34D399"),
                    isSelected: !isReasoningMode
                ) {
                    isReasoningMode = false
                    dismiss()
                }

                ModeOption(
                    title: "Resonerande",
                    subtitle: "Djupt tänkande upp till 5 min. Läser kunskapsbanken, drar paralleller, ger genomtänkta svar.",
                    icon: "brain.head.profile",
                    color: Color(hex: "#F472B6"),
                    isSelected: isReasoningMode
                ) {
                    isReasoningMode = true
                    dismiss()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - ModeOption

struct ModeOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isSelected ? 0.2 : 0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color.opacity(isSelected ? 1.0 : 0.45))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                        if isSelected {
                            Text("AKTIV")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(color)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(color.opacity(0.15)))
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isSelected ? 0.06 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? color.opacity(0.45) : Color.white.opacity(0.07), lineWidth: 0.8)
                    )
            )
        }
    }
}
