"""scripts/build-release.sh packs a tarball that installs, and installing again over a live site updates it in place."""

import json
import shutil
import subprocess
import tarfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "build-release.sh"

pytestmark = pytest.mark.skipif(not shutil.which("git") or not shutil.which("shasum"), reason="git and shasum are needed")


def in_git():
    r = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--is-inside-work-tree"], capture_output=True, text=True)
    return r.returncode == 0


@pytest.fixture(scope="module")
def built(tmp_path_factory):
    if not in_git():
        pytest.skip("not a git checkout")
    out = tmp_path_factory.mktemp("dist")
    r = subprocess.run([str(SCRIPT), "9.9.9", str(out)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return out


def test_it_refuses_a_bad_version(tmp_path):
    r = subprocess.run([str(SCRIPT), "v1", str(tmp_path)], capture_output=True, text=True)
    assert r.returncode == 2 and "usage" in r.stderr


def test_the_tarball_has_what_the_installer_needs_and_its_checksum_matches(built):
    tgz = built / "handoff-web-9.9.9.tar.gz"
    names = tarfile.open(tgz).getnames()
    for want in ("install.sh", "LICENSE", "template/_site/serve.py", "template/_site/app/app.js", "template/_site/warren-mark.svg",
                 "template/_site/site.css", "example/site.json"):
        assert f"handoff-web-9.9.9/{want}" in names, want
    assert not any("/tests/" in n or "/web/" in n or "node_modules" in n for n in names), "tests and sources stay out"
    r = subprocess.run(["shasum", "-a", "256", "-c", "handoff-web-9.9.9.sha256"], cwd=built, capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr


def test_installing_from_the_tarball_then_again_updates_in_place(built, tmp_path):
    src = tmp_path / "src"
    src.mkdir()
    tarfile.open(built / "handoff-web-9.9.9.tar.gz").extractall(src)
    inst = src / "handoff-web-9.9.9" / "install.sh"
    site = tmp_path / "site"
    args = [str(inst), str(site), "--owner", "Alex", "--port", "5999"]
    r = subprocess.run(args, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert r.returncode == 0, r.stderr
    assert (site / "_site" / "serve.py").exists() and (site / "_site" / "warren-mark.svg").exists()
    cfg = json.loads((site / "site.json").read_text())
    assert cfg["owner"] == "Alex" and cfg["port"] == 5999
    # A live site: saved answers, its own pages, a custom folder file, and a stale file of an older release.
    (site / "_saved" / "answers.json").write_text('{"keep": true}')
    (site / "mine").mkdir()
    (site / "mine" / "page.json").write_text("{}")
    (site / "custom" / "mine.css").write_text("/* mine */")
    (site / "_site" / "serve.py").write_text("# old release\n")
    r = subprocess.run([str(inst), str(site)], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert r.returncode == 0, r.stderr
    assert "kept the existing" in r.stdout
    assert json.loads((site / "site.json").read_text()) == cfg, "site.json is kept"
    assert (site / "_saved" / "answers.json").read_text() == '{"keep": true}'
    assert (site / "mine" / "page.json").exists() and (site / "custom" / "mine.css").exists()
    assert "old release" not in (site / "_site" / "serve.py").read_text(), "the code is replaced by the release's"
