#!/usr/bin/env bash
# Shared setup for the scaffold tests: the warren assert helpers, the assert_eq/assert_contains
# style the ported tests use, and an environment that never reads the person's own installed
# plugins (WARREN_SCAFFOLD_SEARCH=0), only the fixtures here.
source "$(dirname "${BASH_SOURCE[0]}")/../assert.sh"
SC="$ROOT/plugins/scaffold"
BIN="$SC/bin"
FIX="$ROOT/tests/scaffold/fixtures"
export WARREN_SCAFFOLD_SEARCH=0
unset WARREN_SCAFFOLD_DIRS
export WARREN_SCAFFOLD_DIRS="$FIX/example-org/scaffold:$FIX/extends-owner/scaffold:$FIX/mit-owner/scaffold:$FIX/odd-owner/scaffold"
assert_eq() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3"; printf '     expected: %q\n     actual:   %q\n' "$2" "$1"; fi; }
assert_contains() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3"; printf '     missing: %q\n' "$2" ;; esac; }
present() { [ -e "$1" ] && echo yes || echo no; }
# with_stub_bin <name> <body>: an executable stub first on PATH for the rest of the test.
with_stub_bin() {
  local d; d="$(mktmp)"
  printf '#!/usr/bin/env bash\n%s\n' "$2" > "$d/$1"; chmod +x "$d/$1"
  PATH="$d:$PATH"
}
# scaffold_lib: load the plugin's library into this shell.
scaffold_lib() { SCAFFOLD_ROOT="$SC"; ORG_DIR=""; SCAFFOLD_DIR_FLAG=""; source "$SC/lib/scaffold.sh"; }
