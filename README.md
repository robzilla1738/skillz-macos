# Skills

Skills is a macOS app for browsing, editing, and managing local agent harness assets: skills, MCP server configs, and plugins across Cursor, Claude Code, Codex, Hermes, Pi, and OpenClaw.

It also includes a menu bar monitor for live Cursor, Claude Code, and Codex session status, including waiting-agent counts for sessions that need input.

## Status

This repository is ready for public source use and Debug verification. Production signing, notarization, Sparkle signing, and release archive generation are intentionally not run from this repo by default.

## Requirements

- macOS 26.2+
- Xcode with the macOS 26.2 SDK or newer
- No app sandbox. Skills reads local agent folders such as `~/.cursor`, `~/.claude`, and `~/.codex`.

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
- installs or repairs the bundled notify hook script at `~/.skillz/bin/skillz-agent-notify.sh` when automatic hook repair is enabled
- merges Skills hooks into existing Claude Code and Codex hook configs without replacing existing hooks
- enables Codex hooks in `~/.codex/config.toml` when installing Codex hooks
- watches the Skills state file plus known Cursor, Claude Code, and Codex session directories
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
