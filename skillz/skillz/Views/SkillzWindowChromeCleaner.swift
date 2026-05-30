import AppKit
import SwiftUI

struct SkillzWindowChromeCleaner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            cleanWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            cleanWindow(for: nsView)
        }
    }

    private func cleanWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.toolbar = nil
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
    }
}
