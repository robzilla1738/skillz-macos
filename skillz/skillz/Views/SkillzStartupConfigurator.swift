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
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                guard didConfigure, !SkillzRuntime.isRunningAppHostedTests else { return }
                agentStore.reopenWatching()
                refreshHooksForCurrentSettings()
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
        if settings.autoInstallAgentHooks {
            if initial {
                hookStore.autoInstallIfNeeded()
            } else {
                hookStore.autoRepairIfNeeded()
            }
        } else {
            hookStore.refresh()
        }
    }
}

enum SkillzRuntime {
    static var isRunningAppHostedTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains { $0.contains(".xctest") }
    }
}
