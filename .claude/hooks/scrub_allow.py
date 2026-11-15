"""Filters AI-tell findings through the ai-tell entries of .github/scrub-allow.txt.

Used by lib.sh (gov_find_file_tells), so the PR Hygiene step and the pre-commit hook honour the
same reviewed allowlist as the push gate. The list is read from a base revision, never from the
working tree or the index, so an entry only counts once its own PR is on the base.

  python3 -I scrub_allow.py <base rev> <repo path> <patterns file> < candidate lines

Candidate lines are grep -in output ("<n>:<text>") for <repo path>. Each pattern in the patterns
file (one extended regex per line) is matched on its own, as the push gate does, and a line passes
only when every match on it is covered by an entry: the exact matched text (case kept, %XX
decoded) and a path glob (fnmatch, case sensitive, * crosses /). Lines that still have an
unallowed match are printed in the same form. Each honoured entry is noted on stderr.

Any problem (unreadable revision, a bad line in the list, a pattern that does not compile) exits
2 with the reason on stderr, and the caller treats every candidate as a finding.

Entries of the org scanner's classes (private-ip, email, home-path, fqdn) are parsed for the
same errors and skipped here. `secret` and unknown classes are refused. The grammar is the push
gate's: `<class> <value> <path glob>` with a `# reason` on the line or on the comment line
directly above.
"""
import fnmatch
import re
import subprocess
import sys

ALLOW_FILE = ".github/scrub-allow.txt"
CLASSES = ("private-ip", "email", "home-path", "fqdn", "ai-tell")
VALUE = re.compile(r"(?:[^%*?\[\]\s#]|%[0-9A-Fa-f]{2})+")
GLOB = re.compile(r"[^\s#]+")


class Bad(Exception):
    pass


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True)


def parse(text, label):
    """[(class, decoded value, glob, line number, raw value)]; a bad line raises Bad."""
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
            raise Bad(f"{where}: want '<class> <value> <path glob>  # reason'")
        cls, value, glob = fields
        if cls == "secret":
            raise Bad(f"{where}: secrets can't be allowed there")
        if cls not in CLASSES:
            raise Bad(f"{where}: unknown class '{cls}' (one of {', '.join(CLASSES)})")
        if not VALUE.fullmatch(value):
            raise Bad(f"{where}: the value must be exact: no wildcards, % only as %XX")
        if (not GLOB.fullmatch(glob) or glob.startswith("/") or ".." in glob.split("/")
                or not re.search(r"[^*?/]", glob)):
            raise Bad(f"{where}: the path glob must be relative and name more than wildcards")
        if not (sep and reason.strip()) and not reason_above:
            raise Bad(f"{where}: needs a # reason on the line or the line above")
        decoded = re.sub(r"%([0-9A-Fa-f]{2})", lambda m: chr(int(m.group(1), 16)), value)
        entries.append((cls, decoded, glob, n, value))
        reason_above = False
    return entries


def load(rev):
    if git("cat-file", "-e", f"{rev}^{{commit}}").returncode != 0:
        raise Bad(f"can't read {ALLOW_FILE}: {rev} is not a commit in this clone")
    shown = git("show", f"{rev}:{ALLOW_FILE}")
    text = shown.stdout if shown.returncode == 0 else ""
    short = git("rev-parse", "--short=12", f"{rev}^{{commit}}").stdout.strip() or rev
    label = f"{ALLOW_FILE}@{short}"
    return label, parse(text, label)


def main(argv):
    rev, path, patterns_file = argv[1:4]
    with open(patterns_file, encoding="utf-8") as fh:
        patterns = [l.rstrip("\n") for l in fh if l.strip()]
    try:
        rx = [re.compile(p, re.I) for p in patterns]
    except re.error as e:
        raise Bad(f"a pattern in the AI-tell list does not compile: {e}")
    candidates = [l.rstrip("\n") for l in sys.stdin if l.strip()]
    loaded = None
    remaining = []
    for cand in candidates:
        num, _, text = cand.partition(":")
        matches = [m.group(0) for r in rx for m in r.finditer(text)]
        if not matches:
            # The patterns file and grep disagree; keep the finding.
            remaining.append(cand)
            continue
        if loaded is None:
            loaded = load(rev)
        label, entries = loaded
        notes, blocked = [], False
        for value in matches:
            hit = next((e for e in entries if e[0] == "ai-tell" and e[1] == value
                        and fnmatch.fnmatchcase(path, e[2])), None)
            if hit is None:
                blocked = True
                break
            notes.append(f"{label}:{hit[3]} (ai-tell {hit[4]} {hit[2]})")
        if blocked:
            remaining.append(cand)
        else:
            for note in dict.fromkeys(notes):
                print(f"hygiene: allowed by {note}: {path}:{num}", file=sys.stderr)
    for cand in remaining:
        print(cand)


if __name__ == "__main__":
    try:
        main(sys.argv)
    except Bad as e:
        print(f"scrub-allow: {e}", file=sys.stderr)
        sys.exit(2)
