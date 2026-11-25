"""AppleManager.embed_entitlements: capabilities (Sign in with Apple, Game Center) survive the
unsigned archive -> exportArchive pipeline."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

try:
    from server.core.apple_manager import AppleManager
except ImportError:
    from core.apple_manager import AppleManager

ENT = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>com.apple.developer.applesignin</key><array><string>Default</string></array></dict></plist>
"""


class EmbedEntitlementsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def _project(self, name, entitlements=ENT):
        root = Path(self.tmp.name) / name
        runner = root / "proj" / "ios" / "Runner"
        runner.mkdir(parents=True)
        if entitlements is not None:
            (runner / "Runner.entitlements").write_text(entitlements)
        (root / "Runner.xcarchive" / "Products" / "Applications" / "Runner.app").mkdir(parents=True)
        return str(root / "proj"), str(root / "Runner.xcarchive")

    def test_no_entitlements_file_is_nothing_to_do(self):
        proj, arch = self._project("a", entitlements=None)
        with patch.object(subprocess, "run") as run:
            self.assertTrue(AppleManager.embed_entitlements(proj, arch))
        run.assert_not_called()

    def test_signs_the_archived_app_with_the_project_entitlements(self):
        proj, arch = self._project("b")
        logs = []
        with patch.object(subprocess, "run",
                          side_effect=lambda cmd, **kw: subprocess.CompletedProcess(cmd, 0, "", "")) as run:
            self.assertTrue(AppleManager.embed_entitlements(proj, arch, logs.append))
        cmd = run.call_args[0][0]
        self.assertEqual(cmd[:4], ["codesign", "--force", "--sign", "-"])
        self.assertTrue(cmd[cmd.index("--entitlements") + 1].endswith(os.path.join("ios", "Runner", "Runner.entitlements")))
        self.assertTrue(cmd[-1].endswith("Runner.app"))
        self.assertIn("embedded", logs[-1])

    def test_build_variables_or_a_failed_codesign_stop_the_build(self):
        proj, arch = self._project("c")
        with patch.object(subprocess, "run",
                          side_effect=lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1, "", "boom")):
            self.assertFalse(AppleManager.embed_entitlements(proj, arch, lambda m: None))
        proj2, arch2 = self._project("d", entitlements=ENT.replace("Default", "$(TEAM)"))
        self.assertFalse(AppleManager.embed_entitlements(proj2, arch2, lambda m: None))

    def test_godot_entitlements_path(self):
        """Godot writes <scheme>/<scheme>.entitlements next to its Xcode project; that file is used."""
        proj, arch = self._project("g", entitlements=None)
        godot_ent = Path(proj) / "build" / "ios" / "Game" / "Game.entitlements"
        godot_ent.parent.mkdir(parents=True)
        godot_ent.write_text(ENT.replace("<key>com.apple.developer.applesignin</key><array><string>Default</string></array>",
                                         "<key>com.apple.developer.game-center</key><true/>"))
        with patch.object(subprocess, "run",
                          side_effect=lambda cmd, **kw: subprocess.CompletedProcess(cmd, 0, "", "")) as run:
            self.assertTrue(AppleManager.embed_entitlements(proj, arch, lambda m: None,
                                                            entitlements_path=str(godot_ent)))
        cmd = run.call_args[0][0]
        self.assertEqual(cmd[cmd.index("--entitlements") + 1], str(godot_ent))
        with patch.object(subprocess, "run") as run:
            self.assertTrue(AppleManager.embed_entitlements(proj, arch, lambda m: None,
                                                            entitlements_path=str(godot_ent) + ".missing"))
        run.assert_not_called()

    def test_godot_build_embeds_entitlements_after_archive(self):
        src = Path(__file__).resolve().parents[1].joinpath("core", "apple_manager.py").read_text()
        body = src[src.index("def build_godot_ipa"):src.index("def ensure_info_plist")]
        self.assertIn("entitlements_path=godot_ent", body)
        self.assertLess(body.index('"archive"'), body.index("embed_entitlements"))
        self.assertLess(body.index("embed_entitlements"), body.index("-exportArchive"))


if __name__ == "__main__":
    unittest.main()
