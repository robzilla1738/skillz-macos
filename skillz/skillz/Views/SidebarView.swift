import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: CatalogStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.xl) {
                Text(AppBrand.name)
                    .skillzNavigationTitleStyle()
                    .padding(.horizontal, SkillzSpacing.sm)

                VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                    SkillzSectionHeader(title: "Library")
                        .padding(.horizontal, SkillzSpacing.sm)

                    ForEach(CatalogSection.allCases) { section in
                        Button {
                            store.selectedSection = section
                        } label: {
                            SidebarNavRow(
                                title: section.displayName,
                                count: store.count(for: section),
                                isSelected: store.selectedSection == section
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                    SkillzSectionHeader(title: "Platforms")
                        .padding(.horizontal, SkillzSpacing.sm)

                    Button {
                        store.selectedPlatformFilter = nil
                    } label: {
                        SidebarNavRow(
                            title: "All Platforms",
                            count: store.countAllPlatforms(),
                            isSelected: store.selectedPlatformFilter == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(AgentPlatform.allCases) { platform in
                        Button {
                            store.selectedPlatformFilter = platform
                        } label: {
                            SidebarNavRow(
                                title: platform.displayName,
                                count: store.count(for: platform),
                                isSelected: store.selectedPlatformFilter == platform
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, SkillzSpacing.sm)
            .padding(.vertical, SkillzSpacing.lg)
        }
        .skillzCanvas()
    }
}
