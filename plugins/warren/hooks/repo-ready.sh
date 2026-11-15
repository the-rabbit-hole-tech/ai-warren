#!/usr/bin/env bash
# SessionStart hook: tells the session when the owner's rules for its repo are not loaded. No org
# plugin at all is a note (the base rules still apply); an installed but disabled one is a stop. A
# repo with no plugin list of its own is fine. Advisory only: nothing is blocked. WARREN_ENFORCE=off silences it (default is warn).
set -uo pipefail
[ "${WARREN_ENFORCE:-warn}" = off ] && exit 0
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
cwd=$(jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$cwd" ] || cwd=$PWD
status=$("$root/bin/warren-repo-ready" "$cwd") || exit 0
case "$status" in not-set-up:*) ;; *) exit 0 ;; esac
reason=${status#not-set-up:}
remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || true)
owner=""
if [[ "$remote" =~ github\.com[:/]+([^/]+)/ ]]; then
  owner=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
fi
if [ "$reason" = disabled ]; then
  ctx="The org plugin for this repo's owner (${owner:-unknown}) is installed but disabled, so its rules are not loaded. Stop and enable it (/warren:menu), then continue."
else
  ctx="No org plugin for this repo's owner (${owner:-unknown}) is installed: the base warren rules still apply, and the owner's own rules are not loaded. To add them, see /warren:menu."
fi
jq -n --arg c "$ctx" --arg m "$ctx" \
  '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
exit 0
