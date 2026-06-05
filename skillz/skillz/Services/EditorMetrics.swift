import Foundation

/// Pure text statistics for the editor footer.
enum EditorMetrics {
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    static func characterCount(_ text: String) -> Int {
        text.count
    }
}
