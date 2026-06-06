import SwiftUI

/// Line-oriented log highlighter: leading timestamps and severity tokens
/// (ERROR/WARN/INFO/DEBUG families) get distinct colors.
nonisolated enum LogHighlighter {
    private static let errorLevels: Set<String> = ["ERROR", "ERR", "FATAL", "CRITICAL", "SEVERE", "PANIC"]
    private static let warningLevels: Set<String> = ["WARN", "WARNING"]
    private static let infoLevels: Set<String> = ["INFO", "NOTICE"]
    private static let traceLevels: Set<String> = ["DEBUG", "TRACE", "VERBOSE"]

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
        var remainder = line

        // Leading timestamp (ISO 8601, bracketed, or syslog-style).
        let timestampEnd = scanTimestamp(remainder)
        if timestampEnd > remainder.startIndex {
            builder.append(remainder[..<timestampEnd], color: palette.secondary)
            remainder = remainder[timestampEnd...]
        }

        // Tokenize the rest, coloring severity words.
        var index = remainder.startIndex
        while index < remainder.endIndex {
            let character = remainder[index]
            if character.isLetter {
                let end = scanWord(remainder, from: index)
                let word = String(remainder[index..<end]).uppercased()
                let color: Color
                if errorLevels.contains(word) {
                    color = palette.error
                } else if warningLevels.contains(word) {
                    color = palette.warning
                } else if infoLevels.contains(word) {
                    color = palette.accent
                } else if traceLevels.contains(word) {
                    color = palette.comment
                } else {
                    color = palette.foreground
                }
                builder.append(remainder[index..<end], color: color)
                index = end
            } else {
                builder.append(String(character), color: palette.foreground)
                index = remainder.index(after: index)
            }
        }
    }

    /// Consumes a leading timestamp-ish run: digits, date/time separators, and
    /// an optional surrounding bracket pair.
    private static func scanTimestamp(_ line: Substring) -> Substring.Index {
        var index = line.startIndex
        var sawDigit = false
        var openBracket = false

        while index < line.endIndex {
            let character = line[index]
            if character == "[", index == line.startIndex {
                openBracket = true
            } else if character.isNumber {
                sawDigit = true
            } else if "-:.,/TZ+ ".contains(character), sawDigit || openBracket {
                // separators inside a timestamp run
            } else if character == "]", openBracket {
                index = line.index(after: index)
                break
            } else {
                break
            }
            index = line.index(after: index)
        }

        return sawDigit ? index : line.startIndex
    }

    private static func scanWord(_ line: Substring, from start: Substring.Index) -> Substring.Index {
        var index = start
        while index < line.endIndex, line[index].isLetter {
            index = line.index(after: index)
        }
        return index
    }
}
