import SwiftUI

struct MCPDetailView: View {
    @ObservedObject var store: CatalogStore
    let mcp: MCPItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.xl) {
                header
                metadataCard
                configCard
                actions
            }
            .padding(SkillzSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .skillzCanvas()
        .navigationTitle("")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text(mcp.name)
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
                PlatformBadge(platform: mcp.platform)
                SkillzTag(text: mcp.transportLabel, style: .muted)
            }
            Text(mcp.endpointSummary)
                .skillzBodySecondaryStyle()
                .textSelection(.enabled)
        }
    }

    private var metadataCard: some View {
        SkillzDetailCard(title: "Server Details") {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm + 2) {
                SkillzDetailRow(label: "Name", value: mcp.name)
                SkillzDetailRow(label: "Transport", value: mcp.transportLabel)
                if let command = mcp.command {
                    SkillzDetailRow(label: "Command", value: command, mono: true)
                }
                if !mcp.args.isEmpty {
                    SkillzDetailRow(label: "Arguments", value: mcp.args.joined(separator: " "), mono: true)
                }
                if let url = mcp.url {
                    SkillzDetailRow(label: "URL", value: url, mono: true)
                }
                if !mcp.envKeys.isEmpty {
                    SkillzDetailRow(
                        label: "Environment",
                        value: mcp.envKeys.joined(separator: ", ") + " (values hidden)"
                    )
                }
            }
        }
    }

    private var configCard: some View {
        SkillzDetailCard(title: "Configuration File") {
            Text(mcp.configFileURL.path)
                .skillzMonoStyle()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: SkillzSpacing.md) {
            SkillzTextButton(title: "Reveal Config") {
                store.revealInFinder(mcp.configFileURL)
            }
            SkillzTextButton(title: "Open in Default App") {
                store.openInDefaultApp(mcp.configFileURL)
            }
            SkillzTextButton(title: "Copy Path") {
                store.copyPath(mcp.configFileURL)
            }
        }
    }
}
