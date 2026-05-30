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
    private var hoverInsideTask: Task<Void, Never>?
    private var hoverOutsideTask: Task<Void, Never>?
    private var previousAttentionKeys: Set<String> = []

    /// How long the cursor must rest over the closed pill before it expands. Short enough to feel
    /// instant, long enough to ignore the cursor merely passing across the notch.
    private let hoverOpenDelay: Duration = .milliseconds(120)
    /// Small grace period before collapsing so brief excursions off the panel edge don't flicker it.
    private let hoverCloseDelay: Duration = .milliseconds(150)
    private var layoutRowCount = 1
    private var layoutShowsHooksPrompt = false

    /// Whether there is anything worth showing in the resting notch (working, waiting, or stopped sessions).
    private(set) var hasContent = false

    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Lively, lightly-bouncy spring for revealing/expanding the notch — the shape grows into place
    /// like the Dynamic Island. A little overshoot reads as "alive" without feeling loose.
    var openAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.22) : .spring(response: 0.4, dampingFraction: 0.78)
    }

    /// Quick, near-critically-damped spring for collapsing — fluid with no lingering bounce.
    var closeAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.86)
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
            // The resting pill uses an *exact-size* window (no padding/shadow margin) so the always-on
            // notch never leaves an invisible region over the menu bar that would swallow clicks. The
            // padded window is only used while open/peeking, where the larger interactive area is
            // expected and the shadow needs room.
            return (width: geometry.closedWidth, height: geometry.closedHeight)
        }
    }

    func updateOpenLayout(rowCount: Int, showsHooksPrompt: Bool) {
        layoutRowCount = rowCount
        layoutShowsHooksPrompt = showsHooksPrompt
        let previous = openLayout
        applyOpenLayout()
        if openLayout != previous, usesOpenLayout {
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

    /// Refresh resting visibility from the latest summary without triggering attention drop-downs.
    func refreshContent(from summary: AgentActivitySummary) {
        hasContent = !summary.notchClosedSessions.isEmpty || summary.hasNotchAttention
    }

    func bind(to agentStore: AgentSessionStore) {
        let summary = agentStore.summary
        hasContent = !summary.notchClosedSessions.isEmpty || summary.hasNotchAttention

        let attention = summary.notchAttentionSessions
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

    func showAttention(for session: AgentSession) {
        showAttention()
        if session.state == .idle {
            scheduleFinishedDismiss()
        }
    }

    private func showAttention() {
        dismissTask?.cancel()
        isPinnedOpen = false
        withAnimation(openAnimation) {
            state = .open(.home)
        }
        onLayoutChange?()
    }

    private func scheduleFinishedDismiss() {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, !self.isPinnedOpen else { return }
                self.closeIfTransient()
            }
        }
    }

    func cancelPendingDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    /// Single source of truth for hover-driven expansion, fed by the controller's mouse monitor.
    /// Expands the closed pill after a short delay and collapses an un-pinned panel when the cursor
    /// leaves. Pinned-open panels (opened by a click) are left alone — only a click closes those.
    func setHovering(_ inside: Bool) {
        if inside {
            hoverOutsideTask?.cancel()
            hoverOutsideTask = nil
            cancelPendingDismiss()
            guard case .closed = state, hoverInsideTask == nil else { return }
            hoverInsideTask = Task { [weak self] in
                try? await Task.sleep(for: self?.hoverOpenDelay ?? .milliseconds(120))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.hoverInsideTask = nil
                    if case .closed = self.state { self.open(pinned: false) }
                }
            }
        } else {
            hoverInsideTask?.cancel()
            hoverInsideTask = nil
            guard case .open = state, !isPinnedOpen, hoverOutsideTask == nil else { return }
            hoverOutsideTask = Task { [weak self] in
                try? await Task.sleep(for: self?.hoverCloseDelay ?? .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.hoverOutsideTask = nil
                    if case .open = self.state, !self.isPinnedOpen { self.close() }
                }
            }
        }
    }

    func openTransient(duration: TimeInterval = 2.4) {
        open(pinned: false)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, !self.isPinnedOpen else { return }
                self.closeIfTransient()
            }
        }
    }

    /// The notch always rests in its closed (pill) form while the feature is enabled, so there is a
    /// visible, Dynamic-Island-style indicator even with no active agents. `.hidden` is reserved for
    /// when the notch is switched off entirely (handled by `hide()` / the window controller).
    private var restingState: NotchState { .closed }

    private func closeIfTransient() {
        dismissTask?.cancel()
        let target = restingState
        if state == target { return }
        withAnimation(closeAnimation) {
            state = target
        }
        onLayoutChange?()
    }

    func showPeek(_ kind: NotchPeekKind, duration: TimeInterval = 1.6) {
        dismissTask?.cancel()
        withAnimation(openAnimation) {
            state = .peeking(kind)
        }
        onLayoutChange?()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if case .peeking = self.state {
                    withAnimation(self.closeAnimation) {
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
        withAnimation(openAnimation) {
            state = .open(panel)
        }
        onLayoutChange?()
    }

    func close() {
        dismissTask?.cancel()
        isPinnedOpen = false
        withAnimation(closeAnimation) {
            state = restingState
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

    private var usesOpenLayout: Bool {
        switch state {
        case .open, .peeking: return true
        case .closed, .hidden: return false
        }
    }
}
