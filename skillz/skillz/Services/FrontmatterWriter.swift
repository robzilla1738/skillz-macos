import Foundation

enum FrontmatterWriter {
    struct Update: Sendable {
        var name: String?
        var description: String?
        var version: String?
        var disableModelInvocation: Bool?
    }

    static func apply(to content: String, update: Update) -> String {
        let (existing, body) = FrontmatterParser.parse(from: content)
        var merged = existing
        if let name = update.name { merged.name = name }
        if let description = update.description { merged.description = description }
        if let version = update.version { merged.version = version.isEmpty ? nil : version }
        if let disable = update.disableModelInvocation { merged.disableModelInvocation = disable }

        let yaml = serialize(merged)
        let trimmedBody = body.trimmingCharacters(in: .newlines)
        if trimmedBody.isEmpty {
            return "---\n\(yaml)---\n"
        }
        return "---\n\(yaml)---\n\n\(trimmedBody)\n"
    }

    private static func serialize(_ fm: SkillFrontmatter) -> String {
        var lines: [String] = []
        if let name = fm.name, !name.isEmpty {
            lines.append("name: \(quoteIfNeeded(name))")
        }
        if let description = fm.description, !description.isEmpty {
            if description.contains("\n") {
                lines.append("description: >")
                lines.append(contentsOf: description.components(separatedBy: "\n"))
            } else {
                lines.append("description: \(quoteIfNeeded(description))")
            }
        }
        if let version = fm.version, !version.isEmpty {
            lines.append("version: \(quoteIfNeeded(version))")
        }
        if let disable = fm.disableModelInvocation {
            lines.append("disable-model-invocation: \(disable ? "true" : "false")")
        }
        if lines.isEmpty {
            lines.append("name: skill")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func quoteIfNeeded(_ value: String) -> String {
        if value.contains(":") || value.contains("#") || value.hasPrefix(" ") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return value
    }

    static func make(name: String, description: String, body: String) -> String {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyText = trimmedBody.isEmpty
            ? "# \(name)\n\nDescribe when to use this skill."
            : trimmedBody
        return apply(
            to: "---\nname: skill\n---\n\n\(bodyText)\n",
            update: Update(name: name, description: description)
        )
    }
}
