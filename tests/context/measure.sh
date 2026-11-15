#!/usr/bin/env bash
# Measures what a session loads before its first turn, in one directory, and appends one row to
# docs/context-budget.md.
#   tests/context/measure.sh <dir> <label> [--no-session]
# Two numbers:
#   1. tokens: a one-line `claude -p` run in <dir>, reading usage from the JSON result:
#      input_tokens + cache_creation_input_tokens + cache_read_input_tokens. That is the whole
#      prompt of the first turn: the system prompt, the tool list, the memory files, skill
#      listings and hook context, so it's an upper bound on the rules, not the rules alone.
#      --no-session skips this (it costs a real request).
#   2. bytes: the size of every memory file the session loads: ~/.claude/CLAUDE.md and what it
#      imports, ~/.claude/rules/*.md, each CLAUDE.md from <dir> up to $HOME and what each
#      imports, and the project's auto memory MEMORY.md. Imports (@path lines) are followed
#      recursively, each file counted once.
# It reads the person's live config and never changes it. Language files aren't counted: they
# load only when read.
set -euo pipefail
dir=$(cd "${1:?usage: measure.sh <dir> <label> [--no-session]}" && pwd -P)
label=${2:?label}
session=1; [ "${3:-}" = "--no-session" ] && session=0
root=$(cd "$(dirname "$0")/../.." && pwd -P)
out="$root/docs/context-budget.md"
cfg=${CLAUDE_CONFIG_DIR:-$HOME/.claude}

files=$(python3 -I "$(dirname "$0")/memory_files.py" "$dir" "$cfg" "$HOME")
bytes=$(printf '%s\n' "$files" | awk -F'\t' '{s+=$1} END {print s+0}')
count=$(printf '%s\n' "$files" | grep -c . || true)

tokens="not run"
if [ "$session" = 1 ]; then
  json=$(cd "$dir" && claude -p "Reply with OK." --output-format json 2>/dev/null)
  tokens=$(printf '%s' "$json" | jq -r '.usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)')
fi

mkdir -p "$(dirname "$out")"
if [ ! -f "$out" ]; then
  printf '# Context budget\n\nRows are appended by `tests/context/measure.sh`.\n\n| Date | Label | Directory | First-turn tokens | Memory files | Memory bytes |\n|---|---|---|---|---|---|\n' > "$out"
fi
short=${dir/#$HOME/\~}
printf '| %s | %s | `%s` | %s | %s | %s |\n' "$(date +%Y-%m-%d)" "$label" "$short" "$tokens" "$count" "$bytes" >> "$out"
echo "$label: tokens=$tokens files=$count bytes=$bytes"
printf '%s\n' "$files" | sed "s|$HOME|~|" | awk -F'\t' '{printf "  %8d  %s\n", $1, $2}'
