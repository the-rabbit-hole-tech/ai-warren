#!/usr/bin/env bash
# compose: each ecosystem gets the workflows its manifest needs and nothing it can't run.
# Ported from the governance template's compose test.
source "$(dirname "$0")/lib.sh"
scaffold_lib
work="$(mktmp)"; trap 'rm -rf "$work"' EXIT
for eco in go npm python claude-code; do
  for mode in public private; do
    compose "$eco" "$work/$eco-$mode" "$mode" "" "" >/dev/null || bad "compose $eco $mode"
  done
done
wf() { present "$work/$1/.github/workflows/$2"; }

assert_eq "$(wf go-public job-go-security.yaml)" yes "go public -> job-go-security"
assert_eq "$(wf go-private job-go-security.yaml)" yes "go private -> job-go-security"
assert_contains "$(cat "$work/go-public/.github/workflows/job-go-security.yaml")" '/bin/govulncheck" ./...' "govulncheck runs over the module"
assert_contains "$(cat "$work/go-public/.github/workflows/job-go-security.yaml")" 'gosec -quiet -exclude-generated ./...' "gosec skips generated code"
assert_eq "$(wf npm-public job-go-security.yaml)" no "npm public -> no job-go-security"
assert_eq "$(wf npm-private job-go-security.yaml)" no "npm private -> no job-go-security"
assert_eq "$(wf go-public job-license-check-go.yaml)" yes "go -> Go licence check"
assert_eq "$(wf go-public job-license-check-npm.yaml)" no "go -> no npm licence check"
assert_eq "$(wf npm-public job-license-check-npm.yaml)" yes "npm -> npm licence check"
assert_eq "$(wf npm-public job-license-check-go.yaml)" no "npm -> no Go licence check"
assert_eq "$(wf python-public job-license-check-go.yaml)$(wf python-public job-license-check-npm.yaml)" nono "python -> no licence job"
assert_eq "$(wf claude-code-public job-license-check-go.yaml)$(wf claude-code-public job-license-check-npm.yaml)" nono "claude-code -> no licence job"
assert_eq "$(wf claude-code-public job-golic.yaml)" no "claude-code -> no golic job (workflows.skip)"
assert_eq "$(wf claude-code-public job-go-security.yaml)" no "claude-code -> no job-go-security"
assert_eq "$(wf npm-public job-gitleaks.yaml)" no "no standalone gitleaks workflow"
assert_eq "$(wf go-private scan-security.yml)" no "go private -> no duplicate scan-security"
assert_eq "$(ls "$work/go-public/.claude/hooks" | tr '\n' ' ')" "forbidden-text.txt lib.sh " "no repo-local git hooks (the guard covers them), only the two files PR Checks sources"
assert_eq "$(present "$work/go-public/init.sh")" no "no init script left in the tree"
assert_eq "$(present "$work/go-public/.github/FUNDING.yml")" no "no sponsor file without a funding setting"

# Every composed job has a timeout, except reusable-workflow callers, which can't take one.
missing=""
for f in "$work"/*/.github/workflows/*.y*ml; do
  missing+="$(awk -v f="$f" '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^ #]/ { injobs = 0 }
    injobs && /^  [A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*$/ { if (job != "" && !ok) print f ":" job; job = $1; ok = 0; next }
    injobs && /^    (timeout-minutes|uses):/ { ok = 1 }
    END { if (job != "" && !ok) print f ":" job }
  ' "$f")"
done
assert_eq "$missing" "" "every composed job has timeout-minutes"
assert_eq "$(grep -rlE '^    if:.*hashFiles' "$work"/*/.github/workflows/ 2>/dev/null | wc -l | tr -d ' ')" 0 "no job-level hashFiles() in composed workflows"

# An unknown ecosystem or variant writes nothing.
compose nope "$work/nope" public "" "" >/dev/null 2>&1; rc=$?; expect 1 "an unknown ecosystem fails"
compose go "$work/go-bad" public nope "" >/dev/null 2>&1; rc=$?; expect 1 "an unknown variant fails"
assert_eq "$(present "$work/go-bad")" no "a rejected variant writes nothing"
finish
