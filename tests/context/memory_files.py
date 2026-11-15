#!/usr/bin/env python3
"""Prints <bytes>\t<path> for every memory file a session in <dir> loads (see measure.sh).

  python3 -I memory_files.py <dir> <config dir> <home>
"""
import os, re, sys
d, cfg, home = sys.argv[1:4]
seen, order = set(), []
def add(p):
    p = os.path.realpath(os.path.expanduser(p))
    if p in seen or not os.path.isfile(p):
        return
    seen.add(p); order.append(p)
    base = os.path.dirname(p)
    in_code = False
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        m = None if in_code else re.match(r"^@(\S+)\s*$", line.strip())
        if m:
            t = m.group(1)
            t = os.path.expanduser(t) if t.startswith("~") else (t if os.path.isabs(t) else os.path.join(base, t))
            add(t)
add(os.path.join(cfg, "CLAUDE.md"))
rules = os.path.join(cfg, "rules")
if os.path.isdir(rules):
    for f in sorted(os.listdir(rules)):
        if f.endswith(".md"):
            add(os.path.join(rules, f))
chain, cur = [], d
while True:
    chain.append(cur)
    if cur in (home, "/"):
        break
    cur = os.path.dirname(cur)
for c in reversed(chain):
    for name in ("CLAUDE.md", os.path.join(".claude", "CLAUDE.md")):
        add(os.path.join(c, name))
slug = re.sub(r"[^A-Za-z0-9]", "-", d)
add(os.path.join(cfg, "projects", slug, "memory", "MEMORY.md"))
for p in order:
    print(f"{os.path.getsize(p)}\t{p}")
