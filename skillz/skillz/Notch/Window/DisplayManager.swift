import AppKit

@MainActor
final class DisplayManager {
    static let shared = DisplayManager()

    private init() {}

    func preferredScreen(settings: AppSettings) -> NSScreen? {
        if let id = settings.agentNotchDisplayUUID,
           let match = NSScreen.screens.first(where: { screen in
               screen.displayUUID == id
           }) {
            return match
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    func position(panel: NSWindow, on screen: NSScreen, geometry: NotchGeometry) {
        let frame = screen.frame
        let x = frame.origin.x + (frame.width - panel.frame.width) / 2
        let y = frame.origin.y + frame.height - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

extension NSScreen {
    var displayUUID: String? {
        if let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }
        if let string = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String {
            return string
        }
        return nil
    }
}
