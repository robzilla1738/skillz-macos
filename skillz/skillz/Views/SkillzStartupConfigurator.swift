import SwiftUI

struct SkillzStartupConfigurator: View {
    @ObservedObject var agentStore: AgentSessionStore
    @ObservedObject var hookStore: AgentHookStore
    @ObservedObject var settings: AppSettings
    var notchDelegate: NotchAppDelegate

    @State private var didConfigure = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                guard !didConfigure else { return }
                didConfigure = true
                notchDelegate.configure(agentStore: agentStore, hookStore: hookStore, settings: settings)
            }
    }
}
