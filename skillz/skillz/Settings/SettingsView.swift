import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case sources
    case agents
    case editor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .sources: return "Sources"
        case .agents: return "Agents"
        case .editor: return "Editor"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: CatalogStore
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            settingsTabBar

            Divider()

            selectedSettingsPane
                .padding(SkillzSpacing.xl)
        }
        .background(Color.skillzCanvas)
        .frame(width: 640, height: 560)
        .onAppear { applyDestination(SettingsWindowOpener.consumePendingDestination()) }
        .onReceive(NotificationCenter.default.publisher(for: .skillzOpenSettingsTab)) { note in
            // Clear the pending value too, so an already-open window's handling here
            // doesn't leave a stale destination for the next fresh open to consume.
            _ = SettingsWindowOpener.consumePendingDestination()
            applyDestination(note.object as? SettingsDestination)
        }
    }

    private func applyDestination(_ destination: SettingsDestination?) {
        switch destination {
        case .agents:
            selectedTab = .agents
        case .none:
            break
        }
    }

    private var settingsTabBar: some View {
        HStack(spacing: SkillzSpacing.sm) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(SkillzTypography.body)
                        .foregroundStyle(selectedTab == tab ? Color.skillzEmphasis : Color.skillzMuted)
                        .frame(minWidth: 76)
                        .padding(.horizontal, SkillzSpacing.sm)
                        .frame(height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: SkillzSpacing.sm, style: .continuous)
                                .fill(selectedTab == tab ? Color.skillzSelection.opacity(0.58) : Color.clear)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: SkillzSpacing.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, SkillzSpacing.xl)
        .padding(.vertical, SkillzSpacing.md)
    }

    @ViewBuilder
    private var selectedSettingsPane: some View {
        switch selectedTab {
        case .general:
            generalSettings
        case .sources:
            sourcesSettings
        case .agents:
            AgentHooksSettingsSection(
                settings: settings,
                agentStore: agentStore,
                hookStore: hookStore
            )
        case .editor:
            editorSettings
        }
    }

    private var generalSettings: some View {
        SettingsPane(
            title: "General",
            subtitle: "Customize how \(AppBrand.name) looks, launches, and filters your library."
        ) {
            Form {
                Section {
                    Picker("Appearance", selection: $settings.appearanceRaw) {
                        ForEach(SkillzAppearance.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .font(SkillzTypography.body)
                } header: {
                    Text("Appearance")
                }

                Section {
                    Toggle("Hide Cursor built-in skills", isOn: $settings.hideBuiltInCursorSkills)
                        .font(SkillzTypography.body)
                    Toggle("Hide Codex system skills (.system)", isOn: $settings.hideSystemCodexSkills)
                        .font(SkillzTypography.body)
                } header: {
                    Text("Library")
                } footer: {
                    Text("\(AppBrand.name) scans standard agent config folders in your home directory. Source paths are listed in the Sources tab.")
                        .skillzCaptionStyle()
                }

                Section {
                    Button("Show onboarding again") {
                        settings.hasCompletedOnboarding = false
                        NotificationCenter.default.post(name: .skillzShowOnboarding, object: nil)
                    }
                    .font(SkillzTypography.body)
                } header: {
                    Text("First Run")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.skillzCanvas)
        }
    }

    private var sourcesSettings: some View {
        SettingsPane(
            title: "Sources",
            subtitle: "Choose what this Mac contributes to the catalog and reveal source folders quickly."
        ) {
            Form {
                Section {
                    HStack {
                        Text("Detected platforms")
                            .font(SkillzTypography.body)
                        Spacer()
                        SkillzTag(text: "\(store.detectedPlatforms.count) found", style: .muted)
                        Button("Refresh") {
                            store.refresh()
                        }
                        .font(SkillzTypography.caption)
                    }
                } header: {
                    Text("Scan")
                }

                Section {
                    ForEach(store.sourceStatuses) { status in
                        PlatformSourceRow(status: status) { url in
                            store.revealInFinder(url)
                        }
                    }
                } header: {
                    Text("Platforms")
                } footer: {
                    Text("\(AppBrand.name) reads standard agent config folders in your home directory. No Full Disk Access required.")
                        .skillzCaptionStyle()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.skillzCanvas)
        }
    }

    private var editorSettings: some View {
        SettingsPane(
            title: "Editor",
            subtitle: "Tune the editing surface for reading and maintaining SKILL.md files."
        ) {
            Form {
                Section {
                    Stepper(value: $settings.editorFontSize, in: 10...20, step: 1) {
                        HStack {
                            Text("Editor font size")
                                .font(SkillzTypography.body)
                            Spacer()
                            Text("\(Int(settings.editorFontSize)) pt")
                                .skillzCaptionStyle()
                        }
                    }

                    Slider(value: $settings.editorFontSize, in: 10...20, step: 1)
                } header: {
                    Text("Text")
                } footer: {
                    Text("Markdown uses a monospaced editor font to match agent instruction files.")
                        .skillzCaptionStyle()
                }

                Section {
                    Toggle("Show inspector by default", isOn: $settings.showInspector)
                        .font(SkillzTypography.body)
                } header: {
                    Text("Detail View")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.skillzCanvas)
        }
    }
}

private struct PlatformSourceRow: View {
    let status: PlatformSourceStatus
    let revealInFinder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
            HStack {
                Text(status.platform.displayName)
                    .font(SkillzTypography.body)
                Spacer()
                SkillzTag(text: status.hookSupportLabel, style: .subtle)
                SkillzTag(text: status.statusLabel, style: status.isDetected ? .muted : .subtle)
                Text("\(status.itemCount) items")
                    .skillzCaptionStyle()
            }

            Text(status.detectionLabel)
                .skillzCaptionStyle()
                .lineLimit(1)

            if let path = status.primaryPath {
                HStack(spacing: SkillzSpacing.sm) {
                    Text(path.path)
                        .skillzCaptionStyle()
                        .lineLimit(2)
                    if FileManager.default.fileExists(atPath: path.path) {
                        Button("Reveal") {
                            revealInFinder(path)
                        }
                        .font(SkillzTypography.caption)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.skillzInk)
                    }
                }
            } else if let fallback = status.scanPaths.first {
                Text(fallback.path)
                    .skillzCaptionStyle()
                    .lineLimit(2)
            }

            if !status.isDetected {
                Text(status.notDetectedHint)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
            }
        }
        .padding(.vertical, SkillzSpacing.xs)
    }
}
