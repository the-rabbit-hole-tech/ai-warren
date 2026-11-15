#!/usr/bin/env python3
"""The listeners switch: one server-side flag, in <site>/_saved/_listeners.json, that every tab, agent and hook reads.

While the listeners are paused, `page.py wait` and `page.py listen` deliver nothing and the inbox hook says nothing, so no
agent is woken and no tokens are spent; Send still saves its submission to the inbox, so nothing is lost. Turning the
listeners On (or a timed pause running out) lets the next poll deliver what queued, blockers first.

A timed pause ("until 06:00") stores an ISO time with its zone; once it has passed the listeners count as On.
Standard library only: serve.py, page.py and the hook all import this.
"""
import datetime as dt
import json
import os
import re
import tempfile

FILE = "_listeners.json"
CLOCK = re.compile(r"^([01][0-9]|2[0-3]):([0-5][0-9])$")


def path(root):
    return os.path.join(root, "_saved", FILE)


def _now():
    return dt.datetime.now(dt.timezone.utc)


def _read(root):
    try:
        with open(path(root), encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def status(root, now=None):
    """{"paused", "until", "at", "by"}. A damaged or missing file means On; a pause whose time has passed means On."""
    d = _read(root)
    off = {"paused": False, "until": None, "at": None, "by": None}
    if d.get("paused") is not True:
        return off
    until = d.get("until")
    if until:
        try:
            end = dt.datetime.fromisoformat(until)
            if end.tzinfo is None:
                end = end.replace(tzinfo=dt.timezone.utc)
        except (TypeError, ValueError):
            return off
        if (now or _now()) >= end:
            return off
    return {"paused": True, "until": until or None, "at": d.get("at"), "by": d.get("by")}


def paused(root, now=None):
    return status(root, now)["paused"]


def _write(root, obj):
    os.makedirs(os.path.dirname(path(root)), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path(root)), prefix=".listeners-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(obj, f)
        os.replace(tmp, path(root))
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def pause(root, until=None, by="owner", now=None):
    """Pause the listeners, for good or until a timezone-aware time. Returns the new status."""
    at = (now or _now()).isoformat(timespec="seconds")
    _write(root, {"paused": True, "until": until.isoformat(timespec="seconds") if until else None, "at": at, "by": by})
    return status(root, now)


def resume(root, by="owner", now=None):
    """Turn the listeners On. Returns the new status."""
    _write(root, {"paused": False, "until": None, "at": (now or _now()).isoformat(timespec="seconds"), "by": by})
    return status(root, now)


def until_clock(text, tz_name, now=None):
    """The next HH:MM in the site's zone (today if it is still ahead, else tomorrow), as an aware datetime."""
    if not isinstance(text, str) or not CLOCK.match(text):
        raise ValueError("until must be a time like 06:00")
    hour, minute = int(text[:2]), int(text[3:])
    try:
        from zoneinfo import ZoneInfo
        zone = ZoneInfo(tz_name or "UTC")
    except Exception:
        zone = dt.timezone.utc
    here = (now or _now()).astimezone(zone)
    end = here.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if end <= here:
        end += dt.timedelta(days=1)
    return end
