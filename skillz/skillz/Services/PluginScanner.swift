import Foundation

enum PluginScanner {
    nonisolated static func scan() -> [PluginItem] {
        var items: [PluginItem] = []
        items += scanCursor()
        items += scanClaude()
        items += scanCodex()
        return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private nonisolated static func scanCursor() -> [PluginItem] {
        let cacheRoot = AgentPlatform.cursor.homeDirectory.appendingPathComponent("plugins/cache")
        return scanPluginMetadata(in: cacheRoot, platform: .cursor, enabledMap: [:], defaultEnabled: true)
    }

    private nonisolated static func scanClaude() -> [PluginItem] {
        let installedURL = AgentPlatform.claudeCode.homeDirectory
            .appendingPathComponent("plugins/installed_plugins.json")
        let settingsURL = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("settings.json")

        let enabledMap = loadClaudeEnabledPlugins(from: settingsURL)
        var items: [PluginItem] = []

        guard let data = try? Data(contentsOf: installedURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: Any] else {
            let cacheRoot = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("plugins/cache")
            return scanPluginMetadata(in: cacheRoot, platform: .claudeCode, enabledMap: enabledMap, defaultEnabled: false)
        }

        for (pluginID, entries) in plugins {
            guard let entryList = entries as? [[String: Any]],
                  let first = entryList.first,
                  let installPathString = first["installPath"] as? String else { continue }

            let installPath = URL(fileURLWithPath: installPathString)
            let metadataPath = findPluginJSON(in: installPath)
            let metadata = metadataPath.flatMap { loadPluginMetadata(from: $0) }
            let skillCount = countSkills(in: installPath)
            let version = first["version"] as? String ?? metadata?.version
            let isEnabled = enabledMap[pluginID] ?? false

            items.append(PluginItem(
                id: PluginItem.makeID(platform: .claudeCode, pluginID: pluginID, installPath: installPath),
                platform: .claudeCode,
                pluginID: pluginID,
                displayName: metadata?.name ?? pluginID,
                description: metadata?.description ?? "",
                version: version,
                marketplace: marketplace(from: pluginID),
                isEnabled: isEnabled,
                installPath: installPath,
                metadataPath: metadataPath,
                skillCount: skillCount,
                modifiedAt: modificationDate(for: installPath)
            ))
        }

        return items
    }

    private nonisolated static func scanCodex() -> [PluginItem] {
        let configURL = AgentPlatform.codex.homeDirectory.appendingPathComponent("config.toml")
        let enabledMap = TOMLParser.enabledPlugins(from: configURL)
        let cacheRoot = AgentPlatform.codex.homeDirectory.appendingPathComponent("plugins/cache")
        var items = scanPluginMetadata(in: cacheRoot, platform: .codex, enabledMap: enabledMap, defaultEnabled: false)

        for (pluginID, enabled) in enabledMap {
            if items.contains(where: { $0.pluginID == pluginID }) { continue }
            items.append(PluginItem(
                id: PluginItem.makeID(platform: .codex, pluginID: pluginID, installPath: nil),
                platform: .codex,
                pluginID: pluginID,
                displayName: pluginID,
                description: "",
                version: nil,
                marketplace: marketplace(from: pluginID),
                isEnabled: enabled,
                installPath: nil,
                metadataPath: nil,
                skillCount: 0,
                modifiedAt: modificationDate(for: configURL)
            ))
        }

        return items
    }

    private nonisolated static func scanPluginMetadata(
        in root: URL,
        platform: AgentPlatform,
        enabledMap: [String: Bool],
        defaultEnabled: Bool
    ) -> [PluginItem] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var seenPaths = Set<String>()
        var items: [PluginItem] = []

        for case let dirURL as URL in enumerator {
            let pluginJSON = dirURL.appendingPathComponent(".claude-plugin/plugin.json")
            let codexJSON = dirURL.appendingPathComponent(".codex-plugin/plugin.json")
            let metadataURL: URL?
            if FileManager.default.fileExists(atPath: pluginJSON.path) {
                metadataURL = pluginJSON
            } else if FileManager.default.fileExists(atPath: codexJSON.path) {
                metadataURL = codexJSON
            } else {
                continue
            }

            let installPath = dirURL
            guard seenPaths.insert(installPath.path).inserted else { continue }

            let metadata = metadataURL.flatMap { loadPluginMetadata(from: $0) }
            let pluginName = metadata?.name ?? installPath.deletingLastPathComponent().lastPathComponent
            let pluginID = inferPluginID(name: pluginName, path: installPath, platform: platform)
            let isEnabled = enabledMap[pluginID] ?? defaultEnabled

            items.append(PluginItem(
                id: PluginItem.makeID(platform: platform, pluginID: pluginID, installPath: installPath),
                platform: platform,
                pluginID: pluginID,
                displayName: metadata?.name ?? pluginName,
                description: metadata?.description ?? "",
                version: metadata?.version,
                marketplace: marketplace(from: pluginID),
                isEnabled: isEnabled,
                installPath: installPath,
                metadataPath: metadataURL,
                skillCount: countSkills(in: installPath),
                modifiedAt: modificationDate(for: installPath)
            ))
        }

        return items
    }

    private nonisolated static func loadClaudeEnabledPlugins(from url: URL) -> [String: Bool] {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let enabled = json["enabledPlugins"] as? [String: Bool] else {
            return [:]
        }
        return enabled
    }

    private nonisolated static func findPluginJSON(in installPath: URL) -> URL? {
        let claude = installPath.appendingPathComponent(".claude-plugin/plugin.json")
        if FileManager.default.fileExists(atPath: claude.path) { return claude }
        let codex = installPath.appendingPathComponent(".codex-plugin/plugin.json")
        if FileManager.default.fileExists(atPath: codex.path) { return codex }
        return nil
    }

    private nonisolated static func loadPluginMetadata(from url: URL) -> (name: String, description: String, version: String?)? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let name = json["name"] as? String ?? url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        let description = json["description"] as? String ?? ""
        let version = json["version"] as? String
        return (name, description, version)
    }

    private nonisolated static func countSkills(in installPath: URL) -> Int {
        let skillsDir = installPath.appendingPathComponent("skills")
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: skillsDir.path) else {
            return 0
        }
        return contents.filter { name in
            var isDir: ObjCBool = false
            let path = skillsDir.appendingPathComponent(name).path
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }.count
    }

    private nonisolated static func inferPluginID(name: String, path: URL, platform: AgentPlatform) -> String {
        let parent = path.deletingLastPathComponent().lastPathComponent
        if parent.contains("@") { return "\(name)@\(parent.split(separator: "@").last ?? "")" }
        return "\(name)@\(platform.displayName.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    private nonisolated static func marketplace(from pluginID: String) -> String? {
        guard let at = pluginID.lastIndex(of: "@") else { return nil }
        return String(pluginID[pluginID.index(after: at)...])
    }

    private nonisolated static func modificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
