import AppKit
import QuickLookUI
import SwiftUI

/// Quick Look preview extension entry point. Renders the shared
/// `PreviewContentView` (SkillzPreviewCore) inside an `NSHostingView`, themed
/// by the per-type settings the host app writes into the shared app group.
final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        // The file extension is the reliable disambiguator across the UTI
        // identifier soup in QLSupportedContentTypes. Unknown extensions get
        // the plain-ish log treatment.
        let type = PreviewFileType(fileExtension: url.pathExtension) ?? .log
        // Effective settings honor the master switch and the per-type
        // "Preview with Skills" toggle: disabled types render the neutral
        // system-style preview. (Declining with an error is NOT an option —
        // Quick Look then shows a generic icon, not the built-in previewer;
        // verified empirically on macOS 26.)
        let settings = PreviewSettingsStore().effectiveSettings(for: type)

        let loaded: PreviewInputLoader.LoadedText
        do {
            loaded = try PreviewInputLoader.load(url, type: type)
        } catch {
            handler(error)
            return
        }

        let content = PreviewContentView(
            text: loaded.text,
            type: type,
            settings: settings,
            wasTruncated: loaded.wasTruncated
        )

        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        handler(nil)
    }
}
