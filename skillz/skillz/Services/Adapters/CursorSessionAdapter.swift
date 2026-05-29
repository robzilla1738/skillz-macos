import Foundation

enum CursorSessionAdapter {
    private static let recentWindow: TimeInterval = 180

    static func scan() -> [AgentSession] {
        let root = AgentPaths.cursorProjectsDirectory
        guard FileManager.default.fileExists(atPath: root.path),
              let projects = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
              )
        else { return [] }

        var sessions: [AgentSession] = []
        let now = Date()

        for project in projects where project.hasDirectoryPath {
            if let terminal = mostRecentTerminal(in: project, since: now.addingTimeInterval(-recentWindow)) {
                sessions.append(terminal)
            }
            if let transcript = mostRecentTranscript(in: project, since: now.addingTimeInterval(-recentWindow)) {
                sessions.append(transcript)
            }
        }

        return dedupe(sessions)
    }

    private static func dedupe(_ sessions: [AgentSession]) -> [AgentSession] {
        var byKey: [String: AgentSession] = [:]
        for session in sessions {
            let key = session.cwd ?? session.id
            if let existing = byKey[key], existing.updatedAt > session.updatedAt {
                continue
            }
            byKey[key] = session
        }
        return Array(byKey.values)
    }

    private static func mostRecentTerminal(in project: URL, since: Date) -> AgentSession? {
        let terminals = project.appendingPathComponent("terminals", isDirectory: true)
        guard FileManager.default.fileExists(atPath: terminals.path),
              let files = try? FileManager.default.contentsOfDirectory(
                at: terminals,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              )
        else { return nil }

        let recent = files
            .filter { $0.pathExtension == "txt" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return l > r
            }
            .first

        guard let file = recent,
              let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              modified >= since,
              let content = try? String(contentsOf: file, encoding: .utf8),
              isTerminalRunning(content)
        else { return nil }

        let cwd = parseYAMLHeader(content, key: "cwd") ?? project.path
        let pid = Int(parseYAMLHeader(content, key: "pid") ?? "")
        if let pid, !AgentActivityEngine.isProcessAlive(pid) {
            return nil
        }
        return AgentSession(
            id: "cursor:terminal:\(file.lastPathComponent)",
            platform: .cursor,
            state: .working,
            title: (cwd as NSString).lastPathComponent,
            cwd: cwd,
            pid: pid,
            updatedAt: modified,
            source: .fileWatch
        )
    }

    private static func mostRecentTranscript(in project: URL, since: Date) -> AgentSession? {
        let transcripts = project.appendingPathComponent("agent-transcripts", isDirectory: true)
        guard FileManager.default.fileExists(atPath: transcripts.path) else { return nil }

        var newest: (url: URL, date: Date)?
        guard let enumerator = FileManager.default.enumerator(
            at: transcripts,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let file as URL in enumerator {
            guard file.pathExtension == "jsonl" else { continue }
            guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  modified >= since
            else { continue }
            if newest == nil || modified > newest!.date {
                newest = (file, modified)
            }
        }

        guard let newest else { return nil }

        return AgentSession(
            id: "cursor:transcript:\(newest.url.deletingLastPathComponent().lastPathComponent)",
            platform: .cursor,
            state: .working,
            title: (project.lastPathComponent as NSString).deletingPathExtension,
            cwd: project.path,
            pid: nil,
            updatedAt: newest.date,
            source: .fileWatch
        )
    }

    private static func isTerminalRunning(_ content: String) -> Bool {
        !content.contains("exit_code:") && !content.contains("ended_at:")
    }

    private static func parseYAMLHeader(_ content: String, key: String) -> String? {
        guard content.hasPrefix("---") else { return nil }
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 2 else { return nil }
        for line in parts[1].split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\(key):") {
                return trimmed
                    .replacingOccurrences(of: "\(key):", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }
}
