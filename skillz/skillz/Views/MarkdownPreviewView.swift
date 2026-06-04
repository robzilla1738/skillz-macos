import SiriusMarkdown
import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    let fontSize: Double

    @StateObject private var session: MarkdownRenderSession
    @State private var pendingRenderTask: Task<Void, Never>?
    @State private var lastRenderedMarkdown = ""

    init(markdown: String, fontSize: Double) {
        self.markdown = markdown
        self.fontSize = fontSize
        _session = StateObject(
            wrappedValue: MarkdownRenderSession(
                configuration: MarkdownPreviewTheme.configuration(fontSize: fontSize)
            )
        )
    }

    var body: some View {
        MarkdownDocumentView(
            preparedSnapshot: session.preparedSnapshot,
            configuration: session.configuration
        )
        .background(Color.skillzCanvas)
        .accessibilityLabel("Markdown preview")
        .onAppear {
            scheduleRender(markdown, debounce: false)
        }
        .onChange(of: markdown) { _, newValue in
            scheduleRender(newValue, debounce: true)
        }
        .onDisappear {
            pendingRenderTask?.cancel()
            pendingRenderTask = nil
        }
    }

    private func scheduleRender(_ source: String, debounce: Bool) {
        pendingRenderTask?.cancel()
        pendingRenderTask = Task { @MainActor in
            if debounce {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            render(source)
        }
    }

    private func render(_ source: String) {
        let renderedSource = MarkdownPreviewSource.renderedMarkdown(from: source)
        guard renderedSource != lastRenderedMarkdown else { return }
        lastRenderedMarkdown = renderedSource
        session.reset()
        guard !renderedSource.isEmpty else { return }
        session.append(renderedSource)
        session.finish()
    }
}

nonisolated enum MarkdownPreviewSource {
    static func renderedMarkdown(from source: String) -> String {
        FrontmatterParser.parse(from: source).body.trimmingCharacters(in: .newlines)
    }
}

private enum MarkdownPreviewTheme {
    static func configuration(fontSize: Double) -> MarkdownRendererConfiguration {
        MarkdownRendererConfiguration(
            theme: theme(fontSize: fontSize),
            inlineRenderingMode: .coreTextPaintedLines
        )
    }

    static func theme(fontSize: Double) -> MarkdownTheme {
        let bodySize = max(11, fontSize)
        let bodyLineHeight = max(bodySize + 6, bodySize * 1.45)
        let headingSize = max(bodySize + 3, bodySize * 1.22)
        let headingLineHeight = max(headingSize + 7, headingSize * 1.35)

        return MarkdownTheme(
            paragraphFont: .system(size: bodySize, weight: .regular, design: .monospaced),
            codeFont: .system(size: bodySize, weight: .regular, design: .monospaced),
            headingFont: .system(size: headingSize, weight: .semibold, design: .monospaced),
            textColor: Color.skillzEmphasis,
            secondaryTextColor: Color.skillzMuted,
            codeBackground: Color.skillzSelection.opacity(0.35),
            quoteAccent: Color.skillzMuted.opacity(0.75),
            tableBackground: Color.skillzCanvas,
            tableHeaderBackground: Color.skillzSelection.opacity(0.35),
            tableAlternateRowBackground: Color.skillzSelection.opacity(0.18),
            tableBorderColor: Color.skillzHairline,
            tableAccentColor: Color.skillzEmphasis,
            tableCornerRadius: 6,
            tableHorizontalCellPadding: 10,
            tableVerticalCellPadding: 7,
            blockSpacing: SkillzSpacing.md,
            paragraphFontSize: bodySize,
            paragraphLineHeight: bodyLineHeight,
            headingFontSize: headingSize,
            headingLineHeight: headingLineHeight,
            codeFontSize: bodySize,
            codeLineHeight: bodyLineHeight
        )
    }
}
