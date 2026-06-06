import Foundation

/// Decodes a property list (binary or XML) and re-serializes it as XML text so
/// the XML highlighter can render it. Returns `nil` when the data is not a
/// valid plist — callers fall back to showing the raw text.
nonisolated enum PlistRenderer {
    static func xmlString(from data: Data) -> String? {
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let xmlData = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0),
              let xml = String(data: xmlData, encoding: .utf8) else {
            return nil
        }
        return xml
    }
}
