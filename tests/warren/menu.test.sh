#!/usr/bin/env bash
# The /warren menu lists every choice, and each flow it names is a skill in the tree (a plugin that
# hasn't landed yet is reported as pending).
source "$(dirname "$0")/../assert.sh"
menu="$PLUGIN/skills/menu/SKILL.md"
out=$(cat "$menu")
for choice in "Set up a new org" "Start a new project or repo" "Set up this repo" "Start a feature" \
  "Review or release" "Update warren" "Set up a person's GitHub" "This machine's host file" \
  "Connect your password manager"; do
  has "| $choice |" "the menu offers: $choice"
done
has 'Show "Connect your password manager" only when `secrets@ai-warren` is installed' "the password-manager choice shows only with its plugin"
has "disable-model-invocation: true" "the menu stays out of the model's skill listing"
while IFS= read -r ref; do
  plugin=${ref%%:*}; skill=${ref#*:}
  if [ -f "$ROOT/plugins/$plugin/skills/$skill/SKILL.md" ]; then ok "flow $ref is in the tree"
  elif [ ! -d "$ROOT/plugins/$plugin" ] || { [ "$plugin" = warren ] && [ "$skill" = warren-host ]; }; then echo "pending $ref (its PR hasn't landed)"
  else bad "flow $ref is in the tree"; fi
done < <(grep -oE '`/[a-z-]+:[a-z-]+`' "$menu" | tr -d '`/' | sort -u)
for s in warren-repo warren-update; do
  f="$PLUGIN/skills/$s/SKILL.md"
  [ -f "$f" ] && ok "$s exists" || bad "$s exists"
  grep -q "warren step ${s#warren-}" "$f" 2>/dev/null || grep -q "warren step repo-settings" "$f" 2>/dev/null \
    && ok "$s runs its warren step" || bad "$s runs its warren step"
done
finish
