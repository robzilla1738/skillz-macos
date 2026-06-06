import SwiftUI

/// Line-oriented YAML highlighter: keys, values, comments, list markers, and
/// document separators. Multi-line scalar bodies render as plain text.
nonisolated enum YAMLHighlighter {
    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (offset, line) in lines.enumerated() {
            highlightLine(line, palette: palette, into: &builder)
            if offset < lines.count - 1 {
                builder.newline(color: palette.foreground)
            }
        }

        return builder.build()
    }

    private static func highlightLine(_ line: Substring, palette: PreviewPalette, into builder: inout HighlightBuilder) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            builder.append(line, color: palette.foreground)
            return
        }
        if trimmed.hasPrefix("#") {
            builder.append(line, color: palette.comment)
            return
        }
        if trimmed == "---" || trimmed == "..." {
            builder.append(line, color: palette.punctuation)
            return
        }

        // Split a trailing comment (a "#" preceded by whitespace, outside quotes).
        let (content, comment) = splitTrailingComment(line)

        var remainder = content

        // Leading indentation.
        let indentEnd = remainder.firstIndex(where: { $0 != " " && $0 != "\t" }) ?? remainder.endIndex
        builder.append(remainder[..<indentEnd], color: palette.foreground)
        remainder = remainder[indentEnd...]

        // List marker.
        if remainder.hasPrefix("- ") || remainder == "-" {
            let markerEnd = remainder.index(remainder.startIndex, offsetBy: min(2, remainder.count))
            builder.append(remainder[..<markerEnd], color: palette.punctuation)
            remainder = remainder[markerEnd...]
        }

        // `key:` prefix.
        if let colonIndex = keyColonIndex(in: remainder) {
            builder.append(remainder[..<colonIndex], color: palette.key)
            builder.append(":", color: palette.punctuation)
            remainder = remainder[remainder.index(after: colonIndex)...]
        }

        appendValue(remainder, palette: palette, into: &builder)

        if !comment.isEmpty {
            builder.append(comment, color: palette.comment)
        }
    }

    /// Finds the colon terminating a `key:` prefix — the first `:` that is
    /// followed by whitespace or end-of-line and not inside quotes.
    private static func keyColonIndex(in text: Substring) -> Substring.Index? {
        var index = text.startIndex
        var quote: Character?
        while index < text.endIndex {
            let character = text[index]
            if let active = quote {
                if character == active { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ":" {
                let next = text.index(after: index)
                if next == text.endIndex || text[next] == " " || text[next] == "\t" {
                    return index
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func splitTrailingComment(_ line: Substring) -> (content: Substring, comment: Substring) {
        var index = line.startIndex
        var quote: Character?
        while index < line.endIndex {
            let character = line[index]
            if let active = quote {
                if character == active { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "#" {
                let isLineStart = index == line.startIndex
                let previous = isLineStart ? " " : line[line.index(before: index)]
                if previous == " " || previous == "\t" {
                    return (line[..<index], line[index...])
                }
            }
            index = line.index(after: index)
        }
        return (line, line[line.endIndex...])
    }

    private static func appendValue(_ value: Substring, palette: PreviewPalette, into builder: inout HighlightBuilder) {
        guard !value.isEmpty else { return }

        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let color: Color
        if trimmed.isEmpty {
            color = palette.foreground
        } else if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") {
            color = palette.string
        } else if trimmed.hasPrefix("&") || trimmed.hasPrefix("*") {
            color = palette.accent
        } else if isNumber(trimmed) {
            color = palette.number
        } else if isBooleanish(trimmed) {
            color = palette.accent
        } else {
            color = palette.foreground
        }
        builder.append(value, color: color)
    }

    private static func isNumber(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return Double(text) != nil
    }

    private static func isBooleanish(_ text: String) -> Bool {
        ["true", "false", "yes", "no", "on", "off", "null", "~"].contains(text.lowercased())
    }
}
