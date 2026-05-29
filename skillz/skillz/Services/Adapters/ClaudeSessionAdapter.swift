import Foundation

enum ClaudeSessionAdapter {
    static func scan() -> [AgentSession] {
        let directory = AgentPaths.claudeSessionsDirectory
        guard FileManager.default.fileExists(atPath: directory.path),
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              )
        else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { parseSession(at: $0) }
    }

    private static func parseSession(at url: URL) -> AgentSession? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let pid = json["pid"] as? Int
        let sessionId = json["sessionId"] as? String ?? url.deletingPathExtension().lastPathComponent
        let cwd = json["cwd"] as? String
        let status = (json["status"] as? String)?.lowercased() ?? "unknown"

        let state: AgentActivityState
        switch status {
        case "busy", "working": state = .working
        case "idle": state = .idle
        default: state = pid.map { AgentActivityEngine.isProcessAlive($0) } == true ? .working : .unknown
        }

        let fileModified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
        var updatedAt = fileModified
        if let ms = json["updatedAt"] as? Double {
            updatedAt = Date(timeIntervalSince1970: ms / 1000)
        } else if let ms = json["updatedAt"] as? Int {
            updatedAt = Date(timeIntervalSince1970: Double(ms) / 1000)
        }

        if let pid, !AgentActivityEngine.isProcessAlive(pid) {
            return nil
        }

        let id = "claude:\(pid ?? Int(sessionId.hashValue))"
        let title = cwd.map { ($0 as NSString).lastPathComponent } ?? "Claude Code"

        return AgentSession(
            id: id,
            platform: .claudeCode,
            state: state,
            title: title,
            cwd: cwd,
            pid: pid,
            updatedAt: updatedAt,
            source: .fileWatch
        )
    }
}
