"""Timed release ("drip") of gallery-hot collections.

A collection can sit in the bucket long before players may see it. Its folder then carries
`collections/<id>/release.json` = {"releaseAt": "<ISO UTC>"}; the gallery-hot worker reads the
file on every bucket scan and drops the collection from EVERY manifest until that moment
(gallery-hot worker, src/release.js). Put the schedule BEFORE the pictures, so no
manifest built in between can list them.

    python tools/r2/publish_release.py rooftop_rain_noir 2026-10-15       # 00:00 UTC that day
    python tools/r2/publish_release.py --list                              # every scheduled collection
    python tools/r2/publish_release.py --check rooftop_rain_noir           # read back one schedule

The file gets the cache standard's mutable-JSON header and the same bytes go to the local bucket
mirror (<r2.mirror_root>/gallery-hot/...). Credentials: the R2 token file named by
r2.credentials_file (via r2_s3). Machine paths come from the environment first, then
server/config/settings.json (git-ignored), as in tools/character/common.py:
  r2.mirror_root        R2_MIRROR_ROOT        local bucket mirror root (mirror_buckets.py --root)
  r2.credentials_file   R2_CREDENTIALS_FILE   R2 S3 credentials json (kept outside the repo)
To move a date, publish again; to release now, publish today's date (the manifest follows on
its next rebuild, within the 6 h base-cache window).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import r2_s3  # noqa: E402

SETTINGS = HERE.parent.parent / "server" / "config" / "settings.json"


def setting(key: str, env: str = "", default: str = "") -> str:
    """Dotted key from settings.json; a non-empty environment variable wins."""
    if env:
        v = os.environ.get(env, "").strip()
        if v:
            return v
    if SETTINGS.is_file():
        d = json.loads(SETTINGS.read_text(encoding="utf-8")) or {}
        for part in key.split("."):
            d = d.get(part) if isinstance(d, dict) else None
        if isinstance(d, str) and d.strip():
            return os.path.expanduser(os.path.expandvars(d.strip()))
    return default


r2_s3.set_credentials_file(setting("r2.credentials_file", "R2_CREDENTIALS_FILE"))

BUCKET = "gallery-hot"
FILE = "release.json"
CACHE_JSON = "public, max-age=21600, stale-while-revalidate=86400"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9_]{0,80}$")


def mirror_dir() -> Path:
    root = setting("r2.mirror_root", "R2_MIRROR_ROOT")
    if not root:
        raise SystemExit("r2.mirror_root is not set: add it to server/config/settings.json "
                         "or set R2_MIRROR_ROOT")
    return Path(root) / BUCKET


def key_for(collection: str) -> str:
    return "collections/%s/%s" % (collection, FILE)


def parse_date(text: str) -> dt.datetime:
    """YYYY-MM-DD (00:00 UTC) or a full ISO timestamp with a zone."""
    s = text.strip()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", s):
        return dt.datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=dt.timezone.utc)
    t = dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
    if t.tzinfo is None:
        raise ValueError("timestamp needs a zone (use Z for UTC): %s" % text)
    return t.astimezone(dt.timezone.utc)


def body_for(when: dt.datetime) -> bytes:
    doc = {"releaseAt": when.strftime("%Y-%m-%dT%H:%M:%SZ"),
           "publishedAt": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    return (json.dumps(doc, indent=1) + "\n").encode("utf-8")


def publish(collection: str, when: dt.datetime) -> dict:
    if not ID_RE.match(collection):
        raise ValueError("collection id must be lowercase snake_case: %r" % collection)
    mirror_dir()  # resolve before the upload: never write the bucket without its mirror
    body = body_for(when)
    key = key_for(collection)
    r2_s3._call("PUT", BUCKET, key,
                headers={"content-type": "application/json; charset=utf-8", "cache-control": CACHE_JSON},
                body=body, timeout=120)
    back = json.loads(r2_s3.get_object(BUCKET, key).decode("utf-8"))
    if back.get("releaseAt") != json.loads(body)["releaseAt"]:
        raise RuntimeError("read-back mismatch for %s: %r" % (key, back))
    head = r2_s3.head_object(BUCKET, key)
    mirror = mirror_dir() / key
    mirror.parent.mkdir(parents=True, exist_ok=True)
    mirror.write_bytes(body)
    return {"key": key, "releaseAt": back["releaseAt"], "cache_control": head["cache_control"],
            "mirror": str(mirror)}


def schedule() -> list[dict]:
    out = []
    for o in r2_s3.list_all(BUCKET, prefix="collections/"):
        parts = o["key"].split("/")
        if len(parts) == 3 and parts[2] == FILE:
            try:
                doc = json.loads(r2_s3.get_object(BUCKET, o["key"]).decode("utf-8"))
                at = doc.get("releaseAt", "?")
            except Exception as e:  # shown, never hidden: an unreadable file hides the collection
                at = "UNREADABLE (%s)" % e
            out.append({"collection": parts[1], "releaseAt": at})
    return sorted(out, key=lambda r: str(r["releaseAt"]))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("collection", nargs="?")
    ap.add_argument("date", nargs="?", help="YYYY-MM-DD (00:00 UTC) or ISO timestamp with zone")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    if a.list:
        now = dt.datetime.now(dt.timezone.utc)
        for r in schedule():
            try:
                state = "released" if parse_date(r["releaseAt"]) <= now else "scheduled"
            except Exception:
                state = "HIDDEN (bad date)"
            print("%-28s %-22s %s" % (r["collection"], r["releaseAt"], state))
        return
    if not a.collection:
        ap.error("collection required")
    if a.check:
        print(r2_s3.get_object(BUCKET, key_for(a.collection)).decode("utf-8"))
        return
    if not a.date:
        ap.error("date required")
    when = parse_date(a.date)
    if when <= dt.datetime.now(dt.timezone.utc):
        print("note: %s is not in the future - the collection is released on the next manifest rebuild"
              % when.isoformat())
    r = publish(a.collection, when)
    print("%s -> releaseAt %s  (cache-control '%s')\n  mirror %s" % (r["key"], r["releaseAt"],
                                                                     r["cache_control"], r["mirror"]))


if __name__ == "__main__":
    main()
