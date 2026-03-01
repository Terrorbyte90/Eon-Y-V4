import SwiftUI

// MARK: - SessionHistoryView
// Visar alla sparade körningssessioner.
// Senaste sessionen (pågående) visas överst.
// Äldre sessioner kan läsas, kopieras och raderas.

struct SessionHistoryView: View {
    @State private var sessions: [SessionInfo] = []
    @State private var selectedSession: SessionInfo?
    @State private var sessionContent: String = ""
    @State private var isLoading = false
    @State private var copyDone = false
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: SessionInfo?

    var body: some View {
        if let selected = selectedSession {
            sessionDetailView(selected)
        } else {
            sessionListView
        }
    }

    // MARK: - Session list

    var sessionListView: some View {
        VStack(spacing: 0) {
            // Rubrik
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                Text("KÖRNINGSHISTORIK")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1.5)
                Spacer()
                Text("\(sessions.count) sessioner")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if sessions.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.15))
                    Text("Inga sparade sessioner ännu")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Loggar sparas automatiskt under körning")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.2))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear { loadSessions() }
    }

    private func sessionRow(_ session: SessionInfo) -> some View {
        Button {
            openSession(session)
        } label: {
            HStack(spacing: 12) {
                // Ikon
                ZStack {
                    Circle()
                        .fill(session.isCurrent
                              ? Color(hex: "#34D399").opacity(0.15)
                              : Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    Image(systemName: session.isCurrent ? "dot.radiowaves.left.and.right" : "doc.text")
                        .font(.system(size: 14))
                        .foregroundStyle(session.isCurrent ? Color(hex: "#34D399") : Color(hex: "#A78BFA").opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                        if session.isCurrent {
                            Text("AKTIV")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(Color(hex: "#34D399"))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color(hex: "#34D399").opacity(0.12), in: Capsule())
                        }
                    }
                    Text(session.sizeString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(session.isCurrent
                          ? Color(hex: "#34D399").opacity(0.06)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                session.isCurrent
                                    ? Color(hex: "#34D399").opacity(0.2)
                                    : Color.white.opacity(0.06),
                                lineWidth: 0.6
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !session.isCurrent {
                Button(role: .destructive) {
                    sessionToDelete = session
                    showDeleteAlert = true
                } label: {
                    Label("Radera", systemImage: "trash")
                }
            }
        }
        .alert("Radera session?", isPresented: $showDeleteAlert, presenting: sessionToDelete) { s in
            Button("Radera", role: .destructive) {
                RunSessionLogger.shared.deleteSession(s)
                loadSessions()
            }
            Button("Avbryt", role: .cancel) {}
        } message: { s in
            Text("Körningen från \(s.displayName) raderas permanent.")
        }
    }

    // MARK: - Session detail

    private func sessionDetailView(_ session: SessionInfo) -> some View {
        VStack(spacing: 0) {
            // Rubrik
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSession = nil
                        sessionContent = ""
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .padding(8)
                        .background(Color(hex: "#A78BFA").opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.displayName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                    HStack(spacing: 6) {
                        Text(session.sizeString)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                        if session.isCurrent {
                            Text("● AKTIV SESSION")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#34D399"))
                        }
                    }
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = sessionContent
                    withAnimation { copyDone = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copyDone = false }
                    }
                } label: {
                    Label(copyDone ? "✓" : "Kopiera", systemImage: copyDone ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(copyDone ? Color(hex: "#34D399") : .white.opacity(0.7))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Color(hex: "#A78BFA"))
                Spacer()
            } else {
                ScrollView {
                    Text(sessionContent)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadSessions() {
        sessions = RunSessionLogger.shared.allSessions()
    }

    private func openSession(_ session: SessionInfo) {
        isLoading = true
        selectedSession = session
        Task.detached(priority: .userInitiated) {
            let content = RunSessionLogger.shared.readSession(session)
            await MainActor.run {
                sessionContent = content
                isLoading = false
            }
        }
    }
}
