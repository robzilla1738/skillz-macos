import AppKit

@MainActor
final class NotchAppDelegate: NSObject, NSApplicationDelegate {
    var agentStore: AgentSessionStore?
    var hookStore: AgentHookStore?
    var settings: AppSettings?
    private var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        agentStore?.reopenWatching()
        if settings?.autoInstallAgentHooks == true {
            hookStore?.autoRepairIfNeeded()
        } else {
            hookStore?.refresh()
        }
        if settings?.enableAgentNotch == true {
            notchController?.reposition()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        agentStore?.stop()
    }

    func configure(agentStore: AgentSessionStore, hookStore: AgentHookStore, settings: AppSettings) {
        self.agentStore = agentStore
        self.hookStore = hookStore
        self.settings = settings
        agentStore.start()
        if settings.autoInstallAgentHooks {
            hookStore.autoInstallIfNeeded()
        } else {
            hookStore.refresh()
        }

        if settings.enableAgentNotch {
            showNotch()
        }
    }

    func setNotchEnabled(_ enabled: Bool) {
        if enabled {
            showNotch()
        } else {
            hideNotch()
        }
    }

    func showNotch() {
        guard let agentStore, let hookStore, let settings else { return }
        if notchController == nil {
            notchController = NotchWindowController(agentStore: agentStore, hookStore: hookStore, settings: settings)
        }
        notchController?.showNotch()
    }

    func hideNotch() {
        notchController?.hideNotch()
    }

    func openNotch() {
        notchController?.openNotch()
    }

    @objc private func screenParametersChanged() {
        notchController?.reposition()
    }
}
