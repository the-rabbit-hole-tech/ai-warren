#!/usr/bin/env bash
# PostToolUse hook (matcher: Skill). Records each loaded skill per session under ~/.claude/warren/skills-loaded/<session_id>/.
# Logic is in skill-gate.py (mode record). Quiet unless it denies; malformed input is allowed.
PY="$(command -v python3 || echo /usr/bin/python3)"
exec "$PY" -I "$(dirname "${BASH_SOURCE[0]}")/skill-gate.py" record
