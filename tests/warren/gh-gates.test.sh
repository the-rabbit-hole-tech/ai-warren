#!/usr/bin/env bash
# gh-meta-guard (issue and PR metadata), the merge-yes gate and its marker flow. HOME is a
# throwaway folder, so no real marker is read or written; the repo comes from -R, never from git.
source "$(dirname "$0")/../assert.sh"
meta="$PLUGIN/hooks/gh-meta-guard.sh"
gate="$PLUGIN/hooks/merge-yes-gate.sh"
rec="$PLUGIN/hooks/merge-yes-record.sh"
yes="$PLUGIN/bin/warren-yes"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"; mkdir -p "$HOME"
M="$HOME/.claude/warren/merge-yes"

payload() { jq -n --arg c "$1" '{tool_input:{command:$c},cwd:"/nonexistent"}'; }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; echo "$out"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }
run() { out=$(payload "$2" | "$1"); }

# gh-meta-guard
run "$meta" 'gh issue create -R o/r --title "feat: x" --body y'; deny "an issue with no metadata is denied"
has "--assignee, --milestone, --label" "the deny names every missing flag"
run "$meta" 'gh issue create -R o/r --assignee a --label bug'; deny "an issue without a milestone is denied"
has "missing --milestone" "only the missing flag is named"; hasnt "--assignee," "an assignee that is there is not named"
run "$meta" 'gh issue create -R o/r --assignee a --milestone vNext'; deny "an issue without a label is denied"
run "$meta" 'gh pr create -R o/r --title "feat: x" --assignee a'; deny "a PR without a milestone is denied"
run "$meta" 'gh pr create -R o/r --milestone v1'; deny "a PR without an assignee is denied"
run "$meta" 'gh pr create -R o/r -a me -m v1'; allow "a PR with assignee and milestone (short flags) is allowed, no label needed"
run "$meta" 'gh pr create -R o/r --assignee=me --milestone=v1'; allow "the = flag form is accepted"
run "$meta" 'gh issue create -R o/r -a me -m v1 -l bug'
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext|contains("updateIssueIssueType")' >/dev/null 2>&1 \
  && ! printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then ok "a complete issue create is allowed with the issue-type reminder"; else bad "issue-type reminder"; echo "$out"; fi
run "$meta" 'echo gh issue create'; allow "text that only mentions the command is allowed"
run "$meta" 'gh issue create --title x'; allow "a target repo that can't be found is allowed"
run "$meta" 'gh issue list -R o/r'; allow "other gh commands are allowed"
run "$meta" 'for r in a b; do gh pr create -R o/r; done'; deny "a create inside a loop is checked"
out=$(printf 'not json' | "$meta"); allow "malformed input to the meta guard is allowed"
out=$(printf '{}' | "$meta"); allow "an empty payload to the meta guard is allowed"

# merge-yes gate
run "$gate" 'gh pr merge 5 -R o/r --squash --delete-branch'; deny "a merge with no marker is denied"
has "warren-yes o/r 5" "the deny says how to record a standing Yes"
run "$gate" 'gh api -X PUT repos/o/r/pulls/5/merge'; deny "a gh api merge with no marker is denied"
run "$gate" 'gh pr merge --squash'; deny "a merge whose PR can't be told is denied"
run "$gate" 'gh pr merge 5 -R o/plan'; allow "a plan repo needs no Yes"
run "$gate" 'gh pr view 5 -R o/r'; allow "other gh pr commands are allowed"
run "$gate" 'merge-green.sh o/r 5 done'; allow "merge-green.sh is left to the script"
run "$gate" 'echo gh pr merge 5 -R o/r'; allow "text that only mentions the merge is allowed"
out=$(printf 'not json' | "$gate"); allow "malformed input to the merge gate is allowed"

# the marker flow: warren-yes
out=$("$yes" o/r 5); rc=$?; expect 0 "warren-yes writes a marker"
[ -f "$M/o__r__5" ] && ok "the marker file is <owner>__<repo>__<n>" || bad "marker file name"
run "$gate" 'gh pr merge 5 -R o/r --squash'; allow "a merge with a fresh marker is allowed"
run "$gate" 'gh pr merge https://github.com/o/r/pull/5'; allow "a merge by URL reads the marker too"
run "$gate" 'gh pr merge 6 -R o/r'; deny "a marker for another PR does not cover this one"
touch -t 200001010000 "$M/o__r__5"
run "$gate" 'gh pr merge 5 -R o/r'; deny "a marker older than 7 days is denied"
out=$("$yes" notarepo 5 2>&1); rc=$?; expect 1 "warren-yes rejects a bad repo"
out=$("$yes" o/r x 2>&1); rc=$?; expect 1 "warren-yes rejects a bad number"

# the marker flow: the answer to a question
rm -rf "$M"
ask() { jq -n --arg q "$1" --arg r "$2" '{tool_name:"AskUserQuestion",tool_input:{questions:[{question:$q}]},tool_response:$r}' | "$rec"; }
out=$(ask 'Do you approve o/r@PR#10?' 'User has answered your questions: "Do you approve o/r@PR#10?"="Yes". You can now continue.'); allow "recording prints nothing"
[ -f "$M/o__r__10" ] && ok "a Yes writes the marker" || bad "a Yes writes the marker"
ask 'Do you approve o/r@PR#11?' 'User has answered your questions: "Do you approve o/r@PR#11?"="No".'
[ -f "$M/o__r__11" ] && bad "a No writes no marker" || ok "a No writes no marker"
ask 'Merge #294, #296 and #297 in the-org/some.repo?' 'User has answered your questions: "Merge #294, #296 and #297 in the-org/some.repo?"="Yes, merge in order".'
[ -f "$M/the-org__some.repo__294" ] && [ -f "$M/the-org__some.repo__296" ] && [ -f "$M/the-org__some.repo__297" ] \
  && ok "a question listing several PRs writes one marker each" || bad "several PRs"
ask 'Approve #12?' 'User has answered your questions: "Approve #12?"="Yes".'
[ -f "$M/o__r__12" ] && bad "no repo, no marker" || ok "a question with no repo writes no marker"
jq -n '{tool_name:"AskUserQuestion",tool_input:{questions:[{question:"Approve o/r PR #13?"}]},tool_response:{answers:{"Approve o/r PR #13?":"Yes"}}}' | "$rec"
[ -f "$M/o__r__13" ] && ok "the answers-object shape works" || bad "answers-object shape"
jq -n '{tool_name:"Bash",tool_input:{questions:[{question:"Approve o/r PR #14?"}]},tool_response:"\"Approve o/r PR #14?\"=\"Yes\""}' | "$rec"
[ -f "$M/o__r__14" ] && bad "only the question tool writes markers" || ok "only the question tool writes markers"
out=$(printf 'not json' | "$rec"); allow "malformed input to the recorder is allowed"
run "$gate" 'gh pr merge 10 -R o/r'; allow "a merge after the recorded Yes is allowed"
finish
