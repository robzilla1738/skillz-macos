import Foundation

/// Converts CSV/TSV text to a GitHub-flavored markdown table for MarkdownUI to
/// render. Quoted-field aware (embedded delimiters, doubled quotes, embedded
/// newlines), with row/column caps to stay inside the Quick Look budget.
nonisolated enum CSVTableConverter {
    static let maxRows = 200
    static let maxColumns = 24

    struct Result: Equatable {
        let markdownTable: String
        let truncated: Bool
    }

    /// Returns `nil` when the text doesn't look tabular (no delimiter in the
    /// first row) so callers can fall back to plain text.
    static func markdownTable(from text: String) -> Result? {
        let delimiter = detectDelimiter(in: text)
        let parsed = parseRows(text, delimiter: delimiter, rowCap: maxRows + 1)
        guard let header = parsed.rows.first, header.count > 1 else { return nil }

        var truncated = parsed.truncated
        var rows = parsed.rows
        if rows.count > maxRows {
            rows = Array(rows.prefix(maxRows))
            truncated = true
        }

        let columnCount = min(header.count, maxColumns)
        if header.count > maxColumns {
            truncated = true
        }

        var lines: [String] = []
        lines.reserveCapacity(rows.count + 1)

        lines.append(markdownRow(rows[0], columnCount: columnCount))
        lines.append("| " + Array(repeating: "---", count: columnCount).joined(separator: " | ") + " |")
        for row in rows.dropFirst() {
            lines.append(markdownRow(row, columnCount: columnCount))
        }

        return Result(markdownTable: lines.joined(separator: "\n"), truncated: truncated)
    }

    /// Tab wins when the first line has more tabs than commas (covers .tsv
    /// without needing the file extension).
    static func detectDelimiter(in text: String) -> Character {
        let firstLine = text.prefix(while: { $0 != "\n" })
        let tabs = firstLine.filter { $0 == "\t" }.count
        let commas = firstLine.filter { $0 == "," }.count
        return tabs > commas ? "\t" : ","
    }

    private static func markdownRow(_ row: [String], columnCount: Int) -> String {
        var cells = row.prefix(columnCount).map(escapeCell)
        while cells.count < columnCount {
            cells.append("")
        }
        return "| " + cells.joined(separator: " | ") + " |"
    }

    private static func escapeCell(_ cell: String) -> String {
        cell
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// RFC 4180-ish state machine. Stops after `rowCap` rows and reports
    /// whether input remained.
    private static func parseRows(_ text: String, delimiter: Character, rowCap: Int) -> (rows: [[String]], truncated: Bool) {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func endField() {
            currentRow.append(field)
            field = ""
        }

        func endRow() {
            endField()
            // Skip rows that are entirely empty (trailing newline artifacts).
            if !(currentRow.count == 1 && currentRow[0].isEmpty) {
                rows.append(currentRow)
            }
            currentRow = []
        }

        while index < text.endIndex {
            if rows.count >= rowCap {
                return (rows, true)
            }
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"" where field.isEmpty:
                    inQuotes = true
                case delimiter:
                    endField()
                case "\n":
                    endRow()
                case "\r":
                    break
                default:
                    field.append(character)
                }
            }
            index = text.index(after: index)
        }

        if !field.isEmpty || !currentRow.isEmpty {
            endRow()
        }

        return (rows, false)
    }
}
