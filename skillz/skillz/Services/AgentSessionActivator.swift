import AppKit
import Foundation

enum AgentSessionActivator {
    @MainActor
    static func activateOwningApp(for session: AgentSession) -> Bool {
        guard let pid = session.pid,
              let app = owningApp(startingAt: pid, platform: session.platform)
        else { return false }

        return app.activate(options: [.activateAllWindows])
    }

    private static func owningApp(startingAt pid: Int, platform: AgentPlatform) -> NSRunningApplication? {
        let processes = processTable()
        var current = pid
        var seen = Set<Int>()

        for _ in 0..<32 {
            guard current > 1, seen.insert(current).inserted else { break }
            if let app = NSRunningApplication(processIdentifier: pid_t(current)),
               app.matchesAgentHost(for: platform) {
                return app
            }
            guard let parent = processes[current]?.parentPID else { break }
            current = parent
        }

        return nil
    }

    private static func processTable() -> [Int: ProcessRecord] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return [:]
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var records: [Int: ProcessRecord] = [:]
        for line in output.split(separator: "\n") {
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

private extension NSRunningApplication {
    func matchesAgentHost(for platform: AgentPlatform) -> Bool {
        let bundleID = bundleIdentifier ?? ""
        let name = localizedName ?? ""

        switch platform {
        case .cursor:
            return bundleID.localizedCaseInsensitiveContains("cursor")
                || name.localizedCaseInsensitiveContains("cursor")
        case .codex, .claudeCode:
            return isTerminalHost(bundleID: bundleID, name: name)
        default:
            return false
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
