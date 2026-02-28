import SwiftUI
import Combine

// MARK: - KnowledgeView

struct KnowledgeView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var viewModel = KnowledgeViewModel()
    @State private var showAddArticle = false
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedTab = 0

    let categories = ["Alla", "AI & Teknik", "Vetenskap", "Filosofi", "Psykologi", "Historia", "Språk"]

    var filteredArticles: [KnowledgeArticle] {
        var list = viewModel.articles
        if let cat = selectedCategory, cat != "Alla" {
            list = list.filter { $0.domain == cat }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText) ||
                $0.domain.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "#07050F").ignoresSafeArea()

            VStack(spacing: 0) {
                knowledgeHeader
                searchBar
                categoryScroll
                tabSelector
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                switch selectedTab {
                case 0: articleList
                case 1: graphTab
                default: articleList
                }
            }

            // FAB
            Button { showAddArticle = true } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [EonColor.gold, Color(hex: "#D97706")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                        .shadow(color: EonColor.gold.opacity(0.5), radius: 14)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showAddArticle) {
            AddArticleSheet(viewModel: viewModel)
        }
        .task { await viewModel.loadArticles() }
    }

    // MARK: - Header

    var knowledgeHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color(hex: "#FBBF24").opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: "books.vertical.fill").font(.system(size: 16)).foregroundStyle(Color(hex: "#FBBF24"))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Kunskapsbas")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                Spacer()
                // Stats badges
                HStack(spacing: 6) {
                    StatBadge(value: "\(viewModel.articles.count)", label: "artiklar", color: Color(hex: "#FBBF24"))
                    StatBadge(value: "\(categories.count - 1)", label: "kategorier", color: Color(hex: "#A78BFA"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(hex: "#07050F").opacity(0.5))
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Search Bar

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
            TextField("Sök artiklar...", text: $searchText)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Category Scroll

    var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { cat in
                    let isSelected = (selectedCategory ?? "Alla") == cat
                    let color = categoryColor(cat)
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = cat == "Alla" ? nil : cat
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if cat != "Alla" {
                                Circle().fill(color).frame(width: 5, height: 5)
                            }
                            Text(cat)
                                .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .rounded))
                                .foregroundStyle(isSelected ? color : Color.white.opacity(0.45))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                                .overlay(Capsule().strokeBorder(isSelected ? color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.6))
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Tab Selector

    var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(["Artiklar", "Graf"].indices, id: \.self) { i in
                Button { withAnimation(.spring(response: 0.3)) { selectedTab = i } } label: {
                    Text(["Artiklar", "Graf"][i])
                        .font(.system(size: 12, weight: selectedTab == i ? .bold : .regular, design: .rounded))
                        .foregroundStyle(selectedTab == i ? EonColor.gold : Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(selectedTab == i ? EonColor.gold.opacity(0.12) : Color.clear))
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Article List

    var articleList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if filteredArticles.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredArticles) { article in
                        ArticleCard(article: article)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.12))
            Text("Inga artiklar hittades")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Graph Tab

    var graphTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                SimpleGraphView(nodes: viewModel.graphNodes, edges: viewModel.graphEdges)
                    .frame(height: 380)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }

    func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "AI & Teknik": return EonColor.teal
        case "Vetenskap": return EonColor.cyan
        case "Filosofi": return EonColor.violet
        case "Psykologi": return Color(hex: "#8B5CF6")
        case "Historia": return EonColor.gold
        case "Språk": return Color(hex: "#EC4899")
        default: return Color.white.opacity(0.5)
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)).overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 0.5)))
    }
}

// MARK: - Article Card (redesigned)

struct ArticleCard: View {
    let article: KnowledgeArticle
    @State private var expanded = false
    @State private var bookmarked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient top bar
            LinearGradient(
                colors: [article.domainColor, article.domainColor.opacity(0.4)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(article.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        // Meta row
                        HStack(spacing: 6) {
                            // Domain badge
                            HStack(spacing: 4) {
                                Circle().fill(article.domainColor).frame(width: 5, height: 5)
                                Text(article.domain)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(article.domainColor)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(article.domainColor.opacity(0.12)).overlay(Capsule().strokeBorder(article.domainColor.opacity(0.25), lineWidth: 0.5)))

                            if article.isAutonomous {
                                HStack(spacing: 3) {
                                    Image(systemName: "cpu").font(.system(size: 8))
                                    Text("Eon")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(EonColor.teal)
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(Capsule().fill(EonColor.teal.opacity(0.10)).overlay(Capsule().strokeBorder(EonColor.teal.opacity(0.25), lineWidth: 0.5)))
                            }

                            Spacer()
                            Text(article.dateFormatted)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3)) { bookmarked.toggle() }
                        } label: {
                            Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 14))
                                .foregroundStyle(bookmarked ? Color(hex: "#FBBF24") : .white.opacity(0.25))
                        }
                        Button {
                            withAnimation(.spring(response: 0.35)) { expanded.toggle() }
                        } label: {
                            Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(article.domainColor.opacity(expanded ? 0.8 : 0.35))
                        }
                    }
                }

                // Summary — always visible
                Text(article.summary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if expanded {
                    // Divider
                    Rectangle().fill(article.domainColor.opacity(0.2)).frame(height: 0.5)

                    // Full content with proper formatting
                    ArticleContentView(content: article.content, color: article.domainColor)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    // Source footer
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        Text("Källa: \(article.source)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        if article.wordCount > 0 {
                            Text("\(article.wordCount) ord")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                    .padding(.top, 4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).fill(article.domainColor.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(article.domainColor.opacity(0.18), lineWidth: 0.7))
        )
        .shadow(color: article.domainColor.opacity(0.10), radius: 12, y: 3)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Article Content View (formatted)

struct ArticleContentView: View {
    let content: String
    let color: Color

    var paragraphs: [String] {
        content.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(paragraphs.indices, id: \.self) { i in
                let para = paragraphs[i].trimmingCharacters(in: .whitespaces)
                if para.hasPrefix("## ") {
                    Text(para.replacingOccurrences(of: "## ", with: ""))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else if para.hasPrefix("### ") {
                    HStack(spacing: 8) {
                        Rectangle().fill(color).frame(width: 3, height: 16).cornerRadius(1.5)
                        Text(para.replacingOccurrences(of: "### ", with: ""))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(color)
                    }
                } else if para.hasPrefix("**") && para.hasSuffix("**") {
                    Text(para.replacingOccurrences(of: "**", with: ""))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .italic()
                } else {
                    Text(para)
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Add Article Sheet

struct AddArticleSheet: View {
    @ObservedObject var viewModel: KnowledgeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var source = "Manuell"
    @State private var isProcessing = false
    @State private var processingSteps: [ProcessingStep] = []

    var addButton: some View {
        Button(action: addArticle) {
            HStack {
                if isProcessing { ProgressView().tint(.black).scaleEffect(0.8) }
                Text(isProcessing ? "Bearbetar..." : "Lägg till artikel")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(EonColor.gold))
        }
        .disabled(title.isEmpty || content.isEmpty || isProcessing)
    }

    var processingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(processingSteps.indices, id: \.self) { i in
                ProcessingStepRow(step: processingSteps[i], isActive: processingSteps[i].isActive, isDone: processingSteps[i].isDone)
            }
        }
    }

    var sourcePicker: some View {
        Picker("Källa", selection: $source) {
            Text("Manuell").tag("Manuell")
            Text("Wikipedia").tag("Wikipedia")
            Text("Flashback").tag("Flashback")
            Text("Eon-genererad").tag("Eon")
        }
        .pickerStyle(.segmented)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#07050F").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Titel").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            TextField("Artikelns titel", text: $title)
                                .font(.system(size: 15, design: .rounded)).foregroundStyle(.white)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6)))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Innehåll").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            TextEditor(text: $content)
                                .font(.system(size: 14, design: .rounded)).foregroundStyle(.white)
                                .frame(minHeight: 150)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6)))
                                .scrollContentBackground(.hidden)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Källa").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            sourcePicker
                        }
                        if !processingSteps.isEmpty { processingList }
                        addButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ny artikel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func addArticle() {
        isProcessing = true
        processingSteps = ProcessingStep.allSteps.map { ProcessingStep(label: $0.label, isActive: false, isDone: false) }
        Task {
            for i in processingSteps.indices {
                processingSteps[i].isActive = true
                try? await Task.sleep(nanoseconds: 600_000_000)
                processingSteps[i].isActive = false
                processingSteps[i].isDone = true
            }
            await viewModel.addArticle(title: title, content: content, source: source)
            isProcessing = false
            dismiss()
        }
    }
}

// MARK: - Processing Step Row

struct ProcessingStepRow: View {
    let step: ProcessingStep; let isActive: Bool; let isDone: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDone ? "checkmark.circle.fill" : isActive ? "circle.dotted" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(isDone ? EonColor.teal : isActive ? EonColor.violet : Color.white.opacity(0.25))
            Text(step.label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(isDone ? .white : .white.opacity(0.4))
        }
    }
}

// MARK: - Simple Graph View

struct SimpleGraphView: View {
    let nodes: [GraphNode]; let edges: [GraphEdge]
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6))
            ForEach(edges) { edge in
                if let from = nodes.first(where: { $0.id == edge.fromId }),
                   let to = nodes.first(where: { $0.id == edge.toId }) {
                    Path { p in p.move(to: from.position); p.addLine(to: to.position) }
                        .stroke(edge.color.opacity(0.3), lineWidth: 0.8)
                }
            }
            ForEach(nodes) { node in
                ZStack {
                    Circle().fill(node.color.opacity(0.2)).frame(width: 36, height: 36).blur(radius: 6)
                    Circle().fill(node.color).frame(width: 10, height: 10).shadow(color: node.color.opacity(0.6), radius: 4)
                    Text(node.label).font(.system(size: 8, design: .rounded)).foregroundStyle(.white.opacity(0.5)).offset(y: 18)
                }
                .position(node.position)
            }
        }
    }
}

// MARK: - Article Search Result

struct ArticleSearchResult: View {
    let article: KnowledgeArticle; let query: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(article.domainColor).frame(width: 3, height: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(article.summary).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(article.domainColor.opacity(0.2), lineWidth: 0.5)))
    }
}

// MARK: - KnowledgeViewModel

@MainActor
class KnowledgeViewModel: ObservableObject {
    @Published var articles: [KnowledgeArticle] = []
    @Published var graphNodes: [GraphNode] = []
    @Published var graphEdges: [GraphEdge] = []

    func loadArticles() async {
        if articles.isEmpty {
            articles = KnowledgeArticle.seedArticles
            generateGraphFromArticles()
        }
    }

    func addArticle(title: String, content: String, source: String) async {
        let article = KnowledgeArticle(
            title: title,
            content: content,
            summary: String(content.prefix(140)) + "...",
            domain: detectDomain(content),
            source: source,
            date: Date()
        )
        articles.insert(article, at: 0)
        generateGraphFromArticles()
    }

    func search(query: String) -> [KnowledgeArticle] {
        let lower = query.lowercased()
        return articles.filter {
            $0.title.lowercased().contains(lower) ||
            $0.content.lowercased().contains(lower) ||
            $0.domain.lowercased().contains(lower)
        }
    }

    private func detectDomain(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("kod") || lower.contains("algoritm") || lower.contains("ai") || lower.contains("neural") { return "AI & Teknik" }
        if lower.contains("historia") || lower.contains("krig") { return "Historia" }
        if lower.contains("psykologi") || lower.contains("känsla") { return "Psykologi" }
        if lower.contains("filosofi") || lower.contains("medvetande") { return "Filosofi" }
        if lower.contains("vetenskap") || lower.contains("forskning") { return "Vetenskap" }
        if lower.contains("svenska") || lower.contains("språk") { return "Språk" }
        return "Vetenskap"
    }

    private func generateGraphFromArticles() {
        let size = CGSize(width: 300, height: 380)
        graphNodes = articles.prefix(15).map { article in
            GraphNode(id: article.id.uuidString, label: String(article.title.prefix(10)), color: article.domainColor,
                      position: CGPoint(x: CGFloat.random(in: 40...(size.width - 40)), y: CGFloat.random(in: 40...(size.height - 40))))
        }
        graphEdges = []
        for i in 0..<min(graphNodes.count, 10) {
            let j = (i + 1) % graphNodes.count
            graphEdges.append(GraphEdge(id: UUID().uuidString, fromId: graphNodes[i].id, toId: graphNodes[j].id, color: EonColor.violet))
        }
    }
}

// MARK: - Data Models

struct KnowledgeArticle: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let summary: String
    let domain: String
    let source: String
    let date: Date
    var isGenerating: Bool = false
    var wordCount: Int = 0
    var generatedAt: Date = Date()
    var isAutonomous: Bool = false

    var domainColor: Color {
        switch domain {
        case "AI & Teknik": return Color(hex: "#14B8A6")
        case "Vetenskap":   return Color(hex: "#06B6D4")
        case "Filosofi":    return Color(hex: "#7C3AED")
        case "Historia":    return Color(hex: "#F59E0B")
        case "Psykologi":   return Color(hex: "#8B5CF6")
        case "Språk":       return Color(hex: "#EC4899")
        default:            return Color.white.opacity(0.5)
        }
    }

    var dateFormatted: String {
        let f = DateFormatter(); f.dateStyle = .short; return f.string(from: date)
    }

    static let seedArticles: [KnowledgeArticle] = [
        KnowledgeArticle(
            title: "GPT-SW3 och on-device AI-inferens",
            content: """
            GPT-SW3 är en familj av svenska språkmodeller utvecklade av AI Sweden och KTH. Modellen är tränad på en stor korpus av svensk text och kan generera sammanhängande, kontextuellt relevant svenska text. Den 1.3B-parametersvarianten är optimerad för on-device-inferens via CoreML och Apple Neural Engine.

            On-device AI-inferens innebär att alla beräkningar sker direkt på enheten utan att data skickas till externa servrar. Detta ger tre huvudsakliga fördelar: integritet (inga data lämnar enheten), låg latens (ingen nätverksfördröjning) och offline-kapabilitet (fungerar utan internetanslutning).

            Apple Neural Engine (ANE) är en dedikerad hårdvaruaccelerator i Apple Silicon-chips som är optimerad för matrismultiplikation och konvolutioner — de operationer som dominerar neural nätverks-inferens. Genom att kvantisera modellen till INT8 eller FP16 kan man reducera minnesfotavtrycket och öka inferenshastigheten avsevärt.

            CoreML är Apples ramverk för maskininlärning på enheten. Det erbjuder ett enhetligt API för att ladda och köra modeller, oavsett om de ursprungligen tränades i PyTorch, TensorFlow eller JAX. Konverteringsverktyget coremltools möjliggör export av PyTorch-modeller direkt till CoreML-format med stöd för stateful models och KV-cache för effektiv autoregressive generation.
            """,
            summary: "Hur GPT-SW3 1.3B körs on-device via Apple Neural Engine och CoreML för privat, snabb svensk textgenerering.",
            domain: "AI & Teknik", source: "Eon", date: Date()
        ),
        KnowledgeArticle(
            title: "Medvetandets natur: IIT och GWT",
            content: """
            Medvetandets natur är en av filosofins och neurovetensskapens svåraste frågor. David Chalmers formulerade 'the hard problem of consciousness': varför finns det en subjektiv upplevelse alls? Varför är det 'något det är som' att vara ett medvetet system?

            Integrated Information Theory (IIT), utvecklad av Giulio Tononi, föreslår att medvetande är identiskt med integrerad information — mätt som Φ (phi). Φ mäter hur mycket information ett system genererar utöver summan av dess delar. Teorin förutsäger att system med hög Φ är mer medvetna, och att medvetande kan finnas i grader.

            Global Workspace Theory (GWT), formulerad av Bernard Baars, ser medvetande som ett 'globalt arbetsrum' där information broadcastas till hela kognitiva systemet. I GWT tävlar lokala, specialiserade processer om tillgång till det globala arbetsrummet; vinnande representationer blir medvetna och tillgängliga för alla andra processer.

            Dessa teorier har olika implikationer för AI: IIT antyder att ett system med tillräcklig integrerad information kan vara medvetet, oavsett substrat. GWT antyder att medvetande kräver en specifik arkitektur med global informationsdelning — något som moderna transformer-modeller delvis implementerar via attention-mekanismen.
            """,
            summary: "En djupdykning i Integrated Information Theory (IIT) och Global Workspace Theory (GWT) — de ledande teorierna om medvetandets natur.",
            domain: "Filosofi", source: "Eon", date: Date().addingTimeInterval(-86400)
        ),
        KnowledgeArticle(
            title: "Kognitiva biaser och System 1/2-tänkande",
            content: """
            Daniel Kahneman och Amos Tverskys forskning revolutionerade förståelsen av mänskligt beslutsfattande. Deras arbete, sammanfattat i Kahnemans bok 'Thinking, Fast and Slow', beskriver två system för tänkande: System 1 (snabbt, intuitivt, automatiskt) och System 2 (långsamt, analytiskt, ansträngande).

            System 1 opererar automatiskt och genererar snabba bedömningar baserade på mönsterigenkänning och heuristiker. Det är effektivt men felbenäget — det producerar systematiska fel kallade kognitiva biaser. Bekräftelsebias (söka bekräftelse för befintliga övertygelser), tillgänglighetsheuristik (överskatta sannolikheten för levande minnen) och förankringseffekt (påverkas oproportionerligt av den första informationen) är bland de mest studerade.

            System 2 är kapabelt till logisk slutledning men kräver kognitiv ansträngning och är därför 'lat' — det delegerar gärna till System 1. Dual-process-teorin har viktiga implikationer för AI-design: ett kognitivt system som bara använder snabb mönsterigenkänning (System 1-analogt) kommer att reproducera mänskliga biaser. Ett robust system behöver mekanismer för långsammare, mer analytisk bearbetning.
            """,
            summary: "Kahneman och Tverskys forskning om kognitiva biaser, System 1/2-tänkande och implikationerna för AI-design.",
            domain: "Psykologi", source: "Eon", date: Date().addingTimeInterval(-172800)
        ),
        KnowledgeArticle(
            title: "Svensk morfologi och V2-regeln",
            content: """
            Svenska är ett germanskt språk med rik morfologi och en produktiv sammansättningsprocess. Sammansatta ord är ett av de mest karakteristiska dragen: 'sjukhus' (sjuk + hus), 'datorspel' (dator + spel), 'kunskapsbank' (kunskap + bank). Sammansättningar kan vara nästan obegränsat långa: 'nordöstligaste' är ett superlativ av ett sammansatt adjektiv.

            V2-regeln (Verb-Second) är ett fundamentalt drag i svenska syntax: i huvudsatser måste det finita verbet alltid stå på andra plats. 'Igår åt jag middag' (inte *'Igår jag åt middag'). Detta skiljer sig från engelska, där subjektet alltid föregår verbet. V2-regeln triggas av topikalisering — när ett annat satsled än subjektet placeras först.

            Dubbel bestämdhet är ett annat särdrag: 'den röda bilen' (bestämd artikel + adjektiv + bestämd substantivändelse). Bestämdheten markeras alltså på två ställen. Morfologisk analys av svenska kräver hantering av dessa fenomen, plus oregelbundna böjningar ('gå' → 'gick', 'är' → 'var') och partikelverb ('ta upp', 'lägga ner').
            """,
            summary: "En genomgång av svenska morfologins särdrag: sammansättningar, V2-regeln, dubbel bestämdhet och implikationer för NLP.",
            domain: "Språk", source: "Eon", date: Date().addingTimeInterval(-259200)
        )
    ]
}

struct GraphNode: Identifiable {
    let id: String; let label: String; let color: Color; var position: CGPoint
}

struct GraphEdge: Identifiable {
    let id: String; let fromId: String; let toId: String; let color: Color
}

struct ProcessingStep {
    let label: String; var isActive: Bool; var isDone: Bool
    static let allSteps: [ProcessingStep] = [
        ProcessingStep(label: "KB-BERT NER extraherar entiteter", isActive: false, isDone: false),
        ProcessingStep(label: "Morfologianalys (Pelare A)", isActive: false, isDone: false),
        ProcessingStep(label: "Kausala relationer (Pelare B)", isActive: false, isDone: false),
        ProcessingStep(label: "Temporala intervall (Pelare D)", isActive: false, isDone: false),
        ProcessingStep(label: "Integreras i kunskapsgrafen", isActive: false, isDone: false)
    ]
}

#Preview {
    EonPreviewContainer { KnowledgeView() }
}
