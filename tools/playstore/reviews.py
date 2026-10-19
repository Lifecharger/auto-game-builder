"""Google Play reviews: list the unanswered ones, post replies, tell the owner on the phone.

    python reviews.py list   [--all] [--out FILE]      # unanswered reviews of every app as JSON
    python reviews.py reply  replies.json              # [{"package", "reviewId", "text"}, ...]
    python reviews.py notify <title> <textfile>        # note in the AGB app's Notes tab (like the weekly report)

The Play API only returns reviews written or edited in the LAST 7 DAYS, so this has to run
at least every few days; older reviews are only visible in Play Console. Every review seen is
appended to <reviews_dir>/seen.jsonl and every posted reply to <reviews_dir>/replies.jsonl, so
the history outlives the 7-day window.

Settings (tools/local_settings.json): play_console_service_account, reviews_dir.
AGB api key / port for `notify`: server/config/settings.json (security.api_key, server.port)
or env AGB_API_KEY / AGB_URL. Reply text limit is 350 characters (Play rule).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
from pathlib import Path

import requests
from google.oauth2 import service_account
from googleapiclient.discovery import build

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import local_settings  # noqa: E402

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
REPO = Path(__file__).resolve().parents[2]
MAX_REPLY = 350

# Every app with a Play listing; packages without reviews just return nothing.
PACKAGES = [
    "com.lifecharger." + p for p in (
        "acepong animashift animestreamer antempire arcadesnake hotcardgames hotcharm hotclash "
        "hotidle hotjigsaw hotslider locationalarm luminalive newcitynewrise pixeladventurer "
        "projigsaw sentience beestriker deathpin hotcollector appmanager").split()
]


def _svc():
    key = os.environ.get("PLAY_SA_KEY") or local_settings.get("play_console_service_account")
    creds = service_account.Credentials.from_service_account_file(key, scopes=[SCOPE])
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def _dir() -> Path:
    d = local_settings.path("reviews_dir")
    d.mkdir(parents=True, exist_ok=True)
    return d


def _append(name: str, rows: list[dict]) -> None:
    if rows:
        with open(_dir() / name, "a", encoding="utf-8") as fh:
            for r in rows:
                fh.write(json.dumps(r, ensure_ascii=False) + "\n")


def fetch(svc) -> tuple[list[dict], list[str]]:
    out, errors = [], []
    for pkg in PACKAGES:
        tok = None
        try:
            while True:
                r = svc.reviews().list(packageName=pkg, maxResults=100, token=tok).execute()
                for rv in r.get("reviews", []):
                    cs = rv.get("comments", [])
                    u = next((c["userComment"] for c in cs if "userComment" in c), {})
                    dev = next((c["developerComment"] for c in cs if "developerComment" in c), None)
                    secs = int(u.get("lastModified", {}).get("seconds", 0))
                    out.append({
                        "package": pkg, "reviewId": rv["reviewId"], "author": rv.get("authorName", ""),
                        "stars": u.get("starRating"), "text": u.get("text", "").strip(),
                        "language": u.get("reviewerLanguage"), "version": u.get("appVersionName"),
                        "device": u.get("deviceMetadata", {}).get("productName"),
                        "date": dt.datetime.fromtimestamp(secs, dt.timezone.utc).strftime("%Y-%m-%d %H:%M"),
                        "replied": dev is not None, "reply": dev.get("text") if dev else None,
                    })
                tok = r.get("tokenPagination", {}).get("nextPageToken")
                if not tok:
                    break
        except Exception as e:  # one app failing must not hide the others; reported in the output
            errors.append("%s: %s" % (pkg, str(e)[:200]))
    return out, errors


def cmd_list(a) -> None:
    rows, errors = fetch(_svc())
    _append("seen.jsonl", [dict(r, fetched=dt.datetime.now().isoformat(timespec="seconds")) for r in rows])
    if not a.all:
        rows = [r for r in rows if not r["replied"]]
    data = json.dumps({"reviews": rows, "errors": errors}, ensure_ascii=False, indent=1)
    if a.out:
        Path(a.out).write_text(data, encoding="utf-8")
        print("%d reviews -> %s (%d errors)" % (len(rows), a.out, len(errors)))
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        print(data)
    if errors:
        sys.exit(2)


def cmd_reply(a) -> None:
    items = json.loads(Path(a.file).read_text(encoding="utf-8"))
    svc, done, failed = _svc(), [], 0
    for it in items:
        text = it["text"].strip()
        if len(text) > MAX_REPLY:
            print("SKIP too long (%d chars): %s %s" % (len(text), it["package"], it["reviewId"]))
            failed += 1
            continue
        try:
            svc.reviews().reply(packageName=it["package"], reviewId=it["reviewId"],
                                body={"replyText": text}).execute()
            done.append(dict(it, sent=dt.datetime.now().isoformat(timespec="seconds")))
            print("OK", it["package"], it["reviewId"])
        except Exception as e:
            print("FAIL", it["package"], it["reviewId"], str(e)[:200])
            failed += 1
    _append("replies.jsonl", done)
    print("%d sent, %d failed" % (len(done), failed))
    if failed:
        sys.exit(2)


def _agb_setting(path: str, env: str, default: str = "") -> str:
    if os.environ.get(env):
        return os.environ[env]
    try:
        cur = json.loads((REPO / "server" / "config" / "settings.json").read_text(encoding="utf-8"))
        for part in path.split("."):
            cur = cur[part]
        return str(cur)
    except (OSError, KeyError, TypeError, ValueError):
        return default


def cmd_notify(a) -> None:
    """Leave the summary in the AGB app's Notes tab (POST /api/notices)."""
    text = Path(a.textfile).read_text(encoding="utf-8")
    key = _agb_setting("security.api_key", "AGB_API_KEY")
    if not key:
        raise SystemExit("AGB api key not set (security.api_key / AGB_API_KEY)")
    base = (os.environ.get("AGB_URL") or "http://localhost:%s" % _agb_setting("server.port", "AGB_PORT", "8000")).rstrip("/")
    r = requests.post(base + "/api/notices", headers={"X-API-Key": key}, timeout=30,
                      json={"source": "play_reviews", "title": a.title, "body": text, "key": "play_reviews:" + a.title})
    r.raise_for_status()
    print("created AGB note #%s" % r.json()["id"])


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list"); p.add_argument("--all", action="store_true"); p.add_argument("--out")
    p.set_defaults(fn=cmd_list)
    p = sub.add_parser("reply"); p.add_argument("file"); p.set_defaults(fn=cmd_reply)
    p = sub.add_parser("notify"); p.add_argument("title"); p.add_argument("textfile"); p.set_defaults(fn=cmd_notify)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
