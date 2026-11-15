#!/usr/bin/env bash
# The scaffold plugin's skills and scripts exist and the plugin passes `claude plugin validate --strict`.
# The CLI isn't on every machine; CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
P="$ROOT/plugins/scaffold"
for s in governance new-repo adopt-repo licence reuse helper-repo warren-org warren-project; do
  [ -f "$P/skills/$s/SKILL.md" ] && ok "skill $s exists" || bad "skill $s exists"
done
for b in warren-new-repo warren-apply-governance warren-apply-ruleset warren-apply-topics warren-new-org-plugin; do
  [ -x "$P/bin/$b" ] && ok "bin/$b is executable" || bad "bin/$b is executable"
  grep -rqF "$b" "$P/skills" && ok "a skill names $b" || bad "a skill names $b"
done
for s in warren-org warren-project; do
  grep -q '^disable-model-invocation: true$' "$P/skills/$s/SKILL.md" && ok "$s is a menu skill" || bad "$s is a menu skill"
done
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip: claude CLI not installed"; finish; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$P" --strict 2>&1); rc=$?
expect 0 "scaffold plugin validates (--strict)"
finish
