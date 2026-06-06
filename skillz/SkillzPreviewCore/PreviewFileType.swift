import Foundation

/// File types the preview pipeline understands. Each case is one user-facing
/// configuration row in the Quick Look settings tab; extensions that share a
/// case (yml/yaml, csv/tsv, the shell dialects) share one settings blob.
nonisolated enum PreviewFileType: String, CaseIterable, Codable, Identifiable, Sendable {
    case markdown
    case json
    case jsonl
    case yaml
    case toml
    case ini
    case env
    case csv
    case log
    case diff
    case sql
    case plist
    case xml
    case shell

    var id: String { rawValue }

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd": self = .markdown
        case "json": self = .json
        case "jsonl", "ndjson": self = .jsonl
        case "yaml", "yml": self = .yaml
        case "toml": self = .toml
        case "ini", "conf", "cfg", "properties": self = .ini
        case "env": self = .env
        case "csv", "tsv": self = .csv
        case "log": self = .log
        case "diff", "patch": self = .diff
        case "sql": self = .sql
        case "plist": self = .plist
        case "xml": self = .xml
        case "sh", "zsh", "bash", "fish": self = .shell
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .jsonl: return "JSON Lines"
        case .yaml: return "YAML"
        case .toml: return "TOML"
        case .ini: return "INI / Config"
        case .env: return "Dotenv"
        case .csv: return "CSV / TSV"
        case .log: return "Log"
        case .diff: return "Diff / Patch"
        case .sql: return "SQL"
        case .plist: return "Property List"
        case .xml: return "XML"
        case .shell: return "Shell Script"
        }
    }

    var allExtensions: [String] {
        switch self {
        case .markdown: return ["md", "markdown", "mdown", "mkd"]
        case .json: return ["json"]
        case .jsonl: return ["jsonl", "ndjson"]
        case .yaml: return ["yaml", "yml"]
        case .toml: return ["toml"]
        case .ini: return ["ini", "conf", "cfg", "properties"]
        case .env: return ["env"]
        case .csv: return ["csv", "tsv"]
        case .log: return ["log"]
        case .diff: return ["diff", "patch"]
        case .sql: return ["sql"]
        case .plist: return ["plist"]
        case .xml: return ["xml"]
        case .shell: return ["sh", "zsh", "bash", "fish"]
        }
    }

    /// Gates which per-type options the settings UI shows.
    enum Category: Sendable {
        case markdown
        case structured
        case tabular
        case plain
    }

    var category: Category {
        switch self {
        case .markdown: return .markdown
        case .csv: return .tabular
        case .log: return .plain
        case .json, .jsonl, .yaml, .toml, .ini, .env, .diff, .sql, .plist, .xml, .shell: return .structured
        }
    }

    var supportsPrettyPrint: Bool {
        self == .json || self == .jsonl
    }

    /// Small literal sample rendered by the settings live preview.
    var defaultSampleContent: String {
        switch self {
        case .markdown:
            return """
            ---
            name: sample-skill
            description: Demonstrates the preview theme.
            ---

            # Sample Skill

            A **rendered** markdown preview with `inline code`, a list, and a table.

            ![architecture diagram](https://example.com/diagram.png)

            - Reads agent folders
            - Writes `SKILL.md`

            | Platform | Path |
            | --- | --- |
            | Claude | ~/.claude/skills |
            | Cursor | ~/.cursor/skills |

            ```swift
            let preview = "themed"
            ```
            """
        case .json:
            return """
            {
              "name": "sample-mcp",
              "transport": "stdio",
              "enabled": true,
              "retries": 3,
              "env": { "API_KEY": "redacted" },
              "tags": ["agents", "preview", null]
            }
            """
        case .jsonl:
            return """
            {"event": "session_start", "agent": "claude", "ts": "2026-06-06T10:00:00Z"}
            {"event": "tool_use", "tool": "Read", "ok": true, "duration_ms": 42}
            {"event": "session_end", "exit_code": 0}
            """
        case .yaml:
            return """
            # Agent configuration
            name: sample-agent
            version: 1.2.0
            enabled: true
            paths:
              - ~/.claude/skills
              - ~/.cursor/skills
            limits:
              timeout_s: 30
            """
        case .toml:
            return """
            # Codex configuration
            model = "gpt-5"
            approval_policy = "on-request"

            [mcp_servers.search]
            command = "npx"
            args = ["-y", "mcp-search"]
            enabled = true
            """
        case .ini:
            return """
            ; Editor configuration
            [core]
            editor = "vim"
            autocrlf = input

            [alias]
            st = status
            co = checkout
            """
        case .env:
            return """
            # Local development secrets
            export NODE_ENV=development
            API_BASE_URL=https://api.example.com
            API_KEY="redacted-key-value"
            RETRY_COUNT=3
            DEBUG=true
            """
        case .csv:
            return """
            platform,skills,mcps,enabled
            Claude Code,24,6,true
            Cursor,18,3,true
            Codex,12,4,false
            """
        case .diff:
            return """
            diff --git a/SKILL.md b/SKILL.md
            index 3f1a2b4..9c8d7e6 100644
            --- a/SKILL.md
            +++ b/SKILL.md
            @@ -1,5 +1,6 @@
             ---
             name: sample-skill
            -description: Old description.
            +description: New, improved description.
            +version: 2.0.0
             ---
            """
        case .sql:
            return """
            -- Agent session metrics
            CREATE TABLE sessions (
                id INTEGER PRIMARY KEY,
                agent TEXT NOT NULL,
                started_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            SELECT agent, COUNT(*) AS runs
            FROM sessions
            WHERE started_at >= '2026-01-01'
            GROUP BY agent
            ORDER BY runs DESC;
            """
        case .log:
            return """
            2026-06-06T10:00:01Z INFO  session started pid=4821
            2026-06-06T10:00:02Z DEBUG scanning ~/.claude/skills
            2026-06-06T10:00:03Z WARN  skill missing frontmatter: legacy-tool
            2026-06-06T10:00:04Z ERROR hook install failed: permission denied
            2026-06-06T10:00:05Z INFO  done in 412ms
            """
        case .plist:
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>SUEnableAutomaticChecks</key>
                <true/>
                <key>SUScheduledCheckInterval</key>
                <integer>86400</integer>
            </dict>
            </plist>
            """
        case .xml:
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!-- Sample feed -->
            <rss version="2.0">
              <channel>
                <title>Skills Updates</title>
                <item enabled="true">
                  <title>Version 1.0.4</title>
                </item>
              </channel>
            </rss>
            """
        case .shell:
            return """
            #!/bin/bash
            # Notify the agent monitor
            STATE_FILE="$HOME/Library/Application Support/Skillz/agent-state.json"
            if [ -f "$STATE_FILE" ]; then
                echo "updating $STATE_FILE"
                export SKILLZ_LAST_RUN=$(date +%s)
            fi
            """
        }
    }
}
