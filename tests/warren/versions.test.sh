#!/usr/bin/env bash
# Version drift: every listed plugin has a semver of its own, and the marketplace's release version
# is never behind the highest plugin version. See RELEASING.md.
source "$(dirname "$0")/../assert.sh"
M="$ROOT/.claude-plugin/marketplace.json"
semver='^[0-9]+\.[0-9]+\.[0-9]+$'
mv=$(jq -r '.metadata.version' "$M")
[[ "$mv" =~ $semver ]] && ok "the marketplace version is semver ($mv)" || bad "the marketplace version is semver ($mv)"
highest="0.0.0"
while IFS= read -r src; do
  v=$(jq -r '.version // empty' "$ROOT/$src/.claude-plugin/plugin.json")
  if [[ "$v" =~ $semver ]]; then ok "$src has semver $v"; else bad "$src has semver (got '$v')"; continue; fi
  highest=$(printf '%s\n%s\n' "$highest" "$v" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
done < <(jq -r '.plugins[].source' "$M")
top=$(printf '%s\n%s\n' "$mv" "$highest" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
[ "$top" = "$mv" ] && ok "the marketplace version ($mv) is not behind the highest plugin ($highest)" || bad "the marketplace version ($mv) is behind the highest plugin ($highest)"
n=$(jq -r '.plugins | length' "$M"); d=$(ls -d "$ROOT"/plugins/*/ | wc -l | tr -d ' ')
[ "$n" = "$d" ] && ok "every plugin folder is listed ($n)" || bad "plugin folders ($d) and listed plugins ($n) differ"
[ -f "$ROOT/RELEASING.md" ] && ok "RELEASING.md exists" || bad "RELEASING.md exists"
finish
