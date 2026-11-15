#!/usr/bin/env bash
# The design plugin ships its skills and passes `claude plugin validate --strict`.
# The CLI isn't on every machine; CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
P="$ROOT/plugins/design"
[ "$(jq -r .name "$P/.claude-plugin/plugin.json")" = design ] && ok "plugin is named design" || bad "plugin is named design"
[ "$(jq -r .version "$P/.claude-plugin/plugin.json")" = 1.0.0 ] && ok "plugin version is 1.0.0" || bad "plugin version is 1.0.0"
for s in brainstorm plans section-review design-session new-ui; do
  f="$P/skills/$s/SKILL.md"
  if [ -f "$f" ] && [ "$(sed -n 2p "$f")" = "name: $s" ] && grep -q '^description: Use when' "$f"; then
    ok "skill $s exists with name and description"
  else bad "skill $s exists with name and description"; fi
done
n=$(find "$P/skills" -name SKILL.md | wc -l | tr -d ' ')
[ "$n" = 5 ] && ok "exactly five skills" || bad "exactly five skills (got $n)"
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip: claude CLI not installed"; finish; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$P" --strict 2>&1); rc=$?
expect 0 "plugin design validates (--strict)"
finish
