"""Redo one outfit level end to end after a review verdict on the STILL:
new Qwen still (prompt already changed in ladders.json) -> RVM cut ->
portrait -> LTX loop -> matte. Old masters go to _redo/ with a version tag.

    python redo_level.py <girl> <old_level_key>     e.g. redo_level.py iris 5
"""
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
PY = sys.executable
LOG = os.path.join(ROOT, "redo_level.log")


def run(args):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"\n=== {time.strftime('%H:%M:%S')} {' '.join(args)}\n"); f.flush()
        subprocess.run([PY, *args], cwd=HERE, stdout=f, stderr=subprocess.STDOUT)


def withdraw_approval(girl: str, old_key: str) -> None:
    """A new still voids its portrait and loop even if they were approved
    (user 2026-09-16): drop all three board items of that level from
    approved.json so they are re-uploaded and return to the board."""
    import json
    order_path = os.path.join(HERE, "order.json")
    ap_path = os.path.join(HERE, "approved.json")
    if not os.path.isfile(ap_path):
        return
    with open(order_path, encoding="utf-8") as f:
        keys = json.load(f)["order"][girl]
    n = keys.index(old_key) + 1
    with open(ap_path, encoding="utf-8") as f:
        ap = json.load(f)
    voided = {f"L{n}_still", f"L{n}_portrait", f"L{n}_loop"}
    ap[girl] = [i for i in ap.get(girl, []) if i not in voided]
    with open(ap_path + ".tmp", "w", encoding="utf-8") as f:
        json.dump(ap, f, indent=1, sort_keys=True)
    os.replace(ap_path + ".tmp", ap_path)


def mark_pending(girl: str, old_key: str) -> None:
    """Hide the level's three board items until their replacements land."""
    import json
    with open(os.path.join(HERE, "order.json"), encoding="utf-8") as f:
        n = json.load(f)["order"][girl].index(old_key) + 1
    path = os.path.join(HERE, "pending_redo.json")
    pend = json.load(open(path, encoding="utf-8")) if os.path.isfile(path) else {}
    now = int(time.time())
    pend.setdefault(girl, {}).update({f"L{n}_still": now, f"L{n}_portrait": now, f"L{n}_loop": now})
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pend, f, indent=1)


def main():
    girl, lv = sys.argv[1], sys.argv[2]
    withdraw_approval(girl, f"L{lv}")
    mark_pending(girl, f"L{lv}")
    d = os.path.join(ROOT, girl)
    os.makedirs(os.path.join(ROOT, "_redo"), exist_ok=True)
    stamp = time.strftime("%m%d%H%M")
    for name in (f"L{lv}.png", f"L{lv}_cut.png", f"L{lv}_scene.png", f"L{lv}_loop.mp4", f"L{lv}_loop_rgba.webm"):
        p = os.path.join(d, name)
        if os.path.isfile(p):
            shutil.move(p, os.path.join(ROOT, "_redo", f"{girl}_{name}.{stamp}"))
    run(["gen_stills.py", girl, "--levels", lv, "--inflight", "1"])
    run(["matte_loops.py", girl, "--levels", lv, "--stills", "--force"])
    run(["gen_stills.py", girl, "--levels", lv, "--scenes", "--inflight", "1"])
    run(["gen_stills.py", girl, "--levels", lv, "--loops", "--inflight", "1"])
    run(["matte_loops.py", girl, "--levels", lv, "--force"])
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"\n=== {time.strftime('%H:%M:%S')} REDO DONE {girl} L{lv}\n")


if __name__ == "__main__":
    main()
