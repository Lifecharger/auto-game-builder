"""Undo a colour drift inside one girl rig clip (Grok video lighting sliding green or warm over the
take): every frame's green/red and blue/red balance over her opaque pixels is pulled back to the
reference frame's. Publishes the clip under a new revision in the live v2 pack.

    python tint_match.py <event> <anim> [--ref 0] [--direction south]
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


def balance(cell: np.ndarray) -> tuple[float, float]:
    m = cell[..., 3] > 200
    r, g, b = (cell[..., c][m].mean() + 1e-3 for c in range(3))
    return g / r, b / r


def match(im: Image.Image, frames: int, ref: int) -> tuple[Image.Image, list[float]]:
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    cw = a.shape[1] // frames
    g0, b0 = balance(a[:, ref * cw:(ref + 1) * cw])
    gains = []
    for k in range(frames):
        cell = a[:, k * cw:(k + 1) * cw]
        gk, bk = balance(cell)
        gg, gb = g0 / gk, b0 / bk
        cell[..., 1] = np.clip(cell[..., 1] * gg, 0, 255)
        cell[..., 2] = np.clip(cell[..., 2] * gb, 0, 255)
        gains.append(round(gg, 3))
    return Image.fromarray(a.astype(np.uint8), "RGBA"), gains


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("anim")
    ap.add_argument("--ref", type=int, default=0)
    ap.add_argument("--direction", default="south")
    args = ap.parse_args()
    with pack_lock(args.event):
        pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{args.event}/pack.json"))
        base = pack["base"]
        rev = max(int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))) + 1
        row = pack["girl"]["animations"][args.anim][args.direction]
        im = Image.open(io.BytesIO(r2_s3.get_object(BUCKET, row["file"])))
        out, gains = match(im, int(row["frames"]), args.ref)
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
        print(f"{args.event} {args.anim}: green gains {gains} -> {name}, pack v{pack['version']}")


if __name__ == "__main__":
    main()
