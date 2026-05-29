import Foundation

nonisolated enum MCPTransport: String, Sendable {
    case stdio
    case http
    case unknown
}

nonisolated struct MCPItem: Identifiable, Equatable, Sendable {
    let id: String
    let platform: AgentPlatform
    let name: String
    let transport: MCPTransport
    let command: String?
    let args: [String]
    let url: String?
    let envKeys: [String]
    let configFileURL: URL
    let modifiedAt: Date?

    var transportLabel: String {
        switch transport {
        case .stdio: return "stdio"
        case .http: return "HTTP"
        case .unknown: return "Unknown"
        }
    }

    var endpointSummary: String {
        if let url, !url.isEmpty { return url }
        if let command {
            let argText = args.isEmpty ? "" : " " + args.joined(separator: " ")
            return command + argText
        }
        return "—"
    }

    static func makeID(platform: AgentPlatform, name: String) -> String {
        "mcp:\(platform.rawValue):\(name)"
    }
}
