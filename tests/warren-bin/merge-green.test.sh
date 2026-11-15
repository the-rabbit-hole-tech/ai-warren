#!/usr/bin/env bash
# merge-green.sh against a fake gh on PATH: no network, no real repo.
source "$(dirname "$0")/lib.sh"
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/gh" <<'GH'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "pr view") case "$*" in *mergeCommit*) echo "MERGED abc1234" ;; *) echo "$FAKE_STATE" ;; esac ;;
  "pr checks") printf '%b' "$FAKE_CHECKS" ;;
  "pr merge") exit 0 ;;
esac
GH
chmod +x "$TMP/fakebin/gh"
export PATH="$TMP/fakebin:$PATH" FAKE_LOG="$TMP/log"
: > "$FAKE_LOG"
mkhome
bash "$BIN/warren-yes" o/r 1 2 3 >/dev/null
export FAKE_STATE="CLOSED MERGEABLE" FAKE_CHECKS=''; out=$("$BIN/merge-green.sh" o/r 1 "done"); rc=$?
has "SKIP o/r#1: CLOSED MERGEABLE" "skips a PR that is not open"
export FAKE_STATE="OPEN MERGEABLE" FAKE_CHECKS='build\tfail\t1m\nlint\tpass\t1s\n'; out=$("$BIN/merge-green.sh" o/r 2 "done"); rc=$?
expect 1 "a failing check blocks the merge"
has "WAIT o/r#2 not green: build" "names the failing check"
hasnt "pr merge" "never calls merge when not green"
: > "$FAKE_LOG"
export FAKE_STATE="OPEN MERGEABLE" FAKE_CHECKS='build\tpass\t1m\n'; out=$("$BIN/merge-green.sh" o/r 3 all good); rc=$?
expect 0 "a green PR merges"
has "o/r#3 MERGED abc1234" "reports the merge"
out=$(cat "$FAKE_LOG"); has "pr comment 3 -R o/r -b Closing summary: all good" "posts the closing summary"
has "pr merge 3 -R o/r --squash --delete-branch" "squash-merges and deletes the branch"
out=$("$BIN/merge-green.sh" o/r 9 "done"); rc=$?
expect 1 "no marker, no merge"
has "NOYES o/r#9" "says the owner's Yes is missing"
out=$("$BIN/merge-green.sh" o/plan 9 "done"); rc=$?
expect 0 "a plan repo needs no marker"
touch -t 200001010000 "$HOME/.claude/warren/merge-yes/o__r__3"
out=$("$BIN/merge-green.sh" o/r 3 "done"); rc=$?
expect 1 "a marker older than 7 days does not count"
finish
