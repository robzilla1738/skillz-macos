import SwiftUI

struct SkillDetailsSheet: View {
    @ObservedObject var store: CatalogStore
    let skill: SkillItem
    @ObservedObject var document: EditorDocument

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var version: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canModify: Bool {
        SkillFileService.canModify(skill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
            Text("Skill Details")
                .skillzHeadlineStyle()

            if !canModify {
                Text(SkillFileService.modificationBlockedReason(skill))
                    .skillzBodySecondaryStyle()
            }

            Form {
                TextField("Name", text: $name)
                    .font(SkillzTypography.body)
                TextField("Description", text: $description, axis: .vertical)
                    .font(SkillzTypography.body)
                    .lineLimit(3...6)
                TextField("Version (optional)", text: $version)
                    .font(SkillzTypography.body)

                LabeledContent("Platform") {
                    PlatformBadge(platform: skill.platform)
                }
                LabeledContent("Path") {
                    Text(skill.rootDirectory.path)
                        .skillzMonoStyle()
                        .lineLimit(3)
                }
            }
            .formStyle(.grouped)
            .disabled(!canModify || isSaving)

            if let errorMessage {
                Text(errorMessage)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveMetadata() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canModify || isSaving)
            }
        }
        .padding(SkillzSpacing.xl)
        .frame(width: 440)
        .background(Color.skillzCanvas)
        .onAppear {
            name = skill.frontmatter.name ?? skill.rootDirectory.lastPathComponent
            description = skill.description == "No description" ? "" : skill.description
            version = skill.version ?? ""
        }
    }

    private func saveMetadata() {
        isSaving = true
        errorMessage = nil
        document.pauseAutosave()
        do {
            try store.updateSelectedSkillMetadata(
                name: name,
                description: description,
                version: version.isEmpty ? nil : version
            )
            if let updated = store.selectedItem?.skillItem,
               document.fileURL?.path == skill.skillPath.path || document.fileURL == nil {
                document.load(url: updated.skillPath)
            }
            document.resumeAutosave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            document.resumeAutosave()
        }
        isSaving = false
    }
}
