import Foundation

enum CodexSessionAdapter {
    static func scan() -> [AgentSession] {
        var sessions: [AgentSession] = []
        sessions += scanChatProcesses()
        sessions += scanRecentRollouts()
        return sessions
    }

    private static func scanChatProcesses() -> [AgentSession] {
        let url = AgentPaths.codexChatProcessesFile
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !json.isEmpty
        else { return [] }

        return json.compactMap { entry -> AgentSession? in
            let id = (entry["id"] as? String) ?? (entry["session_id"] as? String) ?? UUID().uuidString
            let cwd = entry["cwd"] as? String
            let pid = entry["pid"] as? Int
            let title = cwd.map { ($0 as NSString).lastPathComponent } ?? "Codex"
            return AgentSession(
                id: "codex:\(id)",
                platform: .codex,
                state: .working,
                title: title,
                cwd: cwd,
                pid: pid,
                updatedAt: Date(),
                source: .fileWatch
            )
        }
    }

    private static func scanRecentRollouts() -> [AgentSession] {
        let root = AgentPaths.codexSessionsDirectory
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }

        var rolloutFiles: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let file as URL in enumerator {
            guard file.lastPathComponent.hasPrefix("rollout-"),
                  file.pathExtension == "jsonl"
            else { continue }
            rolloutFiles.append(file)
        }

        let recent = rolloutFiles
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            .prefix(3)

        return recent.compactMap { inferFromRollout($0) }
    }

    private static func inferFromRollout(_ url: URL) -> AgentSession? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < 300
        else { return nil }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = try? handle.readToEnd()
        guard let data,
              let text = String(data: data, encoding: .utf8)
        else { return nil }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).suffix(8)
        var isActive = false
        var cwd: String?

        for line in lines {
            guard let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            if let meta = json["session_meta"] as? [String: Any],
               let path = meta["cwd"] as? String {
                cwd = path
            }
            if json["type"] as? String == "event_msg",
               let payload = json["payload"] as? [String: Any],
               payload["type"] as? String == "task_started" {
                isActive = true
            }
            if json["type"] as? String == "response_item" {
                isActive = true
            }
        }

        guard isActive else { return nil }

        let sessionID = url.deletingPathExtension().lastPathComponent
        return AgentSession(
            id: "codex:rollout:\(sessionID)",
            platform: .codex,
            state: .working,
            title: cwd.map { ($0 as NSString).lastPathComponent } ?? "Codex",
            cwd: cwd,
            pid: nil,
            updatedAt: modified,
            source: .fileWatch
        )
    }
}
