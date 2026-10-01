"""Re-key a glowing effect rendered on black by its brightness (the black background left a
dark smear the border-colour keyer kept). Alpha = how bright the pixel is; colour is un-darkened.

    python luma_key.py <event> <asset key> [--floor 28] [--gain 3.2]
"""
from __future__ import annotations

import argparse
import io
import json
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
from build_v2_pack import BUCKET, CACHE_IMG, CACHE_JSON, ROOT  # noqa: E402
from pack_lock import pack_lock  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("key")
    ap.add_argument("--floor", type=float, default=28)
    ap.add_argument("--gain", type=float, default=3.2)
    a = ap.parse_args()
    with pack_lock(a.event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{a.event}/pack.json"))
        base = pack["base"]
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        row = pack["assets"][a.key]
        im = np.asarray(Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"]))).convert("RGBA")).astype(np.float32)
        rgb = im[..., :3]
        peak = rgb.max(axis=2)
        alpha = np.clip((peak - a.floor) * a.gain, 0, 255)
        alpha = np.minimum(alpha, im[..., 3])
        # un-premultiply the black: brighten what stays so the glow keeps its colour
        scale = np.where(peak > 1, np.minimum(255.0 / np.maximum(peak, 1), 3.0), 1.0)[..., None]
        out = np.dstack([np.clip(rgb * np.where(alpha[..., None] < 250, scale, 1.0), 0, 255), alpha])
        name = f"{a.key}.r{rev}.webp"
        dst = ROOT / a.event / name
        Image.fromarray(out.astype(np.uint8), "RGBA").save(dst, "WEBP", quality=90, method=6)
        r2_s3._call("PUT", BUCKET, base + name, headers={"content-type": "image/webp", "cache-control": CACHE_IMG},
                    body=dst.read_bytes())
        row["file"] = base + name
        row["bytes"] = dst.stat().st_size
        pack["version"] += 1
        body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
        (ROOT / a.event / "pack.json").write_bytes(body)
        r2_s3._call("PUT", BUCKET, base + "pack.json",
                    headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
        print(f"{a.event} {a.key} -> {name}, pack v{pack['version']}")


if __name__ == "__main__":
    main()
