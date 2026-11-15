#!/usr/bin/env bash
# hookspath-check warns when a repo-local core.hooksPath would skip the global guard.
source "$(dirname "$0")/../assert.sh"
# It sets a repo-local core.hooksPath in a throwaway repo, so it runs only in the sandbox.
needs_sandbox
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp/clean"; git init -q "$tmp/husky"
git -C "$tmp/husky" config --local core.hooksPath .husky/_
out=$(jq -n --arg d "$tmp/clean" '{cwd:$d}' | "$PLUGIN/hooks/hookspath-check.sh")
[ -z "$out" ] && ok "a repo without a local core.hooksPath gets no warning" || bad "a repo without a local core.hooksPath gets no warning"
out=$(jq -n --arg d "$tmp/husky" '{cwd:$d}' | "$PLUGIN/hooks/hookspath-check.sh")
has "Commit guard bypassed" "a repo-local core.hooksPath is reported"
has "guard.chainPath" "the fix is named"
finish
