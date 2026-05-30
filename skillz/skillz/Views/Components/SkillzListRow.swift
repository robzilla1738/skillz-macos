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

                if case .plugin(let plugin) = item {
                    EnabledBadge(isEnabled: plugin.isEnabled)
                        .fixedSize()
                }

                if case .skill(let skill) = item, skill.hasSharedAvailability {
                    SharedSkillInfoButton(
                        primary: skill.platform,
                        alsoAvailableOn: skill.alsoAvailableOn
                    )
                    .fixedSize()
                }

                Spacer(minLength: SkillzSpacing.sm)
            }

            Text(subtitleText)
                .skillzBodySecondaryStyle()
                .lineLimit(2, reservesSpace: true)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
        .frame(minHeight: SkillzSpacing.rowMinHeight, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(item.kind.displayName), \(item.displayName), \(item.platform.displayName)")
        .accessibilityHint(subtitleText)
    }

    /// A subtitle is always present so every row keeps the same shape. Prefer the description;
    /// fall back to a meaningful source/path so rows without a description don't collapse or read
    /// as broken. Reserves two lines of height (above) so the list stays a uniform grid.
    private var subtitleText: String {
        let description = item.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return description
        }

        let fallback = item.listSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallback.isEmpty,
           fallback.caseInsensitiveCompare(item.displayName) != .orderedSame {
            return fallback
        }

        return "No description"
    }
}
