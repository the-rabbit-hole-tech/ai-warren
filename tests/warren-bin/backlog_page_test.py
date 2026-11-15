#!/usr/bin/env python3
"""Tests for backlog-page.py: run by backlog-page.test.sh (stdlib only).

Needs the hand-off site's _site/ (page.py, pagefile.py, schema.py); HANDOFF_SITE_SRC points at a folder holding
one.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(os.environ["BACKLOG_PAGE"])
SRC = Path(os.environ["HANDOFF_SITE_SRC"])


def run(*args):
    return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, check=False)


class BacklogPage(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.site = root / "site"
        (self.site / "backlog").mkdir(parents=True)
        shutil.copytree(SRC / "_site", self.site / "_site", ignore=shutil.ignore_patterns("__pycache__"))
        (self.site / "site.json").write_text(json.dumps({"owner": "Alice", "key_prefix": "ops:", "folders": [{"id": "backlog"}]}))
        self.json = root / "backlog.json"
        self.items = [
            {"n": 1, "title": "First", "context": "One <b>raw</b> & `code`.", "status": "open"},
            {"n": 2, "title": "Second", "context": "Two.", "status": "started"},
            {"n": 3, "title": "Third", "context": "Three.", "status": "open"},
            {"n": 4, "title": "Fourth", "context": "Four.", "status": "dropped"},
            {"n": 5, "title": "Fifth & <last>", "context": "Five.", "status": "done"},
        ]
        self.write_items()

    def tearDown(self):
        self.tmp.cleanup()

    def write_items(self):
        self.json.write_text(json.dumps(self.items))

    def build(self):
        r = run("--json", str(self.json), "--site", str(self.site))
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads((self.site / "backlog" / "board.json").read_text())

    def read(self):
        r = run("--json", str(self.json), "--site", str(self.site), "--read")
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout.splitlines()

    def answer(self, answers):
        code = ("import sys, json; sys.path.insert(0, sys.argv[1]); import pagefile; "
                "pagefile.save_answers(sys.argv[2], json.loads(sys.argv[3]), by='Alice')")
        subprocess.run([sys.executable, "-c", code, str(self.site / "_site"), str(self.site / "backlog" / "board.json"),
                        json.dumps(answers)], check=True)

    def submit(self, kind, ids):
        """What the site writes to the page when a Send this item or a confirmed Drop goes through."""
        code = ("import sys, json; sys.path.insert(0, sys.argv[1]); import pagefile; "
                "sub = pagefile.add_submission(sys.argv[2], {'kind': sys.argv[3], 'to': 'ops', 'items': json.loads(sys.argv[4]), "
                "'file': '5-x-{n}.json', **({'scope': 'item'} if sys.argv[3] == 'send' else {})}); "
                "pagefile.hold(sys.argv[2], sub['n']) if sys.argv[3] == 'send' else None")
        subprocess.run([sys.executable, "-c", code, str(self.site / "_site"), str(self.site / "backlog" / "board.json"), kind,
                        json.dumps(ids)], check=True)

    def board(self, doc):
        return [(it["id"], it["title"]) for it in doc["items"] if it.get("type") != "info"]

    def test_page_contract(self):
        doc = self.build()
        self.assertEqual((doc["schema"], doc["kind"], doc["title"]), ("handoff.page/v1", "backlog", "Backlog"))
        self.assertEqual(doc["options"], {"choices": [{"value": "start", "label": "Start"}, {"value": "hold", "label": "Hold"}],
                                          "default": "hold"})
        self.assertEqual(doc["summary"], "Start marks an item to go; press Send this item to send it. Hold is the default, and a comment "
                                         "with Hold asks for the item to be revised. Drop removes an item from the board for good.")
        self.assertNotRegex(json.dumps(doc), r"(?i)\bops\b|operator", "the board's own wording does not name OPS or the operator")
        self.assertIs(doc["droppable"], True)
        self.assertEqual(doc["status"], {"state": "needs-you", "note": "2 backlog items: pick Start or leave on Hold."})
        self.assertEqual(doc["items"][0]["body"], [{"p": "One <b>raw</b> & `code`."}])
        self.assertFalse((self.site / "ops" / "backlog.html").exists())

    def test_started_leaves_the_page_and_done_and_dropped_are_collapsed(self):
        doc = self.build()
        self.assertEqual(self.board(doc), [("b1", "Backlog 1: First"), ("b3", "Backlog 3: Third")])
        done = doc["items"][-1]
        self.assertEqual((done["id"], done["type"], done["title"]), ("completed", "info", "Completed (2)"))
        block = done["body"][0]["html"]
        self.assertTrue(block.startswith("<details>"))
        self.assertIn("Backlog 4: Fourth (dropped)", block)
        self.assertIn("Backlog 5: Fifth &amp; &lt;last&gt; (done)", block)
        self.assertNotIn("Second", json.dumps(doc))

    def test_no_completed_list_when_nothing_is_done(self):
        self.items = [it for it in self.items if it["status"] in ("open", "started")]
        self.write_items()
        self.assertEqual([it["id"] for it in self.build()["items"]], ["b1", "b3"])

    def test_ids_stable_and_picks_kept_when_items_added_or_dropped(self):
        self.build()
        self.answer({"b3": {"answer": "start", "note": "go"}})
        self.submit("send", ["b3"])
        self.items[0]["status"] = "dropped"
        self.items.insert(0, {"n": 18, "title": "New", "context": "New one.", "status": "open"})
        self.write_items()
        self.assertEqual(self.board(self.build()), [("b18", "Backlog 18: New"), ("b3", "Backlog 3: Third")])
        self.assertEqual(self.read(), ["Backlog 18: HOLD (default)", "Backlog 3: START | go"])

    def test_bad_status_fails(self):
        self.items[0]["status"] = "maybe"
        self.write_items()
        r = run("--json", str(self.json), "--site", str(self.site))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("maybe", r.stderr)

    def test_the_page_goes_to_backlog_board_by_default_and_can_be_pointed_elsewhere(self):
        self.build()
        self.assertTrue((self.site / "backlog" / "board.json").exists())
        self.assertFalse((self.site / "ops" / "backlog.json").exists())
        (self.site / "other").mkdir()
        r = run("--json", str(self.json), "--site", str(self.site), "--page", "other/list")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.site / "other" / "list.json").exists())
        env = dict(os.environ, WARREN_BACKLOG_PAGE="other/second")
        r = subprocess.run([sys.executable, str(SCRIPT), "--json", str(self.json), "--site", str(self.site)], env=env,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.site / "other" / "second.json").exists())

    def test_read_follows_the_page_override(self):
        self.build()
        self.answer({"b1": {"answer": "start", "note": ""}})
        self.submit("send", ["b1"])
        r = run("--json", str(self.json), "--site", str(self.site), "--page", "backlog/board", "--read")
        self.assertEqual(r.stdout.splitlines(), ["Backlog 1: START", "Backlog 3: HOLD (default)"])
        r = run("--json", str(self.json), "--site", str(self.site), "--page", "other/none", "--read")
        self.assertEqual(r.stdout.splitlines(), ["Backlog 1: HOLD (default)", "Backlog 3: HOLD (default)"], "no such page: all defaults")

    def test_read_without_a_page(self):
        self.assertEqual(self.read(), ["Backlog 1: HOLD (default)", "Backlog 3: HOLD (default)"])

    def test_read_with_answers(self):
        self.build()
        self.answer({"b1": {"answer": "start", "note": "go  now"}, "b3": {"answer": "", "note": "later please"}})
        self.submit("send", ["b1", "b3"])
        self.assertEqual(self.read(), ["Backlog 1: START | go now", "Backlog 3: HOLD | later please"],
                         "a sent item with no pick is a Hold the owner sent: no (default), and its comment")

    def test_a_sent_hold_reads_as_sent_with_or_without_a_comment(self):
        self.build()
        self.answer({"b1": {"answer": "hold", "note": ""}, "b3": {"answer": "hold", "note": "wait for the redesign"}})
        self.submit("send", ["b1", "b3"])
        self.assertEqual(self.read(), ["Backlog 1: HOLD (sent)", "Backlog 3: HOLD | wait for the redesign"])

    def test_a_sent_start_with_no_comment_is_just_start(self):
        self.build()
        self.answer({"b1": {"answer": "start", "note": ""}})
        self.submit("send", ["b1"])
        self.assertEqual(self.read(), ["Backlog 1: START", "Backlog 3: HOLD (default)"])

    def body_of(self, n, context):
        self.items = [{"n": n, "title": "T", "context": context, "status": "open"}]
        self.write_items()
        return self.build()["items"][0]["body"]

    def test_context_lines_become_separate_paragraphs(self):
        self.assertEqual(self.body_of(1, "First line.\nSecond line.\n\nThird after a blank."),
                         [{"p": "First line."}, {"p": "Second line."}, {"p": "Third after a blank."}])

    def test_dash_lines_become_one_bullet_list_and_a_new_list_after_a_paragraph(self):
        self.assertEqual(self.body_of(1, "Why it matters:\n- one\n- two\nIn between.\n- three"),
                         [{"p": "Why it matters:"}, {"list": ["one", "two"]}, {"p": "In between."}, {"list": ["three"]}])

    def test_a_bold_label_is_passed_through_for_the_page_to_draw(self):
        self.assertEqual(self.body_of(1, "**Why:** it blocks the release.\n- **Next:** pick a date"),
                         [{"p": "**Why:** it blocks the release."}, {"list": ["**Next:** pick a date"]}])

    def test_a_short_context_is_not_folded_and_a_missing_one_has_no_body(self):
        self.assertEqual(self.body_of(1, "Short.\nStill short."), [{"p": "Short."}, {"p": "Still short."}])
        self.items = [{"n": 1, "title": "T", "status": "open"}]
        self.write_items()
        self.assertNotIn("body", self.build()["items"][0])

    def test_a_long_context_shows_its_first_paragraph_and_folds_the_rest(self):
        rest = "A detail line that goes on for a while. " * 20
        body = self.body_of(1, "The summary line.\n" + rest.strip() + "\n- a bullet\n- another")
        self.assertEqual(body[0], {"p": "The summary line."})
        self.assertEqual(body[1], {"details": "Details", "body": [{"p": rest.strip()}, {"list": ["a bullet", "another"]}]})
        self.assertEqual(len(body), 2)

    def test_a_long_context_with_nothing_to_fold_stays_whole(self):
        one = "word " * 200
        self.assertEqual(self.body_of(1, one.strip()), [{"p": one.strip()}])
        self.assertEqual(self.body_of(1, "- " + one.strip() + "\n- two")[0:1], [{"list": [one.strip(), "two"]}], "a list first: nothing to use as a summary")

    def test_rendering_the_context_keeps_ids_picks_and_what_read_prints(self):
        self.build()
        self.answer({"b1": {"answer": "start", "note": "go"}})
        self.submit("send", ["b1"])
        self.items[0]["context"] = "Now\n- in\n- blocks"
        self.write_items()
        doc = self.build()
        self.assertEqual([i["id"] for i in doc["items"] if i["id"].startswith("b")], ["b1", "b3"])
        self.assertEqual(self.read(), ["Backlog 1: START | go", "Backlog 3: HOLD (default)"])

    def test_a_mark_that_was_not_sent_reads_as_the_default(self):
        self.build()
        self.answer({"b1": {"answer": "start", "note": "not yet"}, "b3": {"answer": "start", "note": "go"}})
        self.submit("send", ["b3"])
        self.assertEqual(self.read(), ["Backlog 1: HOLD (default)", "Backlog 3: START | go"])

    def test_a_drop_the_owner_asked_for_is_read_until_it_is_answered(self):
        self.build()
        self.submit("drop", ["b1"])
        self.assertEqual(self.read(), ["Backlog 1: HOLD (default)", "Backlog 1: DROP requested", "Backlog 3: HOLD (default)"])
        self.items[0]["status"] = "dropped"
        self.write_items()
        self.build()
        self.assertEqual(self.read(), ["Backlog 3: HOLD (default)"], "applied: the item is off the board and the request goes with it")


if __name__ == "__main__":
    unittest.main(verbosity=2)
