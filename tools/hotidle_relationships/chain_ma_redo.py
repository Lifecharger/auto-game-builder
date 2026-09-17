"""Loop redos that need the GPU twice (LTX re-render, then the MatAnyone
matte), run in the gap between the matte pass and the living-portrait chain.

The name contains "chain_ma" on purpose: chain_scene_loops.py keeps waiting
while anything matching *chain_ma* is alive, so LTX and MatAnyone never share
the card. Queue: redo_queue.json = [{"girl", "key", "level", "motion"}].

    python chain_ma_redo.py          (detached; log <masters>/chain_ma_redo.log)
"""
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
LOG = os.path.join(ROOT, "chain_ma_redo.log")
QUEUE = os.path.join(HERE, "redo_queue.json")
MATTE_PY = os.path.join(HERE, "..", "matting", ".venv", "Scripts", "python.exe")


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


def alive(pattern: str) -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
                          "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                          f"Where-Object {{ $_.CommandLine -like '*{pattern}*' }} | Measure-Object).Count"],
                         capture_output=True, text=True).stdout.strip()
    return out not in ("", "0")


def run(py: str, script: str, args: list[str]) -> None:
    log("run " + script + " " + " ".join(args))
    with open(LOG, "a", encoding="utf-8") as f:
        subprocess.run([py, os.path.join(HERE, script), *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT)


def main() -> None:
    while alive("chain_ma.py") or alive("matte_ma.py"):
        log("waiting for the matte pass")
        time.sleep(30)
    while True:
        queue = json.load(open(QUEUE, encoding="utf-8")) if os.path.isfile(QUEUE) else []
        if not queue:
            break
        job = queue[0]
        k = job["key"][1:] if job["key"].startswith("L") else job["key"]
        if job["key"] == "base":
            run(sys.executable, "gen_stills.py", [job["girl"], "--base-loops", "--inflight", "1", "--motion", job["motion"]])
            run(MATTE_PY, "matte_ma.py", [job["girl"], "--base", "--force"])
        else:
            run(sys.executable, "gen_stills.py", [job["girl"], "--levels", k, "--loops", "--inflight", "1", "--motion", job["motion"]])
            run(MATTE_PY, "matte_ma.py", [job["girl"], "--levels", k, "--force"])
        queue = json.load(open(QUEUE, encoding="utf-8"))
        queue = [q for q in queue if not (q["girl"] == job["girl"] and q["key"] == job["key"])]
        json.dump(queue, open(QUEUE, "w", encoding="utf-8"), indent=1)
        log(f"REDO DONE {job['girl']} {job['key']}")
    log("CHAIN_MA_REDO DONE")


if __name__ == "__main__":
    main()
