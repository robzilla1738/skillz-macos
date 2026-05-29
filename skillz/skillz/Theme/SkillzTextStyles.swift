import SwiftUI

extension Text {
    func skillzNavigationTitleStyle() -> some View {
        font(SkillzTypography.navigationTitle)
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzHeadlineStyle() -> some View {
        font(SkillzTypography.headline)
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzTitleStyle() -> some View {
        font(SkillzTypography.title)
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzListTitleStyle(isSelected: Bool = false) -> some View {
        font(SkillzTypography.listTitle(selected: isSelected))
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzNavItemStyle(isSelected: Bool = false) -> some View {
        font(SkillzTypography.navItem(selected: isSelected))
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzNavCountStyle(isSelected: Bool = false) -> some View {
        font(SkillzTypography.navCount(selected: isSelected))
            .foregroundStyle(isSelected ? Color.skillzEmphasis : Color.skillzMuted)
    }

    func skillzBodyStyle() -> some View {
        font(SkillzTypography.body)
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzBodySecondaryStyle() -> some View {
        font(SkillzTypography.body)
            .foregroundStyle(Color.skillzMuted)
    }

    func skillzCaptionStyle() -> some View {
        font(SkillzTypography.caption)
            .foregroundStyle(Color.skillzMuted)
    }

    func skillzCaptionStrongStyle() -> some View {
        font(SkillzTypography.captionMedium)
            .foregroundStyle(Color.skillzMuted)
    }

    func skillzSectionHeaderStyle() -> some View {
        font(SkillzTypography.sectionHeader)
            .foregroundStyle(Color.skillzSectionLabel)
            .tracking(0.6)
            .textCase(.uppercase)
    }

    func skillzMonoStyle() -> some View {
        font(SkillzTypography.mono)
            .foregroundStyle(Color.skillzEmphasis)
    }

    func skillzDetailLabelStyle() -> some View {
        font(SkillzTypography.captionMedium)
            .foregroundStyle(Color.skillzSectionLabel)
    }

    func skillzDetailValueStyle(mono: Bool = false) -> some View {
        font(mono ? SkillzTypography.mono : SkillzTypography.body)
            .foregroundStyle(Color.skillzEmphasis)
    }
}
