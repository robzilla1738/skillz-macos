import SwiftUI
import AppKit

struct AgentHooksSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    var onNotchEnabledChange: (Bool) -> Void

    var body: some View {
        SettingsPane(
            title: "Agents",
            subtitle: "Configure live agent detection, the notch, and menu bar status."
        ) {
            Form {
                Section {
                    Toggle("Show agent notch", isOn: $settings.enableAgentNotch)
                        .font(SkillzTypography.body)
                        .onChange(of: settings.enableAgentNotch) { _, enabled in
                            onNotchEnabledChange(enabled)
                        }

                    Picker("Display", selection: displaySelection) {
                        Text("Main display").tag(Optional<String>.none)
                        ForEach(screenOptions, id: \.uuid) { option in
                            Text(option.name).tag(Optional(option.uuid))
                        }
                    }
                    .font(SkillzTypography.body)
                } header: {
                    Text("Notch")
                } footer: {
                    Text("The agent notch sits at the top center of your display and opens when Codex, Cursor, or Claude Code need your input.")
                        .skillzCaptionStyle()
                }

                Section {
                    Toggle("Show waiting count in menu bar", isOn: $settings.showAgentCountInMenuBar)
                        .font(SkillzTypography.body)

                    Toggle("Install or repair hooks automatically", isOn: $settings.autoInstallAgentHooks)
                        .font(SkillzTypography.body)
                        .onChange(of: settings.autoInstallAgentHooks) { _, enabled in
                            if enabled {
                                hookStore.installOrRepairAll()
                            } else {
                                hookStore.refresh()
                            }
                            agentStore.refresh()
                        }
                } header: {
                    Text("Automation")
                } footer: {
                    Text("Automatic hook repair keeps detection working after agent tools rewrite their config files.")
                        .skillzCaptionStyle()
                }

                Section {
                    ForEach(hookStore.statuses, id: \.platform.id) { status in
                        VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                            HStack {
                                Text(status.platform.displayName)
                                    .font(SkillzTypography.body)
                                Spacer()
                                SkillzTag(text: statusLabel(status.status), style: statusTagStyle(status.status))
                            }
                            Text(status.detail)
                                .skillzCaptionStyle()
                        }
                        .padding(.vertical, SkillzSpacing.xs)
                    }

                    HStack {
                        Button(hookStore.isInstalling ? "Installing..." : "Install or Repair") {
                            hookStore.installOrRepairAll()
                            agentStore.refresh()
                        }
                        .disabled(hookStore.isInstalling)

                        Button("Remove Hooks") {
                            hookStore.uninstallAll()
                            agentStore.refresh()
                        }
                        .disabled(hookStore.isInstalling)

                        Button("Reveal State File") {
                            revealStateFile()
                        }
                    }
                    .font(SkillzTypography.body)

                    if let installMessage = hookStore.lastMessage {
                        Text(installMessage)
                            .font(SkillzTypography.caption)
                            .foregroundStyle(Color.skillzSectionLabel)
                    }
                } header: {
                    Text("Activity hooks")
                } footer: {
                    Text("Hooks let \(AppBrand.name) detect when an agent needs approval or input. Existing hook configs are merged, not replaced.")
                        .skillzCaptionStyle()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.skillzCanvas)
            .onAppear {
                hookStore.refresh()
            }
        }
    }

    private var displaySelection: Binding<String?> {
        Binding(
            get: { settings.agentNotchDisplayUUID },
            set: { settings.agentNotchDisplayUUID = $0 }
        )
    }

    private var screenOptions: [(uuid: String, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            return (uuid, screen.localizedName)
        }
    }

    private func revealStateFile() {
        let url = AgentPaths.agentStateFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? AgentStateFile.save(sessions: [])
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func statusLabel(_ status: AgentHookInstallStatus) -> String {
        switch status {
        case .installed: return "Installed"
        case .notInstalled: return "Not installed"
        case .needsRepair: return "Needs repair"
        case .unsupported: return "Unsupported"
        case .requiresTrustOrFeatureFlag: return "Needs enable"
        }
    }

    private func statusTagStyle(_ status: AgentHookInstallStatus) -> SkillzTag.Style {
        switch status {
        case .installed: return .muted
        case .notInstalled, .needsRepair, .requiresTrustOrFeatureFlag: return .subtle
        case .unsupported: return .subtle
        }
    }
}
