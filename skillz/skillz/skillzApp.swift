//
//  skillzApp.swift
//  skillz
//

import SwiftUI
import AppKit

@main
struct skillzApp: App {
    @NSApplicationDelegateAdaptor(NotchAppDelegate.self) private var notchDelegate
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
                        settings: settings,
                        notchDelegate: notchDelegate
                    )
                }
        }
        .defaultSize(
            width: SkillzWindowMetrics.defaultWidth,
            height: SkillzWindowMetrics.defaultHeight
        )
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()
            TextEditingCommands()

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveSkill()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!document.isDirty || store.selectedItem?.skillItem == nil)
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
                .disabled(!store.canModifySelectedSkill())

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

                Divider()

                Button("Open Agent Notch") {
                    notchDelegate.openNotch()
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
                onOpenNotch: { notchDelegate.openNotch() },
                onOpenSkills: { activateMainWindow() },
                onOpenSettings: { SettingsWindowOpener.openAgentsTab() },
                onSetNotchEnabled: { notchDelegate.setNotchEnabled($0) },
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
                hookStore: hookStore,
                onNotchEnabledChange: { enabled in
                    notchDelegate.setNotchEnabled(enabled)
                }
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
        for window in NSApp.windows where !(window is NotchPanel) {
            window.makeKeyAndOrderFront(nil)
            return
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
    var onOpenNotch: () -> Void
    var onOpenSkills: () -> Void
    var onOpenSettings: () -> Void
    var onSetNotchEnabled: (Bool) -> Void
    var onRefresh: () -> Void
    var onQuit: () -> Void

    var body: some View {
        Section("Agents") {
            if agentStore.summary.notchDisplaySessions.isEmpty {
                Label("No active agents", systemImage: "circle.dashed")
            } else {
                ForEach(agentStore.summary.notchDisplaySessions.prefix(6)) { session in
                    Button {
                        onOpenNotch()
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
            Toggle("Show agent notch", isOn: notchEnabled)
        }

        Section {
            Button(action: onOpenNotch) {
                Label("Open Agent Notch", systemImage: "rectangle.topthird.inset.filled")
            }
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

    private var notchEnabled: Binding<Bool> {
        Binding(
            get: { settings.enableAgentNotch },
            set: { enabled in
                settings.enableAgentNotch = enabled
                onSetNotchEnabled(enabled)
            }
        )
    }
}

extension Notification.Name {
    static let skillzNewSkill = Notification.Name("skillzNewSkill")
    static let skillzEditDetails = Notification.Name("skillzEditDetails")
    static let skillzRenameSkill = Notification.Name("skillzRenameSkill")
    static let skillzDeleteSkill = Notification.Name("skillzDeleteSkill")
    static let skillzShowOnboarding = Notification.Name("skillzShowOnboarding")
}
