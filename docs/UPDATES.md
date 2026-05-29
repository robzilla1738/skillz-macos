# App Updates

Skills is structured to use a Sparkle-style appcast hosted from GitHub Pages once production signing is ready.

## Feed Location

Expected public feed URL after GitHub Pages is enabled:

```text
https://robzilla1738.github.io/skillz-macos/appcast.xml
```

The placeholder feed is checked in at `docs/appcast.xml`.

## Production Release Checklist

1. Archive the `skillz` scheme with Developer ID signing.
2. Export the app.
3. Notarize and staple the exported app.
4. Zip the stapled `Skills.app`.
5. Sign the zip with Sparkle EdDSA tooling.
6. Generate or update `docs/appcast.xml`.
7. Attach the zip to a GitHub Release.
8. Enable or update GitHub Pages for the `docs/` folder.
9. Verify a previously installed production build can discover the appcast.

This repository does not run the production build or notarization steps automatically.

## Local Helper

`scripts/prepare-appcast.sh` verifies that Sparkle's `generate_appcast` tool is available and shows the expected command. It is intentionally conservative and does not build or publish release artifacts.
