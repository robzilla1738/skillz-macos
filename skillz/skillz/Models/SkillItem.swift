import Foundation

nonisolated struct SkillFrontmatter: Equatable, Sendable {
    var name: String?
    var description: String?
    var version: String?
    var disableModelInvocation: Bool?
}

nonisolated struct SkillItem: Identifiable, Equatable, Sendable {
    let id: String
    let platform: AgentPlatform
    let skillPath: URL
    let rootDirectory: URL
    let displayName: String
    let description: String
    let version: String?
    let isBuiltIn: Bool
    let isPluginEmbedded: Bool
    let frontmatter: SkillFrontmatter
    let modifiedAt: Date?
    /// Other harnesses that read the same `skillPath` (e.g. shared `~/.agents/skills`).
    let alsoAvailableOn: [AgentPlatform]

    var listSubtitle: String {
        skillPath.deletingLastPathComponent().path
    }

    var hasSharedAvailability: Bool {
        !alsoAvailableOn.isEmpty
    }

    static func makeID(platform: AgentPlatform, path: URL) -> String {
        "skill:\(platform.rawValue):\(path.path)"
    }
}

nonisolated struct SkillMarkdownFile: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let displayName: String
    let isPrimary: Bool

    init(url: URL, isPrimary: Bool = false) {
        self.id = url.path
        self.url = url
        self.displayName = url.lastPathComponent
        self.isPrimary = isPrimary
    }
}
