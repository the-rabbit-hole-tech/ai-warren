#!/usr/bin/env bash
# PreToolUse(Bash) guard: Marketplace action releases are published by a person
# in the browser (the Marketplace checkbox only exists there), never by Claude.
# Blocks creating or publishing a release in those repos, whether the repo is
# named in the command or is the working directory's origin.

set -uo pipefail

# The protected repos come from the environment: WARREN_MARKETPLACE_REPOS, a space-separated
# list of <owner>/<repo>. Empty or unset protects nothing (an org plugin sets it).
read -ra MARKETPLACE_REPOS <<<"${WARREN_MARKETPLACE_REPOS:-}"
[ "${#MARKETPLACE_REPOS[@]}" -gt 0 ] || exit 0

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty')
[ -n "$cmd" ] || exit 0

publishes=0
if printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+release[[:space:]]+create'; then
  publishes=1
elif printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+release[[:space:]]+edit' &&
     printf '%s' "$cmd" | grep -Eq -- '--draft(=|[[:space:]]+)false'; then
  publishes=1
elif printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+api' &&
     printf '%s' "$cmd" | grep -Eq 'releases' &&
     printf '%s' "$cmd" | grep -Eiq 'draft[^[:alnum:]]*=?[[:space:]]*false'; then
  publishes=1
fi
[ "$publishes" -eq 1 ] || exit 0

origin=""
if [ -n "$cwd" ]; then
  origin=$(git -C "$cwd" remote get-url origin 2>/dev/null || true)
fi

hit=""
for r in "${MARKETPLACE_REPOS[@]}"; do
  if printf '%s\n%s' "$cmd" "$origin" | grep -Fiq "$r"; then
    hit=$r
    break
  fi
done
[ -n "$hit" ] || exit 0

reason="$hit is a Marketplace action: its releases are published only by a person. Prepare the draft, notes and major-tag commands, then ask with exactly two options: Open Browser (open the draft release page) or Wait."
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
