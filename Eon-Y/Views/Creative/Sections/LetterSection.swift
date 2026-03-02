import SwiftUI

// MARK: - Letter Section

struct LetterSection: View {
    @ObservedObject var engine: CreativeEngine
    var brain: EonBrain
    @State private var isWriting = false
    @State private var letterSubject = ""
    @State private var letterBody = ""
    @State private var selectedLetter: EonLetter? = nil

    var body: some View {
        VStack(spacing: 14) {
            // Write new letter
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(EonColor.teal)
                    Text("Brev till Eon")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35)) { isWriting.toggle() }
                    } label: {
                        Image(systemName: isWriting ? "xmark" : "square.and.pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(EonColor.teal)
                    }
                    .buttonStyle(.plain)
                }

                Text("Skriv till Eon. Breven sparas och Eon svarar med substans och eftertanke.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                if isWriting {
                    VStack(spacing: 8) {
                        TextField("Ämne", text: $letterSubject)
                            .font(.system(size: 14, design: .rounded))
                            .padding(10)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .foregroundStyle(.white)

                        TextEditor(text: $letterBody)
                            .frame(height: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                            .font(.system(size: 13, design: .rounded))

                        HStack {
                            Spacer()
                            Button {
                                guard !letterSubject.isEmpty && !letterBody.isEmpty else { return }
                                engine.sendLetter(subject: letterSubject, body: letterBody, brain: brain)
                                letterSubject = ""
                                letterBody = ""
                                isWriting = false
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                    Text("Skicka")
                                }
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(EonColor.teal)
                                .cornerRadius(10)
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .glassMorphism(tint: EonColor.teal)

            // Composing indicator
            if engine.isComposingResponse {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(EonColor.teal)
                    Text("Eon funderar på sitt svar...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(EonColor.teal)
                    Spacer()
                }
                .padding(12)
                .glassMorphism(tint: EonColor.teal)
                .transition(.opacity.combined(with: .scale))
            }

            // Letter list
            ForEach(engine.letters) { letter in
                Button {
                    selectedLetter = selectedLetter?.id == letter.id ? nil : letter
                    if !letter.isRead { engine.markLetterAsRead(letter) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(letter.from == .eon ? EonColor.teal : EonColor.violetLight)
                                .frame(width: 8, height: 8)

                            Text(letter.from == .eon ? "Eon" : "Du")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(letter.from == .eon ? EonColor.teal : EonColor.violetLight)

                            if !letter.isRead && letter.from == .eon {
                                Text("NY")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(EonColor.crimson)
                                    .cornerRadius(4)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Text(letter.date.formatted(.relative(presentation: .named)))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }

                        Text(letter.subject)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        if selectedLetter?.id == letter.id {
                            Text(letter.body)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .padding(.top, 4)
                                .transition(.opacity)
                        } else {
                            Text(letter.body.prefix(80) + "...")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.45))
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .glassMorphism(tint: letter.from == .eon ? EonColor.teal : EonColor.violet)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
