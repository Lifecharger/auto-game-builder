from pathlib import Path

def _build_tag_prompt(img_name: str) -> str:
    """Full-schema prompt matching the existing Hot Jigsaw - Pushed asset
    format 1:1. Windows cmd.exe mangles newlines in -p args, but this prompt
    is passed via stdin so multi-line is fine."""
    return (
        f'Analyze the image file "{img_name}" in the current directory.\n\n'
        'Output ONLY a single flat JSON object (no markdown, no code fences, no '
        'commentary). Use these exact keys:\n\n'
        '  "tags": string — 15-25 comma-separated keywords (subject/setting/style)\n'
        '  "description": string — 1 sentence\n'
        '  "adult": int 1-5 (1=fully clothed, 3=swimwear/lingerie, 5=nude)\n'
        '  "racy": int 1-5 (suggestiveness)\n'
        '  "violence": int 1-5\n'
        '  "rating": "kid" | "teen" | "adult"\n'
        '      Rule: "adult" only if adult>=3 OR racy>=4; "kid" only if adult<=1 AND '
        'racy<=1 AND violence<=1; otherwise "teen".\n'
        '  "safety_level": "safe" | "borderline" | "risky"\n'
        '  "camera_angle": e.g. "eye_level" | "low_angle" | "high_angle" | "over_shoulder"\n'
        '  "view_type": e.g. "frontal_view" | "back_view" | "side_view" | "three_quarter"\n'
        '  "pose_type": e.g. "neutral" | "suggestive" | "action" | "relaxed"\n'
        '  "framing": "full_body" | "upper_body" | "portrait" | "close_up"\n'
        '  "skin_exposure": "low" | "medium" | "high" | "very_high"\n'
        '  "mood": short free-form string (e.g. "elegant", "playful", "serious")\n'
        '  "voyeur_risk": "none" | "low" | "medium" | "high"\n'
        '  "context_flag": "ok" | "mismatch" (outfit vs setting)\n'
        '  "body_parts": array of strings (visible body parts like '
        '"cleavage","thighs","legs","arms","shoulders")\n'
        '  "clothing_coverage": "minimal" | "revealing" | "moderate" | "modest"\n'
        '  "clothing_fit": "loose" | "fitted" | "tight"\n'
        '  "clothing_type": array of strings (e.g. ["dress","evening gown"])\n'
        '  "art_style": array of strings (e.g. ["realistic","photorealistic"] or '
        '["anime","digital_art"])\n'
        '  "setting": array of strings (e.g. ["studio","urban","forest"])\n'
        '  "risk_factors": array of strings (e.g. ["cleavage","thigh_exposure",'
        '"suggestive_pose"]) — empty array [] if none\n'
        '  "visual_focus": array of strings (e.g. ["body","face","eyes"])\n'
        '  "policy_flags": array of strings (e.g. ["nudity","minor"]) — empty array [] if none\n\n'
        'Return ONLY the JSON object, no prose before or after.'
    )

def _image_b64_for_vlm(img_path: Path, long_side: int = 1024) -> str:
    """Kucultulmus JPEG (base64) - 7B VLM'e 1600 px gondermenin anlami yok."""
    import base64
    import io
    from PIL import Image
    with Image.open(img_path) as im:
        im = im.convert("RGB")
        w, h = im.size
        s = long_side / float(max(w, h))
        if s < 1:
            im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
    return base64.b64encode(buf.getvalue()).decode()

def _arr():
    return {"type": "array", "items": {"type": "string"}}

_OLLAMA_TAG_SCHEMA = {
    "type": "object",
    "properties": {
        "tags": {"type": "string"},
        "description": {"type": "string"},
        "adult": {"type": "integer"}, "racy": {"type": "integer"}, "violence": {"type": "integer"},
        "rating": {"type": "string", "enum": ["kid", "teen", "adult"]},
        "safety_level": {"type": "string", "enum": ["safe", "borderline", "risky"]},
        "camera_angle": {"type": "string"}, "view_type": {"type": "string"}, "pose_type": {"type": "string"},
        "framing": {"type": "string", "enum": ["full_body", "upper_body", "portrait", "close_up"]},
        "skin_exposure": {"type": "string", "enum": ["low", "medium", "high", "very_high"]},
        "mood": {"type": "string"},
        "voyeur_risk": {"type": "string", "enum": ["none", "low", "medium", "high"]},
        "context_flag": {"type": "string", "enum": ["ok", "mismatch"]},
        "body_parts": _arr(),
        "clothing_coverage": {"type": "string", "enum": ["minimal", "revealing", "moderate", "modest"]},
        "clothing_fit": {"type": "string", "enum": ["loose", "fitted", "tight"]},
        "clothing_type": _arr(), "art_style": _arr(), "setting": _arr(),
        "risk_factors": _arr(), "visual_focus": _arr(), "policy_flags": _arr(),
    },
    "required": ["tags", "description", "adult", "racy", "violence", "rating", "safety_level",
                 "camera_angle", "view_type", "pose_type", "framing", "skin_exposure", "mood",
                 "voyeur_risk", "context_flag", "body_parts", "clothing_coverage", "clothing_fit",
                 "clothing_type", "art_style", "setting", "risk_factors", "visual_focus", "policy_flags"],
}
