import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject var store: CatalogStore
    @ObservedObject var document: EditorDocument
    @ObservedObject var settings: AppSettings
    @ObservedObject private var toasts = ToastCenter.shared

    @State private var showDetailsSheet = false
    @State private var showRenameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showNewSkillSheet = false
    @State private var showOnboarding = false
    @State private var showQuickLookSettings = false
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
                .zIndex(1)
            if showQuickLookSettings {
                QuickLookSettingsPage {
                    showQuickLookSettings = false
                }
            } else {
                NavigationSplitView {
                    SidebarView(store: store)
                        .navigationSplitViewColumnWidth(
                            min: SkillzWindowMetrics.sidebarMin,
                            ideal: SkillzWindowMetrics.sidebarIdeal,
                            max: SkillzWindowMetrics.sidebarMax
                        )
                        .toolbar(removing: .sidebarToggle)
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
                .ignoresSafeArea(.container, edges: .top)
                .padding(.top, -SkillzWindowMetrics.sidebarTopInsetPull)
            }
        }
        .frame(
            minWidth: SkillzWindowMetrics.minWidth,
            minHeight: SkillzWindowMetrics.minHeight
        )
        .skillzCanvas()
        .ignoresSafeArea(.container, edges: .top)
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
                store: store,
                onComplete: {
                    showOnboarding = false
                    NotificationCenter.default.post(name: .skillzOnboardingCompleted, object: nil)
                },
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
                store.refresh(preferredID: settings.lastSelectedItemID)
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
        .onChange(of: store.sortOrder) { _, newValue in
            settings.catalogSortOrder = newValue
        }
        .onChange(of: store.searchSkillBodies) { _, newValue in
            settings.searchSkillBodies = newValue
        }
        .onChange(of: store.selectedSection) { _, newValue in
            settings.lastSelectedSection = newValue
        }
        .onChange(of: store.selectedPlatformFilter) { _, newValue in
            settings.lastSelectedPlatform = newValue
        }
        .onChange(of: store.selectedItemID) { _, newValue in
            settings.lastSelectedItemID = newValue
            showDetailsSheet = false
            showRenameSheet = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzEditDetails)) { _ in
            editSelectedSkillDetails()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzRenameSkill)) { _ in
            renameSelectedSkill()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillzDuplicateSkill)) { _ in
            duplicateSelectedSkill()
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
        .overlay(alignment: .bottom) {
            if activeErrorMessage == nil, let toast = toasts.current {
                SkillzToast(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toasts.current)
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

    private var toolbarLeadingInset: CGFloat {
        SkillzWindowMetrics.trafficLightReservedWidth
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: SkillzSpacing.md) {
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
                    .accessibilityLabel("Toggle Sidebar")
                }
                .help("Toggle sidebar (⌃⌘S)")

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

                SkillzGlassToolbarGroup {
                    Button("Quick Look") {
                        showQuickLookSettings.toggle()
                    }
                    .buttonStyle(SkillzGlassToolbarButtonStyle(prominent: showQuickLookSettings))
                }
                .help("Theme Finder Quick Look previews per file type")
            }
            .padding(.leading, toolbarLeadingInset)

            Spacer(minLength: SkillzSpacing.xl)

            HStack(spacing: SkillzSpacing.md) {
                if isSkillSelected && !showQuickLookSettings {
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
                        }
                    }

                    // The primary commit lives in its own group, away from the destructive Delete.
                    SkillzGlassToolbarGroup {
                        Button("Save") {
                            saveCurrentSkill()
                        }
                        .buttonStyle(SkillzGlassToolbarButtonStyle(prominent: document.isDirty))
                        .help("Save now (⌘S)")
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!canSaveCurrentSkill)
                    }
                }

                if !showQuickLookSettings {
                    SkillzGlassSearchField(
                        text: $store.searchText,
                        prompt: "Search skills, MCPs, plugins"
                    )
                    .frame(width: 320)
                }
            }
        }
        .padding(.trailing, SkillzSpacing.lg)
        .padding(.top, SkillzSpacing.md)
        .padding(.bottom, SkillzSpacing.sm)
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

    func duplicateSelectedSkill() {
        guard let skill = selectedSkill else {
            store.lastOperationError = "Select a skill before duplicating."
            return
        }
        guard SkillFileService.canModify(skill) else {
            store.lastOperationError = SkillFileService.modificationBlockedReason(skill)
            return
        }
        document.pauseAutosave()
        defer { document.resumeAutosave() }
        do {
            try store.duplicateSelectedSkill()
        } catch {
            store.lastOperationError = FileAccessError.userMessage(for: error)
        }
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
}
