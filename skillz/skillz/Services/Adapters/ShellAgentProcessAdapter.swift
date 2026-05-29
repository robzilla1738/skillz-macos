import Foundation

enum ShellAgentProcessAdapter {
    static func scan() -> [AgentSession] {
        processRows().compactMap(session(from:))
    }

    private static func session(from row: ProcessRow) -> AgentSession? {
        let commandName = (row.command as NSString).lastPathComponent

        if commandName == "codex", row.arguments.hasPrefix("codex") {
            return AgentSession(
                id: "codex:\(row.pid)",
                platform: .codex,
                state: .working,
                title: "Codex",
                cwd: nil,
                pid: row.pid,
                updatedAt: Date(),
                source: .fileWatch
            )
        }

        if commandName == "claude",
           row.arguments.hasPrefix("claude"),
           !row.arguments.contains(" remote-control"),
           !row.arguments.contains(" --print ") {
            return AgentSession(
                id: "claudeCode:\(row.pid)",
                platform: .claudeCode,
                state: .working,
                title: "Claude Code",
                cwd: nil,
                pid: row.pid,
                updatedAt: Date(),
                source: .fileWatch
            )
        }

        return nil
    }

    private static func processRows() -> [ProcessRow] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,comm=,args="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int(parts[0]),
                  let parentPID = Int(parts[1])
            else { return nil }

            return ProcessRow(
                pid: pid,
                parentPID: parentPID,
                command: String(parts[2]),
                arguments: String(parts[3])
            )
        }
    }
}

private struct ProcessRow {
    let pid: Int
    let parentPID: Int
    let command: String
    let arguments: String
}
