#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Denies gh pr merge and gh api merge calls unless a fresh ~/.claude/warren/merge-yes/<owner>__<repo>__<n> marker exists (plan repos excepted; merge-green.sh checks the marker itself).
# Logic is in gh-guards.py (mode merge-gate). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/gh-guards.py" merge-gate
