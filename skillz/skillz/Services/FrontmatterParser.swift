import Foundation

nonisolated enum FrontmatterParser {
    static func parse(from content: String) -> (frontmatter: SkillFrontmatter, body: String) {
        guard content.hasPrefix("---") else {
            return (SkillFrontmatter(), content)
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2 else {
            return (SkillFrontmatter(), content)
        }

        var endIndex: Int?
        for index in 1..<lines.count {
            if lines[index] == "---" {
                endIndex = index
                break
            }
        }

        guard let endIndex else {
            return (SkillFrontmatter(), content)
        }

        let yamlLines = lines[1..<endIndex]
        var frontmatter = SkillFrontmatter()

        for line in yamlLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if let colon = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix(">") || value.hasPrefix("|") {
                    value = ""
                }
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                switch key {
                case "name":
                    frontmatter.name = value.isEmpty ? nil : value
                case "description":
                    frontmatter.description = value.isEmpty ? nil : value
                case "version":
                    frontmatter.version = value.isEmpty ? nil : value
                case "disable-model-invocation":
                    frontmatter.disableModelInvocation = ["true", "yes", "1"].contains(value.lowercased())
                default:
                    break
                }
            }
        }

        let bodyStart = endIndex + 1
        let body = bodyStart < lines.count
            ? lines[bodyStart...].joined(separator: "\n")
            : ""

        return (frontmatter, body)
    }

    static func firstParagraph(from body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let paragraphs = trimmed.components(separatedBy: "\n\n")
        let first = paragraphs.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let singleLine = first
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .joined(separator: " ")
        return String(singleLine.prefix(280))
    }
}
