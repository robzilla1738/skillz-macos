import SwiftUI

extension Notification.Name {
    /// Posted to ask an already-open Settings window to change tab.
    static let skillzOpenSettingsTab = Notification.Name("SkillzOpenSettingsTab")
}

/// A Settings tab an external caller can request.
enum SettingsDestination {
    case agents
}

/// Opens the Settings window and selects a specific tab.
///
/// Lives in `Services/` (not the dormant `Notch/` folder) because the live
/// menu-bar and onboarding paths depend on it.
///
/// Selection is delivered two ways so it is robust regardless of window state:
/// a freshly-created `SettingsView` consumes `pendingDestination` on first appear,
/// and an already-open one receives the notification.
@MainActor
enum SettingsWindowOpener {
    private static var pendingDestination: SettingsDestination?

    /// Returns and clears the tab a freshly-opened Settings window should select.
    static func consumePendingDestination() -> SettingsDestination? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    static func open(_ destination: SettingsDestination) {
        pendingDestination = destination
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NotificationCenter.default.post(name: .skillzOpenSettingsTab, object: destination)
    }

    static func openAgentsTab() {
        open(.agents)
    }
}
