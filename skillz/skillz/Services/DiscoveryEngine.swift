import Foundation

struct CatalogSnapshot: Sendable {
    var skills: [SkillItem] = []
    var mcps: [MCPItem] = []
    var plugins: [PluginItem] = []

    var allItems: [CatalogItem] {
        skills.map { .skill($0) }
            + mcps.map { .mcp($0) }
            + plugins.map { .plugin($0) }
    }
}

enum DiscoveryEngine {
    nonisolated static func discover(
        hideBuiltInCursor: Bool,
        hideSystemCodex: Bool
    ) -> CatalogSnapshot {
        CatalogSnapshot(
            skills: SkillScanner.scan(
                hideBuiltInCursor: hideBuiltInCursor,
                hideSystemCodex: hideSystemCodex
            ),
            mcps: MCPScanner.scan(),
            plugins: PluginScanner.scan()
        )
    }
}
