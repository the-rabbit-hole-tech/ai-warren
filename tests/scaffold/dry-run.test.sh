#!/usr/bin/env bash
# warren-new-repo --dry-run: every ecosystem and variant writes a filled tree, calls nothing on
# GitHub, and the tree passes the generic guard's deny list (no org, product, person or host
# names) and names no governance template, hub or sync.
source "$(dirname "$0")/lib.sh"
work="$(mktmp)"; trap 'rm -rf "$work"' EXIT
log="$work/gh.log"
with_stub_bin gh "printf '%s\n' \"\$*\" >> $log; exit 1"
for eco in $(cd "$SC/templates/ecosystems" && ls); do
  [ -d "$SC/templates/ecosystems/$eco/template" ] || continue
  for v in $(grep -vE '^[[:space:]]*(#|$)' "$SC/templates/ecosystems/$eco/layouts/variants"); do
    out=$(bash "$BIN/warren-new-repo" "r-$eco-$v" "$eco" --variant "$v" --org Owner --dry-run -d "A demo." --out "$work/trees" 2>&1); rc=$?
    expect 0 "dry run $eco/$v"
  done
done
out=$(bash "$BIN/warren-new-repo" r-priv go --private --org Owner --dry-run --out "$work/trees" 2>&1); rc=$?
expect 0 "dry run of a private repo"
has "gh repo create Owner/r-priv --private" "says what it would create"
assert_eq "$(cat "$log" 2>/dev/null)" "" "no gh call at all"
assert_eq "$(find "$work/trees" -name .git | wc -l | tr -d ' ')" 0 "no git repo made"
assert_eq "$(grep -rl '__[A-Z_]*__' "$work/trees" | wc -l | tr -d ' ')" 0 "no token left in any tree"
out=$(bash "$BIN/warren-new-repo" x go --dry-run 2>&1); rc=$?
expect 1 "--dry-run without --org is refused"

hits="$(python3 - "$work/trees" <<'PY'
import pathlib, re, sys
deny = [re.compile("/" + "Users/"), re.compile("/" + "home/[a-z]", re.I)]
deny.append(re.compile("project" + r"-template|governance hub|\bthe hub\b|hub-only|governance sync|sync issue", re.I))
for p in sorted(pathlib.Path(sys.argv[1]).rglob("*")):
    if not p.is_file(): continue
    for n, line in enumerate(p.read_text(errors="replace").splitlines(), 1):
        if any(d.search(line) for d in deny):
            print(f"{p.relative_to(sys.argv[1])}:{n}")
PY
)"
assert_eq "$hits" "" "the trees pass the generic checks"
finish
