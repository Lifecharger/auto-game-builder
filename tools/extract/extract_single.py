"""Extract frames from a single MP4 video, remove background using segmentation models."""
import os, sys, time, json, argparse

# Lower process priority so extraction doesn't freeze the system.
if sys.platform == "win32":
    import ctypes
    BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
    ctypes.windll.kernel32.SetPriorityClass(
        ctypes.windll.kernel32.GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS
    )

# Add cuDNN/cuBLAS DLL paths BEFORE importing onnxruntime
cudnn_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cudnn/bin")
cublas_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cublas/bin")
nvrtc_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cuda_nvrtc/bin")
for p in [cudnn_bin, cublas_bin, nvrtc_bin]:
    if os.path.isdir(p):
        os.add_dll_directory(p)
        os.environ["PATH"] = p + os.pathsep + os.environ.get("PATH", "")

import cv2
import numpy as np
from PIL import Image
import onnxruntime as ort

MODELS_DIR = os.path.expanduser("~/.u2net")

AVAILABLE_MODELS = {
    "u2net": {
        "file": "u2net.onnx",
        "size": 320,
        "url": "https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx",
        "mean": (0.485, 0.456, 0.406),
        "std": (0.229, 0.224, 0.225),
        "sigmoid": False,
    },
    "u2netp": {
        "file": "u2netp.onnx",
        "size": 320,
        "url": "https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2netp.onnx",
        "mean": (0.485, 0.456, 0.406),
        "std": (0.229, 0.224, 0.225),
        "sigmoid": False,
    },
    "isnet": {
        "file": "isnet-general-use.onnx",
        "size": 1024,
        "url": "https://github.com/danielgatis/rembg/releases/download/v0.0.0/isnet-general-use.onnx",
        "mean": (0.5, 0.5, 0.5),
        "std": (1.0, 1.0, 1.0),
        "sigmoid": False,
    },
    "birefnet": {
        "file": "birefnet-general.onnx",
        "size": 1024,
        "url": "https://github.com/danielgatis/rembg/releases/download/v0.0.0/BiRefNet-general-epoch_244.onnx",
        "mean": (0.485, 0.456, 0.406),
        "std": (0.229, 0.224, 0.225),
        "sigmoid": True,
    },
    "silueta": {
        "file": "silueta.onnx",
        "size": 320,
        "url": "https://github.com/danielgatis/rembg/releases/download/v0.0.0/silueta.onnx",
        "mean": (0.485, 0.456, 0.406),
        "std": (0.229, 0.224, 0.225),
        "sigmoid": False,
    },
}

parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True, help="Path to MP4 video")
parser.add_argument("--output", required=True, help="Output directory for frames")
parser.add_argument("--no-rembg", action="store_true", help="Skip background removal")
parser.add_argument("--threshold", type=float, default=1.0, help="Hard cutoff 0.0-1.0 (1.0=disabled)")
parser.add_argument("--gamma", type=float, default=1.0, help="Mask gamma: <1=soft, 1=original, >1=sharp")
parser.add_argument("--model", type=str, default="u2net", choices=list(AVAILABLE_MODELS.keys()), help="Segmentation model")
parser.add_argument("--keep-originals", action="store_true", default=True, help="Save original frames to originals/ subfolder")
parser.add_argument("--no-originals", action="store_true", help="Don't save original frames")
args = parser.parse_args()
if args.no_originals:
    args.keep_originals = False

model_info = AVAILABLE_MODELS[args.model]
model_path = os.path.join(MODELS_DIR, model_info["file"])
input_size = model_info["size"]
mean = model_info["mean"]
std = model_info["std"]
use_sigmoid = model_info["sigmoid"]

if not args.no_rembg:
    # Check if model exists, download if not
    if not os.path.exists(model_path):
        print(f"Model {args.model} not found at {model_path}")
        print(f"Downloading from {model_info['url']}...")
        sys.stdout.flush()
        import urllib.request
        os.makedirs(MODELS_DIR, exist_ok=True)
        urllib.request.urlretrieve(model_info["url"], model_path)
        print(f"Downloaded {args.model}!")
        sys.stdout.flush()

    # CUDA for model inference, CPU only as fallback for unsupported ops (not the whole model)
    providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
    sess_opts = ort.SessionOptions()
    sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    sess_opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    print(f"Loading {args.model} model...")
    sys.stdout.flush()
    ort_session = ort.InferenceSession(model_path, sess_options=sess_opts, providers=providers)
    input_name = ort_session.get_inputs()[0].name
    active = ort_session.get_providers()
    if active[0] != "CUDAExecutionProvider":
        print(f"ERROR: GPU not available (got {active}). Refusing to run on CPU only.")
        sys.stdout.flush()
        sys.exit(1)
    print(f"Model loaded! GPU active")
    sys.stdout.flush()

    # Precompute normalization arrays
    _mean = np.array(mean, dtype=np.float32).reshape(1, 1, 3)
    _std = np.array(std, dtype=np.float32).reshape(1, 1, 3)

    def remove_bg(pil_img):
        orig_w, orig_h = pil_img.size
        img = pil_img.convert("RGB").resize((input_size, input_size), Image.LANCZOS)
        arr = (np.array(img, dtype=np.float32) / 255.0 - _mean) / _std
        tensor = arr.transpose(2, 0, 1)[np.newaxis].astype(np.float32)
        results = ort_session.run(None, {input_name: tensor})
        mask = results[0][0, 0]
        if use_sigmoid:
            mask = 1.0 / (1.0 + np.exp(-mask))
        mask = (mask - mask.min()) / (mask.max() - mask.min() + 1e-8)
        if args.gamma != 1.0:
            mask = np.power(mask, args.gamma)
        if args.threshold < 1.0:
            mask = np.where(mask < args.threshold, 0, (mask - args.threshold) / (1.0 - args.threshold))
        mask = (np.clip(mask, 0, 1) * 255).astype(np.uint8)
        mask_img = Image.fromarray(mask).resize((orig_w, orig_h), Image.LANCZOS)
        rgba = pil_img.convert("RGBA")
        rgba.putalpha(mask_img)
        return rgba

os.makedirs(args.output, exist_ok=True)
originals_dir = os.path.join(args.output, "originals")
if args.keep_originals and not args.no_rembg:
    os.makedirs(originals_dir, exist_ok=True)

cap = cv2.VideoCapture(args.input)
if not cap.isOpened():
    print(f"ERROR: Cannot open {args.input}")
    sys.exit(1)

total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
fps = cap.get(cv2.CAP_PROP_FPS)
w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
print(f"Video: {w}x{h}, {total_frames} frames, {fps:.1f} fps")
sys.stdout.flush()

count = 0
t0 = time.time()
while True:
    ret, frame = cap.read()
    if not ret:
        break
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(rgb)

    # Save original before bg removal
    if args.keep_originals and not args.no_rembg:
        orig_path = os.path.join(originals_dir, f"frame_{count:03d}.png")
        pil_img.save(orig_path)

    if not args.no_rembg:
        pil_img = remove_bg(pil_img)

    out_path = os.path.join(args.output, f"frame_{count:03d}.png")
    pil_img.save(out_path)
    count += 1
    if count % 5 == 0 or count <= 3:
        print(f"PROGRESS:{count}/{total_frames}")
        sys.stdout.flush()

cap.release()
meta = {
    "frame_count": count, "original_fps": fps, "width": w, "height": h,
    "model": args.model if not args.no_rembg else "none",
    "gamma": args.gamma, "threshold": args.threshold,
    "has_originals": args.keep_originals and not args.no_rembg,
}
with open(os.path.join(args.output, "anim.json"), "w") as f:
    json.dump(meta, f, indent=2)

print(f"PROGRESS:{count}/{total_frames}")
print(f"DONE:{count} frames in {time.time() - t0:.1f}s")
