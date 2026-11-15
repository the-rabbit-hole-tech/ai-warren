#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
mkdir -p "$TMP/hm/code/Org/a" "$TMP/hm/code/Org/b" "$TMP/bin"
export HOME; HOME=$(cd "$TMP/hm" && pwd -P)
export WARREN_CODE_ROOT="$HOME/code" WARREN_FLEET_LOGS="$HOME/logs"
printf 'Org a\nOrg b\nOrg missing\n# comment\n\n' > "$TMP/repos.txt"
out=$("$BIN/fleet-run" "$TMP/repos.txt" "do it" --dry-run 2>&1); rc=$?
expect 0 "dry run exits 0"
has "would run in $HOME/code/Org/a" "dry run lists the first repo"
has "would run in $HOME/code/Org/b" "dry run lists the second repo"
has "SKIP Org missing" "a missing folder is skipped"
printf '#!/bin/sh\necho "ran: $*"\n' > "$TMP/bin/claude"; chmod +x "$TMP/bin/claude"
out=$(PATH="$TMP/bin:$PATH" "$BIN/fleet-run" "$TMP/repos.txt" "do it" --jobs 2 2>&1); rc=$?
expect 0 "a real run with a fake claude exits 0"
has "OK   Org a" "a run reports OK"
n=$(find "$HOME/logs" -name '*.log' | wc -l | tr -d ' ')
[ "$n" = 2 ] && ok "one log per repo" || bad "one log per repo ($n)"
out=$("$BIN/fleet-run" 2>&1); rc=$?
expect 1 "missing arguments exit non-zero with usage"
finish
