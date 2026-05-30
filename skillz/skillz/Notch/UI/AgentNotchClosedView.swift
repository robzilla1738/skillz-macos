import SwiftUI
import AppKit

struct AgentNotchClosedView: View {
    let summary: AgentActivitySummary
    var onReveal: (AgentSession) -> Void

    /// One representative session per platform (deduped upstream) drives the HUD: the count on the
    /// left and a single icon per agent type on the right.
    private var platformSessions: [AgentSession] {
        summary.notchSessions
    }

    private var activeCount: Int {
        platformSessions.count
    }

    private var visiblePlatformSessions: [AgentSession] {
        Array(platformSessions.prefix(5))
    }

    private var overflowCount: Int {
        max(platformSessions.count - visiblePlatformSessions.count, 0)
    }

    var body: some View {
        Group {
            if activeCount == 0 {
                idleIndicator
            } else {
                activeContent
            }
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: platformSessions.map(\.platform))
        .animation(.snappy(duration: 0.28), value: activeCount)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(closedAccessibilityLabel)
    }

    private var activeContent: some View {
        HStack(spacing: 0) {
            countLabel

            Spacer(minLength: 10)

            iconCluster
        }
    }

    /// At rest (no working/waiting/stopped agents) the notch still shows a quiet, on-brand mark so the
    /// indicator never disappears — mirroring how the Dynamic Island always keeps its pill present.
    private var idleIndicator: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NotchMonochromeStyle.faint)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
    }

    private var countLabel: some View {
        Text("\(activeCount)")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(NotchMonochromeStyle.ink)
            .contentTransition(.numericText())
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var iconCluster: some View {
        HStack(spacing: 9) {
            ForEach(visiblePlatformSessions) { session in
                Button {
                    onReveal(session)
                } label: {
                    sessionGlyph(session)
                }
                .buttonStyle(.plain)
                .help("Open \(session.platform.displayName) session")
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.4).combined(with: .opacity),
                    removal: .scale(scale: 0.4).combined(with: .opacity)
                ))
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(NotchMonochromeStyle.muted)
                    .transition(.opacity)
                    .accessibilityLabel("\(overflowCount) more active agents")
            }
        }
    }

    @ViewBuilder
    private func sessionGlyph(_ session: AgentSession) -> some View {
        ZStack(alignment: .topTrailing) {
            PlatformBrandIcon(
                platform: session.platform,
                size: 12,
                opacity: NotchMonochromeStyle.iconOpacity(for: session.state)
            )

            switch session.state {
            case .needsInput:
                Circle()
                    .fill(NotchMonochromeStyle.ink)
                    .frame(width: 5, height: 5)
                    .offset(x: 3, y: -3)
            case .working:
                WorkingPulseIndicator()
                    .offset(x: 3, y: -3)
            case .idle, .unknown:
                EmptyView()
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

/// Softly pulsing ring that signals a live, working agent. Respects Reduce Motion.
private struct WorkingPulseIndicator: View {
    @State private var animate = false

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var body: some View {
        Circle()
            .strokeBorder(NotchMonochromeStyle.ink.opacity(0.7), lineWidth: 1)
            .frame(width: 5, height: 5)
            .scaleEffect(animate ? 1.3 : 0.85)
            .opacity(animate ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}
