import os, sys, time, json, shutil
import cv2
import numpy as np
from PIL import Image
from rembg import remove, new_session

print("Loading rembg model...")
session = new_session("u2net")

CHARACTERS_SRC = "C:/Users/caca_/Desktop/Characters"
PIXEL_GUY_DIR = "C:/Projects/Pixel Guy/assets/characters"
ELVEN_DUTY_DIR = "C:/Projects/Elven Duty/assets"

videos = [
    ("warior360.mp4", "warrior_turntable"),
    ("mage360.mp4", "mage_turntable"),
    ("archer360.mp4", "archer_turntable"),
]

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

for video_file, name in videos:
    mp4_path = os.path.join(CHARACTERS_SRC, video_file)
    if not os.path.exists(mp4_path):
        print(f"SKIP: {mp4_path} not found")
        continue

    # Extract to Pixel Guy for viewing
    pg_output = os.path.join(PIXEL_GUY_DIR, f"{name}_anim")
    print(f"\nProcessing {name} -> Pixel Guy...")
    t0 = time.time()
    n = extract_and_process(mp4_path, pg_output)
    elapsed = time.time() - t0
    print(f"  Done: {n} frames in {elapsed:.1f}s")

    # Copy to Elven Duty
    ed_output = os.path.join(ELVEN_DUTY_DIR, name)
    print(f"  Copying to Elven Duty...")
    if os.path.exists(ed_output):
        shutil.rmtree(ed_output)
    shutil.copytree(pg_output, ed_output)
    print(f"  Copied to {ed_output}")

# Also copy static character PNGs to Elven Duty
for png_file, name in [("warior.png", "warrior"), ("mage.png", "mage"), ("archer.png", "archer")]:
    src = os.path.join(CHARACTERS_SRC, png_file)
    if os.path.exists(src):
        dst = os.path.join(ELVEN_DUTY_DIR, f"{name}_portrait.png")
        shutil.copy2(src, dst)
        print(f"Copied portrait: {dst}")

print("\n" + "=" * 50)
print("All done!")
