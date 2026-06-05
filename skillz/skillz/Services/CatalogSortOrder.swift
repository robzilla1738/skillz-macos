import Foundation

/// User-selectable ordering for the catalog list. Persisted via `AppSettings.catalogSortOrder`.
nonisolated enum CatalogSortOrder: String, CaseIterable, Identifiable, Sendable {
    case name
    case dateModified
    case platform
    case kind

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateModified: return "Date Modified"
        case .platform: return "Platform"
        case .kind: return "Type"
        }
    }

    var symbolName: String {
        switch self {
        case .name: return "textformat"
        case .dateModified: return "calendar"
        case .platform: return "rectangle.stack"
        case .kind: return "square.grid.2x2"
        }
    }
}
