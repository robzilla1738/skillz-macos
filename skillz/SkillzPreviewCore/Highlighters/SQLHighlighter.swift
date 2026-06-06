import SwiftUI

/// SQL highlighter: keywords (case-insensitive), single-quoted strings,
/// numbers, `--` line comments, and `/* … */` block comments (state carried
/// across lines).
nonisolated enum SQLHighlighter {
    private static let keywords: Set<String> = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "FROM", "WHERE", "JOIN", "LEFT",
        "RIGHT", "INNER", "OUTER", "FULL", "CROSS", "ON", "GROUP", "BY", "ORDER",
        "LIMIT", "OFFSET", "HAVING", "UNION", "ALL", "DISTINCT", "AS", "INTO",
        "VALUES", "SET", "CREATE", "TABLE", "INDEX", "VIEW", "TRIGGER", "DROP",
        "ALTER", "ADD", "COLUMN", "PRIMARY", "KEY", "FOREIGN", "REFERENCES",
        "UNIQUE", "NOT", "NULL", "DEFAULT", "CHECK", "CONSTRAINT", "AND", "OR",
        "IN", "IS", "LIKE", "BETWEEN", "EXISTS", "CASE", "WHEN", "THEN", "ELSE",
        "END", "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "IF", "ASC", "DESC",
        "INTEGER", "TEXT", "REAL", "BLOB", "NUMERIC", "VARCHAR", "CHAR",
        "BOOLEAN", "DATE", "TIMESTAMP", "SERIAL", "BIGINT", "SMALLINT", "FLOAT",
        "DOUBLE", "DECIMAL", "RETURNING", "WITH", "RECURSIVE", "EXPLAIN",
        "VACUUM", "PRAGMA", "CURRENT_TIMESTAMP", "CURRENT_DATE", "COUNT", "SUM",
        "AVG", "MIN", "MAX", "COALESCE", "CAST", "TRUE", "FALSE",
    ]

    static func highlight(_ text: String, palette: PreviewPalette) -> AttributedString {
        var builder = HighlightBuilder()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var inBlockComment = false

        for (offset, line) in lines.enumerated() {
            inBlockComment = highlightLine(line, palette: palette, inBlockComment: inBlockComment, into: &builder)
            if offset < lines.count - 1 {
                builder.newline(color: palette.foreground)
            }
        }

        return builder.build()
    }

    /// Returns whether a block comment is still open at end of line.
    private static func highlightLine(
        _ line: Substring,
        palette: PreviewPalette,
        inBlockComment: Bool,
        into builder: inout HighlightBuilder
    ) -> Bool {
        var index = line.startIndex
        var inBlock = inBlockComment

        while index < line.endIndex {
            if inBlock {
                if let close = line.range(of: "*/", range: index..<line.endIndex) {
                    builder.append(line[index..<close.upperBound], color: palette.comment)
                    index = close.upperBound
                    inBlock = false
                } else {
                    builder.append(line[index...], color: palette.comment)
                    return true
                }
                continue
            }

            let character = line[index]
            switch character {
            case "-" where line[index...].hasPrefix("--"):
                builder.append(line[index...], color: palette.comment)
                return false
            case "/" where line[index...].hasPrefix("/*"):
                inBlock = true
            case "'":
                let end = scanString(line, from: index)
                builder.append(line[index..<end], color: palette.string)
                index = end
            case "\"":
                let end = scanQuoted(line, from: index, quote: "\"")
                builder.append(line[index..<end], color: palette.string)
                index = end
            case "(", ")", ",", ";", "=", "<", ">", "*", "+":
                builder.append(String(character), color: palette.punctuation)
                index = line.index(after: index)
            case "0"..."9":
                let end = scanNumber(line, from: index)
                builder.append(line[index..<end], color: palette.number)
                index = end
            case let c where c.isLetter || c == "_":
                let end = scanWord(line, from: index)
                let word = String(line[index..<end]).uppercased()
                builder.append(line[index..<end], color: keywords.contains(word) ? palette.key : palette.foreground)
                index = end
            default:
                builder.append(String(character), color: palette.foreground)
                index = line.index(after: index)
            }
        }

        return inBlock
    }

    /// SQL strings escape quotes by doubling: 'it''s'.
    private static func scanString(_ line: Substring, from start: Substring.Index) -> Substring.Index {
        var index = line.index(after: start)
        while index < line.endIndex {
            if line[index] == "'" {
                let next = line.index(after: index)
                if next < line.endIndex, line[next] == "'" {
                    index = line.index(after: next)
                    continue
                }
                return next
            }
            index = line.index(after: index)
        }
        return index
    }

    private static func scanQuoted(_ line: Substring, from start: Substring.Index, quote: Character) -> Substring.Index {
        var index = line.index(after: start)
        while index < line.endIndex {
            if line[index] == quote {
                return line.index(after: index)
            }
            index = line.index(after: index)
        }
        return index
    }

    private static func scanNumber(_ line: Substring, from start: Substring.Index) -> Substring.Index {
        var index = line.index(after: start)
        while index < line.endIndex {
            let character = line[index]
            if character.isNumber || "._eE".contains(character) {
                index = line.index(after: index)
            } else {
                break
            }
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
