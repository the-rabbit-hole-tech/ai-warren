#!/usr/bin/env bash
# Every skill has the agreed frontmatter, and the descriptions stay within budget.
source "$(dirname "$0")/../assert.sh"
out=$(python3 -I "$ROOT/tests/skills/skill_format.py" "$ROOT" 12000 2>&1); rc=$?
printf '%s\n' "$out" | sed 's/^/     /'
expect 0 "skills follow the format and the description budget"
finish
