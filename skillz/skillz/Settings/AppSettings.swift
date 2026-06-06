import Foundation
import SwiftUI
import Combine

enum SkillzAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum EditorViewMode: String, CaseIterable, Identifiable {
    case source
    case rich

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .source: return "Source"
        case .rich: return "Rich Text"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("hideBuiltInCursorSkills") var hideBuiltInCursorSkills = false
    @AppStorage("hideSystemCodexSkills") var hideSystemCodexSkills = true
    @AppStorage("editorFontSize") var editorFontSize = 14.0
    @AppStorage("showInspector") var showInspector = false
    @AppStorage("skillzAppearance") var appearanceRaw = SkillzAppearance.system.rawValue
    @AppStorage("enableAgentNotch") var enableAgentNotch = true
    @AppStorage("agentNotchDisplayUUID") var agentNotchDisplayUUID: String?
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("showAgentCountInMenuBar") var showAgentCountInMenuBar = true
    @AppStorage("autoInstallAgentHooks") var autoInstallAgentHooks = true

    // Catalog list ordering & search
    @AppStorage("catalogSortOrderRaw") var catalogSortOrderRaw = CatalogSortOrder.name.rawValue
    @AppStorage("searchSkillBodies") var searchSkillBodies = false

    // Restored-on-launch library state
    @AppStorage("lastSelectedItemID") var lastSelectedItemID: String?
    @AppStorage("lastSelectedSectionRaw") var lastSelectedSectionRaw = CatalogSection.all.rawValue
    @AppStorage("lastSelectedPlatformRaw") var lastSelectedPlatformRaw: String?

    // Editor
    @AppStorage("editorLineWrap") var editorLineWrap = true
    @AppStorage("editorViewModeRaw") var editorViewModeRaw = EditorViewMode.source.rawValue

    var appearance: SkillzAppearance {
        get { SkillzAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var catalogSortOrder: CatalogSortOrder {
        get { CatalogSortOrder(rawValue: catalogSortOrderRaw) ?? .name }
        set { catalogSortOrderRaw = newValue.rawValue }
    }

    var lastSelectedSection: CatalogSection {
        get { CatalogSection(rawValue: lastSelectedSectionRaw) ?? .all }
        set { lastSelectedSectionRaw = newValue.rawValue }
    }

    var lastSelectedPlatform: AgentPlatform? {
        get { lastSelectedPlatformRaw.flatMap { AgentPlatform(rawValue: $0) } }
        set { lastSelectedPlatformRaw = newValue?.rawValue }
    }

    var editorViewMode: EditorViewMode {
        get { EditorViewMode(rawValue: editorViewModeRaw) ?? .source }
        set { editorViewModeRaw = newValue.rawValue }
    }

    private init() {}
}
