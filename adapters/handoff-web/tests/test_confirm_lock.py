"""A Yes the reviewer confirms locks the item: the pagefile rules (the flag, the note-only edit, the refused answer
change, Reopen with a reason) and the endpoints in template/_site/serve.py."""

import json
import sys
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pagefile  # noqa: E402

from test_pagefile import review  # noqa: E402
from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"
T1 = "2026-10-26T08:05:44-04:00"
T2 = "2026-10-26T08:20:02-04:00"


@pytest.fixture
def path(tmp_path):
    p = tmp_path / "design.json"
    pagefile.write_definition(p, review(), now=T0)
    return p


def confirm(path, iid="s1", note="", now=T1):
    return pagefile.save_answers(path, {iid: {"answer": "yes", "note": note, "locked": True}}, by="me", now=now)


def entry(path, iid="s1"):
    return pagefile.load(path)["rounds"][-1]["answers"][iid]


def test_a_confirmed_yes_is_stored_with_its_note_and_the_flag(path):
    confirm(path, note="Looks right.")
    e = entry(path)
    assert e["answer"] == "yes" and e["note"] == "Looks right." and e["locked"] is True
    assert pagefile.item_states(pagefile.load(path))["s1"]["locked"] is True


def test_an_unconfirmed_yes_is_not_locked(path):
    pagefile.save_answers(path, {"s1": {"answer": "yes"}}, by="me", now=T1)
    assert "locked" not in entry(path)
    assert pagefile.item_states(pagefile.load(path))["s1"].get("locked") is None


def test_the_same_yes_confirmed_later_adds_the_lock(path):
    pagefile.save_answers(path, {"s1": {"answer": "yes", "note": "ok"}}, by="me", now=T1)
    confirm(path, note="ok", now=T2)
    assert entry(path)["locked"] is True


@pytest.mark.parametrize("answer,note", [("no", "x"), ("changes", "fix it"), ("", "")])
def test_only_a_yes_can_be_locked(path, answer, note):
    with pytest.raises(pagefile.PageError):
        pagefile.save_answers(path, {"s1": {"answer": answer, "note": note, "locked": True}}, by="me", now=T1)
    assert "s1" not in pagefile.load(path)["rounds"][-1]["answers"]


def test_a_question_cannot_be_locked_this_way(path):
    with pytest.raises(pagefile.PageError):
        pagefile.save_answers(path, {"q1": {"answer": "8080", "locked": True}}, by="me", now=T1)


def test_the_note_stays_editable_after_the_lock(path):
    confirm(path, note="first")
    pagefile.save_answers(path, {"s1": {"answer": "yes", "note": "second", "locked": True}}, by="me", now=T2)
    e = entry(path)
    assert e["note"] == "second" and e["locked"] is True and e["answer"] == "yes"
    # A tab that sends the note without the flag (an older one) must not drop the lock either.
    pagefile.save_answers(path, {"s1": {"answer": "yes", "note": "third"}}, by="me", now=T2)
    assert entry(path)["note"] == "third" and entry(path)["locked"] is True


@pytest.mark.parametrize("new", [{"answer": "no", "note": "n"}, {"answer": "changes", "note": "c"}, {"answer": "", "note": ""}])
def test_the_answer_cannot_change_while_locked(path, new):
    confirm(path, note="first")
    with pytest.raises(pagefile.LockedError) as e:
        pagefile.save_answers(path, {"s1": new}, by="me", now=T2)
    assert "s1" in str(e.value) and "Reopen" in str(e.value)
    assert entry(path)["answer"] == "yes" and entry(path)["note"] == "first"


def test_one_refused_item_changes_nothing_else_in_the_same_save(path):
    confirm(path)
    with pytest.raises(pagefile.LockedError):
        pagefile.save_answers(path, {"s1": {"answer": "no", "note": "n"}, "s2": {"answer": "yes"}}, by="me", now=T2)
    assert "s2" not in pagefile.load(path)["rounds"][-1]["answers"]


def test_reopen_needs_a_reason_and_a_locked_yes(path):
    with pytest.raises(pagefile.PageError):
        pagefile.reopen(path, "s1", "because", by="me", now=T1)
    confirm(path)
    for bad in ("", "   "):
        with pytest.raises(pagefile.PageError):
            pagefile.reopen(path, "s1", bad, by="me", now=T2)
    with pytest.raises(pagefile.PageError):
        pagefile.reopen(path, "nope", "because", by="me", now=T2)
    assert entry(path)["locked"] is True


def test_reopen_unlocks_records_the_reason_and_leaves_the_thread_entry(path):
    confirm(path, note="first")
    pagefile.reopen(path, "s1", "I misread the layout.", by="me", now=T2)
    doc = pagefile.load(path)
    assert "locked" not in entry(path)
    assert doc["rounds"][-1]["reopened"]["s1"] == "I misread the layout."
    st = pagefile.item_states(doc)["s1"]
    assert "locked" not in st and st["reopened"] == "I misread the layout."
    t = doc["thread"]["s1"][-1]
    assert t["from"] == "me" and t["action"] == "reopen" and t["reason"] == "I misread the layout." and t["at"] == T2
    # It is the reviewer's own reopen, not an agent update: nothing is handled or released.
    assert "handled" not in doc["rounds"][-1]


def test_after_a_reopen_the_answer_can_change_again(path):
    confirm(path)
    pagefile.reopen(path, "s1", "wrong", by="me", now=T2)
    pagefile.save_answers(path, {"s1": {"answer": "no", "note": "n"}}, by="me", now=T2)
    assert entry(path)["answer"] == "no" and "locked" not in entry(path)
    assert "s1" not in pagefile.load(path)["rounds"][-1].get("reopened", {})


def test_a_locked_yes_travels_into_the_next_round_as_a_settled_yes_not_a_lock(path):
    confirm(path)
    pagefile.new_round(path, now=T2)
    st = pagefile.item_states(pagefile.load(path))["s1"]
    assert st["hidden"] is True and "locked" not in st


# ---- over HTTP ----

def put(base, p, obj, method="PUT"):
    status, body, _ = request(base + p, method, json.dumps(obj))
    return status, (json.loads(body) if body else None)


@pytest.fixture()
def pages(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "design.json", review(), now=T0)
    return root, base


def test_put_answers_stores_the_lock_and_refuses_an_answer_change_with_409(pages):
    root, base = pages
    assert put(base, "/_page/demo/design/answers", {"answers": {"s1": {"answer": "yes", "note": "ok", "locked": True}}})[0] == 200
    status, out = put(base, "/_page/demo/design/answers", {"answers": {"s1": {"answer": "yes", "note": "ok2", "locked": True}}})
    assert status == 200, "a note-only update is accepted"
    status, out = put(base, "/_page/demo/design/answers", {"answers": {"s1": {"answer": "no", "note": "n"}}})
    assert status == 409 and "Reopen" in out["errors"][0]
    status, body, _ = request(base + "/_page/demo/design")
    page = json.loads(body)
    assert page["states"]["s1"]["locked"] is True
    assert page["page"]["rounds"][-1]["answers"]["s1"]["note"] == "ok2"


def test_a_bad_lock_request_is_a_400_like_other_answer_errors(pages):
    _, base = pages
    status, out = put(base, "/_page/demo/design/answers", {"answers": {"s1": {"answer": "no", "note": "n", "locked": True}}})
    assert status == 400 and out["errors"]


def test_reopen_endpoint(pages):
    _, base = pages
    put(base, "/_page/demo/design/answers", {"answers": {"s1": {"answer": "yes", "locked": True}}})
    assert put(base, "/_page/demo/design/reopen", {"item": "s1", "reason": ""}, "POST")[0] == 400
    assert put(base, "/_page/demo/design/reopen", {"item": "s1", "reason": "wrong"}, "POST")[0] == 200
    status, body, _ = request(base + "/_page/demo/design")
    page = json.loads(body)
    assert page["states"]["s1"].get("locked") is None and page["states"]["s1"]["reopened"] == "wrong"
    assert page["page"]["thread"]["s1"][-1]["action"] == "reopen"


def test_the_legacy_results_text_marks_a_confirmed_yes():
    import serve
    answers = {"s1": {"v": "yes", "n": "fine", "confirmed": True}}
    text = serve._results_text("demo/x.html", "X", "<body><h2>A</h2></body>", {}, answers, 1, "")
    assert "YES (locked)" in text and "Note: fine" in text


# ---- the new surfaces keep WCAG AA in light and dark (4.5:1 text, 3:1 control parts) ----

def test_the_confirm_and_reopen_boxes_have_contrast_in_light_and_dark():
    from test_site_css import contrast, theme_tokens
    text = [("--ink", "--yes-bg"), ("--ink", "--chg-bg"), ("--no", "--chg-bg"), ("--on-solid", "--yes-solid"),
            ("--ink", "--card"), ("--yes", "--yes-bg")]
    bad = []
    for theme, t in theme_tokens().items():
        bad += [(theme, a, b, round(contrast(t[a], t[b]), 2)) for a, b in text if contrast(t[a], t[b]) < 4.5]
    assert bad == []
