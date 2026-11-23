"""Apple App Store Connect and iOS build/deploy management.

Handles:
- App Store Connect API authentication via JWT (ES256)
- Bundle ID registration and queries
- Provisioning profile generation (App Store distribution via fastlane sigh)
- Xcode project configuration (Bundle ID, Development Team, ExportOptions.plist)
- Headless IPA compilation via xcodebuild (archive + exportArchive)
- Upload to App Store Connect / TestFlight via xcrun altool
"""

import json
import logging
import os
import re
import shutil
import subprocess
import time
from typing import Callable, Optional

logger = logging.getLogger(__name__)

# Valid iOS distribution channels (mapped to unified tracks)
# internal   -> TestFlight Internal Testing
# alpha/beta -> TestFlight External Testing
# production -> App Store Release
IOS_TRACK_MAP = {
    "internal": "testflight_internal",
    "alpha": "testflight_external",
    "beta": "testflight_external",
    "production": "appstore",
}


class AppleManager:
    def __init__(self, settings: dict):
        self.settings = settings
        # get_settings() is FLAT (sections merged); a raw settings.json has an "apple" section.
        apple_cfg = settings.get("apple") or settings
        self.key_id = apple_cfg.get("key_id", "")
        self.issuer_id = apple_cfg.get("issuer_id", "")
        self.key_file = apple_cfg.get("key_file", "") or settings.get("paths", {}).get("apple_key_file", "")
        self.team_id = apple_cfg.get("team_id", "N93RGMQBMG")
        self.fastlane_key_file = apple_cfg.get("fastlane_key_file", os.path.expanduser("~/keys/fastlane_api_key.json"))
        self.keychain_path = apple_cfg.get("keychain_path", os.path.expanduser("~/Library/Keychains/agb.keychain-db"))
        # Never a literal here (the repo is public): settings.json, else the private key file.
        self.keychain_password = apple_cfg.get("keychain_password", "")
        if not self.keychain_password:
            pw_file = apple_cfg.get("keychain_password_file", os.path.expanduser("~/keys/agb_keychain_password.txt"))
            try:
                with open(pw_file, encoding="utf-8") as f:
                    self.keychain_password = f.read().strip()
            except OSError:
                pass

    def is_configured(self) -> bool:
        """Check if Apple credentials and tools are available."""
        return bool(
            self.key_id
            and self.issuer_id
            and self.key_file
            and os.path.isfile(self.key_file)
        )

    def get_jwt_token(self) -> str:
        """Generate a short-lived (20 min) JWT for App Store Connect API."""
        if not self.is_configured():
            raise RuntimeError("Apple App Store Connect credentials not configured in settings.json")
        import jwt

        with open(self.key_file, "r", encoding="utf-8") as f:
            private_key = f.read()

        now = int(time.time())
        payload = {
            "iss": self.issuer_id,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1",
        }
        token = jwt.encode(
            payload,
            private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )
        return token

    def _normalize_url(self, path: str) -> str:
        clean = path.lstrip('/')
        if clean.startswith("v1/"):
            clean = clean[3:]
        return f"https://api.appstoreconnect.apple.com/v1/{clean}"

    def api_get(self, path: str, params: Optional[dict] = None) -> dict:
        """Make an authenticated GET request to App Store Connect API."""
        import requests

        url = self._normalize_url(path)
        token = self.get_jwt_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        resp = requests.get(url, headers=headers, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def api_post(self, path: str, data: dict) -> dict:
        """Make an authenticated POST request to App Store Connect API."""
        import requests

        url = self._normalize_url(path)
        token = self.get_jwt_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        resp = requests.post(url, headers=headers, json=data, timeout=30)
        resp.raise_for_status()
        if resp.status_code == 204 or not resp.content:
            return {}
        return resp.json()

    def api_patch(self, path: str, data: dict) -> dict:
        """Make an authenticated PATCH request to App Store Connect API."""
        import requests

        url = self._normalize_url(path)
        token = self.get_jwt_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        resp = requests.patch(url, headers=headers, json=data, timeout=30)
        resp.raise_for_status()
        if resp.status_code == 204 or not resp.content:
            return {}
        return resp.json()

    def get_registered_bundle_ids(self) -> dict[str, str]:
        """Return mapping of identifier -> resource_id for registered bundle IDs."""
        try:
            res = self.api_get("bundleIds", params={"limit": 100})
            data = res.get("data", [])
            return {item["attributes"]["identifier"]: item["id"] for item in data}
        except Exception as e:
            logger.warning("[AppleManager] Failed to fetch bundle IDs: %s", e)
            return {}

    def ensure_bundle_id(self, identifier: str, name: str) -> Optional[str]:
        """Ensure bundle ID exists in Apple Developer portal. Returns resource ID."""
        existing = self.get_registered_bundle_ids()
        if identifier in existing:
            return existing[identifier]

        payload = {
            "data": {
                "type": "bundleIds",
                "attributes": {
                    "identifier": identifier,
                    "name": name[:50],  # Apple limit
                    "platform": "UNIVERSAL",
                },
            }
        }
        try:
            resp = self.api_post("bundleIds", payload)
            res_id = resp.get("data", {}).get("id")
            logger.info("[AppleManager] Registered bundle ID %s (id=%s)", identifier, res_id)
            return res_id
        except Exception as e:
            logger.error("[AppleManager] Error registering bundle ID %s: %s", identifier, e)
            return None

    def ensure_provisioning_profile(self, identifier: str) -> bool:
        """Download or create App Store provisioning profile using Fastlane sigh."""
        fastlane_key = self.fastlane_key_file
        if not os.path.isfile(fastlane_key):
            logger.warning("[AppleManager] Fastlane key file not found at %s", fastlane_key)
            return False

        cmd = [
            "fastlane", "sigh",
            "--app_identifier", identifier,
            "--api_key_path", fastlane_key,
            "--skip_install", "false",
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if res.returncode == 0:
                logger.info("[AppleManager] Provisioning profile ready for %s", identifier)
                # Clean up any downloaded .mobileprovision in current working dir
                for f in os.listdir("."):
                    if f.endswith(".mobileprovision") and identifier in f:
                        try:
                            os.remove(f)
                        except OSError:
                            pass
                return True
            else:
                logger.warning("[AppleManager] sigh returned %d: %s", res.returncode, res.stderr or res.stdout)
                return False
        except Exception as e:
            logger.error("[AppleManager] Failed to run fastlane sigh: %s", e)
            return False

    def sync_ios_project(self, project_path: str, bundle_id: str, app_name: Optional[str] = None) -> bool:
        """Update Xcode project configuration for the bundle ID, team ID, and export options."""
        pbxproj = os.path.join(project_path, "ios", "Runner.xcodeproj", "project.pbxproj")
        if not os.path.isfile(pbxproj):
            return False

        with open(pbxproj, "r", encoding="utf-8") as f:
            content = f.read()

        changed = False

        # 1. Update PRODUCT_BUNDLE_IDENTIFIER
        # Match runner targets (exclude RunnerTests)
        def _replace_bundle_id(match):
            nonlocal changed
            changed = True
            indent = match.group(1)
            return (
                f"{indent}DEVELOPMENT_TEAM = {self.team_id};\n"
                f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};"
            )

        # Replace standard com.example.<something> or old package name
        old_pattern = r"^(\t+)PRODUCT_BUNDLE_IDENTIFIER = (?!.*RunnerTests)[\w\.\-]+;"
        if re.search(old_pattern, content, flags=re.MULTILINE):
            content = re.sub(old_pattern, _replace_bundle_id, content, flags=re.MULTILINE)

        # iPhone only (2026-11-24): our games are phone games; declaring iPad (Flutter's default
        # "1,2") makes Apple require iPad screenshots and iPad review.
        if re.search(r'TARGETED_DEVICE_FAMILY = "?1,2"?;', content):
            content = re.sub(r'TARGETED_DEVICE_FAMILY = "?1,2"?;', 'TARGETED_DEVICE_FAMILY = 1;', content)
            changed = True

        # Ensure DEVELOPMENT_TEAM is present in target build settings if not already
        if f"DEVELOPMENT_TEAM = {self.team_id};" not in content:
            content = re.sub(
                r"^(\t+)(PRODUCT_BUNDLE_IDENTIFIER = .*RunnerTests;)",
                r"\1\2",
                content,
                flags=re.MULTILINE,
            )
            # Add team ID to all Runner configurations
            content = re.sub(
                r"^(\t+)(PRODUCT_NAME = \"\$\(TARGET_NAME\)\";)",
                f"\\1DEVELOPMENT_TEAM = {self.team_id};\n\\1\\2",
                content,
                flags=re.MULTILINE,
            )
            changed = True

        if changed:
            with open(pbxproj, "w", encoding="utf-8") as f:
                f.write(content)
            logger.info("[AppleManager] Updated %s with bundle_id=%s, team=%s", pbxproj, bundle_id, self.team_id)

        # 2. Write ios/ExportOptions.plist
        export_plist_path = os.path.join(project_path, "ios", "ExportOptions.plist")
        profile_name = f"{bundle_id} AppStore"
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>{self.team_id}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>{bundle_id}</key>
        <string>{profile_name}</string>
    </dict>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
"""
        with open(export_plist_path, "w", encoding="utf-8") as f:
            f.write(plist_content)

        # 3. Ensure Podfile minimum iOS platform is at least 16.0
        podfile = os.path.join(project_path, "ios", "Podfile")
        if os.path.isfile(podfile):
            with open(podfile, "r", encoding="utf-8") as f:
                pod_content = f.read()
            if "platform :ios" not in pod_content or "# platform :ios" in pod_content or "platform :ios, '12" in pod_content or "platform :ios, '13" in pod_content or "platform :ios, '14" in pod_content or "platform :ios, '15" in pod_content:
                pod_content = re.sub(r"#?\s*platform :ios,\s*'[^']*'", "platform :ios, '16.0'", pod_content)
                if "platform :ios" not in pod_content:
                    pod_content = "platform :ios, '16.0'\n" + pod_content
                with open(podfile, "w", encoding="utf-8") as f:
                    f.write(pod_content)

        # 4. Info.plist: purpose strings + AdMob id (2026-11-23). Apple silently drops an upload
        #    (ITMS-90683 e-mail) when a linked SDK references a privacy API without its purpose
        #    string, even if the app never calls it; google_mobile_ads crashes at launch without
        #    GADApplicationIdentifier.
        self.ensure_info_plist(project_path)
        # 5. App icon: never ship Flutter's default (2026-11-24, every Flutter app went to
        #    TestFlight with the Flutter logo because the template's 1024 icon counted as "present").
        self.ensure_ios_icon(project_path)

        return True

    FLUTTER_DEFAULT_ICON_MD5 = "c785f8932297af4acd5f5ccb7630f01c"

    def _icon_source(self, project_path: str) -> str:
        cands = ["store_icon_1024.png"]
        pub = os.path.join(project_path, "pubspec.yaml")
        if os.path.isfile(pub):
            m = re.search(r'image_path(?:_ios)?\s*:\s*["\']?([^"\'\n]+)', open(pub, encoding="utf-8").read())
            if m:
                cands.append(m.group(1).strip())
        cands += ["store/icon_512.png", "store/art/icon_512.png", "assets/icon.png", "assets/icons/icon.png",
                  "assets/images/icon.png", "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"]
        for c in cands:
            p = os.path.join(project_path, c)
            if os.path.isfile(p):
                return p
        return ""

    def ensure_ios_icon(self, project_path: str) -> bool:
        import hashlib
        icon_dir = os.path.join(project_path, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
        big = os.path.join(icon_dir, "Icon-App-1024x1024@1x.png")
        contents = os.path.join(icon_dir, "Contents.json")
        if not (os.path.isfile(big) and os.path.isfile(contents)):
            return False
        if hashlib.md5(open(big, "rb").read()).hexdigest() != self.FLUTTER_DEFAULT_ICON_MD5:
            return False  # already the game's icon
        src = self._icon_source(project_path)
        if not src:
            logger.warning("[AppleManager] %s still has Flutter's default iOS icon and no icon source", project_path)
            return False
        # flatten (App Store icons must not have alpha) at 1024, then every size Contents.json lists
        tmp_jpg = os.path.join(icon_dir, "_src.jpg")
        master = os.path.join(icon_dir, "_master.png")
        subprocess.run(["sips", "-z", "1024", "1024", "-s", "format", "jpeg", "-s", "formatOptions", "100", src,
                        "--out", tmp_jpg], capture_output=True)
        subprocess.run(["sips", "-s", "format", "png", tmp_jpg, "--out", master], capture_output=True)
        with open(contents, encoding="utf-8") as f:
            images = json.load(f).get("images", [])
        for im in images:
            fn = im.get("filename")
            if not fn:
                continue
            px = int(round(float(im["size"].split("x")[0]) * int(im["scale"].rstrip("x"))))
            subprocess.run(["sips", "-z", str(px), str(px), master, "--out", os.path.join(icon_dir, fn)],
                           capture_output=True)
        for t in (tmp_jpg, master):
            try:
                os.remove(t)
            except OSError:
                pass
        logger.info("[AppleManager] iOS icon set rebuilt from %s", src)
        return True

    PURPOSE_STRINGS = {
        "NSPhotoLibraryUsageDescription": "This app does not read your photo library.",
        "NSPhotoLibraryAddUsageDescription": "This app may save an image you choose to share to your photo library.",
        "NSCameraUsageDescription": "This app does not use the camera.",
        "NSMicrophoneUsageDescription": "This app does not record audio.",
        "NSLocationWhenInUseUsageDescription": "This app does not use your location.",
        "NSBluetoothAlwaysUsageDescription": "This app does not use Bluetooth.",
        "NSUserTrackingUsageDescription": "Your data is used to show you more relevant ads.",
    }
    # Google's published sample iOS AdMob app id: shows test ads only. Real per-app iOS AdMob
    # ids must replace it before an App Store release.
    ADMOB_SAMPLE_IOS_APP_ID = "ca-app-pub-3940256099942544~1458002511"

    GODOT_PRIVACY = {
        "privacy/camera_usage_description": "This game does not use the camera.",
        "privacy/microphone_usage_description": "This game does not record audio.",
        "privacy/photolibrary_usage_description": "This game does not read your photo library.",
    }

    def ensure_godot_ios_preset(self, project_path: str, bundle_id: str) -> tuple[str, str]:
        """Make sure a Godot project has an 'iOS' export preset (export_project_only, App Store
        team, purpose strings, flat 1024 icon) and that its version follows the Android preset.
        Returns (scheme, export_path)."""
        p = os.path.join(project_path, "export_presets.cfg")
        with open(p, encoding="utf-8") as f:
            s = f.read()
        ver = (re.search(r'^version/name="([^"]*)"', s, re.M) or [None, "1.0.0"])[1]
        code = (re.search(r'^version/code=(\d+)', s, re.M) or [None, "1"])[1]
        name_m = re.search(r'^config/name="([^"]*)"', open(os.path.join(project_path, "project.godot"), encoding="utf-8").read(), re.M)
        scheme = re.sub(r"[^A-Za-z0-9]", "", name_m.group(1) if name_m else "Game") or "Game"
        if 'platform="iOS"' not in s:
            idx = max(int(x) for x in re.findall(r'^\[preset\.(\d+)\]', s, re.M)) + 1
            excl = (re.search(r'^exclude_filter="([^"]*)"', s, re.M) or [None, ""])[1]
            excl = ", ".join(x for x in excl.split(", ") if x and "admob/ios" not in x)
            inc = (re.search(r'^include_filter="([^"]*)"', s, re.M) or [None, ""])[1]
            s = s.rstrip() + f'''

[preset.{idx}]

name="iOS"
platform="iOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="{inc}"
exclude_filter="{excl}"
export_path="build/ios/{scheme}.ipa"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{idx}.options]

custom_template/debug=""
custom_template/release=""
architectures/arm64=true
application/app_store_team_id="{self.team_id}"
application/export_method_debug=1
application/export_method_release=0
application/bundle_identifier="{bundle_id}"
application/signature=""
application/short_version="{ver}"
application/version="{code}"
application/min_ios_version="16.0"
application/export_project_only=true
application/delete_old_export_files_unconditionally=true
application/additional_plist_content="<key>ITSAppUsesNonExemptEncryption</key><false/>"
user_data/accessible_from_files_app=false
user_data/accessible_from_itunes_sharing=false
privacy/camera_usage_description=""
privacy/microphone_usage_description=""
privacy/photolibrary_usage_description=""
icons/icon_1024x1024="res://build_ios_icon_1024.png"
storyboard/image_scale_mode=0
storyboard/use_launch_screen_storyboard=true
'''
        # keep the iOS version in step with Android, fill empty purpose strings
        export_path = f"build/ios/{scheme}.ipa"
        sections = re.split(r'(?m)^(?=\[preset\.)', s)
        ios_idx = None
        for sec in sections:
            hm = re.match(r'\[preset\.(\d+)\]', sec)
            if hm and 'platform="iOS"' in sec:
                ios_idx = hm.group(1)
                export_path = (re.search(r'^export_path="([^"]*)"', sec, re.M) or [None, export_path])[1] or export_path
        if ios_idx is not None:
            for i, sec in enumerate(sections):
                if sec.startswith(f"[preset.{ios_idx}.options]"):
                    sec = re.sub(r'^application/short_version=.*$', f'application/short_version="{ver}"', sec, flags=re.M)
                    sec = re.sub(r'^application/version=.*$', f'application/version="{code}"', sec, flags=re.M)
                    for k, v in self.GODOT_PRIVACY.items():
                        sec = re.sub(rf'^{re.escape(k)}=""$', f'{k}="{v}"', sec, flags=re.M)
                    # iPhone only (0); Godot's default 2 = iPhone + iPad
                    if re.search(r'^application/targeted_device_family=', sec, flags=re.M):
                        sec = re.sub(r'^application/targeted_device_family=.*$', 'application/targeted_device_family=0', sec, flags=re.M)
                    else:
                        sec = sec.replace("\napplication/bundle_identifier=", "\napplication/targeted_device_family=0\napplication/bundle_identifier=", 1)
                    sections[i] = sec
            s = "".join(sections)
        with open(p, "w", encoding="utf-8") as f:
            f.write(s if s.endswith("\n") else s + "\n")
        # flat 1024 icon from the project icon when the preset points at the generated one
        if "res://build_ios_icon_1024.png" in s:
            icon_m = re.search(r'^config/icon="res://([^"]+)"', open(os.path.join(project_path, "project.godot"), encoding="utf-8").read(), re.M)
            src = os.path.join(project_path, icon_m.group(1)) if icon_m else ""
            if src.endswith(".svg") or not os.path.isfile(src):
                for cand in ("store/icon_512.png", "store/art/icon_512.png", "icon_512.png", "icon.png"):
                    if os.path.isfile(os.path.join(project_path, cand)):
                        src = os.path.join(project_path, cand)
                        break
            out = os.path.join(project_path, "build_ios_icon_1024.png")
            if os.path.isfile(src) and not os.path.isfile(out):
                tmp = os.path.join(project_path, "build", "ios_icon_tmp.jpg")
                os.makedirs(os.path.dirname(tmp), exist_ok=True)
                subprocess.run(["sips", "-z", "1024", "1024", "-s", "format", "jpeg", src, "--out", tmp], capture_output=True)
                subprocess.run(["sips", "-s", "format", "png", tmp, "--out", out], capture_output=True)
        return os.path.splitext(os.path.basename(export_path))[0], export_path

    def build_godot_ipa(self, project_path: str, bundle_id: str, app_name: str, godot_bin: str,
                        log_callback: Optional[Callable[[str], None]] = None) -> tuple[bool, str, str]:
        """Godot -> Xcode project -> unsigned archive -> App Store signed IPA (automatic signing
        through the App Store Connect API key, no devices or Apple ID needed)."""
        logs: list[str] = []

        def _log(msg: str):
            logs.append(msg)
            if log_callback:
                log_callback(msg)

        self.unlock_keychain()
        self.ensure_bundle_id(bundle_id, app_name)
        scheme, export_path = self.ensure_godot_ios_preset(project_path, bundle_id)
        ios_dir = os.path.join(project_path, os.path.dirname(export_path))
        shutil.rmtree(ios_dir, ignore_errors=True)
        os.makedirs(ios_dir, exist_ok=True)
        _log(f"Exporting Godot iOS project ({scheme})...")
        res = subprocess.run([godot_bin, "--headless", "--path", project_path, "--export-release", "iOS", export_path],
                             cwd=project_path, capture_output=True, text=True, timeout=900)
        xcodeproj = os.path.join(ios_dir, f"{scheme}.xcodeproj")
        if not os.path.isdir(xcodeproj):
            return False, "", "\n".join(logs) + "\nGodot iOS export failed:\n" + (res.stdout + res.stderr)[-3000:]
        archive = os.path.join(ios_dir, f"{scheme}.xcarchive")
        _log("Archiving iOS release...")
        a = subprocess.run(["xcodebuild", "archive", "-project", xcodeproj, "-scheme", scheme,
                            "-configuration", "Release", "-destination", "generic/platform=iOS",
                            "-archivePath", archive, f"DEVELOPMENT_TEAM={self.team_id}",
                            "CODE_SIGNING_ALLOWED=NO", "-quiet"],
                           cwd=project_path, capture_output=True, text=True, timeout=1800)
        if a.returncode != 0:
            return False, "", "\n".join(logs) + "\nxcodebuild archive failed:\n" + (a.stdout + a.stderr)[-3000:]
        opts = os.path.join(ios_dir, "ExportOptions.plist")
        with open(opts, "w", encoding="utf-8") as f:
            f.write(f'''<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>method</key><string>app-store-connect</string><key>teamID</key><string>{self.team_id}</string>
<key>signingStyle</key><string>automatic</string><key>destination</key><string>export</string><key>uploadSymbols</key><true/></dict></plist>
''')
        _log("Exporting signed IPA...")
        self.unlock_keychain()
        out_dir = os.path.join(ios_dir, "ipa")
        e = subprocess.run(["xcodebuild", "-exportArchive", "-archivePath", archive, "-exportPath", out_dir,
                            "-exportOptionsPlist", opts, "-allowProvisioningUpdates",
                            "-authenticationKeyPath", self.key_file, "-authenticationKeyID", self.key_id,
                            "-authenticationKeyIssuerID", self.issuer_id],
                           cwd=project_path, capture_output=True, text=True, timeout=900)
        ipas = [x for x in os.listdir(out_dir) if x.endswith(".ipa")] if os.path.isdir(out_dir) else []
        if e.returncode != 0 or not ipas:
            return False, "", "\n".join(logs) + "\nexportArchive failed:\n" + (e.stdout + e.stderr)[-3000:]
        ipa = os.path.join(out_dir, ipas[0])
        _log(f"IPA successfully built: {ipa}")
        return True, ipa, "\n".join(logs)

    def ensure_info_plist(self, project_path: str) -> bool:
        import plistlib
        info = os.path.join(project_path, "ios", "Runner", "Info.plist")
        if not os.path.isfile(info):
            return False
        with open(info, "rb") as f:
            data = plistlib.load(f)
        changed = False
        for key, text in self.PURPOSE_STRINGS.items():
            if not str(data.get(key, "")).strip():
                data[key] = text
                changed = True
        if "ITSAppUsesNonExemptEncryption" not in data:
            data["ITSAppUsesNonExemptEncryption"] = False
            changed = True
        pubspec = os.path.join(project_path, "pubspec.yaml")
        uses_admob = os.path.isfile(pubspec) and "google_mobile_ads" in open(pubspec, encoding="utf-8").read()
        if uses_admob and not str(data.get("GADApplicationIdentifier", "")).strip():
            data["GADApplicationIdentifier"] = self.ADMOB_SAMPLE_IOS_APP_ID
            changed = True
        if changed:
            with open(info, "wb") as f:
                plistlib.dump(data, f)
            logger.info("[AppleManager] Info.plist purpose strings/AdMob id ensured for %s", project_path)
        return changed

    def unlock_keychain(self) -> bool:
        """Unlock the keychain so headless codesign succeeds without GUI prompt."""
        if os.path.isfile(self.keychain_path):
            try:
                subprocess.run(["security", "unlock-keychain", "-p", self.keychain_password, self.keychain_path],
                               capture_output=True, timeout=10)
                subprocess.run(["security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
                                "-s", "-k", self.keychain_password, self.keychain_path],
                               capture_output=True, timeout=15)
                return True
            except Exception as e:
                logger.warning("[AppleManager] Failed to unlock keychain: %s", e)
        return False

    def build_ipa(self, project_path: str, bundle_id: str, app_name: str,
                  log_callback: Optional[Callable[[str], None]] = None) -> tuple[bool, str, str]:
        """Build release IPA using xcodebuild (archive + exportArchive).

        Returns: (success: bool, ipa_path: str, log_output: str)
        """
        self.unlock_keychain()
        self.sync_ios_project(project_path, bundle_id, app_name)
        self.ensure_bundle_id(bundle_id, app_name)
        self.ensure_provisioning_profile(bundle_id)

        workspace = os.path.join(project_path, "ios", "Runner.xcworkspace")
        archive_path = os.path.join(project_path, "build", "ios", "Runner.xcarchive")
        export_path = os.path.join(project_path, "build", "ios", "ipa")
        export_plist = os.path.join(project_path, "ios", "ExportOptions.plist")
        os.makedirs(export_path, exist_ok=True)

        logs: list[str] = []

        def _log(msg: str):
            logs.append(msg)
            if log_callback:
                log_callback(msg)

        # Step 0: Ensure Flutter Generated.xcconfig matches pubspec.yaml
        pubspec = os.path.join(project_path, "pubspec.yaml")
        if os.path.isfile(pubspec):
            _log("Syncing Flutter iOS configuration (flutter build ios --config-only)...")
            flutter_bin = self.settings.get("engines", {}).get("flutter_path") or self.settings.get("flutter_path") or "flutter"
            res_flutter = subprocess.run([flutter_bin, "build", "ios", "--config-only"],
                                         cwd=project_path, capture_output=True, text=True, timeout=300)
            if res_flutter.returncode != 0:
                _log(f"Flutter config warning: {res_flutter.stderr[:200]}")

        # Step 1: Run pod install if needed
        podfile = os.path.join(project_path, "ios", "Podfile")
        if os.path.isfile(podfile):
            _log("Running pod install...")
            res = subprocess.run(["pod", "install"], cwd=os.path.join(project_path, "ios"),
                                 capture_output=True, text=True, timeout=300)
            if res.returncode != 0:
                _log(f"pod install warning: {res.stderr[:200]}")

        # Step 2: Archive workspace with CODE_SIGNING_ALLOWED=NO
        _log("Archiving iOS release...")
        archive_cmd = [
            "xcodebuild", "archive",
            "-workspace", workspace,
            "-scheme", "Runner",
            "-configuration", "Release",
            "-destination", "generic/platform=iOS",
            "-archivePath", archive_path,
            "CODE_SIGNING_ALLOWED=NO",
        ]
        proc = subprocess.run(archive_cmd, cwd=project_path, capture_output=True, text=True, timeout=900)
        if proc.returncode != 0:
            err = proc.stderr or proc.stdout
            _log(f"xcodebuild archive failed: {err[-500:]}")
            return False, "", "\n".join(logs) + "\n" + err

        # Step 3: Export archive to signed IPA using ExportOptions.plist
        _log("Exporting signed IPA...")
        self.unlock_keychain()
        export_cmd = [
            "xcodebuild", "-exportArchive",
            "-archivePath", archive_path,
            "-exportPath", export_path,
            "-exportOptionsPlist", export_plist,
        ]
        proc_export = subprocess.run(export_cmd, cwd=project_path, capture_output=True, text=True, timeout=600)
        if proc_export.returncode != 0:
            err = proc_export.stderr or proc_export.stdout
            _log(f"xcodebuild exportArchive failed: {err[-500:]}")
            return False, "", "\n".join(logs) + "\n" + err

        # Step 4: Find the generated .ipa file
        ipa_files = [f for f in os.listdir(export_path) if f.endswith(".ipa")]
        if not ipa_files:
            return False, "", "No .ipa file generated in " + export_path

        ipa_path = os.path.join(export_path, ipa_files[0])
        _log(f"IPA successfully built: {ipa_path}")
        return True, ipa_path, "\n".join(logs)

    def upload_to_app_store(self, ipa_path: str, track: str = "internal") -> dict:
        """Upload IPA to App Store Connect / TestFlight via xcrun altool.

        Returns dict: {"ok": bool, "delivery_id": str, "message": str, "error": str}
        """
        if not os.path.isfile(ipa_path):
            return {"ok": False, "error": f"IPA file not found: {ipa_path}"}
        if not self.is_configured():
            return {"ok": False, "error": "Apple credentials not configured in settings.json"}

        # Ensure private key is symlinked to ~/.appstoreconnect/private_keys/
        home_keys = os.path.expanduser("~/.appstoreconnect/private_keys")
        os.makedirs(home_keys, exist_ok=True)
        key_target = os.path.join(home_keys, f"AuthKey_{self.key_id}.p8")
        if not os.path.exists(key_target):
            try:
                os.symlink(self.key_file, key_target)
            except OSError:
                pass

        cmd = [
            "xcrun", "altool",
            "--upload-app",
            "-f", ipa_path,
            "--type", "ios",
            "--api-key", self.key_id,
            "--api-issuer", self.issuer_id,
            "--output-format", "json",
        ]

        logger.info("[AppleManager] Uploading %s to App Store Connect...", ipa_path)
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
            output = proc.stdout.strip()
            stderr = proc.stderr.strip()

            parsed = {}
            if output:
                try:
                    parsed = json.loads(output)
                except json.JSONDecodeError:
                    pass

            if proc.returncode == 0:
                delivery_id = ""
                if isinstance(parsed, dict):
                    delivery_id = parsed.get("delivery-id", "")
                logger.info("[AppleManager] IPA uploaded successfully (delivery_id=%s)", delivery_id)
                channel_name = IOS_TRACK_MAP.get(track, track)
                return {
                    "ok": True,
                    "delivery_id": delivery_id,
                    "channel": channel_name,
                    "message": f"Successfully uploaded to Apple TestFlight / App Store (channel: {channel_name})",
                }
            else:
                # Extract error message
                err_msg = ""
                if isinstance(parsed, dict) and "product-errors" in parsed:
                    errors = parsed.get("product-errors", [])
                    if errors and isinstance(errors[0], dict):
                        err_msg = errors[0].get("message", "")
                if not err_msg:
                    err_msg = stderr or output or f"altool failed with exit code {proc.returncode}"
                logger.error("[AppleManager] Upload failed: %s", err_msg)
                return {"ok": False, "error": err_msg}

        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "Upload to App Store Connect timed out (15 min)"}
        except Exception as e:
            return {"ok": False, "error": f"Upload error: {str(e)}"}

    def get_app_store_apps(self) -> list[dict]:
        """Fetch list of all apps in App Store Connect account."""
        try:
            resp = self.api_get("apps", params={"limit": 50})
            data = resp.get("data", [])
            apps = []
            for item in data:
                attr = item.get("attributes", {})
                apps.append({
                    "id": item.get("id"),
                    "name": attr.get("name"),
                    "bundle_id": attr.get("bundleId"),
                    "sku": attr.get("sku"),
                    "primary_locale": attr.get("primaryLocale"),
                })
            return apps
        except Exception as e:
            logger.warning("[AppleManager] Failed to fetch apps: %s", e)
            return []

    def upload_screenshot_file(self, set_id: str, file_path: str) -> dict:
        """Upload a single screenshot to an appScreenshotSet."""
        import hashlib
        import requests

        file_name = os.path.basename(file_path)
        with open(file_path, "rb") as f:
            file_bytes = f.read()

        file_size = len(file_bytes)
        file_md5 = hashlib.md5(file_bytes).hexdigest()

        # 1. Reserve asset
        reserve_payload = {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": file_name,
                    "fileSize": file_size,
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {
                            "type": "appScreenshotSets",
                            "id": set_id,
                        }
                    }
                },
            }
        }
        res = self.api_post("appScreenshots", reserve_payload)
        screenshot_id = res["data"]["id"]
        upload_ops = res["data"]["attributes"]["uploadOperations"]

        # 2. Upload chunks
        for op in upload_ops:
            url = op["url"]
            offset = op["offset"]
            length = op["length"]
            req_headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            chunk = file_bytes[offset : offset + length]
            put_res = requests.put(url, data=chunk, headers=req_headers, timeout=60)
            put_res.raise_for_status()

        # 3. Commit
        commit_payload = {
            "data": {
                "type": "appScreenshots",
                "id": screenshot_id,
                "attributes": {
                    "uploaded": True,
                    "sourceFileChecksum": file_md5,
                },
            }
        }
        return self.api_patch(f"appScreenshots/{screenshot_id}", commit_payload)

    def upload_screenshots(self, localization_id: str, screenshot_paths: list[str], display_type: str = "APP_IPHONE_67") -> list[dict]:
        """Upload a list of screenshots for a given localization and display type."""
        sets_res = self.api_get(f"appStoreVersionLocalizations/{localization_id}/appScreenshotSets")
        set_id = None
        for s in sets_res.get("data", []):
            if s.get("attributes", {}).get("screenshotDisplayType") == display_type:
                set_id = s["id"]
                break

        if not set_id:
            create_payload = {
                "data": {
                    "type": "appScreenshotSets",
                    "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {
                        "appStoreVersionLocalization": {
                            "data": {
                                "type": "appStoreVersionLocalizations",
                                "id": localization_id,
                            }
                        }
                    },
                }
            }
            res = self.api_post("appScreenshotSets", create_payload)
            set_id = res["data"]["id"]

        results = []
        for path in screenshot_paths:
            logger.info("[AppleManager] Uploading screenshot: %s", path)
            r = self.upload_screenshot_file(set_id, path)
            results.append(r)
        return results
