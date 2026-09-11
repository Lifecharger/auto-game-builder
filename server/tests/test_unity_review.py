"""Review worker tests with private lane, process and Comfy stubs."""
from contextlib import contextmanager
import logging
from pathlib import Path
import subprocess
import tempfile
import threading
import types
import unittest
from unittest.mock import MagicMock, patch

from test_review_regressions import CORE, extract


class UnityReviewTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name)
        (self.project / "ProjectSettings").mkdir()
        (self.project / "ProjectSettings/ProjectVersion.txt").touch()
        self.exe = self.project / "Unity.exe"
        self.exe.touch()
        self.events = []

        @contextmanager
        def hold(ticket):
            self.events.append("acquire")
            try:
                yield
            finally:
                self.events.append("release")

        self.proc = MagicMock()
        self.proc.wait.return_value = 0
        logger = MagicMock(spec=logging.Logger)
        self.env = dict(Path=Path, re=__import__("re"), _lock=threading.Lock(),
            _jobs={"test": dict(app_id=23, status="queued")}, logger=logger,
            subprocess=types.SimpleNamespace(Popen=MagicMock(return_value=self.proc),
                DEVNULL=subprocess.DEVNULL, TimeoutExpired=subprocess.TimeoutExpired),
            gpu_lane=types.SimpleNamespace(hold_reserved=hold),
            get_settings=lambda: {"unity_path": str(self.exe)})
        extract(CORE / "unity_review.py", ["command", "_run"], self.env)
        core = types.ModuleType("core")
        core.comfy_gen = types.SimpleNamespace(free_memory=lambda _: self.events.append("free"))
        self.stub = patch.dict("sys.modules", {"core": core})
        self.stub.start()
        self.addCleanup(self.stub.stop)

    def run_worker(self):
        self.env["_run"]("test", {}, self.project, ["unity", str(self.project / "review.log")], 60)
        return self.env["_jobs"]["test"]

    def test_command_is_argv_and_rejects_shell_text(self):
        command = self.env["command"]
        args = command(self.project, "Project.Review.Run", self.project / "review.log")
        self.assertIn("-batchmode", args)
        self.assertNotIn("-quit", args)  # project review owns asynchronous exit
        for method in ("x;evil", "..x", "x /bad", "Single"):
            with self.assertRaises(ValueError):
                command(self.project, method, self.project / "review.log")

    def test_success_holds_lane_through_process_exit(self):
        self.assertEqual(self.run_worker()["status"], "completed")
        self.assertEqual(self.events, ["acquire", "free", "release"])

    def test_nonzero_exit_fails_and_releases_lane(self):
        self.proc.wait.return_value = 1
        self.assertEqual(self.run_worker()["status"], "failed")
        self.assertEqual(self.events[-1], "release")

    def test_timeout_kills_then_waits_before_release(self):
        self.proc.wait.side_effect = [subprocess.TimeoutExpired("unity", 60), 0]
        self.assertEqual(self.run_worker()["status"], "failed")
        self.proc.kill.assert_called_once()
        self.assertEqual(self.proc.wait.call_count, 2)
        self.assertEqual(self.events[-1], "release")

    def test_open_editor_prevents_launch(self):
        (self.project / "Temp").mkdir()
        (self.project / "Temp/UnityLockfile").touch()
        self.assertEqual(self.run_worker()["status"], "failed")
        self.env["subprocess"].Popen.assert_not_called()
