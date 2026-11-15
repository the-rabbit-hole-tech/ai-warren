#!/usr/bin/env bash
# refresh-projects.sh [out-file]: regenerate the catalog (default $WARREN_CATALOG, else
# ~/.claude/warren/catalog.md), the local
# catalog of an org's published packages with their current versions.
# Import it from your global CLAUDE.md so every Claude session and agent on this machine
# knows what exists before writing its own. Local only, never committed.
# Run it after every release, or any time. Lists the org's public repos only.
# WARREN_CATALOG_ORG   the GitHub org or user to list (required)
set -u
ORG="${WARREN_CATALOG_ORG:-}"
[ -n "$ORG" ] || { echo "refresh-projects.sh: set WARREN_CATALOG_ORG to the GitHub org or user to list" >&2; exit 2; }
OUT="${1:-${WARREN_CATALOG:-$HOME/.claude/warren/catalog.md}}"
mkdir -p "$(dirname "$OUT")"
TMP="$(mktemp)"
kind_of() { # repo -> go | npm | action | chart | other
  case "$1" in
    go-*) echo go ;;
    fastify-*|node-*) echo npm ;;
    *-action) echo action ;;
    helm-*) echo chart ;;
    *) echo other ;;
  esac
}
{
  echo "# Published packages of $ORG (generated $(date -u +%Y-%m-%dT%H:%MZ) by refresh-projects.sh)"
  echo
  echo "Use these packages at these versions before writing your own code for the same job."
  echo "Every repo should build on them. If a need isn't covered, say so as a gap; don't build a one-off."
  echo "Check a package's README for its API before using it. The versions are the latest published releases."
  echo
  for section in go npm action chart; do
    case $section in
      go) echo "## Go modules"; echo; echo "| Module | Version | Purpose |"; echo "|---|---|---|" ;;
      npm) echo; echo "## npm packages"; echo; echo "| Package | Version | Purpose |"; echo "|---|---|---|" ;;
      action) echo; echo "## GitHub Actions"; echo; echo "| Action | Version | Purpose |"; echo "|---|---|---|" ;;
      chart) echo; echo "## Helm charts"; echo; echo "| Chart repo | Version | Purpose |"; echo "|---|---|---|" ;;
    esac
    gh repo list "$ORG" --limit 200 --no-archived --visibility public --json name,isFork,description,repositoryTopics \
      -q '.[] | select(.isFork|not) | select(([.repositoryTopics[]?.name]|index("to-be-deleted"))|not) | [.name, (.description // "")] | @tsv' |
    sort | while IFS=$'\t' read -r r desc; do
      [ "$(kind_of "$r")" = "$section" ] || continue
      ver=$(gh release list -R "$ORG/$r" --limit 20 --exclude-drafts --json tagName,isPrerelease -q '[.[]|select(.isPrerelease|not)][0].tagName // "unreleased"' 2>/dev/null)
      name="$r"
      case $section in
        go)  m=$(gh api "repos/$ORG/$r/contents/go.mod" -q .content 2>/dev/null | base64 -d 2>/dev/null | awk '/^module /{print $2; exit}'); name="\`${m:-github.com/$ORG/$r}\`" ;;
        npm) p=$(gh api "repos/$ORG/$r/contents/package.json" -q .content 2>/dev/null | base64 -d 2>/dev/null | awk -F'"' '/"name"/{print $4; exit}'); name="\`${p:-$r}\`" ;;
        action) name="\`$ORG/$r@${ver%%.*}\`" ;;
        chart) name="\`$ORG/$r\`" ;;
      esac
      echo "| $name | $ver | ${desc//|/-} |"
    done
  done
} > "$TMP" && mv "$TMP" "$OUT" && echo "wrote $OUT ($(wc -l < "$OUT") lines)"
