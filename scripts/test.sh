#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
xcodegen generate
xcodebuild test \
  -scheme VibeReview \
  -destination 'platform=macOS' \
  -only-testing:VibeReviewTests \
  CODE_SIGNING_ALLOWED=NO

echo "UNIT TESTS PASSED"
