import SwiftUI

struct SidebarNavRow: View {
    let title: String
    let count: Int
    let isSelected: Bool

    var body: some View {
        SkillzNavRow(
            title: title,
            trailing: "\(count)",
            isSelected: isSelected
        )
    }
}
