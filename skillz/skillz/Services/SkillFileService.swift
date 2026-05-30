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
