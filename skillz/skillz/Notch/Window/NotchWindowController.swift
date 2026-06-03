import AppKit
import SwiftUI
import QuartzCore
import Combine

@MainActor
final class NotchWindowController: NSWindowController {
    private let notchModel = NotchViewModel()
    private weak var agentStore: AgentSessionStore?
    private weak var hookStore: AgentHookStore?
    private weak var settings: AppSettings?
    private var hostingView: NSHostingView<AnyView>?
    private var pendingFrameTask: Task<Void, Never>?
    private var lastAppliedFrame: NSRect?
    private var cancellables: Set<AnyCancellable> = []

    /// Screen-space rectangle of the live notch (closed pill or open panel) plus a small grace margin.
    /// Cached so the high-frequency mouse monitor stays O(1) — the guide's "never do heavy work in
    /// mouseMoved" rule.
    private var hotZone: CGRect = .zero
    private var lastHoverInside = false
    private var mouseMonitors: [Any] = []

    convenience init(agentStore: AgentSessionStore, hookStore: AgentHookStore, settings: AppSettings) {
        let screen = DisplayManager.shared.preferredScreen(settings: settings) ?? NSScreen.main ?? NSScreen.screens[0]
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 448, height: 300))
        self.init(window: panel)
        self.agentStore = agentStore
        self.hookStore = hookStore
        self.settings = settings
        notchModel.updateGeometry(for: screen)
        notchModel.onLayoutChange = { [weak self] in
            self?.schedulePanelFrame(animated: true)
            self?.updateHotZone()
        }
        setupContent()
        if let frame = targetFrame() {
            applyFrame(frame)
        }
        updateHotZone()
        observeStores(agentStore: agentStore, hookStore: hookStore)
        startMouseMonitoring()
    }

    deinit {
        for monitor in mouseMonitors {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// React to agent/hook changes from the controller itself rather than relying on the SwiftUI
    /// hosting view: when the panel is ordered out (empty/hidden state) SwiftUI suspends the hosting
    /// view's `onChange`, so without this the notch would never re-appear once it hides. Hopping to
    /// the next main-actor turn lets `@Published` finish assigning before we read the fresh summary.
    private func observeStores(agentStore: AgentSessionStore, hookStore: AgentHookStore) {
        agentStore.$summary
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleStoreChange() }
            }
            .store(in: &cancellables)

        hookStore.$statuses
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleStoreChange() }
            }
            .store(in: &cancellables)
    }

    private func handleStoreChange() {
        guard let agentStore, settings?.enableAgentNotch == true else { return }
        notchModel.bind(to: agentStore)
        let rowCount = agentStore.summary.notchSessions.count
        let showsHooks = hookStore?.statuses.contains { $0.status != .installed && $0.status != .unsupported } ?? false
        notchModel.updateOpenLayout(rowCount: rowCount, showsHooksPrompt: showsHooks)
        reposition()
        updatePanelVisibility()
        updateHotZone()
    }

    func refreshHookStatuses() {
        hookStore?.refresh()
        rebuildContent()
    }

    func showNotch() {
        guard let settings, settings.enableAgentNotch else {
            hideNotch()
            return
        }
        if let agentStore {
            notchModel.refreshContent(from: agentStore.summary)
        }
        // Always rest in the closed pill so there is a visible indicator at rest; bind() promotes to
        // the drop-down only when an agent needs attention.
        switch notchModel.state {
        case .open, .peeking:
            break
        case .closed, .hidden:
            notchModel.state = .closed
        }
        reposition()
        updatePanelVisibility()
        // Resolve click-through immediately for wherever the cursor currently sits.
        handleMouseMoved()
    }

    func hideNotch() {
        notchModel.hide()
        window?.orderOut(nil)
    }

    func openNotch() {
        notchModel.openTransient()
        window?.orderFrontRegardless()
    }

    func reposition() {
        guard let window, let screen = DisplayManager.shared.preferredScreen(settings: settings ?? .shared) else {
            return
        }
        notchModel.updateGeometry(for: screen)
        if let frame = targetFrame() {
            applyFrame(frame)
        }
        DisplayManager.shared.position(panel: window, on: screen, geometry: notchModel.geometry)
        updateHotZone()
    }

    // MARK: - Hover + click-through (global mouse monitor)

    /// Global + local mouse monitors are the most reliable way to track the cursor over a
    /// non-activating overlay regardless of which app is frontmost. The handler is O(1): a cached
    /// rectangle test plus, at most, one `ignoresMouseEvents` toggle and one hover transition.
    private func startMouseMonitoring() {
        guard mouseMonitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseMoved() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseMoved() }
            return event
        }
        mouseMonitors = [global, local].compactMap { $0 }
    }

    private func handleMouseMoved() {
        guard let window, settings?.enableAgentNotch == true else { return }
        let isOver = hotZone.contains(NSEvent.mouseLocation)

        // Click-through everywhere except directly over the notch — this is what lets the always-on
        // pill (and the transparent margins around the open panel) never steal clicks.
        let shouldIgnore = !isOver
        if window.ignoresMouseEvents != shouldIgnore {
            window.ignoresMouseEvents = shouldIgnore
        }

        guard isOver != lastHoverInside else { return }
        lastHoverInside = isOver
        notchModel.setHovering(isOver)
    }

    private func updateHotZone() {
        guard let screen = DisplayManager.shared.preferredScreen(settings: settings ?? .shared) else {
            hotZone = .zero
            return
        }
        let width = notchModel.currentWidth
        let height = notchModel.currentHeight
        guard width > 0, height > 0 else {
            hotZone = .zero
            return
        }
        // A few points of grace around the live notch makes entering/leaving forgiving without
        // claiming a meaningful slice of the menu bar.
        let grace: CGFloat = 6
        hotZone = CGRect(
            x: screen.frame.midX - width / 2 - grace,
            y: screen.frame.maxY - height - grace,
            width: width + grace * 2,
            height: height + grace
        )
    }

    private func targetFrame() -> NSRect? {
        guard let screen = DisplayManager.shared.preferredScreen(settings: settings ?? .shared) else { return nil }
        let size = notchModel.panelSize
        return NSRect(
            x: screen.frame.origin.x + (screen.frame.width - size.width) / 2,
            y: screen.frame.origin.y + screen.frame.height - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func applyFrame(_ frame: NSRect) {
        guard let window else { return }
        if let lastAppliedFrame, lastAppliedFrame.isNearlyEqual(to: frame) { return }
        lastAppliedFrame = frame
        // No AppKit frame tween: the SwiftUI NotchShape spring carries the visible motion, so the
        // borderless (transparent) panel only needs to bound it.
        window.setFrame(frame, display: false)
    }

    /// The panel is anchored at the top of the screen and the visible shape is a SwiftUI spring.
    /// Grow the bounding window instantly so the shape can expand into it, but defer shrinking
    /// until the collapse animation has settled so the window never clips the closing shape.
    private func schedulePanelFrame(animated: Bool) {
        pendingFrameTask?.cancel()
        guard let target = targetFrame() else { return }

        let current = lastAppliedFrame
        let isGrowing = current == nil
            || target.width > current!.width + 0.5
            || target.height > current!.height + 0.5

        if isGrowing || !animated || notchModel.reduceMotion {
            applyFrame(target)
            updatePanelVisibility()
            return
        }

        // Wait for the SwiftUI collapse spring to fully settle before shrinking the bounding window.
        // The resting window is now exactly the pill, so shrinking too early would clip the tail of the
        // closing shape. `closeAnimation` (response 0.32, damping 0.9) settles within ~0.5s.
        pendingFrameTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.applyFrame(target)
                self?.updatePanelVisibility()
            }
        }
    }

    /// Order the panel out entirely when there is nothing to show, so an empty notch never
    /// paints a black bar or captures hover on Macs without a hardware notch.
    private func updatePanelVisibility() {
        guard let window else { return }
        let shouldHide: Bool
        if settings?.enableAgentNotch == false {
            shouldHide = true
        } else if case .hidden = notchModel.state {
            shouldHide = true
        } else {
            shouldHide = false
        }

        if shouldHide {
            if window.isVisible { window.orderOut(nil) }
        } else if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    private func setupContent() {
        rebuildContent()
    }

    private func rebuildContent() {
        guard let agentStore, let hookStore else { return }

        let root = NotchRootView(
            notchModel: notchModel,
            agentStore: agentStore,
            hookStore: hookStore,
            onReveal: { [weak self] session in
                Task { @MainActor [weak self] in
                    await self?.reveal(session)
                }
            },
            onOpenSkillz: { [weak self] in
                self?.activateMainApp()
            },
            onRefresh: { [weak self] in
                self?.agentStore?.refresh()
                self?.refreshHookStatuses()
            },
            onInstallHooks: { [weak self] in
                self?.installHooks()
            }
        )

        let anyView = AnyView(root)
        if let hostingView {
            hostingView.rootView = anyView
        } else if let window {
            let container = NSView(frame: window.contentView?.bounds ?? window.frame)
            container.autoresizingMask = [.width, .height]

            let hosting = NSHostingView(rootView: anyView)
            hosting.frame = container.bounds
            hosting.autoresizingMask = [.width, .height]
            if #available(macOS 13.0, *) {
                hosting.sizingOptions = []
            }
            container.addSubview(hosting)
            window.contentView = container
            hostingView = hosting
        }
    }

    private func reveal(_ session: AgentSession) async {
        if await AgentSessionActivator.activateOwningApp(for: session) {
            return
        }

        if let cwd = session.cwd {
            let url = URL(fileURLWithPath: cwd, isDirectory: true)
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }

        activateMainApp()
    }

    private func activateMainApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NotchPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func installHooks() {
        hookStore?.installOrRepairAll()
        rebuildContent()
        NSApp.activate(ignoringOtherApps: true)
        SettingsWindowOpener.openAgentsTab()
    }
}

private extension NSRect {
    func isNearlyEqual(to other: NSRect) -> Bool {
        abs(origin.x - other.origin.x) < 0.5
            && abs(origin.y - other.origin.y) < 0.5
            && abs(size.width - other.size.width) < 0.5
            && abs(size.height - other.size.height) < 0.5
    }
}
