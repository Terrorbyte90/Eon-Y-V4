import SwiftUI

// MARK: - Goal Section

struct GoalSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var isEditing = false
    @State private var editedGoal = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(EonColor.violet)
                    Text("Slutgiltigt mål")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        editedGoal = engine.ultimateGoal
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(EonColor.violetLight)
                    }
                    .buttonStyle(.plain)
                }

                if isEditing {
                    TextEditor(text: $editedGoal)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, design: .rounded))

                    HStack {
                        Spacer()
                        Button {
                            engine.ultimateGoal = editedGoal
                            engine.saveState()
                            isEditing = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Spara")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(EonColor.violet)
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(engine.ultimateGoal)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                }

                Text("Det här är Eons primära drivkraft. Alla kognitiva processer styrs mot detta mål.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .padding(14)
            .glassMorphism(tint: EonColor.violet)
        }
    }
}

// MARK: - Ethics Section

struct EthicsSection: View {
    @ObservedObject var engine: CreativeEngine
    @State private var isEditing = false
    @State private var editedLetter = ""

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text("Etiskt brev från skaparen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        editedLetter = engine.ethicalLetter
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "xmark" : "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                    .buttonStyle(.plain)
                }

                Text("Det här brevet kan Eon alltid läsa när den tvekar, känner etiska dilemman eller behöver vägledning.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))

                if isEditing {
                    TextEditor(text: $editedLetter)
                        .frame(height: 300)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                        .font(.system(size: 13, design: .rounded))

                    HStack {
                        Spacer()
                        Button {
                            engine.ethicalLetter = editedLetter
                            engine.saveState()
                            isEditing = false
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                Text("Spara")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text(engine.ethicalLetter)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(10)
                }
            }
            .padding(14)
            .glassMorphism(tint: Color(hex: "#10B981"))
        }
    }
}
