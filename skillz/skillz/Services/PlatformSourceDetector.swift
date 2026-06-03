import Foundation

nonisolated enum PlatformHookSupport: Equatable, Sendable {
    case preciseWaitingState
    case processFallback

    var label: String {
        switch self {
        case .preciseWaitingState: return "Waiting-state hooks"
        case .processFallback: return "Process fallback"
        }
    }

    var detail: String {
        switch self {
        case .preciseWaitingState:
            return "Precise waiting-state hooks are available for this tool."
        case .processFallback:
            return "Live activity uses process detection until this tool exposes stable hooks."
        }
    }
}

nonisolated enum PlatformDetectionSignalKind: Equatable, Sendable {
    case source
    case executable
}

nonisolated struct PlatformDetectionSignal: Equatable, Sendable {
    let kind: PlatformDetectionSignalKind
    let label: String
    let url: URL
    let isInstallSignal: Bool
}

nonisolated struct PlatformSourceStatus: Identifiable, Equatable, Sendable {
    let platform: AgentPlatform
    let isDetected: Bool
    let scanPaths: [URL]
    let detectionSignals: [PlatformDetectionSignal]
    let itemCount: Int
    let hookSupport: PlatformHookSupport

    var id: String { platform.id }

    var detectedSignal: PlatformDetectionSignal? {
        detectionSignals.first(where: \.isInstallSignal) ?? detectionSignals.first
    }

    var primaryPath: URL? {
        detectedSignal?.url
            ?? scanPaths.first { FileManager.default.fileExists(atPath: $0.path) }
            ?? scanPaths.first
    }

    var detectionLabel: String {
        detectedSignal?.label ?? "No install signal found"
    }

    var statusLabel: String {
        isDetected ? "Found" : "Not detected"
    }

    var hookSupportLabel: String {
        hookSupport.label
    }

    var notDetectedHint: String {
        PlatformDetectionProfile.profile(for: platform).notDetectedHint
    }
}

enum PlatformSourceDetector {
    static func detect(snapshot: CatalogSnapshot) -> [PlatformSourceStatus] {
        AgentPlatform.allCases.map { platform in
            let profile = PlatformDetectionProfile.profile(for: platform)
            let signals = detectionSignals(for: profile)
            let count = CatalogFilter.items(in: snapshot, section: .all, platform: platform).count
            return PlatformSourceStatus(
                platform: platform,
                isDetected: signals.contains(where: \.isInstallSignal),
                scanPaths: profile.sourcePaths,
                detectionSignals: signals,
                itemCount: count,
                hookSupport: profile.hookSupport
            )
        }
    }

    nonisolated static func isInstalled(platform: AgentPlatform) -> Bool {
        let profile = PlatformDetectionProfile.profile(for: platform)
        return detectionSignals(for: profile).contains(where: \.isInstallSignal)
    }

    static func detectedPlatforms(from statuses: [PlatformSourceStatus]) -> Set<AgentPlatform> {
        Set(statuses.filter(\.isDetected).map(\.platform))
    }

    static func defaultNewSkillPlatforms(from statuses: [PlatformSourceStatus]) -> Set<AgentPlatform> {
        // When nothing is detected, don't pre-check absent tools — that would create
        // skill folders for platforms the user hasn't installed. Force a deliberate choice.
        detectedPlatforms(from: statuses)
    }

    static func allScanPaths(for platform: AgentPlatform) -> [URL] {
        PlatformDetectionProfile.profile(for: platform).sourcePaths
    }
}

nonisolated private struct PlatformDetectionProfile: Sendable {
    let platform: AgentPlatform
    let sourcePaths: [URL]
    let executableNames: [String]
    let notDetectedHint: String
    let hookSupport: PlatformHookSupport

    static func profile(for platform: AgentPlatform) -> PlatformDetectionProfile {
        PlatformDetectionProfile(
            platform: platform,
            sourcePaths: unique(sourcePaths(for: platform)),
            executableNames: executableNames(for: platform),
            notDetectedHint: notDetectedHint(for: platform),
            hookSupport: hookSupport(for: platform)
        )
    }

    private static func sourcePaths(for platform: AgentPlatform) -> [URL] {
        var paths = PlatformSkillPaths.skillScanRoots(for: platform)
        switch platform {
        case .cursor:
            paths.append(platform.homeDirectory.appendingPathComponent("mcp.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("agent-hooks.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("skills-cursor", isDirectory: true))
        case .claudeCode:
            paths.append(platform.homeDirectory.appendingPathComponent("settings.json"))
            paths.append(platform.homeDirectory.appendingPathComponent(".mcp.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/installed_plugins.json"))
        case .codex:
            paths.append(platform.homeDirectory.appendingPathComponent("config.toml"))
            paths.append(platform.homeDirectory.appendingPathComponent("hooks.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins/cache", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("process_manager/chat_processes.json"))
        case .hermes:
            paths.append(platform.homeDirectory.appendingPathComponent("config.yaml"))
            paths.append(platform.homeDirectory.appendingPathComponent("processes.json"))
            paths.append(platform.homeDirectory.appendingPathComponent("sessions", isDirectory: true))
            paths.append(platform.homeDirectory.appendingPathComponent("plugins", isDirectory: true))
        case .pi:
            break
        case .openClaw:
            paths.append(PlatformSkillPaths.agentsSkillsDirectory)
            paths.append(OpenClawConfig.configURL)
            let workspace = OpenClawConfig.workspaceDirectory()
            paths.append(workspace)
            paths.append(OpenClawConfig.workspaceSkillsDirectory())
            paths.append(AgentPaths.environment.homeDirectory.appendingPathComponent(".opencode", isDirectory: true))
        }

        paths.append(platform.homeDirectory)
        return paths
    }

    private static func executableNames(for platform: AgentPlatform) -> [String] {
        switch platform {
        case .cursor:
            return ["cursor-agent", "cursor"]
        case .claudeCode:
            return ["claude"]
        case .codex:
            return ["codex"]
        case .hermes:
            return ["hermes", "hermes-cli", "tirith"]
        case .pi:
            return ["pi"]
        case .openClaw:
            return ["opencode", "open-code", "openclaw", "open-claw"]
        }
    }

    private static func notDetectedHint(for platform: AgentPlatform) -> String {
        switch platform {
        case .cursor:
            return "Install Cursor or add skills under ~/.cursor/skills."
        case .claudeCode:
            return "Install Claude Code or add skills under ~/.claude/skills."
        case .codex:
            return "Install Codex or add skills under ~/.codex/skills."
        case .hermes:
            return "Install Hermes or add skills under ~/.hermes/skills."
        case .pi:
            return "Install Pi or add skills under ~/.pi/agent/skills."
        case .openClaw:
            return "Install OpenCode or add skills under the legacy ~/.openclaw layout."
        }
    }

    private static func hookSupport(for platform: AgentPlatform) -> PlatformHookSupport {
        switch platform {
        case .cursor, .claudeCode, .codex:
            return .preciseWaitingState
        case .hermes, .pi, .openClaw:
            return .processFallback
        }
    }

    private static func unique(_ paths: [URL]) -> [URL] {
        var seen = Set<String>()
        return paths.filter { seen.insert($0.path).inserted }
    }
}

private extension PlatformSourceDetector {
    nonisolated static func detectionSignals(for profile: PlatformDetectionProfile) -> [PlatformDetectionSignal] {
        var signals: [PlatformDetectionSignal] = []

        for path in profile.sourcePaths where FileManager.default.fileExists(atPath: path.path) {
            signals.append(PlatformDetectionSignal(
                kind: .source,
                label: sourceLabel(for: path),
                url: path,
                isInstallSignal: isInstallSource(path)
            ))
        }

        for root in PlatformSkillPaths.skillScanRoots(for: profile.platform) where directoryContainsSkillMD(at: root) {
            let signal = PlatformDetectionSignal(
                kind: .source,
                label: sourceLabel(for: root),
                url: root,
                isInstallSignal: isInstallSource(root)
            )
            if !signals.contains(signal) {
                signals.append(signal)
            }
        }

        for executable in executableCandidates(named: profile.executableNames) {
            guard FileManager.default.isExecutableFile(atPath: executable.path) else { continue }
            signals.append(PlatformDetectionSignal(
                kind: .executable,
                label: "Executable",
                url: executable,
                isInstallSignal: true
            ))
        }

        var seen = Set<String>()
        return signals.filter { seen.insert("\($0.kind)-\($0.url.path)").inserted }
    }

    nonisolated private static func executableCandidates(named names: [String]) -> [URL] {
        AgentPaths.environment.executableSearchDirectories.flatMap { directory in
            names.map { directory.appendingPathComponent($0) }
        }
    }

    nonisolated private static func sourceLabel(for url: URL) -> String {
        if isSharedSkillSource(url) {
            return "Shared skill source"
        }
        let name = url.lastPathComponent
        if name == "SKILL.md" || name == "skills" || url.path.contains("/skills") {
            return "Skill source"
        }
        if name == "mcp.json" || name == ".mcp.json" || name == "config.toml" {
            return "Config"
        }
        if name.contains("plugin") || url.path.contains("/plugins") {
            return "Plugin source"
        }
        return "Home folder"
    }

    nonisolated private static func isInstallSource(_ url: URL) -> Bool {
        // A bare home directory (e.g. an empty ~/.cursor left after uninstalling,
        // or created by unrelated software) is shown for context but must not count
        // as "installed" — otherwise we'd auto-install hooks into a tool the user
        // doesn't actually run. Real config files, skill dirs, and executables still do.
        !isSharedSkillSource(url) && !isBareHomeDirectory(url)
    }

    nonisolated private static func isBareHomeDirectory(_ url: URL) -> Bool {
        AgentPlatform.allCases.contains { url.standardizedFileURL == $0.homeDirectory.standardizedFileURL }
    }

    nonisolated private static func isSharedSkillSource(_ url: URL) -> Bool {
        let sharedPath = PlatformSkillPaths.agentsSkillsDirectory.path
        return url.path == sharedPath || url.path.hasPrefix("\(sharedPath)/")
    }

    nonisolated static func directoryContainsSkillMD(at url: URL) -> Bool {
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
