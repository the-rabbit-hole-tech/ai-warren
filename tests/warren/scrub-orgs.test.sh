#!/usr/bin/env bash
# The scrub gate's org table: the plugin's orgs.conf plus the person's local table, which
# warren-guard-sync never manages. No commits or network: it loads gate.py and asks it which
# org layer a remote URL gets.
source "$(dirname "$0")/../assert.sh"
TMP=$(mktmp); trap 'rm -rf "$TMP"' EXIT
GATE="$PLUGIN/git-hooks/scrub/gate.py"
lookup() { # <url> -> "<segment> <lists...>" or "none"
  python3 -I - "$GATE" "$1" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("gate", sys.argv[1])
gate = importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)
try:
    seg, lists = gate.org_for(sys.argv[2], gate.load_orgs())
except gate.Blocked as e:
    print(f"blocked: {e}"); sys.exit(0)
print(" ".join([seg] + lists) if seg else "none")
PY
}
export SCRUB_ORGS_FILE="$TMP/scrub-orgs.conf"
out=$(lookup "git@github.com:Example-Org/demo.git")
[ "$out" = none ] && ok "no local table: an unlisted org gets no org layer" || bad "no local table: an unlisted org gets no org layer (got: $out)"
printf '# mine\nexample-org   forbidden extra\n' > "$SCRUB_ORGS_FILE"
out=$(lookup "git@github.com:Example-Org/demo.git")
[ "$out" = "example-org forbidden extra" ] && ok "a local row turns the org layer on" || bad "a local row turns the org layer on (got: $out)"
out=$(lookup "https://github.com/Example-Org/plan.git")
[ "$out" = "example-org forbidden" ] && ok "a plan repo under a local row runs only the forbidden list" || bad "a plan repo under a local row runs only the forbidden list (got: $out)"
out=$(lookup "https://github.com/other/demo.git")
[ "$out" = none ] && ok "other remotes are unaffected" || bad "other remotes are unaffected (got: $out)"
mkdir "$TMP/dir-not-file"; export SCRUB_ORGS_FILE="$TMP/dir-not-file"
out=$(lookup "git@github.com:Example-Org/demo.git")
has "blocked: can't read" "an unreadable local table blocks (fails closed)"
# warren-guard-sync leaves the local table alone.
export HOME="$TMP/home"; mkdir -p "$HOME/.config/git"
export WARREN_GUARD_DIR="$HOME/.config/warren/git-hooks" WARREN_HOOKS_LINK="$HOME/.config/git/hooks"
mkdir -p "$HOME/.config/warren"; printf 'example-org forbidden\n' > "$HOME/.config/warren/scrub-orgs.conf"
CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/bin/warren-guard-sync" --quiet >/dev/null 2>&1 || true
[ "$(cat "$HOME/.config/warren/scrub-orgs.conf")" = "example-org forbidden" ] && ok "warren-guard-sync leaves the local table alone" || bad "warren-guard-sync leaves the local table alone"
[ -x "$WARREN_GUARD_DIR/_dispatch" ] && ok "the guard still synced beside it" || bad "the guard still synced beside it"
finish
