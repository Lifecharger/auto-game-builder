"""Peel the dark fringe a black-background render leaves around an fx sprite (wave spray, wings):
near-black pixels touching transparency are cleared, a few passes deep, so the dark INTERIOR
(deep water, outlines) stays. Publishes the asset under a new revision in the live v2 pack.

    python fringe_peel.py <event> <asset key> [--dark 60] [--passes 4]
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


def peel(im: np.ndarray, dark: float, passes: int) -> tuple[np.ndarray, int]:
    out = im.copy()
    cleared = 0
    for _ in range(passes):
        clear = (out[..., 3] < 20).astype(np.uint8)
        edge = cv2.dilate(clear, np.ones((3, 3), np.uint8)) > 0
        m = (out[..., :3].max(axis=2) < dark) & edge & (out[..., 3] > 0)
        cleared += int(m.sum())
        out[m, 3] = 0
    return out, cleared


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("key")
    ap.add_argument("--dark", type=float, default=60)
    ap.add_argument("--passes", type=int, default=4)
    a = ap.parse_args()
    with pack_lock(a.event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{a.event}/pack.json"))
        base = pack["base"]
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        row = pack["assets"][a.key]
        im = np.asarray(Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"]))).convert("RGBA")).copy()
        out, cleared = peel(im, a.dark, a.passes)
        name = f"{a.key}.r{rev}.webp"
        dst = ROOT / a.event / name
        Image.fromarray(out, "RGBA").save(dst, "WEBP", quality=90, method=6)
        r2_s3._call("PUT", BUCKET, base + name, headers={"content-type": "image/webp", "cache-control": CACHE_IMG},
                    body=dst.read_bytes())
        row["file"] = base + name
        row["bytes"] = dst.stat().st_size
        pack["version"] += 1
        body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
        (ROOT / a.event / "pack.json").write_bytes(body)
        r2_s3._call("PUT", BUCKET, base + "pack.json",
                    headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
        print(f"{a.event} {a.key}: peeled {cleared} px -> {name}, pack v{pack['version']}")


if __name__ == "__main__":
    main()
