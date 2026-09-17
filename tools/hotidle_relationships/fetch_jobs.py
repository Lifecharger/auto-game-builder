"""Copy finished AGB generate jobs to their master paths (for jobs whose
submitting process died before the result landed).

    python fetch_jobs.py <job_id>=<dst.png> [<job_id>=<dst> ...]
"""
import json
import os
import shutil
import sys
import time
import urllib.request

KEY_FILE = r"D:/keys/agb_api_key.txt"


def key() -> str:
    try:
        return open(KEY_FILE, encoding="utf-8").read().strip()
    except OSError:
        return os.environ.get("AGB_API_KEY", "")


def get(jid: str) -> dict:
    req = urllib.request.Request(f"http://localhost:8000/api/generate/{jid}", headers={"X-API-Key": key()})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main() -> None:
    todo = dict(a.split("=", 1) for a in sys.argv[1:])
    t0 = time.time()
    while todo and time.time() - t0 < 4 * 3600:
        for jid, dst in list(todo.items()):
            try:
                j = get(jid)
            except Exception:
                continue
            st = j.get("status")
            if st == "done" and j.get("file") and os.path.isfile(j["file"]):
                shutil.copy(j["file"], dst)
                print(f"{jid} -> {dst}", flush=True)
                todo.pop(jid)
            elif st in ("error", "cancelled"):
                print(f"{jid}: {st} {j.get('error')}", flush=True)
                todo.pop(jid)
        time.sleep(15)
    print("BITTI", flush=True)


if __name__ == "__main__":
    main()
