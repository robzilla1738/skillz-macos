import Foundation
import Combine

@MainActor
final class AgentHookStore: ObservableObject {
    @Published private(set) var statuses: [AgentHookStatus] = AgentHookInstaller.statusForAllPlatforms()
    @Published private(set) var isInstalling = false
    @Published private(set) var lastMessage: String?

    private var didAutoInstall = false
    private var lastAutoRepairAt: Date?

    func refresh() {
        statuses = AgentHookInstaller.statusForAllPlatforms()
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
        isInstalling = true
        statuses = AgentHookInstaller.autoInstallDetectedHooks()
        lastMessage = "Agent hooks checked."
        isInstalling = false
    }

    func installOrRepairAll() {
        isInstalling = true
        do {
            statuses = try AgentHookInstaller.installAllHooks()
            lastMessage = "Hooks installed successfully."
        } catch {
            statuses = AgentHookInstaller.statusForAllPlatforms()
            lastMessage = error.localizedDescription
        }
        isInstalling = false
    }

    func uninstallAll() {
        isInstalling = true
        statuses = AgentHookInstaller.uninstallAllHooks()
        lastMessage = "\(AppBrand.name) hooks removed."
        isInstalling = false
    }
}
