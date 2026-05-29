import Foundation

enum AgentActivityEngine {
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

        return byID.values
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

    static func discover(now: Date = Date()) -> [AgentSession] {
        let hookSessions = AgentStateFile.load()
        let fileSessions =
            ClaudeSessionAdapter.scan()
            + CodexSessionAdapter.scan()
            + CursorSessionAdapter.scan()
        return merge(hookSessions: hookSessions, fileSessions: fileSessions, now: now)
    }

    private static func mergePair(existing: AgentSession, incoming: AgentSession) -> AgentSession {
        let state: AgentActivityState
        if incoming.source == .hooks {
            state = incoming.state
        } else if existing.source == .hooks {
            state = existing.state
        } else {
            state = incoming.state.priority >= existing.state.priority ? incoming.state : existing.state
        }
        let updatedAt = max(existing.updatedAt, incoming.updatedAt)

        return AgentSession(
            id: existing.id,
            platform: existing.platform,
            state: state,
            title: incoming.title.isEmpty ? existing.title : incoming.title,
            cwd: incoming.cwd ?? existing.cwd,
            pid: incoming.pid ?? existing.pid,
            updatedAt: updatedAt,
            source: .merged
        )
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
        AgentPlatform.trackedAgentPlatforms.compactMap { platform in
            bestSession(for: platform)
        }
        .filter { $0.state == .needsInput || $0.state == .idle }
    }

    var notchDisplaySessions: [AgentSession] {
        let attention = notchAttentionSessions
        if !attention.isEmpty { return attention }
        return AgentPlatform.trackedAgentPlatforms.compactMap { platform in
            bestSession(for: platform)
        }
    }

    var hasNotchAttention: Bool {
        !notchAttentionSessions.isEmpty
    }
}
