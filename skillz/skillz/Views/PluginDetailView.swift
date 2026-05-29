import SwiftUI

struct PluginDetailView: View {
    @ObservedObject var store: CatalogStore
    let plugin: PluginItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.xl) {
                header
                metadataCard
                if let path = plugin.installPath {
                    pathCard(path)
                }
                actions
            }
            .padding(SkillzSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .skillzCanvas()
        .navigationTitle("")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text(plugin.displayName)
                    .skillzNavigationTitleStyle()
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, SkillzSpacing.xl)
            .padding(.vertical, SkillzSpacing.md)
            .background(Color.skillzCanvas)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.sm + 2) {
            HStack(spacing: SkillzSpacing.sm) {
                PlatformBadge(platform: plugin.platform)
                EnabledBadge(isEnabled: plugin.isEnabled)
            }
            Text(plugin.description.isEmpty ? "No description available." : plugin.description)
                .skillzBodySecondaryStyle()
        }
    }

    private var metadataCard: some View {
        SkillzDetailCard(title: "Plugin Details") {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm + 2) {
                SkillzDetailRow(label: "ID", value: plugin.pluginID, mono: true)
                if let marketplace = plugin.marketplace {
                    SkillzDetailRow(label: "Marketplace", value: marketplace)
                }
                if let version = plugin.version {
                    SkillzDetailRow(label: "Version", value: version)
                }
                SkillzDetailRow(label: "Skills", value: "\(plugin.skillCount)")
                SkillzDetailRow(label: "Status", value: plugin.isEnabled ? "Enabled" : "Disabled")
            }
        }
    }

    private func pathCard(_ path: URL) -> some View {
        SkillzDetailCard(title: "Install Location") {
            Text(path.path)
                .skillzMonoStyle()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: SkillzSpacing.md) {
            if let path = plugin.installPath {
                SkillzTextButton(title: "Reveal in Finder") {
                    store.revealInFinder(path)
                }
            }
            if let metadata = plugin.metadataPath {
                SkillzTextButton(title: "Open Metadata") {
                    store.openInDefaultApp(metadata)
                }
            }
            if let path = plugin.installPath ?? plugin.metadataPath {
                SkillzTextButton(title: "Copy Path") {
                    store.copyPath(path)
                }
            }
        }
    }
}
