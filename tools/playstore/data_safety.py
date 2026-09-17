"""Add the first-party analytics declarations to an app's Play "Data safety" form and push it.

The Play Developer API can only WRITE the whole declaration (POST applications/{pkg}/dataSafety with
the CSV text); it cannot read it. So the current answers come from Play Console's own
"Export to CSV" (Policy > App content > Data safety), this tool ADDS what the shared analytics
client collects and never unsets an existing answer (ads, sign-in, purchases stay as they are):

  App activity / App interactions        collected, Analytics, optional
  Device or other IDs                    collected, Analytics (random install id); an existing
                                         "shared / advertising / required" answer is kept
  App info and performance / Diagnostics collected, Analytics, optional
  App info and performance / Crash logs  collected, Analytics, optional  (not for Godot apps: their
                                         client reports start time and freezes, not errors)

  python data_safety.py merge <exported.csv> <out.csv> [--no-crash-logs]   write the merged CSV, print the diff
  python data_safety.py push <package> <merged.csv>                        send it (204 = saved)
  python data_safety.py run <folder> [--push]     every <slug>.csv in the folder (hotjigsaw.csv, deathpin.csv ...):
                                                  merge into <folder>/merged/, and with --push send them

Service-account key: --key, else env PLAY_SA_KEY, else the Play publish key in the keys folder.
"""
from __future__ import annotations

import argparse
import csv
import io
import os
import sys

DEFAULT_KEY = "D:/keys/arcade-snake-488801-5ac9863bb0ab.json"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
USAGE = "PSL_DATA_USAGE_RESPONSES:%s:%s"

# slug (file name) -> (package, reports uncaught errors)
APPS = {
    "acepong": ("com.lifecharger.acepong", True), "arcadesnake": ("com.lifecharger.arcadesnake", True),
    "appmanager": ("com.lifecharger.appmanager", True), "beestriker": ("com.lifecharger.beestriker", False),
    "deathpin": ("com.lifecharger.deathpin", False), "hotcharm": ("com.lifecharger.hotcharm", True),
    "hotidle": ("com.lifecharger.hotidle", True), "hotjigsaw": ("com.lifecharger.hotjigsaw", True),
    "hotslider": ("com.lifecharger.hotslider", True), "locationalarm": ("com.lifecharger.locationalarm", True),
    "projigsaw": ("com.lifecharger.projigsaw", True), "sentience": ("com.lifecharger.sentience", True),
    "hotcardgames": ("com.lifecharger.hotcardgames", True), "animestreamer": ("com.lifecharger.animestreamer", True),
    "animashift": ("com.lifecharger.animashift", True), "antempire": ("com.lifecharger.antempire", True),
    "newcitynewrise": ("com.lifecharger.newcitynewrise", True),
}


def read_rows(path: str) -> list[list[str]]:
    with io.open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.reader(f))


def write_rows(path: str, rows: list[list[str]]) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)


def merge(rows: list[list[str]], crash_logs: bool) -> tuple[list[list[str]], list[str]]:
    """Returns (rows, human-readable changes). Only ever turns answers ON or fills empty ones."""
    index = {(r[0], r[1]): r for r in rows[1:] if len(r) >= 3}
    changes: list[str] = []

    def answered(question: str) -> bool:
        return any(q == question and r[2].strip() for (q, _), r in index.items())

    def put(question: str, response: str, value: str, only_if_unanswered: bool = False) -> None:
        row = index.get((question, response))
        if row is None:
            raise SystemExit("row missing in the exported CSV (template changed?): %s | %s" % (question, response))
        if only_if_unanswered and answered(question):
            return
        if row[2].strip() != value:
            changes.append("%s | %s: '%s' -> '%s'" % (question, response or "-", row[2].strip(), value))
            row[2] = value

    put("PSL_DATA_COLLECTION_COLLECTS_PERSONAL_DATA", "", "true")
    put("PSL_DATA_COLLECTION_ENCRYPTED_IN_TRANSIT", "", "true")
    # "can users ask for deletion?" - our policies offer deletion by e-mail; keep an existing answer
    put("PSL_SUPPORT_DATA_DELETION_BY_USER", "DATA_DELETION_YES", "true", only_if_unanswered=True)

    types = [("PSL_DATA_TYPES_APP_ACTIVITY", "PSL_USER_INTERACTION"),
             ("PSL_DATA_TYPES_IDENTIFIERS", "PSL_DEVICE_ID"),
             ("PSL_DATA_TYPES_APP_PERFORMANCE", "PSL_PERFORMANCE_DIAGNOSTICS")]
    if crash_logs:
        types.append(("PSL_DATA_TYPES_APP_PERFORMANCE", "PSL_CRASH_LOGS"))
    for group, data_type in types:
        put(group, data_type, "true")
        put(USAGE % (data_type, "PSL_DATA_USAGE_COLLECTION_AND_SHARING"), "PSL_DATA_USAGE_ONLY_COLLECTED", "true")
        put(USAGE % (data_type, "PSL_DATA_USAGE_EPHEMERAL"), "", "false", only_if_unanswered=True)
        # single choice: an existing REQUIRED (ads device id) stays; otherwise the player can switch it off
        put(USAGE % (data_type, "DATA_USAGE_USER_CONTROL"), "PSL_DATA_USAGE_USER_CONTROL_OPTIONAL", "true",
            only_if_unanswered=True)
        put(USAGE % (data_type, "DATA_USAGE_COLLECTION_PURPOSE"), "PSL_ANALYTICS", "true")
    return rows, changes


def push(package: str, csv_path: str, key: str | None) -> int:
    import google.auth.transport.requests
    import requests
    from google.oauth2 import service_account

    key = key or os.environ.get("PLAY_SA_KEY") or DEFAULT_KEY
    creds = service_account.Credentials.from_service_account_file(key, scopes=[SCOPE])
    creds.refresh(google.auth.transport.requests.Request())
    with io.open(csv_path, encoding="utf-8") as f:
        text = f.read()
    r = requests.post(
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/%s/dataSafety" % package,
        headers={"Authorization": "Bearer %s" % creds.token, "Content-Type": "application/json"},
        json={"safetyLabels": text}, timeout=60)
    print("%s -> %s %s" % (package, r.status_code, r.text[:400]))
    return 0 if r.status_code in (200, 204) else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("merge")
    m.add_argument("src"), m.add_argument("dst"), m.add_argument("--no-crash-logs", action="store_true")
    p = sub.add_parser("push")
    p.add_argument("package"), p.add_argument("csv"), p.add_argument("--key")
    r = sub.add_parser("run")
    r.add_argument("folder"), r.add_argument("--push", action="store_true"), r.add_argument("--key")
    a = ap.parse_args()

    if a.cmd == "merge":
        rows, changes = merge(read_rows(a.src), not a.no_crash_logs)
        write_rows(a.dst, rows)
        print("\n".join(changes) or "nothing to change")
        return 0
    if a.cmd == "push":
        return push(a.package, a.csv, a.key)

    failed = 0
    for name in sorted(os.listdir(a.folder)):
        slug, ext = os.path.splitext(name.lower())
        if ext != ".csv":
            continue
        if slug not in APPS:
            print("SKIP %s: file name is not one of %s" % (name, ", ".join(sorted(APPS))))
            continue
        package, crash_logs = APPS[slug]
        rows, changes = merge(read_rows(os.path.join(a.folder, name)), crash_logs)
        out = os.path.join(a.folder, "merged", slug + ".csv")
        write_rows(out, rows)
        print("== %s (%s): %d answers changed" % (slug, package, len(changes)))
        for c in changes:
            print("   " + c)
        if a.push and changes:
            failed += push(package, out, a.key)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
