import AppKit

struct NotchGeometry: Equatable {
    var closedWidth: CGFloat
    var closedHeight: CGFloat
    var hasPhysicalNotch: Bool

    static let closedFallbackWidth: CGFloat = 200
    static let closedFallbackHeight: CGFloat = 32

    static func make(for screen: NSScreen) -> NotchGeometry {
        let menuBarHeight = screen.frame.height - screen.visibleFrame.height - screen.visibleFrame.origin.y
        let barHeight = max(menuBarHeight, 24)
        let topInset = screen.safeAreaInsets.top
        let hasNotch = topInset > barHeight || topInset > 20

        var closedWidth = closedFallbackWidth
        if hasNotch, #available(macOS 12.0, *) {
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            let gap = screen.frame.width - left - right
            if gap > 120, gap < 260 {
                closedWidth = gap
            }
        }

        let closedHeight = hasNotch ? max(barHeight, topInset > 0 ? topInset : barHeight) : barHeight

        return NotchGeometry(
            closedWidth: closedWidth,
            closedHeight: closedHeight,
            hasPhysicalNotch: hasNotch
        )
    }
}
