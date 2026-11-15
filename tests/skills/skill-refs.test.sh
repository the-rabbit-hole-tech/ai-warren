#!/usr/bin/env bash
# Every <plugin>:<skill> named in this repo's skills, hooks, docs and tests points at a skill that exists here.
source "$(dirname "$0")/../assert.sh"
plugins=$(ls "$ROOT/plugins" | paste -sd'|' -)
n=0; missing=0
while IFS= read -r ref; do
  p=${ref%%:*}; s=${ref#*:}
  n=$((n+1))
  [ -f "$ROOT/plugins/$p/skills/$s/SKILL.md" ] || { bad "skill reference $ref has no skill"; missing=$((missing+1)); }
done < <(grep -rhoE "\b($plugins):[a-z][a-z0-9-]+\b" "$ROOT/plugins" "$ROOT/tests" "$ROOT/README.md" "$ROOT/AGENTS.md" "$ROOT/CLAUDE.md" 2>/dev/null | grep -v "^warren:warren\b" | grep -v '^coding:lang$' | sort -u)
[ "$missing" = 0 ] && ok "all $n skill references resolve"
finish
