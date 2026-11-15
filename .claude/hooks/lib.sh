#!/usr/bin/env bash
# Shared helpers for the project governance hooks.
# Works with BSD (macOS) and GNU tooling. Emoji detection uses perl (BSD grep
# lacks -P); text-pattern detection uses grep -E.

GOV_HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOV_PATTERNS_FILE="${GOV_PATTERNS_FILE:-$GOV_HOOKS_DIR/forbidden-text.txt}"
# Patterns a repo may use in its Markdown docs (one per line, copied exactly
# from the patterns file). Laid down only for ecosystems whose docs must name a
# product the list blocks, such as claude-code add-ons naming Claude's CLI.
# Found from the hooks dir (.claude/hooks), so the cwd does not matter.
GOV_DOCS_ALLOW_FILE="${GOV_DOCS_ALLOW_FILE:-$GOV_HOOKS_DIR/../../.github/docs-allowed-forbidden-text.txt}"

# Print the AI-tell patterns that apply to a path, one per line. With a path to a Markdown doc,
# the patterns in the docs allow file are left out.
gov_text_patterns() {
  case "${1:-}" in
    *.md|docs/*)
      if [ -f "$GOV_DOCS_ALLOW_FILE" ]; then
        grep -vE '^[[:space:]]*(#|$)' "$GOV_PATTERNS_FILE" 2>/dev/null \
          | grep -vxF -f <(grep -vE '^[[:space:]]*(#|$)' "$GOV_DOCS_ALLOW_FILE")
        return
      fi ;;
  esac
  grep -vE '^[[:space:]]*(#|$)' "$GOV_PATTERNS_FILE" 2>/dev/null
}

# Build one extended-regex alternation from the patterns for a path.
gov_text_regex() {
  gov_text_patterns "${1:-}" | paste -sd '|' -
}

# The revision the local hooks read the reviewed allowlist (.github/scrub-allow.txt) from: the
# remote's default branch as last fetched. Never the index, the working tree or a local branch, so
# an entry cannot approve itself in the commit that adds it. Empty when there is no such ref (no
# remote yet), which means no allowlist. CI passes the PR's base commit through GOV_ALLOW_REF.
gov_default_allow_ref() {
  local r
  for r in origin/HEAD origin/main; do
    if git rev-parse --verify --quiet "refs/remotes/$r^{commit}" >/dev/null 2>&1; then
      echo "$r"; return 0
    fi
  done
  return 0
}

# Read stdin; print offending lines for forbidden AI-tell phrases (empty if none).
# Commit messages and PR text come through here and always get the full list.
gov_find_text_tells() {
  local re
  re="$(gov_text_regex)"
  [ -z "$re" ] && return 0
  grep -inE "$re" || true
}

# gov_find_file_tells <path>: the same for a file in the repo, given by its path
# from the root, so a Markdown doc gets the repo's docs allowances. When GOV_ALLOW_REF names a
# revision, a match the ai-tell entries of .github/scrub-allow.txt at that revision cover (exact
# text, path glob, a reason on every entry, the push gate's rules) is not reported. A revision or
# list that cannot be read reports every match, with the reason on stdout, and honoured entries
# are noted on stderr.
gov_find_file_tells() {
  local re found filtered pats err rc
  re="$(gov_text_regex "$1")"
  [ -z "$re" ] && return 0
  found="$(grep -inE -- "$re" "$1" || true)"
  [ -z "$found" ] && return 0
  if [ -z "${GOV_ALLOW_REF:-}" ]; then
    printf '%s\n' "$found"; return 0
  fi
  pats="$(mktemp)"; err="$(mktemp)"
  gov_text_patterns "$1" > "$pats"
  rc=0
  filtered="$(printf '%s\n' "$found" | python3 -I "$GOV_HOOKS_DIR/scrub_allow.py" "$GOV_ALLOW_REF" "$1" "$pats" 2>"$err")" || rc=$?
  if [ "$rc" -eq 0 ]; then
    cat "$err" >&2
    [ -z "$filtered" ] || printf '%s\n' "$filtered"
  else
    cat "$err"
    printf '%s\n' "$found"
  fi
  rm -f "$pats" "$err"
}

# Read stdin; print offending lines containing emoji/pictographs (empty if none).
gov_find_emoji() {
  perl -CSD -ne 'print "$.: $_" if /[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE00}-\x{FE0F}\x{1F1E6}-\x{1F1FF}]/'
}
