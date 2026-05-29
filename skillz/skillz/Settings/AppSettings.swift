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

    var appearance: SkillzAppearance {
        get { SkillzAppearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    private init() {}
}
