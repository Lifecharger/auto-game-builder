#!/usr/bin/env python3
"""AppManager - Central dashboard for managing app projects."""

import sys
import os
import shutil
import subprocess
import atexit
import threading
import psutil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config.settings_loader import get_settings, settings_exist

_background_procs = []


def _kill_process_tree_by_pid(pid: int):
    """Kill a process and all its children by PID using psutil."""
    try:
        parent = psutil.Process(pid)
        children = parent.children(recursive=True)
        for child in reversed(children):
            try:
                child.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        parent.kill()
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass


def _kill_orphaned_processes():
    """Kill orphaned processes from previous AppManager sessions."""
    my_pid = os.getpid()
    killed = []

    # Patterns to match in command lines of orphaned processes
    orphan_cmdline_patterns = [
        "_auto.sh",        # automation scripts
        "_oneshot.sh",     # one-shot scripts
        "_task_",          # task scripts
        "claude.*-p",      # claude CLI in pipe mode
    ]
    orphan_name_patterns = [
        "cloudflared.exe",
    ]

    try:
        for proc in psutil.process_iter(["pid", "name", "cmdline"]):
            try:
                if proc.pid == my_pid:
                    continue
                name = (proc.info.get("name") or "").lower()
                cmdline = " ".join(proc.info.get("cmdline") or [])

                # Check name patterns
                for pattern in orphan_name_patterns:
                    if pattern.lower() in name:
                        print(f"[AutoGameBuilder] Killing orphaned {name} (pid={proc.pid})")
                        _kill_process_tree_by_pid(proc.pid)
                        killed.append(proc.pid)
                        break
                else:
                    # Check cmdline patterns
                    for pattern in orphan_cmdline_patterns:
                        if pattern in cmdline:
                            print(f"[AutoGameBuilder] Killing orphaned process (pid={proc.pid}): ...{pattern}...")
                            _kill_process_tree_by_pid(proc.pid)
                            killed.append(proc.pid)
                            break
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception as e:
        print(f"[AutoGameBuilder] Orphan cleanup error: {e}")

    print(f"[AutoGameBuilder] Orphan process cleanup done ({len(killed)} killed)")


def start_background_services():
    """Start API server and Cloudflare tunnel in background."""
    settings = get_settings()
    api_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "api")
    cloudflared = settings.get("cloudflared_path", "")

    # Kill orphaned processes from previous sessions before starting fresh
    _kill_orphaned_processes()

    # Start API server with auto-restart watchdog
    def _kill_port_holder(port):
        """Kill any process holding the given port."""
        try:
            result = subprocess.run(
                ["netstat", "-ano"], capture_output=True, text=True,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            for line in result.stdout.splitlines():
                if f":{port}" in line and "LISTENING" in line:
                    pid = int(line.strip().split()[-1])
                    if pid != os.getpid():
                        print(f"[AutoGameBuilder] Killing old process on port {port} (pid={pid})")
                        subprocess.run(
                            ["taskkill", "/PID", str(pid), "/F"],
                            capture_output=True,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
        except Exception as e:
            print(f"[AutoGameBuilder] Port cleanup warning: {e}")

    def _run_api_server():
        import time
        api_port = int(settings.get("port", 8000))
        _kill_port_holder(api_port)
        last_pid = None
        while True:
            log_file = open(os.path.join(api_dir, "server_crash.log"), "w", encoding="utf-8")
            host = settings.get("host", "0.0.0.0")
            port = str(settings.get("port", 8000))
            proc = subprocess.Popen(
                [sys.executable, "-m", "uvicorn", "server:app", "--host", host, "--port", port],
                cwd=api_dir,
                stdout=log_file, stderr=log_file,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            _background_procs.append(proc)
            last_pid = proc.pid
            print(f"[AutoGameBuilder] API server started (pid={proc.pid})")
            proc.wait()
            if proc in _background_procs:
                _background_procs.remove(proc)
            print("[AutoGameBuilder] API server stopped. Restarting in 5s...")
            time.sleep(5)
            # Clear the port before restarting
            _kill_port_holder(api_port)

    threading.Thread(target=_run_api_server, daemon=True).start()

    # Start Cloudflare tunnel with auto-restart watchdog
    def _run_tunnel():
        import time
        import re

        time.sleep(3)
        if not os.path.isfile(cloudflared):
            print("[AutoGameBuilder] cloudflared not found, tunnel skipped")
            return

        restart_delay = 5  # seconds between restart attempts
        max_delay = 60     # max backoff delay
        consecutive_failures = 0

        while True:
            tunnel_port = settings.get("port", 8000)
            tunnel_proc = subprocess.Popen(
                [cloudflared, "tunnel", "--url", f"http://localhost:{tunnel_port}"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            _background_procs.append(tunnel_proc)
            print(f"[AutoGameBuilder] Cloudflare tunnel started (pid={tunnel_proc.pid})")

            # Read output lines to find the tunnel URL
            tunnel_url = None
            for _ in range(60):  # read up to 60 lines
                line = tunnel_proc.stdout.readline()
                if not line:
                    break
                text = line.decode("utf-8", errors="ignore")
                match = re.search(r"(https://[a-z0-9-]+\.trycloudflare\.com)", text)
                if match:
                    tunnel_url = match.group(1)
                    break

            if tunnel_url:
                print(f"[AutoGameBuilder] Tunnel URL: {tunnel_url}")
                consecutive_failures = 0  # reset on success
                # Push to Cloudflare KV so the phone app can find us
                try:
                    kv_ns = settings.get("kv_namespace_id", "")
                    if not kv_ns:
                        print("[AutoGameBuilder] KV namespace ID not configured, skipping KV write")
                    else:
                        wrangler = settings.get("wrangler_path", "") or shutil.which("wrangler") or "wrangler"
                        kv_cmd = [
                            wrangler, "kv", "key", "put",
                            "--namespace-id", kv_ns,
                            "tunnel_url", tunnel_url, "--remote",
                        ]
                        subprocess.run(
                            kv_cmd, timeout=30, shell=True,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                        )
                        print("[AutoGameBuilder] Tunnel URL registered to KV")
                except Exception as e:
                    print(f"[AutoGameBuilder] KV write failed: {e}")
            else:
                print("[AutoGameBuilder] Could not detect tunnel URL")
                consecutive_failures += 1

            # Drain output and wait for the process to exit
            try:
                while tunnel_proc.poll() is None:
                    tunnel_proc.stdout.readline()
            except Exception:
                pass

            # Process has exited — clean up and prepare to restart
            if tunnel_proc in _background_procs:
                _background_procs.remove(tunnel_proc)
            exit_code = tunnel_proc.returncode
            if tunnel_url:
                # Tunnel was working but crashed — count as a failure now
                consecutive_failures += 1
            delay = min(restart_delay * (2 ** min(consecutive_failures, 4)), max_delay)
            print(f"[AutoGameBuilder] Cloudflare tunnel exited (code={exit_code}). Restarting in {delay}s...")
            time.sleep(delay)

    threading.Thread(target=_run_tunnel, daemon=True).start()


def cleanup():
    for proc in _background_procs:
        _kill_process_tree_by_pid(proc.pid)


def archive_old_logs():
    """Archive automation logs older than 1 month into zip files."""
    from datetime import datetime, timedelta
    import zipfile
    import glob

    cutoff = datetime.now() - timedelta(days=30)
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # Scan all project auto_build_logs directories
    try:
        sys.path.insert(0, base_dir)
        from database.db_manager import DBManager
        db_path = os.path.join(base_dir, "app_manager.db")
        db = DBManager(db_path)
        apps = db.get_all_apps()
    except Exception as e:
        print(f"[AutoGameBuilder] Log archiver: can't load apps: {e}")
        return

    for app in apps:
        log_dir = os.path.join(app.project_path, "auto_build_logs")
        if not os.path.isdir(log_dir):
            continue
        old_logs = []
        for f in glob.glob(os.path.join(log_dir, "session_*.log")):
            try:
                mtime = datetime.fromtimestamp(os.path.getmtime(f))
                if mtime < cutoff:
                    old_logs.append(f)
            except Exception:
                pass
        if not old_logs:
            continue
        archive_path = os.path.join(log_dir, f"archived_logs_{datetime.now().strftime('%Y%m%d')}.zip")
        try:
            # Collect already-archived names to avoid duplicates
            existing_names = set()
            if os.path.isfile(archive_path):
                with zipfile.ZipFile(archive_path, "r") as zr:
                    existing_names = set(zr.namelist())
            with zipfile.ZipFile(archive_path, "a", zipfile.ZIP_DEFLATED) as zf:
                for f in old_logs:
                    basename = os.path.basename(f)
                    if basename not in existing_names:
                        zf.write(f, basename)
                    os.remove(f)
            print(f"[AutoGameBuilder] Archived {len(old_logs)} old logs for {app.name}")
        except Exception as e:
            print(f"[AutoGameBuilder] Log archive error ({app.name}): {e}")


def main():
    if not settings_exist():
        # Run setup wizard from repo root
        root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        sys.path.insert(0, root_dir)
        from setup_wizard import run_wizard
        run_wizard()

    archive_old_logs()
    start_background_services()
    atexit.register(cleanup)

    settings = get_settings()
    port = settings.get("port", 8000)
    print(f"[AutoGameBuilder] Server running at http://localhost:{port}")
    print("[AutoGameBuilder] Press Ctrl+C to stop")

    # Keep the process alive (API server runs in background thread)
    try:
        while True:
            import time
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[AutoGameBuilder] Shutting down...")


if __name__ == "__main__":
    main()
