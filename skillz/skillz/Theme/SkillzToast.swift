import SwiftUI

/// Transient, auto-dismissing confirmation toast. Mirrors `SkillzErrorBanner` styling but is
/// non-interactive and used for success/info feedback.
struct SkillzToast: View {
    let toast: ToastCenter.Toast

    var body: some View {
        HStack(spacing: SkillzSpacing.sm) {
            Image(systemName: toast.kind.symbolName)
                .font(SkillzTypography.caption)
                .foregroundStyle(Color.skillzEmphasis)
            Text(toast.message)
                .font(SkillzTypography.caption)
                .foregroundStyle(Color.skillzEmphasis)
                .lineLimit(2)
        }
        .padding(.horizontal, SkillzSpacing.lg)
        .padding(.vertical, SkillzSpacing.md)
        .background(Color.skillzCanvas, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.skillzHairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .padding(.bottom, SkillzSpacing.lg)
    }
}
