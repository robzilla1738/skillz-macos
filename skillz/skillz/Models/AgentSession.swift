import Foundation

enum AgentActivityState: String, Codable, Sendable, CaseIterable {
    case idle
    case working
    case needsInput
    case unknown

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .needsInput: return "Waiting for you"
        case .unknown: return "Unknown"
        }
    }

    var priority: Int {
        switch self {
        case .needsInput: return 3
        case .working: return 2
        case .idle: return 1
        case .unknown: return 0
        }
    }
}

struct AgentSession: Identifiable, Equatable, Sendable {
    let id: String
    let platform: AgentPlatform
    var state: AgentActivityState
    var title: String
    var cwd: String?
    var pid: Int?
    var updatedAt: Date
    var source: AgentSessionSource

    var listTitle: String {
        if !title.isEmpty { return title }
        if let cwd, !cwd.isEmpty {
            return (cwd as NSString).lastPathComponent
        }
        return platform.displayName
    }
}

enum AgentSessionSource: String, Codable, Sendable {
    case hooks
    case fileWatch
    case merged
}

struct AgentStateSnapshot: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    var sessions: [AgentSessionRecord]

    init(version: Int = currentVersion, sessions: [AgentSessionRecord] = []) {
        self.version = version
        self.sessions = sessions
    }
}

struct AgentSessionRecord: Codable, Sendable, Equatable {
    var id: String
    var platform: String
    var state: String
    var title: String
    var cwd: String?
    var pid: Int?
    var updatedAt: String

    func toSession() -> AgentSession? {
        guard let platform = AgentPlatform(rawValue: platform),
              let state = AgentActivityState(rawValue: state),
              AgentPlatform.trackedAgentPlatforms.contains(platform)
        else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: updatedAt)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: updatedAt)
        }

        return AgentSession(
            id: id,
            platform: platform,
            state: state,
            title: title,
            cwd: cwd,
            pid: pid,
            updatedAt: date ?? Date.distantPast,
            source: .hooks
        )
    }
}

extension AgentPlatform {
    static var trackedAgentPlatforms: [AgentPlatform] {
        [.cursor, .claudeCode, .codex]
    }
}
