import SwiftUI

struct AgentStatusChip: View {
    let state: AgentActivityState

    var body: some View {
        NotchStatusPill(state: state)
    }
}
