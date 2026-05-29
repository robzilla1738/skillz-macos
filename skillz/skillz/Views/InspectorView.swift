import SwiftUI

struct InspectorView: View {
    @ObservedObject var store: CatalogStore
    let item: CatalogItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.xl) {
                inspectorSection(title: "Details") {
                    SkillzDetailRow(label: "Type", value: item.kind.displayName)
                    HStack(alignment: .top, spacing: SkillzSpacing.lg) {
                        Text("Platform")
                            .skillzDetailLabelStyle()
                            .frame(width: 88, alignment: .leading)
                        PlatformBadge(platform: item.platform)
                        if case .skill(let skill) = item, skill.hasSharedAvailability {
                            SharedSkillInfoButton(
                                primary: skill.platform,
                                alsoAvailableOn: skill.alsoAvailableOn
                            )
                        }
                        Spacer()
                    }
                }

                switch item {
                case .skill(let skill):
                    skillInspector(skill)
                case .mcp(let mcp):
                    mcpInspector(mcp)
                case .plugin(let plugin):
                    pluginInspector(plugin)
                }
            }
            .padding(SkillzSpacing.lg)
        }
        .background(Color.skillzCanvas)
        .frame(minWidth: 240)
    }

    @ViewBuilder
    private func inspectorSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.md) {
            SkillzSectionHeader(title: title)
            VStack(alignment: .leading, spacing: SkillzSpacing.sm + 2) {
                content()
            }
        }
    }

    @ViewBuilder
    private func skillInspector(_ skill: SkillItem) -> some View {
        inspectorSection(title: "Skill") {
            if let version = skill.version {
                SkillzDetailRow(label: "Version", value: version)
            }
            if skill.isBuiltIn {
                SkillzDetailRow(label: "Source", value: "Cursor Built-in")
            }
            if skill.isPluginEmbedded {
                SkillzDetailRow(label: "Source", value: "Plugin")
            }
            SkillzDetailRow(label: "Path", value: skill.skillPath.path, mono: true)
        }

        let related = store.relatedPlatforms(for: skill.displayName, excluding: skill)
        if !related.isEmpty {
            inspectorSection(title: "Also Available On") {
                HStack(spacing: SkillzSpacing.sm) {
                    ForEach(related, id: \.self) { platform in
                        PlatformBadge(platform: platform)
                    }
                }
                Text("Edits to this file apply to every harness listed above.")
                    .skillzCaptionStyle()
            }
        }
    }

    @ViewBuilder
    private func mcpInspector(_ mcp: MCPItem) -> some View {
        inspectorSection(title: "MCP") {
            SkillzDetailRow(label: "Transport", value: mcp.transportLabel)
            SkillzDetailRow(label: "Endpoint", value: mcp.endpointSummary, mono: true)
            if !mcp.envKeys.isEmpty {
                SkillzDetailRow(label: "Env Keys", value: mcp.envKeys.joined(separator: ", "))
            }
            SkillzDetailRow(label: "Config", value: mcp.configFileURL.path, mono: true)
        }
    }

    @ViewBuilder
    private func pluginInspector(_ plugin: PluginItem) -> some View {
        inspectorSection(title: "Plugin") {
            SkillzDetailRow(label: "ID", value: plugin.pluginID, mono: true)
            SkillzDetailRow(label: "Status", value: plugin.isEnabled ? "Enabled" : "Disabled")
            if let marketplace = plugin.marketplace {
                SkillzDetailRow(label: "Marketplace", value: marketplace)
            }
            if let version = plugin.version {
                SkillzDetailRow(label: "Version", value: version)
            }
            SkillzDetailRow(label: "Skills", value: "\(plugin.skillCount)")
            if let path = plugin.installPath {
                SkillzDetailRow(label: "Path", value: path.path, mono: true)
            }
        }
    }
}
