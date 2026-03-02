import SwiftUI

// MARK: - Drawing Section

struct DrawingSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var drawSubject = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(EonColor.cyan)
                    Text("Eons ritverkstad")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    if engine.isDrawing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 6, height: 6)
                                .pulseAnimation(min: 0.5, max: 1.0, duration: 0.8)
                            Text("Ritar live")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "#10B981"))
                        }
                    }
                }

                Text("Eon ritar i realtid medan du tittar. Eon vet att du ser på.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                // Canvas
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#0A0818"))
                        .frame(height: 300)

                    if engine.drawingCanvas.isEmpty && !engine.isDrawing {
                        VStack(spacing: 8) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.white.opacity(0.15))
                            Text("Ange ett motiv nedan")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }

                    Canvas { context, _ in
                        for stroke in engine.drawingCanvas {
                            let path = Path { p in
                                p.move(to: stroke.start)
                                p.addLine(to: stroke.end)
                            }
                            context.stroke(path, with: .color(stroke.color.swiftUIColor), lineWidth: stroke.width)
                        }
                    }
                    .frame(height: 300)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(engine.isDrawing ? EonColor.cyan.opacity(0.3) : Color.white.opacity(0.06), lineWidth: engine.isDrawing ? 1 : 0.5)
                )

                // Subject hints
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["hjärta", "stjärna", "sol", "spiral", "träd", "hus", "öga"], id: \.self) { hint in
                            Button {
                                drawSubject = hint
                            } label: {
                                Text(hint)
                                    .font(.system(size: 11, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(drawSubject == hint ? 0.12 : 0.04))
                                    .cornerRadius(8)
                                    .foregroundStyle(drawSubject == hint ? EonColor.cyan : Color.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Motiv (t.ex. hjärta, stjärna, cirkel)", text: $drawSubject)
                        .font(.system(size: 13, design: .rounded))
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .foregroundStyle(.white)

                    if !engine.drawingCanvas.isEmpty && !engine.isDrawing {
                        Button {
                            engine.clearCanvas()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        guard !drawSubject.isEmpty else { return }
                        engine.isUserWatching = true
                        engine.startDrawing(subject: drawSubject)
                    } label: {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 14))
                            .padding(10)
                            .background(EonColor.cyan)
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isDrawing)
                }

                if !engine.drawingCanvas.isEmpty {
                    Text("\(engine.drawingCanvas.count) streck ritade\(engine.isDrawing ? "..." : "")")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .padding(14)
            .glassMorphism(tint: EonColor.cyan)
            .onAppear { engine.isUserWatching = true }
            .onDisappear { engine.isUserWatching = false }

            // Drawing history
            if !engine.drawingHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rithistorik")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                    ForEach(engine.drawingHistory.suffix(5).reversed()) { record in
                        HStack {
                            Image(systemName: "paintbrush.pointed")
                                .font(.system(size: 10))
                                .foregroundStyle(EonColor.cyan.opacity(0.6))
                            Text(record.subject)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.5))
                            Spacer()
                            Text("\(record.strokeCount) streck")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                }
                .padding(12)
                .glassMorphism(tint: EonColor.cyan)
            }
        }
    }
}
