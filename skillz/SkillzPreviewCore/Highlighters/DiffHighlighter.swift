import SwiftUI

/// Unified-diff highlighter: file headers, hunk markers, added/removed lines,
/// and git metadata lines.
nonisolated enum DiffHighlighter {
    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (offset, line) in lines.enumerated() {
            builder.append(line, color: color(for: line, palette: palette))
            if offset < lines.count - 1 {
                builder.newline(color: palette.foreground)
            }
        }

        return builder.build()
    }

    private static func color(for line: Substring, palette: PreviewPalette) -> Color {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return palette.heading
        }
        if line.hasPrefix("@@") {
            return palette.accent
        }
        if line.hasPrefix("+") {
            return palette.success
        }
        if line.hasPrefix("-") {
            return palette.error
        }
        if line.hasPrefix("diff ") || line.hasPrefix("index ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file")
            || line.hasPrefix("rename ") || line.hasPrefix("similarity ")
            || line.hasPrefix("Binary files") || line.hasPrefix("old mode") || line.hasPrefix("new mode") {
            return palette.secondary
        }
        if line.hasPrefix("\\ No newline") {
            return palette.comment
        }
        return palette.foreground
    }
}
