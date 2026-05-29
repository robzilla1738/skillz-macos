import AppKit
import SwiftUI

enum MenuBarIcon {
    static let pointSize: CGFloat = 18

    static var image: NSImage? {
        guard let source = NSApp.applicationIconImage else { return nil }
        return source.resizedMaintainingAspectRatio(to: NSSize(width: pointSize, height: pointSize))
    }
}

extension NSImage {
    func resizedMaintainingAspectRatio(to targetSize: NSSize) -> NSImage {
        let image = self
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let sourceSize = image.size
        let scale = min(targetSize.width / sourceSize.width, targetSize.height / sourceSize.height)
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let origin = NSPoint(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2
        )
        image.draw(
            in: NSRect(origin: origin, size: drawSize),
            from: NSRect(origin: .zero, size: sourceSize),
            operation: .copy,
            fraction: 1
        )
        newImage.unlockFocus()
        return newImage
    }
}

struct SkillzMenuBarIconView: View {
    var body: some View {
        if let icon = MenuBarIcon.image {
            Image(nsImage: icon)
                .accessibilityLabel(AppBrand.name)
        }
    }
}
