"""An item marked "fix in progress": stored beside the definition, locked like a blocked item, counted apart from open."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pagefile  # noqa: E402
import pageindex  # noqa: E402

from test_pagefile import review  # noqa: E402
from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"
T1 = "2026-10-26T08:05:44-04:00"


@pytest.fixture
def path(tmp_path):
    p = tmp_path / "design.json"
    pagefile.write_definition(p, review(), now=T0)
    return p


def test_marking_an_item_stores_the_text_beside_the_definition(path):
    before = pagefile.load(path)["items"][0]
    pagefile.set_fixing(path, "s1", "bug log 246")
    doc = pagefile.load(path)
    assert doc["fixing"] == {"s1": "bug log 246"}
    assert doc["items"][0] == before, "the item itself is untouched, so its hash is too"
    assert pagefile.item_states(doc)["s1"]["fixing"] == "bug log 246"
    assert "fixing" not in pagefile.item_states(doc)["s2"]


def test_marking_does_not_reopen_an_answered_item(path):
    pagefile.save_answers(path, {"s1": {"answer": "yes"}}, by="me", now=T0)
    pagefile.set_fixing(path, "s1", "bug log 246")
    pagefile.clear_fixing(path, "s1")
    st = pagefile.item_states(pagefile.load(path))["s1"]
    assert st["answer"] == "yes" and st["reopened"] is None


@pytest.mark.parametrize("item,text", [("nope", "x"), ("s1", ""), ("s1", "   ")])
def test_marking_needs_an_item_and_a_text(path, item, text):
    with pytest.raises(pagefile.PageError):
        pagefile.set_fixing(path, item, text)
    assert "fixing" not in pagefile.load(path)


def test_an_info_item_cannot_be_marked(tmp_path):
    p = tmp_path / "i.json"
    d = review()
    d["items"].append({"id": "i1", "type": "info", "title": "Background", "body": [{"p": "x"}]})
    pagefile.write_definition(p, d, now=T0)
    with pytest.raises(pagefile.PageError):
        pagefile.set_fixing(p, "i1", "x")


def test_a_marked_item_takes_no_answer_and_the_rest_still_do(path):
    pagefile.set_fixing(path, "s1", "bug log 246")
    with pytest.raises(pagefile.PageError) as e:
        pagefile.save_answers(path, {"s1": {"answer": "yes"}}, by="me", now=T1)
    assert "fix in progress" in str(e.value) and "bug log 246" in str(e.value)
    pagefile.save_answers(path, {"s2": {"answer": "yes"}}, by="me", now=T1)
    assert "s1" not in pagefile.load(path)["rounds"][-1]["answers"]


def test_a_marked_item_counts_apart_from_open_and_blocked(path):
    base = pagefile.summary(pagefile.load(path))
    assert base["open"] == 2 and "fixing" not in base
    pagefile.set_fixing(path, "s1", "bug log 246")
    s = pagefile.summary(pagefile.load(path))
    assert s["open"] == 1 and s["blocked"] == 0 and s["fixing"] == 1 and s["counted"] == 2
    assert s["approved"] is False
    assert "s1" in pagefile.blocked_items(pagefile.load(path)), "send and the dependants treat it as blocked"


def test_clearing_returns_the_item_to_open(path):
    pagefile.set_fixing(path, "s1", "bug log 246")
    pagefile.clear_fixing(path, "s1")
    doc = pagefile.load(path)
    assert "fixing" not in doc, "an empty map is not left behind"
    assert pagefile.summary(doc)["open"] == 2 and "fixing" not in pagefile.item_states(doc)["s1"]
    pagefile.save_answers(path, {"s1": {"answer": "yes"}}, by="me", now=T1)
    with pytest.raises(pagefile.PageError):
        pagefile.clear_fixing(path, "s1")


def test_a_definition_rewrite_keeps_the_mark(path):
    pagefile.set_fixing(path, "s1", "bug log 246")
    pagefile.write_definition(path, review(summary="Updated"), now=T1)
    assert pagefile.load(path)["fixing"] == {"s1": "bug log 246"}


def test_a_mark_on_a_removed_item_is_dropped_with_it(path):
    pagefile.set_fixing(path, "s2", "bug log 246")
    d = review()
    d["items"] = [i for i in d["items"] if i["id"] != "s2"]
    pagefile.write_definition(path, d, now=T1)
    assert "s2" not in pagefile.load(path).get("fixing", {})


def test_the_schema_rejects_a_mark_on_nothing(path):
    doc = pagefile.load(path)
    doc["fixing"] = {"zzz": "x"}
    import schema
    assert schema.validate(doc)
    doc["fixing"] = {"s1": 5}
    assert schema.validate(doc)


def test_the_index_card_leaves_it_out_of_open_and_shows_a_chip(path, tmp_path):
    root = tmp_path / "demo"
    root.mkdir()
    p = root / "design.json"
    pagefile.write_definition(p, review(), now=T0)
    n_open = pageindex.page_card("demo", "demo/design", str(p))["open"]
    pagefile.set_fixing(p, "s1", "bug log 246")
    card = pageindex.page_card("demo", "demo/design", str(p))
    assert card["open"] == n_open - 1 and "Fix in progress" in card["chips"]
    pagefile.clear_fixing(p, "s1")
    card = pageindex.page_card("demo", "demo/design", str(p))
    assert card["open"] == n_open and "Fix in progress" not in card["chips"]


def run(tmp_path, *args):
    return subprocess.run([sys.executable, str(SITE / "page.py"), "--root", str(tmp_path), *args], capture_output=True, text=True)


def test_page_py_sets_and_clears_it(tmp_path):
    (tmp_path / "demo").mkdir()
    pagefile.write_definition(tmp_path / "demo" / "design.json", review(), now=T0)
    r = run(tmp_path, "fixing", "demo/design", "s1", "bug log 246")
    assert r.returncode == 0, r.stderr
    assert pagefile.load(tmp_path / "demo" / "design.json")["fixing"] == {"s1": "bug log 246"}
    assert run(tmp_path, "fixing", "demo/design", "s1").returncode != 0, "a text or --clear is required"
    r = run(tmp_path, "fixing", "demo/design", "s1", "--clear")
    assert r.returncode == 0, r.stderr
    assert "fixing" not in pagefile.load(tmp_path / "demo" / "design.json")
    assert run(tmp_path, "fixing", "demo/design", "s1", "--clear").returncode != 0, "clearing what is not set says so"


def test_the_page_endpoint_serves_it_and_refuses_answers_and_sends(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "design.json", review(), now=T0)
    pagefile.save_answers(root / "demo" / "design.json", {"s1": {"answer": "no", "note": "broken"}}, by="me", now=T0)
    pagefile.set_fixing(root / "demo" / "design.json", "s1", "bug log 246")
    _, body, _ = request(base + "/_page/demo/design")
    page = json.loads(body)
    assert page["states"]["s1"]["fixing"] == "bug log 246" and page["summary"]["fixing"] == 1
    status, _, _ = request(base + "/_page/demo/design/answers", "PUT", json.dumps({"answers": {"s1": {"answer": "yes"}}}))
    assert status == 400
    body = json.dumps({"kind": "send", "scope": "item", "items": ["s1"], "results": "r"})
    status, _, _ = request(base + "/_page/demo/design/send", "POST", body)
    assert status == 400, "an item send refuses a marked item as blocked"


def test_the_purple_fix_colours_have_contrast_in_light_and_dark():
    from test_site_css import contrast, theme_tokens
    text = [("--fix", "--fix-bg"), ("--fix", "--card"), ("--ink", "--fix-bg"), ("--ink", "--card")]
    parts = [("--fix-edge", "--card"), ("--fix-edge", "--paper")]
    bad = []
    for theme, t in theme_tokens().items():
        bad += [(theme, a, b, round(contrast(t[a], t[b]), 2)) for a, b in text if contrast(t[a], t[b]) < 4.5]
        bad += [(theme, a, b, round(contrast(t[a], t[b]), 2)) for a, b in parts if contrast(t[a], t[b]) < 3]
    assert bad == []
