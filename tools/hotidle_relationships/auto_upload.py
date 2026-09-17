"""Upload every relationship asset to R2 as soon as it exists (user
2026-09-16: "i approve all. i want to see in game. upload as it is made").

Every 3 minutes: encode + upload whatever changed among stills, portraits,
outfit loops and living portraits (upload_relationships.py keeps a hash
state, so only new or changed files go up). Mutable cache header while the
set is still being produced; the final immutable pass is a one-liner later.

    python auto_upload.py         (detached; log <masters>/auto_upload.log)
"""
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = r"C:/Reusable Assets/Images/Hot Idle/relationships/auto_upload.log"
KINDS = ["stills", "portraits", "loops", "sceneloops"]
EVERY = 180


def main() -> None:
    while True:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(f"\n=== {time.strftime('%H:%M:%S')} pass\n")
            f.flush()
            subprocess.run([sys.executable, os.path.join(HERE, "upload_relationships.py"), *KINDS],
                           cwd=HERE, stdout=f, stderr=subprocess.STDOUT)
        time.sleep(EVERY)


if __name__ == "__main__":
    main()
