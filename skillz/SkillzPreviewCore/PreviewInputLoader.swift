import Foundation

/// Reads preview input with byte + line caps so Quick Look previews stay well
/// inside the extension's memory/time budget (~120 MB / 30 s).
nonisolated enum PreviewInputLoader {
    static let maxBytes = 1_500_000
    static let maxLines = 5_000
    /// Binary plists must be parsed whole; allow a larger raw budget before
    /// conversion, then cap the resulting XML text.
    static let maxPlistBytes = 8_000_000

    struct LoadedText: Equatable {
        let text: String
        let wasTruncated: Bool
    }

    enum LoadError: Error {
        case unreadable
        case tooLarge
    }

    static func load(_ url: URL, type: PreviewFileType) throws -> LoadedText {
        if type == .plist {
            return try loadPlist(url)
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw LoadError.unreadable
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: maxBytes + 1) else {
            throw LoadError.unreadable
        }

        let byteTruncated = data.count > maxBytes
        let text = String(decoding: data.prefix(maxBytes), as: UTF8.self)
        return capped(text: text, alreadyTruncated: byteTruncated)
    }

    private static func loadPlist(_ url: URL) throws -> LoadedText {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int else {
            throw LoadError.unreadable
        }
        guard size <= maxPlistBytes else {
            throw LoadError.tooLarge
        }
        guard let data = try? Data(contentsOf: url) else {
            throw LoadError.unreadable
        }

        if let xml = PlistRenderer.xmlString(from: data) {
            return capped(text: xml)
        }

        // Fall back to raw text for malformed plists so the user still sees
        // something useful; flag the clip so the truncation footer shows.
        let clipped = data.count > maxBytes
        return capped(
            text: String(decoding: data.prefix(maxBytes), as: UTF8.self),
            alreadyTruncated: clipped
        )
    }

    /// Pure cap used by `load` and directly testable: enforces the byte cap
    /// (in UTF-8) and then the line cap.
    static func capped(text: String, alreadyTruncated: Bool = false) -> LoadedText {
        var working = text
        var truncated = alreadyTruncated

        if working.utf8.count > maxBytes {
            let prefixData = Data(working.utf8.prefix(maxBytes))
            working = String(decoding: prefixData, as: UTF8.self)
            truncated = true
        }

        let lines = working.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > maxLines {
            working = lines.prefix(maxLines).joined(separator: "\n")
            truncated = true
        }

        return LoadedText(text: working, wasTruncated: truncated)
    }
}
