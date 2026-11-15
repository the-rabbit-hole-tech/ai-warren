"""The gh command guards behind meta-guard.sh, merge-yes-gate.sh, merge-yes-record.sh and
to-be-deleted-guard.sh. One mode per hook: meta, merge-gate, merge-record, topic.

Every mode reads the hook JSON on stdin, prints nothing when nothing is wrong and tolerates
malformed input by allowing (exit 0, no output). A deny is exit 0 plus a permissionDecision JSON.
"""
import json
import os
import re
import shlex
import subprocess
import sys
import time

SEPARATORS = {"&&", "||", ";", ";;", "|", "|&", "&", "(", ")", "\n"}
SKIP_WORDS = {"do", "then", "else", "elif", "if", "while", "until", "!", "{", "}", "time", "env",
              "command", "exec", "sudo", "nohup", "xargs"}
MARKER_DAYS = 7
REPO_RE = re.compile(r"(?<![A-Za-z0-9_./-])([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)")


def state_dir():
    return os.path.join(os.path.expanduser("~"), ".claude", "warren", "merge-yes")


def marker_path(repo, num):
    owner, name = repo.split("/", 1)
    return os.path.join(state_dir(), "%s__%s__%s" % (owner, name, num))


def marker_fresh(repo, num):
    try:
        age = time.time() - os.stat(marker_path(repo, num)).st_mtime
    except OSError:
        return False
    return age < MARKER_DAYS * 86400


def is_plan_repo(repo):
    # github:merge: plan repos merge without the owner's Yes.
    return repo.split("/", 1)[1] == "plan"


def emit(decision=None, reason=None, context=None):
    out = {"hookEventName": "PreToolUse"}
    if decision:
        out["permissionDecision"] = decision
        out["permissionDecisionReason"] = reason
    if context:
        out["additionalContext"] = context
    print(json.dumps({"hookSpecificOutput": out}))


def load():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def segments(cmd):
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        toks = list(lex)
    except Exception:
        return None
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


def head_and_args(seg):
    """The program name and its arguments, looking through env assignments and prefixes."""
    for j, t in enumerate(seg):
        if "=" in t and not t.startswith("-") and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            continue
        if t in SKIP_WORDS:
            continue
        return os.path.basename(t), seg[j + 1:]
    return None, []


def gh_calls(cmd):
    """Yield (group, verb, args) for each gh invocation: `gh pr create ...` is ("pr", "create", rest).
    Global flags between gh and the group (-R o/r) stay in args."""
    segs = segments(cmd)
    if segs is None:
        return []
    out = []
    for seg in segs:
        head, args = head_and_args(seg)
        if head != "gh":
            continue
        pos = [a for a in args if not a.startswith("-")]
        if args and args[0] == "api":
            out.append(("api", "", args[1:]))
        elif len(pos) >= 2:
            # Drop the flag values that would be taken for positionals before the verb.
            i = 0
            rest = list(args)
            while i < len(rest) and rest[i].startswith("-"):
                i += 2 if rest[i] in ("-R", "--repo") else 1
            if i + 1 < len(rest):
                out.append((rest[i], rest[i + 1], rest[i + 2:] + rest[:i]))
    return out


def has_flag(args, longs, shorts):
    for a in args:
        if a == "--":
            break
        for lf in longs:
            if a == lf or a.startswith(lf + "="):
                return True
        if a.startswith("-") and not a.startswith("--") and len(a) >= 2:
            if a[1] in shorts:
                return True
    return False


def flag_value(args, longs, shorts):
    for k, a in enumerate(args):
        for lf in longs:
            if a == lf and k + 1 < len(args):
                return args[k + 1]
            if a.startswith(lf + "="):
                return a[len(lf) + 1:]
        if a.startswith("-") and not a.startswith("--") and len(a) >= 2 and a[1] in shorts:
            if len(a) > 2:
                return a[2:].lstrip("=")
            if k + 1 < len(args):
                return args[k + 1]
    return None


def repo_of(args, cwd):
    r = flag_value(args, ["--repo"], ["R"])
    if r and re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", r.split("github.com/")[-1]):
        return r.split("github.com/")[-1]
    if not cwd or not os.path.isdir(cwd):
        return None
    try:
        url = subprocess.run(["git", "-C", cwd, "remote", "get-url", "origin"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return None
    m = re.search(r"github\.com[:/]([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+?)(?:\.git)?/?$", url)
    return "%s/%s" % (m.group(1), m.group(2)) if m else None


ISSUE_TYPE_NOTE = (
    "Set the issue type (Task, Bug or Feature; feat is Feature, fix is Bug, the rest Task) once the issue exists: "
    "gh api graphql -f query='mutation($i:ID!,$t:ID!){updateIssueIssueType(input:{issueId:$i,issueTypeId:$t}){issue{number}}}' "
    "-f i=\"$(gh api repos/<owner>/<repo>/issues/<n> -q .node_id)\" "
    "-f t=\"$(gh api graphql -f query='{repository(owner:\"<owner>\",name:\"<repo>\"){issueTypes(first:10){nodes{id name}}}}' "
    "-q '.data.repository.issueTypes.nodes[]|select(.name==\"Feature\").id')\""
)


def mode_meta(data):
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or "gh" not in cmd:
        return
    cwd = data.get("cwd") or ""
    issue_created = False
    for group, verb, args in gh_calls(cmd):
        if (group, verb) not in (("issue", "create"), ("pr", "create")):
            continue
        if repo_of(args, cwd) is None:
            continue
        missing = []
        if not has_flag(args, ["--assignee"], "a"):
            missing.append("--assignee")
        if not has_flag(args, ["--milestone"], "m"):
            missing.append("--milestone")
        if group == "issue" and not has_flag(args, ["--label"], "l"):
            missing.append("--label")
        if missing:
            what = "issue" if group == "issue" else "PR"
            extra = " (the label on a PR comes from the autolabeler)" if group == "pr" else ""
            emit("deny", "gh %s create is missing %s. Every %s gets its metadata when it is created%s; "
                 "see github:work." % (group, ", ".join(missing), what, extra))
            return
        if group == "issue":
            issue_created = True
    if issue_created:
        emit(context=ISSUE_TYPE_NOTE)


def merge_targets(cmd, cwd):
    """(repo, number) for each merge in the command; repo or number is None when it can't be told.
    A call through merge-green.sh is left to the script, which checks the marker itself."""
    targets = []
    for group, verb, args in gh_calls(cmd):
        if group == "pr" and verb == "merge":
            pos = []
            skip = False
            for a in args:
                if skip:
                    skip = False
                    continue
                if a in ("-R", "--repo", "-b", "--body", "-F", "--body-file", "-t", "--subject",
                         "-A", "--author-email", "--match-head-commit"):
                    skip = True
                elif not a.startswith("-"):
                    pos.append(a)
            repo = repo_of(args, cwd)
            num = None
            if pos:
                m = re.fullmatch(r"(?:https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/pull/)?(\d+)", pos[0])
                if m:
                    num = m.group(2)
                    repo = m.group(1) or repo
            targets.append((repo, num))
        elif group == "api":
            text = " ".join(args)
            m = re.search(r"repos/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/pulls/(\d+)/merge", text)
            if m:
                targets.append((m.group(1), m.group(2)))
            elif re.search(r"/pulls/[^ ]*/merge|mergePullRequest|enablePullRequestAutoMerge", text):
                targets.append((None, None))
    return targets


def mode_merge_gate(data):
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or "gh" not in cmd:
        return
    for repo, num in merge_targets(cmd, data.get("cwd") or ""):
        if repo is None or num is None:
            emit("deny", "Can't tell which PR this merges. Name it as gh pr merge <n> -R <owner>/<repo> so the "
                 "owner's Yes can be checked (github:merge).")
            return
        if is_plan_repo(repo) or marker_fresh(repo, num):
            continue
        emit("deny", "No owner Yes on record for %s PR #%s. Ask the owner (AskUserQuestion, "
             "\"Do you approve %s@PR#%s?\"); a Yes writes the marker. For a standing Yes the owner gave in words: "
             "warren-yes %s %s. Markers last %d days. See github:merge."
             % (repo, num, repo, num, repo, num, MARKER_DAYS))
        return


def stringify(resp):
    if isinstance(resp, str):
        return resp
    try:
        return json.dumps(resp)
    except Exception:
        return ""


def answers_for(question, resp):
    """The answer text recorded for this question, or None."""
    if isinstance(resp, dict) and isinstance(resp.get("answers"), dict):
        a = resp["answers"].get(question)
        if isinstance(a, str):
            return a
        if isinstance(a, list) and a and isinstance(a[0], str):
            return a[0]
    text = stringify(resp)
    for variant in {question, json.dumps(question)[1:-1], json.dumps(json.dumps(question))[3:-3]}:
        m = re.search(re.escape(variant) + r'\\?"\s*[=:]\s*\\?"((?:[^"\\]|\\.)*?)\\?"', text)
        if m:
            return m.group(1)
    return None


def question_targets(q):
    q = re.sub(r"https?://github\.com/", "", q)
    repos = [(m.end(), m.group(1).rstrip(".")) for m in REPO_RE.finditer(q)
             if re.search(r"[A-Za-z]", m.group(1))]
    nums = [(m.start(), m.group(1)) for m in re.finditer(r"(?:#|/pull/)(\d+)", q)]
    out = []
    for pos, n in nums:
        before = [r for end, r in repos if end <= pos]
        repo = before[-1] if before else (repos[0][1] if repos else None)
        if repo and (repo, n) not in out:
            out.append((repo, n))
    return out


def mode_merge_record(data):
    if data.get("tool_name") != "AskUserQuestion":
        return
    qs = (data.get("tool_input") or {}).get("questions")
    resp = data.get("tool_response")
    if not isinstance(qs, list) or resp is None:
        return
    for q in qs:
        text = q.get("question") if isinstance(q, dict) else None
        if not isinstance(text, str):
            continue
        ans = answers_for(text, resp)
        if not ans or not ans.startswith("Yes"):
            continue
        for repo, n in question_targets(text):
            try:
                os.makedirs(state_dir(), exist_ok=True)
                with open(marker_path(repo, n), "a"):
                    pass
                os.utime(marker_path(repo, n), None)
            except OSError:
                pass


def mode_topic(data):
    cmd = (data.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or "to-be-deleted" not in cmd:
        return
    for group, verb, args in gh_calls(cmd):
        if group == "repo" and verb == "edit":
            for k, a in enumerate(args):
                val = a[len("--add-topic="):] if a.startswith("--add-topic=") else (
                    args[k + 1] if a == "--add-topic" and k + 1 < len(args) else None)
                if val is not None and "to-be-deleted" in [v.strip() for v in val.split(",")]:
                    emit("deny", "A repo slated for deletion carries the single topic to-be-deleted: replace the topic "
                         "list instead of adding to it (gh api -X PUT repos/<owner>/<repo>/topics -f names[]=to-be-deleted). "
                         "See github:repos.")
                    return
        elif group == "api":
            text = " ".join(args)
            if re.search(r"/topics", text) and re.search(r"(-X|--method)[ =]*(PUT|put)", text):
                names = re.findall(r"names\[\]=?\s*([^\s]+)", text)
                if "to-be-deleted" in names and len(names) > 1:
                    emit("deny", "A repo slated for deletion carries the single topic to-be-deleted: names[] must be "
                         "to-be-deleted only. See github:repos.")
                    return


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    data = load()
    if data is None:
        return
    {"meta": mode_meta, "merge-gate": mode_merge_gate, "merge-record": mode_merge_record,
     "topic": mode_topic}.get(mode, lambda d: None)(data)


try:
    main()
except Exception:
    pass
