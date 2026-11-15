#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Denies gh repo edit --add-topic to-be-deleted; the single-topic PUT form is the way (github:repos).
# Logic is in gh-guards.py (mode topic). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/gh-guards.py" topic
