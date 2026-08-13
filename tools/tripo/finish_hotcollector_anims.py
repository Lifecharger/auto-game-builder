"""Hot Collector: make sure every Tripo woman has idle/walk/sit retargets,
downloading each animation GLB to raw_assets/tripo_women/<name>_anim_<anim>.glb.

Retarget rule discovered 2026-08-11: ONE retarget per project at a time
(server answers 406 while one is running) and multi-animation arrays only
queue the first entry — so submit single animations sequentially per project.
"""
import json
import time

import requests

from tripo_studio_api import TripoStudio

GEN = "C:/Projects/Hot Collector/raw_assets/tripo_women/gen_results.json"
OUT = "C:/Projects/Hot Collector/raw_assets/tripo_women/"
WOMEN = ["elf", "teacher", "housewife", "leafgirl"]
ANIMS = ["idle", "walk", "sit"]


def entries(c, pid):
    det = c.project_detail(pid)
    return det.get("operator", {}).get("retarget", [])


def main():
    c = TripoStudio()
    gen = json.load(open(GEN, encoding="utf-8"))
    for name in WOMEN:
        pid = gen[name]["project_id"]
        for anim in ANIMS:
            # already done?
            done = {e.get("name", "").split(":")[-1]: e for e in entries(c, pid)
                    if e.get("status") == "success"}
            if anim not in done:
                # submit (retry while another retarget is running -> 406)
                while True:
                    try:
                        r = c.retarget_model(pid, [f"preset:biped:{anim}"])
                        print(f"{name} {anim} submitted -> {r.get('operator_id')}", flush=True)
                        break
                    except requests.HTTPError as e:
                        if e.response is not None and e.response.status_code == 406:
                            time.sleep(10)
                            continue
                        raise
                # wait for it to appear as success
                deadline = time.time() + 600
                while time.time() < deadline:
                    done = {e.get("name", "").split(":")[-1]: e for e in entries(c, pid)
                            if e.get("status") == "success"}
                    if anim in done:
                        break
                    time.sleep(8)
                if anim not in done:
                    print(f"[FAIL] {name} {anim}: timed out", flush=True)
                    continue
            url = done[anim].get("model_url", "")
            if url:
                resp = requests.get(url, timeout=600)
                resp.raise_for_status()
                open(OUT + f"{name}_anim_{anim}.glb", "wb").write(resp.content)
                print(f"{name} {anim} downloaded {len(resp.content)//1024} KB", flush=True)
    print("ALL ANIMS READY", flush=True)


if __name__ == "__main__":
    main()
