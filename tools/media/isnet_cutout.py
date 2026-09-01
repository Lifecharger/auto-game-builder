"""Cut the Flow table out with isnet (onnxruntime directly - rembg import hangs on this box)."""
import sys, os
import numpy as np
import onnxruntime as ort
from PIL import Image

src = sys.argv[1]
dst = sys.argv[2]
model = os.path.expanduser('~/.u2net/isnet-general-use.onnx')

im = Image.open(src).convert('RGB')
W, H = im.size
inp = im.resize((1024, 1024), Image.BILINEAR)
x = np.asarray(inp).astype(np.float32) / 255.0
x = (x - 0.5) / 1.0
x = x.transpose(2, 0, 1)[None]

sess = ort.InferenceSession(model, providers=['CPUExecutionProvider'])
name = sess.get_inputs()[0].name
out = sess.run(None, {name: x})[0][0][0]
out = (out - out.min()) / (out.max() - out.min() + 1e-8)
alpha = Image.fromarray((out * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
a = np.asarray(alpha).astype(np.float32)

# White studio background: sharpen the matte a little so the gap between the
# legs is fully clear and the wood edge is crisp.
a = np.clip((a - 40) * (255.0 / (255 - 40)), 0, 255)
rgb = np.asarray(im).astype(np.float32)
# Un-premultiply against white so light edges don't keep a white halo.
af = (a / 255.0)[..., None]
rgb_clean = np.clip((rgb - 255.0 * (1 - af)) / np.maximum(af, 1e-3), 0, 255)
rgb_out = np.where(af > 0.02, rgb_clean, rgb)
rgba = np.dstack([rgb_out, a]).astype(np.uint8)
res = Image.fromarray(rgba, 'RGBA')

# Crop to content with a small margin.
ys, xs = np.where(a > 8)
x0, x1 = max(xs.min() - 8, 0), min(xs.max() + 8, W)
y0, y1 = max(ys.min() - 8, 0), min(ys.max() + 8, H)
res = res.crop((x0, y0, x1, y1))
res.save(dst, optimize=True)
print('saved', dst, res.size, 'alpha coverage %.1f%%' % (100 * (a > 128).mean()))
