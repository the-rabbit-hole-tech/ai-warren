#!/usr/bin/env -S python3 -I
"""Build the backlog page on the hand-off site from backlog.json, or read your picks.

  backlog-page.py              write the backlog board, the page backlog/board (its own folder, not under OPS), through page.py
  backlog-page.py --page F/S   write or read another address instead (or set WARREN_BACKLOG_PAGE)
  backlog-page.py --read       print the picks that were SENT: "Backlog <n>: START|HOLD | comment" (a sent Hold with no
                               comment reads "HOLD (sent)"; an item nothing was sent for reads "HOLD (default)"), and a line
                               "Backlog <n>: DROP requested" for each drop the reviewer asked for and nobody has answered

backlog.json is a list of {"n": int, "title": str, "context": str, "status": "open"|"started"|"done"|"dropped"}.
An item's context is drawn as separate blocks: each line is a paragraph (start one with **Label:** for a bold label), lines
starting with "- " are a bullet list, and a context over 600 characters shows its first paragraph and folds the rest under
Details. Item ids, picks and --read do not change.
Started items are Tasks, not backlog, so the page leaves them out.
Open items get Start/Hold under the stable id "b<n>", so picks survive a rewrite; done and dropped items sit
in a collapsed "Completed (n)" list without controls.
Start only marks an item. The owner's "Send this item" button, which appears once Start or Hold is pressed (a comment alone
offers nothing), is what sends the pick, so --read reports a pick only once it was sent (a mark that was not sent reads as
the default, HOLD), together with its comment. What a sent pick means: START is go (add it to the active work queue); HOLD is
just hold; HOLD with a comment is a request to revise or update the backlog item as the comment says. Open items can be dropped:
the owner's Drop button (after a confirm) sends a kind-drop submission to the operator's inbox, the page shows "Drop
requested" and takes no pick for that item until you act. A drop is final: set its status to "dropped" in backlog.json and run
this script again (the item moves to the Completed list and never returns to the board unless it is added again as a new
item); to decline, reply under the item with page.py reply.
The folders default to $WARREN_SETUP (~/.warren) and $WARREN_HANDOFF_SITE ($WARREN_SETUP/handoff-site).
Log level comes from LOG_LEVEL (default info); logs go to stderr.
"""
import argparse
import html
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

SETUP = Path(os.environ.get("WARREN_SETUP", Path.home() / ".warren"))
SITE = Path(os.environ.get("WARREN_HANDOFF_SITE", SETUP / "handoff-site"))
# The backlog is a system of its own, not an OPS page: it has a folder of its own on the site (mark it "board" in site.json).
PAGE = os.environ.get("WARREN_BACKLOG_PAGE", "backlog/board")
OPTIONS = [("start", "Start"), ("hold", "Hold")]
DEFAULT = "hold"
STATUSES = ("open", "started", "done", "dropped")
INTRO = ("Start marks an item to go; press Send this item to send it. Hold is the default, and a comment with Hold asks for "
         "the item to be revised. Drop removes an item from the board for good.")

log = logging.getLogger("backlog-page")


def load_items(path):
    items = json.loads(Path(path).read_text())
    seen = set()
    for it in items:
        if not isinstance(it.get("n"), int) or not it.get("title"):
            sys.exit(f"backlog-page: bad item (needs int n and a title): {it}")
        if it.get("status") not in STATUSES:
            sys.exit(f"backlog-page: Backlog {it['n']} has status {it.get('status')!r}; use one of {', '.join(STATUSES)}")
        if it["n"] in seen:
            sys.exit(f"backlog-page: Backlog {it['n']} is listed twice")
        seen.add(it["n"])
    log.debug("loaded %d items from %s", len(items), path)
    return items


LONG = 600  # characters: a longer context shows its first paragraph and folds the rest under Details


def blocks(context):
    """An item's context as separate blocks, not one wall of text.

    Each line is a paragraph (a leading **Label:** is drawn bold by the page); consecutive lines starting with "- " are one
    bullet list. A context over LONG characters whose first block is a paragraph shows that paragraph as the summary and folds the
    other blocks into a Details block. A single short line stays the single paragraph it always was.
    """
    out, bullets = [], []

    def flush():
        if bullets:
            out.append({"list": list(bullets)})
            bullets.clear()

    for line in (context or "").replace("\r", "").split("\n"):
        line = line.strip()
        if not line:
            continue
        if line.startswith("- ") and line[2:].strip():
            bullets.append(line[2:].strip())
            continue
        flush()
        out.append({"p": line})
    flush()
    if len(context) > LONG and len(out) > 1 and "p" in out[0]:
        return [out[0], {"details": "Details", "body": out[1:]}]
    return out


def definition(items):
    board = [it for it in items if it["status"] == "open"]
    off = [it for it in items if it["status"] in ("done", "dropped")]
    page_items = [{"id": f"b{it['n']}", "title": f"Backlog {it['n']}: {it['title']}",
                   **({"body": blocks(it["context"])} if it.get("context") and blocks(it["context"]) else {})} for it in board]
    if off:
        rows = "".join(f"<li>Backlog {it['n']}: {html.escape(it['title'], quote=False)} ({it['status']})</li>" for it in off)
        page_items.append({"id": "completed", "type": "info", "title": f"Completed ({len(off)})",
                           "body": [{"html": f"<details><summary>Show the {len(off)} items</summary><ul>{rows}</ul></details>"}]})
    return {
        "schema": "handoff.page/v1", "kind": "backlog", "title": "Backlog", "summary": INTRO, "droppable": True,
        "status": {"state": "needs-you", "note": f"{len(board)} backlog items: pick Start or leave on Hold."},
        "options": {"choices": [{"value": v, "label": label} for v, label in OPTIONS], "default": DEFAULT},
        "items": page_items,
    }, len(board)


def write_page(site, items, page=PAGE):
    doc, open_count = definition(items)
    exists = (site / f"{page}.json").exists()
    (site / page).parent.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, str(site / "_site" / "page.py"), "--root", str(site), "set" if exists else "new", page]
    t0 = time.monotonic()
    r = subprocess.run(cmd, input=json.dumps(doc), capture_output=True, text=True, check=False)
    log.debug("page.py %s exit %d in %.2fs", cmd[4], r.returncode, time.monotonic() - t0)
    if r.returncode != 0:
        log.error("page.py %s failed: %s", cmd[4], r.stderr.strip())
        return 1
    log.info("wrote %s (%d on the board, %d off)", page, open_count, len(items) - open_count)
    return 0


def read_picks(site, items, page=PAGE):
    sys.path.insert(0, str(site / "_site"))
    import pagefile

    path = site / f"{page}.json"
    if not path.exists():
        log.debug("no %s yet", path)
        doc = None
    else:
        doc = pagefile.load(path)
    log.debug("picks from %s: %s", path, "found" if doc else "none saved yet")
    labels = dict(OPTIONS)
    dropping = pagefile.dropping_items(doc) if doc else set()
    for it in items:
        if it["status"] != "open":
            continue
        iid = f"b{it['n']}"
        # Only what "Send this item" carried counts; a mark that was not sent reads as the default.
        sent = pagefile.sent_answer(doc, iid) if doc else None
        if sent is None:
            line = f"Backlog {it['n']}: {labels[DEFAULT].upper()} (default)"
        else:
            # A sent item with no pick is a Hold the reviewer sent (a comment alone, or Hold pressed): it reads HOLD, never
            # "(default)", so it can be told from an item nobody sent. With no comment it reads "HOLD (sent)".
            v = sent.get("answer") or DEFAULT
            note = " ".join((sent.get("note") or "").split())
            line = f"Backlog {it['n']}: {labels.get(v, labels[DEFAULT]).upper()}"
            if note:
                line += " | " + note
            elif v == DEFAULT:
                line += " (sent)"
        print(line)
        if iid in dropping:
            print(f"Backlog {it['n']}: DROP requested")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", default=str(SETUP / "backlog.json"), help="backlog list (default: %(default)s)")
    ap.add_argument("--site", default=str(SITE), help="hand-off site folder (default: %(default)s)")
    ap.add_argument("--page", default=PAGE, help="the board's address, <folder>/<slug> (default: %(default)s)")
    ap.add_argument("--read", action="store_true", help="print the owner's saved picks instead of building")
    args = ap.parse_args()
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "info").upper().replace("TRACE", "DEBUG"),
                        format="%(levelname)s %(name)s: %(message)s", stream=sys.stderr)
    items = load_items(args.json)
    site = Path(args.site)
    return read_picks(site, items, args.page) if args.read else write_page(site, items, args.page)


if __name__ == "__main__":
    sys.exit(main())
