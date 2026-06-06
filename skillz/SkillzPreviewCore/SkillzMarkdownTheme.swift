import SwiftUI
import MarkdownUI

/// Builds a MarkdownUI `Theme` from a resolved `PreviewPalette` + font size.
/// Used by the Quick Look extension, the settings live preview, and the app's
/// Rich Text editor pane so all three render identically.
nonisolated enum SkillzMarkdownTheme {
    static func theme(palette: PreviewPalette, fontSize: Double, fontName: String? = nil) -> Theme {
        let choice = PreviewFontResolver.choice(for: fontName)
        return Theme()
            .text {
                bodyFamily(for: choice)
                FontSize(fontSize)
                ForegroundColor(palette.foreground)
            }
            .code {
                codeFamily(for: choice)
                FontSize(.em(0.94))
                BackgroundColor(palette.codeBackground)
            }
            .strong {
                FontWeight(.semibold)
            }
            .emphasis {
                FontStyle(.italic)
            }
            .link {
                ForegroundColor(palette.accent)
                UnderlineStyle(.single)
            }
            .heading1 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.6))
                            ForegroundColor(palette.heading)
                        }
                    Divider().overlay(palette.border)
                }
            }
            .heading2 { configuration in
                VStack(alignment: .leading, spacing: 0) {
                    configuration.label
                        .relativePadding(.bottom, length: .em(0.3))
                        .relativeLineSpacing(.em(0.125))
                        .markdownMargin(top: 24, bottom: 16)
                        .markdownTextStyle {
                            FontWeight(.semibold)
                            FontSize(.em(1.3))
                            ForegroundColor(palette.heading)
                        }
                    Divider().overlay(palette.border)
                }
            }
            .heading3 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 20, bottom: 12)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.15))
                        ForegroundColor(palette.heading)
                    }
            }
            .heading4 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 16, bottom: 10)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        ForegroundColor(palette.heading)
                    }
            }
            .heading5 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 16, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.9))
                        ForegroundColor(palette.heading)
                    }
            }
            .heading6 { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.125))
                    .markdownMargin(top: 16, bottom: 8)
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(0.85))
                        ForegroundColor(palette.secondary)
                    }
            }
            .paragraph { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.3))
                    .markdownMargin(top: 0, bottom: 14)
            }
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(palette.border)
                        .relativeFrame(width: .em(0.2))
                    configuration.label
                        .markdownTextStyle { ForegroundColor(palette.secondary) }
                        .relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            codeFamily(for: choice)
                            FontSize(.em(0.94))
                        }
                        .padding(12)
                }
                .background(palette.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 0, bottom: 14)
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: palette.border))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(Color.clear, palette.codeBackground)
                    )
                    .markdownMargin(top: 0, bottom: 14)
            }
            .tableCell { configuration in
                configuration.label
                    .markdownTextStyle {
                        if configuration.row == 0 {
                            FontWeight(.semibold)
                        }
                        FontSize(.em(0.94))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .relativeLineSpacing(.em(0.25))
            }
            .thematicBreak {
                Divider()
                    .overlay(palette.border)
                    .markdownMargin(top: 24, bottom: 24)
            }
    }

    /// Body text follows the user's font choice.
    @TextStyleBuilder
    private static func bodyFamily(for choice: PreviewFontResolver.Choice) -> some TextStyle {
        switch choice {
        case .systemMono:
            FontFamilyVariant(.monospaced)
        case .systemSans:
            FontFamily(.system(.default))
        case .systemSerif:
            FontFamily(.system(.serif))
        case .custom(let family):
            FontFamily(.custom(family))
        }
    }

    /// Code spans/blocks stay monospaced for the system sans/serif choices;
    /// a deliberately chosen custom family (usually a coding font) applies.
    @TextStyleBuilder
    private static func codeFamily(for choice: PreviewFontResolver.Choice) -> some TextStyle {
        switch choice {
        case .custom(let family):
            FontFamily(.custom(family))
        case .systemMono, .systemSans, .systemSerif:
            FontFamilyVariant(.monospaced)
        }
    }
}
