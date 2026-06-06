#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="VibeReview"
APP_BUNDLE_ID="com.randroid.VibeReview"
APP_PATH="$PROJECT_DIR/build/${APP_NAME}.app"

"$PROJECT_DIR/scripts/build.sh"

osascript -e "tell application id \"${APP_BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true

for _ in {1..50}; do
  if ! pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.1
done

if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -x "$APP_NAME" || true
  sleep 0.3
fi

open "$APP_PATH"
