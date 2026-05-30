import Foundation
import Combine

@MainActor
final class AgentHookStore: ObservableObject {
    @Published private(set) var statuses: [AgentHookStatus] = AgentHookInstaller.statusForAllPlatforms()
    @Published private(set) var isInstalling = false
    @Published private(set) var lastMessage: String?

    private var didAutoInstall = false
    private var lastAutoRepairAt: Date?
    private var statusTask: Task<Void, Never>?

    func refresh() {
        runStatusTask(markInstalling: false) {
            (AgentHookInstaller.statusForAllPlatforms(), nil)
        }
    }

    func autoInstallIfNeeded() {
        guard !didAutoInstall else { return }
        didAutoInstall = true
        autoRepairIfNeeded(force: true)
    }

    func autoRepairIfNeeded(force: Bool = false) {
        if !force,
           let lastAutoRepairAt,
           Date().timeIntervalSince(lastAutoRepairAt) < 60 {
            refresh()
            return
        }
        lastAutoRepairAt = Date()
        runStatusTask(markInstalling: true) {
            (AgentHookInstaller.autoInstallDetectedHooks(), "Agent hooks checked.")
        }
    }

    func installOrRepairAll() {
        runStatusTask(markInstalling: true) {
            do {
                return (try AgentHookInstaller.installAllHooks(), "Hooks installed successfully.")
            } catch {
                return (AgentHookInstaller.statusForAllPlatforms(), error.localizedDescription)
            }
        }
    }

    func uninstallAll() {
        runStatusTask(markInstalling: true) {
            (AgentHookInstaller.uninstallAllHooks(), "\(AppBrand.name) hooks removed.")
        }
    }

    private func runStatusTask(
        markInstalling: Bool,
        work: @escaping @Sendable () -> ([AgentHookStatus], String?)
    ) {
        if isInstalling && !markInstalling {
            return
        }
        statusTask?.cancel()
        if markInstalling {
            isInstalling = true
        }

        statusTask = Task { [weak self] in
            let result = await Task.detached(priority: markInstalling ? .userInitiated : .utility) {
                work()
            }.value

            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.statuses = result.0
                if let message = result.1 {
                    self.lastMessage = message
                }
                if markInstalling {
                    self.isInstalling = false
                }
                self.statusTask = nil
            }
        }
    }
}
