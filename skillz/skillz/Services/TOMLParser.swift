import Foundation

nonisolated enum TOMLParser {
    struct Section: Sendable {
        let name: String
        var keys: [String: String] = [:]
    }

    static func parseSections(from content: String) -> [Section] {
        var sections: [Section] = []
        var currentName = ""
        var currentKeys: [String: String] = [:]

        func flush() {
            guard !currentName.isEmpty else { return }
            sections.append(Section(name: currentName, keys: currentKeys))
            currentKeys = [:]
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                flush()
                currentName = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            if !currentName.isEmpty {
                currentKeys[key] = value
            }
        }

        flush()
        return sections
    }

    static func mcpServers(from configURL: URL) -> [MCPItem] {
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }
        let sections = parseSections(from: content)
        let modifiedAt = modificationDate(for: configURL)

        return sections.compactMap { section -> MCPItem? in
            guard section.name.hasPrefix("mcp_servers.") else { return nil }
            let name = String(section.name.dropFirst("mcp_servers.".count))
            guard !name.isEmpty else { return nil }

            let command = section.keys["command"]
            let url = section.keys["url"]
            let argsRaw = section.keys["args"] ?? ""
            let args = parseArgs(argsRaw)

            let transport: MCPTransport
            if url != nil {
                transport = .http
            } else if command != nil {
                transport = .stdio
            } else {
                transport = .unknown
            }

            let envKeys = section.keys.keys.filter { $0.hasPrefix("env.") }
                .map { String($0.dropFirst(4)) }
                + section.keys.keys.filter { $0 == "env" }.map { _ in "env" }

            return MCPItem(
                id: MCPItem.makeID(platform: .codex, name: name),
                platform: .codex,
                name: name,
                transport: transport,
                command: command,
                args: args,
                url: url,
                envKeys: Array(Set(envKeys)).sorted(),
                configFileURL: configURL,
                modifiedAt: modifiedAt
            )
        }
    }

    static func enabledPlugins(from configURL: URL) -> [String: Bool] {
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return [:] }
        let sections = parseSections(from: content)
        var result: [String: Bool] = [:]

        for section in sections where section.name.hasPrefix("plugins.\"") || section.name.hasPrefix("plugins.\'") {
            let pluginID = extractQuotedPluginID(from: section.name)
            guard !pluginID.isEmpty else { continue }
            if let enabled = section.keys["enabled"] {
                result[pluginID] = ["true", "yes", "1"].contains(enabled.lowercased())
            } else {
                result[pluginID] = true
            }
        }

        return result
    }

    private static func extractQuotedPluginID(from sectionName: String) -> String {
        guard sectionName.hasPrefix("plugins.") else { return "" }
        var remainder = String(sectionName.dropFirst("plugins.".count))
        if remainder.hasPrefix("\"") {
            remainder.removeFirst()
            if let end = remainder.firstIndex(of: "\"") {
                return String(remainder[..<end])
            }
        }
        return remainder.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private static func parseArgs(_ raw: String) -> [String] {
        guard raw.hasPrefix("[") && raw.hasSuffix("]") else { return [] }
        let inner = String(raw.dropFirst().dropLast())
        var args: [String] = []
        var current = ""
        var inQuote = false
        var quoteChar: Character?

        for char in inner {
            if inQuote {
                if char == quoteChar {
                    inQuote = false
                    args.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                inQuote = true
                quoteChar = char
            } else if char == "," {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { args.append(trimmed) }
                current = ""
            } else if !char.isWhitespace {
                current.append(char)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { args.append(trimmed) }
        return args
    }

    private static func modificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
