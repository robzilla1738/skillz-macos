import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var state: NotchState = .closed
    @Published var isPinnedOpen = false
    @Published var openLayout: NotchOpenLayout = NotchLayoutCalculator.openLayout(
        rowCount: 1,
        showsHooksPrompt: false,
        closedWidth: NotchGeometry.closedFallbackWidth,
        hasPhysicalNotch: false
    )
    @Published var geometry: NotchGeometry = NotchGeometry.make(for: NSScreen.main ?? NSScreen.screens[0])

    var onLayoutChange: (() -> Void)?

    private var dismissTask: Task<Void, Never>?
    private var previousAttentionKeys: Set<String> = []
    private var layoutRowCount = 1
    private var layoutShowsHooksPrompt = false

    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var panelSize: (width: CGFloat, height: CGFloat) {
        switch state {
        case .open:
            return NotchLayoutCalculator.panelSize(for: openLayout, closedHeight: geometry.closedHeight)
        case .peeking:
            let peekLayout = NotchOpenLayout(
                width: max(openLayout.width, 260),
                height: geometry.closedHeight + 48
            )
            return NotchLayoutCalculator.panelSize(for: peekLayout, closedHeight: geometry.closedHeight)
        case .closed, .hidden:
            let closedLayout = NotchOpenLayout(width: geometry.closedWidth, height: geometry.closedHeight)
            return NotchLayoutCalculator.panelSize(for: closedLayout, closedHeight: geometry.closedHeight)
        }
    }

    func updateOpenLayout(rowCount: Int, showsHooksPrompt: Bool) {
        layoutRowCount = rowCount
        layoutShowsHooksPrompt = showsHooksPrompt
        let previous = openLayout
        applyOpenLayout()
        if openLayout != previous {
            onLayoutChange?()
        }
    }

    private func applyOpenLayout() {
        openLayout = NotchLayoutCalculator.openLayout(
            rowCount: layoutRowCount,
            showsHooksPrompt: layoutShowsHooksPrompt,
            closedWidth: geometry.closedWidth,
            hasPhysicalNotch: geometry.hasPhysicalNotch
        )
    }

    func bind(to agentStore: AgentSessionStore) {
        let attention = agentStore.summary.notchAttentionSessions
        let attentionKeys = Set(attention.map(attentionKey(for:)))
        let newAttention = attention.filter { !previousAttentionKeys.contains(attentionKey(for: $0)) }

        if let session = newAttention.first {
            showAttention(for: session)
        } else if attention.isEmpty, !isPinnedOpen {
            closeIfTransient()
        }

        previousAttentionKeys = attentionKeys
    }

    private func attentionKey(for session: AgentSession) -> String {
        "\(session.id):\(session.state.rawValue)"
    }

    func showAttention(for _: AgentSession) {
        dismissTask?.cancel()
        isPinnedOpen = false
        withAnimation(reduceMotion ? .easeInOut(duration: 0.22) : .interactiveSpring(response: 0.38, dampingFraction: 0.86)) {
            state = .open(.home)
        }
        onLayoutChange?()
    }

    private func closeIfTransient() {
        dismissTask?.cancel()
        if case .closed = state { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 1)) {
            state = .closed
        }
        onLayoutChange?()
    }

    func showPeek(_ kind: NotchPeekKind, duration: TimeInterval = 1.6) {
        dismissTask?.cancel()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth) {
            state = .peeking(kind)
        }
        onLayoutChange?()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if case .peeking = self.state {
                    withAnimation(self.reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 1)) {
                        self.state = .closed
                    }
                    self.onLayoutChange?()
                }
            }
        }
    }

    func open(_ panel: NotchPanelMode = .home, pinned: Bool = false) {
        dismissTask?.cancel()
        isPinnedOpen = pinned
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
            state = .open(panel)
        }
        onLayoutChange?()
    }

    func close() {
        dismissTask?.cancel()
        isPinnedOpen = false
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 1)) {
            state = .closed
        }
        onLayoutChange?()
    }

    func hide() {
        dismissTask?.cancel()
        isPinnedOpen = false
        state = .hidden
        onLayoutChange?()
    }

    func updateGeometry(for screen: NSScreen) {
        geometry = NotchGeometry.make(for: screen)
        applyOpenLayout()
        onLayoutChange?()
    }

    var currentWidth: CGFloat {
        switch state {
        case .hidden: return 0
        case .closed: return geometry.closedWidth
        case .peeking: return max(openLayout.width, 260)
        case .open: return openLayout.width
        }
    }

    var currentHeight: CGFloat {
        switch state {
        case .hidden: return 0
        case .closed: return geometry.closedHeight
        case .peeking: return geometry.closedHeight + 48
        case .open: return openLayout.height
        }
    }

    var topRadius: CGFloat {
        switch state {
        case .closed: return 16
        case .peeking: return 18
        case .open: return 24
        case .hidden: return 16
        }
    }

    var bottomRadius: CGFloat {
        switch state {
        case .closed: return 16
        case .peeking: return 18
        case .open: return 24
        case .hidden: return 16
        }
    }

    var showsShadow: Bool {
        switch state {
        case .open, .peeking: return true
        default: return false
        }
    }
}
