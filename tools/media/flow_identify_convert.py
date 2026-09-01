"""Identify Flow green-screen cashier videos by matching their first frame to
the reference stills, then convert each to an alpha WebP loop.

Usage: flow_identify_convert.py <downloads_dir> <refs_dir> <out_root> [--since EPOCH]

- every .mp4 in downloads_dir (newer than --since) gets frame 0 extracted,
  chroma-keyed, and compared to every <name>_ref.jpg (white background
  removed) by a hue/saturation/value histogram of the foreground;
- the best match names the video: copied to <out_root>/flow_out/<name>_side.mp4
  and converted via flow_vid2webp.py into <out_root>/out/<name>.webp (+frames);
- a contact sheet <out_root>/out/_identify_sheet.jpg shows frame-0 vs the
  chosen reference so the match can be eyeballed;
- already-converted names are skipped unless --force.
"""
import sys, os, glob, subprocess, shutil, time, json
import numpy as np
from PIL import Image, ImageDraw

downloads, refs_dir, out_root = sys.argv[1], sys.argv[2], sys.argv[3]
since = float(sys.argv[sys.argv.index('--since') + 1]) if '--since' in sys.argv else 0
force = '--force' in sys.argv
here = os.path.dirname(os.path.abspath(__file__))
flow_out = os.path.join(out_root, 'flow_out'); os.makedirs(flow_out, exist_ok=True)
out_dir = os.path.join(out_root, 'out'); os.makedirs(out_dir, exist_ok=True)
state_path = os.path.join(out_dir, '_identify_state.json')
state = json.load(open(state_path)) if os.path.exists(state_path) else {}


def fg_hist(rgb, mask):
    hsv = np.asarray(Image.fromarray(rgb.astype(np.uint8)).convert('HSV')).astype(np.float32)
    h, s, v = hsv[..., 0][mask], hsv[..., 1][mask], hsv[..., 2][mask]
    if h.size == 0:
        return np.zeros(64 + 16 + 16)
    hh, _ = np.histogram(h, bins=64, range=(0, 256))
    sh, _ = np.histogram(s, bins=16, range=(0, 256))
    vh, _ = np.histogram(v, bins=16, range=(0, 256))
    f = np.concatenate([hh / h.size, sh / h.size, vh / h.size]).astype(np.float32)
    return f


def ref_feature(path):
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    # white studio background
    mask = (rgb.min(axis=2) < 225)
    return fg_hist(rgb, mask)


def frame_feature(mp4):
    tmp = os.path.join(out_dir, '_f0.png')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', mp4, '-frames:v', '1', tmp], check=True)
    rgb = np.asarray(Image.open(tmp).convert('RGB')).astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mask = (g - np.maximum(r, b)) < 40
    return fg_hist(rgb, mask), Image.open(tmp).convert('RGB')


refs = {os.path.basename(p)[:-8]: ref_feature(p) for p in sorted(glob.glob(os.path.join(refs_dir, '*_ref.jpg')))}
print('refs', list(refs))

rows = []
for mp4 in sorted(glob.glob(os.path.join(downloads, '*.mp4')), key=os.path.getmtime):
    if os.path.getmtime(mp4) < since:
        continue
    base = os.path.basename(mp4)
    if base in state and not force:
        continue
    feat, frame = frame_feature(mp4)
    scores = {n: float(np.abs(feat - f).sum()) for n, f in refs.items()}
    ranked = sorted(scores.items(), key=lambda kv: kv[1])
    name, best = ranked[0]
    second = ranked[1]
    print(f'{base}: {name} ({best:.3f}) next {second[0]} ({second[1]:.3f})')
    dst_mp4 = os.path.join(flow_out, f'{name}_side.mp4')
    if os.path.exists(dst_mp4) and not force:
        # a second video for the same girl: keep it under a suffix, don't clobber
        k = 2
        while os.path.exists(os.path.join(flow_out, f'{name}_side_{k}.mp4')):
            k += 1
        dst_mp4 = os.path.join(flow_out, f'{name}_side_{k}.mp4')
        tag = f'{name}_{k}'
    else:
        tag = name
    shutil.copy2(mp4, dst_mp4)
    subprocess.run([sys.executable, os.path.join(here, 'flow_vid2webp.py'), dst_mp4, out_dir, tag,
                    '--height', '720', '--fps', '24', '--xfade', '10'], check=True)
    state[base] = {'name': tag, 'score': best, 'second': second[0], 'mp4': dst_mp4, 'time': time.time()}
    json.dump(state, open(state_path, 'w'), indent=1)
    rows.append((base, tag, frame, ranked[:2]))

if rows:
    W, H = 150, 270
    sheet = Image.new('RGB', (len(rows) * (2 * W + 20), H + 30), (20, 20, 20))
    d = ImageDraw.Draw(sheet)
    for i, (base, tag, frame, ranked) in enumerate(rows):
        x = i * (2 * W + 20)
        fr = frame.copy(); fr.thumbnail((W, H)); sheet.paste(fr, (x, 0))
        ref = Image.open(os.path.join(refs_dir, f"{tag.split('_')[0]}_ref.jpg")).convert('RGB'); ref.thumbnail((W, H))
        sheet.paste(ref, (x + W + 5, 0))
        d.text((x + 2, H + 4), f'{tag} ({ranked[0][1]:.2f} / {ranked[1][0]} {ranked[1][1]:.2f})', fill=(255, 255, 0))
    sheet.save(os.path.join(out_dir, '_identify_sheet.jpg'), quality=85)
    print('sheet written')
print('done', len(rows))
