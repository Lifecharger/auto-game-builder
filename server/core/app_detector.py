"""Detect app type, version, and package name from a project folder."""

import logging
import os
import re
import shutil
from config.constants import TECH_STACKS

logger = logging.getLogger(__name__)

ICONS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "icons")


class AppDetector:
    def detect(self, project_path: str) -> dict:
        """Scan a project folder and return detected app info."""
        result = {
            "app_type": "custom",
            "version": "",
            "package_name": "",
            "has_claude_md": False,
            "has_git": False,
        }

        if not os.path.isdir(project_path):
            return result

        # Check for CLAUDE.md
        result["has_claude_md"] = os.path.isfile(os.path.join(project_path, "CLAUDE.md"))
        result["has_git"] = os.path.isdir(os.path.join(project_path, ".git"))

        # Detect type by marker files
        for tech_key, tech in TECH_STACKS.items():
            if tech_key == "custom":
                continue
            detect_file = tech.get("detect_file")
            if detect_file and os.path.isfile(os.path.join(project_path, detect_file)):
                result["app_type"] = tech_key
                break

        # Parse version
        tech = TECH_STACKS.get(result["app_type"], {})
        version_file = tech.get("version_file")
        version_pattern = tech.get("version_pattern")
        if version_file and version_pattern:
            vf_path = os.path.join(project_path, version_file)
            if os.path.isfile(vf_path):
                result["version"] = self._parse_version(vf_path, version_pattern)

        # Parse package name
        if result["app_type"] == "flutter":
            result["package_name"] = self._detect_flutter_package(project_path)
        elif result["app_type"] == "react_native":
            result["package_name"] = self._detect_flutter_package(project_path)
        elif result["app_type"] == "godot":
            result["package_name"] = self._detect_godot_package(project_path)
        elif result["app_type"] == "phaser":
            result["package_name"] = self._detect_phaser_package(project_path)

        return result

    def _parse_version(self, file_path: str, pattern: str) -> str:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()
            match = re.search(pattern, content)
            return match.group(1).strip() if match else ""
        except Exception as e:
            logger.debug("Failed to parse version from %s: %s", file_path, e)
            return ""

    def _detect_flutter_package(self, project_path: str) -> str:
        # Try build.gradle.kts first (modern Flutter), then build.gradle, then AndroidManifest
        for gradle_name in ["build.gradle.kts", "build.gradle"]:
            gradle = os.path.join(project_path, "android", "app", gradle_name)
            if os.path.isfile(gradle):
                try:
                    with open(gradle, "r", encoding="utf-8") as f:
                        content = f.read()
                    match = re.search(r'applicationId\s*[=:]\s*["\']([^"\'\s]+)', content)
                    if match:
                        return match.group(1)
                except Exception as e:
                    logger.debug("Failed to read %s: %s", gradle_name, e)

        manifest = os.path.join(project_path, "android", "app", "src", "main", "AndroidManifest.xml")
        if os.path.isfile(manifest):
            try:
                with open(manifest, "r", encoding="utf-8") as f:
                    content = f.read()
                match = re.search(r'package="([^"]+)"', content)
                if match:
                    return match.group(1)
            except Exception as e:
                logger.debug("Failed to read AndroidManifest: %s", e)
        return ""

    def _detect_godot_package(self, project_path: str) -> str:
        cfg = os.path.join(project_path, "export_presets.cfg")
        if os.path.isfile(cfg):
            try:
                with open(cfg, "r", encoding="utf-8") as f:
                    content = f.read()
                match = re.search(r'package/unique_name="([^"]+)"', content)
                if match:
                    return match.group(1)
            except Exception as e:
                logger.debug("Failed to read export_presets.cfg: %s", e)
        return ""

    def _detect_phaser_package(self, project_path: str) -> str:
        # Capacitor's appId lives in capacitor.config.ts
        cfg = os.path.join(project_path, "capacitor.config.ts")
        if os.path.isfile(cfg):
            try:
                with open(cfg, "r", encoding="utf-8") as f:
                    content = f.read()
                match = re.search(r"appId:\s*['\"]([^'\"]+)['\"]", content)
                if match:
                    return match.group(1)
            except Exception as e:
                logger.debug("Failed to read capacitor.config.ts: %s", e)
        return ""

    def extract_icon(self, project_path: str, slug: str, app_type: str = "flutter") -> str:
        """Find and copy app icon to icons/. Returns icon path or empty."""
        os.makedirs(ICONS_DIR, exist_ok=True)

        # Candidate icon paths by app type
        candidates = []
        if app_type == "flutter":
            candidates = [
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-xxxhdpi", "ic_launcher.png"),
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-xxhdpi", "ic_launcher.png"),
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-xhdpi", "ic_launcher.png"),
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-hdpi", "ic_launcher.png"),
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-mdpi", "ic_launcher.png"),
                os.path.join(project_path, "web", "favicon.png"),
            ]
        elif app_type == "godot":
            candidates = [
                os.path.join(project_path, "icon.png"),
                os.path.join(project_path, "icon.svg"),
            ]
        elif app_type == "react_native":
            candidates = [
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-xxxhdpi", "ic_launcher.png"),
                os.path.join(project_path, "android", "app", "src", "main", "res", "mipmap-hdpi", "ic_launcher.png"),
            ]

        for candidate in candidates:
            if os.path.isfile(candidate):
                ext = os.path.splitext(candidate)[1]
                dest = os.path.join(ICONS_DIR, f"{slug}{ext}")
                try:
                    shutil.copy2(candidate, dest)
                    return dest
                except Exception as e:
                    logger.debug("Failed to copy icon %s: %s", candidate, e)
        return ""

    def generate_slug(self, name: str) -> str:
        slug = name.lower().strip()
        slug = re.sub(r"[^a-z0-9]+", "-", slug)
        slug = slug.strip("-")
        return slug
