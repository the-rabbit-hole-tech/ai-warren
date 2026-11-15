#!/usr/bin/env bash
# Runs inside the clean container (see Dockerfile): warren init from the example answers, then
# warren doctor, then a guarded commit and push as testperson and a blocked one as someone else.
# pass and fail always return 0, so "a && pass || fail" reads as if-then-else here.
# shellcheck disable=SC2015
set -uo pipefail

fails=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; fails=$((fails + 1)); }

unset GH_TOKEN
echo "== warren init --config /test/agent-machine.yaml"
if warren init --config /test/agent-machine.yaml | tee /tmp/init.out; then
  pass "warren init exited 0"
else
  fail "warren init exited non-zero"
fi
grep -Eq '^gh-auth +skipped +skipped: no token' /tmp/init.out && pass "gh-auth skipped: no token" || fail "gh-auth was not skipped"
for t in tmux gh; do command -v "$t" >/dev/null && pass "$t installed" || fail "$t not installed"; done
[ -x "$HOME/.local/bin/claude" ] && pass "claude installed by the official installer ($("$HOME/.local/bin/claude" --version 2>/dev/null))" || fail "claude not installed"

echo "== warren init again (nothing should change)"
warren init --config /test/agent-machine.yaml | tee /tmp/init2.out
grep -q ' changed ' /tmp/init2.out && fail "second init changed something" || pass "second init changed nothing"

echo "== warren doctor --json"
warren doctor --json | tee /tmp/doctor.json
python3 -I - /tmp/doctor.json <<'PY' && pass "doctor: every step ok except gh-auth and host (skipped)" || fail "doctor report unexpected"
import json, sys
rep = json.load(open(sys.argv[1]))
got = {s["step"]: s["status"] for s in rep["steps"]}
want = {k: "ok" for k in ["tools", "marketplace", "plugins", "guard-identity", "guard-sync", "path", "lessons-log"]}
want["gh-auth"] = "skipped"
want["host"] = "skipped"
sys.exit(0 if got == want and rep["ok"] else 1)
PY

echo "== guard"
echo "core.hooksPath=$(git config --global core.hooksPath)"
echo "hooks link -> $(readlink "$HOME/.config/git/hooks")"
echo "guard.expectedLogin=$(git config --global guard.expectedLogin)"
# gh must report testperson as the active account for the guard; no real token is involved.
mkdir -p "$HOME/.config/gh"
cat > "$HOME/.config/gh/hosts.yml" <<'YML'
github.com:
    users:
        testperson:
    user: testperson
    oauth_token: placeholder
    git_protocol: https
YML
echo "gh active account: $(gh config get -h github.com user)"

git init -q --bare /tmp/remote.git
git init -q -b main /tmp/work
cd /tmp/work || exit 1
git remote add origin /tmp/remote.git
echo one > one.txt && git add one.txt
if git commit -q -m "test: first commit as testperson"; then pass "commit as testperson allowed"; else fail "commit as testperson blocked"; fi
if git push -q origin main 2>/tmp/push.err; then pass "push as testperson to the bare repo allowed"; else fail "push blocked: $(cat /tmp/push.err)"; fi
echo two > two.txt && git add two.txt
if GIT_AUTHOR_NAME=other GIT_AUTHOR_EMAIL=other@example.com git commit -q -m "test: commit as someone else" 2>/tmp/commit.err; then
  fail "commit as another author was allowed"
else
  pass "commit as another author blocked: $(head -1 /tmp/commit.err)"
fi

echo "== $fails failure(s)"
exit "$fails"
