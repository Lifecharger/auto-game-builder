"""
Meshy AI API Client — shared base for all Meshy tools.
Handles auth, requests, polling, downloading.
"""

import os
import sys
import json
import time
import base64
import requests
from pathlib import Path

API_BASE = "https://api.meshy.ai"
API_KEY = os.environ.get("MESHY_API_KEY", "msy_UMpHAqbkZotRypdTTT1nN7adqEbDo0wfDebW")


def headers():
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }


def post(endpoint: str, payload: dict) -> dict:
    url = f"{API_BASE}{endpoint}"
    r = requests.post(url, headers=headers(), json=payload)
    if r.status_code >= 400:
        print(f"ERROR {r.status_code}: {r.text}", file=sys.stderr)
        sys.exit(1)
    return r.json()


def get(endpoint: str, params: dict = None) -> dict:
    url = f"{API_BASE}{endpoint}"
    r = requests.get(url, headers=headers(), params=params)
    if r.status_code >= 400:
        print(f"ERROR {r.status_code}: {r.text}", file=sys.stderr)
        sys.exit(1)
    return r.json()


def delete(endpoint: str) -> bool:
    url = f"{API_BASE}{endpoint}"
    r = requests.delete(url, headers=headers())
    return r.status_code < 400


def image_to_base64(path: str) -> str:
    p = Path(path)
    ext = p.suffix.lower()
    mime = "image/png" if ext == ".png" else "image/jpeg"
    data = p.read_bytes()
    b64 = base64.b64encode(data).decode()
    return f"data:{mime};base64,{b64}"


def model_to_base64(path: str) -> str:
    data = Path(path).read_bytes()
    b64 = base64.b64encode(data).decode()
    return f"data:application/octet-stream;base64,{b64}"


def poll_task(endpoint: str, task_id: str, interval: int = 10, timeout: int = 600) -> dict:
    url = f"{endpoint}/{task_id}"
    start = time.time()
    while True:
        result = get(url)
        status = result.get("status", "UNKNOWN")
        progress = result.get("progress", 0)
        print(f"  [{status}] {progress}%")

        if status == "SUCCEEDED":
            return result
        if status in ("FAILED", "CANCELED"):
            err = result.get("task_error", {}).get("message", "Unknown error")
            print(f"Task {status}: {err}", file=sys.stderr)
            sys.exit(1)
        if time.time() - start > timeout:
            print(f"Timeout after {timeout}s", file=sys.stderr)
            sys.exit(1)

        time.sleep(interval)


def download_model(url: str, output_path: str):
    r = requests.get(url, stream=True)
    r.raise_for_status()
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "wb") as f:
        for chunk in r.iter_content(8192):
            f.write(chunk)
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"  Downloaded: {output_path} ({size_mb:.1f} MB)")


def download_task_models(task: dict, output_dir: str, name_prefix: str, formats: list = None):
    if formats is None:
        formats = ["glb"]
    model_urls = task.get("model_urls", {})
    for fmt in formats:
        url = model_urls.get(fmt)
        if url:
            out = os.path.join(output_dir, f"{name_prefix}.{fmt}")
            download_model(url, out)

    # Download textures if available
    texture_urls = task.get("texture_urls", [])
    for i, tex in enumerate(texture_urls):
        for tex_type, tex_url in tex.items():
            if tex_url:
                out = os.path.join(output_dir, f"{name_prefix}_tex{i}_{tex_type}.png")
                download_model(tex_url, out)
