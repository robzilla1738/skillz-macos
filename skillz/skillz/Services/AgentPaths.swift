import Foundation

nonisolated enum AgentPaths {
    static let stateFileVersion = 1
    static let staleWorkingInterval: TimeInterval = 90
    static let staleNeedsInputInterval: TimeInterval = 60 * 60
    static let staleIdleInterval: TimeInterval = 8
    nonisolated(unsafe) static var environment = AgentEnvironment.live

    static var applicationSupportDirectory: URL {
        environment.applicationSupportDirectory
    }

    static var agentStateFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("agent-state.json")
    }

    static var skillzHomeDirectory: URL {
        environment.skillzHomeDirectory
    }

    static var notifyScriptInstalledURL: URL {
        skillzHomeDirectory.appendingPathComponent("bin/skillz-agent-notify.sh")
    }

    static var claudeSessionsDirectory: URL {
        AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("sessions", isDirectory: true)
    }

    static var codexSessionsDirectory: URL {
        AgentPlatform.codex.homeDirectory.appendingPathComponent("sessions", isDirectory: true)
    }

    static var codexChatProcessesFile: URL {
        AgentPlatform.codex.homeDirectory
            .appendingPathComponent("process_manager/chat_processes.json")
    }

    static var cursorProjectsDirectory: URL {
        AgentPlatform.cursor.homeDirectory.appendingPathComponent("projects", isDirectory: true)
    }

    static func watchPathsForAgents() -> [URL] {
        let paths: [URL] = [
            applicationSupportDirectory,
            claudeSessionsDirectory,
            codexSessionsDirectory,
            codexChatProcessesFile,
            cursorProjectsDirectory,
        ]
        return paths.filter { path in
            if path.lastPathComponent == "chat_processes.json" {
                return FileManager.default.fileExists(atPath: path.path)
            }
            return FileManager.default.fileExists(atPath: path.deletingLastPathComponent().path)
                || FileManager.default.fileExists(atPath: path.path)
        }
    }
}
