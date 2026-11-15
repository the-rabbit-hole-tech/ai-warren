#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

mkdir -p "$HOME/bin"
cp "$FIXTURES/fake-claude" "$HOME/bin/claude"
export PATH="$HOME/bin:$PATH" CLAUDE_CALLS="$HOME/calls.txt"
: > "$CLAUDE_CALLS"

wait_for_call() { for (( i = 0; i < 50; i++ )); do [ -s "$CLAUDE_CALLS" ] && return 0; sleep 0.1; done; return 1; }

# a new ops starts Claude, and its shell stays once Claude exits
out="$("$BIN/tmux-start" </dev/null)"
grep -q 'not attaching' <<<"$out" || fail "start without a terminal: $out"
t has-session -t "=ops" || fail "ops was not created"
wait_for_call || fail "tmux-start did not start Claude"
sleep 0.5
assert_eq "$(wc -l < "$CLAUDE_CALLS" | tr -d ' ')" 1 "Claude starts once"
t has-session -t "=ops" || fail "ops died when Claude exited"

# an ops that is already running is left alone
: > "$CLAUDE_CALLS"
"$BIN/tmux-start" </dev/null >/dev/null
sleep 0.5
[ ! -s "$CLAUDE_CALLS" ] || fail "tmux-start typed into a running ops: $(cat "$CLAUDE_CALLS")"
