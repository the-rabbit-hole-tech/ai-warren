#!/usr/bin/env -S python3 -I
"""Build a bug-log page on the hand-off site from its JSON source.

  bug-log-page.py --folder myproject --json $WARREN_SETUP/bug-log-<date>-<project>.json

The JSON holds {"title", "date", "context", "entries": [...]}. Each entry is
{"n": int, "by": "owner"|"ops", "repo": "<owner>/<repo>", "area": str, "status": str,
 "title": str, "raw": str, "notes"?: str, "issue"?: url}. "raw" is the reporter's own words, kept
as typed; "title" is the cleaned-up one-line summary. Entries render in the order reported.
Writes the <folder>/bug-log-<date> page file (the project's folder) through page.py, as a reference page.
Log level comes from LOG_LEVEL (default info); logs go to stderr.
"""
import argparse
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

SETUP = Path(os.environ.get("WARREN_SETUP", Path.home() / ".warren"))
SITE = Path(os.environ.get("WARREN_HANDOFF_SITE", SETUP / "handoff-site"))

log = logging.getLogger("bug-log-page")


def load(path):
    doc = json.loads(Path(path).read_text())
    seen = set()
    for e in doc.get("entries", []):
        for k in ("n", "by", "repo", "status", "title", "raw"):
            if k not in e:
                sys.exit(f"bug-log-page: entry {e.get('n')} is missing {k!r}")
        if e["n"] in seen:
            sys.exit(f"bug-log-page: entry {e['n']} is listed twice")
        seen.add(e["n"])
    log.debug("loaded %d entries from %s", len(doc.get("entries", [])), path)
    return doc


def item(e, section):
    who = "You reported" if e["by"] == "owner" else "The operator found"
    meta = [e["repo"]] + ([e["area"]] if e.get("area") else [])
    if e.get("issue"):
        meta.append(f"[#{e['issue'].rstrip('/').rsplit('/', 1)[-1]}]({e['issue']})")
    meta.append(f"**{e['status'].capitalize()}**")
    body = [{"p": f"**{who}:** {e['raw']}"}]
    if e.get("notes"):
        body.append({"p": f"**Notes:** {e['notes']}"})
    body.append({"p": " · ".join(meta)})
    out = {"id": f"bug-{e['n']}", "title": f"Bug {e['n']}: {e['title']}", "body": body}
    if section:
        out["section"] = section
    return out


def definition(doc):
    entries = doc.get("entries", [])
    owner = [e for e in entries if e["by"] == "owner"]
    ops = [e for e in entries if e["by"] != "owner"]
    items = [item(e, "Your reports" if i == 0 else None) for i, e in enumerate(owner)]
    if not owner:
        items.append({"id": "none", "title": "Your reports", "body": [{"p": "Nothing reported yet."}]})
    items += [item(e, "Found by the operator" if i == 0 else None) for i, e in enumerate(ops)]
    summary = f"{len(owner)} reported by you · {len(ops)} found by the operator · updated {time.strftime('%H:%M')}"
    return {
        "schema": "handoff.page/v1", "kind": "reference", "title": doc["title"],
        "summary": f"{doc['context']} {summary}" if doc.get("context") else summary,
        "status": {"state": "reference", "note": f"{len(owner)} reported by you, {len(ops)} found by the operator. Logged as reported."},
        "items": items,
    }, len(owner), len(ops)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", required=True, help="bug-log JSON source")
    ap.add_argument("--folder", required=True, help="the project's hand-off folder, e.g. myproject")
    ap.add_argument("--site", default=str(SITE), help="hand-off site folder (default: %(default)s)")
    args = ap.parse_args()
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "info").upper().replace("TRACE", "DEBUG"),
                        format="%(levelname)s %(name)s: %(message)s", stream=sys.stderr)
    doc = load(args.json)
    site = Path(args.site)
    page = f"{args.folder}/bug-log-{doc['date']}"
    definition_doc, n_owner, n_ops = definition(doc)
    action = "set" if (site / f"{page}.json").exists() else "new"
    r = subprocess.run([sys.executable, str(site / "_site" / "page.py"), "--root", str(site), action, page],
                       input=json.dumps(definition_doc), capture_output=True, text=True, check=False)
    if r.returncode != 0:
        log.error("page.py %s failed: %s", action, r.stderr.strip())
        return 1
    log.info("wrote %s (%d from you, %d from the operator)", page, n_owner, n_ops)
    return 0


if __name__ == "__main__":
    sys.exit(main())
