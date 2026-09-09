"""Build engine for Flutter, Godot, Phaser and Unity apps."""

import logging
import shlex
import subprocess
import threading
import time
import os
import re
from datetime import datetime
from typing import Callable, Optional

logger = logging.getLogger(__name__)
from database.db_manager import DBManager
from database.models import App
from core import unity_project

# #332: Dart symbol archive (Play Vitals libapp.so frames -> function names)
SYMBOLS_SUBDIR = "build/symbols"
SYMBOLS_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "symbols")


def flutter_root(project_path: str) -> str:
    """pubspec.yaml is at the project root, or in a well-known subdir (the AGB
    app itself lives in <repo>/app). Mirrors deploy_engine._resolve_flutter_root."""
    if os.path.isfile(os.path.join(project_path, "pubspec.yaml")):
        return project_path
    for sub in ("app", "flutter", "mobile", "client"):
        if os.path.isfile(os.path.join(project_path, sub, "pubspec.yaml")):
            return os.path.join(project_path, sub)
    return project_path


def archive_symbols(project_path: str, slug: str = "app") -> str:
    """#332: copy <flutter root>/build/symbols/*.symbols to
    server/data/symbols/<applicationId>/<versionCode>/ (kept forever; Play Vitals
    reports arrive days later). versionCode = the +N of pubspec `version:`,
    applicationId from android/app/build.gradle(.kts). Used by BOTH build paths
    (build_engine and deploy_engine). Returns a one-line note or ""."""
    import glob
    import shutil
    root = flutter_root(project_path)
    files = glob.glob(os.path.join(root, SYMBOLS_SUBDIR, "*.symbols"))
    if not files:
        return ""
    version_code = "0"
    try:
        with open(os.path.join(root, "pubspec.yaml"), encoding="utf-8") as f:
            m = re.search(r"^version:\s*([\w.]+)\+(\d+)", f.read(), re.M)
        if m:
            version_code = m.group(2)
    except OSError:
        pass
    package = slug or "app"
    for g in ("android/app/build.gradle.kts", "android/app/build.gradle"):
        try:
            with open(os.path.join(root, g), encoding="utf-8") as f:
                m = re.search(r'applicationId\s*=?\s*"([\w.]+)"', f.read())
            if m:
                package = m.group(1)
                break
        except OSError:
            continue
    dest = os.path.join(SYMBOLS_ROOT, package, version_code)
    os.makedirs(dest, exist_ok=True)
    for f in files:
        shutil.copy(f, os.path.join(dest, os.path.basename(f)))
    return f"[symbols] {len(files)} Dart symbol file(s) archived -> {dest}"


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
        # Resolving the command can fail on its own (e.g. a Unity project with
        # no BuildPlayer editor script). Record that as a failed build instead
        # of letting the worker thread die with the row stuck on "running".
        try:
            cmd = self._get_build_command(app, build_type)
            output_path = self._get_output_path(app, build_type)
        except Exception as e:
            self.db.update_build(
                build_id,
                status="failed",
                log_output=f"Cannot start build: {e}",
                duration_seconds=0,
                completed_at=datetime.now().isoformat(),
            )
            self.db.update_app(app.id, status="error")
            self._emit("build_completed", build_id, False)
            return

        # Hard guard: refuse to build if cwd lacks the expected project marker.
        # Prevents silently producing builds in the wrong directory.
        marker = {
            "flutter": "pubspec.yaml",
            "godot": "export_presets.cfg",
            "phaser": "package.json",
            "unity": "ProjectSettings/ProjectVersion.txt",
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
            if success and app.app_type == "flutter":
                try:
                    note = self._archive_symbols(app)
                    if note:
                        output_lines.append(note)
                        self._emit("build_output", build_id, note)
                except Exception as e:  # symbols are a bonus - never fail the build
                    logger.warning("symbol archive failed for %s: %s", app.name, e)

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

    # ------------------------------------------------------------ #332 symbols
    def _archive_symbols(self, app: App) -> str:
        return archive_symbols(app.project_path, app.slug or "app")

    def _get_build_command(self, app: App, build_type: str) -> str:
        if app.build_command:
            return app.build_command

        flutter = self.settings.get("flutter_path", "") or "flutter"
        godot = self.settings.get("godot_path", "") or "godot"

        pp = shlex.quote(app.project_path)
        if app.app_type == "flutter":
            # flutter clean + pub get before every build to invalidate Gradle's
            # mergeAssets incremental cache — otherwise regenerated assets
            # (SFX, images) with unchanged filenames get served stale.
            prelude = f'cd {pp} && flutter clean && flutter pub get'
            # #332: --split-debug-info keeps the Dart symbols (libapp.so) out of
            # the binary and next to it; _archive_symbols() files them per
            # versionCode so Play Vitals native frames can be resolved later
            # with tools/playstore/vitals.py symbolize.
            if build_type == "appbundle":
                return f'{prelude} && flutter build appbundle --release --split-debug-info={SYMBOLS_SUBDIR}'
            elif build_type == "apk":
                return f'{prelude} && flutter build apk --release --split-debug-info={SYMBOLS_SUBDIR}'
            elif build_type == "debug":
                return f'{prelude} && flutter build apk --debug'
        elif app.app_type == "godot":
            return f'{shlex.quote(godot)} --headless --export-release "Android" build/{app.slug}.apk'
        elif app.app_type == "unity":
            return self._unity_build_command(app, build_type)
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

    def _unity_build_command(self, app: App, build_type: str) -> str:
        """Unity builds head-lessly through an editor method in the project.

        The project must ship a BuildPlayer editor script exposing static
        Aab / Apk / DebugApk; its namespace is read from the script itself
        (core/unity_project.py) rather than assumed. Signing passwords come
        from the environment, never from here.

        Unity LOCKS a project folder, so this fails while the editor has the same
        project open - the lock file check gives that a readable error instead of a
        wall of Unity log noise.
        """
        unity = self.settings.get("unity_path", "") or "Unity"
        method = unity_project.resolve_build_method(app.project_path, build_type)
        pp = shlex.quote(app.project_path)

        # The lock file's presence alone is not proof the editor is open: a Unity
        # that dies (crash, license failure, killed batch job) leaves it behind,
        # and refusing on that blocked every later build until someone deleted it
        # by hand. Ask whether a process actually holds it.
        state = unity_project.lock_state(app.project_path)
        if state == "held":
            raise RuntimeError(
                "Refusing to build: the Unity editor has this project open "
                "(Temp/UnityLockfile). Close it and retry."
            )
        if state == "stale" and unity_project.clear_stale_lock(app.project_path):
            logger.info("Unity: removed stale lock file in %s", app.project_path)

        return (
            f'cd {pp} && '
            f'{shlex.quote(unity)} -batchmode -quit -nographics '
            f'-projectPath {pp} '
            f'-executeMethod {method} '
            f'-logFile build/unity_build.log'
        )

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
        elif app.app_type == "unity":
            extension = "aab" if build_type == "appbundle" else "apk"
            return os.path.normpath(
                os.path.join(app.project_path, f"build/{app.slug}.{extension}")
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
