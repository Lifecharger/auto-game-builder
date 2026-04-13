"""
Tripo Studio direct API client — uses your web subscription credits.

Unlike the official tripo3d SDK (which requires separate tsk_* API credits
on a different billing pool), this talks to the Studio backend at
api.tripo3d.ai/v2/studio/* using the Bearer JWT captured from the web UI.
Credits come out of your Studio subscription (3000/mo on Professional).

Endpoints (reverse-engineered from studio.tripo3d.ai):
    POST /v2/studio/operation/image-prompt-model   — text-to-3D generation
    POST /v2/studio/progress                        — poll task status
    GET  /v2/studio/project/detail/v3/{project_id}  — fetch finished project
    GET  /v2/web/user/profile/payment               — account info + credit balance

Token location: tripo_studio_token.json (gitignored)

The JWT expires periodically. When it does, re-run the Chrome DevTools
network capture (tools/chrome/cdp_network_capture.py) against a logged-in
Chrome to grab a fresh one — takes 30 seconds. See tools/CHROME_CDP_HOWTO.md.

Usage:
    # Print balance
    python tripo_studio_api.py --balance

    # Text-to-3D (defaults to texture=True, parts=False, face_limit=50000)
    python tripo_studio_api.py --text "elven female warrior, T-pose, full body"

    # Cheaper draft
    python tripo_studio_api.py --text "..." --quality standard --face-limit 50000

    # Higher detail
    python tripo_studio_api.py --text "..." --quality detailed --face-limit 300000

    # Wait + download
    python tripo_studio_api.py --text "..." --wait --output ./out/
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests

_SCRIPT_DIR = Path(__file__).parent.resolve()
TOKEN_FILE = _SCRIPT_DIR / "tripo_studio_token.json"
API_BASE = "https://api.tripo3d.ai"


def load_token() -> str:
    env = os.environ.get("TRIPO_STUDIO_TOKEN", "").strip()
    if env:
        return env
    if TOKEN_FILE.is_file():
        with open(TOKEN_FILE, encoding="utf-8") as f:
            tok = json.load(f).get("bearer_token", "").strip()
            if tok:
                return tok
    raise RuntimeError(
        f"No Studio JWT found. Set TRIPO_STUDIO_TOKEN env var, or create "
        f"{TOKEN_FILE} with {{\"bearer_token\": \"eyJ...\"}}. Capture a fresh "
        f"one with tools/chrome/cdp_network_capture.py against a logged-in "
        f"Chrome on studio.tripo3d.ai."
    )


def save_token(token: str):
    token = token.strip().replace("Bearer ", "")
    if not token.startswith("eyJ"):
        raise ValueError("JWT tokens start with 'eyJ'")
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(TOKEN_FILE, "w", encoding="utf-8") as f:
        json.dump({"bearer_token": token}, f, indent=2)
    print(f"Saved token to {TOKEN_FILE}")


def _headers() -> dict:
    return {
        "Authorization": f"Bearer {load_token()}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
        "Origin": "https://studio.tripo3d.ai",
        "Referer": "https://studio.tripo3d.ai/",
    }


class TripoStudio:
    """Thin wrapper around the studio.tripo3d.ai backend."""

    def __init__(self, base: str = API_BASE):
        self.base = base

    def _post(self, path: str, body: dict) -> dict:
        r = requests.post(f"{self.base}{path}", json=body, headers=_headers(), timeout=60)
        r.raise_for_status()
        data = r.json()
        if data.get("code") != 0:
            raise RuntimeError(f"Studio API error on {path}: {data}")
        return data.get("data", {})

    def _get(self, path: str) -> dict:
        r = requests.get(f"{self.base}{path}", headers=_headers(), timeout=60)
        r.raise_for_status()
        data = r.json()
        if data.get("code") != 0:
            raise RuntimeError(f"Studio API error on {path}: {data}")
        return data.get("data", {})

    def balance(self) -> dict:
        return self._get("/v2/web/user/profile/payment")

    def text_to_model(self, prompt: str, *,
                       model_version: str = "v3.1-20260211",
                       geometry_quality: str = "standard",
                       texture: bool = True,
                       generate_parts: bool = False,
                       smart_poly: bool = False,
                       quad: bool = False,
                       face_limit: int = 50000,
                       t_pose: bool = True,
                       visibility: str = "public",
                       sketch_to_render: bool = False,
                       gen_image_model_version: str = "flux.1_dev") -> dict:
        body = {
            "prompt": prompt,
            "model_version": model_version,
            "geometry_quality": geometry_quality,
            "texture": texture,
            "generate_parts": generate_parts,
            "smart_poly": smart_poly,
            "quad": quad,
            "face_limit": face_limit,
            "t_pose": t_pose,
            "visibility": visibility,
            "sketch_to_render": sketch_to_render,
            "gen_image_model_version": gen_image_model_version,
        }
        return self._post("/v2/studio/operation/image-prompt-model", body)

    def progress(self, operator_ids: list) -> list:
        return self._post("/v2/studio/progress", {"ids": operator_ids})

    def wait_for(self, operator_id: str, timeout: float = 900, poll_interval: float = 3.0) -> dict:
        deadline = time.time() + timeout
        last_status, last_progress = None, -1
        while time.time() < deadline:
            items = self.progress([operator_id])
            if items:
                item = items[0]
                status = item.get("status")
                progress = item.get("progress", 0)
                if status != last_status or progress != last_progress:
                    print(f"  [{status}] progress={progress}  left_time={item.get('left_time')}")
                    last_status, last_progress = status, progress
                if status in ("success", "failed", "error", "cancelled"):
                    return item
            time.sleep(poll_interval)
        raise TimeoutError(f"Operator {operator_id} timed out after {timeout}s")

    def project_detail(self, project_id: str) -> dict:
        return self._get(f"/v2/studio/project/detail/v3/{project_id}")


def main():
    p = argparse.ArgumentParser(description="Tripo Studio backend API client (uses web subscription credits)")
    p.add_argument("--balance", action="store_true", help="Print subscription + credit info")
    p.add_argument("--save-token", help="Save a fresh Bearer JWT (eyJ... format, no 'Bearer ' prefix)")
    p.add_argument("--text", help="Text prompt for text-to-3D generation")
    p.add_argument("--quality", default="standard", choices=["standard", "detailed"])
    p.add_argument("--texture", default="true", choices=["true", "false"])
    p.add_argument("--parts", default="false", choices=["true", "false"])
    p.add_argument("--face-limit", type=int, default=50000)
    p.add_argument("--t-pose", default="true", choices=["true", "false"])
    p.add_argument("--wait", action="store_true", help="Poll until the generation completes")
    p.add_argument("--output", help="Download the finished model(s) to this directory")
    args = p.parse_args()

    if args.save_token:
        save_token(args.save_token)
        return

    client = TripoStudio()

    if args.balance:
        info = client.balance()
        print(json.dumps(info, indent=2, ensure_ascii=False))
        return

    if not args.text:
        p.error("--text is required (or use --balance)")

    result = client.text_to_model(
        prompt=args.text,
        geometry_quality=args.quality,
        texture=args.texture == "true",
        generate_parts=args.parts == "true",
        face_limit=args.face_limit,
        t_pose=args.t_pose == "true",
    )
    print(f"Submitted: project_id={result.get('project_id')}  operator_id={result.get('operator_id')}")

    if args.wait:
        print("Polling...")
        final = client.wait_for(result["operator_id"], timeout=900)
        print(f"\nFinal status: {final.get('status')}")
        if final.get("status") == "success":
            detail = client.project_detail(result["project_id"])
            print("\nProject detail (first 3000 chars):")
            print(json.dumps(detail, indent=2, ensure_ascii=False)[:3000])
            model_url = detail.get("model_url") or ""
            if args.output and model_url:
                out_dir = Path(args.output)
                out_dir.mkdir(parents=True, exist_ok=True)
                ext = model_url.split("?")[0].split(".")[-1]
                out_file = out_dir / f"{result['project_id']}.{ext}"
                print(f"\nDownloading {model_url[:80]}... -> {out_file}")
                r = requests.get(model_url, timeout=300)
                r.raise_for_status()
                out_file.write_bytes(r.content)
                print(f"  Saved: {out_file} ({out_file.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
