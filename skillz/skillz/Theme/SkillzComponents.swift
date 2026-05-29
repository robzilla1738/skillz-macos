import SwiftUI

struct SkillzHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.skillzHairline)
            .frame(height: 1)
    }
}

struct SkillzTag: View {
    enum Style {
        case outline
        case filled
        case muted
        /// List metadata — matches caption path text size and color.
        case subtle
    }

    let text: String
    var style: Style = .outline

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay {
                if showsBorder {
                    Capsule()
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .accessibilityLabel(text)
    }

    private var font: Font {
        switch style {
        case .subtle: return SkillzTypography.caption
        default: return SkillzTagMetrics.font
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .subtle: return SkillzSpacing.sm
        default: return SkillzTagMetrics.horizontalPadding
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .subtle: return 1
        default: return 0
        }
    }

    private var showsBorder: Bool {
        switch style {
        case .filled: return false
        case .subtle, .outline, .muted: return true
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return Color.skillzCanvas
        case .outline: return Color.skillzEmphasis
        case .muted, .subtle: return Color.skillzMuted
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled: return Color.skillzInk
        case .outline, .muted: return Color.skillzCanvas
        case .subtle: return Color.clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .filled: return .clear
        case .outline: return Color.skillzEmphasis
        case .muted, .subtle: return Color.skillzHairline
        }
    }
}

struct SkillzDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.md) {
            Text(title)
                .skillzSectionHeaderStyle()

            content
        }
        .padding(SkillzSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.skillzCanvas)
        .clipShape(RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                .strokeBorder(Color.skillzHairline, lineWidth: 1)
        }
    }
}

struct SkillzEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: SkillzSpacing.sm) {
            Text(title)
                .skillzListTitleStyle()
            Text(message)
                .skillzBodySecondaryStyle()
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.skillzCanvas)
    }
}

struct SkillzErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: SkillzSpacing.md) {
            Text(message)
                .font(SkillzTypography.caption)
                .foregroundStyle(Color.skillzEmphasis)
                .lineLimit(3)
            Spacer(minLength: SkillzSpacing.sm)
            Button("Dismiss", action: onDismiss)
                .font(SkillzTypography.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.skillzEmphasis)
        }
        .padding(.horizontal, SkillzSpacing.lg)
        .padding(.vertical, SkillzSpacing.md)
        .background(Color.skillzCanvas, in: RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SkillzSpacing.cardRadius)
                .strokeBorder(Color.skillzHairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, SkillzSpacing.lg)
        .padding(.bottom, SkillzSpacing.lg)
    }
}

struct SkillzGlassToolbarGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                content
                    .frame(height: SkillzPillMetrics.height)
                    .padding(.horizontal, SkillzSpacing.sm)
                    .glassEffect(in: Capsule())
            }
        } else {
            content
                .frame(height: SkillzPillMetrics.height)
                .padding(.horizontal, SkillzSpacing.sm)
                .background(.regularMaterial, in: Capsule())
        }
    }
}

struct SkillzGlassSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        SkillzGlassToolbarGroup {
            HStack(spacing: SkillzSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(SkillzPillMetrics.font)
                    .foregroundStyle(Color.skillzMuted)
                    .frame(width: SkillzPillMetrics.iconWidth)

                TextField(prompt, text: $text)
                    .textFieldStyle(.plain)
                    .font(SkillzPillMetrics.font)
                    .foregroundStyle(Color.skillzEmphasis)
            }
            .padding(.horizontal, SkillzPillMetrics.horizontalPadding)
            .frame(minWidth: 240)
        }
    }
}

/// Labels inside a glass toolbar group — no per-button chrome; the group carries the material.
struct SkillzGlassToolbarButtonStyle: ButtonStyle {
    var prominent: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SkillzPillMetrics.font)
            .padding(.horizontal, SkillzPillMetrics.horizontalPadding)
            .frame(height: SkillzPillMetrics.height)
            .foregroundStyle(foregroundColor)
            .background {
                if prominent && isEnabled {
                    Capsule().fill(Color.skillzInk)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return Color.skillzMuted }
        if prominent { return Color.skillzCanvas }
        return Color.skillzEmphasis
    }
}

struct SkillzSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .skillzSectionHeaderStyle()
    }
}

struct SkillzTextButton: View {
    let title: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(SkillzTextButtonStyle(prominent: prominent))
    }
}

struct SkillzTextButtonStyle: ButtonStyle {
    var prominent: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SkillzTypography.captionMedium)
            .padding(.horizontal, SkillzSpacing.md)
            .padding(.vertical, SkillzSpacing.sm)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: showsBorder ? 1 : 0)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var showsBorder: Bool {
        !prominent || !isEnabled
    }

    private var foregroundColor: Color {
        guard isEnabled else { return Color.skillzMuted }
        return prominent ? Color.skillzCanvas : Color.skillzEmphasis
    }

    private var backgroundColor: Color {
        guard isEnabled else { return Color.clear }
        return prominent ? Color.skillzEmphasis : Color.clear
    }

    private var borderColor: Color {
        guard isEnabled else { return Color.skillzHairline }
        return prominent ? Color.clear : Color.skillzEmphasis.opacity(0.35)
    }
}

struct SkillzDetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: SkillzSpacing.lg) {
            Text(label)
                .skillzDetailLabelStyle()
                .frame(width: 88, alignment: .leading)
            Text(value)
                .skillzDetailValueStyle(mono: mono)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SkillzCanvasBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.skillzCanvas)
    }
}

extension View {
    func skillzCanvas() -> some View {
        modifier(SkillzCanvasBackground())
    }
}
