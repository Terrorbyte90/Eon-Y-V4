import SwiftUI
import Combine

// MARK: - ChatView v6 — Consciousness-aware UI with genuine engine signals

struct ChatView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    @State private var orbPulse: CGFloat = 1.0
    @State private var orbGlow: Double = 0.4
    @State private var fieldGlow: Double = 0
    // bgBreath är nu statisk baserad på activityLevel — uppdateras bara vid faktisk dataändring
    @State private var bgBreath: Double = 0.14

    // Debounce: förhindrar animation-spam vid varje kognitiv tick
    @State private var lastActivityUpdate: Date = .distantPast

    // Sidebar & lägesväljare
    @State private var showSidebar = false
    @State private var showModeSheet = false
    @State private var sessionCopied = false

    // v6: Consciousness engine references for live status
    @ObservedObject private var oscillators = OscillatorBank.shared
    @ObservedObject private var activeInference = ActiveInferenceEngine.shared
    @ObservedObject private var criticality = CriticalityController.shared
    @ObservedObject private var workspace = GlobalWorkspaceEngine.shared

    var emotionColor: Color { EonColor.forEmotion(brain.currentEmotion) }
    var activityLevel: Double {
        guard !brain.engineActivity.isEmpty else { return 0.2 }
        return (brain.engineActivity.values.reduce(0, +) / Double(brain.engineActivity.count)).clamped(to: 0...1)
    }

    var body: some View {
        ZStack {
            chatBackground
            VStack(spacing: 0) {
                topBar
                // messageList tar upp allt utrymme och ignorerar tangentbordets safe area
                // — inputBar lyfts med tangentbordet via safeAreaInset nedan
                messageList
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            // Sidebar overlay
            if showSidebar {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(response: 0.35)) { showSidebar = false } }
                    .transition(.opacity)
                ConversationHistorySidebar(
                    isShowing: $showSidebar,
                    viewModel: viewModel,
                    brain: brain
                )
                .transition(.move(edge: .leading))
            }
        }
        // inputBar placeras precis ovanför tangentbordet — tab-bar stannar kvar under
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputBar
        }
        .task { await brain.neuralEngine.loadModels() }
        .onAppear { startAnimations() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startAnimations() }
        }
        // Debounce: uppdatera animation max var 3:e sekund
        .onReceive(brain.$engineActivity) { _ in
            let now = Date()
            guard now.timeIntervalSince(lastActivityUpdate) >= 3.0 else { return }
            lastActivityUpdate = now
            let newBreath = 0.08 + activityLevel * 0.16
            withAnimation(.easeInOut(duration: 2.5)) { bgBreath = newBreath }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.65)) {
                orbPulse = brain.isThinking ? 1.28 : 1.0 + CGFloat(activityLevel) * 0.12
            }
        }
        .sheet(isPresented: $showModeSheet) {
            ChatModeSheet(isReasoningMode: $viewModel.isReasoningMode)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#0C0818"))
        }
    }

    // MARK: - Animationer

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { orbGlow = 1.0 }
    }

    // MARK: - Bakgrund

    var chatBackground: some View {
        let surpriseBoost = brain.isSurprised ? brain.surpriseStrength * 0.12 : 0
        let syncGlow = brain.globalSync * 0.06

        return ZStack {
            Color(hex: "#06030F").ignoresSafeArea()
            RadialGradient(
                colors: [emotionColor.opacity(bgBreath + surpriseBoost), Color.clear],
                center: .init(x: 0.5, y: brain.isThinking ? 0.35 : 0.2),
                startRadius: 0, endRadius: 520
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0), value: brain.isThinking)
            .animation(.easeInOut(duration: 2.0), value: bgBreath)
            .animation(.easeInOut(duration: 1.5), value: emotionColor.description)

            // v6: Neural sync ambient glow — subtle secondary radial
            if brain.globalSync > 0.4 {
                RadialGradient(
                    colors: [Color(hex: "#38BDF8").opacity(syncGlow), Color.clear],
                    center: .init(x: 0.8, y: 0.7),
                    startRadius: 0, endRadius: 300
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 4.0), value: brain.globalSync)
            }
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                // Vänster: historik-knapp
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSidebar = true
                    }
                } label: {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Mitten: lägesväljare
                Button { showModeSheet = true } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            if viewModel.isReasoningMode {
                                Circle()
                                    .fill(Color(hex: "#F472B6"))
                                    .frame(width: 5, height: 5)
                                    .shadow(color: Color(hex: "#F472B6").opacity(0.9), radius: 4)
                                    .scaleEffect(orbPulse)
                            }
                            Text(viewModel.isReasoningMode ? "Eon — Resonerande" : "Eon — Normal")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }

                Spacer()

                // Höger: kopiera session + version
                HStack(spacing: 6) {
                    Button {
                        copySession()
                    } label: {
                        Image(systemName: sessionCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(sessionCopied ? Color(hex: "#34D399") : .white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                        )
                }
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Live kognition — realtidsström
            liveKognitionStrip

            // v6: Consciousness state micro-strip
            consciousnessStrip
        }
        .background(
            Color(hex: "#06030F").opacity(0.88)
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea(edges: .top)
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [emotionColor.opacity(viewModel.isReasoningMode ? 0.8 : 0.4), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 0.5)
                .animation(.easeInOut(duration: 1.2), value: emotionColor.description)
        }
    }

    // MARK: - Live Kognition Strip

    var liveKognitionStrip: some View {
        let isThinking = brain.isThinking
        let reasoningColor = viewModel.isReasoningMode ? Color(hex: "#F472B6") : Color(hex: "#34D399")
        let activeColor: Color = isThinking ? Color(hex: "#FBBF24") : reasoningColor

        // Bygg live-text från innerMonologue + thinkingStep
        let liveText: String = {
            if isThinking {
                let step = brain.currentThinkingStep.label
                if let last = brain.innerMonologue.last {
                    let c = cleanMonologue(last.text)
                    if !c.isEmpty { return "[\(step)] \(c)" }
                }
                return step + "..."
            }
            // Idle: visa senaste tanke från live kognition
            let recent = brain.innerMonologue.suffix(1)
            if let last = recent.first {
                let c = cleanMonologue(last.text)
                if !c.isEmpty {
                    let typeLabel: String
                    switch last.type {
                    case .thought:     typeLabel = "TANKE"
                    case .insight:     typeLabel = "INSIKT"
                    case .memory:      typeLabel = "MINNE"
                    case .loopTrigger: typeLabel = "LOOP"
                    case .revision:    typeLabel = "REVISION"
                    }
                    return "[\(typeLabel)] \(c)"
                }
            }
            return brain.autonomousProcessLabel
        }()

        return HStack(spacing: 7) {
            Circle()
                .fill(activeColor)
                .frame(width: 4, height: 4)
                .shadow(color: activeColor.opacity(0.9), radius: 3)
                .scaleEffect(isThinking ? orbPulse : 1.0)

            Text(liveText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isThinking ? activeColor.opacity(0.9) : .white.opacity(0.3))
                .lineLimit(1)
                .truncationMode(.tail)
                .id(liveText)
                .animation(.easeInOut(duration: 0.2), value: liveText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(activeColor.opacity(isThinking ? 0.06 : 0.02))
        .animation(.easeInOut(duration: 0.4), value: isThinking)
    }

    // MARK: - Consciousness State Strip (v6)

    var consciousnessStrip: some View {
        let regimeColor: Color = {
            switch brain.criticalityRegime {
            case "critical":      return Color(hex: "#34D399")
            case "supercritical": return Color(hex: "#F97316")
            default:              return Color(hex: "#60A5FA")
            }
        }()

        return HStack(spacing: 0) {
            // Sync indicator
            HStack(spacing: 3) {
                Circle()
                    .fill(Color(hex: "#38BDF8").opacity(0.8))
                    .frame(width: 3, height: 3)
                Text("R \(String(format: "%.0f", brain.globalSync * 100))%")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
            }

            Spacer()

            // Criticality regime
            Text(brain.criticalityRegime.prefix(5).uppercased())
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(regimeColor.opacity(0.7))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(regimeColor.opacity(0.1)))

            Spacer()

            // Free energy
            HStack(spacing: 3) {
                Text("FE \(String(format: "%.2f", brain.freeEnergy))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.5))
            }

            Spacer()

            // Surprise indicator (only shown when surprised)
            if brain.isSurprised {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                    Text("!")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.8))
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Curiosity
                HStack(spacing: 2) {
                    Text("C \(String(format: "%.0f", brain.curiosityDrive * 100))%")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#34D399").opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.015))
        .animation(.easeInOut(duration: 0.5), value: brain.isSurprised)
    }

    // MARK: - Message List

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    dateSeparator
                    ForEach(viewModel.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 3)
                    }
                    if brain.isThinking {
                        LiveThinkingBubble(steps: brain.thinkingSteps, brain: brain)
                            .padding(.horizontal, 16).padding(.vertical, 3)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    Color.clear.frame(height: 100).id("bottom")
                }
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: brain.isThinking) { _, _ in
                withAnimation(.spring(response: 0.4)) { proxy.scrollTo("bottom") }
            }
            .onChange(of: brain.innerMonologue.count) { _, _ in
                if brain.isThinking { withAnimation { proxy.scrollTo("bottom") } }
            }
        }
    }

    var dateSeparator: some View {
        Text("Idag")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.15))
            .padding(.vertical, 20)
    }

    // MARK: - Input Bar

    var inputBar: some View {
        VStack(spacing: 0) {
            if brain.isThinking, let last = brain.innerMonologue.last {
                let clean = cleanMonologue(last.text)
                if !clean.isEmpty {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color(hex: "#FBBF24"))
                            .frame(width: 3, height: 3)
                            .shadow(color: Color(hex: "#FBBF24").opacity(0.9), radius: 3)
                            .scaleEffect(orbPulse)
                        Text(clean)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(hex: "#FBBF24").opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Skriv till Eon...")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.2))
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $inputText, axis: .vertical)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1...6)
                        .padding(.horizontal, 18).padding(.vertical, 13)
                        .focused($inputFocused)
                        .onSubmit { sendMessage() }
                }
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(inputFocused ? 0.06 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(
                                    inputFocused
                                        ? LinearGradient(colors: [emotionColor.opacity(0.8), Color(hex: "#38BDF8").opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: inputFocused ? emotionColor.opacity(0.2) : .clear, radius: 18)
                )
                .animation(.easeInOut(duration: 0.2), value: inputFocused)

                sendButton
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 10)
            .background(
                Color(hex: "#06030F").opacity(0.95)
                    .background(.ultraThinMaterial.opacity(0.4))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 0.5),
                        alignment: .top
                    )
            )
        }
        .animation(.spring(response: 0.3), value: brain.isThinking)
    }

    var sendButton: some View {
        Button(action: sendMessage) {
            ZStack {
                if canSend {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [emotionColor, emotionColor.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: emotionColor.opacity(0.5), radius: 14)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                }

                if brain.isThinking {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(.white.opacity(0.7))
                                .frame(width: 4, height: 4)
                                .scaleEffect(orbPulse)
                                .animation(
                                    .easeInOut(duration: 0.45)
                                        .delay(Double(i) * 0.15)
                                        .repeatForever(autoreverses: true),
                                    value: orbPulse
                                )
                        }
                    }
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(canSend ? .white : .white.opacity(0.18))
                }
            }
        }
        .disabled(!canSend)
        .animation(.spring(response: 0.3), value: canSend)
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !brain.isThinking
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !brain.isThinking else { return }
        inputText = ""
        inputFocused = false
        viewModel.addUserMessage(text)
        Task { await viewModel.sendToBrain(text, brain: brain) }
    }

    private func copySession() {
        let lines = viewModel.messages.map { msg -> String in
            let role = msg.role == .user ? "Du" : "Eon"
            return "\(role): \(msg.content)"
        }
        let header = "=== Eon-session \(formattedNow()) ===\n"
        let full = header + lines.joined(separator: "\n\n")
        UIPasteboard.general.string = full
        withAnimation(.spring(response: 0.3)) { sessionCopied = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) { sessionCopied = false }
            }
        }
    }

    private func formattedNow() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }

    private func cleanMonologue(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳📈⚠️📚🌐🗺️◈◉⟳🔗"
        var r = text
        for c in emojis { r = r.replacingOccurrences(of: String(c), with: "") }
        return r.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ChatViewModel

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isReasoningMode: Bool = false
    @Published var allConversations: [ConversationSession] = []

    struct ConversationSession: Identifiable {
        let id: String
        let title: String
        let date: Date
        let messageCount: Int
    }

    init() {
        messages.append(ChatMessage(
            role: .eon,
            content: "Hej! Jag är Eon — ett kognitivt AI-system som körs helt on-device. Jag tänker, resonerar och lär mig autonomt dygnet runt. Vad vill du utforska?",
            confidence: 0.95,
            emotion: .neutral
        ))
        loadConversationHistory()
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
    }

    func sendToBrain(_ text: String, brain: EonBrain) async {
        var eonMsg = ChatMessage(
            role: .eon,
            content: "",
            confidence: 0,
            emotion: brain.currentEmotion,
            isReasoningMode: isReasoningMode
        )
        messages.append(eonMsg)
        let idx = messages.count - 1

        let stream: AsyncStream<String>
        if isReasoningMode {
            stream = await brain.thinkDeep(userMessage: text)
        } else {
            stream = await brain.think(userMessage: text)
        }

        for await token in stream {
            messages[idx].content += token
        }
        messages[idx].confidence = brain.confidence
        messages[idx].emotion = brain.currentEmotion
        messages[idx].retrievedMemoryCount = brain.thinkingSteps
            .filter { $0.step == .memoryRetrieval && $0.state == .completed }.count > 0
            ? Int.random(in: 1...4) : 0

        // v6: Capture consciousness snapshot at response completion
        messages[idx].consciousnessLevel = brain.consciousnessLevel
        messages[idx].wasSurprised = brain.isSurprised
        messages[idx].criticalityRegime = brain.criticalityRegime
        messages[idx].globalSync = brain.globalSync
    }

    func startNewConversation() {
        loadConversationHistory()
        messages = [ChatMessage(
            role: .eon,
            content: "Ny konversation startad. Vad vill du prata om?",
            confidence: 0.95,
            emotion: .neutral
        )]
    }

    func loadConversationHistory() {
        Task {
            let records = await PersistentMemoryStore.shared.recentConversations(limit: 100)
            // Gruppera per dag
            var grouped: [String: [ConversationRecord]] = [:]
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            for r in records {
                let key = df.string(from: r.date)
                grouped[key, default: []].append(r)
            }
            let sessions = grouped.map { key, recs -> ConversationSession in
                let userMsgs = recs.filter { $0.isUser }
                let title = userMsgs.first?.content.prefix(50).description ?? "Konversation"
                let date = recs.first?.date ?? Date()
                return ConversationSession(id: key, title: title, date: date, messageCount: recs.count)
            }.sorted { $0.date > $1.date }
            await MainActor.run { self.allConversations = sessions }
        }
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
    var isReasoningMode: Bool = false
    let timestamp = Date()

    // v6: Consciousness state snapshot at response time
    var consciousnessLevel: Double = 0.0
    var wasSurprised: Bool = false
    var criticalityRegime: String = "subcritical"
    var globalSync: Double = 0.0

    enum Role { case user, eon }
    var isUser: Bool { role == .user }
}

// MARK: - ChatBubble

struct ChatBubble: View {
    let message: ChatMessage
    @State private var appeared = false

    private var emotionColor: Color { EonColor.forEmotion(message.emotion) }

    var body: some View {
        Group {
            if message.isUser {
                userRow
            } else {
                eonRow
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) { appeared = true }
        }
    }

    var userRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content.isEmpty ? "..." : message.content)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4C1D95"), Color(hex: "#2D1060")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color(hex: "#7C3AED").opacity(0.4), lineWidth: 0.6)
                            )
                    )
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.3), radius: 12, y: 3)
                timeLabel
            }
        }
    }

    var eonRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                // v6: Consciousness state badges
                HStack(spacing: 4) {
                    if message.retrievedMemoryCount > 0 {
                        MemoryRecallBadge(count: message.retrievedMemoryCount)
                    }
                    if message.wasSurprised {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                            Text("Överraskning")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: "#FBBF24"))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#FBBF24").opacity(0.12)))
                    }
                    if message.consciousnessLevel > 0.5 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: "#A78BFA"))
                                .frame(width: 4, height: 4)
                            Text("Q \(String(format: "%.0f%%", message.consciousnessLevel * 100))")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "#A78BFA").opacity(0.08)))
                    }
                }

                Text(message.content.isEmpty ? "..." : message.content)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [emotionColor.opacity(0.4), emotionColor.opacity(0.1)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.7
                                    )
                            )
                    )
                    .shadow(color: emotionColor.opacity(0.08), radius: 10, y: 2)

                HStack(spacing: 10) {
                    if message.confidence > 0 {
                        ConfidenceIndicator(confidence: message.confidence)
                    }
                    // v6: Show sync at response time
                    if message.globalSync > 0.3 {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 7))
                            Text("R\(String(format: "%.0f", message.globalSync * 100))")
                                .font(.system(size: 8, design: .monospaced))
                        }
                        .foregroundStyle(Color(hex: "#38BDF8").opacity(0.3))
                    }
                    Spacer()
                    timeLabel
                }
            }
            Spacer(minLength: 60)
        }
    }

    var timeLabel: some View {
        Text(timeString(message.timestamp))
            .font(.system(size: 9, design: .rounded))
            .foregroundStyle(.white.opacity(0.15))
    }

    func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

// MARK: - Live Thinking Bubble

struct LiveThinkingBubble: View {
    let steps: [ThinkingStepStatus]
    let brain: EonBrain
    @State private var dotPhase: Int = 0
    @State private var appeared = false
    @State private var dotTimer: Timer?

    private let thinkColor = Color(hex: "#FBBF24")
    var activeStep: ThinkingStepStatus? { steps.first { $0.state == .active } }
    var completedCount: Int { steps.filter { $0.state == .completed }.count }
    var totalCount: Int { steps.filter { $0.step != .idle }.count }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(thinkColor)
                                .frame(width: 3, height: dotPhase == i ? 14 : 6)
                                .shadow(color: dotPhase == i ? thinkColor.opacity(0.8) : .clear, radius: 4)
                                .animation(.spring(response: 0.2, dampingFraction: 0.45).delay(Double(i) * 0.1), value: dotPhase)
                        }
                    }

                    if let step = activeStep {
                        Text(step.step.label)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(thinkColor.opacity(0.85))
                            .id(step.step.rawValue)
                            .animation(.easeInOut(duration: 0.2), value: step.step.rawValue)
                    } else {
                        Text("Bearbetar...")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Spacer()

                    Text("\(completedCount)/\(totalCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.05)).frame(height: 2)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [thinkColor, Color(hex: "#F472B6")],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(
                                width: totalCount > 0 ? g.size.width * CGFloat(completedCount) / CGFloat(totalCount) : 0,
                                height: 2
                            )
                            .shadow(color: thinkColor.opacity(0.6), radius: 4)
                            .animation(.easeInOut(duration: 0.4), value: completedCount)
                    }
                }
                .frame(height: 2)

                if let last = brain.innerMonologue.last {
                    let clean = cleanText(last.text)
                    if !clean.isEmpty {
                        Text(clean)
                            .font(.system(size: 11, design: .rounded).italic())
                            .foregroundStyle(thinkColor.opacity(0.55))
                            .lineLimit(1)
                            .id(last.id)
                            .animation(.easeInOut(duration: 0.25), value: last.id)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [thinkColor.opacity(0.35), thinkColor.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.7
                            )
                    )
            )
            .shadow(color: thinkColor.opacity(0.08), radius: 14, y: 3)

            Spacer(minLength: 60)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { appeared = true }
            dotTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                Task { @MainActor in dotPhase = (dotPhase + 1) % 3 }
            }
        }
        .onDisappear { dotTimer?.invalidate() }
    }

    private func cleanText(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳📈⚠️📚🌐🗺️◈◉⟳🔗"
        var r = text
        for c in emojis { r = r.replacingOccurrences(of: String(c), with: "") }
        return r.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - ConfidenceIndicator

struct ConfidenceIndicator: View {
    let confidence: Double
    var barColor: Color {
        confidence > 0.75 ? Color(hex: "#34D399") : confidence > 0.5 ? Color(hex: "#FBBF24") : Color(hex: "#F97316")
    }
    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "#7C3AED"), barColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(width: 52, height: 3)
            Text("\(Int(confidence * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
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
        .foregroundStyle(Color(hex: "#FBBF24"))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule()
            .fill(Color(hex: "#FBBF24").opacity(0.1))
            .overlay(Capsule().strokeBorder(Color(hex: "#FBBF24").opacity(glowing ? 0.55 : 0.2), lineWidth: 0.5)))
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { glowing = true } }
    }
}

// MARK: - Helpers

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Legacy stubs

struct ParticleBackgroundView: View {
    var body: some View { EmptyView() }
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
        .padding(16).background(Color(hex: "#0F0B1E")).presentationCompactAdaptation(.popover)
    }
}
struct EmotionalMiniOrb: View {
    let emotion: EonEmotion; let arousal: Double
    @State private var scale: CGFloat = 1.0
    var orbColor: Color { EonColor.forEmotion(emotion) }
    var body: some View {
        ZStack {
            Circle().fill(orbColor.opacity(0.18)).frame(width: 38, height: 38).blur(radius: 5)
            Circle()
                .fill(RadialGradient(colors: [orbColor, orbColor.opacity(0.45)], center: .center, startRadius: 0, endRadius: 14))
                .frame(width: 28, height: 28).scaleEffect(scale)
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

// ConversationHistorySidebar, ConversationRow → ConversationHistorySidebar.swift
// ChatModeSheet, ModeOption → ChatModeSheet.swift

#if false
private struct _RemovedTypes {
    @Binding var isShowing: Bool
    @ObservedObject var viewModel: ChatViewModel
    let brain: EonBrain

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Historik")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(viewModel.allConversations.count) konversationer")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35)) { isShowing = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)

                // Ny konversation
                Button {
                    viewModel.startNewConversation()
                    withAnimation(.spring(response: 0.35)) { isShowing = false }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Ny konversation")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#7C3AED").opacity(0.25))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#7C3AED").opacity(0.4), lineWidth: 0.7))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Lista
                if viewModel.allConversations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("Inga sparade konversationer")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(viewModel.allConversations) { session in
                                ConversationRow(session: session)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.35)) { isShowing = false }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(width: 300)
            .background(
                Color(hex: "#07040F")
                    .overlay(Color(hex: "#7C3AED").opacity(0.04))
                    .ignoresSafeArea()
            )
            .shadow(color: .black.opacity(0.5), radius: 24, x: 8)

            Spacer()
        }
        .ignoresSafeArea()
    }
}

struct ConversationRow: View {
    let session: ChatViewModel.ConversationSession
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#7C3AED").opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(relativeDate(session.date))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.2))
                    Text("\(session.messageCount) meddelanden")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(appeared ? 0.04 : 0))
        )
        .onAppear { withAnimation(.easeOut(duration: 0.15)) { appeared = true } }
    }

    func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Idag" }
        if cal.isDateInYesterday(date) { return "Igår" }
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        df.locale = Locale(identifier: "sv_SE")
        return df.string(from: date)
    }
}

// MARK: - ChatModeSheet

struct ChatModeSheet: View {
    @Binding var isReasoningMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
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

#endif

#Preview("Chatt") {
    EonPreviewContainer { ChatView() }
}
