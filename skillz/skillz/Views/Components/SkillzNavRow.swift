import SwiftUI

/// Shared sidebar / file-tree row — subtle selection fill, no system accent pill.
struct SkillzNavRow: View {
    let title: String
    var trailing: String? = nil
    let isSelected: Bool

    var body: some View {
        HStack(spacing: SkillzSpacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(isSelected ? Color.skillzEmphasis : Color.clear)
                .frame(width: 2, height: 14)

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
        .padding(.vertical, SkillzSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SkillzSpacing.sm)
                .fill(isSelected ? Color.skillzSelection : Color.clear)
        }
        .contentShape(RoundedRectangle(cornerRadius: SkillzSpacing.sm))
    }
}

struct SkillzNavRowButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
