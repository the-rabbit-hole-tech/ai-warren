#!/usr/bin/env bash
# merge-green.sh <owner/repo> <pr> <summary...>
# Squash-merges a PR only if it is open, mergeable, and has no failing or pending checks.
set -u
R=$1 n=$2; shift 2; msg="$*"
# The owner's Yes: a fresh marker from the answer hook or warren-yes (plan repos are exempt).
if [ "${R#*/}" != plan ]; then
  mk="$HOME/.claude/warren/merge-yes/${R%%/*}__${R#*/}__$n"
  [ -n "$(find "$mk" -mmin -10080 2>/dev/null)" ] || { echo "NOYES $R#$n: no owner Yes on record (ask, or warren-yes $R $n)"; exit 4; }
fi
st=$(gh pr view "$n" -R "$R" --json state,mergeable -q '.state+" "+.mergeable')
[ "${st%% *}" = OPEN ] || { echo "SKIP $R#$n: $st"; exit 0; }
bad=$(gh pr checks "$n" -R "$R" 2>/dev/null | awk -F'\t' '$2=="fail"||$2=="pending"{print $1}' | paste -sd, -)
[ -n "$bad" ] && { echo "WAIT $R#$n not green: $bad"; exit 2; }
gh pr comment "$n" -R "$R" -b "Closing summary: $msg" >/dev/null
gh pr merge "$n" -R "$R" --squash --delete-branch >/dev/null 2>&1 || { echo "FAIL $R#$n: merge refused; no admin override"; exit 3; }
echo "$R#$n $(gh pr view "$n" -R "$R" --json state,mergeCommit -q '.state+" "+(.mergeCommit.oid//"")[0:7]')"
