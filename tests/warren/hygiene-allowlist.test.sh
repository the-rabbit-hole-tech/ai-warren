#!/usr/bin/env bash
# The PR Hygiene step and the pre-commit hook share .claude/hooks/lib.sh. Their AI-tell scan
# honours the ai-tell entries of .github/scrub-allow.txt, read from a base revision (the PR's
# base commit in CI), with the push gate's rules: exact value (percent-decoded, case kept),
# fnmatch path glob, a reason on every entry, any bad line blocks, and only the base side counts.
# The tells are assembled at run time so this file passes its own check.
source "$(dirname "$0")/../assert.sh"
needs_sandbox

CC="Claude"" Code"
BI="below is"" a"
AS="as an A""I"
cd "$(mktmp)" || exit 1
base=$(pwd)

git_() { git -c user.name=tester -c user.email=tester@example.org -c commit.gpgsign=false "$@"; }

# mkrepo <name> <allowlist text, or - for none>: a repo on main with the hook files and the allowlist.
mkrepo() {
  rm -rf "${base:?}/$1"; mkdir -p "$base/$1/.claude/hooks" "$base/$1/.github"; cd "$base/$1" || exit 1
  git init -q -b main
  cp "$ROOT/.claude/hooks/lib.sh" "$ROOT/.claude/hooks/forbidden-text.txt" "$ROOT/.claude/hooks/scrub_allow.py" .claude/hooks/
  [ "$2" = - ] || printf '%b' "$2" > .github/scrub-allow.txt
  git add -A; git_ commit -q -m "chore: base"
}

# verdict <ref> <file>: out holds what the scan reports on stdout (offences and list errors), rc is 0
# when it reports nothing; the honoured entries go to stderr, kept in $base/notes.
verdict() {
  out=$(GOV_ALLOW_REF="$1" bash -c 'source .claude/hooks/lib.sh; gov_find_file_tells "$1"' _ "$2" 2>"$base/notes"); rc=0
  [ -z "$out" ] || rc=1
}

mkrepo exact "# the docs name the product\nai-tell Claude%20Code README.md\n"
printf 'This is for %s.\n' "$CC" > README.md
verdict main README.md; expect 0 "an exact entry allows the phrase"
out=$(cat "$base/notes"); has "scrub-allow.txt@" "an honoured entry is reported with its source"
printf 'This is for %s.\n' "$(printf '%s' "$CC" | tr 'A-Z' 'a-z')" > README.md
verdict main README.md; expect 1 "a different case is not the entry's value"
printf 'This is for %s.\n' "$CC" > NOTES.md
verdict main NOTES.md; expect 1 "a path the glob does not cover is blocked"
printf 'This is for %s, %s.\n' "$CC" "$AS" > README.md
verdict main README.md; expect 1 "an allowed phrase does not hide a second tell on the line"
printf 'Two: %s and %s.\n' "$CC" "$CC" > README.md
verdict main README.md; expect 0 "every match of an allowed phrase on a line is allowed"
verdict "" README.md; expect 1 "no allowlist ref means no allowance"

mkrepo glob "# reason\nai-tell below%20is%20a docs/*\n"
mkdir -p docs/deep; printf 'The list %s check.\n' "$BI" > docs/deep/x.md
verdict main docs/deep/x.md; expect 0 "* crosses / in the path glob"

mkrepo above "# the reason sits above\nai-tell Claude%20Code README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 0 "a reason on the line above counts"
mkrepo blank "# a reason\n\nai-tell Claude%20Code README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a blank line between the reason and the entry breaks it"
has "reason" "the missing reason is named"
mkrepo noreason "ai-tell Claude%20Code README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "an entry with no reason blocks"

mkrepo secret "# r\nsecret abcdef README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a secret entry is refused"
mkrepo unknown "# r\nbogus abcdef README.md\n"
verdict main README.md; expect 0 "no tell, so a bad list is never read"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "an unknown class blocks"
mkrepo wildval "# r\nai-tell Claude* README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a wildcard in the value blocks"
mkrepo wildglob "# r\nai-tell Claude%20Code **\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a glob of only wildcards blocks"
mkrepo dotdot "# r\nai-tell Claude%20Code ../README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a glob with .. blocks"
mkrepo fields "# r\nai-tell Claude%20Code\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "a line without three fields blocks"

mkrepo otherclass "# r\nemail someone@example.org README.md\n# r\nai-tell Claude%20Code README.md\n"
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 0 "entries of the org scanner's classes parse and are skipped"

# Only the base side counts: an entry added on the branch does not approve itself.
mkrepo selfapprove -
git_ checkout -q -b feature
printf '# r\nai-tell Claude%%20Code README.md\n' > .github/scrub-allow.txt
printf 'For %s.\n' "$CC" > README.md
git add -A; git_ commit -q -m "docs: add the entry and the phrase"
verdict main README.md; expect 1 "an entry that exists only on the branch does not count"
git_ checkout -q main; git_ merge -q feature
verdict main README.md; expect 0 "once the entry is on the base it counts"

verdict nosuchrev README.md; expect 1 "an unreadable base revision blocks"
has "nosuchrev" "the unreadable revision is named"

mkrepo nolist -
printf 'For %s.\n' "$CC" > README.md
verdict main README.md; expect 1 "no allowlist at the base is an empty list"

# The default ref for the local hook: the remote's default branch, never a local branch.
mkrepo defref "# r\nai-tell Claude%20Code README.md\n"
out=$(bash -c 'source .claude/hooks/lib.sh; gov_default_allow_ref'); rc=0; [ -z "$out" ] || rc=1
expect 0 "no remote, no default ref"
git update-ref refs/remotes/origin/main main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
out=$(bash -c 'source .claude/hooks/lib.sh; gov_default_allow_ref'); rc=0; [ "$out" = origin/HEAD ] || rc=1
expect 0 "origin/HEAD is the default ref"
finish
