import SwiftUI

struct NotchRootView: View {
    @ObservedObject var notchModel: NotchViewModel
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    var onReveal: (AgentSession) -> Void
    var onOpenSkillz: () -> Void
    var onRefresh: () -> Void
    var onInstallHooks: () -> Void

    private var displayRowCount: Int {
        agentStore.summary.notchSessions.count
    }

    private var showsHooksPrompt: Bool {
        hookStore.statuses.contains { $0.status != .installed && $0.status != .unsupported }
    }

    private var isOpen: Bool { if case .open = notchModel.state { return true }; return false }
    private var isClosed: Bool { if case .closed = notchModel.state { return true }; return false }
    private var isHidden: Bool { if case .hidden = notchModel.state { return true }; return false }
    private var peekKind: NotchPeekKind? {
        if case let .peeking(kind) = notchModel.state { return kind }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            notchBody
                // The shape (and the black fill) is the only thing that animates size: it grows/shrinks
                // with a spring while the content below stays laid out at its natural size, so the panel
                // is *revealed* by the clip rather than reflowed every frame. This is what makes the
                // motion read as smooth.
                .frame(width: notchModel.currentWidth, height: notchModel.currentHeight, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.black)
                .clipShape(NotchShape(topRadius: notchModel.topRadius, bottomRadius: notchModel.bottomRadius))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 1)
                        .padding(.horizontal, notchModel.topRadius)
                }
                .shadow(
                    color: notchModel.showsShadow ? .black.opacity(0.55) : .clear,
                    radius: 6,
                    y: 2
                )
                .contentShape(Rectangle())
                .opacity(isHidden ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            syncLayout()
            notchModel.bind(to: agentStore)
        }
        .onChange(of: agentStore.sessions) { _, _ in
            notchModel.bind(to: agentStore)
            syncLayout()
        }
        .onChange(of: hookStore.statuses) { _, _ in
            syncLayout()
        }
    }

    /// All states are layered and crossfaded by opacity. Each layer is laid out at its own resting
    /// size so the animated clip frame above simply reveals/hides it — there is no per-frame reflow.
    private var notchBody: some View {
        ZStack(alignment: .top) {
            closedLayer
                .opacity(isClosed ? 1 : 0)
                .allowsHitTesting(isClosed)

            openLayer
                .opacity(isOpen ? 1 : 0)
                .allowsHitTesting(isOpen)

            if let kind = peekKind {
                peekContent(kind)
                    .frame(
                        width: max(notchModel.openLayout.width, 260),
                        height: notchModel.geometry.closedHeight + 48,
                        alignment: .top
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
            }
        }
    }

    private var closedLayer: some View {
        AgentNotchClosedView(summary: agentStore.summary, onReveal: onReveal)
            .frame(width: notchModel.geometry.closedWidth, height: notchModel.geometry.closedHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                notchModel.open(pinned: true)
            }
    }

    private var openLayer: some View {
        AgentNotchOpenView(
            agentStore: agentStore,
            hookStatuses: hookStore.statuses,
            hasPhysicalNotch: notchModel.geometry.hasPhysicalNotch,
            onClose: { notchModel.close() },
            onReveal: onReveal,
            onOpenSkillz: onOpenSkillz,
            onRefresh: onRefresh,
            onInstallHooks: onInstallHooks
        )
        .frame(width: notchModel.openLayout.width, height: notchModel.openLayout.height, alignment: .top)
        // Click anywhere that isn't an interactive control to collapse back to the HUD.
        .onTapGesture {
            notchModel.close()
        }
    }

    @ViewBuilder
    private func peekContent(_ kind: NotchPeekKind) -> some View {
        switch kind {
        case .needsInput(let platformName, let sessionTitle):
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(NotchMonochromeStyle.ink)
                        .frame(width: 6, height: 6)
                    Text(platformName)
                        .font(NotchMonochromeStyle.titleFont)
                        .foregroundStyle(NotchMonochromeStyle.ink)
                }
                Text(sessionTitle)
                    .font(NotchMonochromeStyle.bodyFont)
                    .foregroundStyle(NotchMonochromeStyle.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Waiting for you")
                    .font(NotchMonochromeStyle.captionFont)
                    .foregroundStyle(NotchMonochromeStyle.faint)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func syncLayout() {
        notchModel.updateOpenLayout(
            rowCount: displayRowCount,
            showsHooksPrompt: showsHooksPrompt
        )
    }
}
