"""Hot CBN — the "reveal" Color-By-Number flow for finished, shaded artwork.

Unlike Kid CBN (one flat colour per region) the END RESULT here is the source
painting itself: the player sees a clean line-art page with numbers, and every
region they colour reveals that patch of the finished picture — shading, hair
strands, highlights and all. Numbers are the region's average colour, so the
palette is large (up to 80 entries) like the reference app.

  1. source    a finished illustration — a pool jpg, or Z-Image in the reference
               "clean semi-realistic illustration" style (--subject).
  2. lineart   Qwen Image Edit 2511 turns it into a coloring-page line drawing
               (background included). Generative, but measured to sit on the
               source's real edges within a few px.
  3. things    the vision model lists what is in the picture, SAM 3.1 masks it
               (same object finder as Kid CBN).
  4. regions   cells enclosed by the drawn lines, split where SAM says two things
               share a cell and where the colour really changes; specks folded
               into neighbours; palette fitted over region means.
  5. write     <out>/<slug>/ 00_source.png (x2 ESRGAN, long side <= 2560) ·
               02_regions.png (24-bit id) · 03_preview.png (source + lines) ·
               04_numbered.png · 05_lineart.png + .svg (vector, crisp at any zoom) ·
               06_reveal.mp4 (line art -> filled by number -> finished, 1280) · asset.json
  Ratios: 9:16 720x1280 · 2:3 832x1248 · 1:1 1024x1024 · 3:2 1248x832 · 16:9 1280x720
  (generation size; exact ratios so the Qwen page is never stretched).

    python hot_cbn.py --source "D:/.../Generic/615.jpg"
    python hot_cbn.py --subject "woman in a red dress on a balcony" --aspect 9:16
    python hot_cbn.py --matrix
"""
from __future__ import annotations

import argparse
import json
import random
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kid_cbn import (COMFY_IN, WORKFLOWS, POOL_ROOT, _converter, _saved_files, comfy_run,  # noqa: E402
                     discover_concepts, segment, _kmeans, _relabel, _delta_e, slugify, _setting,
                     order_masks_by_center, palette_by_object, segments_overlay)
from cbn_align import align_page, pad_for_edit, unpad_page  # noqa: E402

OUT_ROOT = Path(_setting("hot_cbn.root", "HOT_CBN_ROOT",
                         str(POOL_ROOT.parent / "Hot CBN" / "_proto") if str(POOL_ROOT) != "." else ""))
# Five exact ratios, 16-multiples, ~1 MP, long side <= 1280 (x2 -> 2560). 2:3 and
# 1:1 equal Qwen Edit's Kontext canvas; the rest are padded to it (cbn_align).
SIZES = {"9:16": (720, 1280), "2:3": (832, 1248), "1:1": (1024, 1024), "3:2": (1248, 832), "16:9": (1280, 720)}
ASPECT_ALIASES = {"portrait": "2:3", "square": "1:1", "landscape": "3:2"}
UPSCALE_MODEL = "RealESRGAN_x4plus_anime_6B.pth"
UPSCALE_FACTOR = 2               # asset resolution = generation x2 (long side up to 2560)
REVEAL_MAX_SIDE = 1280           # the replay video stays phone-sized

STYLE_PROMPT = (
    "{}, clean semi-realistic digital illustration, smooth cel shading with soft gradients, "
    "crisp clean edges, glossy highlights, vivid saturated colors, detailed hair strands, "
    "beautiful adult woman, glamorous, high detail")
LINEART_PROMPT = (
    "Convert this picture into a clean black-and-white line art coloring page. Draw EVERYTHING in "
    "the frame: the person AND the whole background, as crisp uniform black outlines on a pure white "
    "background, every object outlined as closed shapes, no shading, no hatching, no gray, no color, "
    "keep the exact composition, proportions and positions unchanged")
LINEART_NEG = "color, gray, shading, hatching, gradient, blur, photo, texture, noise"

CONCEPTS_HOT = ["eyes", "eyebrows", "lips", "teeth", "nose", "earring", "necklace", "bracelet",
                "ring", "hand", "fingers", "face", "hat", "sunglasses", "hair", "shoes", "bag",
                "belt", "arm", "leg", "skin", "bikini", "dress", "top", "skirt", "pants", "jacket",
                "clothing", "flower", "chair", "table", "umbrella", "cup", "car", "window", "door",
                "wall", "tree", "palm tree", "building", "water", "sea", "sand", "grass", "cloud",
                "mountain", "sky"]

LINE_THRESHOLD = 150            # Qwen's page: darker than this is line
MIN_REGION_FRAC = 0.00025       # specks below this share of the image are folded away
MIN_REGION_PX = 90
LABEL_MIN_FRAC = 0.00045        # a region gets a number when it covers this share of the picture (500 px at 1.1 MP)
L_WEIGHT = 0.6                  # shading DOES split here (sky bands, skin tones) but gently
DE_SPLIT = 16.0                 # clusters closer than this (LAB, L weighted) fuse
PALETTE_MAX = 80
PALETTE_MERGE_DE = 6.0
GOOD_REGIONS = (60, 700)
GOOD_COLORS = (16, 96)
REVEAL_SECONDS, REVEAL_FPS = 6, 24

MATRIX = [
    ("2:3", "woman with long wavy honey-brown hair in a white halter bikini and a blue sarong, leaning on a wooden cafe table with a cup of coffee, tropical beach and palm trunk behind"),
    ("9:16", "woman with a sleek black bob in a red satin evening dress on a city balcony at night, neon lights behind"),
    ("16:9", "woman with curly auburn hair in a yellow sundress lying on a picnic blanket in a sunflower field"),
    ("1:1", "woman with silver hair and a black leather jacket sitting on a motorcycle in a desert at sunset"),
]


# ------------------------------------------------------------------ comfy
def zimage(subject: str, dest: Path, aspect: str, seed: int | None = None) -> Path:
    w, h = SIZES[aspect]
    wf = json.loads((WORKFLOWS / "Image Z Turbo.json").read_text(encoding="utf-8"))
    seed = seed or random.randint(1, 2 ** 31)
    p = STYLE_PROMPT.format(subject)
    g = _converter()(wf, {"prompt": p, "text": p, "width": w, "height": h, "seed": seed, "noise_seed": seed})
    for n in g.values():
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "hot_cbn/gen"
    t0 = time.time()
    shutil.copy(_saved_files(comfy_run(g))[-1], dest)
    print(f"  z-image {w}x{h} {time.time() - t0:.0f}s -> {dest.name}")
    return dest


def upscale(src: Path, dest: Path, factor: int = UPSCALE_FACTOR, model: str = UPSCALE_MODEL) -> Path:
    """ESRGAN x4 (anime model, crisp on cel-shaded art) then lanczos down to
    exactly `factor` x the source - the picture the player colours and zooms."""
    img = cv2.imread(str(src))
    if img is None:
        raise RuntimeError(f"cannot read {src}")
    H, W = img.shape[:2]
    name = f"hotcbn_up_{uuid.uuid4().hex[:8]}.png"
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(COMFY_IN / name), img)
    g = {
        "1": {"class_type": "LoadImage", "inputs": {"image": name}},
        "2": {"class_type": "UpscaleModelLoader", "inputs": {"model_name": model}},
        "3": {"class_type": "ImageUpscaleWithModel", "inputs": {"upscale_model": ["2", 0], "image": ["1", 0]}},
        "4": {"class_type": "ImageScale", "inputs": {"image": ["3", 0], "upscale_method": "lanczos",
                                                     "width": W * factor, "height": H * factor, "crop": "disabled"}},
        "5": {"class_type": "SaveImage", "inputs": {"images": ["4", 0], "filename_prefix": "hot_cbn/up"}},
    }
    t0 = time.time()
    out = cv2.imread(str(_saved_files(comfy_run(g))[-1]))
    if out is None or out.shape[:2] != (H * factor, W * factor):
        raise RuntimeError("upscale returned the wrong size")
    cv2.imwrite(str(dest), out)
    print(f"  upscale x{factor} {time.time() - t0:.0f}s -> {dest.name} {W * factor}x{H * factor}")
    return dest


def qwen_lineart(src: Path, dest: Path, seed: int | None = None) -> Path:
    """Qwen Edit line-art page for `src`, written to `dest` at the source's own
    size. The picture is padded to an exact Kontext aspect ratio (+4 % margin)
    before the edit so FluxKontextImageScale does not stretch it and the
    model's zoom cannot crop content; the page is cropped back afterwards.
    (Residual drift is removed later by cbn_align.align_page in build().)"""
    wf = json.loads((WORKFLOWS / "Image Qwen Image.json").read_text(encoding="utf-8"))
    seed = seed or random.randint(1, 2 ** 31)
    g = _converter()(wf, {"positive_prompt": LINEART_PROMPT, "prompt": LINEART_PROMPT,
                          "negative_prompt": LINEART_NEG, "enable_turbo_mode": True,
                          "seed": seed, "noise_seed": seed})
    img = cv2.imread(str(src))
    if img is None:
        raise RuntimeError(f"cannot read {src}")
    padded, box = pad_for_edit(img)
    name = f"hotcbn_{uuid.uuid4().hex[:8]}.png"
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(COMFY_IN / name), padded)
    for n in g.values():
        if n["class_type"] == "LoadImage":
            n["inputs"]["image"] = name
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "hot_cbn/lineart"
    t0 = time.time()
    page = cv2.imread(str(_saved_files(comfy_run(g))[-1]), cv2.IMREAD_GRAYSCALE)
    page = unpad_page(page, box)
    cv2.imwrite(str(dest), page)
    print(f"  qwen lineart {time.time() - t0:.0f}s (canvas {box['padded'][0]}x{box['padded'][1]}) -> {dest.name}")
    return dest


# ---------------------------------------------------------------- regions
def _fold_specks(labels: np.ndarray, min_px: int, lab_img: np.ndarray, rounds: int = 12) -> np.ndarray:
    """Fold regions below min_px into the neighbour with the closest colour
    (ties -> longest shared border). Bounding-box local, so cheap."""
    for _ in range(rounds):
        _n, lab = _relabel(labels)
        n = lab.max() + 1
        areas = np.bincount(lab.ravel(), minlength=n)
        small = np.where((areas > 0) & (areas < min_px))[0]
        if len(small) == 0:
            return lab
        means = np.zeros((n, 3), np.float32)
        for c in range(3):
            means[:, c] = np.bincount(lab.ravel(), weights=lab_img[..., c].ravel(), minlength=n) / np.maximum(areas, 1)
        H, W = lab.shape
        for i in small:
            ys, xs = np.where(lab == i)
            if len(ys) == 0:
                continue
            y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, H)
            x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, W)
            win = lab[y0:y1, x0:x1]
            me = win == i
            ring = cv2.dilate(me.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~me
            neigh = win[ring]
            neigh = neigh[neigh != i]
            if len(neigh) == 0:
                continue
            cand, cnt = np.unique(neigh, return_counts=True)
            score = cnt / cnt.max() - 0.03 * np.array([_delta_e(means[i], means[c]) for c in cand])
            win[me] = cand[int(np.argmax(score))]
        labels = lab
    # whatever is still tiny after the rounds (specks walled in by other specks)
    # is handed to the nearest big region outright
    _n, lab = _relabel(labels)
    areas = np.bincount(lab.ravel())
    tiny = areas < min_px
    if tiny.any() and not tiny.all():
        _d, idx = cv2.distanceTransformWithLabels(tiny[lab].astype(np.uint8), cv2.DIST_L2, 3, labelType=cv2.DIST_LABEL_PIXEL)
        big = ~tiny[lab]
        flat = np.zeros(idx.max() + 1, np.int32)
        flat[idx[big]] = lab[big]
        lab = np.where(tiny[lab], flat[idx], lab)
    return _relabel(lab)[1]


def sam_outline(seg: np.ndarray, thick: int = 3) -> np.ndarray:
    """Object outlines straight from the SAM segments: the border between two
    different segments, lightly smoothed, drawn `thick` px. Pixel-exact with
    the source (unlike a generated line-art page) and, by construction, only
    where objects meet - no shading lines inside a thing (task #281)."""
    sm = cv2.medianBlur(seg.astype(np.uint16), 5).astype(np.int32)   # de-jag mask edges
    e = _borders(sm)
    out = cv2.dilate(e.astype(np.uint8), np.ones((thick, thick), np.uint8)).astype(bool)
    # masks that touch the picture edge leave a dashed frame along the border;
    # the page has no use for lines there
    f = thick + 2
    out[:f, :] = out[-f:, :] = False
    out[:, :f] = out[:, -f:] = False
    return out


def fit_masks(masks, H: int, W: int):
    """SAM runs on the generation-size picture; the asset is built at x2. Scale
    the masks up (linear + threshold, so edges stay smooth) when sizes differ."""
    out = []
    for name, m, share in masks:
        if m.shape != (H, W):
            m = cv2.resize(m.astype(np.uint8) * 255, (W, H), interpolation=cv2.INTER_LINEAR) > 127
        out.append((name, m, share))
    return out


def build(img_bgr: np.ndarray, line_gray, masks, min_px_override: int | None = None) -> dict:
    """line_gray: a drawn line-art page (Qwen) or None -> outlines come from
    the SAM segments themselves."""
    H, W = img_bgr.shape[:2]
    area = H * W
    min_px = min_px_override or max(MIN_REGION_PX, int(area * MIN_REGION_FRAC))
    label_min_px = max(500, int(area * LABEL_MIN_FRAC))
    lab_img = cv2.cvtColor(cv2.bilateralFilter(img_bgr, 7, 30, 7), cv2.COLOR_BGR2LAB)
    masks = fit_masks(masks, H, W)

    # 2) semantic segments by claim priority (needed first: with no drawn page
    #    the outlines ARE the segment borders)
    seg = np.full((H, W), -1, dtype=np.int32)
    seg_names: list[str] = []
    for concept, mask, _s in order_masks_by_center(masks, H, W):
        m = mask & (seg == -1)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
        if m.sum() < min_px:
            continue
        seg[m] = len(seg_names)
        seg_names.append(concept)
    seg[seg == -1] = len(seg_names)
    seg_names.append("rest")

    # 1) lines -> cells. Drawn page if given (and sane), else SAM outlines.
    #    A drawn page is first registered onto the picture's real edges
    #    (cbn_align: affine + mesh) - Qwen's page comes back ~4 % zoomed and
    #    shifted, which put hair lines beside the hair.
    align_info = None
    if line_gray is not None:
        line_gray, align_info = align_page(line_gray, img_bgr, LINE_THRESHOLD)
        line = line_gray < LINE_THRESHOLD
        line = cv2.morphologyEx(line.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
        if line.mean() > 0.35:            # a "page" that is a third black is not line art
            line = sam_outline(seg)
    else:
        line = sam_outline(seg)
    _n, cells = cv2.connectedComponents((~line).astype(np.uint8), connectivity=4)

    # 3) inside every (cell, segment) piece: colour clusters where the colour really changes
    piece = cells.astype(np.int64) * (len(seg_names) + 1) + (seg + 1)
    piece[line] = 0
    _u, piece = np.unique(piece, return_inverse=True)
    piece = piece.reshape(H, W).astype(np.int32)
    feat = lab_img.astype(np.float32).copy()
    feat[..., 0] *= L_WEIGHT
    prov = np.zeros((H, W), np.int32)
    nxt = 1
    counts = np.bincount(piece.ravel())
    for pid in range(1, len(counts)):
        cnt = counts[pid]
        if cnt == 0:
            continue
        m = piece == pid
        share = cnt / area
        k = 1 if share < 0.003 else 2 if share < 0.02 else 3 if share < 0.08 else 5
        if k > 1:
            lbl, cen = _kmeans(feat[m], k)
            owner = list(range(k))
            for i in range(k):
                for j in range(i):
                    if owner[j] == j and owner[i] == i and _delta_e(cen[i], cen[j]) < DE_SPLIT:
                        owner[i] = j
                        break
            lbl = np.array([owner[v] for v in range(k)])[lbl]
            prov[m] = nxt + lbl
            nxt += k
        else:
            prov[m] = nxt
            nxt += 1
    # line pixels join the nearest coloured pixel so every pixel belongs to a region
    _d, idx = cv2.distanceTransformWithLabels(line.astype(np.uint8), cv2.DIST_L2, 3, labelType=cv2.DIST_LABEL_PIXEL)
    flat = np.zeros(idx.max() + 1, np.int32)
    flat[idx[~line]] = prov[~line]
    prov = np.where(line, flat[idx], prov)
    prov = cv2.medianBlur(prov.astype(np.uint16), 3).astype(np.int32)

    labels = _fold_specks(prov, min_px, lab_img)
    n = labels.max() + 1
    counts = np.bincount(labels.ravel(), minlength=n).astype(np.float32)

    # 4) palette PER OBJECT: each thing (centre-first) gets its own run of
    #    numbers from its own colour pool, background last; global cap 80
    cen, region_color, _owner = palette_by_object(labels, seg, lab_img, line, per_object_k=8,
                                                  max_colors=PALETTE_MAX, merge_de=PALETTE_MERGE_DE)
    region_color = region_color.astype(np.int32)
    pal_bgr = cv2.cvtColor(cen.reshape(1, -1, 3).astype(np.uint8), cv2.COLOR_LAB2BGR).reshape(-1, 3)
    palette = [f"#{b[2]:02x}{b[1]:02x}{b[0]:02x}" for b in pal_bgr]

    # 5) label points
    points = []
    for r in range(n):
        m = (labels == r).astype(np.uint8)
        ys, xs = np.where(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        dt = cv2.distanceTransform(np.pad(m[y0:y1, x0:x1], 1), cv2.DIST_L2, 3)
        iy, ix = np.unravel_index(np.argmax(dt), dt.shape)
        points.append((int(x0 + ix - 1), int(y0 + iy - 1), float(dt.max())))

    metrics = {"regions": int(n), "colors": len(palette), "min_region_px": int(counts.min()),
               "median_region_px": int(np.median(counts)), "largest_region_share": round(float(counts.max()) / area, 3),
               "labeled_regions": int((counts >= label_min_px).sum()), "label_min_px": label_min_px,
               "segments": seg_names,
               "line_share": round(float(line.mean()), 3), "align": align_info}
    metrics["verdict"] = ("pass" if GOOD_REGIONS[0] <= n <= GOOD_REGIONS[1] and GOOD_COLORS[0] <= len(palette) <= GOOD_COLORS[1]
                          and metrics["largest_region_share"] < 0.35 else "fail")
    return {"labels": labels, "region_color": region_color, "palette": palette, "points": points,
            "counts": counts.astype(int), "line": line, "seg": seg, "seg_names": seg_names, "metrics": metrics}


# ----------------------------------------------------------------- output
def _borders(labels: np.ndarray) -> np.ndarray:
    e = np.zeros(labels.shape, bool)
    e[:, 1:] |= labels[:, 1:] != labels[:, :-1]
    e[1:, :] |= labels[1:, :] != labels[:-1, :]
    return e


def write_asset(img_bgr: np.ndarray, res: dict, out: Path, meta: dict, reveal: bool = True) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    H, W = img_bgr.shape[:2]
    labels, rc, pal, line = res["labels"], res["region_color"], res["palette"], res["line"]
    n = labels.max() + 1
    cv2.imwrite(str(out / "00_source.png"), img_bgr)

    # the drawn page shows ONLY the object outlines Qwen drew. Regions that were
    # split inside one outline (shading bands, SAM parts) have no visible border
    # — the user's rule: lines belong to objects, not to colour changes. The
    # split borders are kept in a debug image for tuning.
    page = np.full((H, W, 3), 255, np.uint8)
    page[line] = (0, 0, 0)
    cv2.imwrite(str(out / "05_lineart.png"), page)
    dbg = page.copy()
    dbg[_borders(labels) & ~line] = (150, 150, 150)
    cv2.imwrite(str(out / "_debug_splits.png"), dbg)

    idmap = np.zeros((H, W, 3), np.uint8)
    idmap[..., 2] = (labels >> 16) & 255
    idmap[..., 1] = (labels >> 8) & 255
    idmap[..., 0] = labels & 255
    cv2.imwrite(str(out / "02_regions.png"), idmap)

    # finished look = source with the lines on top (this is what a filled region shows)
    finished = img_bgr.copy()
    finished[line] = (finished[line] * 0.15).astype(np.uint8)
    cv2.imwrite(str(out / "03_preview.png"), finished)

    label_min_px = res["metrics"]["label_min_px"]
    k = min(H, W) / 876.0                     # font/thickness follow the resolution
    thick = max(1, int(round(k)))
    numbered = page.copy()
    for r in range(n):
        if res["counts"][r] < label_min_px:
            continue
        x, y, depth = res["points"][r]
        depth /= k
        scale = (0.38 if depth < 12 else 0.5 if depth < 24 else 0.65 if depth < 50 else 0.85) * k
        txt = str(int(rc[r]) + 1)
        (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, scale, thick)
        cv2.putText(numbered, txt, (x - tw // 2, y + th // 2), cv2.FONT_HERSHEY_SIMPLEX, scale, (60, 60, 60), thick, cv2.LINE_AA)
    cv2.imwrite(str(out / "04_numbered.png"), numbered)
    (out / "05_lineart.svg").write_text(lineart_svg(line), encoding="utf-8")

    # segments overlay for the contact sheet
    # (#318: ortak yardimci - Gelen on izlemesiyle ayni goruntu)
    over = segments_overlay(img_bgr, res["seg"], res["seg_names"], seed=3, scale=0.5)
    cv2.imwrite(str(out / "01_segments.png"), over)

    data = {**meta, "width": W, "height": H,
            "palette": [{"id": i + 1, "hex": p} for i, p in enumerate(pal)],
            "regions": [{"id": r, "color": int(rc[r]) + 1, "area": int(res["counts"][r]),
                         "label_at": [res["points"][r][0], res["points"][r][1]],
                         "labeled": bool(res["counts"][r] >= label_min_px)} for r in range(n)],
            "metrics": res["metrics"],
            "files": ["00_source.png", "01_segments.png", "02_regions.png", "03_preview.png",
                      "04_numbered.png", "05_lineart.png", "05_lineart.svg", "06_reveal.mp4", "asset.json"]}
    (out / "asset.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    if reveal:
        reveal_video(img_bgr, res, page, out / "06_reveal.mp4")
    return data


def lineart_svg(line: np.ndarray, eps: float = 0.6) -> str:
    """The line mask as vector fills (outer contours minus holes, even-odd) so
    the page stays crisp at any zoom in the app. eps = simplification (px)."""
    H, W = line.shape
    cs, _h = cv2.findContours(line.astype(np.uint8), cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    d = []
    for c in cs:
        c = cv2.approxPolyDP(c, eps, True).reshape(-1, 2)
        if len(c) < 3:
            continue
        d.append("M" + " L".join(f"{x} {y}" for x, y in c) + "Z")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
            f'<path fill="#000" fill-rule="evenodd" d="{" ".join(d)}"/></svg>')


def reveal_video(img_bgr: np.ndarray, res: dict, page: np.ndarray, dest: Path) -> None:
    """Line art -> regions fill in palette order -> finished picture, like the
    reference app's completion replay. Rendered at phone size (long side
    REVEAL_MAX_SIDE) whatever the asset resolution; even dims for libx264."""
    ff = shutil.which("ffmpeg")
    if not ff:
        print("  ffmpeg missing - no reveal video")
        return
    labels, rc, line = res["labels"], res["region_color"], res["line"]
    H0, W0 = img_bgr.shape[:2]
    if max(H0, W0) > REVEAL_MAX_SIDE:
        f = REVEAL_MAX_SIDE / max(H0, W0)
        W, H = int(round(W0 * f)) // 2 * 2, int(round(H0 * f)) // 2 * 2
        img_bgr = cv2.resize(img_bgr, (W, H), interpolation=cv2.INTER_AREA)
        page = cv2.resize(page, (W, H), interpolation=cv2.INTER_AREA)
        labels = cv2.resize(labels.astype(np.int32), (W, H), interpolation=cv2.INTER_NEAREST)
        line = cv2.resize(line.astype(np.uint8), (W, H), interpolation=cv2.INTER_AREA) > 0
    H, W = img_bgr.shape[:2]
    total = REVEAL_SECONDS * REVEAL_FPS
    hold_in, hold_out = int(0.6 * REVEAL_FPS), int(1.2 * REVEAL_FPS)
    fill_frames = total - hold_in - hold_out
    # order regions by colour id, then by area (big first) inside a colour
    order = sorted(range(labels.max() + 1), key=lambda r: (int(rc[r]), -int(res["counts"][r])))
    filled = np.zeros((H, W), bool)
    lined = img_bgr.copy()
    lined[line] = (lined[line] * 0.15).astype(np.uint8)
    tmp = dest.with_suffix(".tmp.mp4")
    proc = subprocess.Popen(
        [ff, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{W}x{H}",
         "-r", str(REVEAL_FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
         "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", str(tmp)], stdin=subprocess.PIPE)
    per_frame = max(1, int(np.ceil(len(order) / fill_frames)))
    pos = 0
    for f in range(total):
        if hold_in <= f < hold_in + fill_frames:
            for r in order[pos:pos + per_frame]:
                filled |= labels == r
            pos += per_frame
        if f >= hold_in + fill_frames + hold_out // 2:
            frame = img_bgr                    # last half second: lines dissolve, pure art
        else:
            frame = np.where(filled[..., None], lined, page)
        proc.stdin.write(np.ascontiguousarray(frame, dtype=np.uint8).tobytes())
    proc.stdin.close()
    proc.wait()
    if tmp.exists():
        tmp.replace(dest)
        print(f"  reveal video -> {dest.name}")


# ------------------------------------------------------------------- main
def run_one(source: Path | None, subject: str, aspect: str, seed: int | None = None) -> dict:
    aspect = ASPECT_ALIASES.get(aspect, aspect)
    slug = slugify(source.stem if source else subject)
    slug = ("src_" if source else f"{aspect.replace(':', 'x')}_") + slug
    out = OUT_ROOT / slug
    out.mkdir(parents=True, exist_ok=True)
    print(f"\n=== {slug}")
    gen = out / "_gen.png"                    # generation size: Qwen page + SAM run on this
    if source:
        img = cv2.imread(str(source))
        if img is None:
            raise RuntimeError(f"cannot read {source}")
        cv2.imwrite(str(gen), img)
    elif not gen.exists():
        zimage(subject, gen, aspect, seed)
    src = out / "00_source.png"               # asset size (x2): what the player colours
    if not src.exists():
        upscale(gen, src)
    img = cv2.imread(str(src))
    la_path = out / "_qwen_lineart.png"
    if not la_path.exists():
        qwen_lineart(gen, la_path)
    la = cv2.imread(str(la_path), cv2.IMREAD_GRAYSCALE)   # build() scales + aligns it
    found = discover_concepts(gen)
    print(f"  vision model found {len(found)}: {', '.join(found[:18])}{' ...' if len(found) > 18 else ''}")
    concepts = list(dict.fromkeys(found + CONCEPTS_HOT))
    masks = segment(gen, concepts)
    t0 = time.time()
    res = build(img, la, masks)
    data = write_asset(img, res, out, {"subject": subject, "source": str(source) if source else "", "aspect": aspect, "flow": "hot_cbn"})
    m = res["metrics"]
    print(f"  build {time.time() - t0:.0f}s -> {m['regions']} regions, {m['colors']} colors, min {m['min_region_px']} px, "
          f"largest {m['largest_region_share']:.0%}, labeled {m['labeled_regions']} -> {m['verdict'].upper()}   ({out})")
    return data


def main() -> int:
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path)
    ap.add_argument("--subject", default="")
    ap.add_argument("--aspect", choices=list(SIZES) + list(ASPECT_ALIASES), default="2:3")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--matrix", action="store_true")
    a = ap.parse_args()
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    jobs = [(None, s, asp) for asp, s in MATRIX] if a.matrix else [(a.source, a.subject, a.aspect)]
    results = []
    for source, subject, aspect in jobs:
        try:
            results.append(run_one(source, subject, aspect, a.seed))
        except Exception as e:
            print(f"  FAILED: {e}")
            results.append({"subject": subject, "source": str(source or ""), "error": str(e)[:300]})
    (OUT_ROOT / "_last_run.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
