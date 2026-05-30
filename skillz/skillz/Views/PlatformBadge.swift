import SwiftUI

struct PlatformBadge: View {
    let platform: AgentPlatform
    var style: SkillzTag.Style = .subtle

    var body: some View {
        SkillzTag(text: platform.displayName, style: style)
            .accessibilityLabel("Platform: \(platform.displayName)")
    }
}

struct EnabledBadge: View {
    let isEnabled: Bool

    var body: some View {
        SkillzTag(
            text: isEnabled ? "Enabled" : "Disabled",
            style: .subtle
        )
        .accessibilityLabel(isEnabled ? "Enabled" : "Disabled")
    }
}
