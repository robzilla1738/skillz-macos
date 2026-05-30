import AppKit
import SwiftUI

enum MenuBarIcon {
    static let pointSize: CGFloat = 16
}

struct SkillzMenuBarIconView: View {
    var body: some View {
        // The Skills app icon is a near-black brand mark, which renders invisibly on a dark menu bar
        // (and as an opaque box on a light one). We instead use a template SF Symbol: the system tints
        // it to match the menu bar in either appearance, so the status item is always visible while
        // Skills is running.
        Image(systemName: "sparkles")
            .font(.system(size: MenuBarIcon.pointSize, weight: .medium))
            .accessibilityLabel(AppBrand.name)
    }
}
