#!/usr/bin/env bash
# check-push-readiness checks the repo the push targets, not the session's start folder.
source "$(dirname "$0")/../assert.sh"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/plain"
for r in clean dirty; do
  git init -q "$tmp/$r"; printf 'a\n' > "$tmp/$r/f"; git -C "$tmp/$r" add f
  git -C "$tmp/$r" -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm init
done
printf 'b\n' > "$tmp/dirty/f"
run() { out=$(jq -n --arg d "$1" --arg c "$2" '{cwd:$d,tool_input:{command:$c}}' \
  | (cd "$1" && "$PLUGIN/hooks/check-push-readiness.sh")); }
run "$tmp/dirty" "git push"
has "Uncommitted changes" "a dirty repo blocks a plain push"
run "$tmp/plain" "git push"
hasnt "deny" "a cwd that isn't a git repo leaves the push to git"
run "$tmp/dirty" "git -C $tmp/clean push origin HEAD"
hasnt "deny" "git -C a clean repo pushes even when the cwd is dirty"
run "$tmp/dirty" "cd $tmp/clean && git push"
hasnt "deny" "cd into a clean repo pushes even when the cwd is dirty"
run "$tmp/clean" "git -C $tmp/dirty push"
has "Uncommitted changes" "git -C a dirty repo blocks from a clean cwd"
finish
