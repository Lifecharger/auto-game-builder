"""Batch-generate hollow garment shells for the wardrobe via Meshy text-to-3D.

Submits previews in waves of 5, polls them in parallel, downloads GLBs
straight into the Mixamo Downloader wardrobe folders, then regenerates the
viewer manifests. Preview mode only (untextured — garments get tinted/
textured downstream).

Usage: python batch_garments.py
"""

import subprocess
import sys
import time

from meshy_client import post, get, download_model

ENDPOINT = "/openapi/v2/text-to-3d"
WARDROBE = r"C:\Projects\Mixamo Downloader\wardrobe"
GEN_MANIFEST = r"C:\Projects\Mixamo Downloader\tools\gen_manifest.py"

SHELL = (
    "women's clothing, hollow garment shell only, shaped as if worn by an "
    "invisible slim adult woman, empty interior, no body, no mannequin, "
    "thin single-layer fabric, clean game-ready mesh"
)

ITEMS = [
    # --- etekler (bottoms) ---
    ("bottoms", "skirt_pleated_mini", "short pleated mini skirt"),
    ("bottoms", "skirt_pencil_mini", "tight pencil mini skirt"),
    ("bottoms", "skirt_ruffle_layers", "layered ruffled mini skirt with three tiers"),
    ("bottoms", "skirt_skater", "high waist flared skater skirt"),
    ("bottoms", "skirt_slit_midi", "fitted midi skirt with high side slit"),
    # --- gomlekler (tops) ---
    ("tops", "shirt_fitted_button", "fitted button-up shirt with open collar"),
    ("tops", "shirt_offshoulder", "off-shoulder loose blouse"),
    ("tops", "shirt_sleeveless", "sleeveless collared shirt"),
    ("tops", "shirt_knotted", "shirt with knotted front tied at the waist"),
    ("tops", "shirt_vneck_blouse", "silk blouse with deep v neckline"),
    # --- tisortler (tops) ---
    ("tops", "tshirt_fitted_crew", "fitted crew neck t-shirt"),
    ("tops", "tshirt_deep_vneck", "fitted deep v-neck t-shirt"),
    ("tops", "tshirt_cap_sleeve", "cap sleeve fitted t-shirt"),
    ("tops", "tshirt_oversized", "oversized loose t-shirt"),
    ("tops", "tshirt_scoop", "scoop neck fitted t-shirt"),
    # --- crop ustler (tops) ---
    ("tops", "crop_tube", "strapless tube crop top"),
    ("tops", "crop_tied_front", "tied front crop top with knot"),
    ("tops", "crop_halter", "halter neck crop top"),
    ("tops", "crop_offshoulder", "off-shoulder crop top"),
    ("tops", "crop_tank", "cropped tank top with thin straps"),
    # --- ic camasirlari (underwear) ---
    ("underwear", "bra_lace", "lace bra with thin straps"),
    ("underwear", "bra_sport", "sports bra"),
    ("underwear", "bralette", "delicate bralette with scalloped edges"),
    ("underwear", "panties_bikini", "bikini panties"),
    ("underwear", "briefs_highwaist", "high waist briefs"),
]

WAVE = 5
POLL_S = 12
TASK_TIMEOUT = 900


def submit(desc):
    payload = {
        "mode": "preview",
        "prompt": f"{desc}, {SHELL}",
        "art_style": "realistic",
        "ai_model": "latest",
        "topology": "triangle",
        "target_polycount": 4000,
        "symmetry_mode": "on",
    }
    return post(ENDPOINT, payload)["result"]


def main():
    done, failed = 0, 0
    for w in range(0, len(ITEMS), WAVE):
        wave = ITEMS[w:w + WAVE]
        tasks = {}
        for cat, slug, desc in wave:
            try:
                tid = submit(desc)
                tasks[tid] = (cat, slug)
                print(f"[SUBMIT] {slug} -> {tid}", flush=True)
            except Exception as e:
                print(f"[FAIL-SUBMIT] {slug}: {e}", flush=True)
                failed += 1
            time.sleep(1.5)
        deadline = time.time() + TASK_TIMEOUT
        pending = dict(tasks)
        while pending and time.time() < deadline:
            time.sleep(POLL_S)
            for tid in list(pending):
                cat, slug = pending[tid]
                try:
                    t = get(f"{ENDPOINT}/{tid}")
                except Exception as e:
                    print(f"[POLL-ERR] {slug}: {e}", flush=True)
                    continue
                st = t.get("status")
                if st == "SUCCEEDED":
                    url = (t.get("model_urls") or {}).get("glb")
                    if url:
                        out = rf"{WARDROBE}\{cat}\meshy_{slug}.glb"
                        download_model(url, out)
                        print(f"[OK] {slug} -> {out}", flush=True)
                        done += 1
                    else:
                        print(f"[FAIL] {slug}: glb url yok", flush=True)
                        failed += 1
                    del pending[tid]
                elif st in ("FAILED", "CANCELED"):
                    print(f"[FAIL] {slug}: {st} {t.get('task_error')}", flush=True)
                    failed += 1
                    del pending[tid]
        for tid, (cat, slug) in pending.items():
            print(f"[TIMEOUT] {slug} ({tid})", flush=True)
            failed += 1
    subprocess.run([sys.executable, GEN_MANIFEST], check=False)
    print(f"BITTI: {done} ok / {failed} hata / {len(ITEMS)} toplam", flush=True)


if __name__ == "__main__":
    main()
