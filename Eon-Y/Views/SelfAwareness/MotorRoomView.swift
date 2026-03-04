import SwiftUI

// MARK: - MotorRoomView — Eons motorrum
// Shows real-time motor speeds, temperatures, Eon's decisions and reasoning.
// Only accessible when Eon-läge is active.

struct MotorRoomView: View {
    @ObservedObject private var motorController = EonMotorController.shared
    @ObservedObject private var consciousness = ConsciousnessEngine.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLogSheet = false
    @State private var pulsePhase: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                RadialGradient(
                    colors: [Color(hex: "#1A0A35").opacity(0.4), Color.clear],
                    center: .init(x: 0.5, y: 0.0), startRadius: 0, endRadius: 500
                ).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Mood Card
                        moodCard

                        // Body Status
                        bodyStatusCard

                        // Motor Grid
                        motorGridCard

                        // Recent Decisions
                        recentDecisionsCard

                        // Log Button
                        logButton

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Motorrummet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(Color(hex: "#EC4899"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLogSheet) {
                MotorLogSheet()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1.06
            }
        }
    }

    // MARK: - Mood Card

    var moodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(moodColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulsePhase)
                    Image(systemName: moodIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(moodColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("EONS TILLSTÅND")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(1)
                    Text(motorController.currentMood)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if motorController.safetyOverrideActive {
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "#EF4444"))
                        Text("SÄKERHET")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                }
            }

            if !motorController.lastDecisionSummary.isEmpty {
                Text(motorController.lastDecisionSummary)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(cardBg(moodColor))
    }

    // MARK: - Body Status Card

    var bodyStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 11)).foregroundStyle(Color(hex: "#06B6D4"))
                Text("KROPPSSTATUS")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }

            HStack(spacing: 0) {
                bodyStatItem("Termisk", consciousness.bodyBudget.thermalState,
                            thermalColor, consciousness.bodyBudget.thermalLevel)
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                bodyStatItem("Valens", String(format: "%+.2f", consciousness.bodyBudget.valence),
                            consciousness.bodyBudget.valence >= 0 ? Color(hex: "#34D399") : Color(hex: "#EF4444"),
                            abs(consciousness.bodyBudget.valence))
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                bodyStatItem("Arousal", String(format: "%.0f%%", consciousness.bodyBudget.arousal * 100),
                            Color(hex: "#F59E0B"), consciousness.bodyBudget.arousal)
                Divider().background(Color.white.opacity(0.08)).frame(height: 40)
                bodyStatItem("Parasym.", consciousness.bodyBudget.parasympatheticLevel.label,
                            Color(hex: consciousness.bodyBudget.parasympatheticLevel.color),
                            Double(consciousness.bodyBudget.parasympatheticLevel.rawValue) / 3.0)
            }
        }
        .padding(16)
        .background(cardBg(Color(hex: "#06B6D4")))
    }

    // MARK: - Motor Grid Card

    var motorGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "engine.combustion.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#EC4899"))
                Text("AKTIVA MOTORER")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                let avgSpeed = motorController.motors.map(\.speed).reduce(0, +) / max(1, Double(motorController.motors.count))
                Text("Snitt: \(Int(avgSpeed * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "#EC4899").opacity(0.6))
            }

            ForEach(motorController.motors) { motor in
                motorRow(motor)
            }
        }
        .padding(16)
        .background(cardBg(Color(hex: "#EC4899")))
    }

    // MARK: - Recent Decisions Card

    var recentDecisionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "brain").font(.system(size: 11)).foregroundStyle(Color(hex: "#A78BFA"))
                Text("SENASTE BESLUT")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
                Spacer()
                Text("\(motorController.decisionLog.count) totalt")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }

            if motorController.decisionLog.isEmpty {
                Text("Inga beslut ännu. Eon observerar sin kropp...")
                    .font(.system(size: 12, design: .rounded).italic())
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 8)
            } else {
                ForEach(motorController.decisionLog.suffix(8).reversed()) { decision in
                    decisionRow(decision)
                }
            }
        }
        .padding(16)
        .background(cardBg(Color(hex: "#A78BFA")))
    }

    // MARK: - Log Button

    var logButton: some View {
        Button {
            showLogSheet = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F59E0B").opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beslutslogg")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Visa och kopiera alla beslut")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#F59E0B").opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 0.6))
            )
        }
    }

    // MARK: - Motor Row

    func motorRow(_ motor: MotorState) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: motor.importance.color))
                    .frame(width: 6, height: 6)
                Text(motor.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(motor.speed * 100))%")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(motorSpeedColor(motor.speed))
                Text(motor.importance.label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: motor.importance.color).opacity(0.6))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: motor.importance.color).opacity(0.1)))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule().fill(Color.white.opacity(0.05))
                    // Min marker
                    Rectangle()
                        .fill(Color(hex: "#EF4444").opacity(0.3))
                        .frame(width: 1)
                        .offset(x: geo.size.width * motor.minSpeed / 1.5)
                    // Max marker
                    Rectangle()
                        .fill(Color(hex: "#34D399").opacity(0.3))
                        .frame(width: 1)
                        .offset(x: geo.size.width * motor.maxSpeed / 1.5)
                    // Current speed
                    Capsule()
                        .fill(LinearGradient(
                            colors: [motorSpeedColor(motor.speed).opacity(0.5), motorSpeedColor(motor.speed)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * motor.speed / 1.5)
                        .animation(.easeInOut(duration: 0.8), value: motor.speed)
                }
            }
            .frame(height: 5)

            Text(motor.description)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Decision Row

    func decisionRow(_ decision: MotorDecision) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 2) {
                Circle()
                    .fill(decision.newSpeed > decision.oldSpeed ? Color(hex: "#34D399") : Color(hex: "#F59E0B"))
                    .frame(width: 6, height: 6)
                    .padding(.top, 4)
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
            }
            .frame(width: 6)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(decision.motorName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(Int(decision.oldSpeed * 100))% → \(Int(decision.newSpeed * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(decision.newSpeed > decision.oldSpeed ? Color(hex: "#34D399") : Color(hex: "#F59E0B"))
                    Spacer()
                    Text(decision.timestamp.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }
                Text(decision.reason)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Helpers

    func bodyStatItem(_ label: String, _ value: String, _ color: Color, _ level: Double) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    func cardBg(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.2), lineWidth: 0.6))
    }

    func motorSpeedColor(_ speed: Double) -> Color {
        if speed >= 1.2 { return Color(hex: "#34D399") }      // Boosted — green
        if speed >= 0.8 { return Color(hex: "#38BDF8") }      // Normal — blue
        if speed >= 0.5 { return Color(hex: "#F59E0B") }      // Reduced — amber
        return Color(hex: "#EF4444")                            // Low — red
    }

    var thermalColor: Color {
        switch consciousness.bodyBudget.thermalState {
        case "Nominal": return Color(hex: "#34D399")
        case "Förhöjd": return Color(hex: "#F59E0B")
        case "Allvarlig": return Color(hex: "#EF4444")
        case "Kritisk": return Color(hex: "#EF4444")
        default: return Color(hex: "#38BDF8")
        }
    }

    var moodColor: Color {
        let valence = consciousness.bodyBudget.valence
        if motorController.safetyOverrideActive { return Color(hex: "#EF4444") }
        if valence > 0.1 { return Color(hex: "#34D399") }
        if valence > -0.2 { return Color(hex: "#38BDF8") }
        if valence > -0.4 { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    var moodIcon: String {
        if motorController.safetyOverrideActive { return "exclamationmark.shield.fill" }
        let valence = consciousness.bodyBudget.valence
        if valence > 0.1 { return "bolt.fill" }
        if valence > -0.2 { return "brain.head.profile" }
        if valence > -0.4 { return "moon.fill" }
        return "bed.double.fill"
    }
}

// MARK: - Motor Log Sheet

struct MotorLogSheet: View {
    @ObservedObject private var motorController = EonMotorController.shared
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Copy button
                        Button {
                            UIPasteboard.general.string = motorController.exportableLog
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 14))
                                Text(copied ? "Kopierad!" : "Kopiera hela loggen")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(copied ? Color(hex: "#34D399") : Color(hex: "#EC4899"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(copied ? Color(hex: "#34D399").opacity(0.1) : Color(hex: "#EC4899").opacity(0.1))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(copied ? Color(hex: "#34D399").opacity(0.3) : Color(hex: "#EC4899").opacity(0.3), lineWidth: 0.6))
                            )
                        }
                        .padding(.bottom, 8)

                        // Log content
                        Text(motorController.exportableLog)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Beslutslogg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EonPreviewContainer { MotorRoomView() }
}
