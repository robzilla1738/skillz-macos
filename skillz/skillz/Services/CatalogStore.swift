import Foundation
import AppKit
import Combine

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var snapshot = CatalogSnapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var sourceStatuses: [PlatformSourceStatus] = []
    @Published var selectedSection: CatalogSection = .all
    @Published var selectedPlatformFilter: AgentPlatform?
    @Published var searchText = ""
    @Published var selectedItemID: String?
    @Published var showInspector: Bool
    @Published var lastOperationError: String?

    private var fsWatcher: FSEventWatcher?
    private let settings: AppSettings

    init() {
        self.settings = .shared
        self.showInspector = settings.showInspector
        self.sourceStatuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
    }

    init(settings: AppSettings) {
        self.settings = settings
        self.showInspector = settings.showInspector
        self.sourceStatuses = PlatformSourceDetector.detect(snapshot: CatalogSnapshot())
    }

    var filteredItems: [CatalogItem] {
        CatalogFilter.sorted(
            CatalogFilter.items(
                in: snapshot,
                section: selectedSection,
                platform: selectedPlatformFilter,
                searchText: searchText
            )
        )
    }

    var selectedItem: CatalogItem? {
        guard let id = selectedItemID else { return nil }
        return snapshot.allItems.first { $0.id == id }
    }

    var detectedPlatforms: Set<AgentPlatform> {
        PlatformSourceDetector.detectedPlatforms(from: sourceStatuses)
    }

    var defaultNewSkillPlatforms: Set<AgentPlatform> {
        PlatformSourceDetector.defaultNewSkillPlatforms(from: sourceStatuses)
    }

    var hasAnyCatalogItems: Bool {
        !snapshot.allItems.isEmpty
    }

    /// Items visible for a library section, honoring the active platform filter and search.
    func count(for section: CatalogSection) -> Int {
        CatalogFilter.items(
            in: snapshot,
            section: section,
            platform: selectedPlatformFilter,
            searchText: searchText
        ).count
    }

    /// Items visible for a platform, honoring the active library section and search.
    func count(for platform: AgentPlatform) -> Int {
        CatalogFilter.items(
            in: snapshot,
            section: selectedSection,
            platform: platform,
            searchText: searchText
        ).count
    }

    /// Items for the current library section across all platforms (search applied).
    func countAllPlatforms() -> Int {
        CatalogFilter.items(
            in: snapshot,
            section: selectedSection,
            platform: nil,
            searchText: searchText
        ).count
    }

    func relatedPlatforms(for skillName: String, excluding item: SkillItem) -> [AgentPlatform] {
        if !item.alsoAvailableOn.isEmpty {
            return item.alsoAvailableOn
        }
        return snapshot.skills
            .filter { $0.displayName == skillName && $0.id != item.id }
            .map(\.platform)
    }

    func refresh(silent: Bool = false) {
        if !silent {
            isLoading = true
        }
        let hideBuiltIn = settings.hideBuiltInCursorSkills
        let hideSystem = settings.hideSystemCodexSkills
        let preserveID = selectedItemID

        Task.detached(priority: .userInitiated) {
            let newSnapshot = DiscoveryEngine.discover(
                hideBuiltInCursor: hideBuiltIn,
                hideSystemCodex: hideSystem
            )
            await MainActor.run {
                self.snapshot = newSnapshot
                self.sourceStatuses = PlatformSourceDetector.detect(snapshot: newSnapshot)
                self.lastRefreshedAt = Date()
                if !silent {
                    self.isLoading = false
                }
                if let preserveID, newSnapshot.allItems.contains(where: { $0.id == preserveID }) {
                    self.selectedItemID = preserveID
                } else if let first = self.filteredItems.first?.id {
                    self.selectedItemID = first
                } else {
                    self.selectedItemID = nil
                }
            }
        }
    }

    func reloadCatalog(selecting preferredID: String?) {
        let hideBuiltIn = settings.hideBuiltInCursorSkills
        let hideSystem = settings.hideSystemCodexSkills
        snapshot = DiscoveryEngine.discover(
            hideBuiltInCursor: hideBuiltIn,
            hideSystemCodex: hideSystem
        )
        sourceStatuses = PlatformSourceDetector.detect(snapshot: snapshot)
        lastRefreshedAt = Date()
        if let preferredID, snapshot.allItems.contains(where: { $0.id == preferredID }) {
            selectedItemID = preferredID
        } else if let first = filteredItems.first?.id {
            selectedItemID = first
        } else {
            selectedItemID = nil
        }
    }

    func clearLastOperationError() {
        lastOperationError = nil
    }

    func refreshOnBecomeActive() {
        startWatching()
        refresh(silent: true)
    }

    func startWatching() {
        let paths = PlatformSkillPaths.watchDirectories
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        fsWatcher?.stop()
        fsWatcher = FSEventWatcher(paths: paths) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
        fsWatcher?.start()
    }

    func stopWatching() {
        fsWatcher?.stop()
        fsWatcher = nil
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    func openInCursor(_ url: URL) {
        let cursorApp = URL(fileURLWithPath: "/Applications/Cursor.app")
        guard FileManager.default.fileExists(atPath: cursorApp.path) else {
            openInDefaultApp(url)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: cursorApp, configuration: config)
    }

    func canModifySelectedSkill() -> Bool {
        guard let skill = selectedItem?.skillItem else { return false }
        return SkillFileService.canModify(skill)
    }

    func renameSelectedSkill(to newFolderName: String) throws {
        guard let skill = selectedItem?.skillItem else { return }
        let newRoot = try SkillFileService.renameSkill(skill, newFolderName: newFolderName)
        let newPath = newRoot.appendingPathComponent("SKILL.md")
        let newID = SkillItem.makeID(platform: skill.platform, path: newPath)
        reloadCatalog(selecting: newID)
        lastOperationError = nil
    }

    func deleteSelectedSkill() throws {
        guard let skill = selectedItem?.skillItem else { return }
        try SkillFileService.deleteSkill(skill)
        reloadCatalog(selecting: nil)
        lastOperationError = nil
    }

    func updateSelectedSkillMetadata(name: String, description: String, version: String?) throws {
        guard let skill = selectedItem?.skillItem else { return }
        try SkillFileService.updateMetadata(skill, name: name, description: description, version: version)
        reloadCatalog(selecting: skill.id)
        lastOperationError = nil
    }

    @discardableResult
    func createSkill(
        name: String,
        description: String,
        body: String,
        platforms: Set<AgentPlatform>
    ) throws -> URL {
        let paths = try SkillFileService.createSkill(
            name: name,
            description: description,
            body: body,
            platforms: platforms
        )
        guard let firstPath = paths.first else {
            throw SkillFileError.validation("No skill was created.")
        }
        selectedSection = .skills
        let newID = SkillItem.makeID(platform: PlatformSkillPaths.platformFor(path: firstPath), path: firstPath)
        reloadCatalog(selecting: newID)
        lastOperationError = nil
        return firstPath
    }
}
