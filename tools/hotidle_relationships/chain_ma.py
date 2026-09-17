"""Run the v2 matte (BiRefNet + MatAnyone) over every still and loop, in one
GPU process, after any LTX render in flight has finished (the two do not fit
in 16 GB together). Log: <masters>/chain_ma.log

    ..\\matting\\.venv\\Scripts\\python.exe chain_ma.py
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = r"C:/Reusable Assets/Images/Hot Idle/relationships/chain_ma.log"
PY = sys.executable


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


def renders_alive() -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command",
                          "(Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                          "Where-Object { $_.CommandLine -like '*gen_stills*' -or $_.CommandLine -like '*redo_level*' } | "
                          "Measure-Object).Count"], capture_output=True, text=True).stdout.strip()
    return out not in ("", "0")


def run(args: list[str]) -> None:
    log("run " + " ".join(args))
    with open(LOG, "a", encoding="utf-8") as f:
        subprocess.run([PY, os.path.join(HERE, "matte_ma.py"), *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT)


def main() -> None:
    while renders_alive():
        log("waiting for LTX render to finish")
        time.sleep(30)
    run(["--stills", "--force"])   # every L<k>.png and base.png -> *_cut.png (ma1)
    run(["--force"])               # every *_loop.mp4 -> *_loop_rgba.webm
    log("CHAIN_MA DONE")


if __name__ == "__main__":
    main()
