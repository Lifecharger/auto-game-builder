"""
Chrome CDP Launcher — spin up a real Chrome with a debug port so Playwright
(or any CDP client) can attach without triggering Google's automation detection.

Why this exists:
    - Playwright's bundled Chromium gets blocked by Google login ("this browser
      may not be secure") for OAuth flows. Same with headless Chrome.
    - Tripo Studio, Grok, and most modern webapps detect Playwright's
      chrome.exe launch args and refuse to log in.
    - BUT if you launch real Chrome yourself with --remote-debugging-port,
      it passes every automation check because it's a normal Chrome instance.
      Playwright then ATTACHES to it after you're already logged in.

The catch — Chrome silently ignores --remote-debugging-port if your main
User Data directory has policy/extension state that blocks it. The fix:
use a FRESH isolated --user-data-dir so the flag is honored.

Usage:
    # One-time: launch a fresh Chrome tied to a named profile
    python chrome_cdp_launcher.py --profile tripo --port 9222
    python chrome_cdp_launcher.py --profile grok  --port 9223
    python chrome_cdp_launcher.py --profile twitter --port 9224

    # Each --profile keeps its own cookies forever so you only log in once.
    # After running: the Chrome window is open, debug port is live.
    # Verify with: curl http://localhost:9222/json/version

    # Kill all Chrome instances globally first (sometimes needed)
    python chrome_cdp_launcher.py --profile tripo --kill-first

    # Use the --cdp-url from this script as input to cdp_network_capture.py
"""
import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import urlopen
from urllib.error import URLError

PROFILES_ROOT = Path.home() / ".chrome-cdp-profiles"

CHROME_CANDIDATE_PATHS = [
    r"C:\Users\{user}\AppData\Local\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
]


def find_chrome() -> str:
    """Locate chrome.exe on Windows by probing common install paths."""
    if sys.platform != "win32":
        p = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chrome")
        if p:
            return p
        raise RuntimeError("Chrome not found in PATH on non-Windows system")
    user = os.environ.get("USERNAME", "caca_")
    for template in CHROME_CANDIDATE_PATHS:
        path = template.format(user=user)
        if os.path.isfile(path):
            return path
    # Last-ditch: try registry lookup
    try:
        import winreg
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                              r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe")
        val, _ = winreg.QueryValueEx(key, None)
        if os.path.isfile(val):
            return val
    except Exception:
        pass
    raise RuntimeError("chrome.exe not found. Install Chrome or add --chrome-path.")


def kill_all_chrome():
    """Windows: taskkill every chrome.exe."""
    if sys.platform != "win32":
        subprocess.run(["pkill", "-f", "chrome"], capture_output=True)
        return
    subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"],
                     capture_output=True, text=True)
    time.sleep(2)  # let orphaned renderer procs settle


def wait_for_port(port: int, timeout: float = 10.0) -> bool:
    """Poll http://localhost:<port>/json/version until ready or timeout."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urlopen(f"http://localhost:{port}/json/version", timeout=1) as r:
                if r.status == 200:
                    return True
        except (URLError, ConnectionError, OSError):
            pass
        time.sleep(0.5)
    return False


def launch(profile_name: str, port: int, chrome_path: str = None,
            kill_first: bool = False, start_url: str = "about:blank",
            extra_args: list = None) -> dict:
    """Launch Chrome tied to a named isolated profile with CDP enabled."""
    if not chrome_path:
        chrome_path = find_chrome()
    profile_dir = PROFILES_ROOT / profile_name
    profile_dir.mkdir(parents=True, exist_ok=True)

    if kill_first:
        print(f"Killing all chrome.exe processes...")
        kill_all_chrome()

    args = [
        chrome_path,
        f"--remote-debugging-port={port}",
        f"--user-data-dir={profile_dir}",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-features=DialMediaRouteProvider",
    ]
    if extra_args:
        args.extend(extra_args)
    args.append(start_url)

    print(f"Launching Chrome:")
    print(f"  profile dir: {profile_dir}")
    print(f"  debug port:  {port}")
    print(f"  start URL:   {start_url}")

    # Detach — we want Chrome to keep running after this script exits
    if sys.platform == "win32":
        # CREATE_NEW_PROCESS_GROUP + DETACHED_PROCESS
        CREATE_NEW_PROCESS_GROUP = 0x00000200
        DETACHED_PROCESS = 0x00000008
        subprocess.Popen(args, creationflags=CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS,
                          close_fds=True)
    else:
        subprocess.Popen(args, start_new_session=True, close_fds=True)

    print(f"\nWaiting for debug port to come up...")
    if not wait_for_port(port, timeout=15):
        print(f"  WARNING: port {port} didn't respond within 15s")
        print("  Try again with --kill-first, or close ALL Chrome windows manually first.")
        return {"ok": False, "port": port, "profile": str(profile_dir)}

    # Probe it once more to get the actual info
    try:
        import json
        with urlopen(f"http://localhost:{port}/json/version", timeout=2) as r:
            info = json.loads(r.read())
    except Exception as e:
        info = {"error": str(e)}

    print(f"\n[OK] Chrome is ready at http://localhost:{port}")
    print(f"     Browser: {info.get('Browser', '?')}")
    print(f"     CDP WS:  {info.get('webSocketDebuggerUrl', '?')}")
    print(f"\nNext steps:")
    print(f"  1. In the Chrome window that opened, log into the target site (once)")
    print(f"  2. Run cdp_network_capture.py --port {port} to record network traffic")
    print(f"  3. Profile persists at: {profile_dir}")

    return {"ok": True, "port": port, "profile": str(profile_dir), "info": info}


def main():
    p = argparse.ArgumentParser(
        description="Launch Chrome with CDP enabled for Playwright/requests attach",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Typical flow:
  python chrome_cdp_launcher.py --profile tripo --kill-first
  # log in to the site in the Chrome window
  python cdp_network_capture.py --port 9222 --out tripo_capture.json
""",
    )
    p.add_argument("--profile", required=True,
                   help="Named profile. One per site — keeps cookies separate.")
    p.add_argument("--port", type=int, default=9222,
                   help="CDP port (default 9222). Use different ports per profile if running multiple.")
    p.add_argument("--chrome-path", help="Override chrome.exe location")
    p.add_argument("--kill-first", action="store_true",
                   help="Kill all chrome.exe processes before launching (recommended for first launch)")
    p.add_argument("--start-url", default="about:blank",
                   help="Initial URL to navigate to")
    p.add_argument("--extra-arg", action="append", default=[],
                   help="Additional Chrome flag (repeatable)")
    args = p.parse_args()

    result = launch(
        profile_name=args.profile,
        port=args.port,
        chrome_path=args.chrome_path,
        kill_first=args.kill_first,
        start_url=args.start_url,
        extra_args=args.extra_arg,
    )
    sys.exit(0 if result.get("ok") else 1)


if __name__ == "__main__":
    main()
