"""Skipping a question: the page-level `skippable` flag, the Skipped state on the round's answer, its counts, and a Send."""

import json
import sys
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))

import pagefile  # noqa: E402
import schema  # noqa: E402

from test_serve import request, site  # noqa: E402, F401
from test_serve_pages import inbox, post, put_json  # noqa: E402

T0 = "2026-10-26T07:42:10-04:00"
T1 = "2026-10-26T08:05:44-04:00"
T2 = "2026-10-26T08:20:02-04:00"


def asks(**extra):
    d = {"schema": schema.SCHEMA, "kind": "questions", "title": "Asks", "skippable": True,
         "items": [{"id": "q1", "title": "One?"}, {"id": "q2", "title": "Two?"}]}
    d.update(extra)
    return d


@pytest.fixture
def path(tmp_path):
    return tmp_path / "app" / "asks.json"


def make(path, definition=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    pagefile.write_definition(path, definition or asks(), now=T0)
    return path


def skip(path, iid="q1", text="", at=T0, flag=True):
    return pagefile.save_answers(path, {iid: {"answer": text, "skipped": flag}}, by="me", now=at)


def sent(path, ids, at=T1):
    sub = pagefile.add_submission(path, {"kind": "send", "to": "ops", "items": ids, "file": "f-{n}.json"}, now=at)
    pagefile.hold(path, sub["n"])
    return sub


def test_the_skippable_flag_changes_no_item_hash(path):
    check = {"id": "c1", "title": "Check it", "skip": True}
    before = pagefile.item_hash(check)
    plain = {"schema": schema.SCHEMA, "kind": "checklist", "title": "T", "build": "b1", "items": [check]}
    make(path, plain)
    pagefile.save_answers(path, {"c1": {"answer": "skipped"}}, by="me", now=T0)
    pagefile.write_definition(path, {**plain, "skippable": True}, now=T1)
    doc = pagefile.load(path)
    assert doc["skippable"] is True and doc["rounds"][0]["answers"]["c1"]["hash"] == before == pagefile.item_hash(doc["items"][0])
    assert pagefile.item_states(doc)["c1"]["reopened"] is None and "revisions" not in doc


def test_a_question_skip_keeps_the_text_and_un_skip_gives_it_back(path):
    make(path)
    pagefile.save_answers(path, {"q1": {"answer": "Saturd"}}, by="me", now=T0)
    skip(path, text="Saturd", at=T1)
    entry = pagefile.load(path)["rounds"][0]["answers"]["q1"]
    assert entry["skipped"] is True and entry["answer"] == "Saturd"
    assert entry["was"] == [{"answer": "Saturd", "note": "", "by": "me", "at": T0}]
    assert pagefile.item_states(pagefile.load(path))["q1"]["skipped"] is True
    skip(path, text="Saturd", at=T2, flag=False)
    state = pagefile.item_states(pagefile.load(path))["q1"]
    assert "skipped" not in state and state["answer"] == "Saturd"


def test_a_skipped_question_refuses_new_text_until_un_skipped(path):
    make(path)
    skip(path, text="one")
    for body in ({"answer": "two"}, {"answer": "two", "skipped": True}):
        with pytest.raises(pagefile.PageError, match="un-skip to change"):
            pagefile.save_answers(path, {"q1": body}, by="me", now=T1)
    skip(path, text="two", at=T1, flag=False)
    assert pagefile.load(path)["rounds"][0]["answers"]["q1"]["answer"] == "two"


def test_skipping_with_no_text_is_an_answer_and_repeating_it_is_a_no_op(path):
    make(path)
    rev = skip(path)
    assert pagefile.load(path)["rounds"][0]["answers"]["q1"]["skipped"] is True
    assert skip(path, at=T1) == rev
    assert pagefile.save_answers(path, {"q1": {"answer": ""}}, by="me", now=T1) == rev, "no key keeps the skip"


def test_skipping_is_refused_off_a_skippable_page_and_off_a_non_question(path):
    make(path, asks(skippable=False))
    with pytest.raises(pagefile.PageError, match="skippable page"):
        skip(path)
    mixed = asks(items=[{"id": "q1", "type": "question", "title": "One?"}, {"id": "s1", "type": "section", "title": "S"}], kind="review")
    pagefile.write_definition(path, mixed, now=T1)
    with pytest.raises(pagefile.PageError, match="skippable page"):
        skip(path, "s1", "yes", at=T2)
    skip(path, "s1", "yes", at=T2, flag=False)
    assert "skipped" not in pagefile.load(path)["rounds"][0]["answers"]["s1"]


def test_a_page_without_skippable_is_unchanged(path):
    plain = asks()
    del plain["skippable"]
    make(path, plain)
    pagefile.save_answers(path, {"q1": {"answer": "Saturday"}}, by="me", now=T0)
    doc = pagefile.load(path)
    assert "skippable" not in doc and "skipped" not in doc["rounds"][0]["answers"]["q1"]
    assert pagefile.item_states(doc)["q1"] == {"answer": "Saturday", "hidden": False, "reopened": None, "round": 1}
    assert "skipped" not in pagefile.summary(doc)


def test_a_skipped_question_stays_skipped_in_the_next_round(path):
    make(path)
    skip(path)
    pagefile.new_round(path, now=T1)
    state = pagefile.item_states(pagefile.load(path))["q1"]
    assert state == {"answer": "", "hidden": True, "reopened": None, "round": 1, "skipped": True}


def test_un_skipping_a_skip_from_an_earlier_round_cancels_it(path):
    make(path)
    skip(path, text="keep me")
    pagefile.new_round(path, now=T1)
    skip(path, text="keep me", at=T2, flag=False)
    state = pagefile.item_states(pagefile.load(path))["q1"]
    assert "skipped" not in state and state["answer"] == "keep me"
    skip(path, text="", at=T2, flag=False)
    state = pagefile.item_states(pagefile.load(path))["q1"]
    assert "skipped" not in state and state["answer"] == "" and state["hidden"] is False
    pagefile.new_round(path, now=T2)
    assert "skipped" not in pagefile.item_states(pagefile.load(path))["q1"]


def test_a_sent_skip_locks_and_can_be_un_skipped_after_the_update(path):
    make(path)
    skip(path)
    sent(path, ["q1"])
    with pytest.raises(pagefile.PageError, match="was sent"):
        skip(path, at=T1, flag=False)
    pagefile.reply(path, "_page", "ops", "Taken.", now=T2)
    assert pagefile.item_states(pagefile.load(path))["q1"]["hidden"] is True
    skip(path, text="now", at=T2, flag=False)
    state = pagefile.item_states(pagefile.load(path))["q1"]
    assert state["answer"] == "now" and "skipped" not in state


def test_summary_counts_skipped_questions_only_when_there_are_some(path):
    items = [{"id": "q1", "type": "question", "title": "One?"}, {"id": "s1", "type": "section", "title": "S"}]
    make(path, asks(kind="review", items=items))
    assert "skipped" not in pagefile.summary(pagefile.load(path))
    skip(path)
    s = pagefile.summary(pagefile.load(path))
    assert s["skipped"] == 1 and s["open"] == 1 and s["counted"] == 1


def test_a_skipped_question_does_not_stop_a_phase_or_the_page(path):
    make(path, asks(kind="round", phases=[{"id": "A", "title": "One"}],
                    items=[{"id": "A1", "type": "section", "title": "S"}, {"id": "A2", "type": "question", "title": "Q"}]))
    pagefile.save_answers(path, {"A1": {"answer": "yes"}}, by="me", now=T0)
    skip(path, "A2", at=T1)
    doc = pagefile.load(path)
    assert pagefile.phase_states(doc)["A"]["closed"] is True and pagefile.summary(doc)["approved"] is True


def test_a_skippable_page_can_be_checked_and_a_question_still_takes_no_skip_key():
    assert schema.validate(asks()) == []
    assert schema.validate(asks(skippable="yes")) == ["skippable: expected true or false"]
    bad = asks(items=[{"id": "q1", "title": "Q?", "skip": True}])
    assert any("skip" in e for e in schema.validate(bad))


def test_a_stored_answer_may_carry_skipped():
    doc = asks(rounds=[{"round": 1, "opened": "x", "closed": None, "openedBy": "created", "answers": {
        "q1": {"answer": "", "at": "x", "skipped": True, "was": [{"answer": "a", "at": "y", "skipped": True}]}}}])
    assert schema.validate(doc) == []
    doc["rounds"][0]["answers"]["q1"]["skipped"] = "yes"
    assert schema.validate(doc) == ["rounds[#1].answers.q1.skipped: expected true or false"]


@pytest.fixture()
def pages(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "asks.json", asks())
    return root, base


def card(base):
    return next(c for c in json.loads(request(base + "/_index/demo")[1])["pages"] if c["href"] == "/demo/asks")


def test_a_skipped_question_goes_in_a_send_with_the_flag_and_no_answer(pages):
    root, base = pages
    status, _, _ = put_json(base, "/_page/demo/asks/answers", {"answers": {"q1": {"answer": "draft", "skipped": True}}})
    assert status == 200
    assert card(base)["state"] == "needs-you" and "To review" in card(base)["chips"], "q2 is still open"
    status, _, _ = post(base, "/_page/demo/asks/send", {"kind": "send", "results": "SKIPPED: One?"})
    assert status == 200
    sub = json.loads((root / "_inbox" / "ops" / inbox(root)[0]).read_text())
    assert sub["items"] == [{"id": "q1", "n": 1, "answer": "", "note": "", "skipped": True, "blocker": False}]


def test_a_skipped_question_can_be_sent_alone_and_counts_as_handled_on_the_card(pages):
    root, base = pages
    pagefile.write_definition(root / "demo" / "asks.json", asks(items=[{"id": "q1", "title": "One?"}]))
    put_json(base, "/_page/demo/asks/answers", {"answers": {"q1": {"answer": "", "skipped": True}}})
    assert "To review" not in card(base)["chips"]
    status, _, _ = post(base, "/_page/demo/asks/send", {"kind": "send", "scope": "item", "items": ["q1"], "results": "R"})
    assert status == 200


def test_put_answers_refuses_a_skip_off_a_skippable_page(pages):
    root, base = pages
    pagefile.write_definition(root / "demo" / "plain.json", asks(skippable=False))
    status, body, _ = put_json(base, "/_page/demo/plain/answers", {"answers": {"q1": {"answer": "", "skipped": True}}})
    assert status == 400 and "skippable" in json.dumps(body)
