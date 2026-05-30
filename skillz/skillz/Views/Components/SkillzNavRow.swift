import SwiftUI

/// Shared sidebar / file-tree row — subtle selection fill, no system accent pill.
struct SkillzNavRow: View {
    let title: String
    var symbolName: String? = nil
    var platform: AgentPlatform? = nil
    var trailing: String? = nil
    let isSelected: Bool

    var body: some View {
        HStack(spacing: SkillzSpacing.sm) {
            icon

            Text(title)
                .skillzNavItemStyle(isSelected: isSelected)
                .lineLimit(1)

            Spacer(minLength: SkillzSpacing.sm)

            if let trailing {
                Text(trailing)
                    .skillzNavCountStyle(isSelected: isSelected)
            }
        }
        .padding(.horizontal, SkillzSpacing.sm)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: SkillzSpacing.sm, style: .continuous)
                .fill(isSelected ? Color.skillzSelection.opacity(0.78) : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SkillzSpacing.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(trailing ?? "0") items")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var icon: some View {
        if let platform, let assetName = platform.brandIconAssetName {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(isSelected ? Color.skillzEmphasis : Color.skillzMuted)
                .frame(width: 16, height: 16)
        } else if let symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.skillzEmphasis : Color.skillzMuted)
                .frame(width: 16, height: 16)
        }
    }
}

struct SkillzNavRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
