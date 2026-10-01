"""Clean green spill out of one girl rig clip in a live v2 pack, under a new revision.

    python recolor_girl_spill.py <event> <anim> [--straw-below 0.55] [--direction south]

Green-dominant pixels ABOVE the line (hair, outfit edges) are despilled: green is pulled down
to the larger of red and blue. Green-dominant pixels BELOW the line (a straw broom head the
keyer half-ate) are repainted straw, keeping their brightness. The line is a fraction of the
cell height. Then, per frame, alpha islands smaller than 1.5 % of the biggest one (specks the
key left around the feet) are dropped. The rig cell and every other clip stay as they are.
"""
from __future__ import annotations

import argparse
import io
import json
import re
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
from build_v2_pack import BUCKET, CACHE_IMG, CACHE_JSON, ROOT  # noqa: E402
from pack_lock import pack_lock  # noqa: E402

STRAW = np.array([214, 178, 104], dtype=np.float32)


def clean(im: Image.Image, straw_below: float) -> tuple[Image.Image, int, int]:
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    green = (g > r + 25) & (g > b + 25) & (al > 0)
    rows = np.arange(a.shape[0])[:, None] >= straw_below * a.shape[0]
    straw = green & rows
    spill = green & ~rows
    lum = (0.3 * r + 0.59 * g + 0.11 * b) / 170.0
    for c in range(3):
        a[..., c] = np.where(straw, np.clip(STRAW[c] * lum, 0, 255), a[..., c])
    a[..., 1] = np.where(spill, np.maximum(r, b), a[..., 1])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA"), int(straw.sum()), int(spill.sum())


def drop_specks(im: Image.Image, frames: int, keep: float = 0.015) -> tuple[Image.Image, int]:
    a = np.asarray(im).copy()
    cw = a.shape[1] // frames
    dropped = 0
    for k in range(frames):
        cell = a[:, k * cw:(k + 1) * cw]
        mask = (cell[..., 3] > 8).astype(np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
        if n <= 2:
            continue
        areas = stats[1:, cv2.CC_STAT_AREA]
        small = [i + 1 for i, ar in enumerate(areas) if ar < keep * areas.max()]
        for i in small:
            cell[lab == i, 3] = 0
            dropped += int(stats[i, cv2.CC_STAT_AREA])
    return Image.fromarray(a, "RGBA"), dropped


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("anim")
    ap.add_argument("--direction", default="south")
    ap.add_argument("--straw-below", type=float, default=0.55)
    args = ap.parse_args()
    with pack_lock(args.event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{args.event}/pack.json"))
        base = pack["base"]
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        row = pack["girl"]["animations"][args.anim][args.direction]
        im = Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"])))
        out, n_straw, n_spill = clean(im, args.straw_below)
        out, n_speck = drop_specks(out, int(row["frames"]))
        name = re.sub(r"\.r\d+\.webp$", f".r{rev}.webp", row["file"].split("/")[-1])
        key = f"{pack['girl']['base']}{name}"
        dst = ROOT / args.event / "girl" / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        out.save(dst, "WEBP", quality=88, method=6)
        # the plain strip too: the next repack re-pads every clip from it
        out.save(dst.parent / re.sub(r"\.r\d+\.webp$", ".webp", name), "WEBP", quality=88, method=6)
        r2_s3._call("PUT", BUCKET, key, headers={"content-type": "image/webp", "cache-control": CACHE_IMG},
                    body=dst.read_bytes())
        row["file"] = key
        row["bytes"] = dst.stat().st_size
        pack["version"] += 1
        body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
        (ROOT / args.event / "pack.json").write_bytes(body)
        r2_s3._call("PUT", BUCKET, base + "pack.json",
                    headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
        print(f"{args.event} {args.anim}: straw {n_straw} px, despill {n_spill} px, specks {n_speck} px -> {name}, pack v{pack['version']}")


if __name__ == "__main__":
    main()
