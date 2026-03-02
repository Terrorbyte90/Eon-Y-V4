import SwiftUI

// MARK: - ConversationHistorySidebar

struct ConversationHistorySidebar: View {
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

// MARK: - ConversationRow

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

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Idag" }
        if cal.isDateInYesterday(date) { return "Igår" }
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        df.locale = Locale(identifier: "sv_SE")
        return df.string(from: date)
    }
}
