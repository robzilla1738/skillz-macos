# App Updates

Skills uses Sparkle 2 for app updates. The app reads its feed URL and EdDSA public key from the app Info.plist.

The embedded Sparkle public key is:

```text
3LBPx8Uv5L5ptqRqdCWovmUIPLxcDEPnivy8cOpIlH8=
```

## Feed Location

Expected public feed URL after GitHub Pages is enabled:

```text
https://robzilla1738.github.io/skillz-macos/appcast.xml
```

The feed is checked in at `docs/appcast.xml` and is meant to be hosted through GitHub Pages.

## Production Release Checklist

1. Archive the `skillz` scheme with Developer ID signing.
2. Export the app.
3. Notarize and staple the exported app.
4. Create, sign, notarize, and staple the release DMG.
5. Sign the DMG enclosure with Sparkle EdDSA tooling.
6. Generate or update `docs/appcast.xml`.
7. Attach the DMG to a GitHub Release.
8. Enable or update GitHub Pages for the `docs/` folder.
9. Verify a previously installed production build can discover the appcast through **Check for Updates…**.

This repository does not run the production build or notarization steps automatically.

## Local Helper

`scripts/prepare-appcast.sh` verifies that Sparkle's `generate_appcast` tool is available, signs release enclosures, and copies the generated appcast into `docs/`. It is intentionally conservative and does not build or publish release artifacts.
