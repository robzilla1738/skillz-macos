# Skills

Skills is a macOS app for browsing, editing, and managing local AI tool assets: skills, MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode.

It gives you one place to inspect and update the files these tools scatter across hidden folders, without making you remember every config path.

## Status

This repository is ready for public source use and Debug verification. Production signing, notarization, Sparkle signing, and release archive generation are intentionally not run from this repo by default.

## Requirements

- macOS 26.2+
- Xcode with the macOS 26.2 SDK or newer
- No app sandbox. Skills reads local agent folders such as `~/.cursor`, `~/.claude`, `~/.codex`, `~/.hermes`, `~/.pi`, `~/.openclaw`, and shared `~/.agents/skills`.

## Install

Skills ships as a signed, notarized DMG on the [Releases](https://github.com/robzilla1738/skillz-macos/releases) page (macOS 26.2+).

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

## Updates

The repository is prepared for app-update hosting through GitHub Pages and a Sparkle-compatible appcast placeholder:

- `docs/appcast.xml`
- `docs/UPDATES.md`
- `scripts/prepare-appcast.sh`

Production update publishing still requires a signed and notarized app archive plus a real Sparkle EdDSA key. Do not publish unsigned local Debug builds to the appcast.

## CI

GitHub Actions runs Debug build and unit tests on the macOS 26 runner:

```text
.github/workflows/ci.yml
```

## License

No project license has been selected yet. Third-party Lobe icon assets retain their MIT license in `skillz/skillz/ThirdParty/lobe-icons-LICENSE.txt`.
