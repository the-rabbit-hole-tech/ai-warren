#!/usr/bin/env python3
"""Pre-push scrub gate, run by _dispatch after the identity check.

  python3 -I gate.py <remote-name> <remote-url>   (pre-push lines on stdin)

Scans only what is new to the remote. Layers (README has the detail):
  every push      secret patterns (patterns.txt) over added lines and messages;
                  attribution trailers (patterns.txt) in commit and tag messages
  governed repos  the AI-tell list (forbidden-text.txt next to this gate, or the shared rules repo clone's
                  copy when `git config guard.scrubHubPath` names one) over added lines and
                  messages, with the governance files' own path exemptions
  org remotes     the org scrub.py identifiers scan plus the local term lists
                  (orgs.conf), judged against `git ls-remote`, failing closed

The repo's reviewed allowlist, .github/scrub-allow.txt, is read from the remote's default
branch tip (never from what is being pushed), only when a finding it could cover turns up.
`ai-tell` entries apply to the AI-tell layer here; identifier entries go through the org
scanner's own matcher. Secrets and term-list hits can't be listed.

The term lists are local only: <name>-terms.txt in ~/.config/warren/terms/ (mode 600),
never in a repo. The org scanner clone (URL from SCRUB_ORG_SCANNER_URL or
`git config --global guard.scrubScannerUrl`) is cached in ~/.cache/git-scrub/. SCRUB_TERMS_DIR
and SCRUB_CACHE_DIR override the two folders. The org table is orgs.conf here plus the person's
local table, ~/.config/warren/scrub-orgs.conf (SCRUB_ORGS_FILE overrides it).

Exit 0 clean, 1 blocked. Any error blocks: the gate fails closed.
"""

import fnmatch
import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ZERO = re.compile(r"^0+$")
HUB_LIST = "governance/claude/hooks/forbidden-text.txt"
TELLS_FILE = "forbidden-text.txt"
DOCS_ALLOW = ".github/docs-allowed-forbidden-text.txt"
GOVERNED_MARKER = ".claude/hooks/forbidden-text.txt"
ORG_SCANNER_PATH = ".github/scripts/scrub.py"
TERMS_DIR = os.environ.get("SCRUB_TERMS_DIR") or os.path.expanduser("~/.config/warren/terms")
CACHE_DIR = os.environ.get("SCRUB_CACHE_DIR") or os.path.expanduser("~/.cache/git-scrub")
LOCAL_ORGS = os.environ.get("SCRUB_ORGS_FILE") or os.path.expanduser("~/.config/warren/scrub-orgs.conf")
ORG_SCANNER_CACHE = os.path.join(CACHE_DIR, "org-scanner.git")
ALLOW_SECRET = "scrub:allow=secret"
ALLOW_FILE = ".github/scrub-allow.txt"
ALLOW_CLASSES = ("private-ip", "email", "home-path", "fqdn", "ai-tell")
ALLOW_VALUE = re.compile(r"(?:[^%*?\[\]\s#]|%[0-9A-Fa-f]{2})+")
ALLOW_GLOB = re.compile(r"[^\s#]+")


class Blocked(Exception):
    """A condition the gate can't verify: block the push (fail closed)."""


def git(*args, inp=None, check=True, env=None):
    proc = subprocess.run(["git", "-c", "core.quotePath=false", *args], input=inp,
                          capture_output=True, env=env)
    if proc.returncode != 0 and check:
        err = proc.stderr.decode("utf-8", "replace").strip().splitlines()
        raise Blocked(f"git {args[0]} failed: {err[-1] if err else proc.returncode}")
    return proc.stdout.decode("utf-8", "replace") if proc.returncode == 0 else None


def clean_env():
    """Environment for git commands on another repository than the one pushing."""
    env = dict(os.environ)
    for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY",
              "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_COMMON_DIR", "GIT_PREFIX"):
        env.pop(k, None)
    return env


def mask(value, keep=3):
    value = value.strip()
    if len(value) <= keep + 1:
        return "*" * len(value)
    return f"{value[:keep]}...({len(value)} chars)"


def read_list(text):
    return [l.rstrip("\r") for l in text.split("\n")
            if l.strip() and not l.lstrip().startswith("#")]


# --- what is being pushed -------------------------------------------------

def read_updates(stdin):
    ups = []
    for line in stdin.split("\n"):
        parts = line.split()
        if len(parts) == 4:
            ups.append(tuple(parts))
    return ups


def local_objects(shas):
    if not shas:
        return set()
    out = git("cat-file", "--batch-check=%(objectname) %(objecttype)",
              inp="\n".join(shas).encode() + b"\n")
    return {l.split()[0] for l in out.splitlines() if l.endswith((" commit", " tag"))}


def remote_shas(url):
    out = git("ls-remote", url, check=False)
    if out is None:
        return None
    return [l.split()[0] for l in out.splitlines() if l.strip()]


def outgoing(tips, exclude):
    """Commits reachable from tips and not from exclude, oldest first."""
    if not tips:
        return []
    revs = "\n".join(tips + ["--not"] + sorted(exclude)) + "\n"
    return git("rev-list", "--reverse", "--stdin", inp=revs.encode()).split()


def merges_in(commits):
    if not commits:
        return set()
    out = git("rev-list", "--no-walk=unsorted", "--min-parents=2", "--stdin",
              inp=("\n".join(commits) + "\n").encode())
    return set(out.split())


def messages(commits):
    """(sha, message lines) per commit, merges included."""
    if not commits:
        return []
    out = git("log", "--no-walk=unsorted", "--stdin", "--format=%x01%H%x02%B",
              inp=("\n".join(commits) + "\n").encode())
    res = []
    for chunk in out.split("\x01")[1:]:
        sha, _, body = chunk.partition("\x02")
        res.append((sha, body.rstrip("\n").split("\n")))
    return res


def tag_texts(updates):
    res = []
    for _, lsha, rref, _ in updates:
        if git("cat-file", "-t", lsha).strip() == "tag":
            body = git("cat-file", "tag", lsha).split("\n\n", 1)
            res.append((rref, body[1].rstrip("\n").split("\n") if len(body) > 1 else []))
    return res


def added_lines(commits):
    """(sha, path, line number, text) for every line the commits add.

    Non-merge commits use their own patch; merge commits use remerge-diff, so
    only what the merge itself adds (conflict resolutions) is read. --text keeps
    binary files and .gitattributes from hiding content.
    """
    if not commits:
        return
    out = git("log", "--no-walk=unsorted", "--stdin", "-p", "--text", "--unified=0",
              "--no-color", "--no-ext-diff", "--no-textconv", "--no-renames",
              "--diff-merges=remerge", "--format=%x01%H",
              inp=("\n".join(commits) + "\n").encode())
    sha = path = None
    header = in_hunk = False
    lineno = 0
    for raw in out.split("\n"):
        if raw.startswith("\x01"):
            sha, path, header, in_hunk = raw[1:], None, False, False
        elif raw.startswith("diff --git ") or raw.startswith("diff --cc "):
            path, header, in_hunk = None, True, False
        elif header and raw.startswith("+++ "):
            p = raw[4:].strip('"')
            path = None if p == "/dev/null" else (p[2:] if p.startswith("b/") else p)
        elif raw.startswith("@@"):
            m = re.match(r"@@+ (?:-\S+ )+\+(\d+)", raw)
            lineno, header, in_hunk = (int(m.group(1)) if m else 0), False, True
        elif in_hunk and path is not None and raw.startswith("+"):
            yield sha, path, lineno, raw[1:]
            lineno += 1


# --- the reviewed allowlist -------------------------------------------------

def parse_allowlist(text, label):
    """[(class, value, glob, label)] from .github/scrub-allow.txt; any bad line blocks.

    The same grammar as the org scanner's parse_allowlist: `<class> <value> <path glob>`
    with a `# reason` on the line or on a comment line directly above. Values are exact
    and percent-decoded (%20 for a space).
    """
    entries, reason_above = [], False
    for n, raw in enumerate(text.split("\n"), 1):
        stripped = raw.strip()
        if stripped.startswith("#"):
            reason_above = bool(stripped.lstrip("#").strip())
            continue
        body, sep, reason = raw.rstrip("\r").partition("#")
        fields = body.split()
        if not fields:
            reason_above = False
            continue
        where = f"{label}:{n}"
        if len(fields) != 3:
            raise Blocked(f"{where}: want '<class> <value> <path glob>  # reason'")
        cls, value, glob = fields
        if cls == "secret":
            raise Blocked(f"{where}: secrets can't be allowed there; put {ALLOW_SECRET} on the line")
        if cls not in ALLOW_CLASSES:
            raise Blocked(f"{where}: unknown class '{cls}' (one of {', '.join(ALLOW_CLASSES)})")
        if not ALLOW_VALUE.fullmatch(value):
            raise Blocked(f"{where}: the value must be exact: no wildcards, % only as %XX")
        if (not ALLOW_GLOB.fullmatch(glob) or glob.startswith("/") or ".." in glob.split("/")
                or not re.search(r"[^*?/]", glob)):
            raise Blocked(f"{where}: the path glob must be relative and name more than wildcards")
        if not (sep and reason.strip()) and not reason_above:
            raise Blocked(f"{where}: needs a # reason on the line or the line above")
        decoded = re.sub(r"%([0-9A-Fa-f]{2})", lambda m: chr(int(m.group(1), 16)), value)
        entries.append((cls, decoded, glob, f"{where} ({cls} {value} {glob})"))
        reason_above = False
    return entries


class AllowSource:
    """The allowlist at the remote's default branch tip, read once and only when needed.

    The tip comes from `git ls-remote --symref`, never from a local tracking ref, and must
    already be in this clone. No default branch yet, or no file there, is an empty list.
    """

    def __init__(self, remote, url):
        self.remote, self.url, self.loaded = remote, url, None

    def load(self):
        if self.loaded is not None:
            return self.loaded
        out = git("ls-remote", "--symref", self.url, "HEAD", check=False)
        if out is None:
            raise Blocked(f"can't read {ALLOW_FILE}: git ls-remote {self.url} failed")
        tip = next((l.split()[0] for l in out.splitlines()
                    if l.endswith("\tHEAD") and not l.startswith("ref:")), None)
        text, label = "", ALLOW_FILE
        if tip:
            if git("cat-file", "-e", f"{tip}^{{commit}}", check=False) is None:
                raise Blocked(f"{ALLOW_FILE} is read from the remote's default branch tip "
                              f"{tip[:12]}, which isn't in this clone: git fetch {self.remote}, "
                              "then push again")
            label = f"{ALLOW_FILE}@{tip[:12]}"
            text = git("show", f"{tip}:{ALLOW_FILE}", check=False) or ""
        self.loaded = (text, label, parse_allowlist(text, label))
        return self.loaded

    def match(self, cls, value, path):
        for c, v, glob, by in self.load()[2]:
            if c == cls and v == value and fnmatch.fnmatchcase(path, glob):
                return by
        return ""


# --- global layer -----------------------------------------------------------

def load_patterns():
    path = os.path.join(HERE, "patterns.txt")
    try:
        with open(path, encoding="utf-8") as fh:
            lines = read_list(fh.read())
    except OSError as e:
        raise Blocked(f"can't read {path}: {e.strerror}")
    secrets, trailers = [], []
    for l in lines:
        kind, name, rx = (l.split(None, 2) + ["", ""])[:3]
        if kind == "secret":
            secrets.append((name, re.compile(rx)))
        elif kind == "attribution":
            trailers.append((name, re.compile(rx, re.I | re.M)))
        else:
            raise Blocked(f"{path}: unknown pattern kind '{kind}'")
    if not secrets or not trailers:
        raise Blocked(f"{path} has no secret or attribution patterns")
    return secrets, trailers


def load_hub_tells():
    """The AI-tell list: the one shipped next to this gate, or, when `guard.scrubHubPath` names a
    hub clone, that clone's origin/main copy instead. Either source failing blocks the push."""
    hub = (git("config", "--get", "guard.scrubHubPath", check=False) or "").strip()
    if hub:
        hub = os.path.expanduser(hub)
        text = git("-C", hub, "show", f"origin/main:{HUB_LIST}", check=False, env=clean_env())
        if text is None:
            raise Blocked(f"can't read {HUB_LIST} from {hub} origin/main (guard.scrubHubPath)")
        where = f"{hub} (guard.scrubHubPath)"
    else:
        path = os.path.join(HERE, TELLS_FILE)
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError as e:
            raise Blocked(f"can't read the AI-tell list {path}: {e.strerror}")
        where = path
    pats = []
    for l in read_list(text):
        try:
            pats.append((l, re.compile(l, re.I)))
        except re.error as e:
            raise Blocked(f"AI-tell pattern '{l}' from {where} doesn't compile: {e}")
    if not pats:
        raise Blocked(f"the AI-tell list from {where} is empty")
    return pats


def tells_exempt(path):
    """The shared pre-commit's exemptions: files that document the rule."""
    base = path.rsplit("/", 1)[-1]
    return (base == "CLAUDE.md" or path.startswith(".claude/") or "/.claude/" in path
            or path.startswith("governance/") or "/governance/" in path
            or ".github/workflows/" in path or re.search(r"workflows/[^/]*\.ya?ml$", path)
            or path.endswith("forbidden-text.txt"))


def is_docs(path):
    return path.endswith(".md") or path.startswith("docs/")


def tree_file(rev, path):
    return git("show", f"{rev}:{path}", check=False)


class Report:
    def __init__(self):
        self.open, self.allowed, self.seen = [], [], set()

    def add(self, where, cls, shown, allowed_by=""):
        key = (where, cls, shown, allowed_by)
        if key in self.seen:
            return
        self.seen.add(key)
        (self.allowed if allowed_by else self.open).append((where, cls, shown, allowed_by))


def scan_global(rep, commits, tags, heads, allow_paths, allow):
    secrets, trailers = load_patterns()
    governed = any(tree_file(h, GOVERNED_MARKER) is not None for h in heads)
    tells, docs_allow = [], set()
    if governed:
        tells = load_hub_tells()
        for h in heads:
            extra = tree_file(h, DOCS_ALLOW)
            if extra:
                docs_allow.update(read_list(extra))

    def path_allowed(path):
        return any(fnmatch.fnmatch(path, g) for g in allow_paths)

    def check_secrets(text, where, honor):
        for name, rx in secrets:
            for m in rx.finditer(text):
                by = ALLOW_SECRET if honor and ALLOW_SECRET in text else ""
                rep.add(where, f"secret {name}", mask(m.group(0), 4), by)

    def check_tells(text, where, path=None):
        for pat, rx in tells:
            if path and is_docs(path) and pat in docs_allow:
                continue
            for m in (rx.finditer(text) if path else [rx.search(text)]):
                if not m:
                    continue
                if path:
                    file_tells.append((where, path, m.group(0)))
                else:
                    rep.add(where, "ai-tell", repr(m.group(0)))

    file_tells = []
    for sha, path, n, text in added_lines(commits):
        where = f"{path}:{n} (commit {sha[:12]})"
        if path_allowed(path):
            continue
        check_secrets(text, where, honor=True)
        if tells and not tells_exempt(path):
            check_tells(text, where, path)
    for where, path, value in file_tells:
        rep.add(where, "ai-tell", repr(value), allow.match("ai-tell", value, path))
    texts = [(f"commit {sha[:12]} message", lines) for sha, lines in messages(commits)]
    texts += [(f"tag {ref} message", lines) for ref, lines in tags]
    for where, lines in texts:
        body = "\n".join(lines)
        for name, rx in trailers:
            m = rx.search(body)
            if m:
                rep.add(where, f"attribution {name}", repr(m.group(0).strip()))
        for i, text in enumerate(lines, 1):
            check_secrets(text, f"{where}:{i}", honor=False)
            check_tells(text, f"{where}:{i}")
    return governed


# --- org layer --------------------------------------------------------------

def read_orgs(path):
    try:
        with open(path, encoding="utf-8") as fh:
            rows = [l.split() for l in read_list(fh.read())]
    except OSError as e:
        raise Blocked(f"can't read {path}: {e.strerror}")
    return {r[0].lower(): r[1:] for r in rows if r}


def load_orgs():
    """The plugin's orgs.conf, then the person's local table, whose rows win per segment.

    The local table lives outside the folder warren-guard-sync manages, so a plugin update
    never touches it. A missing local table is fine; one that exists but can't be read blocks.
    """
    orgs = read_orgs(os.path.join(HERE, "orgs.conf"))
    local = LOCAL_ORGS
    if os.path.lexists(local):
        orgs.update(read_orgs(local))
    return orgs


def org_for(url, orgs):
    for seg, lists in orgs.items():
        if re.search(rf"(^|[/:]){re.escape(seg)}/", url, re.I):
            plan = re.search(rf"(^|[/:]){re.escape(seg)}/plan(\.git)?/?$", url, re.I)
            return seg, (["forbidden"] if plan else lists)
    return None, []


def load_terms(name):
    path = os.path.join(TERMS_DIR, f"{name}-terms.txt")
    try:
        with open(path, encoding="utf-8") as fh:
            terms = [t.strip().lower() for t in read_list(fh.read())]
    except OSError:
        raise Blocked(f"term list {path} is missing or unreadable")
    if not terms:
        raise Blocked(f"term list {path} has no terms")
    return [(name, t) for t in terms]


def org_scanner():
    """The org scrub.py, fetched and read from origin/main of a dedicated clone."""
    env = clean_env()
    url = (os.environ.get("SCRUB_ORG_SCANNER_URL")
           or (git("config", "--global", "--get", "guard.scrubScannerUrl", check=False) or "").strip())
    if not url and not os.path.isdir(ORG_SCANNER_CACHE):
        raise Blocked("no org scanner: set SCRUB_ORG_SCANNER_URL or `git config --global guard.scrubScannerUrl <url>`")
    if not os.path.isdir(ORG_SCANNER_CACHE):
        os.makedirs(os.path.dirname(ORG_SCANNER_CACHE), exist_ok=True)
        if git("clone", "-q", "--bare", url, ORG_SCANNER_CACHE,
               check=False, env=env) is None:
            raise Blocked(f"can't clone the org scanner from {url}")
    gd = f"--git-dir={ORG_SCANNER_CACHE}"
    if git(gd, "fetch", "-q", "origin", "+refs/heads/main:refs/remotes/origin/main",
           check=False, env=env) is None:
        raise Blocked("can't fetch the org scanner's origin/main")
    src = git(gd, "show", f"refs/remotes/origin/main:{ORG_SCANNER_PATH}", check=False, env=env)
    head = git(gd, "rev-parse", "--short=12", "refs/remotes/origin/main", check=False, env=env)
    if not src:
        raise Blocked("the org scanner is missing from origin/main")
    tmp = tempfile.mkdtemp(prefix="scrub-gate-")
    path = os.path.join(tmp, "scrub_org.py")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(src)
    spec = importlib.util.spec_from_file_location("scrub_org", path)
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception as e:
        raise Blocked(f"the org scanner doesn't load: {e}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return mod, (head or "").strip()


class TermScanner:
    """Fixed-string, case-insensitive term matches, shaped like scrub.py's Scanner."""

    def __init__(self, mod, terms):
        self.mod, self.terms = mod, terms

    def line(self, text, binary=False, honor_allow=True, docs_example=False):
        low = text.lower()
        return [self.mod.Finding(f"term ({name} list)", t) for name, t in self.terms if t in low]


def scan_org(rep, seg, lists, commits, tags, refs, allow):
    mod, head = org_scanner()
    domains = (git("config", "--get-all", "guard.scrubAllowDomain", check=False) or "").split()
    terms = [t for name in lists for t in load_terms(name)]
    merges = merges_in(commits)
    empty = git("hash-object", "-t", "tree", "/dev/null").strip()
    cols = [mod.Collector(mod.Scanner(domains)), mod.Collector(TermScanner(mod, terms))]
    try:
        for col in cols:
            for sha in commits:
                if sha in merges:
                    continue
                parents = git("rev-list", "--parents", "-n1", sha).split()[1:]
                col.changes(parents[0] if parents else empty, sha, f"commit {sha[:12]}")
            for sha, path, n, text in added_lines(sorted(merges)):
                col.add(text, f"{path}:{n} (merge {sha[:12]})", path, n,
                        docs_example=mod.docs_example_path(path))
            for sha in commits:
                col.message(sha)
            for ref, lines in tags:
                for i, text in enumerate(lines, 1):
                    col.add(text, f"tag {ref} message:{i}", honor_allow=False)
            for ref in refs:
                col.add(ref, f"ref name {ref}", honor_allow=False)
    except SystemExit:
        raise Blocked("the org scanner hit a git error (unreadable content)")
    apply_allowlist(mod, head, cols[0].findings, allow)
    for col in cols:
        for f in col.findings:
            keep = 1 if f.cls.startswith("term") else 3
            rep.add(f.where, f.cls, mask(f.match, keep), f.allowed_by)
    return head


def apply_allowlist(mod, head, findings, allow):
    """Apply the allowlist's identifier entries through the org scanner's own matcher.

    Only findings on file lines can be allowed (the scanner's AllowList.allow checks that).
    A scanner too old to have the matcher fails closed when the list has identifier entries.
    """
    pending = [f for f in findings if not f.allowed_by and f.file and f.line]
    if not pending:
        return
    text, label, entries = allow.load()
    if not any(e[0] != "ai-tell" for e in entries):
        return
    parse = getattr(mod, "parse_allowlist", None)
    if parse is None:
        raise Blocked(f"the org scanner (scrub.py@{head}) can't apply {label}: it predates "
                      "--allow-file. Its entries aren't applied")
    try:
        allowlist = parse(text, label)
    except ValueError as e:
        raise Blocked(str(e))
    for f in pending:
        allowlist.allow(f)


# --- main -------------------------------------------------------------------

def main(argv):
    url = argv[2] if len(argv) > 2 else (argv[1] if len(argv) > 1 else "")
    updates = [u for u in read_updates(sys.stdin.read()) if not ZERO.match(u[1])]
    if not updates:
        return 0
    rep = Report()
    seg, lists = org_for(url, load_orgs())
    tips = [u[1] for u in updates]
    advertised = remote_shas(url)
    if advertised is None and seg:
        raise Blocked(f"git ls-remote {url} failed; the org gate judges outgoing commits by it")
    strict = local_objects((advertised or []) + [u[3] for u in updates if not ZERO.match(u[3])])
    tracking = git("for-each-ref", "--format=%(objectname)", "refs/remotes").split()
    loose = strict | set(tracking)
    tags = tag_texts(updates)
    allow_paths = (git("config", "--get-all", "guard.scrubAllowPath", check=False) or "").split()
    commits = outgoing(tips, loose)
    allow = AllowSource(argv[1] if len(argv) > 2 else url, url)
    layers = ["global"]
    if scan_global(rep, commits, tags, tips, allow_paths, allow):
        layers.append("shared AI-tells")
    scanned = len(commits)
    if seg:
        org_commits = outgoing(tips, strict)
        head = scan_org(rep, seg, lists, org_commits, tags, [u[2] for u in updates], allow)
        layers.append(f"org {seg} (scrub.py@{head}, lists: {', '.join(lists)})")
        scanned = max(scanned, len(org_commits))
    for where, cls, shown, by in rep.allowed:
        print(f"scrub gate: allowed by {by}: {where}: {cls}: {shown}", file=sys.stderr)
    if rep.open:
        print(f"PUSH BLOCKED by the scrub gate: {len(rep.open)} finding(s) "
              f"[{'; '.join(layers)}]", file=sys.stderr)
        for where, cls, shown, _ in rep.open:
            print(f"  {where}: {cls}: {shown}", file=sys.stderr)
        print("Remove each one from the commits being pushed (amend or rebase), then push "
              f"again. Never --no-verify. Allowlisting: {os.path.join(HERE, 'README.md')}",
              file=sys.stderr)
        return 1
    print(f"scrub gate: {scanned} commit(s) clean [{'; '.join(layers)}]", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Blocked as e:
        print(f"PUSH BLOCKED by the scrub gate (fails closed): {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:  # any surprise blocks rather than letting content through
        print(f"PUSH BLOCKED by the scrub gate (fails closed): {type(e).__name__}: {e}",
              file=sys.stderr)
        sys.exit(1)
