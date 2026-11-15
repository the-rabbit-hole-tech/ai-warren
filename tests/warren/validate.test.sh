#!/usr/bin/env bash
# The marketplace and every plugin pass `claude plugin validate --strict`.
# The CLI isn't on every machine; CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip: claude CLI not installed"; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$ROOT" --strict 2>&1); rc=$?
expect 0 "marketplace validates (--strict)"
for p in "$ROOT"/plugins/*/; do
  out=$(claude plugin validate "$p" --strict 2>&1); rc=$?
  expect 0 "plugin $(basename "$p") validates (--strict)"
done
plugins=$(jq -r '.plugins[].name' "$ROOT/.claude-plugin/marketplace.json" | tr '\n' ' ')
want="warren github coding operator design handoff scaffold secrets "
[ "$plugins" = "$want" ] && ok "the marketplace lists the warren plugin and the phase 2 plugins" || bad "the marketplace lists the phase 2 plugins (got: $plugins)"
for name in $plugins; do
  src=$(jq -r --arg n "$name" '.plugins[] | select(.name == $n) | .source' "$ROOT/.claude-plugin/marketplace.json")
  [ "$src" = "./plugins/$name" ] && ok "$name points at ./plugins/$name" || bad "$name points at ./plugins/$name (got: $src)"
done
[ "$(jq -r .name "$ROOT/.claude-plugin/marketplace.json")" = ai-warren ] && ok "the marketplace is named ai-warren" || bad "the marketplace is named ai-warren"
finish
