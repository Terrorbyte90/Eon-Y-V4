import SwiftUI

// MARK: - Eon-Y V3 Design System

enum EonColor {
    // Bakgrunder
    static let background = Color(hex: "#07050F")
    static let surfacePrimary = Color(hex: "#0F0B1E")
    static let surfaceSecondary = Color(hex: "#1A1530")
    static let surfaceGlass = Color.white.opacity(0.04)

    // Accent
    static let violet = Color(hex: "#7C3AED")
    static let violetLight = Color(hex: "#A78BFA")
    static let violetDim = Color(hex: "#7C3AED").opacity(0.3)
    static let teal = Color(hex: "#14B8A6")
    static let gold = Color(hex: "#F59E0B")
    static let crimson = Color(hex: "#EF4444")
    static let cyan = Color(hex: "#06B6D4")
    static let orange = Color(hex: "#F97316")

    // Pelare-färger
    static let pillarMorphology = Color(hex: "#EF4444")   // Pelare A
    static let pillarCausal = Color(hex: "#F97316")       // Pelare B
    static let pillarMeta = Color(hex: "#8B5CF6")         // Pelare C
    static let pillarTemporal = Color(hex: "#06B6D4")     // Pelare D
    static let pillarEmergent = Color(hex: "#10B981")     // Pelare E
    static let pillarWSD = Color(hex: "#A78BFA")          // Pelare F
    static let pillarThoughtGlass = Color(hex: "#EC4899") // Pelare G
    static let pillarGPT = Color(hex: "#7C3AED")          // GPT-SW3
    static let pillarBERT = Color(hex: "#3B82F6")         // KB-BERT
    static let pillarGWT = Color(hex: "#F59E0B")          // Global Workspace

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    // Emotion → färg
    static func forEmotion(_ emotion: EonEmotion) -> Color {
        switch emotion {
        case .curious:       return teal
        case .joyful:        return gold
        case .neutral:       return violetLight
        case .uncertain:     return crimson
        case .focused:       return cyan
        case .satisfied:     return Color(hex: "#10B981")
        case .contemplative: return Color(hex: "#8B5CF6")
        case .engaged:       return Color(hex: "#06B6D4")
        }
    }
}

enum EonEmotion: String, CaseIterable {
    case curious, joyful, neutral, uncertain, focused, satisfied, contemplative, engaged
}

enum EonFont {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Glasmorfism modifier

struct GlassMorphism: ViewModifier {
    var tint: Color = EonColor.violet
    var cornerRadius: CGFloat = 16
    var borderOpacity: Double = 0.15

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tint.opacity(0.05))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(borderOpacity), tint.opacity(borderOpacity * 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func glassMorphism(tint: Color = EonColor.violet, cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassMorphism(tint: tint, cornerRadius: cornerRadius))
    }

    func eonGlow(color: Color = EonColor.violet, radius: CGFloat = 8) -> some View {
        shadow(color: color.opacity(0.5), radius: radius)
    }
}

// MARK: - Hex Color init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Pulsating animation

struct PulseAnimation: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    init(min: CGFloat = 0.95, max: CGFloat = 1.05, duration: Double = 1.8) {
        self.minScale = min
        self.maxScale = max
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    scale = maxScale
                }
            }
    }
}

extension View {
    func pulseAnimation(min: CGFloat = 0.95, max: CGFloat = 1.05, duration: Double = 1.8) -> some View {
        modifier(PulseAnimation(min: min, max: max, duration: duration))
    }
}

// MARK: - Sparkline data

struct SparklineView: View {
    let values: [Double]
    var color: Color = EonColor.violet
    var height: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let range = max(maxV - minV, 0.001)

            Path { path in
                guard values.count > 1 else { return }
                let step = w / CGFloat(values.count - 1)
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = h - (CGFloat(v - minV) / CGFloat(range)) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
    }
}
