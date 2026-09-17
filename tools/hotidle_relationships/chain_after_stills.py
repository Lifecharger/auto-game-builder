"""Overnight chain for the Relationships art (design/relationships.md 9).

Waits for a running stills pass (gen_stills.py without --scenes/--loops) to
exit, then runs, in order and each resume-safe:
  1. the policy/escalation redos (luna L6, sofia L10, lilith L10)
  2. the portrait pass   (--scenes, levels 1-10)
  3. the loop pass       (--loops,  levels 2-10, LTX-2.5)

Started detached (Start-Process python chain_after_stills.py) so it outlives
the session; replaces the two PowerShell launchers that silently died on
2026-09-15. Logs: gen_fix_l10.log / gen_scenes.log / gen_loops.log next to the
masters.
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
PY = sys.executable
GEN = os.path.join(HERE, "gen_stills.py")


def stills_pass_running() -> bool:
    out = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
         "Where-Object { $_.CommandLine -like '*gen_stills.py*' -and "
         "$_.CommandLine -notlike '*--scenes*' -and $_.CommandLine -notlike '*--loops*' } | "
         "Measure-Object | Select-Object -ExpandProperty Count"],
        capture_output=True, text=True)
    try:
        return int(out.stdout.strip() or "0") > 0
    except ValueError:
        return False


def run(args: list[str], log: str, append: bool = False) -> int:
    with open(os.path.join(ROOT, log), "a" if append else "w", encoding="utf-8") as f:
        return subprocess.run([PY, GEN, *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT).returncode


def main() -> None:
    """Steps come from argv (default: redo scenes loops). Every step is
    resume-safe, so after a crash or a server restart just relaunch with the
    steps still owed."""
    steps = sys.argv[1:] or ["redo", "scenes", "loops"]
    while stills_pass_running():
        time.sleep(60)
    if "redo" in steps:
        for g, lv in (("sofia", "10"), ("lilith", "10"), ("luna", "6")):
            try:
                os.remove(os.path.join(ROOT, g, f"L{lv}.png"))
            except OSError:
                pass
        run(["sofia", "lilith", "--levels", "10"], "gen_fix_l10.log")
        run(["luna", "--levels", "6"], "gen_fix_l10.log", append=True)
    if "scenes" in steps:
        run(["--scenes"], "gen_scenes.log", append=True)
    if "loops" in steps:
        run(["--loops"], "gen_loops.log", append=True)


if __name__ == "__main__":
    main()
