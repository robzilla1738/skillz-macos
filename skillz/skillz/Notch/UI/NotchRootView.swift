import SwiftUI

struct NotchRootView: View {
    @ObservedObject var notchModel: NotchViewModel
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    var onReveal: (AgentSession) -> Void
    var onOpenSkillz: () -> Void
    var onRefresh: () -> Void
    var onInstallHooks: () -> Void

    @State private var isHovering = false
    @State private var hoverTask: Task<Void, Never>?

    private var displayRowCount: Int {
        agentStore.summary.notchDisplaySessions.count
    }

    private var hasAttentionRows: Bool {
        agentStore.summary.hasNotchAttention
    }

    private var showsHooksPrompt: Bool {
        hookStore.statuses.contains { $0.status != .installed && $0.status != .unsupported }
    }

    var body: some View {
        ZStack(alignment: .top) {
            notchBody
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
                .onHover(perform: handleHover)
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
        .onChange(of: notchModel.state) { _, _ in
            syncLayout()
        }
    }

    @ViewBuilder
    private var notchBody: some View {
        switch notchModel.state {
        case .hidden:
            EmptyView()
        case .closed:
            AgentNotchClosedView(summary: agentStore.summary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .onTapGesture {
                    notchModel.open(pinned: true)
                }
        case .peeking(let kind):
            peekContent(kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                .padding(.horizontal, 12)
        case .open:
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

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()

        if hovering {
            isHovering = true
            guard case .closed = notchModel.state else { return }
            guard hasAttentionRows else { return }
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if isHovering, case .closed = notchModel.state {
                        notchModel.open(pinned: false)
                    }
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isHovering = false
                    if case .open = notchModel.state, !notchModel.isPinnedOpen, !hasAttentionRows {
                        notchModel.close()
                    }
                }
            }
        }
    }
}
