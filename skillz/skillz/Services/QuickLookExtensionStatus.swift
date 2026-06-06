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

    /// Quick Look extensions only register reliably when the app runs from a
    /// stable location. Returns a user-facing warning when the app is running
    /// translocated (quarantined, launched from Downloads/DMG) or outside
    /// /Applications; `nil` when the location is fine.
    nonisolated static func bundleLocationIssue(bundlePath: String = Bundle.main.bundlePath) -> String? {
        if bundlePath.contains("/AppTranslocation/") {
            return "macOS is running \(AppBrand.name) from a temporary quarantine location, so Finder can't register the Quick Look extension. Move \(AppBrand.name) to Applications and relaunch."
        }
        if !bundlePath.hasPrefix("/Applications/") {
            return "\(AppBrand.name) is running from \(URL(fileURLWithPath: bundlePath).deletingLastPathComponent().path). Quick Look extensions register most reliably from /Applications — move the app there for Finder previews."
        }
        return nil
    }

    /// Writes the sample content for a type to a temp file and opens it in
    /// the Quick Look panel (`qlmanage -p`) — instant proof the extension and
    /// theme work, no Finder hunting required. Fire-and-forget: the panel
    /// stays open until the user closes it, so we never wait on the process.
    func openTestPreview(for type: PreviewFileType) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Skills Preview Sample.\(type.allExtensions[0])")
        do {
            try type.defaultSampleContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            ToastCenter.shared.show("Couldn't write the sample file", kind: .info)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-p", url.path]
        do {
            try process.run()
        } catch {
            ToastCenter.shared.show("Couldn't open the Quick Look panel", kind: .info)
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
