"""A reopened item starts clean: its old note is history, never the current note, and a page Send never carries it."""

import json
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pagefile  # noqa: E402

from test_pagefile import review  # noqa: E402
from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"
T1 = "2026-10-26T08:05:44-04:00"
OLD = "the box is not centered"


def post(base, path, obj):
    status, body, _ = request(base + path, "POST", json.dumps(obj))
    return status, (json.loads(body) if body else None)


def test_a_page_send_leaves_out_a_reopened_item_until_it_is_answered_again(site):  # noqa: F811
    root, base = site
    page = root / "demo" / "design.json"
    pagefile.write_definition(page, review(), now=T0)
    pagefile.save_answers(page, {"s1": {"answer": "yes", "note": OLD}, "s2": {"answer": "yes", "note": "fine"}}, by="me", now=T0)
    pagefile.reply(page, "s1", "app", "Fixed.", action="reopen", reason="fixed in 1.2", now=T1)
    assert pagefile.item_states(pagefile.load(page))["s1"]["reopened"] == "fixed in 1.2"
    status, out = post(base, "/_page/demo/design/send", {"kind": "send", "results": "R"})
    assert status == 200, out
    sub = json.loads(next((root / "_inbox" / "ops").iterdir()).read_text())
    assert [i["id"] for i in sub["items"]] == ["s2"]
    assert OLD not in json.dumps(sub), "the note from before the reopen is nowhere in what was sent"


def test_an_item_send_refuses_a_reopened_item_that_was_not_answered_again(site):  # noqa: F811
    root, base = site
    page = root / "demo" / "design.json"
    pagefile.write_definition(page, review(), now=T0)
    pagefile.save_answers(page, {"s1": {"answer": "yes", "note": OLD}}, by="me", now=T0)
    pagefile.reply(page, "s1", "app", "Fixed.", action="reopen", reason="fixed in 1.2", now=T1)
    status, out = post(base, "/_page/demo/design/send", {"kind": "send", "scope": "item", "items": ["s1"], "results": "R"})
    assert status == 400 and "no new answer" in out["errors"][0]


def test_answering_again_replaces_the_old_note_in_what_is_sent(site):  # noqa: F811
    root, base = site
    page = root / "demo" / "design.json"
    pagefile.write_definition(page, review(), now=T0)
    pagefile.save_answers(page, {"s1": {"answer": "yes", "note": OLD}}, by="me", now=T0)
    pagefile.reply(page, "s1", "app", "Fixed.", action="reopen", reason="fixed in 1.2", now=T1)
    pagefile.save_answers(page, {"s1": {"answer": "yes", "note": "now it is"}}, by="me", now=T1)
    status, out = post(base, "/_page/demo/design/send", {"kind": "send", "results": "R"})
    assert status == 200, out
    sub = json.loads(next((root / "_inbox" / "ops").iterdir()).read_text())
    assert [(i["id"], i["note"]) for i in sub["items"]] == [("s1", "now it is")]
    assert OLD not in json.dumps(sub)
