#!/usr/bin/env bash
# Helpers for the bin/ script tests. Source it, call finish at the end.
#   assert_eq <got> <want> <description>    assert_true <command> <description>
#   mkrepo <dir>                            a repo with one empty commit
#   mkhome                                  a throwaway HOME with a test git identity
# Tests that make commits call needs_sandbox first (see tests/assert.sh).
source "$(dirname "${BASH_SOURCE[0]}")/../assert.sh"
BIN="$PLUGIN/bin"
TMP=$(mktmp)
trap 'rm -rf "$TMP"' EXIT
assert_eq()   { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (want '$2', got '$1')"; fi; }
assert_true() { if eval "$1"; then ok "$2"; else bad "$2"; fi; }
mkhome() {
  export HOME="$TMP/home"; mkdir -p "$HOME"
  unset GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  export GIT_CONFIG_NOSYSTEM=1
  printf '[user]\n\tname = Test Person\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n' > "$HOME/.gitconfig"
}
mkrepo() { git init -q -b main "$1" && git -C "$1" commit -q --allow-empty -m "chore: init"; }
