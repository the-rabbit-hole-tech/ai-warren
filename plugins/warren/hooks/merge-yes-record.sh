#!/usr/bin/env bash
# PostToolUse hook (matcher: the question tool). Writes a merge-yes marker per PR when the answer to a question naming owner/repo and #<n> starts with Yes.
# Logic is in gh-guards.py (mode merge-record). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/gh-guards.py" merge-record
