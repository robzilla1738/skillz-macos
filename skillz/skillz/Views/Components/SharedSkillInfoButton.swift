import SwiftUI

struct SharedSkillInfoButton: View {
    let primary: AgentPlatform
    let alsoAvailableOn: [AgentPlatform]

    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "info.circle")
                .font(SkillzTypography.caption)
                .foregroundStyle(Color.skillzMuted)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                Text("Shared skill file")
                    .skillzCaptionStrongStyle()
                Text(popoverMessage)
                    .skillzCaptionStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SkillzSpacing.md)
            .frame(maxWidth: 260)
        }
        .help("Shared across multiple harnesses")
        .accessibilityLabel("Shared skill information")
    }

    private var popoverMessage: String {
        let names = alsoAvailableOn.map(\.displayName).joined(separator: ", ")
        return "This file is shown under \(primary.displayName) and is also read by \(names). Edits apply to all of them."
    }
}
