import AppKit
import SwiftUI

/// Stored identifiers for the non-custom font choices. Leading dots keep the
/// sentinels out of the real font-family namespace.
nonisolated enum PreviewFontID {
    static let systemMono = ".system-mono"
    static let systemSans = ".system-sans"
    static let systemSerif = ".system-serif"
}

/// Resolves a stored `PreviewTypeSettings.fontName` to a SwiftUI font.
/// `nil` and unknown/uninstalled family names fall back to the system
/// monospaced font so previews never break when a font disappears.
nonisolated enum PreviewFontResolver {
    enum Choice: Equatable {
        case systemMono
        case systemSans
        case systemSerif
        case custom(String)
    }

    static func choice(for name: String?) -> Choice {
        switch name {
        case nil, PreviewFontID.systemMono:
            return .systemMono
        case PreviewFontID.systemSans:
            return .systemSans
        case PreviewFontID.systemSerif:
            return .systemSerif
        case let custom?:
            return isInstalled(custom) ? .custom(custom) : .systemMono
        }
    }

    static func isInstalled(_ familyName: String) -> Bool {
        NSFont(name: familyName, size: 12) != nil
            || NSFontManager.shared.availableFontFamilies.contains(familyName)
    }

    static func font(name: String?, size: Double) -> Font {
        switch choice(for: name) {
        case .systemMono:
            return .system(size: size, design: .monospaced)
        case .systemSans:
            return .system(size: size, design: .default)
        case .systemSerif:
            return .system(size: size, design: .serif)
        case .custom(let family):
            return .custom(family, size: size)
        }
    }

    /// Display name for pickers and accessibility.
    static func displayName(for name: String?) -> String {
        switch choice(for: name) {
        case .systemMono: return "System Mono"
        case .systemSans: return "System Sans"
        case .systemSerif: return "System Serif"
        case .custom(let family): return family
        }
    }

    /// Installed fixed-pitch font families, for the settings picker. Sorted,
    /// computed on demand (font set can change while the app runs).
    static func installedMonospacedFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { family in
                guard !family.hasPrefix(".") else { return false }
                guard let font = NSFont(name: family, size: 12) else { return false }
                return font.isFixedPitch
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
