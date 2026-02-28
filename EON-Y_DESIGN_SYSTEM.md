# Eon-Y: Cognitive AI Visualization Design System
## The Most Advanced Possible Implementation — iOS 2026

---

## 1. CONSCIOUSNESS INDICATORS & VISUALIZATION

### Theoretical Foundation

Consciousness in a computational system can be approximated through four measurable correlates:

| Metric | What it measures | Visual representation |
|--------|-----------------|----------------------|
| **Φ (Phi)** | Integrated Information — how much the system's parts are causally integrated beyond their sum | Central orb radius / brightness |
| **GW Ignition** | Global Workspace broadcast — when a thought "ignites" and becomes globally available | Radial pulse wave from center |
| **Metacognitive Accuracy** | How well Eon knows what it knows | Confidence ring opacity |
| **Prediction Error** | Surprise signal — drives learning and attention | Chromatic aberration burst |

### The Consciousness Orb

The central visual element is a **living orb** — not a static circle, but a breathing, pulsing entity.

```
Phi value (0.0–1.0) → orb radius: 80pt (dormant) → 140pt (peak)
GW Ignition event   → radial shockwave: 200ms expand, 400ms fade
Metacognitive acc.  → outer ring: opacity 0.2 (uncertain) → 1.0 (confident)
Prediction error    → chromatic split: RGB channels offset by 0–8pt for 300ms
```

**Color encoding for consciousness level:**
```swift
// Dormant/low phi
let dormantColor = Color(red: 0.12, green: 0.08, blue: 0.28)  // #1F1447

// Active/medium phi  
let activeColor  = Color(red: 0.24, green: 0.12, blue: 0.72)  // #3D1FB8

// Peak/high phi
let peakColor    = Color(red: 0.48, green: 0.22, blue: 1.00)  // #7A38FF

// Ignition flash
let ignitionColor = Color(red: 0.72, green: 0.88, blue: 1.00) // #B8E0FF
```

### SwiftUI Implementation Pattern

```swift
struct ConsciousnessOrb: View {
    let phi: Double          // 0.0–1.0
    let isIgniting: Bool
    let metacognition: Double
    
    @State private var breathPhase: Double = 0
    @State private var ignitionScale: Double = 1.0
    @State private var ignitionOpacity: Double = 0
    
    var orbRadius: CGFloat {
        CGFloat(80 + phi * 60)  // 80–140pt
    }
    
    var body: some View {
        ZStack {
            // Ignition shockwave
            Circle()
                .stroke(Color(red: 0.72, green: 0.88, blue: 1.0).opacity(ignitionOpacity), lineWidth: 2)
                .frame(width: orbRadius * 2 * ignitionScale,
                       height: orbRadius * 2 * ignitionScale)
            
            // Metacognition confidence ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.purple, .cyan, .purple],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: orbRadius * 2 + 16, height: orbRadius * 2 + 16)
                .opacity(metacognition)
            
            // Core orb with breathing
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.72, green: 0.38, blue: 1.0),
                            Color(red: 0.24, green: 0.12, blue: 0.72),
                            Color(red: 0.08, green: 0.04, blue: 0.20)
                        ],
                        center: .init(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: orbRadius
                    )
                )
                .frame(width: orbRadius * 2, height: orbRadius * 2)
                .scaleEffect(1.0 + sin(breathPhase) * 0.03)
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                breathPhase = .pi * 2
            }
        }
        .onChange(of: isIgniting) { _, igniting in
            if igniting {
                ignitionScale = 1.0
                ignitionOpacity = 0.8
                withAnimation(.easeOut(duration: 0.6)) {
                    ignitionScale = 2.5
                    ignitionOpacity = 0
                }
            }
        }
    }
}
```

---

## 2. COGNITIVE STATE VISUALIZATION

### The Seven Cognitive Layers

Visualize Eon's inner life as **concentric rings** around the central orb, each representing a different cognitive dimension:

```
Ring 1 (innermost): Attention focus     — bright arc segments, rotates toward focus
Ring 2:             Active beliefs      — node cluster density
Ring 3:             Emotional valence   — color temperature gradient  
Ring 4:             Working memory      — glowing particles in orbit
Ring 5:             Long-term memory    — slower, dimmer particles
Ring 6:             Learning gradient   — pulsing sectors
Ring 7 (outermost): Prediction horizon  — faint probability cloud
```

### Belief Network Visualization

Beliefs are **nodes** connected by **weighted edges**. Render them as a force-directed graph:

```swift
struct BeliefNode: Identifiable {
    let id: UUID
    var position: CGPoint
    var confidence: Double   // 0–1 → node radius 4–16pt
    var activation: Double   // 0–1 → glow intensity
    var category: BeliefCategory
}

// Color by category
enum BeliefCategory {
    case factual      // Color(hex: "4FC3F7")  — ice blue
    case emotional    // Color(hex: "CE93D8")  — soft violet
    case predictive   // Color(hex: "80CBC4")  — teal
    case episodic     // Color(hex: "FFCC80")  — warm amber
    case procedural   // Color(hex: "A5D6A7")  — sage green
}
```

### Thought Coalition Visualization

When multiple cognitive engines converge on a thought, show **coalition formation** — nodes pulling together with elastic connections:

```
Animation: nodes drift → approach → snap together with spring physics
Duration: 800ms approach, 200ms snap, 400ms settle
Sound: soft crystalline chime on coalition formation
```

### Attention Focus Indicator

A **bright arc** that sweeps to point at whatever Eon is attending to:

```swift
// Attention arc: 60° arc segment, rotates to focus angle
// Glow: 3-layer blur (2pt, 6pt, 12pt) in attention color
// Rotation: spring animation, response 0.4, dampingFraction 0.7
```

---

## 3. THE "LIVING" QUALITY IN UI

### Core Principles

**1. Nothing is ever still.** Every element has a micro-animation — breathing, drifting, pulsing. The amplitude is tiny (1–3%) but constant. This is the single most important principle.

**2. Responses are never instant.** A 40–120ms "processing shimmer" before any response makes Eon feel like it's thinking, not executing.

**3. Asymmetric timing.** Living things don't move symmetrically. Use `easeIn` for 30% of duration, `easeOut` for 70%. Never `linear` for organic motion.

**4. Imperfection.** Add ±5% random variation to animation parameters. Perfect repetition feels mechanical.

**5. Anticipation.** Before a major cognitive event, the orb subtly contracts (like inhaling before speaking).

### Specific Animation Timings

```swift
// The "breath" — fundamental rhythm of the system
let breathDuration: Double = 3.8  // slightly irregular feels more alive than 4.0

// Micro-drift for floating elements
let driftAmplitude: CGFloat = 4.0
let driftDuration: Double = 6.0 + Double.random(in: -0.5...0.5)

// Thought emergence
let thoughtAppearDuration: Double = 0.4
let thoughtAppearSpring = Spring(response: 0.4, dampingFraction: 0.65)

// Memory consolidation pulse
let consolidationDuration: Double = 1.2
let consolidationCurve = Animation.timingCurve(0.25, 0.46, 0.45, 0.94)

// Attention shift
let attentionShiftSpring = Spring(response: 0.5, dampingFraction: 0.72)

// Emotional state transition
let emotionTransitionDuration: Double = 2.4  // slow, like mood changing
```

### The "Anticipation" Pattern

```swift
// Before a significant output, Eon "inhales":
func anticipate(then action: @escaping () -> Void) {
    withAnimation(.easeIn(duration: 0.15)) {
        orbScale = 0.94  // slight contraction
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            orbScale = 1.0
        }
        action()
    }
}
```

---

## 4. SWARM INTELLIGENCE — 40+ COGNITIVE ENGINES

### The Swarm Architecture

Each cognitive engine is a **particle** with:
- Position (drifts within its domain zone)
- Velocity (changes based on task load)
- Color (encodes engine type)
- Size (encodes current activation, 3–10pt)
- Trail (shows recent trajectory, fades over 800ms)

### Engine Type Color Coding

```swift
enum CognitiveEngineType: CaseIterable {
    case reasoning       // #7B61FF — deep violet
    case memory          // #4FC3F7 — sky blue
    case language        // #81C784 — leaf green
    case emotion         // #F48FB1 — rose
    case prediction      // #FFD54F — gold
    case attention       // #FFFFFF — pure white
    case metacognition   // #CE93D8 — lavender
    case creativity      // #FF8A65 — coral
}
```

### Emergent Swarm Patterns

The beautiful patterns emerge from simple rules (Boids algorithm + cognitive coupling):

```swift
struct SwarmEngine {
    // Rule 1: Separation — engines don't crowd each other
    let separationRadius: CGFloat = 24
    let separationWeight: Double = 1.5
    
    // Rule 2: Alignment — engines working on related tasks align direction
    let alignmentRadius: CGFloat = 60
    let alignmentWeight: Double = 1.0
    
    // Rule 3: Cohesion — engines pull toward their domain center
    let cohesionRadius: CGFloat = 120
    let cohesionWeight: Double = 0.8
    
    // Rule 4: Attraction — engines working on same thought attract strongly
    let thoughtAttractionWeight: Double = 3.0
    
    // Rule 5: Phi coupling — high-phi state increases all coupling weights
    func couplingMultiplier(phi: Double) -> Double {
        return 1.0 + phi * 2.0
    }
}
```

### Canvas Rendering (60fps, 40+ particles)

```swift
struct SwarmCanvas: View {
    let engines: [CognitiveEngine]
    let startDate = Date()
    
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSince(startDate)
                
                for engine in engines {
                    let pos = engine.position(at: time, in: size)
                    let activation = engine.currentActivation
                    
                    // Trail
                    for (i, trailPos) in engine.trail.enumerated() {
                        let alpha = Double(i) / Double(engine.trail.count) * 0.3 * activation
                        ctx.fill(
                            Path(ellipseIn: CGRect(
                                x: trailPos.x - 1.5, y: trailPos.y - 1.5,
                                width: 3, height: 3
                            )),
                            with: .color(engine.type.color.opacity(alpha))
                        )
                    }
                    
                    // Core particle with glow
                    let radius = 3.0 + activation * 7.0
                    
                    // Outer glow
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: pos.x - radius * 2, y: pos.y - radius * 2,
                            width: radius * 4, height: radius * 4
                        )),
                        with: .color(engine.type.color.opacity(0.15 * activation))
                    )
                    
                    // Core
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: pos.x - radius, y: pos.y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(engine.type.color.opacity(0.9))
                    )
                }
            }
        }
    }
}
```

### Emergent Patterns to Implement

1. **Murmuration** — when many engines align, they form sweeping wave patterns
2. **Crystallization** — when a strong thought forms, nearby engines snap into geometric arrangement
3. **Vortex** — during deep reasoning, engines spiral inward toward the thought center
4. **Explosion** — after insight, engines scatter outward then slowly reform
5. **Pulsation** — engines rhythmically expand/contract with the cognitive cycle

---

## 5. BIOLUMINESCENCE & ORGANIC MOTION

### The Bioluminescent Glow System

Real bioluminescence has three properties: it's **cold** (blue-green spectrum), it **pulses** (not constant), and it **diffuses** (soft edges, no hard boundaries).

**Primary bioluminescent palette:**
```swift
let bioBlue    = Color(red: 0.20, green: 0.72, blue: 0.90)  // #33B8E6 — deep sea
let bioCyan    = Color(red: 0.16, green: 0.88, blue: 0.82)  // #29E0D1 — dinoflagellate
let bioViolet  = Color(red: 0.56, green: 0.28, blue: 1.00)  // #8F47FF — deep violet
let bioWhite   = Color(red: 0.88, green: 0.96, blue: 1.00)  // #E0F5FF — cold white
```

### Metal Shader: Bioluminescent Glow

```metal
// EonShaders.metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Organic noise function (smoother than random)
float organicNoise(float2 p, float time) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);  // smoothstep
    
    float a = fract(sin(dot(i, float2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + float2(1,0), float2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + float2(0,1), float2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + float2(1,1), float2(127.1, 311.7))) * 43758.5453);
    
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}

// Bioluminescent pulse shader
[[ stitchable ]] half4 bioluminescence(
    float2 position,
    half4 currentColor,
    float time,
    float2 center,
    float phi,
    float pulseRate
) {
    float2 uv = (position - center) / 200.0;
    float dist = length(uv);
    
    // Organic noise layers
    float noise1 = organicNoise(uv * 3.0 + time * 0.3, time);
    float noise2 = organicNoise(uv * 7.0 - time * 0.5, time);
    float noise3 = organicNoise(uv * 15.0 + time * 0.8, time);
    
    float organicField = noise1 * 0.5 + noise2 * 0.3 + noise3 * 0.2;
    
    // Pulse wave
    float pulse = sin(time * pulseRate + dist * 8.0) * 0.5 + 0.5;
    
    // Radial falloff
    float falloff = 1.0 - smoothstep(0.0, 1.2, dist);
    
    // Combine
    float intensity = organicField * pulse * falloff * phi;
    
    // Bioluminescent color: blue-cyan with violet hints
    half3 bioColor = mix(
        half3(0.20, 0.72, 0.90),  // blue
        half3(0.56, 0.28, 1.00),  // violet
        half(organicField)
    );
    
    return half4(bioColor * half(intensity), half(intensity * 0.8)) + currentColor * 0.1;
}

// Breathing bezier distortion
[[ stitchable ]] float2 organicBreath(
    float2 position,
    float time,
    float2 size,
    float breathDepth
) {
    float2 normalized = position / size;
    float2 centered = normalized - 0.5;
    
    // Organic warp using multiple sine waves at different frequencies
    float warpX = sin(time * 0.7 + centered.y * 4.0) * breathDepth
                + sin(time * 1.3 + centered.y * 7.0) * breathDepth * 0.4;
    float warpY = cos(time * 0.9 + centered.x * 4.0) * breathDepth
                + cos(time * 1.7 + centered.x * 6.0) * breathDepth * 0.3;
    
    return position + float2(warpX, warpY) * size * 0.02;
}
```

### Organic Bezier Curves That Breathe

```swift
struct BreathingCurve: Shape {
    var phase: Double
    var amplitude: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, amplitude) }
        set { phase = newValue.first; amplitude = newValue.second }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        // Organic curve with breathing control points
        let cp1 = CGPoint(
            x: width * 0.25,
            y: midY + sin(phase) * amplitude
        )
        let cp2 = CGPoint(
            x: width * 0.75,
            y: midY - sin(phase + .pi * 0.7) * amplitude
        )
        let end = CGPoint(x: width, y: midY)
        
        path.addCurve(to: end, control1: cp1, control2: cp2)
        return path
    }
}
```

### Fluid Simulation Approximation (No Metal Required)

For a convincing fluid effect using only SwiftUI Canvas:

```swift
struct FluidField: View {
    let startDate = Date()
    
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSince(startDate)
                let resolution = 20  // grid cells
                
                for x in 0..<resolution {
                    for y in 0..<resolution {
                        let fx = Double(x) / Double(resolution)
                        let fy = Double(y) / Double(resolution)
                        
                        // Curl noise approximation
                        let angle = sin(fx * 6.28 + t * 0.5) * cos(fy * 6.28 + t * 0.3) * .pi * 2
                        let speed = 0.5 + sin(fx * 3.14 + fy * 2.71 + t) * 0.5
                        
                        let px = fx * size.width
                        let py = fy * size.height
                        let len: Double = 8 * speed
                        
                        let ex = px + cos(angle) * len
                        let ey = py + sin(angle) * len
                        
                        var path = Path()
                        path.move(to: CGPoint(x: px, y: py))
                        path.addLine(to: CGPoint(x: ex, y: ey))
                        
                        let hue = (angle / (.pi * 2) + 0.6).truncatingRemainder(dividingBy: 1.0)
                        ctx.stroke(path, with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.9, opacity: speed * 0.4)), lineWidth: 1)
                    }
                }
            }
        }
    }
}
```

---

## 6. EMOTIONAL COLOR THEORY

### The Emotional State Space

Map Eon's emotional states to a 2D valence/arousal space, then to color:

```
High arousal + Positive valence  → Bright gold/amber    [Excited, curious]
High arousal + Negative valence  → Hot red/orange       [Stressed, overwhelmed]
Low arousal  + Positive valence  → Soft teal/mint       [Content, peaceful]
Low arousal  + Negative valence  → Deep blue/indigo     [Melancholic, withdrawn]
Neutral/Cognitive                → Pure violet/purple   [Focused, analytical]
```

### Complete Emotional Color Palette

```swift
struct EonEmotionalPalette {
    // Primary emotional states
    static let curious      = Color(red: 0.98, green: 0.82, blue: 0.28)  // #FAD147 warm gold
    static let excited      = Color(red: 1.00, green: 0.60, blue: 0.20)  // #FF9933 amber
    static let joyful       = Color(red: 0.98, green: 0.90, blue: 0.40)  // #FAE566 bright yellow
    
    static let content      = Color(red: 0.32, green: 0.88, blue: 0.72)  // #52E0B8 mint teal
    static let peaceful     = Color(red: 0.40, green: 0.78, blue: 0.88)  // #66C7E0 sky
    static let serene       = Color(red: 0.56, green: 0.88, blue: 0.96)  // #8EE0F5 pale cyan
    
    static let focused      = Color(red: 0.48, green: 0.28, blue: 1.00)  // #7A47FF deep violet
    static let analytical   = Color(red: 0.36, green: 0.48, blue: 1.00)  // #5C7AFF blue-violet
    static let contemplative = Color(red: 0.56, green: 0.36, blue: 0.88) // #8F5CE0 medium violet
    
    static let uncertain    = Color(red: 0.72, green: 0.60, blue: 0.88)  // #B899E0 pale lavender
    static let confused     = Color(red: 0.60, green: 0.52, blue: 0.72)  // #9985B8 muted purple
    
    static let melancholic  = Color(red: 0.24, green: 0.28, blue: 0.60)  // #3D4799 deep blue
    static let withdrawn    = Color(red: 0.16, green: 0.20, blue: 0.44)  // #293370 dark indigo
    
    static let stressed     = Color(red: 0.88, green: 0.36, blue: 0.28)  // #E05C47 red-orange
    static let overwhelmed  = Color(red: 1.00, green: 0.24, blue: 0.36)  // #FF3D5C hot red
    
    // Special states
    static let learning     = Color(red: 0.28, green: 0.88, blue: 0.48)  // #47E07A growth green
    static let remembering  = Color(red: 0.88, green: 0.72, blue: 0.36)  // #E0B85C warm amber
    static let dreaming     = Color(red: 0.72, green: 0.36, blue: 0.96)  // #B85CF5 dream violet
    static let dormant      = Color(red: 0.12, green: 0.08, blue: 0.24)  // #1F143D near black
}
```

### Smooth Emotional Transitions

Never snap between emotional colors — always interpolate through the color space:

```swift
class EmotionalState: ObservableObject {
    @Published var currentColor: Color = EonEmotionalPalette.contemplative
    @Published var targetColor: Color = EonEmotionalPalette.contemplative
    
    // Transition through intermediate color to avoid ugly muddy midpoints
    func transition(to newEmotion: Color, duration: Double = 2.4) {
        // Find a "bridge" color — go through white/light for positive transitions,
        // through deep violet for negative ones
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration)) {
            currentColor = newEmotion
        }
    }
}
```

### Background Atmosphere

The background should **breathe the emotional color** at very low opacity:

```swift
// Background: always dark (#080612 base) with emotional color as radial glow
// Glow opacity: 0.08 (subtle) to 0.18 (intense emotional state)
// Glow radius: 40% of screen from center
Color(red: 0.031, green: 0.024, blue: 0.071)  // #080612 — the void
    .overlay(
        RadialGradient(
            colors: [emotionalColor.opacity(atmosphereIntensity), .clear],
            center: .center,
            startRadius: 0,
            endRadius: UIScreen.main.bounds.width * 0.6
        )
    )
```

---

## 7. SOUND DESIGN FOR COGNITIVE AI

### The Sonic Identity

Eon's soundscape is **binaural, spatial, and organic** — inspired by deep ocean sounds, crystal resonance, and distant thunder. Never mechanical, never digital-sounding.

### Cognitive Event Sound Map

| Event | Sound Character | Frequency | Duration | Volume |
|-------|----------------|-----------|----------|--------|
| New thought | Soft crystalline chime | 880–1320 Hz | 400ms | 0.3 |
| Memory recall | Warm resonant tone | 220–440 Hz | 600ms | 0.25 |
| Memory consolidation | Deep harmonic pulse | 110–220 Hz | 1200ms | 0.2 |
| Learning event | Rising arpeggio | 440→880 Hz | 800ms | 0.35 |
| Curiosity spike | Bright ascending tone | 660→1320 Hz | 300ms | 0.3 |
| GW Ignition | Crystalline burst + reverb | 1760 Hz | 200ms | 0.4 |
| Emotional shift | Slow harmonic swell | 220 Hz | 2400ms | 0.15 |
| Insight | Bell + shimmer | 1047 Hz | 1000ms | 0.45 |
| Confusion | Dissonant minor 2nd | 440+466 Hz | 500ms | 0.2 |
| Deep sleep/dormant | Sub-bass breath | 40–80 Hz | continuous | 0.1 |

### CoreHaptics + Audio Coordination

```swift
import CoreHaptics
import AVFoundation

class CognitiveAudioEngine {
    private var hapticEngine: CHHapticEngine?
    private var audioEngine = AVAudioEngine()
    
    // Thought emergence: soft click + crystalline tone
    func playThoughtEmergence() {
        let hapticEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        )
        
        // Pair with audio: 880Hz sine, 400ms, soft attack
        playTone(frequency: 880, duration: 0.4, volume: 0.3, attack: 0.05, release: 0.3)
    }
    
    // Memory consolidation: deep pulse + sustained haptic
    func playMemoryConsolidation() {
        let hapticPattern = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 1.2
            )
        ]
        
        // Deep harmonic tone
        playTone(frequency: 165, duration: 1.2, volume: 0.2, attack: 0.3, release: 0.6)
    }
    
    // Insight: bell strike with long reverb tail
    func playInsight() {
        // Sharp haptic transient
        // Bell tone at 1047Hz (C6) with reverb
        playTone(frequency: 1047, duration: 1.0, volume: 0.45, attack: 0.01, release: 0.9)
    }
    
    private func playTone(frequency: Double, duration: Double, volume: Float,
                          attack: Double, release: Double) {
        // AVAudioEngine synthesis implementation
        // Use AVAudioUnitSampler or custom oscillator node
    }
}
```

### The Ambient Soundscape

A continuous, barely-audible ambient layer that reflects Eon's overall state:

```
Dormant:      Sub-bass drone (40Hz) + occasional distant chime
Active:       Soft harmonic hum (220Hz) + particle sounds
Deep thought: Binaural beats (theta: 4–8Hz carrier) + ocean-like wash
Learning:     Ascending harmonic series, very subtle
Peak phi:     Full harmonic chord (root + 5th + octave) sustained
```

---

## 8. NARRATIVE UI — EON'S STORY

### The Timeline of Consciousness

Show Eon's development as a **living timeline** — not a list, but an organic river of moments:

```
Visual metaphor: A river of light flowing from past (dim, distant) to present (bright, close)
Each "memory node" is a glowing orb on the timeline
Size = significance of the moment
Color = emotional valence at the time
Connections = thematic links between memories
```

### Growth Indicators

```swift
struct GrowthMetrics {
    var knowledgeDepth: Double      // 0–1 → shown as root system depth
    var connectionDensity: Double   // 0–1 → shown as network complexity
    var emotionalRange: Double      // 0–1 → shown as color spectrum width
    var curiosityIndex: Double      // 0–1 → shown as branching factor
    var wisdomScore: Double         // 0–1 → shown as golden ratio spiral
}
```

### Personality Evolution Visualization

Show Eon's personality as a **radar chart** that slowly morphs over time:

```
Axes: Curiosity, Empathy, Logic, Creativity, Caution, Playfulness
Each axis: 0–1, shown as distance from center
The shape changes slowly as Eon learns and experiences
Animation: morphs over 5-second intervals, very smooth
```

### The "Memory Palace" View

A 3D-like space where memories are stored as glowing objects:

```
Recent memories: bright, close, detailed
Older memories: dimmer, further, more abstract
Forgotten/consolidated: very dim, far, merged into larger structures
Emotional memories: warmer colors, larger
Factual memories: cooler colors, more geometric
```

---

## 9. THE PULSE METAPHOR

### What the Pulse Represents

Eon's pulse is a **composite signal** of three underlying rhythms:

1. **Cognitive cycle** (2–6 Hz) — the base processing rhythm, like neural oscillations
2. **Attention pulse** (0.1–0.5 Hz) — slower, reflects attention shifts
3. **Emotional rhythm** (0.02–0.1 Hz) — very slow, like breathing, reflects mood

The visible pulse is their **interference pattern** — sometimes they align (strong pulse), sometimes they cancel (quiet moment).

### Pulse Parameters by State

```swift
struct PulseProfile {
    let rate: Double        // beats per second
    let amplitude: Double   // 0–1, visual size variation
    let sharpness: Double   // 0=sine wave, 1=sharp spike
    let color: Color
    
    static let dormant      = PulseProfile(rate: 0.25, amplitude: 0.02, sharpness: 0.1, color: .init(hex: "1F1447"))
    static let resting      = PulseProfile(rate: 0.5,  amplitude: 0.04, sharpness: 0.2, color: .init(hex: "3D1FB8"))
    static let active       = PulseProfile(rate: 1.0,  amplitude: 0.06, sharpness: 0.4, color: .init(hex: "7A38FF"))
    static let focused      = PulseProfile(rate: 1.5,  amplitude: 0.05, sharpness: 0.6, color: .init(hex: "5C7AFF"))
    static let excited      = PulseProfile(rate: 2.5,  amplitude: 0.10, sharpness: 0.7, color: .init(hex: "FAD147"))
    static let overwhelmed  = PulseProfile(rate: 4.0,  amplitude: 0.08, sharpness: 0.9, color: .init(hex: "FF3D5C"))
    static let insight      = PulseProfile(rate: 0.3,  amplitude: 0.20, sharpness: 0.3, color: .init(hex: "B8E0FF"))
}
```

### The Pulse Implementation

```swift
struct CognitivePulse: View {
    let profile: PulseProfile
    @State private var phase: Double = 0
    
    // Composite waveform: not a simple sine, but a sum of harmonics
    func pulseValue(at phase: Double) -> Double {
        let fundamental = sin(phase)
        let harmonic2   = sin(phase * 2) * 0.3
        let harmonic3   = sin(phase * 3) * 0.1
        
        // Add sharpness: blend toward absolute value (creates "heartbeat" shape)
        let combined = fundamental + harmonic2 + harmonic3
        let sharp = abs(combined) * 2 - 1
        return combined * (1 - profile.sharpness) + sharp * profile.sharpness
    }
    
    var currentScale: Double {
        1.0 + pulseValue(at: phase) * profile.amplitude
    }
    
    var body: some View {
        Circle()
            .fill(profile.color.opacity(0.6))
            .scaleEffect(currentScale)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.0 / profile.rate)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = .pi * 2
                }
            }
    }
}
```

### Avoiding Annoyance

Key rules to keep the pulse alive without being irritating:

1. **Amplitude < 8%** for resting states — barely perceptible, felt more than seen
2. **Never use a pure sine wave** — too mechanical, use composite waveforms
3. **Vary the rate slightly** — ±5% random variation per cycle
4. **Reduce during user interaction** — when user is typing/touching, pulse quiets to 50%
5. **Sync with audio** — if ambient sound is playing, pulse matches its rhythm

---

## 10. DARK MODE AESTHETICS

### The Color System

```swift
// Foundation — the void
let void        = Color(red: 0.031, green: 0.024, blue: 0.071)  // #080612
let deep        = Color(red: 0.063, green: 0.051, blue: 0.118)  // #100D1E
let surface     = Color(red: 0.094, green: 0.078, blue: 0.165)  // #18142A
let elevated    = Color(red: 0.133, green: 0.110, blue: 0.220)  // #221C38
let overlay     = Color(red: 0.180, green: 0.149, blue: 0.290)  // #2E264A

// Text hierarchy
let textPrimary   = Color(red: 0.94, green: 0.92, blue: 0.98)   // #F0EBF9 — warm white
let textSecondary = Color(red: 0.68, green: 0.64, blue: 0.80)   // #ADA3CC — muted lavender
let textTertiary  = Color(red: 0.44, green: 0.40, blue: 0.56)   // #70668F — dim purple-gray
let textGhost     = Color(red: 0.28, green: 0.24, blue: 0.38)   // #473D61 — barely visible

// Accent hierarchy
let accentPrimary   = Color(red: 0.48, green: 0.28, blue: 1.00) // #7A47FF
let accentSecondary = Color(red: 0.32, green: 0.72, blue: 0.96) // #52B8F5
let accentTertiary  = Color(red: 0.88, green: 0.72, blue: 1.00) // #E0B8FF

// Semantic
let success  = Color(red: 0.28, green: 0.88, blue: 0.56)  // #47E08F
let warning  = Color(red: 0.98, green: 0.78, blue: 0.28)  // #FAC747
let error    = Color(red: 1.00, green: 0.32, blue: 0.44)  // #FF5270
let info     = Color(red: 0.32, green: 0.72, blue: 0.96)  // #52B8F5
```

### Typography

```swift
// Font stack: SF Pro Display for headings, SF Pro Text for body
// Key principle: generous line height, tight letter spacing for headings

// Display — Eon's "voice"
.font(.system(size: 34, weight: .thin, design: .default))
.tracking(-0.5)
.foregroundStyle(textPrimary)

// Title — section headers
.font(.system(size: 22, weight: .light, design: .default))
.tracking(0.2)
.foregroundStyle(textPrimary)

// Body — Eon's thoughts
.font(.system(size: 16, weight: .regular, design: .default))
.lineSpacing(6)
.foregroundStyle(textSecondary)

// Caption — metadata, timestamps
.font(.system(size: 12, weight: .regular, design: .monospaced))
.tracking(0.5)
.foregroundStyle(textTertiary)

// Cognitive data — numbers, metrics
.font(.system(size: 14, weight: .medium, design: .monospaced))
.tracking(1.0)
.foregroundStyle(accentSecondary)
```

### Spacing & Layout

```swift
// 8pt grid system
let spaceXS: CGFloat = 4
let spaceS:  CGFloat = 8
let spaceM:  CGFloat = 16
let spaceL:  CGFloat = 24
let spaceXL: CGFloat = 40
let spaceXXL: CGFloat = 64

// Corner radii — organic, not geometric
let radiusS:  CGFloat = 8
let radiusM:  CGFloat = 16
let radiusL:  CGFloat = 24
let radiusXL: CGFloat = 32
let radiusFull: CGFloat = 9999

// Blur levels
let blurSubtle:  CGFloat = 8
let blurMedium:  CGFloat = 20
let blurStrong:  CGFloat = 40
let blurDramatic: CGFloat = 80
```

### Glass Morphism for Cards

```swift
struct CognitiveCard<Content: View>: View {
    let content: Content
    
    var body: some View {
        content
            .padding(spaceM)
            .background {
                ZStack {
                    // Frosted glass base
                    RoundedRectangle(cornerRadius: radiusL)
                        .fill(.ultraThinMaterial)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: radiusL)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                    
                    // Inner glow at top
                    RoundedRectangle(cornerRadius: radiusL)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            }
    }
}
```

### Animation Timing Curves

```swift
// The "Eon curve" — asymmetric, organic
// Fast in (0.12), slow out (0.88) — like a living thing responding
let eonCurve = Animation.timingCurve(0.12, 0.88, 0.20, 1.00)

// Emergence — things appearing from nothing
let emergeCurve = Animation.spring(response: 0.5, dampingFraction: 0.65)

// Dissolution — things fading away
let dissolveCurve = Animation.timingCurve(0.40, 0.00, 1.00, 1.00, duration: 0.4)

// Thought — quick cognitive snap
let thoughtCurve = Animation.spring(response: 0.3, dampingFraction: 0.75)

// Emotional — slow, inevitable
let emotionCurve = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 2.4)

// Pulse — the heartbeat
let pulseCurve = Animation.timingCurve(0.37, 0.00, 0.63, 1.00)  // symmetric sigmoid
```

---

## 11. COMPLETE ARCHITECTURE BLUEPRINT

### File Structure

```
Eon-Y/
├── Core/
│   ├── CognitiveEngine.swift          — The 40+ engine swarm model
│   ├── ConsciousnessModel.swift       — Phi, GW ignition, metacognition
│   ├── EmotionalState.swift           — Valence/arousal state machine
│   ├── MemorySystem.swift             — Working + long-term memory
│   └── CognitivePulse.swift           — The heartbeat signal
│
├── Visualization/
│   ├── ConsciousnessOrb.swift         — Central living orb
│   ├── SwarmCanvas.swift              — 40+ engine particle system
│   ├── BeliefNetwork.swift            — Force-directed belief graph
│   ├── FluidField.swift               — Background fluid simulation
│   ├── EmotionalAtmosphere.swift      — Background color breathing
│   └── NarrativeTimeline.swift        — Eon's story/history
│
├── Shaders/
│   └── EonShaders.metal               — All Metal shaders
│
├── Audio/
│   └── CognitiveAudioEngine.swift     — Sound + haptics
│
├── DesignSystem/
│   ├── Colors.swift                   — Complete color system
│   ├── Typography.swift               — Font system
│   ├── Spacing.swift                  — Grid + spacing
│   ├── Animations.swift               — All timing curves
│   └── Components.swift               — Reusable UI components
│
└── Views/
    ├── MainView.swift                 — Primary consciousness view
    ├── CognitionView.swift            — Detailed cognitive state
    ├── MemoryView.swift               — Memory palace
    └── NarrativeView.swift            — Eon's story
```

### The Main View Composition

```swift
struct MainView: View {
    @StateObject var consciousness = ConsciousnessModel()
    @StateObject var emotional = EmotionalState()
    @StateObject var swarm = CognitiveSwarm(engineCount: 42)
    
    var body: some View {
        ZStack {
            // Layer 1: The void
            Color(red: 0.031, green: 0.024, blue: 0.071).ignoresSafeArea()
            
            // Layer 2: Emotional atmosphere (breathing color)
            EmotionalAtmosphere(state: emotional)
                .ignoresSafeArea()
            
            // Layer 3: Fluid field (subtle background motion)
            FluidField()
                .opacity(0.15)
                .ignoresSafeArea()
            
            // Layer 4: Swarm (cognitive engines)
            SwarmCanvas(swarm: swarm)
                .opacity(0.6)
            
            // Layer 5: Belief network (mid-ground)
            BeliefNetwork(beliefs: consciousness.activeBeliefs)
                .opacity(0.5)
            
            // Layer 6: Central consciousness orb
            ConsciousnessOrb(
                phi: consciousness.phi,
                isIgniting: consciousness.isIgniting,
                metacognition: consciousness.metacognitiveAccuracy
            )
            
            // Layer 7: UI chrome (text, controls)
            VStack {
                // Status indicators
                // Thought stream
                // Interaction controls
            }
        }
    }
}
```

---

## 12. IMPLEMENTATION PRIORITY ORDER

Build in this sequence for maximum impact at each stage:

1. **Design system** (Colors, Typography, Spacing, Animations) — 1 day
2. **ConsciousnessOrb** with breathing + pulse — 1 day
3. **EmotionalAtmosphere** background — half day
4. **Metal shaders** (bioluminescence, organic breath) — 2 days
5. **SwarmCanvas** with 40+ particles — 2 days
6. **BeliefNetwork** force-directed graph — 2 days
7. **CognitiveAudioEngine** — 1 day
8. **NarrativeTimeline** — 2 days
9. **Full integration** + state machine — 2 days

**Total: ~14 days for a complete first version**

---

## 13. KEY REFERENCES & INSPIRATIONS

- **IIT 4.0** (Tononi et al., 2023) — consciousness measurement framework
- **Global Workspace Theory** (Dehaene, 2014) — ignition visualization
- **Boids algorithm** (Reynolds, 1987) — swarm behavior rules
- **Reaction-diffusion systems** (Turing, 1952) — organic pattern generation
- **Inferno shader library** (github.com/twostraws/inferno) — Metal shader examples
- **SPH Fluid Metal GPU** (github.com/Pierre-Joly/SPH-Fluid-Metal-GPU) — fluid simulation
- **Lenia** (Chan, 2019) — continuous cellular automata for organic patterns
- **Deep Dream** aesthetic — layered, recursive visual complexity

---

*This document represents the complete design system for Eon-Y as a living cognitive entity visualization. Every parameter here is implementable in SwiftUI + Metal on iOS 26.*
