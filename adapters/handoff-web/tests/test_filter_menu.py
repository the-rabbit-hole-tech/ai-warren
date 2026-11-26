"""The Projects filter menu on the root index stays inside the screen at phone widths.

Drives headless Chrome against a real serve.py: a harness frames the root page at the given width,
opens the menu like the owner would and writes the menu's box into the DOM. Skipped when no Chrome
or Chromium is installed. Regression for the-rabbit-hole-tech/ai-warren#25.
"""

import html
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.request

import pytest

from sites import html_example
from test_review_choices import ROOT, find_chrome, free_port

HARNESS = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>harness</title></head><body style="margin:0">
<iframe id="f" style="width:%dpx;height:700px;border:0"></iframe>
<pre id="out">pending</pre>
<script>
const out = {};
const sleep = ms => new Promise(r => setTimeout(r, ms));
const f = document.getElementById("f");
(async () => {
  await new Promise(r => { f.onload = r; f.src = "/"; });
  const d = f.contentDocument;
  for (let i = 0; i < 100 && !d.querySelector("#filter .fbtn"); i++) await sleep(50);
  d.querySelector("#filter .fbtn").click();
  await sleep(200);
  const m = d.querySelector("#filter-menu"), r = m.getBoundingClientRect();
  out.hidden = m.hidden; out.left = r.left; out.right = r.right; out.top = r.top; out.bottom = r.bottom;
  out.width = f.contentWindow.innerWidth; out.height = f.contentWindow.innerHeight;
  out.scrollable = getComputedStyle(m).overflowY;
})().catch(e => { out.error = String(e && e.stack || e); })
  .finally(() => { document.getElementById("out").textContent = JSON.stringify(out); });
</script></body></html>
"""


def measure(width, folders=None):
    chrome = find_chrome()
    if not chrome:
        pytest.skip("Chrome or Chromium is not installed")
    import tempfile
    from pathlib import Path
    tmp = Path(tempfile.mkdtemp(prefix="filtermenu"))
    try:
        root = tmp / "site"
        shutil.copytree(ROOT / "template", root)
        for d in ("demo", "guide"):
            shutil.copytree(html_example(d), root / d)
        cfg = json.loads((ROOT / "example" / "site.json").read_text())
        for i in range(folders or 0):
            cfg["folders"].append({"id": f"extra{i}", "name": f"A long project group name number {i}", "blurb": "x"})
            (root / f"extra{i}").mkdir()
        (root / "site.json").write_text(json.dumps(cfg))
        built = subprocess.run([sys.executable, str(root / "gen-index.py")], cwd=root, capture_output=True, text=True)
        assert built.returncode == 0, built.stderr
        (root / "harness.html").write_text(HARNESS % width)
        port = free_port()
        proc = subprocess.Popen([sys.executable, str(root / "_site" / "serve.py"), str(port), "--bind", "127.0.0.1",
                                 "--directory", str(root)], stderr=subprocess.DEVNULL)
        try:
            base = f"http://127.0.0.1:{port}"
            for _ in range(100):
                try:
                    urllib.request.urlopen(base + "/", timeout=1)
                    break
                except OSError:
                    time.sleep(0.05)
            r = subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-first-run",
                                f"--user-data-dir={tmp / 'profile'}", "--virtual-time-budget=20000", "--dump-dom",
                                f"{base}/harness.html"], capture_output=True, text=True, timeout=120)
            m = re.search(r'<pre id="out">(.*?)</pre>', r.stdout, re.S)
            assert m, r.stdout[-2000:] + r.stderr[-2000:]
            data = json.loads(html.unescape(m.group(1)))
            assert "error" not in data, data["error"]
            return data
        finally:
            proc.terminate()
            proc.wait(timeout=5)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@pytest.mark.parametrize("width", [320, 390, 768, 1200])
def test_menu_stays_inside_the_screen(width):
    box = measure(width)
    assert box["hidden"] is False, "the menu opened"
    assert box["left"] >= 0, f"menu starts {box['left']}px off the left edge at {width}px"
    assert box["right"] <= box["width"], f"menu ends past the right edge at {width}px"


def test_a_long_menu_scrolls_instead_of_running_off_the_bottom():
    box = measure(390, folders=20)
    assert box["bottom"] <= box["height"] + 1 or box["scrollable"] in ("auto", "scroll"), box
    assert box["left"] >= 0
