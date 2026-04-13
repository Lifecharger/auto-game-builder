"""
Gemini CLI integration for comic page analysis and translation.
Accepts both JSON and markdown responses from Gemini, converts to structured data.
"""

import subprocess
import shutil
import json
import re
import os
import sys
from pathlib import Path

import cv2
import numpy as np


def _find_gemini() -> str:
    """Find the gemini CLI executable."""
    if sys.platform == 'win32':
        npm_path = os.path.join(
            os.environ.get('APPDATA', ''), 'npm', 'gemini.cmd')
        if os.path.exists(npm_path):
            return npm_path
    found = shutil.which('gemini')
    if found:
        return found
    raise RuntimeError("Gemini CLI not found. Install: npm install -g @google/gemini-cli")


def analyze_and_translate(image_path: str, on_status=None) -> list[dict]:
    """
    Send a comic page to Gemini CLI for analysis and translation.
    Handles both JSON and markdown responses.
    """
    image_path = os.path.abspath(image_path)
    filename = os.path.basename(image_path)
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found: {image_path}")

    if on_status:
        on_status("Sending image to Gemini CLI...")

    from PIL import Image
    with Image.open(image_path) as img:
        width, height = img.size

    prompt = (
        f'Read the image file "{filename}" in the current directory. '
        f'Image is {width}x{height} pixels. '
        f'Find ALL speech bubbles, thought bubbles, captions, and sound effects. '
        f'List connected/chained bubbles SEPARATELY. Do not skip small text. '
        f'For each, provide bounding box [x1,y1,x2,y2] pixel coordinates, English text, natural Turkish translation, and type. '
        f'Use everyday spoken Turkish. SFX: use Turkish equivalents (BOOM=GUM, CRASH=CARS). '
        f'Return ONLY a JSON array: '
        f'[{{"bbox":[x1,y1,x2,y2],"original":"English","translated":"Turkish","type":"speech"}}]'
    )

    try:
        result = subprocess.run(
            [_find_gemini(), '-p', prompt, '-y', '-o', 'text'],
            capture_output=True,
            text=True,
            timeout=180,
            cwd=os.path.dirname(image_path),
            encoding='utf-8',
            errors='replace',
        )

        stdout = result.stdout or ''

        if on_status:
            on_status("Parsing Gemini response...")

        # Try 1: Parse JSON from stdout
        bubbles = _parse_json(stdout, width, height)

        # Try 2: If JSON fails, parse markdown tables from stdout
        if not bubbles:
            if on_status:
                on_status("JSON not found, parsing markdown...")
            texts = _parse_markdown(stdout)
            if texts:
                # Get coordinates in a second pass
                if on_status:
                    on_status("Getting coordinates from Gemini...")
                bubbles = _get_coordinates(
                    image_path, texts, width, height)

        # Try 3: Combined stdout+stderr as last resort
        if not bubbles:
            combined = stdout + '\n' + (result.stderr or '')
            bubbles = _parse_json(combined, width, height)

        # Validate with OpenCV
        image = cv2.imread(image_path)
        if image is not None and bubbles:
            bubbles = _validate_bubbles(bubbles, image)

        return bubbles

    except subprocess.TimeoutExpired:
        raise TimeoutError("Gemini CLI timed out after 180 seconds")
    except FileNotFoundError:
        raise RuntimeError("Gemini CLI not found.")


# ── JSON parsing ─────────────────────────────────────────────────────────────

def _parse_json(text: str, img_width: int, img_height: int) -> list[dict]:
    """Parse JSON array of bubbles from text."""
    text = re.sub(r'```json\s*', '', text)
    text = re.sub(r'```\s*', '', text)

    bubbles = None
    start = text.find('[')
    while start != -1 and bubbles is None:
        depth = 0
        for i in range(start, len(text)):
            if text[i] == '[':
                depth += 1
            elif text[i] == ']':
                depth -= 1
                if depth == 0:
                    try:
                        parsed = json.loads(text[start:i + 1])
                        if (isinstance(parsed, list) and len(parsed) > 0
                                and isinstance(parsed[0], dict)):
                            bubbles = parsed
                    except json.JSONDecodeError:
                        pass
                    break
        if bubbles is None:
            start = text.find('[', start + 1)

    if not bubbles:
        return []

    valid = []
    for b in bubbles:
        if not isinstance(b, dict):
            continue
        if not all(k in b for k in ('bbox', 'original', 'translated', 'type')):
            continue
        bbox = b['bbox']
        if not isinstance(bbox, list) or len(bbox) != 4:
            continue

        x1 = max(0, min(int(bbox[0]), img_width))
        y1 = max(0, min(int(bbox[1]), img_height))
        x2 = max(0, min(int(bbox[2]), img_width))
        y2 = max(0, min(int(bbox[3]), img_height))
        if x2 <= x1 or y2 <= y1:
            continue

        valid.append({
            'bbox': [x1, y1, x2, y2],
            'original': str(b['original']),
            'translated': str(b['translated']),
            'type': str(b.get('type', 'speech')),
        })

    return valid


# ── Markdown parsing ─────────────────────────────────────────────────────────

def _parse_markdown(text: str) -> list[dict]:
    """
    Extract text pairs from markdown tables.
    Handles various formats Gemini might return:
    - Tables with Original/Translation columns
    - Numbered lists with text pairs
    - Two separate tables (English + Turkish)
    """
    results = []

    # Pattern 1: Table with original and translation in same row
    # | # | Original | Translation | Type |
    table_pattern = re.compile(
        r'\|\s*\d+\s*\|[^|]*\|\s*["\']?(.+?)["\']?\s*\|\s*["\']?(.+?)["\']?\s*\|',
        re.MULTILINE
    )
    for m in table_pattern.finditer(text):
        orig, trans = m.group(1).strip(), m.group(2).strip()
        if orig and trans and not orig.startswith('---'):
            results.append({'original': orig, 'translated': trans, 'type': 'speech'})

    if results:
        return results

    # Pattern 2: Two tables — one English, one Turkish
    # Find quoted text in each table row
    english_texts = []
    turkish_texts = []

    # Split into sections by headers
    sections = re.split(r'#{2,3}\s+', text)

    for section in sections:
        section_lower = section.lower()
        quoted = re.findall(r'["\u201c]([^"\u201d]+)["\u201d]', section)
        if not quoted:
            # Try pipe-delimited table cells
            quoted = re.findall(r'\|\s*(?:\*{2}[^*]+\*{2}\s*\|)?\s*"?([A-Z][^|"]+)"?\s*\|',
                                section)

        if any(kw in section_lower for kw in ['english', 'original', 'transcription']):
            english_texts.extend(quoted)
        elif any(kw in section_lower for kw in ['turkish', 'türk', 'çeviri', 'translation']):
            turkish_texts.extend(quoted)

    if english_texts and turkish_texts:
        for en, tr in zip(english_texts, turkish_texts):
            results.append({'original': en.strip(), 'translated': tr.strip(),
                            'type': 'speech'})
        return results

    # Pattern 3: Character dialogue format
    # | **Falcone** | "text here" |
    dialogue = re.findall(
        r'\|\s*\*{0,2}(\w+)\*{0,2}\s*\|\s*["\u201c]([^"\u201d]+)["\u201d]\s*\|',
        text
    )
    if len(dialogue) >= 2:
        # Might be two tables — check if first half is English, second Turkish
        mid = len(dialogue) // 2
        first_half = dialogue[:mid]
        second_half = dialogue[mid:]

        # Check if characters match between halves
        if all(a[0] == b[0] for a, b in zip(first_half, second_half)):
            for (char1, en), (char2, tr) in zip(first_half, second_half):
                results.append({'original': en.strip(), 'translated': tr.strip(),
                                'type': 'speech'})
            return results

    return results


# ── Coordinate retrieval for markdown results ────────────────────────────────

def _get_coordinates(image_path: str, texts: list[dict],
                     img_width: int, img_height: int) -> list[dict]:
    """
    Second Gemini call: given extracted text pairs, get their bounding boxes.
    This is a text-only call referencing the image for coordinates.
    """
    filename = os.path.basename(image_path)

    # Build a numbered list of texts for Gemini
    text_list = '\n'.join(
        f'{i+1}. "{t["original"]}"' for i, t in enumerate(texts)
    )

    prompt = (
        f'Read the image file "{filename}" in the current directory. '
        f'Image is {img_width}x{img_height} pixels. '
        f'I found these text areas in the comic page:\n{text_list}\n\n'
        f'For each numbered text, provide its bounding box as [x1,y1,x2,y2] pixel coordinates. '
        f'Return ONLY a JSON array of [x1,y1,x2,y2] arrays in the same order: '
        f'[[x1,y1,x2,y2],[x1,y1,x2,y2],...]'
    )

    try:
        result = subprocess.run(
            [_find_gemini(), '-p', prompt, '-y', '-o', 'text'],
            capture_output=True, text=True, timeout=120,
            cwd=os.path.dirname(image_path),
            encoding='utf-8', errors='replace',
        )

        stdout = result.stdout or ''
        # Parse array of arrays
        coords = _parse_coord_array(stdout, len(texts))

        if coords and len(coords) == len(texts):
            bubbles = []
            for t, bbox in zip(texts, coords):
                x1 = max(0, min(int(bbox[0]), img_width))
                y1 = max(0, min(int(bbox[1]), img_height))
                x2 = max(0, min(int(bbox[2]), img_width))
                y2 = max(0, min(int(bbox[3]), img_height))
                if x2 > x1 and y2 > y1:
                    bubbles.append({
                        'bbox': [x1, y1, x2, y2],
                        'original': t['original'],
                        'translated': t['translated'],
                        'type': t.get('type', 'speech'),
                    })
            return bubbles

    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return []


def _parse_coord_array(text: str, expected_count: int) -> list[list[int]]:
    """Parse an array of coordinate arrays from text."""
    text = re.sub(r'```json\s*', '', text)
    text = re.sub(r'```\s*', '', text)

    # Find the outer array
    match = re.search(r'\[\s*\[', text)
    if not match:
        return []

    start = match.start()
    depth = 0
    for i in range(start, len(text)):
        if text[i] == '[':
            depth += 1
        elif text[i] == ']':
            depth -= 1
            if depth == 0:
                try:
                    data = json.loads(text[start:i + 1])
                    if isinstance(data, list) and all(
                        isinstance(c, list) and len(c) == 4 for c in data
                    ):
                        return data
                except json.JSONDecodeError:
                    pass
                break

    return []


# ── Validation ───────────────────────────────────────────────────────────────

def _validate_bubbles(bubbles: list[dict], image: np.ndarray) -> list[dict]:
    """
    Validate detected bubbles using OpenCV.
    Checks the inner core of each bbox for bright pixels.
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    valid = []

    for b in bubbles:
        x1, y1, x2, y2 = b['bbox']
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w, x2), min(h, y2)

        if x2 <= x1 or y2 <= y1:
            continue

        # Check inner 60% of bbox
        bw, bh = x2 - x1, y2 - y1
        ix1 = x1 + bw // 5
        iy1 = y1 + bh // 5
        ix2 = x2 - bw // 5
        iy2 = y2 - bh // 5

        if ix2 <= ix1 or iy2 <= iy1:
            b['bbox'] = [x1, y1, x2, y2]
            valid.append(b)
            continue

        core = gray[iy1:iy2, ix1:ix2]
        bright_ratio = np.sum(core > 180) / core.size

        if bright_ratio < 0.10:
            continue

        b['bbox'] = [x1, y1, x2, y2]
        valid.append(b)

    return valid
