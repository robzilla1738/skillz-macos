import SwiftUI
import AppKit

struct SkillzStartupConfigurator: View {
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    @ObservedObject var settings: AppSettings

    @State private var didConfigure = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                guard !didConfigure else { return }
                didConfigure = true
                guard !SkillzRuntime.isRunningAppHostedTests else { return }
                configureAgentMonitoring()
                // Make sure the Quick Look extension always finds per-type
                // settings in the shared app group.
                PreviewSettingsStore().seedMissingDefaults()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                guard didConfigure, !SkillzRuntime.isRunningAppHostedTests else { return }
                agentStore.reopenWatching()
                refreshHooksForCurrentSettings()
            }
            .onReceive(NotificationCenter.default.publisher(for: .skillzOnboardingCompleted)) { _ in
                guard didConfigure, !SkillzRuntime.isRunningAppHostedTests else { return }
                refreshHooksForCurrentSettings(initial: true)
                agentStore.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                agentStore.stop()
            }
    }

    private func configureAgentMonitoring() {
        agentStore.start()
        refreshHooksForCurrentSettings(initial: true)
    }

    private func refreshHooksForCurrentSettings(initial: Bool = false) {
        switch SkillzStartupHookPolicy.action(
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            autoInstallAgentHooks: settings.autoInstallAgentHooks,
            initial: initial
        ) {
        case .refreshOnly:
            hookStore.refresh()
        case .autoInstall:
            hookStore.autoInstallIfNeeded()
        case .autoRepair:
            hookStore.autoRepairIfNeeded()
        }
    }
}

enum SkillzStartupHookAction: Equatable {
    case refreshOnly
    case autoInstall
    case autoRepair
}

enum SkillzStartupHookPolicy {
    static func action(
        hasCompletedOnboarding: Bool,
        autoInstallAgentHooks: Bool,
        initial: Bool
    ) -> SkillzStartupHookAction {
        guard hasCompletedOnboarding, autoInstallAgentHooks else {
            return .refreshOnly
        }
        return initial ? .autoInstall : .autoRepair
    }
}

enum SkillzRuntime {
    static var isRunningAppHostedTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.contains(".xctest") }
    }
}
