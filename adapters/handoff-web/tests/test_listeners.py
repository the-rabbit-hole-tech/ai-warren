"""Pausing the listeners: one server-side switch that stops agents being woken, loses no submission and delivers on resume."""

import datetime as dt
import json
import select
import subprocess
import sys
import time
from pathlib import Path

import pytest

SITE = Path(__file__).resolve().parent.parent / "template" / "_site"
sys.path.insert(0, str(SITE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import listeners  # noqa: E402
import pagefile  # noqa: E402

from test_pagefile import review  # noqa: E402
from test_serve import request, site  # noqa: E402, F401

T0 = "2026-10-26T07:42:10-04:00"
EST = dt.timezone(dt.timedelta(hours=-5))


@pytest.fixture
def root(tmp_path):
    (tmp_path / "_saved").mkdir()
    (tmp_path / "site.json").write_text(json.dumps({"timezone": "America/New_York"}))
    return tmp_path


# ---- the state ----

def test_listeners_are_on_by_default(root):
    assert listeners.status(str(root)) == {"paused": False, "until": None, "at": None, "by": None}


def test_pause_and_resume_are_stored_in_saved(root):
    listeners.pause(str(root), by="Alex")
    st = listeners.status(str(root))
    assert st["paused"] is True and st["until"] is None and st["by"] == "Alex" and st["at"]
    assert json.loads((root / "_saved" / "_listeners.json").read_text())["paused"] is True
    listeners.resume(str(root), by="Alex")
    assert listeners.status(str(root))["paused"] is False


def test_a_timed_pause_ends_by_itself(root):
    now = dt.datetime(2026, 11, 8, 23, 0, tzinfo=EST)
    listeners.pause(str(root), until=now + dt.timedelta(hours=7), now=now)
    assert listeners.status(str(root), now=now + dt.timedelta(hours=6))["paused"] is True
    st = listeners.status(str(root), now=now + dt.timedelta(hours=7, seconds=1))
    assert st["paused"] is False and st["until"] is None, "past its time the listeners are On"


def test_a_pause_until_a_clock_time_picks_the_next_one_in_the_site_zone():
    late = dt.datetime(2026, 11, 8, 23, 0, tzinfo=EST)
    early = dt.datetime(2026, 11, 9, 5, 0, tzinfo=EST)
    assert listeners.until_clock("06:00", "America/New_York", now=late).isoformat() == "2026-11-09T06:00:00-05:00"
    assert listeners.until_clock("06:00", "America/New_York", now=early).isoformat() == "2026-11-09T06:00:00-05:00"
    assert listeners.until_clock("06:00", "America/New_York", now=early.replace(hour=7)).isoformat() == "2026-11-10T06:00:00-05:00"


@pytest.mark.parametrize("bad", ["", "6", "25:00", "06:61", "noon", "06:00:00", None, 600])
def test_a_bad_clock_time_is_refused(bad):
    with pytest.raises(ValueError):
        listeners.until_clock(bad, "UTC")


def test_a_damaged_file_means_on_not_a_crash(root):
    (root / "_saved" / "_listeners.json").write_text("{not json")
    assert listeners.status(str(root))["paused"] is False


# ---- what the agent side does ----

def page_py(root, *args, **kw):
    return subprocess.Popen([sys.executable, str(SITE / "page.py"), "--root", str(root), *args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, **kw)


def drop(root, agent="ops", names=("5-send.json", "0-blocker.json")):
    inbox = root / "_inbox" / agent
    inbox.mkdir(parents=True, exist_ok=True)
    for n in names:
        (inbox / n).write_text("{}")
    return inbox


def test_wait_keeps_blocking_while_paused_and_delivers_on_resume_blockers_first(root):
    inbox = drop(root)
    listeners.pause(str(root))
    p = page_py(root, "wait", "ops", "--timeout", "20", "--interval", "0.2", "--poll")
    time.sleep(1.5)
    assert p.poll() is None, "a paused wait does not return, so the agent is not woken and spends nothing"
    assert (inbox / ".listening").exists(), "the page still sees an agent listening"
    listeners.resume(str(root))
    out, err = p.communicate(timeout=10)
    assert p.returncode == 0, err
    assert [Path(x).name for x in out.split()] == ["0-blocker.json", "5-send.json"], "blockers first"
    assert (inbox / "0-blocker.json").exists() and (inbox / "5-send.json").exists(), "nothing was lost or removed"


def test_wait_that_times_out_while_paused_exits_quietly_with_the_timeout_status(root):
    drop(root)
    listeners.pause(str(root))
    p = page_py(root, "wait", "ops", "--timeout", "1", "--interval", "0.2", "--poll")
    out, _ = p.communicate(timeout=10)
    assert p.returncode == 3 and out == ""


def test_a_submission_that_arrives_during_a_pause_waits_too(root):
    (root / "_inbox" / "ops").mkdir(parents=True)
    listeners.pause(str(root))
    p = page_py(root, "wait", "ops", "--timeout", "20", "--interval", "0.2")
    time.sleep(0.8)
    (root / "_inbox" / "ops" / "5-late.json").write_text("{}")
    time.sleep(1.2)
    assert p.poll() is None, "even with kqueue waking it, a paused wait goes back to sleep"
    listeners.resume(str(root))
    out, _ = p.communicate(timeout=10)
    assert [Path(x).name for x in out.split()] == ["5-late.json"]


def test_an_expired_timed_pause_delivers_at_once(root):
    drop(root, names=("5-send.json",))
    past = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=1)
    stored = {"paused": True, "until": past.isoformat(), "at": past.isoformat(), "by": "x"}
    (root / "_saved" / "_listeners.json").write_text(json.dumps(stored))
    p = page_py(root, "wait", "ops", "--timeout", "5", "--interval", "0.2", "--poll")
    out, _ = p.communicate(timeout=10)
    assert p.returncode == 0 and Path(out.split()[0]).name == "5-send.json"


def test_listen_prints_nothing_while_paused_and_the_queue_on_resume(root):
    drop(root)
    listeners.pause(str(root))
    p = page_py(root, "listen", "ops", "--interval", "0.2")
    try:
        time.sleep(1.2)
        assert p.poll() is None
        assert not select.select([p.stdout], [], [], 0)[0], "paused: nothing is printed, though two files are waiting"
        listeners.resume(str(root))
        lines = []
        deadline = time.monotonic() + 8
        while len(lines) < 2 and time.monotonic() < deadline:
            line = p.stdout.readline()
            if line:
                lines.append(Path(line.strip()).name)
        assert lines == ["0-blocker.json", "5-send.json"]
    finally:
        p.terminate()
        p.wait(timeout=5)


def hook(root):
    r = subprocess.run([sys.executable, str(SITE / "page.py"), "--root", str(root), "hook", "ops"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return r.stdout


def test_the_inbox_hook_says_nothing_while_paused(root):
    drop(root)
    assert "submission" in hook(root), "baseline: it speaks when listeners are on"
    listeners.pause(str(root))
    assert hook(root) == "", "paused: no waiting line and no 'nothing is listening' line"
    listeners.resume(str(root))
    assert "submission" in hook(root)
    (root / "_inbox" / "ops" / "5-send.json").unlink()
    (root / "_inbox" / "ops" / "0-blocker.json").unlink()
    assert "nothing is listening" in hook(root)
    listeners.pause(str(root))
    assert hook(root) == ""


def test_page_py_listeners_command(root):
    def run(*a):
        cmd = [sys.executable, str(SITE / "page.py"), "--root", str(root), "listeners", *a]
        return subprocess.run(cmd, capture_output=True, text=True)
    assert "on" in run("status").stdout.lower()
    r = run("pause")
    assert r.returncode == 0 and listeners.status(str(root))["paused"] is True
    assert "paused" in run("status").stdout.lower()
    r = run("pause", "--until", "06:00")
    assert r.returncode == 0 and listeners.status(str(root))["until"], r.stderr
    assert run("pause", "--until", "noon").returncode != 0
    assert run("on").returncode == 0 and listeners.status(str(root))["paused"] is False


# ---- the server ----

def test_the_endpoints_get_and_set_the_state(site):  # noqa: F811
    root, base = site
    status, body, _ = request(base + "/_listeners")
    assert status == 200 and json.loads(body)["paused"] is False
    status, body, _ = request(base + "/_listeners", "POST", json.dumps({"paused": True}))
    assert status == 200 and json.loads(body)["paused"] is True
    assert listeners.status(str(root))["paused"] is True, "stored on the server, so every tab and agent sees it"
    status, body, _ = request(base + "/_listeners", "POST", json.dumps({"paused": True, "until": "06:00"}))
    st = json.loads(body)
    assert status == 200 and st["paused"] is True and st["until"].endswith(":00") and "T06:00:00" in st["until"]
    assert request(base + "/_listeners", "POST", json.dumps({"paused": True, "until": "noon"}))[0] == 400
    assert request(base + "/_listeners", "POST", json.dumps({"paused": "yes"}))[0] == 400
    assert request(base + "/_listeners", "POST", "not json")[0] in (400, 415)
    status, body, _ = request(base + "/_listeners", "POST", json.dumps({"paused": False}))
    assert json.loads(body)["paused"] is False


def test_a_page_and_a_send_know_about_the_pause_and_still_save_the_submission(site):  # noqa: F811
    root, base = site
    pagefile.write_definition(root / "demo" / "design.json", review(), now=T0)
    request(base + "/_page/demo/design/answers", "PUT", json.dumps({"answers": {"s1": {"answer": "yes"}}}))
    request(base + "/_listeners", "POST", json.dumps({"paused": True}))
    page = json.loads(request(base + "/_page/demo/design")[1])
    assert page["listeners"]["paused"] is True
    status, body, _ = request(base + "/_page/demo/design/send", "POST", json.dumps({"kind": "send", "results": "R"}))
    out = json.loads(body)
    assert status == 200 and out["paused"] is True
    assert (root / "_inbox" / "ops" / out["file"]).exists(), "the Send is saved to the inbox while paused"
    request(base + "/_listeners", "POST", json.dumps({"paused": False}))
    assert json.loads(request(base + "/_page/demo/design")[1])["listeners"]["paused"] is False
