"""Build engine for Flutter and Godot apps."""

import shlex
import subprocess
import threading
import time
import os
import re
from datetime import datetime
from typing import Callable, Optional
from database.db_manager import DBManager
from database.models import App


class BuildEngine:
    def __init__(self, db: DBManager, settings: dict):
        self.db = db
        self.settings = settings
        self._active_thread: Optional[threading.Thread] = None
        self._callbacks: dict[str, list[Callable]] = {
            "build_started": [],
            "build_completed": [],
            "build_output": [],
        }

    def on(self, event: str, callback: Callable):
        if event in self._callbacks:
            self._callbacks[event].append(callback)

    def _emit(self, event: str, *args):
        for cb in self._callbacks.get(event, []):
            try:
                cb(*args)
            except Exception:
                pass

    def build_app(self, app: App, build_type: str = "appbundle") -> int:
        """Start a build in background thread. Returns build_id."""
        build_id = self.db.create_build(
            app_id=app.id,
            build_type=build_type,
            version=app.current_version,
            status="running",
            started_at=datetime.now().isoformat(),
        )
        self._active_thread = threading.Thread(
            target=self._run_build, args=(app, build_type, build_id), daemon=True
        )
        self._active_thread.start()
        self._emit("build_started", build_id)
        return build_id

    def _run_build(self, app: App, build_type: str, build_id: int):
        cmd = self._get_build_command(app, build_type)
        output_path = self._get_output_path(app, build_type)

        # Hard guard: refuse to build if cwd lacks the expected project marker.
        # Prevents silently producing builds in the wrong directory.
        marker = {
            "flutter": "pubspec.yaml",
            "godot": "export_presets.cfg",
            "phaser": "package.json",
        }.get(app.app_type)
        if marker and not os.path.isfile(os.path.join(app.project_path, marker)):
            err = (
                f"Refusing to build: {marker} not found in {app.project_path}. "
                f"Fix the project_path for app id={app.id} ({app.name})."
            )
            self.db.update_build(
                build_id,
                status="failed",
                log_output=err,
                duration_seconds=0,
                completed_at=datetime.now().isoformat(),
            )
            self.db.update_app(app.id, status="error")
            self._emit("build_completed", build_id, False)
            return

        self.db.update_app(app.id, status="building")
        start = time.time()
        output_lines = []

        try:
            # Run via bash for PATH handling
            process = subprocess.Popen(
                ["bash", "-l", "-c", cmd],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=app.project_path,
            )

            for line in process.stdout:
                clean = re.sub(r"\x1b\[[0-9;]*m", "", line.rstrip())
                output_lines.append(clean)
                self._emit("build_output", build_id, clean)

            process.wait(timeout=600)
            duration = int(time.time() - start)
            success = process.returncode == 0

            self.db.update_build(
                build_id,
                status="success" if success else "failed",
                output_path=output_path if success else "",
                log_output="\n".join(output_lines[-200:]),
                duration_seconds=duration,
                completed_at=datetime.now().isoformat(),
            )
            self.db.update_app(app.id, status="idle", last_build_at=datetime.now().isoformat())
            self._emit("build_completed", build_id, success)

        except Exception as e:
            # Kill the subprocess so it doesn't linger as a zombie
            try:
                process.kill()
                process.wait(timeout=10)
            except Exception:
                pass
            self.db.update_build(
                build_id,
                status="failed",
                log_output=f"Error: {e}\n" + "\n".join(output_lines[-100:]),
                duration_seconds=int(time.time() - start),
                completed_at=datetime.now().isoformat(),
            )
            self.db.update_app(app.id, status="error")
            self._emit("build_completed", build_id, False)

    def _get_build_command(self, app: App, build_type: str) -> str:
        if app.build_command:
            return app.build_command

        flutter = self.settings.get("flutter_path", "") or "flutter"
        godot = self.settings.get("godot_path", "") or "godot"

        pp = shlex.quote(app.project_path)
        if app.app_type == "flutter":
            if build_type == "appbundle":
                return f'cd {pp} && flutter build appbundle --release'
            elif build_type == "apk":
                return f'cd {pp} && flutter build apk --release'
            elif build_type == "debug":
                return f'cd {pp} && flutter build apk --debug'
        elif app.app_type == "godot":
            return f'{shlex.quote(godot)} --headless --export-release "Android" build/{app.slug}.apk'
        elif app.app_type == "phaser":
            # Runs via bash -l -c. Commands use bash-native syntax / forward slashes.
            # npm install is idempotent; npx cap add android runs once (only if missing).
            # Gradle task varies by build_type.
            gradle_task = {
                "appbundle": "bundleRelease",
                "apk": "assembleRelease",
                "debug": "assembleDebug",
            }.get(build_type, "bundleRelease")
            return (
                f'cd {pp} && '
                f'npm install && '
                f'npm run build && '
                f'{{ [ -d "android" ] || npx cap add android; }} && '
                f'npx cap sync android && '
                f'cd android && '
                f'./gradlew {gradle_task}'
            )

        return "echo 'No build command configured'"

    def _get_output_path(self, app: App, build_type: str) -> str:
        if app.build_output_path:
            return os.path.normpath(os.path.join(app.project_path, app.build_output_path)).replace("\\", "/")

        if app.app_type == "flutter":
            if build_type == "appbundle":
                return os.path.normpath(
                    os.path.join(app.project_path, "build/app/outputs/bundle/release/app-release.aab")
                ).replace("\\", "/")
            else:
                return os.path.normpath(
                    os.path.join(app.project_path, "build/app/outputs/flutter-apk/app-release.apk")
                ).replace("\\", "/")
        elif app.app_type == "godot":
            return os.path.normpath(
                os.path.join(app.project_path, f"build/{app.slug}.apk")
            ).replace("\\", "/")
        elif app.app_type == "phaser":
            if build_type == "appbundle":
                return os.path.normpath(
                    os.path.join(app.project_path, "android/app/build/outputs/bundle/release/app-release.aab")
                ).replace("\\", "/")
            elif build_type == "debug":
                return os.path.normpath(
                    os.path.join(app.project_path, "android/app/build/outputs/apk/debug/app-debug.apk")
                ).replace("\\", "/")
            else:
                return os.path.normpath(
                    os.path.join(app.project_path, "android/app/build/outputs/apk/release/app-release.apk")
                ).replace("\\", "/")

        return ""
