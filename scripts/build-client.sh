#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
TARGET="${1:-android}"
ARCH="${ANDROID_ARCH:-arm64}"
ENVIRONMENT="${APP_ENV:-pre}"

cd "$ROOT_DIR"
export PATH="$(dirname "$(command -v "$FLUTTER_BIN")"):$PATH"
mkdir -p dist

case "$TARGET" in
  android)
    "$FLUTTER_BIN" pub get
    case "$ARCH" in
      arm64) ABI="android-arm64" ;;
      arm) ABI="android-arm" ;;
      amd64) ABI="android-x64" ;;
      *) printf 'Unsupported Android ABI: %s\n' "$ARCH" >&2; exit 2 ;;
    esac
    "$FLUTTER_BIN" build apk --release --split-per-abi --target-platform "$ABI" \
      --dart-define=APP_ENV="$ENVIRONMENT"
    cp build/app/outputs/flutter-apk/app-"$ABI"-release.apk \
      dist/xiaohuojian-android-"$ARCH".apk
    ;;
  windows)
    "$FLUTTER_BIN" pub get
    "$FLUTTER_BIN" build windows --release --dart-define=APP_ENV="$ENVIRONMENT"
    if command -v zip >/dev/null 2>&1; then
      (cd build/windows/x64/runner && zip -qr "$ROOT_DIR/dist/xiaohuojian-windows-amd64.zip" Release)
    else
      powershell -NoProfile -Command "Compress-Archive -Path build/windows/x64/runner/Release -DestinationPath dist/xiaohuojian-windows-amd64.zip -Force"
    fi
    ;;
  *)
    printf 'Usage: %s {android|windows}\n' "$0" >&2
    exit 2
    ;;
esac

printf '\nBuild artifacts:\n'
find dist -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
