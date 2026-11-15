#!/usr/bin/env bash
# SessionStart hook: warn when the current repo has a repo-local core.hooksPath, which makes
# git skip the global commit guard (husky re-sets it on npm install).
set -uo pipefail
cwd=$(jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$cwd" ] || cwd=$PWD
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
hp=$(git -C "$top" config --local --get core.hooksPath) || exit 0
msg="Commit guard bypassed in $top: repo-local core.hooksPath=$hp. Fix: git -C \"$top\" config guard.chainPath \"$hp\" && git -C \"$top\" config --unset core.hooksPath"
jq -n --arg m "$msg" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $m}}'
exit 0
