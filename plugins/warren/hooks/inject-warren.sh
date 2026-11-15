#!/usr/bin/env bash
# SessionStart hook: puts the always-on warren text into the session's context. A plugin
# can't ship an always-loaded CLAUDE.md, so this is how the short rule set reaches every turn.
set -euo pipefail
root=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
text_file="$root/warren.md"
[ -r "$text_file" ] || { echo "warren: $text_file is missing" >&2; exit 1; }
jq -n --rawfile t "$text_file" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$t}}'
