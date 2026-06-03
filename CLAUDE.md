# CLAUDE.md — Skillz

macOS app for browsing, editing, and managing **agent harness artifacts** on disk: skills (`SKILL.md`), MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode. Includes a menu-bar agent monitor for live session status.

## Repo layout

```
skillz-macos/
├── CLAUDE.md / AGENTS.md     # This file (keep in sync)
├── README.md                 # Public status, agent detection, CI, Sparkle placeholders
├── .github/workflows/ci.yml  # Debug build + skillzTests on macos-26
└── skillz/                   # Xcode project root
    ├── skillz.xcodeproj
    ├── skillz/               # App target sources
    │   ├── skillzApp.swift   # @main — WindowGroup, MenuBarExtra, Settings
    │   ├── Views/            # SwiftUI UI (MainWindowView, lists, editor, sheets)
    │   ├── Services/         # Catalog discovery, file I/O, agent engines, hooks
    │   ├── Models/           # SkillItem, MCPItem, PluginItem, AgentSession, …
    │   ├── Settings/         # AppSettings, SettingsView tabs
    │   ├── Theme/            # Typography, colors, shared components
    │   ├── Notch/            # Dormant legacy NSPanel notch UI sources (not wired at runtime)
    │   ├── Resources/        # skillz-agent-notify.sh (bundled, installed to ~/.skillz/bin)
    │   ├── Assets.xcassets/  # AppIcon, Skillz* colors, PlatformIcon* SVG/vector assets
    │   └── ThirdParty/       # icon notices / third-party licenses
    ├── skillzTests/          # Swift Testing unit tests
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
| Icons | Asset-catalog platform icons (`PlatformIcon*`) rendered as template images in sidebar/menu-bar surfaces |

**Deployment:** macOS **26.2+**, bundle ID `robertcourson.skillz`, **not sandboxed** (`skillz.entitlements` → `com.apple.security.app-sandbox` = false) so the app can read `~/.cursor`, `~/.claude`, `~/.codex`, etc. UI product name is **Skills** (`AppBrand.name`); current marketing version **1.0.2**.

## Build and test

From `skillz/` (directory containing `skillz.xcodeproj`):

```bash
xcodebuild -scheme skillz -destination 'platform=macOS' build
xcodebuild -scheme skillz -destination 'platform=macOS' test
```

- **Scheme:** `skillz`
- **Unit tests:** `skillzTests` — 48 `@Test` functions (frontmatter, catalog filter, platform paths, source detection, bare-home-not-detected, agent engine, session-adapter liveness/id stability, process runner, hooks, startup hook policy, file service, legacy notch layout/view-model, process exclusions, session dedup, discovery smoke)
- **UI tests:** `skillzUITests` — launch/performance (slow); skip unless needed
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) — Debug build + `-only-testing:skillzTests` on `macos-26`

Release checklist is inline in `skillz.entitlements` (Developer ID, archive, notarize, staple). Public builds ship as GitHub Release DMGs (`Skills-macOS-v*.dmg`); update/signing/Sparkle details live in `README.md` and `docs/UPDATES.md`.

## Architecture

### App entry and scenes

- **`skillzApp`**: `WindowGroup` → `MainWindowView` with hidden titlebar; `MenuBarExtra` → agent menu + **menu-bar glyph** (`SkillzMenuBarIconView` — template `sparkles` SF Symbol the system tints, so it stays visible on light/dark menu bars; the app icon is a near-black mark unusable here); `Settings` scene.
- **`SkillzStartupConfigurator`**: on first appear, starts `AgentSessionStore`, defers initial hook install/repair until onboarding is complete, reopens watching on app activation, and stops monitoring on termination.
- **`SkillzWindowChromeCleaner`**: AppKit bridge — clears native toolbar/titlebar chrome and hides stray AppKit sidebar-toggle buttons in the title bar.
- **`OnboardingView`**: first-launch sheet (`settings.hasCompletedOnboarding`); shows live source/tool detection for all tracked platforms and toggles menu-bar waiting count, inspector, and automatic hook repair before catalog use.

### Main window (`NavigationSplitView`)

| Column | View | Role |
|--------|------|------|
| Sidebar | `SidebarView` | Library sections (All / Skills / MCPs / Plugins) + platform filters |
| Content | `ItemListView` | Searchable catalog list (`SkillzListRow`) |
| Detail | `DetailContainerView` | Skill editor, MCP/plugin detail; optional `InspectorView` |

**State:** `CatalogStore` (snapshot, filters, selection, FSEvents rescan), `EditorDocument` (markdown autosave), `AppSettings` (`@AppStorage`).

**Top bar** (full-width row above the split view, `.zIndex(1)` so its hairline masks inset-sidebar shadow bleed):
- **Leading:** sidebar toggle (glass icon group), then New Skill + Refresh (glass group); inset from traffic lights via `SkillzWindowMetrics.trafficLightReservedWidth` (88pt).
- **Trailing:** skill actions (Details / Rename / Delete), Save in its own group (separated from destructive actions), search field (320pt).
- Sidebar uses `.toolbar(removing: .sidebarToggle)` — the custom toolbar button is the only sidebar control.

**Sidebar inset:** `NavigationSplitView` is pulled up by `SkillzWindowMetrics.sidebarTopInsetPull` (14pt) so the floating sidebar card sits evenly below the top-bar divider; do not remove the top-bar `zIndex` or the card shadow will overlap the hairline again.

### Catalog discovery

- **`DiscoveryEngine`** orchestrates `SkillScanner`, `MCPScanner`, `PluginScanner`.
- **`PlatformSkillPaths`** — per-platform scan roots; shared `~/.agents/skills` for Codex/Pi/OpenCode dedup via `alsoAvailableOn`.
- **`PlatformSourceDetector`** — centralized platform detection profiles; checks source folders, config files, shared `~/.agents/skills`, and known CLI locations; keeps shared skill sources separate from install signals; drives onboarding, settings, empty states, and “New Skill” defaults.
- **`CatalogFilter`** — section × platform × search.
- Live rescan: `FSEventWatcher` + refresh on `NSApplication.didBecomeActive`.
- **List rows:** `PlatformBadge` + `EnabledBadge` (`.subtle` tag, next to platform pill) for plugins; `subtitleText` fallbacks with `.lineLimit(2, reservesSpace: true)` for uniform row height; `SkillzListRowChrome` animates hover/selection; shared-skill info button when applicable.

### Skill editing

- **`SkillFileService`** — create/rename/delete under platform skill dirs; validates names via **`SkillNameValidator`**.
- **`FrontmatterParser` / `FrontmatterWriter`** — YAML frontmatter in `SKILL.md`.
- **`MarkdownEditorView`** — monospaced editor; font size from settings.

### Agent monitoring

| Piece | Path / type |
|-------|-------------|
| Session store | `AgentSessionStore` — merges file watch + hook + process state |
| State file | `~/Library/Application Support/Skillz/agent-state.json` |
| Adapters | `CursorSessionAdapter`, `ClaudeSessionAdapter`, `CodexSessionAdapter`, `ShellAgentProcessAdapter` |
| Process runner | `ShellProcessRunner` — drains stdout/stderr concurrently, waits off the main thread, and enforces timeouts |
| Merge logic | `AgentActivityEngine` (needsInput > working > idle; stale working → unknown; process/transcript/hook dedup) |
| Menu-bar display | `AgentActivitySummary.notchDisplaySessions` — active/actionable sessions shown in the menu-bar menu |
| Hooks | `AgentHookInstaller` — patches Cursor/Claude/Codex configs; installs `~/.skillz/bin/skillz-agent-notify.sh` |
| Notify script | `Resources/skillz-agent-notify.sh` → updates state file |

**Defaults:** `autoInstallAgentHooks = true`, `showAgentCountInMenuBar = true` (`AppSettings`).

**Tracked platforms in menu bar:** Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode (`AgentPlatform.trackedAgentPlatforms`). Cursor, Claude Code, and Codex support precise waiting-state hooks; Hermes, Pi, and OpenCode use process detection. The internal enum case is still named `openClaw` for compatibility with existing state/config paths, but the user-facing label and icon are OpenCode.

### Legacy notch sources

The `Notch/` folder is retained as dormant legacy code for now, but no app entrypoint, settings screen, onboarding flow, or menu-bar action should instantiate `NotchAppDelegate`, `NotchWindowController`, or `NotchPanel`. Keep runtime agent monitoring in `SkillzStartupConfigurator` and menu-bar UI.

### Settings tabs

General (appearance, hide built-in Cursor/Codex skills, inspector) · **Sources** (scan paths, rescan) · **Agents** (menu-bar waiting count, hook install status) · Editor (font size).

## Design system

- **Colors:** `Assets.xcassets` — `SkillzCanvas`, `SkillzInk`, `SkillzEmphasis`, `SkillzMuted`, `SkillzSectionLabel`, `SkillzHairline`, `SkillzSelection`.
- **Typography:** `SkillzTypography` — monospaced scale; primary UI text uses **`SkillzEmphasis`** (~#333), not pure black; editor uses `SkillzTypography.editor(size:)`.
- **Components:** `SkillzComponents.swift` (tags, glass search/toolbar groups, detail rows), `SkillzTextStyles` view modifiers.
- **Window chrome:** main window owns its custom top bar; do not reintroduce SwiftUI/AppKit toolbar title text or the native sidebar toggle.
- **Notch:** `NotchMonochromeStyle` — black panel, white-only UI.

## Platform homes (read-only conventions)

| Platform | Home dir | Typical skill path |
|----------|----------|-------------------|
| Cursor | `~/.cursor` | `~/.cursor/skills` |
| Claude Code | `~/.claude` | `~/.claude/skills` |
| Codex | `~/.codex` | `~/.codex/skills` + `~/.agents/skills` |
| Hermes | `~/.hermes` | `~/.hermes/skills` |
| Pi | `~/.pi` | `~/.pi/agent/skills` + `~/.agents/skills` |
| OpenCode | `~/.openclaw` legacy config | workspace + `~/.openclaw/skills` |

MCP configs currently scan Cursor `mcp.json`, Claude `.mcp.json`, and Codex `config.toml`. Plugin catalog support scans Cursor, Claude, and Codex plugin caches/configs where implemented.

## Gotchas

- **Non-sandboxed** — required for scanning user agent dirs; do not enable app sandbox without redesigning file access.
- **Test PIDs** — avoid `pid: 1` in agent engine tests (treated as stale/system).
- **Notch layout** — call `updateOpenLayout` when session count / hooks / state change; `NotchShape` must keep vertical side edges at full width.
- **Sidebar inset pull** — tune only `SkillzWindowMetrics.sidebarTopInsetPull`; keep top bar above the split view (`zIndex`) or scroll-edge shadow bleeds over the hairline.
- **Platform icons** — SVG assets with transparent backgrounds and `template-rendering-intent`; do not use page-backed PDFs (they render as solid blocks), and keep paths CoreSVG-safe. See `ThirdParty/platform-icons-NOTICE.txt` for sources.
- **Codex icon** — `PlatformIconCodex` is a single `codex.svg`; path arcs must be CoreSVG-safe (minified `a`/`A` commands break rendering in the asset catalog).
- **Cursor process matching** — `ShellAgentProcessAdapter` excludes the Cursor desktop app and Electron helpers; do not broaden matching or the menu bar will show false positives.
- **OpenCode compatibility** — source path handling still uses `OpenClawConfig` until the on-disk layout changes; detection also accepts `opencode`/`open-code` and legacy `openclaw`/`open-claw` executables.
- **Commits** — only when the user asks.
- **Third-party icons** — retain `ThirdParty/lobe-icons-LICENSE.txt` when updating Lobe assets.

## Editing conventions

- Match existing patterns: `@MainActor` stores, minimal diff, no over-abstraction.
- Prefer extending `SkillzTypography` / `SkillzTextStyles` over one-off fonts.
- Do not re-enable the legacy notch without an explicit product decision; runtime agent monitoring should stay independent of the dormant notch sources.
- Hook install paths are harness-specific — see `AgentHookInstaller` before changing notify wiring.
