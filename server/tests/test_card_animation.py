"""Card animation contracts, without loading the live dispatcher."""
import json
import math
import os
from pathlib import Path
import random
import tempfile
import types
import unittest
from unittest.mock import Mock

from test_review_regressions import CORE, extract


class CardAnimationTests(unittest.TestCase):
    def env(self):
        env = {"SECONDS": 6, "anim_id": lambda x: (x or "idle").lower()}
        return extract(CORE / "card_flow.py", {"animation_seconds"}, env)

    def test_victory_cut_is_24_frames_and_two_rows(self):
        tool = types.SimpleNamespace(cut_video=Mock(return_value={}))
        env = self.env()
        env.update(FPS=12, COLS=12, math=math, SHEET_QUALITY=85,
                   still_size=lambda kind: (832, 1248))
        extract(CORE / "card_flow.py", {"_cut_call"}, env)
        env["_cut_call"](tool, "video", "output", "sam", "woman", (512, 768),
                          (640, 960), anim="victory")
        args = tool.cut_video.call_args.kwargs
        self.assertEqual(args["seconds"] * args["fps"], 24)
        self.assertEqual(args["grid"], (12, 2))

    def test_selected_engine_and_exact_prompt_are_retained(self):
        with tempfile.TemporaryDirectory() as folder:
            Path(folder, "still.png").touch()
            submit = Mock(return_value={"id": "job", "combined": "one compact fist pump, locked camera"})
            env = self.env()
            env.update(os=os, random=random, rank_dir=lambda *a: folder,
                       gesture_text=lambda *a: "one compact fist pump",
                       engine_of=lambda *a: "minimax", VIDEO_ENGINES={"minimax": {"task": "h3"}},
                       G=types.SimpleNamespace(submit=submit, _task=lambda task: True),
                       still_size=lambda kind: (832, 1248), _motion2=lambda kind: "{}, locked camera",
                       _negative=lambda kind: "bad anatomy")
            extract(CORE / "card_flow.py", {"_video_job"}, env)
            job = env["_video_job"]("collection", "card", "A", "victory", anim="victory")
            self.assertEqual(submit.call_args.args[0], "h3")
            self.assertEqual(submit.call_args.kwargs["duration"], 2)
            self.assertEqual(job["motion_prompt"], "one compact fist pump, locked camera")
            env["G"]._task = lambda task: False
            with self.assertRaisesRegex(ValueError, "unavailable"):
                env["_video_job"]("collection", "card", "A", "victory")

    def test_default_profiles_use_one_bounded_gesture(self):
        profiles = json.loads((CORE.parent / "config/card_options.json").read_text(encoding="utf-8"))
        for kind in ("card", "dealer"):
            for tag in ("idle", "victory"):
                self.assertEqual(profiles[kind]["jest_karisim"][tag]["n"], 1)
            self.assertIn("hands below shoulder", profiles[kind]["video_sablon"])

    def test_move_retries_preview_lock_without_losing_output(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder, "source.mp4")
            dest = Path(folder, "pool", "video.mp4")
            source.write_bytes(b"video")
            import shutil
            error = PermissionError("preview still reading")
            error.winerror = 32
            attempts = []
            def move(src, target):
                attempts.append(src)
                if len(attempts) == 1:
                    Path(target).write_bytes(b"video")
                    raise error
                return shutil.move(src, target)
            env = {"os": os, "shutil": types.SimpleNamespace(move=move),
                   "time": types.SimpleNamespace(sleep=lambda seconds: None)}
            extract(CORE / "card_flow.py", {"_tasi"}, env)
            env["_tasi"](str(source), str(dest))
            self.assertEqual(dest.read_bytes(), b"video")
            self.assertFalse(source.exists())
            self.assertEqual(len(attempts), 2)


if __name__ == "__main__":
    unittest.main()
