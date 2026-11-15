#!/usr/bin/env bash
# Install __SCRIPT_NAME__.sh into the Claude config dir (~/.claude) and print the
# settings.json snippet that turns it on. settings.json is never edited here:
# it holds the user's own choices, so the change stays theirs to paste.
set -euo pipefail

SCRIPT="__SCRIPT_NAME__.sh"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CONFIG_DIR/hooks/$SCRIPT"

command -v jq >/dev/null 2>&1 || echo "warning: jq is not on PATH; $SCRIPT needs it at run time." >&2

mkdir -p "$(dirname "$DEST")"
cp "$HERE/$SCRIPT" "$DEST"
chmod +x "$DEST"
echo "Installed $DEST"
echo
echo "To turn it on, add this to $CONFIG_DIR/settings.json:"
echo
cat <<EOF
  "statusLine": { "type": "command", "command": "$DEST" }
EOF
