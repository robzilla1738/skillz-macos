import SwiftUI

struct RenameSkillSheet: View {
    @ObservedObject var store: CatalogStore
    let skill: SkillItem
    @ObservedObject var document: EditorDocument

    @Environment(\.dismiss) private var dismiss

    @State private var folderName: String = ""
    @State private var errorMessage: String?
    @State private var isRenaming = false

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
            Text("Rename Skill")
                .skillzHeadlineStyle()

            Text("Renames the folder on disk and updates the name in SKILL.md.")
                .skillzBodySecondaryStyle()

            VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                Text("Platform")
                    .skillzDetailLabelStyle()
                PlatformBadge(platform: skill.platform)
            }

            VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                Text("Location")
                    .skillzDetailLabelStyle()
                Text(skill.rootDirectory.deletingLastPathComponent().path)
                    .skillzMonoStyle()
                    .lineLimit(2)
            }

            TextField("Folder name", text: $folderName)
                .font(SkillzTypography.body)

            if let errorMessage {
                Text(errorMessage)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Rename") { performRename() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isRenaming || folderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(SkillzSpacing.xl)
        .frame(width: 440)
        .background(Color.skillzCanvas)
        .onAppear {
            folderName = skill.rootDirectory.lastPathComponent
        }
    }

    private func performRename() {
        isRenaming = true
        errorMessage = nil
        document.pauseAutosave()
        do {
            try store.renameSelectedSkill(to: folderName)
            document.resumeAutosave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            document.resumeAutosave()
        }
        isRenaming = false
    }
}
