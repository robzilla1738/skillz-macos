import SwiftUI
import AppKit
import MarkdownUI

/// The shared preview renderer: used by the Quick Look extension, the Quick
/// Look settings live sample, and (markdown branch) the app's Rich Text pane.
/// Input is already-loaded text — file reading/caps live in
/// `PreviewInputLoader`.
struct PreviewContentView: View {
    let text: String
    let type: PreviewFileType
    let settings: PreviewTypeSettings
    var wasTruncated: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var palette: PreviewPalette? {
        settings.useCustomTheme
            ? PreviewPalette(theme: settings.preset.theme, colorScheme: colorScheme)
            : nil
    }

    var body: some View {
        let palette = self.palette
        let plan = Self.renderPlan(text: text, type: type, settings: settings, wasTruncated: wasTruncated)
        VStack(spacing: 0) {
            content(palette: palette, plan: plan)
            if plan.truncated {
                truncationFooter(palette: palette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette?.background ?? Color(nsColor: .textBackgroundColor))
    }

    /// Display-ready content: per-type transforms applied, output re-capped,
    /// and every truncation source folded into one flag for the footer.
    struct RenderPlan {
        let text: String
        let csvTable: CSVTableConverter.Result?
        let truncated: Bool
    }

    /// Pretty-printing can massively amplify already-capped input (a 1-line
    /// minified JSON array can expand to hundreds of thousands of lines), so
    /// transformed output is re-capped before highlighting. CSV conversion
    /// reports its own row/column truncation, which folds in here too.
    nonisolated static func renderPlan(
        text: String,
        type: PreviewFileType,
        settings: PreviewTypeSettings,
        wasTruncated: Bool
    ) -> RenderPlan {
        switch type {
        case .json where settings.jsonPrettyPrint:
            let recapped = PreviewInputLoader.capped(text: JSONHighlighter.prettyPrinted(text))
            return RenderPlan(text: recapped.text, csvTable: nil, truncated: wasTruncated || recapped.wasTruncated)
        case .jsonl where settings.jsonPrettyPrint:
            let recapped = PreviewInputLoader.capped(text: JSONHighlighter.prettyPrintedLines(text))
            return RenderPlan(text: recapped.text, csvTable: nil, truncated: wasTruncated || recapped.wasTruncated)
        case .csv:
            let table = CSVTableConverter.markdownTable(from: text)
            return RenderPlan(text: text, csvTable: table, truncated: wasTruncated || (table?.truncated ?? false))
        default:
            return RenderPlan(text: text, csvTable: nil, truncated: wasTruncated)
        }
    }

    @ViewBuilder
    private func content(palette: PreviewPalette?, plan: RenderPlan) -> some View {
        switch type {
        case .markdown where settings.markdownRenderedMode:
            renderedMarkdown(palette: palette)
        case .csv:
            csvContent(palette: palette, plan: plan)
        default:
            scrollingMonoText(highlightedText(plan.text, palette: palette), palette: palette)
        }
    }

    // MARK: Markdown

    private func renderedMarkdown(palette: PreviewPalette?) -> some View {
        let document = MarkdownDocumentSplitter.split(text)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let frontmatter = document.frontmatter, !frontmatter.isEmpty {
                    frontmatterBlock(frontmatter, palette: palette)
                }
                markdownView(document.body, palette: palette)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func markdownView(_ body: String, palette: PreviewPalette?) -> some View {
        let themed = Group {
            if let palette {
                Markdown(body)
                    .markdownTheme(SkillzMarkdownTheme.theme(palette: palette, fontSize: settings.fontSize))
            } else {
                Markdown(body)
            }
        }
        .textSelection(.enabled)

        // Remote images are opt-in ("Load remote images", markdown only).
        // Default keeps previews network-free for untrusted content — see
        // MarkdownImageProviders.swift.
        if settings.loadRemoteImages {
            themed
        } else {
            themed
                .markdownImageProvider(LocalOnlyImageProvider())
                .markdownInlineImageProvider(LocalOnlyInlineImageProvider())
        }
    }

    private func frontmatterBlock(_ frontmatter: String, palette: PreviewPalette?) -> some View {
        let highlighted: AttributedString
        if let palette {
            highlighted = YAMLHighlighter.highlight(frontmatter, palette: palette)
        } else {
            highlighted = AttributedString(frontmatter)
        }
        return Text(highlighted)
            .font(.system(size: settings.fontSize * 0.94, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette?.codeBackground ?? Color(nsColor: .quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .textSelection(.enabled)
    }

    // MARK: CSV

    @ViewBuilder
    private func csvContent(palette: PreviewPalette?, plan: RenderPlan) -> some View {
        if let table = plan.csvTable {
            // GeometryReader pins small content top-leading — a two-axis
            // ScrollView centers undersized content otherwise.
            GeometryReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    markdownView(table.markdownTable, palette: palette)
                        .padding(16)
                        .frame(
                            minWidth: proxy.size.width,
                            minHeight: proxy.size.height,
                            alignment: .topLeading
                        )
                }
            }
        } else {
            scrollingMonoText(highlightedText(plan.text, palette: palette), palette: palette)
        }
    }

    // MARK: Mono text

    private func scrollingMonoText(_ attributed: AttributedString, palette: PreviewPalette?) -> some View {
        // GeometryReader pins small content top-leading — a two-axis
        // ScrollView centers undersized content otherwise.
        GeometryReader { proxy in
            ScrollView(settings.lineWrap ? [.vertical] : [.vertical, .horizontal]) {
                Text(attributed)
                    .font(.system(size: settings.fontSize, design: .monospaced))
                    .lineSpacing(settings.fontSize * 0.25)
                    .multilineTextAlignment(.leading)
                    .padding(16)
                    .textSelection(.enabled)
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height,
                        alignment: .topLeading
                    )
            }
        }
    }

    /// Applies syntax colors and the optional line-number gutter to content
    /// already transformed/re-capped by `renderPlan`.
    private func highlightedText(_ content: String, palette: PreviewPalette?) -> AttributedString {
        guard let palette else {
            // Plain mode: no syntax colors; gutter (when on) uses secondary.
            if settings.showLineNumbers {
                return Self.numbered(content, prefixColor: Color(nsColor: .tertiaryLabelColor)) {
                    AttributedString($0)
                }
            }
            return AttributedString(content)
        }

        let highlight = Self.highlighter(for: type)
        if settings.showLineNumbers {
            return Self.numbered(content, prefixColor: palette.lineNumber) {
                highlight($0, palette)
            }
        }
        return highlight(content, palette)
    }

    private static func highlighter(for type: PreviewFileType) -> (String, PreviewPalette) -> AttributedString {
        switch type {
        case .json, .jsonl:
            return JSONHighlighter.highlight
        case .yaml:
            return YAMLHighlighter.highlight
        case .toml:
            return TOMLHighlighter.highlight
        case .xml, .plist:
            return XMLPlistHighlighter.highlight
        case .shell:
            return ShellHighlighter.highlight
        case .log:
            return LogHighlighter.highlight
        case .markdown, .csv:
            return { text, palette in
                var plain = AttributedString(text)
                plain.foregroundColor = palette.foreground
                return plain
            }
        }
    }

    /// Splits into lines, highlights each line independently, and prepends a
    /// right-aligned line-number prefix. Per-line highlighting keeps gutter
    /// prefixes out of the tokenizers.
    nonisolated static func numbered(
        _ content: String,
        prefixColor: Color,
        highlight: (String) -> AttributedString
    ) -> AttributedString {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let width = String(lines.count).count
        var result = AttributedString()

        for (offset, line) in lines.enumerated() {
            var prefix = AttributedString(String(format: "%\(width)d  ", offset + 1))
            prefix.foregroundColor = prefixColor
            result += prefix
            result += highlight(String(line))
            if offset < lines.count - 1 {
                result += AttributedString("\n")
            }
        }

        return result
    }

    private func truncationFooter(palette: PreviewPalette?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .imageScale(.small)
            Text("Preview truncated — open the file to see everything.")
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(palette?.secondary ?? Color(nsColor: .secondaryLabelColor))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background((palette?.codeBackground ?? Color(nsColor: .quaternarySystemFill)).opacity(0.8))
    }
}
