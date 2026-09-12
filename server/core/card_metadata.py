"""Card push metadata, using the same local vision schema as r2manager."""
import hashlib
import importlib.util
import json
from pathlib import Path
import urllib.request

from . import gpu_lane, jigsaw_flow


def tag_still(path: str, previous: dict | None, op_id: str) -> dict:
    source = Path(path)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if previous and previous.get("source_sha256") == digest:
        return previous
    schema_file = Path(__file__).resolve().parents[2] / "tools/r2manager/tagging_schema.py"
    spec = importlib.util.spec_from_file_location("card_tagging_schema", schema_file)
    schema = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(schema)
    url, model = jigsaw_flow._ollama_cfg()
    body = {"model": model, "stream": False, "format": schema._OLLAMA_TAG_SCHEMA,
            "keep_alive": 0, "options": {"temperature": 0.2, "num_predict": 1200},
            "messages": [{"role": "user", "content": schema._build_tag_prompt(source.name),
                          "images": [schema._image_b64_for_vlm(source)]}]}
    with gpu_lane.hold("kart etiketleme", "ollama", op_id=op_id, total=1):
        try:
            req = urllib.request.Request(url.rstrip("/") + "/api/chat", data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=240) as response:
                data = json.loads(json.load(response)["message"]["content"])
            for field in schema._OLLAMA_TAG_SCHEMA["required"]:
                if field not in data:
                    raise ValueError("Card metadata missing field: " + field)
            for field, rule in schema._OLLAMA_TAG_SCHEMA["properties"].items():
                value = data[field]
                if "enum" in rule and value not in rule["enum"]:
                    raise ValueError("Invalid card metadata: " + field)
                if rule["type"] == "string" and not isinstance(value, str):
                    raise ValueError("Invalid card metadata text: " + field)
                if rule["type"] == "integer" and (type(value) is not int or not 1 <= value <= 5):
                    raise ValueError("Invalid card metadata score: " + field)
                if rule["type"] == "array" and (not isinstance(value, list) or
                        any(not isinstance(v, str) for v in value)):
                    raise ValueError("Invalid card metadata list: " + field)
            subject = {out: data[src] for out, src in {
                "rating": "rating", "safety": "safety_level", "voyeur": "voyeur_risk",
                "skin": "skin_exposure", "adult": "adult", "racy": "racy", "violence": "violence",
                "camera": "camera_angle", "view": "view_type", "pose": "pose_type",
                "framing": "framing", "mood": "mood", "context": "context_flag"}.items()}
            title = {out: data[src] for out, src in {
                "coverage": "clothing_coverage", "fit": "clothing_fit", "risk": "risk_factors",
                "flags": "policy_flags", "body": "body_parts", "clothing": "clothing_type",
                "style": "art_style", "setting": "setting", "focus": "visual_focus"}.items()}
            return {"source_sha256": digest, "model": model, "subject_fields": subject,
                    "title_fields": title, "description": data["description"], "tags": data["tags"]}
        finally:
            jigsaw_flow.ollama_unload()
