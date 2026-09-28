"""Turn a Grok trophy video (gold, green screen) into looping, tier-recoloured animated WebPs.

    python trophy_anim.py <video.mp4> <out_dir> <name> --kind spin|alive [--fps 12] [--height 360]
        [--quality 80] [--alpha-quality 100] [--step N]

Hot Idle set (2026-09-28): shelf spin --height 200 --fps 24 --step 1 --quality 65 --alpha-quality 60
(~1.8-2 MB); popup alive_full --height 0 (native crop height, full resolution) --fps 24 --step 1.



- Zoom drift is removed: the base's width (a band just above the lowest point of the trophy) is
  measured per frame, a straight line is fitted over time and every frame is rescaled back to the
  first frame's size, anchored at the ground contact point.
- Loop: every clip (spin and alive) is the full 24 fps take forward then back (6 s -> 12 s);
  never drop frames or lower the fps - lower the height to save bytes.
- Every tier (bronze, silver, gold, platinum, diamond) is produced with recolor_trophy's maps; the
  green key gives the transparency. Output: <out_dir>/<name>_<tier>.webp (animated, loops forever).
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

from recolor_trophy import TIERS, despill, gradient, key_green, metal_mask


def read_frames(path: str) -> tuple[np.ndarray, float]:
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                            "stream=width,height,r_frame_rate", "-of", "csv=p=0", path],
                           capture_output=True, text=True).stdout.strip().split(",")
    w, h = int(probe[0]), int(probe[1])
    num, den = probe[2].split("/")
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3), float(num) / float(den)


def base_metrics(alpha: np.ndarray) -> tuple[float, float, float]:
    """(ground y, base width, base centre x) from the lowest band of the trophy."""
    rows = np.where(alpha.max(axis=1) > 0.5)[0]
    bottom = rows.max()
    band = alpha[max(0, bottom - 40):bottom - 8] > 0.5
    cols = np.where(band.any(axis=0))[0]
    return float(bottom), float(cols.max() - cols.min()), float((cols.max() + cols.min()) / 2)


def stabilise(frames: np.ndarray, alphas: list[np.ndarray]) -> tuple[list[np.ndarray], list[np.ndarray]]:
    m = np.array([base_metrics(a) for a in alphas])
    t = np.arange(len(frames))
    width_fit = np.polyval(np.polyfit(t, m[:, 1], 1), t)
    ground_fit = np.polyval(np.polyfit(t, m[:, 0], 1), t)
    cx_fit = np.polyval(np.polyfit(t, m[:, 2], 1), t)
    h, w = frames.shape[1:3]
    out_f, out_a = [], []
    for i, (f, a) in enumerate(zip(frames, alphas)):
        s = width_fit[0] / width_fit[i]
        rgba = Image.fromarray(np.dstack([f, (a * 255).astype(np.uint8)]), "RGBA")
        nw, nh = max(1, round(w * s)), max(1, round(h * s))
        rgba = rgba.resize((nw, nh), Image.LANCZOS)
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # Keep the ground contact point and base centre where they were in frame 0.
        ox = round(cx_fit[0] - cx_fit[i] * s)
        oy = round(ground_fit[0] - ground_fit[i] * s)
        canvas.alpha_composite(rgba, (ox, oy)) if 0 <= ox and 0 <= oy else canvas.paste(rgba, (ox, oy), rgba)
        arr = np.asarray(canvas)
        out_f.append(arr[..., :3].copy())  # uint8: a full-res take stays well under 1 GB
        out_a.append(arr[..., 3].astype(np.float32) / 255.0)
    return out_f, out_a


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out_dir")
    ap.add_argument("name")
    ap.add_argument("--kind", choices=["spin", "alive"], required=True)
    ap.add_argument("--fps", type=int, default=12)
    ap.add_argument("--height", type=int, default=360,
                    help="output height in px; 0 = native crop height (full resolution)")
    ap.add_argument("--quality", type=int, default=80, help="WebP colour quality")
    ap.add_argument("--alpha-quality", type=int, default=100, help="WebP alpha plane quality")
    ap.add_argument("--step", type=int, default=0,
                    help="keep every Nth source frame (0 = spin: all, alive: source fps / --fps)")
    a = ap.parse_args()

    frames, src_fps = read_frames(a.video)
    if a.step:
        frames = frames[::a.step]
    elif a.kind == "alive":
        step = max(1, round(src_fps / a.fps))
        frames = frames[::step]
    alphas = [key_green(f.astype(np.float32)) for f in frames]
    rgbs = np.stack([despill(f.astype(np.float32)).astype(np.uint8) for f in frames])
    del frames
    rgbs, alphas = stabilise(rgbs, alphas)
    order = list(range(len(rgbs)))
    # Owner 2026-09-28: every trophy clip (spin AND alive) is the full 24 fps source played
    # forward then back - 6 s take = 12 s seamless loop. Never drop frames or fps.
    order = order + order[-2:0:-1]          # forward then back, ends are not repeated

    # One crop box for the whole clip so the trophy never jumps.
    union = np.max(np.stack(alphas), axis=0)
    ys, xs = np.where(union > 0.1)
    pad = 10
    y0, y1 = max(0, ys.min() - pad), ys.max() + pad
    x0, x1 = max(0, xs.min() - pad), xs.max() + pad
    ref = rgbs[0][y0:y1, x0:x1]
    lum_ref = (0.299 * ref[..., 0] + 0.587 * ref[..., 1] + 0.114 * ref[..., 2]) / 255.0
    lo, hi = np.percentile(lum_ref[alphas[0][y0:y1, x0:x1] > 0.5], [2, 99.5])

    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    # --height 0 = the trophy's native pixel height in the source crop (never upscaled).
    height = (y1 - y0) if a.height <= 0 else min(a.height, y1 - y0)
    scale = height / (y1 - y0)
    size = (max(1, round((x1 - x0) * scale)), height)
    for tier in ["bronze", "silver", "gold", "platinum", "diamond"]:
        made: dict[int, Image.Image] = {}   # ping-pong reuses each source frame's image
        imgs = []
        for i in order:
            if i in made:
                imgs.append(made[i])
                continue
            rgb, al = rgbs[i][y0:y1, x0:x1], alphas[i][y0:y1, x0:x1]
            if tier != "gold":
                lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0
                mapped = gradient(np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1), TIERS[tier])
                mask = metal_mask(rgb)[..., None]
                rgb = rgb * (1 - mask) + mapped * mask
            rgba = np.dstack([np.clip(rgb, 0, 255), al * 255]).astype(np.uint8)
            made[i] = Image.fromarray(rgba, "RGBA").resize(size, Image.LANCZOS)
            imgs.append(made[i])
        imgs[0].save(out / f"{a.name}_{tier}.webp", "WEBP", save_all=True, append_images=imgs[1:],
                     duration=round(1000 / a.fps), loop=0, quality=a.quality,
                     alpha_quality=a.alpha_quality, method=4)
    print("ok", a.name, a.kind, len(order), "frames", size)


if __name__ == "__main__":
    main()
