import Foundation

enum SkillFileService {
    static func canModify(_ skill: SkillItem) -> Bool {
        guard !skill.isBuiltIn,
              isFolderBackedSkill(skill)
        else { return false }

        return FileManager.default.isWritableFile(atPath: skill.rootDirectory.path)
            && FileManager.default.isWritableFile(atPath: skill.rootDirectory.deletingLastPathComponent().path)
    }

    static func canEditMetadata(_ skill: SkillItem) -> Bool {
        FileManager.default.isWritableFile(atPath: skill.skillPath.path)
    }

    static func modificationBlockedReason(_ skill: SkillItem) -> String {
        if skill.isBuiltIn {
            return "Built-in Cursor skills cannot be renamed or deleted from \(AppBrand.name)."
        }
        if !isFolderBackedSkill(skill) {
            return "This skill is stored as a single SKILL.md file, so only its metadata can be edited from \(AppBrand.name)."
        }
        return "This skill folder is not writable by \(AppBrand.name). Check file permissions or edit it in its install folder."
    }

    static func metadataBlockedReason(_ skill: SkillItem) -> String {
        if canEditMetadata(skill) { return "" }
        return "This SKILL.md file is not writable by \(AppBrand.name). Check file permissions or edit it in its install folder."
    }

    static func renameSkill(_ skill: SkillItem, newFolderName: String) throws -> URL {
        guard canModify(skill) else {
            throw SkillFileError.blocked(modificationBlockedReason(skill))
        }
        let validated = try SkillNameValidator.validate(newFolderName).get()

        let parent = skill.rootDirectory.deletingLastPathComponent()
        let newRoot = parent.appendingPathComponent(validated, isDirectory: true)

        if FileManager.default.fileExists(atPath: newRoot.path) {
            throw SkillFileError.duplicateName("A skill named \"\(validated)\" already exists in this location.")
        }

        try FileManager.default.moveItem(at: skill.rootDirectory, to: newRoot)

        let newSkillPath = newRoot.appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: newSkillPath.path) {
            let content = try String(contentsOf: newSkillPath, encoding: .utf8)
            let updated = FrontmatterWriter.apply(
                to: content,
                update: FrontmatterWriter.Update(name: validated)
            )
            try updated.write(to: newSkillPath, atomically: true, encoding: .utf8)
        }

        return newRoot
    }

    static func deleteSkill(_ skill: SkillItem) throws {
        guard canModify(skill) else {
            throw SkillFileError.blocked(modificationBlockedReason(skill))
        }
        try FileManager.default.removeItem(at: skill.rootDirectory)
    }

    static func updateMetadata(
        _ skill: SkillItem,
        name: String,
        description: String,
        version: String?
    ) throws {
        guard canEditMetadata(skill) else {
            throw SkillFileError.blocked(metadataBlockedReason(skill))
        }

        let validatedName = try SkillNameValidator.validate(name).get()
        let content = try String(contentsOf: skill.skillPath, encoding: .utf8)
        let updated = FrontmatterWriter.apply(
            to: content,
            update: FrontmatterWriter.Update(
                name: validatedName,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                version: version?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        try updated.write(to: skill.skillPath, atomically: true, encoding: .utf8)
    }

    static func createSkill(
        name: String,
        description: String,
        body: String,
        platforms: Set<AgentPlatform>
    ) throws -> [URL] {
        guard !platforms.isEmpty else {
            throw SkillFileError.validation("Select at least one platform.")
        }

        let validatedName = try SkillNameValidator.validate(name).get()
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileContent = FrontmatterWriter.make(
            name: validatedName,
            description: trimmedDescription,
            body: body
        )

        var createdPaths: [URL] = []
        var duplicatePlatforms: [String] = []

        for platform in platforms.sorted(by: { $0.displayName < $1.displayName }) {
            let skillsRoot = platform.userSkillsDirectory
            try FileManager.default.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
            let skillDir = skillsRoot.appendingPathComponent(validatedName, isDirectory: true)

            if FileManager.default.fileExists(atPath: skillDir.path) {
                duplicatePlatforms.append(platform.displayName)
                continue
            }

            try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
            let skillPath = skillDir.appendingPathComponent("SKILL.md")
            try fileContent.write(to: skillPath, atomically: true, encoding: .utf8)
            createdPaths.append(skillPath)
        }

        if createdPaths.isEmpty {
            let names = duplicatePlatforms.joined(separator: ", ")
            throw SkillFileError.duplicateName("A skill named \"\(validatedName)\" already exists on: \(names).")
        }

        return createdPaths
    }

    /// Copies the entire skill folder (including secondary markdown, assets, scripts) alongside
    /// the original. The copied SKILL.md's frontmatter `name` is updated to the new folder name.
    @discardableResult
    static func duplicateSkill(_ skill: SkillItem, newName: String? = nil) throws -> URL {
        guard canModify(skill) else {
            throw SkillFileError.blocked(modificationBlockedReason(skill))
        }

        let parent = skill.rootDirectory.deletingLastPathComponent()
        let targetName: String
        if let newName {
            targetName = try SkillNameValidator.validate(newName).get()
            if FileManager.default.fileExists(atPath: parent.appendingPathComponent(targetName).path) {
                throw SkillFileError.duplicateName("A skill named \"\(targetName)\" already exists in this location.")
            }
        } else {
            targetName = collisionFreeName(base: skill.rootDirectory.lastPathComponent, in: parent)
        }

        let newRoot = parent.appendingPathComponent(targetName, isDirectory: true)
        try FileManager.default.copyItem(at: skill.rootDirectory, to: newRoot)
        try renamePrimaryFrontmatter(in: newRoot, to: targetName)
        return newRoot
    }

    /// Copies the skill folder into one or more other platforms' user skill directories.
    /// Existing folders are never overwritten — a `-copy` suffix is applied on collision.
    @discardableResult
    static func copySkill(_ skill: SkillItem, toPlatforms platforms: Set<AgentPlatform>) throws -> [URL] {
        guard !platforms.isEmpty else {
            throw SkillFileError.validation("Select at least one platform.")
        }
        guard isFolderBackedSkill(skill) else {
            throw SkillFileError.blocked(modificationBlockedReason(skill))
        }

        let sourceName = skill.rootDirectory.lastPathComponent
        var createdRoots: [URL] = []

        for platform in platforms.sorted(by: { $0.displayName < $1.displayName }) {
            let skillsRoot = platform.userSkillsDirectory
            try FileManager.default.createDirectory(at: skillsRoot, withIntermediateDirectories: true)

            // Don't duplicate the source in place.
            if skillsRoot.standardizedFileURL == skill.rootDirectory.deletingLastPathComponent().standardizedFileURL {
                continue
            }

            let targetName = collisionFreeName(base: sourceName, in: skillsRoot)
            let newRoot = skillsRoot.appendingPathComponent(targetName, isDirectory: true)
            try FileManager.default.copyItem(at: skill.rootDirectory, to: newRoot)
            if targetName != sourceName {
                try renamePrimaryFrontmatter(in: newRoot, to: targetName)
            }
            createdRoots.append(newRoot)
        }

        if createdRoots.isEmpty {
            throw SkillFileError.duplicateName("This skill already exists on the selected platform(s).")
        }
        return createdRoots
    }

    /// Returns `base` if free, otherwise `base-copy`, `base-copy-2`, … until an unused name is found.
    private static func collisionFreeName(base: String, in directory: URL) -> String {
        if !FileManager.default.fileExists(atPath: directory.appendingPathComponent(base).path) {
            return base
        }
        var candidate = "\(base)-copy"
        var counter = 2
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-copy-\(counter)"
            counter += 1
        }
        return candidate
    }

    /// Rewrites the `name:` frontmatter of a folder's primary SKILL.md to match its folder name.
    private static func renamePrimaryFrontmatter(in root: URL, to name: String) throws {
        let skillPath = root.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillPath.path) else { return }
        let content = try String(contentsOf: skillPath, encoding: .utf8)
        let updated = FrontmatterWriter.apply(
            to: content,
            update: FrontmatterWriter.Update(name: name)
        )
        try updated.write(to: skillPath, atomically: true, encoding: .utf8)
    }

    private static func isFolderBackedSkill(_ skill: SkillItem) -> Bool {
        skill.rootDirectory.appendingPathComponent("SKILL.md").path == skill.skillPath.path
            && skill.rootDirectory.lastPathComponent != "skills"
            && !skill.rootDirectory.lastPathComponent.hasSuffix("skills")
    }
}

enum SkillFileError: LocalizedError {
    case blocked(String)
    case duplicateName(String)
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .blocked(let message): return message
        case .duplicateName(let message): return message
        case .validation(let message): return message
        }
    }
}
