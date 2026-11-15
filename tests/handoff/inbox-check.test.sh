#!/usr/bin/env bash
# The inbox hook is silent without a site, silent with no unread Send, and prints a line for an unread one.
source "$(dirname "$0")/../assert.sh"
H="$ROOT/plugins/handoff/hooks/inbox-check.sh"
d=$(mktmp); trap 'rm -rf "$d"' EXIT
exec </dev/null
unset TMUX WARREN_HANDOFF_AGENT WARREN_OPS_SESSION

out=$(env -u WARREN_HANDOFF_SITE bash "$H" 2>&1); rc=$?
expect 0 "unset site exits 0"
[ -z "$out" ] && ok "unset site prints nothing" || bad "unset site prints nothing"

out=$(WARREN_HANDOFF_SITE="$d/missing" bash "$H" 2>&1); rc=$?
expect 0 "missing site exits 0"
[ -z "$out" ] && ok "missing site prints nothing" || bad "missing site prints nothing"

site="$d/site"; mkdir -p "$site/_site" "$site/_inbox/alpha"
cat > "$site/_site/page.py" <<'PY'
import os, sys
if sys.argv[1:2] == ["hook"] and os.path.exists(os.path.join("_inbox", sys.argv[2], "unread")):
    print("hand-off: 1 unread Send for " + sys.argv[2])
PY
out=$(WARREN_HANDOFF_SITE="$site" WARREN_HANDOFF_AGENT=alpha bash "$H" 2>&1); rc=$?
expect 0 "no unread Send exits 0"
[ -z "$out" ] && ok "no unread Send prints nothing" || bad "no unread Send prints nothing"

: > "$site/_inbox/alpha/unread"
out=$(WARREN_HANDOFF_SITE="$site" WARREN_HANDOFF_AGENT=alpha bash "$H" 2>&1); rc=$?
expect 0 "unread Send exits 0"
has "1 unread Send for alpha" "unread Send prints the line"

mkdir -p "$d/Code/Alpha-App"
out=$(cd "$d/Code/Alpha-App" && WARREN_HANDOFF_SITE="$site" bash "$H" 2>&1)
has "1 unread Send for alpha" "inbox is picked from the working directory"

out=$(WARREN_HANDOFF_SITE="$site" WARREN_HANDOFF_AGENT=nobody bash "$H" 2>&1)
expect 0 "agent with no inbox exits 0"
[ -z "$out" ] && ok "agent with no inbox prints nothing" || bad "agent with no inbox prints nothing"
# the lost-listener note prints once per session; an unread Send prints every time
export HOME="$d/home"; mkdir -p "$HOME"
cat > "$site/_site/page.py" <<'PY'
import os, sys
print("hand-off: nothing is listening for " + sys.argv[2])
if os.path.exists(os.path.join("_inbox", sys.argv[2], "unread")):
    print("hand-off: 1 unread Send for " + sys.argv[2])
PY
rm -f "$site/_inbox/alpha/unread"
run_s() { out=$(printf '{"session_id":"%s"}' "$1" | WARREN_HANDOFF_SITE="$site" WARREN_HANDOFF_AGENT=alpha bash "$H" 2>&1); }
run_s s1; has "nothing is listening for alpha" "the lost-listener note prints on the first prompt"
run_s s1; [ -z "$out" ] && ok "the note does not repeat in the same session" || bad "the note does not repeat in the same session"
run_s s2; has "nothing is listening for alpha" "a new session gets the note once"
: > "$site/_inbox/alpha/unread"
run_s s1; has "1 unread Send for alpha" "an unread Send still prints in a session that had the note"
hasnt "nothing is listening" "the note stays quiet while the Send prints"
out=$(printf 'not json' | WARREN_HANDOFF_SITE="$site" WARREN_HANDOFF_AGENT=alpha bash "$H" 2>&1); rc=$?
expect 0 "malformed input exits 0"
finish
