import SwiftUI

struct SidebarNavRow: View {
    let title: String
    var symbolName: String? = nil
    var platform: AgentPlatform? = nil
    let count: Int
    let isSelected: Bool

    var body: some View {
        SkillzNavRow(
            title: title,
            symbolName: symbolName,
            platform: platform,
            trailing: "\(count)",
            isSelected: isSelected
        )
    }
}
