#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
command -v jq >/dev/null || { echo "skip claude-trust.test.sh: no jq"; exit 0; }
mkdir -p "$TMP/home"; export HOME; HOME=$(cd "$TMP/home" && pwd -P)  # physical path: the script compares pwd -P
export WARREN_CODE_ROOT="$HOME/src"
mkdir -p "$HOME/src/Org/repo/.git" "$HOME/src/Org/plain" "$HOME/src/_forks/x/.git" "$HOME/outside"
echo '{"projects":{"/keep":{"a":1}},"other":true}' > "$HOME/.claude.json"
out=$("$BIN/claude-trust.sh" "$HOME/src/Org/plain" "$HOME/outside" 2>&1); rc=$?
expect 0 "trusts a folder under the code root"
has "skipped (not under" "refuses a folder outside the code root"
assert_eq "$(jq -r '.projects | keys | length' "$HOME/.claude.json")" "2" "adds one entry beside the existing one"
assert_eq "$(jq -r '.projects["/keep"].a' "$HOME/.claude.json")" "1" "keeps existing project data"
assert_eq "$(jq -r '.other' "$HOME/.claude.json")" "true" "keeps other settings"
out=$("$BIN/claude-trust.sh" --all 2>&1); rc=$?
expect 0 "--all succeeds"
has "trusted 3 folder(s)" "--all trusts the code root, the org folder and the repo (not _forks)"
assert_eq "$(jq -r '.projects["'"$HOME"'/src/Org/repo"].hasTrustDialogAccepted' "$HOME/.claude.json")" "true" "repo is trusted"
finish
