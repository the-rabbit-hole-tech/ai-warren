#!/usr/bin/env bash
# validate-conventional-commit denies commit, issue and PR titles that aren't Conventional Commits.
source "$(dirname "$0")/../assert.sh"
g="$PLUGIN/hooks/validate-conventional-commit.sh"
run() { out=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$g"); }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
run "git commit -m 'added stuff'"; deny "a free-form commit title is denied"
run "gh pr create --title 'Update readme' --body x"; deny "a free-form PR title is denied"
run "gh issue create -t 'feature: x'"; deny "an unknown type is denied"
run "git commit -m 'fix(guard): fail closed without an identity'"; allow "a Conventional Commit is allowed"
run "gh pr create -t 'feat!: drop the old path'"; allow "a breaking marker is allowed"
run "git status"; allow "other commands are not checked"
finish
