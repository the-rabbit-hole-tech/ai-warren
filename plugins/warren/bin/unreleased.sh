#!/usr/bin/env bash
# unreleased.sh: list unreleased work across your orgs.
# For each non-fork, non-archived repo it reports:
#   - draft GitHub Releases (release-drafter)
#   - open release-please PRs
#   - commits on the default branch since the latest published release
# Usage: unreleased.sh [org ...]   (no args = the orgs in $WARREN_ORGS, space-separated)
# Repos with nothing unreleased are skipped. Repos tagged to-be-deleted are skipped.
set -u
if [ $# -gt 0 ]; then orgs=("$@"); else read -ra orgs <<<"${WARREN_ORGS:-}"; fi
[ "${#orgs[@]}" -gt 0 ] || { echo "usage: unreleased.sh [org ...]   (or set WARREN_ORGS)" >&2; exit 2; }
for o in "${orgs[@]}"; do
  printf "\n## %s\n" "$o"
  gh repo list "$o" --limit 200 --no-archived --json name,isFork,repositoryTopics,defaultBranchRef \
    -q '.[] | select(.isFork|not) | select(([.repositoryTopics[]?.name] | index("to-be-deleted")) | not) | .name + " " + (.defaultBranchRef.name // "main")' |
  while read -r r def; do
    R="$o/$r"
    drafts=$(gh release list -R "$R" --limit 20 --json tagName,isDraft -q '[.[] | select(.isDraft) | .tagName] | join(",")' 2>/dev/null)
    latest=$(gh release list -R "$R" --limit 20 --json tagName,isDraft,isPrerelease -q '[.[] | select((.isDraft|not) and (.isPrerelease|not))][0].tagName // ""' 2>/dev/null)
    rp=$(gh pr list -R "$R" --state open --limit 50 --json number,title -q '[.[] | select(.title | startswith("chore(main): release")) | "#\(.number) \(.title | ltrimstr("chore(main): release "))"] | join(", ")' 2>/dev/null)
    ahead=""
    if [ -n "$latest" ]; then
      ahead=$(gh api "repos/$R/compare/$latest...$def" -q '.ahead_by' 2>/dev/null)
    fi
    if [ -n "$drafts" ] || [ -n "$rp" ] || { [ -n "$ahead" ] && [ "$ahead" != 0 ]; }; then
      printf '  %-40s last=%-10s ahead=%-4s draft=%-12s release-pr=%s\n' "$r" "${latest:-none}" "${ahead:--}" "${drafts:--}" "${rp:--}"
    fi
  done
done
