#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CLI_PATH="${PROJECT_DIR}/build/VibeReview.app/Contents/MacOS/vibereview"

if [[ ! -x "$CLI_PATH" ]]; then
  "${PROJECT_DIR}/scripts/build.sh"
fi

exec "$CLI_PATH" "$@"
