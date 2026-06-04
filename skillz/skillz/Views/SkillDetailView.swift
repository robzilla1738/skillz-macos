import SwiftUI

struct SkillDetailView: View {
    @ObservedObject var store: CatalogStore
    let skill: SkillItem
    @ObservedObject var document: EditorDocument
    @ObservedObject var settings: AppSettings

    @State private var selectedFileID: String?
    @State private var paneMode: MarkdownPaneMode = .edit
    @State private var showSaveFailedAlert = false
    @State private var saveError: String?

    private var markdownFiles: [SkillMarkdownFile] {
        SkillScanner.markdownFiles(in: skill.rootDirectory)
    }

    private var showsFileTree: Bool {
        markdownFiles.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SkillzHairline()
            Group {
                if showsFileTree {
                    HSplitView {
                        fileTree
                            .frame(
                                minWidth: SkillzWindowMetrics.fileTreeMin,
                                idealWidth: SkillzWindowMetrics.fileTreeIdeal,
                                maxWidth: SkillzWindowMetrics.fileTreeMax
                            )
                        editorPane
                            .frame(minWidth: SkillzWindowMetrics.editorMin)
                            .layoutPriority(1)
                    }
                } else {
                    editorPane
                        .frame(minWidth: SkillzWindowMetrics.editorMin)
                }
            }
        }
        .skillzCanvas()
        .navigationTitle("")
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: SkillzSpacing.xs) {
                    Text(skill.displayName)
                        .skillzNavigationTitleStyle()
                        .lineLimit(1)

                    Button {
                        store.revealInFinder(skill.rootDirectory)
                    } label: {
                        Text(skill.rootDirectory.path)
                            .skillzCaptionStyle()
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal skill folder in Finder")
                    .accessibilityLabel("Reveal \(skill.displayName) folder in Finder")
                }
                Spacer()
            }
            .padding(.horizontal, SkillzSpacing.xl)
            .padding(.top, SkillzWindowMetrics.columnHeaderTopInset)
            .padding(.bottom, SkillzSpacing.md)
            .background(Color.skillzCanvas)
        }
        .alert("Save Failed", isPresented: $showSaveFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Could not save changes.")
        }
        .onAppear { loadSkillContent() }
        .onChange(of: skill.id) { _, _ in
            Task { await handleSkillChange() }
        }
    }

    private func loadSkillContent() {
        if let url = document.fileURL,
           url.path.hasPrefix(skill.rootDirectory.path),
           !document.isDirty {
            if selectedFileID == nil {
                selectedFileID = markdownFiles.first(where: { $0.url == url })?.id
                    ?? markdownFiles.first(where: \.isPrimary)?.id
            }
            return
        }
        selectInitialFile()
    }

    private func handleSkillChange() async {
        if document.isDirty {
            let saved = document.saveImmediately()
            if !saved {
                saveError = failureMessage(from: document.saveStatus)
                showSaveFailedAlert = true
                return
            }
        }
        selectInitialFile()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                Text(skill.description)
                    .skillzBodySecondaryStyle()
                    .lineLimit(3)

                HStack(spacing: SkillzSpacing.sm) {
                    PlatformBadge(platform: skill.platform)
                    if skill.isBuiltIn {
                        SkillzTag(text: "Built-in", style: .muted)
                    }
                    saveStatusChip
                }
            }
            Spacer()
        }
        .padding(.horizontal, SkillzSpacing.xl)
        .padding(.vertical, SkillzSpacing.lg)
        .background(Color.skillzCanvas)
    }

    @ViewBuilder
    private var saveStatusChip: some View {
        switch document.saveStatus {
        case .saved:
            if document.isDirty {
                SkillzTag(text: "Unsaved", style: .muted)
            } else {
                SkillzTag(text: "Saved", style: .muted)
            }
        case .saving:
            SkillzTag(text: "Saving…", style: .muted)
        case .failed:
            SkillzTag(text: "Save failed", style: .outline)
        }
    }

    private var fileTree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SkillzSpacing.sm) {
                SkillzSectionHeader(title: "Files")
                    .padding(.horizontal, SkillzSpacing.sm)
                    .padding(.top, SkillzSpacing.lg)

                ForEach(markdownFiles) { file in
                    Button {
                        Task { await attemptSwitch(to: file.id) }
                    } label: {
                        SkillzNavRow(
                            title: relativePath(for: file.url),
                            isSelected: selectedFileID == file.id
                        )
                    }
                    .buttonStyle(SkillzNavRowButtonStyle(isSelected: selectedFileID == file.id))
                }
            }
            .padding(.horizontal, SkillzSpacing.sm)
            .padding(.bottom, SkillzSpacing.lg)
        }
        .background(Color.skillzCanvas)
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: SkillzSpacing.md) {
                Picker("Markdown mode", selection: $paneMode) {
                    ForEach(MarkdownPaneMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                .accessibilityLabel("Markdown mode")

                Spacer()
            }
            .padding(.horizontal, SkillzSpacing.lg)
            .padding(.vertical, SkillzSpacing.sm)
            .background(Color.skillzCanvas)

            SkillzHairline()

            Group {
                switch paneMode {
                case .edit:
                    MarkdownEditorView(document: document, fontSize: settings.editorFontSize)
                case .preview:
                    MarkdownPreviewView(markdown: document.text, fontSize: settings.editorFontSize)
                        .id(settings.editorFontSize)
                }
            }
        }
    }

    private func relativePath(for url: URL) -> String {
        let root = skill.rootDirectory.path
        let full = url.path
        if full.hasPrefix(root + "/") {
            return String(full.dropFirst(root.count + 1))
        }
        return url.lastPathComponent
    }

    private func selectInitialFile() {
        let primary = markdownFiles.first(where: \.isPrimary) ?? markdownFiles.first
        if let primary {
            selectedFileID = primary.id
            document.load(url: primary.url)
        }
    }

    private func attemptSwitch(to fileID: String) async {
        guard let file = markdownFiles.first(where: { $0.id == fileID }) else { return }
        if document.isDirty {
            let saved = document.saveImmediately()
            if !saved {
                selectedFileID = document.fileURL?.path
                saveError = failureMessage(from: document.saveStatus)
                showSaveFailedAlert = true
                return
            }
        }
        document.load(url: file.url)
        selectedFileID = fileID
    }

    private func failureMessage(from status: SaveStatus) -> String {
        if case .failed(let message) = status { return message }
        return "Could not save changes."
    }
}

private enum MarkdownPaneMode: String, CaseIterable, Identifiable {
    case edit
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: return "Edit"
        case .preview: return "Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .edit: return "pencil"
        case .preview: return "doc.richtext"
        }
    }
}
