"""
Pad an image with extra horizontal (or vertical) space using the edge-sampled
background color. Intended use: pre-process character base images before i2v
animation so sword swings / walk cycles / attack arcs have room to extend
beyond the original character silhouette without clipping out of frame.

Defaults add 40% extra width (20% on each side) matching a plain studio
background. Padding color is auto-sampled from the top-left + top-right +
bottom-left + bottom-right corners (average).

Usage:
    python pad_image.py -i elven_east.jpg -o elven_east_padded.jpg
    python pad_image.py -i char.png --horizontal 0.5 --color "#888888" -o padded.png
    python pad_image.py -i char.png --horizontal 0.3 --vertical 0.1 -o padded.png
    python pad_image.py -i char.png --preserve-aspect 16:9 -o padded.png

The --preserve-aspect mode calculates padding to reach a target aspect ratio
(e.g. if you want the padded result to be exactly 16:9, pass --preserve-aspect
16:9 and it pads whichever dimension is short).
"""
import argparse
import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)


def sample_background_color(img: Image.Image, sample_size: int = 20) -> tuple:
    """Sample the 4 corners of the image and average them to guess the bg color."""
    w, h = img.size
    s = min(sample_size, w // 4, h // 4)
    if s < 1:
        s = 1
    corners = [
        img.crop((0, 0, s, s)),                      # top-left
        img.crop((w - s, 0, w, s)),                  # top-right
        img.crop((0, h - s, s, h)),                  # bottom-left
        img.crop((w - s, h - s, w, h)),              # bottom-right
    ]
    r_sum = g_sum = b_sum = count = 0
    for c in corners:
        for px in c.getdata():
            if len(px) >= 3:
                r_sum += px[0]
                g_sum += px[1]
                b_sum += px[2]
                count += 1
    if count == 0:
        return (128, 128, 128)
    return (r_sum // count, g_sum // count, b_sum // count)


def parse_color(s: str) -> tuple:
    s = s.strip()
    if s.startswith("#"):
        s = s[1:]
    if len(s) == 6:
        return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))
    raise ValueError(f"Cannot parse color: {s}")


def parse_aspect(s: str) -> float:
    """'16:9' -> 16/9"""
    w, h = s.split(":")
    return float(w) / float(h)


def pad_image(
    input_path: str,
    output_path: str,
    horizontal: float = 0.4,
    vertical: float = 0.0,
    color: tuple = None,
    preserve_aspect: str = None,
) -> str:
    img = Image.open(input_path).convert("RGB")
    w, h = img.size

    if color is None:
        color = sample_background_color(img)
        print(f"  Auto-sampled background color: RGB{color}")

    if preserve_aspect:
        target_ratio = parse_aspect(preserve_aspect)
        current_ratio = w / h
        if current_ratio >= target_ratio:
            # already wide enough; pad top/bottom to reach target
            new_h = int(w / target_ratio)
            pad_y = (new_h - h) // 2
            pad_x = 0
            new_w = w
        else:
            # too narrow; pad left/right to reach target
            new_w = int(h * target_ratio)
            pad_x = (new_w - w) // 2
            pad_y = 0
            new_h = h
    else:
        pad_x = int(w * horizontal / 2)
        pad_y = int(h * vertical / 2)
        new_w = w + 2 * pad_x
        new_h = h + 2 * pad_y

    padded = Image.new("RGB", (new_w, new_h), color)
    padded.paste(img, (pad_x, pad_y))

    # Always save as JPEG if .jpg/.jpeg; PNG if .png; else keep format of input
    ext = os.path.splitext(output_path)[1].lower()
    if ext in (".jpg", ".jpeg"):
        padded.save(output_path, "JPEG", quality=95)
    else:
        padded.save(output_path)
    print(f"  Padded: {w}x{h} -> {new_w}x{new_h}  ({output_path})")
    return output_path


def main():
    parser = argparse.ArgumentParser(description="Pad an image with background-matched horizontal/vertical space")
    parser.add_argument("--image", "-i", required=True, help="Input image path")
    parser.add_argument("--output", "-o", required=True, help="Output image path")
    parser.add_argument("--horizontal", type=float, default=0.4,
                        help="Extra horizontal space as a fraction of original width (default 0.4 = +40%%)")
    parser.add_argument("--vertical", type=float, default=0.0,
                        help="Extra vertical space as a fraction of original height (default 0)")
    parser.add_argument("--all", type=float, default=None,
                        help="Shortcut: pad all 4 sides by this fraction. Overrides --horizontal and --vertical.")
    parser.add_argument("--color", default=None,
                        help='Padding color as "#RRGGBB" (default: auto-sample from image corners)')
    parser.add_argument("--preserve-aspect", default=None,
                        help='Pad to match a target aspect ratio (e.g. "16:9"). Overrides --horizontal/--vertical.')
    args = parser.parse_args()

    color = parse_color(args.color) if args.color else None
    horizontal = args.all if args.all is not None else args.horizontal
    vertical = args.all if args.all is not None else args.vertical
    pad_image(args.image, args.output, horizontal, vertical, color, args.preserve_aspect)


if __name__ == "__main__":
    main()
