"""Multi-user AGB: users, roles, app ownership, member limits, migration 16.

Every database here is a temp file; the live server/app_manager.db is only ever
opened read-only (mode=ro) to copy its schema. The API is driven in-process
through the ASGI app without its lifespan, so nothing starts (no ComfyUI, no
deploy worker, no tunnel) and the optional generation modules are kept out of
the import so their on-disk job stores are never touched.
"""
from __future__ import annotations

import asyncio
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import sqlite3
import sys
import tempfile
import types
import unittest
from pathlib import Path

SERVER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER))

from core import access  # noqa: E402
from core import users as users_core  # noqa: E402
from database.db_manager import DBManager  # noqa: E402
from database.migrations import MIGRATIONS  # noqa: E402

LIVE_DB = SERVER / "app_manager.db"
ADMIN_KEY = "admin-test-key-not-real"
_OPTIONAL = ("core.comfy_gen", "core.jigsaw_flow", "core.yan_servisler")


_API_MODULE = "agb_api_server"


def _import_server():
    """Import api/server.py with the generation side modules blocked (they
    load and rewrite their job stores at import).

    Loaded from its file under its own module name: under `unittest discover`
    another test may already have imported the `server` *package* (the
    server/ directory), and a plain `import server` would return that."""
    if _API_MODULE in sys.modules:
        return sys.modules[_API_MODULE]
    placed = [m for m in _OPTIONAL if m not in sys.modules]
    for m in placed:
        sys.modules[m] = None
    try:
        sys.path.insert(0, str(SERVER / "api"))
        spec = importlib.util.spec_from_file_location(_API_MODULE, SERVER / "api" / "server.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules[_API_MODULE] = module
        with contextlib.redirect_stdout(io.StringIO()):
            try:
                spec.loader.exec_module(module)
            except BaseException:
                sys.modules.pop(_API_MODULE, None)
                raise
    finally:
        for m in placed:
            sys.modules.pop(m, None)
    return module


def _schema_v15_db(path: Path) -> None:
    """A version-15 database: the live DB's schema when it is present (opened
    read-only), else migrations 1..15."""
    dst = sqlite3.connect(path)
    try:
        if LIVE_DB.is_file():
            src = sqlite3.connect(f"file:{LIVE_DB}?mode=ro", uri=True)
            try:
                version = src.execute("SELECT MAX(version) FROM schema_version").fetchone()[0]
                rows = src.execute(
                    "SELECT type, name, sql FROM sqlite_master "
                    "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' "
                    "ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END"
                ).fetchall()
            finally:
                src.close()
            if version != 15:
                raise unittest.SkipTest(f"live DB is at version {version}, test expects 15")
            for _type, _name, sql in rows:
                dst.execute(sql)
            dst.executemany("INSERT INTO schema_version (version) VALUES (?)",
                            [(v,) for v in range(1, 16)])
        else:
            dst.execute("CREATE TABLE schema_version (version INTEGER PRIMARY KEY, "
                        "applied_at TEXT NOT NULL DEFAULT (datetime('now')))")
            for i, script in enumerate(MIGRATIONS[:15], start=1):
                dst.executescript(script)
                dst.execute("INSERT INTO schema_version (version) VALUES (?)", (i,))
        dst.commit()
    finally:
        dst.close()


def _call(app, method: str, path: str, key: str | None = None, body=None, query: str = ""):
    """One HTTP request straight into the ASGI app -> (status, parsed body)."""
    raw = json.dumps(body).encode() if body is not None else b""
    headers = [(b"host", b"testserver"), (b"content-length", str(len(raw)).encode())]
    if body is not None:
        headers.append((b"content-type", b"application/json"))
    if key is not None:
        headers.append((b"x-api-key", key.encode()))
    scope = {
        "type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
        "method": method, "scheme": "http", "path": path, "raw_path": path.encode(),
        "query_string": query.encode(), "root_path": "", "headers": headers,
        "client": ("127.0.0.1", 1), "server": ("testserver", 80),
    }
    out = {"status": 0, "body": b""}

    async def run():
        sent = False
        never = asyncio.Event()

        async def receive():
            nonlocal sent
            if not sent:
                sent = True
                return {"type": "http.request", "body": raw, "more_body": False}
            await never.wait()

        async def send(msg):
            if msg["type"] == "http.response.start":
                out["status"] = msg["status"]
            elif msg["type"] == "http.response.body":
                out["body"] += msg.get("body", b"")

        await app(scope, receive, send)

    asyncio.run(run())
    try:
        data = json.loads(out["body"] or b"null")
    except ValueError:
        data = out["body"]
    return out["status"], data


class _FakeDeploy:
    def __init__(self):
        self.calls = []

    def deploy(self, a, track="internal", build_target="aab", upload=False, started_by_user_id=None):
        self.calls.append((a.id, started_by_user_id))
        return {"ok": True, "message": "queued"}

    def get_status(self, app_id):
        return None


class MigrationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "copy.db"
        _schema_v15_db(self.path)
        con = sqlite3.connect(self.path)
        con.execute("INSERT INTO apps (name, slug, project_path, notes) VALUES ('Game A','game-a','/p/a','keep me')")
        con.execute("INSERT INTO builds (app_id, version, status) VALUES (1, '1.0.0', 'success')")
        con.execute("INSERT INTO notices (source, title, body) VALUES ('weekly', 'Weekly', 'body')")
        con.commit()
        con.close()

    def test_migration_16_is_additive_on_real_schema(self):
        db = DBManager(str(self.path))
        self.addCleanup(lambda: db._get_conn().close())
        con = db._get_conn()
        self.assertEqual(con.execute("SELECT MAX(version) FROM schema_version").fetchone()[0], 16)
        admin = db.get_user(1)
        self.assertEqual((admin.name, admin.role, admin.active), ("admin", "admin", True))
        self.assertEqual(con.execute("SELECT api_key_hash FROM users WHERE id=1").fetchone()[0], "")
        a = db.get_app(1)
        self.assertEqual((a.owner_user_id, a.play_account, a.git_ssh_key_path, a.notes),
                         (1, None, "", "keep me"))
        self.assertIsNone(db.get_builds(app_id=1)[0].started_by_user_id)
        self.assertIsNone(db.get_notices()[0]["user_id"])
        # Reopening runs nothing twice.
        DBManager(str(self.path))._get_conn().close()
        self.assertEqual(con.execute("SELECT COUNT(*) FROM users").fetchone()[0], 1)

    def test_full_copy_of_live_db_migrates(self):
        if not LIVE_DB.is_file():
            self.skipTest("no live database on this machine")
        full = Path(self.tmp.name) / "full.db"
        src = sqlite3.connect(f"file:{LIVE_DB}?mode=ro", uri=True)
        dst = sqlite3.connect(full)
        src.backup(dst)
        src.close()
        before = {t: dst.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                  for t in ("apps", "builds", "issues", "notices")}
        dst.close()
        db = DBManager(str(full))
        self.addCleanup(lambda: db._get_conn().close())
        con = db._get_conn()
        after = {t: con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in before}
        self.assertEqual(before, after)
        self.assertEqual(con.execute("SELECT COUNT(*) FROM apps WHERE owner_user_id != 1").fetchone()[0], 0)
        self.assertEqual(db.get_user(1).role, "admin")


class UsersCoreTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = DBManager(str(Path(self.tmp.name) / "t.db"))
        self.addCleanup(lambda: self.db._get_conn().close())

    def test_create_returns_key_once_and_stores_only_hash(self):
        user, key = users_core.create_user(self.db, "User 2", "member", self.tmp.name)
        rows = self.db._get_conn().execute("SELECT * FROM users").fetchall()
        dump = json.dumps([list(r) for r in rows])
        self.assertNotIn(key, dump)
        stored = self.db._get_conn().execute(
            "SELECT api_key_hash FROM users WHERE id=?", (user.id,)).fetchone()[0]
        self.assertEqual(stored, hashlib.sha256(key.encode()).hexdigest())
        self.assertNotIn("api_key", user.public_dict())
        self.assertNotIn("api_key_hash", user.public_dict())
        self.assertEqual(users_core.resolve_user(self.db, key, ADMIN_KEY).id, user.id)

    def test_settings_key_is_admin_and_unknown_key_is_nobody(self):
        self.assertTrue(users_core.resolve_user(self.db, ADMIN_KEY, ADMIN_KEY).is_admin)
        self.assertIsNone(users_core.resolve_user(self.db, "nope", ADMIN_KEY))
        self.assertIsNone(users_core.resolve_user(self.db, "", ADMIN_KEY))

    def test_rotate_and_deactivate(self):
        user, old = users_core.create_user(self.db, "User 2")
        new = users_core.rotate_key(self.db, user.id)
        self.assertIsNone(users_core.resolve_user(self.db, old, ADMIN_KEY))
        self.assertEqual(users_core.resolve_user(self.db, new, ADMIN_KEY).id, user.id)
        users_core.deactivate(self.db, user.id)
        self.assertIsNone(users_core.resolve_user(self.db, new, ADMIN_KEY))
        with self.assertRaises(ValueError):
            users_core.deactivate(self.db, 1)
        with self.assertRaises(ValueError):
            users_core.rotate_key(self.db, 1)

    def test_path_within(self):
        root = os.path.join(self.tmp.name, "member")
        os.makedirs(root)
        self.assertTrue(users_core.path_within(root, os.path.join(root, "Game")))
        self.assertFalse(users_core.path_within(root, root))
        self.assertFalse(users_core.path_within(root, os.path.join(root, "..", "other")))
        self.assertFalse(users_core.path_within(root, os.path.join(root, "Game", "..", "..", "x")))
        self.assertFalse(users_core.path_within(root, root + "-sibling/Game"))
        self.assertFalse(users_core.path_within("", os.path.join(root, "Game")))

    def test_play_account_resolution(self):
        s = {"service_account_key": "/k/default.json", "play_accounts": {"second": "/k/second.json"}}
        self.assertEqual(users_core.play_service_account_path(s, None), "/k/default.json")
        self.assertEqual(users_core.play_service_account_path(s, ""), "/k/default.json")
        self.assertEqual(users_core.play_service_account_path(s, "second"), "/k/second.json")
        with self.assertRaises(ValueError):
            users_core.play_service_account_path(s, "missing")

    def test_cli_add_prints_key_once_and_stores_hash(self):
        spec = importlib.util.spec_from_file_location("agb_users_cli", SERVER / "tools" / "users.py")
        cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cli)
        cli.get_settings = lambda: {"worker_url": "https://worker.example"}
        db_path = str(Path(self.tmp.name) / "cli.db")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = cli.main(["--db", db_path, "add", "--name", "User 2", "--role", "member",
                           "--projects-root", self.tmp.name])
        self.assertEqual(rc, 0)
        lines = buf.getvalue().splitlines()
        key = lines[lines.index("API key (shown once, store it now):") + 1]
        cdb = DBManager(db_path)
        self.addCleanup(lambda: cdb._get_conn().close())
        u = users_core.resolve_user(cdb, key, ADMIN_KEY)
        self.assertEqual((u.name, u.role), ("User 2", "member"))
        code = lines[lines.index("Pairing code (paste or QR):") + 1]
        import base64
        self.assertEqual(json.loads(base64.b64decode(code))["api_key"], key)
        with contextlib.redirect_stdout(io.StringIO()) as out:
            cli.main(["--db", db_path, "list"])
        self.assertNotIn(key, out.getvalue())


class ApiAccessTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = _import_server()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.admin_root = base / "admin_projects"
        self.member_root = base / "member_projects"
        self.admin_root.mkdir()
        self.member_root.mkdir()
        self.db = DBManager(str(base / "t.db"))
        self.addCleanup(lambda: self.db._get_conn().close())
        srv = self.server
        self.settings = {"api_key": ADMIN_KEY, "projects_root": str(self.admin_root),
                         "worker_url": "", "developer_name": "",
                         "play_accounts": {"second": str(base / "second.json")}}
        self.deploy = _FakeDeploy()
        self._saved = (srv.get_settings, srv.event_log, getattr(srv.app.state, "db", None),
                       getattr(srv.app.state, "deploy", None))
        srv.get_settings = lambda *a, **k: self.settings
        srv.event_log = types.SimpleNamespace(append=lambda *a, **k: None, current_seq=0,
                                              replay_since=lambda *_: [])
        srv.app.state.db = self.db
        srv.app.state.deploy = self.deploy
        self.addCleanup(self._restore)

        self.member, self.mkey = users_core.create_user(self.db, "User 2", "member", str(self.member_root))
        self.admin_app = self.db.create_app(name="Admin Game", slug="admin-game",
                                            project_path=str(self.admin_root / "Admin Game"))
        self.member_app = self.db.create_app(name="Member Game", slug="member-game",
                                             project_path=str(self.member_root / "Member Game"),
                                             owner_user_id=self.member.id)
        self.admin_build = self.db.create_build(app_id=self.admin_app, status="success")
        self.member_build = self.db.create_build(app_id=self.member_app, status="success")

    def _restore(self):
        srv = self.server
        srv.get_settings, srv.event_log, db, deploy = self._saved
        srv.app.state.db = db
        srv.app.state.deploy = deploy

    def call(self, method, path, key=None, body=None, query=""):
        return _call(self.server.app, method, path, key, body, query)

    # ── admin ──
    def test_admin_key_works_as_before(self):
        st, apps = self.call("GET", "/api/apps", ADMIN_KEY)
        self.assertEqual(st, 200)
        self.assertEqual({a["id"] for a in apps}, {self.admin_app, self.member_app})
        st, me = self.call("GET", "/api/me", ADMIN_KEY)
        self.assertEqual((st, me["role"], me["id"]), (200, "admin", 1))
        st, _ = self.call("GET", f"/api/apps/{self.member_app}", ADMIN_KEY)
        self.assertEqual(st, 200)
        self.assertEqual(self.call("GET", "/api/health")[0], 200)

    def test_bad_or_missing_key_is_401(self):
        self.assertEqual(self.call("GET", "/api/apps")[0], 401)
        self.assertEqual(self.call("GET", "/api/apps", "wrong")[0], 401)

    def test_admin_reassigns_owner_and_play_account(self):
        st, _ = self.call("PATCH", f"/api/apps/{self.admin_app}", ADMIN_KEY,
                          {"owner_user_id": self.member.id, "play_account": "second"})
        self.assertEqual(st, 200)
        a = self.db.get_app(self.admin_app)
        self.assertEqual((a.owner_user_id, a.play_account), (self.member.id, "second"))
        st, _ = self.call("PATCH", f"/api/apps/{self.admin_app}", ADMIN_KEY, {"play_account": "nope"})
        self.assertEqual(st, 400)
        st, _ = self.call("PATCH", f"/api/apps/{self.admin_app}", ADMIN_KEY, {"owner_user_id": 999})
        self.assertEqual(st, 400)

    # ── member ──
    def test_member_sees_only_own_apps(self):
        st, apps = self.call("GET", "/api/apps", self.mkey)
        self.assertEqual((st, [a["id"] for a in apps]), (200, [self.member_app]))
        st, me = self.call("GET", "/api/me", self.mkey)
        self.assertEqual((me["role"], me["name"]), ("member", "User 2"))
        st, data = self.call("GET", "/api/sync", self.mkey)
        self.assertEqual([a["id"] for a in data["apps"]], [self.member_app])
        self.assertEqual({b["app_id"] for b in data["builds"]}, {self.member_app})
        st, builds = self.call("GET", "/api/builds", self.mkey)
        self.assertEqual([b["id"] for b in builds], [self.member_build])
        st, dash = self.call("GET", "/api/dashboard", self.mkey)
        self.assertEqual([a["id"] for a in dash["apps"]], [self.member_app])

    def test_member_gets_404_on_other_users_app(self):
        other = self.admin_app
        for method, path, body in [
            ("GET", f"/api/apps/{other}", None),
            ("PATCH", f"/api/apps/{other}", {"notes": "x"}),
            ("GET", f"/api/apps/{other}/tasks", None),
            ("POST", f"/api/apps/{other}/deploy", {"track": "internal"}),
            ("GET", f"/api/apps/{other}/deploy/status", None),
            ("GET", f"/api/apps/{other}/claude-md", None),
            ("GET", f"/api/apps/{other}/icon", None),
            ("POST", f"/api/automations/{other}/start", None),
            ("GET", f"/api/builds/{self.admin_build}", None),
            ("POST", "/api/issues", {"app_id": other, "title": "t"}),
            ("POST", "/api/automations", {"app_id": other}),
            ("GET", "/api/apps/999999", None),
        ]:
            st, _ = self.call(method, path, self.mkey, body)
            self.assertEqual(st, 404, f"{method} {path}")
        self.assertEqual(self.deploy.calls, [])

    def test_member_builds_own_app_and_build_records_who(self):
        st, _ = self.call("POST", f"/api/apps/{self.member_app}/deploy", self.mkey,
                          {"track": "internal", "build_target": "aab"})
        self.assertEqual(st, 200)
        self.assertEqual(self.deploy.calls, [(self.member_app, self.member.id)])
        bid = self.db.create_build(app_id=self.member_app, started_by_user_id=self.member.id)
        st, b = self.call("GET", f"/api/builds/{bid}", self.mkey)
        self.assertEqual((st, b["started_by_user_id"], b["started_by"]), (200, self.member.id, "User 2"))

    def test_admin_only_endpoints_refuse_members(self):
        for method, path, body in [
            ("GET", "/api/users", None),
            ("POST", "/api/users", {"name": "x"}),
            ("POST", "/api/users/1/rotate-key", None),
            ("GET", "/api/play-accounts", None),
            ("GET", "/api/queue", None),
            ("POST", "/api/queue/cancel", {}),
            ("GET", "/api/gpu/queue", None),
            ("GET", "/api/r2/buckets", None),
            ("GET", "/api/generate", None),
            ("GET", "/api/delivery/rules", None),
            ("GET", "/api/mcp/presets", None),
            ("POST", "/api/reset", None),
            ("POST", "/api/chat", {}),
            ("POST", "/api/apps/scan", None),
            ("POST", "/api/reports/pull", None),
            ("GET", "/api/card/flow/collections", None),
            ("PUT", f"/api/apps/{self.member_app}/mcp", {"mcp_servers": []}),
            ("GET", "/docs", None),
        ]:
            st, _ = self.call(method, path, self.mkey, body)
            self.assertEqual(st, 403, f"{method} {path}")
        # Admin-only fields on an own app.
        for field, value in (("play_account", "second"), ("owner_user_id", 1),
                             ("git_ssh_key_path", "/k/id")):
            st, _ = self.call("PATCH", f"/api/apps/{self.member_app}", self.mkey, {field: value})
            self.assertEqual(st, 403, field)
        st, _ = self.call("POST", "/api/automations", self.mkey,
                          {"app_id": self.member_app, "mcp_servers": ["x"]})
        self.assertEqual(st, 403)

    def test_member_project_path_must_stay_in_root(self):
        app_path = f"/api/apps/{self.member_app}"
        for bad in ("/etc/x", str(self.admin_root / "Stolen"), str(self.member_root),
                    str(self.member_root / ".." / "admin_projects" / "x"),
                    str(self.member_root) + "-sibling/x"):
            st, _ = self.call("PATCH", app_path, self.mkey, {"project_path": bad})
            self.assertEqual(st, 400, bad)
        good = str(self.member_root / "Renamed")
        st, _ = self.call("PATCH", app_path, self.mkey, {"project_path": good})
        self.assertEqual(st, 200)
        self.assertEqual(self.db.get_app(self.member_app).project_path, good)

    def test_member_creates_app_under_own_root_and_owns_it(self):
        st, res = self.call("POST", "/api/apps", self.mkey, {"name": "Word Quiz", "app_type": "flutter"})
        self.assertEqual(st, 200, res)
        a = self.db.get_app(res["id"])
        self.assertEqual(a.owner_user_id, self.member.id)
        self.assertTrue(users_core.path_within(str(self.member_root), a.project_path))
        self.assertTrue((self.member_root / "Word Quiz" / "tasklist.json").is_file())
        st, _ = self.call("POST", "/api/apps", self.mkey, {"name": "../escape", "app_type": "flutter"})
        self.assertEqual(st, 400)
        self.assertFalse((Path(self.tmp.name) / "escape").exists())
        # Without a root a member can't create apps; the admin's root is never used.
        self.db.update_user(self.member.id, projects_root="")
        st, _ = self.call("POST", "/api/apps", self.mkey, {"name": "Other", "app_type": "flutter"})
        self.assertEqual(st, 400)
        self.assertFalse((self.admin_root / "Other").exists())
        # The admin's new app goes under the settings root, owned by the admin.
        st, res = self.call("POST", "/api/apps", ADMIN_KEY, {"name": "Admin Two", "app_type": "flutter"})
        self.assertEqual(st, 200)
        self.assertEqual(self.db.get_app(res["id"]).owner_user_id, 1)
        self.assertTrue((self.admin_root / "Admin Two").is_dir())

    def test_users_endpoints(self):
        st, res = self.call("POST", "/api/users", ADMIN_KEY,
                            {"name": "User 3", "projects_root": str(self.member_root)})
        self.assertEqual(st, 200)
        key, uid = res["api_key"], res["user"]["id"]
        st, listed = self.call("GET", "/api/users", ADMIN_KEY)
        self.assertNotIn(key, json.dumps(listed))
        self.assertTrue(all("api_key" not in u and "api_key_hash" not in u for u in listed))
        self.assertEqual(self.call("GET", "/api/me", key)[1]["name"], "User 3")
        st, rot = self.call("POST", f"/api/users/{uid}/rotate-key", ADMIN_KEY)
        self.assertEqual(self.call("GET", "/api/me", key)[0], 401)
        self.assertEqual(self.call("GET", "/api/me", rot["api_key"])[0], 200)
        self.assertEqual(self.call("POST", f"/api/users/{uid}/deactivate", ADMIN_KEY)[0], 200)
        self.assertEqual(self.call("GET", "/api/me", rot["api_key"])[0], 401)
        self.assertEqual(self.call("POST", "/api/users/1/deactivate", ADMIN_KEY)[0], 400)
        self.assertEqual(self.call("POST", "/api/users", ADMIN_KEY, {"name": "x", "role": "root"})[0], 400)

    def test_notices_are_scoped(self):
        self.db.upsert_notice("weekly", "Admin note", "b", note_key="k")
        st, n = self.call("POST", "/api/notices", self.mkey, {"title": "Mine", "key": "k"})
        self.assertEqual(st, 200)
        st, mine = self.call("GET", "/api/notices", self.mkey)
        self.assertEqual([x["title"] for x in mine], ["Mine"])
        st, alln = self.call("GET", "/api/notices", ADMIN_KEY)
        self.assertEqual(sorted(x["title"] for x in alln), ["Admin note", "Mine"])
        admin_note = [x for x in alln if x["title"] == "Admin note"][0]
        self.assertEqual(self.call("DELETE", f"/api/notices/{admin_note['id']}", self.mkey)[0], 404)
        self.assertEqual(self.call("GET", "/api/notices/count", self.mkey)[1]["total"], 1)

    def test_events_only_carry_own_apps_for_members(self):
        srv = self.server
        member = self.db.get_user(self.member.id)
        self.assertTrue(srv._event_visible(member, {"type": "app.status_changed", "app_id": self.member_app}))
        self.assertFalse(srv._event_visible(member, {"type": "app.status_changed", "app_id": self.admin_app}))
        self.assertFalse(srv._event_visible(member, {"type": "app.updated", "app": {"id": self.admin_app}}))
        self.assertFalse(srv._event_visible(member, {"type": "server.thing"}))
        self.assertTrue(srv._event_visible(users_core.implicit_admin(), {"type": "x", "app_id": self.admin_app}))


class AccessPolicyTest(unittest.TestCase):
    def test_unlisted_routes_default_to_admin_only(self):
        member = users_core.User(id=2, name="m", role="member")
        for path in ("/api/settings", "/api/some/new/global/tool", "/api/users/2"):
            d = access.check(None, member, "GET", path)
            self.assertEqual(d.status, 403, path)
        self.assertIsNone(access.check(None, users_core.implicit_admin(), "GET", "/api/anything"))


if __name__ == "__main__":
    unittest.main()
