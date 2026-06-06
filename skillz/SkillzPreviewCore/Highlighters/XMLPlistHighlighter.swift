import SwiftUI

/// Highlighter for XML documents and XML-serialized property lists: tags,
/// attribute names/values, comments, and declarations.
nonisolated enum XMLPlistHighlighter {
    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        var index = text.startIndex

        while index < text.endIndex {
            guard let tagStart = text[index...].firstIndex(of: "<") else {
                builder.append(text[index...], color: palette.foreground)
                break
            }

            // Text content before the tag.
            builder.append(text[index..<tagStart], color: palette.foreground)

            if text[tagStart...].hasPrefix("<!--") {
                let end = rangeEnd(of: "-->", in: text, from: tagStart)
                builder.append(text[tagStart..<end], color: palette.comment)
                index = end
            } else if text[tagStart...].hasPrefix("<?") || text[tagStart...].hasPrefix("<!") {
                let end = rangeEnd(of: ">", in: text, from: tagStart)
                builder.append(text[tagStart..<end], color: palette.punctuation)
                index = end
            } else {
                index = appendTag(text, from: tagStart, palette: palette, into: &builder)
            }
        }

        return builder.build()
    }

    private static func rangeEnd(of terminator: String, in text: String, from start: String.Index) -> String.Index {
        if let range = text.range(of: terminator, range: start..<text.endIndex) {
            return range.upperBound
        }
        return text.endIndex
    }

    /// Colors one `<tag attr="value">` run starting at `<`. Returns the index
    /// just past the closing `>`.
    private static func appendTag(
        _ text: String,
        from start: String.Index,
        palette: PreviewPalette,
        into builder: inout HighlightBuilder
    ) -> String.Index {
        var index = text.index(after: start)
        builder.append("<", color: palette.punctuation)

        if index < text.endIndex, text[index] == "/" {
            builder.append("/", color: palette.punctuation)
            index = text.index(after: index)
        }

        // Tag name.
        let nameStart = index
        while index < text.endIndex, isNameCharacter(text[index]) {
            index = text.index(after: index)
        }
        builder.append(text[nameStart..<index], color: palette.key)

        // Attributes until `>`.
        while index < text.endIndex {
            let character = text[index]
            if character == ">" {
                builder.append(">", color: palette.punctuation)
                return text.index(after: index)
            }
            if character == "/" || character == "?" {
                builder.append(String(character), color: palette.punctuation)
                index = text.index(after: index)
                continue
            }
            if character == "=" {
                builder.append("=", color: palette.punctuation)
                index = text.index(after: index)
                continue
            }
            if character == "\"" || character == "'" {
                let end = scanQuoted(text, from: index, quote: character)
                builder.append(text[index..<end], color: palette.string)
                index = end
                continue
            }
            if isNameCharacter(character) {
                let attrStart = index
                while index < text.endIndex, isNameCharacter(text[index]) {
                    index = text.index(after: index)
                }
                builder.append(text[attrStart..<index], color: palette.accent)
                continue
            }
            builder.append(String(character), color: palette.foreground)
            index = text.index(after: index)
        }
        return index
    }

    private static func isNameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "_" || character == ":" || character == "."
    }

    private static func scanQuoted(_ text: String, from start: String.Index, quote: Character) -> String.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            if text[index] == quote {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        return index
    }
}
