"""Background chain after the 2026-09-15 re-ranking, all resume-safe:

  1. gen_stills.py --base-stills      sharp Qwen re-render of every original outfit -> base.png
  2. matte_loops.py --stills          RVM cut of every still incl. base.png -> *_cut.png
  3. gen_stills.py --base-loops       LTX loop of every original outfit from base.png -> base_loop.mp4
  4. matte_loops.py                   RVM matte of every loop incl. base -> *_loop_rgba.webm
  5. (loop) step 4 again every 10 min while the LTX loop pass is still producing clips

Started detached (Start-Process python chain_matte.py). Logs next to the masters:
chain_matte.log.
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
PY = sys.executable
LOG = os.path.join(ROOT, "chain_matte.log")


def run(args: list[str]) -> int:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"\n=== {time.strftime('%H:%M:%S')} {' '.join(args)}\n")
        f.flush()
        return subprocess.run([PY, *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT).returncode


def loops_pass_running() -> bool:
    out = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
         "Where-Object { $_.CommandLine -like '*gen_stills.py*--loops*' -and $_.CommandLine -notlike '*base*' } | "
         "Measure-Object | Select-Object -ExpandProperty Count"],
        capture_output=True, text=True)
    try:
        return int(out.stdout.strip() or "0") > 0
    except ValueError:
        return False


def main() -> None:
    run(["gen_stills.py", "--base-stills"])
    run(["matte_loops.py", "--stills"])
    run(["gen_stills.py", "--base-loops"])
    run(["matte_loops.py"])
    # The LTX loop pass (levels 2-10) may still be producing clips: keep
    # matting what lands until it is done, then one final pass.
    while loops_pass_running():
        time.sleep(600)
        run(["matte_loops.py"])
    run(["matte_loops.py"])
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"\n=== {time.strftime('%H:%M:%S')} CHAIN DONE\n")


if __name__ == "__main__":
    main()
