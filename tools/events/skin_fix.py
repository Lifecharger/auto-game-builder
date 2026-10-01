"""Cap green on warm skin pixels below a line in one girl clip (a Grok take whose legs slide
yellow-green as the lighting drifts): green -> ratio x red, blue kept at most 0.62 x red. Hair, outfit
and gear are left alone (they are not warm-skin coloured). Publishes a new revision and rewrites the
plain source strip so the next repack keeps the fix.

    python skin_fix.py <event> <anim> [--below 0.45] [--ratio 0.74] [--rmin 90] [--rg 0.95]
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


def fix(a: np.ndarray, below: float, ratio: float, rmin: float, rg: float = 0.95) -> int:
    sub = a[int(a.shape[0] * below):]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    skin = (sub[..., 3] > 0) & (r > rmin) & (g > ratio * r) & (b < 0.8 * g) & (r >= g * rg)
    sub[..., 1] = np.where(skin, ratio * r, g)
    sub[..., 2] = np.where(skin, np.minimum(b, 0.62 * r), b)
    return int(skin.sum())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("anim")
    ap.add_argument("--below", type=float, default=0.45)
    ap.add_argument("--ratio", type=float, default=0.74)
    ap.add_argument("--rmin", type=float, default=90)
    ap.add_argument("--rg", type=float, default=0.95, help="red must be at least rg x green (lower = catch greener skin)")
    ap.add_argument("--direction", default="south")
    args = ap.parse_args()
    with pack_lock(args.event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{args.event}/pack.json"))
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        row = pack["girl"]["animations"][args.anim][args.direction]
        a = np.asarray(Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"]))).convert("RGBA")).astype(np.float32)
        n = fix(a, args.below, args.ratio, args.rmin, args.rg)
        out = Image.fromarray(a.astype(np.uint8), "RGBA")
        name = re.sub(r"\.r\d+\.webp$", f".r{rev}.webp", row["file"].split("/")[-1])
        dst = ROOT / args.event / "girl" / name
        out.save(dst, "WEBP", quality=88, method=6)
        # the plain strip too: the next repack re-pads every clip from it
        out.save(dst.parent / re.sub(r"\.r\d+\.webp$", ".webp", name), "WEBP", quality=88, method=6)
        key = pack["girl"]["base"] + name
        r2_s3._call("PUT", BUCKET, key, headers={"content-type": "image/webp", "cache-control": CACHE_IMG},
                    body=dst.read_bytes())
        row["file"] = key
        row["bytes"] = dst.stat().st_size
        pack["version"] += 1
        body = json.dumps(pack, ensure_ascii=False, indent=1).encode()
        (ROOT / args.event / "pack.json").write_bytes(body)
        r2_s3._call("PUT", BUCKET, pack["base"] + "pack.json",
                    headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
        print(f"{args.event} {args.anim}: {n} skin px -> {name}, pack v{pack['version']}")


if __name__ == "__main__":
    main()
