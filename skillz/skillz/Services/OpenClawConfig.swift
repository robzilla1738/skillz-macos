import Foundation

nonisolated enum OpenClawConfig {
    static var configURL: URL {
        AgentPlatform.openClaw.homeDirectory.appendingPathComponent("openclaw.json")
    }

    /// Resolved workspace directory (default `~/.openclaw/workspace`).
    static func workspaceDirectory() -> URL {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let agents = json["agents"] as? [String: Any],
              let defaults = agents["defaults"] as? [String: Any],
              let workspace = defaults["workspace"] as? String,
              !workspace.isEmpty
        else {
            return AgentPlatform.openClaw.homeDirectory.appendingPathComponent("workspace", isDirectory: true)
        }

        if workspace.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return URL(fileURLWithPath: home + String(workspace.dropFirst(1)), isDirectory: true)
        }
        if workspace.hasPrefix("/") {
            return URL(fileURLWithPath: workspace, isDirectory: true)
        }
        return AgentPlatform.openClaw.homeDirectory.appendingPathComponent(workspace, isDirectory: true)
    }

    static func workspaceSkillsDirectory() -> URL {
        workspaceDirectory().appendingPathComponent("skills", isDirectory: true)
    }
}
