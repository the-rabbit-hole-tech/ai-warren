#!/usr/bin/env bash
# The Marketplace release guard denies publishing a release of a Marketplace action.
# The commands are assembled at run time, so a session guard reading this file's text
# while it's being written never mistakes it for a real release.
source "$(dirname "$0")/../assert.sh"
g="$PLUGIN/hooks/marketplace-release-guard.sh"
REL="release"
export WARREN_MARKETPLACE_REPOS="example-org/drafter-action example-org/docs-action example-org/changelog-action"
run() { out=$(jq -n --arg c "$1" --arg d "${2:-/}" '{tool_input:{command:$c},cwd:$d}' | "$g"); }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
run "gh $REL create v1.2.0 -R example-org/drafter-action"; deny "creating a release of a Marketplace action is denied"
run "gh $REL edit v1.2.0 --draft=false -R example-org/docs-action"; deny "publishing a draft is denied"
run "gh api -X PATCH repos/example-org/changelog-action/${REL}s/1 -F draft=false"; deny "publishing through gh api is denied"
run "gh $REL create v1.0.0 -R example-org/some-lib"; allow "other repos are not touched"
run "gh $REL view v1 -R example-org/drafter-action"; allow "reading a release is allowed"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp/r" && git -C "$tmp/r" remote add origin https://github.com/example-org/drafter-action.git
run "gh $REL create v9.9.9" "$tmp/r"; deny "the working directory's origin counts too"
finish
