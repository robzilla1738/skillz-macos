import Foundation

/// Single source of truth for library section × platform × search filtering.
enum CatalogFilter {
    static func items(
        in snapshot: CatalogSnapshot,
        section: CatalogSection,
        platform: AgentPlatform?,
        searchText: String = ""
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
            items = items.filter { item in
                item.displayName.localizedCaseInsensitiveContains(query)
                    || item.descriptionText.localizedCaseInsensitiveContains(query)
                    || item.listSubtitle.localizedCaseInsensitiveContains(query)
                    || item.platform.displayName.localizedCaseInsensitiveContains(query)
            }
        }

        return items
    }

    static func sorted(_ items: [CatalogItem]) -> [CatalogItem] {
        items.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}
