#!/usr/bin/env bash
# The skill-first gate: the Skill PostToolUse hook records, the Bash PreToolUse hook denies until
# the session has loaded the skill for the command. HOME and CLAUDE_CONFIG_DIR are throwaway, with
# fake installed skills under the plugin cache.
source "$(dirname "$0")/../assert.sh"
rec="$PLUGIN/hooks/skill-record.sh"
gate="$PLUGIN/hooks/skill-gate.sh"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" CLAUDE_CONFIG_DIR="$tmp/home/.claude"; mkdir -p "$HOME"
unset CLAUDE_PLUGIN_ROOT
for s in github/work github/merge github/repos github/open-pr github/approve-merge github/file-issue github/repo-metadata operator/sessions; do
  mkdir -p "$CLAUDE_CONFIG_DIR/plugins/cache/mk/${s%/*}/1.0.0/skills/${s#*/}"; : > "$CLAUDE_CONFIG_DIR/plugins/cache/mk/${s%/*}/1.0.0/skills/${s#*/}/SKILL.md"
done
S="$HOME/.claude/warren/skills-loaded"

cmd() { jq -n --arg c "$1" --arg s "${2:-sess1}" '{session_id:$s,tool_input:{command:$c}}' | "$gate"; }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; echo "$out"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
load() { jq -n --arg s "$2" --arg k "$1" '{session_id:$s,tool_name:"Skill",tool_input:{skill:$k}}' | "$rec"; }

out=$(cmd 'gh pr create -R o/r --title x'); deny "gh pr create is denied before the skill is loaded"
has "Load skill github:work first" "the deny names the skill"
out=$(cmd 'gh pr merge 5 -R o/r'); has "Load skill github:merge first" "a merge needs approve-merge"
out=$(cmd 'gh issue create -R o/r --title x'); has "Load skill github:work first" "an issue create needs file-issue"
out=$(cmd 'gh repo edit o/r --add-topic go'); has "Load skill github:repos first" "a repo edit needs repo-metadata"
out=$(cmd 'tmux kill-window -t work:2'); has "Load skill operator:sessions first" "a tmux kill needs operator:sessions"
out=$(cmd 'tmux new-window -n x'); deny "tmux new-window is gated"
out=$(cmd 'cd /tmp && gh pr ready 5 -R o/r'); deny "a command in a chain is gated"
out=$(cmd 'gh pr create -R o/r --title x' sess3); deny "alternatives: denied before either name is loaded"
load github:work sess3; out=$(cmd 'gh pr create -R o/r --title x' sess3); allow "alternatives: the new name github:work passes"
out=$(cmd 'gh release create v1 -R o/r'); allow "a skill that is not installed is not required (github:release)"

load github:open-pr sess1; [ -f "$S/sess1/github:open-pr" ] && ok "the Skill hook writes a per-session marker" || bad "the Skill hook writes a per-session marker"
out=$(cmd 'gh pr create -R o/r --title x'); allow "the command passes once the skill is loaded"
out=$(cmd 'gh pr create -R o/r --title x' sess2); deny "another session does not inherit the marker"
out=$(cmd 'gh pr merge 5 -R o/r'); deny "one skill does not cover another command"

out=$(cmd 'gh pr view 5 -R o/r'); allow "gh pr view is not gated"
out=$(cmd 'gh api repos/o/r/issues'); allow "gh api is not gated"
out=$(cmd 'python3 _site/page.py publish x'); allow "page.py is not gated"
out=$(cmd 'curl -s http://localhost:5390/x'); allow "curl to the hand-off site is not gated"
out=$(cmd 'echo gh pr create'); allow "text that only mentions the command is allowed"
out=$(cmd 'tmux list-windows'); allow "other tmux commands are allowed"
out=$(printf 'not json' | "$gate"); allow "malformed input to the gate is allowed"
out=$(printf '{"tool_input":{"command":"gh pr create"}}' | "$gate"); allow "a payload with no session id is allowed"
out=$(printf 'not json' | "$rec"); allow "malformed input to the recorder is allowed"
out=$(jq -n '{session_id:"../x",tool_input:{skill:"a:b"}}' | "$rec"); allow "an unsafe session id is ignored"
[ ! -e "$HOME/.claude/warren/x" ] && ok "nothing is written outside the state folder" || bad "path escape"
# every skill the table names exists in this marketplace
while IFS=$'\t' read -r rx sk; do
  case "$rx" in ""|\#*) continue ;; esac
  for one in ${sk//|/ }; do
    [ -f "$ROOT/plugins/${one%%:*}/skills/${one#*:}/SKILL.md" ] && ok "table skill $one exists" || bad "table skill $one exists"
  done
done < "$PLUGIN/hooks/skill-gate.tsv"
finish
