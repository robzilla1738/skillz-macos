import Foundation

enum SkillNameValidationError: LocalizedError, Equatable {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

enum SkillNameValidator {
    static func validate(_ name: String) -> Result<String, SkillNameValidationError> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalid("Name cannot be empty."))
        }
        guard trimmed != "." && trimmed != ".." else {
            return .failure(.invalid("Name is not valid."))
        }
        if trimmed.hasPrefix(".") {
            return .failure(.invalid("Name cannot start with a dot."))
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return .failure(.invalid("Use only letters, numbers, hyphens, and underscores."))
        }
        return .success(trimmed)
    }
}
