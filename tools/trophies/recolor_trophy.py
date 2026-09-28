"""Turn one gold trophy render on a green chroma background into a tier set.

    python recolor_trophy.py <gold_source.jpg> <out_dir> [--height 512]

Writes trophy_bronze/silver/gold/platinum/diamond/locked.webp with a transparent background.
Only the metal (the gold-hued pixels) is recoloured; gems, velvet and other non-gold parts
keep their colour. Every tier keeps the source's exact shape and shading, so the set reads as
one trophy in six materials.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

# Gradient maps: metal luminance 0..1 -> RGB, dark to light.
TIERS = {
    "bronze": [(0.00, (40, 18, 6)), (0.35, (122, 62, 26)), (0.70, (205, 127, 72)), (1.00, (255, 222, 190))],
    "silver": [(0.00, (28, 30, 34)), (0.35, (110, 114, 122)), (0.70, (196, 200, 208)), (1.00, (255, 255, 255))],
    "platinum": [(0.00, (46, 36, 56)), (0.35, (150, 132, 168)), (0.70, (228, 214, 236)), (1.00, (255, 250, 255))],
    "diamond": [(0.00, (20, 60, 90)), (0.30, (90, 170, 215)), (0.65, (190, 235, 255)), (1.00, (255, 255, 255))],
}


def key_green(rgb: np.ndarray) -> np.ndarray:
    """Alpha from the green screen: green-dominant pixels become transparent, edges feathered."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dominance = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (dominance - 20) / 60.0, 0, 1)
    a = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    return np.asarray(a).astype(np.float32) / 255.0


def despill(rgb: np.ndarray) -> np.ndarray:
    out = rgb.copy()
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    lim = np.maximum(r, b)
    out[..., 1] = np.where(g > lim, lim, g)
    return out


def metal_mask(rgb: np.ndarray) -> np.ndarray:
    """0..1 weight of 'this pixel is gold metal' from hue/saturation."""
    img = Image.fromarray(rgb.astype(np.uint8)).convert("HSV")
    h, s, v = [np.asarray(c).astype(np.float32) for c in img.split()]
    hue = h / 255.0 * 360.0
    gold = np.clip(1 - np.abs(hue - 42) / 22, 0, 1)          # yellow-orange band
    sat = np.clip((s / 255.0 - 0.12) / 0.2, 0, 1)
    bright_white = np.clip((v / 255.0 - 0.9) / 0.1, 0, 1) * (1 - np.clip(s / 255.0 / 0.25, 0, 1))  # specular highlights
    return np.clip(gold * sat + bright_white, 0, 1)


def gradient(lum: np.ndarray, stops) -> np.ndarray:
    xs = np.array([p for p, _ in stops])
    out = np.zeros(lum.shape + (3,), np.float32)
    for c in range(3):
        out[..., c] = np.interp(lum, xs, np.array([col[c] for _, col in stops], np.float32))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("out_dir")
    ap.add_argument("--height", type=int, default=512)
    a = ap.parse_args()
    src = Image.open(a.source).convert("RGB")
    rgb = np.asarray(src).astype(np.float32)
    alpha = key_green(rgb)
    rgb = despill(rgb)
    # Crop to the trophy with a small margin.
    ys, xs = np.where(alpha > 0.1)
    pad = 12
    y0, y1 = max(0, ys.min() - pad), min(rgb.shape[0], ys.max() + pad)
    x0, x1 = max(0, xs.min() - pad), min(rgb.shape[1], xs.max() + pad)
    rgb, alpha = rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) / 255.0
    lo, hi = np.percentile(lum[alpha > 0.5], [2, 99.5])
    lum_n = np.clip((lum - lo) / max(hi - lo, 1e-3), 0, 1)
    mask = metal_mask(rgb)[..., None]
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    def save(name: str, img_rgb: np.ndarray, img_a: np.ndarray) -> None:
        rgba = np.dstack([np.clip(img_rgb, 0, 255), img_a * 255]).astype(np.uint8)
        im = Image.fromarray(rgba, "RGBA")
        w = round(im.width * a.height / im.height)
        im.resize((w, a.height), Image.LANCZOS).save(out / f"trophy_{name}.webp", "WEBP", quality=92, method=6)

    save("gold", rgb, alpha)
    for tier, stops in TIERS.items():
        mapped = gradient(lum_n, stops)
        if tier == "diamond":
            mapped = np.clip(mapped * 1.05 + 10, 0, 255)
        save(tier, rgb * (1 - mask) + mapped * mask, alpha)
    grey = np.full_like(rgb, 70.0)
    save("locked", grey, alpha * 0.85)
    print("ok", out)


if __name__ == "__main__":
    main()
