"""Fails when a tracked file holds a home path or a term from the user's private term list.

The repo holds no list of names. The private terms live in a local folder, never in a repo:
*.txt files in $WARREN_TERMS_DIR, default ~/.config/warren/terms. One term per line, matched
case-insensitively as a substring; a line starting with re: is a regular expression; blank lines
and lines starting with # are ignored. A missing folder is fine: only the built-in home-path
checks run. Hits print the file and line only, never the term.
docs/examples/warren-terms.example.txt shows the format with placeholder terms.

  python3 -I .github/scripts/check-generic.py            every tracked file
  python3 -I .github/scripts/check-generic.py --staged   the staged version of staged files
"""
import os
import pathlib
import re
import subprocess
import sys

# Built from parts so this file does not match its own patterns.
BUILTIN = [re.compile("/" + "Users/"), re.compile("/" + "home/[a-z]", re.I)]


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True).stdout


def load_terms():
    d = pathlib.Path(os.environ.get("WARREN_TERMS_DIR") or pathlib.Path.home() / ".config/warren/terms")
    terms = []
    if d.is_dir():
        for f in sorted(d.glob("*.txt")):
            for i, t in enumerate(f.read_text(errors="replace").splitlines(), 1):
                t = t.strip()
                if not t or t.startswith("#"):
                    continue
                try:
                    m = re.compile(t[3:], re.I) if t.startswith("re:") else re.compile(re.escape(t), re.I)
                except re.error:
                    print(f"{f.name} entry {i}: not a valid expression, skipped", file=sys.stderr)
                    continue
                terms.append((f"{f.name} entry {i}", m))
    return terms


def scan(name, text, terms):
    hits = []
    for n, line in enumerate(text.splitlines(), 1):
        if any(m.search(line) for _, m in terms):
            hits.append(f"{name}:{n}: a local term-list entry")
        for d in BUILTIN:
            m = d.search(line)
            if m:
                hits.append(f"{name}:{n}: '{m.group(0)}' (home path)")
    return hits


def main():
    root = pathlib.Path(git("rev-parse", "--show-toplevel").decode().strip())
    os.chdir(root)
    staged = "--staged" in sys.argv[1:]
    terms = load_terms()
    if staged:
        files = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").decode().split("\0")
    else:
        files = git("ls-files", "-z").decode().split("\0")
    hits = []
    for f in filter(None, files):
        hits += scan(f"{f} (path)", f, terms)
        data = git("show", f":{f}") if staged else pathlib.Path(f).read_bytes() if pathlib.Path(f).is_file() else b""
        if b"\0" in data[:8000]:
            continue
        hits += scan(f, data.decode("utf-8", "replace"), terms)
    for h in hits:
        print(h)
    if hits:
        print(f"generic check: {len(hits)} finding(s). Move the specific text to your org plugin.")
        return 1
    print("generic check: clean")
    return 0


sys.exit(main())
