"""Weekly performance + health report for the Lifecharger apps (no LLM - plain rules).

    python weekly_report.py                 # last 7 full days vs the 7 before, write report + notify phone
    python weekly_report.py --no-notify     # write the report only
    python weekly_report.py --end 2026-09-28  # a different last day (inclusive)

Per app it compares LAST 7 DAYS with the PREVIOUS 7 DAYS: Google Ads spend / installs / CPI,
AdMob earnings, Play purchases, money in vs out, new players, DAU, session length, D1 return,
Play crash / ANR rate, abnormal ends / freezes and new crash signatures on the newest builds.
Rules in weekly_report_config.json turn the numbers into plain-language flags.

Output: <output_dir>/<end date>.html (self-contained, phone friendly) + <end date>.md, and a
short summary delivered to the owner's phone as an AGB task ("Weekly report <date>", created in
the Auto Game Builder app and closed at once so no automation session picks it up).

The repo is PUBLIC: nothing machine-specific or secret lives in this file. Everything is read
from an environment variable first, then the dotted key in server/config/settings.json
(git-ignored), then a portable default (same pattern as tools/events/event_paths.py):

  weekly_report.output_dir          WEEKLY_REPORT_DIR           default ~/Reports/weekly
  weekly_report.oauth_token_file    REPORTS_OAUTH_TOKEN         default <paths.keys_dir>/reports_oauth_token.json
  weekly_report.play_sa_key         PLAY_SA_KEY                 default paths.service_account_key
  weekly_report.analytics_url       ANALYTICS_URL               default https://analytics.lifecharger.workers.dev
  weekly_report.analytics_key_file  ANALYTICS_ADMIN_KEY_FILE    default <paths.keys_dir>/analytics_admin_key.txt
  weekly_report.ads_customer_id     ADS_CUSTOMER_ID             Google Ads customer id (digits)
  weekly_report.ads_quota_project   ADS_QUOTA_PROJECT           GCP project sent as x-goog-user-project
  weekly_report.admob_publisher_id  ADMOB_PUBLISHER_ID          pub-...
  weekly_report.play_bucket         PLAY_REPORTS_BUCKET         pubsite_prod_<developer id>
  weekly_report.agb_url             AGB_URL                     default http://localhost:<server.port>
  security.api_key                  AGB_API_KEY                 AGB server key (for the phone task)
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import csv
import datetime as dt
import html
import io
import json
import os
import sys
import time
import traceback
import zipfile
from pathlib import Path

import requests
from google.auth.transport.requests import AuthorizedSession, Request
from google.oauth2 import service_account
from google.oauth2.credentials import Credentials

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent
SETTINGS = AGB_ROOT / "server" / "config" / "settings.json"
CONFIG = HERE / "weekly_report_config.json"

ADS_API = "https://googleads.googleapis.com/v24/customers/%s/googleAds:search"
ADMOB_API = "https://admob.googleapis.com/v1/accounts/%s"
PLAY_API = "https://playdeveloperreporting.googleapis.com/v1beta1/apps/%s"
GCS_API = "https://storage.googleapis.com/storage/v1/b/%s/o"
PLAY_TZ = {"id": "America/Los_Angeles"}  # the Reporting API rejects "UTC"

NOTES: list[str] = []  # data-source problems, shown in the report and the phone summary


# ---------------------------------------------------------------- settings

def _settings() -> dict:
    if SETTINGS.is_file():
        return json.loads(SETTINGS.read_text(encoding="utf-8")) or {}
    return {}


def setting(key: str, env: str = "", default: str = "") -> str:
    """Dotted key from settings.json; a non-empty environment variable wins."""
    if env:
        v = os.environ.get(env, "").strip()
        if v:
            return v
    d = _settings()
    for part in key.split("."):
        d = d.get(part) if isinstance(d, dict) else None
    if isinstance(d, (str, int)) and str(d).strip():
        return os.path.expanduser(os.path.expandvars(str(d).strip()))
    return default


def keys_dir_file(name: str) -> str:
    kd = setting("paths.keys_dir", "LIFECHARGER_KEYS_DIR")
    return os.path.join(kd, name) if kd else ""


def cfg() -> dict:
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def note(msg: str) -> None:
    NOTES.append(msg)
    print("NOTE:", msg, file=sys.stderr)


def _short_err(e: Exception) -> str:
    s = str(e).replace("\n", " ")
    return (type(e).__name__ + ": " + s)[:220]


# ---------------------------------------------------------------- windows

class Win:
    def __init__(self, end: dt.date):
        self.end = end
        self.start = end - dt.timedelta(days=6)
        self.pend = self.start - dt.timedelta(days=1)
        self.pstart = self.pend - dt.timedelta(days=6)

    def which(self, day: dt.date | str) -> str | None:
        if isinstance(day, str):
            day = dt.date.fromisoformat(day[:10])
        if self.start <= day <= self.end:
            return "cur"
        if self.pstart <= day <= self.pend:
            return "prev"
        return None

    def label(self) -> str:
        return "%s .. %s" % (self.start, self.end)

    def plabel(self) -> str:
        return "%s .. %s" % (self.pstart, self.pend)


def two() -> dict:
    return {"cur": 0.0, "prev": 0.0}


# ---------------------------------------------------------------- Google Ads

def oauth_session() -> AuthorizedSession:
    tok = setting("weekly_report.oauth_token_file", "REPORTS_OAUTH_TOKEN", keys_dir_file("reports_oauth_token.json"))
    if not tok or not os.path.isfile(tok):
        raise RuntimeError("OAuth token file not found (weekly_report.oauth_token_file)")
    c = Credentials.from_authorized_user_file(tok)
    c.refresh(Request())
    return AuthorizedSession(c)


def fetch_ads(s: AuthorizedSession, w: Win) -> dict:
    cust = setting("weekly_report.ads_customer_id", "ADS_CUSTOMER_ID").replace("-", "")
    proj = setting("weekly_report.ads_quota_project", "ADS_QUOTA_PROJECT")
    if not cust:
        raise RuntimeError("weekly_report.ads_customer_id is not set")
    hdr = {"x-goog-user-project": proj} if proj else {}

    def search(q: str) -> list:
        out, tok = [], None
        while True:
            body = {"query": q}
            if tok:
                body["pageToken"] = tok
            r = s.post(ADS_API % cust, json=body, headers=hdr, timeout=60)
            if r.status_code != 200:
                raise RuntimeError("Google Ads HTTP %s %s" % (r.status_code, r.text[:200]))
            d = r.json()
            out += d.get("results", [])
            tok = d.get("nextPageToken")
            if not tok:
                return out

    cur_code = "TRY"
    try:
        rows = search("SELECT customer.currency_code FROM customer")
        cur_code = rows[0]["customer"].get("currencyCode", "TRY") if rows else "TRY"
    except Exception as e:
        note("Google Ads currency lookup failed (%s); assuming TRY" % _short_err(e))
    q = ("SELECT campaign.id, campaign.name, campaign.status, campaign.app_campaign_setting.app_id, "
         "campaign_budget.amount_micros, segments.date, metrics.cost_micros, metrics.conversions, "
         "metrics.impressions, metrics.clicks FROM campaign "
         "WHERE segments.date BETWEEN '%s' AND '%s'" % (w.pstart, w.end))
    camps: dict = {}
    for r in search(q):
        c = r["campaign"]
        k = w.which(r["segments"]["date"])
        if not k:
            continue
        m = r.get("metrics", {})
        e = camps.setdefault(c["id"], {"id": c["id"], "name": c.get("name", ""), "status": c.get("status", ""),
                                        "package": (c.get("appCampaignSetting") or {}).get("appId", ""),
                                        "budget": int((r.get("campaignBudget") or {}).get("amountMicros", 0)) / 1e6,
                                        "spend": two(), "installs": two(), "impressions": two(), "clicks": two()})
        e["spend"][k] += int(m.get("costMicros", 0)) / 1e6
        e["installs"][k] += float(m.get("conversions", 0) or 0)
        e["impressions"][k] += int(m.get("impressions", 0) or 0)
        e["clicks"][k] += int(m.get("clicks", 0) or 0)
    return {"currency": cur_code, "campaigns": list(camps.values())}


# ---------------------------------------------------------------- AdMob

def fetch_admob(s: AuthorizedSession, w: Win) -> dict:
    pub = setting("weekly_report.admob_publisher_id", "ADMOB_PUBLISHER_ID")
    if not pub:
        raise RuntimeError("weekly_report.admob_publisher_id is not set")
    base = ADMOB_API % pub
    r = s.get(base + "/apps", params={"pageSize": 200}, timeout=60)
    if r.status_code != 200:
        raise RuntimeError("AdMob apps HTTP %s %s" % (r.status_code, r.text[:200]))
    app_pkg = {a["appId"]: (a.get("linkedAppInfo") or {}).get("appStoreId", "") for a in r.json().get("apps", [])}
    d = lambda x: {"year": x.year, "month": x.month, "day": x.day}
    body = {"reportSpec": {"dateRange": {"startDate": d(w.pstart), "endDate": d(w.end)}, "dimensions": ["APP", "DATE"],
                           "metrics": ["ESTIMATED_EARNINGS", "IMPRESSIONS", "AD_REQUESTS", "MATCHED_REQUESTS"],
                           "localizationSettings": {"currencyCode": "TRY"}}}
    r = s.post(base + "/networkReport:generate", json=body, timeout=120)
    if r.status_code != 200:
        raise RuntimeError("AdMob report HTTP %s %s" % (r.status_code, r.text[:200]))
    per: dict = {}
    for item in r.json():
        row = item.get("row")
        if not row:
            continue
        dv, mv = row["dimensionValues"], row["metricValues"]
        day = dv["DATE"]["value"]
        k = w.which("%s-%s-%s" % (day[:4], day[4:6], day[6:8]))
        if not k:
            continue
        pkg = app_pkg.get(dv["APP"]["value"]) or dv["APP"].get("displayLabel", "?")
        e = per.setdefault(pkg, {"earnings": two(), "impressions": two(), "requests": two(), "matched": two()})
        e["earnings"][k] += int(mv.get("ESTIMATED_EARNINGS", {}).get("microsValue", 0)) / 1e6
        e["impressions"][k] += int(mv.get("IMPRESSIONS", {}).get("integerValue", 0))
        e["requests"][k] += int(mv.get("AD_REQUESTS", {}).get("integerValue", 0))
        e["matched"][k] += int(mv.get("MATCHED_REQUESTS", {}).get("integerValue", 0))
    return per


# ---------------------------------------------------------------- Play (GCS sales / earnings)

def play_sa(scope: str) -> AuthorizedSession:
    key = setting("weekly_report.play_sa_key", "PLAY_SA_KEY", setting("paths.service_account_key"))
    if not key or not os.path.isfile(key):
        raise RuntimeError("Play service-account key not found (weekly_report.play_sa_key)")
    return AuthorizedSession(service_account.Credentials.from_service_account_file(key, scopes=[scope]))


def gcs_list(s: AuthorizedSession, bucket: str, prefix: str) -> list:
    out, tok = [], None
    while True:
        p = {"prefix": prefix, "maxResults": 1000}
        if tok:
            p["pageToken"] = tok
        r = s.get(GCS_API % bucket, params=p, timeout=60)
        r.raise_for_status()
        d = r.json()
        out += d.get("items", [])
        tok = d.get("nextPageToken")
        if not tok:
            return out


def gcs_get(s: AuthorizedSession, bucket: str, name: str) -> bytes:
    r = s.get(GCS_API % bucket + "/" + requests.utils.quote(name, safe=""), params={"alt": "media"}, timeout=120)
    r.raise_for_status()
    return r.content


def _zip_csv_rows(blob: bytes) -> list[dict]:
    rows = []
    with zipfile.ZipFile(io.BytesIO(blob)) as zf:
        for n in zf.namelist():
            raw = zf.read(n)
            try:
                txt = raw.decode("utf-8-sig")
            except UnicodeDecodeError:
                txt = raw.decode("utf-16")
            rows += list(csv.DictReader(io.StringIO(txt)))
    return rows


def fx_to_try() -> dict:
    """TRY per 1 unit of each currency (public FX feeds, no key)."""
    for url, path in (("https://open.er-api.com/v6/latest/TRY", "rates"),
                      ("https://api.frankfurter.dev/v1/latest?base=TRY", "rates")):
        try:
            r = requests.get(url, timeout=30)
            r.raise_for_status()
            rates = r.json()[path]
            out = {c: 1.0 / float(v) for c, v in rates.items() if float(v)}
            out["TRY"] = 1.0
            return out
        except Exception as e:
            note("FX feed %s failed (%s)" % (url.split("/")[2], _short_err(e)))
    return {"TRY": 1.0}


def fetch_play_money(w: Win) -> dict:
    bucket = setting("weekly_report.play_bucket", "PLAY_REPORTS_BUCKET")
    if not bucket:
        raise RuntimeError("weekly_report.play_bucket is not set")
    s = play_sa("https://www.googleapis.com/auth/devstorage.read_only")
    fee = cfg().get("play_fee_pct", 15) / 100.0
    fx = fx_to_try()
    months = sorted({d.strftime("%Y%m") for d in (w.pstart, w.pend, w.start, w.end)})
    per: dict = {}
    missing_fx: set = set()
    for m in months:
        items = gcs_list(s, bucket, "sales/salesreport_%s" % m)
        if not items:
            note("Play sales report for %s not in the bucket yet" % m)
            continue
        for it in items:
            for row in _zip_csv_rows(gcs_get(s, bucket, it["name"])):
                k = w.which(row.get("Order Charged Date", "")[:10]) if row.get("Order Charged Date") else None
                if not k:
                    continue
                pkg = row.get("Package ID", "")
                cur = row.get("Currency of Sale", "")
                try:
                    price = float((row.get("Item Price") or "0").replace(",", ""))
                except ValueError:
                    price = 0.0
                rate = fx.get(cur)
                if rate is None:
                    missing_fx.add(cur)
                    rate = 0.0
                e = per.setdefault(pkg, {"sales": two(), "gross_try": two(), "net_try": two(), "refunds": two(), "items": {"cur": [], "prev": []}})
                status = (row.get("Financial Status") or "").lower()
                if "refund" in status:
                    e["refunds"][k] += 1
                    continue
                if status and status not in ("charged", "complete", "completed"):
                    continue
                e["sales"][k] += 1
                e["gross_try"][k] += price * rate
                e["net_try"][k] += price * rate * (1 - fee)
                e["items"][k].append("%s %s %.2f" % (row.get("SKU ID", "?"), cur, price))
    if missing_fx:
        note("No FX rate for %s - those sales count as 0 TL" % ", ".join(sorted(missing_fx)))
    # the newest Google earnings report (monthly, net TRY actually paid out) when it exists
    earnings = {"month": None, "per": {}}
    try:
        files = gcs_list(s, bucket, "earnings/earnings_")
        if files:
            newest = max(files, key=lambda o: o["name"].split("_")[1])
            month = newest["name"].split("_")[1]
            for it in [f for f in files if f["name"].split("_")[1] == month]:
                for row in _zip_csv_rows(gcs_get(s, bucket, it["name"])):
                    pkg = row.get("Package ID") or row.get("Product id") or ""
                    try:
                        amt = float((row.get("Amount (Merchant Currency)") or "0").replace(",", ""))
                    except ValueError:
                        amt = 0.0
                    earnings["per"][pkg] = earnings["per"].get(pkg, 0.0) + amt
            earnings["month"] = month
    except Exception as e:
        note("Play earnings report read failed (%s)" % _short_err(e))
    return {"per": per, "earnings": earnings}


# ---------------------------------------------------------------- Play vitals

def _pdate(d: dt.date) -> dict:
    return {"year": d.year, "month": d.month, "day": d.day, "timeZone": PLAY_TZ}


def _interval(st: dt.date, ed_excl: dt.date) -> dict:
    return {"interval.startTime.year": st.year, "interval.startTime.month": st.month, "interval.startTime.day": st.day,
            "interval.endTime.year": ed_excl.year, "interval.endTime.month": ed_excl.month, "interval.endTime.day": ed_excl.day}


def _pcall(s: AuthorizedSession, method: str, url: str, **kw) -> dict:
    last = ""
    for i in range(4):
        r = s.request(method, url, timeout=60, **kw)
        if r.status_code in (429, 500, 503):
            last = "HTTP %s" % r.status_code
            time.sleep(2 * (i + 1))
            continue
        if r.status_code != 200:
            raise RuntimeError("HTTP %s %s" % (r.status_code, r.text[:160]))
        return r.json()
    raise RuntimeError(last + " after retries")


def fetch_vitals(s: AuthorizedSession, pkg: str, w: Win) -> dict:
    out = {"crash": {"cur": None, "prev": None}, "anr": {"cur": None, "prev": None},
           "reports": {"cur": {"CRASH": 0, "APPLICATION_NOT_RESPONDING": 0}, "prev": {"CRASH": 0, "APPLICATION_NOT_RESPONDING": 0}},
           "issues_cur": {}, "prior_issue_ids": set()}
    for ms, metric in (("crashRateMetricSet", "crash"), ("anrRateMetricSet", "anr")):
        body = {"timelineSpec": {"aggregationPeriod": "DAILY", "startTime": _pdate(w.pstart), "endTime": _pdate(w.end)},
                "metrics": [metric + "Rate", "distinctUsers"], "pageSize": 200}
        r = _pcall(s, "POST", PLAY_API % pkg + "/%s:query" % ms, json=body)
        acc = {"cur": [0.0, 0.0], "prev": [0.0, 0.0]}
        for row in r.get("rows", []):
            st = row["startTime"]
            k = w.which(dt.date(st["year"], st["month"], st["day"]))
            if not k:
                continue
            m = {x["metric"]: float(x.get("decimalValue", {}).get("value", 0) or 0) for x in row.get("metrics", [])}
            users = m.get("distinctUsers", 0)
            acc[k][0] += m.get(metric + "Rate", 0) * users
            acc[k][1] += users
        for k in ("cur", "prev"):
            if acc[k][1]:
                out[metric][k] = 100.0 * acc[k][0] / acc[k][1]
    # every error report of the two weeks (type, issue, build)
    tok = None
    params = dict(_interval(w.pstart, w.end + dt.timedelta(days=1)), pageSize=100)
    for _ in range(20):
        if tok:
            params["pageToken"] = tok
        r = _pcall(s, "GET", PLAY_API % pkg + "/errorReports:search", params=params)
        for rep in r.get("errorReports", []):
            k = w.which(rep.get("eventTime", "")[:10])
            if not k:
                continue
            t = rep.get("type", "")
            out["reports"][k][t] = out["reports"][k].get(t, 0) + 1
            if k == "cur":
                iid = rep.get("issue", "").split("/")[-1]
                e = out["issues_cur"].setdefault(iid, {"type": t, "count": 0, "versions": set(), "cause": "", "location": ""})
                e["count"] += 1
                e["versions"].add(str((rep.get("appVersion") or {}).get("versionCode", "")))
        tok = r.get("nextPageToken")
        if not tok:
            break
    # issues seen before this week (up to 60 days back) -> anything else is NEW
    st = w.start - dt.timedelta(days=60)
    params = dict(_interval(st, w.start), pageSize=50)
    tok = None
    for _ in range(10):
        if tok:
            params["pageToken"] = tok
        try:
            r = _pcall(s, "GET", PLAY_API % pkg + "/errorIssues:search", params=params)
        except RuntimeError:
            params.update(_interval(w.start - dt.timedelta(days=28), w.start))
            r = _pcall(s, "GET", PLAY_API % pkg + "/errorIssues:search", params=params)
        for i in r.get("errorIssues", []):
            out["prior_issue_ids"].add(i["name"].split("/")[-1])
        tok = r.get("nextPageToken")
        if not tok:
            break
    # cause/location text for this week's issues
    if out["issues_cur"]:
        params = dict(_interval(w.start, w.end + dt.timedelta(days=1)), pageSize=50)
        r = _pcall(s, "GET", PLAY_API % pkg + "/errorIssues:search", params=params)
        for i in r.get("errorIssues", []):
            iid = i["name"].split("/")[-1]
            if iid in out["issues_cur"]:
                out["issues_cur"][iid]["cause"] = i.get("cause", "")
                out["issues_cur"][iid]["location"] = i.get("location", "")
    return out


# ---------------------------------------------------------------- first-party analytics

class Analytics:
    def __init__(self):
        self.base = setting("weekly_report.analytics_url", "ANALYTICS_URL", "https://analytics.lifecharger.workers.dev").rstrip("/")
        kf = setting("weekly_report.analytics_key_file", "ANALYTICS_ADMIN_KEY_FILE", keys_dir_file("analytics_admin_key.txt"))
        if not kf or not os.path.isfile(kf):
            raise RuntimeError("analytics admin key file not found (weekly_report.analytics_key_file)")
        self.h = {"X-Admin-Key": Path(kf).read_text(encoding="utf-8").strip()}

    def get(self, rep: str, **params) -> dict:
        last = None
        for i in range(3):
            try:
                r = requests.get(self.base + "/report/" + rep, headers=self.h, params=params, timeout=120)
                if r.status_code == 200:
                    return r.json()
                last = RuntimeError("HTTP %s %s" % (r.status_code, r.text[:160]))
            except requests.RequestException as e:
                last = e
            time.sleep(3 * (i + 1))
        raise last


def days_since(d: dt.date) -> int:
    return (dt.datetime.now(dt.timezone.utc).date() - d).days + 1


def fetch_analytics(an: Analytics, pkg: str, w: Win, usage_builds: int, health_builds: int) -> dict:
    n_all = days_since(w.pstart)
    ov = an.get("overview", app=pkg, days=n_all, builds=usage_builds)
    ret = an.get("retention", app=pkg, days=n_all + 1, builds=usage_builds)
    stab = an.get("stability", app=pkg, days=n_all, builds=health_builds, limit=100)
    n_cur = days_since(w.start)
    err_cur_new = an.get("stability", app=pkg, days=n_cur, builds=health_builds, limit=500)
    err_cur_all = an.get("stability", app=pkg, days=n_cur, builds=0, limit=500)
    err_hist = an.get("stability", app=pkg, days=n_cur + 35, builds=0, limit=500)

    u = {k: {"new": 0, "dau_sum": 0, "days": 0, "sessions": 0, "seconds": 0} for k in ("cur", "prev")}
    for r in ov.get("rows", []):
        k = w.which(r["day"])
        if k:
            u[k]["new"] += r.get("new_installs") or 0
            u[k]["dau_sum"] += r.get("dau") or 0
            u[k]["sessions"] += r.get("sessions") or 0
            u[k]["seconds"] += r.get("seconds") or 0
    # D1: cohorts whose next day is complete inside the window (the window's last cohort returns "today")
    d1 = {k: [0, 0] for k in ("cur", "prev")}
    for r in ret.get("rows", []):
        day = dt.date.fromisoformat(r["cohort"])
        k = w.which(day)
        if not k or day >= (w.end if k == "cur" else w.pend):
            continue
        d1[k][0] += r.get("d1") or 0
        d1[k][1] += r.get("size") or 0
    h = {k: {"sessions": 0, "unclean": 0, "errors": 0, "stalls": 0, "freezes": 0} for k in ("cur", "prev")}
    for r in stab.get("daily", []):
        k = w.which(r["day"])
        if k:
            h[k]["sessions"] += r.get("sessions") or 0
            h[k]["unclean"] += r.get("unclean_exits") or 0
            h[k]["errors"] += r.get("errors") or 0
            h[k]["stalls"] += r.get("stalls") or 0
            h[k]["freezes"] += r.get("anr_class_stalls") or 0
    # a signature is NEW when every sighting of the last 35+ days falls in this week
    def by_sig(rows):
        o: dict = {}
        for e in rows:
            s = e.get("signature") or "?"
            o[s] = o.get(s, 0) + (e.get("count") or 0)
        return o
    cur_all, hist = by_sig(err_cur_all.get("errors", [])), by_sig(err_hist.get("errors", []))
    new_sigs = []
    for e in err_cur_new.get("errors", []):
        s = e.get("signature") or "?"
        if hist.get(s, 0) <= cur_all.get(s, 0) and s not in [x["signature"] for x in new_sigs]:
            new_sigs.append({"signature": s, "version": e.get("version"), "count": cur_all.get(s, 0), "installs": e.get("installs")})
    top_errors = sorted(by_sig(err_cur_new.get("errors", [])).items(), key=lambda x: -x[1])[:5]
    return {"usage": u, "d1": d1, "health": h, "by_version": stab.get("by_version", [])[:6],
            "build_versions": stab.get("build_versions") or [], "new_sigs": new_sigs, "top_errors": top_errors}


# ---------------------------------------------------------------- assemble + rules

def pct(a, b):
    if a is None or b in (None, 0):
        return None
    return 100.0 * (a - b) / b


def ratio(a, b):
    return (a / b) if b else None


def build_rows(c: dict, w: Win, src: dict) -> list[dict]:
    rows = []
    ads_by_pkg: dict = {}
    for camp in (src.get("ads") or {}).get("campaigns", []):
        ads_by_pkg.setdefault(camp["package"], []).append(camp)
    for app in c["apps"]:
        pkg = app["package"]
        camps = ads_by_pkg.get(pkg, [])
        spend = {k: sum(x["spend"][k] for x in camps) for k in ("cur", "prev")}
        inst = {k: sum(x["installs"][k] for x in camps) for k in ("cur", "prev")}
        am = (src.get("admob") or {}).get(pkg)
        pm = ((src.get("play") or {}).get("per") or {}).get(pkg)
        an = (src.get("analytics") or {}).get(pkg)
        vi = (src.get("vitals") or {}).get(pkg)
        row = {"app": app, "camps": camps, "spend": spend, "installs": inst,
               "cpi": {k: ratio(spend[k], inst[k]) for k in ("cur", "prev")},
               "admob": {k: (am["earnings"][k] if am else 0.0) for k in ("cur", "prev")},
               "admob_impr": {k: (am["impressions"][k] if am else 0) for k in ("cur", "prev")},
               "match": {k: (100.0 * am["matched"][k] / am["requests"][k] if am and am["requests"][k] else None) for k in ("cur", "prev")},
               "sales": {k: (pm["sales"][k] if pm else 0) for k in ("cur", "prev")},
               "purch": {k: (pm["net_try"][k] if pm else 0.0) for k in ("cur", "prev")},
               "sale_items": (pm["items"]["cur"] if pm else []),
               "refunds": (pm["refunds"]["cur"] if pm else 0),
               "an": an, "vi": vi}
        row["money_in"] = {k: row["admob"][k] + row["purch"][k] for k in ("cur", "prev")}
        row["roi"] = {k: ratio(row["money_in"][k], spend[k]) for k in ("cur", "prev")}
        if an:
            u = an["usage"]
            row["new"] = {k: u[k]["new"] for k in ("cur", "prev")}
            row["dau"] = {k: u[k]["dau_sum"] / 7.0 for k in ("cur", "prev")}
            row["sess"] = {k: (u[k]["seconds"] / u[k]["sessions"] / 60.0 if u[k]["sessions"] else None) for k in ("cur", "prev")}
            row["d1"] = {k: (100.0 * an["d1"][k][0] / an["d1"][k][1] if an["d1"][k][1] else None) for k in ("cur", "prev")}
            row["d1_n"] = {k: an["d1"][k][1] for k in ("cur", "prev")}
            hh = an["health"]
            row["abn"] = {k: (100.0 * hh[k]["unclean"] / hh[k]["sessions"] if hh[k]["sessions"] else None) for k in ("cur", "prev")}
            row["sessions_h"] = {k: hh[k]["sessions"] for k in ("cur", "prev")}
            row["freezes"] = {k: hh[k]["freezes"] for k in ("cur", "prev")}
            row["errors"] = {k: hh[k]["errors"] for k in ("cur", "prev")}
        if vi:
            row["crash"] = vi["crash"]
            row["anr"] = vi["anr"]
            row["play_crashes"] = {k: vi["reports"][k].get("CRASH", 0) for k in ("cur", "prev")}
            row["play_anrs"] = {k: vi["reports"][k].get("APPLICATION_NOT_RESPONDING", 0) for k in ("cur", "prev")}
        rows.append(row)
    return rows


def newest_codes(row) -> set:
    an = row.get("an") or {}
    return {v.split("+")[-1] for v in an.get("build_versions", []) if "+" in v}


def apply_rules(c: dict, rows: list[dict], src: dict) -> None:
    t = c["thresholds"]
    for r in rows:
        flags = []  # (level, text)  level: red | amber | info
        util = r["app"]["group"] == "utility"
        name = r["app"]["name"]
        if not util:
            for camp in r["camps"]:
                cpi_c, cpi_p = ratio(camp["spend"]["cur"], camp["installs"]["cur"]), ratio(camp["spend"]["prev"], camp["installs"]["prev"])
                ch = pct(cpi_c, cpi_p)
                if ch is not None and ch > t["cpi_rise_pct"]:
                    flags.append(("amber", "Campaign \"%s\": cost per install rose %+.0f%% (%.2f -> %.2f TL)." % (camp["name"], ch, cpi_p, cpi_c)))
                if camp["status"] == "ENABLED" and camp["budget"] and camp["spend"]["cur"] < camp["budget"] * 7 * t["underspend_pct"] / 100.0:
                    flags.append(("info", "Campaign \"%s\" spent %.0f of a possible %.0f TL at today's budget (%.0f%%) - the bid (tCPI) may be too low to use the budget." % (
                        camp["name"], camp["spend"]["cur"], camp["budget"] * 7, 100 * camp["spend"]["cur"] / (camp["budget"] * 7))))
            if r["spend"]["cur"] > 0 and r["roi"]["cur"] is not None and r["roi"]["cur"] < t["money_ratio_min"]:
                flags.append(("red", "%s earned %.0f TL (ads + purchases) on %.0f TL ad spend = %.2fx - it is losing money on the campaign." % (
                    name, r["money_in"]["cur"], r["spend"]["cur"], r["roi"]["cur"])))
            ch = pct(r["admob"]["cur"], r["admob"]["prev"])
            if r["admob"]["prev"] >= t["admob_min_prev"] and ch is not None and ch < -t["admob_drop_pct"]:
                flags.append(("amber", "AdMob earnings fell %.0f%% (%.0f -> %.0f TL)." % (-ch, r["admob"]["prev"], r["admob"]["cur"])))
        if r.get("d1") and r["d1"]["cur"] is not None and r["d1"]["prev"] is not None and min(r["d1_n"].values()) >= t["d1_min_cohort"]:
            if r["d1"]["prev"] - r["d1"]["cur"] >= t["d1_drop_points"]:
                flags.append(("amber", "Day-1 return fell from %.1f%% to %.1f%% (new players coming back the next day)." % (r["d1"]["prev"], r["d1"]["cur"])))
        if r.get("crash") and r["crash"]["cur"] is not None and r["crash"]["cur"] > t["crash_rate_max_pct"]:
            flags.append(("red", "Google Play crash rate is %.2f%% (limit %.1f%%)." % (r["crash"]["cur"], t["crash_rate_max_pct"])))
        if r.get("anr") and r["anr"]["cur"] is not None and r["anr"]["cur"] > t["anr_rate_max_pct"]:
            flags.append(("red", "Google Play ANR (freeze) rate is %.2f%% (Play's bad-behaviour line is %.2f%%)." % (r["anr"]["cur"], t["anr_rate_max_pct"])))
        if r.get("abn") and r["abn"]["cur"] is not None and r["sessions_h"]["cur"] >= t["min_sessions_for_rate"] and r["abn"]["cur"] > t["abnormal_end_max_pct"]:
            flags.append(("amber", "%.1f%% of sessions on the newest builds ended abnormally (app died on screen), %d sessions." % (r["abn"]["cur"], r["sessions_h"]["cur"])))
        vi = r.get("vi")
        if vi:
            codes = newest_codes(r)
            older = []
            for iid, e in sorted(vi["issues_cur"].items(), key=lambda x: -x[1]["count"]):
                if iid in vi["prior_issue_ids"]:
                    continue
                # on one of the newest builds -> act, one flag each; on an older build (often the one
                # most players still run) -> one "watch" line per app, the details as info
                on_new = (not codes) or bool(e["versions"] & codes)
                kind = "crash" if e["type"] == "CRASH" else "ANR / freeze"
                text = "NEW %s on Google Play (%sbuild %s, %d report%s): %s%s" % (
                    kind, "" if on_new else "older ", ",".join(sorted(e["versions"])), e["count"], "" if e["count"] == 1 else "s",
                    (e["cause"] or "?")[:110], (" @ " + e["location"][:60]) if e["location"] else "")
                flags.append(("red" if on_new else "info", text))
                if not on_new:
                    older.append(e)
            if older:
                vers = sorted({v for e in older for v in e["versions"]})
                n_crash = sum(1 for e in older if e["type"] == "CRASH")
                flags.append(("amber", "%d new Google Play signature%s on older build %s (%d crash, %d ANR, %d reports) - check whether the current code still has them (details in the report)." % (
                    len(older), "" if len(older) == 1 else "s", ",".join(vers), n_crash, len(older) - n_crash, sum(e["count"] for e in older))))
        an = r.get("an")
        if an:
            for s in an["new_sigs"][:5]:
                flags.append(("red", "NEW in-app error on build %s (%d time%s): %s" % (s["version"], s["count"], "" if s["count"] == 1 else "s", s["signature"][:120])))
        r["flags"] = flags


def experiment_status(c: dict, rows: list[dict]) -> list[dict]:
    ex = c.get("experiment") or {}
    tg = ex.get("targets", {})
    by = {r["app"]["package"]: r for r in rows}
    out = []
    for cp in ex.get("campaigns", []):
        r = by.get(cp["package"])
        if not r:
            continue
        live_budget = sum(x["budget"] for x in r["camps"] if x["status"] == "ENABLED")
        cpi = r["cpi"]["cur"]
        ads_day = r["admob"]["cur"] / 7.0
        d1 = (r.get("d1") or {}).get("cur")
        sales = r["sales"]["cur"]
        checks = [
            ("CPI < %s TL" % tg.get("cpi_max"), cpi is not None and cpi < tg.get("cpi_max", 0), "%.2f TL" % cpi if cpi is not None else "no installs"),
            ("AdMob > %s TL/day" % tg.get("admob_per_day_min"), ads_day > tg.get("admob_per_day_min", 0), "%.1f TL/day" % ads_day),
            ("D1 > %s%%" % tg.get("d1_min_pct"), d1 is not None and d1 > tg.get("d1_min_pct", 0), "%.1f%%" % d1 if d1 is not None else "n/a"),
            (">= %s sale/week" % tg.get("sales_per_week_min"), sales >= tg.get("sales_per_week_min", 0), "%d" % sales),
        ]
        out.append({"name": r["app"]["name"], "planned": cp.get("budget_per_day"), "live": live_budget,
                    "spend_day": r["spend"]["cur"] / 7.0, "checks": checks, "passed": sum(1 for x in checks if x[1])})
    return out


# ---------------------------------------------------------------- formatting

def tl(v, dec=0):
    if v is None:
        return "-"
    return ("{:,.%df} TL" % dec).format(v)


def num(v, dec=0):
    if v is None:
        return "-"
    return ("{:,.%df}" % dec).format(v)


def pc(v, dec=1):
    return "-" if v is None else ("%.*f%%" % (dec, v))


def delta(cur, prev, invert=False, points=False):
    """(text, css class) for a change; invert=True when lower is better."""
    if cur is None or prev is None:
        return "", ""
    if points:
        d = cur - prev
        if abs(d) < 0.05:
            return "±0", "flat"
        good = (d < 0) if invert else (d > 0)
        return "%+.1f pt" % d, "good" if good else "bad"
    if prev == 0:
        return ("new", "flat") if cur else ("", "")
    d = 100.0 * (cur - prev) / prev
    if abs(d) < 0.5:
        return "±0%", "flat"
    good = (d < 0) if invert else (d > 0)
    return "%+.0f%%" % d, "good" if good else "bad"


def totals(rows, grp=None):
    rs = [r for r in rows if grp is None or r["app"]["group"] == grp]
    t = {}
    for key in ("spend", "installs", "admob", "purch", "money_in", "sales"):
        t[key] = {k: sum(r[key][k] for r in rs) for k in ("cur", "prev")}
    for key in ("new", "dau"):
        t[key] = {k: sum((r.get(key) or {}).get(k, 0) or 0 for r in rs) for k in ("cur", "prev")}
    t["cpi"] = {k: ratio(t["spend"][k], t["installs"][k]) for k in ("cur", "prev")}
    t["roi"] = {k: ratio(t["money_in"][k], t["spend"][k]) for k in ("cur", "prev")}
    return t


def metric_lines(r: dict, money: bool) -> list[tuple]:
    """(label, cur text, prev text, (delta text, cls))"""
    L = []
    if money:
        if r["camps"] or r["spend"]["prev"]:
            L.append(("Ad spend", tl(r["spend"]["cur"]), tl(r["spend"]["prev"]), delta(r["spend"]["cur"], r["spend"]["prev"], invert=True)))
            L.append(("Installs (Ads)", num(r["installs"]["cur"]), num(r["installs"]["prev"]), delta(r["installs"]["cur"], r["installs"]["prev"])))
            L.append(("Cost per install", tl(r["cpi"]["cur"], 2), tl(r["cpi"]["prev"], 2), delta(r["cpi"]["cur"], r["cpi"]["prev"], invert=True)))
        L.append(("AdMob earnings", tl(r["admob"]["cur"]), tl(r["admob"]["prev"]), delta(r["admob"]["cur"], r["admob"]["prev"])))
        if r["admob_impr"]["cur"] or r["admob_impr"]["prev"]:
            L.append(("Ad impressions", num(r["admob_impr"]["cur"]), num(r["admob_impr"]["prev"]), delta(r["admob_impr"]["cur"], r["admob_impr"]["prev"])))
            L.append(("Ad match rate", pc(r["match"]["cur"]), pc(r["match"]["prev"]), delta(r["match"]["cur"], r["match"]["prev"], points=True)))
        L.append(("Purchases (net)", "%s (%d)" % (tl(r["purch"]["cur"]), r["sales"]["cur"]), "%s (%d)" % (tl(r["purch"]["prev"]), r["sales"]["prev"]),
                  delta(r["purch"]["cur"], r["purch"]["prev"])))
        if r["spend"]["cur"] or r["spend"]["prev"]:
            L.append(("Money in / ad spend", "%s = %s" % (tl(r["money_in"]["cur"]), ("%.2fx" % r["roi"]["cur"]) if r["roi"]["cur"] is not None else "-"),
                      "%s = %s" % (tl(r["money_in"]["prev"]), ("%.2fx" % r["roi"]["prev"]) if r["roi"]["prev"] is not None else "-"),
                      delta(r["roi"]["cur"], r["roi"]["prev"])))
        else:
            L.append(("Money in", tl(r["money_in"]["cur"]), tl(r["money_in"]["prev"]), delta(r["money_in"]["cur"], r["money_in"]["prev"])))
    if r.get("an"):
        L.append(("New players", num(r["new"]["cur"]), num(r["new"]["prev"]), delta(r["new"]["cur"], r["new"]["prev"])))
        L.append(("Daily active (avg)", num(r["dau"]["cur"], 1), num(r["dau"]["prev"], 1), delta(r["dau"]["cur"], r["dau"]["prev"])))
        L.append(("Avg session", ("%.1f min" % r["sess"]["cur"]) if r["sess"]["cur"] else "-", ("%.1f min" % r["sess"]["prev"]) if r["sess"]["prev"] else "-",
                  delta(r["sess"]["cur"], r["sess"]["prev"])))
        L.append(("Day-1 return", "%s (of %d)" % (pc(r["d1"]["cur"]), r["d1_n"]["cur"]), "%s (of %d)" % (pc(r["d1"]["prev"]), r["d1_n"]["prev"]),
                  delta(r["d1"]["cur"], r["d1"]["prev"], points=True)))
    if r.get("vi"):
        L.append(("Play crash rate", pc(r["crash"]["cur"], 2) if r["crash"]["cur"] is not None else "too few users",
                  pc(r["crash"]["prev"], 2) if r["crash"]["prev"] is not None else "too few users", delta(r["crash"]["cur"], r["crash"]["prev"], invert=True, points=True)))
        L.append(("Play ANR rate", pc(r["anr"]["cur"], 2) if r["anr"]["cur"] is not None else "too few users",
                  pc(r["anr"]["prev"], 2) if r["anr"]["prev"] is not None else "too few users", delta(r["anr"]["cur"], r["anr"]["prev"], invert=True, points=True)))
        L.append(("Play crash / ANR reports", "%d / %d" % (r["play_crashes"]["cur"], r["play_anrs"]["cur"]),
                  "%d / %d" % (r["play_crashes"]["prev"], r["play_anrs"]["prev"]), ("", "")))
    if r.get("an"):
        L.append(("Abnormal ends (newest builds)", "%s of %d sess." % (pc(r["abn"]["cur"]), r["sessions_h"]["cur"]),
                  "%s of %d sess." % (pc(r["abn"]["prev"]), r["sessions_h"]["prev"]), delta(r["abn"]["cur"], r["abn"]["prev"], invert=True, points=True)))
        L.append(("Freezes 5s+ / app errors", "%d / %d" % (r["freezes"]["cur"], r["errors"]["cur"]), "%d / %d" % (r["freezes"]["prev"], r["errors"]["prev"]), ("", "")))
    return L


def donations_line(r: dict) -> str:
    n = r["sales"]["cur"]
    if not n:
        return "Donations this week: none"
    return "Donations this week: %d (%s net)" % (n, tl(r["purch"]["cur"], 2))


def summary_text(c, w, rows, exp, report_path) -> str:
    t = totals(rows, "monetized")
    L = ["Weekly report %s (vs %s)" % (w.label(), w.plabel())]
    if t["spend"]["cur"] or t["spend"]["prev"]:
        L.append("Ads: spend %s (%s), installs %s (%s), CPI %s (%s)" % (
            tl(t["spend"]["cur"]), delta(t["spend"]["cur"], t["spend"]["prev"])[0] or "-",
            num(t["installs"]["cur"]), delta(t["installs"]["cur"], t["installs"]["prev"])[0] or "-",
            tl(t["cpi"]["cur"], 2), delta(t["cpi"]["cur"], t["cpi"]["prev"])[0] or "-"))
    L.append("Money in: AdMob %s (%s) + Play %s (%d sales) = %s%s" % (
        tl(t["admob"]["cur"]), delta(t["admob"]["cur"], t["admob"]["prev"])[0] or "-",
        tl(t["purch"]["cur"]), t["sales"]["cur"], tl(t["money_in"]["cur"]),
        (" = %.2fx ad spend" % t["roi"]["cur"]) if t["roi"]["cur"] is not None else ""))
    L.append("Players: %s new (%s), avg DAU %s (%s)" % (
        num(t["new"]["cur"]), delta(t["new"]["cur"], t["new"]["prev"])[0] or "-",
        num(t["dau"]["cur"]), delta(t["dau"]["cur"], t["dau"]["prev"])[0] or "-"))
    if exp:
        L.append("")
        L.append("%s (judge on %s):" % ((c.get("experiment") or {}).get("title", "Experiment"), (c.get("experiment") or {}).get("judge_on", "?")))
        for e in exp:
            L.append("- %s %d/4: %s" % (e["name"], e["passed"], "; ".join("%s %s %s" % (x[0], "OK" if x[1] else "MISS", x[2]) for x in e["checks"])))
    reds = [(r["app"]["name"], f) for r in rows for f in r["flags"] if f[0] == "red"]
    ambers = [(r["app"]["name"], f) for r in rows for f in r["flags"] if f[0] == "amber"]
    L.append("")
    if reds or ambers:
        L.append("Flags: %d act, %d watch" % (len(reds), len(ambers)))
        for n, f in (reds + ambers)[:12]:
            L.append("- [%s] %s: %s" % ("ACT" if f[0] == "red" else "watch", n, f[1]))
        if len(reds) + len(ambers) > 12:
            L.append("- ... %d more in the full report" % (len(reds) + len(ambers) - 12))
    else:
        L.append("Flags: none - all rules passed.")
    util = [r for r in rows if r["app"]["group"] == "utility"]
    if util:
        L.append("")
        L.append("Utility apps: " + "; ".join("%s %s new, %s" % (r["app"]["name"], num((r.get("new") or {}).get("cur")), donations_line(r).replace("Donations this week: ", "donations ")) for r in util))
    if NOTES:
        L.append("")
        L.append("Data gaps: " + " | ".join(NOTES[:5]))
    L.append("")
    L.append("Full report: " + str(report_path))
    return "\n".join(L)


CSS = """
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2230;--mute:#667085;--line:#e4e7ec;--good:#157f3b;--bad:#c0322b;--amber:#b86e00;--info:#3559c7;--chip:#eef1f6}
@media (prefers-color-scheme:dark){:root{--bg:#0f1218;--card:#181c24;--ink:#e8ebf1;--mute:#98a2b3;--line:#2a303c;--good:#4cc27a;--bad:#ff6b61;--amber:#f0a53a;--info:#7c9cff;--chip:#222836}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
main{max-width:860px;margin:0 auto;padding:16px}
h1{font-size:22px;margin:4px 0 2px}h2{font-size:17px;margin:26px 0 10px}h3{font-size:16px;margin:0}
.sub{color:var(--mute);font-size:13px}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;margin:10px 0}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:12px}
.kpi .l{font-size:12px;color:var(--mute)}.kpi .v{font-size:20px;font-weight:650;margin-top:2px}.kpi .d{font-size:12px}
.good{color:var(--good)}.bad{color:var(--bad)}.flat{color:var(--mute)}
.flag{padding:7px 10px;border-radius:8px;margin:5px 0;border-left:4px solid;background:var(--chip);font-size:14px}
.flag.red{border-color:var(--bad)}.flag.amber{border-color:var(--amber)}.flag.info{border-color:var(--info)}
.tag{display:inline-block;font-size:11px;font-weight:650;padding:1px 7px;border-radius:99px;background:var(--chip);color:var(--mute);margin-left:6px;vertical-align:2px}
.tw{overflow-x:auto;-webkit-overflow-scrolling:touch}
table{border-collapse:collapse;width:100%;font-size:14px}
th,td{padding:6px 8px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left;white-space:normal}
th{font-size:12px;color:var(--mute);font-weight:600}
.ok{color:var(--good);font-weight:650}.miss{color:var(--bad);font-weight:650}
.small{font-size:13px;color:var(--mute)}
details summary{cursor:pointer;color:var(--mute);font-size:13px;margin-top:8px}
"""


def e(s) -> str:
    return html.escape(str(s))


def render_html(c, w, rows, exp, src, generated) -> str:
    t = totals(rows, "monetized")
    P = ["<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>Weekly Report %s</title><style>%s</style></head><body><main>" % (e(w.end), CSS)]
    P.append("<h1>Weekly report</h1><div class='sub'>Last 7 days %s &nbsp;vs&nbsp; previous %s &middot; generated %s</div>" % (e(w.label()), e(w.plabel()), e(generated)))

    def kpi(label, cur, prev, fmt, invert=False, sub=""):
        d, cls = delta(cur, prev, invert=invert)
        return "<div class='kpi'><div class='l'>%s</div><div class='v'>%s</div><div class='d %s'>%s</div>%s</div>" % (
            e(label), e(fmt(cur)), cls, e(("%s vs %s" % (d, fmt(prev))) if d else "vs " + fmt(prev)), sub)
    P.append("<h2>Money (monetized apps)</h2><div class='kpis'>")
    P.append(kpi("Ad spend", t["spend"]["cur"], t["spend"]["prev"], tl, invert=True))
    P.append(kpi("Installs from Ads", t["installs"]["cur"], t["installs"]["prev"], num))
    P.append(kpi("Cost per install", t["cpi"]["cur"], t["cpi"]["prev"], lambda v: tl(v, 2), invert=True))
    P.append(kpi("AdMob earnings", t["admob"]["cur"], t["admob"]["prev"], tl))
    P.append(kpi("Play purchases (net)", t["purch"]["cur"], t["purch"]["prev"], tl))
    P.append(kpi("Money in / ad spend", t["roi"]["cur"], t["roi"]["prev"], lambda v: "-" if v is None else "%.2fx" % v))
    P.append(kpi("New players", t["new"]["cur"], t["new"]["prev"], num))
    P.append(kpi("Daily active (sum of apps)", t["dau"]["cur"], t["dau"]["prev"], num))
    P.append("</div>")

    # flags
    allf = [(r["app"]["name"], f) for r in rows for f in r["flags"]]
    order = {"red": 0, "amber": 1, "info": 2}
    allf.sort(key=lambda x: order[x[1][0]])
    P.append("<h2>Flags</h2><div class='card'>")
    if not allf:
        P.append("<div class='small'>No rule fired - everything is inside the limits.</div>")
    for n, (lvl, txt) in allf:
        P.append("<div class='flag %s'><b>%s</b> %s</div>" % (lvl, e(n), e(txt)))
    P.append("<div class='small' style='margin-top:8px'>Red = act now, amber = watch, blue = info.</div></div>")

    # experiment
    ex = c.get("experiment") or {}
    if exp:
        P.append("<h2>%s</h2><div class='card'><div class='small'>Started %s, judge on %s. %s</div><div class='tw'><table><tr><th>Campaign</th><th>Budget/day plan / live</th><th>Spend/day</th>" % (
            e(ex.get("title", "Experiment")), e(ex.get("started", "?")), e(ex.get("judge_on", "?")), e(ex.get("note", ""))))
        for x in exp[0]["checks"]:
            P.append("<th>%s</th>" % e(x[0]))
        P.append("<th>Score</th></tr>")
        for x in exp:
            P.append("<tr><td>%s</td><td>%s / %s</td><td>%s</td>" % (e(x["name"]), e(num(x["planned"])), e(num(x["live"])), e(tl(x["spend_day"]))))
            for ck in x["checks"]:
                P.append("<td><span class='%s'>%s</span> %s</td>" % ("ok" if ck[1] else "miss", "OK" if ck[1] else "MISS", e(ck[2])))
            P.append("<td>%d/4</td></tr>" % x["passed"])
        P.append("</table></div></div>")

    def app_card(r, money):
        a = r["app"]
        P.append("<div class='card'><h3>%s<span class='tag'>%s</span></h3>" % (e(a["name"]), e(a.get("track", ""))))
        if r["flags"]:
            for lvl, txt in r["flags"]:
                P.append("<div class='flag %s'>%s</div>" % (lvl, e(txt)))
        if not money:
            P.append("<div class='small' style='margin:6px 0'>%s</div>" % e(donations_line(r)))
        P.append("<div class='tw'><table><tr><th>Metric</th><th>Last 7 d</th><th>Prev 7 d</th><th>Change</th></tr>")
        for lab, cur, prev, (dtxt, cls) in metric_lines(r, money):
            P.append("<tr><td>%s</td><td>%s</td><td>%s</td><td class='%s'>%s</td></tr>" % (e(lab), e(cur), e(prev), cls, e(dtxt)))
        P.append("</table></div>")
        if money and r["camps"]:
            P.append("<details><summary>Campaigns</summary><div class='tw'><table><tr><th>Campaign</th><th>Budget/day</th><th>Spend</th><th>Installs</th><th>CPI</th><th>Impr.</th><th>Clicks</th></tr>")
            for cp in r["camps"]:
                P.append("<tr><td>%s (%s)</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
                    e(cp["name"]), e(cp["status"].lower()), e(tl(cp["budget"])), e(tl(cp["spend"]["cur"])), e(num(cp["installs"]["cur"])),
                    e(tl(ratio(cp["spend"]["cur"], cp["installs"]["cur"]), 2)), e(num(cp["impressions"]["cur"])), e(num(cp["clicks"]["cur"]))))
            P.append("</table></div></details>")
        if money and r["sale_items"]:
            P.append("<details><summary>Purchases this week (%d)</summary><div class='small'>%s</div></details>" % (len(r["sale_items"]), e(", ".join(r["sale_items"]))))
        an = r.get("an")
        if an and (an["by_version"] or an["top_errors"]):
            P.append("<details><summary>Health by build (newest builds, last 14 days)</summary><div class='tw'><table><tr><th>Build</th><th>Sessions</th><th>Abnormal ends</th><th>Crash-free</th><th>Freezes</th><th>Errors</th></tr>")
            for v in an["by_version"]:
                P.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
                    e(v.get("version")), e(num(v.get("sessions"))), e(num(v.get("unclean_exits"))), e(pc(v.get("crash_free_pct"))), e(num(v.get("stalls"))), e(num(v.get("errors")))))
            P.append("</table></div>")
            if an["top_errors"]:
                P.append("<div class='small'>Top in-app errors this week: %s</div>" % e("; ".join("%s x%d" % (s[:80], n) for s, n in an["top_errors"])))
            P.append("</details>")
        P.append("</div>")

    mon = [r for r in rows if r["app"]["group"] != "utility"]
    mon.sort(key=lambda r: -(r["money_in"]["cur"] + r["spend"]["cur"]))
    P.append("<h2>Apps</h2>")
    for r in mon:
        app_card(r, True)
    util = [r for r in rows if r["app"]["group"] == "utility"]
    if util:
        P.append("<h2>Utility / not monetized</h2><div class='small'>Judged on usage and health only; donations shown for information.</div>")
        for r in util:
            app_card(r, False)

    earn = (src.get("play") or {}).get("earnings") or {}
    if earn.get("month") and earn.get("per"):
        P.append("<h2>Google Play earnings report %s-%s</h2><div class='card'><div class='tw'><table><tr><th>App</th><th>Net (TRY)</th></tr>" % (e(earn["month"][:4]), e(earn["month"][4:])))
        names = {a["package"]: a["name"] for a in c["apps"]}
        for pkg, amt in sorted(earn["per"].items(), key=lambda x: -x[1]):
            P.append("<tr><td>%s</td><td>%s</td></tr>" % (e(names.get(pkg, pkg)), e(tl(amt, 2))))
        P.append("<tr><td><b>Total</b></td><td><b>%s</b></td></tr></table></div><div class='small'>Google's monthly payout report (after fees, taxes, refunds). Appears a few days after the month ends.</div></div>" % e(tl(sum(earn["per"].values()), 2)))

    P.append("<h2>How to read this</h2><div class='card small'>")
    P.append("<p>Money: Google Ads spend and conversions (installs) per campaign; AdMob estimated earnings in TRY; Play purchases from the daily sales report, item price without tax converted to TRY at today's rate, minus the %d%% Play fee. Money in = AdMob + purchases.</p>" % cfg().get("play_fee_pct", 15))
    P.append("<p>Players: first-party analytics, all builds, test robots excluded. Day-1 return = share of a day's new players who came back the next day (cohorts whose next day is complete). Health: Google Play Vitals (crash / ANR rate is only published on days with enough users) and in-app abnormal ends / freezes / errors on each app's newest %d builds. A crash is NEW when it has no report in the 60 days before this week (Play) or 35 days (in-app).</p>" % c.get("health_builds", 5))
    th = c["thresholds"]
    P.append("<p>Rules: CPI up &gt;%d%%; money in / ad spend &lt; %.1f; AdMob down &gt;%d%% (from at least %d TL); Day-1 return down %d+ points (cohorts of %d+); Play crash rate &gt; %.1f%%; ANR &gt; %.2f%%; abnormal ends &gt; %.1f%% (%d+ sessions); any new crash signature on the newest builds; campaign spending under %d%% of its budget. Utility apps are never judged on money.</p>" % (
        th["cpi_rise_pct"], th["money_ratio_min"], th["admob_drop_pct"], th["admob_min_prev"], th["d1_drop_points"], th["d1_min_cohort"],
        th["crash_rate_max_pct"], th["anr_rate_max_pct"], th["abnormal_end_max_pct"], th["min_sessions_for_rate"], th["underspend_pct"]))
    if NOTES:
        P.append("<p><b>Data gaps this run:</b></p><ul>%s</ul>" % "".join("<li>%s</li>" % e(n) for n in NOTES))
    P.append("</div></main></body></html>")
    return "\n".join(P)


def render_md(c, w, rows, exp, summary) -> str:
    L = ["# Weekly report %s" % w.label(), "", "Previous window: %s" % w.plabel(), "", "## Summary", "", "```", summary, "```", ""]
    for grp, title in (("monetized", "Apps"), ("utility", "Utility / not monetized")):
        rs = [r for r in rows if (r["app"]["group"] == "utility") == (grp == "utility")]
        if not rs:
            continue
        L += ["## " + title, ""]
        for r in rs:
            L += ["### %s (%s)" % (r["app"]["name"], r["app"].get("track", "")), ""]
            for lvl, txt in r["flags"]:
                L.append("- **%s** %s" % ({"red": "ACT", "amber": "WATCH", "info": "INFO"}[lvl], txt))
            if grp == "utility":
                L.append("- " + donations_line(r))
            if r["flags"] or grp == "utility":
                L.append("")
            L += ["| Metric | Last 7 d | Prev 7 d | Change |", "|---|---|---|---|"]
            for lab, cur, prev, (dtxt, _) in metric_lines(r, grp != "utility"):
                L.append("| %s | %s | %s | %s |" % (lab, cur, prev, dtxt))
            L.append("")
    if NOTES:
        L += ["## Data gaps", ""] + ["- " + n for n in NOTES] + [""]
    return "\n".join(L)


# ---------------------------------------------------------------- delivery (AGB task on the phone)

def deliver(title: str, text: str) -> str:
    key = setting("security.api_key", "AGB_API_KEY")
    port = setting("server.port", "", "8000")
    base = setting("weekly_report.agb_url", "AGB_URL", "http://localhost:%s" % port).rstrip("/")
    if not key:
        raise RuntimeError("AGB api key not set (security.api_key / AGB_API_KEY)")
    h = {"X-API-Key": key}
    apps = requests.get(base + "/api/apps", headers=h, timeout=30)
    apps.raise_for_status()
    agb = next((a for a in apps.json() if (a.get("package_name") or a.get("package")) == "com.lifecharger.appmanager"), None)
    if not agb:
        raise RuntimeError("Auto Game Builder app not found in /api/apps")
    aid = agb["id"]
    existing = requests.get(base + "/api/apps/%s/tasks" % aid, headers=h, timeout=30)
    existing.raise_for_status()
    same = next((t for t in existing.json() if t.get("title") == title), None)
    if same:
        tid = same["id"]
        r = requests.patch(base + "/api/apps/%s/tasks/%s" % (aid, tid), headers=h, timeout=30,
                           json={"description": text, "response": text, "status": "completed"})
        r.raise_for_status()
        return "updated AGB task #%s" % tid
    r = requests.post(base + "/api/apps/%s/tasks" % aid, headers=h, timeout=30,
                      json={"title": title, "description": text, "task_type": "issue", "priority": "normal"})
    r.raise_for_status()
    tid = r.json()["id"]
    # closed at once: it is a read-only report, no automation session should pick it up
    r = requests.patch(base + "/api/apps/%s/tasks/%s" % (aid, tid), headers=h, timeout=30,
                       json={"status": "completed", "response": text, "completed_by": "weekly_report"})
    r.raise_for_status()
    return "created AGB task #%s" % tid


# ---------------------------------------------------------------- main

def collect(c: dict, w: Win) -> dict:
    src: dict = {}
    pkgs = [a["package"] for a in c["apps"]]
    try:
        s = oauth_session()
        try:
            src["ads"] = fetch_ads(s, w)
        except Exception as e:
            note("Google Ads not read: " + _short_err(e))
        try:
            src["admob"] = fetch_admob(s, w)
        except Exception as e:
            note("AdMob not read: " + _short_err(e))
    except Exception as e:
        note("Google OAuth token failed, no Ads / AdMob data: " + _short_err(e))
    try:
        src["play"] = fetch_play_money(w)
    except Exception as e:
        note("Play sales not read: " + _short_err(e))
    try:
        an = Analytics()
        src["analytics"] = {}
        with cf.ThreadPoolExecutor(4) as ex:
            futs = {ex.submit(fetch_analytics, an, p, w, c.get("usage_builds", 0), c.get("health_builds", 5)): p for p in pkgs}
            for f in cf.as_completed(futs):
                p = futs[f]
                try:
                    src["analytics"][p] = f.result()
                except Exception as e:
                    note("Analytics for %s not read: %s" % (p.split(".")[-1], _short_err(e)))
    except Exception as e:
        note("Analytics not read: " + _short_err(e))
    try:
        vs = play_sa("https://www.googleapis.com/auth/playdeveloperreporting")
        src["vitals"] = {}
        with cf.ThreadPoolExecutor(3) as ex:
            futs = {ex.submit(fetch_vitals, vs, p, w): p for p in pkgs}
            for f in cf.as_completed(futs):
                p = futs[f]
                try:
                    src["vitals"][p] = f.result()
                except Exception as e:
                    note("Play vitals for %s not read: %s" % (p.split(".")[-1], _short_err(e)))
    except Exception as e:
        note("Play vitals not read: " + _short_err(e))
    return src


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--end", help="last day of the week (inclusive), default yesterday")
    ap.add_argument("--no-notify", action="store_true", help="write the report files only")
    a = ap.parse_args()
    end = dt.date.fromisoformat(a.end) if a.end else dt.date.today() - dt.timedelta(days=1)
    w = Win(end)
    c = cfg()
    out_dir = Path(setting("weekly_report.output_dir", "WEEKLY_REPORT_DIR", str(Path.home() / "Reports" / "weekly")))
    out_dir.mkdir(parents=True, exist_ok=True)
    log = out_dir / "weekly_report.log"

    def logline(msg: str) -> None:
        with log.open("a", encoding="utf-8") as f:
            f.write("%s  %s\n" % (dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg))

    logline("start: window %s vs %s" % (w.label(), w.plabel()))
    try:
        src = collect(c, w)
        rows = build_rows(c, w, src)
        apply_rules(c, rows, src)
        exp = experiment_status(c, rows)
        html_path = out_dir / ("%s.html" % w.end)
        md_path = out_dir / ("%s.md" % w.end)
        summary = summary_text(c, w, rows, exp, html_path)
        generated = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
        html_path.write_text(render_html(c, w, rows, exp, src, generated), encoding="utf-8")
        md_path.write_text(render_md(c, w, rows, exp, summary), encoding="utf-8")
        (out_dir / ("%s_summary.txt" % w.end)).write_text(summary, encoding="utf-8")
        logline("wrote %s and %s (%d data notes)" % (html_path.name, md_path.name, len(NOTES)))
        print(summary)
        if not a.no_notify:
            try:
                res = deliver("Weekly report %s" % w.end, summary)
                logline("phone: " + res)
                print("\nphone:", res)
            except Exception as e:
                logline("phone delivery FAILED: " + _short_err(e))
                print("\nphone delivery FAILED:", _short_err(e), file=sys.stderr)
                return 2
        return 0
    except Exception:
        logline("FAILED:\n" + traceback.format_exc())
        raise


if __name__ == "__main__":
    sys.exit(main())
