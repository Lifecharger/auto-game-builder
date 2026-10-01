"""Trim an fx strip in a live v2 pack to its figure: per frame, alpha islands smaller than 2 %
of the biggest are dropped (keying leftovers at the frame edges made the cell far wider than
the figure, so she drew tiny); then every frame is cropped to the union box of what is left,
padded, and the strip is re-saved under a new revision with its field-unit size updated.

    python trim_strip.py <event> <asset key> [...]
"""
from __future__ import annotations

import io
import json
import re
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
from build_v2_pack import ART_SCALE, BUCKET, CACHE_IMG, CACHE_JSON, ROOT  # noqa: E402
from pack_lock import pack_lock  # noqa: E402


def clean_cell(cell: np.ndarray) -> np.ndarray:
    mask = (cell[..., 3] > 24).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if n > 2:
        areas = stats[1:, cv2.CC_STAT_AREA]
        for i, ar in enumerate(areas):
            if ar < 0.02 * areas.max():
                cell[lab == i + 1, 3] = 0
    cell[cell[..., 3] <= 24, 3] = 0
    return cell


def main() -> None:
    event, keys = sys.argv[1], sys.argv[2:]
    with pack_lock(event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{event}/pack.json"))
        base = pack["base"]
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        for key in keys:
            row = pack["assets"][key]
            frames = int(row.get("frames") or 1)
            a = np.asarray(Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"]))).convert("RGBA")).copy()
            cw = a.shape[1] // frames
            cells = [clean_cell(a[:, k * cw:(k + 1) * cw].copy()) for k in range(frames)]
            ys, xs = [], []
            for c in cells:
                yy, xx = np.nonzero(c[..., 3])
                if len(yy):
                    ys += [yy.min(), yy.max()]
                    xs += [xx.min(), xx.max()]
            if not ys:
                print(key, "empty, skipped")
                continue
            pad = 4
            y0, y1 = max(0, min(ys) - pad), min(a.shape[0], max(ys) + pad + 1)
            x0, x1 = max(0, min(xs) - pad), min(cw, max(xs) + pad + 1)
            strip = np.concatenate([c[y0:y1, x0:x1] for c in cells], axis=1)
            name = f"{key}.r{rev}.webp"
            dst = ROOT / event / name
            Image.fromarray(strip, "RGBA").save(dst, "WEBP", quality=88, method=6)
            r2_s3._call("PUT", BUCKET, base + name, headers={"content-type": "image/webp", "cache-control": CACHE_IMG},
                        body=dst.read_bytes())
            # keep the drawn HEIGHT, the width follows the new aspect
            h_units = row.get("h") or (y1 - y0) / ART_SCALE
            fw, fh = int(x1 - x0), int(y1 - y0)
            row["file"] = base + name
            row["bytes"] = dst.stat().st_size
            row["w"] = round(h_units * fw / fh, 2)
            row["h"] = float(h_units)
            row["px"] = {"w": fw, "h": fh}
            print(f"{event} {key}: cell {cw}x{a.shape[0]} -> {fw}x{fh}")
        pack["version"] += 1
        body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
        (ROOT / event / "pack.json").write_bytes(body)
        r2_s3._call("PUT", BUCKET, base + "pack.json",
                    headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
        print("pack v", pack["version"])


if __name__ == "__main__":
    main()
