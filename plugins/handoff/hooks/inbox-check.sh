#!/usr/bin/env bash
# UserPromptSubmit hook: flag an unread hand-off Send or a lost listener for this session's inbox.
# The site folder comes from WARREN_HANDOFF_SITE; unset or missing means silent exit 0.
# The inbox is WARREN_HANDOFF_AGENT when set, "ops" in the operator tmux session
# (WARREN_OPS_SESSION), otherwise the inbox whose name appears in a folder name of the working
# directory. It only prints a line; it never acts. The lost-listener and stale-session notes
# ("nothing is listening", "stale") print once per session, kept by a marker file under
# ~/.claude/warren/noted/<session_id>; an unread Send is printed every time.
set -u
payload=""; [ -t 0 ] || payload=$(cat 2>/dev/null || true)
sid=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)
site="${WARREN_HANDOFF_SITE:-}"
[ -n "$site" ] && [ -f "$site/_site/page.py" ] || exit 0

agent="${WARREN_HANDOFF_AGENT:-}"
if [ -z "$agent" ] && [ -n "${TMUX:-}" ] && [ -n "${WARREN_OPS_SESSION:-}" ] \
  && [ "$(tmux display-message -p '#S' 2>/dev/null)" = "$WARREN_OPS_SESSION" ]; then
  agent="ops"
fi
if [ -z "$agent" ]; then
  here=$(printf '%s' "$PWD" | tr '[:upper:]' '[:lower:]')
  for d in "$site"/_inbox/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    [ "$name" = ops ] && continue
    case "$here" in *"$name"*) agent="$name"; break ;; esac
  done
fi
[ -n "$agent" ] || exit 0
[ -d "$site/_inbox/$agent" ] || exit 0
msg=$(cd "$site" && python3 _site/page.py hook "$agent" 2>/dev/null) || true
[ -n "$msg" ] || exit 0
noted="$HOME/.claude/warren/noted/${sid:-nosession}"
while IFS= read -r line; do
  if printf '%s' "$line" | grep -Eqi 'nothing is listening|stale'; then
    kind=listener; printf '%s' "$line" | grep -qi stale && kind=stale
    if [ -n "$sid" ]; then
      [ -e "$noted/$kind" ] && continue
    elif [ -n "$(find "$noted/$kind" -mmin -60 2>/dev/null)" ]; then
      continue
    fi
    mkdir -p "$noted" 2>/dev/null && : > "$noted/$kind"
  fi
  printf '%s\n' "$line"
done <<<"$msg"
exit 0
