#!/bin/sh
set -eu

RELEASE_DIR="${1:-dist/releases}"

if ! command -v generate_appcast >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Sparkle generate_appcast was not found.

Install Sparkle's tooling and rerun this script after creating a signed,
notarized, stapled, zipped Skills.app release artifact.
EOF
  exit 1
fi

if [ ! -d "$RELEASE_DIR" ]; then
  echo "Release directory not found: $RELEASE_DIR" >&2
  exit 1
fi

generate_appcast "$RELEASE_DIR" --output-dir docs
