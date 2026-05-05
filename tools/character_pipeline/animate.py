"""
Stage 2 of the character pipeline: image-to-video idle animation via Grok.

Loops over a directory of character images and submits an i2v idle-animation
request for each. Submission only — videos render server-side; fetch them
afterwards with tools/grok/grok_downloader.py.

Usage:
    # Animate every PNG in Characters/ with the default idle prompt
    python tools/character_pipeline/animate.py

    # Custom subset and prompt
    python tools/character_pipeline/animate.py --pattern "warrior_*.png" \
        --prompt "subtle idle, hair sway, static camera"
"""
import argparse
import glob
import os
import sys
import time

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(_THIS_DIR)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from grok.grok_animate import animate

INPUT_DIR = r"C:\Users\caca_\Desktop\Characters"
DEFAULT_PROMPT = (
    "subtle idle breathing motion, slight hair sway, minimal body movement, "
    "static camera, gentle pose shifts, no camera movement"
)


def main():
    parser = argparse.ArgumentParser(description="Character pipeline - Stage 2: i2v idle animation (Grok)")
    parser.add_argument("--pattern", default="*.png",
                        help="Glob pattern within the Characters folder (default *.png)")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT,
                        help="Animation prompt sent for each image")
    parser.add_argument("--length", type=int, default=6, choices=[6, 10],
                        help="Video length in seconds (default 6)")
    parser.add_argument("--resolution", default="480p", choices=["480p", "720p"],
                        help="Video resolution (default 480p)")
    parser.add_argument("--sleep-between", type=float, default=2.0,
                        help="Seconds to sleep between submissions (politeness, default 2)")
    parser.add_argument("--start-at", type=int, default=0,
                        help="Skip the first N images (resume after a partial run)")
    args = parser.parse_args()

    images = sorted(glob.glob(os.path.join(INPUT_DIR, args.pattern)))
    if not images:
        print(f"No images matched {args.pattern} in {INPUT_DIR}")
        sys.exit(1)

    if args.start_at:
        images = images[args.start_at:]

    print(f"Submitting {len(images)} i2v jobs from {INPUT_DIR}")
    print(f"Prompt: {args.prompt}\n")

    succeeded, failed = [], []
    for i, img in enumerate(images, 1):
        name = os.path.basename(img)
        print(f"[{i}/{len(images)}] {name}")
        ok = False
        try:
            ok = animate(img, args.prompt, args.length, args.resolution, headless=True)
        except Exception as e:
            print(f"  EXCEPTION: {e}")
        if ok:
            succeeded.append(name)
        else:
            failed.append(name)
        if i < len(images):
            time.sleep(args.sleep_between)

    print(f"\nDone. {len(succeeded)} submitted, {len(failed)} failed.")
    if failed:
        print("Failed:")
        for n in failed:
            print(f"  - {n}")
    print("\nVideos render server-side. Run tools/grok/grok_downloader.py to fetch them.")


if __name__ == "__main__":
    main()
