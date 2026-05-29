# AGENTS.md — Skillz

macOS app for browsing, editing, and managing **agent harness artifacts** on disk: skills (`SKILL.md`), MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenClaw. Includes a menu-bar agent monitor and a Dynamic Island–style **agent notch** for live session status.

## Repo layout

```
skillz-macos/
├── CLAUDE.md / AGENTS.md     # This file (keep in sync)
└── skillz/                   # Xcode project root
    ├── skillz.xcodeproj
    ├── skillz/               # App target sources
    │   ├── skillzApp.swift   # @main — WindowGroup, MenuBarExtra, Settings
    │   ├── Views/            # SwiftUI UI (MainWindowView, lists, editor, sheets)
    │   ├── Services/         # Catalog discovery, file I/O, agent engines, hooks
    │   ├── Models/           # SkillItem, MCPItem, PluginItem, AgentSession, …
    │   ├── Settings/         # AppSettings, SettingsView tabs
    │   ├── Theme/            # Typography, colors, shared components
    │   ├── Notch/            # NSPanel notch UI + window controller
    │   ├── Resources/        # skillz-agent-notify.sh (bundled, installed to ~/.skillz/bin)
    │   ├── Assets.xcassets/  # AppIcon, Skillz* colors, PlatformIcon* (Lobe SVGs)
    │   └── ThirdParty/       # lobe-icons MIT license
    ├── skillzTests/         # Swift Testing unit tests
    └── skillzUITests/        # UI tests (launch smoke)
```

Xcode uses **PBXFileSystemSynchronizedRootGroup** — new files under `skillz/skillz/` are picked up automatically; no manual `pbxproj` edits for most adds.

## Stack

| Layer | Choice |
|-------|--------|
| UI | SwiftUI + AppKit (`NSPanel`, `NSHostingView`, `MenuBarExtra`) |
| Language | Swift 5, `@MainActor` view models |
| Persistence | Direct file I/O (no Core Data); `~/Library/Application Support/Skillz/agent-state.json` for agent snapshots |
| Tests | Swift Testing (`@Test` in `skillzTests`) |
| Icons (notch) | [Lobe Icons](https://github.com/lobehub/lobe-icons) static SVGs (MIT) — Cursor, Claude Code, OpenAI for Codex |

**Deployment:** macOS **26.2+**, bundle ID `robertcourson.skillz`, **not sandboxed** (`skillz.entitlements` → `com.apple.security.app-sandbox` = false) so the app can read `~/.cursor`, `~/.claude`, `~/.codex`, etc.

## Build and test

From `skillz/` (directory containing `skillz.xcodeproj`):

```bash
xcodebuild -scheme skillz -destination 'platform=macOS' build
xcodebuild -scheme skillz -destination 'platform=macOS' test
```

- **Scheme:** `skillz`
- **Unit tests:** `skillzTests` — 20 `@Test` functions (frontmatter, catalog filter, platform paths, agent engine, hooks, file service, notch layout calculator, discovery smoke)
- **UI tests:** `skillzUITests` — launch/performance (slow); skip unless needed

Release notes are inline in `skillz.entitlements` (Developer ID, archive, notarize, staple).

## Architecture

### App entry and scenes

- **`skillzApp`**: `WindowGroup` → `MainWindowView`; `MenuBarExtra` → agent menu + **Skillz app icon** (`MenuBarIcon` / `NSApp.applicationIconImage`); `Settings` scene; `NotchAppDelegate` for notch lifecycle.
- **`SkillzStartupConfigurator`**: on first appear, wires `NotchAppDelegate.configure(agentStore:settings:)`.

### Main window (`NavigationSplitView`)

| Column | View | Role |
|--------|------|------|
| Sidebar | `SidebarView` | Library sections (All / Skills / MCPs / Plugins) + platform filters |
| Content | `ItemListView` | Searchable catalog list (`SkillzListRow`) |
| Detail | `DetailContainerView` | Skill editor, MCP/plugin detail; optional `InspectorView` |

**State:** `CatalogStore` (snapshot, filters, selection, FSEvents rescan), `EditorDocument` (markdown autosave), `AppSettings` (`@AppStorage`).

### Catalog discovery

- **`DiscoveryEngine`** orchestrates `SkillScanner`, `MCPScanner`, `PluginScanner`.
- **`PlatformSkillPaths`** — per-platform scan roots; shared `~/.agents/skills` for Codex/Pi/OpenClaw dedup via `alsoAvailableOn`.
- **`PlatformSourceDetector`** — which harness folders exist; drives empty states and “New Skill” defaults.
- **`CatalogFilter`** — section × platform × search.
- Live rescan: `FSEventWatcher` + refresh on `NSApplication.didBecomeActive`.

### Skill editing

- **`SkillFileService`** — create/rename/delete under platform skill dirs; validates names via **`SkillNameValidator`**.
- **`FrontmatterParser` / `FrontmatterWriter`** — YAML frontmatter in `SKILL.md`.
- **`MarkdownEditorView`** — monospaced editor; font size from settings.

### Agent monitoring

| Piece | Path / type |
|-------|-------------|
| Session store | `AgentSessionStore` — merges file watch + hook state |
| State file | `~/Library/Application Support/Skillz/agent-state.json` |
| Adapters | `CursorSessionAdapter`, `ClaudeSessionAdapter`, `CodexSessionAdapter` |
| Merge logic | `AgentActivityEngine` (needsInput > working > idle; stale working → unknown) |
| Hooks | `AgentHookInstaller` — patches Claude/Codex/Cursor configs; installs `~/.skillz/bin/skillz-agent-notify.sh` |
| Notify script | `Resources/skillz-agent-notify.sh` → updates state file |

**Tracked platforms in notch:** Cursor, Claude Code, Codex only (`AgentPlatform.trackedAgentPlatforms`).

### Agent notch

- **`NotchWindowController`** + borderless **`NotchPanel`** (menu-bar level, non-activating).
- **`NotchViewModel`** — states: closed / open / peeking / hidden; **pinned open**; dynamic size via **`NotchLayoutCalculator`**.
- UI: `NotchRootView`, `AgentNotchClosedView`, `AgentNotchOpenView` (monochrome); brand icons via **`PlatformBrandIcon`** + Lobe assets.
- **`NotchShape`** — rounded rect clip (straight sides; do not reintroduce inset side curves).
- Open width ~440pt+; panel padding animated on layout changes.

### Settings tabs

General (appearance, hide built-in Cursor/Codex skills, inspector) · **Sources** (scan paths, rescan) · **Agents** (notch toggle, display picker, hook install status) · Editor (font size).

## Design system

- **Colors:** `Assets.xcassets` — `SkillzCanvas`, `SkillzInk`, `SkillzEmphasis`, `SkillzMuted`, `SkillzSectionLabel`, `SkillzHairline`, `SkillzSelection`.
- **Typography:** `SkillzTypography` — monospaced scale; primary UI text uses **`SkillzEmphasis`** (~#333), not pure black; editor uses `SkillzTypography.editor(size:)`.
- **Components:** `SkillzComponents.swift` (tags, glass search, detail rows), `SkillzTextStyles` view modifiers.
- **Notch:** `NotchMonochromeStyle` — black panel, white-only UI.

## Platform homes (read-only conventions)

| Platform | Home dir | Typical skill path |
|----------|----------|-------------------|
| Cursor | `~/.cursor` | `~/.cursor/skills` |
| Claude Code | `~/.claude` | `~/.claude/skills` |
| Codex | `~/.codex` | `~/.codex/skills` + `~/.agents/skills` |
| Hermes | `~/.hermes` | `~/.hermes/skills` |
| Pi | `~/.pi` | `~/.pi/agent/skills` + `~/.agents/skills` |
| OpenClaw | `~/.openclaw` | workspace + `~/.openclaw/skills` |

MCP configs: Cursor `mcp.json`, Claude `.mcp.json`, Codex `config.toml`. Plugins: harness-specific cache under each home.

## Gotchas

- **Non-sandboxed** — required for scanning user agent dirs; do not enable app sandbox without redesigning file access.
- **Test PIDs** — avoid `pid: 1` in agent engine tests (treated as stale/system).
- **Notch layout** — call `updateOpenLayout` when session count / hooks / state change; `NotchShape` must keep vertical side edges at full width.
- **Codex notch icon** — `PlatformIconCodex` uses **OpenAI** logo SVG, not Codex wordmark.
- **Git** — repo root may not be a git root; don’t assume `git` metadata.
- **Commits** — only when the user asks.
- **Third-party icons** — retain `ThirdParty/lobe-icons-LICENSE.txt` when updating Lobe assets.

## Editing conventions

- Match existing patterns: `@MainActor` stores, minimal diff, no over-abstraction.
- Prefer extending `SkillzTypography` / `SkillzTextStyles` over one-off fonts.
- New notch sizing logic belongs in `NotchLayoutCalculator` with tests in `skillzTests`.
- Hook install paths are harness-specific — see `AgentHookInstaller` before changing notify wiring.
