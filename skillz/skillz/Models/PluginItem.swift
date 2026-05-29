import Foundation

nonisolated struct PluginItem: Identifiable, Equatable, Sendable {
    let id: String
    let platform: AgentPlatform
    let pluginID: String
    let displayName: String
    let description: String
    let version: String?
    let marketplace: String?
    let isEnabled: Bool
    let installPath: URL?
    let metadataPath: URL?
    let skillCount: Int
    let modifiedAt: Date?

    var listSubtitle: String {
        if let marketplace { return marketplace }
        return pluginID
    }

    static func makeID(platform: AgentPlatform, pluginID: String, installPath: URL?) -> String {
        let path = installPath?.path ?? pluginID
        return "plugin:\(platform.rawValue):\(pluginID):\(path)"
    }
}
