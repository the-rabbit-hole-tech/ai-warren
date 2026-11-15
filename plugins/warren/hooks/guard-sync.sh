#!/usr/bin/env bash
# SessionStart hook: keeps the git guard copy at its stable path in step with this plugin
# version (bin/warren-guard-sync), and says so in the session when git isn't running it.
set -uo pipefail
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
cat >/dev/null
out=$("$root/bin/warren-guard-sync" --quiet 2>&1); rc=$?
case "$rc" in
  0|3) exit 0 ;;
esac
msg="warren guard: ${out//$'\n'/ }"
jq -n --arg m "$msg" '{systemMessage:$m, hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$m}}'
exit 0
