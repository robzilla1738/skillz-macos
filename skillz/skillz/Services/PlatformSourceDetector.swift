import Foundation

struct PlatformSourceStatus: Identifiable, Equatable, Sendable {
    let platform: AgentPlatform
    let isDetected: Bool
    let scanPaths: [URL]
    let itemCount: Int

    var id: String { platform.id }

    var primaryPath: URL? {
        scanPaths.first { FileManager.default.fileExists(atPath: $0.path) }
            ?? scanPaths.first
    }

    var statusLabel: String {
        isDetected ? "Found" : "Not detected"
    }

    var notDetectedHint: String {
        switch platform {
        case .cursor:
            return "Install Cursor to populate ~/.cursor/skills"
        case .claudeCode:
            return "Install Claude Code to populate ~/.claude/skills"
        case .codex:
            return "Install Codex CLI to populate ~/.codex/skills"
        case .hermes:
            return "Install Hermes to populate ~/.hermes/skills"
        case .pi:
            return "Install Pi to populate ~/.pi/agent/skills"
        case .openClaw:
            return "Install OpenCode to populate local skills"
        }
    }
}

enum PlatformSourceDetector {
    static func detect(snapshot: CatalogSnapshot) -> [PlatformSourceStatus] {
        AgentPlatform.allCases.map { platform in
            let paths = allScanPaths(for: platform)
            let detected = isInstalled(platform: platform, paths: paths)
            let count = CatalogFilter.items(in: snapshot, section: .all, platform: platform).count
            return PlatformSourceStatus(
                platform: platform,
                isDetected: detected,
                scanPaths: paths,
                itemCount: count
            )
        }
    }

    static func detectedPlatforms(from statuses: [PlatformSourceStatus]) -> Set<AgentPlatform> {
        Set(statuses.filter(\.isDetected).map(\.platform))
    }

    static func defaultNewSkillPlatforms(from statuses: [PlatformSourceStatus]) -> Set<AgentPlatform> {
        let detected = detectedPlatforms(from: statuses)
        if detected.isEmpty {
            return [.cursor, .claudeCode]
        }
        return detected
    }

    static func allScanPaths(for platform: AgentPlatform) -> [URL] {
        var paths = PlatformSkillPaths.skillScanRoots(for: platform)

        switch platform {
        case .cursor:
            paths.append(platform.homeDirectory.appendingPathComponent("mcp.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("skills-cursor", isDirectory: true))
        case .claudeCode:
            paths.append(platform.homeDirectory.appendingPathComponent(".mcp.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/installed_plugins.json"))
        case .codex:
            paths.append(platform.homeDirectory.appendingPathComponent("config.toml"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
        case .openClaw:
            paths.append(OpenClawConfig.configURL)
            let workspace = OpenClawConfig.workspaceDirectory()
            paths.append(workspace)
            paths.append(OpenClawConfig.workspaceSkillsDirectory())
        case .hermes, .pi:
            break
        }

        paths.append(platform.homeDirectory)

        var seen = Set<String>()
        return paths.filter { seen.insert($0.path).inserted }
    }

    private static func isInstalled(platform: AgentPlatform, paths: [URL]) -> Bool {
        if paths.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return true
        }
        for root in PlatformSkillPaths.skillScanRoots(for: platform) {
            if directoryContainsSkillMD(at: root) { return true }
        }
        return false
    }

    private static func directoryContainsSkillMD(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "SKILL.md" { return true }
        }
        return false
    }
}
