import SwiftUI

/// Compact two-segment pill that flips a markdown pane between raw source and
/// rendered rich text. Selection styling mirrors the settings tab bar pill.
struct EditorViewModeToggle: View {
    @Binding var mode: EditorViewMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(EditorViewMode.allCases) { value in
                segment(for: value)
            }
        }
        .padding(2)
        .background(Color.skillzCanvas, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.skillzHairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editor view mode")
    }

    private func segment(for value: EditorViewMode) -> some View {
        Button {
            mode = value
        } label: {
            Text(value.displayName)
                .font(SkillzTypography.caption)
                .foregroundStyle(mode == value ? Color.skillzEmphasis : Color.skillzMuted)
                .padding(.horizontal, SkillzSpacing.sm)
                .frame(height: 16)
                .background {
                    Capsule()
                        .fill(mode == value ? Color.skillzSelection.opacity(0.58) : Color.clear)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(value == .source ? "Show raw markdown source" : "Show rendered rich text")
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}
