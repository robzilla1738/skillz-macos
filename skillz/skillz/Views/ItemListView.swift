import SwiftUI

struct ItemListView: View {
    @ObservedObject var store: CatalogStore
    @State private var hoveredItemID: String?

    var body: some View {
        Group {
            if store.isLoading && store.filteredItems.isEmpty {
                VStack(spacing: SkillzSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning…")
                        .skillzBodySecondaryStyle()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.filteredItems.isEmpty {
                if isGlobalEmpty {
                    welcomeEmptyState
                } else {
                    SkillzEmptyState(title: "No Items", message: emptyDescription)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: SkillzSpacing.xs) {
                        ForEach(store.filteredItems, id: \.id) { item in
                            let isSelected = store.selectedItemID == item.id
                            Button {
                                store.selectedItemID = item.id
                            } label: {
                                SkillzListRow(item: item, isSelected: isSelected)
                                    .padding(.horizontal, SkillzSpacing.lg)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        SkillzListRowChrome(
                                            isSelected: isSelected,
                                            isHovered: hoveredItemID == item.id
                                        )
                                    }
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    hoveredItemID = item.id
                                } else if hoveredItemID == item.id {
                                    hoveredItemID = nil
                                }
                            }
                            .contextMenu {
                                ItemContextMenu(store: store, item: item)
                            }
                        }
                    }
                    .padding(.vertical, SkillzSpacing.sm)
                }
            }
        }
        .skillzCanvas()
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text(listTitle)
                    .skillzNavigationTitleStyle()
                Spacer()
            }
            .padding(.horizontal, SkillzSpacing.lg)
            .padding(.top, SkillzWindowMetrics.columnHeaderTopInset)
            .padding(.bottom, SkillzSpacing.md)
            .background(Color.skillzCanvas)
        }
    }

    private var isGlobalEmpty: Bool {
        !store.hasAnyCatalogItems
            && store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.selectedSection == .all
            && store.selectedPlatformFilter == nil
    }

    private var welcomeEmptyState: some View {
        VStack(spacing: SkillzSpacing.lg) {
            Text("Welcome to \(AppBrand.name)")
                .skillzListTitleStyle()

            Text("\(AppBrand.name) scans your agent harness folders automatically - skills, MCP servers, and plugins from Cursor, Claude Code, Codex, and more.")
                .skillzBodySecondaryStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if !store.detectedPlatforms.isEmpty {
                VStack(spacing: SkillzSpacing.xs) {
                    Text("Detected on this Mac")
                        .skillzSectionHeaderStyle()
                    ForEach(Array(store.detectedPlatforms).sorted(by: { $0.displayName < $1.displayName })) { platform in
                        Text(platform.displayName)
                            .skillzCaptionStyle()
                    }
                }
            } else {
                Text("No agent harness folders found yet. Install a tool like Cursor or Claude Code, or create your first skill.")
                    .skillzBodySecondaryStyle()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Text("Open Settings → Sources to see all scan paths.")
                .skillzCaptionStyle()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.skillzCanvas)
    }

    private var listTitle: String {
        var parts: [String] = []
        if store.selectedSection != .all {
            parts.append(store.selectedSection.displayName)
        }
        if let platform = store.selectedPlatformFilter {
            parts.append(platform.displayName)
        }
        if parts.isEmpty {
            return CatalogSection.all.displayName
        }
        return parts.joined(separator: " · ")
    }

    private var emptyDescription: String {
        if !store.searchText.isEmpty {
            return "No results for \"\(store.searchText)\"."
        }
        return "Try another section or platform filter, or refresh the catalog."
    }
}
