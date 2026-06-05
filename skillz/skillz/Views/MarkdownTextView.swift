import SwiftUI
import AppKit

/// `NSTextView`-backed editor that preserves the `EditorDocument` binding/autosave contract
/// while adding the native Find bar, undo, and a line-wrap toggle that plain `TextEditor` lacks.
struct MarkdownTextView: NSViewRepresentable {
    @ObservedObject var document: EditorDocument
    let fontSize: Double
    let lineWrap: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: SkillzSpacing.lg, height: SkillzSpacing.md)
        textView.font = SkillzTypography.editorNSFont(size: fontSize)
        let inkColor = NSColor(named: "SkillzEmphasis") ?? .labelColor
        textView.textColor = inkColor
        textView.insertionPointColor = inkColor
        textView.string = document.text

        context.coordinator.textView = textView
        applyWrap(lineWrap, to: textView, scrollView: scrollView)
        context.coordinator.appliedWrap = lineWrap
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.document = document

        // Only push text when it changed externally (file load / discard). Diffing avoids the
        // classic feedback loop and protects the insertion point during normal typing.
        if textView.string != document.text {
            textView.string = document.text
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }

        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = SkillzTypography.editorNSFont(size: fontSize)
        }

        // Re-apply wrap only when it actually changes — applying it every keystroke would force
        // a redundant text-container relayout. `widthTracksTextView` handles live resizing.
        if context.coordinator.appliedWrap != lineWrap {
            applyWrap(lineWrap, to: textView, scrollView: scrollView)
            context.coordinator.appliedWrap = lineWrap
        }
    }

    private func applyWrap(_ wrap: Bool, to textView: NSTextView, scrollView: NSScrollView) {
        guard let container = textView.textContainer else { return }
        if wrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            container.widthTracksTextView = true
            let width = scrollView.contentSize.width
            container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var document: EditorDocument
        weak var textView: NSTextView?
        var appliedWrap: Bool?

        init(document: EditorDocument) {
            self.document = document
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Delegate callbacks arrive on the main thread; bridge to the @MainActor document.
            MainActor.assumeIsolated {
                document.updateText(textView.string)
            }
        }
    }
}
