"""The backlog board: Drop requests, a pick that counts only once it is sent, and what the operator reads."""

import json
import sys
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pagefile  # noqa: E402
import schema  # noqa: E402

from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"
T1 = "2026-10-26T08:05:44-04:00"
T2 = "2026-10-26T08:20:02-04:00"


def board(**extra):
    d = {"schema": "handoff.page/v1", "kind": "backlog", "title": "Backlog", "droppable": True,
         "options": {"choices": [{"value": "start", "label": "Start"}, {"value": "hold", "label": "Hold"}], "default": "hold"},
         "items": [{"id": "b1", "title": "Backlog 1: First"}, {"id": "b2", "title": "Backlog 2: Second"},
                   {"id": "b3", "title": "Backlog 3: Third"}]}
    d.update(extra)
    return d


@pytest.fixture
def pages(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "backlog.json", board(), now=T0)
    return root, base


def post(base, path, obj):
    status, body, _ = request(base + path, "POST", json.dumps(obj))
    return status, (json.loads(body) if body else None)


def put(base, path, obj):
    status, body, _ = request(base + path, "PUT", json.dumps(obj))
    return status, (json.loads(body) if body else None)


def inbox(root, agent="ops"):
    d = root / "_inbox" / agent
    return sorted(p for p in d.iterdir() if p.suffix == ".json") if d.exists() else []


# ---- the opt-in and the schema ----

def test_droppable_is_a_page_setting_and_must_be_true_or_false():
    assert schema.validate({**board(), "rev": 1, "rounds": [{"round": 1, "build": None, "reset": None, "opened": "t", "closed": None,
                            "openedBy": "created", "answers": {}}], "thread": {}, "submissions": []}) == []
    bad = board(droppable="yes")
    assert any("droppable" in e for e in schema.validate(bad))


def test_a_definition_rewrite_keeps_droppable_and_does_not_change_the_items(tmp_path):
    p = tmp_path / "b.json"
    pagefile.write_definition(p, board(), now=T0)
    before = pagefile.load(p)["items"]
    pagefile.write_definition(p, board(summary="again"), now=T1)
    doc = pagefile.load(p)
    assert doc["droppable"] is True and doc["items"] == before


# ---- Drop ----

def test_a_drop_is_saved_to_the_inbox_as_kind_drop_and_shows_as_requested(pages):
    root, base = pages
    status, out = post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b2"], "results": ""})
    assert status == 200, out
    [f] = inbox(root)
    sub = json.loads(f.read_text())
    assert sub["kind"] == "drop" and sub["page"] == "demo/backlog" and [i["id"] for i in sub["items"]] == ["b2"]
    assert f.name.startswith("5-"), "a drop sorts after blockers, with the sends"
    page = json.loads(request(base + "/_page/demo/backlog")[1])
    assert page["states"]["b2"]["dropping"] is True and "dropping" not in page["states"]["b1"]
    assert pagefile.held_items(pagefile.load(root / "demo" / "backlog.json")) == set(), "a drop holds nothing else"


def test_a_drop_needs_a_droppable_page_one_item_and_no_earlier_request(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "plain.json", board(droppable=False), now=T0)
    assert post(base, "/_page/demo/plain/send", {"kind": "drop", "items": ["b1"], "results": ""})[0] == 400
    pagefile.write_definition(root / "demo" / "backlog.json", board(), now=T0)
    assert post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b1", "b2"], "results": ""})[0] == 400
    assert post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["zzz"], "results": ""})[0] == 400
    assert post(base, "/_page/demo/backlog/send", {"kind": "drop", "results": ""})[0] == 400
    assert post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b1"], "results": ""})[0] == 200
    status, out = post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b1"], "results": ""})
    assert status == 400 and "already" in out["errors"][0]


def test_a_dropping_item_takes_no_pick(pages):
    root, base = pages
    post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b2"], "results": ""})
    status, out = put(base, "/_page/demo/backlog/answers", {"answers": {"b2": {"answer": "start"}}})
    assert status == 400 and "drop" in out["errors"][0]
    assert put(base, "/_page/demo/backlog/answers", {"answers": {"b1": {"answer": "start"}}})[0] == 200


def test_a_reply_under_the_item_clears_the_request(pages):
    root, base = pages
    path = root / "demo" / "backlog.json"
    post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b2"], "results": ""})
    assert pagefile.item_states(pagefile.load(path))["b2"]["dropping"] is True
    pagefile.reply(path, "b2", "ops", "Keeping it for now.", action="info", now="2099-01-01T00:00:00-04:00")
    assert "dropping" not in pagefile.item_states(pagefile.load(path))["b2"]
    assert post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b2"], "results": ""})[0] == 200, "it can be asked again"


def test_applying_a_drop_removes_the_item_and_the_page_stays_valid(pages):
    root, base = pages
    path = root / "demo" / "backlog.json"
    post(base, "/_page/demo/backlog/send", {"kind": "drop", "items": ["b2"], "results": ""})
    d = board()
    d["items"] = [i for i in d["items"] if i["id"] != "b2"]
    pagefile.write_definition(path, d, now=T2)
    doc = pagefile.load(path)
    assert [i["id"] for i in doc["items"]] == ["b1", "b3"]
    assert schema.validate(doc) == []
    assert json.loads(request(base + "/_page/demo/backlog")[0:2][1])["summary"]["counted"] >= 0


# ---- a pick is sent only by Send this item ----

def pick(path, iid, value, now):
    pagefile.save_answers(path, {iid: {"answer": value, "note": ""}}, by="me", now=now)


def test_the_sent_pick_is_what_the_item_send_carried_not_what_was_marked_later(pages):
    root, base = pages
    path = root / "demo" / "backlog.json"
    assert pagefile.sent_answer(pagefile.load(path), "b1") is None, "nothing is sent until the item is sent"
    pick(path, "b1", "start", T0)
    assert pagefile.sent_answer(pagefile.load(path), "b1") is None, "marking Start sends nothing"
    status, out = post(base, "/_page/demo/backlog/send", {"kind": "send", "scope": "item", "items": ["b1"], "results": ""})
    assert status == 200, out
    got = pagefile.sent_answer(pagefile.load(path), "b1")
    assert got["answer"] == "start"
    assert [i["answer"] for i in json.loads(inbox(root)[0].read_text())["items"]] == ["start"]


def test_unlocking_takes_the_send_back_and_a_new_pick_counts_only_once_it_is_sent(tmp_path):
    path = tmp_path / "b.json"
    pagefile.write_definition(path, board(), now=T0)
    pick(path, "b1", "start", T0)
    send = {"kind": "send", "to": "ops", "items": ["b1"], "scope": "item", "file": "5-x-{n}.json"}
    sub = pagefile.add_submission(path, send, now=T1)
    pagefile.hold(path, sub["n"])
    assert pagefile.sent_answer(pagefile.load(path), "b1")["answer"] == "start"
    pagefile.release(path)
    assert pagefile.sent_answer(pagefile.load(path), "b1") is None, "an unlocked Send is taken back"
    pick(path, "b1", "hold", T2)
    assert pagefile.sent_answer(pagefile.load(path), "b1") is None, "a new mark is not sent yet"
    pagefile.add_submission(path, send, now="2026-10-26T09:00:00-04:00")
    assert pagefile.sent_answer(pagefile.load(path), "b1")["answer"] == "hold"


def test_a_mark_made_after_a_send_is_not_the_sent_pick(tmp_path):
    path = tmp_path / "b.json"
    pagefile.write_definition(path, board(), now=T0)
    pick(path, "b1", "start", T0)
    pagefile.add_submission(path, {"kind": "send", "to": "ops", "items": ["b1"], "scope": "item", "file": "5-x-{n}.json"}, now=T1)
    pick(path, "b1", "hold", T2)
    assert pagefile.sent_answer(pagefile.load(path), "b1")["answer"] == "start", "what was sent still stands until it is sent again"


def test_other_items_are_not_sent_by_an_item_send(pages):
    root, base = pages
    path = root / "demo" / "backlog.json"
    pick(path, "b1", "start", T0)
    pick(path, "b3", "start", T0)
    post(base, "/_page/demo/backlog/send", {"kind": "send", "scope": "item", "items": ["b1"], "results": ""})
    assert pagefile.sent_answer(pagefile.load(path), "b3") is None


def test_a_comment_alone_cannot_be_sent_for_a_choice_item_but_a_pick_with_a_comment_can(pages):
    root, base = pages
    path = root / "demo" / "backlog.json"
    pagefile.save_answers(path, {"b1": {"answer": "", "note": "just a thought"}}, by="me", now=T0)
    status, out = post(base, "/_page/demo/backlog/send", {"kind": "send", "scope": "item", "items": ["b1"], "results": ""})
    assert status == 400 and "pick" in out["errors"][0], "Start or Hold has to be pressed first"
    assert inbox(root) == []
    pagefile.save_answers(path, {"b1": {"answer": "hold", "note": "revise the title to say what it is"}}, by="me", now=T1)
    status, out = post(base, "/_page/demo/backlog/send", {"kind": "send", "scope": "item", "items": ["b1"], "results": ""})
    assert status == 200, out
    sent = json.loads(inbox(root)[0].read_text())["items"][0]
    assert sent["answer"] == "hold" and sent["note"] == "revise the title to say what it is"
