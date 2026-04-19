"""Local config for r2manager. Copy to config.py and fill in your values.

config.py is gitignored; this config.example.py is the committed template.
Every value here is user-/machine-specific and must NOT live in app.py.
"""
import os
import shutil
from pathlib import Path


# Incoming assets (where new downloads land).
DOWNLOADS = Path(r"C:\Users\YOU\Downloads")

# Staging area where un-pushed assets wait, keyed by content rating.
STAGING_ROOTS = {
    "Teen": Path(r"C:\Path\To\Hot Jigsaw Staging"),
    "Kid":  Path(r"C:\Path\To\Kid Jigsaw Staging"),
}

# Pushed (already uploaded to R2) archive folders.
PUSHED_ROOTS = {
    "Hot Jigsaw (teen)": Path(r"C:\Path\To\Hot Jigsaw - Pushed"),
    "Kid Jigsaw (kid)":  Path(r"C:\Path\To\Kid Jigsaw - Pushed"),
}

# Cloudflare R2 bucket names by rating — matches BUCKET_BY_RATING in app.py.
BUCKET_BY_RATING = {
    "Teen": "your-teen-bucket-name",
    "Kid":  "your-kid-bucket-name",
}

# Wrangler CLI for R2 uploads. Auto-detects PATH; override here if installed elsewhere.
# R2 credentials themselves live in wrangler's own config (`wrangler login`), not here.
WRANGLER_BIN = (
    shutil.which("wrangler.cmd")
    or shutil.which("wrangler")
    or r"C:\Users\YOU\AppData\Roaming\npm\wrangler.cmd"
)

# ElevenLabs API key for music generation.
# Prefer the ELEVENLABS_API_KEY environment variable. NEVER commit a real key.
ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY") or ""
