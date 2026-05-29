import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class NotchWindowController: NSWindowController {
    private let notchModel = NotchViewModel()
    private weak var agentStore: AgentSessionStore?
    private weak var hookStore: AgentHookStore?
    private weak var settings: AppSettings?
    private var hostingView: NSHostingView<AnyView>?

    convenience init(agentStore: AgentSessionStore, hookStore: AgentHookStore, settings: AppSettings) {
        let screen = DisplayManager.shared.preferredScreen(settings: settings) ?? NSScreen.main ?? NSScreen.screens[0]
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 448, height: 300))
        self.init(window: panel)
        self.agentStore = agentStore
        self.hookStore = hookStore
        self.settings = settings
        notchModel.updateGeometry(for: screen)
        notchModel.onLayoutChange = { [weak self] in
            self?.applyPanelFrame(animated: true)
        }
        setupContent()
        applyPanelFrame(animated: false)
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
        notchModel.state = .closed
        window?.orderFrontRegardless()
        reposition()
    }

    func hideNotch() {
        notchModel.hide()
        window?.orderOut(nil)
    }

    func openNotch() {
        notchModel.open(pinned: true)
        window?.orderFrontRegardless()
    }

    func reposition() {
        guard let window, let screen = DisplayManager.shared.preferredScreen(settings: settings ?? .shared) else {
            return
        }
        notchModel.updateGeometry(for: screen)
        applyPanelFrame(animated: false)
        DisplayManager.shared.position(panel: window, on: screen, geometry: notchModel.geometry)
    }

    private func applyPanelFrame(animated: Bool) {
        guard let window, let screen = DisplayManager.shared.preferredScreen(settings: settings ?? .shared) else {
            return
        }

        let size = notchModel.panelSize
        let frame = NSRect(
            x: screen.frame.origin.x + (screen.frame.width - size.width) / 2,
            y: screen.frame.origin.y + screen.frame.height - size.height,
            width: size.width,
            height: size.height
        )

        let shouldAnimate = animated && !notchModel.reduceMotion
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.38
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
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
                self?.reveal(session)
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
            let hosting = NSHostingView(rootView: anyView)
            hosting.frame = window.contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            hostingView = hosting
        }
    }

    private func reveal(_ session: AgentSession) {
        if AgentSessionActivator.activateOwningApp(for: session) {
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

enum SettingsWindowOpener {
    static func openAgentsTab() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
