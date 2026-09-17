"""The r2manager pipeline steps ported into the flow module (#381).

Only the functions under test are loaded - no ComfyUI, no ffmpeg, no network.
"""
from __future__ import annotations

import os
from pathlib import Path
import tempfile
import unittest

from test_review_regressions import CORE, extract


def _env(names, extra=None):
    env = {"os": os, "shutil": __import__("shutil")}
    env.update(extra or {})
    extract(CORE / "jigsaw_flow.py", names, env)
    return env


class PairingTests(unittest.TestCase):
    """Phase B/C of Match Videos: the globally best pairing, then the extras."""

    def setUp(self):
        self.env = _env({"_pair"})

    def test_best_error_wins_and_each_video_is_claimed_once(self):
        pairs = sorted([(5.0, "a.jpg", "v1.mp4"), (1.0, "b.jpg", "v1.mp4"),
                        (9.0, "a.jpg", "v2.mp4")])
        birincil, fazla, hata, _s = self.env["_pair"](pairs)
        self.assertEqual(birincil, {"b.jpg": "v1.mp4", "a.jpg": "v2.mp4"})
        self.assertEqual(fazla, {})
        self.assertEqual(hata["b.jpg"], 1.0)

    def test_a_videoless_image_is_served_before_anyone_gets_an_extra(self):
        # v2 matches a.jpg better than b.jpg, but b.jpg has nothing else, so the
        # primary pass must hand v2 to b.jpg rather than leave b.jpg empty.
        pairs = sorted([(1.0, "a.jpg", "v1.mp4"), (2.0, "a.jpg", "v2.mp4"),
                        (8.0, "b.jpg", "v2.mp4")])
        birincil, fazla, _h, _s = self.env["_pair"](pairs)
        self.assertEqual(birincil, {"a.jpg": "v1.mp4", "b.jpg": "v2.mp4"})
        self.assertEqual(fazla, {})

    def test_unclaimed_videos_become_extras_of_their_best_match(self):
        pairs = sorted([(1.0, "a.jpg", "v1.mp4"), (3.0, "a.jpg", "v2.mp4"),
                        (4.0, "a.jpg", "v3.mp4")])
        birincil, fazla, _h, sahipli = self.env["_pair"](pairs)
        self.assertEqual(birincil, {"a.jpg": "v1.mp4"})
        self.assertEqual(fazla, {"a.jpg": ["v2.mp4", "v3.mp4"]})
        self.assertEqual(sahipli, {"v1.mp4", "v2.mp4", "v3.mp4"})

    def test_nothing_under_the_threshold_means_nothing_is_paired(self):
        birincil, fazla, _h, sahipli = self.env["_pair"]([])
        self.assertEqual((birincil, fazla, sahipli), ({}, {}, set()))


class BundleTests(unittest.TestCase):
    """Reject deletes the whole bundle, extras included."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.env = _env({"_bundle_paths"})

    def _touch(self, *names):
        for n in names:
            Path(self.dir, n).write_bytes(b"x")

    def test_bundle_collects_sidecar_video_and_every_extra(self):
        self._touch("7.jpg", "7.json", "7.mp4", "7.webp",
                    "7-extra.mp4", "7-extra.json", "7-extra2.mp4",
                    "8.jpg", "8.mp4", "70.jpg")
        got = [os.path.basename(p) for p in self.env["_bundle_paths"](str(self.dir / "7.jpg"))]
        self.assertEqual(got, ["7.jpg", "7.mp4", "7.webp", "7.json",
                              "7-extra.mp4", "7-extra.json", "7-extra2.mp4"])

    def test_a_longer_stem_is_not_mistaken_for_an_extra(self):
        self._touch("7.jpg", "70.mp4", "7x-extra.mp4")
        got = [os.path.basename(p) for p in self.env["_bundle_paths"](str(self.dir / "7.jpg"))]
        self.assertEqual(got, ["7.jpg"])

    def test_missing_companions_are_simply_absent(self):
        self._touch("9.jpg")
        got = [os.path.basename(p) for p in self.env["_bundle_paths"](str(self.dir / "9.jpg"))]
        self.assertEqual(got, ["9.jpg"])


class KeepNamesTests(unittest.TestCase):
    """Save Accept refuses to overwrite a number another asset already owns."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.env = _env({"_taken_name"})

    def test_any_extension_counts_as_taken(self):
        Path(self.dir, "12.mp4").write_bytes(b"x")
        self.assertEqual(self.env["_taken_name"](str(self.dir), "12"), "12.mp4")

    def test_a_free_number_and_a_missing_folder_report_nothing(self):
        self.assertEqual(self.env["_taken_name"](str(self.dir), "13"), "")
        self.assertEqual(self.env["_taken_name"](str(self.dir / "yok"), "13"), "")

    def test_a_prefix_of_another_number_is_not_a_clash(self):
        Path(self.dir, "120.jpg").write_bytes(b"x")
        self.assertEqual(self.env["_taken_name"](str(self.dir), "12"), "")


class MissingWebpScanTests(unittest.TestCase):
    """The scan walks the staging root itself, so a video with no jpg twin and a
    collection past the old 1000-row page are both found."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = _env({"_videos_without_webp"},
                        {"paths": lambda rating: {"staging": str(self.root)}})

    def _coll(self, name, *files):
        d = self.root / name
        d.mkdir(parents=True, exist_ok=True)
        for f in files:
            Path(d, f).write_bytes(b"x")

    def test_only_videos_without_a_twin_are_returned(self):
        self._coll("Generic", "1.jpg", "1.mp4", "1.webp", "2.jpg", "2.mp4", "3.jpg")
        self.assertEqual(self.env["_videos_without_webp"]("hot"),
                         [str(self.root / "Generic" / "2.mp4")])

    def test_extra_videos_never_need_a_webp(self):
        self._coll("Generic", "1.jpg", "1.mp4", "1.webp", "1-extra.mp4", "1-extra2.mp4")
        self.assertEqual(self.env["_videos_without_webp"]("hot"), [])

    def test_a_video_whose_image_is_gone_is_still_found(self):
        self._coll("Space", "4.mp4")
        self.assertEqual(self.env["_videos_without_webp"]("hot"),
                         [str(self.root / "Space" / "4.mp4")])

    def test_a_single_collection_can_be_asked_for(self):
        self._coll("Generic", "1.mp4")
        self._coll("Space", "2.mp4")
        self.assertEqual(self.env["_videos_without_webp"]("hot", "space"),
                         [str(self.root / "Space" / "2.mp4")])


if __name__ == "__main__":
    unittest.main()
