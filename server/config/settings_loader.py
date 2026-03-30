"""Settings loader — reads config/settings.json and provides resolved paths.

All server code should call get_settings() to get resolved paths instead of
hardcoding anything. Paths support ~ expansion and {placeholder} references.
"""

import json
import os
import platform
import shutil
from pathlib import Path
from typing import Optional

_CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
_SETTINGS_PATH = os.path.join(_CONFIG_DIR, "settings.json")
_EXAMPLE_PATH = os.path.join(_CONFIG_DIR, "settings.example.json")

_cached_settings: Optional[dict] = None


def _detect_bash() -> str:
    """Auto-detect bash path based on OS."""
    system = platform.system()
    if system == "Windows":
        candidates = [
            r"C:\Program Files\Git\bin\bash.exe",
            r"C:\Program Files (x86)\Git\bin\bash.exe",
            os.path.expandvars(r"%LOCALAPPDATA%\Programs\Git\bin\bash.exe"),
        ]
        for c in candidates:
            if os.path.isfile(c):
                return c
        # Try PATH
        found = shutil.which("bash")
        return found or "bash"
    else:
        return shutil.which("bash") or "/bin/bash"


def _detect_tool(name: str) -> str:
    """Try to find a tool on PATH."""
    found = shutil.which(name)
    return found or ""


def _expand_path(p: str) -> str:
    """Expand ~ and environment variables in a path."""
    if not p:
        return ""
    return os.path.expanduser(os.path.expandvars(p))


def _load_raw() -> dict:
    """Load raw settings from file, falling back to example."""
    if os.path.isfile(_SETTINGS_PATH):
        with open(_SETTINGS_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    if os.path.isfile(_EXAMPLE_PATH):
        with open(_EXAMPLE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def get_settings(force_reload: bool = False) -> dict:
    """Load and resolve all settings. Results are cached.

    Returns a flat dict with resolved paths:
        settings["claude_path"]  -> "/home/user/.local/bin/claude"
        settings["projects_root"] -> "/home/user/Projects"
        settings["port"] -> 8000
        etc.
    """
    global _cached_settings
    if _cached_settings is not None and not force_reload:
        return _cached_settings

    raw = _load_raw()

    # Flatten nested structure
    flat = {}
    for section in raw.values():
        if isinstance(section, dict):
            flat.update(section)
        # Skip non-dict top-level values

    # Expand all path values
    for key in list(flat.keys()):
        val = flat[key]
        if isinstance(val, str) and ("/" in val or "\\" in val or "~" in val):
            flat[key] = _expand_path(val)

    # Auto-detect missing tools
    if not flat.get("bash_path"):
        flat["bash_path"] = _detect_bash()
    if not flat.get("claude_path"):
        flat["claude_path"] = _detect_tool("claude") or ""
    if not flat.get("gemini_path"):
        flat["gemini_path"] = _detect_tool("gemini") or ""
    if not flat.get("codex_path"):
        flat["codex_path"] = _detect_tool("codex") or ""
    if not flat.get("flutter_path"):
        flat["flutter_path"] = _detect_tool("flutter") or ""
    if not flat.get("godot_path"):
        flat["godot_path"] = _detect_tool("godot") or ""
    if not flat.get("aider_path"):
        flat["aider_path"] = _detect_tool("aider") or ""
    if not flat.get("cloudflared_path"):
        flat["cloudflared_path"] = _detect_tool("cloudflared") or ""
    if not flat.get("wrangler_path"):
        flat["wrangler_path"] = _detect_tool("wrangler") or ""
    if not flat.get("npx_path"):
        flat["npx_path"] = _detect_tool("npx") or ""

    # Ensure projects_root exists and is absolute
    if not flat.get("projects_root"):
        flat["projects_root"] = os.path.join(str(Path.home()), "Projects")
    flat["projects_root"] = os.path.abspath(flat["projects_root"])

    # Defaults
    flat.setdefault("host", "0.0.0.0")
    flat.setdefault("port", 8000)
    flat.setdefault("tunnel_enabled", False)
    flat.setdefault("kv_namespace_id", "")
    flat.setdefault("account_id", "")
    flat.setdefault("keys_dir", "")
    flat.setdefault("tools_dir", "")
    flat.setdefault("service_account_key", "")
    flat.setdefault("ollama_url", "http://localhost:11434")

    _cached_settings = flat
    return flat


def save_settings(settings_dict: dict) -> None:
    """Save settings to config/settings.json in the nested format."""
    structured = {
        "server": {
            "host": settings_dict.get("host", "0.0.0.0"),
            "port": settings_dict.get("port", 8000),
        },
        "paths": {
            "projects_root": settings_dict.get("projects_root", ""),
            "keys_dir": settings_dict.get("keys_dir", ""),
            "tools_dir": settings_dict.get("tools_dir", ""),
            "service_account_key": settings_dict.get("service_account_key", ""),
        },
        "ai_agents": {
            "claude_path": settings_dict.get("claude_path", ""),
            "gemini_path": settings_dict.get("gemini_path", ""),
            "codex_path": settings_dict.get("codex_path", ""),
            "aider_path": settings_dict.get("aider_path", ""),
        },
        "engines": {
            "godot_path": settings_dict.get("godot_path", ""),
            "flutter_path": settings_dict.get("flutter_path", ""),
        },
        "system": {
            "bash_path": settings_dict.get("bash_path", ""),
            "cloudflared_path": settings_dict.get("cloudflared_path", ""),
            "npx_path": settings_dict.get("npx_path", ""),
            "wrangler_path": settings_dict.get("wrangler_path", ""),
        },
        "cloudflare": {
            "tunnel_enabled": settings_dict.get("tunnel_enabled", False),
            "kv_namespace_id": settings_dict.get("kv_namespace_id", ""),
            "account_id": settings_dict.get("account_id", ""),
            "worker_url": settings_dict.get("worker_url", ""),
        },
        "services": {
            "ollama_url": settings_dict.get("ollama_url", "http://localhost:11434"),
        },
        "developer": {
            "developer_name": settings_dict.get("developer_name", ""),
        },
    }
    os.makedirs(_CONFIG_DIR, exist_ok=True)
    with open(_SETTINGS_PATH, "w", encoding="utf-8") as f:
        json.dump(structured, f, indent=2)


def settings_exist() -> bool:
    """Check if user has run setup."""
    return os.path.isfile(_SETTINGS_PATH)
