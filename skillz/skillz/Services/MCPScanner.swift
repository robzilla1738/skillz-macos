import Foundation

enum MCPScanner {
    nonisolated static func scan() -> [MCPItem] {
        var items: [MCPItem] = []
        items += scanCursor()
        items += scanClaude()
        items += TOMLParser.mcpServers(from: AgentPlatform.codex.homeDirectory.appendingPathComponent("config.toml"))
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private nonisolated static func scanCursor() -> [MCPItem] {
        let configURL = AgentPlatform.cursor.homeDirectory.appendingPathComponent("mcp.json")
        return parseJSONConfig(at: configURL, platform: .cursor)
    }

    private nonisolated static func scanClaude() -> [MCPItem] {
        let configURL = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent(".mcp.json")
        return parseJSONConfig(at: configURL, platform: .claudeCode)
    }

    private nonisolated static func parseJSONConfig(at url: URL, platform: AgentPlatform) -> [MCPItem] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["mcpServers"] as? [String: Any] else {
            return []
        }

        let modifiedAt = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        return servers.compactMap { name, value -> MCPItem? in
            guard let dict = value as? [String: Any] else { return nil }

            let urlString = dict["url"] as? String
            let command = dict["command"] as? String
            let args = dict["args"] as? [String] ?? []
            let env = dict["env"] as? [String: Any] ?? [:]

            let transport: MCPTransport
            if urlString != nil {
                transport = .http
            } else if command != nil {
                transport = .stdio
            } else {
                transport = .unknown
            }

            return MCPItem(
                id: MCPItem.makeID(platform: platform, name: name),
                platform: platform,
                name: name,
                transport: transport,
                command: command,
                args: args,
                url: urlString,
                envKeys: env.keys.sorted(),
                configFileURL: url,
                modifiedAt: modifiedAt
            )
        }
    }
}
