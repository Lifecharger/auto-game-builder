"""
Shared PixelLab client — auto-reads API key from Auto Game Builder config.

Supports both SDK (v1) and direct API calls (v1 + v2).

Usage:
    from pixellab_client import get_client, get_api_key, api_post, api_post_v2
"""
import json
import os
import requests
from pathlib import Path
from pixellab.client import PixelLabClient

def _find_mcp_servers_file() -> Path:
    """Walk up from this file looking for Auto Game Builder's server/config/mcp_servers.json."""
    here = Path(os.path.abspath(__file__)).parent
    for parent in [here, *here.parents]:
        candidate = parent / "server" / "config" / "mcp_servers.json"
        if candidate.is_file():
            return candidate
    return here.parents[2] / "server" / "config" / "mcp_servers.json" if len(here.parents) >= 3 else here / "server" / "config" / "mcp_servers.json"


MCP_SERVERS_FILE = _find_mcp_servers_file()
API_V1 = "https://api.pixellab.ai/v1"
API_V2 = "https://api.pixellab.ai/v2"


def get_api_key() -> str:
    """Read PixelLab API key from Auto Game Builder's mcp_servers.json."""
    if MCP_SERVERS_FILE.is_file():
        with open(MCP_SERVERS_FILE, "r") as f:
            servers = json.load(f)
        key = servers.get("pixellab", {}).get("_api_key", "")
        if key:
            return key
    key = os.environ.get("PIXELLAB_SECRET", "")
    if key:
        return key
    raise RuntimeError("No PixelLab API key found in mcp_servers.json or PIXELLAB_SECRET env var")


def get_client() -> PixelLabClient:
    """Get a ready-to-use PixelLab SDK client (v1 endpoints)."""
    return PixelLabClient(secret=get_api_key())


def _headers() -> dict:
    return {"Authorization": f"Bearer {get_api_key()}"}


def api_post(endpoint: str, data: dict, version: str = "v1") -> dict:
    """POST to PixelLab API. version='v1' or 'v2'."""
    base = API_V2 if version == "v2" else API_V1
    resp = requests.post(
        f"{base}/{endpoint.lstrip('/')}",
        headers=_headers(),
        json=data,
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()


def api_get(endpoint: str, version: str = "v1") -> dict:
    """GET from PixelLab API."""
    base = API_V2 if version == "v2" else API_V1
    resp = requests.get(
        f"{base}/{endpoint.lstrip('/')}",
        headers=_headers(),
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def get_balance() -> dict:
    """Check account balance."""
    return api_get("/balance")


def image_to_base64(image_path: str) -> str:
    """Convert image file to base64 string for API requests."""
    import base64
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def save_base64_image(b64_data: str, output_path: str):
    """Save base64-encoded image data to file."""
    import base64
    data = base64.b64decode(b64_data)
    with open(output_path, "wb") as f:
        f.write(data)
    print(f"Saved: {output_path}")
