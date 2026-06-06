import SwiftUI

/// A single theme color with explicit light + dark variants, defined in code
/// as 0xRRGGBB hex. The preview core must not reference asset-catalog symbols
/// (`Color.skillz*`) — those are generated only in the app target and do not
/// exist in the Quick Look extension.
nonisolated struct PreviewColor: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32

    init(light: UInt32, dark: UInt32) {
        self.light = light
        self.dark = dark
    }

    init(_ both: UInt32) {
        self.light = both
        self.dark = both
    }

    func resolve(for colorScheme: ColorScheme) -> Color {
        Self.color(fromHex: colorScheme == .dark ? dark : light)
    }

    static func color(fromHex hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

/// Token palette consumed by the highlighters and the markdown theme builder.
nonisolated struct PreviewTheme: Equatable, Sendable {
    var background: PreviewColor
    var foreground: PreviewColor
    var secondary: PreviewColor
    var accent: PreviewColor
    var key: PreviewColor
    var string: PreviewColor
    var number: PreviewColor
    var comment: PreviewColor
    var punctuation: PreviewColor
    var heading: PreviewColor
    var lineNumber: PreviewColor
    var codeBackground: PreviewColor
    var border: PreviewColor
    var error: PreviewColor
    var warning: PreviewColor
    /// Added/positive content (diff additions).
    var success: PreviewColor
}

/// User-selectable theme presets shown in the Quick Look settings tab.
nonisolated enum PreviewThemePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case skillzAuto
    case skillzLight
    case skillzDark
    case githubLight
    case githubDark
    case terminalMono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skillzAuto: return "Skillz Auto"
        case .skillzLight: return "Skillz Light"
        case .skillzDark: return "Skillz Dark"
        case .githubLight: return "GitHub Light"
        case .githubDark: return "GitHub Dark"
        case .terminalMono: return "Terminal Mono"
        }
    }

    var theme: PreviewTheme {
        switch self {
        case .skillzAuto: return .skillzAuto
        case .skillzLight: return PreviewTheme.skillzAuto.forcing(\.light)
        case .skillzDark: return PreviewTheme.skillzAuto.forcing(\.dark)
        case .githubLight: return .githubLight
        case .githubDark: return .githubDark
        case .terminalMono: return .terminalMono
        }
    }
}

nonisolated extension PreviewTheme {
    /// Collapses an adaptive theme to one of its variants (used by the forced
    /// Skillz Light / Skillz Dark presets).
    func forcing(_ variant: KeyPath<PreviewColor, UInt32>) -> PreviewTheme {
        func fix(_ color: PreviewColor) -> PreviewColor {
            PreviewColor(color[keyPath: variant])
        }
        return PreviewTheme(
            background: fix(background),
            foreground: fix(foreground),
            secondary: fix(secondary),
            accent: fix(accent),
            key: fix(key),
            string: fix(string),
            number: fix(number),
            comment: fix(comment),
            punctuation: fix(punctuation),
            heading: fix(heading),
            lineNumber: fix(lineNumber),
            codeBackground: fix(codeBackground),
            border: fix(border),
            error: fix(error),
            warning: fix(warning),
            success: fix(success)
        )
    }

    /// Grayscale palette transcribed from the app's asset-catalog colors
    /// (SkillzCanvas/Ink/Emphasis/Muted/SectionLabel/Hairline/Selection).
    static let skillzAuto = PreviewTheme(
        background: PreviewColor(light: 0xFFFFFF, dark: 0x1E1E1E),
        foreground: PreviewColor(light: 0x333333, dark: 0xD1D1D1),
        secondary: PreviewColor(light: 0x535353, dark: 0x9D9D9D),
        accent: PreviewColor(light: 0x000000, dark: 0xF7F7F7),
        key: PreviewColor(light: 0x000000, dark: 0xF7F7F7),
        string: PreviewColor(light: 0x535353, dark: 0x9D9D9D),
        number: PreviewColor(light: 0x474747, dark: 0x8E8E8E),
        comment: PreviewColor(light: 0xA3A3A3, dark: 0x6B6B6B),
        punctuation: PreviewColor(light: 0x8E8E8E, dark: 0x757575),
        heading: PreviewColor(light: 0x000000, dark: 0xF7F7F7),
        lineNumber: PreviewColor(light: 0xB8B8B8, dark: 0x5A5A5A),
        codeBackground: PreviewColor(light: 0xF2F2F2, dark: 0x2A2A2A),
        border: PreviewColor(light: 0xE8E8E8, dark: 0x3C3C3C),
        error: PreviewColor(light: 0x000000, dark: 0xFFFFFF),
        warning: PreviewColor(light: 0x474747, dark: 0x8E8E8E),
        success: PreviewColor(light: 0x535353, dark: 0x9D9D9D)
    )

    /// GitHub Primer light palette.
    static let githubLight = PreviewTheme(
        background: PreviewColor(0xFFFFFF),
        foreground: PreviewColor(0x1F2328),
        secondary: PreviewColor(0x59636E),
        accent: PreviewColor(0x0969DA),
        key: PreviewColor(0x0550AE),
        string: PreviewColor(0x0A3069),
        number: PreviewColor(0x0550AE),
        comment: PreviewColor(0x6E7781),
        punctuation: PreviewColor(0x57606A),
        heading: PreviewColor(0x1F2328),
        lineNumber: PreviewColor(0x8C959F),
        codeBackground: PreviewColor(0xF6F8FA),
        border: PreviewColor(0xD0D7DE),
        error: PreviewColor(0xCF222E),
        warning: PreviewColor(0x9A6700),
        success: PreviewColor(0x1A7F37)
    )

    /// GitHub Primer dark palette.
    static let githubDark = PreviewTheme(
        background: PreviewColor(0x0D1117),
        foreground: PreviewColor(0xE6EDF3),
        secondary: PreviewColor(0x9198A1),
        accent: PreviewColor(0x58A6FF),
        key: PreviewColor(0x79C0FF),
        string: PreviewColor(0xA5D6FF),
        number: PreviewColor(0x79C0FF),
        comment: PreviewColor(0x8B949E),
        punctuation: PreviewColor(0x8B949E),
        heading: PreviewColor(0xE6EDF3),
        lineNumber: PreviewColor(0x6E7681),
        codeBackground: PreviewColor(0x161B22),
        border: PreviewColor(0x30363D),
        error: PreviewColor(0xFF7B72),
        warning: PreviewColor(0xD29922),
        success: PreviewColor(0x3FB950)
    )

    /// Green-phosphor terminal palette (always dark).
    static let terminalMono = PreviewTheme(
        background: PreviewColor(0x060A06),
        foreground: PreviewColor(0x3DDC84),
        secondary: PreviewColor(0x2BA866),
        accent: PreviewColor(0x9CFFC5),
        key: PreviewColor(0x7CF5A8),
        string: PreviewColor(0xB6FFD2),
        number: PreviewColor(0x8AF7B0),
        comment: PreviewColor(0x1F7A44),
        punctuation: PreviewColor(0x2BA866),
        heading: PreviewColor(0x9CFFC5),
        lineNumber: PreviewColor(0x1F7A44),
        codeBackground: PreviewColor(0x0B130C),
        border: PreviewColor(0x14301F),
        error: PreviewColor(0xFF5C57),
        warning: PreviewColor(0xF3F99D),
        success: PreviewColor(0x50FA7B)
    )
}

/// `PreviewTheme` resolved against a concrete color scheme — what the
/// highlighters and views actually consume.
nonisolated struct PreviewPalette: Sendable {
    let background: Color
    let foreground: Color
    let secondary: Color
    let accent: Color
    let key: Color
    let string: Color
    let number: Color
    let comment: Color
    let punctuation: Color
    let heading: Color
    let lineNumber: Color
    let codeBackground: Color
    let border: Color
    let error: Color
    let warning: Color
    let success: Color

    init(theme: PreviewTheme, colorScheme: ColorScheme) {
        background = theme.background.resolve(for: colorScheme)
        foreground = theme.foreground.resolve(for: colorScheme)
        secondary = theme.secondary.resolve(for: colorScheme)
        accent = theme.accent.resolve(for: colorScheme)
        key = theme.key.resolve(for: colorScheme)
        string = theme.string.resolve(for: colorScheme)
        number = theme.number.resolve(for: colorScheme)
        comment = theme.comment.resolve(for: colorScheme)
        punctuation = theme.punctuation.resolve(for: colorScheme)
        heading = theme.heading.resolve(for: colorScheme)
        lineNumber = theme.lineNumber.resolve(for: colorScheme)
        codeBackground = theme.codeBackground.resolve(for: colorScheme)
        border = theme.border.resolve(for: colorScheme)
        error = theme.error.resolve(for: colorScheme)
        warning = theme.warning.resolve(for: colorScheme)
        success = theme.success.resolve(for: colorScheme)
    }
}
