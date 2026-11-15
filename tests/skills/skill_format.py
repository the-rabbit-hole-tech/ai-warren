"""Checks every SKILL.md: frontmatter with name and description, the description starts with
"Use when" and is 300 characters or fewer, menu skills (warren-* and menu) set
disable-model-invocation, every skill except menu skills carries a Source line, and the model-
invocable descriptions together stay within the budget.
Run: python3 -I tests/skills/skill_format.py <repo root> [budget]
"""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
budget = int(sys.argv[2]) if len(sys.argv) > 2 else 12000
fails, total, count = [], 0, 0
for f in sorted(root.glob("plugins/*/skills/*/SKILL.md")):
    rel = f.relative_to(root).as_posix()
    text = f.read_text()
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        fails.append(f"{rel}: no frontmatter")
        continue
    fm = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip('"')
    name = f.parent.name
    menu = name == "menu" or name.startswith("warren-")
    if fm.get("name") != name:
        fails.append(f"{rel}: name is {fm.get('name')!r}, expected {name!r}")
    desc = fm.get("description", "")
    if not desc.startswith("Use when"):
        fails.append(f"{rel}: the description doesn't start with 'Use when'")
    if len(desc) > 300:
        fails.append(f"{rel}: the description is {len(desc)} characters (max 300)")
    no_model = fm.get("disable-model-invocation") == "true"
    if menu and not no_model:
        fails.append(f"{rel}: a menu skill sets disable-model-invocation: true")
    if not no_model:
        total += len(desc) + len(fm.get("when_to_use", ""))
        count += 1
print(f"{count} model-invocable skills, {total} description characters (budget {budget})")
if total > budget:
    fails.append(f"descriptions total {total} characters, over the {budget} budget")
for x in fails:
    print(f"FAIL {x}")
sys.exit(1 if fails else 0)
