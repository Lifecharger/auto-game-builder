"""Strip sea/background leftovers out of a keyed girl clip strip (plain source) in place.

Surf clips rendered over water key badly: green/teal sea, foam and dark background blocks stay
in the strip, so she surfs with her own little sea glued to her (Summer Surf Party trick clips,
2026-09-25). Per frame: pixels that are clearly GREEN-dominant (sea / chroma leftovers, not skin,
hair, bikini or the white/teal board) lose their alpha; then alpha islands smaller than
`--keep` of the biggest (the girl) are dropped, and so are wide flat islands along the bottom
(a wave band). The strip keeps its size, so the rig's padding is unchanged. Writes a
`<name>.before.webp` backup next to the file the first time.

    python strip_sea_leak.py <plain strip.webp> --frames 10 [--keep 0.04] [--preview out.jpg]
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def clean_frame(rgba: np.ndarray, keep: float) -> np.ndarray:
    r, g, b, a = [rgba[..., i].astype(np.int32) for i in range(4)]
    # clearly green (the sea), but NOT the bright teal board; plus the dark/mid COOL-toned
    # background the key left (teal or grey-green: green and blue at least as strong as red).
    # Her skin and hair are warm (red leads), the board and foam are bright, so they stay.
    bright = np.maximum(np.maximum(r, g), b)
    green = ((g > r + 30) & (g > b + 22)) | ((bright < 130) & (g >= r + 2) & (b >= r - 2))
    out = rgba.copy()
    out[..., 3] = np.where(green, 0, out[..., 3])
    solid = out[..., 3] > 24
    labels, n = ndimage.label(solid)
    if n == 0:
        return out
    sizes = ndimage.sum(solid, labels, index=range(1, n + 1))
    biggest = sizes.max()
    h, w = solid.shape
    drop = np.zeros(n + 1, dtype=bool)
    for i, (sl, size) in enumerate(zip(ndimage.find_objects(labels), sizes), start=1):
        if size < keep * biggest:
            drop[i] = True
            continue
        ys, xs = sl
        band = (xs.stop - xs.start) > 0.6 * w and (ys.stop - ys.start) < 0.3 * h and ys.start > 0.6 * h
        if band and size != biggest:
            drop[i] = True
    out[..., 3] = np.where(drop[labels] & (labels > 0), 0, out[..., 3])
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("strip")
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--keep", type=float, default=0.04)
    ap.add_argument("--preview")
    args = ap.parse_args()
    path = Path(args.strip)
    backup = path.with_name(path.stem + ".before.webp")
    if not backup.exists():
        shutil.copyfile(path, backup)
    src = np.array(Image.open(backup).convert("RGBA"))
    fw = src.shape[1] // args.frames
    out = src.copy()
    for i in range(args.frames):
        out[:, i * fw:(i + 1) * fw] = clean_frame(src[:, i * fw:(i + 1) * fw], args.keep)
    Image.fromarray(out).save(path, "WEBP", lossless=True)
    if args.preview:
        im = Image.fromarray(out)
        bg = Image.new("RGBA", im.size, (40, 40, 40, 255))
        bg.alpha_composite(im)
        bg.convert("RGB").save(args.preview, quality=85)
    print(f"cleaned {path.name}: {args.frames} frames")


if __name__ == "__main__":
    main()
