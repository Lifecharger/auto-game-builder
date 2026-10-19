"""Machine-specific settings for the standalone scripts under tools/.

The repo is public, so personal paths and e-mail addresses never live in code. They are
read from tools/local_settings.json (git-ignored). Copy tools/local_settings.example.json
to tools/local_settings.json and fill in your own values.

Scripts in a subfolder import this module by putting the tools folder on sys.path:

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import local_settings

Keys:
    keys_dir                       folder with signing keys, API key files and service accounts
    play_console_service_account   Google Play service-account JSON (uploads, listings, IAPs)
    play_publish_service_account   second Google Play service-account JSON (publishing API)
    projects_dir                   folder that holds the game projects
    reusable_assets_dir            shared asset library (R2 mirror, Grok downloads, ...)
    pipeline_root                  asset generation pipeline root (_Incoming, Hot CBN, ...)
    backup_dir                     folder with local backups
    owner_email                    Cloudflare account e-mail (Global API Key auth)
    reviews_dir                    history of Play reviews seen + replies sent (playstore/reviews.py)
"""
from __future__ import annotations

import json
import os
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
SETTINGS_FILE = TOOLS_DIR / "local_settings.json"
EXAMPLE_FILE = TOOLS_DIR / "local_settings.example.json"

_cache: dict | None = None


def _load() -> dict:
    global _cache
    if _cache is None:
        if not SETTINGS_FILE.is_file():
            raise RuntimeError(
                "Local settings file not found: %s - copy %s to it and fill in your values."
                % (SETTINGS_FILE, EXAMPLE_FILE.name))
        with open(SETTINGS_FILE, encoding="utf-8") as fh:
            _cache = json.load(fh)
    return _cache


def get(key: str) -> str:
    """Value of `key` (with ~ and environment variables expanded). Raises when it is missing."""
    value = _load().get(key)
    if value is None or (isinstance(value, str) and not value.strip()):
        raise RuntimeError(
            "Missing key '%s' in %s (see %s for the expected keys)."
            % (key, SETTINGS_FILE, EXAMPLE_FILE.name))
    if isinstance(value, str):
        return os.path.expanduser(os.path.expandvars(value.strip()))
    return value


def path(key: str, *parts: str) -> Path:
    """Path from a folder key, optionally joined with sub-parts."""
    return Path(get(key)).joinpath(*parts)


def key_file(name: str) -> Path:
    """A file inside keys_dir."""
    return path("keys_dir", name)
