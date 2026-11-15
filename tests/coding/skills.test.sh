#!/usr/bin/env bash
# The coding plugin has every expected skill and passes `claude plugin validate --strict`.
# CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
CODING="$ROOT/plugins/coding"
for s in test-first discipline docs logging health readme ui packages porting lang-go lang-node lang-helm lang-shell lang-swift; do
  f="$CODING/skills/$s/SKILL.md"
  if [ -f "$f" ] && [ "$(sed -n 's/^name: //p' "$f" | head -1)" = "$s" ]; then ok "skill $s exists"; else bad "skill $s exists with name: $s"; fi
done
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip validate: claude CLI not installed"; finish; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$CODING" --strict 2>&1); rc=$?
expect 0 "plugin coding validates (--strict)"
finish
