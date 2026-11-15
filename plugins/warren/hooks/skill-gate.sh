#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Denies a gh or tmux command whose skill (skill-gate.tsv) this session has not loaded: Load skill <name> first.
# Logic is in skill-gate.py (mode gate). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/skill-gate.py" gate
