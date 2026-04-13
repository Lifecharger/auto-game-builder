"""Extract frames from MP4 videos, remove background using u2net directly (no rembg).

Usage:
    python extract_all.py [--chars-dir PATH] [--downloads-dir PATH]

Defaults:
    --chars-dir: $PIXEL_GUY_CHARS_DIR or ./assets/characters (relative to CWD)
    --downloads-dir: $PIXEL_GUY_DOWNLOADS_DIR or ~/Downloads
"""
import os, sys, time, json, glob, argparse

# Add cuDNN/cuBLAS DLL paths BEFORE importing onnxruntime
cudnn_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cudnn/bin")
cublas_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cublas/bin")
nvrtc_bin = os.path.expanduser("~/AppData/Roaming/Python/Python314/site-packages/nvidia/cuda_nvrtc/bin")
for p in [cudnn_bin, cublas_bin, nvrtc_bin]:
    if os.path.isdir(p):
        os.add_dll_directory(p)
        os.environ["PATH"] = p + os.pathsep + os.environ.get("PATH", "")
        print(f"Added DLL path: {p}")
sys.stdout.flush()

import cv2
import numpy as np
from PIL import Image
import onnxruntime as ort

print(f"onnxruntime providers: {ort.get_available_providers()}")
sys.stdout.flush()

# Load u2net model directly - skip rembg entirely
MODEL_PATH = os.path.expanduser("~/.u2net/u2net.onnx")
providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
print(f"Loading u2net model from {MODEL_PATH} with {providers}...")
sys.stdout.flush()
ort_session = ort.InferenceSession(MODEL_PATH, providers=providers)
input_name = ort_session.get_inputs()[0].name
print(f"Model loaded! Using: {ort_session.get_providers()}")
sys.stdout.flush()

_parser = argparse.ArgumentParser(description="Extract frames from MP4 videos with bg removal")
_parser.add_argument(
    "--chars-dir",
    default=os.environ.get("PIXEL_GUY_CHARS_DIR", os.path.abspath("./assets/characters")),
    help="Output directory for character frame folders",
)
_parser.add_argument(
    "--downloads-dir",
    default=os.environ.get("PIXEL_GUY_DOWNLOADS_DIR", os.path.expanduser("~/Downloads")),
    help="Directory to scan for source .mp4 files (in addition to --chars-dir)",
)
_args = _parser.parse_args()
CHARACTERS_DIR = _args.chars_dir
DOWNLOADS_DIR = _args.downloads_dir


def remove_bg(pil_img):
    """Remove background using u2net directly."""
    orig_w, orig_h = pil_img.size
    # Preprocess: resize to 320x320, normalize
    img = pil_img.convert("RGB").resize((320, 320), Image.LANCZOS)
    arr = np.array(img).astype(np.float32) / 255.0
    # Normalize with u2net mean/std
    mean = [0.485, 0.456, 0.406]
    std = [0.229, 0.224, 0.225]
    arr[:, :, 0] = (arr[:, :, 0] - mean[0]) / std[0]
    arr[:, :, 1] = (arr[:, :, 1] - mean[1]) / std[1]
    arr[:, :, 2] = (arr[:, :, 2] - mean[2]) / std[2]
    # CHW format, add batch dim
    tensor = np.expand_dims(arr.transpose(2, 0, 1), 0).astype(np.float32)

    # Run inference
    results = ort_session.run(None, {input_name: tensor})
    mask = results[0][0, 0]  # first output, first batch, first channel

    # Normalize mask to 0-255
    mask = (mask - mask.min()) / (mask.max() - mask.min() + 1e-8)
    mask = (mask * 255).astype(np.uint8)

    # Resize mask back to original size
    mask_img = Image.fromarray(mask).resize((orig_w, orig_h), Image.LANCZOS)

    # Apply mask as alpha channel
    rgba = pil_img.convert("RGBA")
    rgba.putalpha(mask_img)
    return rgba


def extract_and_process(mp4_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    cap = cv2.VideoCapture(mp4_path)
    if not cap.isOpened():
        print(f"  ERROR: Cannot open {mp4_path}")
        return 0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    print(f"  Video: {w}x{h}, {total_frames} frames, {fps:.1f} fps")
    sys.stdout.flush()
    count = 0
    t0 = time.time()
    for idx in range(total_frames):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            break
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb)
        result = remove_bg(pil_img)
        out_path = os.path.join(output_dir, f"frame_{count:03d}.png")
        result.save(out_path)
        count += 1
        if count % 10 == 0:
            elapsed = time.time() - t0
            fps_rate = count / elapsed if elapsed > 0 else 0
            print(f"    {count}/{total_frames} frames ({fps_rate:.1f} fps)")
            sys.stdout.flush()
    cap.release()
    meta = {"frame_count": count, "original_fps": fps, "width": w, "height": h}
    with open(os.path.join(output_dir, "anim.json"), "w") as f:
        json.dump(meta, f, indent=2)
    return count


def should_skip(output_dir, mp4_path):
    anim_json = os.path.join(output_dir, "anim.json")
    if not os.path.exists(anim_json):
        return False
    try:
        with open(anim_json) as f:
            meta = json.load(f)
        existing_count = meta.get("frame_count", 0)
        cap = cv2.VideoCapture(mp4_path)
        if not cap.isOpened():
            return False
        video_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        cap.release()
        return existing_count >= video_frames
    except Exception:
        return False


# Collect all MP4 files
mp4_files = []
for f in sorted(glob.glob(os.path.join(DOWNLOADS_DIR, "*.mp4"))):
    mp4_files.append(f)
for f in sorted(glob.glob(os.path.join(CHARACTERS_DIR, "*.mp4"))):
    mp4_files.append(f)

print(f"\nFound {len(mp4_files)} MP4 files total.\n")
sys.stdout.flush()

processed = 0
skipped = 0

for mp4_path in mp4_files:
    basename = os.path.splitext(os.path.basename(mp4_path))[0]
    output_dir = os.path.join(CHARACTERS_DIR, f"{basename}_anim")

    if should_skip(output_dir, mp4_path):
        print(f"SKIP: {basename} (already extracted)")
        skipped += 1
        continue

    print(f"\nProcessing {basename}...")
    sys.stdout.flush()
    t0 = time.time()
    n = extract_and_process(mp4_path, output_dir)
    elapsed = time.time() - t0
    print(f"  Done: {n} frames in {elapsed:.1f}s")
    sys.stdout.flush()
    processed += 1

print(f"\n{'='*50}")
print(f"All done! Processed: {processed}, Skipped: {skipped}")
