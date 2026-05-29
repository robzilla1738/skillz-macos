import Foundation

nonisolated enum PlatformSkillPaths {
    static var agentsSkillsDirectory: URL {
        AgentPlatform.agentsDirectory.appendingPathComponent("skills", isDirectory: true)
    }

    static func skillScanRoots(for platform: AgentPlatform) -> [URL] {
        switch platform {
        case .cursor:
            return [AgentPlatform.cursor.userSkillsDirectory]
        case .claudeCode:
            return [AgentPlatform.claudeCode.userSkillsDirectory]
        case .codex:
            return [AgentPlatform.codex.userSkillsDirectory, agentsSkillsDirectory]
        case .hermes:
            return [AgentPlatform.hermes.userSkillsDirectory]
        case .pi:
            return [AgentPlatform.pi.userSkillsDirectory, agentsSkillsDirectory]
        case .openClaw:
            var roots = [AgentPlatform.openClaw.userSkillsDirectory]
            let workspaceSkills = OpenClawConfig.workspaceSkillsDirectory()
            if FileManager.default.fileExists(atPath: workspaceSkills.path) {
                roots.append(workspaceSkills)
            }
            return roots
        }
    }

    /// Harnesses that read the same on-disk skill file (excluding the primary platform).
    static func platformsThatShare(path: URL) -> [AgentPlatform] {
        let pathString = path.path
        guard pathString.contains("/.agents/skills/") || pathString.hasSuffix("/.agents/skills") else {
            return []
        }
        return [.pi, .codex, .openClaw]
    }

    /// Which platform "owns" a skill path for display after deduplication.
    static func primaryPlatform(for path: URL) -> AgentPlatform {
        let pathString = path.path
        if pathString.contains("/skills-cursor/") { return .cursor }
        if pathString.contains("/.hermes/") { return .hermes }
        if pathString.contains("/.openclaw/") { return .openClaw }
        if pathString.contains("/.pi/") { return .pi }
        if pathString.contains("/.cursor/") { return .cursor }
        if pathString.contains("/.claude/") { return .claudeCode }
        if pathString.contains("/.codex/") { return .codex }
        if pathString.contains("/.agents/") { return .pi }
        return .cursor
    }

    static func platformFor(path: URL) -> AgentPlatform {
        primaryPlatform(for: path)
    }

    static var watchDirectories: [URL] {
        var paths: [URL] = AgentPlatform.allCases.map(\.homeDirectory)
        if FileManager.default.fileExists(atPath: agentsSkillsDirectory.path) {
            paths.append(agentsSkillsDirectory)
        } else {
            paths.append(AgentPlatform.agentsDirectory)
        }
        let workspaceSkills = OpenClawConfig.workspaceSkillsDirectory()
        if FileManager.default.fileExists(atPath: workspaceSkills.path) {
            paths.append(workspaceSkills.deletingLastPathComponent())
        }
        return paths
    }
}
