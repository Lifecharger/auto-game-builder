"""Register a generated line-art page onto the picture it was drawn from.

Qwen Image Edit redraws the source rather than tracing it, and its canvas goes
through FluxKontextImageScale (nearest of a fixed list of ~1 MP sizes, stretched
to fit). Measured over the Hot CBN pool (2026-09-07, 10 assets): the page comes
back ~3.5-5 % wider, ~1-2 % taller and shifted 10-17 px left/up - the same
pattern every time, so the drawn hair sits right of the real hair and the arm
patch floats off the arm. On top of that there is a smooth 1-3 px residual.

    aligned, info = align_page(page_gray, source_bgr)

does three things, all CPU and ~1 s at 1 MP:

  1. edges      soft edge-strength map + hard edge mask of the source (LAB
                gradients + Canny on L, a, b - colour edges count too).
  2. affine     ECC (enhanced correlation coefficient) affine of the page onto
                the edge map, coarse->fine, started from the measured prior and
                sanity-checked (scale 0.95-1.12, tiny shear, shift < 8 %). A page
                that will not correlate (a dark, mostly-black page) keeps the
                prior; the caller can still fall back to SAM outlines.
  3. mesh       per-tile ECC translation on the affine result, interpolated to
                a dense field and remapped - takes out the smooth residual.

`pad_for_edit(img)` is the other half: pad the source to EXACTLY one of the
Kontext aspect ratios (plus a margin so the model's zoom cannot crop content)
before sending it to Qwen, `unpad_page` crops the page back. That removes the
aspect stretch at the source; the ECC pass mops up what is left.
"""
from __future__ import annotations

import cv2
import numpy as np

# comfy_extras/nodes_flux.py PREFERRED_KONTEXT_RESOLUTIONS (w, h)
KONTEXT_SIZES = [(672, 1568), (688, 1504), (720, 1456), (752, 1392), (800, 1328), (832, 1248), (880, 1184),
                 (944, 1104), (1024, 1024), (1104, 944), (1184, 880), (1248, 832), (1328, 800), (1392, 752),
                 (1456, 720), (1504, 688), (1568, 672)]
PAD_MARGIN = 0.04           # each side; measured zoom is 3.5-5 % so content never leaves the canvas
PRIOR = np.array([[1.045, 0.0, -14.0], [0.0, 1.015, -7.0]], np.float32)   # page -> source, at 876x1280
PRIOR_REF_W, PRIOR_REF_H = 876, 1280
PAGE_BLACK_LIMIT = 0.35     # more black than this is not a line drawing


# ------------------------------------------------------------------ padding
def pad_for_edit(img_bgr: np.ndarray, margin: float = PAD_MARGIN) -> tuple[np.ndarray, dict]:
    """White-pad the picture by `margin` on every side, then pad further so the
    aspect ratio equals the Kontext size it will be snapped to. Returns the
    padded picture and the crop box to undo it."""
    H, W = img_bgr.shape[:2]
    mx, my = int(round(W * margin)), int(round(H * margin))
    w1, h1 = W + 2 * mx, H + 2 * my
    _d, kw, kh = min((abs(w1 / h1 - w / h), w, h) for w, h in KONTEXT_SIZES)
    target = kw / kh
    if w1 / h1 < target:          # too tall -> widen
        w2, h2 = int(round(h1 * target)), h1
    else:                         # too wide -> heighten
        w2, h2 = w1, int(round(w1 / target))
    left, top = (w2 - W) // 2, (h2 - H) // 2
    out = np.full((h2, w2, 3), 255, np.uint8)
    out[top:top + H, left:left + W] = img_bgr
    # replicate the picture's own border into the margin so the model sees
    # continuous content, not a white frame it might outline
    out = _replicate_into_margin(out, top, left, H, W)
    return out, {"left": left, "top": top, "width": W, "height": H, "padded": [w2, h2], "kontext": [kw, kh]}


def _replicate_into_margin(canvas: np.ndarray, top: int, left: int, H: int, W: int) -> np.ndarray:
    h2, w2 = canvas.shape[:2]
    if top:
        canvas[:top, left:left + W] = canvas[top:top + 1, left:left + W]
    if h2 - top - H:
        canvas[top + H:, left:left + W] = canvas[top + H - 1:top + H, left:left + W]
    if left:
        canvas[:, :left] = canvas[:, left:left + 1]
    if w2 - left - W:
        canvas[:, left + W:] = canvas[:, left + W - 1:left + W]
    return canvas


def unpad_page(page: np.ndarray, box: dict) -> np.ndarray:
    """Crop a page drawn on the padded canvas back to the source frame (page may
    come back at the Kontext size - scale it to the padded size first)."""
    pw, ph = box["padded"]
    if page.shape[1] != pw or page.shape[0] != ph:
        page = cv2.resize(page, (pw, ph), interpolation=cv2.INTER_AREA if page.shape[1] > pw else cv2.INTER_CUBIC)
    l, t, w, h = box["left"], box["top"], box["width"], box["height"]
    return page[t:t + h, l:l + w]


# ------------------------------------------------------------------- edges
def source_edges(img_bgr: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """(soft edge strength 0..1, hard edge mask) of the picture."""
    sm = cv2.bilateralFilter(img_bgr, 7, 30, 7)
    lab = cv2.cvtColor(sm, cv2.COLOR_BGR2LAB).astype(np.float32)
    g = np.zeros(img_bgr.shape[:2], np.float32)
    for c, w in ((0, 1.0), (1, 1.2), (2, 1.2)):
        gx = cv2.Sobel(lab[..., c], cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(lab[..., c], cv2.CV_32F, 0, 1, ksize=3)
        g += w * np.sqrt(gx * gx + gy * gy)
    g = np.clip(g / max(float(np.percentile(g, 99.5)), 1e-6), 0, 1)
    hard = cv2.Canny(cv2.cvtColor(sm, cv2.COLOR_BGR2GRAY), 40, 110) > 0
    for c in (1, 2):
        ch = cv2.normalize(lab[..., c], None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
        hard |= cv2.Canny(ch, 60, 140) > 0
    return g, hard


def _soft(a: np.ndarray, sigma: float) -> np.ndarray:
    b = cv2.GaussianBlur(a.astype(np.float32), (0, 0), sigma)
    return b / (float(b.max()) + 1e-6)


def line_distance(line: np.ndarray, hard_edges: np.ndarray) -> dict:
    """How far the line pixels sit from the nearest real edge (px)."""
    dt = cv2.distanceTransform((~hard_edges).astype(np.uint8), cv2.DIST_L2, 3)
    d = dt[line]
    if d.size == 0:
        return {"mean": 0.0, "median": 0.0, "within2": 0.0}
    return {"mean": round(float(d.mean()), 2), "median": round(float(np.median(d)), 2),
            "within2": round(float((d <= 2).mean()), 3)}


# ------------------------------------------------------------------ affine
def _prior_for(W: int, H: int) -> np.ndarray:
    p = PRIOR.copy()
    p[0, 2] *= W / PRIOR_REF_W
    p[1, 2] *= H / PRIOR_REF_H
    return p


def _sane(warp: np.ndarray, W: int, H: int) -> bool:
    return (0.95 < warp[0, 0] < 1.12 and 0.95 < warp[1, 1] < 1.12 and abs(warp[0, 1]) < 0.03
            and abs(warp[1, 0]) < 0.03 and abs(warp[0, 2]) < 0.08 * W and abs(warp[1, 2]) < 0.08 * H)


def fit_affine(line: np.ndarray, edge_soft: np.ndarray, start: np.ndarray | None = None) -> tuple[np.ndarray, float]:
    """ECC affine mapping source coords -> page coords (what warpAffine with
    WARP_INVERSE_MAP wants). Coarse->fine from the prior; returns (warp, cc);
    cc < 0 means nothing sane was found and the prior is returned."""
    H, W = line.shape
    best = ((start if start is not None else _prior_for(W, H)).copy(), -1.0)
    for sigma, s in ((8.0, 0.25), (5.0, 0.5)):
        a = cv2.resize(_soft(line, sigma), None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        b = cv2.resize(_soft(edge_soft, sigma), None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        warp = best[0].copy()
        warp[:, 2] *= s
        try:
            cc, warp = cv2.findTransformECC(b, a, warp, cv2.MOTION_AFFINE,
                                            (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 150, 1e-6), None, 5)
        except cv2.error:
            continue
        warp[:, 2] /= s
        if _sane(warp, W, H) and cc > best[1]:
            best = (warp, float(cc))
    return best


def apply_affine(page: np.ndarray, warp: np.ndarray, white: bool = True) -> np.ndarray:
    H, W = page.shape[:2]
    return cv2.warpAffine(page, warp, (W, H), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                          borderMode=cv2.BORDER_CONSTANT, borderValue=255 if white else 0)


# -------------------------------------------------------------------- mesh
def fit_mesh(line: np.ndarray, edge_soft: np.ndarray, tile: int = 0, stride: int = 0,
             max_px: float = 0.0) -> tuple[np.ndarray, np.ndarray]:
    """Per-tile ECC translation (page already affine-aligned) -> dense (dx, dy)
    field in source coords. Tiles that fail or move too far vote zero.
    Tile/stride/limit default to the picture's size (384/192/4 px at 876 wide)."""
    H, W = line.shape
    k = min(W, H) / 876.0
    tile = tile or max(128, int(round(384 * k)))
    stride = stride or max(64, tile // 2)
    max_px = max_px or 4.0 * k
    a, b = _soft(line, 4.0), _soft(edge_soft, 4.0)
    ys = list(range(0, max(H - tile, 0) + 1, stride)) or [0]
    xs = list(range(0, max(W - tile, 0) + 1, stride)) or [0]
    cy = np.array([y + min(tile, H - y) / 2 for y in ys], np.float32)
    cx = np.array([x + min(tile, W - x) / 2 for x in xs], np.float32)
    grid = np.zeros((len(ys), len(xs), 2), np.float32)
    conf = np.zeros((len(ys), len(xs)), np.float32)
    for i, y in enumerate(ys):
        for j, x in enumerate(xs):
            wt = np.eye(2, 3, dtype=np.float32)
            try:
                cc, wt = cv2.findTransformECC(b[y:y + tile, x:x + tile], a[y:y + tile, x:x + tile], wt,
                                              cv2.MOTION_TRANSLATION, (3, 100, 1e-5), None, 3)
            except cv2.error:
                continue
            if abs(wt[0, 2]) <= max_px and abs(wt[1, 2]) <= max_px and cc > 0.3:
                grid[i, j] = (wt[0, 2], wt[1, 2])
                conf[i, j] = cc
    # confidence-weighted bilinear interpolation of the tile centres to every pixel
    fx = np.interp(np.arange(W, dtype=np.float32), cx, np.arange(len(xs), dtype=np.float32)).astype(np.float32)
    fy = np.interp(np.arange(H, dtype=np.float32), cy, np.arange(len(ys), dtype=np.float32)).astype(np.float32)
    mapx, mapy = [m.astype(np.float32) for m in np.meshgrid(fx, fy)]
    num = np.stack([cv2.remap(grid[..., k] * conf, mapx, mapy, cv2.INTER_LINEAR) for k in range(2)], -1)
    den = cv2.remap(conf, mapx, mapy, cv2.INTER_LINEAR)[..., None]
    field = num / np.maximum(den, 1e-3)
    field[den[..., 0] < 1e-3] = 0
    return field, grid


def apply_field(page: np.ndarray, field: np.ndarray, white: bool = True) -> np.ndarray:
    """field = where in the page each source pixel's content sits (dx, dy)."""
    H, W = page.shape[:2]
    gy, gx = np.mgrid[0:H, 0:W].astype(np.float32)
    return cv2.remap(page, gx + field[..., 0], gy + field[..., 1], cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=255 if white else 0)


# -------------------------------------------------------------------- main
def align_page(page_gray: np.ndarray, img_bgr: np.ndarray, line_threshold: int = 150,
               mesh: bool = True) -> tuple[np.ndarray, dict]:
    """Aligned page (same size as the picture, white background, 8-bit) + info.
    info['ok'] is False when the page could not be registered (kept as is)."""
    H, W = img_bgr.shape[:2]
    if page_gray.shape[:2] != (H, W):
        page_gray = cv2.resize(page_gray, (W, H), interpolation=cv2.INTER_AREA if page_gray.shape[1] > W else cv2.INTER_CUBIC)
    line0 = page_gray < line_threshold
    info = {"ok": False, "black_share": round(float(line0.mean()), 3)}
    if line0.mean() > PAGE_BLACK_LIMIT or line0.sum() < 500:
        info["reason"] = "not a line drawing"
        return page_gray, info
    edge_soft, hard = source_edges(img_bgr)
    info["before"] = line_distance(line0, hard)
    # two starts: the measured un-padded Qwen prior, and identity (padded
    # input, or any page that already sits close); keep the better fit
    warp, cc = fit_affine(line0, edge_soft)
    w2, cc2 = fit_affine(line0, edge_soft, np.eye(2, 3, dtype=np.float32))
    if cc2 > cc:
        warp, cc = w2, cc2
    info["affine"] = {"sx": round(float(warp[0, 0]), 4), "sy": round(float(warp[1, 1]), 4),
                      "tx": round(float(warp[0, 2]), 1), "ty": round(float(warp[1, 2]), 1), "cc": round(cc, 3)}
    if cc < 0:
        info["reason"] = "ecc did not converge"
        return page_gray, info
    page = apply_affine(page_gray, warp)
    info["after_affine"] = line_distance(page < line_threshold, hard)
    if mesh:
        field, grid = fit_mesh(page < line_threshold, edge_soft)
        page = apply_field(page, field)
        info["mesh_max_px"] = round(float(np.abs(grid).max()), 2)
    info["after"] = line_distance(page < line_threshold, hard)
    info["ok"] = True
    return page, info
