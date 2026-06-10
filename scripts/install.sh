#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_APP="${PROJECT_DIR}/build/VibeReview.app"
INSTALL_APP="/Applications/VibeReview.app"
CLI_SHIM="/usr/local/bin/vibereview"
CLI_TARGET="${INSTALL_APP}/Contents/MacOS/vibereview"

"${PROJECT_DIR}/scripts/build.sh"

install_commands=$(
  cat <<COMMANDS
set -euo pipefail
mkdir -p /usr/local/bin
rm -rf "${INSTALL_APP}"
ditto "${SOURCE_APP}" "${INSTALL_APP}"
ln -sf "${CLI_TARGET}" "${CLI_SHIM}"
COMMANDS
)

if [[ -w "/Applications" && ( -w "/usr/local/bin" || ! -e "/usr/local/bin" && -w "/usr/local" ) ]]; then
  /bin/bash -c "$install_commands"
else
  escaped=${install_commands//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  osascript -e "do shell script \"$escaped\" with administrator privileges"
fi

echo "INSTALL SUCCESS"
echo "App location: ${INSTALL_APP}"
echo "CLI shim: ${CLI_SHIM}"
