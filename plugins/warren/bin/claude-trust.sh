#!/usr/bin/env bash
# Mark folders as trusted in Claude (~/.claude.json projects.<path>.hasTrustDialogAccepted), so a new
# window opens straight to the prompt instead of the "Quick safety check" dialog.
#   claude-trust.sh <dir>...     trust these folders
#   claude-trust.sh --all        trust the code root, every org folder and every repo under $WARREN_CODE_ROOT/<org>/<repo>
# WARREN_CODE_ROOT is the folder holding your repos (required). Only folders under it are accepted. The file is rewritten atomically.
set -euo pipefail

CFG="$HOME/.claude.json"
ROOT="${WARREN_CODE_ROOT:-}"
[ -n "$ROOT" ] || { echo "claude-trust.sh: set WARREN_CODE_ROOT to the folder that holds your repos" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd -P)"

dirs=()
if [ "${1:-}" = "--all" ]; then
  dirs+=("$ROOT")
  for org in "$ROOT"/*/; do
    org="${org%/}"
    case "$(basename "$org")" in _*|worktrees) continue ;; esac
    dirs+=("$org")
    for repo in "$org"/*/; do
      repo="${repo%/}"
      [ -e "$repo/.git" ] && dirs+=("$repo")
    done
  done
else
  [ $# -gt 0 ] || { echo "usage: $0 <dir>... | --all" >&2; exit 2; }
  for d in "$@"; do
    d="$(cd "$d" && pwd -P)"
    case "$d" in "$ROOT"|"$ROOT"/*) dirs+=("$d") ;; *) echo "skipped (not under $ROOT): $d" >&2 ;; esac
  done
fi
[ ${#dirs[@]} -gt 0 ] || exit 0

tmp="$(mktemp "$CFG.XXXXXX")"
printf '%s\n' "${dirs[@]}" | jq -R . | jq -s . |
  jq --slurpfile cfg "$CFG" '. as $d | $cfg[0] | .projects //= {} |
    reduce $d[] as $p (.; .projects[$p] = ((.projects[$p] // {}) + {hasTrustDialogAccepted: true}))' >"$tmp"
mv "$tmp" "$CFG"
echo "trusted ${#dirs[@]} folder(s)"
