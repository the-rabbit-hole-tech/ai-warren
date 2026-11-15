#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# On `git push`, gives fast feedback: blocks if there are uncommitted changes or
# if a quick test pass fails for the detected ecosystem. The git pre-push hook is
# the authoritative gate; this just shortens the feedback loop.
set -euo pipefail
PY="$(command -v python3 || echo /usr/bin/python3)"
input="$(cat)"
# Prints the folder the push targets: `git -C <dir> push`, else a leading
# `cd <dir> &&`, else the payload's cwd. Prints nothing when it isn't a push.
dir="$(printf '%s' "$input" | "$PY" -c 'import json,os,re,shlex,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
cmd=d.get("tool_input",{}).get("command","") or ""
base=d.get("cwd") or os.getcwd()
arg=r"(?:\x27[^\x27]*\x27|\"[^\"]*\"|\S+)"
m=re.search(r"\bgit((?:\s+-C\s+"+arg+r")*)\s+push\b",cmd)
if not m: sys.exit(0)
c=re.match(r"\s*cd\s+("+arg+r")\s*&&",cmd)
if c: base=os.path.join(base,os.path.expanduser(shlex.split(c.group(1))[0]))
for t in shlex.split(m.group(1)):
  if t!="-C": base=os.path.join(base,os.path.expanduser(t))
print(base)')"
[ -n "$dir" ] || exit 0
# Not a git repo (or gone): git's own pre-push hook decides.
cd "$dir" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

deny() {
  "$PY" -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$1"
  exit 0
}

if ! git diff --quiet --exit-code 2>/dev/null; then
  deny "Uncommitted changes present. Commit or stash before pushing."
fi
# A Linux-only repo can't run its tests here; CI is its gate.
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f go.mod ] && [ ! -f "$root/.claude/linux-only" ]; then
  if ! go test -short ./... >/dev/null 2>&1; then
    deny "Quick test pass failed (go test -short ./...). Fix before pushing."
  fi
fi
exit 0
