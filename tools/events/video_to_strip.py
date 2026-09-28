"""Turn a Grok image-to-video clip (flat green background) into a sprite strip.

    python video_to_strip.py clip.mp4 out_strip.png --frames 12 --height 360 [--start 0.2 --end 5.8] [--loop]
    python video_to_strip.py clip.mp4 --contact contact.jpg          # look at every 5th frame first

Steps: decode with ffmpeg at the clip's own fps, chroma-key every frame with
key_green.key_image, find the UNION bounding box over the picked frames (so the
figure never jumps inside its cell), fit the cell to --height pixels tall, and lay
the frames out as one horizontal strip. Prints the meta the manifest needs:
frame size, count, fps (frames / covered seconds) and the feet pivot (bottom
centre of the union box), all in the strip's own pixels.

--loop picks the frame window whose first and last frames look most alike, so
an idle or a walk cycle wraps without a jump.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_green import key_image  # noqa: E402


def decode(src: str, fps: float | None) -> tuple[list[np.ndarray], float]:
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=r_frame_rate,duration", "-of", "json", src],
        capture_output=True, text=True, check=True).stdout
    info = json.loads(probe)["streams"][0]
    num, den = info["r_frame_rate"].split("/")
    src_fps = float(num) / float(den)
    out_fps = fps or src_fps
    with tempfile.TemporaryDirectory() as td:
        subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vf", f"fps={out_fps}",
                        f"{td}/f_%04d.png"], check=True)
        files = sorted(Path(td).glob("f_*.png"))
        frames = [cv2.imread(str(f), cv2.IMREAD_COLOR) for f in files]
    return frames, out_fps


def bbox(a: np.ndarray, alpha_min: int = 10):
    ys, xs = np.where(a >= alpha_min)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def pick_loop(keyed: list[np.ndarray], count: int, min_span: int, max_span: int) -> tuple[int, int]:
    """Start index and stride whose first/last frames match best (for loops)."""
    n = len(keyed)
    best = (1e18, 0, max(1, (n - 1) // count))
    small = [cv2.resize(k[..., 3], (48, 48)).astype(np.float32) for k in keyed]
    for span in range(min_span, min(n, max_span + 1)):
        stride = span / (count)  # frames covered per step, last frame == start+span (excluded)
        for start in range(0, n - span):
            end = start + span
            if end >= n:
                break
            # a longer loop carries more motion: mild preference for span
            d = float(np.mean(np.abs(small[start] - small[end]))) * (1.0 - 0.15 * span / max_span)
            if d < best[0]:
                best = (d, start, stride)
    return best[1], best[2]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst", nargs="?")
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--height", type=int, default=360, help="cell height in output pixels")
    ap.add_argument("--start", type=float, default=0.0, help="seconds")
    ap.add_argument("--end", type=float, default=None, help="seconds")
    ap.add_argument("--loop", action="store_true")
    ap.add_argument("--contact")
    ap.add_argument("--fps", type=float, default=None, help="decode fps (default: clip's)")
    ap.add_argument("--pad", type=int, default=6)
    ap.add_argument("--max-span", type=float, default=2.5, help="longest loop, seconds")
    ap.add_argument("--min-span", type=float, default=0.0, help="shortest loop, seconds")
    ap.add_argument("--quality", type=int, default=88, help="webp quality when dst ends with .webp")
    a = ap.parse_args()

    frames, fps = decode(a.src, a.fps)
    n = len(frames)
    i0 = int(a.start * fps)
    i1 = int(a.end * fps) if a.end is not None else n
    frames = frames[i0:i1]
    keyed = [key_image(f) for f in frames]

    if a.contact:
        step = max(1, len(keyed) // 24)
        picks = keyed[::step]
        h = 200
        tiles = []
        for k in picks:
            b = bbox(k[..., 3])
            t = k if b is None else k[b[1]:b[3], b[0]:b[2]]
            t = cv2.resize(t, (max(1, int(t.shape[1] * h / t.shape[0])), h))
            rgb = t[..., :3].astype(np.float32) * (t[..., 3:4] / 255.0) + 60 * (1 - t[..., 3:4] / 255.0)
            tiles.append(rgb.astype(np.uint8))
        sheet = np.full((h + 10, sum(t.shape[1] for t in tiles) + 5 * (len(tiles) + 1), 3), 60, np.uint8)
        x = 5
        for t in tiles:
            sheet[5:5 + h, x:x + t.shape[1]] = t
            x += t.shape[1] + 5
        cv2.imwrite(a.contact, sheet, [cv2.IMWRITE_JPEG_QUALITY, 85])
        print(f"contact {a.contact}: {len(keyed)} frames at {fps:.2f} fps, showing every {step}")
        return

    if not a.dst:
        raise SystemExit("dst required")

    count = a.frames
    if a.loop:
        start, stride = pick_loop(keyed, count, min_span=max(count, int(a.min_span * fps)), max_span=int(a.max_span * fps))
    else:
        start, stride = 0, (len(keyed) - 1) / max(1, count - 1)
    idx = [min(len(keyed) - 1, int(round(start + i * stride))) for i in range(count)]
    picks = [keyed[i] for i in idx]

    # union box over the picked frames
    boxes = [bbox(k[..., 3]) for k in picks]
    boxes = [b for b in boxes if b is not None]
    x0 = min(b[0] for b in boxes) - a.pad
    y0 = min(b[1] for b in boxes) - a.pad
    x1 = max(b[2] for b in boxes) + a.pad
    y1 = max(b[3] for b in boxes) + a.pad
    H, W = picks[0].shape[:2]
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(W, x1), min(H, y1)
    cell_h = a.height
    scale = cell_h / (y1 - y0)
    cell_w = int(round((x1 - x0) * scale))

    strip = np.zeros((cell_h, cell_w * count, 4), np.uint8)
    for i, k in enumerate(picks):
        crop = k[y0:y1, x0:x1].astype(np.float32)
        al = crop[..., 3:4] / 255.0
        pre = np.dstack([crop[..., :3] * al, crop[..., 3:4]])
        small = cv2.resize(pre, (cell_w, cell_h), interpolation=cv2.INTER_AREA)
        a2 = small[..., 3:4]
        rgb = np.where(a2 > 0.5, small[..., :3] / np.maximum(a2 / 255.0, 1e-6), 0)
        strip[:, i * cell_w:(i + 1) * cell_w] = np.clip(np.dstack([rgb, a2]) + 0.5, 0, 255).astype(np.uint8)
    # PIL writes the alpha; OpenCV's WebP encoder drops it
    from PIL import Image
    rgba = np.ascontiguousarray(strip[..., [2, 1, 0, 3]])
    img = Image.fromarray(rgba, "RGBA")
    if a.dst.lower().endswith(".webp"):
        img.save(a.dst, "WEBP", quality=a.quality, method=6)
    else:
        img.save(a.dst, "PNG", optimize=True)

    covered = (idx[-1] - idx[0] + stride) / fps if count > 1 else 1
    out_fps = round(count / covered, 2)
    # feet pivot: bottom centre of the LAST rows that are opaque in the union box
    meta = {"file": Path(a.dst).name, "frameWidth": cell_w, "frameHeight": cell_h,
            "frames": count, "fps": out_fps, "pivot": {"x": cell_w // 2, "y": cell_h - a.pad},
            "sourceFrames": idx, "sourceFps": fps}
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
