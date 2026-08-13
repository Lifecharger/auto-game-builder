"""Teacher v2: rig + retarget idle/walk/sit + download rigged & anims GLBs.
(Generation already done — project id in gen_results.json under teacher_v2.)"""
import json
import time

import requests

from tripo_studio_api import TripoStudio

GEN = "C:/Projects/Hot Collector/raw_assets/tripo_women/gen_results.json"
OUT = "C:/Projects/Hot Collector/raw_assets/tripo_women/"


def main():
    c = TripoStudio()
    gen = json.load(open(GEN, encoding="utf-8"))
    pid = gen["teacher_v2"]["project_id"]

    print("pre_rig_check:", c.pre_rig_check(pid), flush=True)
    rig = c.rig_model(pid)
    print("rig:", rig, flush=True)
    rig_op = rig["operator_id"]
    while True:
        p = c.progress([rig_op])[0]
        if p.get("status") == "success":
            break
        if p.get("status") in ("failed", "error", "cancelled"):
            raise SystemExit(f"rig failed: {p}")
        time.sleep(6)
    det = c.project_detail(pid)
    url = det["operator"]["model_url"]
    r = requests.get(url, timeout=600)
    r.raise_for_status()
    open(OUT + "teacher2_rigged.glb", "wb").write(r.content)
    print("rigged:", len(r.content) // 1024, "KB", flush=True)

    for anim in ["idle", "walk", "sit"]:
        while True:
            try:
                sub = c.retarget_model(pid, [f"preset:biped:{anim}"])
                print(anim, "submitted:", sub.get("operator_id"), flush=True)
                break
            except requests.HTTPError as e:
                if e.response is not None and e.response.status_code == 406:
                    time.sleep(10)
                    continue
                raise
        deadline = time.time() + 600
        while time.time() < deadline:
            det = c.project_detail(pid)
            done = {e2.get("name", "").split(":")[-1]: e2
                    for e2 in det.get("operator", {}).get("retarget", [])
                    if e2.get("status") == "success"}
            if anim in done:
                break
            time.sleep(8)
        print(anim, "done", flush=True)

    det = c.project_detail(pid)
    for e2 in det["operator"]["retarget"]:
        if e2.get("name") == "preset:biped:idle" and e2.get("model_url"):
            r = requests.get(e2["model_url"], timeout=600)
            r.raise_for_status()
            open(OUT + "teacher2_anims.glb", "wb").write(r.content)
            print("anims glb:", len(r.content) // 1024, "KB", flush=True)
    print("TEACHER2 API DONE", flush=True)


if __name__ == "__main__":
    main()
