import SwiftUI

/// Line-oriented TOML highlighter: `[tables]`, keys, strings, numbers/dates,
/// booleans, and comments.
nonisolated enum TOMLHighlighter {
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
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            builder.append(line, color: palette.heading)
            return
        }

        // `key = value` — find the first `=` outside quotes.
        if let equalsIndex = assignmentIndex(in: line) {
            builder.append(line[..<equalsIndex], color: palette.key)
            builder.append("=", color: palette.punctuation)
            let value = line[line.index(after: equalsIndex)...]
            appendValue(value, palette: palette, into: &builder)
            return
        }

        // Continuation lines (multi-line arrays/strings).
        appendValue(line[line.startIndex...], palette: palette, into: &builder)
    }

    private static func assignmentIndex(in line: Substring) -> Substring.Index? {
        var index = line.startIndex
        var quote: Character?
        while index < line.endIndex {
            let character = line[index]
            if let active = quote {
                if character == active { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "=" {
                return index
            } else if character == "#" {
                return nil
            }
            index = line.index(after: index)
        }
        return nil
    }

    /// Tokenizes the value side: strings, numbers/dates, booleans, array
    /// punctuation, and trailing comments.
    private static func appendValue(_ value: Substring, palette: PreviewPalette, into builder: inout HighlightBuilder) {
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]
            switch character {
            case "\"", "'":
                let end = scanString(value, from: index, quote: character)
                builder.append(value[index..<end], color: palette.string)
                index = end
            case "#":
                builder.append(value[index...], color: palette.comment)
                return
            case "[", "]", "{", "}", ",", "=":
                builder.append(String(character), color: palette.punctuation)
                index = value.index(after: index)
            case "-", "+", "0"..."9":
                let end = scanNumberish(value, from: index)
                builder.append(value[index..<end], color: palette.number)
                index = end
            case let c where c.isLetter:
                let end = scanWord(value, from: index)
                let word = value[index..<end]
                let isBool = word == "true" || word == "false"
                builder.append(word, color: isBool ? palette.accent : palette.foreground)
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

    /// Numbers, dates, and times share a character set (digits, separators,
    /// exponent markers, time-zone designators).
    private static func scanNumberish(_ text: Substring, from start: Substring.Index) -> Substring.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            let character = text[index]
            if character.isNumber || "+-._:eExoTZ".contains(character) {
                index = text.index(after: index)
            } else {
                break
            }
        }
        return index
    }

    private static func scanWord(_ text: Substring, from start: Substring.Index) -> Substring.Index {
        var index = start
        while index < text.endIndex, text[index].isLetter || text[index] == "_" {
            index = text.index(after: index)
        }
        return index
    }
}
