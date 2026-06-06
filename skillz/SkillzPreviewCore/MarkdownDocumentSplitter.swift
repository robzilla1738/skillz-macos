import Foundation

/// Minimal `---`-fence splitter for markdown previews. Intentionally
/// independent of the app's `FrontmatterParser` (which returns the typed
/// `SkillFrontmatter` app model) so the preview core stays self-contained.
nonisolated enum MarkdownDocumentSplitter {
    struct Document: Equatable {
        /// Raw YAML between the fences, without the fences. `nil` when the
        /// document has no frontmatter block.
        let frontmatter: String?
        let body: String
    }

    static func split(_ text: String) -> Document {
        guard text.hasPrefix("---") else {
            return Document(frontmatter: nil, body: text)
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2, lines[0] == "---" else {
            return Document(frontmatter: nil, body: text)
        }

        var closeIndex: Int?
        for index in 1..<lines.count where lines[index] == "---" {
            closeIndex = index
            break
        }

        guard let closeIndex else {
            return Document(frontmatter: nil, body: text)
        }

        let frontmatter = lines[1..<closeIndex].joined(separator: "\n")
        let bodyStart = closeIndex + 1
        let body = bodyStart < lines.count
            ? lines[bodyStart...].joined(separator: "\n")
            : ""

        return Document(frontmatter: frontmatter, body: body)
    }
}
