import os, sys, time, json, glob
import cv2
import numpy as np
from PIL import Image
from rembg import remove, new_session

print("Loading rembg model...")
session = new_session("u2net")

CHARACTERS_DIR = "C:/Projects/Pixel Guy/assets/characters"
DOWNLOADS_DIR = "C:/Users/caca_/Downloads"

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
    count = 0
    for idx in range(total_frames):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            break
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(rgb)
        result = remove(pil_img, session=session)
        out_path = os.path.join(output_dir, f"frame_{count:03d}.png")
        result.save(out_path)
        count += 1
        if count % 10 == 0:
            print(f"    Processed {count}/{total_frames} frames...")
    cap.release()
    meta = {"frame_count": count, "original_fps": fps, "width": w, "height": h}
    with open(os.path.join(output_dir, "anim.json"), "w") as f:
        json.dump(meta, f, indent=2)
    return count

def should_skip(output_dir, mp4_path):
    """Skip if anim.json exists and frame count matches the video's frame count."""
    anim_json = os.path.join(output_dir, "anim.json")
    if not os.path.exists(anim_json):
        return False
    try:
        with open(anim_json) as f:
            meta = json.load(f)
        existing_count = meta.get("frame_count", 0)
        # Verify against actual video frame count
        cap = cv2.VideoCapture(mp4_path)
        if not cap.isOpened():
            return False
        video_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        cap.release()
        if existing_count >= video_frames:
            return True
        return False
    except Exception:
        return False

# Collect all MP4 files from both directories
mp4_files = []

# 1. MP4s in Downloads (UUID-named)
for f in sorted(glob.glob(os.path.join(DOWNLOADS_DIR, "*.mp4"))):
    mp4_files.append(f)

# 2. MP4s in characters directory (8.mp4, 9.mp4, 10.mp4)
for f in sorted(glob.glob(os.path.join(CHARACTERS_DIR, "*.mp4"))):
    mp4_files.append(f)

print(f"\nFound {len(mp4_files)} MP4 files total.\n")

processed = 0
skipped = 0

for mp4_path in mp4_files:
    # Use filename without extension as the anim name
    basename = os.path.splitext(os.path.basename(mp4_path))[0]
    output_dir = os.path.join(CHARACTERS_DIR, f"{basename}_anim")

    if should_skip(output_dir, mp4_path):
        print(f"SKIP: {basename} (already extracted, frame count matches)")
        skipped += 1
        continue

    print(f"\nProcessing {basename} from {mp4_path}...")
    t0 = time.time()
    n = extract_and_process(mp4_path, output_dir)
    elapsed = time.time() - t0
    print(f"  Done: {n} frames in {elapsed:.1f}s")
    processed += 1

print(f"\n{'='*50}")
print(f"All done! Processed: {processed}, Skipped: {skipped}")
