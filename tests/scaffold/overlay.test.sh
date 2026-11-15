#!/usr/bin/env bash
# apply_overlay (warren-apply-governance --sync): the shared set lands, retired workflows go, and
# the Go and npm workflows follow the manifest. Ported from the governance template's test.
source "$(dirname "$0")/lib.sh"
scaffold_lib
ov() { ( org_use "${1:-Owner}"; org_env "${1:-Owner}" repo "A repo."; apply_overlay ) >/dev/null 2>&1; }

w="$(mktmp)"; cd "$w" || exit 1
git init -q
mkdir -p .github/workflows .claude/hooks
printf 'version: 2\n' > .github/dependabot.yml
printf 'name: x\n' > .github/workflows/job-dependabot-auto-merge.yaml
printf 'name: Gitleaks\n' > .github/workflows/job-gitleaks.yaml
printf 'name: License Check\n' > .github/workflows/job-license-check.yaml
printf 'old\n' > .claude/hooks/lib.sh
ov
assert_eq "$(present CLAUDE.md)" yes "CLAUDE.md laid down"
assert_eq "$(present .github/PULL_REQUEST_TEMPLATE.md)" yes "PR template laid down"
assert_eq "$(present .github/release-drafter.yml)" yes "release-drafter config laid down"
assert_eq "$(present .github/dependabot.yml)" no "dependabot.yml removed"
assert_eq "$(present .github/workflows/job-dependabot-auto-merge.yaml)" no "auto-merge workflow removed"
assert_eq "$(present .github/workflows/job-gitleaks.yaml)" no "standalone gitleaks retired"
assert_eq "$(present .github/workflows/job-license-check.yaml)" no "two-job licence check retired"
assert_eq "$(present .github/workflows/job-go-security.yaml)" no "no go.mod -> no Go security scan"
assert_eq "$(present .github/workflows/job-license-check-npm.yaml)" no "no package.json -> no npm licence check"
assert_eq "$(cat .claude/hooks/lib.sh)" old "a repo's existing .claude/hooks are left alone"
assert_eq "$(grep -rl '__[A-Z_]*__' .github CLAUDE.md AGENTS.md | wc -l | tr -d ' ')" 0 "tokens filled"
assert_contains "$(cat .github/workflows/job-pr-checks.yaml)" "Gitleaks (secret scan)" "gitleaks runs inside PR Checks"
assert_contains "$(cat .gitignore)" "plan/" "notes folder ignored"
assert_contains "$(cat .github/CODEOWNERS)" "* @Owner" "root CODEOWNERS rule for an owner without a baseline"

w="$(mktmp)"; cd "$w" || exit 1
printf 'module example.com/m\n\ngo 1.26\n' > go.mod; ov
assert_eq "$(present .github/workflows/job-go-security.yaml)" yes "Go repo -> job-go-security"
assert_eq "$(present .github/workflows/job-license-check-go.yaml)" yes "Go repo -> Go licence check"
assert_eq "$(present .github/workflows/job-license-check-npm.yaml)" no "Go repo -> no npm licence check"

w="$(mktmp)"; cd "$w" || exit 1
printf '{"name":"x"}\n' > package.json; ov
assert_eq "$(present .github/workflows/job-license-check-npm.yaml)" yes "npm repo -> npm licence check"
assert_eq "$(present .github/workflows/job-go-security.yaml)" no "npm repo -> no Go security scan"

w="$(mktmp)"; cd "$w" || exit 1
printf 'module example.com/m\n\ngo 1.26\n' > go.mod
mkdir -p .github/workflows; printf 'name: scan-security\n# adapted\n' > .github/workflows/scan-security.yml
ov
assert_eq "$(present .github/workflows/job-go-security.yaml)" no "legacy scan-security -> no duplicate scan"
assert_eq "$(present .github/workflows/job-license-check-go.yaml)" yes "legacy scan-security -> Go licence check still lands"
assert_eq "$(cat .github/workflows/scan-security.yml)" "$(printf 'name: scan-security\n# adapted')" "legacy scan-security left as it is"

# An owner that extends a shared release-drafter config loses the local copy and gets its sponsor file.
w="$(mktmp)"; cd "$w" || exit 1
mkdir -p .github; printf 'old\n' > .github/release-drafter.yml
ov extends-owner
assert_eq "$(present .github/release-drafter.yml)" no "extends owner -> local release-drafter config removed"
assert_eq "$(cat .github/FUNDING.yml)" "github: [extends-owner]" "funding setting -> FUNDING.yml"

# The files the shared PR Checks workflow sources land with the governance, so a new repo's first PR can pass.
w="$(mktmp)"; cd "$w" || exit 1
git init -q
ov
assert_eq "$(present .claude/hooks/lib.sh)" yes "the hook library PR Checks sources is laid down"
assert_eq "$(present .claude/hooks/forbidden-text.txt)" yes "the forbidden-text list it reads is laid down"
assert_eq "$(bash -c 'source .claude/hooks/lib.sh && type -t gov_find_emoji gov_find_file_tells | tr "\n" " "')" "function function " "the library defines what the workflow calls"
printf 'hello\n' > ok.txt
assert_eq "$(bash -c 'source .claude/hooks/lib.sh && gov_find_file_tells ok.txt')" "" "a clean file passes the tell check"
assert_eq "$(git check-ignore .claude/hooks/lib.sh .claude/hooks/forbidden-text.txt | wc -l | tr -d ' ')" 0 "they are tracked, not ignored"

# A repo whose .gitignore ignores .claude still tracks them.
w="$(mktmp)"; cd "$w" || exit 1
git init -q
printf '.claude/\n' > .gitignore
ov
assert_eq "$(git check-ignore .claude/hooks/lib.sh .claude/hooks/forbidden-text.txt | wc -l | tr -d ' ')" 0 "an ignored .claude folder still tracks the two files"

# A repo's own forbidden-text list is kept too.
w="$(mktmp)"; cd "$w" || exit 1
git init -q; mkdir -p .claude/hooks; printf 'mine\n' > .claude/hooks/forbidden-text.txt
ov
assert_eq "$(cat .claude/hooks/forbidden-text.txt)" mine "an existing forbidden-text list is left alone"
finish
