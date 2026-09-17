"""Cut the white studio background off the Relationships stills (user 2026-09-15:
"stills still have white background they shouldn't have").

L<n>.png (white background, the animation base) -> L<n>_cut.png (RGBA, same
canvas size, no crop, so a level still keeps the framing the roster and the
outfit tiles expect). upload_relationships.py prefers the _cut file for the
`stills` kind. isnet via onnxruntime directly, same recipe as
tools/media/isnet_cutout.py (rembg's import hangs on this machine).

    python cutout_stills.py            # every girl, levels 2-10, skips existing
    python cutout_stills.py ava luna
    python cutout_stills.py --force    # redo
"""
from __future__ import annotations

import argparse
import json
import os

import numpy as np
import onnxruntime as ort
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"C:/Reusable Assets/Images/Hot Idle/relationships"
MODEL = os.path.expanduser("~/.u2net/isnet-general-use.onnx")


def girls() -> list[str]:
    with open(os.path.join(HERE, "ladders.json"), encoding="utf-8") as f:
        return list(json.load(f)["girls"])


def cutout(sess: ort.InferenceSession, src: str, dst: str) -> float:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    x = np.asarray(im.resize((1024, 1024), Image.BILINEAR)).astype(np.float32) / 255.0
    x = ((x - 0.5) / 1.0).transpose(2, 0, 1)[None]
    out = sess.run(None, {sess.get_inputs()[0].name: x})[0][0][0]
    out = (out - out.min()) / (out.max() - out.min() + 1e-8)
    a = np.asarray(Image.fromarray((out * 255).astype(np.uint8))
                   .resize((w, h), Image.BILINEAR)).astype(np.float32)
    # White studio background: firm up the matte so hair gaps and the space
    # between the legs go fully clear.
    a = np.clip((a - 40) * (255.0 / (255 - 40)), 0, 255)
    rgb = np.asarray(im).astype(np.float32)
    # Un-premultiply against white so light edges keep no white halo.
    af = (a / 255.0)[..., None]
    clean = np.clip((rgb - 255.0 * (1 - af)) / np.maximum(af, 1e-3), 0, 255)
    rgb_out = np.where(af > 0.02, clean, rgb)
    Image.fromarray(np.dstack([rgb_out, a]).astype(np.uint8), "RGBA").save(dst, optimize=True)
    return float((a > 128).mean())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("girls", nargs="*")
    ap.add_argument("--levels", default="2,3,4,5,6,7,8,9,10")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--base", action="store_true",
                    help="cut the ORIGINAL reference (cashiers_side/refs) to base_cut.png")
    a = ap.parse_args()
    names = a.girls or girls()
    levels = [int(x) for x in a.levels.split(",") if x.strip()]
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    done = skipped = missing = 0
    if a.base:
        refs = r"C:/Reusable Assets/Images/Hot Idle/cashiers_side/refs"
        for g in names:
            dst = os.path.join(SRC, g, "base_cut.png")
            if os.path.isfile(dst) and not a.force:
                skipped += 1
                continue
            # Prefer the sharp Qwen re-render (base.png); the 540x960 reference
            # only when it does not exist yet.
            src = os.path.join(SRC, g, "base.png")
            if not os.path.isfile(src):
                src = os.path.join(refs, f"{g}_ref.jpg")
            cov = cutout(sess, src, dst)
            done += 1
            print(f"  {g} base: cut, figure {cov * 100:.0f}% of frame", flush=True)
        print(f"BITTI: {done} cut, {skipped} skipped", flush=True)
        return
    for g in names:
        for n in levels:
            src = os.path.join(SRC, g, f"L{n}.png")
            dst = os.path.join(SRC, g, f"L{n}_cut.png")
            if not os.path.isfile(src):
                missing += 1
                continue
            if os.path.isfile(dst) and not a.force and os.path.getmtime(dst) >= os.path.getmtime(src):
                skipped += 1
                continue
            cov = cutout(sess, src, dst)
            done += 1
            print(f"  {g} L{n}: cut, figure {cov * 100:.0f}% of frame", flush=True)
    print(f"BITTI: {done} cut, {skipped} skipped, {missing} missing", flush=True)


if __name__ == "__main__":
    main()
