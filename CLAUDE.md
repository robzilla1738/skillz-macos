# CLAUDE.md — Skillz

macOS app for browsing, editing, and managing **agent harness artifacts** on disk: skills (`SKILL.md`), MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode. Includes a menu-bar agent monitor for live session status.

## Repo layout

```
skillz-macos/
├── CLAUDE.md / AGENTS.md     # This file (keep in sync)
├── README.md                 # Public status, agent detection, CI, Sparkle updates
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
    ├── SkillzPreviewCore/    # Shared preview engine — compiled into app AND Quick Look targets
    ├── SkillzQuickLook/      # Quick Look extension (.appex): PreviewViewController, Info.plist, entitlements
    ├── skillzTests/          # Swift Testing unit tests
    └── skillzUITests/        # UI tests (launch smoke)
```

Xcode uses **PBXFileSystemSynchronizedRootGroup** — new files under `skillz/skillz/` (app), `SkillzPreviewCore/` (app + extension), and `SkillzQuickLook/` (extension) are picked up automatically; no manual `pbxproj` edits for most adds.

## Stack

| Layer | Choice |
|-------|--------|
| UI | SwiftUI + AppKit (`NSPanel`, `NSHostingView`, `MenuBarExtra`) |
| Language | Swift 5, `@MainActor` view models |
| Persistence | Direct file I/O (no Core Data); `~/Library/Application Support/Skillz/agent-state.json` for agent snapshots |
| Tests | Swift Testing (`@Test` in `skillzTests`) |
| Icons | Asset-catalog platform icons (`PlatformIcon*`) rendered as template images in sidebar/menu-bar surfaces |
| Markdown rendering | **MarkdownUI** (SPM, pinned upToNextMajor 2.4.0) in app + Quick Look targets |

**Deployment:** macOS **14.0+**, bundle ID `robertcourson.skillz`, **not sandboxed** (`skillz.entitlements` → `com.apple.security.app-sandbox` = false) so the app can read `~/.cursor`, `~/.claude`, `~/.codex`, etc. UI product name is **Skills** (`AppBrand.name`); current marketing version **1.2.0**. The embedded Quick Look extension (`robertcourson.skillz.quicklook`, product `SkillzQuickLook.appex`) **is** sandboxed (required for appexes) and shares prefs with the host via the app group `9F2JXY8TCK.group.robertcourson.skillz` (`$(TeamIdentifierPrefix)`-prefixed in both entitlements files).

## Build and test

From `skillz/` (directory containing `skillz.xcodeproj`):

```bash
xcodebuild -scheme skillz -destination 'platform=macOS' build
xcodebuild -scheme skillz -destination 'platform=macOS' test
```

- **Scheme:** `skillz`
- **Unit tests:** `skillzTests` — 100 `@Test` functions (frontmatter, catalog filter, **catalog sort + body search**, **selection resolve**, platform paths, source detection, bare-home-not-detected, agent engine, session-adapter liveness/id stability, process runner, hooks, startup hook policy, file service incl. **duplicate/copy-to-platform**, **editor metrics**, **toast center**, legacy notch layout/view-model, process exclusions, session dedup, discovery smoke, plus the **preview core**: settings codec/store/seeding, effective-settings master/per-type routing, file-type resolution, all nine highlighters, CSV→markdown table, markdown splitter, input caps + render-plan re-capping, plist conversion, image policy, font resolver, theme presets, pluginkit-output parse, editor view mode)
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

**Top bar** (full-width row above the split view, `.zIndex(1)` so its hairline masks inset-sidebar shadow bleed) is deliberately minimal:
- **Leading:** sidebar toggle only (glass icon group), inset from traffic lights via `SkillzWindowMetrics.trafficLightReservedWidth` (88pt); disabled while the Quick Look page is open.
- **Trailing:** search field (320pt; hidden while the Quick Look page is open).
- Sidebar uses `.toolbar(removing: .sidebarToggle)` — the custom toolbar button is the only sidebar control.
- **Global actions live in the sidebar's pinned bottom section** (`SidebarView.actions`): New Skill (posts `.skillzNewSkill`), Refresh Catalog, Quick Look Themes (posts `.skillzShowQuickLookThemes`; also in the View menu).
- **Skill actions live in the detail header** (`SkillDetailView.header`): Details / Rename / Delete post the existing notifications; Save calls `document.saveImmediately()` directly (prominent while dirty). The action HStack needs `.fixedSize()` or the capsules wrap when the description competes for width.

**Sidebar inset:** `NavigationSplitView` is pulled up by `SkillzWindowMetrics.sidebarTopInsetPull` (14pt) so the floating sidebar card sits evenly below the top-bar divider; do not remove the top-bar `zIndex` or the card shadow will overlap the hairline again.

### Catalog discovery

- **`DiscoveryEngine`** orchestrates `SkillScanner`, `MCPScanner`, `PluginScanner`.
- **`PlatformSkillPaths`** — per-platform scan roots; shared `~/.agents/skills` for Codex/Pi/OpenCode dedup via `alsoAvailableOn`.
- **`PlatformSourceDetector`** — centralized platform detection profiles; checks source folders, config files, shared `~/.agents/skills`, and known CLI locations; keeps shared skill sources separate from install signals; drives onboarding, settings, empty states, and “New Skill” defaults.
- **`CatalogFilter`** — section × platform × search × **sort** (`CatalogSortOrder`: name/date-modified/platform/type, stable tiebreak on name). Search also matches `SKILL.md` body when `searchSkillBodies` is on (`SkillItem.searchableBody`, indexed at scan time, length-capped + lowercased — no extra disk I/O). Sort menu + body-search toggle live in the `ItemListView` column header.
- **`CatalogSelection.resolve`** — shared "keep preferred / else first / else nil" selection rule used by `refresh` and `reloadCatalog`; last selection/section/platform/sort persist via `AppSettings` and restore on launch.
- Live rescan: `FSEventWatcher` + refresh on `NSApplication.didBecomeActive`.
- **List rows:** `PlatformBadge` + `EnabledBadge` (`.subtle` tag, next to platform pill) for plugins; `subtitleText` fallbacks with `.lineLimit(2, reservesSpace: true)` for uniform row height; `SkillzListRowChrome` animates hover/selection; shared-skill info button when applicable.

### Skill editing

- **`SkillFileService`** — create/rename/delete/**duplicate**/**copy-to-platform** under platform skill dirs; validates names via **`SkillNameValidator`**. `duplicateSkill`/`copySkill` copy the whole folder (multi-file skills) with `-copy` collision-free naming and rewrite the primary `SKILL.md` `name` frontmatter. Context-menu entries: Duplicate Skill, Copy to Platform (targets = detected platforms minus existing).
- **`FrontmatterParser` / `FrontmatterWriter`** — YAML frontmatter in `SKILL.md`.
- **`MarkdownEditorView` / `MarkdownTextView`** — `NSTextView`-backed monospaced editor (native Find bar, undo, line-wrap via `editorLineWrap`); font size from settings. The `updateNSView` text diff guards the SwiftUI⇄AppKit feedback loop — never push `document.text` unconditionally. Footer shows word/char count (`EditorMetrics`) + "Open in Editor".
- **Source | Rich Text toggle** — `EditorViewModeToggle` (two-segment pill in the editor footer) flips `editorPane` between `MarkdownEditorView` and **`MarkdownRichTextView`** (read-only: frontmatter metadata card + MarkdownUI body themed via the shared `SkillzMarkdownTheme`). Last-used mode persists globally (`AppSettings.editorViewMode` / `editorViewModeRaw`); the "Wrap" checkbox hides in rich mode. Rich mode never mutates `EditorDocument` — autosave/dirty/file-switch guards are untouched.

### Quick Look previews

| Piece | Path / type |
|-------|-------------|
| Shared engine | `SkillzPreviewCore/` — `PreviewFileType` (14 types), `PreviewTheme` presets (in-code hex palettes, light+dark per token, incl. `success` for diff additions), `PreviewTypeSettings` (+ forward-compatible codec), `PreviewSettingsStore` (app-group `UserDefaults`), `PreviewFontResolver` (per-type font family: System Mono/Sans/Serif sentinels or installed family name, missing fonts fall back to mono), `Highlighters/` (JSON/YAML/TOML/config-INI-env/diff/SQL/XML-plist/shell/log), `CSVTableConverter` (CSV→markdown table), `PlistRenderer` (binary→XML), `MarkdownDocumentSplitter`, `SkillzMarkdownTheme` (palette+font→MarkdownUI `Theme`; code spans stay mono unless a custom family is chosen), `PreviewContentView` (the renderer), `PreviewInputLoader` (1.5 MB / 5,000-line caps), `PreviewContentTypeIDs` (UTI source of truth) |
| Extension | `SkillzQuickLook/PreviewViewController.swift` — `QLPreviewingController` mounting `PreviewContentView` in `NSHostingView`; embedded into `Contents/PlugIns` via the app target's "Embed Foundation Extensions" phase |
| Settings UI | **Sidebar "Quick Look Themes" action** (pinned bottom section; also View menu) posts `.skillzShowQuickLookThemes`, which swaps the full window area below the top bar for `QuickLookSettingsPage` (`Views/`): file-type list left, per-type theme preset/font family+size/wrap/line-numbers/pretty-print/markdown-mode strip + large live sample (same `PreviewContentView`) right; header has extension status + "System Settings…" + "Reset Quick Look" + **"Test Preview"** (writes the selected type's sample to temp and opens the real `qlmanage -p` panel) via `QuickLookExtensionStatus`, and a Done button (Esc). `QuickLookExtensionStatus.bundleLocationIssue` warns under the header when the app runs translocated or outside /Applications (extension can't register there). Onboarding shows a Quick Look info card. Catalog-specific trailing top-bar controls (skill actions, Save, search) hide while the page is open. |
| Shared prefs | `9F2JXY8TCK.group.robertcourson.skillz` group defaults; `SkillzStartupConfigurator` seeds missing per-type blobs on launch (`PreviewSettingsStore.seedMissingDefaults`) |

Covered types: md/markdown, json, jsonl/ndjson, yaml/yml, toml, ini/conf/cfg/properties, env (named `*.env`; bare `.env` dotfiles have no path extension and never reach Quick Look), csv/tsv, log, diff/patch, sql, plist, xml, sh/zsh/bash/fish. The host `Info.plist` imports UTIs for jsonl/ndjson/toml/log/fish/ini/env/diff/sql; the extension's `QLSupportedContentTypes` is exact-match and must mirror `PreviewContentTypeIDs.swift`. Recent macOS reserves some types for built-in previews (e.g. json/jsonl/toml/csv on macOS 26) — Skillz theming applies wherever third-party previews are allowed (markdown + log everywhere).

**Optionality:** every type has a "Preview with Skills" switch (`PreviewTypeSettings.enabled`, default on — old blobs decode enabled) and the page header has a master switch (`PreviewSettingsStore.masterEnabled`). Off → the extension renders `PreviewTypeSettings.neutralFallback` (plain mono source, system colors, no transforms) via `PreviewSettingsStore.effectiveSettings(for:)`. **Do not "decline" previews with an error to fall back to the system previewer — Quick Look shows a generic icon instead (verified empirically on macOS 26).** True hand-back to macOS exists only per-extension: System Settings toggle, or deleting the app (removes the appex).

Remote images in rendered markdown are **blocked by default** (`MarkdownImageProviders.swift` — local-file-only providers; placeholders otherwise) so previewing untrusted files never touches the network. The per-markdown "Load remote images" setting opts into MarkdownUI's network providers; the extension carries `com.apple.security.network.client` solely for that opt-in. Transformed content is re-capped via `PreviewContentView.renderPlan` (pretty-printed JSON can amplify past the loader caps; CSV truncation folds into the footer flag).

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

General (appearance, hide built-in Cursor/Codex skills, inspector) · **Sources** (scan paths, rescan) · **Agents** (menu-bar waiting count, hook install status) · Editor (font size). Quick Look preview themes live in the main window (top-bar Quick Look page), not in the Settings window.

## Design system

- **Colors:** `Assets.xcassets` — `SkillzCanvas`, `SkillzInk`, `SkillzEmphasis`, `SkillzMuted`, `SkillzSectionLabel`, `SkillzHairline`, `SkillzSelection`.
- **Typography:** `SkillzTypography` — monospaced scale; primary UI text uses **`SkillzEmphasis`** (~#333), not pure black; editor uses `SkillzTypography.editor(size:)`.
- **Components:** `SkillzComponents.swift` (tags, glass search/toolbar groups, detail rows), `SkillzTextStyles` view modifiers. Transient success/info feedback uses `SkillzToast` + `ToastCenter.shared` (auto-dismissing, mounted as a second bottom overlay in `MainWindowView`); errors keep the explicit-dismiss `SkillzErrorBanner`.
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
- **SkillzPreviewCore is asset-free** — never reference `Color.skillz*` or other asset-catalog symbols there; the Quick Look target does not compile `Assets.xcassets`, so those symbols don't exist in it. Theme palettes are in-code hex (`PreviewTheme`).
- **QLSupportedContentTypes is exact-match** — no parent-conformance walk. The UTI lists in `SkillzQuickLook/Info.plist` and the host `UTImportedTypeDeclarations` must stay in sync with `PreviewContentTypeIDs.swift`.
- **App group sharing** — the app target sets `CODE_SIGN_ENTITLEMENTS = skillz/skillz.entitlements`; without it the non-sandboxed host writes `UserDefaults(suiteName:)` to `~/Library/Preferences` instead of the group container and the extension stops seeing settings. Keep the `$(TeamIdentifierPrefix)` prefix (macOS 15+ prompt avoidance).
- **System-reserved Quick Look types** — newer macOS keeps json/csv (and on macOS 26 also jsonl/toml) on its built-in previewer; don't chase "extension not used" bugs for those types before checking with `qlmanage -p` on the target OS.
- **Commits** — only when the user asks.
- **Third-party icons** — retain `ThirdParty/lobe-icons-LICENSE.txt` when updating Lobe assets.

## Editing conventions

- Match existing patterns: `@MainActor` stores, minimal diff, no over-abstraction.
- Prefer extending `SkillzTypography` / `SkillzTextStyles` over one-off fonts.
- Do not re-enable the legacy notch without an explicit product decision; runtime agent monitoring should stay independent of the dormant notch sources.
- Hook install paths are harness-specific — see `AgentHookInstaller` before changing notify wiring.
