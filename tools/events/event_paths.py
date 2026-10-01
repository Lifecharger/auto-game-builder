"""Machine-specific paths for the event queue scripts.

The repo is public -> no absolute path is written into code. Same pattern as tools/character/common.py
and tools/comfyui/kid_cbn.py: environment variable first, then the dotted key in
`server/config/settings.json` (git-ignored, per machine), then a portable default.

Keys:
  events.minigames_root  EVENTS_MINIGAMES_ROOT  v2 minigame work folder (<root>/<event>/_game_pipeline*.log)
  grok.bro_profile_dir   GROK_BRO_PROFILE_DIR   second logged-in Grok Playwright profile
                                                (default ~/.grok-playwright-bro)
"""
from __future__ import annotations

import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent
SETTINGS = AGB_ROOT / "server" / "config" / "settings.json"


def setting(key: str, env: str = "", default: str = "") -> str:
    """Dotted key from settings.json; a non-empty environment variable wins."""
    if env:
        v = os.environ.get(env, "").strip()
        if v:
            return v
    if SETTINGS.is_file():
        d = json.loads(SETTINGS.read_text(encoding="utf-8")) or {}
        for part in key.split("."):
            d = d.get(part) if isinstance(d, dict) else None
        if isinstance(d, str) and d.strip():
            return os.path.expanduser(os.path.expandvars(d.strip()))
    return default


def minigames_root() -> str:
    root = setting("events.minigames_root", "EVENTS_MINIGAMES_ROOT")
    if not root:
        raise SystemExit("events.minigames_root is not set: add it to server/config/settings.json "
                         "or set EVENTS_MINIGAMES_ROOT")
    return root.replace("\\", "/").rstrip("/")


def event_log(ev: str, name: str) -> str:
    """<minigames_root>/<event>/<name> - the log next to the event's pipeline output."""
    return "%s/%s/%s" % (minigames_root(), ev, name)


def bro_profile_dir() -> str:
    return setting("grok.bro_profile_dir", "GROK_BRO_PROFILE_DIR",
                   str(Path.home() / ".grok-playwright-bro"))


def bro_env() -> dict:
    """Environment for game_pipeline.py on the second Grok profile."""
    return dict(os.environ, GROK_PROFILE_DIR=bro_profile_dir())
