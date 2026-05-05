"""
Stage 1 of the character pipeline: text-to-image via Grok.

Saves output to C:\\Users\\caca_\\Desktop\\Characters.

Usage:
    python tools/character_pipeline/generate.py -d "anime swordswoman, full body" -o swords --pro
    python tools/character_pipeline/generate.py -d "cyberpunk hacker" --aspect 16:9
"""
import argparse
import os
import sys

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_TOOLS_DIR = os.path.dirname(_THIS_DIR)
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from grok.grok_generate_image import generate_images

OUTPUT_DIR = r"C:\Users\caca_\Desktop\Characters"


def main():
    parser = argparse.ArgumentParser(description="Character pipeline - Stage 1: text-to-image (Grok)")
    parser.add_argument("--description", "-d", required=True, help="Image prompt")
    parser.add_argument("--output", "-o", default=None,
                        help="Output filename stem (e.g. 'knight' -> knight_1.png, knight_2.png ...). Default: grok_<id>_N.png")
    parser.add_argument("--aspect", default="2:3",
                        choices=["2:3", "3:2", "16:9", "9:16", "1:1", "4:3", "3:4"],
                        help="Aspect ratio (default 2:3 - card aspect)")
    parser.add_argument("--pro", action="store_true", help="Quality mode (Imagine v3)")
    parser.add_argument("--model", default=None, choices=["imagine", "aurora", "flux"])
    args = parser.parse_args()

    saved = generate_images(
        prompt=args.description,
        aspect_ratio=args.aspect,
        output=args.output,
        pro=args.pro,
        model=args.model,
        output_dir=OUTPUT_DIR,
    )

    if not saved:
        sys.exit(1)


if __name__ == "__main__":
    main()
