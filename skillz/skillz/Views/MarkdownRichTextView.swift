import SwiftUI
import MarkdownUI

/// Read-only rendered view of the current markdown document. YAML frontmatter
/// is stripped from the rendered body and surfaced as a compact metadata card.
/// This view never mutates the document — editing stays in `MarkdownTextView`.
struct MarkdownRichTextView: View {
    let text: String
    let fontSize: Double

    @Environment(\.colorScheme) private var colorScheme

    /// Follows the markdown Quick Look preferences so one place governs
    /// remote-image loading and the font family in both the app and Finder
    /// previews. (Font size stays the editor's setting.)
    private var markdownPreferences: PreviewTypeSettings {
        PreviewSettingsStore().load(.markdown)
    }

    var body: some View {
        let parsed = FrontmatterParser.parse(from: text)
        let palette = PreviewPalette(theme: PreviewThemePreset.skillzAuto.theme, colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
                if hasFrontmatter(parsed.frontmatter) {
                    frontmatterCard(parsed.frontmatter)
                }

                renderedBody(parsed.body, palette: palette)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, SkillzSpacing.xl)
            .padding(.vertical, SkillzSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.skillzCanvas)
        .accessibilityLabel("Rendered markdown preview")
    }

    @ViewBuilder
    private func renderedBody(_ body: String, palette: PreviewPalette) -> some View {
        let preferences = markdownPreferences
        let themed = Markdown(body)
            .markdownTheme(
                SkillzMarkdownTheme.theme(
                    palette: palette,
                    fontSize: fontSize,
                    fontName: preferences.fontName
                )
            )
            .textSelection(.enabled)

        if preferences.loadRemoteImages {
            themed
        } else {
            themed
                .markdownImageProvider(LocalOnlyImageProvider())
                .markdownInlineImageProvider(LocalOnlyInlineImageProvider())
        }
    }

    private func hasFrontmatter(_ frontmatter: SkillFrontmatter) -> Bool {
        frontmatter.name != nil
            || frontmatter.description != nil
            || frontmatter.version != nil
            || frontmatter.disableModelInvocation != nil
    }

    private func frontmatterCard(_ frontmatter: SkillFrontmatter) -> some View {
        SkillzDetailCard(title: "Frontmatter") {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                if let name = frontmatter.name {
                    SkillzDetailRow(label: "Name", value: name, mono: true)
                }
                if let description = frontmatter.description {
                    SkillzDetailRow(label: "Description", value: description)
                }
                if let version = frontmatter.version {
                    SkillzDetailRow(label: "Version", value: version, mono: true)
                }
                if let disabled = frontmatter.disableModelInvocation {
                    SkillzDetailRow(label: "Invocation", value: disabled ? "Manual only" : "Model + manual")
                }
            }
        }
    }

}
