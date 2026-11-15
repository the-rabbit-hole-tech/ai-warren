#!/usr/bin/env bash
# The secrets plugin validates, ships no MCP server and no literal or default server URL.
# The CLI isn't on every machine; CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
P="$ROOT/plugins/secrets"
[ ! -e "$P/.mcp.json" ] && ok "the plugin ships no MCP server" || bad "the plugin ships no MCP server"
if grep -rEq 'https?://[A-Za-z0-9]' "$P" --include='*.json' --include='*.md' --exclude-dir=.git; then
  out=$(grep -rEn 'https?://[A-Za-z0-9]' "$P" --include='*.json' --include='*.md'); bad "no literal URL in the plugin"
else ok "no literal URL in the plugin"; fi
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip: claude CLI not installed"; finish; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$P" --strict 2>&1); rc=$?
expect 0 "secrets plugin validates (--strict)"
finish
