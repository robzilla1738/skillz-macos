import SwiftUI

struct SkillzListRow: View {
    let item: CatalogItem
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: SkillzSpacing.sm) {
                Text(item.displayName)
                    .skillzListTitleStyle(isSelected: isSelected)
                    .lineLimit(1)

                PlatformBadge(platform: item.platform)
                    .fixedSize()

                if case .skill(let skill) = item, skill.hasSharedAvailability {
                    SharedSkillInfoButton(
                        primary: skill.platform,
                        alsoAvailableOn: skill.alsoAvailableOn
                    )
                    .fixedSize()
                }

                Spacer(minLength: SkillzSpacing.sm)

                if case .plugin(let plugin) = item {
                    EnabledBadge(isEnabled: plugin.isEnabled)
                        .fixedSize()
                }
            }

            Text(item.descriptionText)
                .skillzBodySecondaryStyle()
                .lineLimit(2)
        }
        .frame(minHeight: SkillzSpacing.rowMinHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(item.kind.displayName), \(item.displayName), \(item.platform.displayName)")
        .accessibilityHint(item.descriptionText)
    }
}
