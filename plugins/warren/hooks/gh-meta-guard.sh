#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Denies gh issue create without --assignee, --milestone and a --label, and gh pr create without --assignee and --milestone; reminds to set the issue type after an allowed issue create.
# Logic is in gh-guards.py (mode meta). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/gh-guards.py" meta
