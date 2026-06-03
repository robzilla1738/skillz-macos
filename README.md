# Skills

Skills is a macOS app for browsing, editing, and managing local agent harness assets: skills, MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode.

It also includes a menu bar monitor for live Cursor, Claude Code, Codex, Hermes, Pi, and OpenCode activity. Cursor, Claude Code, and Codex support precise waiting-state hooks; Hermes, Pi, and OpenCode use process detection until stable hook configs are available.

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

This downloads the latest release, verifies its Developer ID signature, installs `Skills.app` to `/Applications`, and launches it. On first run, leave **Install or repair hooks automatically** enabled and click **Get Started** — Skills sets up live-activity hooks for every supported tool it detects.

### Ask your coding agent

Paste this to Claude Code, Cursor, Codex, or any agent with shell access:

> Install the Skills macOS app for me. Run:
> `curl -fsSL https://raw.githubusercontent.com/robzilla1738/skillz-macos/main/scripts/install.sh | bash`
> Then confirm `Skills.app` is in `/Applications` and running. Skills configures
> the agent hooks itself on first launch, so just tell me to click "Get Started"
> in its setup window to finish wiring up my tools.

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

## Agent Detection

On launch, Skills:

- creates its application support state file if needed
- detects existing agent homes, skill sources, config files, shared `~/.agents/skills`, and known CLI locations without treating shared skill folders as installed apps
- after onboarding, installs or repairs the bundled notify hook script at `~/.skillz/bin/skillz-agent-notify.sh` when automatic hook repair is enabled
- merges Skills hooks into existing Cursor, Claude Code, and Codex hook configs without replacing existing hooks
- enables Codex hooks in `~/.codex/config.toml` when installing Codex hooks
- watches the Skills state file plus known Cursor, Claude Code, and Codex session directories
- uses process detection for Hermes, Pi, OpenCode, and fallback active-session detection
- polls every five seconds as a fallback

The state file lives at:

```text
~/Library/Application Support/Skillz/agent-state.json
```

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
