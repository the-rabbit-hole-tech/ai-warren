#!/usr/bin/env bash
# Runs the whole test suite in a throwaway Debian container with WARREN_TEST_SANDBOX=1, so the
# tests that make commits under a test identity never touch this machine's git setup.
# The repo is mounted read-only; the container is removed when it exits.
#   bash tests/sandbox.sh [pattern]
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
image=warren-test-sandbox:local
docker build -q -t "$image" -f - "$root/tests" >/dev/null <<'DOCKER'
FROM debian:stable-slim
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      bash git python3 jq gh ca-certificates >/dev/null && rm -rf /var/lib/apt/lists/*
RUN useradd -m -d /sandbox tester
USER tester
WORKDIR /sandbox
DOCKER
docker run --rm -e WARREN_TEST_SANDBOX=1 -v "$root:/repo:ro" "$image" \
  bash -c 'mkdir repo && tar -C /repo --exclude=./.git --warning=no-file-changed -cf - . | tar -C repo -xf - && cd repo && bash tests/run.sh "$@"' _ "${1:-.}"
