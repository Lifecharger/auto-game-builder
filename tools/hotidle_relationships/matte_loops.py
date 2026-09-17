"""Cut the white studio background off the Relationships art with Robust Video Matting.

Loops:  L<n>_loop.mp4 / base_loop.mp4 (opaque, white background) -> *_loop_rgba.webm
        (VP9 with alpha, lossless, the matted master the delivery WebPs are cut from).
Stills: L<n>.png / base.png -> *_cut.png (RGBA), --stills. Same model as the loops so
        a still and its loop cut identically (user 2026-09-15: "use it on stills too").

RVM (PeterL1n/RobustVideoMatting, mobilenetv3, ONNX) runs on the CPU through
onnxruntime, so it never touches the shared GPU lane. It carries a recurrent
state across frames, which is what keeps hair edges from flickering the way a
per-frame cut-out (isnet) does. Model: ~/.u2net/rvm_mobilenetv3_fp32.onnx.

    python matte_loops.py                     # every loop that has no matte yet
    python matte_loops.py ava --levels 3      # one clip
    python matte_loops.py --stills            # every still (and base.png) -> _cut.png
    python matte_loops.py --force
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile

import numpy as np
import onnxruntime as ort
from PIL import Image, PngImagePlugin

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"C:/Reusable Assets/Images/Hot Idle/relationships"
MODEL = os.path.expanduser("~/.u2net/rvm_mobilenetv3_fp32.onnx")
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
FFPROBE = shutil.which("ffprobe") or "ffprobe"
ISNET_STEP = 4     # isnet on every 4th frame of a loop (0.17 s at 24 fps)
RECIPE_TS = 1789509128  # loop mattes written before the final recipe (rvm6) are stale
DOWNSAMPLE = 0.4   # RVM's internal working scale; 0.25 is for 4K, 0.4 suits 704x1280
TAG_KEY = "matte"  # PNG text chunk: "rvm" marks a cut made here (isnet cuts have none)


def girls() -> list[str]:
    with open(os.path.join(HERE, "ladders.json"), encoding="utf-8") as f:
        return list(json.load(f)["girls"])


def probe_fps(path: str) -> float:
    out = subprocess.run([FFPROBE, "-v", "error", "-select_streams", "v:0",
                          "-show_entries", "stream=r_frame_rate", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    num, den = (out.split("/") + ["1"])[:2]
    return float(num) / float(den or 1)


def _punch_pockets(src_rgb01, a):
    """Enclosed background pockets (between fingers, under an arm, inside a
    ponytail curl) are surrounded by figure, so the matte marks them as
    figure too. The studio background is flat pure white while any garment,
    even a white one, carries shading, so a flat pure-white patch of a few
    dozen pixels inside the figure is background: punch it out with a soft
    edge (user 2026-09-15: "hands have whites between fingers")."""
    from scipy import ndimage
    px = (src_rgb01 * 255.0)
    lum = px.mean(axis=2)
    rng = ndimage.maximum_filter(lum, 5) - ndimage.minimum_filter(lum, 5)
    # 1. Studio white that is CONNECTED to the frame edge is background, full
    #    stop: the gap between the thighs, under an arm, beside a shoe below a
    #    hem, between a flying ponytail and the shoulder all open to the
    #    outside in the source picture even when the matte closed them. A
    #    white garment never reaches the frame edge through flat white.
    #    Strict white for the flood fill so a white shirt with any shading
    #    stays out of it; then let the result creep a few pixels into softer
    #    white so a shadowed floor patch or a strand gap still clears.
    strict = (px.min(axis=2) >= 247.0) & (rng <= 6.0)
    loose = (px.min(axis=2) >= 236.0) & (rng <= 12.0)
    lab_e, n_e = ndimage.label(strict)
    if n_e:
        border = np.zeros_like(strict)
        border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
        touching = np.unique(lab_e[border & strict])
        touching = touching[touching > 0]
        if touching.size:
            outside = np.isin(lab_e, touching)
            for _ in range(6):
                outside = ndimage.binary_dilation(outside) & loose
            soft = ndimage.gaussian_filter(outside.astype(np.float32), 0.8)
            a = np.clip(a * (1.0 - soft), 0.0, 1.0)
    # 2. Fully enclosed pockets (between fingers on a hip): flat pure white
    #    walled by skin, hair or dark cloth.
    white = px.min(axis=2) >= 249.0
    flat = rng <= 4.0
    cand = white & flat & (a > 0.3)
    lab, n = ndimage.label(cand)
    if n == 0:
        return a
    sizes = ndimage.sum(cand, lab, index=np.arange(1, n + 1))
    keep = np.zeros(n + 1, dtype=bool)
    nonwhite = px.min(axis=2) < 235.0
    for i in range(1, n + 1):
        if sizes[i - 1] < 20:
            continue
        comp = lab == i
        # A real pocket is walled by skin, hair or dark cloth; a flat patch on a
        # white garment is walled by more white fabric. Look at the ring
        # around the patch and only punch when most of it is not white.
        ring = ndimage.binary_dilation(comp, iterations=3) & ~comp
        if ring.any() and nonwhite[ring].mean() >= 0.6:
            keep[i] = True
    hole = keep[lab]
    # grow one pixel into the anti-aliased rim, then feather
    hole = ndimage.binary_dilation(hole, iterations=1)
    soft = ndimage.gaussian_filter(hole.astype(np.float32), 0.8)
    return np.clip(a * (1.0 - soft), 0.0, 1.0)


def _clean(fgr_chw, pha_hw, src_chw=None):
    """Kill the light fringe RVM leaves on hair and shoulders against a white
    studio: where the matte is soft, un-premultiply the colour against white
    and tighten the alpha, so an edge shows the strand's own colour over any
    background instead of a whitish rim (user 2026-09-15)."""
    a = np.clip(pha_hw, 0.0, 1.0)
    rgb = np.clip(fgr_chw.transpose(1, 2, 0), 0.0, 1.0)
    soft = (a > 0.02) & (a < 0.98)
    af = a[..., None]
    unp = np.clip((rgb - (1.0 - af)) / np.maximum(af, 0.05), 0.0, 1.0)
    rgb = np.where(soft[..., None], unp, rgb)
    a = a ** 1.4
    if src_chw is not None:
        src = np.clip(src_chw.transpose(1, 2, 0), 0.0, 1.0)
        a = _punch_pockets(src, a)
    return rgb, a


ISNET = os.path.expanduser("~/.u2net/isnet-general-use.onnx")
_isnet_sess = None


def _isnet_alpha(rgb01_hwc, size: int = 1024):
    """isnet (DIS) alpha for one frame. Trained for dichotomous segmentation
    with thin structures and holes, so it sees the white between fishnet
    threads or under a sleeve that RVM reads as figure. Returned as a soft
    mask in [0,1] at the frame's own size."""
    global _isnet_sess
    if _isnet_sess is None:
        _isnet_sess = ort.InferenceSession(ISNET, providers=["CPUExecutionProvider"])
    h, w = rgb01_hwc.shape[:2]
    im = Image.fromarray((rgb01_hwc * 255.0).astype(np.uint8)).resize((size, size), Image.BILINEAR)
    x = ((np.asarray(im).astype(np.float32) / 255.0) - 0.5).transpose(2, 0, 1)[None]
    out = _isnet_sess.run(None, {_isnet_sess.get_inputs()[0].name: x})[0][0][0]
    out = (out - out.min()) / (out.max() - out.min() + 1e-8)
    m = np.asarray(Image.fromarray((out * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)).astype(np.float32) / 255.0
    # soften the decision band so the cut never looks stepped
    return np.clip((m - 0.15) / 0.45, 0.0, 1.0)


def _combine(rgb, a, isn, src):
    """RVM owns the soft edges; isnet owns holes AND props. Where isnet is
    sure it is background, cut it; where isnet is sure it is figure but RVM
    dropped it (bunny ears, cat ears, horns, hats, a staff: RVM is a person
    matter and treats props as scenery, user 2026-09-16), add it back with
    the source colour, since RVM's colour estimate is garbage there."""
    out = np.minimum(a, isn)
    sure = isn >= 0.85
    out = np.where(sure, np.maximum(out, isn), out)
    rgb = np.where(((a < 0.2) & sure)[..., None], src, rgb)
    return rgb, out


def _run(sess, x, rec, ds):
    fgr, pha, *rec = sess.run(None, {"src": x, "r1i": rec[0], "r2i": rec[1],
                                     "r3i": rec[2], "r4i": rec[3], "downsample_ratio": ds})
    return fgr, pha, rec


def matte(sess: ort.InferenceSession, src: str, dst: str) -> float:
    fps = probe_fps(src)
    tmp = tempfile.mkdtemp(prefix="rvm_")
    try:
        subprocess.run([FFMPEG, "-v", "error", "-y", "-i", src, os.path.join(tmp, "f_%04d.png")], check=True)
        frames = sorted(f for f in os.listdir(tmp) if f.startswith("f_"))
        rec = [np.zeros((1, 1, 1, 1), dtype=np.float32)] * 4
        ds = np.array([DOWNSAMPLE], dtype=np.float32)
        coverage = 0.0
        # Two opinions: RVM owns the soft edges frame by frame; isnet owns the
        # holes (white through fishnet, a pocket walled by a white shirt) and
        # runs on every ISNET_STEP-th frame, interpolated in between: holes
        # move slowly, and full-rate isnet on the CPU would take 5 min a clip.
        # Frames stay on disk and are read as uint8 one at a time: a whole
        # clip as float32 was 1.5 GB and got the pass killed next to LTX.
        def load(i):
            return np.asarray(Image.open(os.path.join(tmp, frames[i])).convert("RGB")).astype(np.float32) / 255.0
        keys = list(range(0, len(frames), ISNET_STEP))
        if keys[-1] != len(frames) - 1:
            keys.append(len(frames) - 1)
        key_masks = {k: _isnet_alpha(load(k)).astype(np.float16) for k in keys}
        def isnet_at(i):
            lo = max(k for k in keys if k <= i)
            hi = min(k for k in keys if k >= i)
            if lo == hi:
                return key_masks[lo].astype(np.float32)
            t = (i - lo) / (hi - lo)
            return (key_masks[lo].astype(np.float32) * (1 - t) + key_masks[hi].astype(np.float32) * t)
        for i in range(len(frames)):
            src = load(i)
            x = src.transpose(2, 0, 1)[None]
            fgr, pha, rec = _run(sess, x, rec, ds)
            rgb, a = _clean(fgr[0], pha[0, 0], x[0])
            rgb, a = _combine(rgb, a, isnet_at(i), src)
            Image.fromarray((np.dstack([rgb, a]) * 255.0).astype(np.uint8), "RGBA") \
                .save(os.path.join(tmp, f"o_{i:04d}.png"))
            coverage += float((a > 0.5).mean())
        subprocess.run([FFMPEG, "-v", "error", "-y", "-framerate", str(fps),
                        "-i", os.path.join(tmp, "o_%04d.png"),
                        "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-lossless", "1",
                        "-f", "webm", dst + ".tmp"], check=True)
        os.replace(dst + ".tmp", dst)
        return coverage / max(1, len(frames))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def matte_still(sess: ort.InferenceSession, src: str, dst: str) -> float:
    """One still through RVM as a one-frame video. Two passes: the recurrent
    state from the first pass settles the matte on the second."""
    im = Image.open(src).convert("RGB")
    x = (np.asarray(im).astype(np.float32) / 255.0).transpose(2, 0, 1)[None]
    rec = [np.zeros((1, 1, 1, 1), dtype=np.float32)] * 4
    ds = np.array([DOWNSAMPLE], dtype=np.float32)
    for _ in range(2):
        fgr, pha, rec = _run(sess, x, rec, ds)
    rgb, a = _clean(fgr[0], pha[0, 0], x[0])
    rgb, a = _combine(rgb, a, _isnet_alpha(x[0].transpose(1, 2, 0)), x[0].transpose(1, 2, 0))
    meta = PngImagePlugin.PngInfo()
    meta.add_text(TAG_KEY, "rvm7")
    Image.fromarray((np.dstack([rgb, a]) * 255.0).astype(np.uint8), "RGBA").save(dst, pnginfo=meta)
    return float((a > 0.5).mean())


def is_rvm_cut(path: str) -> bool:
    try:
        return Image.open(path).info.get(TAG_KEY) == "rvm7"
    except OSError:
        return False


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("girls", nargs="*")
    ap.add_argument("--levels", default="", help="comma list; default every level incl. base")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--stills", action="store_true",
                    help="cut the stills (L<n>.png, base.png -> *_cut.png) instead of the loops")
    a = ap.parse_args()
    names = a.girls or girls()
    wanted = {int(x) for x in a.levels.split(",") if x.strip()}
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    done = skipped = 0
    if a.stills:
        for g in names:
            d = os.path.join(SRC, g)
            tags = ([f"L{n}" for n in range(2, 11)] + ["base"]) if not wanted else [f"L{n}" for n in sorted(wanted)]
            for tag in tags:
                src, dst = os.path.join(d, tag + ".png"), os.path.join(d, tag + "_cut.png")
                if not os.path.isfile(src):
                    continue
                if (os.path.isfile(dst) and not a.force and is_rvm_cut(dst)
                        and os.path.getmtime(dst) >= os.path.getmtime(src)):
                    skipped += 1
                    continue
                cov = matte_still(sess, src, dst)
                done += 1
                print(f"  {g} {tag}: RVM cut, figure {cov * 100:.0f}% of frame", flush=True)
        print(f"BITTI: {done} cut, {skipped} skipped", flush=True)
        return
    for g in names:
        d = os.path.join(SRC, g)
        tags = ([f"L{n}_loop" for n in range(2, 11)] + ["base_loop"]) if not wanted \
            else [f"L{n}_loop" for n in sorted(wanted)]
        for tag in tags:
            src = os.path.join(d, tag + ".mp4")
            dst = os.path.join(d, tag + "_rgba.webm")
            if not os.path.isfile(src):
                continue
            if (os.path.isfile(dst) and not a.force and os.path.getmtime(dst) >= os.path.getmtime(src)
                    and os.path.getmtime(dst) >= RECIPE_TS):
                skipped += 1
                continue
            cov = matte(sess, src, dst)
            done += 1
            print(f"  {g} {tag}: matted, figure {cov * 100:.0f}% of frame", flush=True)
    print(f"BITTI: {done} matted, {skipped} skipped", flush=True)


if __name__ == "__main__":
    main()
