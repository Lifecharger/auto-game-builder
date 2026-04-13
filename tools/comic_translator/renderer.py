"""
Turkish text renderer for comic speech bubbles.
Renders translated text inside actual bubble contour shapes with auto-sizing and centering.
Uses bbox Y range to correctly position text in connected/chained bubbles.
"""

import os
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from contour import get_contour_widths

# Default font search order — comic font first, then system fallbacks.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_WIN_FONTS_DIR = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts")
DEFAULT_FONTS = [
    os.path.join(SCRIPT_DIR, "assets", "fonts", "Bangers-Regular.ttf"),
    os.path.join(_WIN_FONTS_DIR, "arialbd.ttf"),
    os.path.join(_WIN_FONTS_DIR, "arial.ttf"),
    os.path.join(_WIN_FONTS_DIR, "comicbd.ttf"),
    os.path.join(_WIN_FONTS_DIR, "comic.ttf"),
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def get_font(size: int, font_path: str = None) -> ImageFont.FreeTypeFont:
    """Load a font that supports Turkish characters."""
    if font_path and os.path.exists(font_path):
        return ImageFont.truetype(font_path, size)
    for f in DEFAULT_FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def _layout_text_in_contour(text: str, contour: np.ndarray, bbox: list[int],
                             image_shape: tuple, font_path: str = None,
                             min_size: int = 0, max_size: int = 0,
                             margin_pct: float = 0.10
                             ) -> tuple[int, list[tuple[str, int, int]]]:
    """
    Lay out text inside a contour shape, constrained to the bbox's Y range.
    This correctly handles connected/chained bubbles by keeping each text
    in its own vertical zone.

    Returns:
        (font_size, lines) where each line is (text, center_x, y)
    """
    widths = get_contour_widths(contour, image_shape, margin_pct)
    if not widths:
        return _layout_text_in_bbox(text, bbox, font_path, min_size, max_size)

    # Constrain to the bbox Y range (with small expansion for margin)
    bx1, by1, bx2, by2 = bbox
    y_expand = int((by2 - by1) * 0.08)
    y_lo = by1 - y_expand
    y_hi = by2 + y_expand

    # Filter contour widths to only the bbox's Y zone
    # Scale font size range to image resolution
    img_w = image_shape[1]
    if max_size == 0:
        max_size = max(20, img_w // 30)
    if min_size == 0:
        min_size = max(8, img_w // 250)

    zone_widths = {y: lr for y, lr in widths.items() if y_lo <= y <= y_hi}

    if not zone_widths:
        # Bbox Y range doesn't overlap contour — fall back to bbox
        return _layout_text_in_bbox(text, bbox, font_path, min_size, max_size)

    ys = sorted(zone_widths.keys())
    y_min, y_max = ys[0], ys[-1]
    total_h = y_max - y_min

    words = text.split()
    if not words:
        return min_size, []

    for font_size in range(max_size, min_size - 1, -1):
        font = get_font(font_size, font_path)
        line_h = int(font_size * 1.4)

        margin_v = int(total_h * 0.08)
        usable_h = total_h - margin_v * 2
        if usable_h <= 0:
            continue
        max_lines = usable_h // line_h
        if max_lines < 1:
            continue

        # Center text block vertically within the zone
        center_y = (y_min + y_max) // 2
        block_h = max_lines * line_h
        start_y = center_y - block_h // 2

        lines = []
        remaining = list(words)
        all_fit = True

        for line_idx in range(max_lines):
            if not remaining:
                break

            line_y = start_y + line_idx * line_h + line_h // 2

            avail_w = _get_width_at_y(zone_widths, ys, line_y, line_h)
            if avail_w <= 0:
                all_fit = False
                break

            line_words = []
            while remaining:
                test = ' '.join(line_words + [remaining[0]])
                if font.getlength(test) <= avail_w:
                    line_words.append(remaining.pop(0))
                else:
                    break

            if not line_words:
                all_fit = False
                break

            line_text = ' '.join(line_words)
            lx, rx = _get_bounds_at_y(zone_widths, ys, line_y)
            center_x = (lx + rx) // 2
            lines.append((line_text, center_x, start_y + line_idx * line_h))

        if all_fit and not remaining:
            return font_size, lines

    # Fallback: smallest size, best effort within zone
    font = get_font(min_size, font_path)
    line_h = int(min_size * 1.4)
    lines = []
    remaining = list(words)
    line_idx = 0
    start_y = y_min + int(total_h * 0.08)

    while remaining:
        line_y = start_y + line_idx * line_h + line_h // 2
        if line_y > y_max:
            if lines:
                last_text, last_cx, last_y = lines[-1]
                lines[-1] = (last_text + ' ' + ' '.join(remaining),
                             last_cx, last_y)
            break

        avail_w = _get_width_at_y(zone_widths, ys, line_y, line_h)
        if avail_w <= 0:
            line_idx += 1
            continue

        line_words = []
        while remaining:
            test = ' '.join(line_words + [remaining[0]])
            if font.getlength(test) <= avail_w:
                line_words.append(remaining.pop(0))
            else:
                break
        if not line_words and remaining:
            line_words.append(remaining.pop(0))

        lx, rx = _get_bounds_at_y(zone_widths, ys, line_y)
        center_x = (lx + rx) // 2
        lines.append((' '.join(line_words), center_x,
                       start_y + line_idx * line_h))
        line_idx += 1

    return min_size, lines


def _layout_text_in_bbox(text: str, bbox: list[int], font_path: str = None,
                          min_size: int = 10, max_size: int = 60
                          ) -> tuple[int, list[tuple[str, int, int]]]:
    """Fallback: lay out text in a rectangular bbox."""
    x1, y1, x2, y2 = bbox
    margin = 10
    # Scale max size based on bubble height
    bubble_h = y2 - y1
    max_size = min(max_size, max(12, bubble_h // 3))
    box_w = (x2 - x1) - margin * 2
    box_h = (y2 - y1) - margin * 2
    center_x = (x1 + x2) // 2

    words = text.split()
    if not words or box_w <= 0 or box_h <= 0:
        return min_size, []

    for font_size in range(max_size, min_size - 1, -1):
        font = get_font(font_size, font_path)
        line_h = int(font_size * 1.4)
        max_lines = box_h // line_h
        if max_lines < 1:
            continue

        lines = []
        remaining = list(words)
        for _ in range(max_lines):
            if not remaining:
                break
            line_words = []
            while remaining:
                test = ' '.join(line_words + [remaining[0]])
                if font.getlength(test) <= box_w:
                    line_words.append(remaining.pop(0))
                else:
                    break
            if not line_words:
                break
            lines.append(' '.join(line_words))

        if not remaining:
            start_y = y1 + margin + (box_h - len(lines) * line_h) // 2
            result = [(l, center_x, start_y + i * line_h)
                       for i, l in enumerate(lines)]
            return font_size, result

    return min_size, [(text, center_x, y1 + margin)]


def _get_width_at_y(widths: dict, ys: list, y: int,
                     line_h: int = 20) -> float:
    """Get minimum available width across a line height band."""
    samples = [y - line_h // 4, y, y + line_h // 4]
    min_w = float('inf')
    for sy in samples:
        closest = min(ys, key=lambda row: abs(row - sy))
        if closest in widths:
            lx, rx = widths[closest]
            min_w = min(min_w, rx - lx)
    return min_w if min_w != float('inf') else 0


def _get_bounds_at_y(widths: dict, ys: list, y: int) -> tuple[int, int]:
    """Get (left, right) bounds at a Y position."""
    closest = min(ys, key=lambda row: abs(row - y))
    if closest in widths:
        return widths[closest]
    return (0, 0)


def render_text(image: np.ndarray, bubble: dict,
                font_path: str = None, color: tuple = (0, 0, 0),
                uppercase: bool = True) -> np.ndarray:
    """
    Render translated text inside a bubble using contour shape + bbox constraint.
    """
    text = bubble['translated']
    if uppercase:
        text = text.upper()

    contour = bubble.get('_contour')

    if contour is not None:
        font_size, lines = _layout_text_in_contour(
            text, contour, bubble['bbox'], image.shape, font_path)
    else:
        font_size, lines = _layout_text_in_bbox(
            text, bubble['bbox'], font_path)

    if not lines:
        return image

    font = get_font(font_size, font_path)

    pil_img = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil_img)

    for line_text, center_x, y in lines:
        tw = font.getlength(line_text)
        x = center_x - tw / 2
        draw.text((x, y), line_text, font=font, fill=color)

    return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)


def render_all(image: np.ndarray, bubbles: list[dict],
               font_path: str = None, uppercase: bool = True) -> np.ndarray:
    """Render all Turkish translations into cleaned bubbles."""
    result = image.copy()
    for b in bubbles:
        result = render_text(result, b, font_path=font_path,
                              uppercase=uppercase)
    return result
