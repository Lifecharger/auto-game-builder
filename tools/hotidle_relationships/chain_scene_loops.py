"""Per-frame portraits + living portraits: regenerate every painting at its
wall frame's aspect, then render an LTX-2.5 loop for each, but
only once the MatAnyone matte pass has left the GPU (LTX and MatAnyone do not
fit in 16 GB together). Uploads are done continuously by auto_upload.py.

    python chain_scene_loops.py          (detached; log <masters>/chain_scene_loops.log)
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = r"C:/Reusable Assets/Images/Hot Idle/relationships/chain_scene_loops.log"
PY = sys.executable


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


def matte_alive() -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
                          "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                          "Where-Object { $_.CommandLine -like '*matte_ma*' -or $_.CommandLine -like '*chain_ma*' -or $_.CommandLine -like '*fetch_jobs*' } | "
                          "Measure-Object).Count"], capture_output=True, text=True).stdout.strip()
    return out not in ("", "0")


def run(script: str, args: list[str]) -> None:
    log("run " + script + " " + " ".join(args))
    with open(LOG, "a", encoding="utf-8") as f:
        subprocess.run([PY, os.path.join(HERE, script), *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT)


def main() -> None:
    while matte_alive():
        log("waiting for the matte pass to free the GPU")
        time.sleep(60)
    run("gen_stills.py", ["--scenes", "--inflight", "3"])        # per-frame portraits (L1-10)
    run("gen_stills.py", ["--scene-loops", "--inflight", "2"])   # living portraits, same aspect
    log("CHAIN_SCENE_LOOPS DONE")


if __name__ == "__main__":
    main()
