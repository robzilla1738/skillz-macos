import AppKit
import MarkdownUI
import SwiftUI

/// Markdown image loading policy for previews: never touch the network.
///
/// Rendered markdown previews handle untrusted agent artifacts (skills
/// installed from marketplaces, arbitrary files previewed in Finder). With
/// MarkdownUI's default providers, `![…](https://…)` would trigger a
/// URLSession fetch just by rendering — leaking the user's IP and the fact
/// that a file was previewed. Local file URLs still render (size-capped);
/// everything else gets an inert placeholder.
nonisolated enum MarkdownImagePolicy {
    /// Largest local image file the previews will load.
    static let maxLocalImageBytes = 20_000_000

    static func localImage(at url: URL?) -> NSImage? {
        guard let url, url.isFileURL else { return nil }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maxLocalImageBytes else { return nil }
        return NSImage(contentsOf: url)
    }

    static func placeholderLabel(for url: URL?) -> String {
        guard let url else { return "image" }
        if let host = url.host, !host.isEmpty { return host }
        let name = url.lastPathComponent
        return name.isEmpty ? "image" : name
    }
}

/// Block-image provider: loads local files, renders a placeholder for
/// remote/relative/data URLs without fetching anything.
nonisolated struct LocalOnlyImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        Group {
            if let image = MarkdownImagePolicy.localImage(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder(for: url)
            }
        }
    }

    private func placeholder(for url: URL?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
                .imageScale(.small)
            Text(MarkdownImagePolicy.placeholderLabel(for: url))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.secondary.opacity(0.35), lineWidth: 1)
        }
        .accessibilityLabel("Image not loaded: \(MarkdownImagePolicy.placeholderLabel(for: url))")
    }
}

/// Inline-image provider counterpart (images inside a line of text).
nonisolated struct LocalOnlyInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        if let image = MarkdownImagePolicy.localImage(at: url) {
            return Image(nsImage: image)
        }
        return Image(systemName: "photo")
    }
}
