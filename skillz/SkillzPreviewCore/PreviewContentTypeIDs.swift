import Foundation

/// Single source of truth for the UTI identifier strings used by the Quick
/// Look pipeline. The extension's `QLSupportedContentTypes` (Info.plist) and
/// the host's `UTImportedTypeDeclarations` are hand-authored plists that MUST
/// match these lists — tests reference this file to keep drift visible.
///
/// `QLSupportedContentTypes` matching is EXACT (no parent-conformance walk),
/// which is why types without a system UTI list both our imported identifiers
/// and plausible identifiers other apps export.
nonisolated enum PreviewContentTypeIDs {
    /// Identifiers our host app declares via `UTImportedTypeDeclarations`.
    static let importedIdentifiers: [String] = [
        "robertcourson.skillz.jsonl",
        "robertcourson.skillz.ndjson",
        "robertcourson.skillz.toml",
        "robertcourson.skillz.log",
        "robertcourson.skillz.fish",
    ]

    static func supportedContentTypes(for type: PreviewFileType) -> [String] {
        switch type {
        case .markdown:
            return [
                "net.daringfireball.markdown",
                "public.markdown",
                "com.unknown.md",
                "org.textbundle.markdown",
            ]
        case .json:
            return ["public.json"]
        case .jsonl:
            return [
                "robertcourson.skillz.jsonl",
                "robertcourson.skillz.ndjson",
                "public.jsonl",
                "public.ndjson",
            ]
        case .yaml:
            return ["public.yaml", "org.yaml.yaml"]
        case .toml:
            return [
                "robertcourson.skillz.toml",
                "net.toml-lang.toml",
                "public.toml",
            ]
        case .csv:
            return [
                "public.comma-separated-values-text",
                "public.tab-separated-values-text",
            ]
        case .log:
            return [
                "robertcourson.skillz.log",
                "com.apple.log",
                "public.log",
            ]
        case .plist:
            return [
                "com.apple.property-list",
                "com.apple.xml-property-list",
                "com.apple.binary-property-list",
            ]
        case .xml:
            return ["public.xml"]
        case .shell:
            return [
                "public.shell-script",
                "public.bash-script",
                "public.zsh-script",
                "robertcourson.skillz.fish",
                "com.apple.terminal.shell-script",
            ]
        }
    }

    /// Flat list for the extension's `QLSupportedContentTypes` array.
    static var allSupportedContentTypes: [String] {
        var seen = Set<String>()
        return PreviewFileType.allCases
            .flatMap { supportedContentTypes(for: $0) }
            .filter { seen.insert($0).inserted }
    }
}
