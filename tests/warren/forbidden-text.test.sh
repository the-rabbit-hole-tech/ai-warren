#!/usr/bin/env bash
# block-ai-tells denies commit, issue and PR commands carrying an AI tell or emoji.
# The tells are assembled at run time so this file passes its own check.
source "$(dirname "$0")/../assert.sh"
g="$PLUGIN/hooks/block-ai-tells.sh"
run() { out=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$g"); }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
TRAILER="Co-""Authored-By: x <x@example.org>"
PHRASE="I hope this"" helps"
EMOJI=$(printf '\xf0\x9f\x9a\x80')
run "git commit -m 'feat: x' -m '$TRAILER'"; deny "attribution trailer in a commit is denied"
run "gh pr create -t 'feat: x' -b '$PHRASE'"; deny "filler phrase in a PR body is denied"
run "gh issue comment 3 -b 'done $EMOJI'"; deny "emoji in an issue comment is denied"
run "git commit -m 'feat(warren): add the guard'"; allow "a clean commit is allowed"
run "echo '$PHRASE'"; allow "commands that publish nothing are not checked"
[ -s "$PLUGIN/hooks/forbidden-text.txt" ] && ok "the pattern list ships with the plugin" || bad "the pattern list ships with the plugin"
finish
