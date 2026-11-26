#!/usr/bin/env python3
"""The one writer for handoff.page/v1 page files.

Every write takes an exclusive flock on <slug>.json.lock, reads the file, changes it, validates the result with
schema.py, writes a temp file and renames it into place, so the browser and an agent never clobber each other.
Rounds, revs, reply numbers and submissions all count from 1.

    from pagefile import write_definition, save_answers, new_round, restart, reply, set_route, load, item_states
"""
import contextlib
import fcntl
import hashlib
import json
import os
import re
import tempfile
from datetime import datetime

from schema import DEFAULT_TYPE, SCHEMA, TYPE_ANSWERS, validate

MAX_BYTES = 2 * 1024 * 1024
SERVER_KEYS = ("rev", "rounds", "thread", "submissions", "route", "emails", "revisions")
DEFINITION_KEYS = ("schema", "kind", "title", "summary", "build", "reset", "status", "options", "items", "phases", "drafts", "deck",
                   "template", "droppable", "skippable", "gate", "answers")
DONE = ("yes", "risk")
DEPENDENCY_MET = ("yes", "changes", "risk")
JOURNEY_ANSWERS = ("yes", "changes")


class PageError(Exception):
    def __init__(self, errors):
        self.errors = [errors] if isinstance(errors, str) else list(errors)
        super().__init__("; ".join(self.errors))


class LockedError(PageError):
    """An answer change on an item whose Yes the reviewer confirmed and locked; it answers 409, not 400."""


def _at(iso):
    return datetime.fromisoformat(iso)


def now_iso():
    return datetime.now().astimezone().isoformat(timespec="seconds")


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def item_hash(item):
    return hashlib.sha256(json.dumps(item, sort_keys=True, separators=(",", ":")).encode()).hexdigest()[:16]


def item_type(doc, item):
    return item.get("type", DEFAULT_TYPE[doc["kind"]])


def _default_answers(doc, typ):
    """What an item of this type takes when it names no answers. A journey step takes OK and CHANGE (stored as yes and
    changes), or the page's own answers list."""
    if doc["kind"] == "journey" and typ == "step":
        return doc.get("answers") or JOURNEY_ANSWERS
    return TYPE_ANSWERS[typ]


def _previous_step(doc, typ, prev_step):
    """The step a step waits on: the one before it, only on a page with gate: true. Otherwise none, so steps are answered in any order."""
    return [prev_step] if typ == "step" and prev_step and doc.get("gate") else []


def allowed_answers(doc, item):
    """The answers an item takes: a tuple of values, None for free text, or () when it isn't answerable."""
    typ = item_type(doc, item)
    if typ == "question":
        return None
    if typ == "info":
        return ()
    if typ == "choice":
        return tuple(c["value"] for c in item.get("choices") or doc["options"]["choices"])
    base = tuple(item.get("answers") or _default_answers(doc, typ))
    if item.get("skip") and "skipped" not in base:
        base += ("skipped",)
    if doc["kind"] == "round" and not item.get("answers"):
        base += ("risk",)
    return base


def _choice_problem(item, values, answer, other):
    """Why an answer doesn't fit an item's own choices: other is the built-in Other, a pick list is comma-joined."""
    picks = [p for p in answer.split(",") if p]
    bad = [p for p in picks if p not in values and p != "other"]
    if bad:
        return "expected one of " + ", ".join(values) + " or other"
    if len(picks) > 1 and not item.get("multi"):
        return "this takes one pick"
    if "other" in picks and not other.strip():
        return "Other needs its text"
    return None


@contextlib.contextmanager
def _locked(path):
    path = os.fspath(path)
    with open(path + ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield path
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def _commit(path, doc):
    errors = validate(doc)
    if errors:
        raise PageError(errors)
    doc["rev"] = doc.get("rev", 0) + 1
    data = json.dumps(doc, indent=2, ensure_ascii=False).encode() + b"\n"
    if len(data) > MAX_BYTES:
        raise PageError(f"page file would be {len(data)} bytes; the cap is {MAX_BYTES}")
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix="." + os.path.basename(path), suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise
    return doc["rev"]


def dropping_items(doc):
    """Items with a Drop the reviewer asked for that nobody has answered yet: the last kind-drop submission that carried the
    item (and reached the inbox), with no reply under the item since. The operator answers by removing the item from the
    page, or by replying under it."""
    ids = {it["id"] for it in doc["items"]}
    out = {}
    for s in doc["submissions"]:
        if s["kind"] != "drop" or s.get("state") == "failed":
            continue
        for iid in s["items"]:
            if iid in ids:
                out[iid] = s["at"]
    return {iid for iid, at in out.items() if not any(_at(r["at"]) > _at(at) for r in doc["thread"].get(iid, []))}


def sent_answer(doc, iid):
    """The answer for an item that its last Send carried in the open round (a Send the reviewer has not taken back), or None.
    A mark made after that Send is not the sent pick: it counts only once it is sent. This is what the operator acts on."""
    cur = doc["rounds"][-1]
    sends = [s for s in doc["submissions"] if s["kind"] == "send" and s["round"] == cur["round"] and s.get("state") != "failed"
             and not s.get("released") and iid in s["items"]]
    entry = cur["answers"].get(iid)
    if not sends or not entry:
        return None
    at = _at(sends[-1]["at"])
    for a in [entry, *reversed(entry.get("was", []))]:
        if "at" in a and _at(a["at"]) <= at:
            return a
    return None


def fixing_of(doc):
    """{item id: text} for the items marked fix in progress that still exist."""
    ids = {it["id"] for it in doc["items"]}
    return {k: t for k, t in (doc.get("fixing") or {}).items() if k in ids and isinstance(t, str) and t.strip()}


def set_fixing(path, item_id, text, *, now=None):
    """Mark an item as having a fix in progress (say what, like a bug log number). It takes no answer until cleared. The mark
    lives beside the definition, so it changes neither the item's hash nor its answers. Returns the rev."""
    text = str(text or "").strip()
    with _locked(path) as p:
        doc = load(p)
        item = _items_by_id(doc).get(item_id)
        if item is None:
            raise PageError(f"{item_id}: no item {item_id} on this page")
        if allowed_answers(doc, item) == ():
            raise PageError(f"{item_id}: this item takes no answer, so it can't have a fix in progress")
        if not text:
            raise PageError(f"{item_id}: say what the fix is, like a bug log number")
        doc.setdefault("fixing", {})[item_id] = text
        return _commit(p, doc)


def clear_fixing(path, item_id):
    """Take the fix-in-progress mark off an item; it is open again. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        if item_id not in (doc.get("fixing") or {}):
            raise PageError(f"{item_id}: no fix is marked in progress on this item")
        del doc["fixing"][item_id]
        if not doc["fixing"]:
            del doc["fixing"]
        return _commit(p, doc)


def _round(n, build, reset, at, opened_by):
    return {"round": n, "build": build, "reset": reset, "opened": at, "closed": None, "openedBy": opened_by,
            "answers": {}, "checkpoints": {}, "reopened": {}}


def _open_next(doc, at, opened_by, results=None):
    cur = doc["rounds"][-1]
    cur["closed"] = at
    if results is not None:
        cur["results"] = results
    nxt = _round(cur["round"] + 1, doc.get("build"), doc.get("reset"), at, opened_by)
    # A reopen nobody has answered yet stays open in the next round.
    nxt["reopened"] = {k: v for k, v in cur.get("reopened", {}).items() if k not in cur["answers"]}
    doc["rounds"].append(nxt)
    return nxt


def _items_by_id(doc):
    return {it["id"]: it for it in doc["items"]}


def _held_sends(rnd):
    return rnd.get("held") or ([rnd["awaiting"]] if "awaiting" in rnd else [])


def held_items(doc):
    """The items Sends carried that wait on the agent. Every other item stays open to answer."""
    subs = doc["submissions"]
    return {iid for n in _held_sends(doc["rounds"][-1]) for iid in subs[n - 1]["items"]}


def _clear_hold(rnd):
    rnd.pop("awaiting", None)
    rnd.pop("held", None)


def _open_blocker(doc, rnd, iid):
    """The Blocker on this item in the open round that the agent hasn't dealt with yet, if any."""
    return next((s for s in reversed(doc["submissions"]) if s["kind"] == "blocker" and s["round"] == rnd["round"]
                 and iid in s["items"] and s.get("state") != "failed" and not s.get("handled")), None)


def _release(doc, rnd, items=()):
    """The agent updated the page: unlock every page Send, and an item Send only when its own item is in items."""
    subs = doc["submissions"]
    keep = [n for n in _held_sends(rnd) if subs[n - 1].get("scope") == "item" and subs[n - 1]["items"][0] not in items]
    _clear_hold(rnd)
    if keep:
        rnd["held"] = keep
        rnd["awaiting"] = keep[-1]


def _settle(doc, iid, at, via):
    """A sent No or Changes, or a Blocker, the agent dealt with leaves the open answers for good, so its note
    can't be sent again. A dealt-with Blocker also stops flagging the item."""
    rnd = doc["rounds"][-1]
    entry = rnd["answers"].get(iid)
    blocker = _open_blocker(doc, rnd, iid)
    if blocker is not None:
        blocker["handled"] = at
    carried = entry and blocker is not None and _at(entry["at"]) <= _at(blocker["at"])
    if not entry or not carried and (entry["answer"] not in ("no", "changes") or not _sent(doc, rnd, iid, entry)):
        return
    del rnd["answers"][iid]
    kept = {k: entry[k] for k in ("answer", "note", "by", "at") if k in entry}
    if carried:
        kept["blocker"] = True
    rnd.setdefault("handled", {}).setdefault(iid, []).append({**kept, "handled": at, "via": via})


def write_definition(path, definition, *, now=None):
    """Create the page, or replace its definition. A build or reset change opens a new round. Returns the rev."""
    refused = [f"{k}: written by the server, not the definition" for k in SERVER_KEYS if k in definition]
    if refused:
        raise PageError(refused)
    at = now or now_iso()
    with _locked(path) as p:
        if os.path.exists(p):
            doc = load(p)
            old_build, old_reset = doc.get("build"), doc.get("reset")
            old_items = {it["id"]: it for it in doc["items"]}
            for k in DEFINITION_KEYS:
                doc.pop(k, None)
            doc.update(definition)
            if doc.get("fixing"):
                kept = fixing_of(doc)
                if kept:
                    doc["fixing"] = kept
                else:
                    del doc["fixing"]
            changed = [it["id"] for it in doc["items"] if it["id"] in old_items and item_hash(old_items[it["id"]]) != item_hash(it)]
            _release(doc, doc["rounds"][-1], changed)
            for it in doc["items"]:
                old = old_items.get(it["id"])
                if old is not None and item_hash(old) != item_hash(it):
                    _settle(doc, it["id"], at, "definition")
                    doc.setdefault("revisions", {}).setdefault(it["id"], []).append(
                        {"at": at, "round": doc["rounds"][-1]["round"], "before": old, "after": it})
            if doc.get("build") != old_build:
                _open_next(doc, at, "build changed")
            elif doc.get("reset") != old_reset:
                _open_next(doc, at, "reset")
        else:
            doc = dict(definition)
            doc.setdefault("schema", SCHEMA)
            doc["rev"] = 0
            doc["rounds"] = [_round(1, doc.get("build"), doc.get("reset"), at, "created")]
            doc["thread"] = {}
            doc["submissions"] = []
        return _commit(p, doc)


def set_route(path, to, mode):
    """The operator's per-page route. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        doc["route"] = {"to": to, "mode": mode}
        return _commit(p, doc)


def save_answers(path, answers, *, by, base=None, now=None):
    """Merge one tab's changed answers ({id: {answer, note}}) into the open round, item by item.

    base is the rev the tab last saw. A stale base is fine: only the items this tab sent are laid over the file.
    Returns the rev.
    """
    at = now or now_iso()
    with _locked(path) as p:
        doc = load(p)
        items = _items_by_id(doc)
        rnd = doc["rounds"][-1]
        held = held_items(doc)
        fixing = fixing_of(doc)
        dropping = dropping_items(doc)
        states_now = item_states(doc) if doc.get("skippable") else {}
        errors = []
        refused = False
        changed = False
        for iid, new in answers.items():
            item = items.get(iid)
            if item is None:
                errors.append(f"{iid}: no item {iid} on this page")
                continue
            if iid in held:
                errors.append(f"{iid}: this was sent; unlock it, or wait for the update, to change the answer")
                continue
            if iid in dropping:
                errors.append(f"{iid}: a drop is requested for it, so it takes no pick until the operator answers")
                continue
            if iid in fixing:
                errors.append(f"{iid}: fix in progress ({fixing[iid]}); it takes no answer until the fix is cleared")
                continue
            answer, note, other = str(new.get("answer", "")), str(new.get("note", "")), str(new.get("other", ""))
            old = rnd["answers"].get(iid)
            skipped = bool(old and old.get("skipped"))
            if "skipped" in new:
                if not isinstance(new["skipped"], bool):
                    errors.append(f"{iid}: skipped expected true or false")
                    continue
                if new["skipped"] and not (doc.get("skippable") and item_type(doc, item) == "question"):
                    errors.append(f"{iid}: only a question on a skippable page can be skipped")
                    continue
                skipped = new["skipped"]
            if skipped and old and old.get("skipped") and answer != old["answer"]:
                errors.append(f"{iid}: this question is skipped; un-skip to change the answer")
                continue
            # An un-skip is written even when the item was skipped in an earlier round, so it overrides that look-back.
            unskip = "skipped" in new and not skipped and (bool(old and old.get("skipped")) or bool(states_now.get(iid, {}).get("skipped")))
            was_locked = bool(old and old.get("locked"))
            if was_locked and answer != old["answer"]:
                errors.append(f"{iid}: this Yes is confirmed and locked; Reopen it with a reason to change the answer")
                refused = True
                continue
            lock = was_locked or bool(new.get("locked"))
            if lock and not was_locked and (answer != "yes" or item_type(doc, item) in ("question", "choice")):
                errors.append(f"{iid}: only a Yes can be confirmed and locked")
                continue
            ok = allowed_answers(doc, item)
            if item.get("choices"):
                problem = _choice_problem(item, ok, answer, other)
                if problem:
                    errors.append(f"{iid}: {problem}")
                    continue
                ok = None
            if ok == ():
                errors.append(f"{iid}: this item takes no answer")
                continue
            if ok is not None and answer and answer not in ok:
                errors.append(f"{iid}: expected one of " + ", ".join(ok))
                continue
            if answer == "changes" and not note.strip():
                errors.append(f"{iid}: Changes needs a note")
                continue
            if answer == "risk" and not note.strip():
                errors.append(f"{iid}: Accept risk needs a note on how the risk is presented")
                continue
            if old is None and not answer and not note.strip() and not skipped and not unskip:
                continue
            # The same Yes again is still news on a reopened or changed item: it clears the reopen.
            current = iid not in rnd.get("reopened", {}) and (old or {}).get("hash") in (None, item_hash(item))
            if current and old is not None and old["answer"] == answer and old.get("note", "") == note and old.get("other", "") == other \
                    and bool(old.get("locked")) == lock and bool(old.get("skipped")) == skipped and not unskip:
                continue
            entry = {"answer": answer, "note": note, "by": by, "at": at, "hash": item_hash(item)}
            if skipped:
                entry["skipped"] = True
            elif unskip or (old and "skipped" in old):
                entry["skipped"] = False
            if lock:
                entry["locked"] = True
            if other:
                entry["other"] = other
            if old is not None:
                entry["was"] = old.get("was", []) + [{k: old[k] for k in ("answer", "note", "by", "at", "skipped") if k in old}]
            rnd["answers"][iid] = entry
            rnd.get("reopened", {}).pop(iid, None)
            if answer == "yes" and item.get("checkpoint"):
                rnd.setdefault("checkpoints", {}).setdefault(item["checkpoint"], at)
            changed = True
        if errors:
            raise (LockedError if refused else PageError)(errors)
        return _commit(p, doc) if changed else doc["rev"]


def reopen(path, item_id, reason, *, by, now=None):
    """The reviewer takes the lock off a confirmed Yes. The reason is required; it is kept as the item's reopen reason and as an
    entry in its thread. This is the reviewer's own act, so unlike reply() it settles and releases nothing. Returns the rev."""
    at = now or now_iso()
    reason = str(reason or "").strip()
    with _locked(path) as p:
        doc = load(p)
        if item_id not in _items_by_id(doc):
            raise PageError(f"{item_id}: no item {item_id} on this page")
        rnd = doc["rounds"][-1]
        entry = rnd["answers"].get(item_id)
        if not entry or not entry.get("locked"):
            raise PageError(f"{item_id}: this item is not confirmed and locked")
        if not reason:
            raise PageError(f"{item_id}: say why you are reopening it")
        del entry["locked"]
        rnd.setdefault("reopened", {})[item_id] = reason
        replies = doc["thread"].setdefault(item_id, [])
        replies.append({"n": len(replies) + 1, "from": by, "at": at, "round": rnd["round"], "text": reason,
                        "action": "reopen", "reason": reason})
        return _commit(p, doc)


def new_round(path, *, opened_by="saved", results=None, now=None):
    """Save round now: close the open round, keeping its Copy results text, and open the next. Returns its number."""
    with _locked(path) as p:
        doc = load(p)
        nxt = _open_next(doc, now or now_iso(), opened_by, results)
        _commit(p, doc)
        return nxt["round"]


def restart(path, checkpoint, *, by, results=None, now=None):
    """Restart a journey from a checkpoint reached in any round: the steps up to it carry over as Yes."""
    at = now or now_iso()
    with _locked(path) as p:
        doc = load(p)
        reached = {}
        for r in doc["rounds"]:
            for cp, t in r.get("checkpoints", {}).items():
                reached.setdefault(cp, t)
        upto = next((n for n, it in enumerate(doc["items"]) if it.get("checkpoint") == checkpoint), None)
        if checkpoint not in reached or upto is None:
            raise PageError(f"checkpoint {checkpoint}: not reached yet")
        keep = {it.get("checkpoint") for it in doc["items"][: upto + 1]} - {None}
        nxt = _open_next(doc, at, f"restart from {checkpoint}", results)
        nxt["restart"] = checkpoint
        nxt["reopened"] = {}
        nxt["checkpoints"] = {cp: t for cp, t in reached.items() if cp in keep}
        for it in doc["items"][: upto + 1]:
            if allowed_answers(doc, it):
                nxt["answers"][it["id"]] = {"answer": "yes", "note": "", "by": by, "at": at, "hash": item_hash(it)}
        _commit(p, doc)
        return nxt["round"]


def reply(path, item_id, frm, text, *, action=None, reason=None, ref=None, now=None):
    """Append a reply under an item (or "_page"). A reopen action reopens the item. Returns the reply number."""
    at = now or now_iso()
    with _locked(path) as p:
        doc = load(p)
        if item_id != "_page" and item_id not in _items_by_id(doc):
            raise PageError(f"{item_id}: no item {item_id} on this page")
        rnd = doc["rounds"][-1]
        _release(doc, rnd, [item_id])
        replies = doc["thread"].setdefault(item_id, [])
        entry = {"n": len(replies) + 1, "from": frm, "at": at, "round": rnd["round"], "text": text}
        for k, val in (("action", action), ("reason", reason), ("ref", ref)):
            if val is not None:
                entry[k] = val
        replies.append(entry)
        if item_id != "_page":
            _settle(doc, item_id, at, "reply")
        if action == "reopen" and item_id != "_page":
            rnd.setdefault("reopened", {})[item_id] = reason or text
        _commit(p, doc)
        return entry["n"]


def add_email(path, item_id, frm, subject, body, *, to=None, request=None, now=None):
    """A draft came back: the next version on its item, with what produced it. Nothing locks or unlocks. Returns its number."""
    at = now or now_iso()
    with _locked(path) as p:
        doc = load(p)
        if item_id not in _items_by_id(doc):
            raise PageError(f"{item_id}: no item {item_id} on this page")
        versions = doc.setdefault("emails", {}).setdefault(item_id, [])
        entry = {"n": len(versions) + 1, "at": at, "from": frm, "body": body}
        asked = doc["submissions"][request - 1] if request is not None else {}
        for k, val in (("subject", subject), ("to", to or asked.get("recipient")), ("request", request)):
            if val is not None:
                entry[k] = val
        for k in ("ask", "tone", "change", "basedOn"):
            if k in asked:
                entry[k] = asked[k]
        versions.append(entry)
        _commit(p, doc)
        return entry["n"]


def import_rounds(path, rounds):
    """Replace a new page's empty round 1 with converted history plus the open round. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        if doc["rev"] != 1 or len(doc["rounds"]) != 1 or doc["rounds"][0]["answers"]:
            raise PageError("rounds can only be imported into a new page")
        doc["rounds"] = rounds
        return _commit(p, doc)


def set_status(path, state, *, note=None, chips=None, priority=None):
    """The page's index card. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        st = {"state": state}
        for k, val in (("note", note), ("chips", chips), ("priority", priority)):
            if val is not None:
                st[k] = val
        doc["status"] = st
        return _commit(p, doc)


def add_submission(path, record, *, now=None):
    """Record a Send, Blocker or Restart on the page. Returns the stored record, numbered from 1.

    record["file"] may hold "{n}", filled with the submission's number under the lock.
    """
    with _locked(path) as p:
        doc = load(p)
        n = len(doc["submissions"]) + 1
        sub = {"n": n, "kind": record["kind"], "at": now or now_iso(), "to": record["to"],
               "round": doc["rounds"][-1]["round"], "rev": doc["rev"], "items": list(record.get("items", [])),
               "file": record["file"].replace("{n}", str(n)), "state": "sent"}
        for k in ("scope", "recipient", "ask", "tone", "change", "basedOn", "framing"):
            if record.get(k):
                sub[k] = record[k]
        doc["submissions"].append(sub)
        _commit(p, doc)
        return sub


def hold(path, n):
    """Submission n reached the inbox: lock its items until the agent's next update or an unlock. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        rnd = doc["rounds"][-1]
        rnd["held"] = _held_sends(rnd) + [n]
        rnd["awaiting"] = n
        return _commit(p, doc)


def release(path):
    """Unlock a held page without waiting for the agent: that Send no longer settles anything. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        rnd = doc["rounds"][-1]
        for n in _held_sends(rnd):
            doc["submissions"][n - 1]["released"] = True
        _clear_hold(rnd)
        return _commit(p, doc)


def mark_undelivered(path, n):
    """Submission n never reached the inbox. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        doc["submissions"][n - 1]["state"] = "failed"
        return _commit(p, doc)


def mark_taken(path, n, *, at=None):
    """An agent took submission n from its inbox. Returns the rev."""
    with _locked(path) as p:
        doc = load(p)
        sub = doc["submissions"][n - 1]
        if sub.get("state") == "taken":
            return doc["rev"]
        sub["state"] = "taken"
        sub["takenAt"] = at or now_iso()
        return _commit(p, doc)


def _sent(doc, cur, iid, answer, *, answered=False):
    """Did a Send in the open round carry this answer? With answered, only a Send the agent has since dealt with."""
    held = set(_held_sends(cur)) if answered else set()
    return any(s["kind"] == "send" and s["round"] == cur["round"] and s.get("state") != "failed" and not s.get("released")
               and iid in s["items"] and _at(answer["at"]) <= _at(s["at"]) and s["n"] not in held for s in doc["submissions"])


def _settles(item, typ, answer, skipped=False):
    """An answer that locks once it's gone back: a Yes or Accept risk, any answered or skipped question, an item's own pick."""
    return bool(answer or skipped) and (answer in DONE and typ != "question" or typ == "question" or bool(item.get("choices")))


def item_states(doc):
    """Where each answerable item stands in the open round.

    {id: {"answer", "hidden", "reopened", "round"}}, plus "locked": true on a Yes the reviewer confirmed in the open
    round; a Yes from an earlier round, or one a Send carried once the
    agent has updated the page, is hidden; a reopen, or a definition change since the item's last Yes, makes it
    open again with the reason.
    """
    items = [it for it in doc["items"] if allowed_answers(doc, it) != ()]
    rounds = doc["rounds"]
    cur = rounds[-1]
    fixing = fixing_of(doc)
    dropping = dropping_items(doc)
    out = {}
    for it in items:
        iid, h, typ = it["id"], item_hash(it), item_type(doc, it)
        state = {"answer": "", "hidden": False, "reopened": cur.get("reopened", {}).get(iid), "round": None}
        mine = cur["answers"].get(iid)
        # A skipped question counts as given even with no text; an entry that says "skipped": false is an un-skip, which
        # also cancels a skip from an earlier round.
        if mine and (mine["answer"] or mine.get("skipped")):
            sk = bool(mine.get("skipped"))
            if _settles(it, typ, mine["answer"], sk) and mine.get("hash") not in (None, h):
                state["reopened"] = f"changed since round {cur['round']}"
            elif state["reopened"] is None:
                state.update(answer=mine["answer"], round=cur["round"])
                if sk:
                    state["skipped"] = True
                if mine.get("locked"):
                    state["locked"] = True
                state["hidden"] = _settles(it, typ, mine["answer"], sk) and _sent(doc, cur, iid, mine, answered=True)
        elif (state["reopened"] is None and not (mine and "skipped" in mine) and not cur.get("restart")
              and iid not in cur.get("handled", {})):
            for r in reversed(rounds[:-1]):
                if iid in r.get("handled", {}):
                    break
                a = r["answers"].get(iid)
                if a and (a["answer"] or "skipped" in a):
                    sk = bool(a.get("skipped"))
                    if _settles(it, typ, a["answer"], sk):
                        if a.get("hash") not in (None, h):
                            state["reopened"] = f"changed since round {r['round']}"
                        else:
                            state.update(answer=a["answer"], hidden=True, round=r["round"])
                            if sk:
                                state["skipped"] = True
                    break
                if r.get("restart"):
                    break
        if iid in fixing:
            state["fixing"] = fixing[iid]
        if iid in dropping:
            state["dropping"] = True
        out[iid] = state
    return out


def email_context(doc, item_id):
    """What an agent needs to write an email about a step, so the person doesn't retype it."""
    it = _items_by_id(doc)[item_id]
    comments = []
    for r in doc["rounds"]:
        entries = [r["answers"][item_id]] if item_id in r["answers"] else []
        entries += r.get("handled", {}).get(item_id, [])
        comments += [{"round": r["round"], "answer": e.get("answer", ""), "note": e["note"]} for e in entries if e.get("note")]
    answer = item_states(doc).get(item_id, {}).get("answer", "")
    return {"id": item_id, "title": it["title"], "body": it.get("body", []), "answer": answer,
            "changed": doc.get("revisions", {}).get(item_id, []), "comments": comments, "replies": doc["thread"].get(item_id, [])}


def deck_items(doc):
    """What a deck is built from: the items whose final answer is Yes or Accept risk, in page order."""
    states = item_states(doc)
    out = []
    for it in doc["items"]:
        st = states.get(it["id"])
        if st and st["answer"] in DONE and not st["reopened"]:
            answer = next((r["answers"][it["id"]] for r in reversed(doc["rounds"]) if it["id"] in r["answers"]), {})
            out.append({"id": it["id"], "title": it["title"], "body": it.get("body", []),
                        "answer": st["answer"], "note": answer.get("note", "")})
    return out


def phase_of(iid):
    return re.match(r"[A-Z]+", iid).group()


def phase_states(doc):
    """{phase id: {"items", "closed", "blocked"}}: closed once every counted item is Yes, Accept risk or Skipped."""
    states = item_states(doc)
    out = {}
    for ph in doc.get("phases") or []:
        items = [it["id"] for it in doc["items"] if phase_of(it["id"]) == ph["id"]]
        by_id = _items_by_id(doc)
        counted = [i for i in items if i in states and item_type(doc, by_id[i]) != "question"]
        settled = [i for i in counted if states[i]["answer"] in DONE + ("skipped",) or (by_id[i].get("choices") and states[i]["answer"])]
        out[ph["id"]] = {"items": items, "closed": len(settled) == len(counted), "blocked": None}
    for ph in doc.get("phases") or []:
        out[ph["id"]]["blocked"] = next((d for d in ph.get("dependsOn", []) if not _met(d, states, out)), None)
    return out


def _met(dep, states, phases):
    return phases[dep]["closed"] if dep in phases else states.get(dep, {}).get("answer") in DEPENDENCY_MET


def _unblocked(doc, iid):
    return any(r.get("action") == "unblock" for r in doc["thread"].get(iid, []))


def blocked_items(doc):
    """Items that can't be answered yet: a dependsOn item isn't answered Yes, Changes or Accept risk (a journey
    step depends on the one before it only on a page with gate: true), its phase waits on another, or its blockedBy
    hasn't had an unblock reply."""
    states, phases = item_states(doc), phase_states(doc)
    out, prev_step = set(fixing_of(doc)), None
    for it in doc["items"]:
        typ = item_type(doc, it)
        if typ in ("info", "question", "choice"):
            continue
        deps = it.get("dependsOn")
        if deps is None:
            deps = _previous_step(doc, typ, prev_step)
        if typ == "step":
            prev_step = it["id"]
        phase = phases.get(phase_of(it["id"])) if phases else None
        if (it.get("blockedBy") and not _unblocked(doc, it["id"])) or not all(
                _met(d, states, phases) for d in deps) or (phase and phase["blocked"]):
            out.add(it["id"])
    return out


def summary(doc):
    """The bar's counts for the open round: what's open, blocked, Yes and reopened, and a backlog's tally.

    An item is blocked while a dependsOn item isn't answered Yes, Changes or Accept risk (a journey step depends on the
    one before it only on a page with gate: true) or while its blockedBy hasn't had an unblock reply. An item marked fix in progress is
    counted in "fixing" (only
    present when something is marked) instead of open or blocked: it isn't awaiting the reviewer, and it keeps the page from approved.
    """
    states = item_states(doc)
    phases = phase_states(doc)
    fixing = fixing_of(doc)
    out = {"open": 0, "blocked": 0, "counted": 0, "yes": 0, "reopened": 0, "approved": False, "tally": None}
    choices = doc.get("options") or {}
    tally = {c["value"]: 0 for c in choices.get("choices", [])}
    prev_step = None
    for it in doc["items"]:
        typ = item_type(doc, it)
        if typ == "info":
            continue
        st = states[it["id"]]
        if typ == "choice" and it.get("choices"):
            out["counted"] += 1
            out["yes" if st["answer"] else "open"] += 1
            continue
        if typ == "choice":
            pick = st["answer"] or choices.get("default", "")
            if pick in tally:
                tally[pick] += 1
            continue
        deps = it.get("dependsOn")
        if deps is None:
            deps = _previous_step(doc, typ, prev_step)
        if typ == "step":
            prev_step = it["id"]
        if typ == "question":
            if st.get("skipped"):
                out["skipped"] = out.get("skipped", 0) + 1
            continue
        out["counted"] += 1
        if it["id"] in fixing:
            out["fixing"] = out.get("fixing", 0) + 1
            continue
        if st["reopened"]:
            out["reopened"] += 1
        phase = phases.get(phase_of(it["id"])) if phases else None
        blocked = (it.get("blockedBy") and not _unblocked(doc, it["id"])) or not all(
            _met(d, states, phases) for d in deps) or (phase and phase["blocked"])
        if blocked:
            out["blocked"] += 1
        elif st["answer"] in DONE:
            out["yes"] += 1
        elif st["answer"] == "skipped":
            pass
        elif not st["answer"] or st["reopened"]:
            out["open"] += 1
    if tally:
        out["tally"] = tally
    out["approved"] = out["counted"] > 0 and out["yes"] == out["counted"]
    return out
