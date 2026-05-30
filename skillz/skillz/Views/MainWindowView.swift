import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject var store: CatalogStore
    @ObservedObject var document: EditorDocument
    @ObservedObject var settings: AppSettings

    @State private var showDetailsSheet = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showNewSkillSheet = false
    @State private var showOnboarding = false
    @State private var dismissedSaveErrorMessage: String?

    private var selectedSkill: SkillItem? {
        store.selectedItem?.skillItem
    }

    private var isSkillSelected: Bool {
        selectedSkill != nil
    }

    private var canModifySkill: Bool {
        guard let skill = selectedSkill else { return false }
        return SkillFileService.canModify(skill)
    }

    private var canSaveCurrentSkill: Bool {
        isSkillSelected && document.fileURL != nil && document.isDirty
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            NavigationSplitView {
                SidebarView(store: store)
                    .navigationSplitViewColumnWidth(
                        min: SkillzWindowMetrics.sidebarMin,
                        ideal: SkillzWindowMetrics.sidebarIdeal,
                        max: SkillzWindowMetrics.sidebarMax
                    )
            } content: {
                ItemListView(store: store)
                    .navigationSplitViewColumnWidth(
                        min: SkillzWindowMetrics.listMin,
                        ideal: SkillzWindowMetrics.listIdeal,
                        max: SkillzWindowMetrics.listMax
                    )
            } detail: {
                DetailContainerView(store: store, document: document, settings: settings)
                    .navigationSplitViewColumnWidth(
                        min: SkillzWindowMetrics.detailMin,
                        ideal: SkillzWindowMetrics.detailIdeal
                    )
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar(removing: .sidebarToggle)
        }
        .frame(
            minWidth: SkillzWindowMetrics.minWidth,
            minHeight: SkillzWindowMetrics.minHeight
        )
        .skillzCanvas()
        .background {
            SkillzWindowChromeCleaner()
                .frame(width: 0, height: 0)
        }
        .sheet(isPresented: $showDetailsSheet) {
            if let skill = selectedSkill {
                SkillDetailsSheet(store: store, skill: skill, document: document)
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            if let skill = selectedSkill {
                RenameSkillSheet(store: store, skill: skill, document: document)
            }
        }
        .sheet(isPresented: $showNewSkillSheet) {
            NewSkillSheet(store: store, document: document, settings: settings)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                settings: settings,
                onComplete: { showOnboarding = false },
                onOpenSettings: {
                    showOnboarding = false
                    SettingsWindowOpener.openAgentsTab()
                }
            )
            .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Delete \"\(selectedSkill?.displayName ?? "skill")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Skill", role: .destructive) {
                deleteSelectedSkill()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let skill = selectedSkill {
                Text("This permanently deletes the skill folder at:\n\(skill.rootDirectory.path)")
            }
        }
        .onAppear {
            if store.snapshot.allItems.isEmpty {
                store.refresh()
            }
            if !settings.hasCompletedOnboarding {
                showOnboarding = true
            }
            store.startWatching()
        }
        .onDisappear {
            store.stopWatching()
        }
        .onChange(of: settings.hideBuiltInCursorSkills) { _, _ in store.refresh() }
        .onChange(of: settings.hideSystemCodexSkills) { _, _ in store.refresh() }
        .onChange(of: store.showInspector) { _, newValue in
            settings.showInspector = newValue
        }
        .onChange(of: store.selectedItemID) { _, _ in
            showDetailsSheet = false
            showRenameSheet = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzEditDetails)) { _ in
            editSelectedSkillDetails()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzRenameSkill)) { _ in
            renameSelectedSkill()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzDeleteSkill)) { _ in
            confirmDeleteSelectedSkill()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzNewSkill)) { _ in
            showNewSkillSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzShowOnboarding)) { _ in
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshOnBecomeActive()
        }
        .overlay(alignment: .bottom) {
            if let message = activeErrorMessage {
                SkillzErrorBanner(message: message) {
                    dismissActiveError()
                }
            }
        }
        .onChange(of: document.saveStatus) { _, newStatus in
            if case .saved = newStatus {
                dismissedSaveErrorMessage = nil
            }
        }
    }

    private var activeErrorMessage: String? {
        if let operationError = store.lastOperationError {
            return operationError
        }
        if case .failed(let message) = document.saveStatus {
            if message == dismissedSaveErrorMessage { return nil }
            return message
        }
        return nil
    }

    private func dismissActiveError() {
        store.clearLastOperationError()
        if case .failed(let message) = document.saveStatus {
            dismissedSaveErrorMessage = message
        }
    }

    private var topBar: some View {
        HStack(spacing: SkillzSpacing.md) {
            SkillzGlassToolbarGroup {
                Button("New Skill") {
                    showNewSkillSheet = true
                }
                .buttonStyle(SkillzGlassToolbarButtonStyle())
            }
            .help("Create a new skill (⌘N)")

            SkillzGlassToolbarGroup {
                Button("Refresh") {
                    store.refresh()
                }
                .buttonStyle(SkillzGlassToolbarButtonStyle())
            }
            .help("Refresh catalog (⌘R)")

            SkillzGlassIconToolbarGroup {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: SkillzPillMetrics.height, height: SkillzPillMetrics.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SkillzGlassIconToolbarButtonStyle())
            }
            .help("Hide sidebar")

            Spacer(minLength: SkillzSpacing.xl)

            if isSkillSelected {
                SkillzGlassToolbarGroup {
                    HStack(spacing: 0) {
                        Button("Details") {
                            editSelectedSkillDetails()
                        }
                        .buttonStyle(SkillzGlassToolbarButtonStyle())
                        .help(canModifySkill ? "Edit skill metadata" : "View skill metadata")

                        Button("Rename") {
                            renameSelectedSkill()
                        }
                        .buttonStyle(SkillzGlassToolbarButtonStyle())
                        .help("Rename skill folder")
                        .disabled(!canModifySkill)

                        Button("Delete") {
                            confirmDeleteSelectedSkill()
                        }
                        .buttonStyle(SkillzGlassToolbarButtonStyle())
                        .help("Delete skill folder")
                        .disabled(!canModifySkill)

                        Button("Save") {
                            saveCurrentSkill()
                        }
                        .buttonStyle(SkillzGlassToolbarButtonStyle(prominent: document.isDirty))
                        .help("Save now (⌘S)")
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!canSaveCurrentSkill)
                    }
                }
            }

            SkillzGlassSearchField(
                text: $store.searchText,
                prompt: "Search skills, MCPs, plugins"
            )
            .frame(width: 440)
        }
        .padding(.leading, SkillzWindowMetrics.trafficLightReservedWidth)
        .padding(.trailing, SkillzSpacing.lg)
        .padding(.vertical, SkillzSpacing.sm)
        .background(Color.skillzCanvas)
        .overlay(alignment: .bottom) {
            SkillzHairline()
        }
    }

    func saveCurrentSkill() {
        guard isSkillSelected else {
            store.lastOperationError = "Select a skill before saving."
            return
        }
        guard document.fileURL != nil else {
            store.lastOperationError = "No editable skill file is loaded."
            return
        }
        _ = document.saveImmediately()
    }

    func toggleSidebar() {
        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    }

    func editSelectedSkillDetails() {
        guard isSkillSelected else {
            store.lastOperationError = "Select a skill before editing details."
            return
        }
        showDetailsSheet = true
    }

    func renameSelectedSkill() {
        guard let skill = selectedSkill else {
            store.lastOperationError = "Select a skill before renaming."
            return
        }
        guard SkillFileService.canModify(skill) else {
            store.lastOperationError = SkillFileService.modificationBlockedReason(skill)
            return
        }
        showRenameSheet = true
    }

    func confirmDeleteSelectedSkill() {
        guard let skill = selectedSkill else {
            store.lastOperationError = "Select a skill before deleting."
            return
        }
        guard SkillFileService.canModify(skill) else {
            store.lastOperationError = SkillFileService.modificationBlockedReason(skill)
            return
        }
        showDeleteConfirmation = true
    }

    func deleteSelectedSkill() {
        document.pauseAutosave()
        do {
            try store.deleteSelectedSkill()
            document.resumeAutosave()
        } catch {
            store.lastOperationError = FileAccessError.userMessage(for: error)
            document.resumeAutosave()
        }
    }

    func revealSelection() {
        guard let item = store.selectedItem else { return }
        switch item {
        case .skill(let skill):
            store.revealInFinder(document.fileURL ?? skill.skillPath)
        case .mcp(let mcp):
            store.revealInFinder(mcp.configFileURL)
        case .plugin(let plugin):
            if let path = plugin.installPath ?? plugin.metadataPath {
                store.revealInFinder(path)
            }
        }
    }
}
