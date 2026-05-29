import SwiftUI

struct AgentNotchClosedView: View {
    let summary: AgentActivitySummary

    private var visiblePlatforms: [AgentPlatform] {
        let active = AgentPlatform.trackedAgentPlatforms.filter { platform in
            guard let state = summary.bestSession(for: platform)?.state else { return false }
            return state == .working || state == .needsInput || state == .idle
        }
        return active.isEmpty ? AgentPlatform.trackedAgentPlatforms : active
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(visiblePlatforms, id: \.id) { platform in
                platformGlyph(platform)
            }

            if summary.needsInputCount > 0 {
                needsInputBadge
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(closedAccessibilityLabel)
    }

    private var needsInputBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(NotchMonochromeStyle.ink)
                .frame(width: 5, height: 5)
            Text("\(summary.needsInputCount)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NotchMonochromeStyle.ink)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .overlay {
            Capsule().strokeBorder(NotchMonochromeStyle.ink.opacity(0.85), lineWidth: 1)
        }
        .accessibilityLabel("\(summary.needsInputCount) waiting")
    }

    @ViewBuilder
    private func platformGlyph(_ platform: AgentPlatform) -> some View {
        let session = summary.bestSession(for: platform)
        let state = session?.state

        ZStack(alignment: .topTrailing) {
            PlatformBrandIcon(
                platform: platform,
                size: 11,
                opacity: NotchMonochromeStyle.iconOpacity(for: state)
            )

            if state == .needsInput {
                Circle()
                    .fill(NotchMonochromeStyle.ink)
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: -3)
            } else if state == .working {
                Circle()
                    .strokeBorder(NotchMonochromeStyle.ink.opacity(0.7), lineWidth: 1)
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: -3)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityLabel("\(platform.displayName) \(session?.state.displayName ?? "inactive")")
    }

    private var closedAccessibilityLabel: String {
        if summary.hasNeedsInput {
            return "Agents active. \(summary.needsInputCount) waiting for your input."
        }
        if summary.workingCount > 0 {
            return "Agents active. \(summary.workingCount) working."
        }
        return "No active agents."
    }
}
