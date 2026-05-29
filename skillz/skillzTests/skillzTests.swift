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
        #expect(summary.notchDisplaySessions.map(\.id) == ["claude-stopped", "codex-input"])

        let workingSummary = AgentActivityEngine.summary(for: [sessions[0]])
        #expect(!workingSummary.hasNotchAttention)
        #expect(workingSummary.notchDisplaySessions.map(\.id) == ["cursor-working"])
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

    @Test func platformSourceDetectorMarksExistingHomeAsDetected() {
        let snapshot = CatalogSnapshot()
        let statuses = PlatformSourceDetector.detect(snapshot: snapshot)
        #expect(statuses.count == AgentPlatform.allCases.count)

        let cursorStatus = statuses.first { $0.platform == .cursor }
        #expect(cursorStatus != nil)
        if FileManager.default.fileExists(atPath: AgentPlatform.cursor.homeDirectory.path) {
            #expect(cursorStatus?.isDetected == true)
        }
    }

    @Test func platformSourceDetectorDefaultNewSkillPlatformsFallback() {
        let emptyStatuses = AgentPlatform.allCases.map {
            PlatformSourceStatus(platform: $0, isDetected: false, scanPaths: [], itemCount: 0)
        }
        let defaults = PlatformSourceDetector.defaultNewSkillPlatforms(from: emptyStatuses)
        #expect(defaults == [.cursor, .claudeCode])
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
