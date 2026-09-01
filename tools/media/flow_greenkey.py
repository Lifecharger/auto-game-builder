"""Chroma-key a Flow green-screen render (or a frame) to a transparent PNG.

Alpha = min(isnet matte, green-distance key); green spill removed on the
edge band. Usage: greenkey.py <in> <out.png> [--no-isnet] [--crop]
"""
import sys, os
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
use_isnet = '--no-isnet' not in sys.argv
crop = '--crop' in sys.argv

im = Image.open(src).convert('RGB')
W, H = im.size
rgb = np.asarray(im).astype(np.float32)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]

# Green-screen key: how much greener than the other channels a pixel is.
greenness = g - np.maximum(r, b)          # ~150+ on pure key, <0 on skin/cloth
key_alpha = np.clip((60 - greenness) / 50.0, 0, 1)   # 1 = keep, 0 = key out

alpha = key_alpha
if use_isnet:
    import onnxruntime as ort
    model = os.path.expanduser('~/.u2net/isnet-general-use.onnx')
    inp = im.resize((1024, 1024), Image.BILINEAR)
    x = (np.asarray(inp).astype(np.float32) / 255.0 - 0.5).transpose(2, 0, 1)[None]
    sess = ort.InferenceSession(model, providers=['CPUExecutionProvider'])
    out = sess.run(None, {sess.get_inputs()[0].name: x})[0][0][0]
    out = (out - out.min()) / (out.max() - out.min() + 1e-8)
    matte = np.asarray(Image.fromarray((out * 255).astype(np.uint8))
                       .resize((W, H), Image.BILINEAR)).astype(np.float32) / 255.0
    matte = np.clip((matte - 0.15) / 0.7, 0, 1)
    # isnet decides the silhouette; the green key only trims spill/halo.
    alpha = np.minimum(matte, np.maximum(key_alpha, matte * 0.0 + (greenness < 20)))

# Despill: pull green down to the max of red/blue where it dominates.
spill = np.clip(g - np.maximum(r, b), 0, None)
g2 = g - spill * 0.9
rgb2 = np.dstack([r, g2, b])
rgba = np.dstack([np.clip(rgb2, 0, 255), alpha * 255]).astype(np.uint8)
res = Image.fromarray(rgba, 'RGBA')
if crop:
    ys, xs = np.where(alpha > 0.03)
    res = res.crop((max(xs.min() - 6, 0), max(ys.min() - 6, 0),
                    min(xs.max() + 6, W), min(ys.max() + 6, H)))
res.save(dst, optimize=True)
print('saved', dst, res.size)
