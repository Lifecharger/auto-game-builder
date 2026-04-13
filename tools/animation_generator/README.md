# 2D Animation Generator

UI-driven character asset pipeline for indie game dev, powered by Grok Imagine.

## What it does

Button-click workflow for turning a text prompt into a full character animation pack:

```
Text prompt
    ↓ Generate Base      →  01_south_base/
    ↓ i2i Directional    →  02_east/, 03_west/, 04_north/
    ↓ Pad Image          →  05_padded_for_anim/
    ↓ Animate            →  06_animations/
    ↓ Download Favorites →  fetches everything back from Grok
```

Each character gets its own folder under `projects/<name>/` with the canonical 6-stage structure. The projects directory defaults to `~/Documents/AnimationGenerator/` but you can override via the `ANIMATION_GENERATOR_PROJECTS_DIR` env var.

## Setup

```bash
cd "/c/Projects/Auto Game Builder/tools/animation_generator"
pip install -r requirements.txt
python -m playwright install chromium
python main.py
```

First run requires valid Grok cookies in `../grok/grok_download_history.json` (gitignored). If it's stale:
1. Log into `grok.com` in real Chrome
2. Copy the sso + sso-rw + cf_clearance cookies
3. Paste into the `cached_cookies` field of the JSON, or just re-run `grok_downloader.py` which will re-extract them via Playwright.

## Tools under the hood

This UI is a thin wrapper around the sibling vendor subfolders in `tools/`. On startup `main.py` adds `../grok/`, `../media/`, and `../tripo/` to `sys.path` and imports the scripts directly:

| Tool | Subfolder | Button | What it does |
|---|---|---|---|
| `grok_generate_image.py` | `../grok/` | 🎨 Generate Base | Text → image via Grok WebSocket (`--pro` for quality mode = 4 high-fidelity outputs) |
| `grok_i2i.py` | `../grok/` | 🔄 i2i Directional | Image + prompt → new image preserving character identity. For deriving east/west/north from a south base. |
| `pad_image.py` | `../media/` | 🖼️ Pad Image | Adds background-matched padding on all 4 sides so animations have room for sword swings / walk cycles. |
| `grok_animate.py` | `../grok/` | 🎬 Animate | Image + prompt → 6s or 10s video (image-to-video) at 480p or 720p. |
| `grok_downloader.py` | `../grok/` | ⬇️ Download Favorites | Pulls all recently-favorited Grok media to `~/Downloads/grok-favorites/` with prompt-based filenames. |
| `tripo_studio_api.py` | `../tripo/` | (available) | Tripo3D Studio browser-path for 3D character generation — refresh the JWT first via `../tripo/refresh_studio_token.py` when it expires. |

## Roadmap

- [ ] Thumbnail grid preview (not just one image at a time)
- [ ] Animation templates (click a preset: "walk cycle", "attack slash", etc.)
- [ ] Batch run (queue multiple animations and let them cook)
- [ ] Direct video playback in the preview pane
- [ ] Delete / rename / move buttons on the file list
- [ ] Export sprite sheets (video → PNG frame sequence)

## Not in scope

- Mobile/web UI — desktop only for now
- Alternative generators — Grok Imagine only for now
- Background task daemon — everything runs on-click

## Pipeline doc

See `../GROK_ASSET_PIPELINE.md` for the detailed hand-written playbook on what prompts work, how to frame characters, why 1:1 + pad beats direct 16:9, etc.

## Where it lived before

Originally a standalone repo at `C:/Projects/Animation Generator` with its own `tools/` folder duplicating grok + pad scripts. Merged into Auto Game Builder's `tools/animation_generator/` on 2026-04-13, with the duplicated scripts deleted in favor of importing from the shared vendor subfolders.
