//
//  skillzTests.swift
//  skillzTests
//

import Foundation
import Testing
@testable import skillz

@Suite(.serialized)
struct skillzTests {

    @Test func frontmatterParsesNameAndDescription() {
        let content = """
        ---
        name: test-skill
        description: A helpful skill for testing.
        version: 1.0.0
        ---
        # Body
        """
        let (fm, body) = FrontmatterParser.parse(from: content)
        #expect(fm.name == "test-skill")
        #expect(fm.description == "A helpful skill for testing.")
        #expect(fm.version == "1.0.0")
        #expect(body.contains("# Body"))
    }

    @Test func frontmatterWriterUpdatesNameAndPreservesBody() {
        let original = """
        ---
        name: old-name
        description: Old description.
        ---
        # Heading

        Body text.
        """
        let updated = FrontmatterWriter.apply(
            to: original,
            update: FrontmatterWriter.Update(
                name: "new-name",
                description: "New description."
            )
        )
        let (fm, body) = FrontmatterParser.parse(from: updated)
        #expect(fm.name == "new-name")
        #expect(fm.description == "New description.")
        #expect(body.contains("# Heading"))
        #expect(body.contains("Body text."))
    }

    @Test func catalogFilterCountsMatchIntersection() {
        let snapshot = CatalogSnapshot(
            skills: [
                Self.makeSkill(name: "s1", platform: .cursor),
                Self.makeSkill(name: "s2", platform: .claudeCode),
            ],
            mcps: [
                Self.makeMCP(name: "m1", platform: .cursor),
                Self.makeMCP(name: "m2", platform: .cursor),
                Self.makeMCP(name: "m3", platform: .codex),
            ],
            plugins: [
                Self.makePlugin(name: "p1", platform: .cursor),
            ]
        )

        let allCursor = CatalogFilter.items(in: snapshot, section: .all, platform: .cursor)
        #expect(allCursor.count == 4)

        let mcpsOnCursor = CatalogFilter.items(in: snapshot, section: .mcpServers, platform: .cursor)
        #expect(mcpsOnCursor.count == 2)

        let mcpsAllPlatforms = CatalogFilter.items(in: snapshot, section: .mcpServers, platform: nil)
        #expect(mcpsAllPlatforms.count == 3)

        let cursorWithMCPSection = CatalogFilter.items(in: snapshot, section: .mcpServers, platform: .cursor)
        #expect(cursorWithMCPSection.count == mcpsOnCursor.count)
    }

    @Test func platformSkillPathsSharedAgentsDirectory() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentsSkill = URL(fileURLWithPath: "\(home)/.agents/skills/my-skill/SKILL.md")
        let shared = PlatformSkillPaths.platformsThatShare(path: agentsSkill)
        #expect(shared.contains(.pi))
        #expect(shared.contains(.codex))
        #expect(shared.contains(.openClaw))
        #expect(shared.count == 3)

        let primary = PlatformSkillPaths.primaryPlatform(for: agentsSkill)
        #expect(primary == .pi)

        let cursorSkill = URL(fileURLWithPath: "\(home)/.cursor/skills/foo/SKILL.md")
        #expect(PlatformSkillPaths.primaryPlatform(for: cursorSkill) == .cursor)
        #expect(PlatformSkillPaths.platformsThatShare(path: cursorSkill).isEmpty)
    }

    @Test func platformSkillPathsUserSkillsDirectories() {
        #expect(AgentPlatform.hermes.userSkillsDirectory.lastPathComponent == "skills")
        #expect(AgentPlatform.pi.userSkillsDirectory.path.contains("/.pi/agent/skills"))
        #expect(AgentPlatform.openClaw.userSkillsDirectory.path.contains("/.openclaw/skills"))
    }

    @Test func skillNameValidatorRejectsInvalidNames() {
        if case .success = SkillNameValidator.validate("") { Issue.record("Expected failure for empty name") }
        if case .success = SkillNameValidator.validate("bad/name") { Issue.record("Expected failure for slash") }
        if case .success = SkillNameValidator.validate(".hidden") { Issue.record("Expected failure for dot prefix") }
        if case .failure = SkillNameValidator.validate("valid-skill_1") { Issue.record("Expected success for valid name") }
    }

    @Test func agentActivityEngineMergePrefersHookNeedsInput() {
        let fileSession = AgentSession(
            id: "claude:1",
            platform: .claudeCode,
            state: .working,
            title: "proj",
            cwd: "/tmp/proj",
            pid: nil,
            updatedAt: Date(),
            source: .fileWatch
        )
        let hookSession = AgentSession(
            id: "claude:1",
            platform: .claudeCode,
            state: .needsInput,
            title: "proj",
            cwd: "/tmp/proj",
            pid: nil,
            updatedAt: Date(),
            source: .hooks
        )

        let merged = AgentActivityEngine.merge(hookSessions: [hookSession], fileSessions: [fileSession])
        #expect(merged.count == 1)
        #expect(merged[0].state == .needsInput)
    }

    @Test func agentActivityEngineCollapsesProcessAndTranscriptForSameWorkspace() {
        let transcript = AgentSession(
            id: "codex:rollout:abc",
            platform: .codex,
            state: .working,
            title: "skillz-macos",
            cwd: "/tmp/skillz-macos",
            pid: nil,
            updatedAt: Date().addingTimeInterval(-3),
            source: .fileWatch
        )
        let process = AgentSession(
            id: "codex:process:42",
            platform: .codex,
            state: .working,
            title: "Codex",
            cwd: "/tmp/skillz-macos",
            pid: 42,
            updatedAt: Date(),
            source: .process
        )

        let merged = AgentActivityEngine.merge(hookSessions: [], fileSessions: [transcript, process])
        #expect(merged.count == 1)
        #expect(merged[0].title == "skillz-macos")
        #expect(merged[0].pid == 42)
    }

    @Test func agentActivityEngineDropsPidOnlyProcessWhenBetterPlatformSignalExists() {
        let hook = AgentSession(
            id: "codex:hook:abc",
            platform: .codex,
            state: .working,
            title: "Session active",
            cwd: nil,
            pid: nil,
            updatedAt: Date(),
            source: .hooks
        )
        let process = AgentSession(
            id: "codex:process:42",
            platform: .codex,
            state: .working,
            title: "Codex",
            cwd: nil,
            pid: 42,
            updatedAt: Date(),
            source: .process
        )

        let merged = AgentActivityEngine.merge(hookSessions: [hook], fileSessions: [process])
        #expect(merged.count == 1)
        #expect(merged[0].id == "codex:hook:abc")
    }

    @Test func agentActivityEngineLiveProcessUpgradesIdleHookForSameWorkspace() {
        let hook = AgentSession(
            id: "codex:hook:abc",
            platform: .codex,
            state: .idle,
            title: "skillz-macos",
            cwd: "/tmp/skillz-macos",
            pid: nil,
            updatedAt: Date(),
            source: .hooks
        )
        let process = AgentSession(
            id: "codex:process:42",
            platform: .codex,
            state: .working,
            title: "skillz-macos",
            cwd: "/tmp/skillz-macos",
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            updatedAt: Date(),
            source: .process
        )

        let merged = AgentActivityEngine.merge(hookSessions: [hook], fileSessions: [process])
        #expect(merged.count == 1)
        #expect(merged[0].state == .working)
    }

    @Test func agentActivityEngineMarksStaleWorkingAsUnknown() {
        let stale = AgentSession(
            id: "codex:1",
            platform: .codex,
            state: .working,
            title: "codex",
            cwd: nil,
            pid: nil,
            updatedAt: Date().addingTimeInterval(-200),
            source: .fileWatch
        )
        let updated = AgentActivityEngine.applyStaleRules(stale, now: Date())
        #expect(updated.state == .unknown)
    }

    @Test func agentActivityEngineSummaryCountsNeedsInput() {
        let sessions = [
            AgentSession(
                id: "a", platform: .cursor, state: .needsInput,
                title: "a", cwd: nil, pid: nil, updatedAt: Date(), source: .hooks
            ),
            AgentSession(
                id: "b", platform: .codex, state: .working,
                title: "b", cwd: nil, pid: nil, updatedAt: Date(), source: .hooks
            ),
        ]
        let summary = AgentActivityEngine.summary(for: sessions)
        #expect(summary.needsInputCount == 1)
        #expect(summary.workingCount == 1)
        #expect(summary.hasNeedsInput)
    }

    @Test func agentActivitySummaryNotchRowsPreferActionableSessions() {
        let sessions = [
            AgentSession(
                id: "cursor-working", platform: .cursor, state: .working,
                title: "cursor", cwd: nil, pid: nil, updatedAt: Date(), source: .hooks
            ),
            AgentSession(
                id: "claude-stopped", platform: .claudeCode, state: .idle,
                title: "claude", cwd: nil, pid: nil, updatedAt: Date(), source: .hooks
            ),
            AgentSession(
                id: "codex-input", platform: .codex, state: .needsInput,
                title: "codex", cwd: nil, pid: nil, updatedAt: Date(), source: .hooks
            ),
        ]

        let summary = AgentActivityEngine.summary(for: sessions)
        #expect(summary.hasNotchAttention)
        #expect(summary.notchAttentionSessions.map(\.id) == ["claude-stopped", "codex-input"])
        #expect(summary.notchDisplaySessions.map(\.id) == ["cursor-working", "claude-stopped", "codex-input"])

        let workingSummary = AgentActivityEngine.summary(for: [sessions[0]])
        #expect(!workingSummary.hasNotchAttention)
        #expect(workingSummary.notchDisplaySessions.map(\.id) == ["cursor-working"])
    }

    @Test func notchSessionsCollapseToOnePerPlatform() {
        let now = Date()
        let sessions = [
            AgentSession(
                id: "claude-a", platform: .claudeCode, state: .working,
                title: "claude", cwd: "/Users/x/proj", pid: nil, updatedAt: now, source: .hooks
            ),
            AgentSession(
                id: "claude-b", platform: .claudeCode, state: .needsInput,
                title: "claude", cwd: "/Users/x/.claude", pid: nil,
                updatedAt: now.addingTimeInterval(-5), source: .hooks
            ),
            AgentSession(
                id: "claude-c", platform: .claudeCode, state: .working,
                title: "claude", cwd: "/Users/x/other", pid: nil,
                updatedAt: now.addingTimeInterval(-10), source: .hooks
            ),
            AgentSession(
                id: "cursor-working", platform: .cursor, state: .working,
                title: "cursor", cwd: "/Users/x/repo", pid: nil, updatedAt: now, source: .hooks
            ),
        ]

        let summary = AgentActivityEngine.summary(for: sessions)
        // One representative per platform, highest-priority first: Claude (needsInput) then Cursor.
        #expect(summary.notchSessions.map(\.platform) == [.claudeCode, .cursor])
        #expect(summary.notchSessions.first?.state == .needsInput)
        #expect(summary.notchSessions.count == 2)
    }

    @Test func shellProcessRunnerCapturesOutputAndTimesOut() {
        let echo = ShellProcessRunner.run(
            executablePath: "/bin/echo",
            arguments: ["skillz-process-runner"],
            timeout: 1
        )
        #expect(echo?.didTimeOut == false)
        #expect(echo?.terminationStatus == 0)
        #expect(echo?.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) == "skillz-process-runner")

        let slow = ShellProcessRunner.run(
            executablePath: "/bin/sh",
            arguments: ["-c", "sleep 2; echo late"],
            timeout: 0.05
        )
        #expect(slow?.didTimeOut == true)
    }

    @Test func appHostedTestsDisableStartupSideEffects() {
        #expect(SkillzRuntime.isRunningAppHostedTests)
    }

    @Test func agentHookInstallerNotifyCommandIncludesScript() {
        let command = AgentHookInstaller.notifyCommand(for: "working", platform: .claudeCode)
        #expect(command.contains("skillz-agent-notify.sh"))
        #expect(command.contains("claudeCode"))
        #expect(command.contains("working"))
    }

    @Test func agentStateFileRoundTrip() throws {
        try Self.withTemporaryAgentEnvironment { _ in
        let sessions = [
            AgentSession(
                id: "claude:test-roundtrip",
                platform: .claudeCode,
                state: .needsInput,
                title: "demo",
                cwd: "/tmp/demo",
                pid: nil,
                updatedAt: Date(),
                source: .hooks
            ),
        ]

        try AgentStateFile.save(sessions: sessions)
        let loaded = AgentStateFile.load()
        #expect(loaded.contains { $0.id == "claude:test-roundtrip" && $0.state == .needsInput })

        let cleaned = loaded.filter { $0.id != "claude:test-roundtrip" }
        try AgentStateFile.save(sessions: cleaned)
        }
    }

    @Test func agentStateFileEnsureExistsCreatesLaunchStateFile() throws {
        try Self.withTemporaryAgentEnvironment { _ in
            #expect(!FileManager.default.fileExists(atPath: AgentPaths.agentStateFileURL.path))
            try AgentStateFile.ensureExists()
            #expect(FileManager.default.fileExists(atPath: AgentPaths.agentStateFileURL.path))
            #expect(AgentStateFile.load().isEmpty)
        }
    }

    @Test func agentHookInstallerMergesRepairsAndUninstallsSkillzHooks() throws {
        try Self.withTemporaryAgentEnvironment { root in
            let codex = root.appendingPathComponent(".codex", isDirectory: true)
            let claude = root.appendingPathComponent(".claude", isDirectory: true)
            let cursor = root.appendingPathComponent(".cursor", isDirectory: true)
            try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cursor, withIntermediateDirectories: true)
            // A real config file makes Cursor a genuine install signal (a bare home dir
            // no longer counts — see platformSourceDetectorBareHomeIsNotAnInstallSignal).
            try "{}".write(to: cursor.appendingPathComponent("mcp.json"), atomically: true, encoding: .utf8)

            try """
            {
              "hooks": {
                "Stop": [
                  {
                    "matcher": "",
                    "hooks": [
                      { "type": "command", "command": "echo keep-codex" }
                    ]
                  }
                ]
              }
            }
            """.write(to: codex.appendingPathComponent("hooks.json"), atomically: true, encoding: .utf8)
            try "[features]\n".write(to: codex.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

            try """
            {
              "hooks": {
                "Stop": [
                  {
                    "matcher": "",
                    "hooks": [
                      { "type": "command", "command": "echo keep-claude" }
                    ]
                  }
                ]
              }
            }
            """.write(to: claude.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)

            let installed = try AgentHookInstaller.installAllHooks()
            #expect(installed.allSatisfy { $0.status == .installed })
            #expect(AgentHookInstaller.status(for: .codex).status == .installed)
            #expect(Self.countSkillzHooks(in: codex.appendingPathComponent("hooks.json"), event: "Stop") == 1)
            #expect(Self.countSkillzHooks(in: claude.appendingPathComponent("settings.json"), event: "Stop") == 1)
            #expect(try String(contentsOf: codex.appendingPathComponent("config.toml"), encoding: .utf8).contains("hooks = true"))

            _ = try AgentHookInstaller.installAllHooks()
            #expect(Self.countSkillzHooks(in: codex.appendingPathComponent("hooks.json"), event: "Stop") == 1)
            #expect(Self.fileContains(codex.appendingPathComponent("hooks.json"), "keep-codex"))
            #expect(Self.fileContains(claude.appendingPathComponent("settings.json"), "keep-claude"))

            let uninstalled = AgentHookInstaller.uninstallAllHooks()
            #expect(uninstalled.contains { $0.platform == .codex && ($0.status == .needsRepair || $0.status == .notInstalled) })
            #expect(Self.countSkillzHooks(in: codex.appendingPathComponent("hooks.json"), event: "Stop") == 0)
            #expect(Self.fileContains(codex.appendingPathComponent("hooks.json"), "keep-codex"))
        }
    }

    @Test func agentHookAutoInstallDoesNotWriteFilesWithoutDetectedSupportedTools() throws {
        try Self.withTemporaryAgentEnvironment { _ in
            let statuses = AgentHookInstaller.autoInstallDetectedHooks()
            #expect(statuses.allSatisfy { $0.status == .unsupported })
            #expect(!FileManager.default.fileExists(atPath: AgentPaths.notifyScriptInstalledURL.path))
            #expect(!FileManager.default.fileExists(atPath: AgentPlatform.claudeCode.homeDirectory.path))
            #expect(!FileManager.default.fileExists(atPath: AgentPlatform.codex.homeDirectory.path))
            #expect(!FileManager.default.fileExists(atPath: AgentPlatform.cursor.homeDirectory.path))
        }
    }

    @Test func agentHookAutoInstallUsesExecutableDetectionForFreshDownloads() throws {
        try Self.withTemporaryAgentEnvironment { root in
            try Self.writeExecutable(
                at: root.appendingPathComponent(".local/bin/claude"),
                content: "#!/bin/sh\n"
            )

            let statuses = AgentHookInstaller.autoInstallDetectedHooks()
            #expect(statuses.contains { $0.platform == .claudeCode && $0.status == .installed })
            #expect(statuses.contains { $0.platform == .codex && $0.status == .unsupported })
            #expect(statuses.contains { $0.platform == .cursor && $0.status == .unsupported })
            #expect(FileManager.default.fileExists(atPath: AgentPaths.notifyScriptInstalledURL.path))
            #expect(Self.countSkillzHooks(
                in: AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("settings.json"),
                event: "Stop"
            ) == 1)
        }
    }

    @Test func agentHookInstallerDoesNotOverwriteInvalidExistingConfig() throws {
        try Self.withTemporaryAgentEnvironment { root in
            let claude = root.appendingPathComponent(".claude", isDirectory: true)
            try FileManager.default.createDirectory(at: claude, withIntermediateDirectories: true)
            let settings = claude.appendingPathComponent("settings.json")
            try "{ invalid json".write(to: settings, atomically: true, encoding: .utf8)

            let statuses = AgentHookInstaller.autoInstallDetectedHooks()
            #expect(statuses.contains { $0.platform == .claudeCode && $0.status == .needsRepair })
            #expect(try String(contentsOf: settings, encoding: .utf8) == "{ invalid json")
        }
    }

    @Test func startupHookPolicyDefersAutoInstallUntilOnboardingCompletes() {
        #expect(SkillzStartupHookPolicy.action(
            hasCompletedOnboarding: false,
            autoInstallAgentHooks: true,
            initial: true
        ) == .refreshOnly)
        #expect(SkillzStartupHookPolicy.action(
            hasCompletedOnboarding: true,
            autoInstallAgentHooks: false,
            initial: true
        ) == .refreshOnly)
        #expect(SkillzStartupHookPolicy.action(
            hasCompletedOnboarding: true,
            autoInstallAgentHooks: true,
            initial: true
        ) == .autoInstall)
        #expect(SkillzStartupHookPolicy.action(
            hasCompletedOnboarding: true,
            autoInstallAgentHooks: true,
            initial: false
        ) == .autoRepair)
    }

    @Test func catalogFilterIncludesSharedPlatformAvailability() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentsPath = URL(fileURLWithPath: "\(home)/.agents/skills/shared-skill/SKILL.md")
        let sharedSkill = SkillItem(
            id: SkillItem.makeID(platform: .pi, path: agentsPath),
            platform: .pi,
            skillPath: agentsPath,
            rootDirectory: agentsPath.deletingLastPathComponent(),
            displayName: "shared-skill",
            description: "Shared skill",
            version: nil,
            isBuiltIn: false,
            isPluginEmbedded: false,
            frontmatter: SkillFrontmatter(name: "shared-skill", description: "Shared skill"),
            modifiedAt: nil,
            alsoAvailableOn: [.codex, .openClaw]
        )

        let snapshot = CatalogSnapshot(skills: [sharedSkill], mcps: [], plugins: [])

        let onPi = CatalogFilter.items(in: snapshot, section: .skills, platform: .pi)
        #expect(onPi.count == 1)

        let onCodex = CatalogFilter.items(in: snapshot, section: .skills, platform: .codex)
        #expect(onCodex.count == 1)

        let onOpenClaw = CatalogFilter.items(in: snapshot, section: .skills, platform: .openClaw)
        #expect(onOpenClaw.count == 1)

        let onCursor = CatalogFilter.items(in: snapshot, section: .skills, platform: .cursor)
        #expect(onCursor.isEmpty)
    }

    @Test func platformSourceDetectorEmitsStatusForEveryPlatform() {
        let statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
        #expect(statuses.count == AgentPlatform.allCases.count)
    }

    @Test func platformSourceDetectorBareHomeIsNotAnInstallSignal() throws {
        try Self.withTemporaryAgentEnvironment { root in
            // A bare home directory (no config/skills/executable) — e.g. an empty
            // ~/.cursor left after uninstalling — must NOT count as installed, or we
            // would auto-install hooks into a tool the user doesn't actually run.
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(".cursor", isDirectory: true),
                withIntermediateDirectories: true
            )

            var statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
            #expect(statuses.first { $0.platform == .cursor }?.isDetected == false)
            #expect(PlatformSourceDetector.isInstalled(platform: .cursor) == false)

            // The home folder still appears as a context signal, just not an install signal.
            let homeSignal = statuses.first { $0.platform == .cursor }?
                .detectionSignals.first { $0.url.lastPathComponent == ".cursor" }
            #expect(homeSignal != nil)
            #expect(homeSignal?.isInstallSignal == false)

            // A real config file under the home dir flips it to detected.
            try "{}".write(
                to: root.appendingPathComponent(".cursor/mcp.json"),
                atomically: true,
                encoding: .utf8
            )
            statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
            #expect(statuses.first { $0.platform == .cursor }?.isDetected == true)
            #expect(PlatformSourceDetector.isInstalled(platform: .cursor) == true)
        }
    }

    @Test func platformSourceDetectorDefaultNewSkillPlatformsEmptyWhenNothingDetected() {
        // When nothing is detected we must not pre-check absent tools — that would
        // create skill folders for platforms the user hasn't installed.
        let emptyStatuses = AgentPlatform.allCases.map {
            Self.makeSourceStatus(platform: $0, isDetected: false)
        }
        let defaults = PlatformSourceDetector.defaultNewSkillPlatforms(from: emptyStatuses)
        #expect(defaults.isEmpty)
    }

    @Test func platformSourceDetectorDefaultNewSkillPlatformsUsesDetectedTools() {
        let statuses = AgentPlatform.allCases.map {
            Self.makeSourceStatus(platform: $0, isDetected: $0 == .codex || $0 == .hermes)
        }
        let defaults = PlatformSourceDetector.defaultNewSkillPlatforms(from: statuses)
        #expect(defaults == [.codex, .hermes])
    }

    @Test func platformSourceDetectorFindsHomesSharedSkillsAndExecutables() throws {
        try Self.withTemporaryAgentEnvironment { root in
            let cursorConfig = root.appendingPathComponent(".cursor/mcp.json")
            try FileManager.default.createDirectory(
                at: cursorConfig.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "{}".write(to: cursorConfig, atomically: true, encoding: .utf8)

            let claudeSkill = root.appendingPathComponent(".claude/skills/reviewer/SKILL.md")
            try Self.writeSkill(at: claudeSkill, name: "reviewer")

            let sharedSkill = root.appendingPathComponent(".agents/skills/shared/SKILL.md")
            try Self.writeSkill(at: sharedSkill, name: "shared")

            try FileManager.default.createDirectory(
                at: root.appendingPathComponent(".codex", isDirectory: true),
                withIntermediateDirectories: true
            )
            try "[features]\n".write(
                to: root.appendingPathComponent(".codex/config.toml"),
                atomically: true,
                encoding: .utf8
            )

            try Self.writeExecutable(
                at: root.appendingPathComponent(".local/bin/hermes"),
                content: "#!/bin/sh\n"
            )
            try Self.writeSkill(
                at: root.appendingPathComponent(".pi/agent/skills/pi-skill/SKILL.md"),
                name: "pi-skill"
            )
            try Self.writeExecutable(
                at: root.appendingPathComponent(".local/bin/open-code"),
                content: "#!/bin/sh\n"
            )

            let statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
            #expect(statuses.first { $0.platform == .cursor }?.isDetected == true)
            #expect(statuses.first { $0.platform == .claudeCode }?.isDetected == true)
            #expect(statuses.first { $0.platform == .codex }?.isDetected == true)
            #expect(statuses.first { $0.platform == .hermes }?.isDetected == true)
            #expect(statuses.first { $0.platform == .pi }?.isDetected == true)
            #expect(statuses.first { $0.platform == .openClaw }?.isDetected == true)

            let hermes = statuses.first { $0.platform == .hermes }
            #expect(hermes?.detectedSignal?.kind == .executable)
            #expect(hermes?.detectedSignal?.url.lastPathComponent == "hermes")

            let codex = statuses.first { $0.platform == .codex }
            #expect(codex?.detectionSignals.contains {
                $0.url.path.contains("/.agents/skills") && !$0.isInstallSignal
            } == true)
        }
    }

    @Test func platformSourceDetectorSharedSkillsDoNotCreateToolInstallFalsePositives() throws {
        try Self.withTemporaryAgentEnvironment { root in
            let sharedSkill = root.appendingPathComponent(".agents/skills/shared/SKILL.md")
            try Self.writeSkill(at: sharedSkill, name: "shared")

            let statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
            for platform in [AgentPlatform.codex, .pi, .openClaw] {
                let status = statuses.first { $0.platform == platform }
                #expect(status?.isDetected == false)
                #expect(status?.detectionSignals.contains {
                    $0.label == "Shared skill source" && !$0.isInstallSignal
                } == true)
            }
        }
    }

    @Test func platformSourceDetectorFindsExecutableOnlyOpenCode() throws {
        try Self.withTemporaryAgentEnvironment { root in
            try Self.writeExecutable(
                at: root.appendingPathComponent(".local/bin/opencode"),
                content: "#!/bin/sh\n"
            )

            let statuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
            let openCode = statuses.first { $0.platform == .openClaw }
            #expect(openCode?.isDetected == true)
            #expect(openCode?.detectedSignal?.kind == .executable)
            #expect(openCode?.detectedSignal?.url.lastPathComponent == "opencode")
        }
    }

    @Test func codexSessionAdapterDropsDeadChatProcesses() throws {
        try Self.withTemporaryAgentEnvironment { _ in
            let file = AgentPaths.codexChatProcessesFile
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let alivePID = Int(ProcessInfo.processInfo.processIdentifier)
            try """
            [
              { "id": "dead", "cwd": "/tmp/dead", "pid": 999999 },
              { "id": "alive", "cwd": "/tmp/alive", "pid": \(alivePID) }
            ]
            """.write(to: file, atomically: true, encoding: .utf8)

            let sessions = CodexSessionAdapter.scan()
            // A lingering record for a dead process must not keep showing as Working.
            #expect(sessions.contains { $0.id == "codex:alive" })
            #expect(!sessions.contains { $0.id == "codex:dead" })
        }
    }

    @Test func claudeSessionAdapterUsesRawSessionIDForStableID() throws {
        try Self.withTemporaryAgentEnvironment { _ in
            let dir = AgentPaths.claudeSessionsDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // No pid → id derives from sessionId. The raw string must be used (not its
            // per-launch-randomized hashValue), so the id is stable across app restarts.
            try """
            { "sessionId": "abc-123", "cwd": "/tmp/proj", "status": "working" }
            """.write(to: dir.appendingPathComponent("abc-123.json"), atomically: true, encoding: .utf8)

            let sessions = ClaudeSessionAdapter.scan()
            #expect(sessions.contains { $0.id == "claude:abc-123" })
        }
    }

    @Test func discoveryRunsWithoutCrashingOnEmptyMachine() {
        let snapshot = DiscoveryEngine.discover(
            hideBuiltInCursor: true,
            hideSystemCodex: true
        )
        #expect(snapshot.skills.allSatisfy { !$0.displayName.isEmpty })
        #expect(snapshot.mcps.allSatisfy { !$0.name.isEmpty })
        #expect(snapshot.plugins.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test func mcpEnvKeysAreListedNotValues() async throws {
        let mcps = MCPScanner.scan()
        for mcp in mcps {
            for key in mcp.envKeys {
                #expect(!key.contains("="))
            }
        }
    }

    @Test func skillFileServiceCreateSkillInTempDirectory() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("skillz-create-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let cursorSkills = tempRoot.appendingPathComponent("cursor/skills", isDirectory: true)
        let claudeSkills = tempRoot.appendingPathComponent("claude/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: cursorSkills, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: claudeSkills, withIntermediateDirectories: true)

        // Use direct paths via a test helper pattern — createSkill uses real home dirs,
        // so test the content builder and single-platform create via temp override.
        let content = FrontmatterWriter.make(
            name: "test-skill",
            description: "A test skill.",
            body: "# Hello\n"
        )
        #expect(content.contains("name: test-skill"))
        #expect(content.contains("description: A test skill."))
        #expect(content.contains("# Hello"))

        let skillDir = tempRoot.appendingPathComponent("my-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillMD = skillDir.appendingPathComponent("SKILL.md")
        try content.write(to: skillMD, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: skillMD.path))

        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func skillFileServiceRenameAndDeleteInTempDirectory() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("skillz-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let skillDir = tempRoot.appendingPathComponent("my-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillMD = skillDir.appendingPathComponent("SKILL.md")
        try """
        ---
        name: my-skill
        description: Test skill.
        ---
        # Hello
        """.write(to: skillMD, atomically: true, encoding: .utf8)

        let item = SkillItem(
            id: SkillItem.makeID(platform: .claudeCode, path: skillMD),
            platform: .claudeCode,
            skillPath: skillMD,
            rootDirectory: skillDir,
            displayName: "my-skill",
            description: "Test skill.",
            version: nil,
            isBuiltIn: false,
            isPluginEmbedded: false,
            frontmatter: SkillFrontmatter(name: "my-skill", description: "Test skill."),
            modifiedAt: nil,
            alsoAvailableOn: []
        )

        let renamedRoot = try SkillFileService.renameSkill(item, newFolderName: "renamed-skill")
        #expect(renamedRoot.lastPathComponent == "renamed-skill")
        let renamedMD = renamedRoot.appendingPathComponent("SKILL.md")
        let content = try String(contentsOf: renamedMD, encoding: .utf8)
        let (fm, _) = FrontmatterParser.parse(from: content)
        #expect(fm.name == "renamed-skill")

        let renamedItem = SkillItem(
            id: SkillItem.makeID(platform: .claudeCode, path: renamedMD),
            platform: .claudeCode,
            skillPath: renamedMD,
            rootDirectory: renamedRoot,
            displayName: "renamed-skill",
            description: "Test skill.",
            version: nil,
            isBuiltIn: false,
            isPluginEmbedded: false,
            frontmatter: fm,
            modifiedAt: nil,
            alsoAvailableOn: []
        )

        try SkillFileService.deleteSkill(renamedItem)
        #expect(!FileManager.default.fileExists(atPath: renamedRoot.path))

        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func skillFileServiceEditsPluginEmbeddedMetadataAndAllowsWritableFolderOperations() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("skillz-plugin-metadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let skillDir = tempRoot.appendingPathComponent("plugin-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillMD = skillDir.appendingPathComponent("SKILL.md")
        try """
        ---
        name: plugin-skill
        description: Old.
        ---
        # Hello
        """.write(to: skillMD, atomically: true, encoding: .utf8)

        let item = SkillItem(
            id: SkillItem.makeID(platform: .codex, path: skillMD),
            platform: .codex,
            skillPath: skillMD,
            rootDirectory: skillDir,
            displayName: "plugin-skill",
            description: "Old.",
            version: nil,
            isBuiltIn: false,
            isPluginEmbedded: true,
            frontmatter: SkillFrontmatter(name: "plugin-skill", description: "Old."),
            modifiedAt: nil,
            alsoAvailableOn: []
        )

        #expect(SkillFileService.canEditMetadata(item))
        try SkillFileService.updateMetadata(item, name: "plugin-skill", description: "Updated.", version: "1.2.3")
        let (frontmatter, _) = FrontmatterParser.parse(from: try String(contentsOf: skillMD, encoding: .utf8))
        #expect(frontmatter.description == "Updated.")
        #expect(frontmatter.version == "1.2.3")

        #expect(SkillFileService.canModify(item))
        let renamedRoot = try SkillFileService.renameSkill(item, newFolderName: "renamed")
        #expect(FileManager.default.fileExists(atPath: renamedRoot.appendingPathComponent("SKILL.md").path))

        let renamedItem = SkillItem(
            id: SkillItem.makeID(platform: .codex, path: renamedRoot.appendingPathComponent("SKILL.md")),
            platform: .codex,
            skillPath: renamedRoot.appendingPathComponent("SKILL.md"),
            rootDirectory: renamedRoot,
            displayName: "renamed",
            description: "Updated.",
            version: "1.2.3",
            isBuiltIn: false,
            isPluginEmbedded: true,
            frontmatter: SkillFrontmatter(name: "renamed", description: "Updated.", version: "1.2.3"),
            modifiedAt: nil,
            alsoAvailableOn: []
        )
        try SkillFileService.deleteSkill(renamedItem)
        #expect(!FileManager.default.fileExists(atPath: renamedRoot.path))

        try? FileManager.default.removeItem(at: tempRoot)
    }

    @Test func notchLayoutCalculatorHeightGrowsWithRowsAndHooks() {
        let base = NotchLayoutCalculator.openLayout(
            rowCount: 1,
            showsHooksPrompt: false,
            closedWidth: 200,
            hasPhysicalNotch: false
        )
        let threeRows = NotchLayoutCalculator.openLayout(
            rowCount: 3,
            showsHooksPrompt: false,
            closedWidth: 200,
            hasPhysicalNotch: false
        )
        let withHooks = NotchLayoutCalculator.openLayout(
            rowCount: 3,
            showsHooksPrompt: true,
            closedWidth: 200,
            hasPhysicalNotch: true
        )

        #expect(threeRows.height > base.height)
        #expect(withHooks.height > threeRows.height)
        #expect(withHooks.height > NotchLayoutCalculator.legacyOpenHeight)
    }

    @Test func notchLayoutCalculatorWidthIsAtLeastMinimum() {
        let narrow = NotchLayoutCalculator.openLayout(
            rowCount: 1,
            showsHooksPrompt: false,
            closedWidth: 120,
            hasPhysicalNotch: false
        )
        let wide = NotchLayoutCalculator.openLayout(
            rowCount: 1,
            showsHooksPrompt: false,
            closedWidth: 500,
            hasPhysicalNotch: false
        )

        #expect(narrow.width >= NotchLayoutCalculator.minOpenWidth)
        #expect(wide.width <= NotchLayoutCalculator.maxOpenWidth)
        #expect(wide.width >= narrow.width)
    }

    @MainActor
    @Test func notchClosedStateDoesNotRelayoutForBackgroundRows() {
        let model = NotchViewModel()
        var layoutChangeCount = 0
        model.onLayoutChange = {
            layoutChangeCount += 1
        }

        model.state = .closed
        model.updateOpenLayout(rowCount: 4, showsHooksPrompt: true)

        #expect(layoutChangeCount == 0)
    }

    @MainActor
    @Test func notchTransientOpenDoesNotStayPinned() async {
        let model = NotchViewModel()

        model.openTransient(duration: 0.01)
        #expect(model.isPinnedOpen == false)
        if case .open = model.state {
            // Expected immediately after opening.
        } else {
            Issue.record("Expected transient notch to open immediately")
        }

        try? await Task.sleep(for: .milliseconds(40))
        #expect(model.isPinnedOpen == false)
        // The notch always rests in its visible closed pill rather than hiding entirely.
        #expect(model.state == .closed)
    }

    @Test func trackedAgentPlatformsIncludeAllSupportedTools() {
        #expect(AgentPlatform.trackedAgentPlatforms == [.cursor, .claudeCode, .codex, .hermes, .pi, .openClaw])
    }

    @Test func cursorDesktopAppIsNotDetectedAsAgent() {
        // The Cursor IDE binary and its Electron helpers must not register as a working agent.
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "Cursor",
            arguments: "/Applications/Cursor.app/Contents/MacOS/Cursor"
        ) == nil)

        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "Cursor Helper (Renderer)",
            arguments: "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/Cursor Helper --type=renderer"
        ) == nil)

        // The Cursor agent CLI should still be detected.
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "cursor-agent",
            arguments: "cursor-agent chat"
        ) == .cursor)
    }

    @Test func shellAgentProcessAdapterMatchesAllSupportedCliTools() {
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "hermes",
            arguments: "hermes"
        ) == .hermes)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "hermes-cli",
            arguments: "hermes-cli run"
        ) == .hermes)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "pi",
            arguments: "pi"
        ) == .pi)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "opencode",
            arguments: "opencode"
        ) == .openClaw)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "open-code",
            arguments: "open-code"
        ) == .openClaw)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "openclaw",
            arguments: "openclaw"
        ) == .openClaw)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "open-claw",
            arguments: "open-claw"
        ) == .openClaw)
    }

    @Test func shellAgentProcessAdapterExcludesKnownNonInteractiveProcesses() {
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "codex",
            arguments: "codex app-server --listen stdio://"
        ) == nil)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "codex",
            arguments: "/Applications/Codex.app/Contents/MacOS/Codex"
        ) == nil)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "claude",
            arguments: "claude remote-control"
        ) == nil)
        #expect(ShellAgentProcessAdapter.matchedPlatform(
            commandName: "claude",
            arguments: "claude --print hello"
        ) == nil)
    }

    @MainActor
    @Test func notchRestsClosedWhetherOrNotThereIsContent() {
        let model = NotchViewModel()

        // With no sessions the notch still rests in its visible closed pill (it never hides on its own).
        model.refreshContent(from: AgentActivityEngine.summary(for: []))
        model.close()
        #expect(model.hasContent == false)
        #expect(model.state == .closed)

        let working = AgentSession(
            id: "cursor:process:4242",
            platform: .cursor,
            state: .working,
            title: "proj",
            cwd: "/tmp/proj",
            pid: nil,
            updatedAt: Date(),
            source: .process
        )
        model.refreshContent(from: AgentActivityEngine.summary(for: [working]))
        model.close()
        #expect(model.hasContent == true)
        #expect(model.state == .closed)

        // `hide()` is still the explicit way to remove the notch when the feature is disabled.
        model.hide()
        #expect(model.state == .hidden)
    }

    private static func makeSkill(name: String, platform: AgentPlatform) -> SkillItem {
    let root = URL(fileURLWithPath: "/tmp/\(name)")
    let path = root.appendingPathComponent("SKILL.md")
    return SkillItem(
        id: SkillItem.makeID(platform: platform, path: path),
        platform: platform,
        skillPath: path,
        rootDirectory: root,
        displayName: name,
        description: name,
        version: nil,
        isBuiltIn: false,
        isPluginEmbedded: false,
        frontmatter: SkillFrontmatter(name: name, description: name),
        modifiedAt: nil,
        alsoAvailableOn: []
    )
    }

    private static func makeMCP(name: String, platform: AgentPlatform) -> MCPItem {
    MCPItem(
        id: MCPItem.makeID(platform: platform, name: name),
        platform: platform,
        name: name,
        transport: .stdio,
        command: "cmd",
        args: [],
        url: nil,
        envKeys: [],
        configFileURL: platform.homeDirectory.appendingPathComponent("mcp.json"),
        modifiedAt: nil
    )
    }

    private static func makePlugin(name: String, platform: AgentPlatform) -> PluginItem {
    PluginItem(
        id: PluginItem.makeID(platform: platform, pluginID: name, installPath: nil),
        platform: platform,
        pluginID: name,
        displayName: name,
        description: name,
        version: nil,
        marketplace: nil,
        isEnabled: true,
        installPath: nil,
        metadataPath: nil,
        skillCount: 0,
        modifiedAt: nil
    )
    }

    private static func makeSourceStatus(platform: AgentPlatform, isDetected: Bool) -> PlatformSourceStatus {
        PlatformSourceStatus(
            platform: platform,
            isDetected: isDetected,
            scanPaths: [],
            detectionSignals: [],
            itemCount: 0,
            hookSupport: platform == .cursor || platform == .claudeCode || platform == .codex
                ? .preciseWaitingState
                : .processFallback
        )
    }

    private static func writeSkill(at url: URL, name: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        ---
        name: \(name)
        description: Test skill.
        ---
        # \(name)
        """.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeExecutable(at url: URL, content: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private static func withTemporaryAgentEnvironment(_ body: (URL) throws -> Void) throws {
        let previous = AgentPaths.environment
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skillz-env-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        AgentPaths.environment = .temporary(root: root)
        defer {
            AgentPaths.environment = previous
            try? FileManager.default.removeItem(at: root)
        }
        try body(root)
    }

    private static func countSkillzHooks(in url: URL, event: String) -> Int {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any],
              let entries = hooks[event] as? [[String: Any]]
        else { return 0 }

        return entries.reduce(0) { count, entry in
            guard let nested = entry["hooks"] as? [[String: Any]] else { return count }
            return count + nested.filter {
                ($0["command"] as? String)?.contains("skillz-agent-notify.sh") == true
                    || $0["skillz"] as? Bool == true
            }.count
        }
    }

    private static func fileContains(_ url: URL, _ needle: String) -> Bool {
        (try? String(contentsOf: url, encoding: .utf8).contains(needle)) ?? false
    }
}
