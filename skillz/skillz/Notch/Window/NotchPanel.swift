import AppKit

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        isMovableByWindowBackground = false
        hasShadow = false
        isReleasedWhenClosed = false
        // We drive every size/position change ourselves (SwiftUI springs + manual frames), so AppKit's
        // implicit window animations must stay out of the way to keep motion fluid.
        animationBehavior = .none
        // Pass-through by default: a global mouse monitor flips this on only while the cursor is over
        // the notch, so the overlay never swallows clicks meant for the menu bar or apps beneath it.
        ignoresMouseEvents = true
        level = .mainMenu + 3
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
