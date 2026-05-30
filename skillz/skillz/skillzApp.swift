//
//  skillzApp.swift
//  skillz
//

import SwiftUI
import AppKit

@main
struct skillzApp: App {
    @StateObject private var store = CatalogStore()
    @StateObject private var document = EditorDocument()
    @StateObject private var settings = AppSettings.shared
    @StateObject private var agentStore = AgentSessionStore()
    @StateObject private var hookStore = AgentHookStore()

    var body: some Scene {
        WindowGroup {
            MainWindowView(store: store, document: document, settings: settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .background {
                    SkillzStartupConfigurator(
                        agentStore: agentStore,
                        hookStore: hookStore,
                        settings: settings
                    )
                }
        }
        .defaultSize(
            width: SkillzWindowMetrics.defaultWidth,
            height: SkillzWindowMetrics.defaultHeight
        )
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            TextEditingCommands()

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveSkill()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!document.isDirty || document.fileURL == nil || store.selectedItem?.skillItem == nil)
            }

            CommandMenu("File") {
                Button("New Skill…") {
                    NotificationCenter.default.post(name: .skillzNewSkill, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Reveal in Finder") {
                    revealSelection()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Edit Details…") {
                    NotificationCenter.default.post(name: .skillzEditDetails, object: nil)
                }
                .disabled(store.selectedItem?.skillItem == nil)

                Button("Rename Skill…") {
                    NotificationCenter.default.post(name: .skillzRenameSkill, object: nil)
                }
                .disabled(!store.canModifySelectedSkill())

                Button("Delete Skill…") {
                    NotificationCenter.default.post(name: .skillzDeleteSkill, object: nil)
                }
                .disabled(!store.canModifySelectedSkill())
            }

            CommandMenu("View") {
                Button("Refresh Catalog") {
                    store.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)

                Toggle("Show Inspector", isOn: $store.showInspector)
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }

            CommandMenu(AppBrand.name) {
                Button("New Skill…") {
                    NotificationCenter.default.post(name: .skillzNewSkill, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Refresh All Sources") {
                    store.refresh()
                }

                Button("Refresh Agents") {
                    agentStore.refresh()
                }
            }
        }

        MenuBarExtra {
            AgentMenuBarView(
                agentStore: agentStore,
                settings: settings,
                onOpenSession: { openAgentSession($0) },
                onOpenSkills: { activateMainWindow() },
                onOpenSettings: { SettingsWindowOpener.openAgentsTab() },
                onRefresh: { agentStore.refresh() },
                onQuit: { NSApp.terminate(nil) }
            )
        } label: {
            AgentMenuBarLabel(summary: agentStore.summary, settings: settings)
        }

        Settings {
            SettingsView(
                settings: settings,
                store: store,
                agentStore: agentStore,
                hookStore: hookStore
            )
            .preferredColorScheme(settings.appearance.colorScheme)
        }
    }

    private func saveSkill() {
        guard store.selectedItem?.skillItem != nil else { return }
        _ = document.saveImmediately()
    }

    private func revealSelection() {
        guard let item = store.selectedItem else { return }
        switch item {
        case .skill(let skill):
            store.revealInFinder(document.fileURL ?? skill.skillPath)
        case .mcp(let mcp):
            store.revealInFinder(mcp.configFileURL)
        case .plugin(let plugin):
            if let path = plugin.installPath ?? plugin.metadataPath {
                store.revealInFinder(path)
            }
        }
    }

    private func activateMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    private func openAgentSession(_ session: AgentSession) {
        Task { @MainActor in
            if await AgentSessionActivator.activateOwningApp(for: session) {
                return
            }

            if let cwd = session.cwd {
                let url = URL(fileURLWithPath: cwd, isDirectory: true)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return
            }

            activateMainWindow()
        }
    }
}

private struct AgentMenuBarLabel: View {
    let summary: AgentActivitySummary
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            SkillzMenuBarIconView()
            if settings.showAgentCountInMenuBar, summary.needsInputCount > 0 {
                Text("\(summary.needsInputCount)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct AgentMenuBarView: View {
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var settings: AppSettings
    var onOpenSession: (AgentSession) -> Void
    var onOpenSkills: () -> Void
    var onOpenSettings: () -> Void
    var onRefresh: () -> Void
    var onQuit: () -> Void

    var body: some View {
        Section("Agents") {
            if agentStore.summary.notchDisplaySessions.isEmpty {
                Label("No active agents", systemImage: "circle.dashed")
            } else {
                ForEach(agentStore.summary.notchDisplaySessions.prefix(6)) { session in
                    Button {
                        onOpenSession(session)
                    } label: {
                        Label {
                            Text("\(session.platform.displayName) · \(session.state.displayName)")
                        } icon: {
                            Image(systemName: symbolName(for: session.state))
                        }
                    }
                }
            }
        }

        Section {
            Toggle("Show waiting count", isOn: $settings.showAgentCountInMenuBar)
        }

        Section {
            Button(action: onOpenSkills) {
                Label("Open \(AppBrand.name)", systemImage: "rectangle.stack")
            }
            Button(action: onOpenSettings) {
                Label("Agent Settings", systemImage: "gearshape")
            }
            Button(action: onRefresh) {
                Label("Refresh Agents", systemImage: "arrow.clockwise")
            }
        }

        Section {
            Button(action: onQuit) {
                Label("Quit \(AppBrand.name)", systemImage: "power")
            }
        }
    }

    private func symbolName(for state: AgentActivityState) -> String {
        switch state {
        case .needsInput: return "exclamationmark.circle"
        case .working: return "play.circle"
        case .idle: return "pause.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

extension Notification.Name {
    static let skillzNewSkill = Notification.Name("skillzNewSkill")
    static let skillzEditDetails = Notification.Name("skillzEditDetails")
    static let skillzRenameSkill = Notification.Name("skillzRenameSkill")
    static let skillzDeleteSkill = Notification.Name("skillzDeleteSkill")
    static let skillzShowOnboarding = Notification.Name("skillzShowOnboarding")
}
