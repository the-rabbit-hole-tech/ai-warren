#!/usr/bin/env bash
# The generic guard (.github/scripts/check-generic.py) fails on a home path or a term from the
# user's local terms folder, and passes on clean files. It runs in throwaway git repos holding a
# copy of the guard, with WARREN_TERMS_DIR pointed at a throwaway folder, so no real term list is
# read. The repo holds no term list of its own.
source "$(dirname "$0")/../assert.sh"
TMP=$(mktmp); trap 'rm -rf "$TMP"' EXIT
export WARREN_TERMS_DIR="$TMP/terms"; mkdir -p "$WARREN_TERMS_DIR"
mkcopy() {
  local r="$TMP/$1"
  mkdir -p "$r/.github/scripts"
  cp "$ROOT/.github/scripts/check-generic.py" "$r/.github/scripts/"
  printf 'plain words about nothing in particular\n' > "$r/README.md"
  git -C "$r" init -q -b main && git -C "$r" add -A
}
check() { out=$(cd "$TMP/$1" && python3 -I .github/scripts/check-generic.py "${@:2}" 2>&1); rc=$?; }
ORG="zzplanted""org"
TERM="zzplanted""term"

mkcopy clean
check clean; expect 0 "a clean tree passes"
has "generic check: clean" "and says so"

mkcopy org
printf '%s\n' "$ORG" > "$WARREN_TERMS_DIR/org-terms.txt"
printf 'built for %s only\n' "$ORG" > "$TMP/org/notes.md"; git -C "$TMP/org" add -A
check org; expect 1 "a planted org name fails"
has "notes.md:1:" "the hit names file:line"
check org --staged; expect 1 "the staged check fails too"

rm -f "$WARREN_TERMS_DIR/org-terms.txt"
mkcopy path
printf 'see /%s/someone/work\n' Users > "$TMP/path/p.md"; git -C "$TMP/path" add -A
check path; expect 1 "a planted home path fails"

mkcopy term
printf '%s\n' "$TERM" > "$WARREN_TERMS_DIR/fake-terms.txt"
printf 'this line has %s in it\n' "$TERM" > "$TMP/term/t.md"; git -C "$TMP/term" add -A
check term; expect 1 "a hit from a local term list fails"
has "t.md:1: a local term-list entry" "it prints file:line"
hasnt "$TERM" "and never the term"
rm -f "$WARREN_TERMS_DIR/fake-terms.txt"

mkcopy staged
printf '%s\n' "$ORG" > "$WARREN_TERMS_DIR/org-terms.txt"
printf 'built for %s only\n' "$ORG" > "$TMP/staged/s.md"
check staged --staged; expect 0 "an unstaged file is not part of the staged check"
rm -f "$WARREN_TERMS_DIR/org-terms.txt"

# The default folder is under ~/.config/warren, and a missing folder is not an error.
mkcopy dflt
out=$(cd "$TMP/dflt" && HOME="$TMP/nohome" env -u WARREN_TERMS_DIR python3 -I .github/scripts/check-generic.py 2>&1); rc=$?
expect 0 "a missing terms folder passes on structural checks alone"
mkdir -p "$TMP/home2/.config/warren/terms"; printf '%s\n' "$TERM" > "$TMP/home2/.config/warren/terms/x.txt"
printf 'has %s here\n' "$TERM" > "$TMP/dflt/d.md"; git -C "$TMP/dflt" add -A
out=$(cd "$TMP/dflt" && HOME="$TMP/home2" env -u WARREN_TERMS_DIR python3 -I .github/scripts/check-generic.py 2>&1); rc=$?
expect 1 "the default folder is ~/.config/warren/terms"
hasnt "$TERM" "and the default folder hit does not print the term"

# The repo ships no term list, only a documented example with placeholders.
rc=0; [ ! -e "$ROOT/.github/generic-guard.txt" ] || rc=1; out=""
expect 0 "the repo holds no generic-guard list"
ex="$ROOT/docs/examples/warren-terms.example.txt"
rc=0; [ -f "$ex" ] || rc=1; out=""
expect 0 "the documented example terms file exists"
out=$(cat "$ex" 2>/dev/null)
has "placeholder" "and says its terms are placeholders"
finish
