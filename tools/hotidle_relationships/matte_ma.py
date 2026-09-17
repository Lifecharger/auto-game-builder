"""Background removal v2 for the Relationships art: BiRefNet-HR + MatAnyone.

Why: the RVM + isnet recipe judged every frame on its own, so hair, fingers
and thin straps flickered and props (bunny ears) popped in and out (user
2026-09-16: "made anims even worse, flicky"). MatAnyone (CVPR 2025) is a
video matting model with memory: it takes ONE mask on the first frame and
propagates a soft alpha through the clip, so edges stay put. BiRefNet-HR
(2024) makes that first-frame mask and cuts the stills; it is far cleaner
than isnet on white-on-white.

Runs in the matting venv:  ..\\matting\\.venv\\Scripts\\python.exe matte_ma.py

    matte_ma.py <girl> --levels 2 4 7            loops of those levels
    matte_ma.py <girl> --levels 2 --stills       stills of those levels
    matte_ma.py <girl> --base [--stills]         the base outfit
    matte_ma.py                                  everything not yet done
    --suffix _ma      write L2_loop_rgba_ma.webm / L2_cut_ma.png instead of
                      the canonical names (side-by-side test runs)
    --force           redo even if the output exists

Outputs are byte-compatible with the old recipe: *_loop_rgba.webm (lossless
VP9 with alpha, source fps) and *_cut.png tagged matte="ma1".
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

import cv2
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, PngImagePlugin

ROOT = r"C:/Reusable Assets/Images/Hot Idle/relationships"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"
TAG_KEY, TAG = "matte", "ma1"
DEV = "cuda"

# BiRefNet-HR was trained at 2048x2048; feeding a 704x1280 frame upscaled is
# what the authors recommend, the mask is resized back afterwards.
BIREFNET_SIZE = (2048, 2048)
# MatAnyone: the first frame is repeated as a warm-up so the memory settles
# before the real clip starts; erode/dilate soften the seed mask so the
# network decides the exact edge itself (defaults from the authors).
N_WARMUP, R_ERODE, R_DILATE = 10, 10, 10

_birefnet = None
_matanyone = None


def birefnet():
    global _birefnet
    if _birefnet is None:
        from transformers import AutoModelForImageSegmentation
        torch.set_float32_matmul_precision("high")
        m = AutoModelForImageSegmentation.from_pretrained("ZhengPeng7/BiRefNet_HR", trust_remote_code=True)
        _birefnet = m.to(DEV).eval().half()
    return _birefnet


def matanyone():
    global _matanyone
    if _matanyone is None:
        from matanyone import InferenceCore
        _matanyone = InferenceCore("PeiqingYang/MatAnyone", device=DEV)
    return _matanyone


@torch.no_grad()
def birefnet_alpha(rgb_u8: np.ndarray) -> np.ndarray:
    """HxWx3 uint8 -> HxW float32 alpha in 0..1 at the source size."""
    from torchvision import transforms
    im = Image.fromarray(rgb_u8)
    tf = transforms.Compose([
        transforms.Resize(BIREFNET_SIZE),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    x = tf(im).unsqueeze(0).to(DEV).half()
    pred = birefnet()(x)[-1].sigmoid().float()
    pred = F.interpolate(pred, size=rgb_u8.shape[:2], mode="bilinear", align_corners=False)
    return pred[0, 0].clamp(0, 1).cpu().numpy()


def unpremultiply_white(rgb01: np.ndarray, a: np.ndarray) -> np.ndarray:
    """The renders sit on a pure white studio, so a soft edge pixel is the
    figure's colour blended with white. Solve for the figure's own colour so
    the edge carries no white rim over any background."""
    soft = (a > 0.02) & (a < 0.98)
    af = a[..., None]
    unp = np.clip((rgb01 - (1.0 - af)) / np.maximum(af, 0.05), 0.0, 1.0)
    return np.where(soft[..., None], unp, rgb01)


def cut_still(src: str, dst: str) -> float:
    rgb = np.asarray(Image.open(src).convert("RGB"))
    a = birefnet_alpha(rgb)
    rgb01 = unpremultiply_white(rgb.astype(np.float32) / 255.0, a)
    meta = PngImagePlugin.PngInfo()
    meta.add_text(TAG_KEY, TAG)
    Image.fromarray((np.dstack([rgb01, a]) * 255.0).round().astype(np.uint8), "RGBA").save(dst, pnginfo=meta)
    return float((a > 0.5).mean())


def probe_fps(path: str) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=r_frame_rate", "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip()
    n, d = out.split("/") if "/" in out else (out, "1")
    return float(n) / float(d or 1)


def _seed_mask(frame0: np.ndarray) -> torch.Tensor:
    """BiRefNet alpha on the first frame -> 0/255 mask, dilated then eroded
    the way MatAnyone's own script does, so the seed is a solid core and the
    network refines the edge."""
    a = birefnet_alpha(frame0)
    m = (a > 0.5).astype(np.float32)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (R_DILATE, R_DILATE))
    m = cv2.dilate(m, k, iterations=1)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (R_ERODE, R_ERODE))
    m = cv2.erode(m, k, iterations=1) * 255.0
    return torch.from_numpy(m).float().to(DEV)


@torch.inference_mode()
def matte_loop(src: str, dst: str) -> float:
    fps = probe_fps(src)
    tmp = tempfile.mkdtemp(prefix="ma_")
    try:
        subprocess.run([FFMPEG, "-v", "error", "-y", "-i", src, os.path.join(tmp, "f_%04d.png")], check=True)
        names = sorted(f for f in os.listdir(tmp) if f.startswith("f_"))
        load = lambda i: np.asarray(Image.open(os.path.join(tmp, names[i])).convert("RGB"))
        proc = matanyone()
        proc.clear_memory() if hasattr(proc, "clear_memory") else None
        mask = _seed_mask(load(0))
        coverage = 0.0
        n = len(names)
        # Frame index sequence: the first frame N_WARMUP times, then the clip.
        for ti in range(N_WARMUP + n):
            i = 0 if ti < N_WARMUP else ti - N_WARMUP
            rgb = load(i)
            image = torch.from_numpy(rgb).permute(2, 0, 1).float().div(255.0).to(DEV)
            if ti == 0:
                prob = proc.step(image, mask, objects=[1])
                prob = proc.step(image, first_frame_pred=True)
            elif ti <= N_WARMUP:
                prob = proc.step(image, first_frame_pred=True)
            else:
                prob = proc.step(image)
            if ti < N_WARMUP:
                continue
            a = proc.output_prob_to_mask(prob).clamp(0, 1).cpu().numpy().astype(np.float32)
            rgb01 = unpremultiply_white(rgb.astype(np.float32) / 255.0, a)
            Image.fromarray((np.dstack([rgb01, a]) * 255.0).round().astype(np.uint8), "RGBA") \
                .save(os.path.join(tmp, f"o_{i:04d}.png"))
            coverage += float((a > 0.5).mean())
        subprocess.run([FFMPEG, "-v", "error", "-y", "-framerate", str(fps),
                        "-i", os.path.join(tmp, "o_%04d.png"),
                        "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-lossless", "1",
                        "-f", "webm", dst + ".tmp"], check=True)
        os.replace(dst + ".tmp", dst)
        return coverage / max(1, n)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def girls() -> list[str]:
    return sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)) and not d.startswith("_"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("girls", nargs="*")
    ap.add_argument("--levels", nargs="*", type=int, default=[])
    ap.add_argument("--base", action="store_true")
    ap.add_argument("--stills", action="store_true")
    ap.add_argument("--suffix", default="")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    todo = []
    for g in args.girls or girls():
        d = os.path.join(ROOT, g)
        keys = [f"L{k}" for k in args.levels] if args.levels else ([] if args.base else [f"L{k}" for k in range(1, 11)])
        if args.base:
            keys.append("base")   # legacy: base.* files no longer exist after the 2026-09-16 rename
        for key in keys:
            if args.stills:
                src = os.path.join(d, f"{key}.png")
                dst = os.path.join(d, f"{key}_cut{args.suffix}.png")
            else:
                src = os.path.join(d, f"{key}_loop.mp4")
                dst = os.path.join(d, f"{key}_loop_rgba{args.suffix}.webm")
            if os.path.isfile(src) and (args.force or not os.path.isfile(dst)):
                todo.append((g, key, src, dst))
    print(f"{len(todo)} to do", flush=True)
    done = 0
    for g, key, src, dst in todo:
        t0 = time.time()
        cov = cut_still(src, dst) if args.stills else matte_loop(src, dst)
        done += 1
        print(f"  {g} {key}: figure {cov * 100:.0f}% of frame, {time.time() - t0:.0f}s", flush=True)
    print(f"BITTI: {done} done")


if __name__ == "__main__":
    main()
