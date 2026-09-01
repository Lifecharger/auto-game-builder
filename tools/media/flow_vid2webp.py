"""Green-screen mp4 -> alpha animated WebP loop (+ still + frame folder).

Usage: vid2webp.py <in.mp4> <out_dir> <name> [--height 720] [--fps 24] [--xfade 10]

- frames extracted with ffmpeg at --fps
- chroma key per frame (green distance), despill, common crop box over ALL
  frames (so nothing shifts), resized to --height
- seam: last --xfade frames cross-faded into the first ones so the loop wraps
- writes <name>.webp (animated, alpha), <name>_still.png (frame 0) and
  frames/<name>/frame_NNN.webp (the cashier frame-sequence format)
"""
import sys, os, subprocess, glob, shutil
import numpy as np
from PIL import Image

src, out_dir, name = sys.argv[1], sys.argv[2], sys.argv[3]
def opt(flag, default):
    return type(default)(sys.argv[sys.argv.index(flag) + 1]) if flag in sys.argv else default
height = opt('--height', 720); fps = opt('--fps', 24); xfade = opt('--xfade', 10)

work = os.path.join(out_dir, '_frames_' + name)
shutil.rmtree(work, ignore_errors=True); os.makedirs(work)
subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', src, '-vf', f'fps={fps}',
                os.path.join(work, 'f_%04d.png')], check=True)
files = sorted(glob.glob(os.path.join(work, 'f_*.png')))
print('frames', len(files))

# Letterboxed frames (Flow pads the still to 9:16 with black bars on the
# first/last frames of some clips): drop any frame whose top rows are black.
def letterboxed(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    top = a[: max(4, a.shape[0] // 40)]
    return top.mean() < 20
kept = [f for f in files if not letterboxed(f)]
if len(kept) != len(files):
    print('dropped letterboxed frames:', len(files) - len(kept))
files = kept

def key(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip((55 - greenness) / 45.0, 0, 1)
    # Residual letterbox bars: full-width near-black rows at the very top or
    # bottom edge are padding, not the subject (hair never spans the width).
    dark_row = (rgb.max(axis=2) < 16).mean(axis=1) > 0.9
    for rows in (range(rgb.shape[0]), range(rgb.shape[0] - 1, -1, -1)):
        for y in rows:
            if not dark_row[y]:
                break
            alpha[y] = 0
    # kill faint green fringes: anything still clearly green at low alpha -> 0
    alpha = np.where((greenness > 40) & (alpha < 0.6), 0, alpha)
    spill = np.clip(greenness, 0, None)
    g2 = g - spill * 0.9
    return np.dstack([r, g2, b]), alpha

rgbs, alphas = [], []
for f in files:
    rgb = np.asarray(Image.open(f).convert('RGB')).astype(np.float32)
    c, a = key(rgb); rgbs.append(c); alphas.append(a)
union = np.max(np.stack(alphas), axis=0) > 0.05
ys, xs = np.where(union)
x0, x1 = max(xs.min() - 8, 0), min(xs.max() + 8, union.shape[1])
y0, y1 = max(ys.min() - 8, 0), min(ys.max() + 8, union.shape[0])
print('crop', (x0, y0, x1, y1))

frames = []
for c, a in zip(rgbs, alphas):
    rgba = np.dstack([np.clip(c, 0, 255), a * 255]).astype(np.uint8)[y0:y1, x0:x1]
    im = Image.fromarray(rgba, 'RGBA')
    w = int(round(im.width * height / im.height))
    frames.append(im.resize((w, height), Image.LANCZOS))

# Seam cross-fade: blend the tail into the head so wrap is smooth.
n = len(frames)
if xfade > 0 and n > 2 * xfade:
    head = [np.asarray(f).astype(np.float32) for f in frames[:xfade]]
    tail = [np.asarray(f).astype(np.float32) for f in frames[n - xfade:]]
    for i in range(xfade):
        t = (i + 1) / (xfade + 1)
        mixed = tail[i] * (1 - t) + head[i] * t
        frames[n - xfade + i] = Image.fromarray(mixed.astype(np.uint8), 'RGBA')

os.makedirs(out_dir, exist_ok=True)
webp = os.path.join(out_dir, f'{name}.webp')
frames[0].save(webp, save_all=True, append_images=frames[1:], duration=int(1000 / fps),
               loop=0, quality=82, method=4, lossless=False)
frames[0].save(os.path.join(out_dir, f'{name}_still.png'))
fdir = os.path.join(out_dir, 'frames', name)
shutil.rmtree(fdir, ignore_errors=True); os.makedirs(fdir)
for i, f in enumerate(frames):
    f.save(os.path.join(fdir, f'frame_{i:03d}.webp'), quality=82, method=4)
shutil.rmtree(work, ignore_errors=True)
print('webp', webp, os.path.getsize(webp) // 1024, 'KB', frames[0].size, n, 'frames')
