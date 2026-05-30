import SwiftUI

struct ItemContextMenu: View {
    @ObservedObject var store: CatalogStore
    let item: CatalogItem

    var body: some View {
        if let skill = item.skillItem {
            Button("Edit Details…") {
                store.selectedItemID = item.id
                NotificationCenter.default.post(name: .skillzEditDetails, object: nil)
            }

            if SkillFileService.canModify(skill) {
                Button("Rename Skill…") {
                    store.selectedItemID = item.id
                    NotificationCenter.default.post(name: .skillzRenameSkill, object: nil)
                }
                Divider()
                Button("Delete Skill…", role: .destructive) {
                    store.selectedItemID = item.id
                    NotificationCenter.default.post(name: .skillzDeleteSkill, object: nil)
                }
            }
            Divider()
        }

        Button("Reveal in Finder") {
            reveal()
        }
        Button("Copy Path") {
            copyPath()
        }
        if item.skillItem != nil {
            Button("Open in Cursor") {
                if let path = item.skillItem?.skillPath {
                    store.openInCursor(path)
                }
            }
        }
    }

    private func reveal() {
        switch item {
        case .skill(let skill):
            store.revealInFinder(skill.skillPath)
        case .mcp(let mcp):
            store.revealInFinder(mcp.configFileURL)
        case .plugin(let plugin):
            if let path = plugin.installPath ?? plugin.metadataPath {
                store.revealInFinder(path)
            }
        }
    }

    private func copyPath() {
        switch item {
        case .skill(let skill):
            store.copyPath(skill.skillPath)
        case .mcp(let mcp):
            store.copyPath(mcp.configFileURL)
        case .plugin(let plugin):
            if let path = plugin.installPath ?? plugin.metadataPath {
                store.copyPath(path)
            }
        }
    }
}
