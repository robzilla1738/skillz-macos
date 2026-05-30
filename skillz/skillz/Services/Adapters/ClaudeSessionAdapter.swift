import Foundation

nonisolated enum ClaudeSessionAdapter {
    static func scan() -> [AgentSession] {
        scanSessionDirectory() + scanProjectTranscripts()
    }

    private static func scanSessionDirectory() -> [AgentSession] {
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

    private static func scanProjectTranscripts() -> [AgentSession] {
        let root = AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("projects", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path),
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              )
        else { return [] }

        var files: [URL] = []
        for case let file as URL in enumerator {
            guard file.pathExtension == "jsonl",
                  !file.path.contains("/subagents/")
            else { continue }
            files.append(file)
        }

        return files
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            .prefix(6)
            .compactMap { inferFromTranscript($0) }
    }

    private static func inferFromTranscript(_ url: URL) -> AgentSession? {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        guard Date().timeIntervalSince(modified) < 300 else { return nil }

        let projectName = url.deletingLastPathComponent().lastPathComponent
        let cwd = decodedProjectPath(from: projectName)
        let sessionID = url.deletingPathExtension().lastPathComponent
        return AgentSession(
            id: "claude:transcript:\(sessionID)",
            platform: .claudeCode,
            state: .working,
            title: cwd.map { ($0 as NSString).lastPathComponent } ?? "Claude Code",
            cwd: cwd,
            pid: nil,
            updatedAt: modified,
            source: .fileWatch
        )
    }

    private static func decodedProjectPath(from name: String) -> String? {
        guard name.hasPrefix("-") else { return nil }
        let path = "/" + name.dropFirst().replacingOccurrences(of: "-", with: "/")
        return path == "/" ? nil : path
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
