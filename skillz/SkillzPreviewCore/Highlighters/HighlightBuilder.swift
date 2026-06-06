import SwiftUI

/// Accumulates colored text runs into one `AttributedString`, merging adjacent
/// runs of the same color so output stays compact for large inputs.
nonisolated struct HighlightBuilder {
    private var output = AttributedString()
    private var runText = ""
    private var runColor: Color?

    mutating func append(_ text: some StringProtocol, color: Color) {
        guard !text.isEmpty else { return }
        if runColor != color {
            flush()
            runColor = color
        }
        runText += text
    }

    mutating func newline(color: Color) {
        append("\n", color: color)
    }

    private mutating func flush() {
        guard !runText.isEmpty, let color = runColor else {
            runText = ""
            return
        }
        var segment = AttributedString(runText)
        segment.foregroundColor = color
        output += segment
        runText = ""
    }

    mutating func build() -> AttributedString {
        flush()
        return output
    }
}
