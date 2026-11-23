"""Unit tests for AppleManager and iOS / Dual deploy engine features."""

import os
import shutil
import tempfile
import unittest
from unittest.mock import MagicMock, patch

try:
    from server.core.apple_manager import AppleManager, IOS_TRACK_MAP
except ImportError:
    from core.apple_manager import AppleManager, IOS_TRACK_MAP
try:
    from server.core.deploy_engine import BUILD_TARGETS, VALID_TRACKS
except ImportError:
    from core.deploy_engine import BUILD_TARGETS, VALID_TRACKS


class AppleManagerTests(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.key_path = os.path.join(self.tmp_dir, "test_key.p8")
        with open(self.key_path, "w") as f:
            f.write("-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgMTpNwlwHDd8HQwQj\nWdlXatR1IvZIPTHg2v5uv6NSMg6gCgYIKoZIzj0DAQehRANCAARgVY79Gb0b+baj\nOePWY3LrvkSwiVbL+iKZR1U4+UD3mG+cgLX/TYapT8urkpzsNiUVbgsDIzoiCgwX\n54CBQlIs\n-----END PRIVATE KEY-----")

        self.settings = {
            "apple": {
                "key_id": "TEST_KEY_ID",
                "issuer_id": "test-issuer-uuid",
                "key_file": self.key_path,
                "team_id": "TEST_TEAM",
            }
        }
        self.mgr = AppleManager(self.settings)

    def tearDown(self):
        shutil.rmtree(self.tmp_dir)

    def test_configured_state(self):
        self.assertTrue(self.mgr.is_configured())
        unconfigured = AppleManager({})
        self.assertFalse(unconfigured.is_configured())

    def test_jwt_generation(self):
        token = self.mgr.get_jwt_token()
        self.assertIsInstance(token, str)
        self.assertTrue(len(token) > 20)
        # Token starts with eyJ (JWT header in base64)
        self.assertTrue(token.startswith("eyJ"))

    def test_track_mapping(self):
        self.assertEqual(IOS_TRACK_MAP["internal"], "testflight_internal")
        self.assertEqual(IOS_TRACK_MAP["alpha"], "testflight_external")
        self.assertEqual(IOS_TRACK_MAP["beta"], "testflight_external")
        self.assertEqual(IOS_TRACK_MAP["production"], "appstore")

    def test_sync_ios_project(self):
        # Create dummy Flutter iOS project structure
        ios_dir = os.path.join(self.tmp_dir, "ios")
        xcode_dir = os.path.join(ios_dir, "Runner.xcodeproj")
        os.makedirs(xcode_dir, exist_ok=True)

        pbxproj = os.path.join(xcode_dir, "project.pbxproj")
        with open(pbxproj, "w") as f:
            f.write("""
\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.dummy;
\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\tPRODUCT_BUNDLE_IDENTIFIER = com.example.dummy.RunnerTests;
""")

        podfile = os.path.join(ios_dir, "Podfile")
        with open(podfile, "w") as f:
            f.write("# platform :ios, '12.0'\n")

        ok = self.mgr.sync_ios_project(self.tmp_dir, "com.lifecharger.dummy", "Dummy")
        self.assertTrue(ok)

        # Check pbxproj
        with open(pbxproj) as f:
            content = f.read()
        self.assertIn("com.lifecharger.dummy;", content)
        self.assertIn("DEVELOPMENT_TEAM = TEST_TEAM;", content)

        # Check ExportOptions.plist
        export_plist = os.path.join(ios_dir, "ExportOptions.plist")
        self.assertTrue(os.path.isfile(export_plist))
        with open(export_plist) as f:
            plist = f.read()
        self.assertIn("<string>app-store-connect</string>", plist)
        self.assertIn("<string>TEST_TEAM</string>", plist)
        self.assertIn("<string>com.lifecharger.dummy AppStore</string>", plist)

        # Check Podfile
        with open(podfile) as f:
            pod = f.read()
        self.assertIn("platform :ios, '16.0'", pod)


class DeployEngineTargetsTest(unittest.TestCase):
    def test_flutter_targets_include_ios_and_dual(self):
        targets = BUILD_TARGETS.get("flutter", {})
        self.assertIn("aab", targets)
        self.assertIn("ios", targets)
        self.assertIn("dual", targets)
        self.assertEqual(targets["dual"]["label"], "Dual (AAB + iOS)")

    def test_valid_tracks_cover_play_and_appstore(self):
        self.assertIn("internal", VALID_TRACKS)
        self.assertIn("alpha", VALID_TRACKS)
        self.assertIn("beta", VALID_TRACKS)
        self.assertIn("production", VALID_TRACKS)


if __name__ == "__main__":
    unittest.main()
