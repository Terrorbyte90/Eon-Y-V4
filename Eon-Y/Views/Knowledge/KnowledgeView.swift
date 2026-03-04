import SwiftUI
import Combine

// MARK: - KnowledgeView v6 — Category Grid

struct KnowledgeView: View {
    @EnvironmentObject var brain: EonBrain
    @Environment(\.tabBarVisible) private var tabBarVisible
    @StateObject private var viewModel = KnowledgeViewModel()
    @ObservedObject private var gemini = GeminiArticleService.shared
    @State private var searchText = ""
    @State private var selectedCategory: KnowledgeCategory? = nil
    @State private var showAddArticle = false
    @State private var selectedArticle: KnowledgeArticle? = nil
    @State private var showGeminiSettings = false
    @State private var pulse: CGFloat = 1.0
    @State private var searchFocused = false

    // v6: Consciousness engine references for curiosity-driven learning
    @ObservedObject private var activeInference = ActiveInferenceEngine.shared
    @ObservedObject private var workspace = GlobalWorkspaceEngine.shared
    @ObservedObject private var oscillators = OscillatorBank.shared

    // Alla kategorier med metadata
    let categories = KnowledgeCategory.all

    // Artiklar filtrerade på sökning (används i sök-läge)
    var searchResults: [KnowledgeArticle] {
        guard !searchText.isEmpty else { return [] }
        return viewModel.articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText) ||
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#07050F").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#1A0050").opacity(0.5), Color.clear],
                center: .init(x: 0.5, y: 0.1),
                startRadius: 0, endRadius: 450
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                // v6: Learning consciousness strip
                learningMetricsStrip
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                if !searchText.isEmpty {
                    // Sök-läge: visa resultat direkt
                    searchResultsList
                } else if let cat = selectedCategory {
                    // Kategori-läge: visa artiklar för vald kategori
                    CategoryArticleView(
                        category: cat,
                        articles: viewModel.articles.filter { $0.domain == cat.name },
                        onBack: { withAnimation(.spring(response: 0.35)) { selectedCategory = nil } },
                        onSelect: { selectedArticle = $0 },
                        onDelete: { article in Task { await viewModel.deleteArticle(article) } }
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    // Hem-läge: kategori-rutor
                    categoryGrid
                }
            }
        }
        .sheet(isPresented: $showAddArticle) { AddArticleSheet(viewModel: viewModel) }
        .sheet(item: $selectedArticle) { ArticleDetailView(article: $0) }
        .fullScreenCover(isPresented: $showGeminiSettings) {
            GeminiSettingsView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadArticles()
            gemini.restartSchedulerIfNeeded(viewModel: viewModel)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = 1.08 }
        }
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kunskapsbas")
                    .font(.system(size: selectedCategory != nil ? 20 : 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedCategory == nil)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: "#34D399"))
                        .frame(width: 5, height: 5)
                        .shadow(color: Color(hex: "#34D399"), radius: 4)
                        .scaleEffect(pulse)
                    Text("\(viewModel.articles.count) artiklar  ·  \(categories.count) kategorier")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))

                    // v6: Curiosity drive indicator
                    if activeInference.epistemicValue > 0.3 {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                        HStack(spacing: 2) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 8))
                            Text("Nyfiken \(String(format: "%.0f%%", activeInference.epistemicValue * 100))")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.6))
                    }
                }
            }
            Spacer()

            // Tillbaka-knapp om kategori är vald
            if selectedCategory != nil {
                Button {
                    withAnimation(.spring(response: 0.35)) { selectedCategory = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Tillbaka")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
                }
            }

            // + knapp — lägg till artikel
            Button { showAddArticle = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Kugghjul — Gemini-inställningar
            Button { showGeminiSettings = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: gemini.isGenerating ? "sparkles" : "gearshape.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            GeminiSettings.load().isEnabled
                            ? Color(hex: "#A78BFA")
                            : Color.white.opacity(0.4)
                        )
                        .symbolEffect(.pulse, isActive: gemini.isGenerating)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Grön dot om aktiv
                if GeminiSettings.load().isEnabled {
                    Circle()
                        .fill(Color(hex: "#34D399"))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color(hex: "#07050F"), lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Search Bar

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(searchText.isEmpty ? Color.white.opacity(0.3) : Color(hex: "#A78BFA"))
            TextField("Sök i kunskapsbasen...", text: $searchText)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .tint(Color(hex: "#A78BFA"))
            if !searchText.isEmpty {
                Button { withAnimation { searchText = "" } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            searchText.isEmpty ? Color.white.opacity(0.1) : Color(hex: "#A78BFA").opacity(0.4),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }

    // MARK: - Learning Metrics Strip (v6)

    var learningMetricsStrip: some View {
        HStack(spacing: 0) {
            // Free energy (prediction error — lower is better)
            HStack(spacing: 3) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.6))
                Text("FE \(String(format: "%.2f", activeInference.freeEnergy))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#A78BFA").opacity(0.5))
            }

            Spacer()

            // Epistemic value (curiosity)
            HStack(spacing: 3) {
                Image(systemName: "sparkle")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#FBBF24").opacity(0.6))
                Text("Nyfikenhet \(String(format: "%.0f%%", activeInference.epistemicValue * 100))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#FBBF24").opacity(0.5))
            }

            Spacer()

            // Workspace focus (what Eon is learning about)
            HStack(spacing: 3) {
                Image(systemName: "target")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#34D399").opacity(0.6))
                Text("\(workspace.thoughtCount) tankar")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#34D399").opacity(0.5))
            }

            Spacer()

            // Neural sync
            HStack(spacing: 3) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#38BDF8").opacity(0.6))
                Text("R \(String(format: "%.0f%%", oscillators.globalSync * 100))")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#38BDF8").opacity(0.5))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.02))
        )
    }

    // MARK: - Category Grid

    var categoryGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(categories) { cat in
                    let count = viewModel.articles.filter { $0.domain == cat.name }.count
                    CategoryCard(category: cat, articleCount: count, pulse: pulse) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedCategory = cat
                        }
                    }
                }
            }
            .scrollTabBarVisibility(tabBarVisible: tabBarVisible)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 100)
        }
        .coordinateSpace(name: "scrollSpace")
        .transition(.opacity)
    }

    // MARK: - Search Results

    var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("Inga träffar för \"\(searchText)\"")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    Text("\(searchResults.count) träffar")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    ForEach(searchResults) { article in
                        ArticleRow(article: article) { selectedArticle = article }
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .transition(.opacity)
    }

    // MARK: - FAB

}

// MARK: - CategoryCard

struct CategoryCard: View {
    let category: KnowledgeCategory
    let articleCount: Int
    let pulse: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [category.color.opacity(0.16), category.color.opacity(0.07)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(category.color.opacity(0.28), lineWidth: 0.8)
                    )

                // Glow corner
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .blur(radius: 16)
                    .offset(x: 8, y: -8)
                    .clipped()

                // Content
                VStack(alignment: .center, spacing: 8) {
                    // Ikon
                    Image(systemName: category.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(category.color)
                        .shadow(color: category.color.opacity(0.5), radius: 6)

                    // Namn
                    Text(category.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    // Antal pill
                    Text("\(articleCount) art.")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(category.color.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(category.color.opacity(0.15))
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
            }
            .frame(height: 101)
        }
        .buttonStyle(EonPressButtonStyle())
    }
}

// MARK: - CategoryArticleView

struct CategoryArticleView: View {
    let category: KnowledgeCategory
    let articles: [KnowledgeArticle]
    let onBack: () -> Void
    let onSelect: (KnowledgeArticle) -> Void
    var onDelete: ((KnowledgeArticle) -> Void)? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Hero-banner
                ZStack(alignment: .bottomLeading) {
                    // Gradient bakgrund
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [category.color.opacity(0.22), category.color.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(category.color.opacity(0.25), lineWidth: 1)
                        )

                    // Stor glow
                    Circle()
                        .fill(category.color.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 20, y: -20)

                    // Stor ikon i bakgrunden
                    Image(systemName: category.icon)
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(category.color.opacity(0.12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.trailing, 20)
                        .padding(.top, 10)

                    // Text
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: category.icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(category.color)
                            .shadow(color: category.color.opacity(0.5), radius: 8)

                        Text(category.name)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(category.description)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text("\(articles.count) \(articles.count == 1 ? "artikel" : "artiklar")")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(category.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(category.color.opacity(0.15)))
                        }
                        .padding(.top, 2)
                    }
                    .padding(20)
                }
                .frame(height: 180)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if articles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(category.color.opacity(0.4))
                        Text("Inga artiklar ännu")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Eon lär sig kontinuerligt och lägger\ntill artiklar autonomt.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // Artikelkort
                    VStack(spacing: 10) {
                        ForEach(articles) { article in
                            ArticleCard(article: article) { onSelect(article) }
                                .contextMenu {
                                    if let onDelete {
                                        Button(role: .destructive) {
                                            onDelete(article)
                                        } label: {
                                            Label("Ta bort artikel", systemImage: "trash")
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if let onDelete {
                                        Button(role: .destructive) {
                                            onDelete(article)
                                        } label: {
                                            Label("Ta bort", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Spacer(minLength: 140)
            }
        }
        .coordinateSpace(name: "scrollSpace")
        .scrollDismissesKeyboard(.interactively)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }
}

// MARK: - ArticleCard (används i kategori-vy)

struct ArticleCard: View {
    let article: KnowledgeArticle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                // Färgad ikon-box
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(article.domainColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: article.isAutonomous ? "brain.head.profile" : "doc.text.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(article.domainColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.summary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(article.dateFormatted)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.2))
                        if article.isAutonomous {
                            Text("Autonom")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(article.domainColor.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(article.domainColor.opacity(0.1)))
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.top, 14)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(EonPressButtonStyle())
    }
}

// MARK: - ArticleRow

struct ArticleRow: View {
    let article: KnowledgeArticle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Domänfärg-dot
                Circle()
                    .fill(article.domainColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: article.domainColor.opacity(0.6), radius: 3)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(article.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                        if article.isAutonomous {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 8))
                                .foregroundStyle(article.domainColor.opacity(0.6))
                        }
                    }
                    Text(article.summary)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(EonPressButtonStyle())
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - ArticleDetailView

struct ArticleDetailView: View {
    let article: KnowledgeArticle
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Domain badge
                        HStack(spacing: 8) {
                            Circle().fill(article.domainColor).frame(width: 8, height: 8)
                            Text(article.domain.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(article.domainColor)
                                .tracking(1)
                            Spacer()
                            Text(article.dateFormatted)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                        }

                        Text(article.title)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text(article.summary)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(article.domainColor.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(article.domainColor.opacity(0.2), lineWidth: 1))
                            )

                        Text(article.content)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineSpacing(5)

                        // Källor
                        if !article.source.isEmpty && article.source != "Eon" {
                            VStack(alignment: .leading, spacing: 10) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.07))
                                    .frame(height: 1)

                                Text("KÄLLOR")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                                    .tracking(1.5)

                                let sources = article.source
                                    .components(separatedBy: ";")
                                    .map { $0.trimmingCharacters(in: .whitespaces) }
                                    .filter { !$0.isEmpty }

                                ForEach(Array(sources.enumerated()), id: \.offset) { _, src in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("—")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(article.domainColor.opacity(0.6))
                                        Text(src)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.45))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        // Eon-genererad badge + kognitiv snapshot
                        if article.isAutonomous {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 10))
                                        .foregroundStyle(article.domainColor)
                                    Text("Genererad autonomt av Eon")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                if !article.eonStateSnapshot.isEmpty {
                                    HStack(spacing: 5) {
                                        Image(systemName: "waveform.path.ecg")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.purple.opacity(0.5))
                                        Text(article.eonStateSnapshot)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.2))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - AddArticleSheet

struct AddArticleSheet: View {
    @ObservedObject var viewModel: KnowledgeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var source = ""
    @State private var selectedCategory: String = KnowledgeCategory.all.first?.name ?? "Historia"
    @State private var isSaving = false

    private var canSave: Bool { !title.isEmpty && !content.isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        fieldBlock("Titel", text: $title, placeholder: "Artikelns rubrik...")
                        fieldBlock("Källa", text: $source, placeholder: "Källa eller referens...")

                        // Kategorival
                        VStack(alignment: .leading, spacing: 8) {
                            Text("KATEGORI")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                                .tracking(1)
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)
                                ],
                                spacing: 8
                            ) {
                                ForEach(KnowledgeCategory.all) { cat in
                                    let isSelected = selectedCategory == cat.name
                                    Button { selectedCategory = cat.name } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(isSelected ? .white : cat.color.opacity(0.7))
                                            Text(cat.name)
                                                .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .rounded))
                                                .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 7)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? cat.color.opacity(0.25) : Color.white.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .strokeBorder(isSelected ? cat.color.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                                }
                            }
                        }

                        // Innehåll
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INNEHÅLL")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.3))
                                .tracking(1)
                            TextEditor(text: $content)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 160)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                                )
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ny artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                        .foregroundStyle(.white.opacity(0.5))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guard canSave else { return }
                        isSaving = true
                        Task {
                            await viewModel.addArticle(
                                title: title,
                                content: content,
                                source: source.isEmpty ? "Manuell" : source,
                                domain: selectedCategory
                            )
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color(hex: "#A78BFA"))
                        } else {
                            Text("Spara")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(canSave ? Color(hex: "#A78BFA") : Color.white.opacity(0.3))
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func fieldBlock(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1)
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .tint(Color(hex: "#A78BFA"))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                )
        }
    }
}

// MARK: - KnowledgeViewModel

@MainActor
class KnowledgeViewModel: ObservableObject {
    @Published var articles: [KnowledgeArticle] = []

    func loadArticles() async {
        let stored = await PersistentMemoryStore.shared.loadAllArticles(limit: 500)
        if !stored.isEmpty {
            // Slå ihop sparade artiklar med seed-artiklar (seed visas ej om de redan finns sparade)
            let storedTitles = Set(stored.map { $0.title })
            let newSeeds = KnowledgeArticle.seedArticles.filter { !storedTitles.contains($0.title) }
            articles = stored + newSeeds
        } else {
            // Första körningen — spara seed-artiklarna i databasen
            articles = KnowledgeArticle.seedArticles
            for article in articles {
                await PersistentMemoryStore.shared.saveArticle(article)
            }
        }
    }

    func addArticle(title: String, content: String, source: String) async {
        let article = KnowledgeArticle(
            title: title, content: content,
            summary: String(content.prefix(140)) + "...",
            domain: detectDomain(content), source: source, date: Date()
        )
        articles.insert(article, at: 0)
        await PersistentMemoryStore.shared.saveArticle(article)
    }

    func addArticle(title: String, content: String, source: String, domain: String) async {
        let article = KnowledgeArticle(
            title: title, content: content,
            summary: String(content.prefix(140)) + "...",
            domain: domain, source: source, date: Date()
        )
        articles.insert(article, at: 0)
        await PersistentMemoryStore.shared.saveArticle(article)
    }

    func deleteArticle(_ article: KnowledgeArticle) async {
        articles.removeAll { $0.id == article.id }
        await PersistentMemoryStore.shared.deleteArticle(title: article.title)
    }

    private func detectDomain(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("hack") || lower.contains("exploit") || lower.contains("säkerhet") || lower.contains("programmering") || lower.contains("kod") || lower.contains("python") || lower.contains("javascript") { return "Kodning & Hacking" }
        if lower.contains("ai") || lower.contains("neural") || lower.contains("maskininlärning") || lower.contains("algoritm") || lower.contains("teknik") || lower.contains("robot") { return "AI & Teknik" }
        if lower.contains("krig") || lower.contains("konflikt") || lower.contains("militär") || lower.contains("strid") || lower.contains("batalj") { return "Konflikter & Krig" }
        if lower.contains("brott") || lower.contains("mord") || lower.contains("straff") || lower.contains("kriminell") || lower.contains("rättegång") || lower.contains("fängelse") { return "Brott & Straff" }
        if lower.contains("flashback") || lower.contains("skandal") || lower.contains("kontroversiell") || lower.contains("forum") { return "Flashback" }
        if lower.contains("geologi") || lower.contains("vulkan") || lower.contains("tektonisk") || lower.contains("mineral") || lower.contains("jordskorpa") || lower.contains("berg") { return "Geologi" }
        if lower.contains("uppfinning") || lower.contains("innovation") || lower.contains("patent") || lower.contains("uppfinnare") || lower.contains("discovery") { return "Uppfinningar" }
        if lower.contains("historia") || lower.contains("antik") || lower.contains("arkeologi") || lower.contains("civilisation") || lower.contains("forntid") { return "Historia" }
        if lower.contains("filosofi") || lower.contains("medvetande") || lower.contains("etik") || lower.contains("moral") || lower.contains("existens") { return "Filosofi" }
        if lower.contains("psykologi") || lower.contains("beteende") || lower.contains("bias") || lower.contains("kognition") || lower.contains("trauma") { return "Psykologi" }
        if lower.contains("hälsa") || lower.contains("medicin") || lower.contains("sjukdom") || lower.contains("kropp") || lower.contains("träning") || lower.contains("kost") { return "Hälsa" }
        if lower.contains("människa") || lower.contains("evolution") || lower.contains("biologi") || lower.contains("dna") || lower.contains("anatomi") { return "Människan" }
        if lower.contains("svenska") || lower.contains("språk") || lower.contains("grammatik") || lower.contains("morfologi") || lower.contains("lingvistik") { return "Språk" }
        if lower.contains("land") || lower.contains("kultur") || lower.contains("geopolitik") || lower.contains("nation") || lower.contains("världen") { return "Världen" }
        return "AI & Teknik"
    }
}

// MARK: - KnowledgeCategory

struct KnowledgeCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let description: String

    static let all: [KnowledgeCategory] = [
        KnowledgeCategory(
            name: "AI & Teknik",
            icon: "cpu.fill",
            color: Color(hex: "#34D399"),
            description: "Maskininlärning, neurala nätverk och framtidens teknik"
        ),
        KnowledgeCategory(
            name: "Kodning & Hacking",
            icon: "terminal.fill",
            color: Color(hex: "#22D3EE"),
            description: "Programmering, säkerhet och exploits"
        ),
        KnowledgeCategory(
            name: "Historia",
            icon: "building.columns.fill",
            color: Color(hex: "#FBBF24"),
            description: "Civilisationer, händelser och kulturarv"
        ),
        KnowledgeCategory(
            name: "Uppfinningar",
            icon: "lightbulb.fill",
            color: Color(hex: "#FCD34D"),
            description: "Upptäckter och innovationer som förändrat världen"
        ),
        KnowledgeCategory(
            name: "Geologi",
            icon: "mountain.2.fill",
            color: Color(hex: "#A78BFA"),
            description: "Jordens struktur, vulkaner och tektoniska plattor"
        ),
        KnowledgeCategory(
            name: "Filosofi",
            icon: "brain.head.profile",
            color: Color(hex: "#818CF8"),
            description: "Medvetande, etik och existentiella frågor"
        ),
        KnowledgeCategory(
            name: "Språk",
            icon: "text.bubble.fill",
            color: Color(hex: "#FB923C"),
            description: "Lingvistik, morfologi och semantik"
        ),
        KnowledgeCategory(
            name: "Människan",
            icon: "figure.stand",
            color: Color(hex: "#F472B6"),
            description: "Biologi, evolution och mänsklig natur"
        ),
        KnowledgeCategory(
            name: "Hälsa",
            icon: "heart.fill",
            color: Color(hex: "#F87171"),
            description: "Medicin, kropp och välmående"
        ),
        KnowledgeCategory(
            name: "Psykologi",
            icon: "theatermasks.fill",
            color: Color(hex: "#C084FC"),
            description: "Kognition, beteende och det mänskliga sinnet"
        ),
        KnowledgeCategory(
            name: "Världen",
            icon: "globe.europe.africa.fill",
            color: Color(hex: "#38BDF8"),
            description: "Länder, kulturer och geopolitik"
        ),
        KnowledgeCategory(
            name: "Konflikter & Krig",
            icon: "shield.fill",
            color: Color(hex: "#EF4444"),
            description: "Krig, konflikter och militär historia"
        ),
        KnowledgeCategory(
            name: "Brott & Straff",
            icon: "lock.fill",
            color: Color(hex: "#F97316"),
            description: "Kriminologi, rättsväsende och verkliga brott"
        ),
        KnowledgeCategory(
            name: "Flashback",
            icon: "flame.fill",
            color: Color(hex: "#DC2626"),
            description: "Kontroverser, skandaler och det osagda"
        ),
        KnowledgeCategory(
            name: "Eon",
            icon: "sparkles",
            color: Color(hex: "#7C3AED"),
            description: "Artiklar skrivna och tänkta av Eon"
        ),
    ]
}

// MARK: - Data Models

struct KnowledgeArticle: Identifiable {
    let id: UUID
    let title: String; let content: String; let summary: String
    let domain: String; let source: String; let date: Date
    var isGenerating: Bool = false; var wordCount: Int = 0
    var generatedAt: Date = Date(); var isAutonomous: Bool = false
    /// Eons kognitiva tillstånd vid skrivtillfället (Φ-värde, stadium etc.) — visas i ArticleDetailView
    var eonStateSnapshot: String = ""

    init(id: UUID = UUID(), title: String, content: String, summary: String,
         domain: String, source: String, date: Date, isAutonomous: Bool = false,
         eonStateSnapshot: String = "") {
        self.id = id
        self.title = title; self.content = content; self.summary = summary
        self.domain = domain; self.source = source; self.date = date
        self.isAutonomous = isAutonomous
        self.eonStateSnapshot = eonStateSnapshot
    }

    var domainColor: Color {
        KnowledgeCategory.all.first { $0.name == domain }?.color ?? Color.white.opacity(0.4)
    }

    var dateFormatted: String {
        let f = DateFormatter(); f.dateStyle = .short; return f.string(from: date)
    }

    /// Seed-artiklar hämtas från KnowledgeArticleLibrary.swift — lägg till nya artiklar där.
    static let seedArticles: [KnowledgeArticle] = KnowledgeArticle.library
}

#Preview {
    KnowledgeView()
        .environmentObject(EonBrain.shared)
}
