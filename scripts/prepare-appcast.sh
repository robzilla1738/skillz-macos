#!/bin/sh
set -eu

RELEASE_DIR="${1:-dist/releases}"
APPCAST_PATH="${2:-docs/appcast.xml}"

GENERATE_APPCAST="$(command -v generate_appcast || true)"
if [ -z "$GENERATE_APPCAST" ]; then
  GENERATE_APPCAST="$(find . -path '*/SourcePackages/checkouts/Sparkle/bin/generate_appcast' -perm -111 2>/dev/null | head -1 || true)"
fi
if [ -z "$GENERATE_APPCAST" ]; then
  GENERATE_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' -perm -111 2>/dev/null | head -1 || true)"
fi
if [ -z "$GENERATE_APPCAST" ] && [ -x "/opt/homebrew/Caskroom/sparkle/latest/bin/generate_appcast" ]; then
  GENERATE_APPCAST="/opt/homebrew/Caskroom/sparkle/latest/bin/generate_appcast"
fi

if [ -z "$GENERATE_APPCAST" ]; then
  cat >&2 <<'EOF'
Sparkle generate_appcast was not found.

Resolve the Xcode package dependencies or install Sparkle's tooling, then rerun
this script after creating a signed, notarized, stapled Skills.app release
artifact.
EOF
  exit 1
fi

if [ ! -d "$RELEASE_DIR" ]; then
  echo "Release directory not found: $RELEASE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$APPCAST_PATH")"
if [ -n "${DOWNLOAD_URL_PREFIX:-}" ]; then
  "$GENERATE_APPCAST" --download-url-prefix "$DOWNLOAD_URL_PREFIX" --embed-release-notes -o "$APPCAST_PATH" "$RELEASE_DIR"
else
  "$GENERATE_APPCAST" --embed-release-notes -o "$APPCAST_PATH" "$RELEASE_DIR"
fi
