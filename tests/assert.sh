#!/usr/bin/env bash
# Shared helpers for the shell tests. Source it; call finish at the end.
#   expect <0|1> <description>   checks $rc (0 = must pass, 1 = must fail)
#   has / hasnt <text> <description>   checks $out
#   ok / bad <description>
#   needs_sandbox                 skips the file unless WARREN_TEST_SANDBOX=1
# Tests that make commits run only in a sandbox (CI or tests/sandbox.sh), never against a
# person's own machine identity.
fails=0
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
PLUGIN="$ROOT/plugins/warren"
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fails=$((fails+1)); }
expect() {
  if { [ "$1" = 0 ] && [ "$rc" = 0 ]; } || { [ "$1" = 1 ] && [ "$rc" != 0 ]; }; then ok "$2"
  else bad "$2 (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/     | /' | head -20; fi
}
has()   { if printf '%s' "$out" | grep -qF -- "$1"; then ok "$2"; else bad "$2"; printf '%s\n' "$out" | sed 's/^/     | /' | head -20; fi; }
hasnt() { if printf '%s' "$out" | grep -qF -- "$1"; then bad "$2"; else ok "$2"; fi; }
needs_sandbox() {
  if [ "${WARREN_TEST_SANDBOX:-0}" != 1 ]; then
    echo "skip $(basename "$0"): makes commits, runs only with WARREN_TEST_SANDBOX=1 (CI or tests/sandbox.sh)"
    exit 0
  fi
}
mktmp() { mktemp -d "${TMPDIR:-/tmp}/warren-test.XXXXXX"; }
finish() { if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails FAILED"; exit 1; fi; }
