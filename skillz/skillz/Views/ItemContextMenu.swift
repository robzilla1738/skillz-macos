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
                Button("Duplicate Skill") {
                    store.selectedItemID = item.id
                    NotificationCenter.default.post(name: .skillzDuplicateSkill, object: nil)
                }
                let targets = copyTargets(for: skill)
                if !targets.isEmpty {
                    Menu("Copy to Platform") {
                        ForEach(targets) { platform in
                            Button(platform.displayName) {
                                store.selectedItemID = item.id
                                copySkill(to: platform)
                            }
                        }
                    }
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
        if let skill = item.skillItem {
            Button("Open in Cursor") {
                store.openInCursor(skill.skillPath)
            }
            Button("Open in Default Editor") {
                store.openInDefaultApp(skill.skillPath)
            }
        }
    }

    /// Detected platforms that don't already host this skill (directly or via shared dirs).
    private func copyTargets(for skill: SkillItem) -> [AgentPlatform] {
        var existing = Set(skill.alsoAvailableOn)
        existing.insert(skill.platform)
        return store.detectedPlatforms
            .subtracting(existing)
            .sorted { $0.displayName < $1.displayName }
    }

    private func copySkill(to platform: AgentPlatform) {
        do {
            try store.copySelectedSkill(toPlatforms: [platform])
        } catch {
            store.lastOperationError = FileAccessError.userMessage(for: error)
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
