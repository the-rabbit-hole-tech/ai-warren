#!/usr/bin/env bash
# Pack the hand-off web into a release tarball and its checksum, from the committed tree.
#
#   scripts/build-release.sh <version> [out-dir]     version like 1.0.0 (no prefix); out-dir defaults to ./dist
#
# Writes handoff-web-<version>.tar.gz (everything under handoff-web-<version>/) and handoff-web-<version>.sha256.
# Only tracked files go in, so a working copy's stray files never ship. The tarball is what the installer
# needs: install.sh, the template, the example, the docs, the memory file, the licence and the README.
# Unpack it and run install.sh <site-dir> (the same command updates an existing site; see docs/adapters.md in
# the repository). Nothing is tagged or published here.
set -euo pipefail

VERSION="${1:-}"
OUT="${2:-dist}"
case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "usage: build-release.sh <version, like 1.0.0> [out-dir]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
REL="$(git -C "$HERE" rev-parse --show-prefix)"      # adapters/handoff-web/
NAME="handoff-web-$VERSION"

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "building $NAME from $(git -C "$ROOT" rev-parse --short HEAD) (committed files only)" >&2

# git archive of a subtree takes its paths relative to that tree.
(cd "$ROOT" && git archive --format=tar.gz --prefix="$NAME/" -o "$OUT/$NAME.tar.gz" "HEAD:${REL%/}" \
  install.sh LICENSE README.md template example docs memory)

(cd "$OUT" && shasum -a 256 "$NAME.tar.gz" > "$NAME.sha256")
echo "$OUT/$NAME.tar.gz"
echo "$OUT/$NAME.sha256"
