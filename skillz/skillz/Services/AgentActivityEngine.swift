import Foundation

nonisolated enum AgentActivityEngine {
    enum DiscoveryScope: Sendable {
        case fast
        case full
    }

    static func merge(
        hookSessions: [AgentSession],
        fileSessions: [AgentSession],
        now: Date = Date()
    ) -> [AgentSession] {
        var byID: [String: AgentSession] = [:]

        for session in fileSessions {
            byID[session.id] = session
        }

        for hookSession in hookSessions {
            if var existing = byID[hookSession.id] {
                existing = mergePair(existing: existing, incoming: hookSession)
                byID[hookSession.id] = existing
            } else {
                byID[hookSession.id] = hookSession
            }
        }

        return collapseDuplicateSessions(Array(byID.values))
            .map { applyStaleRules($0, now: now) }
            .filter { session in
                if session.state != .unknown { return true }
                return now.timeIntervalSince(session.updatedAt) < 300
            }
            .sorted { lhs, rhs in
                if lhs.state.priority != rhs.state.priority {
                    return lhs.state.priority > rhs.state.priority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    static func discover(scope: DiscoveryScope = .full, now: Date = Date()) -> [AgentSession] {
        let hookSessions = AgentStateFile.load()
        let fileSessions: [AgentSession]
        switch scope {
        case .fast:
            fileSessions = ShellAgentProcessAdapter.scan()
        case .full:
            fileSessions =
                ClaudeSessionAdapter.scan()
                + CodexSessionAdapter.scan()
                + CursorSessionAdapter.scan()
                + ShellAgentProcessAdapter.scan()
        }
        return merge(hookSessions: hookSessions, fileSessions: fileSessions, now: now)
    }

    private static func mergePair(existing: AgentSession, incoming: AgentSession) -> AgentSession {
        let state: AgentActivityState
        if incoming.source == .hooks && incoming.state == .needsInput {
            state = incoming.state
        } else if existing.source == .hooks && existing.state == .needsInput {
            state = existing.state
        } else {
            state = incoming.state.priority >= existing.state.priority ? incoming.state : existing.state
        }
        let updatedAt = max(existing.updatedAt, incoming.updatedAt)

        return AgentSession(
            id: existing.id,
            platform: existing.platform,
            state: state,
            title: preferredTitle(existing: existing, incoming: incoming),
            cwd: incoming.cwd ?? existing.cwd,
            pid: incoming.pid ?? existing.pid,
            updatedAt: updatedAt,
            source: .merged
        )
    }

    private static func collapseDuplicateSessions(_ sessions: [AgentSession]) -> [AgentSession] {
        let platformsWithBetterSignals = Set(
            sessions
                .filter { $0.source != .process }
                .map(\.platform)
        )
        var byKey: [String: AgentSession] = [:]
        var passthrough: [AgentSession] = []

        for session in sessions.sorted(by: sessionIdentitySort) {
            if session.source == .process,
               canonicalCWD(session.cwd) == nil,
               platformsWithBetterSignals.contains(session.platform) {
                continue
            }

            guard let key = duplicateKey(for: session) else {
                passthrough.append(session)
                continue
            }

            if let existing = byKey[key] {
                byKey[key] = mergePair(existing: existing, incoming: session)
            } else {
                byKey[key] = session
            }
        }

        return passthrough + Array(byKey.values)
    }

    private static func sessionIdentitySort(_ lhs: AgentSession, _ rhs: AgentSession) -> Bool {
        if identityRank(lhs.source) != identityRank(rhs.source) {
            return identityRank(lhs.source) > identityRank(rhs.source)
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private static func identityRank(_ source: AgentSessionSource) -> Int {
        switch source {
        case .hooks: return 3
        case .fileWatch, .merged: return 2
        case .process: return 1
        }
    }

    private static func duplicateKey(for session: AgentSession) -> String? {
        if let cwd = canonicalCWD(session.cwd) {
            return "\(session.platform.rawValue):cwd:\(cwd)"
        }

        if session.source == .process {
            return "\(session.platform.rawValue):process-fallback"
        }

        return nil
    }

    private static func canonicalCWD(_ cwd: String?) -> String? {
        guard let cwd,
              !cwd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return (cwd as NSString)
            .standardizingPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func preferredTitle(existing: AgentSession, incoming: AgentSession) -> String {
        if titleScore(incoming) > titleScore(existing) {
            return incoming.title
        }
        if titleScore(existing) > 0 {
            return existing.title
        }
        return incoming.title
    }

    private static func titleScore(_ session: AgentSession) -> Int {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return 0 }

        var score = 1
        if title != session.platform.displayName && title != "Session active" {
            score += 2
        }
        if session.source != .process {
            score += 1
        }
        if let cwd = session.cwd,
           title == (cwd as NSString).lastPathComponent {
            score += 1
        }
        return score
    }

    static func applyStaleRules(_ session: AgentSession, now: Date) -> AgentSession {
        var updated = session

        if session.state == .working,
           now.timeIntervalSince(session.updatedAt) > AgentPaths.staleWorkingInterval {
            updated.state = .unknown
        }

        if session.state == .needsInput,
           now.timeIntervalSince(session.updatedAt) > AgentPaths.staleNeedsInputInterval {
            updated.state = .unknown
        }

        if session.state == .idle,
           now.timeIntervalSince(session.updatedAt) > AgentPaths.staleIdleInterval {
            updated.state = .unknown
        }

        if let pid = session.pid, !isProcessAlive(pid) {
            if session.state == .working || session.state == .needsInput {
                updated.state = .unknown
            }
        }

        return updated
    }

    static func isProcessAlive(_ pid: Int) -> Bool {
        kill(pid_t(pid), 0) == 0
    }

    static func summary(for sessions: [AgentSession]) -> AgentActivitySummary {
        let needsInput = sessions.filter { $0.state == .needsInput }
        let working = sessions.filter { $0.state == .working }
        return AgentActivitySummary(
            sessions: sessions,
            needsInputCount: needsInput.count,
            workingCount: working.count,
            hasNeedsInput: !needsInput.isEmpty
        )
    }
}

struct AgentActivitySummary: Equatable, Sendable {
    let sessions: [AgentSession]
    let needsInputCount: Int
    let workingCount: Int
    let hasNeedsInput: Bool

    func bestSession(for platform: AgentPlatform) -> AgentSession? {
        sessions
            .filter { $0.platform == platform }
            .sorted { lhs, rhs in
                if lhs.state.priority != rhs.state.priority {
                    return lhs.state.priority > rhs.state.priority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .first
    }

    var notchAttentionSessions: [AgentSession] {
        sessions.filter { $0.state == .needsInput || $0.state == .idle }
    }

    var notchDisplaySessions: [AgentSession] {
        sessions.filter { $0.state == .needsInput || $0.state == .idle || $0.state == .working }
    }

    var notchClosedSessions: [AgentSession] {
        let active = sessions.filter { $0.state == .working || $0.state == .needsInput }
        return active.isEmpty ? sessions.filter { $0.state == .idle } : active
    }

    var hasNotchAttention: Bool {
        !notchAttentionSessions.isEmpty
    }
}
