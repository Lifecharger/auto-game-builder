"""Regression tests without importing the live server or generation dispatcher.

Only selected function definitions are loaded; filesystem fixtures, lane state,
network and subprocesses are private to the tests. Run with unittest discovery.
"""
from __future__ import annotations

import ast
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import types
import unittest

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "core"


def extract(path, names, env, class_name=None):
    body = ast.parse(path.read_text(encoding="utf-8-sig")).body
    if class_name:
        body = next(n.body for n in body if isinstance(n, ast.ClassDef) and n.name == class_name)
    selected = [n for n in body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name in names]
    assert len(selected) == len(names), names
    for n in selected:
        n.decorator_list = []
    module = ast.Module(body=[ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0)] + selected, type_ignores=[])
    exec(compile(ast.fix_missing_locations(module), str(path), "exec"), env)
    return env


class Regressions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.pkg = types.ModuleType("regression_core")
        self.pkg.__path__ = []
        sys.modules[self.pkg.__name__] = self.pkg
        spec = importlib.util.spec_from_file_location("regression_core.gpu_lane", CORE / "gpu_lane.py")
        self.lane = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = self.lane
        spec.loader.exec_module(self.lane)
        self.pkg.gpu_lane = self.lane
        self.addCleanup(lambda: [sys.modules.pop(k, None) for k in list(sys.modules) if k.startswith("regression_core")])

    def test_reorder_preserves_dispatcher_ticket_and_other_kinds(self):
        lane = self.lane
        with lane.hold("block", "test"):
            a = lane.reserve("A", "comfy", job_id="A")
            other = lane.reserve("build", "build")
            b = lane.reserve("B", "comfy", job_id="B")
            c = lane.reserve("C", "comfy", job_id="C")
            env = {"__package__": self.pkg.__name__, "_cv": threading.Condition(),
                   "_queue": ["B", "C"], "_tickets": {"B": b, "C": c}}
            extract(CORE / "comfy_gen.py", {"move_job"}, env)
            self.assertTrue(env["move_job"]("C", -1))
            self.assertEqual([w["id"] for w in lane.status()["waiting"]],
                             [a["id"], other["id"], c["id"], b["id"]])
        with lane.hold_reserved(a):
            self.assertEqual(lane.status()["running"]["job_id"], "A")
        for ticket in (other, b, c):
            lane.drop(ticket)

    def test_dropped_waiter_exits_with_lane_cancelled(self):
        lane = self.lane
        errors = []
        with lane.hold("block", "test"):
            ticket = lane.reserve("waiter")
            def wait():
                try:
                    with lane.hold_reserved(ticket):
                        errors.append("entered")
                except Exception as e:
                    errors.append(type(e))
            thread = threading.Thread(target=wait, daemon=True)
            thread.start()
            lane.drop(ticket)
            thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertEqual(errors, [lane.LaneCancelled])

    def engine(self):
        names = {"__init__", "deploy", "_enqueue_deploy", "cancel", "_cancel_locked",
                 "_update_status", "_is_cancelled", "_run_deploy", "_deploy_worker"}
        env = {"__package__": self.pkg.__name__, "datetime": datetime, "threading": threading,
               "VALID_TRACKS": ("internal",), "BUILD_TARGETS": {"flutter": {"aab": {"label": "AAB"}}}}
        extract(CORE / "deploy_engine.py", names, env, "DeployEngine")
        engine = types.SimpleNamespace()
        for name in names:
            setattr(engine, name, types.MethodType(env[name], engine))
        engine.__init__(None, {})
        engine._emit = lambda *a: None
        engine._set_app_status = lambda *a: None
        return engine

    def test_cancelled_popped_build_cannot_be_revived_by_retry(self):
        engine = self.engine()
        engine._inflight.add(6)  # Worker has popped it, but is waiting on GPU.
        engine._active_deploys[6] = {"phase": "queued"}
        observed = []
        engine._run_deploy_inner = lambda *a: observed.append(a[3])
        app = types.SimpleNamespace(id=6, name="Fixture", app_type="flutter", package_name="example.fixture")
        with self.lane.hold("block", "test"):
            thread = threading.Thread(target=engine._run_deploy, args=(app, "internal", "aab", True, 0), daemon=True)
            thread.start()
            for _ in range(200):
                if self.lane.status()["waiting"]:
                    break
                time.sleep(.005)
            self.assertTrue(self.lane.status()["waiting"])
            engine.cancel(6)
            self.assertIn("error", engine.deploy(app, upload=False))
            self.assertTrue(engine._is_cancelled(6))
            thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertEqual(observed, [])
        engine._inflight.clear()
        engine._deploy_worker_running = True
        self.assertTrue(engine.deploy(app, upload=False)["ok"])
        engine._deploy_worker()
        self.assertEqual(observed, [False])
        self.assertEqual(engine._inflight, set())

    def test_concurrent_build_requests_accept_only_one(self):
        engine = self.engine()
        engine._deploy_worker_running = True
        app = types.SimpleNamespace(id=6, name="Fixture", app_type="flutter", package_name="example.fixture")
        gate = threading.Barrier(2)
        def submit():
            gate.wait(2)
            return engine.deploy(app)
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: submit(), range(2)))
        self.assertEqual(sum(bool(r.get("ok")) for r in results), 1)
        self.assertEqual(len(engine._deploy_queue), 1)

    def test_agent_prompt_title_path_and_pipeline_rule(self):
        folder = self.path / "Auto Game Builder"
        folder.mkdir()
        env = {"os": os, "to_unix_path": lambda p: str(p).replace("\\", "/"),
               "_get_tool_paths": lambda: {k + "_bin": k for k in ("claude", "gemini", "codex", "aider")},
               "_load_studio_knowledge": lambda _: "", "_load_automation_instructions": lambda: "",
               "get_settings": lambda: {}, "_resolve_mcp_config": lambda *a: "", "AUTOMATIONS_DIR": str(folder)}
        extract(ROOT / "api/server.py", {"_build_ai_command", "_generate_task_script"}, env)
        app = types.SimpleNamespace(project_path=str(folder), name="Fixture", app_type="flutter", slug="fixture")
        title = 'Keep literal $(echo SHOULD_NOT_EXECUTE) and `backticks`'
        script = env["_generate_task_script"](app, {"ai_agent": "codex"}, {"id": 42, "title": title})
        prompt_path = folder / "fixture_task_42.prompt.txt"
        prompt = prompt_path.read_text(encoding="utf-8")
        self.assertIn("Task #42: " + title, prompt)
        self.assertIn("gpu_lane", prompt)
        self.assertNotIn("timeout 300 <godot/flutter build command>", prompt)
        for agent in ("codex", "gemini", "local"):
            command = env["_build_ai_command"](agent, 10, "claude", "gemini", "codex", str(folder), app)
            self.assertIn('"$(cat "$PROMPT_FILE")"', command)
        bash = shutil.which("bash")
        if bash and Path(bash).exists():
            result = subprocess.run([bash, "--noprofile", "--norc", "-c",
                'PROMPT_FILE="$1"; printf "%s" "$(cat "$PROMPT_FILE")"', "test", str(prompt_path).replace("\\", "/")],
                capture_output=True, text=True, encoding="utf-8", timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, prompt.rstrip("\n"))

    def generation(self):
        (self.path / "music.json").write_text("{}", encoding="utf-8")
        (self.path / "fixture.mp3").write_bytes(b"audio fixture")
        env = {"__package__": self.pkg.__name__, "os": os, "json": json, "shutil": shutil,
               "threading": threading, "datetime": datetime,
               "time": types.SimpleNamespace(time=lambda: 0.0, sleep=lambda _: None),
               "_task": lambda _: {"workflow": "music.json", "is_video": False},
               "_jobs": {}, "_lock": threading.Lock(), "comfy_up": lambda: True,
               "_wf2api": lambda: types.SimpleNamespace(convert=lambda *a: {}, validate_graph=lambda _: []),
               "WFDIR": str(self.path), "workflow_inputs": lambda _: [], "_apply_slot_files": lambda *a: None,
               "_watch_progress": lambda *a: None, "_post": lambda *a: {"prompt_id": "pid"},
               "_get": lambda _: {"pid": {"status": {"status_str": "success"}, "outputs": {"1": {"audio": [{"filename": "fixture.mp3"}]}}}},
               "COMFY_OUT": str(self.path), "OUT_DIR": str(self.path / "generated"),
               "_persist": lambda: None, "_persist_locked": lambda: None, "thumb": lambda *a: None,
               "_KIND_EXT": {"audio": (".mp3",)}, "_queue": [], "_tickets": {}, "_current": None}
        env["_cv"] = threading.Condition(env["_lock"])
        extract(CORE / "comfy_gen.py", {"_run_job", "_stop_prompt", "cancel_job", "clear_queue", "_drop_ticket_locked"}, env)
        return env

    def run_generation(self, env, jid):
        env["_jobs"][jid] = {"id": jid, "mode": "free", "status": "queued"}
        env["_run_job"](jid, "music", {"seed": 1, "width": 0, "height": 0, "prompt": "music", "negative": "", "turbo": True})
        return env["_jobs"][jid]

    def test_audio_history_is_saved_as_completed_media(self):
        job = self.run_generation(self.generation(), "audio")
        self.assertEqual(job["status"], "done")
        self.assertTrue(job["is_audio"])
        self.assertEqual(Path(job["file"]).read_bytes(), b"audio fixture")

    def test_cancel_during_prompt_response_holds_lane_until_stopped(self):
        env = self.generation()
        calls = []
        state = {"running": True, "failed_read": False, "cancels": 0}
        def post(path, payload):
            calls.append((path, payload))
            self.assertEqual(self.lane.status()["running"]["kind"], "comfy")
            if path == "/prompt":
                self.assertTrue(env["cancel_job"]("race"))
                return {"prompt_id": "late-pid"}
            if path == "/api/jobs/late-pid/cancel":
                self.assertEqual(payload, {})
                state["cancels"] += 1
                if state["cancels"] >= 3:
                    state["running"] = False
            return {}
        def get(path):
            self.assertEqual(path, "/queue")
            if not state["failed_read"]:
                state["failed_read"] = True
                raise OSError("transient connection failure")
            return {"queue_running": [[1, "late-pid"]] if state["running"] else [[2, "someone-else"]],
                    "queue_pending": []}
        env.update(_post=post, _get=get)
        with self.lane.hold("fixture", "comfy"):
            job = self.run_generation(env, "race")
        self.assertEqual(job["status"], "cancelled")
        self.assertFalse(state["running"])
        self.assertIn(("/api/jobs/late-pid/cancel", {}), calls)
        self.assertIsNone(self.lane.status()["running"])

    def test_clear_includes_selected_waiter_but_preserves_running_job(self):
        env = self.generation()
        env["_jobs"] = {j: {"id": j, "status": "queued"} for j in ("selected", "pending", "running")}
        env["_current"] = "running"
        env["_queue"] = ["pending"]
        selected = self.lane.reserve("selected", "comfy", job_id="selected")
        env["_tickets"]["pending"] = self.lane.reserve("pending", "comfy", job_id="pending")
        self.assertEqual(env["clear_queue"](), 2)
        self.assertTrue(selected["cancelled"])
        self.assertNotIn("cancel", env["_jobs"]["running"])
        self.lane.drop(selected)

    def test_snapshot_cursor_does_not_ack_unseen_event(self):
        log = types.SimpleNamespace(current_seq=10)
        class DB:
            def count_issues_by_app(self, **kw): return {}
            def get_all_apps(self, **kw): return [{"id": 6, "status": "idle"}]
            def get_all_issues(self):
                log.current_seq = 11
                return []
            def get_all_builds(self): return []
            def get_all_sessions(self): return []
        env = {"_reconcile_tasklist_mtimes": lambda: None, "db": DB,
               "_app_dict": lambda a, **kw: dict(a), "event_log": log,
               "_utc_now_str": lambda: "2026-09-11 10:00:01"}
        extract(ROOT / "api/server.py", {"sync_delta"}, env)
        result = env["sync_delta"]()
        self.assertEqual(result["event_seq"], 10)
        self.assertEqual(log.current_seq, 11)

    def test_delta_includes_updates_at_cursor_second(self):
        conn = sqlite3.connect(":memory:")
        self.addCleanup(conn.close)
        conn.row_factory = sqlite3.Row
        conn.execute("CREATE TABLE apps (id INTEGER, updated_at TEXT, created_at TEXT)")
        conn.execute("INSERT INTO apps VALUES (1, '2026-09-11 10:00:01', '2026-01-01 00:00:00')")
        env = {}
        path = ROOT / "database/db_manager.py"
        extract(path, {"_normalize_since"}, env)
        extract(path, {"get_apps_since"}, env, "DBManager")
        db = types.SimpleNamespace(_get_conn=lambda: conn, _row_to_app=dict)
        self.assertEqual(env["get_apps_since"](db, "2026-09-11T10:00:01.900Z")[0]["id"], 1)

    def test_unified_queue_reports_movable_pending_tickets(self):
        self.pkg.comfy_gen = types.SimpleNamespace(queue_state=lambda: {"pending": [{"id": "B"}, {"id": "C"}]})
        for jid in "ABC":
            self.lane.reserve(jid, "comfy", job_id=jid)
        env = {"__package__": self.pkg.__name__, "_bilet": lambda t: dict(t)}
        extract(CORE / "queue_view.py", {"snapshot"}, env)
        result = env["snapshot"]()
        self.assertEqual(result["comfy_pending"], [])
        self.assertEqual([(t["can_move_up"], t["can_move_down"]) for t in result["waiting"]],
                         [(False, False), (False, True), (True, False)])

    def test_concurrent_card_settings_and_state_keep_both_updates(self):
        env = {"os": os, "json": json, "tempfile": tempfile, "threading": threading,
               "_json_locks": {}, "_json_locks_guard": threading.Lock(), "kind_id": lambda k: k,
               "col_dir": lambda *a, **kw: str(self.path), "rank_dir": lambda *a, **kw: str(self.path),
               "MODELLER": {"zimage": 1, "qwen": 2}, "VIDEO_ENGINES": {"ltx": 1},
               "collection_model": lambda m: m["model"], "face_detail_on": lambda m: m["face_detail"],
               "collection_engine": lambda m: m["video_engine"], "video_engines": lambda: []}
        extract(CORE / "card_flow.py", {"_json_lock", "_read_json", "_write_json", "collection_meta",
                "_save_collection", "_update_collection", "set_settings", "_set_state"}, env)
        env["_save_collection"]("fixture", "", {"model": "zimage", "face_detail": False, "video_engine": "ltx"})
        # Slow reads force overlap if the read-modify-write lock is removed.
        read = env["_read_json"]
        def slow_read(*args):
            snapshot = read(*args)
            time.sleep(.02)
            return snapshot
        env["_read_json"] = slow_read
        gate = threading.Barrier(2)
        def change(kw):
            gate.wait(2)
            return env["set_settings"]("fixture", **kw)
        with ThreadPoolExecutor(2) as pool:
            list(pool.map(change, [{"model": "qwen"}, {"face_detail": True}]))
        env["_update_collection"]("fixture", "", jokers=2)
        saved = env["collection_meta"]("fixture")
        self.assertEqual((saved["model"], saved["face_detail"], saved["jokers"]), ("qwen", True, 2))
        with ThreadPoolExecutor(2) as pool:
            list(pool.map(lambda kw: env["_set_state"]("fixture", "A", "", **kw), [{"video": "v"}, {"still": "s"}]))
        self.assertEqual(read(str(self.path / "state.json")), {"video": "v", "still": "s", "rank": "A"})
        self.assertEqual(list(self.path.glob("*.tmp")), [])

    def test_studio_error_callback_survives_except_scope(self):
        studio = Path(os.environ.get("AGB_STUDIO_PATH", ""))
        if not studio.is_file():
            self.skipTest("Set AGB_STUDIO_PATH to test the external desktop client")
        callbacks, messages = [], []
        class InlineThread:
            def __init__(self, target, **kw): self.target = target
            def start(self): self.target()
        def fail(*a): raise RuntimeError("fixture network error")
        env = {"messagebox": types.SimpleNamespace(askyesno=lambda *a, **kw: True),
               "threading": types.SimpleNamespace(Thread=InlineThread)}
        extract(studio, {"save"}, env, "DeliveryPanel")
        panel = types.SimpleNamespace(rules={"default": {}, "apps": {}},
            api=types.SimpleNamespace(delivery_save=fail),
            app=types.SimpleNamespace(root=types.SimpleNamespace(after=lambda _, cb: callbacks.append(cb)),
                                      say=lambda *a: messages.append(a)))
        env["save"](panel)
        callbacks[0]()
        self.assertIn("fixture network error", messages[0][0])


if __name__ == "__main__":
    unittest.main()
