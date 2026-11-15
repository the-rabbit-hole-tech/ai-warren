#!/usr/bin/env bash
# Shared helpers for the operator plugin tests: a private tmux server on its own socket
# (tmux -L warren-test-<pid>), never the live one. The test is skipped when tmux or jq is missing.
set -euo pipefail
for tool in tmux jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "skip $(basename "$0"): $tool is not installed"; exit 0; }
done
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PLUGIN="$ROOT/plugins/operator"
FIXTURES="$ROOT/tests/operator/fixtures"
export ROOT PLUGIN FIXTURES
# Each test runs in a throwaway HOME so nothing reaches the real one.
HOME="$(mktemp -d "${TMPDIR:-/tmp}/warren-op-home.XXXXXX")"
HOME="$(cd "$HOME" && pwd -P)"
export HOME
export TMUX_SOCKET_NAME="warren-test-$$"
export TMUX_STATE_DIR="$HOME/state"
export TMUX_CONFIG=/dev/null
# tmux leaves its socket file behind after kill-server; keep them out of /tmp/tmux-<uid>.
TMUX_TMPDIR="$(mktemp -d /tmp/warren-test-tmux.XXXXXX)"
export TMUX_TMPDIR
unset TMUX TMUX_PANE CLAUDE_PID CLAUDE_CONFIG_DIR WARREN_OPS_SESSION
export BIN="$PLUGIN/bin"

t() { tmux -L "$TMUX_SOCKET_NAME" -f /dev/null "$@"; }
start_server() { t new-session -d -s "$1" -c "${2:-$HOME}"; }
stop_server() { t kill-server 2>/dev/null || true; }
# A restored pane can still be writing into HOME as the server stops, so the first rm may race it.
cleanup() { stop_server; rm -rf "$TMUX_TMPDIR"; rm -rf "$HOME" 2>/dev/null || { sleep 1; rm -rf "$HOME" 2>/dev/null || true; }; }
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3: expected [$2] got [$1]"; }
# On Linux a new pane reports an empty path until its process has started.
wait_pane_path() {
  local i
  for (( i = 0; i < 50; i++ )); do
    [ "$(t display -p -t "$1" '#{pane_current_path}')" = "$2" ] && return 0
    sleep 0.1
  done
  fail "pane $1 never reached $2"
}
