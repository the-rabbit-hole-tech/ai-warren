#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# Denies `tmux kill-window`, and `tmux kill-pane` on the last pane, when it would leave the target
# session with no windows: closing the last window ends the session. Also denied: `kill-server`,
# `kill-session` on the sessions named in WARREN_OPS_SESSION and WARREN_CODING_SESSION (default
# ops and work; `kill-session -a` always), `kill-window` inside a for/while/until loop or behind
# xargs, and `send-keys` of `exit` or C-d at a session's last window. The target comes from -t
# (default: the current session) and is checked with `tmux display-message`. A command that cannot
# be parsed, tmux not being installed or running, or a target tmux can't resolve is allowed: this
# guard has nothing to check then. A `tmux new-window` or `new-session` earlier in the same command
# counts as the placeholder window.
set -euo pipefail
PY="$(command -v python3 || echo /usr/bin/python3)"
input="$(cat)"

hit="$(printf '%s' "$input" | "$PY" -I -c '
import json, os, re, shlex, subprocess, sys

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    sys.exit()
if not isinstance(cmd, str) or "tmux" not in cmd:
    sys.exit()
PROTECTED = {os.environ.get("WARREN_OPS_SESSION") or "ops", os.environ.get("WARREN_CODING_SESSION") or "work"}

SEPARATORS = {"&&", "||", ";", ";;", "|", "|&", "&", "(", ")", "\n"}
GLOBAL_WITH_VALUE = {"-L", "-S", "-f", "-c", "-T"}
KILL_WINDOW = {"kill-window", "killw"}
KILL_PANE = {"kill-pane", "killp"}
KILL_SESSION = {"kill-session"}
SEND_KEYS = {"send-keys", "send"}
PLACEHOLDER = {"new-window", "neww", "new-session", "new"}

try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    toks = list(lex)
except Exception:
    sys.exit()

segs, seg = [], []
for t in toks:
    if t in SEPARATORS:
        if seg:
            segs.append(seg)
        seg = []
    else:
        seg.append(t)
if seg:
    segs.append(seg)

def tmux_args(seg):
    """(args after tmux, whether xargs feeds it); None when the segment does not run tmux."""
    xargs = False
    for j, t in enumerate(seg):
        if os.path.basename(t) == "tmux":
            return seg[j + 1:], xargs
        if t == "xargs":
            xargs = True
        elif xargs:
            continue
        elif "=" not in t and t not in ("env", "command", "exec", "sudo", "time", "do", "then", "else", "!", "{"):
            return None
    return None

def split(args):
    i = 0
    while i < len(args) and args[i].startswith("-"):
        i += 2 if args[i] in GLOBAL_WITH_VALUE else 1
    return (args[i], args[i + 1:]) if i < len(args) else (None, [])

def target_of(rest):
    for k, a in enumerate(rest):
        if a == "-t":
            return rest[k + 1] if k + 1 < len(rest) else None
        if a.startswith("-t") and len(a) > 2:
            return a[2:]
    return None

def flags(rest):
    out = set()
    for a in rest:
        if a == "--":
            break
        if a.startswith("-") and len(a) > 1 and not a.startswith("-t"):
            out.update(a[1:])
    return out

def windows_of(target):
    argv = ["tmux", "display-message", "-p"] + (["-t", target] if target else []) + ["#{session_windows} #{window_panes} #S"]
    try:
        out = subprocess.run(argv, capture_output=True, text=True, timeout=5)
        if out.returncode != 0:
            return None
        parts = out.stdout.split(None, 2)
        return int(parts[0]), int(parts[1]), (parts[2].strip() if len(parts) > 2 else "")
    except Exception:
        return None

placeholder = False
depth = 0
for seg in segs:
    if seg[0] in ("for", "while", "until"):
        depth += 1
    elif seg[0] == "done":
        depth = max(0, depth - 1)
    got = tmux_args(seg)
    if got is None:
        continue
    args, via_xargs = got
    sub, rest = split(args)
    if sub in PLACEHOLDER:
        placeholder = True
        continue
    if sub == "kill-server":
        print("server")
        break
    if sub in KILL_SESSION:
        if "a" in flags(rest):
            print("session")
            break
        target = target_of(rest)
        name = target.lstrip("=").split(":")[0] if target else None
        if name is None:
            info = windows_of(None)
            name = info[2] if info else None
        if name in PROTECTED:
            print("session")
            break
        continue
    if sub in SEND_KEYS:
        keys = [a for a in rest if not a.startswith("-")]
        t = target_of(rest)
        if t is not None and t in keys:
            keys.remove(t)
        if placeholder or not any(re.fullmatch(r"(exit(\s.*)?|C-d)", k.strip()) for k in keys):
            continue
        info = windows_of(t)
        if info and info[0] <= 1:
            print("send-keys")
            break
        continue
    if sub not in KILL_WINDOW and sub not in KILL_PANE:
        continue
    if "a" in flags(rest) or placeholder:
        continue
    if sub in KILL_WINDOW and (depth > 0 or via_xargs):
        print("loop")
        break
    info = windows_of(target_of(rest))
    if info is None:
        continue
    windows, panes, _ = info
    if windows <= 1 and (sub in KILL_WINDOW or panes <= 1):
        print(sub)
        break
')"

[ -z "$hit" ] && exit 0

case "$hit" in
  server) msg="tmux kill-server ends every session, the operator and coding sessions included. Close the one window you mean." ;;
  session) msg="That kills the operator or coding session (WARREN_OPS_SESSION, WARREN_CODING_SESSION). Close single windows instead." ;;
  loop) msg="Don't kill windows in a loop: it can close the last window and end the session. Kill each named window on its own, with a placeholder window made first." ;;
  send-keys) msg="Sending exit or C-d to the last window ends the tmux session. Keep a placeholder window first." ;;
  *) msg="That closes the last window and ends the tmux session. Keep a placeholder window first." ;;
esac
"$PY" -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$msg"
exit 0
