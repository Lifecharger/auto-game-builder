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

def _find_mcp_servers_file() -> Path:
    """Walk up from this file looking for Auto Game Builder's server/config/mcp_servers.json."""
    here = Path(os.path.abspath(__file__)).parent
    for parent in [here, *here.parents]:
        candidate = parent / "server" / "config" / "mcp_servers.json"
        if candidate.is_file():
            return candidate
    # Not found — return the expected path so error messages are still meaningful.
    return here.parents[2] / "server" / "config" / "mcp_servers.json" if len(here.parents) >= 3 else here / "server" / "config" / "mcp_servers.json"


MCP_SERVERS_FILE = _find_mcp_servers_file()


def get_api_key() -> str:
    """Read Meshy API key from Auto Game Builder's mcp_servers.json, falling back to env."""
    if MCP_SERVERS_FILE.is_file():
        with open(MCP_SERVERS_FILE, "r") as f:
            servers = json.load(f)
        key = servers.get("meshy", {}).get("_api_key", "")
        if key:
            return key
    key = os.environ.get("MESHY_API_KEY", "")
    if key:
        return key
    raise RuntimeError(
        "No Meshy API key found. Set it in server/config/mcp_servers.json "
        "under meshy._api_key, or export MESHY_API_KEY."
    )


def headers():
    return {
        "Authorization": f"Bearer {get_api_key()}",
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
