import Foundation

/// Per-file-type preview preferences shared between the app and the Quick Look
/// extension. Decoding is forward-compatible: every field falls back to a
/// neutral default when missing, so older blobs survive schema additions.
nonisolated struct PreviewTypeSettings: Codable, Equatable, Sendable {
    /// Per-type "Preview with Skills" switch. When off, the type renders the
    /// neutral system-style preview (`neutralFallback`) instead of the themed
    /// pipeline. Defaults on — existing blobs decode as enabled.
    var enabled: Bool
    var useCustomTheme: Bool
    var preset: PreviewThemePreset
    var fontSize: Double
    /// Font family: `nil` / `PreviewFontID.systemMono` for the system
    /// monospaced default, a `PreviewFontID` sentinel for sans/serif, or an
    /// installed family name. Missing fonts fall back to system mono at
    /// render time (`PreviewFontResolver`).
    var fontName: String?
    var lineWrap: Bool
    var showLineNumbers: Bool
    /// JSON / JSON Lines only.
    var jsonPrettyPrint: Bool
    /// Markdown only: rendered rich text (`true`) vs raw source (`false`).
    var markdownRenderedMode: Bool
    /// Markdown only: opt-in for fetching remote images in rendered previews.
    /// Off by default — previewed markdown is untrusted, and a fetch leaks
    /// the user's IP plus the fact that a file was previewed.
    var loadRemoteImages: Bool

    static let fontSizeRange: ClosedRange<Double> = 9...24

    init(
        enabled: Bool = true,
        useCustomTheme: Bool = true,
        preset: PreviewThemePreset = .skillzAuto,
        fontSize: Double = 13,
        fontName: String? = nil,
        lineWrap: Bool = true,
        showLineNumbers: Bool = false,
        jsonPrettyPrint: Bool = false,
        markdownRenderedMode: Bool = true,
        loadRemoteImages: Bool = false
    ) {
        self.enabled = enabled
        self.useCustomTheme = useCustomTheme
        self.preset = preset
        self.fontSize = fontSize.clamped(to: Self.fontSizeRange)
        self.fontName = fontName
        self.lineWrap = lineWrap
        self.showLineNumbers = showLineNumbers
        self.jsonPrettyPrint = jsonPrettyPrint
        self.markdownRenderedMode = markdownRenderedMode
        self.loadRemoteImages = loadRemoteImages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let neutral = PreviewTypeSettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? neutral.enabled
        useCustomTheme = try container.decodeIfPresent(Bool.self, forKey: .useCustomTheme) ?? neutral.useCustomTheme
        preset = try container.decodeIfPresent(PreviewThemePreset.self, forKey: .preset) ?? neutral.preset
        fontSize = (try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? neutral.fontSize)
            .clamped(to: Self.fontSizeRange)
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
        lineWrap = try container.decodeIfPresent(Bool.self, forKey: .lineWrap) ?? neutral.lineWrap
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers) ?? neutral.showLineNumbers
        jsonPrettyPrint = try container.decodeIfPresent(Bool.self, forKey: .jsonPrettyPrint) ?? neutral.jsonPrettyPrint
        markdownRenderedMode = try container.decodeIfPresent(Bool.self, forKey: .markdownRenderedMode) ?? neutral.markdownRenderedMode
        loadRemoteImages = try container.decodeIfPresent(Bool.self, forKey: .loadRemoteImages) ?? neutral.loadRemoteImages
    }

    /// What a disabled type renders: plain mono source, system colors, no
    /// gutter, no transforms — the closest stand-in for the macOS built-in
    /// text preview, since Quick Look offers no per-type hand-back.
    static let neutralFallback = PreviewTypeSettings(
        enabled: false,
        useCustomTheme: false,
        fontSize: 13,
        fontName: nil,
        lineWrap: true,
        showLineNumbers: false,
        jsonPrettyPrint: false,
        markdownRenderedMode: false,
        loadRemoteImages: false
    )

    /// Sensible per-type starting points.
    static func defaults(for type: PreviewFileType) -> PreviewTypeSettings {
        switch type {
        case .markdown:
            return PreviewTypeSettings(markdownRenderedMode: true)
        case .json:
            return PreviewTypeSettings(lineWrap: false, showLineNumbers: true, jsonPrettyPrint: true)
        case .jsonl:
            return PreviewTypeSettings(lineWrap: false, showLineNumbers: true, jsonPrettyPrint: false)
        case .yaml, .toml, .ini, .env, .sql, .xml, .plist, .shell:
            return PreviewTypeSettings(lineWrap: false, showLineNumbers: true)
        case .diff:
            return PreviewTypeSettings(lineWrap: false, showLineNumbers: false)
        case .csv:
            return PreviewTypeSettings(lineWrap: false)
        case .log:
            return PreviewTypeSettings(preset: .terminalMono, lineWrap: false, showLineNumbers: true)
        }
    }
}

nonisolated extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
