"""
Use SAM to get a clean character mask, then split into upper/lower body
for a breathing idle animation.

Usage:
    python sam_breathe_split.py <image1> <image2> ...

Environment variables:
    COMFYUI_CUSTOM_NODES: path to ComfyUI/custom_nodes (for segment_anything import)
    SAM_CHECKPOINT: path to SAM model .pth file
    SAM_MODEL_TYPE: SAM variant (default: vit_b)
"""
import sys, json, os, argparse
import numpy as np
from PIL import Image
import torch

_default_comfy_nodes = os.path.expanduser("~/ComfyUI/custom_nodes")
_comfy_nodes = os.environ.get("COMFYUI_CUSTOM_NODES", _default_comfy_nodes)
if os.path.isdir(_comfy_nodes):
    sys.path.insert(0, _comfy_nodes)

from segment_anything import sam_model_registry, SamPredictor

SAM_CHECKPOINT = os.environ.get(
    "SAM_CHECKPOINT",
    os.path.expanduser("~/ComfyUI/models/sam/sam_vit_b_01ec64.pth"),
)
MODEL_TYPE = os.environ.get("SAM_MODEL_TYPE", "vit_b")

def segment_character(img_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    
    # Load image
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    # Get alpha mask from the already-background-removed image
    alpha = np.array(img)[:, :, 3]
    
    # Find bounding box of character
    rows = np.any(alpha > 10, axis=1)
    cols = np.any(alpha > 10, axis=0)
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    
    char_height = rmax - rmin
    
    # Split point: roughly at the waist (55% down from top of character)
    split_y = rmin + int(char_height * 0.55)
    
    img_array = np.array(img)
    
    # Upper body: everything above split_y
    upper = img_array.copy()
    # Feather the split edge: 6px gradient blend to avoid hard line
    feather = 6
    for fy in range(feather):
        row = split_y + fy
        if row < h:
            fade = 1.0 - (fy / feather)
            upper[row, :, 3] = (upper[row, :, 3] * fade).astype(np.uint8)
    upper[split_y + feather:, :, :] = 0
    
    # Lower body: everything below split_y
    lower = img_array.copy()
    for fy in range(feather):
        row = split_y - fy
        if row >= 0:
            fade = 1.0 - (fy / feather)
            lower[row, :, 3] = (lower[row, :, 3] * fade).astype(np.uint8)
    lower[:split_y - feather, :, :] = 0
    
    # Save parts
    Image.fromarray(upper).save(os.path.join(output_dir, "upper.png"))
    Image.fromarray(lower).save(os.path.join(output_dir, "lower.png"))
    
    # Save metadata
    meta = {
        "width": w,
        "height": h,
        "split_y": int(split_y),
        "char_top": int(rmin),
        "char_bottom": int(rmax),
    }
    with open(os.path.join(output_dir, "breathe.json"), "w") as f:
        json.dump(meta, f, indent=2)
    
    print(f"  Split at y={split_y} (char: {rmin}-{rmax}, h={char_height})")
    print(f"  Saved upper.png, lower.png, breathe.json")

def main():
    parser = argparse.ArgumentParser(description="Split character PNGs into upper/lower for breathing anim")
    parser.add_argument("images", nargs="+", help="Input .png file paths")
    parser.add_argument(
        "--out-suffix",
        default="_parts",
        help="Suffix appended to image basename for output folder (default: _parts)",
    )
    args = parser.parse_args()

    for img_path in args.images:
        img_path = os.path.abspath(img_path)
        stem, _ = os.path.splitext(img_path)
        out_dir = stem + args.out_suffix
        name = os.path.basename(img_path)
        print(f"Processing {name}...")
        segment_character(img_path, out_dir)

    print("\nDone! All characters split for breathing animation.")


if __name__ == "__main__":
    main()
