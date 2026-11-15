#!/usr/bin/env bash
# The always-on text stays short, and the SessionStart hook hands it over unchanged.
source "$(dirname "$0")/../assert.sh"
text="$PLUGIN/warren.md"
lines=$(grep -cv '^[[:space:]]*$' "$text")
chars=$(wc -c < "$text" | tr -d ' ')
[ "$lines" -le 8 ] && ok "warren.md has $lines non-blank lines (max 8)" || bad "warren.md has $lines non-blank lines (max 8)"
[ "$chars" -le 1700 ] && ok "warren.md has $chars characters (max 1,700)" || bad "warren.md has $chars characters (max 1,700)"
out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/hooks/inject-warren.sh"); rc=$?
expect 0 "inject-warren.sh runs"
event=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')
[ "$event" = SessionStart ] && ok "output names the SessionStart event" || bad "output names the SessionStart event"
if [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')" = "$(cat "$text")" ]; then
  ok "additionalContext equals warren.md"
else bad "additionalContext equals warren.md"; fi
finish
