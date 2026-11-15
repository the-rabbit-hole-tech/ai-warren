#!/usr/bin/env bash
# warren-new-repo end to end, against a stub gh and a local bare repo standing in for GitHub.
# It makes commits, so it runs only in the sandbox (CI or tests/sandbox.sh).
# Ported from the governance template's new-repo test.
source "$(dirname "$0")/lib.sh"
needs_sandbox
sandbox="$(mktmp)"; trap 'rm -rf "$sandbox"' EXIT
remotes="$sandbox/remotes"; hooks="$sandbox/hooks"; stub="$sandbox/bin"
mkdir -p "$remotes" "$hooks" "$stub"
export STUB_LOG="$sandbox/gh.log" STUB_REMOTES="$remotes" ORIGIN_LOG="$sandbox/origin.log"
# A clean git config: github.com URLs resolve to the local bare repos, and a pre-commit hook
# records origin at commit time, as a host identity guard reads it.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$sandbox/gitconfig"
git config --global url."file://$remotes/".insteadOf https://github.com/
git config --global core.hooksPath "$hooks"
git config --global init.defaultBranch main
cat > "$hooks/pre-commit" <<'SH'
#!/usr/bin/env bash
git config --get remote.origin.url >> "$ORIGIN_LOG" 2>/dev/null || echo "<none>" >> "$ORIGIN_LOG"
SH
chmod +x "$hooks/pre-commit"
cat > "$stub/gh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$*" in
  "api user --jq .login") echo octo-op ;;
  "api user --jq .id") echo 1000 ;;
  "repo create "*) git init -q --bare "$STUB_REMOTES/$3.git" ;;
  *) exit 0 ;;
esac
SH
chmod +x "$stub/gh"
export PATH="$stub:$PATH"
run() { local dir="$1"; shift; mkdir -p "$dir"; : > "$STUB_LOG"; : > "$ORIGIN_LOG"
  out="$(cd "$dir" && bash "$BIN/warren-new-repo" "$@" 2>&1)"; rc=$?; }

w="$sandbox/create"
run "$w" demo go --org Example-Org -d "A demo."
expect 0 "create: succeeds"
assert_eq "$(cat "$ORIGIN_LOG")" "https://github.com/Example-Org/demo.git" "create: origin is set before the first commit"
assert_eq "$(git -C "$remotes/Example-Org/demo.git" rev-parse main 2>/dev/null)" "$(git -C "$w/demo" rev-parse HEAD 2>/dev/null)" "create: the first commit reaches the remote"
assert_eq "$(grep -c '^repo create Example-Org/demo --public' "$STUB_LOG")" 1 "create: gh repo create is called"
assert_contains "$(cat "$STUB_LOG")" "repos/Example-Org/demo/rulesets" "create: the ruleset is applied"
assert_contains "$(cat "$STUB_LOG")" "repo edit Example-Org/demo --add-topic golang" "create: the topics are applied"
msg="$(git -C "$w/demo" log -1 --format=%B)"
assert_eq "$(printf '%s\n' "$msg" | head -1)" "chore(repo): scaffold demo" "create: neutral subject"
assert_contains "$msg" "Signed-off-by: octo-op <1000+octo-op@users.noreply.github.com>" "create: DCO sign-off for a dco owner"
assert_eq "$(git -C "$w/demo" config user.email)" "1000+octo-op@users.noreply.github.com" "create: the operator's noreply identity"
case "$msg" in *"$SC"*|*://*) leak=yes ;; *) leak=no ;; esac
assert_eq "$leak" no "create: the commit message names no path or URL"
assert_eq "$(git -C "$w/demo" grep -I -l -e "$SC" HEAD 2>/dev/null)" "" "create: no committed file names the plugin path"

git init -q --bare "$remotes/Example-Org/old.git"
w="$sandbox/existing"
run "$w" old go --org Example-Org --existing -d "A demo."
expect 0 "existing: succeeds"
assert_eq "$(git -C "$remotes/Example-Org/old.git" rev-parse main 2>/dev/null)" "$(git -C "$w/old" rev-parse HEAD 2>/dev/null)" "existing: the first commit reaches the remote"
assert_eq "$(grep -c '^repo create ' "$STUB_LOG")" 0 "existing: no gh repo create"

w="$sandbox/local"
run "$w" solo go --org Owner --no-remote -d "A demo."
expect 0 "no-remote: succeeds"
assert_eq "$(git -C "$w/solo" rev-list --count HEAD 2>/dev/null)" 1 "no-remote: the first commit is made"
assert_eq "$(grep -c -e '^repo create ' -e '^api repos/' -e '^repo edit ' "$STUB_LOG")" 0 "no-remote: nothing is created on GitHub"
has "not pushed" "no-remote: says the push was skipped"
has "origin main" "no-remote: says how to send it later"
assert_eq "$(git -C "$w/solo" log -1 --format=%B | grep -c Signed-off-by)" 0 "no-remote: no sign-off for an owner without dco"
finish
