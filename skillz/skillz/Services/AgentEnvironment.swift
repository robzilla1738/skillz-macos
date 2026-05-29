import Foundation

nonisolated struct AgentEnvironment: Sendable {
    var homeDirectory: URL
    var applicationSupportDirectory: URL
    var skillzHomeDirectory: URL

    static var live: AgentEnvironment {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return AgentEnvironment(
            homeDirectory: home,
            applicationSupportDirectory: FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Skillz", isDirectory: true),
            skillzHomeDirectory: home.appendingPathComponent(".skillz", isDirectory: true)
        )
    }

    static func temporary(root: URL) -> AgentEnvironment {
        AgentEnvironment(
            homeDirectory: root,
            applicationSupportDirectory: root
                .appendingPathComponent("Library/Application Support/Skillz", isDirectory: true),
            skillzHomeDirectory: root.appendingPathComponent(".skillz", isDirectory: true)
        )
    }

    func homeDirectory(for platform: AgentPlatform) -> URL {
        switch platform {
        case .cursor: return homeDirectory.appendingPathComponent(".cursor", isDirectory: true)
        case .claudeCode: return homeDirectory.appendingPathComponent(".claude", isDirectory: true)
        case .codex: return homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        case .hermes: return homeDirectory.appendingPathComponent(".hermes", isDirectory: true)
        case .pi: return homeDirectory.appendingPathComponent(".pi", isDirectory: true)
        case .openClaw: return homeDirectory.appendingPathComponent(".openclaw", isDirectory: true)
        }
    }
}
