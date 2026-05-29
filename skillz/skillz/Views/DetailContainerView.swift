import SwiftUI

struct DetailContainerView: View {
    @ObservedObject var store: CatalogStore
    @ObservedObject var document: EditorDocument
    @ObservedObject var settings: AppSettings

    var body: some View {
        Group {
            if let item = store.selectedItem {
                detailContent(for: item)
                    .inspector(isPresented: $store.showInspector) {
                        InspectorView(store: store, item: item)
                            .inspectorColumnWidth(
                                min: SkillzWindowMetrics.inspectorMin,
                                ideal: SkillzWindowMetrics.inspectorIdeal,
                                max: SkillzWindowMetrics.inspectorMax
                            )
                    }
            } else {
                SkillzEmptyState(
                    title: "No Selection",
                    message: "Select a skill, MCP server, or plugin to view details."
                )
            }
        }
        .skillzCanvas()
    }

    @ViewBuilder
    private func detailContent(for item: CatalogItem) -> some View {
        switch item {
        case .skill(let skill):
            SkillDetailView(
                store: store,
                skill: skill,
                document: document,
                settings: settings
            )
        case .mcp(let mcp):
            MCPDetailView(store: store, mcp: mcp)
        case .plugin(let plugin):
            PluginDetailView(store: store, plugin: plugin)
        }
    }
}
