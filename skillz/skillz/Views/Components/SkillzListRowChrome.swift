import SwiftUI

struct SkillzListRowChrome: View {
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: SkillzSpacing.sm)
            .fill(backgroundColor)
            .padding(.horizontal, SkillzSpacing.sm)
            .animation(.easeOut(duration: 0.13), value: isHovered)
            .animation(.easeOut(duration: 0.13), value: isSelected)
    }

    private var backgroundColor: Color {
        if isSelected { return Color.skillzSelection }
        if isHovered { return Color.skillzSelection.opacity(0.5) }
        return Color.clear
    }
}
