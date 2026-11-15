"""The skill-first gate behind skill-record.sh (PostToolUse on the Skill tool) and skill-gate.sh
(PreToolUse on Bash). Modes: record, gate.

record writes ~/.claude/warren/skills-loaded/<session_id>/<skill name>. gate maps the command to
the skill that skill-gate.tsv requires and denies with "Load skill <name> first" while this
session has no marker for it. Quiet when nothing is wrong; malformed input is allowed.
"""
import glob
import json
import os
import re
import shlex
import sys

SEPARATORS = {"&&", "||", ";", ";;", "|", "|&", "&", "(", ")", "\n"}
SKIP_WORDS = {"do", "then", "else", "elif", "if", "while", "until", "!", "{", "}", "time", "env",
              "command", "exec", "sudo", "nohup", "xargs"}
TMUX_GLOBAL_WITH_VALUE = {"-L", "-S", "-f", "-c", "-T"}
SAFE = re.compile(r"^[A-Za-z0-9._:-]+$")


def home():
    return os.path.join(os.path.expanduser("~"), ".claude")


def state_dir(session):
    return os.path.join(home(), "warren", "skills-loaded", session)


def load():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def mode_record(data):
    session = data.get("session_id")
    skill = (data.get("tool_input") or {}).get("skill")
    if not isinstance(session, str) or not isinstance(skill, str):
        return
    skill = skill.lstrip("/").strip()
    if not SAFE.match(session) or not SAFE.match(skill) or skill.startswith("."):
        return
    d = state_dir(session)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, skill), "a"):
        pass


def segments(cmd):
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        toks = list(lex)
    except Exception:
        return []
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
    return segs


def keys(cmd):
    """One key per gh or tmux invocation: "gh pr create", "tmux kill-window"."""
    out = []
    for seg in segments(cmd):
        j = 0
        while j < len(seg) and (SKIP_WORDS & {seg[j]} or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[j])):
            j += 1
        if j >= len(seg):
            continue
        head, args = os.path.basename(seg[j]), seg[j + 1:]
        if head == "gh":
            pos, i = [], 0
            while i < len(args) and len(pos) < 2:
                if args[i] in ("-R", "--repo"):
                    i += 2
                    continue
                if not args[i].startswith("-"):
                    pos.append(args[i])
                i += 1
            if len(pos) == 2:
                out.append("gh %s %s" % tuple(pos))
        elif head == "tmux":
            i = 0
            while i < len(args) and args[i].startswith("-"):
                i += 2 if args[i] in TMUX_GLOBAL_WITH_VALUE else 1
            if i < len(args):
                out.append("tmux " + args[i])
    return out


def table():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "skill-gate.tsv")
    rows = []
    try:
        with open(path) as f:
            for line in f:
                line = line.rstrip("\n")
                if not line.strip() or line.startswith("#") or "\t" not in line:
                    continue
                rx, skill = line.split("\t", 1)
                rows.append((re.compile(rx), skill.strip()))
    except (OSError, re.error):
        pass
    return rows


def skill_installed(name):
    if ":" not in name:
        return False
    plugin, skill = name.split(":", 1)
    cfg = os.environ.get("CLAUDE_CONFIG_DIR") or home()
    pats = [os.path.join(cfg, "plugins", "cache", "*", plugin, "*", "skills", skill, "SKILL.md")]
    root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if root:
        pats.append(os.path.join(root, "..", plugin, "skills", skill, "SKILL.md"))
    return any(glob.glob(p) for p in pats)


def mode_gate(data):
    cmd = (data.get("tool_input") or {}).get("command")
    session = data.get("session_id")
    if not isinstance(cmd, str) or not isinstance(session, str) or not SAFE.match(session):
        return
    if "gh" not in cmd and "tmux" not in cmd:
        return
    rows = table()
    for key in keys(cmd):
        for rx, skill in rows:
            if not rx.search(key):
                continue
            names = [n.strip() for n in skill.split("|") if n.strip()]
            need = [n for n in names if skill_installed(n)]
            if not need:
                break
            if not any(os.path.exists(os.path.join(state_dir(session), n)) for n in need):
                reason = "Load skill %s first (Skill tool), then run this again." % need[0]
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                  "permissionDecision": "deny", "permissionDecisionReason": reason}}))
                return
            break


def main():
    data = load()
    if data is None:
        return
    {"record": mode_record, "gate": mode_gate}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda d: None)(data)


try:
    main()
except Exception:
    pass
