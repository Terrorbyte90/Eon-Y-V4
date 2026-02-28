import SwiftUI
import Combine

// MARK: - ChatView

struct ChatView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var viewModel = ChatViewModel()
    @State private var showMindSheet = false
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#07050F").ignoresSafeArea()
            // Subtle background gradient
            LinearGradient(
                colors: [Color(hex: "#0D0820"), Color(hex: "#07050F")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                messageList
            }

            inputBar
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showMindSheet) {
            MindView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .task { await brain.neuralEngine.loadModels() }
    }

    // MARK: - Header

    var chatHeader: some View {
        HStack(spacing: 12) {
            // Eon avatar orb — mer detaljerad
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [EonColor.forEmotion(brain.currentEmotion).opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: 26
                    ))
                    .frame(width: 52, height: 52)
                    .blur(radius: 8)
                Circle()
                    .strokeBorder(EonColor.forEmotion(brain.currentEmotion).opacity(0.3), lineWidth: 0.8)
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(RadialGradient(
                        colors: [EonColor.forEmotion(brain.currentEmotion).opacity(0.9), EonColor.violet.opacity(0.7), Color(hex: "#1E0B3A")],
                        center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 18
                    ))
                    .frame(width: 38, height: 38)
                    .shadow(color: EonColor.forEmotion(brain.currentEmotion).opacity(0.5), radius: 8)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Eon")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("II \(String(format: "%.2f", brain.integratedIntelligence))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#7C3AED").opacity(0.15)).overlay(Capsule().strokeBorder(Color(hex: "#7C3AED").opacity(0.3), lineWidth: 0.4)))
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(brain.isThinking ? EonColor.gold : EonColor.teal)
                        .frame(width: 5, height: 5)
                        .pulseAnimation(min: 0.5, max: 1.5, duration: 0.7)
                    Text(brain.isThinking ? brain.currentThinkingStep.label : brain.autonomousProcessLabel)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(brain.isThinking ? EonColor.gold : EonColor.violet.opacity(0.8))
                        .animation(.easeInOut, value: brain.isThinking)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Model indicator
            HStack(spacing: 5) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                Text("GPT-SW3")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Color.white.opacity(0.3))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.05)))

            Button { showMindSheet = true } label: {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(EonColor.violet)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(EonColor.violet.opacity(0.12)).overlay(Circle().strokeBorder(EonColor.violet.opacity(0.25), lineWidth: 0.6)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "#07050F").opacity(0.5))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    // Date separator
                    Text("Idag")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.vertical, 12)

                    ForEach(viewModel.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                    }

                    if brain.isThinking {
                        ThinkingPanel(steps: brain.thinkingSteps)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .onTapGesture { showMindSheet = true }
                    }

                    Color.clear.frame(height: 80).id("bottom")
                }
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: brain.isThinking) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: - Input Bar

    var inputBar: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text("Skriv till Eon...")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white.opacity(0.28))
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
                TextField("", text: $inputText, axis: .vertical)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focused($inputFocused)
                    .onSubmit { sendMessage() }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(inputFocused ? EonColor.violet.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 0.8))
            )
            .animation(.easeInOut(duration: 0.2), value: inputFocused)

            Button(action: sendMessage) {
                ZStack {
                    Circle()
                        .fill(brain.isThinking
                            ? AnyShapeStyle(EonColor.violet.opacity(0.3))
                            : AnyShapeStyle(LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: 44, height: 44)
                        .shadow(color: EonColor.violet.opacity(brain.isThinking ? 0 : 0.5), radius: 10)
                    if brain.isThinking {
                        ProgressView().tint(.white).scaleEffect(0.65)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || brain.isThinking)
            .animation(.spring(response: 0.3), value: brain.isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: "#07050F").opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.5), radius: 20, y: -4)
        )
        .padding(.horizontal, 12)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !brain.isThinking else { return }
        inputText = ""
        inputFocused = false
        viewModel.addUserMessage(text)
        Task { await viewModel.sendToBrain(text, brain: brain) }
    }
}

// MARK: - ChatViewModel

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []

    init() {
        messages.append(ChatMessage(
            role: .eon,
            content: "Hej! Jag är Eon — ett kognitivt AI-system som körs helt on-device via Apple Neural Engine. Jag tänker, resonerar och lär mig. Vad vill du utforska idag?",
            confidence: 0.95,
            emotion: .neutral
        ))
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
    }

    func sendToBrain(_ text: String, brain: EonBrain) async {
        var eonMessage = ChatMessage(role: .eon, content: "", confidence: 0, emotion: brain.currentEmotion)
        messages.append(eonMessage)
        let idx = messages.count - 1
        let stream = await brain.think(userMessage: text)
        for await token in stream {
            messages[idx].content += token
        }
        messages[idx].confidence = brain.confidence
        messages[idx].retrievedMemoryCount = brain.thinkingSteps
            .filter { $0.step == .memoryRetrieval && $0.state == .completed }.count > 0
            ? Int.random(in: 1...3) : 0
    }
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var confidence: Double = 0.75
    var emotion: EonEmotion = .neutral
    var disambiguations: [String] = []
    var retrievedMemoryCount: Int = 0
    let timestamp = Date()

    enum Role { case user, eon }
    var isUser: Bool { role == .user }
}

// MARK: - ChatBubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                eonAvatar
                VStack(alignment: .leading, spacing: 5) {
                    if message.retrievedMemoryCount > 0 {
                        MemoryRecallBadge(count: message.retrievedMemoryCount)
                    }
                    eonBubble
                    if message.confidence > 0 {
                        ConfidenceIndicator(confidence: message.confidence)
                            .padding(.leading, 4)
                    }
                }
                Spacer(minLength: 60)
            }
        }
    }

    var eonAvatar: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [EonColor.forEmotion(message.emotion).opacity(0.85), EonColor.violet.opacity(0.6), Color(hex: "#1E0B3A")],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14
                ))
                .frame(width: 28, height: 28)
                .shadow(color: EonColor.violet.opacity(0.4), radius: 6)
            Text("E")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .alignmentGuide(.bottom) { d in d[.bottom] }
    }

    var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content.isEmpty ? "..." : message.content)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(hex: "#6D28D9"), Color(hex: "#4C1D95")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color(hex: "#7C3AED").opacity(0.4), lineWidth: 0.6))
                )
                .shadow(color: EonColor.violet.opacity(0.25), radius: 8, y: 2)
            Text(timeString(message.timestamp))
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    var eonBubble: some View {
        Text(message.content.isEmpty ? "..." : message.content)
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.03)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(colors: [EonColor.violet.opacity(0.3), EonColor.teal.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 0.7
                        ))
            )
            .shadow(color: EonColor.violet.opacity(0.08), radius: 8, y: 2)
    }

    func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - ThinkingPanel

struct ThinkingPanel: View {
    let steps: [ThinkingStepStatus]
    @State private var expanded = false

    var activeStep: ThinkingStepStatus? { steps.first { $0.state == .active } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(EonColor.violet)
                        .frame(width: 7, height: 7)
                        .pulseAnimation(min: 0.5, max: 1.5, duration: 0.75)
                    Text(activeStep.map { "\($0.step.label)..." } ?? "Bearbetar...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(activeStep?.step.pillarColor ?? EonColor.violet)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            // Progress dots
            HStack(spacing: 4) {
                ForEach(steps.filter { $0.step != .idle }) { step in
                    Capsule()
                        .fill(step.state.color)
                        .frame(width: step.state == .active ? 20 : 6, height: 4)
                        .opacity(step.state == .pending ? 0.2 : 1.0)
                        .animation(.spring(response: 0.3), value: step.state)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(steps.filter { $0.step != .idle && $0.state != .pending }) { step in
                        HStack(spacing: 8) {
                            Image(systemName: step.step.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(step.step.pillarColor)
                                .frame(width: 14)
                            Text(step.step.label)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(step.state.color)
                            Spacer()
                            if step.state == .triggered {
                                Text("LOOP")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(EonColor.orange)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(EonColor.orange.opacity(0.15)))
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.square").font(.system(size: 10))
                Text("Tryck för att följa resonemanget live").font(.system(size: 10, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.25))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(EonColor.violet.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(EonColor.violet.opacity(0.2), lineWidth: 0.6))
        )
        .shadow(color: EonColor.violet.opacity(0.12), radius: 12)
    }
}

// MARK: - ConfidenceIndicator

struct ConfidenceIndicator: View {
    let confidence: Double
    var barColor: Color {
        confidence > 0.75 ? EonColor.teal : confidence > 0.5 ? EonColor.gold : EonColor.orange
    }
    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [EonColor.violet, barColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(width: 52, height: 3)
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - MemoryRecallBadge

struct MemoryRecallBadge: View {
    let count: Int
    @State private var glowing = false
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .semibold))
            Text("\(count) minnen hämtade").font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundStyle(EonColor.gold)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(EonColor.gold.opacity(0.1)).overlay(Capsule().strokeBorder(EonColor.gold.opacity(glowing ? 0.5 : 0.2), lineWidth: 0.5)))
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glowing = true } }
    }
}

// MARK: - EmotionalMiniOrb

struct EmotionalMiniOrb: View {
    let emotion: EonEmotion
    let arousal: Double
    @State private var scale: CGFloat = 1.0
    var orbColor: Color { EonColor.forEmotion(emotion) }
    var body: some View {
        ZStack {
            Circle().fill(orbColor.opacity(0.18)).frame(width: 38, height: 38).blur(radius: 5)
            Circle()
                .fill(RadialGradient(colors: [orbColor, orbColor.opacity(0.45)], center: .center, startRadius: 0, endRadius: 14))
                .frame(width: 28, height: 28)
                .scaleEffect(scale)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: orbColor.opacity(0.4), radius: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2 + (1.0 - arousal) * 1.6).repeatForever(autoreverses: true)) {
                scale = 1.0 + CGFloat(arousal) * 0.18
            }
        }
    }
}

// MARK: - Particle Background

struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = (0..<25).map { _ in Particle() }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { _ in
            Canvas { ctx, size in
                for p in particles {
                    let rect = CGRect(x: p.x * size.width - 1, y: p.y * size.height - 1, width: 2, height: 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(EonColor.violet.opacity(p.opacity)))
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                for i in particles.indices {
                    particles[i].y -= particles[i].speed
                    if particles[i].y < 0 { particles[i] = Particle() }
                }
            }
        }
    }
}

struct Particle {
    var x: Double = Double.random(in: 0...1)
    var y: Double = Double.random(in: 0...1)
    var speed: Double = Double.random(in: 0.001...0.003)
    var opacity: Double = Double.random(in: 0.08...0.35)
}

struct EmotionDetailPopover: View {
    let emotion: EonEmotion; let arousal: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eons emotionella tillstånd").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            HStack {
                Text("Emotion:").foregroundStyle(.white.opacity(0.55))
                Text(emotion.rawValue.capitalized).foregroundStyle(EonColor.forEmotion(emotion)).fontWeight(.semibold)
            }.font(.system(size: 13, design: .rounded))
        }
        .padding(16)
        .background(Color(hex: "#0F0B1E"))
        .presentationCompactAdaptation(.popover)
    }
}

#Preview("Chatt") {
    EonPreviewContainer { ChatView() }
}
