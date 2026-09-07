r"""Wan Animate 2 klibi -> seffaf sprite kareleri (isnet) -> WebP + sheet.

ARTIK YEDEK YOLDUR: birincil kesici `sam_frames.py` (SAM 3.1). Bu script
ComfyUI'siz calisir (yalniz onnxruntime), o yuzden SAM erisilemedigi ya da
hizli bir on izleme istendigi durumlar icin duruyor.

    python sprite_cikart.py --video wan.mp4 --out_dir <klip klasoru> [--fps 15]
           [--height 512] [--mirror] [--model <isnet.onnx>] [--bg 200,200,200]

Tuval KIRPILMAZ: tum klipler ayni tuvali paylasir, pivot kaymaz.
Cikti sam_frames ile ayni: frames/*.png, anim.webp, sheet.png, sprite.json.
"""
from __future__ import annotations

import argparse
import glob
import json
import shutil
import time
from pathlib import Path

import numpy as np

try:
    from . import common as C
    from . import sam_frames as SF
except ImportError:
    import common as C
    import sam_frames as SF


def extract(video, out_dir, fps: int = 15, height: int = 0, mirror: bool = False,
            bg: tuple | None = None, log=print) -> dict:
    from PIL import Image
    video, out_dir = Path(video), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = out_dir / "_raw"
    shutil.rmtree(raw, ignore_errors=True)
    raw.mkdir()
    C.ffmpeg(["-i", str(video), "-vf", "fps=%d" % fps, str(raw / "f_%04d.png")])
    files = [Path(p) for p in sorted(glob.glob(str(raw / "f_*.png")))]
    if not files:
        raise RuntimeError("videodan kare cikmadi: %s" % video)
    if SF.isnet_session() is None:
        raise RuntimeError("isnet modeli yok: %s" % C.ISNET)
    fdir = out_dir / "frames"
    shutil.rmtree(fdir, ignore_errors=True)
    fdir.mkdir(parents=True)
    first = Image.open(files[0]).convert("RGB")
    if bg is None:
        bg = tuple(int(v) for v in np.asarray(first)[2:12, 2:12].reshape(-1, 3).mean(0))
    frames, alphas = [], []
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB")
        rgba = SF.cut(im, SF.isnet_matte(im), bg)
        if mirror:
            rgba = rgba.transpose(Image.FLIP_LEFT_RIGHT)
        if height and rgba.height != height:
            rgba = rgba.resize((int(rgba.width * height / rgba.height), height), Image.LANCZOS)
        rgba.save(str(fdir / ("%04d.png" % i)))
        frames.append(rgba)
        alphas.append(np.asarray(rgba)[..., 3])
        log("kare %d/%d" % (i + 1, len(files)))
    A = np.stack(alphas)
    ys, xs = np.where(A.max(0) > 8)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    w, h = frames[0].size
    frames[0].save(str(out_dir / "anim.webp"), save_all=True, append_images=frames[1:],
                   duration=int(1000 / fps), loop=0, quality=88, method=4)
    sheet = Image.new("RGBA", (w * len(frames), h))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * w, 0))
    sheet.save(str(out_dir / "sheet.png"), optimize=True)
    info = {"frames": len(frames), "fps": fps, "w": w, "h": h, "bbox": bbox,
            "pivot": [w // 2, bbox[3]], "mirror": mirror, "bg": list(bg),
            "cutout": "isnet", "fallback_frames": [], "coverage": round(float((A > 8).mean()), 4),
            "src": video.name, "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    (out_dir / "sprite.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    shutil.rmtree(raw, ignore_errors=True)
    log("TAMAM %d kare %dx%d bbox=%s" % (len(frames), w, h, bbox))
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--out_dir", required=True)
    ap.add_argument("--fps", type=int, default=15)
    ap.add_argument("--height", type=int, default=0)
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--model", default="")
    ap.add_argument("--bg", default="")
    a = ap.parse_args()
    if a.model:
        C.ISNET = a.model
    bg = tuple(int(v) for v in a.bg.split(",")) if a.bg else None
    print(json.dumps(extract(a.video, a.out_dir, a.fps, a.height, a.mirror, bg), indent=1))


if __name__ == "__main__":
    main()
