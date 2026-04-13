"""
Shared Tripo3D client helpers — loads API key, provides async client,
and exposes constants used by the wrapper scripts.

API key lookup order:
    1. TRIPO_API_KEY environment variable
    2. Auto Game Builder's gitignored server/config/mcp_servers.json under tripo._api_key
    3. Local tripo_config.json next to this script (gitignored, legacy fallback)

Keys must start with `tsk_`. Get yours from https://platform.tripo3d.ai/
"""
import json
import os
from pathlib import Path

_SCRIPT_DIR = Path(__file__).parent.resolve()
CONFIG_FILE = _SCRIPT_DIR / "tripo_config.json"


def _find_mcp_servers_file() -> Path | None:
    """Walk up from this file looking for Auto Game Builder's server/config/mcp_servers.json."""
    for parent in [_SCRIPT_DIR, *_SCRIPT_DIR.parents]:
        candidate = parent / "server" / "config" / "mcp_servers.json"
        if candidate.is_file():
            return candidate
    return None

# Default output locations
DEFAULT_OUTPUT_DIR = Path(os.path.expanduser("~")) / "Downloads" / "tripo3d-output"

# Default model version — the newest production-ready one as of 2026-02
# (bump this when Tripo releases a newer v3.x)
DEFAULT_MODEL_VERSION = "v3.1-20260211"

# For character work we want:
#   - detailed geometry (crisper mesh features)
#   - detailed texture (game-ready PBR)
#   - Mixamo-compatible rig spec (so you can retarget any Mixamo animation later)
#   - FBX output (standard for Unity/Unreal/Godot/Blender)
CHARACTER_DEFAULTS = dict(
    model_version=DEFAULT_MODEL_VERSION,
    geometry_quality="detailed",
    texture_quality="detailed",
    pbr=True,
    texture=True,
    quad=True,                   # quad topology for better deformation
)


def load_api_key() -> str:
    # 1. Env var
    key = os.environ.get("TRIPO_API_KEY", "").strip()
    if key:
        return key
    # 2. Auto Game Builder's gitignored mcp_servers.json
    mcp_file = _find_mcp_servers_file()
    if mcp_file:
        try:
            with open(mcp_file, encoding="utf-8") as f:
                data = json.load(f)
            key = (data.get("tripo", {}).get("_api_key") or "").strip()
            if key:
                return key
        except Exception:
            pass
    # 3. Legacy local config file (gitignored)
    if CONFIG_FILE.is_file():
        try:
            with open(CONFIG_FILE, encoding="utf-8") as f:
                data = json.load(f)
            key = (data.get("api_key") or "").strip()
            if key:
                return key
        except Exception:
            pass
    raise RuntimeError(
        "No Tripo3D API key found. Set TRIPO_API_KEY env var, "
        "or add {\"tripo\": {\"_api_key\": \"tsk_...\"}} to "
        "server/config/mcp_servers.json. "
        "Get a key from https://platform.tripo3d.ai/"
    )


def save_api_key(key: str):
    """One-time helper to persist a key in the local config file."""
    key = key.strip()
    if not key.startswith("tsk_"):
        raise ValueError("Tripo API keys must start with 'tsk_'")
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump({"api_key": key}, f, indent=2)
    print(f"Saved API key to {CONFIG_FILE}")


def get_client():
    """Return an initialized TripoClient. Use as async context manager."""
    from tripo3d import TripoClient
    return TripoClient(api_key=load_api_key())


if __name__ == "__main__":
    # CLI helper: python tripo_client.py --save-key tsk_abcdef...
    import argparse
    p = argparse.ArgumentParser(description="Tripo3D config helper")
    p.add_argument("--save-key", help="Save API key to tripo_config.json")
    p.add_argument("--check-balance", action="store_true",
                   help="Verify API key works by fetching balance")
    args = p.parse_args()
    if args.save_key:
        save_api_key(args.save_key)
    if args.check_balance:
        import asyncio
        async def _check():
            async with get_client() as client:
                bal = await client.get_balance()
                print(f"Balance: {bal}")
        asyncio.run(_check())
    if not args.save_key and not args.check_balance:
        p.print_help()
