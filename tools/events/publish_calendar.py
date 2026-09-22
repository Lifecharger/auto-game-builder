"""Publish the yearly event calendar to the events bucket.

The calendar (`takvim.json` in the event package, see Hot Jigsaw design/events.md)
is the one file every game and both content workers read to know which event is
on. This tool validates it and puts it at `events/calendar.json` (bucket `events`) with the
cache standard's mutable-JSON header, then drops the same bytes into the local
bucket mirror so the mirror stays current without a full re-sync.

    python tools/events/publish_calendar.py                # default source
    python tools/events/publish_calendar.py --source path/to/takvim.json
    python tools/events/publish_calendar.py --check        # validate only

Validation: unique ids, month-day windows that parse, no two windows overlapping
(a window that crosses the year is checked on both sides), every event names a
collection and a deck.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "r2"))
import r2_s3  # noqa: E402

DEFAULT_SOURCE = Path.home() / "Desktop" / "etkinlik ve deste paketi" / "takvim.json"
BUCKET = "events"
KEY = "calendar.json"
CACHE_JSON = "public, max-age=21600, stale-while-revalidate=86400"
MIRROR = Path(r"D:/Reusable Assets/r2buckets") / BUCKET / KEY
PUBLIC_URL = f"https://events.lifechargergames.com/{KEY}"


def _md(s: str) -> tuple[int, int]:
    m, d = s.split("-")
    m, d = int(m), int(d)
    dt.date(2024, m, d)  # leap year so 02-29 is allowed
    return m, d


def _days(start: str, end: str, year: int = 2025) -> set:
    """Calendar days a window covers in a reference (non-leap) year."""
    sm, sd = _md(start)
    em, ed = _md(end)
    a = dt.date(year, sm, sd)
    b = dt.date(year + (1 if (em, ed) < (sm, sd) else 0), em, ed)
    out, cur = set(), a
    while cur <= b:
        out.add((cur.month, cur.day))
        cur += dt.timedelta(days=1)
    return out


def validate(cal: dict) -> list[str]:
    errors: list[str] = []
    events = cal.get("events")
    if not isinstance(events, list) or not events:
        return ["calendar has no events list"]
    seen: dict[str, tuple] = {}
    ids = set()
    for e in events:
        eid = e.get("id")
        if not eid or eid in ids:
            errors.append(f"duplicate or missing id: {eid!r}")
        ids.add(eid)
        for field in ("start", "end", "collection_id", "deck_id", "name_en"):
            if not e.get(field):
                errors.append(f"{eid}: missing {field}")
        try:
            days = _days(e["start"], e["end"])
        except Exception as ex:  # bad month-day
            errors.append(f"{eid}: bad window {e.get('start')}..{e.get('end')} ({ex})")
            continue
        kind = e.get("kind", "event")
        for other, (okind, odays) in seen.items():
            # Monthly events may not overlap each other and seasons may not
            # overlap each other; a monthly event inside a season is the design.
            if kind == okind and days & odays:
                errors.append(f"{eid} overlaps {other}")
        seen[eid] = (kind, days)
    seasons = [e for e in events if e.get("kind") == "season"]
    if seasons:
        covered = set()
        for e in seasons:
            try:
                covered |= _days(e["start"], e["end"])
            except Exception:
                pass
        if len(covered) != 365:
            errors.append(f"seasons cover {len(covered)} days, not the whole year")
    return errors


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=str(DEFAULT_SOURCE))
    ap.add_argument("--check", action="store_true", help="validate only, do not upload")
    args = ap.parse_args()

    src = Path(args.source)
    cal = json.loads(src.read_text(encoding="utf-8"))
    errors = validate(cal)
    if errors:
        sys.exit("calendar rejected:\n  " + "\n  ".join(errors))
    print(f"calendar ok: {len(cal['events'])} events")
    if args.check:
        return

    cal["publishedAt"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    body = json.dumps(cal, ensure_ascii=False, indent=1).encode("utf-8")
    r2_s3._call("PUT", BUCKET, KEY,
                headers={"content-type": "application/json; charset=utf-8", "cache-control": CACHE_JSON},
                body=body, timeout=120)
    head = r2_s3.head_object(BUCKET, KEY)
    print(f"uploaded {KEY}: {head['size']} bytes, cache-control '{head['cache_control']}'")
    MIRROR.parent.mkdir(parents=True, exist_ok=True)
    MIRROR.write_bytes(body)
    print(f"mirror -> {MIRROR}")
    print(f"public  -> {PUBLIC_URL}")


if __name__ == "__main__":
    main()
