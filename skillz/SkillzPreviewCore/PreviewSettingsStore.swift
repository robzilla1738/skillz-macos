import Foundation

/// Shared app-group identity. The literal team prefix is required at runtime
/// (entitlements use `$(TeamIdentifierPrefix)group.robertcourson.skillz`,
/// which expands to the same string at build time).
nonisolated enum PreviewAppGroup {
    static let identifier = "9F2JXY8TCK.group.robertcourson.skillz"
}

/// Reads/writes per-type `PreviewTypeSettings` blobs in the shared app-group
/// defaults. The host app writes; the sandboxed Quick Look extension reads.
/// Falls back to standard defaults when the suite is unavailable so app-only
/// contexts (and tests, via injection) keep working.
nonisolated struct PreviewSettingsStore {
    static let schemaVersion = 1
    private static let schemaVersionKey = "quicklook.preview.settings.schemaVersion"

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: PreviewAppGroup.identifier)
            ?? .standard
    }

    static func key(for type: PreviewFileType) -> String {
        "quicklook.preview.settings.\(type.rawValue)"
    }

    func load(_ type: PreviewFileType) -> PreviewTypeSettings {
        guard let data = defaults.data(forKey: Self.key(for: type)),
              let decoded = try? JSONDecoder().decode(PreviewTypeSettings.self, from: data) else {
            return PreviewTypeSettings.defaults(for: type)
        }
        return decoded
    }

    func save(_ settings: PreviewTypeSettings, for type: PreviewFileType) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key(for: type))
        defaults.set(Self.schemaVersion, forKey: Self.schemaVersionKey)
    }

    func loadAll() -> [PreviewFileType: PreviewTypeSettings] {
        Dictionary(uniqueKeysWithValues: PreviewFileType.allCases.map { ($0, load($0)) })
    }

    /// Writes defaults for any type that has no blob yet so the extension
    /// always finds settings. Called by the host app on launch.
    func seedMissingDefaults() {
        for type in PreviewFileType.allCases where defaults.data(forKey: Self.key(for: type)) == nil {
            save(PreviewTypeSettings.defaults(for: type), for: type)
        }
        defaults.set(Self.schemaVersion, forKey: Self.schemaVersionKey)
    }
}
