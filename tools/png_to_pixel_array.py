"""
Convert a PNG sprite to a JavaScript pixel array for HTML games.

Usage:
    python "C:/General Tools/png_to_pixel_array.py" -i sprite.png
    python "C:/General Tools/png_to_pixel_array.py" -i sprite.png -o output.js
    python "C:/General Tools/png_to_pixel_array.py" -i sprite.png --format python
    python "C:/General Tools/png_to_pixel_array.py" -i sprite.png --max-colors 16
    python "C:/General Tools/png_to_pixel_array.py" -i sprite.png --downscale 32

Outputs a 2D array where each cell is a hex color (0xRRGGBB) or 0 for transparent.
"""

import argparse
import os
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow required. Install with: pip install Pillow")
    sys.exit(1)


def png_to_array(image_path: str, max_colors: int = 0, downscale: int = 0, alpha_threshold: int = 128) -> tuple[list[list[int]], dict[int, int]]:
    """Convert PNG to 2D pixel array. Returns (grid, palette_counts)."""
    img = Image.open(image_path).convert("RGBA")

    if downscale and (img.width > downscale or img.height > downscale):
        ratio = min(downscale / img.width, downscale / img.height)
        new_w = max(1, int(img.width * ratio))
        new_h = max(1, int(img.height * ratio))
        img = img.resize((new_w, new_h), Image.NEAREST)

    pixels = img.load()
    w, h = img.size
    grid = []
    color_counts = Counter()

    for y in range(h):
        row = []
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < alpha_threshold:
                row.append(0)
            else:
                hex_color = (r << 16) | (g << 8) | b
                row.append(hex_color)
                color_counts[hex_color] += 1
        grid.append(row)

    # Quantize to max_colors if requested
    if max_colors and len(color_counts) > max_colors:
        # Keep the most common colors, map rare ones to nearest common
        top_colors = [c for c, _ in color_counts.most_common(max_colors)]
        color_map = {}
        for color in color_counts:
            if color in top_colors:
                color_map[color] = color
            else:
                # Find nearest color by RGB distance
                best = min(top_colors, key=lambda tc: _color_dist(color, tc))
                color_map[color] = best

        for y in range(len(grid)):
            for x in range(len(grid[y])):
                if grid[y][x] != 0:
                    grid[y][x] = color_map[grid[y][x]]

        color_counts = Counter()
        for row in grid:
            for c in row:
                if c != 0:
                    color_counts[c] += 1

    return grid, dict(color_counts)


def _color_dist(c1: int, c2: int) -> int:
    """Simple RGB distance between two hex colors."""
    r1, g1, b1 = (c1 >> 16) & 0xFF, (c1 >> 8) & 0xFF, c1 & 0xFF
    r2, g2, b2 = (c2 >> 16) & 0xFF, (c2 >> 8) & 0xFF, c2 & 0xFF
    return (r1 - r2) ** 2 + (g1 - g2) ** 2 + (b1 - b2) ** 2


def format_js(grid: list[list[int]], palette: dict[int, int], var_name: str = "sprite") -> str:
    """Format as JavaScript with palette + indexed grid for compact output."""
    sorted_colors = sorted(palette.keys(), key=lambda c: -palette[c])
    color_to_idx = {c: i + 1 for i, c in enumerate(sorted_colors)}

    lines = []
    lines.append(f"// {len(grid[0])}x{len(grid)} sprite, {len(sorted_colors)} colors")
    lines.append(f"const {var_name}_palette = [")
    for c in sorted_colors:
        r, g, b = (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF
        lines.append(f"  0x{c:06X}, // #{c:06X} rgb({r},{g},{b})")
    lines.append("];")
    lines.append("")
    lines.append(f"// 0 = transparent, 1-{len(sorted_colors)} = palette index")
    lines.append(f"const {var_name}_data = [")

    for row in grid:
        idx_row = [color_to_idx.get(c, 0) for c in row]
        # Compact: use single chars for indices 0-9, then hex
        if max(idx_row) <= 9:
            row_str = "".join(str(v) for v in idx_row)
            lines.append(f'  "{row_str}",')
        else:
            lines.append(f"  {idx_row},")

    lines.append("];")

    # Add render helper
    lines.append("")
    lines.append(f"""// Render function (PixiJS)
function draw_{var_name}(gfx, x, y, scale) {{
  const p = {var_name}_palette;
  const d = {var_name}_data;
  for (let r = 0; r < d.length; r++) {{
    const row = typeof d[r] === 'string' ? d[r].split('').map(Number) : d[r];
    for (let c = 0; c < row.length; c++) {{
      const idx = row[c];
      if (idx > 0) {{
        gfx.beginFill(p[idx - 1]);
        gfx.drawRect(x + c * scale, y + r * scale, scale, scale);
        gfx.endFill();
      }}
    }}
  }}
}}""")
    return "\n".join(lines)


def format_python(grid: list[list[int]], palette: dict[int, int], var_name: str = "sprite") -> str:
    """Format as Python."""
    sorted_colors = sorted(palette.keys(), key=lambda c: -palette[c])
    color_to_idx = {c: i + 1 for i, c in enumerate(sorted_colors)}

    lines = []
    lines.append(f"# {len(grid[0])}x{len(grid)} sprite, {len(sorted_colors)} colors")
    lines.append(f"{var_name}_palette = [")
    for c in sorted_colors:
        lines.append(f"    0x{c:06X},  # rgb({(c>>16)&0xFF}, {(c>>8)&0xFF}, {c&0xFF})")
    lines.append("]")
    lines.append("")
    lines.append(f"# 0 = transparent, 1-{len(sorted_colors)} = palette index")
    lines.append(f"{var_name}_data = [")
    for row in grid:
        idx_row = [color_to_idx.get(c, 0) for c in row]
        lines.append(f"    {idx_row},")
    lines.append("]")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Convert PNG sprite to pixel array for HTML games")
    parser.add_argument("-i", "--input", required=True, help="Input PNG file")
    parser.add_argument("-o", "--output", default=None, help="Output file (default: print to stdout)")
    parser.add_argument("--format", choices=["js", "python"], default="js", help="Output format (default: js)")
    parser.add_argument("--var", default="sprite", help="Variable name (default: sprite)")
    parser.add_argument("--max-colors", type=int, default=0, help="Quantize to N colors (0 = no limit)")
    parser.add_argument("--downscale", type=int, default=0, help="Downscale to NxN max (0 = original size)")
    parser.add_argument("--alpha-threshold", type=int, default=128, help="Alpha below this = transparent (default: 128)")
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"ERROR: File not found: {args.input}")
        sys.exit(1)

    img = Image.open(args.input)
    print(f"Input: {args.input} ({img.width}x{img.height})", file=sys.stderr)

    grid, palette = png_to_array(args.input, args.max_colors, args.downscale, args.alpha_threshold)

    print(f"Grid: {len(grid[0])}x{len(grid)}, {len(palette)} unique colors", file=sys.stderr)

    if args.format == "js":
        result = format_js(grid, palette, args.var)
    else:
        result = format_python(grid, palette, args.var)

    if args.output:
        with open(args.output, "w") as f:
            f.write(result)
        print(f"Saved: {args.output}", file=sys.stderr)
    else:
        print(result)


if __name__ == "__main__":
    main()
