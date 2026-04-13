"""Extract frames from a single MP4 video with GPU-only BiRefNet background removal."""
import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request

# Optional self-relaunch under a specific python interpreter that has CUDA onnxruntime installed.
# Set PIXEL_GUY_PYTHON to the full path of that interpreter to enable, otherwise run as-is.
_PREFERRED_PYTHON = os.environ.get("PIXEL_GUY_PYTHON", "")
if (
    sys.platform == "win32"
    and _PREFERRED_PYTHON
    and sys.executable.lower() != _PREFERRED_PYTHON.lower()
    and os.path.exists(_PREFERRED_PYTHON)
):
    raise SystemExit(subprocess.run([_PREFERRED_PYTHON, os.path.abspath(__file__), *sys.argv[1:]]).returncode)

# Lower process priority so extraction does not stall the desktop.
if sys.platform == "win32":
    import ctypes

    BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
    ctypes.windll.kernel32.SetPriorityClass(
        ctypes.windll.kernel32.GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS
    )


def _add_cuda_dll_dirs() -> None:
    """Expose common NVIDIA wheel DLL folders before importing onnxruntime."""
    home = os.path.expanduser("~")
    candidate_roots = [
        os.path.join(home, "AppData", "Roaming", "Python", "Python314", "site-packages", "nvidia"),
        os.path.join(home, "AppData", "Roaming", "Python", "Python312", "site-packages", "nvidia"),
        os.path.join(home, "AppData", "Local", "Programs", "Python", "Python314", "Lib", "site-packages", "nvidia"),
        os.path.join(home, "AppData", "Local", "Programs", "Python", "Python312", "Lib", "site-packages", "nvidia"),
    ]
    suffixes = [
        ("cudnn", "bin"),
        ("cublas", "bin"),
        ("cuda_nvrtc", "bin"),
        ("cufft", "bin"),
        ("curand", "bin"),
    ]
    for root in candidate_roots:
        for package_name, bin_dir in suffixes:
            path = os.path.join(root, package_name, bin_dir)
            if os.path.isdir(path):
                os.add_dll_directory(path)
                os.environ["PATH"] = path + os.pathsep + os.environ.get("PATH", "")


_add_cuda_dll_dirs()

import cv2
import numpy as np
import onnxruntime as ort
from PIL import Image

MODELS_DIR = os.path.expanduser("~/.u2net")
MODEL_FILE = "birefnet-general.onnx"
FP16_MODEL_FILE = "birefnet-general-fp16.onnx"
MODEL_URL = "https://github.com/danielgatis/rembg/releases/download/v0.0.0/BiRefNet-general-epoch_244.onnx"
MEAN = np.array((0.485, 0.456, 0.406), dtype=np.float32).reshape(1, 1, 3)
STD = np.array((0.229, 0.224, 0.225), dtype=np.float32).reshape(1, 1, 3)


def _sigmoid(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, -60.0, 60.0)
    return 1.0 / (1.0 + np.exp(-x))


def _require_gpu_session(model_path: str) -> tuple[ort.InferenceSession, str, int]:
    providers = [("CUDAExecutionProvider", {"do_copy_in_default_stream": "1"}), "CPUExecutionProvider"]
    sess_opts = ort.SessionOptions()
    sess_opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    sess_opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    print("Loading BiRefNet model...")
    sys.stdout.flush()
    session = ort.InferenceSession(model_path, sess_options=sess_opts, providers=providers)
    active = session.get_providers()
    if not active or active[0] != "CUDAExecutionProvider":
        print(f"ERROR: CUDAExecutionProvider not active. Got {active}")
        sys.stdout.flush()
        sys.exit(1)
    input_meta = session.get_inputs()[0]
    input_shape = input_meta.shape
    if len(input_shape) < 4 or not isinstance(input_shape[2], int) or not isinstance(input_shape[3], int):
        print(f"ERROR: Unexpected BiRefNet input shape: {input_shape}")
        sys.stdout.flush()
        sys.exit(1)
    input_size = input_shape[2]
    if input_shape[2] != input_shape[3]:
        print(f"ERROR: Non-square BiRefNet input shape is unsupported: {input_shape}")
        sys.stdout.flush()
        sys.exit(1)
    print(f"Model loaded! GPU active with BiRefNet at {input_size}x{input_size}")
    sys.stdout.flush()
    return session, input_meta.name, input_size


def _ensure_model(model_path: str) -> None:
    if os.path.exists(model_path):
        return
    os.makedirs(MODELS_DIR, exist_ok=True)
    print(f"BiRefNet model not found at {model_path}")
    print(f"Downloading from {MODEL_URL}...")
    sys.stdout.flush()
    urllib.request.urlretrieve(MODEL_URL, model_path)
    print("Downloaded BiRefNet")
    sys.stdout.flush()


def _ensure_fp16_model(fp32_model_path: str) -> str:
    fp16_model_path = os.path.join(MODELS_DIR, FP16_MODEL_FILE)
    if os.path.exists(fp16_model_path):
        return fp16_model_path

    print("Converting BiRefNet to FP16 for faster CUDA inference...")
    sys.stdout.flush()
    import onnx
    from onnxconverter_common import float16

    model = onnx.load(fp32_model_path)
    model_fp16 = float16.convert_float_to_float16(model, keep_io_types=True)
    onnx.save(model_fp16, fp16_model_path)
    print(f"Saved FP16 BiRefNet model: {fp16_model_path}")
    sys.stdout.flush()
    return fp16_model_path


def _remove_bg(
    pil_img: Image.Image,
    session: ort.InferenceSession,
    input_name: str,
    input_size: int,
    gamma: float,
    threshold: float,
) -> Image.Image:
    orig_w, orig_h = pil_img.size
    img = pil_img.convert("RGB").resize((input_size, input_size), Image.LANCZOS)
    arr = (np.array(img, dtype=np.float32) / 255.0 - MEAN) / STD
    tensor = arr.transpose(2, 0, 1)[np.newaxis].astype(np.float32)
    results = session.run(None, {input_name: tensor})
    mask = results[0][0, 0]
    mask = _sigmoid(mask)
    mask = (mask - mask.min()) / (mask.max() - mask.min() + 1e-8)
    if gamma != 1.0:
        mask = np.power(mask, gamma)
    if threshold < 1.0:
        mask = np.where(mask < threshold, 0, (mask - threshold) / (1.0 - threshold))
    mask = (np.clip(mask, 0, 1) * 255).astype(np.uint8)
    mask_img = Image.fromarray(mask).resize((orig_w, orig_h), Image.LANCZOS)
    rgba = pil_img.convert("RGBA")
    rgba.putalpha(mask_img)
    return rgba


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="Path to MP4 video")
    parser.add_argument("--output", required=True, help="Output directory for frames")
    parser.add_argument("--no-rembg", action="store_true", help="Skip background removal")
    parser.add_argument("--threshold", type=float, default=1.0, help="Hard cutoff 0.0-1.0 (1.0=disabled)")
    parser.add_argument("--gamma", type=float, default=1.0, help="Mask gamma: <1=soft, 1=original, >1=sharp")
    parser.add_argument("--keep-originals", action="store_true", default=True, help="Save original frames to originals/ subfolder")
    parser.add_argument("--no-originals", action="store_true", help="Do not save original frames")
    parser.add_argument("--model", default="birefnet", help="Ignored. BiRefNet is always used.")
    args = parser.parse_args()

    if args.no_originals:
        args.keep_originals = False

    if args.model.lower() != "birefnet":
        print(f"INFO: requested model '{args.model}' ignored. Using BiRefNet.")
        sys.stdout.flush()

    os.makedirs(args.output, exist_ok=True)
    originals_dir = os.path.join(args.output, "originals")
    if args.keep_originals and not args.no_rembg:
        os.makedirs(originals_dir, exist_ok=True)

    session = None
    input_name = None
    input_size = None
    if not args.no_rembg:
        model_path = os.path.join(MODELS_DIR, MODEL_FILE)
        _ensure_model(model_path)
        model_path = _ensure_fp16_model(model_path)
        session, input_name, input_size = _require_gpu_session(model_path)

    cap = cv2.VideoCapture(args.input)
    if not cap.isOpened():
        print(f"ERROR: Cannot open {args.input}")
        return 1

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    print(f"Video: {width}x{height}, {total_frames} frames, {fps:.1f} fps")
    sys.stdout.flush()

    count = 0
    start = time.time()
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb)

        if args.keep_originals and not args.no_rembg:
            pil_img.save(os.path.join(originals_dir, f"frame_{count:03d}.png"))

        if not args.no_rembg:
            pil_img = _remove_bg(pil_img, session, input_name, input_size, args.gamma, args.threshold)

        pil_img.save(os.path.join(args.output, f"frame_{count:03d}.png"))
        count += 1
        if count % 5 == 0 or count <= 3:
            print(f"PROGRESS:{count}/{total_frames}")
            sys.stdout.flush()

    cap.release()

    meta = {
        "frame_count": count,
        "original_fps": fps,
        "width": width,
        "height": height,
        "model": "birefnet" if not args.no_rembg else "none",
        "gamma": args.gamma,
        "threshold": args.threshold,
        "has_originals": args.keep_originals and not args.no_rembg,
    }
    with open(os.path.join(args.output, "anim.json"), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2)

    print(f"PROGRESS:{count}/{total_frames}")
    print(f"DONE:{count} frames in {time.time() - start:.1f}s")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
