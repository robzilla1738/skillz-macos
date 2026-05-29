import SwiftUI

struct MarkdownEditorView: View {
    @ObservedObject var document: EditorDocument
    let fontSize: Double

    var body: some View {
        TextEditor(text: Binding(
            get: { document.text },
            set: { document.updateText($0) }
        ))
        .font(SkillzTypography.editor(size: fontSize))
        .foregroundStyle(Color.skillzEmphasis)
        .scrollContentBackground(.hidden)
        .padding(SkillzSpacing.lg)
        .background(Color.skillzCanvas)
        .accessibilityLabel("Markdown editor")
    }
}
