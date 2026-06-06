import SwiftUI

/// Character-scanning JSON tokenizer shared by `.json` and `.jsonl` previews.
/// Output preserves the input text exactly; only colors are attached.
nonisolated enum JSONHighlighter {
    /// Pretty-prints a whole JSON document. Returns the input unchanged when it
    /// does not parse.
    static func prettyPrinted(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .withoutEscapingSlashes, .fragmentsAllowed]
              ),
              let string = String(data: pretty, encoding: .utf8) else {
            return text
        }
        return string
    }

    /// Pretty-prints each JSON Lines record individually, separating records
    /// with a blank line. Unparseable lines pass through unchanged.
    static func prettyPrintedLines(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return String(line) }
                return prettyPrinted(trimmed)
            }
            .joined(separator: "\n")
    }

    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            switch character {
            case "\"":
                let stringEnd = scanString(text, from: index)
                let isKey = nextMeaningfulCharacter(text, from: stringEnd) == ":"
                builder.append(text[index..<stringEnd], color: isKey ? palette.key : palette.string)
                index = stringEnd
            case "{", "}", "[", "]", ",", ":":
                builder.append(String(character), color: palette.punctuation)
                index = text.index(after: index)
            case "-", "0"..."9":
                let numberEnd = scanNumber(text, from: index)
                builder.append(text[index..<numberEnd], color: palette.number)
                index = numberEnd
            case let c where c.isLetter:
                let wordEnd = scanWord(text, from: index)
                let word = text[index..<wordEnd]
                let isLiteral = word == "true" || word == "false" || word == "null"
                builder.append(word, color: isLiteral ? palette.accent : palette.foreground)
                index = wordEnd
            default:
                builder.append(String(character), color: palette.foreground)
                index = text.index(after: index)
            }
        }

        return builder.build()
    }

    private static func scanString(_ text: String, from start: String.Index) -> String.Index {
        var index = text.index(after: start)
        var escaped = false
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                return text.index(after: index)
            } else if character == "\n" {
                // Unterminated string on this line (common mid-edit) — stop at EOL.
                return index
            }
            index = text.index(after: index)
        }
        return index
    }

    private static func scanNumber(_ text: String, from start: String.Index) -> String.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            let character = text[index]
            if character.isNumber || "+-.eE".contains(character) {
                index = text.index(after: index)
            } else {
                break
            }
        }
        return index
    }

    private static func scanWord(_ text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex, text[index].isLetter {
            index = text.index(after: index)
        }
        return index
    }

    private static func nextMeaningfulCharacter(_ text: String, from start: String.Index) -> Character? {
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if !character.isWhitespace {
                return character
            }
            index = text.index(after: index)
        }
        return nil
    }
}
