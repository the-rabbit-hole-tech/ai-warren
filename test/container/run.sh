#!/usr/bin/env bash
# Builds a clean debian:stable-slim image with the linux warren binary and a copy of the plugin
# tree (a local `directory` marketplace, so no GitHub credentials are needed), runs
# in-container.sh once with `docker run --rm`, then removes the image.
#
#   test/container/run.sh
#
# WARREN_PLUGIN_TREE  the tree holding .claude-plugin/marketplace.json (default: this repo)
# WARREN_TEST_WORKDIR where to stage the build context (default: a temp folder, removed after)
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
tree=${WARREN_PLUGIN_TREE:-$repo}
image=warren-cli-test:local

[ -f "$tree/.claude-plugin/marketplace.json" ] || { echo "no marketplace in $tree (set WARREN_PLUGIN_TREE)" >&2; exit 2; }

if [ -n "${WARREN_TEST_WORKDIR:-}" ]; then
  work=$WARREN_TEST_WORKDIR
  mkdir -p "$work"
else
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
fi

case "$(docker info --format '{{.Architecture}}')" in
  aarch64|arm64) arch=arm64 ;;
  x86_64|amd64) arch=amd64 ;;
  *) echo "unsupported docker architecture" >&2; exit 2 ;;
esac

echo "building warren for linux/$arch"
(cd "$repo" && GOWORK=off CGO_ENABLED=0 GOOS=linux GOARCH=$arch go build -o "$work/warren" ./cmd/warren)
cp "$here/Dockerfile" "$here/in-container.sh" "$here/agent-machine.yaml" "$work/"
mkdir -p "$work/marketplace"
(cd "$tree" && tar --exclude=.git -cf - .) | (cd "$work/marketplace" && tar -xf -)

docker build -q -t "$image" "$work" >/dev/null
status=0
docker run --rm "$image" || status=$?
docker rmi "$image" >/dev/null
exit "$status"
