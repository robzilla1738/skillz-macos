import Foundation

nonisolated enum ShellAgentProcessAdapter {
    /// Testable seam: resolve the agent platform for a process command/arguments, or nil if not an agent.
    static func matchedPlatform(commandName: String, arguments: String) -> AgentPlatform? {
        AgentProcessSpec.allCases.first {
            $0.matches(commandName: commandName.lowercased(), arguments: arguments.lowercased())
        }?.platform
    }

    static func scan() -> [AgentSession] {
        let candidates = processRows().compactMap { row -> (ProcessRow, AgentProcessSpec)? in
            guard let spec = AgentProcessSpec.match(for: row) else { return nil }
            return (row, spec)
        }
        let cwdByPID = cwdByPID(for: candidates.map { $0.0.pid })
        return candidates.map { row, spec in
            session(from: row, spec: spec, cwd: cwdByPID[row.pid])
        }
    }

    private static func session(from row: ProcessRow, spec: AgentProcessSpec, cwd: String?) -> AgentSession {
        AgentSession(
            id: "\(spec.platform.rawValue):process:\(row.pid)",
            platform: spec.platform,
            state: .working,
            title: cwd.map { ($0 as NSString).lastPathComponent } ?? spec.platform.displayName,
            cwd: cwd,
            pid: row.pid,
            updatedAt: Date(),
            source: .process
        )
    }

    private static func processRows() -> [ProcessRow] {
        guard let result = ShellProcessRunner.run(
            executablePath: "/bin/ps",
            arguments: ["-axo", "pid=,ppid=,comm=,args="],
            timeout: 1.5
        ),
        !result.didTimeOut,
        result.terminationStatus == 0
        else { return [] }

        return result.standardOutput.split(separator: "\n").compactMap { line in
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

    private static func cwdByPID(for pids: [Int]) -> [Int: String] {
        let uniquePIDs = Array(Set(pids)).sorted()
        guard !uniquePIDs.isEmpty,
              let result = ShellProcessRunner.run(
                executablePath: "/usr/sbin/lsof",
                arguments: ["-nP", "-F", "pn", "-a", "-d", "cwd", "-p", uniquePIDs.map(String.init).joined(separator: ",")],
                timeout: 1
              ),
              !result.didTimeOut,
              result.terminationStatus == 0
        else { return [:] }

        var cwdByPID: [Int: String] = [:]
        var currentPID: Int?

        for line in result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("p") {
                currentPID = Int(line.dropFirst())
            } else if line.hasPrefix("n"),
                      let currentPID {
                cwdByPID[currentPID] = String(line.dropFirst())
            }
        }

        return cwdByPID
    }
}

nonisolated private struct ProcessRow {
    let pid: Int
    let parentPID: Int
    let command: String
    let arguments: String
}

nonisolated private enum AgentProcessSpec: CaseIterable {
    case cursor
    case claudeCode
    case codex
    case hermes
    case pi
    case openClaw

    var platform: AgentPlatform {
        switch self {
        case .cursor: return .cursor
        case .claudeCode: return .claudeCode
        case .codex: return .codex
        case .hermes: return .hermes
        case .pi: return .pi
        case .openClaw: return .openClaw
        }
    }

    static func match(for row: ProcessRow) -> AgentProcessSpec? {
        let commandName = (row.command as NSString).lastPathComponent.lowercased()
        let arguments = row.arguments.lowercased()
        return allCases.first { $0.matches(commandName: commandName, arguments: arguments) }
    }

    func matches(commandName: String, arguments: String) -> Bool {
        switch self {
        case .cursor:
            // Match the Cursor agent CLI, not the Cursor desktop app or its Electron helpers.
            if arguments.contains("/applications/cursor.app/contents/macos/") { return false }
            if arguments.contains("--type=") { return false }
            if commandName.contains("helper") { return false }
            return commandName == "cursor-agent" || commandName == "cursor"
        case .claudeCode:
            return (commandName == "claude" || arguments.hasPrefix("claude "))
                && !arguments.contains(" remote-control")
                && !arguments.contains(" --print ")
        case .codex:
            return commandName == "codex"
                && !arguments.contains(" app-server")
                && !arguments.contains("/applications/codex.app/contents/macos/codex")
        case .hermes:
            return commandName == "hermes" || commandName == "hermes-cli"
        case .pi:
            return commandName == "pi"
        case .openClaw:
            return commandName == "opencode"
                || commandName == "open-code"
                || commandName == "openclaw"
                || commandName == "open-claw"
        }
    }
}
