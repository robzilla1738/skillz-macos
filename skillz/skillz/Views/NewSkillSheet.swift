import SwiftUI

struct NewSkillSheet: View {
    @ObservedObject var store: CatalogStore
    @ObservedObject var document: EditorDocument
    @ObservedObject var settings: AppSettings

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var bodyText = ""
    @State private var selectedPlatforms: Set<AgentPlatform> = []
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var didConfigurePlatforms = false

    var body: some View {
        VStack(alignment: .leading, spacing: SkillzSpacing.lg) {
            Text("New Skill")
                .skillzHeadlineStyle()

            Text("Creates a skill folder with SKILL.md in each selected platform's skills directory.")
                .skillzBodySecondaryStyle()

            Form {
                TextField("Name", text: $name, prompt: Text("e.g. code-review"))
                    .font(SkillzTypography.body)

                TextField("Description", text: $description, axis: .vertical)
                    .font(SkillzTypography.body)
                    .lineLimit(2...4)

                Section("Platforms") {
                    ForEach(AgentPlatform.allCases) { platform in
                        let isDetected = store.detectedPlatforms.contains(platform)
                        Toggle(isOn: platformBinding(platform)) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: SkillzSpacing.sm) {
                                    PlatformBadge(platform: platform)
                                    Text(platform.userSkillsDirectory.path)
                                        .skillzCaptionStyle()
                                        .lineLimit(1)
                                }
                                if !isDetected {
                                    Text("Not detected on this Mac")
                                        .font(SkillzTypography.caption)
                                        .foregroundStyle(Color.skillzSectionLabel)
                                }
                            }
                        }
                        .font(SkillzTypography.body)
                    }
                }

                Section("Markdown") {
                    TextEditor(text: $bodyText)
                        .font(SkillzTypography.editor(size: settings.editorFontSize))
                        .foregroundStyle(Color.skillzEmphasis)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(SkillzTypography.caption)
                    .foregroundStyle(Color.skillzSectionLabel)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { createSkill() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isCreating || !canCreate)
            }
        }
        .padding(SkillzSpacing.xl)
        .frame(width: 520, height: 520)
        .background(Color.skillzCanvas)
        .onAppear {
            if !didConfigurePlatforms {
                selectedPlatforms = store.defaultNewSkillPlatforms
                didConfigurePlatforms = true
            }
            if bodyText.isEmpty {
                bodyText = bodyTemplate(for: name)
            }
        }
    }

    private func bodyTemplate(for skillName: String) -> String {
        let title = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = title.isEmpty ? "Skill Name" : title
        return "# \(heading)\n\nDescribe when to use this skill.\n"
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedPlatforms.isEmpty
    }

    private func platformBinding(_ platform: AgentPlatform) -> Binding<Bool> {
        Binding(
            get: { selectedPlatforms.contains(platform) },
            set: { enabled in
                if enabled {
                    selectedPlatforms.insert(platform)
                } else {
                    selectedPlatforms.remove(platform)
                }
            }
        )
    }

    private func createSkill() {
        isCreating = true
        errorMessage = nil
        document.pauseAutosave()
        do {
            let skillPath = try store.createSkill(
                name: name,
                description: description,
                body: bodyText,
                platforms: selectedPlatforms
            )
            document.load(url: skillPath)
            document.resumeAutosave()
            dismiss()
        } catch {
            errorMessage = FileAccessError.userMessage(for: error)
            document.resumeAutosave()
        }
        isCreating = false
    }
}
