"""Chroma-key Grok renders (flat RGB 0,255,0 background) into trimmed PNG sprites.

    python key_green.py IN.jpg OUT.png [--max 512] [--pad 8] [--webp]
    python key_green.py --batch map.json          # [{"in":..,"out":..,"max":..}, ...]

The key works in a distance space around the green primary: fully green pixels go
transparent, pixels near the key get a soft alpha and their green spill is pulled
back toward the neighbouring luma, everything else stays. Output is trimmed to the
opaque bounding box plus `pad` pixels and scaled so its longest side is `max`.
JPEG ringing around thin edges is handled by a 1 px erosion of the hard core and a
small blur of the alpha edge only.
"""
from __future__ import annotations

import argparse
import json
import sys

import cv2
import numpy as np


def estimate_background(bgr: np.ndarray, ring: int = 8) -> np.ndarray:
    """Median colour of the frame's border ring: the green screen as THIS render
    painted it (a still is RGB 0,255,0; a video frame comes back darker)."""
    h, w = bgr.shape[:2]
    top, bot = bgr[:ring].reshape(-1, 3), bgr[-ring:].reshape(-1, 3)
    left, right = bgr[:, :ring].reshape(-1, 3), bgr[:, -ring:].reshape(-1, 3)
    return np.median(np.concatenate([top, bot, left, right]), axis=0)


def key_image(bgr: np.ndarray, *, soft: float = 0.35, bg=None,
              t0: float = 0.07, t1: float = 0.22) -> np.ndarray:
    """Return BGRA with the green background removed.

    Keyed by CHROMA distance from the background colour (estimated from the
    border unless given), so a dark, desaturated video green keys as cleanly as
    a pure still green, and a shaded green leaf on a pure green screen stays.
    """
    img = bgr.astype(np.float32) / 255.0
    bgc = (np.asarray(bg, dtype=np.float32) / 255.0) if bg is not None else estimate_background(bgr) / 255.0
    s = img.sum(axis=-1, keepdims=True) + 1e-6
    chroma = img / s
    bchroma = bgc / (bgc.sum() + 1e-6)
    d = np.sqrt(((chroma - bchroma) ** 2).sum(axis=-1))
    # brightness far from the screen's also counts (a black outline on green)
    lum = img.mean(axis=-1)
    blum = float(bgc.mean())
    d = np.maximum(d, np.abs(lum - blum) * 0.6)
    alpha = np.clip((d - t0) / (t1 - t0), 0.0, 1.0)
    # clean speckle in the hard core and soften only the edge band
    core8 = (alpha <= 0.02).astype(np.uint8)
    core8 = cv2.morphologyEx(core8, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    alpha[core8 == 1] = 0.0
    edge = ((alpha > 0.0) & (alpha < 1.0)).astype(np.uint8)
    edge = cv2.dilate(edge, np.ones((3, 3), np.uint8))
    blurred = cv2.GaussianBlur(alpha, (3, 3), 0)
    alpha = np.where(edge == 1, blurred, alpha)
    # despill the fringe: where the pixel is not fully opaque, pull green down
    # to the other channels so the edge goes neutral instead of lime
    b, g, r = img[..., 0], img[..., 1], img[..., 2]
    fringe = alpha < 0.999
    g2 = np.where(fringe, np.minimum(g, np.maximum(r, b) + 0.04), g)
    out = np.dstack([b, g2, r, alpha])
    return np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)


def trim(bgra: np.ndarray, pad: int, alpha_min: int = 8) -> np.ndarray:
    a = bgra[..., 3]
    ys, xs = np.where(a >= alpha_min)
    if len(xs) == 0:
        return bgra
    x0, x1 = max(0, xs.min() - pad), min(bgra.shape[1], xs.max() + 1 + pad)
    y0, y1 = max(0, ys.min() - pad), min(bgra.shape[0], ys.max() + 1 + pad)
    return bgra[y0:y1, x0:x1]


def fit(bgra: np.ndarray, max_side: int | None) -> np.ndarray:
    if not max_side:
        return bgra
    h, w = bgra.shape[:2]
    s = max_side / max(h, w)
    if s >= 1:
        return bgra
    # premultiply before resampling so dark fringes do not appear
    f = bgra.astype(np.float32)
    a = f[..., 3:4] / 255.0
    pre = np.dstack([f[..., :3] * a, f[..., 3:4]])
    small = cv2.resize(pre, (max(1, round(w * s)), max(1, round(h * s))), interpolation=cv2.INTER_AREA)
    a2 = small[..., 3:4]
    rgb = np.where(a2 > 0.5, small[..., :3] / np.maximum(a2 / 255.0, 1e-6), 0)
    return np.clip(np.dstack([rgb, a2]) + 0.5, 0, 255).astype(np.uint8)


def process(src: str, dst: str, *, max_side: int | None, pad: int, webp: bool = False) -> tuple[int, int]:
    bgr = cv2.imread(src, cv2.IMREAD_COLOR)
    if bgr is None:
        raise SystemExit(f"cannot read {src}")
    out = fit(trim(key_image(bgr), pad), max_side)
    from PIL import Image
    img = Image.fromarray(np.ascontiguousarray(out[..., [2, 1, 0, 3]]), "RGBA")
    if webp or dst.lower().endswith(".webp"):
        img.save(dst, "WEBP", quality=92, method=6)
    else:
        img.save(dst, "PNG", optimize=True)
    return out.shape[1], out.shape[0]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--max", type=int, default=None)
    ap.add_argument("--pad", type=int, default=8)
    ap.add_argument("--webp", action="store_true")
    ap.add_argument("--batch")
    a = ap.parse_args()
    jobs = json.load(open(a.batch, encoding="utf-8")) if a.batch else [{"in": a.src, "out": a.dst, "max": a.max}]
    for j in jobs:
        w, h = process(j["in"], j["out"], max_side=j.get("max", a.max), pad=j.get("pad", a.pad), webp=a.webp)
        print(f"{j['out']}  {w}x{h}")


if __name__ == "__main__":
    main()
