import SwiftUI

/// Line-oriented shell highlighter for sh/zsh/bash/fish: shebang, comments,
/// strings, variables, and control-flow keywords.
nonisolated enum ShellHighlighter {
    private static let keywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
        "case", "esac", "in", "function", "select", "time", "return", "break",
        "continue", "exit", "export", "local", "readonly", "set", "unset", "source",
        "alias", "shift", "trap", "eval", "exec",
        // fish
        "begin", "end", "switch", "and", "or", "not"
    ]

    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for (offset, line) in lines.enumerated() {
            if offset == 0, line.hasPrefix("#!") {
                builder.append(line, color: palette.accent)
            } else {
                highlightLine(line, palette: palette, into: &builder)
            }
            if offset < lines.count - 1 {
                builder.newline(color: palette.foreground)
            }
        }

        return builder.build()
    }

    private static func highlightLine(_ line: Substring, palette: PreviewPalette, into builder: inout HighlightBuilder) {
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            switch character {
            case "#":
                let isCommentStart = index == line.startIndex
                    || line[line.index(before: index)] == " "
                    || line[line.index(before: index)] == "\t"
                if isCommentStart {
                    builder.append(line[index...], color: palette.comment)
                    return
                }
                builder.append("#", color: palette.foreground)
                index = line.index(after: index)
            case "\"", "'":
                let end = scanString(line, from: index, quote: character)
                builder.append(line[index..<end], color: palette.string)
                index = end
            case "$":
                let end = scanVariable(line, from: index)
                builder.append(line[index..<end], color: palette.accent)
                index = end
            case let c where c.isLetter || c == "_":
                let end = scanWord(line, from: index)
                let word = String(line[index..<end])
                builder.append(line[index..<end], color: keywords.contains(word) ? palette.key : palette.foreground)
                index = end
            default:
                builder.append(String(character), color: palette.foreground)
                index = line.index(after: index)
            }
        }
    }

    private static func scanString(_ line: Substring, from start: Substring.Index, quote: Character) -> Substring.Index {
        var index = line.index(after: start)
        var escaped = false
        while index < line.endIndex {
            let character = line[index]
            if escaped {
                escaped = false
            } else if character == "\\", quote == "\"" {
                escaped = true
            } else if character == quote {
                return line.index(after: index)
            }
            index = line.index(after: index)
        }
        return index
    }

    /// `$NAME`, `${NAME}`, `$1`, `$?`, `$@` — stops before command
    /// substitution bodies (`$(…)` colors just the `$`).
    private static func scanVariable(_ line: Substring, from start: Substring.Index) -> Substring.Index {
        var index = line.index(after: start)
        guard index < line.endIndex else { return index }

        let first = line[index]
        if first == "{" {
            while index < line.endIndex, line[index] != "}" {
                index = line.index(after: index)
            }
            return index < line.endIndex ? line.index(after: index) : index
        }
        if "?@#!$*0123456789".contains(first), !first.isLetter {
            return line.index(after: index)
        }
        while index < line.endIndex, line[index].isLetter || line[index].isNumber || line[index] == "_" {
            index = line.index(after: index)
        }
        return index
    }

    private static func scanWord(_ line: Substring, from start: Substring.Index) -> Substring.Index {
        var index = start
        while index < line.endIndex, line[index].isLetter || line[index].isNumber || line[index] == "_" {
            index = line.index(after: index)
        }
        return index
    }
}
