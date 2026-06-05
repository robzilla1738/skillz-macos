import Foundation

enum SkillScanner {
    nonisolated static func scan(
        hideBuiltInCursor: Bool,
        hideSystemCodex: Bool
    ) -> [SkillItem] {
        var items: [SkillItem] = []

        for platform in AgentPlatform.allCases {
            let hideSystem = platform == .codex && hideSystemCodex
            for root in PlatformSkillPaths.skillScanRoots(for: platform) {
                items += scanDirectory(
                    root,
                    platform: platform,
                    isBuiltIn: false,
                    isPluginEmbedded: false,
                    hideSystem: hideSystem
                )
            }
        }

        if !hideBuiltInCursor {
            items += scanDirectory(
                AgentPlatform.cursor.homeDirectory.appendingPathComponent("skills-cursor"),
                platform: .cursor,
                isBuiltIn: true,
                isPluginEmbedded: false,
                hideSystem: false
            )
        }

        items += scanPluginEmbeddedSkills(
            root: AgentPlatform.cursor.homeDirectory.appendingPathComponent("plugins/cache"),
            platform: .cursor
        )
        items += scanPluginEmbeddedSkills(
            root: AgentPlatform.claudeCode.homeDirectory.appendingPathComponent("plugins/cache"),
            platform: .claudeCode
        )
        items += scanPluginEmbeddedSkills(
            root: AgentPlatform.codex.homeDirectory.appendingPathComponent("plugins/cache"),
            platform: .codex
        )

        return deduplicate(items)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private nonisolated static func deduplicate(_ items: [SkillItem]) -> [SkillItem] {
        var byPath: [String: SkillItem] = [:]

        for item in items {
            let pathKey = item.skillPath.path
            let primary = PlatformSkillPaths.primaryPlatform(for: item.skillPath)
            let also = PlatformSkillPaths.platformsThatShare(path: item.skillPath)
                .filter { $0 != primary }

            let deduped = SkillItem(
                id: SkillItem.makeID(platform: primary, path: item.skillPath),
                platform: primary,
                skillPath: item.skillPath,
                rootDirectory: item.rootDirectory,
                displayName: item.displayName,
                description: item.description,
                version: item.version,
                isBuiltIn: item.isBuiltIn,
                isPluginEmbedded: item.isPluginEmbedded,
                frontmatter: item.frontmatter,
                modifiedAt: item.modifiedAt,
                alsoAvailableOn: also,
                searchableBody: item.searchableBody
            )
            byPath[pathKey] = deduped
        }

        return Array(byPath.values)
    }

    private nonisolated static func scanDirectory(
        _ root: URL,
        platform: AgentPlatform,
        isBuiltIn: Bool,
        isPluginEmbedded: Bool,
        hideSystem: Bool
    ) -> [SkillItem] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [SkillItem] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "SKILL.md" else { continue }
            let relative = fileURL.deletingLastPathComponent().path
            if hideSystem && (relative.contains("/.system/") || relative.hasSuffix("/.system")) {
                continue
            }
            if let item = makeSkillItem(
                skillPath: fileURL,
                platform: platform,
                isBuiltIn: isBuiltIn,
                isPluginEmbedded: isPluginEmbedded
            ) {
                items.append(item)
            }
        }
        return items
    }

    private nonisolated static func scanPluginEmbeddedSkills(root: URL, platform: AgentPlatform) -> [SkillItem] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [SkillItem] = []
        for case let dirURL as URL in enumerator {
            let name = dirURL.lastPathComponent
            guard name == "skills" || name.hasSuffix("skills") else { continue }
            guard (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

            guard let skillFiles = try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for skillDir in skillFiles where skillDir.hasDirectoryPath {
                let skillMD = skillDir.appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: skillMD.path) else { continue }
                if let item = makeSkillItem(
                    skillPath: skillMD,
                    platform: platform,
                    isBuiltIn: false,
                    isPluginEmbedded: true
                ) {
                    items.append(item)
                }
            }

            for file in skillFiles where file.lastPathComponent == "SKILL.md" {
                if let item = makeSkillItem(
                    skillPath: file,
                    platform: platform,
                    isBuiltIn: false,
                    isPluginEmbedded: true
                ) {
                    items.append(item)
                }
            }
        }
        return items
    }

    private nonisolated static func makeSkillItem(
        skillPath: URL,
        platform: AgentPlatform,
        isBuiltIn: Bool,
        isPluginEmbedded: Bool
    ) -> SkillItem? {
        guard let content = try? String(contentsOf: skillPath, encoding: .utf8) else { return nil }

        let (frontmatter, body) = FrontmatterParser.parse(from: content)
        let folderName = skillPath.deletingLastPathComponent().lastPathComponent
        let displayName = frontmatter.name ?? folderName
        let description = frontmatter.description ?? FrontmatterParser.firstParagraph(from: body)
        let rootDirectory = skillPath.deletingLastPathComponent()

        let modifiedAt = try? skillPath.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        return SkillItem(
            id: SkillItem.makeID(platform: platform, path: skillPath),
            platform: platform,
            skillPath: skillPath,
            rootDirectory: rootDirectory,
            displayName: displayName,
            description: description.isEmpty ? "No description" : description,
            version: frontmatter.version,
            isBuiltIn: isBuiltIn,
            isPluginEmbedded: isPluginEmbedded,
            frontmatter: frontmatter,
            modifiedAt: modifiedAt,
            alsoAvailableOn: [],
            searchableBody: String(body.prefix(8000)).lowercased()
        )
    }

    nonisolated static func markdownFiles(in rootDirectory: URL) -> [SkillMarkdownFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [SkillMarkdownFile(url: rootDirectory.appendingPathComponent("SKILL.md"), isPrimary: true)]
        }

        var files: [SkillMarkdownFile] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let isPrimary = fileURL.lastPathComponent == "SKILL.md"
            files.append(SkillMarkdownFile(url: fileURL, isPrimary: isPrimary))
        }

        return files.sorted { lhs, rhs in
            if lhs.isPrimary != rhs.isPrimary { return lhs.isPrimary }
            return lhs.url.path.localizedCaseInsensitiveCompare(rhs.url.path) == .orderedAscending
        }
    }
}
