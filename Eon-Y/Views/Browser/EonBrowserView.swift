import SwiftUI
import WebKit

// MARK: - EonBrowserView: Autonomous Safari-like browser

struct EonBrowserView: View {
    @EnvironmentObject var brain: EonBrain
    @StateObject private var agent = EonBrowserAgent()
    @State private var urlText = ""
    @State private var isEditingURL = false
    @State private var showGoalSheet = true
    @State private var showActivityLog = true
    @State private var webView: WKWebView?
    @State private var webViewProgress: Double = 0
    @State private var isWebViewLoading = false
    @State private var loadError: String?
    @FocusState private var urlFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let accentColor = Color(hex: "#06B6D4")

    var body: some View {
        ZStack {
            EonColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                browserToolbar
                webViewProgressBar

                ZStack(alignment: .bottom) {
                    WebViewContainer(
                        agent: agent,
                        onWebViewCreated: { wv in
                            webView = wv
                            setupProgressObserver(wv)
                        },
                        onError: { errorMsg in
                            withAnimation { loadError = errorMsg }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                withAnimation { if loadError == errorMsg { loadError = nil } }
                            }
                        }
                    )
                    .allowsHitTesting(!agent.isBrowsing || agent.userTookOver)

                    overlayStack
                }
            }

            if let error = loadError {
                errorToast(error)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: agent.currentURL) { _, newURL in
            if !isEditingURL, let url = newURL {
                urlText = url.absoluteString
            }
        }
    }

    private var overlayStack: some View {
        VStack(spacing: 8) {
            Spacer()

            if agent.isBrowsing && !agent.userTookOver {
                takeOverButton
            }

            if agent.isBrowsing && agent.userTookOver {
                handBackButton
            }

            if agent.isBrowsing && !agent.userTookOver {
                activityPill
            }

            if showGoalSheet && !agent.isBrowsing && agent.result == nil {
                goalSheet
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let result = agent.result {
                resultSheet(result)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 8)
    }

    private func setupProgressObserver(_ wv: WKWebView) {
        let kvoProgress = wv.observe(\.estimatedProgress, options: .new) { webView, change in
            Task { @MainActor in
                withAnimation(.linear(duration: 0.15)) {
                    webViewProgress = change.newValue ?? 0
                }
            }
        }
        let kvoLoading = wv.observe(\.isLoading, options: .new) { webView, change in
            Task { @MainActor in
                isWebViewLoading = change.newValue ?? false
                if !(change.newValue ?? false) {
                    loadError = nil
                }
            }
        }
        // Store to prevent deallocation
        objc_setAssociatedObject(wv, "progressKVO", kvoProgress, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(wv, "loadingKVO", kvoLoading, .OBJC_ASSOCIATION_RETAIN)
    }

    private func errorToast(_ message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#EF4444"))
                Text(message)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                Spacer()
                Button { withAnimation { loadError = nil } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#7F1D1D").opacity(0.9))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#EF4444").opacity(0.3), lineWidth: 0.6))
            )
            .padding(.horizontal, 16)
            .padding(.top, 80)
            Spacer()
        }
    }

    private func navigateToURL() {
        var input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isEditingURL = false
        urlFieldFocused = false

        if !input.hasPrefix("http://") && !input.hasPrefix("https://") {
            if input.contains(".") && !input.contains(" ") {
                input = "https://\(input)"
            } else {
                let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
                input = "https://www.google.com/search?q=\(encoded)&hl=sv"
            }
        }

        if let url = URL(string: input) {
            webView?.load(URLRequest(url: url))
        }
    }

    // MARK: - Take Over / Hand Back buttons

    private var takeOverButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { agent.takeOver() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Ta över")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: "#7C3AED").opacity(0.7))
                    .overlay(Capsule().strokeBorder(Color(hex: "#A78BFA").opacity(0.5), lineWidth: 0.7))
                    .shadow(color: Color(hex: "#7C3AED").opacity(0.4), radius: 12, y: 4)
            )
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var handBackButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { agent.handBack() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Lämna tillbaka till Eon")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.7))
                    .overlay(Capsule().strokeBorder(accentColor.opacity(0.5), lineWidth: 0.7))
                    .shadow(color: accentColor.opacity(0.4), radius: 12, y: 4)
            )
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Activity Pill (compact, non-blocking)

    private var activityPill: some View {
        Group {
            if showActivityLog {
                activityLogExpanded
            } else {
                activityLogCollapsed
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Browser Toolbar (Safari-like)

    private var browserToolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                toolbarURLBar

                toolbarActions
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(hex: "#0F0B1E").opacity(0.95)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
            )
        }
    }

    private var toolbarURLBar: some View {
        HStack(spacing: 6) {
            if agent.isBrowsing {
                ProgressView().tint(accentColor).scaleEffect(0.6)
            } else if isWebViewLoading {
                ProgressView().tint(.white.opacity(0.5)).scaleEffect(0.6)
            } else {
                Image(systemName: urlText.hasPrefix("https") ? "lock.fill" : "globe")
                    .font(.system(size: 10))
                    .foregroundStyle(urlText.hasPrefix("https") ? Color(hex: "#34D399") : .white.opacity(0.35))
            }

            if isEditingURL {
                TextField("Sök eller ange adress", text: $urlText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .focused($urlFieldFocused)
                    .onSubmit { navigateToURL() }
            } else {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isEditingURL = true
                        urlFieldFocused = true
                    }
            }

            Spacer(minLength: 0)

            if isEditingURL {
                Button {
                    isEditingURL = false
                    urlFieldFocused = false
                    if let url = agent.currentURL { urlText = url.absoluteString }
                } label: {
                    Text("Avbryt")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(accentColor)
                }
            } else if agent.isBrowsing {
                Button { agent.stopBrowsing() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else if isWebViewLoading {
                Button { webView?.stopLoading() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Button { webView?.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isEditingURL ? Color.white.opacity(0.1) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isEditingURL ? accentColor.opacity(0.5) :
                            agent.isBrowsing ? accentColor.opacity(0.3) : Color.white.opacity(0.08),
                            lineWidth: 0.6
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isEditingURL)
    }

    private var displayTitle: String {
        if agent.isBrowsing { return agent.statusLabel }
        if !agent.pageTitle.isEmpty { return agent.pageTitle }
        if !urlText.isEmpty {
            if let url = URL(string: urlText), let host = url.host {
                return host.replacingOccurrences(of: "www.", with: "")
            }
        }
        return "Sök eller ange adress"
    }

    private var toolbarActions: some View {
        HStack(spacing: 14) {
            Button { webView?.goBack() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button { webView?.goForward() } label: {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button {
                if agent.result != nil {
                    agent.result = nil
                    showGoalSheet = true
                } else {
                    withAnimation(.spring(response: 0.3)) { showGoalSheet.toggle() }
                }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accentColor)
            }
        }
    }

    // MARK: - Progress Bar (uses WKWebView estimatedProgress when manually browsing)

    private var webViewProgressBar: some View {
        GeometryReader { geo in
            let showAgentProgress = agent.isBrowsing
            let showWebProgress = isWebViewLoading && !agent.isBrowsing
            let fraction = showAgentProgress ? agent.progress : webViewProgress

            if showAgentProgress || showWebProgress {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.03))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: showAgentProgress
                                    ? [accentColor.opacity(0.6), accentColor, accentColor.opacity(0.6)]
                                    : [Color.white.opacity(0.3), Color.white.opacity(0.5), Color.white.opacity(0.3)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.easeInOut(duration: 0.3), value: fraction)
                }
            }
        }
        .frame(height: (agent.isBrowsing || isWebViewLoading) ? 2.5 : 0)
        .animation(.easeInOut(duration: 0.2), value: agent.isBrowsing)
        .animation(.easeInOut(duration: 0.2), value: isWebViewLoading)
    }

    // MARK: - Goal Sheet

    private var goalSheet: some View {
        VStack(spacing: 16) {
            goalHeader
            goalModePicker
            if agent.mode == .article { articleDomainPicker }
            goalTextInput
            goalStartButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
                .shadow(color: .black.opacity(0.4), radius: 30, y: -10)
        )
    }

    private var goalHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [accentColor.opacity(0.4), Color.clear], center: .center, startRadius: 0, endRadius: 24))
                    .frame(width: 44, height: 44)
                Image(systemName: "globe.desk.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Eons Webbläsare")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Beskriv vad du vill att Eon ska hitta eller undersöka")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
    }

    private var goalModePicker: some View {
        HStack(spacing: 8) {
            ForEach(BrowseMode.allCases, id: \.self) { m in
                goalModeButton(m)
            }
            Spacer()
        }
    }

    private func goalModeButton(_ m: BrowseMode) -> some View {
        let isSelected = agent.mode == m
        return Button {
            withAnimation(.spring(response: 0.3)) { agent.mode = m }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: m == .research ? "magnifyingglass" : "doc.text.fill")
                    .font(.system(size: 11))
                Text(m.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .foregroundStyle(isSelected ? accentColor : .white.opacity(0.4))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? accentColor.opacity(0.15) : Color.white.opacity(0.04))
                    .overlay(Capsule().strokeBorder(isSelected ? accentColor.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.6))
            )
        }
    }

    private var goalTextInput: some View {
        let placeholder = agent.mode == .research
            ? "T.ex. \"Hitta bästa gaming PC för billigast peng\""
            : "T.ex. \"Undersök självmedvetenhet hos AI-system\""
        return ZStack(alignment: .topLeading) {
            if agent.goal.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(14)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $agent.goal)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(10)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6)
                )
        )
    }

    private var goalStartButton: some View {
        let isEmpty = agent.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let label = agent.mode == .research ? "Starta forskning" : "Skapa artikel"
        return Button {
            showGoalSheet = false
            agent.startBrowsing()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.4), accentColor.opacity(0.25)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accentColor.opacity(0.5), lineWidth: 0.7)
                    )
            )
        }
        .disabled(isEmpty)
        .opacity(isEmpty ? 0.4 : 1)
    }

    // MARK: - Article Domain Picker

    private let domains = ["AI & Teknik", "Vetenskap", "Filosofi", "Psykologi", "Matematik",
                           "Historia", "Språk", "Kultur", "Natur", "Samhälle", "Hälsa"]

    private var articleDomainPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(domains, id: \.self) { domain in
                    Button {
                        agent.articleDomain = domain
                    } label: {
                        Text(domain)
                            .font(.system(size: 10, weight: agent.articleDomain == domain ? .semibold : .regular, design: .rounded))
                            .foregroundStyle(agent.articleDomain == domain ? accentColor : .white.opacity(0.4))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(agent.articleDomain == domain ? accentColor.opacity(0.12) : Color.white.opacity(0.03))
                                    .overlay(Capsule().strokeBorder(agent.articleDomain == domain ? accentColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 0.5))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Activity Log (expanded / collapsed)

    private var activityLogExpanded: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .modifier(PulseModifier())
                    Text("EON SURFER")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(accentColor.opacity(0.7))
                        .tracking(2)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { showActivityLog = false }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(agent.steps) { step in
                            stepRow(step).id(step.id)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
                .frame(maxHeight: 160)
                .onChange(of: agent.steps.count) { _, _ in
                    if let last = agent.steps.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.15), lineWidth: 0.6)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var activityLogCollapsed: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { showActivityLog = true }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(accentColor).frame(width: 6, height: 6).modifier(PulseModifier())
                Text(agent.steps.last?.message ?? agent.statusLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(accentColor.opacity(0.15), lineWidth: 0.5))
            )
        }
    }

    private func stepRow(_ step: BrowseStep) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.icon)
                .font(.system(size: 11))
                .foregroundStyle(stepColor(step.type))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(step.timestamp.formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private func stepColor(_ type: BrowseStep.StepType) -> Color {
        switch type {
        case .thinking:   return Color(hex: "#A78BFA")
        case .navigating: return accentColor
        case .reading:    return Color(hex: "#34D399")
        case .extracting: return Color(hex: "#FBBF24")
        case .writing:    return Color(hex: "#F472B6")
        case .done:       return Color(hex: "#34D399")
        case .error:      return Color(hex: "#EF4444")
        }
    }

    // MARK: - Result Sheet (translucent bottom sheet, web visible behind)

    private func resultSheet(_ result: BrowseResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            resultSheetHeader(result)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(result.summary)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    resultSourcesList(result)
                }
            }
            .frame(maxHeight: 200)

            resultSheetButtons(result)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color(hex: "#34D399").opacity(0.2), lineWidth: 0.6)
                )
        )
    }

    private func resultSheetHeader(_ result: BrowseResult) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color(hex: "#34D399").opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: result.articleDomain != nil ? "doc.text.fill" : "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#34D399"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                resultSheetSubtitle(result)
            }
            Spacer()
            Button { UIPasteboard.general.string = result.summary } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func resultSheetSubtitle(_ result: BrowseResult) -> some View {
        Group {
            if let domain = result.articleDomain {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill").font(.system(size: 7))
                    Text("Sparad i \(domain)").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color(hex: "#34D399"))
            } else {
                Text("\(result.sources.count) källor")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func resultSourcesList(_ result: BrowseResult) -> some View {
        Group {
            if !result.sources.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KÄLLOR")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1)
                    ForEach(result.sources.prefix(4), id: \.self) { source in
                        HStack(spacing: 5) {
                            Image(systemName: "link").font(.system(size: 7)).foregroundStyle(accentColor.opacity(0.5))
                            Text(source)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(accentColor.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func resultSheetButtons(_ result: BrowseResult) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    agent.result = nil
                    showGoalSheet = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 11))
                    Text("Ny sökning").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accentColor.opacity(0.3), lineWidth: 0.6))
                )
            }

            Button { dismiss() } label: {
                Text("Stäng")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.6))
                    )
            }
        }
    }
}

// MARK: - PulseModifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - WKWebView Container

struct WebViewContainer: UIViewRepresentable {
    let agent: EonBrowserAgent
    let onWebViewCreated: (WKWebView) -> Void
    var onError: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(agent: agent)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "eonExtract")

        let extractScript = WKUserScript(source: Self.contentExtractionJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(extractScript)

        let cookieScript = WKUserScript(source: Self.cookieBannerDismissJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(cookieScript)

        let helpersScript = WKUserScript(source: Self.browserHelpersJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(helpersScript)

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(EonColor.background)
        webView.scrollView.backgroundColor = UIColor(EonColor.background)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        context.coordinator.webView = webView
        context.coordinator.onError = onError
        onWebViewCreated(webView)

        agent.onNavigate = { url in
            webView.load(URLRequest(url: url))
        }

        agent.onExtractContent = { completion in
            context.coordinator.pendingExtraction = completion
            webView.evaluateJavaScript("window.eonExtractContent()") { _, error in
                if error != nil {
                    let fallback = PageContent(url: webView.url?.absoluteString ?? "", title: webView.title ?? "", bodyText: "", headings: [], links: [], metaDescription: "", tableData: [], listItems: [])
                    if context.coordinator.pendingExtraction != nil {
                        context.coordinator.pendingExtraction?(fallback)
                        context.coordinator.pendingExtraction = nil
                    }
                }
            }
        }

        agent.onRunJS = { script, completion in
            webView.evaluateJavaScript(script) { result, error in
                if let str = result as? String {
                    completion(str)
                } else if let bool = result as? Bool {
                    completion(bool ? "true" : "false")
                } else if let num = result as? NSNumber {
                    completion(num.stringValue)
                } else {
                    completion(nil)
                }
            }
        }

        agent.onGoBack = {
            webView.goBack()
        }

        let startURL = URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: startURL))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Content Extraction JavaScript

    static let contentExtractionJS = """
    window.eonExtractContent = function() {
        try {
            var title = document.title || '';
            var url = window.location.href || '';

            var meta = '';
            var metaTag = document.querySelector('meta[name="description"]') ||
                          document.querySelector('meta[property="og:description"]');
            if (metaTag) meta = metaTag.getAttribute('content') || '';

            var body = '';

            var contentEl = document.querySelector('article') ||
                            document.querySelector('[role="main"]') ||
                            document.querySelector('main') ||
                            document.querySelector('.post-content') ||
                            document.querySelector('.entry-content') ||
                            document.querySelector('.article-body') ||
                            document.querySelector('.mw-parser-output') ||
                            document.querySelector('#mw-content-text') ||
                            document.querySelector('.content') ||
                            document.querySelector('#content');

            if (contentEl && contentEl.innerText.trim().length > 100) {
                body = contentEl.innerText;
            }

            if (body.length < 100) {
                var allDivs = document.querySelectorAll('div, section');
                var bestDiv = null;
                var bestLen = 0;
                for (var d = 0; d < Math.min(allDivs.length, 80); d++) {
                    var divText = allDivs[d].innerText || '';
                    if (divText.length > bestLen && divText.length < 50000) {
                        var childDivs = allDivs[d].querySelectorAll('div').length;
                        if (childDivs < 15) {
                            bestLen = divText.length;
                            bestDiv = allDivs[d];
                        }
                    }
                }
                if (bestDiv && bestLen > 100) {
                    body = bestDiv.innerText;
                }
            }

            if (body.length < 100) {
                var paragraphs = document.querySelectorAll('p');
                var pTexts = [];
                for (var p = 0; p < paragraphs.length; p++) {
                    var pText = (paragraphs[p].innerText || '').trim();
                    if (pText.length > 15) pTexts.push(pText);
                }
                if (pTexts.length > 0) body = pTexts.join('\\n\\n');
            }

            if (body.length < 50) {
                body = document.body ? (document.body.innerText || '') : '';
            }

            // Also try aria-label and alt attributes for richer context
            if (body.length < 200) {
                var altTexts = [];
                var imgs = document.querySelectorAll('img[alt]');
                for (var im = 0; im < Math.min(imgs.length, 20); im++) {
                    var alt = (imgs[im].alt || '').trim();
                    if (alt.length > 10) altTexts.push(alt);
                }
                if (altTexts.length > 0) body += '\\n' + altTexts.join('. ');
            }

            body = body.substring(0, 10000);

            var headings = [];
            var hTags = document.querySelectorAll('h1, h2, h3, h4');
            for (var h = 0; h < Math.min(hTags.length, 20); h++) {
                var hText = (hTags[h].innerText || '').trim();
                if (hText.length > 2 && hText.length < 150) headings.push(hText);
            }

            var links = [];
            var seenHrefs = {};
            var linkSources = contentEl ? contentEl.querySelectorAll('a[href]') : [];
            if (linkSources.length < 5) {
                linkSources = document.querySelectorAll('a[href]');
            }

            for (var i = 0; i < Math.min(linkSources.length, 80); i++) {
                var a = linkSources[i];
                var text = (a.innerText || a.getAttribute('aria-label') || '').trim().substring(0, 120);
                var href = a.href || '';

                if (text.length < 3 || !href.startsWith('http')) continue;
                if (seenHrefs[href]) continue;
                seenHrefs[href] = true;

                var parent = a.closest('nav, footer, header, aside, [role="navigation"], [role="banner"]');
                if (parent && contentEl && !contentEl.contains(a)) continue;

                links.push({text: text, href: href});
                if (links.length >= 50) break;
            }

            var tableData = [];
            var tables = document.querySelectorAll('table');
            for (var t = 0; t < Math.min(tables.length, 5); t++) {
                var rows = tables[t].querySelectorAll('tr');
                for (var r = 0; r < Math.min(rows.length, 12); r++) {
                    var cells = rows[r].querySelectorAll('td, th');
                    var rowText = [];
                    for (var c = 0; c < cells.length; c++) {
                        rowText.push((cells[c].innerText || '').trim().substring(0, 60));
                    }
                    if (rowText.length > 0) tableData.push(rowText.join(' | '));
                }
            }

            var listItems = [];
            var lists = (contentEl || document).querySelectorAll('ul, ol');
            for (var l = 0; l < Math.min(lists.length, 8); l++) {
                var items = lists[l].querySelectorAll('li');
                for (var li = 0; li < Math.min(items.length, 15); li++) {
                    var liText = (items[li].innerText || '').trim().substring(0, 200);
                    if (liText.length > 5) listItems.push(liText);
                }
            }

            var payload = JSON.stringify({
                title: title,
                url: url,
                body: body,
                meta: meta,
                headings: headings,
                links: links,
                tableData: tableData,
                listItems: listItems
            });

            window.webkit.messageHandlers.eonExtract.postMessage(payload);
        } catch(e) {
            var fallback = JSON.stringify({
                title: document.title || '',
                url: window.location.href || '',
                body: (document.body ? document.body.innerText : '').substring(0, 5000),
                meta: '',
                headings: [],
                links: [],
                tableData: [],
                listItems: []
            });
            window.webkit.messageHandlers.eonExtract.postMessage(fallback);
        }
    };
    """

    // MARK: - Browser Helper Functions (click, scroll, search results, overlays, expand)

    static let browserHelpersJS = """
    window.eonClickElement = function(selector) {
        try {
            var el = document.querySelector(selector);
            if (!el) return 'false';
            el.scrollIntoView({behavior: 'smooth', block: 'center'});
            setTimeout(function() { el.click(); }, 200);
            return 'true';
        } catch(e) { return 'false'; }
    };

    window.eonScrollDown = function() {
        window.scrollBy({top: window.innerHeight * 0.85, behavior: 'smooth'});
        return 'done';
    };

    window.eonDismissOverlays = function() {
        var removed = 0;

        // Remove fixed/sticky overlays (modals, popups, banners)
        var candidates = document.querySelectorAll(
            '[class*="modal"], [class*="popup"], [class*="overlay"], [class*="banner"], ' +
            '[class*="dialog"], [class*="lightbox"], [class*="paywall"], [class*="subscribe"], ' +
            '[class*="newsletter"], [role="dialog"], [role="alertdialog"]'
        );
        for (var i = 0; i < candidates.length; i++) {
            var style = window.getComputedStyle(candidates[i]);
            if (style.position === 'fixed' || style.position === 'sticky' || style.zIndex > 999) {
                candidates[i].style.display = 'none';
                removed++;
            }
        }

        // Click close/dismiss buttons
        var closeSelectors = [
            'button[aria-label="Close"]', 'button[aria-label="Stäng"]',
            'button[aria-label="close"]', 'button[aria-label="Dismiss"]',
            '.close-button', '.modal-close', '.popup-close',
            '[class*="dismiss"]', '[class*="close-btn"]', '[class*="close-icon"]',
            'button.close', '[data-dismiss]', '[data-action="close"]',
            '.icon-close', '[class*="CloseButton"]'
        ];
        for (var s = 0; s < closeSelectors.length; s++) {
            try {
                var btns = document.querySelectorAll(closeSelectors[s]);
                for (var b = 0; b < btns.length; b++) {
                    if (btns[b].offsetParent !== null) { btns[b].click(); removed++; }
                }
            } catch(e) {}
        }

        // Remove body scroll lock
        document.body.style.overflow = 'auto';
        document.body.style.position = '';
        document.documentElement.style.overflow = 'auto';

        // Remove overlay backdrop elements
        var backdrops = document.querySelectorAll(
            '[class*="backdrop"], [class*="mask"], [class*="scrim"]'
        );
        for (var bd = 0; bd < backdrops.length; bd++) {
            var bdStyle = window.getComputedStyle(backdrops[bd]);
            if (bdStyle.position === 'fixed') { backdrops[bd].style.display = 'none'; removed++; }
        }

        return String(removed);
    };

    window.eonExpandContent = function() {
        var expandWords = [
            'read more', 'show more', 'visa mer', 'läs mer', 'fler', 'expand',
            'see more', 'continue reading', 'fortsätt läsa', 'mer', 'see all',
            'visa alla', 'load more', 'ladda fler', 'view more', 'show all',
            'se alla', 'full article', 'hela artikeln'
        ];
        var buttons = document.querySelectorAll('button, a, [role="button"], span[onclick], div[onclick]');
        var clicked = 0;
        for (var i = 0; i < buttons.length && clicked < 5; i++) {
            var txt = (buttons[i].innerText || '').trim().toLowerCase();
            if (txt.length > 0 && txt.length < 40) {
                for (var w = 0; w < expandWords.length; w++) {
                    if (txt.indexOf(expandWords[w]) >= 0 && buttons[i].offsetParent !== null) {
                        try { buttons[i].click(); clicked++; } catch(e) {}
                        break;
                    }
                }
            }
        }

        // Also expand <details> elements
        var details = document.querySelectorAll('details:not([open])');
        for (var d = 0; d < Math.min(details.length, 5); d++) {
            details[d].setAttribute('open', '');
            clicked++;
        }

        return String(clicked);
    };

    window.eonExtractSearchResults = function() {
        var results = [];

        // Google search results
        var gItems = document.querySelectorAll('div.g');
        if (gItems.length === 0) gItems = document.querySelectorAll('[data-sokoban-container]');
        if (gItems.length === 0) gItems = document.querySelectorAll('div.MjjYud > div');

        for (var i = 0; i < gItems.length && results.length < 15; i++) {
            var el = gItems[i];
            var link = el.querySelector('a[href]');
            if (!link) continue;
            var href = link.href || '';
            if (!href.startsWith('http') || href.indexOf('google.com/search') >= 0) continue;
            if (href.indexOf('google.com/imgres') >= 0) continue;
            if (href.indexOf('/maps/') >= 0) continue;

            var titleEl = el.querySelector('h3');
            if (!titleEl) titleEl = link.querySelector('h3');
            if (!titleEl) continue;

            var title = (titleEl.innerText || '').trim();
            if (title.length < 3) continue;

            // Find snippet - try multiple selectors
            var snippet = '';
            var snippetEl = el.querySelector('[data-sncf]') ||
                            el.querySelector('.VwiC3b') ||
                            el.querySelector('[class*="snippet"]') ||
                            el.querySelector('div[style*="-webkit-line-clamp"]');
            if (snippetEl) snippet = (snippetEl.innerText || '').trim();
            if (!snippet) {
                var allDivs = el.querySelectorAll('div');
                for (var sd = 0; sd < allDivs.length; sd++) {
                    var divText = (allDivs[sd].innerText || '').trim();
                    if (divText.length > 40 && divText.length < 500 && divText !== title) {
                        snippet = divText;
                        break;
                    }
                }
            }

            // Deduplicate
            var isDupe = false;
            for (var r = 0; r < results.length; r++) {
                if (results[r].url === href) { isDupe = true; break; }
            }
            if (isDupe) continue;

            results.push({
                title: title.substring(0, 120),
                snippet: snippet.substring(0, 250),
                url: href,
                index: results.length
            });
        }

        // Bing fallback
        if (results.length === 0) {
            var bItems = document.querySelectorAll('li.b_algo');
            for (var j = 0; j < bItems.length && results.length < 15; j++) {
                var bLink = bItems[j].querySelector('a');
                var bSnippet = bItems[j].querySelector('.b_caption p');
                if (bLink && bLink.href) {
                    results.push({
                        title: (bLink.innerText || '').trim().substring(0, 120),
                        snippet: bSnippet ? (bSnippet.innerText || '').trim().substring(0, 250) : '',
                        url: bLink.href,
                        index: results.length
                    });
                }
            }
        }

        // DuckDuckGo fallback
        if (results.length === 0) {
            var dItems = document.querySelectorAll('.result, [data-result]');
            for (var k = 0; k < dItems.length && results.length < 15; k++) {
                var dLink = dItems[k].querySelector('a.result__a, a[data-testid="result-title-a"]');
                var dSnip = dItems[k].querySelector('.result__snippet, [data-testid="result-snippet"]');
                if (dLink && dLink.href) {
                    results.push({
                        title: (dLink.innerText || '').trim().substring(0, 120),
                        snippet: dSnip ? (dSnip.innerText || '').trim().substring(0, 250) : '',
                        url: dLink.href,
                        index: results.length
                    });
                }
            }
        }

        // Generic: if still no results, find all meaningful links on page
        if (results.length === 0) {
            var allLinks = document.querySelectorAll('a[href]');
            var seenU = {};
            for (var g = 0; g < allLinks.length && results.length < 15; g++) {
                var aHref = allLinks[g].href || '';
                var aText = (allLinks[g].innerText || '').trim();
                if (aHref.startsWith('http') && aText.length > 10 && aText.length < 200 && !seenU[aHref]) {
                    seenU[aHref] = true;
                    var isNav = allLinks[g].closest('nav, header, footer, aside');
                    if (!isNav) {
                        results.push({
                            title: aText.substring(0, 120),
                            snippet: '',
                            url: aHref,
                            index: results.length
                        });
                    }
                }
            }
        }

        return JSON.stringify(results);
    };
    """

    // MARK: - Cookie Banner Dismissal

    static let cookieBannerDismissJS = """
    (function() {
        function dismissCookies() {
            var selectors = [
                '[class*="cookie"] button[class*="accept"]',
                '[class*="cookie"] button[class*="agree"]',
                '[class*="cookie"] button[class*="allow"]',
                '[class*="consent"] button[class*="accept"]',
                '[class*="consent"] button[class*="agree"]',
                '[id*="cookie"] button',
                '[class*="gdpr"] button[class*="accept"]',
                'button[class*="accept-cookies"]',
                'button[class*="acceptAll"]',
                'button[id*="accept"]',
                '.cc-btn.cc-dismiss',
                '#onetrust-accept-btn-handler',
                '.js-accept-cookies',
                '[data-testid="cookie-policy-manage-dialog-btn-accept-all"]',
                'button[aria-label*="Accept"]',
                'button[aria-label*="Acceptera"]',
                'button[aria-label*="Godkänn"]'
            ];
            for (var s = 0; s < selectors.length; s++) {
                try {
                    var btn = document.querySelector(selectors[s]);
                    if (btn && btn.offsetParent !== null) {
                        btn.click();
                        return;
                    }
                } catch(e) {}
            }
            // Try generic: any visible button with accept-like text
            var allButtons = document.querySelectorAll('button, a.button, [role="button"]');
            var acceptWords = ['accept', 'agree', 'godkänn', 'acceptera', 'samtycke', 'ok', 'jag förstår', 'i agree', 'got it'];
            for (var b = 0; b < allButtons.length; b++) {
                var txt = (allButtons[b].innerText || '').trim().toLowerCase();
                if (txt.length < 30) {
                    for (var w = 0; w < acceptWords.length; w++) {
                        if (txt.indexOf(acceptWords[w]) >= 0 && allButtons[b].offsetParent !== null) {
                            allButtons[b].click();
                            return;
                        }
                    }
                }
            }
        }
        setTimeout(dismissCookies, 1500);
        setTimeout(dismissCookies, 4000);
    })();
    """

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let agent: EonBrowserAgent
        weak var webView: WKWebView?
        var pendingExtraction: ((PageContent) -> Void)?
        var onError: ((String) -> Void)?

        init(agent: EonBrowserAgent) {
            self.agent = agent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                agent.pageTitle = webView.title ?? ""
                if let url = webView.url {
                    agent.currentURL = url
                }
                agent.pageLoadContinuation?.resume()
                agent.pageLoadContinuation = nil
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            Task { @MainActor in
                onError?(error.localizedDescription)
                agent.pageLoadContinuation?.resume()
                agent.pageLoadContinuation = nil
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            Task { @MainActor in
                agent.pageTitle = ""
                onError?(error.localizedDescription)
                agent.pageLoadContinuation?.resume()
                agent.pageLoadContinuation = nil
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let scheme = url.scheme ?? ""
                if scheme == "itms-appss" || scheme == "itms-apps" ||
                   scheme == "tel" || scheme == "mailto" || scheme == "sms" {
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    Task { @MainActor in
                        onError?("HTTP \(httpResponse.statusCode)")
                    }
                }
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "eonExtract",
                  let jsonString = message.body as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let empty = PageContent(url: "", title: "", bodyText: "", headings: [], links: [], metaDescription: "", tableData: [], listItems: [])
                pendingExtraction?(empty)
                pendingExtraction = nil
                return
            }

            let title = json["title"] as? String ?? ""
            let url = json["url"] as? String ?? ""
            let body = json["body"] as? String ?? ""
            let meta = json["meta"] as? String ?? ""
            let headings = json["headings"] as? [String] ?? []
            let tableData = json["tableData"] as? [String] ?? []
            let listItems = json["listItems"] as? [String] ?? []
            let linksArray = json["links"] as? [[String: String]] ?? []

            let links = linksArray.compactMap { dict -> (text: String, href: String)? in
                guard let text = dict["text"], let href = dict["href"] else { return nil }
                return (text: text, href: href)
            }

            let content = PageContent(
                url: url, title: title, bodyText: body, headings: headings,
                links: links, metaDescription: meta, tableData: tableData, listItems: listItems
            )
            pendingExtraction?(content)
            pendingExtraction = nil
        }
    }
}

#Preview {
    EonBrowserView()
        .environmentObject(EonBrain.shared)
}
