"""Store status memory and promote-without-rebuild (Google Play + App Store).

What lives here:

* Reading what is on each store right now: the Play tracks (production,
  beta, alpha, internal) of an app and, on App Store Connect, its TestFlight
  builds and App Store versions. Results are kept in the ``store_status``
  table so the phone shows them at once, and a failed refresh keeps the last
  known data next to its error.
* The display rule: per store the HIGHEST version found, labelled with the
  track it is on; when the same version sits on several tracks the most
  public track wins (production > beta > alpha > internal on Play;
  live > in review > TestFlight on Apple).
* Promote without rebuild. Play: copy the live release of one track to
  another through an edit (read source versionCodes, write the target track,
  commit). Apple: attach a processed TestFlight build to the editable App
  Store version (created when missing). Submitting for review is a separate,
  explicit action; nothing here ever submits on its own.

Every network call goes through small client objects (a googleapiclient
service, ``AscClient``) so the tests can replace them; the tests never reach
Google or Apple.
"""
from __future__ import annotations

import logging
import re
import threading
import time
from datetime import datetime, timezone
from typing import Callable, Optional

logger = logging.getLogger(__name__)

PLAY_SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

# Standard Play tracks, most public first. Anything else (custom closed
# tracks, form-factor tracks like "wear:production") is listed but ranks
# below internal.
PLAY_TRACK_PRIORITY = {"production": 4, "beta": 3, "alpha": 2, "internal": 1}
PLAY_TRACKS = tuple(PLAY_TRACK_PRIORITY)
PLAY_LIVE_STATUSES = ("completed", "inProgress")

# App Store version states. "live" outranks "review" outranks TestFlight; an
# editable version (being prepared, rejected) is not on the store at all.
APPLE_LIVE_STATES = ("READY_FOR_SALE", "READY_FOR_DISTRIBUTION")
APPLE_REVIEW_STATES = (
    "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "PROCESSING_FOR_DISTRIBUTION",
    "WAITING_FOR_EXPORT_COMPLIANCE", "ACCEPTED",
)
APPLE_EDITABLE_STATES = (
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
    "METADATA_REJECTED", "INVALID_BINARY",
)
APPLE_TRACK_PRIORITY = {"live": 4, "review": 3, "testflight": 1, "prepare": 0}

# Refresh pacing. Apple's API is sensitive to bursts: a pause between apps
# in the periodic sweep, and a floor between two refreshes of the same app
# unless the caller forces it.
REFRESH_INTERVAL_S = 6 * 3600
# The background loop wakes this often and refreshes only stores older than
# REFRESH_INTERVAL_S, so a server restart neither loses the 6 h rhythm nor
# re-reads every store at once.
STALE_CHECK_EVERY_S = 15 * 60
FIRST_CHECK_AFTER_S = 120
MIN_REFRESH_GAP_S = 300
SWEEP_PAUSE_S = 2.0
# After a deploy/upload: Play shows the new release at once; Apple needs
# time to process the uploaded build.
AFTER_DEPLOY_PLAY_DELAY_S = 30
AFTER_DEPLOY_APPLE_DELAY_S = 20 * 60

APPLE_BUILDS_LIMIT = 10
APPLE_VERSIONS_LIMIT = 5


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── Version ordering + display rule ─────────────────────────────────────

def _version_parts(version: str) -> tuple[int, ...]:
    return tuple(int(p) for p in re.findall(r"\d+", version or ""))


def entry_sort_key(entry: dict) -> tuple:
    """Higher = newer. A Play versionCode decides alone; otherwise the
    marketing version, then the build number."""
    code = entry.get("code")
    if isinstance(code, int):
        return (1, code, ())
    build = entry.get("build") or ""
    build_n = int(build) if str(build).isdigit() else -1
    return (0, 0, _version_parts(entry.get("version", "")) + (build_n,))


def entry_priority(store: str, entry: dict) -> int:
    track = entry.get("track", "")
    if store == "play":
        return PLAY_TRACK_PRIORITY.get(track, 0)
    return APPLE_TRACK_PRIORITY.get(track, 0)


def pick_display(store: str, entries: list[dict]) -> Optional[dict]:
    """The entry to show for a store: highest version, then most public track.

    Only entries that are actually out (Play: completed / staged rollout;
    Apple: live, in review, valid TestFlight build) are considered; when
    there are none, any entry is better than nothing (e.g. a draft-only app).
    """
    def out(e: dict) -> bool:
        if store == "play":
            return e.get("status") in PLAY_LIVE_STATUSES
        return e.get("track") in ("live", "review", "testflight")

    pool = [e for e in entries if out(e)] or list(entries)
    if not pool:
        return None
    best = max(pool, key=lambda e: (entry_sort_key(e), entry_priority(store, e)))
    return dict(best)


# ── Google Play ─────────────────────────────────────────────────────────

_NAME_VERSION_RE = re.compile(r"\(([0-9][0-9A-Za-z.\-+_]*)\)")


def version_from_release_name(name: str) -> str:
    """Play names a release "254 (1.0.253)" by default; a custom name that is
    itself a version ("1.0.253") is taken as is."""
    if not name:
        return ""
    m = _NAME_VERSION_RE.search(name)
    if m:
        return m.group(1)
    name = name.strip()
    return name if re.fullmatch(r"[0-9][0-9A-Za-z.\-+_]*", name) else ""


def play_service_for(settings: dict, play_account: Optional[str]):
    """An androidpublisher v3 client for the app's Play account."""
    from google.oauth2 import service_account
    from googleapiclient.discovery import build as google_build
    from core.users import play_service_account_path

    key = play_service_account_path(settings, play_account)
    if not key:
        raise ValueError("No service_account_key configured in settings.json")
    creds = service_account.Credentials.from_service_account_file(key, scopes=PLAY_SCOPES)
    return google_build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def parse_play_tracks(tracks_resp: dict) -> list[dict]:
    """``edits.tracks.list`` answer -> flat entries (one per release)."""
    entries = []
    for t in tracks_resp.get("tracks", []) or []:
        track = t.get("track", "")
        for rel in t.get("releases", []) or []:
            codes = [int(c) for c in rel.get("versionCodes", []) or [] if str(c).isdigit()]
            if not codes:
                continue
            name = rel.get("name", "") or ""
            entries.append({
                "track": track,
                "code": max(codes),
                "codes": sorted(codes),
                "version": version_from_release_name(name) or str(max(codes)),
                "name": name,
                "status": rel.get("status", ""),
                "fraction": rel.get("userFraction"),
            })
    entries.sort(key=lambda e: (-entry_priority("play", e), -e["code"]))
    return entries


def fetch_play_status(service, package: str) -> dict:
    """Read-only: open an edit, list the tracks, throw the edit away."""
    edits = service.edits()
    edit_id = edits.insert(packageName=package, body={}).execute()["id"]
    try:
        resp = edits.tracks().list(packageName=package, editId=edit_id).execute()
    finally:
        try:
            edits.delete(packageName=package, editId=edit_id).execute()
        except Exception as e:  # an unused edit expires by itself; say so and go on
            logger.warning("store_status: Play edit cleanup failed for %s: %s", package, e)
    entries = parse_play_tracks(resp)
    return {"store": "play", "package": package, "entries": entries,
            "display": pick_display("play", entries)}


def _live_release(track_resp: dict) -> Optional[dict]:
    """The newest release that is actually out on a track."""
    live = [r for r in track_resp.get("releases", []) or []
            if r.get("status") in PLAY_LIVE_STATUSES and r.get("versionCodes")]
    if not live:
        return None
    return max(live, key=lambda r: max(int(c) for c in r["versionCodes"]))


def promote_play(service, package: str, from_track: str, to_track: str,
                 rollout: Optional[float] = None) -> dict:
    """Copy the live release of ``from_track`` to ``to_track`` (no rebuild).

    ``rollout`` None / 1.0 = completed; 0 < rollout < 1 = staged rollout.
    """
    if from_track == to_track:
        raise ValueError("Source and target track are the same")
    if rollout is not None and not (0 < rollout <= 1):
        raise ValueError("rollout must be in (0, 1]")
    edits = service.edits()
    edit_id = edits.insert(packageName=package, body={}).execute()["id"]
    committed = False
    try:
        src = edits.tracks().get(packageName=package, editId=edit_id, track=from_track).execute()
        rel = _live_release(src)
        if rel is None:
            raise ValueError(f"No live release on the '{from_track}' track to promote")
        codes = [str(c) for c in rel["versionCodes"]]
        new_rel = {"versionCodes": codes, "status": "completed"}
        if rollout is not None and rollout < 1:
            new_rel["status"] = "inProgress"
            new_rel["userFraction"] = rollout
        if rel.get("name"):
            new_rel["name"] = rel["name"]
        if rel.get("releaseNotes"):
            new_rel["releaseNotes"] = rel["releaseNotes"]
        edits.tracks().update(
            packageName=package, editId=edit_id, track=to_track,
            body={"track": to_track, "releases": [new_rel]},
        ).execute()
        edits.commit(packageName=package, editId=edit_id).execute()
        committed = True
    finally:
        if not committed:
            try:
                edits.delete(packageName=package, editId=edit_id).execute()
            except Exception as e:
                logger.warning("store_status: Play edit cleanup failed for %s: %s", package, e)
    codes_int = [int(c) for c in codes]
    return {
        "version": version_from_release_name(rel.get("name", "")) or str(max(codes_int)),
        "version_codes": codes_int,
        "status": new_rel["status"],
        "fraction": new_rel.get("userFraction"),
    }


# ── App Store Connect ───────────────────────────────────────────────────

class AscError(RuntimeError):
    def __init__(self, status: int, message: str):
        super().__init__(f"App Store Connect {status}: {message}")
        self.status = status


class AscClient:
    """Thin JSON:API client over AppleManager's JWT. Errors keep Apple's own
    message (``errors[].detail``) instead of a bare HTTP status."""

    def __init__(self, apple_manager):
        self.am = apple_manager

    def _request(self, method: str, path: str, params: Optional[dict] = None,
                 data: Optional[dict] = None) -> dict:
        import requests
        url = self.am._normalize_url(path)
        headers = {"Authorization": f"Bearer {self.am.get_jwt_token()}",
                   "Content-Type": "application/json"}
        resp = requests.request(method, url, headers=headers, params=params, json=data, timeout=30)
        if resp.status_code >= 400:
            detail = resp.text[:500]
            try:
                errs = resp.json().get("errors") or []
                if errs:
                    detail = "; ".join(e.get("detail") or e.get("title") or "" for e in errs)[:500]
            except ValueError:
                pass
            raise AscError(resp.status_code, detail)
        if resp.status_code == 204 or not resp.content:
            return {}
        return resp.json()

    def get(self, path: str, params: Optional[dict] = None) -> dict:
        return self._request("GET", path, params=params)

    def post(self, path: str, data: dict) -> dict:
        return self._request("POST", path, data=data)

    def patch(self, path: str, data: dict) -> dict:
        return self._request("PATCH", path, data=data)


def resolve_apple_app_id(asc, bundle_id: str) -> str:
    resp = asc.get("apps", params={"filter[bundleId]": bundle_id, "fields[apps]": "bundleId", "limit": 5})
    for item in resp.get("data", []) or []:
        if (item.get("attributes") or {}).get("bundleId") == bundle_id:
            return item["id"]
    raise ValueError(f"No App Store Connect app with bundle id {bundle_id}")


def _included_map(resp: dict) -> dict:
    return {(i.get("type"), i.get("id")): i for i in resp.get("included", []) or []}


def _rel_id(item: dict, name: str) -> Optional[str]:
    data = ((item.get("relationships") or {}).get(name) or {}).get("data")
    return data.get("id") if isinstance(data, dict) else None


def parse_apple_builds(resp: dict) -> list[dict]:
    """``GET builds?include=preReleaseVersion,buildBetaDetail`` -> build dicts."""
    inc = _included_map(resp)
    out = []
    for b in resp.get("data", []) or []:
        a = b.get("attributes") or {}
        prv = inc.get(("preReleaseVersions", _rel_id(b, "preReleaseVersion"))) or {}
        bbd = inc.get(("buildBetaDetails", _rel_id(b, "buildBetaDetail"))) or {}
        bbd_a = bbd.get("attributes") or {}
        out.append({
            "build_id": b.get("id"),
            "version": (prv.get("attributes") or {}).get("version", ""),
            "build": str(a.get("version", "")),
            "processing": a.get("processingState", ""),
            "expired": bool(a.get("expired")),
            "uploaded_at": a.get("uploadedDate", ""),
            "internal_state": bbd_a.get("internalBuildState", ""),
            "external_state": bbd_a.get("externalBuildState", ""),
        })
    out.sort(key=lambda e: entry_sort_key(e), reverse=True)
    return out


def apple_version_state(attrs: dict) -> str:
    return attrs.get("appVersionState") or attrs.get("appStoreState") or ""


def parse_apple_versions(resp: dict) -> list[dict]:
    """``GET apps/{id}/appStoreVersions?include=build`` -> version dicts."""
    inc = _included_map(resp)
    out = []
    for v in resp.get("data", []) or []:
        a = v.get("attributes") or {}
        build_id = _rel_id(v, "build")
        build = inc.get(("builds", build_id)) or {}
        out.append({
            "version_id": v.get("id"),
            "version": a.get("versionString", ""),
            "state": apple_version_state(a),
            "build_id": build_id,
            "build": str((build.get("attributes") or {}).get("version", "")) if build else "",
            "created_at": a.get("createdDate", ""),
        })
    return out


def apple_track_for_state(state: str) -> str:
    if state in APPLE_LIVE_STATES:
        return "live"
    if state in APPLE_REVIEW_STATES:
        return "review"
    return "prepare"


def build_apple_entries(builds: list[dict], versions: list[dict]) -> list[dict]:
    entries = []
    for v in versions:
        entries.append({
            "track": apple_track_for_state(v["state"]),
            "version": v["version"], "build": v["build"],
            "status": v["state"], "version_id": v["version_id"], "build_id": v["build_id"],
        })
    for b in builds:
        if b["processing"] != "VALID" or b["expired"]:
            continue
        entries.append({
            "track": "testflight",
            "version": b["version"], "build": b["build"],
            "status": b["external_state"] or b["internal_state"] or b["processing"],
            "build_id": b["build_id"],
        })
    entries.sort(key=lambda e: (entry_sort_key(e), entry_priority("apple", e)), reverse=True)
    return entries


def fetch_apple_builds(asc, apple_app_id: str) -> list[dict]:
    resp = asc.get("builds", params={
        "filter[app]": apple_app_id,
        "sort": "-uploadedDate",
        "limit": APPLE_BUILDS_LIMIT,
        "include": "preReleaseVersion,buildBetaDetail",
        "fields[builds]": "version,processingState,expired,uploadedDate,preReleaseVersion,buildBetaDetail",
        "fields[preReleaseVersions]": "version",
        "fields[buildBetaDetails]": "internalBuildState,externalBuildState",
    })
    return parse_apple_builds(resp)


def fetch_apple_versions(asc, apple_app_id: str) -> list[dict]:
    resp = asc.get(f"apps/{apple_app_id}/appStoreVersions", params={
        "filter[platform]": "IOS",
        "limit": APPLE_VERSIONS_LIMIT,
        "include": "build",
        "fields[appStoreVersions]": "versionString,appStoreState,appVersionState,createdDate,build",
        "fields[builds]": "version",
    })
    return parse_apple_versions(resp)


def fetch_apple_status(asc, apple_app_id: str) -> dict:
    builds = fetch_apple_builds(asc, apple_app_id)
    versions = fetch_apple_versions(asc, apple_app_id)
    entries = build_apple_entries(builds, versions)
    live = [e for e in entries if e["track"] == "live"]
    editable = [v for v in versions if v["state"] in APPLE_EDITABLE_STATES]
    return {
        "store": "apple", "apple_app_id": apple_app_id,
        "entries": entries,
        "builds": builds,
        "versions": versions,
        "display": pick_display("apple", entries),
        "live": max(live, key=entry_sort_key) if live else None,
        "editable_version": editable[0] if editable else None,
    }


def attach_apple_build(asc, apple_app_id: str, build_id: Optional[str] = None) -> dict:
    """Attach a processed TestFlight build to the editable App Store version.

    Picks the highest VALID, unexpired build unless ``build_id`` is given.
    Creates the version (PREPARE_FOR_SUBMISSION) when there is none, and sets
    its versionString to the build's marketing version. Never submits.
    """
    builds = fetch_apple_builds(asc, apple_app_id)
    valid = [b for b in builds if b["processing"] == "VALID" and not b["expired"]]
    if build_id:
        chosen = next((b for b in builds if b["build_id"] == build_id), None)
        if chosen is None:
            raise ValueError(f"Build {build_id} not found among the latest builds")
        if chosen not in valid:
            raise ValueError(f"Build {chosen['version']} ({chosen['build']}) is not a processed, "
                             f"unexpired build (state {chosen['processing']})")
    else:
        if not valid:
            raise ValueError("No processed TestFlight build to attach")
        chosen = valid[0]
    if not chosen["version"]:
        raise ValueError("The build has no marketing version")

    versions = fetch_apple_versions(asc, apple_app_id)
    editable = next((v for v in versions if v["state"] in APPLE_EDITABLE_STATES), None)
    created = False
    if editable is None:
        resp = asc.post("appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": chosen["version"]},
            "relationships": {"app": {"data": {"type": "apps", "id": apple_app_id}}},
        }})
        version_id = resp["data"]["id"]
        created = True
    else:
        version_id = editable["version_id"]
        if editable["version"] != chosen["version"]:
            asc.patch(f"appStoreVersions/{version_id}", {"data": {
                "type": "appStoreVersions", "id": version_id,
                "attributes": {"versionString": chosen["version"]},
            }})
    asc.patch(f"appStoreVersions/{version_id}/relationships/build",
              {"data": {"type": "builds", "id": chosen["build_id"]}})
    return {"version": chosen["version"], "build": chosen["build"],
            "build_id": chosen["build_id"], "version_id": version_id, "created_version": created}


def submit_apple_for_review(asc, apple_app_id: str) -> dict:
    """Submit the editable App Store version (with its build) for App Review.

    Called ONLY from the explicit submit-for-review action.
    """
    versions = fetch_apple_versions(asc, apple_app_id)
    editable = next((v for v in versions if v["state"] in APPLE_EDITABLE_STATES), None)
    if editable is None:
        raise ValueError("No App Store version waiting to be submitted")
    if not editable["build_id"]:
        raise ValueError(f"Version {editable['version']} has no build attached")

    open_subs = asc.get("reviewSubmissions", params={
        "filter[app]": apple_app_id, "filter[platform]": "IOS",
        "filter[state]": "READY_FOR_REVIEW", "limit": 5,
    }).get("data", []) or []
    if open_subs:
        sub_id = open_subs[0]["id"]
    else:
        sub_id = asc.post("reviewSubmissions", {"data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": apple_app_id}}},
        }})["data"]["id"]
    try:
        asc.post("reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": editable["version_id"]}},
            },
        }})
    except AscError as e:
        # 409 = the version is already an item of this open submission (an
        # earlier attempt stopped half way). Anything else is a real refusal.
        if e.status != 409:
            raise
        logger.warning("store_status: version %s already in review submission %s: %s",
                       editable["version_id"], sub_id, e)
    asc.patch(f"reviewSubmissions/{sub_id}", {"data": {
        "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True},
    }})
    return {"version": editable["version"], "build": editable["build"],
            "version_id": editable["version_id"], "submission_id": sub_id}


# ── Service: persistence, pacing, scheduling ────────────────────────────

def compact(store_rows: dict) -> dict:
    """DB rows -> what the API / app dict carries per store."""
    out = {}
    for store, row in store_rows.items():
        data = row.get("data") or {}
        item = {
            "display": data.get("display"),
            "entries": data.get("entries", []),
            "refreshed_at": row.get("refreshed_at"),
            "error": row.get("error", ""),
            "error_at": row.get("error_at"),
        }
        if store == "apple":
            item["live"] = data.get("live")
            item["editable_version"] = data.get("editable_version")
            item["builds"] = data.get("builds", [])
        out[store] = item
    return out


def load(db, app_id: int) -> dict:
    return compact(db.get_store_status(app_id))


def _apple_enabled(app) -> bool:
    return bool(getattr(app, "apple_app_id", "") or getattr(app, "last_ios_upload_track", "")
                or getattr(app, "last_ios_build_status", ""))


def _play_enabled(app) -> bool:
    return bool(app.package_name and (getattr(app, "last_upload_track", "")
                                      or getattr(app, "play_store_url", "")))


class StoreStatusService:
    """Refreshes and remembers store status; runs promotes. One per server."""

    def __init__(self, db, settings: dict,
                 on_changed: Optional[Callable[[int], None]] = None,
                 play_service_factory: Optional[Callable] = None,
                 asc_factory: Optional[Callable] = None):
        self.db = db
        self.settings = settings
        self.on_changed = on_changed
        self._play_factory = play_service_factory or (
            lambda app: play_service_for(self.settings, getattr(app, "play_account", None)))
        self._asc_factory = asc_factory or self._default_asc
        self._locks: dict[int, threading.Lock] = {}
        self._locks_lock = threading.Lock()
        self._timers: dict[tuple[int, str], threading.Timer] = {}
        self._stop = threading.Event()

    def _default_asc(self):
        from core.apple_manager import AppleManager
        am = AppleManager(self.settings)
        if not am.is_configured():
            raise RuntimeError("Apple App Store Connect credentials not configured in settings.json")
        return AscClient(am)

    def _lock(self, app_id: int) -> threading.Lock:
        with self._locks_lock:
            return self._locks.setdefault(app_id, threading.Lock())

    # -- refresh --------------------------------------------------------

    def _age_s(self, app_id: int, store: str) -> Optional[float]:
        """Seconds since the last attempt (success or error); None = never."""
        row = self.db.get_store_status(app_id).get(store)
        stamps = [x for x in ((row or {}).get("error_at"), (row or {}).get("refreshed_at")) if x]
        if not stamps:
            return None
        try:
            t = max(datetime.strptime(x, "%Y-%m-%dT%H:%M:%SZ") for x in stamps).replace(tzinfo=timezone.utc)
        except ValueError:
            return None
        return (datetime.now(timezone.utc) - t).total_seconds()

    def _recent(self, app_id: int, store: str, within_s: float = MIN_REFRESH_GAP_S) -> bool:
        age = self._age_s(app_id, store)
        return age is not None and age < within_s

    def refresh_app(self, app, force: bool = False, stores: Optional[tuple] = None) -> dict:
        """Refresh one app's store status. ``stores`` None = every store the
        app is on (a forced refresh also tries Play for any app with a
        package name). Returns the compact status."""
        if stores is None:
            stores = tuple(s for s, on in (
                ("play", _play_enabled(app) or (force and bool(app.package_name))),
                ("apple", _apple_enabled(app)),
            ) if on)
        changed = False
        with self._lock(app.id):
            before = self.db.get_store_status(app.id)
            for store in stores:
                if not force and self._recent(app.id, store):
                    continue
                try:
                    data = self._fetch(app, store)
                    self.db.save_store_status(app.id, store, data, now_iso())
                    old = (before.get(store) or {}).get("data") or {}
                    changed = changed or old.get("entries") != data.get("entries")
                except Exception as e:
                    logger.warning("store_status: %s refresh failed for app %s: %s", store, app.id, e)
                    self.db.save_store_status_error(app.id, store, str(e), now_iso())
                    changed = changed or (before.get(store) or {}).get("error") != str(e)[:1000]
        if changed and self.on_changed:
            self.on_changed(app.id)
        return load(self.db, app.id)

    def _fetch(self, app, store: str) -> dict:
        if store == "play":
            if not app.package_name:
                raise ValueError("App has no package_name")
            return fetch_play_status(self._play_factory(app), app.package_name)
        asc = self._asc_factory()
        apple_id = self._apple_app_id(app, asc)
        return fetch_apple_status(asc, apple_id)

    def _apple_app_id(self, app, asc) -> str:
        if getattr(app, "apple_app_id", ""):
            return app.apple_app_id
        if not app.package_name:
            raise ValueError("App has no package_name (bundle id) and no apple_app_id")
        apple_id = resolve_apple_app_id(asc, app.package_name)
        # Remember it: one lookup per app, ever.
        self.db.update_app(app.id, apple_app_id=apple_id)
        app.apple_app_id = apple_id
        return apple_id

    def refresh_stale(self, apps) -> int:
        """Background sweep: refresh only the stores not read for
        REFRESH_INTERVAL_S, pausing between apps. Returns apps refreshed."""
        n = 0
        for app in apps:
            if self._stop.is_set():
                break
            if getattr(app, "is_archived", False):
                continue
            stale = tuple(s for s, on in (("play", _play_enabled(app)), ("apple", _apple_enabled(app)))
                          if on and not self._recent(app.id, s, REFRESH_INTERVAL_S))
            if not stale:
                continue
            self.refresh_app(app, force=True, stores=stale)
            n += 1
            if self._stop.wait(SWEEP_PAUSE_S):
                break
        return n

    def refresh_all(self, apps, force: bool = False) -> int:
        """Sweep every given app, pacing the calls. Returns apps refreshed."""
        n = 0
        for app in apps:
            if self._stop.is_set():
                break
            if getattr(app, "is_archived", False):
                continue
            if not (_play_enabled(app) or _apple_enabled(app)):
                continue
            self.refresh_app(app, force=force)
            n += 1
            if self._stop.wait(SWEEP_PAUSE_S):
                break
        return n

    # -- scheduling -----------------------------------------------------

    def schedule(self, app_id: int, store: str, delay_s: float):
        """Refresh one store of one app after ``delay_s`` (debounced)."""
        key = (app_id, store)
        old = self._timers.pop(key, None)
        if old:
            old.cancel()

        def run():
            self._timers.pop(key, None)
            app = self.db.get_app(app_id)
            if app is not None:
                self.refresh_app(app, force=True, stores=(store,))

        t = threading.Timer(delay_s, run)
        t.daemon = True
        self._timers[key] = t
        t.start()

    def on_deploy_status(self, app_id: int, status: dict):
        """DeployEngine callback: a finished upload refreshes that app."""
        if (status or {}).get("phase") != "done" or status.get("upload") is False:
            return
        target = status.get("build_target", "aab")
        if target in ("aab", "apk", "dual") or "build_target" not in status:
            self.schedule(app_id, "play", AFTER_DEPLOY_PLAY_DELAY_S)
        if target in ("ios", "dual"):
            self.schedule(app_id, "apple", AFTER_DEPLOY_APPLE_DELAY_S)

    def start_periodic(self, apps_provider: Callable[[], list]):
        def loop():
            wait = FIRST_CHECK_AFTER_S
            while not self._stop.wait(wait):
                wait = STALE_CHECK_EVERY_S
                try:
                    n = self.refresh_stale(apps_provider())
                    if n:
                        logger.info("store_status: periodic refresh of %d app(s) done", n)
                except Exception as e:
                    logger.error("store_status: periodic refresh failed: %s", e)
        threading.Thread(target=loop, daemon=True, name="store-status").start()

    def stop(self):
        self._stop.set()
        for t in list(self._timers.values()):
            t.cancel()

    # -- promote / attach / submit ---------------------------------------

    def _record(self, app, store, action, user, from_track="", to_track="",
                version="", build_ref="", error=""):
        self.db.add_store_promotion(
            app_id=app.id, store=store, action=action, from_track=from_track,
            to_track=to_track, version=version, build_ref=build_ref,
            status="failed" if error else "ok", error=error[:1000],
            user_id=getattr(user, "id", None), user_name=getattr(user, "name", "") or "",
        )
        if error:
            logger.warning("store_status: %s %s %s->%s failed for app %s by %s: %s",
                           store, action, from_track, to_track, app.id,
                           getattr(user, "name", "?"), error)
        else:
            logger.info("store_status: %s %s %s->%s v%s (%s) for app %s by %s",
                        store, action, from_track, to_track, version, build_ref, app.id,
                        getattr(user, "name", "?"))

    def promote_play(self, app, from_track: str, to_track: str, user,
                     rollout: Optional[float] = None) -> dict:
        if from_track not in PLAY_TRACKS or to_track not in PLAY_TRACKS:
            raise ValueError(f"Tracks must be one of {', '.join(PLAY_TRACKS)}")
        if not app.package_name:
            raise ValueError("App has no package_name")
        try:
            res = promote_play(self._play_factory(app), app.package_name, from_track, to_track, rollout)
        except Exception as e:
            self._record(app, "play", "promote", user, from_track, to_track, error=str(e))
            raise
        self._record(app, "play", "promote", user, from_track, to_track,
                     version=res["version"], build_ref=",".join(map(str, res["version_codes"])))
        self.refresh_app(app, force=True, stores=("play",))
        return res

    def attach_apple(self, app, user, build_id: Optional[str] = None) -> dict:
        try:
            asc = self._asc_factory()
            res = attach_apple_build(asc, self._apple_app_id(app, asc), build_id)
        except Exception as e:
            self._record(app, "apple", "attach", user, "testflight", "app_store", error=str(e))
            raise
        self._record(app, "apple", "attach", user, "testflight", "app_store",
                     version=res["version"], build_ref=res["build"])
        self.refresh_app(app, force=True, stores=("apple",))
        return res

    def submit_apple(self, app, user) -> dict:
        try:
            asc = self._asc_factory()
            res = submit_apple_for_review(asc, self._apple_app_id(app, asc))
        except Exception as e:
            self._record(app, "apple", "submit_for_review", user, "app_store", "review", error=str(e))
            raise
        self._record(app, "apple", "submit_for_review", user, "app_store", "review",
                     version=res["version"], build_ref=res["build"])
        self.refresh_app(app, force=True, stores=("apple",))
        return res
