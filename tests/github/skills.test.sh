#!/usr/bin/env bash
# The github plugin ships every expected skill and passes `claude plugin validate --strict`.
# The CLI isn't on every machine; CI sets WARREN_REQUIRE_CLAUDE=1 so a missing CLI fails there.
source "$(dirname "$0")/../assert.sh"
G="$ROOT/plugins/github"
for s in file-issue branch open-pr voice approve-merge ci cleanup repo-metadata profiles release release-cut release-tracking warren-release; do
  [ -f "$G/skills/$s/SKILL.md" ] && ok "skill $s exists" || bad "skill $s exists"
done
jq -r .version "$G/.claude-plugin/plugin.json"  | grep -Eq "^[0-9]+\.[0-9]+\.[0-9]+$" && ok "plugin version is semver" || bad "plugin version is semver"
if ! command -v claude >/dev/null 2>&1; then
  if [ "${WARREN_REQUIRE_CLAUDE:-0}" = 1 ]; then bad "claude CLI is installed"; finish; fi
  echo "skip: claude CLI not installed (validate)"; finish; exit 0
fi
cfg=$(mktmp); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
out=$(claude plugin validate "$G" --strict 2>&1); rc=$?
expect 0 "github plugin validates (--strict)"
finish
