import Foundation

nonisolated enum AgentPlatform: String, CaseIterable, Identifiable, Codable, Sendable {
    case cursor
    case claudeCode
    case codex
    case hermes
    case pi
    case openClaw

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .hermes: return "Hermes"
        case .pi: return "Pi"
        case .openClaw: return "OpenClaw"
        }
    }

    var symbolName: String {
        switch self {
        case .cursor: return "cursorarrow.rays"
        case .claudeCode: return "bubble.left.and.bubble.right"
        case .codex: return "terminal"
        case .hermes: return "bolt.fill"
        case .pi: return "laptopcomputer"
        case .openClaw: return "antenna.radiowaves.left.and.right"
        }
    }

    /// Lobe Icons asset name for notch UI (cursor, claudecode, codex/OpenAI).
    var brandIconAssetName: String? {
        switch self {
        case .cursor: return "PlatformIconCursor"
        case .claudeCode: return "PlatformIconClaudeCode"
        case .codex: return "PlatformIconCodex"
        default: return nil
        }
    }

    var homeDirectory: URL {
        AgentPaths.environment.homeDirectory(for: self)
    }

    /// User-writable skills folder for creating new skills.
    var userSkillsDirectory: URL {
        switch self {
        case .cursor, .claudeCode, .codex, .hermes:
            return homeDirectory.appendingPathComponent("skills", isDirectory: true)
        case .pi:
            return homeDirectory.appendingPathComponent("agent/skills", isDirectory: true)
        case .openClaw:
            return homeDirectory.appendingPathComponent("skills", isDirectory: true)
        }
    }

    static var agentsDirectory: URL {
        AgentPaths.environment.homeDirectory.appendingPathComponent(".agents", isDirectory: true)
    }
}

nonisolated enum CatalogSection: String, CaseIterable, Identifiable, Sendable {
    case all
    case skills
    case mcpServers
    case plugins

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All Items"
        case .skills: return "Skills"
        case .mcpServers: return "MCP Servers"
        case .plugins: return "Plugins"
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .skills: return "sparkles"
        case .mcpServers: return "server.rack"
        case .plugins: return "puzzlepiece.extension"
        }
    }
}

nonisolated enum CatalogItemKind: String, Sendable {
    case skill
    case mcp
    case plugin

    var displayName: String {
        switch self {
        case .skill: return "Skill"
        case .mcp: return "MCP Server"
        case .plugin: return "Plugin"
        }
    }
}
