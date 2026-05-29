import Foundation

enum AgentStateFile {
    static func ensureExists() throws {
        let directory = AgentPaths.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: AgentPaths.agentStateFileURL.path) else { return }
        try save(sessions: [])
    }

    static func load() -> [AgentSession] {
        guard let data = try? Data(contentsOf: AgentPaths.agentStateFileURL),
              let snapshot = try? JSONDecoder().decode(AgentStateSnapshot.self, from: data)
        else { return [] }

        return snapshot.sessions.compactMap { $0.toSession() }
    }

    static func save(sessions: [AgentSession]) throws {
        let directory = AgentPaths.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let records = sessions.map { session in
            AgentSessionRecord(
                id: session.id,
                platform: session.platform.rawValue,
                state: session.state.rawValue,
                title: session.title,
                cwd: session.cwd,
                pid: session.pid,
                updatedAt: formatter.string(from: session.updatedAt)
            )
        }

        let snapshot = AgentStateSnapshot(version: AgentPaths.stateFileVersion, sessions: records)
        let data = try JSONEncoder().encode(snapshot)
        let url = AgentPaths.agentStateFileURL
        let temp = url.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: temp, to: url)
    }
}
