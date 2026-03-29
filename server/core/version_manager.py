"""Parse and bump versions for Flutter and Godot projects."""

import os
import re
from config.constants import TECH_STACKS


class VersionManager:
    def get_version(self, project_path: str, app_type: str) -> str:
        tech = TECH_STACKS.get(app_type, {})
        version_file = tech.get("version_file")
        pattern = tech.get("version_pattern")
        if not version_file or not pattern:
            return ""
        full_path = os.path.join(project_path, version_file)
        if not os.path.isfile(full_path):
            return ""
        try:
            with open(full_path, "r", encoding="utf-8") as f:
                content = f.read()
            match = re.search(pattern, content)
            return match.group(1).strip() if match else ""
        except Exception:
            return ""

    def bump_version(self, project_path: str, app_type: str, bump_type: str = "patch") -> tuple[str, str]:
        """Bump version. Returns (old_version, new_version)."""
        old = self.get_version(project_path, app_type)
        if not old:
            return ("", "")

        if app_type == "flutter":
            new = self._bump_flutter(old, bump_type)
            self._write_flutter_version(project_path, old, new)
        elif app_type == "godot":
            new = self._bump_semver(old, bump_type)
            self._write_godot_version(project_path, old, new)
        else:
            new = self._bump_semver(old, bump_type)

        return (old, new)

    def _bump_flutter(self, version: str, bump_type: str) -> str:
        """Handle Flutter versions like 1.0.75+75."""
        parts = version.split("+")
        semver = parts[0]
        build = int(parts[1]) if len(parts) > 1 else 0

        sem_parts = semver.split(".")
        major = int(sem_parts[0]) if len(sem_parts) > 0 else 1
        minor = int(sem_parts[1]) if len(sem_parts) > 1 else 0
        patch = int(sem_parts[2]) if len(sem_parts) > 2 else 0

        # Detect if synced pattern (patch == build)
        synced = (patch == build)

        if bump_type == "major":
            major += 1
            minor = 0
            patch = 0
        elif bump_type == "minor":
            minor += 1
            patch = 0
        else:  # patch
            patch += 1

        build = patch if synced else build + 1
        return f"{major}.{minor}.{patch}+{build}"

    def _bump_semver(self, version: str, bump_type: str) -> str:
        parts = version.split(".")
        if len(parts) < 3:
            parts.extend(["0"] * (3 - len(parts)))
        major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2].split("+")[0].split("-")[0])

        if bump_type == "major":
            major += 1
            minor = 0
            patch = 0
        elif bump_type == "minor":
            minor += 1
            patch = 0
        else:
            patch += 1

        return f"{major}.{minor}.{patch}"

    def _write_flutter_version(self, project_path: str, old: str, new: str):
        pubspec = os.path.join(project_path, "pubspec.yaml")
        try:
            with open(pubspec, "r", encoding="utf-8") as f:
                content = f.read()
            content = content.replace(f"version: {old}", f"version: {new}")
            with open(pubspec, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception:
            pass

    def _write_godot_version(self, project_path: str, old: str, new: str):
        cfg = os.path.join(project_path, "export_presets.cfg")
        try:
            with open(cfg, "r", encoding="utf-8") as f:
                content = f.read()
            content = content.replace(f'version/name="{old}"', f'version/name="{new}"')
            with open(cfg, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception:
            pass
