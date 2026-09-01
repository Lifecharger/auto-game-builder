"""Turn converted alpha WebP loops into Hot Idle cashier frame sequences.

Usage: flow_build_cashier_frames.py <out_dir_with_webps> <app_assets_dir> [--height 400] [--frames 241] [--max-pixels 57600] [names...]

For each <name>.webp in out_dir (or only the given names): resample to
--height, resample the timeline to exactly --frames frames (the cashier
player expects CashierService.cashierFrameCount = 241 at 24 fps) and write
<app_assets_dir>/<name>/frame_NNN.webp. Existing folders are replaced.
"""
import sys, os, glob, shutil
import numpy as np
from PIL import Image

out_dir, assets_dir = sys.argv[1], sys.argv[2]
def opt(flag, default):
    return type(default)(sys.argv[sys.argv.index(flag) + 1]) if flag in sys.argv else default
height = opt('--height', 400); nframes = opt('--frames', 241)
# Per-frame pixel budget (default = the old 180x320 front-view frames): 241
# resident RGBA textures per cashier must stay within what low-end GPUs (and
# the emulator) tolerate — 480px side frames already blanked the gallery wall.
max_pixels = opt('--max-pixels', 57600)
names = [a for a in sys.argv[3:] if not a.startswith('--') and not a.lstrip('-').isdigit()]
webps = [os.path.join(out_dir, f'{n}.webp') for n in names] if names else sorted(glob.glob(os.path.join(out_dir, '*.webp')))

for path in webps:
    name = os.path.splitext(os.path.basename(path))[0]
    if '_' in name:  # skip duplicates like ava_2
        continue
    im = Image.open(path)
    src = []
    try:
        while True:
            src.append(im.convert('RGBA')); im.seek(im.tell() + 1)
    except EOFError:
        pass
    n = len(src)
    aspect = src[0].width / src[0].height
    h = min(height, int((max_pixels / aspect) ** 0.5))
    w = int(round(h * aspect))
    dst = os.path.join(assets_dir, name)
    shutil.rmtree(dst, ignore_errors=True); os.makedirs(dst)
    for i in range(nframes):
        # Short clips (Flow trims letterboxed frames) are tiled, not stretched,
        # so motion keeps its real speed; long clips are resampled 1:1-ish.
        j = i % n if n < nframes * 0.9 else int(round(i * n / nframes)) % n
        f = src[j].resize((w, h), Image.LANCZOS)
        f.save(os.path.join(dst, f'frame_{i:03d}.webp'), quality=80, method=4)
    total = sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst))
    print(f'{name}: {n} -> {nframes} frames, {w}x{h}, {total // 1024} KB')
