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

echo "BUILD SUCCESS"
echo "App location: ${BUILD_DIR}/VibeReview.app"
