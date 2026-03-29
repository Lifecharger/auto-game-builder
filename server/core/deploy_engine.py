"""Deploy engine: build apps (Flutter/Godot), auto-fix on failure, upload to Google Play."""

import os
import re
import subprocess
import threading
import time
import json
from datetime import datetime
from typing import Callable, Optional

from google.oauth2 import service_account
from googleapiclient.discovery import build as google_build
from googleapiclient.http import MediaFileUpload

from database.db_manager import DBManager
from database.models import App
from config.path_utils import to_unix_path
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

# Valid Google Play tracks
VALID_TRACKS = ["internal", "alpha", "beta", "production"]

# Build targets per app type
BUILD_TARGETS = {
    "flutter": {
        "apk": {
            "label": "APK",
            "cmd_args": ["build", "apk", "--release"],
            "output": "build/app/outputs/flutter-apk/app-release.apk",
        },
        "aab": {
            "label": "AAB",
            "cmd_args": ["build", "appbundle", "--release"],
            "output": "build/app/outputs/bundle/release/app-release.aab",
        },
        "exe": {
            "label": "Windows",
            "cmd_args": ["build", "windows", "--release"],
            "output": "build/windows/x64/runner/Release",
        },
        "web": {
            "label": "Web",
            "cmd_args": ["build", "web", "--release"],
            "output": "build/web",
        },
        "ios": {
            "label": "iOS",
            "cmd_args": ["build", "ipa", "--release"],
            "output": "build/ios/ipa",
        },
    },
    "godot": {
        "apk": {
            "label": "APK",
            "preset": "Android APK",
            "output": "build/{slug}.apk",
        },
        "aab": {
            "label": "AAB",
            "preset": "Android AAB",
            "output": "build/{slug}.aab",
        },
        "windows": {
            "label": "Windows",
            "preset": "Windows Desktop",
            "output": "build/{slug}.exe",
        },
        "web": {
            "label": "Web",
            "preset": "Web",
            "output": "build/{slug}.html",
        },
        "linux": {
            "label": "Linux",
            "preset": "Linux",
            "output": "build/{slug}.x86_64",
        },
    },
}


class DeployEngine:
    def __init__(self, db: DBManager, settings: dict):
        self.db = db
        self.settings = settings
        self._active_deploys: dict[int, dict] = {}  # app_id -> status
        self._active_processes: dict[int, subprocess.Popen] = {}  # app_id -> build subprocess
        self._cancelled: set[int] = set()  # app_ids with cancelled deploys
        self._shutting_down = False
        self._godot_build_lock = threading.Lock()  # serialize Godot builds to avoid gradle conflicts
        self._callbacks: dict[str, list[Callable]] = {
            "deploy_status": [],
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

    def cancel(self, app_id: int) -> dict:
        """Cancel an active deploy/build for the given app."""
        self._cancelled.add(app_id)

        # Kill active build subprocess and its entire process tree
        proc = self._active_processes.get(app_id)
        if proc and proc.poll() is None:
            try:
                import psutil
                parent = psutil.Process(proc.pid)
                children = parent.children(recursive=True)
                for child in reversed(children):
                    try:
                        child.kill()
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
                try:
                    parent.kill()
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
                psutil.wait_procs(children + [parent], timeout=5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass

        self._update_status(app_id, phase="failed", message="Build cancelled by user")
        self._active_processes.pop(app_id, None)
        self.db.update_app(app_id, status="idle")
        return {"ok": True, "message": "Build cancelled"}

    def _is_cancelled(self, app_id: int) -> bool:
        return app_id in self._cancelled

    def get_status(self, app_id: int) -> Optional[dict]:
        return self._active_deploys.get(app_id)

    def get_targets(self, app_type: str) -> dict:
        """Return available build targets for an app type."""
        return BUILD_TARGETS.get(app_type, {})

    def shutdown(self):
        """Gracefully terminate all active build subprocesses."""
        self._shutting_down = True
        for app_id, proc in list(self._active_processes.items()):
            try:
                if proc.poll() is None:
                    print(f"[DeployEngine] Terminating build process for app {app_id} (pid={proc.pid})")
                    try:
                        import psutil
                        parent = psutil.Process(proc.pid)
                        children = parent.children(recursive=True)
                        for child in reversed(children):
                            try:
                                child.kill()
                            except (psutil.NoSuchProcess, psutil.AccessDenied):
                                pass
                        parent.kill()
                        psutil.wait_procs(children + [parent], timeout=5)
                    except Exception:
                        proc.kill()
            except Exception:
                pass
        self._active_processes.clear()

    def deploy(self, app: App, track: str = "internal", build_target: str = "aab",
               upload: bool = False, max_retries: int = 2) -> dict:
        """Start build (and optional deploy) in background."""
        if upload and track not in VALID_TRACKS:
            return {"error": f"Invalid track: {track}. Must be one of {VALID_TRACKS}"}

        targets = BUILD_TARGETS.get(app.app_type, {})
        if build_target not in targets:
            return {"error": f"Invalid target '{build_target}' for {app.app_type}. Valid: {list(targets.keys())}"}

        if upload and not app.package_name:
            return {"error": "App has no package_name set"}

        if app_id := app.id:
            # Clear any previous cancellation for this app
            self._cancelled.discard(app_id)
            if app_id in self._active_deploys and self._active_deploys[app_id].get("phase") not in ("done", "failed"):
                return {"error": "Build already in progress"}

        target_label = targets[build_target]["label"]
        status = {
            "app_id": app.id,
            "track": track,
            "build_target": build_target,
            "upload": upload,
            "phase": "starting",
            "message": f"Starting {target_label} build...",
            "started_at": datetime.now().isoformat(),
            "build_id": None,
            "attempt": 0,
            "max_retries": max_retries,
        }
        self._active_deploys[app.id] = status

        thread = threading.Thread(
            target=self._run_deploy,
            args=(app, track, build_target, upload, max_retries),
            daemon=True,
        )
        thread.start()

        msg = f"Building {target_label}"
        if upload:
            msg += f" + upload to {track}"
        return {"ok": True, "message": msg}

    def _update_status(self, app_id: int, **kwargs):
        if app_id in self._active_deploys:
            self._active_deploys[app_id].update(kwargs)
            self._emit("deploy_status", app_id, self._active_deploys[app_id])

    def _run_deploy(self, app: App, track: str, build_target: str, upload: bool, max_retries: int):
        try:
            targets = BUILD_TARGETS.get(app.app_type, {})
            target_info = targets.get(build_target, {})
            target_label = target_info.get("label", build_target)

            # Step 1: Bump version (only for Android targets)
            new_version = None
            if build_target in ("aab", "apk"):
                if self._is_cancelled(app.id):
                    return
                self._update_status(app.id, phase="versioning", message="Bumping version...")
                new_version = self._bump_version(app)
                if new_version:
                    self._update_status(app.id, message=f"Version bumped to {new_version}")
                    self.db.update_app(app.id, current_version=new_version)

            # Step 2: Build (with retry on failure)
            output_path = None
            for attempt in range(1, max_retries + 2):
                if self._is_cancelled(app.id):
                    return
                self._update_status(
                    app.id, phase="building", attempt=attempt,
                    message=f"Building {target_label} (attempt {attempt})..."
                )

                build_id = self._run_build(app, build_target, version=new_version)
                self._update_status(app.id, build_id=build_id)

                build = self._wait_for_build(build_id, timeout=900)
                if build and build.status == "success":
                    output_path = build.output_path
                    # Mark all completed tasks as "built"
                    self._mark_tasks_built(app, new_version or app.current_version)
                    break

                # Check if build hung vs failed
                was_hung = build and build.log_output and "[HUNG]" in build.log_output

                if attempt <= max_retries:
                    if was_hung:
                        self._update_status(
                            app.id, phase="fixing",
                            message=f"Build hung. Diagnosing scripts (attempt {attempt}/{max_retries})..."
                        )
                        fixed = self._auto_fix_hung_build(app)
                    else:
                        self._update_status(
                            app.id, phase="fixing",
                            message=f"Build failed. Auto-fixing (attempt {attempt}/{max_retries})..."
                        )
                        fixed = self._auto_fix_build(app, build)
                    if not fixed:
                        # Don't give up on first auto-fix failure — still retry the build
                        # (the hang might have been transient: stale process, file lock, etc.)
                        if was_hung:
                            self._update_status(
                                app.id, phase="retrying",
                                message=f"No script errors found. Retrying build (attempt {attempt + 1})..."
                            )
                            continue
                        self._update_status(
                            app.id, phase="failed",
                            message="Build failed and auto-fix could not apply changes"
                        )
                        self.db.update_app(app.id, status="error")
                        return
                else:
                    self._update_status(
                        app.id, phase="failed",
                        message=f"Build {'hung' if was_hung else 'failed'} after {max_retries + 1} attempts"
                    )
                    self.db.update_app(app.id, status="error")
                    return

            if not output_path or not os.path.exists(output_path):
                self._update_status(
                    app.id, phase="failed",
                    message=f"Build output not found at {output_path}"
                )
                return

            # Step 3: Upload to Google Play (only if upload=True and target is aab)
            if upload and build_target == "aab":
                if self._is_cancelled(app.id):
                    return
                upload_result = None
                for upload_attempt in range(1, 4):
                    if self._is_cancelled(app.id):
                        return
                    self._update_status(
                        app.id, phase="uploading",
                        message=f"Uploading to Google Play ({track})... attempt {upload_attempt}/3"
                    )
                    upload_result = self._upload_to_play(app, output_path, track)
                    if upload_result.get("ok"):
                        break
                    if upload_attempt < 3:
                        self._update_status(
                            app.id, phase="upload_retry",
                            message=f"Upload failed: {upload_result.get('error', '?')}. Retrying in 10s..."
                        )
                        time.sleep(10)

                if upload_result and upload_result.get("ok"):
                    self._update_status(
                        app.id, phase="done",
                        message=f"Deployed to {track}: v{new_version or app.current_version}"
                    )
                    publish_map = {
                        "internal": "internal_test",
                        "alpha": "external_test",
                        "beta": "external_test",
                        "production": "published",
                    }
                    self.db.update_app(
                        app.id,
                        status="idle",
                        publish_status=publish_map.get(track, "internal_test"),
                    )
                else:
                    err = upload_result.get("error", "Unknown") if upload_result else "No result"
                    self._update_status(
                        app.id, phase="failed",
                        message=f"Upload failed after 3 attempts: {err}"
                    )
            else:
                # Build-only complete
                self._update_status(
                    app.id, phase="done",
                    message=f"{target_label} build complete: {output_path}"
                )
                self.db.update_app(app.id, status="idle")

        except Exception as e:
            self._update_status(
                app.id, phase="failed",
                message=f"Deploy error: {str(e)}"
            )
            self.db.update_app(app.id, status="error")
        finally:
            self._active_processes.pop(app.id, None)

    def _bump_version(self, app: App) -> Optional[str]:
        """Bump patch version and build number."""
        try:
            if app.app_type == "flutter":
                return self._bump_flutter_version(app)
            elif app.app_type == "godot":
                return self._bump_godot_version(app)
        except Exception as e:
            self._update_status(app.id, message=f"Version bump warning: {e}")
        return None

    def _bump_flutter_version(self, app: App) -> Optional[str]:
        pubspec = os.path.join(app.project_path, "pubspec.yaml")
        if not os.path.isfile(pubspec):
            return None
        with open(pubspec, "r") as f:
            content = f.read()
        match = re.search(r"version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)", content)
        if not match:
            return None
        major, minor, patch, build_num = int(match.group(1)), int(match.group(2)), int(match.group(3)), int(match.group(4))
        patch += 1
        build_num += 1
        new_version = f"{major}.{minor}.{patch}+{build_num}"
        content = re.sub(r"version:\s*\d+\.\d+\.\d+\+\d+", f"version: {new_version}", content)
        with open(pubspec, "w") as f:
            f.write(content)
        return new_version

    def _bump_godot_version(self, app: App) -> Optional[str]:
        export_cfg = os.path.join(app.project_path, "export_presets.cfg")
        if not os.path.isfile(export_cfg):
            return None
        with open(export_cfg, "r") as f:
            content = f.read()
        code_match = re.search(r'version/code=(\d+)', content)
        name_match = re.search(r'version/name="(\d+\.\d+\.\d+)"', content)
        if not code_match:
            return None
        code = int(code_match.group(1)) + 1
        content = re.sub(r'version/code=\d+', f'version/code={code}', content)
        if name_match:
            parts = name_match.group(1).split(".")
            parts[-1] = str(int(parts[-1]) + 1)
            new_name = ".".join(parts)
            content = re.sub(r'version/name="[^"]*"', f'version/name="{new_name}"', content)
        else:
            new_name = f"1.0.{code}"
        with open(export_cfg, "w") as f:
            f.write(content)
        return f"{new_name}+{code}"

    def _prepare_godot_android(self, app: App):
        """Sync Android build template with the Godot binary to prevent version mismatch."""
        godot = self.settings.get("godot_path", "") or "godot"
        try:
            result = subprocess.run(
                [godot, "--version"],
                capture_output=True, text=True, timeout=15,
            )
            # e.g. "4.6.1.stable.official.14d19694e" -> "4.6.1.stable"
            full_ver = result.stdout.strip()
            parts = full_ver.split(".")
            # Take up to "stable" or "stable.mono" (before "official")
            ver_parts = []
            for p in parts:
                if p == "official":
                    break
                ver_parts.append(p)
            build_version = ".".join(ver_parts)  # e.g. "4.6.1.stable" or "4.6.1.stable.mono"
        except Exception:
            build_version = None

        if build_version:
            version_changed = False
            for bv_path in [
                os.path.join(app.project_path, "android", ".build_version"),
                os.path.join(app.project_path, "android", "build", ".build_version"),
            ]:
                if os.path.isdir(os.path.dirname(bv_path)):
                    try:
                        existing = ""
                        if os.path.isfile(bv_path):
                            with open(bv_path, "r") as f:
                                existing = f.read().strip()
                        if existing != build_version:
                            version_changed = True
                            with open(bv_path, "w") as f:
                                f.write(build_version)
                    except Exception:
                        pass

            # Only clean gradle cache when there was a version mismatch
            if version_changed:
                gradle_build = os.path.join(app.project_path, "android", "build", "build")
                if os.path.isdir(gradle_build):
                    import shutil
                    try:
                        shutil.rmtree(gradle_build)
                    except Exception:
                        pass

    def _kill_stale_godot_processes(self, app: App):
        """Kill any leftover Godot processes for this app before starting a new build."""
        import psutil
        project_path = app.project_path.replace("\\", "/")
        for proc in psutil.process_iter(["pid", "name", "cmdline"]):
            try:
                name = proc.info.get("name", "") or ""
                if "godot" not in name.lower():
                    continue
                cmdline = " ".join(proc.info.get("cmdline") or [])
                # Kill if it references this app's build output
                if app.slug in cmdline or project_path in cmdline.replace("\\", "/"):
                    print(f"[DeployEngine] Killing stale Godot process pid={proc.pid}: {cmdline}")
                    children = proc.children(recursive=True)
                    for child in reversed(children):
                        try:
                            child.kill()
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                    proc.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

    def _run_build(self, app: App, build_target: str, version: Optional[str] = None) -> int:
        """Build the specified target and return build_id."""
        cmd = self._get_build_cmd(app, build_target)
        output_path = self._get_build_output(app, build_target)

        # Ensure output directory exists for Godot
        is_godot = app.app_type == "godot"
        if is_godot:
            build_dir = os.path.join(app.project_path, "build")
            os.makedirs(build_dir, exist_ok=True)
            # Kill any stale Godot processes for this app
            self._kill_stale_godot_processes(app)
            # Sync Android template version with Godot binary to prevent mismatch
            if build_target in ("aab", "apk"):
                self._prepare_godot_android(app)

        build_id = self.db.create_build(
            app_id=app.id,
            build_type=build_target,
            version=version or app.current_version,
            status="running",
            started_at=datetime.now().isoformat(),
        )

        self.db.update_app(app.id, status="building")
        start = time.time()
        output_lines = []
        hung = False

        # Godot builds serialize via lock to avoid gradle daemon conflicts
        if is_godot:
            self._update_status(app.id, message=f"Waiting for build slot...")
            if not self._godot_build_lock.acquire(timeout=300):
                # Lock stuck for 5 min — force release and take it
                try:
                    self._godot_build_lock.release()
                except RuntimeError:
                    pass
                self._godot_build_lock = threading.Lock()
                self._godot_build_lock.acquire()

        try:
            if is_godot:
                self._update_status(app.id, message=f"Building...")

            if is_godot:
                # GODOT BUILDS: Write to log file instead of pipe.
                # Godot spawns Gradle which inherits pipe handles — the pipe
                # never gets EOF because the Gradle daemon holds it open.
                # This caused builds to hang forever despite the AAB being ready.
                log_file_path = os.path.join(app.project_path, "build", "build_log.txt")
                with open(log_file_path, "w") as log_f:
                    process = subprocess.Popen(
                        cmd,
                        stdout=log_f,
                        stderr=subprocess.STDOUT,
                        cwd=app.project_path,
                    )
                self._active_processes[app.id] = process

                # Monitor: poll for build output file + process exit
                # Godot builds are done when the output file appears and stabilizes
                max_build_time = 900  # 15 min max for Godot builds
                output_stable_time = None

                while time.time() - start < max_build_time:
                    if self._shutting_down or self._is_cancelled(app.id):
                        self._kill_build_tree(process)
                        break

                    # Check if process exited on its own
                    if process.poll() is not None:
                        break

                    # Check if build output file exists and has stabilized
                    if os.path.isfile(output_path):
                        try:
                            size = os.path.getsize(output_path)
                            mtime = os.path.getmtime(output_path)
                        except OSError:
                            size, mtime = 0, 0

                        if size > 0 and mtime > start:
                            if output_stable_time is None:
                                output_stable_time = time.time()
                            elif time.time() - output_stable_time > 15:
                                # AAB file hasn't changed for 15s — build is done
                                self._update_status(app.id, message="Build output ready, cleaning up...")
                                self._kill_build_tree(process)
                                break
                        else:
                            output_stable_time = None
                    else:
                        output_stable_time = None

                    time.sleep(5)
                else:
                    # Max time exceeded
                    hung = True
                    self._update_status(
                        app.id, phase="hang_detected",
                        message=f"Build timed out after {max_build_time // 60} min — killing..."
                    )
                    self._kill_build_tree(process)

                # Read the log file for build output
                try:
                    with open(log_file_path, "r", encoding="utf-8", errors="replace") as f:
                        raw = f.read()
                    output_lines = [re.sub(r"\x1b\[[0-9;]*m", "", l) for l in raw.splitlines()]
                except Exception:
                    pass

                process.wait(timeout=15)

            else:
                # FLUTTER BUILDS: Use pipes (Flutter doesn't have the daemon problem)
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    cwd=app.project_path,
                )
                self._active_processes[app.id] = process

                for line in process.stdout:
                    if self._shutting_down or self._is_cancelled(app.id):
                        process.terminate()
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            process.kill()
                        break
                    clean = re.sub(r"\x1b\[[0-9;]*m", "", line.rstrip())
                    output_lines.append(clean)

                process.wait(timeout=600)

            duration = int(time.time() - start)
            # For Godot: success = output file exists (don't rely on exit code since we kill the process)
            if is_godot:
                build_file_exists = os.path.isfile(output_path) and os.path.getsize(output_path) > 0
                file_fresh = False
                if build_file_exists:
                    try:
                        file_fresh = os.path.getmtime(output_path) > start
                    except OSError:
                        pass
                success = build_file_exists and file_fresh and not self._shutting_down and not self._is_cancelled(app.id) and not hung
            else:
                success = process.returncode == 0 and not self._shutting_down and not self._is_cancelled(app.id)

            self.db.update_build(
                build_id,
                status="success" if success else "failed",
                output_path=output_path if success else "",
                log_output="\n".join(output_lines[-200:]) + ("\n[HUNG] Build killed after timeout" if hung else ""),
                duration_seconds=duration,
                completed_at=datetime.now().isoformat(),
            )
        except Exception as e:
            self.db.update_build(
                build_id,
                status="failed",
                log_output=f"Error: {e}\n" + "\n".join(output_lines[-100:]),
                duration_seconds=int(time.time() - start),
                completed_at=datetime.now().isoformat(),
            )
        finally:
            self._active_processes.pop(app.id, None)
            if is_godot and self._godot_build_lock.locked():
                self._godot_build_lock.release()

        return build_id

    def _kill_build_tree(self, process: subprocess.Popen):
        """Kill a build process and all its children (Gradle daemons etc)."""
        import psutil
        try:
            parent = psutil.Process(process.pid)
            children = parent.children(recursive=True)
            for child in reversed(children):
                try:
                    child.kill()
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            try:
                parent.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
            psutil.wait_procs(children + [parent], timeout=10)
        except Exception:
            try:
                process.kill()
            except Exception:
                pass

    def _get_build_cmd(self, app: App, build_target: str) -> list:
        """Return command for the specified build target."""
        targets = BUILD_TARGETS.get(app.app_type, {})
        target_info = targets.get(build_target, {})

        if app.app_type == "flutter":
            cmd_args = target_info.get("cmd_args", ["build", "appbundle", "--release"])
            return [self.settings.get("flutter_path", "") or "flutter"] + cmd_args
        elif app.app_type == "godot":
            godot = self.settings.get("godot_path", "") or "godot"
            preset = target_info.get("preset", "Android")
            output = target_info.get("output", f"build/{app.slug}.aab").format(slug=app.slug)
            return [godot, "--headless", "--export-release", preset, output]

        return ["echo", "Unsupported app type"]

    def _get_build_output(self, app: App, build_target: str) -> str:
        """Return expected output path for the build target."""
        targets = BUILD_TARGETS.get(app.app_type, {})
        target_info = targets.get(build_target, {})
        relative = target_info.get("output", "")

        if app.app_type == "godot":
            relative = relative.format(slug=app.slug)

        return os.path.normpath(
            os.path.join(app.project_path, relative)
        ).replace("\\", "/")

    def _wait_for_build(self, build_id: int, timeout: int = 600):
        """Poll DB until build is done."""
        start = time.time()
        while time.time() - start < timeout:
            build = self.db.get_build(build_id)
            if build and build.status in ("success", "failed"):
                return build
            time.sleep(3)
        return self.db.get_build(build_id)

    def _mark_tasks_built(self, app: App, version: str):
        """After successful build, mark all 'completed' tasks as 'built' with the build version."""
        try:
            tl_path = os.path.join(app.project_path, "tasklist.json")
            if not os.path.isfile(tl_path):
                return
            with open(tl_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            tasks = data.get("tasks", data) if isinstance(data, dict) else data
            changed = False
            for t in (tasks if isinstance(tasks, list) else []):
                if t.get("status") in ("completed", "divided"):
                    t["status"] = "built"
                    t["built_version"] = version
                    changed = True
            if changed:
                payload = json.dumps({"tasks": tasks} if isinstance(data, dict) else tasks, indent=2, ensure_ascii=False)
                with open(tl_path, "w", encoding="utf-8") as f:
                    f.write(payload)
        except Exception as e:
            print(f"[DeployEngine] Failed to mark tasks as built: {e}")

    def _auto_fix_hung_build(self, app: App) -> bool:
        """Spawn Claude to diagnose and fix a hung build (especially Godot)."""
        claude_md = ""
        claude_md_path = os.path.join(app.project_path, "CLAUDE.md")
        if os.path.isfile(claude_md_path):
            try:
                with open(claude_md_path, "r", encoding="utf-8") as f:
                    claude_md = f"\n\nProject context (CLAUDE.md):\n{f.read()[:2000]}"
            except Exception:
                pass

        claude_path = self.settings.get("claude_path", "") or "claude"
        project_path_unix = to_unix_path(app.project_path)
        mcp_config_path = os.path.join(app.project_path, "mcp_config.json")
        mcp_flag = f"--mcp-config '{project_path_unix}/mcp_config.json'" if os.path.isfile(mcp_config_path) else ""

        prompt = f"""The {app.app_type} build for {app.name} HUNG during export — the build process started but produced no output and had to be killed.

Project path: {app.project_path}
App type: {app.app_type}
{claude_md}

This is a {app.app_type} project. The headless export hung silently.

DIAGNOSE AND FIX (Engine Specialist + DevOps Knowledge):
1. Check ALL script files (.gd for Godot, .dart for Flutter) for syntax errors, undefined references, missing imports, or circular dependencies.
2. Check scene files (.tscn) for broken references to scripts or resources that don't exist.
3. Check project.godot autoloads for missing scripts.
4. Check for any preload/load paths that reference non-existent files.
5. Look for infinite loops in _ready() or _init() that would hang the export.
6. Check for blocking I/O operations without timeouts (HTTP requests, file reads on missing paths).
7. Verify no script uses := in lambdas (Godot 4.6.1 parser bug that can cause silent hangs).
8. If you find errors, FIX THEM. Only fix build-breaking issues, do NOT change game logic.
9. If you can't find any script errors, check if there are export preset issues in export_presets.cfg.
10. Do NOT attempt to run the build yourself — just fix the code."""

        try:
            bash_exe = self.settings.get("bash_path", "") or "bash"
            claude_bin_unix = to_unix_path(claude_path)
            cmd = f'cd "{project_path_unix}" && "{claude_bin_unix}" -p --dangerously-skip-permissions --verbose {mcp_flag}'
            process = subprocess.Popen(
                [bash_exe, "-l", "-c", cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=app.project_path,
            )
            stdout, _ = process.communicate(input=prompt, timeout=300)
            exit_code = process.returncode

            if exit_code == 0:
                try:
                    git_result = subprocess.run(
                        [bash_exe, "-c", f'cd "{project_path_unix}" && git status --porcelain 2>/dev/null'],
                        capture_output=True, text=True, timeout=10, cwd=app.project_path,
                    )
                    if git_result.returncode == 0 and git_result.stdout.strip():
                        has_changes = True
                    elif git_result.returncode != 0:
                        has_changes = True
                    else:
                        has_changes = False
                except Exception:
                    has_changes = True

                if has_changes:
                    self._update_status(app.id, message="Hang diagnosis found and fixed script errors, retrying build...")
                    return True
                else:
                    self._update_status(app.id, message="Hang diagnosis found no script errors — may be transient")
                    return False
            else:
                self._update_status(app.id, message=f"Hang diagnosis failed (exit {exit_code})")
                return False
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            self._update_status(app.id, message="Hang diagnosis timed out (5min)")
            return False
        except Exception as e:
            self._update_status(app.id, message=f"Hang diagnosis error: {e}")
            return False

    def _auto_fix_build(self, app: App, build) -> bool:
        """Run Claude to fix build errors. Returns True if fix was applied."""
        if not build or not build.log_output:
            return False

        error_log = "\n".join(build.log_output.split("\n")[-100:])

        # Read CLAUDE.md context if available
        claude_md = ""
        claude_md_path = os.path.join(app.project_path, "CLAUDE.md")
        if os.path.isfile(claude_md_path):
            try:
                with open(claude_md_path, "r", encoding="utf-8") as f:
                    claude_md = f"\n\nProject context (CLAUDE.md):\n{f.read()[:2000]}"
            except Exception:
                pass

        claude_path = self.settings.get("claude_path", "") or "claude"
        project_path_unix = to_unix_path(app.project_path)
        mcp_config_path = os.path.join(app.project_path, "mcp_config.json")
        mcp_flag = f"--mcp-config '{project_path_unix}/mcp_config.json'" if os.path.isfile(mcp_config_path) else ""

        prompt = f"""The build for {app.name} ({app.app_type}) failed. Fix the build errors.

Project path: {app.project_path}
{claude_md}

Build error log (last 100 lines):
```
{error_log}
```

INSTRUCTIONS (Lead Programmer + Engine Specialist Knowledge):
1. Read the error log carefully and identify the root cause — understand WHY it failed.
2. Navigate to the failing file(s) and fix the code.
3. Only fix build-related errors. Do NOT change game/app logic.
4. Common build-breakers to check:
   - Missing imports or undefined references
   - Type mismatches (especially after refactoring)
   - Circular dependencies between scripts/modules
   - Invalid resource paths (preload/load of non-existent files)
   - Scene files referencing deleted/renamed scripts
   - Godot: := in lambdas (parser bug), missing typed variable declarations
   - Flutter: null safety violations, missing required parameters
5. After fixing, verify the fix makes sense (e.g. correct imports, matching types).
6. Check if the fix could break other files that depend on the changed code.
7. Do NOT attempt to run the build yourself — just fix the code."""

        try:
            bash_exe = self.settings.get("bash_path", "") or "bash"
            claude_bin_unix = to_unix_path(claude_path)
            cmd = f'cd "{project_path_unix}" && "{claude_bin_unix}" -p --dangerously-skip-permissions --verbose {mcp_flag}'
            process = subprocess.Popen(
                [bash_exe, "-l", "-c", cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                cwd=app.project_path,
            )
            stdout, _ = process.communicate(input=prompt, timeout=300)
            exit_code = process.returncode

            if exit_code == 0:
                # Check if Claude actually modified any files
                try:
                    git_result = subprocess.run(
                        [bash_exe, "-c", f'cd "{project_path_unix}" && git status --porcelain 2>/dev/null'],
                        capture_output=True, text=True, timeout=10, cwd=app.project_path,
                    )
                    if git_result.returncode == 0 and git_result.stdout.strip():
                        has_changes = True
                    elif git_result.returncode != 0:
                        # Not a git repo — assume changes were made
                        has_changes = True
                    else:
                        has_changes = False
                except Exception:
                    has_changes = True  # Assume changes if we can't check

                if has_changes:
                    self._update_status(app.id, message="Auto-fix applied changes, retrying build...")
                    return True
                else:
                    self._update_status(app.id, message="Auto-fix ran but made no changes")
                    return False
            else:
                self._update_status(app.id, message=f"Auto-fix failed (exit {exit_code})")
                return False
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            self._update_status(app.id, message="Auto-fix timed out (5min)")
            return False
        except Exception as e:
            self._update_status(app.id, message=f"Auto-fix error: {e}")
            return False

    def _upload_to_play(self, app: App, aab_path: str, track: str) -> dict:
        """Upload AAB to Google Play with timeout protection."""
        result = {}
        upload_error = None

        def _do_upload():
            nonlocal result, upload_error
            try:
                sa_key = self.settings.get("service_account_key", "")
                if not sa_key:
                    raise ValueError("No service_account_key configured in settings.json")
                credentials = service_account.Credentials.from_service_account_file(
                    sa_key, scopes=SCOPES
                )
                service = google_build("androidpublisher", "v3", credentials=credentials)

                package = app.package_name

                edit = service.edits().insert(packageName=package, body={}).execute()
                edit_id = edit["id"]

                media = MediaFileUpload(aab_path, mimetype="application/octet-stream",
                                        resumable=True, chunksize=10 * 1024 * 1024)
                upload_resp = service.edits().bundles().upload(
                    packageName=package, editId=edit_id, media_body=media
                ).execute()

                version_code = upload_resp["versionCode"]

                service.edits().tracks().update(
                    packageName=package,
                    editId=edit_id,
                    track=track,
                    body={
                        "track": track,
                        "releases": [{
                            "versionCodes": [str(version_code)],
                            "status": "draft" if track == "internal" else "completed",
                        }],
                    },
                ).execute()

                service.edits().commit(packageName=package, editId=edit_id).execute()

                result = {"ok": True, "version_code": version_code}

            except Exception as e:
                upload_error = str(e)

            except Exception as e:
                upload_error = str(e)

        upload_thread = threading.Thread(target=_do_upload, daemon=True)
        upload_thread.start()
        upload_thread.join(timeout=300)  # 5 minute timeout for upload

        if upload_thread.is_alive():
            return {"error": "Upload timed out after 5 minutes"}
        if upload_error:
            return {"error": upload_error}
        return result
