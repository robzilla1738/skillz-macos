import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: CatalogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            List {
                Section {
                    ForEach(CatalogSection.allCases) { section in
                        Button {
                            store.selectedSection = section
                        } label: {
                            SidebarNavRow(
                                title: section.displayName,
                                symbolName: section.symbolName,
                                count: store.count(for: section),
                                isSelected: store.selectedSection == section
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowChrome(top: section == .all ? SkillzSpacing.sm : 2)
                    }
                } header: {
                    sectionHeader("Library")
                        .padding(.top, SkillzSpacing.sm)
                }

                Section {
                    Button {
                        store.selectedPlatformFilter = nil
                    } label: {
                        SidebarNavRow(
                            title: "All Platforms",
                            symbolName: "square.stack.3d.up",
                            count: store.countAllPlatforms(),
                            isSelected: store.selectedPlatformFilter == nil
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowChrome(top: SkillzSpacing.sm)

                    ForEach(AgentPlatform.allCases) { platform in
                        Button {
                            store.selectedPlatformFilter = platform
                        } label: {
                            SidebarNavRow(
                                title: platform.displayName,
                                platform: platform,
                                count: store.count(for: platform),
                                isSelected: store.selectedPlatformFilter == platform
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowChrome()
                    }
                } header: {
                    sectionHeader("Platforms")
                        .padding(.top, SkillzSpacing.lg)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            SkillzHairline()
            actions
        }
        .background(Color.skillzCanvas)
    }

    /// Global actions live at the sidebar's pinned bottom edge so the top bar
    /// stays minimal (toggle + search only).
    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            sidebarAction("New Skill", symbol: "plus", help: "Create a new skill (⌘N)") {
                NotificationCenter.default.post(name: .skillzNewSkill, object: nil)
            }
            sidebarAction("Refresh Catalog", symbol: "arrow.clockwise", help: "Rescan agent folders (⌘R)") {
                store.refresh()
            }
            sidebarAction("Quick Look Themes", symbol: "eye", help: "Theme Finder spacebar previews per file type") {
                NotificationCenter.default.post(name: .skillzShowQuickLookThemes, object: nil)
            }
        }
        .padding(.horizontal, SkillzSpacing.md)
        .padding(.vertical, SkillzSpacing.sm)
    }

    private func sidebarAction(
        _ title: String,
        symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SkillzNavRow(title: title, symbolName: symbol, isSelected: false)
        }
        .buttonStyle(SkillzNavRowButtonStyle(isSelected: false))
        .help(help)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(AppBrand.name)
                .skillzNavigationTitleStyle()

            Text("\(store.snapshot.allItems.count) catalog items")
                .skillzCaptionStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SkillzSpacing.lg)
        .padding(.top, SkillzSpacing.md)
        .padding(.bottom, SkillzSpacing.md)
        .background(Color.skillzCanvas)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .skillzSectionHeaderStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func listRowChrome(top: CGFloat = 2) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: SkillzSpacing.lg, bottom: 2, trailing: SkillzSpacing.lg))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
