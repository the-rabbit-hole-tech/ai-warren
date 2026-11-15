#!/usr/bin/env bash
# Attach files to the release that exists for a tag, so a tag never ends up with two releases.
#
#   scripts/attach-release.sh <tag> <file>...
#
# Publishing release-drafter's draft in the browser creates the tag, and the tag starts the Release workflow, so the
# release for the tag usually exists already (published, or still a draft). This finds it and uploads into it, replacing
# a same-named asset on a re-run. A published release is preferred over a draft with the same tag. Only when there is none
# does it create a draft (never a published release): publishing stays a manual step.
# Needs gh, GH_TOKEN and GITHUB_REPOSITORY (both set in GitHub Actions).
set -euo pipefail

tag="${1:-}"
shift || true
if [ -z "$tag" ] || [ "$#" -eq 0 ]; then
  echo "usage: attach-release.sh <tag> <file>..." >&2
  exit 2
fi
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
for f in "$@"; do
  [ -f "$f" ] || { echo "attach-release: no such file: $f" >&2; exit 1; }
done

# "<id> <draft>" for every release with this tag, published ones first.
found="$(gh api "repos/$repo/releases" --paginate --jq ".[] | select(.tag_name == \"$tag\") | \"\\(.id) \\(.draft)\"" | sort -k2,2 -s)"
id="$(printf '%s\n' "$found" | awk 'NF { print $1; exit }')"

if [ -z "$id" ]; then
  echo "attach-release: no release for $tag yet; creating a draft" >&2
  gh release create "$tag" --draft --verify-tag --generate-notes "$@"
  exit 0
fi

echo "attach-release: uploading to release $id for $tag" >&2
for f in "$@"; do
  name="$(basename "$f")"
  old="$(gh api "repos/$repo/releases/$id/assets" --paginate --jq ".[] | select(.name == \"$name\") | .id")"
  for a in $old; do
    gh api --method DELETE "repos/$repo/releases/assets/$a" >/dev/null
  done
  gh api --method POST "https://uploads.github.com/repos/$repo/releases/$id/assets?name=$name" \
    -H "Content-Type: application/octet-stream" --input "$f" >/dev/null
  echo "attach-release: $name" >&2
done
