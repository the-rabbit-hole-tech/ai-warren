#!/usr/bin/env bash
# The tmux last-window guard denies closing the last window of a session; the merge-loop guard only warns and
# the to-be-deleted guard denies. A fake tmux on the PATH answers `display-message` with
# "<windows> <panes>" from FAKE_TMUX_REPLY, so no real tmux session is touched.
source "$(dirname "$0")/../assert.sh"
t="$PLUGIN/hooks/tmux-last-window-guard.sh"
m="$PLUGIN/hooks/merge-loop-warn.sh"
d="$PLUGIN/hooks/to-be-deleted-guard.sh"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/empty"
cat > "$tmp/bin/tmux" <<'FAKE'
#!/usr/bin/env bash
[ "${FAKE_TMUX_FAIL:-0}" = 1 ] && exit 1
[ "$1" = display-message ] && echo "${FAKE_TMUX_REPLY:-2 1} ${FAKE_TMUX_NAME:-cur}"
FAKE
chmod +x "$tmp/bin/tmux"
for b in bash python3 cat dirname; do ln -s "$(command -v $b)" "$tmp/empty/$b"; done

export WARREN_OPS_SESSION=ops WARREN_CODING_SESSION=work
payload() { jq -n --arg c "$1" '{tool_input:{command:$c}}'; }
tmux_run() { out=$(payload "$1" | PATH="$tmp/bin:$PATH" FAKE_TMUX_REPLY="${2:-2 1}" "$t"); }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; echo "$out"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
warn() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext and (.hookSpecificOutput.permissionDecision|not)' >/dev/null 2>&1; then ok "$1"; else bad "$1"; echo "$out"; fi; }

# tmux: the last window
tmux_run "tmux kill-window -t CODING:main" "1 1"; deny "kill-window on a one-window session is denied"
has "That closes the last window and ends the tmux session. Keep a placeholder window first." "the deny message is the agreed text"
tmux_run "tmux kill-window" "1 3"; deny "kill-window of the current session's last window is denied"
tmux_run "tmux kill-pane -t CODING:main.0" "1 1"; deny "kill-pane on the last pane of the last window is denied"
tmux_run "cd /tmp && tmux -L work kill-window -t OPS:2" "1 1"; deny "a global option and a chain are looked through"
tmux_run "tmux killw -t OPS:2" "1 1"; deny "the killw alias is checked"
tmux_run "tmux kill-window -t CODING:main" "3 1"; allow "kill-window with other windows left is allowed"
tmux_run "tmux kill-pane -t CODING:main.1" "1 2"; allow "kill-pane with other panes left is allowed"
tmux_run "tmux kill-window -a -t CODING:main" "1 1"; allow "kill-window -a keeps the target window"
tmux_run "tmux new-window -t CODING -n keep && tmux kill-window -t CODING:main" "1 1"; allow "a placeholder window made first is allowed"
tmux_run "tmux kill-session -t scratch" "1 1"; allow "kill-session of another session is allowed"
tmux_run "tmux kill-server" "3 1"; deny "kill-server is denied"
tmux_run "tmux kill-session -t ops" "3 1"; deny "kill-session of the ops session is denied"
tmux_run "tmux kill-session -t =work:" "3 1"; deny "kill-session of the coding session (exact-match form) is denied"
tmux_run "tmux kill-session -a -t scratch" "3 1"; deny "kill-session -a is denied"
out=$(payload "tmux kill-session" | PATH="$tmp/bin:$PATH" FAKE_TMUX_REPLY="3 1" FAKE_TMUX_NAME=ops "$t"); deny "kill-session of the current ops session is denied"
out=$(payload "tmux kill-session -t ops" | WARREN_OPS_SESSION=other PATH="$tmp/bin:$PATH" "$t"); allow "the protected names come from WARREN_OPS_SESSION"
tmux_run 'for w in 1 2 3; do tmux kill-window -t work:$w; done' "5 1"; deny "kill-window in a for loop is denied"
tmux_run 'tmux list-windows -F "#I" | xargs -I{} tmux kill-window -t {}' "5 1"; deny "kill-window behind xargs is denied"
tmux_run 'while read w; do tmux kill-window -t $w; done < f' "5 1"; deny "kill-window in a while loop is denied"
tmux_run 'tmux new-window -d -n keep; for w in 1 2; do tmux kill-window -t work:$w; done' "5 1"; allow "a loop after a window is made first is allowed"
tmux_run 'for w in 1 2; do echo $w; done; tmux kill-window -t work:3' "5 1"; allow "a kill-window after a finished loop is checked on its own"
tmux_run "tmux send-keys -t work:1 exit Enter" "1 1"; deny "send-keys exit to the last window is denied"
tmux_run "tmux send-keys -t work:1 C-d" "1 1"; deny "send-keys C-d to the last window is denied"
tmux_run "tmux send-keys -t work:1 exit Enter" "3 1"; allow "send-keys exit with other windows left is allowed"
tmux_run "tmux send-keys -t work:1 ls Enter" "1 1"; allow "other send-keys are allowed"
tmux_run "tmux list-windows" "1 1"; allow "other tmux commands are allowed"
tmux_run "echo tmux kill-window" "1 1"; allow "text that only mentions the command is allowed"
tmux_run "ls -la" "1 1"; allow "other commands are not checked"
# tmux: nothing to check
out=$(payload "tmux kill-window -t CODING:main" | PATH="$tmp/bin:$PATH" FAKE_TMUX_FAIL=1 "$t"); allow "a target tmux can't resolve is allowed"
out=$(payload "tmux kill-window -t CODING:main" | PATH="$tmp/empty" "$t"); allow "tmux not installed is allowed"
tmux_run "tmux kill-window -t 'CODING:main" "1 1"; allow "an unparseable command is allowed"
out=$(printf 'not json' | "$t"); allow "malformed input to the tmux guard is allowed"
out=$(printf '{}' | "$t"); allow "an empty payload to the tmux guard is allowed"

# merge loop: warn only
run_m() { out=$(payload "$1" | "$m"); }
run_m 'while true; do gh pr merge 5 --squash && break; sleep 30; done'; warn "a while loop with gh pr merge and sleep warns"
has "Don't hand-roll a merge loop: use warren:scripts merge-green.sh (it checks the real merge state)." "the merge loop message is the agreed text"
run_m 'for i in 1 2 3; do sleep 10; gh pr merge 5 --squash; done'; warn "a for loop warns"
run_m 'until gh pr merge 5 --squash; do sleep 5; done'; warn "an until loop warns"
run_m 'gh pr merge 5 --squash'; allow "a plain merge is allowed"
run_m 'while true; do sleep 5; done'; allow "a loop with no merge is allowed"
run_m 'for pr in 1 2; do gh pr view "$pr"; done'; allow "a loop with no merge and no sleep is allowed"
run_m 'gh pr merge 5 --squash; sleep 5'; allow "a merge and a sleep with no loop is allowed"
out=$(printf 'not json' | "$m"); allow "malformed input to the merge loop warning is allowed"

# to-be-deleted topic: deny unless the PUT form
run_d() { out=$(payload "$1" | "$d"); }
run_d 'gh repo edit o/r --add-topic to-be-deleted'; deny "--add-topic to-be-deleted is denied"
has "carries the single topic to-be-deleted" "the topic message names the rule"
run_d 'gh repo edit o/r --add-topic=to-be-deleted'; deny "--add-topic=to-be-deleted is denied"
run_d "gh repo edit o/r --add-topic 'to-be-deleted'"; deny "a quoted topic is denied"
run_d 'gh repo edit o/r --add-topic go,to-be-deleted'; deny "a topic list that includes it is denied"
run_d 'gh repo edit o/r --add-topic go'; allow "another topic is allowed"
run_d 'gh repo edit o/r --remove-topic to-be-deleted'; allow "removing the topic is allowed"
run_d 'gh api -X PUT repos/o/r/topics -f names[]=to-be-deleted'; allow "the PUT form with only that topic is allowed"
run_d 'gh api -X PUT repos/o/r/topics -f names[]=go -f names[]=to-be-deleted'; deny "the PUT form with other topics too is denied"
run_d 'echo --add-topic to-be-deleted'; allow "text that only mentions the flag is allowed"
out=$(printf 'not json' | "$d"); allow "malformed input to the topic guard is allowed"
finish
