import AppKit
import Combine
import Foundation

/// Reports whether the bundled Quick Look extension is registered with
/// PlugInKit, and exposes the System Settings / `qlmanage -r` escape hatches
/// surfaced in the Quick Look settings tab.
@MainActor
final class QuickLookExtensionStatus: ObservableObject {
    enum State: Equatable {
        case unknown
        case checking
        case enabled
        case disabled
        case notRegistered

        var label: String {
            switch self {
            case .unknown: return "Unknown"
            case .checking: return "Checking…"
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .notRegistered: return "Not registered"
            }
        }
    }

    nonisolated static let extensionBundleID = "robertcourson.skillz.quicklook"

    @Published private(set) var state: State = .unknown

    func refresh() {
        guard state != .checking else { return }
        state = .checking
        Task.detached(priority: .utility) {
            let result = ShellProcessRunner.run(
                executablePath: "/usr/bin/pluginkit",
                arguments: ["-m", "-i", Self.extensionBundleID],
                timeout: 2.0
            )
            let parsed = Self.parse(output: result?.standardOutput ?? "")
            await MainActor.run { [weak self] in
                self?.state = parsed
            }
        }
    }

    /// pluginkit match lines start with an election marker: `+` elected,
    /// `-` ignored/disabled, `!` disallowed by policy.
    nonisolated static func parse(output: String) -> State {
        let lines = output
            .split(separator: "\n")
            .filter { $0.contains(extensionBundleID) }
        guard let first = lines.first?.trimmingCharacters(in: .whitespaces), !first.isEmpty else {
            return .notRegistered
        }
        switch first.first {
        case "-", "!": return .disabled
        default: return .enabled
        }
    }

    /// System Settings → General → Login Items & Extensions, where the Quick
    /// Look extension list lives on macOS 14+.
    func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.ExtensionsPreferences",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    /// `qlmanage -r` resets the Quick Look server so theme changes show up
    /// without waiting for cached previews to expire.
    func resetQuickLook() {
        Task.detached(priority: .utility) {
            let result = ShellProcessRunner.run(
                executablePath: "/usr/bin/qlmanage",
                arguments: ["-r"],
                timeout: 4.0
            )
            await MainActor.run {
                if result?.terminationStatus == 0 {
                    ToastCenter.shared.show("Quick Look reset", kind: .success)
                } else {
                    ToastCenter.shared.show("Quick Look reset may not have completed", kind: .info)
                }
            }
        }
    }
}
