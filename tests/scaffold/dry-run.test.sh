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


# Every file the shared PR Checks workflow sources must be in the tree, for every ecosystem and variant.
missing=""
for t in "$work"/trees/*/; do
  wf="$t.github/workflows/job-pr-checks.yaml"
  [ -f "$wf" ] || continue
  for src in $(grep -oE 'source[[:space:]]+[.A-Za-z0-9_-]+/[.A-Za-z0-9_/-]+' "$wf" | awk '{print $2}'); do
    [ -f "$t$src" ] || missing="$missing $(basename "$t"):$src"
  done
  [ -f "$t.claude/hooks/forbidden-text.txt" ] || missing="$missing $(basename "$t"):.claude/hooks/forbidden-text.txt"
done
assert_eq "$missing" "" "every tree has the files its PR Checks workflow sources"

# Two lint jobs on one shared runner collide on golangci-lint's cache lock unless parallel runs are allowed.
nopar=""
for t in "$work"/trees/*/; do
  for f in "$t"Taskfile.y*ml "$t".github/workflows/*.y*ml; do
    [ -f "$f" ] || continue
    while IFS= read -r line; do
      case "$line" in *--allow-parallel-runners*) ;; *) nopar="$nopar $(basename "$t")/${f#"$t"}" ;; esac
    done < <(grep -E 'golangci-lint run|^[[:space:]]*args:.*--timeout' "$f" | grep -v '^[[:space:]]*#')
  done
done
assert_eq "$nopar" "" "every golangci-lint run in the templates allows parallel runners"
assert_contains "$(grep -h 'golangci-lint run' "$work"/trees/r-go-lib/Taskfile.y*ml)" "--allow-parallel-runners" "the Go Taskfile lint target has the flag"
assert_contains "$(grep -h 'args:' "$work"/trees/r-go-lib/.github/workflows/job-go-lang-ci.yaml)" "--allow-parallel-runners" "the Go lint workflow has the flag"

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
