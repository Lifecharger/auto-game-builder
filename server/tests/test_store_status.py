"""Store status memory + promote without rebuild (core/store_status.py).

Google Play and App Store Connect are replaced by in-memory fakes: no test
here reaches the network. Databases are temp files.
"""
from __future__ import annotations

import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

SERVER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from core import store_status as ss  # noqa: E402
from core import users as users_core  # noqa: E402
from database.db_manager import DBManager  # noqa: E402


# ── Fakes ────────────────────────────────────────────────────────────────

class _Req:
    def __init__(self, fn):
        self.fn = fn

    def execute(self):
        return self.fn()


class FakePlay:
    """androidpublisher v3 edits API, just enough for the module."""

    def __init__(self, tracks: dict[str, list[dict]]):
        self.tracks_data = tracks
        self.calls: list[tuple] = []
        self.fail_update = None

    def edits(self):
        return self

    def insert(self, packageName, body):
        self.calls.append(("insert", packageName))
        return _Req(lambda: {"id": "edit-1"})

    def delete(self, packageName, editId):
        self.calls.append(("delete", editId))
        return _Req(lambda: {})

    def commit(self, packageName, editId):
        self.calls.append(("commit", editId))
        return _Req(lambda: {})

    def tracks(self):
        return _FakeTracks(self)


class _FakeTracks:
    def __init__(self, play: FakePlay):
        self.p = play

    def list(self, packageName, editId):
        self.p.calls.append(("tracks.list",))
        return _Req(lambda: {"tracks": [{"track": t, "releases": r} for t, r in self.p.tracks_data.items()]})

    def get(self, packageName, editId, track):
        self.p.calls.append(("tracks.get", track))
        return _Req(lambda: {"track": track, "releases": self.p.tracks_data.get(track, [])})

    def update(self, packageName, editId, track, body):
        self.p.calls.append(("tracks.update", track, body))

        def run():
            if self.p.fail_update:
                raise self.p.fail_update
            return body
        return _Req(run)


def _build(bid, version, build, processing="VALID", expired=False, ext="IN_BETA_TESTING"):
    return {
        "data": {"type": "builds", "id": bid,
                 "attributes": {"version": build, "processingState": processing, "expired": expired,
                                "uploadedDate": "2026-11-20T10:00:00Z"},
                 "relationships": {"preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "p" + bid}},
                                   "buildBetaDetail": {"data": {"type": "buildBetaDetails", "id": "d" + bid}}}},
        "included": [
            {"type": "preReleaseVersions", "id": "p" + bid, "attributes": {"version": version}},
            {"type": "buildBetaDetails", "id": "d" + bid,
             "attributes": {"internalBuildState": "IN_BETA_TESTING", "externalBuildState": ext}},
        ],
    }


def _builds_resp(*builds):
    return {"data": [b["data"] for b in builds], "included": [i for b in builds for i in b["included"]]}


def _version(vid, version, state, build_id=None, build=""):
    v = {"type": "appStoreVersions", "id": vid,
         "attributes": {"versionString": version, "appVersionState": state, "createdDate": "2026-11-01"},
         "relationships": {"build": {"data": {"type": "builds", "id": build_id} if build_id else None}}}
    inc = [{"type": "builds", "id": build_id, "attributes": {"version": build}}] if build_id else []
    return v, inc


class FakeAsc:
    def __init__(self, builds_resp: dict, versions: list[tuple], open_subs=None, item_status=None,
                 iaps=None, subs=None, product_error=None, gc=None):
        # gc: {"achievements": [(id, vendor, state)], "leaderboards": [...], "app_version": bool}
        self.gc = gc
        self.iaps = iaps or []
        self.subs = subs or []
        self.product_error = product_error
        self.builds_resp = builds_resp
        self.versions = versions
        self.open_subs = open_subs or []
        self.item_status = item_status
        self.calls: list[tuple] = []

    def get(self, path, params=None):
        self.calls.append(("GET", path, params))
        if path == "apps":
            return {"data": [{"id": "999", "attributes": {"bundleId": params["filter[bundleId]"]}}]}
        if path == "builds":
            return self.builds_resp
        if path.endswith("/appStoreVersions"):
            return {"data": [v for v, _ in self.versions], "included": [i for _, inc in self.versions for i in inc]}
        if path == "reviewSubmissions":
            return {"data": self.open_subs}
        if path.endswith("/inAppPurchasesV2"):
            return {"data": self.iaps}
        if path.endswith("/subscriptionGroups"):
            return {"data": [{"id": "g1"}], "included": self.subs}
        if path.endswith("/gameCenterDetail"):
            return {"data": {"id": "gcd"} if self.gc else None}
        if path.endswith("/gameCenterAppVersion"):
            return {"data": {"id": "gcv"} if self.gc and self.gc.get("app_version") else None}
        for kind in ("Achievements", "Leaderboards"):
            rows = (self.gc or {}).get(kind.lower(), [])
            if path == f"gameCenterDetails/gcd/gameCenter{kind}":
                return {"data": [{"id": i, "attributes": {"vendorIdentifier": vid}} for i, vid, _ in rows]}
            for i, vid, state in rows:
                if path == f"v2/gameCenter{kind}/{i}/versions":
                    return {"data": [{"id": f"{i}-v1", "attributes": {"state": state}}]}
        raise AssertionError(f"unexpected GET {path}")

    def post(self, path, data):
        self.calls.append(("POST", path, data))
        if path == "appStoreVersions":
            return {"data": {"id": "new-ver"}}
        if path == "reviewSubmissions":
            return {"data": {"id": "sub-new"}}
        if path == "gameCenterAppVersions":
            return {"data": {"id": "gcv-new"}}
        if path == "reviewSubmissionItems":
            if self.item_status:
                raise ss.AscError(self.item_status, "already added")
            return {"data": {"id": "item-1"}}
        if path in ("inAppPurchaseSubmissions", "subscriptionSubmissions"):
            if self.product_error:
                raise ss.AscError(*self.product_error)
            return {"data": {"id": "ps-1"}}
        raise AssertionError(f"unexpected POST {path}")

    def patch(self, path, data):
        self.calls.append(("PATCH", path, data))
        return {}

    def writes(self):
        return [c for c in self.calls if c[0] != "GET"]


# ── Display rule ─────────────────────────────────────────────────────────

class DisplayRuleTest(unittest.TestCase):
    def test_same_version_on_internal_and_production_shows_production(self):
        entries = [
            {"track": "internal", "code": 172, "version": "1.0.171", "status": "completed"},
            {"track": "production", "code": 172, "version": "1.0.171", "status": "completed"},
        ]
        self.assertEqual(ss.pick_display("play", entries)["track"], "production")

    def test_highest_version_wins_over_more_public_track(self):
        entries = [
            {"track": "production", "code": 170, "version": "1.0.169", "status": "completed"},
            {"track": "internal", "code": 172, "version": "1.0.171", "status": "completed"},
            {"track": "beta", "code": 171, "version": "1.0.170", "status": "completed"},
        ]
        d = ss.pick_display("play", entries)
        self.assertEqual((d["version"], d["track"]), ("1.0.171", "internal"))

    def test_draft_is_ignored_when_something_is_live(self):
        entries = [
            {"track": "production", "code": 180, "version": "1.0.179", "status": "draft"},
            {"track": "alpha", "code": 172, "version": "1.0.171", "status": "completed"},
        ]
        self.assertEqual(ss.pick_display("play", entries)["track"], "alpha")
        only_draft = [entries[0]]
        self.assertEqual(ss.pick_display("play", only_draft)["status"], "draft")
        self.assertIsNone(ss.pick_display("play", []))

    def test_apple_live_beats_testflight_for_same_build(self):
        entries = [
            {"track": "testflight", "version": "1.0.12", "build": "34"},
            {"track": "live", "version": "1.0.12", "build": "34"},
            {"track": "testflight", "version": "1.0.11", "build": "40"},
            {"track": "prepare", "version": "1.0.13", "build": ""},
        ]
        d = ss.pick_display("apple", entries)
        self.assertEqual((d["version"], d["track"]), ("1.0.12", "live"))

    def test_apple_newer_testflight_build_wins(self):
        entries = [
            {"track": "live", "version": "1.0.10", "build": "30"},
            {"track": "testflight", "version": "1.0.12", "build": "34"},
        ]
        self.assertEqual(ss.pick_display("apple", entries)["track"], "testflight")

    def test_release_name_parsing(self):
        self.assertEqual(ss.version_from_release_name("254 (1.0.253)"), "1.0.253")
        self.assertEqual(ss.version_from_release_name("1.2.3"), "1.2.3")
        self.assertEqual(ss.version_from_release_name("Holiday update"), "")


# ── Google Play ──────────────────────────────────────────────────────────

class PlayTest(unittest.TestCase):
    TRACKS = {
        "production": [{"name": "170 (1.0.169)", "versionCodes": ["170"], "status": "completed"}],
        "internal": [{"name": "172 (1.0.171)", "versionCodes": ["172"], "status": "completed",
                      "releaseNotes": [{"language": "en-US", "text": "Fixes"}]}],
        "alpha": [],
    }

    def test_fetch_is_read_only_and_parses(self):
        play = FakePlay(dict(self.TRACKS))
        st = ss.fetch_play_status(play, "com.example.game")
        names = [c[0] for c in play.calls]
        self.assertIn("delete", names)
        self.assertNotIn("commit", names)
        self.assertNotIn("tracks.update", names)
        self.assertEqual(st["display"]["track"], "internal")
        self.assertEqual(st["display"]["version"], "1.0.171")
        self.assertEqual([e["track"] for e in st["entries"]], ["production", "internal"])

    def test_promote_copies_codes_and_commits(self):
        play = FakePlay(dict(self.TRACKS))
        res = ss.promote_play(play, "com.example.game", "internal", "production")
        upd = next(c for c in play.calls if c[0] == "tracks.update")
        self.assertEqual(upd[1], "production")
        rel = upd[2]["releases"][0]
        self.assertEqual(rel["versionCodes"], ["172"])
        self.assertEqual(rel["status"], "completed")
        self.assertEqual(rel["releaseNotes"][0]["text"], "Fixes")
        self.assertEqual(play.calls[-1][0], "commit")
        self.assertEqual(res["version"], "1.0.171")

    def test_staged_rollout(self):
        play = FakePlay(dict(self.TRACKS))
        res = ss.promote_play(play, "com.example.game", "internal", "production", rollout=0.2)
        rel = next(c for c in play.calls if c[0] == "tracks.update")[2]["releases"][0]
        self.assertEqual((rel["status"], rel["userFraction"]), ("inProgress", 0.2))
        self.assertEqual(res["status"], "inProgress")

    def test_promote_without_live_release_fails_and_discards_edit(self):
        play = FakePlay(dict(self.TRACKS))
        with self.assertRaises(ValueError):
            ss.promote_play(play, "com.example.game", "alpha", "production")
        names = [c[0] for c in play.calls]
        self.assertNotIn("commit", names)
        self.assertIn("delete", names)

    def test_play_refusal_discards_edit(self):
        play = FakePlay(dict(self.TRACKS))
        play.fail_update = RuntimeError("Version code 172 is already used")
        with self.assertRaises(RuntimeError):
            ss.promote_play(play, "com.example.game", "internal", "production")
        self.assertNotIn("commit", [c[0] for c in play.calls])


# ── App Store Connect ────────────────────────────────────────────────────

class AppleTest(unittest.TestCase):
    def _builds(self):
        return _builds_resp(
            _build("b34", "1.0.12", "34"),
            _build("b35", "1.0.13", "35", processing="PROCESSING"),
            _build("b20", "1.0.5", "20", expired=True),
        )

    def test_status_parsing(self):
        live = _version("v10", "1.0.10", "READY_FOR_SALE", "b30", "30")
        asc = FakeAsc(self._builds(), [live])
        st = ss.fetch_apple_status(asc, "999")
        self.assertEqual(st["display"]["track"], "testflight")
        self.assertEqual(st["display"]["version"], "1.0.12")
        self.assertEqual(st["live"]["version"], "1.0.10")
        self.assertIsNone(st["editable_version"])
        # processing + expired builds are listed but never displayed as TestFlight
        self.assertEqual(len(st["builds"]), 3)
        self.assertEqual([e["build"] for e in st["entries"] if e["track"] == "testflight"], ["34"])
        self.assertEqual(asc.writes(), [])

    def test_attach_creates_missing_version(self):
        live = _version("v10", "1.0.10", "READY_FOR_SALE", "b30", "30")
        asc = FakeAsc(self._builds(), [live])
        res = ss.attach_apple_build(asc, "999")
        w = asc.writes()
        self.assertEqual(w[0][1], "appStoreVersions")
        self.assertEqual(w[0][2]["data"]["attributes"]["versionString"], "1.0.12")
        self.assertEqual(w[1][1], "appStoreVersions/new-ver/relationships/build")
        self.assertEqual(w[1][2]["data"]["id"], "b34")
        self.assertTrue(res["created_version"])
        self.assertFalse(any("reviewSubmission" in c[1] for c in w))

    def test_attach_renames_existing_editable_version(self):
        prep = _version("v11", "1.0.11", "PREPARE_FOR_SUBMISSION")
        asc = FakeAsc(self._builds(), [prep])
        ss.attach_apple_build(asc, "999")
        w = asc.writes()
        self.assertEqual(w[0], ("PATCH", "appStoreVersions/v11", {"data": {
            "type": "appStoreVersions", "id": "v11", "attributes": {"versionString": "1.0.12"}}}))
        self.assertEqual(w[1][1], "appStoreVersions/v11/relationships/build")

    def test_attach_refuses_unprocessed_build(self):
        asc = FakeAsc(self._builds(), [])
        with self.assertRaises(ValueError):
            ss.attach_apple_build(asc, "999", build_id="b35")
        with self.assertRaises(ValueError):
            ss.attach_apple_build(FakeAsc(_builds_resp(), []), "999")
        self.assertEqual(asc.writes(), [])

    def test_submit_creates_submission_and_submits(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        asc = FakeAsc(self._builds(), [prep])
        res = ss.submit_apple_for_review(asc, "999")
        w = asc.writes()
        self.assertEqual([c[1] for c in w], ["appStoreVersions/v12", "reviewSubmissions",
                                             "reviewSubmissionItems", "reviewSubmissions/sub-new"])
        self.assertEqual(w[0][2]["data"]["attributes"]["releaseType"], "AFTER_APPROVAL")
        self.assertTrue(w[-1][2]["data"]["attributes"]["submitted"])
        self.assertEqual(res["version"], "1.0.12")

    def test_submit_reuses_open_submission_and_tolerates_existing_item(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        asc = FakeAsc(self._builds(), [prep], open_subs=[{"id": "sub-old"}], item_status=409)
        ss.submit_apple_for_review(asc, "999")
        self.assertEqual(asc.writes()[-1][1], "reviewSubmissions/sub-old")

    def test_submit_sends_sold_products_with_the_version(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        iaps = [{"id": "i1", "attributes": {"productId": "coins_100", "state": "READY_TO_SUBMIT"}},
                {"id": "i2", "attributes": {"productId": "old", "state": "APPROVED"}},
                {"id": "i3", "attributes": {"productId": "tickets_500", "state": "READY_TO_SUBMIT"}}]
        subs = [{"type": "subscriptions", "id": "s1",
                 "attributes": {"productId": "vip_month", "state": "READY_TO_SUBMIT"}}]
        asc = FakeAsc(self._builds(), [prep], iaps=iaps, subs=subs)
        res = ss.submit_apple_for_review(asc, "999", "com.lifecharger.arcadesnake")
        w = [c[1] for c in asc.writes()]
        self.assertEqual(w, ["appStoreVersions/v12", "reviewSubmissions", "reviewSubmissionItems",
                             "inAppPurchaseSubmissions",
                             "subscriptionSubmissions", "reviewSubmissions/sub-new"])
        self.assertEqual(res["products"], ["coins_100", "vip_month"])

    def test_submit_stops_when_a_product_is_refused(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        iaps = [{"id": "i1", "attributes": {"productId": "coins_100", "state": "READY_TO_SUBMIT"}}, {"id": "i0", "attributes": {"productId": "old", "state": "APPROVED"}}]
        asc = FakeAsc(self._builds(), [prep], iaps=iaps, product_error=(409, "missing review screenshot"))
        with self.assertRaises(ValueError) as cm:
            ss.submit_apple_for_review(asc, "999")
        self.assertIn("coins_100", str(cm.exception))
        self.assertFalse(any(c[1] == "reviewSubmissions/sub-new" for c in asc.writes()))

    def test_submit_needs_attached_build(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION")
        asc = FakeAsc(self._builds(), [prep])
        with self.assertRaises(ValueError):
            ss.submit_apple_for_review(asc, "999")
        self.assertEqual(asc.writes(), [])


# ── Service: memory, history, scheduling ─────────────────────────────────

class ServiceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = DBManager(str(Path(self.tmp.name) / "t.db"))
        self.addCleanup(lambda: self.db._get_conn().close())
        app_id = self.db.create_app(name="Game One", slug="game-one", project_path="/p/one",
                                    package_name="com.example.one", last_upload_track="internal")
        self.db.update_app(app_id, last_ios_upload_track="internal")
        self.app = self.db.get_app(app_id)
        self.play = FakePlay(dict(PlayTest.TRACKS))
        self.asc = FakeAsc(_builds_resp(_build("b34", "1.0.12", "34")), [])
        self.changed = []
        self.svc = ss.StoreStatusService(
            self.db, {}, on_changed=self.changed.append,
            play_service_factory=lambda app: self.play, asc_factory=lambda: self.asc)
        self.user = users_core.User(id=1, name="admin", role="admin")

    def test_refresh_persists_and_resolves_apple_id(self):
        st = self.svc.refresh_app(self.app, force=True)
        self.assertEqual(st["play"]["display"]["track"], "internal")
        self.assertEqual(st["apple"]["display"]["version"], "1.0.12")
        self.assertEqual(self.db.get_app(self.app.id).apple_app_id, "999")
        self.assertEqual(self.changed, [self.app.id])
        # remembered: readable without any API
        self.assertEqual(ss.load(self.db, self.app.id)["play"]["display"]["version"], "1.0.171")

    def test_failed_refresh_keeps_last_known_data(self):
        self.svc.refresh_app(self.app, force=True)
        self.svc._play_factory = mock.Mock(side_effect=RuntimeError("Play down"))
        st = self.svc.refresh_app(self.app, force=True, stores=("play",))
        self.assertEqual(st["play"]["display"]["version"], "1.0.171")
        self.assertIn("Play down", st["play"]["error"])

    def test_unforced_refresh_is_throttled(self):
        self.svc.refresh_app(self.app, force=True)
        n = len(self.play.calls)
        self.svc.refresh_app(self.app)
        self.assertEqual(len(self.play.calls), n)

    def test_promote_is_recorded(self):
        self.svc.promote_play(self.app, "internal", "production", self.user)
        rows = self.db.get_store_promotions(self.app.id)
        self.assertEqual(len(rows), 1)
        r = rows[0]
        self.assertEqual((r["store"], r["action"], r["from_track"], r["to_track"], r["version"],
                          r["status"], r["user_name"]),
                         ("play", "promote", "internal", "production", "1.0.171", "ok", "admin"))

    def test_failed_promote_is_recorded(self):
        with self.assertRaises(ValueError):
            self.svc.promote_play(self.app, "alpha", "production", self.user)
        r = self.db.get_store_promotions(self.app.id)[0]
        self.assertEqual(r["status"], "failed")
        with self.assertRaises(ValueError):
            self.svc.promote_play(self.app, "internal", "nightly", self.user)

    def test_background_sweep_refreshes_only_stale_stores(self):
        self.assertEqual(self.svc.refresh_stale([self.app]), 1)
        calls = len(self.play.calls) + len(self.asc.calls)
        self.assertEqual(self.svc.refresh_stale([self.app]), 0)
        self.assertEqual(len(self.play.calls) + len(self.asc.calls), calls)

    def test_deploy_done_schedules_refresh(self):
        with mock.patch.object(self.svc, "schedule") as sched:
            self.svc.on_deploy_status(self.app.id, {"phase": "building", "upload": True})
            sched.assert_not_called()
            self.svc.on_deploy_status(self.app.id, {"phase": "done", "upload": False})
            sched.assert_not_called()
            self.svc.on_deploy_status(self.app.id, {"phase": "done", "upload": True, "build_target": "dual"})
            stores = sorted(c.args[1] for c in sched.call_args_list)
            self.assertEqual(stores, ["apple", "play"])


# ── API ──────────────────────────────────────────────────────────────────

class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from test_multi_user import _import_server, _call, ADMIN_KEY
        cls.server = _import_server()
        cls._call = staticmethod(_call)
        cls.key = ADMIN_KEY

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = DBManager(str(Path(self.tmp.name) / "t.db"))
        self.addCleanup(lambda: self.db._get_conn().close())
        srv = self.server
        self.settings = {"api_key": self.key, "projects_root": self.tmp.name, "worker_url": ""}
        saved = (srv.get_settings, srv.event_log, getattr(srv.app.state, "db", None),
                 getattr(srv.app.state, "store_status", None))

        def restore():
            srv.get_settings, srv.event_log, srv.app.state.db, srv.app.state.store_status = saved
        self.addCleanup(restore)
        srv.get_settings = lambda *a, **k: self.settings
        srv.event_log = types.SimpleNamespace(append=lambda *a, **k: None, current_seq=0,
                                              replay_since=lambda *_: [])
        srv.app.state.db = self.db
        self.play = FakePlay(dict(PlayTest.TRACKS))
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        self.asc = FakeAsc(_builds_resp(_build("b34", "1.0.12", "34")), [prep])
        srv.app.state.store_status = ss.StoreStatusService(
            self.db, self.settings, play_service_factory=lambda app: self.play,
            asc_factory=lambda: self.asc)
        self.member, self.mkey = users_core.create_user(self.db, "User 2", "member", self.tmp.name)
        self.app_id = self.db.create_app(name="Game One", slug="game-one", project_path="/p/one",
                                         package_name="com.example.one", last_upload_track="internal",
                                         apple_app_id="999")

    def call(self, method, path, key=None, body=None):
        return self._call(self.server.app, method, path, key or self.key, body)

    def test_promote_play_route(self):
        st, res = self.call("POST", f"/api/apps/{self.app_id}/promote",
                            body={"store": "play", "from": "internal", "to": "production"})
        self.assertEqual(st, 200, res)
        self.assertEqual(res["result"]["version"], "1.0.171")
        self.assertIn("commit", [c[0] for c in self.play.calls])
        st, hist = self.call("GET", f"/api/apps/{self.app_id}/promotions")
        self.assertEqual(hist[0]["to_track"], "production")

    def test_attach_route_never_submits(self):
        st, res = self.call("POST", f"/api/apps/{self.app_id}/promote", body={"store": "apple"})
        self.assertEqual(st, 200, res)
        self.assertFalse(any("reviewSubmission" in c[1] for c in self.asc.writes()))

    def test_submit_needs_confirm(self):
        st, _ = self.call("POST", f"/api/apps/{self.app_id}/submit-for-review", body={})
        self.assertEqual(st, 400)
        self.assertEqual(self.asc.writes(), [])
        st, res = self.call("POST", f"/api/apps/{self.app_id}/submit-for-review", body={"confirm": True})
        self.assertEqual(st, 200, res)

    def test_bad_request_is_400_and_status_is_in_app_dict(self):
        st, _ = self.call("POST", f"/api/apps/{self.app_id}/promote",
                          body={"store": "play", "from": "alpha", "to": "production"})
        self.assertEqual(st, 400)
        st, _ = self.call("POST", f"/api/apps/{self.app_id}/store-status/refresh")
        self.assertEqual(st, 200)
        st, a = self.call("GET", f"/api/apps/{self.app_id}")
        self.assertEqual(a["store_status"]["play"]["display"]["track"], "internal")

    def test_member_cannot_touch_other_users_app(self):
        for method, path, body in (
            ("GET", f"/api/apps/{self.app_id}/store-status", None),
            ("POST", f"/api/apps/{self.app_id}/promote", {"store": "play"}),
            ("POST", f"/api/apps/{self.app_id}/submit-for-review", {"confirm": True}),
        ):
            st, _ = self.call(method, path, key=self.mkey, body=body)
            self.assertEqual(st, 404, path)
        st, res = self.call("POST", "/api/store-status/refresh", key=self.mkey)
        self.assertEqual((st, res["queued"]), (200, 0))
        self.assertEqual(self.play.calls, [])


if __name__ == "__main__":
    unittest.main()


class AutoAttachTest(unittest.TestCase):
    class Asc:
        def __init__(self, builds, versions, groups):
            self.builds, self.versions, self.groups, self.calls = builds, versions, groups, []

        def get(self, path, params=None):
            if path == "builds":
                return self.builds
            if path.endswith("/appStoreVersions"):
                return {"data": [v for v, _ in self.versions], "included": [i for _, inc in self.versions for i in inc]}
            if path.endswith("/betaGroups"):
                return {"data": self.groups}
            raise AssertionError(path)

        def post(self, path, data):
            self.calls.append(("POST", path, data))
            return {"data": {"id": "new-ver"}}

        def patch(self, path, data):
            self.calls.append(("PATCH", path, data))
            return {}

    def _builds(self, state="VALID"):
        return {"data": [
            {"type": "builds", "id": "b35", "attributes": {"version": "35", "processingState": state,
             "expired": False, "uploadedDate": "2026-11-24T12:00:00Z"},
             "relationships": {"preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "p13"}}}},
            {"type": "builds", "id": "b34", "attributes": {"version": "34", "processingState": "VALID",
             "expired": False, "uploadedDate": "2026-11-23T12:00:00Z"},
             "relationships": {"preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": "p12"}}}}],
            "included": [{"type": "preReleaseVersions", "id": "p13", "attributes": {"version": "1.0.13"}},
                         {"type": "preReleaseVersions", "id": "p12", "attributes": {"version": "1.0.12"}}]}

    GROUPS = [{"id": "g1", "attributes": {"name": "Internal", "isInternalGroup": True, "hasAccessToAllBuilds": True}},
              {"id": "g2", "attributes": {"name": "Manual", "isInternalGroup": True, "hasAccessToAllBuilds": False}}]

    def test_waits_while_processing(self):
        asc = self.Asc(self._builds("PROCESSING"), [], self.GROUPS)
        self.assertEqual(ss.auto_attach_newest_build(asc, "999")["state"], "waiting")
        self.assertEqual(asc.calls, [])

    def test_attaches_newest_and_adds_manual_groups(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        asc = self.Asc(self._builds(), [prep], self.GROUPS)
        res = ss.auto_attach_newest_build(asc, "999", "2026-11-24T11:00:00")
        self.assertEqual(res["state"], "attached")
        self.assertEqual(res["build"], "35")
        paths = [c[1] for c in asc.calls]
        self.assertIn("appStoreVersions/v12/relationships/build", paths)
        self.assertIn("betaGroups/g2/relationships/builds", paths)
        self.assertNotIn("betaGroups/g1/relationships/builds", paths)

    def test_apple_dates_with_their_own_offset_are_compared_as_instants(self):
        # 06:08 in California is 14:08 UTC: later than 13:50 UTC.
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        b = self._builds()
        b["data"][0]["attributes"]["uploadedDate"] = "2026-11-24T06:08:28-08:00"
        asc = self.Asc(b, [prep], self.GROUPS)
        self.assertEqual(ss.auto_attach_newest_build(asc, "999", "2026-11-24T13:50:00")["state"], "attached")
        asc2 = self.Asc(b, [prep], self.GROUPS)
        self.assertEqual(ss.auto_attach_newest_build(asc2, "999", "2026-11-24T14:30:00")["state"], "waiting")

    def test_never_touches_a_version_in_review(self):
        rev = _version("v12", "1.0.12", "WAITING_FOR_REVIEW", "b34", "34")
        asc = self.Asc(self._builds(), [rev], self.GROUPS)
        self.assertEqual(ss.auto_attach_newest_build(asc, "999")["state"], "skipped")
        self.assertEqual(asc.calls, [])


class FirstProductsTest(unittest.TestCase):
    class Asc:
        def __init__(self, iap_states):
            self.iap_states = iap_states
            self.posts = []
        def get(self, path, params=None):
            if path.endswith("inAppPurchasesV2"):
                return {"data": [{"id": str(i), "attributes": {"productId": f"p{i}", "state": st}}
                                 for i, st in enumerate(self.iap_states)]}
            return {"included": []}
        def post(self, path, body):
            self.posts.append(path)
            return {}

    def test_first_products_stop_with_website_instructions(self):
        asc = self.Asc(["READY_TO_SUBMIT", "READY_TO_SUBMIT"])
        with self.assertRaises(ValueError) as cm:
            ss.submit_apple_products(asc, "1")
        self.assertIn("website", str(cm.exception))
        self.assertEqual(asc.posts, [])

    def test_later_products_are_sent_by_api(self):
        asc = self.Asc(["APPROVED", "READY_TO_SUBMIT"])
        self.assertEqual(ss.submit_apple_products(asc, "1"), ["p1"])


class LiveVersionTest(unittest.TestCase):
    def test_approved_versions_get_their_own_track(self):
        self.assertEqual(ss.apple_track_for_state("PENDING_DEVELOPER_RELEASE"), "approved")
        self.assertEqual(ss.apple_track_for_state("WAITING_FOR_REVIEW"), "review")
        self.assertEqual(ss.apple_track_for_state("READY_FOR_SALE"), "live")
        # Still "in review" for every guard that must not touch the version.
        self.assertIn("PENDING_DEVELOPER_RELEASE", ss.APPLE_REVIEW_STATES)

    def test_play_live_is_the_newest_production_release_that_is_out(self):
        rows = {"play": {"data": {"entries": [
            {"track": "internal", "version": "1.0.20", "code": 20, "status": "completed"},
            {"track": "production", "version": "1.0.18", "code": 18, "status": "completed"},
            {"track": "production", "version": "1.0.19", "code": 19, "status": "draft"},
        ]}}}
        self.assertEqual(ss.compact(rows)["play"]["live"]["version"], "1.0.18")
        rows["play"]["data"]["entries"] = rows["play"]["data"]["entries"][:1]
        self.assertIsNone(ss.compact(rows)["play"]["live"])


class AutoReleaseTest(unittest.TestCase):
    class Asc:
        def __init__(self):
            self.posts = []
        def post(self, path, data):
            self.posts.append((path, data))
            return {"data": {"id": "r1"}}

    def test_only_approved_versions_waiting_for_manual_release_go_out(self):
        asc = self.Asc()
        versions = [
            {"version": "1.0.5", "state": "PENDING_DEVELOPER_RELEASE", "version_id": "v5"},
            {"version": "1.0.4", "state": "READY_FOR_SALE", "version_id": "v4"},
            {"version": "1.0.6", "state": "WAITING_FOR_REVIEW", "version_id": "v6"},
        ]
        self.assertEqual(ss.release_approved_versions(asc, versions), ["1.0.5"])
        self.assertEqual(len(asc.posts), 1)
        path, body = asc.posts[0]
        self.assertEqual(path, "appStoreVersionReleaseRequests")
        self.assertEqual(body["data"]["relationships"]["appStoreVersion"]["data"]["id"], "v5")

    def test_release_type_is_automatic(self):
        self.assertEqual(ss.APPLE_RELEASE_TYPE, "AFTER_APPROVAL")


class GameCenterSubmitTest(unittest.TestCase):
    def test_submit_switches_game_center_on_and_sends_unreleased_items(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        gc = {"achievements": [("a1", "snake.first", "PREPARE_FOR_SUBMISSION"), ("a2", "snake.old", "APPROVED")],
              "leaderboards": [("l1", "snake.best", "PREPARE_FOR_SUBMISSION")]}
        asc = FakeAsc(_builds_resp(), [prep], gc=gc)
        res = ss.submit_apple_for_review(asc, "999")
        w = asc.writes()
        self.assertIn("gameCenterAppVersions", [c[1] for c in w])
        items = [c[2]["data"]["relationships"] for c in w if c[1] == "reviewSubmissionItems"]
        gc_items = [r for r in items if "appStoreVersion" not in r]
        self.assertEqual([list(r)[1] for r in gc_items], ["gameCenterAchievementVersion", "gameCenterLeaderboardVersion"])
        self.assertEqual(res["game_center"], ["snake.first", "snake.best"])
        self.assertEqual(w[-1][1], "reviewSubmissions/sub-new")  # submitted last

    def test_no_game_center_means_nothing_extra(self):
        prep = _version("v12", "1.0.12", "PREPARE_FOR_SUBMISSION", "b34", "34")
        asc = FakeAsc(_builds_resp(), [prep])
        self.assertEqual(ss.submit_apple_for_review(asc, "999")["game_center"], [])
