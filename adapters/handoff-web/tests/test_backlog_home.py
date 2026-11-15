"""Backlog as its own top-level board: the landing page, the old-address redirects, page.py move and the home page section."""

import http.client
import json
import subprocess
import sys
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import pagefile  # noqa: E402

from test_backlog_board import board  # noqa: E402
from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"


def configure(root, **extra):
    cfg = json.loads((root / "site.json").read_text())
    cfg["folders"] = cfg["folders"] + [{"id": "backlog", "name": "Backlog", "blurb": "Everything waiting to be done", "board": True,
                                        "landing": "board"}]
    cfg.update(extra)
    (root / "site.json").write_text(json.dumps(cfg))
    return cfg


def head(base, path):
    conn = http.client.HTTPConnection(base.removeprefix("http://"), timeout=10)
    conn.request("GET", path)
    r = conn.getresponse()
    r.read()
    return r.status, r.getheader("Location")


@pytest.fixture
def boarded(site):  # noqa: F811
    root, base = site
    configure(root)
    (root / "backlog").mkdir()
    pagefile.write_definition(root / "backlog" / "board.json", board(), now=T0)
    return root, base


# ---- addresses ----

def test_the_folder_address_opens_its_landing_page(boarded):
    _, base = boarded
    for p in ("/backlog", "/backlog/"):
        assert head(base, p) == (302, "/backlog/board"), p
    assert request(base + "/backlog/board")[0] == 200, "the board itself is a normal page"
    assert head(base, "/demo/")[0] == 200, "a folder with no landing page keeps its index"


def test_a_folder_whose_landing_page_is_missing_falls_back_to_its_index(site):  # noqa: F811
    root, base = site
    configure(root)
    (root / "backlog").mkdir()
    (root / "backlog" / "index.html").write_text("<p>index</p>")
    assert head(base, "/backlog/")[0] == 200


def test_old_addresses_redirect_with_or_without_a_slash_or_html(boarded):
    root, base = boarded
    configure(root, redirects={"/ops/backlog": "/backlog/board"})
    for p in ("/ops/backlog", "/ops/backlog/", "/ops/backlog.html"):
        assert head(base, p) == (301, "/backlog/board"), p
    assert head(base, "/ops/other")[0] == 404


@pytest.mark.parametrize("target", ["https://example.org/x", "//example.org/x", "backlog/board", "/a b", "/x?y=1", ""])
def test_an_unsafe_redirect_setting_is_ignored(boarded, target):
    root, base = boarded
    configure(root, redirects={"/ops/backlog": target})
    assert head(base, "/ops/backlog")[0] == 404


def test_the_shell_of_a_landing_page_is_marked_so_its_back_link_can_go_home(boarded):
    root, base = boarded
    pagefile.write_definition(root / "backlog" / "other.json", board(), now=T0)
    _, landing, _ = request(base + "/backlog/board")
    assert b'name="handoff-landing"' in landing, "the folder's landing page: its folder link would only bounce back to it"
    _, other, _ = request(base + "/backlog/other")
    assert b"handoff-landing" not in other, "a page that is not the landing page keeps its folder link"
    _, plain, _ = request(base + "/demo/design-review.html")
    assert b"handoff-landing" not in plain


# ---- page.py move ----

def run(root, *args):
    return subprocess.run([sys.executable, str(SITE / "page.py"), "--root", str(root), *args], capture_output=True, text=True)


def seeded(tmp_path):
    root = tmp_path / "s"
    (root / "ops").mkdir(parents=True)
    (root / "site.json").write_text(json.dumps({"timezone": "UTC", "folders": [{"id": "ops", "name": "OPS"}]}))
    path = root / "ops" / "backlog.json"
    pagefile.write_definition(path, board(), now=T0)
    pagefile.save_answers(path, {"b1": {"answer": "start", "note": "go"}}, by="me", now=T0)
    sub = pagefile.add_submission(path, {"kind": "send", "to": "ops", "items": ["b1"], "scope": "item", "file": "5-x-{n}.json"},
                                  now="2026-10-26T08:00:00-04:00")
    pagefile.hold(path, sub["n"])
    pagefile.reply(path, "b2", "ops", "later", action="info", now="2026-10-26T09:00:00-04:00")
    return root, path


def test_move_keeps_answers_rounds_sends_and_thread(tmp_path):
    root, old = seeded(tmp_path)
    before = json.loads(old.read_text())
    r = run(root, "move", "ops/backlog", "backlog/board")
    assert r.returncode == 0, r.stderr
    new = root / "backlog" / "board.json"
    assert new.exists() and not old.exists()
    assert json.loads(new.read_text()) == before, "the file is moved byte for byte in meaning: answers, rounds, sends, thread"
    assert not (root / "ops" / "backlog.json.lock").exists()


def test_move_refuses_to_overwrite_or_to_move_nothing(tmp_path):
    root, old = seeded(tmp_path)
    (root / "backlog").mkdir()
    pagefile.write_definition(root / "backlog" / "board.json", board(), now=T0)
    assert run(root, "move", "ops/backlog", "backlog/board").returncode != 0, "never over an existing page"
    assert old.exists()
    assert run(root, "move", "ops/missing", "backlog/other").returncode != 0
    assert run(root, "move", "ops/backlog", "board").returncode != 0, "a page is folder/slug"
    assert run(root, "move", "ops/backlog", "ops/backlog").returncode != 0


def test_move_can_record_the_redirect_and_moves_the_lock_file_with_it(tmp_path):
    root, old = seeded(tmp_path)
    (root / "ops" / "backlog.json.lock").write_text("")
    r = run(root, "move", "ops/backlog", "backlog/board", "--redirect")
    assert r.returncode == 0, r.stderr
    assert json.loads((root / "site.json").read_text())["redirects"] == {"/ops/backlog": "/backlog/board"}
    assert (root / "backlog" / "board.json.lock").exists() and not (root / "ops" / "backlog.json.lock").exists()
