import SwiftUI

struct MarkdownEditorView: View {
    @ObservedObject var document: EditorDocument
    let fontSize: Double
    var lineWrap: Bool = true

    var body: some View {
        MarkdownTextView(document: document, fontSize: fontSize, lineWrap: lineWrap)
            .background(Color.skillzCanvas)
            .accessibilityLabel("Markdown editor")
    }
}
