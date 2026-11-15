#!/usr/bin/env bash
# The PR Body step of the shared PR Checks workflow, run from the step's own script (cut out of
# the workflow), so the test covers what ships. A body passes with a template "What" section and
# at least one issue reference GitHub links. Ported from the governance template's test.
source "$(dirname "$0")/lib.sh"
WF="$SC/templates/governance/.github/workflows/job-pr-checks.yaml"
step="$(mktmp)/step.sh"; trap 'rm -rf "$(dirname "$step")"' EXIT
# The `run: |` block of the step named "... PR Body", de-indented.
awk '
  /^      - name: .*PR Body$/ { inside = 1; next }
  inside && /^      - / { exit }
  inside && /^        run: \|/ { body = 1; next }
  body && /^          / { print substr($0, 11); next }
  body && /^$/ { print ""; next }
  body { exit }
' "$WF" > "$step"
[ -s "$step" ] && ok "the PR Body step script is found" || bad "the PR Body step script is found"

check() { if BODY="$1" bash "$step" >/dev/null 2>&1; then echo pass; else echo fail; fi; }
body() { printf '## What and why\n\nSome change.\n\n%s\n\n## Verification\n' "$1"; }
for kw in close closes closed fix fixes fixed resolve resolves resolved refs; do
  assert_eq "$(check "$(body "$kw #12")")" pass "keyword '$kw #12' passes"
done
assert_eq "$(check "$(body "CLOSES #12")")" pass "upper-case keyword passes"
assert_eq "$(check "$(body "Closes: #12")")" pass "keyword with a colon passes"
assert_eq "$(check "$(body "Refs octo-org/octo#166")")" pass "owner/repo#N passes"
assert_eq "$(check "$(body "Fixes octo-org/octo.repo_2#100")")" pass "owner/repo#N with dots and underscores passes"
assert_eq "$(check "$(body "Resolves GH-26")")" pass "GH-N passes"
assert_eq "$(check "$(body "Closes https://github.com/octo-org/octo-repo/issues/7")")" pass "a full GitHub issue URL passes"
assert_eq "$(check "$(body "Resolves #10, resolves octo-org/octo-repo#100")")" pass "several references pass"
assert_eq "$(check "$(body "- Refs octo-org/octo-repo#123.")")" pass "a reference in a list item with trailing punctuation passes"
assert_eq "$(check "$(body "No issue for this one.")")" fail "a body without a reference fails"
assert_eq "$(check "$(body "See #12")")" fail "a reference without a keyword fails"
assert_eq "$(check "$(body "Closes the gap")")" fail "a keyword without a reference fails"
assert_eq "$(check "$(body "Refs octo#166")")" fail "repo#N without an owner fails"
assert_eq "$(check "$(body "Refs https://example.com/page#12")")" fail "a URL fragment on another site fails"
assert_eq "$(check "$(body "Refs owner/repo/#12")")" fail "a trailing slash before # fails"
assert_eq "$(check "$(body "Closes -owner/repo#12")")" fail "an owner starting with a hyphen fails"
assert_eq "$(check "$(body "Closes #12abc")")" fail "a number glued to letters fails"
assert_eq "$(check "$(body "Closes #")")" fail "a hash without a number fails"
assert_eq "$(check "$(body "prefixes #12")")" fail "a keyword glued to other text fails"
assert_eq "$(check "$(body "Closes#12")")" fail "a keyword with no space before the reference fails"
assert_eq "$(check "Closes #12")" fail "a reference without the template section fails"
finish
