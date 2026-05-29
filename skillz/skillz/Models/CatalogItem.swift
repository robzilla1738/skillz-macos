import Foundation

enum CatalogItem: Identifiable, Equatable, Sendable {
    case skill(SkillItem)
    case mcp(MCPItem)
    case plugin(PluginItem)

    var id: String {
        switch self {
        case .skill(let item): return item.id
        case .mcp(let item): return item.id
        case .plugin(let item): return item.id
        }
    }

    var kind: CatalogItemKind {
        switch self {
        case .skill: return .skill
        case .mcp: return .mcp
        case .plugin: return .plugin
        }
    }

    var platform: AgentPlatform {
        switch self {
        case .skill(let item): return item.platform
        case .mcp(let item): return item.platform
        case .plugin(let item): return item.platform
        }
    }

    var displayName: String {
        switch self {
        case .skill(let item): return item.displayName
        case .mcp(let item): return item.name
        case .plugin(let item): return item.displayName
        }
    }

    var descriptionText: String {
        switch self {
        case .skill(let item): return item.description
        case .mcp(let item): return item.endpointSummary
        case .plugin(let item): return item.description
        }
    }

    var listSubtitle: String {
        switch self {
        case .skill(let item): return item.listSubtitle
        case .mcp(let item): return item.configFileURL.path
        case .plugin(let item): return item.listSubtitle
        }
    }

    var modifiedAt: Date? {
        switch self {
        case .skill(let item): return item.modifiedAt
        case .mcp(let item): return item.modifiedAt
        case .plugin(let item): return item.modifiedAt
        }
    }

    var symbolName: String {
        switch kind {
        case .skill: return "sparkles"
        case .mcp: return "server.rack"
        case .plugin: return "puzzlepiece.extension"
        }
    }

    var skillItem: SkillItem? {
        if case .skill(let item) = self { return item }
        return nil
    }

    var mcpItem: MCPItem? {
        if case .mcp(let item) = self { return item }
        return nil
    }

    var pluginItem: PluginItem? {
        if case .plugin(let item) = self { return item }
        return nil
    }
}
