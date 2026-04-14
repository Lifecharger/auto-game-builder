"""Auto Game Builder — Pull & Rebuild script.

Launched by the desktop app when user clicks "Pull & Rebuild".
The app exits before calling this, so the exe is unlocked for rebuild.

Usage: python update.py [repo_root] [flutter_path]
"""

import json
import os
import subprocess
import sys
import time


def find_flutter(repo_root: str) -> str:
    """Resolve flutter path from settings.json or PATH."""
    settings_path = os.path.join(repo_root, "server", "config", "settings.json")
    if os.path.isfile(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            path = data.get("engines", {}).get("flutter_path", "")
            if path:
                if os.path.isfile(path):
                    return path
                for ext in (".bat", ".exe"):
                    if os.path.isfile(path + ext):
                        return path + ext
        except Exception:
            pass
    return "flutter"


def main():
    repo_root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    flutter = sys.argv[2] if len(sys.argv) > 2 else find_flutter(repo_root)
    app_dir = os.path.join(repo_root, "app")
    exe_path = os.path.join(app_dir, "build", "windows", "x64", "runner", "Release", "app_manager_mobile.exe")

    print("=" * 50)
    print("Auto Game Builder — Update")
    print("=" * 50)

    # Step 1: Wait for the app to close
    print("\n[1/4] Waiting for app to close...")
    for _ in range(30):
        try:
            # Check if exe is locked (Windows-specific)
            if os.path.isfile(exe_path):
                with open(exe_path, "a"):
                    pass
            break
        except (PermissionError, OSError):
            time.sleep(1)
    else:
        print("Warning: App may still be running. Proceeding anyway...")

    # Step 2: Git pull
    print("\n[2/4] Pulling latest code...")
    result = subprocess.run(
        ["git", "pull"],
        cwd=repo_root,
        capture_output=True,
        text=True,
    )
    print(result.stdout.strip())
    if result.returncode != 0:
        print(f"Error: {result.stderr.strip()}")
        input("\nPress Enter to close...")
        return

    # Step 3: Flutter build
    print(f"\n[3/4] Building Windows app (this may take a minute)...")
    print(f"  Flutter: {flutter}")
    result = subprocess.run(
        [flutter, "build", "windows", "--release"],
        cwd=app_dir,
        capture_output=False,
    )
    if result.returncode != 0:
        print("\nBuild failed!")
        input("\nPress Enter to close...")
        return

    # Step 4: Relaunch
    print(f"\n[4/4] Launching updated app...")
    if os.path.isfile(exe_path):
        subprocess.Popen([exe_path], cwd=os.path.dirname(exe_path))
        print("Done! You can close this window.")
    else:
        print(f"Warning: exe not found at {exe_path}")
        input("\nPress Enter to close...")


if __name__ == "__main__":
    main()
