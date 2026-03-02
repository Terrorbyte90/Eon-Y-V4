import SwiftUI
import Combine

// MARK: - EonPulseHomeView v7 — Flip-kognition, öga-animation, uppflyttad layout

struct EonPulseHomeView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @Environment(\.scenePhase) private var scenePhase

    @State private var ring1: Double = 0
    @State private var ring2: Double = 0
    @State private var ring3: Double = 0
    @State private var orbPulse: CGFloat = 1.0
    @State private var particles: [HomeParticle] = HomeParticle.generate(count: 20)
    @State private var showContent = false
    @State private var showCognitionLog = false
    @State private var showFullLog = false
    @State private var showSmartDash = false

    // Flip meter states
    @State private var autonomFlipped = false
    @State private var levandeFlipped = false
    @State private var intelligentFlipped = false
    @State private var flipTimer: Timer? = nil

    // Live kognition ↔ Live självmedvetenhet flip
    @State private var showingSelfAwareness = false
    @State private var awarenessFlipTimer: Timer? = nil

    // Öga-animation
    @State private var eyePupilOffset: CGSize = .zero
    @State private var eyeBlinkScale: CGFloat = 1.0
    @State private var eyeGlowPulse: CGFloat = 1.0
    @State private var eyeLookTimer: Timer? = nil

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    orbSection
                        // 15% uppflyttning: original var -40, nu -40 - (280*0.15) ≈ -82
                        .padding(.top, -82)
                    titleSection
                        .padding(.top, 18)
                    if showContent {
                        monologueSection
                            .padding(.top, 16).padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Color.clear.frame(height: 40)
                }
                .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
            }
            .coordinateSpace(name: "scrollSpace")
        }
        .onAppear {
            startAnimations()
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { showContent = true }
            startAwarenessFlipTimer()
        }
        .onDisappear {
            awarenessFlipTimer?.invalidate()
            eyeLookTimer?.invalidate()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startAnimations()
                startAwarenessFlipTimer()
            }
        }
        .onChange(of: showingSelfAwareness) { _, isAwareness in
            if isAwareness {
                startEyeAnimation()
            } else {
                eyeLookTimer?.invalidate()
            }
        }
    }

    // MARK: - Background

    var background: some View {
        let activity = activityLevel
        let dominant = dominantColor
        return ZStack {
            Color(hex: "#050310").ignoresSafeArea()
            RadialGradient(
                colors: [dominant.opacity(0.16 + activity * 0.10), Color.clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#0A0520").opacity(0.85), Color.clear],
                center: .bottomLeading, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()
        }
    }

    // MARK: - Orb

    var orbSection: some View {
        let dominant = dominantColor
        let activity = activityLevel
        return ZStack {
            // Ambient glow
            Circle()
                .fill(RadialGradient(
                    colors: [dominant.opacity(0.20 + activity * 0.12), Color.clear],
                    center: .center, startRadius: 0, endRadius: 180
                ))
                .frame(width: 360, height: 360)
                .blur(radius: 28)
                .scaleEffect(orbPulse)

            // Partiklar — Canvas-baserad, ett enda GPU-pass
            ParticleCanvasView(particles: particles, dominantColor: dominant)
                .frame(width: 340, height: 340)

            // Ring 3 — yttre, långsam
            Circle()
                .trim(from: 0, to: 0.55)
                .stroke(
                    AngularGradient(
                        colors: [.clear, dominant.opacity(0.30), Color(hex: "#38BDF8").opacity(0.18), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [4, 10])
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(ring3))

            // Ring 2 — medel
            Circle()
                .trim(from: 0, to: 0.70)
                .stroke(
                    AngularGradient(
                        colors: [.clear, dominant.opacity(0.60), Color(hex: "#5EEAD4").opacity(0.30), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(ring2))

            // Ring 1 — inre, snabb
            Circle()
                .trim(from: 0, to: 0.45)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(hex: "#A78BFA").opacity(0.85), dominant.opacity(0.55), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
                .frame(width: 148, height: 148)
                .rotationEffect(.degrees(ring1))

            // Kärna — tryckbar → öppnar Full-log
            Button {
                showFullLog = true
            } label: {
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [
                                Color(hex: "#2D1B69").opacity(0.98),
                                Color(hex: "#1A0A3E").opacity(0.95),
                                Color(hex: "#060410")
                            ],
                            center: .center, startRadius: 0, endRadius: 68
                        ))
                        .frame(width: 136, height: 136)

                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [dominant.opacity(0.9), Color(hex: "#38BDF8").opacity(0.5), dominant.opacity(0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .frame(width: 136, height: 136)
                        .shadow(color: dominant.opacity(0.6), radius: 20)

                    // Hjärna eller öga beroende på läge
                    if showingSelfAwareness {
                        EyeOrbView(
                            pupilOffset: eyePupilOffset,
                            blinkScale: eyeBlinkScale,
                            glowPulse: eyeGlowPulse,
                            dominant: dominant
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 42, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [dominant, Color(hex: "#38BDF8")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: dominant.opacity(0.9), radius: 14)
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }

                    // Aktivitetsdottar runt kärnan
                    ForEach(0..<7, id: \.self) { i in
                        let keys = ["cognitive","language","memory","learning","autonomy","hypothesis","worldModel"]
                        let key = keys[i]
                        let act = brain.engineActivity[key] ?? 0.5
                        let angle = Double(i) / 7.0 * 360 - 90
                        Circle()
                            .fill(engineColor(key))
                            .frame(width: act > 0.4 ? 5 : 3, height: act > 0.4 ? 5 : 3)
                            .opacity(0.9)
                            .shadow(color: engineColor(key).opacity(0.9), radius: 5)
                            .offset(y: -62)
                            .rotationEffect(.degrees(angle + ring1 * 0.06))
                    }

                    // Liten indikator längst ner på kärnan
                    VStack {
                        Spacer()
                        Text(showingSelfAwareness ? "MEDVETANDE" : "FULL-LOG")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.35))
                            .tracking(1)
                            .padding(.bottom, 14)
                            .animation(.none, value: showingSelfAwareness)
                    }
                    .frame(width: 136, height: 136)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(orbPulse)
            .animation(.easeInOut(duration: 0.6), value: showingSelfAwareness)
            .sheet(isPresented: $showFullLog) {
                FullLogView()
                    .environmentObject(brain)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .frame(height: 280)
    }

    // MARK: - Titel + Ticker

    var titleSection: some View {
        let dominant = dominantColor
        let label = brain.autonomousProcessLabel
        return VStack(spacing: 10) {
            HStack(spacing: 18) {
                // "E" — tappbar, navigerar till SmartDash
                Text("E")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#C4B5FD"), Color(hex: "#A78BFA")], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(hex: "#A78BFA").opacity(0.6), radius: 16)
                    .onTapGesture { showSmartDash = true }
                Text("O")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#38BDF8"), Color(hex: "#06B6D4")], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: dominant.opacity(0.4), radius: 16)
                Text("N")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "#34D399"), Color(hex: "#10B981")], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(hex: "#34D399").opacity(0.4), radius: 16)
            }
            .shadow(color: dominant.opacity(0.5), radius: 24)
            .fullScreenCover(isPresented: $showSmartDash) {
                SmartDashView().environmentObject(brain)
            }

            HStack(spacing: 10) {
                FlipMeterView(
                    frontLabel: "Autonom",
                    frontColor: Color(hex: "#34D399"),
                    backContent: AnyView(
                        VStack(spacing: 2) {
                            Text("CPU")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                            Text(brain.thermalState)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#34D399"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    ),
                    isFlipped: autonomFlipped,
                    orbPulse: orbPulse
                )
                FlipMeterView(
                    frontLabel: "Levande",
                    frontColor: Color(hex: "#38BDF8"),
                    backContent: AnyView(
                        VStack(spacing: 2) {
                            Text("MEDVETANDE")
                                .font(.system(size: 5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                            Text(consciousnessShortLabel)
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#38BDF8"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    ),
                    isFlipped: levandeFlipped,
                    orbPulse: orbPulse
                )
                FlipMeterView(
                    frontLabel: "Intelligent",
                    frontColor: Color(hex: "#A78BFA"),
                    backContent: AnyView(
                        VStack(spacing: 2) {
                            Text("Φ")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                            Text(String(format: "%.3f", brain.phiValue))
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(hex: "#A78BFA"))
                        }
                    ),
                    isFlipped: intelligentFlipped,
                    orbPulse: orbPulse
                )
            }
            .onAppear { startFlipTimer() }
            .onDisappear { flipTimer?.invalidate() }

            // Process-label — filtreras vid självmedvetenhet
            HStack(spacing: 8) {
                Circle()
                    .fill(showingSelfAwareness ? Color(hex: "#A78BFA") : dominant)
                    .frame(width: 5, height: 5)
                    .shadow(color: (showingSelfAwareness ? Color(hex: "#A78BFA") : dominant).opacity(0.9), radius: 5)
                    .scaleEffect(orbPulse)
                Text(showingSelfAwareness ? awarenessEventLabel : label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle((showingSelfAwareness ? Color(hex: "#A78BFA") : dominant).opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .id(showingSelfAwareness ? awarenessEventLabel : label)
                    .animation(.easeInOut(duration: 0.4), value: showingSelfAwareness)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(
                Capsule()
                    .fill((showingSelfAwareness ? Color(hex: "#A78BFA") : dominant).opacity(0.08))
                    .overlay(Capsule().strokeBorder((showingSelfAwareness ? Color(hex: "#A78BFA") : dominant).opacity(0.30), lineWidth: 0.7))
            )
            .padding(.horizontal, 36)
        }
    }

    // Hämta senaste självmedvetenhet-event från thoughtStream
    var awarenessEventLabel: String {
        let ce = ConsciousnessEngine.shared
        if !ce.currentSelfReflection.isEmpty {
            let s = ce.currentSelfReflection
            return String(s.prefix(60)) + (s.count > 60 ? "..." : "")
        }
        if let thought = ce.thoughtStream.last {
            let s = thought.content
            return String(s.prefix(60)) + (s.count > 60 ? "..." : "")
        }
        return "Självmedvetenhet aktiv..."
    }

    var consciousnessShortLabel: String {
        switch brain.consciousnessLevel {
        case ..<0.15: return "Minimal"
        case 0.15..<0.30: return "Låg"
        case 0.30..<0.50: return "Växer"
        case 0.50..<0.70: return "Stark"
        default: return "Djup"
        }
    }

    func startFlipTimer() {
        flipTimer?.invalidate()
        func runFlipCycle() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { autonomFlipped.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { levandeFlipped.toggle() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { intelligentFlipped.toggle() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { runFlipCycle() }
        flipTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in runFlipCycle() }
    }

    // MARK: - Awareness Flip Timer (30s kognition, 20s självmedvetenhet)

    func startAwarenessFlipTimer() {
        awarenessFlipTimer?.invalidate()
        // Starta med kognition, flippa till självmedvetenhet efter 30s, tillbaka efter 20s
        awarenessFlipTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.7)) {
                showingSelfAwareness = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    showingSelfAwareness = false
                }
            }
        }
    }

    // MARK: - Öga-animation

    func startEyeAnimation() {
        eyeLookTimer?.invalidate()
        // Ögat tittar runt slumpmässigt
        eyeLookTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.8...2.2), repeats: true) { _ in
            let maxOffset: CGFloat = 8
            let newOffset = CGSize(
                width: CGFloat.random(in: -maxOffset...maxOffset),
                height: CGFloat.random(in: -maxOffset...maxOffset)
            )
            withAnimation(.easeInOut(duration: 0.35)) {
                eyePupilOffset = newOffset
            }
            // Blinka ibland
            if Double.random(in: 0...1) < 0.25 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
                    withAnimation(.easeInOut(duration: 0.08)) { eyeBlinkScale = 0.05 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.12)) { eyeBlinkScale = 1.0 }
                    }
                }
            }
            // Pulsera glöd
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                eyeGlowPulse = 1.15
            }
        }
    }

    // MARK: - Live Monologue / Självmedvetenhet

    var monologueSection: some View {
        ZStack {
            // Kognition-sidan
            cognitionPanel
                .opacity(showingSelfAwareness ? 0 : 1)
                .rotation3DEffect(.degrees(showingSelfAwareness ? -90 : 0), axis: (x: 0, y: 1, z: 0))

            // Självmedvetenhet-sidan
            selfAwarenessPanel
                .opacity(showingSelfAwareness ? 1 : 0)
                .rotation3DEffect(.degrees(showingSelfAwareness ? 0 : 90), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.easeInOut(duration: 0.6), value: showingSelfAwareness)
    }

    var cognitionPanel: some View {
        let lines = brain.innerMonologue.suffix(6)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#34D399"))
                    .frame(width: 5, height: 5)
                    .shadow(color: Color(hex: "#34D399").opacity(0.9), radius: 4)
                    .scaleEffect(orbPulse)
                Text("LIVE KOGNITION")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text("\(brain.innerMonologue.count) tankar")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            Rectangle()
                .fill(Color(hex: "#34D399").opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(lines.reversed().enumerated()), id: \.element.id) { idx, line in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Image(systemName: line.type.icon)
                                .font(.system(size: 9))
                                .foregroundStyle(line.type.color)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(line.type.color.opacity(0.12)))
                            if idx < 5 {
                                Rectangle()
                                    .fill(line.type.color.opacity(0.15))
                                    .frame(width: 1, height: 14)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(typeLabel(line.type))
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(line.type.color.opacity(0.7))
                            Text(cleanThought(line.text))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(idx == 0 ? .white.opacity(0.9) : .white.opacity(max(0.2, 0.55 - Double(idx) * 0.08)))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                }
            }
            .padding(.bottom, 6)

            Button {
                showCognitionLog = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                    Text("Visa sparad logg")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(CognitionLogger.shared.fileSizeString)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .foregroundStyle(Color(hex: "#34D399").opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(hex: "#34D399").opacity(0.05))
            }
            .sheet(isPresented: $showCognitionLog) {
                UnifiedLogView(initialTab: .cognition)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .background(glassCard(accent: Color(hex: "#34D399")))
    }

    var selfAwarenessPanel: some View {
        let ce = ConsciousnessEngine.shared
        let thoughts = Array(ce.thoughtStream.suffix(5))
        let reflection = ce.currentSelfReflection
        let accentColor = Color(hex: "#A78BFA")

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Litet pulserande öga
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 9, height: 9)
                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                }
                .scaleEffect(orbPulse)
                Text("LIVE SJÄLVMEDVETENHET")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text("Φ \(String(format: "%.2f", brain.phiValue))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            Rectangle()
                .fill(accentColor.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            // Självreflektion
            if !reflection.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(accentColor.opacity(0.8))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(accentColor.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SJÄLVREFLEKTION")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(accentColor.opacity(0.7))
                        Text(reflection)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)

                Rectangle()
                    .fill(accentColor.opacity(0.05))
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
            }

            // Tankeström
            VStack(spacing: 0) {
                ForEach(Array(thoughts.reversed().enumerated()), id: \.offset) { item in
                    let (idx, thought) = item
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: thoughtIcon(thought.category.rawValue))
                            .font(.system(size: 9))
                            .foregroundStyle(thoughtColor(thought.category.rawValue))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(thoughtColor(thought.category.rawValue).opacity(0.12)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(thought.category.rawValue.uppercased())
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(thoughtColor(thought.category.rawValue).opacity(0.7))
                            Text(thought.content)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(idx == 0 ? .white.opacity(0.9) : .white.opacity(max(0.2, 0.55 - Double(idx) * 0.08)))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                }
            }
            .padding(.bottom, 6)

            // Senast läst artikel
            if !ce.lastReadArticleTitle.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accentColor.opacity(0.6))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Läser: \(ce.lastReadArticleTitle)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(accentColor.opacity(0.8))
                            .lineLimit(1)
                        if !ce.lastReadArticleInsight.isEmpty {
                            Text(ce.lastReadArticleInsight)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(accentColor.opacity(0.04))
            }
        }
        .background(glassCard(accent: accentColor))
    }

    // MARK: - Helpers

    func thoughtIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "observation": return "eye"
        case "question":    return "questionmark.circle"
        case "insight":     return "lightbulb"
        case "reflection":  return "arrow.triangle.2.circlepath"
        case "goal":        return "target"
        default:            return "bubble.left"
        }
    }

    func thoughtColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "observation": return Color(hex: "#38BDF8")
        case "question":    return Color(hex: "#FBBF24")
        case "insight":     return Color(hex: "#34D399")
        case "reflection":  return Color(hex: "#A78BFA")
        case "goal":        return Color(hex: "#F472B6")
        default:            return Color(hex: "#A78BFA")
        }
    }

    var dominantColor: Color {
        let sorted = brain.engineActivity.sorted { $0.value > $1.value }
        return engineColor(sorted.first?.key ?? "cognitive")
    }

    var activityLevel: Double {
        guard !brain.engineActivity.isEmpty else { return 0.45 }
        return (brain.engineActivity.values.reduce(0, +) / Double(brain.engineActivity.count)).clamped(to: 0...1)
    }

    func engineColor(_ key: String) -> Color {
        switch key {
        case "cognitive":  return Color(hex: "#7C3AED")
        case "language":   return Color(hex: "#34D399")
        case "memory":     return Color(hex: "#38BDF8")
        case "learning":   return Color(hex: "#FBBF24")
        case "autonomy":   return Color(hex: "#A78BFA")
        case "hypothesis": return Color(hex: "#F472B6")
        case "worldModel": return Color(hex: "#FB923C")
        default:           return Color(hex: "#7C3AED")
        }
    }

    func typeLabel(_ t: MonologueLine.MonologueType) -> String {
        switch t {
        case .thought:     return "TANKE"
        case .loopTrigger: return "LOOP"
        case .revision:    return "REVISION"
        case .memory:      return "MINNE"
        case .insight:     return "INSIKT"
        }
    }

    func glassCard(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.025))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(
                    colors: [accent.opacity(0.35), accent.opacity(0.07)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            ))
    }

    func cleanThought(_ text: String) -> String {
        let emojis = "🔴🟡🟢💡✅❌⛓🪞🗣📖🌍🔮🎯🔬🔭📊🧩💭🔄✏️🧠⚡🌱🌿🌲🌳📈⚠️📚🌐🗺️◈◉⟳🔗"
        var r = text
        for c in emojis { r = r.replacingOccurrences(of: String(c), with: "") }
        return r.trimmingCharacters(in: .whitespaces)
    }

    private func startAnimations() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false))  { ring1 = 360 }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) { ring2 = -360 }
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) { ring3 = 360 }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { orbPulse = 1.07 }
    }
}

// MARK: - EyeOrbView — Levande öga för självmedvetenhetsläge

struct EyeOrbView: View {
    let pupilOffset: CGSize
    let blinkScale: CGFloat
    let glowPulse: CGFloat
    let dominant: Color

    private let eyeColor = Color(hex: "#A78BFA")

    var body: some View {
        ZStack {
            // Yttre glöd
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [eyeColor.opacity(0.4), Color.clear],
                        center: .center, startRadius: 0, endRadius: 30
                    )
                )
                .frame(width: 60, height: 40)
                .blur(radius: 8)
                .scaleEffect(glowPulse)

            // Ögonvita
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.92), Color.white.opacity(0.75)],
                        center: .center, startRadius: 0, endRadius: 22
                    )
                )
                .frame(width: 46, height: 30)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))
                .shadow(color: eyeColor.opacity(0.6), radius: 8)

            // Iris
            Circle()
                .fill(
                    RadialGradient(
                        colors: [eyeColor, Color(hex: "#5B21B6"), Color(hex: "#1E0A3E")],
                        center: .center, startRadius: 0, endRadius: 12
                    )
                )
                .frame(width: 22, height: 22)
                .offset(pupilOffset)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Pupill
            Circle()
                .fill(Color.black)
                .frame(width: 10, height: 10)
                .offset(pupilOffset)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Ljusreflex
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 4, height: 4)
                .offset(CGSize(
                    width: pupilOffset.width + 4,
                    height: pupilOffset.height - 4
                ))
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            // Ögonlock-linjer
            Ellipse()
                .trim(from: 0, to: 0.5)
                .stroke(eyeColor.opacity(0.6), lineWidth: 1.5)
                .frame(width: 46, height: 30)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))

            Ellipse()
                .trim(from: 0.5, to: 1.0)
                .stroke(eyeColor.opacity(0.4), lineWidth: 1.0)
                .frame(width: 46, height: 30)
                .scaleEffect(CGSize(width: 1.0, height: blinkScale))
        }
        .frame(width: 60, height: 50)
    }
}

// MARK: - HomeParticle (Canvas-baserad — ett enda GPU-pass)

struct HomeParticle: Identifiable {
    let id = UUID()
    let x: CGFloat; let y: CGFloat
    let size: CGFloat; let baseOpacity: Double
    let colorIndex: Int
    let phaseOffset: Double
    let driftX: CGFloat; let driftY: CGFloat

    static func generate(count: Int) -> [HomeParticle] {
        return (0..<count).map { i in
            HomeParticle(
                x: CGFloat.random(in: -170...170),
                y: CGFloat.random(in: -170...170),
                size: CGFloat.random(in: 1.5...4.5),
                baseOpacity: Double.random(in: 0.15...0.55),
                colorIndex: Int.random(in: 0...4),
                phaseOffset: Double(i) / Double(count) * .pi * 2,
                driftX: CGFloat.random(in: -14...14),
                driftY: CGFloat.random(in: -14...14)
            )
        }
    }
}

// Canvas-renderer: ritar alla partiklar i ett enda GPU-pass.
struct ParticleCanvasView: View {
    let particles: [HomeParticle]
    let dominantColor: Color

    @State private var phase: Double = 0

    private let colors: [Color] = [
        Color(hex: "#7C3AED"), Color(hex: "#38BDF8"),
        Color(hex: "#34D399"), Color(hex: "#A78BFA"), Color(hex: "#F472B6")
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            for p in particles {
                let t = phase + p.phaseOffset
                let ox = p.driftX * CGFloat(sin(t * 0.7))
                let oy = p.driftY * CGFloat(cos(t * 0.5))
                let opacity = p.baseOpacity * (0.5 + 0.5 * sin(t * 1.1))
                let color = colors[p.colorIndex % colors.count].opacity(opacity)
                let rect = CGRect(
                    x: cx + p.x + ox - p.size / 2,
                    y: cy + p.y + oy - p.size / 2,
                    width: p.size, height: p.size
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - FlipMeterView

struct FlipMeterView: View {
    let frontLabel: String
    let frontColor: Color
    let backContent: AnyView
    let isFlipped: Bool
    let orbPulse: CGFloat

    var body: some View {
        ZStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(frontColor)
                    .frame(width: 5, height: 5)
                    .shadow(color: frontColor.opacity(0.8), radius: 4)
                    .scaleEffect(orbPulse)
                Text(frontLabel)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(frontColor.opacity(0.7))
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 1, y: 0, z: 0))

            backContent
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 1, y: 0, z: 0))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFlipped ? frontColor.opacity(0.08) : Color.clear)
                .overlay(
                    isFlipped
                    ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(frontColor.opacity(0.2), lineWidth: 0.5)
                    : nil
                )
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: isFlipped)
    }
}

// MARK: - CognitiveDimension helpers

private func dimShortName(_ d: CognitiveDimension) -> String {
    switch d {
    case .reasoning:            return "Resonemang"
    case .causality:            return "Kausalitet"
    case .metacognition:        return "Metakognition"
    case .learning:             return "Inlärning"
    case .knowledge:            return "Kunskap"
    case .selfAwareness:        return "Självkänsla"
    case .language:             return "Språk"
    case .worldModel:           return "Världsbild"
    case .adaptivity:           return "Adaptivitet"
    case .creativity:           return "Kreativitet"
    case .hypothesisGeneration: return "Hypotes"
    case .analogyBuilding:      return "Analogi"
    case .comprehension:        return "Förståelse"
    case .communication:        return "Kommunikation"
    case .prediction:           return "Prediktion"
    case .cognitiveLoad:        return "Kogn. last"
    }
}

// MARK: - StatusLine (bakåtkompatibilitet)

struct StatusLine: Identifiable {
    let id = UUID()
    let color: Color; let label: String; let value: String; let icon: String
}

struct StatusLineView: View {
    let line: StatusLine
    @State private var dotPulse: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(line.color)
                .frame(width: 6, height: 6)
                .scaleEffect(dotPulse)
                .onAppear {
                    withAnimation(.easeInOut(duration: Double.random(in: 0.7...1.4)).repeatForever(autoreverses: true)) {
                        dotPulse = 1.5
                    }
                }
            HStack(spacing: 0) {
                Text(line.label)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(line.color.opacity(0.9))
                Text(": ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(line.color.opacity(0.4))
                Text(line.value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: line.icon)
                .font(.system(size: 11))
                .foregroundStyle(line.color.opacity(0.5))
        }
    }
}

// MARK: - DimMiniCard

struct DimMiniCard: View {
    let dimension: CognitiveDimension
    let value: Double
    let growing: Bool
    @State private var appeared = false

    var dimColor: Color { Color(hex: dimension.color) }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(dimColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(dimColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Image(systemName: dimension.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(dimColor)
            }
            Text(dimShortName(dimension))
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(dimColor.opacity(0.8))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.02))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(dimColor.opacity(0.2), lineWidth: 0.5))
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.85)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double.random(in: 0...0.3))) {
                appeared = true
            }
        }
    }
}
