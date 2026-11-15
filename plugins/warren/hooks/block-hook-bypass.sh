#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash).
# Denies a git command that would skip or replace the git hooks: --no-verify (any git subcommand),
# -n on git commit, and a core.hooksPath override (-c, --config-env, the environment) or write
# (git config). The identity guard and the scrub gate run as git hooks, so going around them turns
# the guard off. Reading core.hooksPath stays allowed.
# A command that cannot be parsed but names the bypass next to git is denied: a guard that cannot
# verify blocks.
set -euo pipefail
PY="$(command -v python3 || echo /usr/bin/python3)"
input="$(cat)"

reason="$(printf '%s' "$input" | "$PY" -c '
import json, os, re, shlex, sys

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    sys.exit()
if not isinstance(cmd, str) or not cmd:
    sys.exit()

SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
SEPARATORS = {"&&", "||", ";", ";;", "|", "|&", "&", "(", ")", "\n"}
GLOBAL_WITH_VALUE = {"-C", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix"}
VALUE_SHORT = set("mFCctS")  # commit options that take a value; the rest of the cluster is that value
CONFIG_WRITES = {"--unset", "--unset-all", "--replace-all", "--add", "--edit", "-e"}
RAW_BYPASS = re.compile(r"--no-verify|core\.hookspath", re.I)

def deny(what):
    return what

def strip_heredocs(text):
    # a heredoc body is text, not commands
    return re.sub(r"<<-?\s*([\x27\"]?)(\w+)\1[^\n]*\n.*?\n\s*\2(?=\n|$)",
                  lambda m: m.group(0).split("\n", 1)[0], text, flags=re.S)

def tokens(text):
    lex = shlex.shlex(strip_heredocs(text), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    return list(lex)

def segments(toks):
    seg = []
    for t in toks:
        if t in SEPARATORS:
            if seg:
                yield seg
            seg = []
        else:
            seg.append(t)
    if seg:
        yield seg

def check_git(args):
    # args: the tokens after "git"
    i = 0
    while i < len(args):
        a = args[i]
        if a == "-c" and i + 1 < len(args):
            if args[i + 1].split("=", 1)[0].lower() == "core.hookspath":
                return "-c core.hooksPath"
            i += 2
            continue
        if a.startswith("--config-env"):
            val = a.split("=", 1)[1] if "=" in a else (args[i + 1] if i + 1 < len(args) else "")
            if val.split("=", 1)[0].lower() == "core.hookspath":
                return "--config-env core.hooksPath"
            i += 1 if "=" in a else 2
            continue
        if a in GLOBAL_WITH_VALUE:
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        break
    if i >= len(args):
        return None
    sub, rest = args[i], args[i + 1:]
    if any(a == "--no-verify" for a in rest):
        return "--no-verify"
    if sub == "commit":
        for a in rest:
            if a == "--":
                break
            if a.startswith("-") and not a.startswith("--"):
                for ch in a[1:]:
                    if ch == "n":
                        return "commit -n"
                    if ch in VALUE_SHORT:
                        break
    if sub == "config":
        names = [a for a in rest if not a.startswith("-")]
        if any(n.lower() == "core.hookspath" for n in names):
            read_only = {"--get", "--get-all", "--get-regexp", "--list", "-l", "--show-origin", "--show-scope"}
            if any(a in read_only for a in rest):
                return None
            if len(names) >= 2 or any(a in CONFIG_WRITES for a in rest):
                return "git config core.hooksPath"
    return None

def check_tokens(toks, depth=0):
    for seg in segments(toks):
        for t in seg:
            if re.match(r"GIT_CONFIG_KEY_\d+=core\.hookspath$", t, re.I):
                return "core.hooksPath through the environment"
        base = [os.path.basename(t) for t in seg]
        if base[0] in SHELLS and depth < 3:
            for j, t in enumerate(seg[1:], 1):
                if t.startswith("-") and not t.startswith("--") and "c" in t[1:] and j + 1 < len(seg):
                    found = check_tokens(tokens(seg[j + 1]), depth + 1)
                    if found:
                        return found
                    break
        if base[0] == "eval" and depth < 3:
            found = check_tokens(tokens(" ".join(seg[1:])), depth + 1)
            if found:
                return found
        for j, b in enumerate(base):
            if b == "git":
                found = check_git(seg[j + 1:])
                if found:
                    return found
                break
    return None

try:
    found = check_tokens(tokens(cmd))
except Exception:
    found = None
    if re.search(r"\bgit\b", cmd) and RAW_BYPASS.search(cmd):
        found = "an unparseable command that names it"
if found:
    print(found)
')"

[ -z "$reason" ] && exit 0

msg="Blocked: this would skip or replace the git hooks (${reason}). Warren rule 4: never --no-verify, never change core.hooksPath. The identity guard and the scrub gate run as git hooks. Fix what the hook reports instead of going around it."
"$PY" -c 'import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":sys.argv[1]}}))' "$msg"
exit 0
