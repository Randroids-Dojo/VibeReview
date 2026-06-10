#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/build"

cd "$PROJECT_DIR"
xcodegen generate
xcodebuild -scheme VibeReview \
  -configuration Debug \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

CLI_SOURCE="${BUILD_DIR}/vibereview"
CLI_DEST="${BUILD_DIR}/VibeReview.app/Contents/MacOS/vibereview"
APP_PLIST="${BUILD_DIR}/VibeReview.app/Contents/Info.plist"
APP_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PLIST")"
APP_EXECUTABLE_PATH="${BUILD_DIR}/VibeReview.app/Contents/MacOS/${APP_EXECUTABLE}"
if [[ ! -x "$CLI_SOURCE" ]]; then
  echo "Expected CLI executable was not built at ${CLI_SOURCE}" >&2
  exit 1
fi
APP_EXECUTABLE_LOWER="$(printf '%s' "$APP_EXECUTABLE" | tr '[:upper:]' '[:lower:]')"
if [[ "$APP_EXECUTABLE_LOWER" == "vibereview" ]]; then
  echo "App executable ${APP_EXECUTABLE} conflicts with bundled CLI name vibereview on case-insensitive filesystems." >&2
  exit 1
fi
ditto "$CLI_SOURCE" "$CLI_DEST"
if [[ ! -x "$APP_EXECUTABLE_PATH" || ! -x "$CLI_DEST" ]]; then
  echo "Expected both app executable and bundled CLI to exist after bundling." >&2
  exit 1
fi
if cmp -s "$APP_EXECUTABLE_PATH" "$CLI_DEST"; then
  echo "Bundled CLI unexpectedly overwrote the app executable." >&2
  exit 1
fi

echo "BUILD SUCCESS"
echo "App location: ${BUILD_DIR}/VibeReview.app"
echo "CLI location: ${CLI_DEST}"
