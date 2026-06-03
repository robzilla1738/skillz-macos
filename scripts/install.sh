#!/bin/sh
# Skills installer — downloads the latest notarized release DMG and installs it to /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/robzilla1738/skillz-macos/main/scripts/install.sh | bash
#
# Env overrides: SKILLS_REPO (owner/name), SKILLS_NO_OPEN=1 (skip launching the app).
set -eu

REPO="${SKILLS_REPO:-robzilla1738/skillz-macos}"
APP_NAME="Skills.app"
DEST="/Applications/${APP_NAME}"
EXPECTED_TEAM_ID="9F2JXY8TCK"
MIN_MAJOR=26

say()  { printf '\033[1m▸ %s\033[0m\n' "$1"; }
warn() { printf '\033[33m! %s\033[0m\n' "$1" >&2; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Skills is a macOS app."

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "${MAJOR:-0}" -lt "$MIN_MAJOR" ] 2>/dev/null; then
  warn "Skills needs macOS ${MIN_MAJOR}.2 or later (you're on $(sw_vers -productVersion)). It may not launch."
fi

say "Finding the latest Skills release…"
API="https://api.github.com/repos/${REPO}/releases/latest"
DMG_URL="$(curl -fsSL "$API" \
  | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+\.dmg"' \
  | head -1 \
  | sed -E 's/.*"(https[^"]+)"/\1/')"
[ -n "$DMG_URL" ] || fail "Could not find a .dmg asset in the latest release of ${REPO}."

WORK="$(mktemp -d "${TMPDIR:-/tmp}/skills-install.XXXXXX")"
MNT="${WORK}/mnt"
DMG="${WORK}/Skills.dmg"
cleanup() {
  [ -d "$MNT" ] && hdiutil detach "$MNT" -quiet >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM

say "Downloading $(basename "$DMG_URL")…"
curl -fSL --progress-bar -o "$DMG" "$DMG_URL" || fail "Download failed."

say "Mounting…"
mkdir -p "$MNT"
hdiutil attach "$DMG" -nobrowse -quiet -mountpoint "$MNT" || fail "Could not mount the disk image."
[ -d "${MNT}/${APP_NAME}" ] || fail "${APP_NAME} was not found inside the disk image."

if [ -e "$DEST" ]; then
  say "Replacing the existing ${APP_NAME}…"
  rm -rf "$DEST" || fail "Could not remove ${DEST}. Quit Skills, or retry with: sudo rm -rf '${DEST}'"
fi

say "Installing to /Applications…"
cp -R "${MNT}/${APP_NAME}" "$DEST" || fail "Could not copy into /Applications."

# Clear extended attributes so the first Finder launch is prompt-free. The release
# is notarized, so Gatekeeper accepts it either way — this is just polish. `xattr -r`
# isn't available on every macOS version, so recurse with find instead.
/usr/bin/find "$DEST" -exec /usr/bin/xattr -c {} + 2>/dev/null || true

say "Verifying signature…"
spctl -a -t exec -vv "$DEST" >/dev/null 2>&1 || fail "Gatekeeper rejected the app; not launching it."
TEAM="$(codesign -dv --verbose=2 "$DEST" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
[ "$TEAM" = "$EXPECTED_TEAM_ID" ] || fail "Unexpected signing team (${TEAM:-none}); aborting."

if [ "${SKILLS_NO_OPEN:-0}" != "1" ]; then
  say "Launching Skills…"
  open "$DEST"
fi

cat <<'DONE'

✓ Skills is installed in /Applications.

On first run, leave "Install or repair hooks automatically" enabled and click
"Get Started" — Skills sets up live-activity hooks for every supported agent
tool it detects (Cursor, Claude Code, Codex) and starts watching the rest.
DONE
