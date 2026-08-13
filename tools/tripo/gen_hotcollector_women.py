"""Hot Collector: generate the 4 Collector women via Tripo Studio (web
subscription credits), serially, and download the finished GLBs.

Women (user spec 2026-08-11): elf / teacher / housewife / leaf-girl.
All outfits SATURATED MAGENTA — the game's tone_tint.gdshader chroma-keys
magenta texels to any tone color, so one texture serves all 20+ colorations.

Usage: python gen_hotcollector_women.py [--out DIR]
Writes <out>/<name>.glb + gen_results.json with project/operator ids.
"""
import argparse
import json
import time
from pathlib import Path

import requests

from tripo_studio_api import TripoStudio

WOMEN = {
    "elf": (
        "beautiful adult elven woman, long silver white hair, pointed elf ears, "
        "fitted magenta fantasy mini dress with small gold trim, bare long legs, "
        "magenta high heels, attractive curvy figure, standing full body, "
        "stylized game character"
    ),
    "teacher": (
        "beautiful adult woman teacher, glasses, dark brown hair in a neat bun, "
        "fitted magenta blouse with cleavage and tight magenta pencil mini skirt, "
        "bare long legs, magenta high heels, attractive curvy figure, "
        "standing full body, stylized game character"
    ),
    "housewife": (
        "beautiful adult housewife woman, wavy blonde hair, fitted magenta short "
        "dress with a small magenta apron, bare long legs, magenta high heels, "
        "attractive curvy figure, standing full body, stylized game character"
    ),
    "leafgirl": (
        "beautiful adult jungle woman, long dark hair with a small flower, "
        "outfit made of magenta leaves, magenta leaf top and magenta leaf mini "
        "skirt, bare long legs, barefoot, attractive curvy figure, "
        "standing full body, stylized game character"
    ),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="C:/Projects/Hot Collector/raw_assets/tripo_women")
    args = ap.parse_args()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    client = TripoStudio()
    results = {}
    for name, prompt in WOMEN.items():
        print(f"\n=== {name} ===", flush=True)
        sub = client.text_to_model(
            prompt=prompt,
            geometry_quality="detailed",
            texture=True,
            texture_quality="standard",
            generate_parts=False,
            smart_poly=False,
            quad=False,
            face_limit=15000,
            t_pose=True,
        )
        print(f"submitted project={sub.get('project_id')} operator={sub.get('operator_id')}", flush=True)
        final = client.wait_for(sub["operator_id"], timeout=1500)
        status = final.get("status")
        results[name] = {"project_id": sub.get("project_id"),
                         "operator_id": sub.get("operator_id"),
                         "status": status}
        if status != "success":
            print(f"[FAIL] {name}: {status}", flush=True)
            continue
        detail = client.project_detail(sub["project_id"])
        url = detail.get("model_url") or ""
        results[name]["model_url"] = url
        if url:
            ext = url.split("?")[0].split(".")[-1]
            dest = out_dir / f"{name}.{ext}"
            r = requests.get(url, timeout=600)
            r.raise_for_status()
            dest.write_bytes(r.content)
            print(f"[OK] {name} -> {dest} ({dest.stat().st_size // 1024} KB)", flush=True)
        else:
            print(f"[WARN] {name}: no model_url in detail; keys={list(detail.keys())}", flush=True)
        (out_dir / "gen_results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
        time.sleep(2)

    (out_dir / "gen_results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("\nALL DONE", flush=True)
    print(json.dumps(results, indent=2), flush=True)


if __name__ == "__main__":
    main()
