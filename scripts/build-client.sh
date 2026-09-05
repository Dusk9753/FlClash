#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
TARGET="${1:-android}"
ARCH="${ANDROID_ARCH:-arm64}"
ENVIRONMENT="${APP_ENV:-pre}"

cd "$ROOT_DIR"
export PATH="$(dirname "$(command -v "$FLUTTER_BIN")"):$PATH"

case "$TARGET" in
  android)
    "$FLUTTER_BIN" pub get
    dart setup.dart android --arch "$ARCH" --env "$ENVIRONMENT" -v
    ;;
  windows)
    "$FLUTTER_BIN" pub get
    dart setup.dart windows --env "$ENVIRONMENT" -v
    ;;
  *)
    printf 'Usage: %s {android|windows}\n' "$0" >&2
    exit 2
    ;;
esac

printf '\nBuild artifacts:\n'
if [[ -d dist ]]; then
  find dist -maxdepth 1 -type f -printf '%f\n' | sort
else
  printf 'dist directory was not created\n' >&2
  exit 1
fi
