import CoreGraphics

struct NotchOpenLayout: Equatable, Sendable {
    var width: CGFloat
    var height: CGFloat
}

enum NotchLayoutCalculator {
    static let minOpenWidth: CGFloat = 440
    static let maxOpenWidth: CGFloat = 520
    static let legacyOpenHeight: CGFloat = 188

    private static let topInsetNotch: CGFloat = 4
    private static let headerHeight: CGFloat = 28
    private static let rowHeight: CGFloat = 44
    private static let hooksBlockHeight: CGFloat = 32
    private static let footerHeight: CGFloat = 30
    private static let verticalPadding: CGFloat = 28
    private static let panelPadding: CGFloat = 24
    private static let horizontalContentPadding: CGFloat = 16

    static func openLayout(
        rowCount: Int,
        showsHooksPrompt: Bool,
        closedWidth: CGFloat,
        hasPhysicalNotch: Bool
    ) -> NotchOpenLayout {
        let rows = max(rowCount, 1)
        let topInset = hasPhysicalNotch ? topInsetNotch : 0
        let hooks = showsHooksPrompt ? hooksBlockHeight : 0

        let height = topInset
            + verticalPadding
            + headerHeight
            + CGFloat(rows) * rowHeight
            + hooks
            + footerHeight

        // Open width is always comfortably wide — never tied to the narrow closed notch gap.
        let width = max(minOpenWidth, min(maxOpenWidth, closedWidth + 220))

        return NotchOpenLayout(width: width, height: height)
    }

    static func panelSize(for openLayout: NotchOpenLayout, closedHeight: CGFloat) -> (width: CGFloat, height: CGFloat) {
        (
            width: openLayout.width + panelPadding * 2,
            height: openLayout.height + panelPadding + closedHeight
        )
    }
}
