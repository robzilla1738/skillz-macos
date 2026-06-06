# Skills

Skills is a macOS app for browsing, editing, and managing local AI tool assets: skills, MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode.

It gives you one place to inspect and update the files these tools scatter across hidden folders, without making you remember every config path.

## Status

Skills ships as signed, notarized DMG releases with Sparkle auto-updates. CI verifies a Debug build and the unit test suite on every push; release archives are produced locally and attached to GitHub Releases.

## Requirements

- macOS 14.0+
- Xcode with the macOS 26.2 SDK or newer
- No app sandbox. Skills reads local agent folders such as `~/.cursor`, `~/.claude`, `~/.codex`, `~/.hermes`, `~/.pi`, `~/.openclaw`, and shared `~/.agents/skills`.

## Install

Skills ships as a signed, notarized DMG on the [Releases](https://github.com/robzilla1738/skillz-macos/releases) page (macOS 14.0+).

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/robzilla1738/skillz-macos/main/scripts/install.sh | bash
```

This downloads the latest release, verifies its Developer ID signature, installs `Skills.app` to `/Applications`, and launches it. On first run, click **Get Started** and choose the sources you want Skills to scan.

### Ask your coding agent

Paste this to Claude Code, Cursor, Codex, or any agent with shell access:

> Install the Skills macOS app for me. Run:
> `curl -fsSL https://raw.githubusercontent.com/robzilla1738/skillz-macos/main/scripts/install.sh | bash`
> Then confirm `Skills.app` is in `/Applications` and running. Tell me to click
> "Get Started" in the setup window so I can pick the local tool folders Skills
> should scan.

### Manual

Download the latest `Skills-macOS-vX.Y.Z.dmg` from [Releases](https://github.com/robzilla1738/skillz-macos/releases), open it, and drag **Skills** into **Applications**.

## Build

From the Xcode project directory:

```bash
cd skillz
xcodebuild -scheme skillz -destination 'platform=macOS' build
xcodebuild -scheme skillz -destination 'platform=macOS' -only-testing:skillzTests test
```

The shared scheme is checked in at `skillz/skillz.xcodeproj/xcshareddata/xcschemes/skillz.xcscheme`.

## Source Discovery

On launch, Skills:

- detects existing tool homes, skill sources, config files, shared `~/.agents/skills`, and known CLI locations
- keeps shared skill folders separate from install signals, so an old empty home folder does not look like a real setup
- scans Cursor `mcp.json`, Claude Code `.mcp.json`, and Codex `config.toml`
- finds plugin metadata where Cursor, Claude Code, and Codex expose it
- watches catalog paths for changes and refreshes when the app becomes active

## Quick Look Previews

Skills bundles a Quick Look extension, so Finder spacebar previews of agent artifacts — `md`, `json`, `jsonl`/`ndjson`, `yaml`, `toml`, `ini`/`conf`/`cfg`/`properties`, `env`, `csv`/`tsv`, `log`, `diff`/`patch`, `sql`, `plist`, `xml`, and shell scripts — render with themes you pick per file type on the **Quick Look Themes** page (bottom of the sidebar, or the View menu): Skillz mono, GitHub light/dark, terminal, plus **font family** (System Mono/Sans/Serif or any installed fixed-pitch font) and size, line numbers, wrap, JSON pretty-print, and rendered-vs-source markdown, all with a full-size live preview and a **Test Preview** button that opens a real Quick Look panel. Markdown previews render rich text with the YAML frontmatter shown as a highlighted block; diffs color added/removed lines.

The extension registers after the app launches once; manage it under **System Settings → General → Login Items & Extensions → Quick Look**. Recent macOS versions reserve a few types (such as JSON and CSV) for the built-in previewer — Skills theming applies wherever third-party previews are allowed.

Everything is optional: each type has a **Preview with Skills** switch (off → a plain, system-style preview), and one master switch turns all theming off. To remove the previews entirely, toggle the extension off in System Settings → Login Items & Extensions → Quick Look, or just delete the app — the extension is removed with it.

Remote images in markdown previews are off by default for privacy (they render as placeholders); flip **Load remote images** on the markdown type if you want them fetched.

In the app itself, the markdown editor gains a **Source | Rich Text** toggle in the footer of every editor pane.

## Updates

The app updates itself through Sparkle 2. The appcast is hosted through GitHub Pages at `https://robzilla1738.github.io/skillz-macos/appcast.xml`:

- `docs/appcast.xml`
- `docs/UPDATES.md`
- `scripts/prepare-appcast.sh`

Production update publishing still requires a signed and notarized app archive. Do not publish unsigned local Debug builds to the appcast.

## CI

GitHub Actions runs Debug build and unit tests on the macOS 26 runner:

```text
.github/workflows/ci.yml
```

## License

No project license has been selected yet. Third-party Lobe icon assets retain their MIT license in `skillz/skillz/ThirdParty/lobe-icons-LICENSE.txt`.
