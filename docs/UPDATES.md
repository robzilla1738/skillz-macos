# App Updates

Skills uses Sparkle 2 for app updates. The app reads its feed URL and EdDSA public key from the app Info.plist.

The embedded Sparkle public key is:

```text
3LBPx8Uv5L5ptqRqdCWovmUIPLxcDEPnivy8cOpIlH8=
```

## Feed Location

Public feed URL, served by GitHub Pages from the `docs/` folder:

```text
https://robzilla1738.github.io/skillz-macos/appcast.xml
```

The feed is checked in at `docs/appcast.xml`.

## Production Release Checklist

1. Archive the `skillz` scheme with Developer ID signing.
2. Export the app.
3. Spot-check the embedded Quick Look extension before notarizing: `codesign -d --entitlements - Skills.app/Contents/PlugIns/SkillzQuickLook.appex` must show the app sandbox, hardened runtime, and the `9F2JXY8TCK.group.robertcourson.skillz` app group (Automatic signing handles nested code, but verify).
4. Notarize and staple the exported app.
5. Create, sign, notarize, and staple the release DMG.
6. Sign the DMG enclosure with Sparkle EdDSA tooling.
7. Generate or update `docs/appcast.xml`.
8. Attach the DMG to a GitHub Release.
9. Push the updated `docs/appcast.xml` so GitHub Pages serves it.
10. Verify a previously installed production build can discover the appcast through **Check for Updates…**.

Sparkle updates replace the whole app bundle, including `Contents/PlugIns/SkillzQuickLook.appex` — no extra publishing steps for the Quick Look extension.

This repository does not run the production build or notarization steps automatically.

## Local Helper

`scripts/prepare-appcast.sh` verifies that Sparkle's `generate_appcast` tool is available, signs release enclosures, and copies the generated appcast into `docs/`. It is intentionally conservative and does not build or publish release artifacts.
