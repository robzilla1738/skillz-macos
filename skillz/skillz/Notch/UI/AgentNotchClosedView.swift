import SwiftUI

struct AgentNotchClosedView: View {
    let summary: AgentActivitySummary

    private var visibleSessions: [AgentSession] {
        let sessions = summary.notchClosedSessions
        return sessions.isEmpty ? AgentPlatform.trackedAgentPlatforms.map { platform in
            AgentSession(
                id: "inactive:\(platform.id)",
                platform: platform,
                state: .unknown,
                title: platform.displayName,
                cwd: nil,
                pid: nil,
                updatedAt: .distantPast,
                source: .fileWatch
            )
        } : Array(sessions.prefix(6))
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(visibleSessions) { session in
                sessionGlyph(session)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchMonochromeStyle.muted)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(closedAccessibilityLabel)
    }

    private var overflowCount: Int {
        max(summary.notchClosedSessions.count - visibleSessions.count, 0)
    }

    @ViewBuilder
    private func sessionGlyph(_ session: AgentSession) -> some View {
        ZStack(alignment: .topTrailing) {
            PlatformBrandIcon(
                platform: session.platform,
                size: 12,
                opacity: NotchMonochromeStyle.iconOpacity(for: session.state)
            )

            if session.state == .needsInput {
                Circle()
                    .fill(NotchMonochromeStyle.ink)
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: -3)
            } else if session.state == .working {
                Circle()
                    .strokeBorder(NotchMonochromeStyle.ink.opacity(0.7), lineWidth: 1)
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: -3)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityLabel("\(session.platform.displayName) \(session.state.displayName)")
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
