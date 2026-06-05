import Foundation

/// Single source of truth for library section × platform × search filtering.
enum CatalogFilter {
    static func items(
        in snapshot: CatalogSnapshot,
        section: CatalogSection,
        platform: AgentPlatform?,
        searchText: String = "",
        searchBody: Bool = false
    ) -> [CatalogItem] {
        var items = snapshot.allItems

        switch section {
        case .all: break
        case .skills: items = items.filter { $0.kind == .skill }
        case .mcpServers: items = items.filter { $0.kind == .mcp }
        case .plugins: items = items.filter { $0.kind == .plugin }
        }

        if let platform {
            items = items.filter { item in
                item.platform == platform
                    || (item.skillItem?.alsoAvailableOn.contains(platform) == true)
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let loweredQuery = query.lowercased()
            items = items.filter { item in
                item.displayName.localizedCaseInsensitiveContains(query)
                    || item.descriptionText.localizedCaseInsensitiveContains(query)
                    || item.listSubtitle.localizedCaseInsensitiveContains(query)
                    || item.platform.displayName.localizedCaseInsensitiveContains(query)
                    || (searchBody && item.skillItem?.searchableBody.contains(loweredQuery) == true)
            }
        }

        return items
    }

    static func sorted(_ items: [CatalogItem], order: CatalogSortOrder = .name) -> [CatalogItem] {
        items.sorted { lhs, rhs in
            switch order {
            case .name:
                return byName(lhs, rhs)
            case .dateModified:
                switch (lhs.modifiedAt, rhs.modifiedAt) {
                case let (l?, r?):
                    if l != r { return l > r }       // newest first
                    return byName(lhs, rhs)
                case (.some, .none):
                    return true                        // dated items before undated
                case (.none, .some):
                    return false
                case (.none, .none):
                    return byName(lhs, rhs)
                }
            case .platform:
                let comparison = lhs.platform.displayName
                    .localizedCaseInsensitiveCompare(rhs.platform.displayName)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return byName(lhs, rhs)
            case .kind:
                if lhs.kind != rhs.kind { return kindRank(lhs.kind) < kindRank(rhs.kind) }
                return byName(lhs, rhs)
            }
        }
    }

    private static func byName(_ lhs: CatalogItem, _ rhs: CatalogItem) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private static func kindRank(_ kind: CatalogItemKind) -> Int {
        switch kind {
        case .skill: return 0
        case .mcp: return 1
        case .plugin: return 2
        }
    }
}
