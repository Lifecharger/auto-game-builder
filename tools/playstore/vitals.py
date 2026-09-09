"""Play Vitals (crash / ANR) via the Play Developer Reporting API + Dart stack symbolizer.

    python vitals.py rates    <package> [--days 28]
    python vitals.py issues   <package> [--days 28] [--reports]      # top issues (+ one sample report each)
    python vitals.py reports  <package> [--days 28]                  # every report with time / version / device
    python vitals.py symbolize <package> <versionCode> <stack.txt>   # libapp.so frames -> Dart function names

Symbols come from the AGB build engine: every Flutter build runs with
--split-debug-info and the *.symbols files are archived under
server/data/symbols/<package>/<versionCode>/ (task #332). `symbolize` runs
`flutter symbolize -d <that dir> -i <stack.txt>`.

Service-account key: --key, else env PLAY_SA_KEY, else the arcade-snake key in D:/keys
(same convention as the other playstore tools). Scope: playdeveloperreporting.
Gotchas (verified 2026-09-09): timeZone must be "America/Los_Angeles" ("UTC" is
rejected); errorReports filter field is `errorIssueId` (not `issue`); the API
answers 503 now and then - retry.
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import os
import subprocess
import sys
import time

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account

DEFAULT_KEY = "D:/keys/arcade-snake-488801-35f27b42dfb3.json"
SCOPE = "https://www.googleapis.com/auth/playdeveloperreporting"
API = "https://playdeveloperreporting.googleapis.com/v1beta1/apps/%s"
TZ = {"id": "America/Los_Angeles"}
_HERE = os.path.dirname(os.path.abspath(__file__))
SYMBOLS_ROOT = os.path.normpath(os.path.join(_HERE, "..", "..", "server", "data", "symbols"))


def session(key: str | None) -> AuthorizedSession:
    key = key or os.environ.get("PLAY_SA_KEY") or DEFAULT_KEY
    creds = service_account.Credentials.from_service_account_file(key, scopes=[SCOPE])
    return AuthorizedSession(creds)


def _call(s: AuthorizedSession, method: str, url: str, **kw):
    for i in range(4):
        r = s.request(method, url, **kw)
        if r.status_code == 503:
            time.sleep(2 * (i + 1))
            continue
        if r.status_code != 200:
            raise SystemExit("HTTP %s %s\n%s" % (r.status_code, url, r.text[:400]))
        return r.json()
    raise SystemExit("503 after retries: " + url)


def _date(d: dt.date) -> dict:
    return {"year": d.year, "month": d.month, "day": d.day, "timeZone": TZ}


def _interval_params(st: dt.date, ed: dt.date) -> dict:
    return {"interval.startTime.year": st.year, "interval.startTime.month": st.month, "interval.startTime.day": st.day,
            "interval.endTime.year": ed.year, "interval.endTime.month": ed.month, "interval.endTime.day": ed.day}


def latest_day(s: AuthorizedSession, pkg: str, metric_set: str) -> dt.date:
    meta = _call(s, "GET", API % pkg + "/" + metric_set)
    for f in meta.get("freshnessInfo", {}).get("freshnesses", []):
        if f.get("aggregationPeriod") == "DAILY":
            e = f.get("latestEndTime", {})
            return dt.date(e["year"], e["month"], e["day"])
    return dt.date.today() - dt.timedelta(days=3)


def rates(s: AuthorizedSession, pkg: str, days: int) -> None:
    for ms, metric in (("crashRateMetricSet", "crashRate"), ("anrRateMetricSet", "anrRate")):
        ed = latest_day(s, pkg, ms)
        st = ed - dt.timedelta(days=days - 1)
        body = {"timelineSpec": {"aggregationPeriod": "DAILY", "startTime": _date(st), "endTime": _date(ed)},
                "metrics": [metric, "distinctUsers"], "pageSize": 200}
        r = _call(s, "POST", API % pkg + "/%s:query" % ms, json=body)
        print("== %s  (latest %s, %d days)" % (metric, ed, days))
        rows = r.get("rows", [])
        if not rows:
            print("   (no rows - too few users per day)")
        for row in rows:
            d = row["startTime"]
            m = {x["metric"]: x.get("decimalValue", {}).get("value") for x in row.get("metrics", [])}
            print("   %04d-%02d-%02d  %s=%s  users=%s" % (d["year"], d["month"], d["day"], metric, m.get(metric), m.get("distinctUsers")))


def issues(s: AuthorizedSession, pkg: str, days: int, with_reports: bool) -> list[dict]:
    ed = latest_day(s, pkg, "crashRateMetricSet")
    st = ed - dt.timedelta(days=days - 1)
    p = dict(_interval_params(st, ed), pageSize=50, orderBy="errorReportCount desc")
    r = _call(s, "GET", API % pkg + "/errorIssues:search", params=p)
    out = []
    for i in r.get("errorIssues", []):
        row = {"id": i["name"].split("/")[-1], "type": i.get("type"), "cause": i.get("cause"), "location": i.get("location"),
               "reports": i.get("errorReportCount"), "users": i.get("distinctUsers"),
               "first": (i.get("firstAppVersion") or {}).get("versionCode"), "last": (i.get("lastAppVersion") or {}).get("versionCode")}
        print("%-26s %3s rep %3s users v%s-%s | %s @ %s" % (row["type"], row["reports"], row["users"], row["first"], row["last"], row["cause"], row["location"]))
        if with_reports:
            rp = _call(s, "GET", API % pkg + "/errorReports:search",
                       params=dict(_interval_params(st, ed), pageSize=1, filter='errorIssueId = "%s"' % row["id"]))
            for rep in rp.get("errorReports", [])[:1]:
                dm = rep.get("deviceModel") or {}
                print("     %s  v%s  API %s  %s" % (rep.get("eventTime", "")[:16], (rep.get("appVersion") or {}).get("versionCode"),
                                                    (rep.get("osVersion") or {}).get("apiLevel"), dm.get("marketName") or dm.get("deviceId")))
                row["sample"] = rep.get("reportText") or ""
                for ln in row["sample"].splitlines()[:12]:
                    print("       " + ln.rstrip()[:150])
        out.append(row)
    return out


def reports(s: AuthorizedSession, pkg: str, days: int) -> None:
    ed = latest_day(s, pkg, "crashRateMetricSet")
    st = ed - dt.timedelta(days=days - 1)
    r = _call(s, "GET", API % pkg + "/errorReports:search", params=dict(_interval_params(st, ed), pageSize=100))
    for rep in sorted(r.get("errorReports", []), key=lambda x: x.get("eventTime", "")):
        dm = rep.get("deviceModel") or {}
        print("%s  %-26s v%-4s API %-3s %s" % (rep.get("eventTime", "")[:16], rep.get("type"), (rep.get("appVersion") or {}).get("versionCode"),
                                                (rep.get("osVersion") or {}).get("apiLevel"), dm.get("marketName") or dm.get("deviceId")))


def symbolize(pkg: str, version_code: str, stack_file: str, flutter: str = "flutter") -> None:
    d = os.path.join(SYMBOLS_ROOT, pkg, str(version_code))
    if not os.path.isdir(d) or not glob.glob(os.path.join(d, "*.symbols")):
        raise SystemExit("no symbols for %s versionCode %s under %s\n(build with the AGB build engine >= task #332)" % (pkg, version_code, SYMBOLS_ROOT))
    subprocess.run([flutter, "symbolize", "-d", d, "-i", stack_file], check=False)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["rates", "issues", "reports", "symbolize"])
    ap.add_argument("package")
    ap.add_argument("rest", nargs="*")
    ap.add_argument("--days", type=int, default=28)
    ap.add_argument("--reports", action="store_true", help="issues: fetch one sample report per issue")
    ap.add_argument("--key", default=None)
    ap.add_argument("--flutter", default=os.environ.get("FLUTTER", "flutter"))
    a = ap.parse_args()
    if a.cmd == "symbolize":
        if len(a.rest) != 2:
            raise SystemExit("symbolize <package> <versionCode> <stack.txt>")
        symbolize(a.package, a.rest[0], a.rest[1], a.flutter)
        return
    s = session(a.key)
    if a.cmd == "rates":
        rates(s, a.package, a.days)
    elif a.cmd == "issues":
        issues(s, a.package, a.days, a.reports)
    elif a.cmd == "reports":
        reports(s, a.package, a.days)


if __name__ == "__main__":
    main()
