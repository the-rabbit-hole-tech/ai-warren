"""Copy works on any address (ai-warren#29): a real Chrome clicks every kind of Copy button at http://127.0.0.1 (a
secure context) and at the machine's LAN address (not secure: no clipboard API), reads the clipboard back, and checks
the "Press and hold to copy" fallback and the 390 px layout. Skipped when Chrome, node or a LAN address is missing."""

import shutil
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import pytest

from test_review_choices import find_chrome
from test_review_smoke import free_port

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tests" / "js" / "copy_cdp.test.mjs"
sys.path.insert(0, str(ROOT / "template" / "_site"))

import pagefile  # noqa: E402

T0 = "2026-10-26T07:42:10-04:00"
ITEMS = [{"id": "r1", "title": "A module repo", "body": [{"p": "Reads."}]}]


def lan_address():
    """An address other machines could use, or None when this one has no network."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        try:
            s.connect(("10.255.255.255", 1))
            ip = s.getsockname()[0]
        except OSError:
            return None
    return None if ip.startswith("127.") else ip


@pytest.fixture(scope="module")
def site(tmp_path_factory):
    tmp = tmp_path_factory.mktemp("copyany")
    root = tmp / "site"
    shutil.copytree(ROOT / "template", root)
    (root / "demo").mkdir()
    shutil.copy(ROOT / "example" / "site.json", root / "site.json")
    demo = root / "demo"
    w = pagefile.write_definition
    w(demo / "cp-ref.json", {"schema": "handoff.page/v1", "kind": "reference", "title": "Notes", "items": [
        {"id": "n1", "title": "Commands", "body": [
            {"copy": "kubectl get pods -n warren"}, {"p": "Open `http://burrow.lan:5390/` to look."}]}]}, now=T0)
    w(demo / "cp-copyroute.json", {"schema": "handoff.page/v1", "kind": "review", "title": "Copy route", "items": ITEMS}, now=T0)
    pagefile.set_route(demo / "cp-copyroute.json", "ops", "copy")
    w(demo / "cp-history.json", {"schema": "handoff.page/v1", "kind": "review", "title": "History", "items": ITEMS}, now=T0)
    pagefile.new_round(demo / "cp-history.json", results="Round 1: History\n- [r1] NO: A module repo", now=T0)
    port = free_port()
    proc = subprocess.Popen([sys.executable, str(root / "_site" / "serve.py"), str(port), "--bind", "0.0.0.0", "--directory", str(root)],
                            stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            try:
                urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1)
                break
            except OSError:
                time.sleep(0.05)
        yield port, tmp
    finally:
        proc.terminate()
        proc.wait(timeout=5)


@pytest.mark.parametrize("where", ["loopback", "lan"])
def test_copy_works_on_any_address(site, where, tmp_path):
    chrome, node = find_chrome(), shutil.which("node")
    if not chrome or not node:
        pytest.skip("Chrome or node is not installed")
    port, _ = site
    if where == "lan":
        ip = lan_address()
        if not ip:
            pytest.skip("this machine has no LAN address")
        base = f"http://{ip}:{port}"
    else:
        base = f"http://127.0.0.1:{port}"
    out = subprocess.run([node, str(SCRIPT), chrome, str(tmp_path / "profile"), base], capture_output=True, text=True, timeout=240)
    assert out.stdout.count("ok   ") == 6 and out.returncode == 0, out.stdout + out.stderr
