import Foundation

/// Resolves which catalog item should be selected after a (re)load: keep the preferred
/// item if it still exists, otherwise fall back to the first visible item, otherwise nil.
enum CatalogSelection {
    static func resolve(
        preferredID: String?,
        in snapshot: CatalogSnapshot,
        fallback: () -> String?
    ) -> String? {
        if let preferredID, snapshot.allItems.contains(where: { $0.id == preferredID }) {
            return preferredID
        }
        return fallback()
    }
}
