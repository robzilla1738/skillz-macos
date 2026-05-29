import SwiftUI

struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
            VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                Text(title)
                    .font(SkillzTypography.navigationTitle)
                    .foregroundStyle(Color.skillzEmphasis)

                Text(subtitle)
                    .skillzBodySecondaryStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SkillzSpacing.xs)

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
