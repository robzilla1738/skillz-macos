import Foundation

nonisolated enum AgentHookPlatform: String, CaseIterable, Identifiable, Sendable {
    case claudeCode
    case codex
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    var agentPlatform: AgentPlatform {
        switch self {
        case .claudeCode: return .claudeCode
        case .codex: return .codex
        case .cursor: return .cursor
        }
    }
}

nonisolated enum AgentHookInstallStatus: Equatable, Sendable {
    case notInstalled
    case installed
    case needsRepair
    case unsupported
    case requiresTrustOrFeatureFlag
}

nonisolated struct AgentHookStatus: Equatable, Sendable {
    let platform: AgentHookPlatform
    let status: AgentHookInstallStatus
    let detail: String
}

nonisolated enum AgentHookInstaller {
    private static let skillzMarker = "skillz-agent-notify.sh"
    private static let integrationVersion = "2"

    static func notifyCommand(for state: String, platform: AgentHookPlatform, extraArgs: String = "") -> String {
        let script = AgentPaths.notifyScriptInstalledURL.path
        let base = "\"\(script)\" \(platform.rawValue) \(state)"
        if extraArgs.isEmpty {
            return "\(base) \"\(platform.rawValue):$PPID\" \"\" \"$PWD\" \"$PPID\""
        }
        return "\(base) \(extraArgs)"
    }

    static func installNotifyScript() throws {
        let destination = AgentPaths.notifyScriptInstalledURL
        let binDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let content = bundledScriptContent()
        try content.write(to: destination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    }

    static func installAllHooks() throws -> [AgentHookStatus] {
        try installNotifyScript()
        return AgentHookPlatform.allCases.map { platform in
            guard isDetected(platform.agentPlatform) else {
                return AgentHookStatus(platform: platform, status: .unsupported, detail: "\(platform.displayName) is not installed on this Mac.")
            }
            do {
                try installHooks(for: platform)
                return status(for: platform)
            } catch {
                return AgentHookStatus(platform: platform, status: .needsRepair, detail: error.localizedDescription)
            }
        }
    }

    static func autoInstallDetectedHooks() -> [AgentHookStatus] {
        let detectedHookPlatforms = AgentHookPlatform.allCases.filter { isDetected($0.agentPlatform) }
        guard !detectedHookPlatforms.isEmpty else {
            return AgentHookPlatform.allCases.map {
                AgentHookStatus(platform: $0, status: .unsupported, detail: "\($0.displayName) is not installed on this Mac.")
            }
        }

        do {
            try installNotifyScript()
        } catch {
            return AgentHookPlatform.allCases.map {
                AgentHookStatus(platform: $0, status: .needsRepair, detail: error.localizedDescription)
            }
        }

        return AgentHookPlatform.allCases.map { platform in
            guard isDetected(platform.agentPlatform) else {
                return AgentHookStatus(platform: platform, status: .unsupported, detail: "\(platform.displayName) is not installed on this Mac.")
            }
            let current = status(for: platform)
            guard current.status != .installed else { return current }
            do {
                try installHooks(for: platform)
                return status(for: platform)
            } catch {
                return AgentHookStatus(platform: platform, status: .needsRepair, detail: error.localizedDescription)
            }
        }
    }

    static func uninstallAllHooks() -> [AgentHookStatus] {
        AgentHookPlatform.allCases.map { platform in
            do {
                try uninstallHooks(for: platform)
                return status(for: platform)
            } catch {
                return AgentHookStatus(platform: platform, status: .needsRepair, detail: error.localizedDescription)
            }
        }
    }

    static func statusForAllPlatforms() -> [AgentHookStatus] {
        AgentHookPlatform.allCases.map { status(for: $0) }
    }

    static func status(for platform: AgentHookPlatform) -> AgentHookStatus {
        guard isDetected(platform.agentPlatform) else {
            return AgentHookStatus(platform: platform, status: .unsupported, detail: "\(platform.displayName) is not installed on this Mac.")
        }
        let scriptOK = FileManager.default.fileExists(atPath: AgentPaths.notifyScriptInstalledURL.path)
        guard scriptOK else {
            return AgentHookStatus(platform: platform, status: .notInstalled, detail: "Notify script not installed.")
        }

        switch platform {
        case .claudeCode:
            return claudeStatus()
        case .codex:
            return codexStatus()
        case .cursor:
            return cursorStatus()
        }
    }

    private static func installHooks(for platform: AgentHookPlatform) throws {
        switch platform {
        case .claudeCode:
            try installClaudeHooks()
        case .codex:
            try installCodexHooks()
        case .cursor:
            try installCursorHooks()
        }
    }

    private static func uninstallHooks(for platform: AgentHookPlatform) throws {
        switch platform {
        case .claudeCode:
            try removeSkillzHooks(at: AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("settings.json"))
        case .codex:
            try removeSkillzHooks(at: AgentPlatform.codex.homeDirectory.appendingPathComponent("hooks.json"))
        case .cursor:
            let url = AgentPlatform.cursor.homeDirectory.appendingPathComponent("agent-hooks.json")
            var root = try loadJSONObject(at: url)
            for key in ["agent_notify", "agent_done", "agent_working"] {
                if (root[key] as? String)?.contains(skillzMarker) == true {
                    root.removeValue(forKey: key)
                }
            }
            if (root["skillz_integration_version"] as? String) == integrationVersion {
                root.removeValue(forKey: "skillz_integration_version")
            }
            try saveJSONObjectIfChanged(root, to: url)
        }
    }

    private static func installClaudeHooks() throws {
        let url = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("settings.json")
        var root = try loadJSONObject(at: url)
        var hooks = root["hooks"] as? [String: Any] ?? [:]

        for spec in hookSpecs(for: .claudeCode) {
            mergeSkillzHook(into: &hooks, key: spec.event, command: notifyCommand(for: spec.state, platform: .claudeCode))
        }

        root["hooks"] = hooks
        try saveJSONObjectIfChanged(root, to: url)
    }

    private static func installCodexHooks() throws {
        let url = AgentPlatform.codex.homeDirectory.appendingPathComponent("hooks.json")
        var root = try loadJSONObject(at: url)

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for spec in hookSpecs(for: .codex) {
            mergeSkillzHook(into: &hooks, key: spec.event, command: notifyCommand(for: spec.state, platform: .codex))
        }

        root["hooks"] = hooks
        try saveJSONObjectIfChanged(root, to: url)
        try enableCodexHooksFeatureIfNeeded()
    }

    private static func installCursorHooks() throws {
        let url = AgentPlatform.cursor.homeDirectory.appendingPathComponent("agent-hooks.json")
        var root: [String: Any]
        if FileManager.default.fileExists(atPath: url.path) {
            root = try loadJSONObject(at: url)
        } else {
            root = ["version": 1]
        }

        let script = AgentPaths.notifyScriptInstalledURL.path
        root["version"] = 1
        root["skillz_integration_version"] = integrationVersion
        root["agent_notify"] = "\"\(script)\" cursor needsInput \"cursor:$PPID\" \"$1\" \"$PWD\" \"$PPID\""
        root["agent_done"] = "\"\(script)\" cursor idle \"cursor:$PPID\" \"Done\" \"$PWD\" \"$PPID\""
        root["agent_working"] = "\"\(script)\" cursor working \"cursor:$PPID\" \"Working\" \"$PWD\" \"$PPID\""

        try saveJSONObjectIfChanged(root, to: url)
    }

    private static func mergeSkillzHook(into hooks: inout [String: Any], key: String, command: String) {
        var entries = hooks[key] as? [[String: Any]] ?? []
        entries.removeAll { entry in
            guard let nested = entry["hooks"] as? [[String: Any]] else { return false }
            return nested.contains { isSkillzHook($0) }
        }
        entries.append([
            "matcher": "*",
            "hooks": [[
                "type": "command",
                "command": command,
                "skillz": true,
            ]],
        ])
        hooks[key] = entries
    }

    private static func claudeStatus() -> AgentHookStatus {
        let url = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("settings.json")
        guard isDetected(.claudeCode) else {
            return AgentHookStatus(platform: .claudeCode, status: .unsupported, detail: "Claude Code is not installed on this Mac.")
        }
        let root: [String: Any]
        do {
            root = try loadJSONObject(at: url)
        } catch {
            return AgentHookStatus(platform: .claudeCode, status: .needsRepair, detail: error.localizedDescription)
        }
        guard let hooks = root["hooks"] as? [String: Any] else {
            return AgentHookStatus(platform: .claudeCode, status: .notInstalled, detail: "\(AppBrand.name) hooks not found in settings.json.")
        }
        guard hooksContainRequiredEvents(hooks, platform: .claudeCode) else {
            return AgentHookStatus(platform: .claudeCode, status: .needsRepair, detail: "Some \(AppBrand.name) hook events are missing from ~/.claude/settings.json.")
        }
        return AgentHookStatus(platform: .claudeCode, status: .installed, detail: "Hooks active in ~/.claude/settings.json.")
    }

    private static func codexStatus() -> AgentHookStatus {
        let url = AgentPlatform.codex.homeDirectory.appendingPathComponent("hooks.json")
        guard isDetected(.codex) else {
            return AgentHookStatus(platform: .codex, status: .unsupported, detail: "Codex is not installed on this Mac.")
        }
        let root: [String: Any]
        do {
            root = try loadJSONObject(at: url)
        } catch {
            return AgentHookStatus(platform: .codex, status: .needsRepair, detail: error.localizedDescription)
        }
        guard let hooks = root["hooks"] as? [String: Any] else {
            return AgentHookStatus(platform: .codex, status: .notInstalled, detail: "\(AppBrand.name) hooks not found in hooks.json.")
        }
        guard hooksContainRequiredEvents(hooks, platform: .codex) else {
            return AgentHookStatus(platform: .codex, status: .needsRepair, detail: "Some \(AppBrand.name) hook events are missing from ~/.codex/hooks.json.")
        }
        guard codexHooksFeatureEnabled() else {
            return AgentHookStatus(platform: .codex, status: .requiresTrustOrFeatureFlag, detail: "Codex hooks are installed, but the hooks feature flag is not enabled.")
        }
        return AgentHookStatus(platform: .codex, status: .installed, detail: "Hooks active in ~/.codex/hooks.json.")
    }

    private static func cursorStatus() -> AgentHookStatus {
        let url = AgentPlatform.cursor.homeDirectory.appendingPathComponent("agent-hooks.json")
        guard isDetected(.cursor) else {
            return AgentHookStatus(platform: .cursor, status: .unsupported, detail: "Cursor is not installed on this Mac.")
        }
        let root: [String: Any]
        do {
            root = try loadJSONObject(at: url)
        } catch {
            return AgentHookStatus(platform: .cursor, status: .needsRepair, detail: error.localizedDescription)
        }
        guard cursorRootContainsSkillz(root) else {
            return AgentHookStatus(platform: .cursor, status: .notInstalled, detail: "\(AppBrand.name) hooks not found in agent-hooks.json.")
        }
        return AgentHookStatus(platform: .cursor, status: .installed, detail: "Hooks active in ~/.cursor/agent-hooks.json.")
    }

    private static func hooksContainRequiredEvents(_ hooks: [String: Any], platform: AgentHookPlatform) -> Bool {
        hookSpecs(for: platform).allSatisfy { spec in
            eventContainsSkillz(hooks[spec.event])
        }
    }

    private static func eventContainsSkillz(_ value: Any?) -> Bool {
        guard let entries = value as? [[String: Any]] else { return false }
        return entries.contains { entry in
            if isCurrentSkillzHook(entry) { return true }
            guard let nested = entry["hooks"] as? [[String: Any]] else { return false }
            return nested.contains { isCurrentSkillzHook($0) }
        }
    }

    private static func cursorRootContainsSkillz(_ root: [String: Any]) -> Bool {
        guard root["skillz_integration_version"] as? String == integrationVersion else { return false }
        return ["agent_notify", "agent_done", "agent_working"].allSatisfy {
            (root[$0] as? String)?.contains(skillzMarker) == true
        }
    }

    private static func isSkillzHook(_ entry: [String: Any]) -> Bool {
        (entry["command"] as? String)?.contains(skillzMarker) == true
            || entry["skillz"] as? Bool == true
    }

    private static func isCurrentSkillzHook(_ entry: [String: Any]) -> Bool {
        guard let command = entry["command"] as? String,
              command.contains(skillzMarker)
        else { return false }
        return command.contains("$PPID")
    }

    private static func loadJSONObject(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw AgentHookError.invalidConfig(path: url.path)
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AgentHookError.invalidConfig(path: url.path)
            }
            return json
        } catch let error as AgentHookError {
            throw error
        } catch {
            throw AgentHookError.invalidConfig(path: url.path)
        }
    }

    private static func saveJSONObjectIfChanged(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        if let existing = try? Data(contentsOf: url), existing == data {
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.copyItem(at: url, to: backupURL(for: url))
        }
        try data.write(to: url, options: .atomic)
    }

    private static func removeSkillzHooks(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var root = try loadJSONObject(at: url)
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for key in hooks.keys {
            guard var entries = hooks[key] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                if (entry["command"] as? String)?.contains(skillzMarker) == true { return true }
                guard let nested = entry["hooks"] as? [[String: Any]] else { return false }
                return nested.contains {
                    ($0["command"] as? String)?.contains(skillzMarker) == true
                        || $0["skillz"] as? Bool == true
                }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: key)
            } else {
                hooks[key] = entries
            }
        }
        root["hooks"] = hooks
        try saveJSONObjectIfChanged(root, to: url)
    }

    private static func isDetected(_ platform: AgentPlatform) -> Bool {
        PlatformSourceDetector.isInstalled(platform: platform)
    }

    private static func hookSpecs(for platform: AgentHookPlatform) -> [(event: String, state: String)] {
        switch platform {
        case .claudeCode:
            return [
                ("SessionStart", "working"),
                ("UserPromptSubmit", "working"),
                ("PreToolUse", "working"),
                ("PermissionRequest", "needsInput"),
                ("Notification", "needsInput"),
                ("Stop", "idle"),
                ("SessionEnd", "release"),
            ]
        case .codex:
            return [
                ("SessionStart", "working"),
                ("UserPromptSubmit", "working"),
                ("PreToolUse", "working"),
                ("PermissionRequest", "needsInput"),
                ("Stop", "idle"),
                ("SessionEnd", "release"),
            ]
        case .cursor:
            return []
        }
    }

    private static func codexHooksFeatureEnabled() -> Bool {
        let url = AgentPlatform.codex.homeDirectory.appendingPathComponent("config.toml")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        var inFeatures = false
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") {
                inFeatures = line == "[features]"
            } else if inFeatures, line.hasPrefix("hooks") {
                return line.contains("true")
            }
        }
        return false
    }

    private static func enableCodexHooksFeatureIfNeeded() throws {
        guard !codexHooksFeatureEnabled() else { return }
        let url = AgentPlatform.codex.homeDirectory.appendingPathComponent("config.toml")
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var featuresRange: Range<Int>?

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "[features]" {
                let start = index
                var end = lines.count
                for candidate in lines.index(after: index)..<lines.count where lines[candidate].trimmingCharacters(in: .whitespaces).hasPrefix("[") {
                    end = candidate
                    break
                }
                featuresRange = start..<end
                break
            }
        }

        if let range = featuresRange {
            var inserted = false
            for index in range {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("hooks") {
                    lines[index] = "hooks = true"
                    inserted = true
                    break
                }
            }
            if !inserted {
                lines.insert("hooks = true", at: range.lowerBound + 1)
            }
            content = lines.joined(separator: "\n")
        } else {
            if !content.isEmpty, !content.hasSuffix("\n") {
                content += "\n"
            }
            content += "\n[features]\nhooks = true\n"
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.copyItem(at: url, to: backupURL(for: url))
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func backupURL(for url: URL) -> URL {
        url.appendingPathExtension("skillz-bak-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))")
    }

    private static func bundledScriptContent() -> String {
        if let url = Bundle.main.url(forResource: "skillz-agent-notify", withExtension: "sh"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        return AgentNotifyScript.content
    }
}

enum AgentHookError: LocalizedError {
    case scriptMissing
    case invalidConfig(path: String)

    var errorDescription: String? {
        switch self {
        case .scriptMissing: return "Could not locate the \(AppBrand.name) notify script in the app bundle."
        case .invalidConfig(let path): return "Could not parse existing hook config at \(path)."
        }
    }
}
