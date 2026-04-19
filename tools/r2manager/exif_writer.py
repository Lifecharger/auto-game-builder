"""Write rating-pipeline EXIF metadata into a JPG.

Called by Gemini CLI (headless) after it analyzes an image. The format below
matches what the old Asset Generation Pipeline produced, so existing pushed
assets stay readable.

Usage:
    python exif_writer.py <image.jpg> --json "<single-line json>"
    python exif_writer.py <image.jpg> --json-file <path.json>

Required JSON schema (matches the existing Hot Jigsaw - Pushed assets 1:1):
    tags                  string — comma-separated keywords (required, non-empty)
    description           string — 1 sentence (optional)
    adult                 int 1-5 (1=clothed, 3=swimwear/lingerie, 5=nude)
    racy                  int 1-5 (suggestiveness)
    violence              int 1-5
    rating                "kid" | "teen" | "adult"
    safety_level          "safe" | "borderline" | "risky"
    camera_angle          e.g. "eye_level" | "low_angle" | "high_angle"
    view_type             e.g. "frontal_view" | "back_view" | "side_view"
    pose_type             e.g. "neutral" | "suggestive" | "action"
    framing               e.g. "full_body" | "upper_body" | "portrait"
    skin_exposure         "low" | "medium" | "high" | "very_high"
    mood                  free-form string (e.g. "elegant", "playful", "neutral")
    voyeur_risk           "none" | "low" | "medium" | "high"
    context_flag          "ok" | "mismatch"
    body_parts            array of strings (e.g. ["cleavage","thighs"])
    clothing_coverage     "minimal" | "revealing" | "moderate" | "modest"
    clothing_fit          "loose" | "fitted" | "tight"
    clothing_type         array of strings (e.g. ["dress","evening gown"])
    art_style             array of strings (e.g. ["realistic","photorealistic"])
    setting               array of strings (e.g. ["studio"])
    risk_factors          array of strings (e.g. ["cleavage","suggestive_pose"])
    visual_focus          array of strings (e.g. ["body","face"])
    policy_flags          array of strings (may be empty)

Exit 0 on success, 1 on error. Prints "OK: <path>" on success.
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image
import piexif


def _arr_to_str(v) -> str:
    """Join list of strings with commas; pass strings through; 'none' for empty."""
    if isinstance(v, str):
        return v or "none"
    if isinstance(v, (list, tuple)) and v:
        return ",".join(str(x) for x in v)
    return "none"


def write_exif(img_path: Path, meta: dict) -> None:
    if img_path.suffix.lower() not in {".jpg", ".jpeg"}:
        raise SystemExit(f"Only JPG supported; got {img_path.suffix}")
    if not img_path.exists():
        raise SystemExit(f"Image not found: {img_path}")

    tags = meta.get("tags", "")
    if not isinstance(tags, str) or not tags.strip():
        raise SystemExit("'tags' key is required and must be a non-empty string")

    # IMPORTANT: do NOT re-encode the pixel data — lossy re-save shifts the
    # image so its content no longer matches the video's first frame, which
    # breaks Match Videos' MSE pairing. piexif.insert edits EXIF in-place
    # without touching pixels. If the existing EXIF is too broken for
    # piexif.insert, we fall back to a re-encode as a last resort.
    exif = {"0th": {}, "Exif": {}, "GPS": {}, "1st": {}, "thumbnail": None}

    # XPKeywords — comma-separated tag list
    exif["0th"][0x9C9E] = tags.encode("utf-16le")

    # XPSubject — content rating + camera/pose/framing fields (matches old
    # Asset Generation Pipeline format exactly).
    subj = (
        f"adult:{meta.get('adult', 1)}|"
        f"racy:{meta.get('racy', 1)}|"
        f"violence:{meta.get('violence', 1)}|"
        f"rating:{meta.get('rating', 'teen')}|"
        f"safety:{meta.get('safety_level', 'safe')}|"
        f"camera:{meta.get('camera_angle', 'eye_level')}|"
        f"view:{meta.get('view_type', 'frontal_view')}|"
        f"pose:{meta.get('pose_type', 'neutral')}|"
        f"framing:{meta.get('framing', 'full_body')}|"
        f"skin:{meta.get('skin_exposure', 'low')}|"
        f"mood:{meta.get('mood', 'neutral')}|"
        f"voyeur:{meta.get('voyeur_risk', 'none')}|"
        f"context:{meta.get('context_flag', 'ok')}"
    )
    exif["0th"][0x9C9F] = subj.encode("utf-16le")

    # XPTitle — body/clothing/risk/focus/flags policy fields
    policy = (
        f"body:{_arr_to_str(meta.get('body_parts'))}|"
        f"coverage:{meta.get('clothing_coverage', 'moderate')}|"
        f"fit:{meta.get('clothing_fit', 'fitted')}|"
        f"clothing:{_arr_to_str(meta.get('clothing_type'))}|"
        f"style:{_arr_to_str(meta.get('art_style'))}|"
        f"setting:{_arr_to_str(meta.get('setting'))}|"
        f"risk:{_arr_to_str(meta.get('risk_factors'))}|"
        f"focus:{_arr_to_str(meta.get('visual_focus'))}|"
        f"flags:{_arr_to_str(meta.get('policy_flags'))}"
    )
    exif["0th"][0x9C9B] = policy.encode("utf-16le")

    # ImageDescription + XPComment — free-form description
    desc = meta.get("description", "")
    if isinstance(desc, str) and desc:
        exif["0th"][0x010E] = desc.encode("utf-8")
        exif["0th"][0x9C9C] = desc.encode("utf-16le")

    exif_bytes = piexif.dump(exif)
    try:
        piexif.insert(exif_bytes, str(img_path))
    except Exception:
        # Fallback for files with unreadable/corrupt EXIF: re-save once
        # so piexif can attach clean tags. Lossy, but rare edge case.
        with Image.open(img_path) as im:
            im.convert("RGB").save(img_path, "JPEG", quality=95)
        piexif.insert(exif_bytes, str(img_path))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--json", help="Inline JSON string")
    grp.add_argument("--json-file", help="Path to a JSON file")
    args = ap.parse_args(argv)

    if args.json:
        meta = json.loads(args.json)
    else:
        with open(args.json_file, encoding="utf-8") as f:
            meta = json.load(f)

    write_exif(Path(args.image), meta)
    print(f"OK: wrote EXIF to {args.image}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
