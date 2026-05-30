import AppKit
import Foundation

enum AgentSessionActivator {
    @MainActor
    static func activateOwningApp(for session: AgentSession) async -> Bool {
        guard let pid = session.pid else { return false }
        let appPID = await Task.detached(priority: .userInitiated) {
            owningAppPID(startingAt: pid, platform: session.platform)
        }.value

        guard let appPID,
              let app = NSRunningApplication(processIdentifier: appPID)
        else {
            return false
        }

        return app.activate(options: [.activateAllWindows])
    }

    private nonisolated static func owningAppPID(startingAt pid: Int, platform: AgentPlatform) -> pid_t? {
        let processes = processTable()
        var current = pid
        var seen = Set<Int>()

        for _ in 0..<32 {
            guard current > 1, seen.insert(current).inserted else { break }
            if let app = NSRunningApplication(processIdentifier: pid_t(current)),
               app.matchesAgentHost(for: platform) {
                return pid_t(current)
            }
            guard let parent = processes[current]?.parentPID else { break }
            current = parent
        }

        return nil
    }

    private nonisolated static func processTable() -> [Int: ProcessRecord] {
        guard let result = ShellProcessRunner.run(
            executablePath: "/bin/ps",
            arguments: ["-axo", "pid=,ppid=,comm="],
            timeout: 1.5
        ),
        !result.didTimeOut,
        result.terminationStatus == 0
        else { return [:] }

        var records: [Int: ProcessRecord] = [:]
        for line in result.standardOutput.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 2,
                  let pid = Int(parts[0]),
                  let parentPID = Int(parts[1])
            else { continue }

            records[pid] = ProcessRecord(parentPID: parentPID)
        }
        return records
    }
}

private struct ProcessRecord {
    let parentPID: Int
}

nonisolated private extension NSRunningApplication {
    func matchesAgentHost(for platform: AgentPlatform) -> Bool {
        let bundleID = bundleIdentifier ?? ""
        let name = localizedName ?? ""

        switch platform {
        case .cursor:
            return bundleID.localizedCaseInsensitiveContains("cursor")
                || name.localizedCaseInsensitiveContains("cursor")
        case .codex, .claudeCode, .hermes, .pi, .openClaw:
            return isTerminalHost(bundleID: bundleID, name: name)
        }
    }

    func isTerminalHost(bundleID: String, name: String) -> Bool {
        let knownBundleIDs: Set<String> = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "dev.warp.Warp-Stable",
            "com.mitchellh.ghostty",
            "com.github.wez.wezterm",
            "net.kovidgoyal.kitty",
            "org.alacritty",
        ]
        if knownBundleIDs.contains(bundleID) { return true }

        let terminalNames = ["Terminal", "iTerm", "Warp", "Ghostty", "WezTerm", "kitty", "Alacritty"]
        return terminalNames.contains { name.localizedCaseInsensitiveContains($0) }
    }
}
