#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# Warns, never blocks, when a command hand-rolls a merge loop: a while, for or until loop with
# `gh pr merge` and `sleep` in it. warren:scripts merge-green.sh does that job and checks the real
# merge state.
set -uo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

printf '%s' "$cmd" | grep -Eq '(^|[;&|({[:space:]])(while|for|until)[[:space:]]' || exit 0
printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' || exit 0
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])sleep[[:space:]]' || exit 0

msg="Don't hand-roll a merge loop: use warren:scripts merge-green.sh (it checks the real merge state)."
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
