"""Crop every portrait painting to its wall frame's EXACT aspect.

Qwen's edit workflow snaps its output to ~1 MP on a 16 px grid, so a canvas
made at the frame's ratio comes back a few percent off (880x1184 = 0.743
for frames that want 0.75-0.80; 1184x880 = 1.35 for a 1.26 frame). A
centre crop of at most a few percent on one axis fixes the ratio exactly,
with no regeneration. Originals are kept once in _redo/scenes_uncropped/.

    python crop_scenes.py            # all girls, all levels (skips exact ones)
    python crop_scenes.py ava 3      # one painting
"""
import importlib.util
import os
import shutil
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
TOL = 0.005   # 0.5 %

_spec = importlib.util.spec_from_file_location("gs", os.path.join(HERE, "gen_stills.py"))
gs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gs)


def crop_to_frame(path: str, level: int) -> str | None:
    im = Image.open(path)
    w, h = im.size
    want = gs.frame_aspect(level)
    have = w / h
    if abs(have / want - 1) <= TOL:
        return None
    if have > want:      # too wide: trim the sides
        nw = round(h * want)
        left = (w - nw) // 2
        box = (left, 0, left + nw, h)
    else:                # too tall: trim top and bottom, biased to keep the head
        nh = round(w / want)
        top = (h - nh) // 3
        box = (0, top, w, top + nh)
    keep = os.path.join(ROOT, "_redo", "scenes_uncropped")
    os.makedirs(keep, exist_ok=True)
    girl = os.path.basename(os.path.dirname(path))
    kept = os.path.join(keep, f"{girl}_{os.path.basename(path)}")
    if not os.path.isfile(kept):
        shutil.copy(path, kept)
    im.crop(box).save(path)
    return f"{w}x{h} -> {box[2] - box[0]}x{box[3] - box[1]}"


def main() -> None:
    girls = [sys.argv[1]] if len(sys.argv) > 1 else sorted(
        d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)) and not d.startswith("_"))
    levels = [int(sys.argv[2])] if len(sys.argv) > 2 else range(1, 11)
    n = 0
    for g in girls:
        for lv in levels:
            p = os.path.join(ROOT, g, f"L{lv}_scene.png")
            if os.path.isfile(p):
                r = crop_to_frame(p, lv)
                if r:
                    n += 1
                    print(f"  {g} L{lv}: {r}")
    print(f"cropped {n}")


if __name__ == "__main__":
    main()
