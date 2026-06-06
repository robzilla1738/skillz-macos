import SwiftUI

/// Line-oriented highlighter for INI-style configs and dotenv files:
/// `[sections]`, `key = value` / `key: value` / `KEY=value`, `#`/`;` comments,
/// quoted strings, numbers, booleans, and `${VAR}` references.
nonisolated enum ConfigHighlighter {
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
        if trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
            builder.append(line, color: palette.comment)
            return
        }
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            builder.append(line, color: palette.heading)
            return
        }

        var remainder = line

        // Leading whitespace.
        let indentEnd = remainder.firstIndex(where: { $0 != " " && $0 != "\t" }) ?? remainder.endIndex
        builder.append(remainder[..<indentEnd], color: palette.foreground)
        remainder = remainder[indentEnd...]

        // Dotenv `export ` prefix.
        if remainder.hasPrefix("export ") {
            let exportEnd = remainder.index(remainder.startIndex, offsetBy: 6)
            builder.append(remainder[..<exportEnd], color: palette.accent)
            builder.append(" ", color: palette.foreground)
            remainder = remainder[remainder.index(after: exportEnd)...]
        }

        // `key =` / `key:` — first separator outside quotes.
        if let separator = separatorIndex(in: remainder) {
            builder.append(remainder[..<separator], color: palette.key)
            builder.append(String(remainder[separator]), color: palette.punctuation)
            appendValue(remainder[remainder.index(after: separator)...], palette: palette, into: &builder)
            return
        }

        appendValue(remainder, palette: palette, into: &builder)
    }

    private static func separatorIndex(in line: Substring) -> Substring.Index? {
        var index = line.startIndex
        var quote: Character?
        while index < line.endIndex {
            let character = line[index]
            if let active = quote {
                if character == active { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "=" || character == ":" {
                return index
            } else if character == "#" || character == ";" {
                return nil
            }
            index = line.index(after: index)
        }
        return nil
    }

    private static func appendValue(_ value: Substring, palette: PreviewPalette, into builder: inout HighlightBuilder) {
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]
            switch character {
            case "\"", "'":
                let end = scanString(value, from: index, quote: character)
                builder.append(value[index..<end], color: palette.string)
                index = end
            case "#", ";":
                let isCommentStart = index == value.startIndex
                    || value[value.index(before: index)] == " "
                    || value[value.index(before: index)] == "\t"
                if isCommentStart {
                    builder.append(value[index...], color: palette.comment)
                    return
                }
                builder.append(String(character), color: palette.foreground)
                index = value.index(after: index)
            case "$":
                let end = scanVariable(value, from: index)
                builder.append(value[index..<end], color: palette.accent)
                index = end
            case "-", "+", "0"..."9":
                let end = scanNumber(value, from: index)
                builder.append(value[index..<end], color: palette.number)
                index = end
            case let c where c.isLetter:
                let end = scanWord(value, from: index)
                let word = String(value[index..<end]).lowercased()
                let isBool = ["true", "false", "yes", "no", "on", "off", "null"].contains(word)
                builder.append(value[index..<end], color: isBool ? palette.accent : palette.foreground)
                index = end
            default:
                builder.append(String(character), color: palette.foreground)
                index = value.index(after: index)
            }
        }
    }

    private static func scanString(_ text: Substring, from start: Substring.Index, quote: Character) -> Substring.Index {
        var index = text.index(after: start)
        var escaped = false
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\", quote == "\"" {
                escaped = true
            } else if character == quote {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        return index
    }

    private static func scanVariable(_ text: Substring, from start: Substring.Index) -> Substring.Index {
        var index = text.index(after: start)
        guard index < text.endIndex else { return index }
        if text[index] == "{" {
            while index < text.endIndex, text[index] != "}" {
                index = text.index(after: index)
            }
            return index < text.endIndex ? text.index(after: index) : index
        }
        while index < text.endIndex, text[index].isLetter || text[index].isNumber || text[index] == "_" {
            index = text.index(after: index)
        }
        return index
    }

    private static func scanNumber(_ text: Substring, from start: Substring.Index) -> Substring.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            let character = text[index]
            if character.isNumber || "._eE".contains(character) {
                index = text.index(after: index)
            } else {
                break
            }
        }
        return index
    }

    private static func scanWord(_ text: Substring, from start: Substring.Index) -> Substring.Index {
        var index = start
        while index < text.endIndex, text[index].isLetter || text[index].isNumber || text[index] == "_" {
            index = text.index(after: index)
        }
        return index
    }
}
