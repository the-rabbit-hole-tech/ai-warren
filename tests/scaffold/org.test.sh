#!/usr/bin/env bash
# The owner layer: an owner's scaffold/ folder sets its own licence, holder, operator and notes
# folder, drops the shared files its .github repo provides, replaces the CODEOWNERS baseline and
# starts each repo with its own files. An owner without one composes with the generic defaults.
# Ported from the governance template's org test, with a fixture owner in place of a real org.
source "$(dirname "$0")/lib.sh"
scaffold_lib
work="$(mktmp)"; trap 'rm -rf "$work"' EXIT
ORG=Example-Org
dropped=".gitleaks.toml .github/CONTRIBUTING.md .github/SECURITY.md .github/CODE_OF_CONDUCT.md .github/SUPPORT.md
.github/FUNDING.yml .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE .github/DISCUSSION_TEMPLATE"
tmpl_refs() { grep -rnI -E 'ecosystems/|governance/rulesets|templates/|the hub|hub-only:|standalone:|@Example-Org([^/A-Za-z0-9-]|$)|(^|[^.])plan/' "$1" --exclude-dir=.git 2>/dev/null || true; }

# Finding the folder.
assert_eq "$(scaffold_find "$ORG")" "$FIX/example-org/scaffold" "owner found through WARREN_SCAFFOLD_DIRS"
assert_eq "$(scaffold_find example-org)" "$FIX/example-org/scaffold" "owner match ignores case"
assert_eq "$(scaffold_find other-handle)" "$FIX/extends-owner/scaffold" "one folder can serve several owners"
assert_eq "$(scaffold_find no-such-owner)" "" "an unknown owner has no settings"
cfg="$(cd "$(mktmp)" && pwd)"; mkdir -p "$cfg/plugins/marketplaces/m/plugins/p/scaffold"
printf 'owners=found-owner\n' > "$cfg/plugins/marketplaces/m/plugins/p/scaffold/scaffold.conf"
assert_eq "$(WARREN_SCAFFOLD_SEARCH=1 CLAUDE_CONFIG_DIR="$cfg" scaffold_find found-owner)" "$cfg/plugins/marketplaces/m/plugins/p/scaffold" "installed plugins are searched"
assert_eq "$(CLAUDE_CONFIG_DIR="$cfg" scaffold_find found-owner)" "" "the search can be turned off"
assert_eq "$(SCAFFOLD_DIR_FLAG="$FIX/extends-owner/scaffold" scaffold_find anyone)" "$FIX/extends-owner/scaffold" "--scaffold-dir wins"

# Settings.
org_use "$ORG"
assert_eq "$(org_setting license)" Apache-2.0 "owner licence"
assert_eq "$(org_setting author)" "The Example Authors" "owner copyright holder"
assert_eq "$(org_setting golic-license)" spdx-apache2 "owner golic template"
assert_eq "$(org_setting dco)" true "owner takes DCO sign-off"
org_use nobody
assert_eq "$(org_setting license Apache-2.0)" Apache-2.0 "an owner without settings gets the default"

# A new repo of the owner.
out="$work/svc"
bash "$BIN/warren-new-repo" svc go --org "$ORG" --dry-run -d "A service." --out "$work" >/dev/null 2>"$work/err"; rc=$?
expect 0 "dry run for the owner composes"
assert_eq "$(present "$out/go.mod")" yes "the tree is there"
for f in $dropped; do assert_eq "$(present "$out/$f")" no "owner drops $f"; done
assert_eq "$(grep -cE '^\*[[:space:]]' "$out/.github/CODEOWNERS")" 0 "owner CODEOWNERS has no root rule"
assert_contains "$(cat "$out/.github/CODEOWNERS")" "/.github/workflows/** @example-maintainer" "owner CODEOWNERS owns the workflows"
assert_contains "$(head -3 "$out/LICENSE")" "Apache License" "owner licence text is Apache"
assert_contains "$(cat "$out/NOTICE")" "Copyright $(date +%Y) The Example Authors" "NOTICE names the holder"
assert_contains "$(cat "$out/.github/workflows/checks.yml")" "uses: Example-Org/.github/.github/workflows/scrub.yml@main" "owner CI caller laid down"
for wf in job-go-lang-ci.yaml job-release-drafter.yaml job-pr-checks.yaml job-label-checker.yaml \
          job-label-sync.yaml job-golic.yaml job-go-security.yaml job-license-check-go.yaml action-lint.yaml; do
  assert_eq "$(present "$out/.github/workflows/$wf")" yes "shared $wf still lands"
done
assert_contains "$(cat "$out/Taskfile.yaml")" 'TEMPLATE_LIC: "spdx-apache2"' "golic checks the owner header"
assert_contains "$(cat "$out/Taskfile.yaml")" "COMMON_LIC: \"$(date +%Y) The Example Authors\"" "golic stamps the owner holder"
assert_contains "$(cat "$out/README.md")" "Apache-2.0 (c) $(date +%Y) The Example Authors" "README names the licence"
assert_eq "$(grep -cw MIT "$out/README.md" "$out/Taskfile.yaml" | awk -F: '{s+=$2} END {print s}')" 0 "no MIT text left"
assert_eq "$(grep -rl '__[A-Z_]*__' "$out" | wc -l | tr -d ' ')" 0 "no token left"
assert_eq "$(tmpl_refs "$out")" "" "the repo names no template path and no org operator"
assert_contains "$(cat "$out/CLAUDE.md")" "The operator (@example-maintainer)" "CLAUDE.md names the owner's operator"
assert_contains "$(cat "$out/CLAUDE.md")" "git-ignored \`.local/\` folder" "CLAUDE.md names the owner's notes folder"
assert_contains "$(cat "$out/.gitignore")" ".local/" "local notes go in .local/"
assert_contains "$(cat "$work/err")$(bash "$BIN/warren-new-repo" svc2 go --org "$ORG" --dry-run --out "$work" 2>&1)" "(signed off)" "a real run would sign the first commit off"

# An owner without settings gets Apache-2.0 and the community files.
plain="$work/plain"
bash "$BIN/warren-new-repo" plain go --org Owner --dry-run -d "A lib." --out "$work" >/dev/null 2>&1
assert_contains "$(head -3 "$plain/LICENSE")" "Apache License" "owner without settings gets Apache-2.0"
assert_contains "$(cat "$plain/LICENSE")" "Copyright $(date +%Y) Owner" "the licence names the holder"
assert_eq "$(present "$plain/.github/CONTRIBUTING.md")" yes "owner without settings keeps the community files"
assert_contains "$(cat "$plain/Taskfile.yaml")" 'TEMPLATE_LIC: "apache2"' "default golic template is apache2"
assert_contains "$(cat "$plain/CLAUDE.md")" "The operator (@Owner)" "the operator defaults to the owner"
assert_eq "$(grep -cE 'hub-only:|standalone:' "$plain/CLAUDE.md")" 0 "no audience marker reaches a repo"

# The extends owner: shared release-drafter config, sponsor file, emoji-free README.
ext="$work/ext"
bash "$BIN/warren-new-repo" ext go --org extends-owner --dry-run -d "A lib." --out "$work" >/dev/null 2>&1
assert_contains "$(cat "$ext/.github/workflows/job-release-drafter.yaml")" "extends: 'extends-owner/.github@main'" "release-drafter extends the owner's shared config"
assert_eq "$(present "$ext/.github/release-drafter.yml")" no "no local release-drafter copy"
assert_eq "$(cat "$ext/.github/FUNDING.yml")" "github: [extends-owner]" "sponsor file from the funding setting"
assert_eq "$(head -1 "$ext/README.md")" "# ext" "readme-emoji=false strips the README emoji"
assert_contains "$(cat "$plain/.github/workflows/job-release-drafter.yaml")" "extends: ''" "an owner without the setting extends nothing"

# Every ecosystem composes for an Apache owner with no MIT text left.
for eco in npm python; do
  bash "$BIN/warren-new-repo" "x$eco" "$eco" --org "$ORG" --dry-run --out "$work" >/dev/null 2>"$work/$eco.err"; rc=$?
  expect 0 "$eco composes for an Apache owner"
  assert_eq "$(grep -rlw MIT "$work/x$eco" --exclude=LICENSE --exclude-dir=.github --exclude-dir=node_modules | wc -l | tr -d ' ')" 0 "$eco leaves no MIT text outside LICENSE and the dependency allow-list"
done
# An MIT owner gets the MIT text; an owner with a licence the base has no text for must bring one.
bash "$BIN/warren-new-repo" mitx go --org mit-owner --dry-run --out "$work" >/dev/null 2>&1; rc=$?
expect 0 "an MIT owner composes"
assert_contains "$(head -1 "$work/mitx/LICENSE")" "MIT License" "an MIT owner gets the MIT text"
assert_contains "$(cat "$work/mitx/Taskfile.yaml")" 'TEMPLATE_LIC: "mit"' "and the mit golic template"
bash "$BIN/warren-new-repo" oddx go --org odd-owner --dry-run --out "$work" >/dev/null 2>"$work/odd.err"; rc=$?
expect 1 "a licence with no shipped text and no overlay LICENSE fails"
assert_contains "$(cat "$work/odd.err")" "EUPL-1.2" "the failure names the licence"

# The overlay for an existing repo of the owner.
repo="$(mktmp)"; cd "$repo" || exit 1
git init -q
printf 'module example.com/m\n\ngo 1.26\n' > go.mod
mkdir -p .github/workflows
printf '/.github/workflows/** @example-maintainer\n/release/** @Example-Org/release-review\n' > .github/CODEOWNERS
printf 'name: checks\n' > .github/workflows/checks.yml
printf 'Apache text\n' > LICENSE
ov() { ( org_use "$ORG"; org_env "$ORG" svc "A service."; apply_overlay ) >/dev/null 2>&1; }
ov
for f in $dropped; do assert_eq "$(present "$f")" no "sync drops $f"; done
assert_eq "$(grep -cE '^\*[[:space:]]' .github/CODEOWNERS)" 0 "sync adds no root CODEOWNERS rule"
assert_contains "$(cat .github/CODEOWNERS)" "/release/** @Example-Org/release-review" "sync keeps the repo's own CODEOWNERS lines"
assert_eq "$(grep -c '^/.github/CODEOWNERS @example-maintainer$' .github/CODEOWNERS)" 1 "sync adds a missing owner line once"
assert_eq "$(cat .github/workflows/checks.yml)" "name: checks" "sync leaves the repo's CI caller alone"
assert_eq "$(cat LICENSE)" "Apache text" "sync leaves the licence alone"
assert_eq "$(present .github/workflows/job-go-security.yaml)" yes "sync still lays the Go workflows"
ov
assert_eq "$(grep -c '^/.github/CODEOWNERS @example-maintainer$' .github/CODEOWNERS)" 1 "a second sync changes nothing"
assert_eq "$(tmpl_refs .)" "" "synced repo names no template path and no org operator"

# A skip entry can never reach outside the repo.
evil="$(mktmp)"; mkdir -p "$evil/o" "$evil/repo" "$evil/keep"
printf 'owners=evil\n' > "$evil/o/scaffold.conf"
printf '../keep\n/etc\n.github/../../keep\n' > "$evil/o/governance.skip"
ORG_DIR="$evil/o" org_skip "$evil/repo" 2>/dev/null
assert_eq "$(present "$evil/keep")" yes "skip entries with .. or a leading / are ignored"

# warren-apply-governance --sync --eco on an existing repo of the owner.
ex="$(mktmp)/svc-two"; mkdir -p "$ex"; cd "$ex" || exit 1
git init -q; git remote add origin "https://github.com/$ORG/svc-two.git"
printf 'module example.com/m\n\ngo 1.26\n' > go.mod
mkdir -p .github/workflows; printf 'name: checks\n' > .github/workflows/checks.yml
printf 'Apache text\n' > LICENSE; printf 'kept\n' > NOTICE; printf 'version: "2"\n' > .golangci.yml
bash "$BIN/warren-apply-governance" --sync --eco go -d "A service." "$ex" >/dev/null 2>&1; rc=$?
expect 0 "apply --sync --eco succeeds"
assert_eq "$(present .github/workflows/job-go-lang-ci.yaml)" yes "apply --eco lays the ecosystem CI"
assert_eq "$(present .github/workflows/job-release-drafter.yaml)" yes "apply --eco lays the release drafter"
assert_eq "$(present .github/CONTRIBUTING.md)" no "apply --sync drops the owner-provided files"
assert_eq "$(cat .github/workflows/checks.yml)" "name: checks" "apply keeps the repo's CI caller"
assert_eq "$(cat NOTICE)" kept "apply keeps the repo's NOTICE"
assert_eq "$(cat .golangci.yml)" 'version: "2"' "apply keeps the repo's lint config"
assert_contains "$(cat .licignore)" '!*.proto' "apply lays the owner's .licignore"
assert_contains "$(cat Taskfile.yaml)" 'TEMPLATE_LIC: "spdx-apache2"' "apply fills the owner golic template"
assert_contains "$(cat Taskfile.yaml)" 'ARTIFACT_NAME: svc-two' "apply fills the repo name"
assert_eq "$(grep -rl '__[A-Z_]*__' .github Taskfile.yaml .licignore .golic.yaml | wc -l | tr -d ' ')" 0 "apply leaves no token"
assert_eq "$(git config --local --get core.hooksPath || true)" "" "apply never sets core.hooksPath"
assert_eq "$(present .git/hooks/pre-push)" no "apply installs no repo git hooks"
assert_eq "$(tmpl_refs .)" "" "applied repo names no template path and no org operator"

assert_eq "$(present .github/workflows/job-golic.yaml)" no "repo-skip keeps a shared file out of the one repo it names"
assert_eq "$(present .github/workflows/job-pr-checks.yaml)" yes "repo-skip leaves the rest of the shared set"

# A protected repo is refused unless forced, and nothing is written.
prot="$(mktmp)/hands-off"; mkdir -p "$prot"; cd "$prot" || exit 1
git init -q; git remote add origin "https://github.com/$ORG/hands-off.git"
out="$(bash "$BIN/warren-apply-governance" --sync "$prot" 2>&1)"; rc=$?
assert_eq "$rc" 3 "a protected repo is refused (exit 3)"
has "protected" "the refusal says why"
assert_eq "$(present CLAUDE.md)$(present .github)" nono "nothing is written to a protected repo"
bash "$BIN/warren-apply-governance" --sync --force -d "x" "$prot" >/dev/null 2>&1; rc=$?
expect 0 "--force applies it anyway"
assert_eq "$(present .github/workflows/job-pr-checks.yaml)" yes "the forced run lays the shared set"

bare="$(mktmp)/r"; mkdir -p "$bare"; cd "$bare" || exit 1
git init -q; git remote add origin "https://github.com/$ORG/r.git"; printf 'module example.com/m\n' > go.mod
bash "$BIN/warren-apply-governance" --sync -d "A repo." "$bare" >/dev/null 2>&1; rc=$?
expect 0 "apply --sync without --eco succeeds"
assert_eq "$(grep -c 'layout:begin' CLAUDE.md)" 0 "apply --sync without --eco writes no layout block"
finish
