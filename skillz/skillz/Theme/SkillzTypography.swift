import SwiftUI
import AppKit

/// Monospaced type scale aligned with the markdown editor.
///
/// | Role            | Token              | Size | Weight   | Use                          |
/// |-----------------|--------------------|------|----------|------------------------------|
/// | Navigation      | navigationTitle    | 15   | semibold | Window / column titles       |
/// | Headline        | headline           | 14   | semibold | Detail page headings         |
/// | Title           | title              | 13   | medium   | Empty states, primary labels |
/// | List title      | listTitle          | 13   | medium   | Catalog row names            |
/// | Nav item        | navItem            | 12   | regular  | Sidebar rows                 |
/// | Body            | body               | 12   | regular  | Descriptions                 |
/// | Caption         | caption            | 11   | regular  | Metadata, paths, counts      |
/// | Caption strong  | captionMedium      | 11   | medium   | Tags, pill labels            |
/// | Section         | sectionHeader      | 10   | medium   | Uppercase section labels     |
/// | Mono            | mono               | 12   | regular  | Paths, code                  |
enum SkillzTypography {
    static let navigationTitle = Font.system(size: 15, weight: .semibold, design: .monospaced)
    static let headline = Font.system(size: 14, weight: .semibold, design: .monospaced)
    static let title = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let listTitle = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let navItem = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let body = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let caption = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let sectionHeader = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)

    static func listTitle(selected: Bool) -> Font {
        .system(size: 13, weight: selected ? .semibold : .medium, design: .monospaced)
    }

    static func navItem(selected: Bool) -> Font {
        .system(size: 12, weight: selected ? .semibold : .regular, design: .monospaced)
    }

    static func navCount(selected: Bool) -> Font {
        .system(size: 11, weight: selected ? .medium : .regular, design: .monospaced)
    }

    static func editor(size: Double) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    /// AppKit counterpart to `editor(size:)` for the `NSTextView`-backed editor.
    static func editorNSFont(size: Double) -> NSFont {
        .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

enum SkillzPillMetrics {
    static let font = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let height: CGFloat = 32
    static let horizontalPadding: CGFloat = 12
    static let iconWidth: CGFloat = 14
}

enum SkillzTagMetrics {
    static let height: CGFloat = 22
    static let horizontalPadding: CGFloat = 10
    static let font = SkillzTypography.captionMedium
}
