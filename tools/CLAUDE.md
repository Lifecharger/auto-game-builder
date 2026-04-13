# Tools Folder — Claude Reference

This folder is the user's general-purpose toolkit for asset generation, content creation, and automation. Tools are organized by vendor/category subfolders. Each tool is self-contained and can be invoked from any project. Read this before reaching for an existing tool or when unsure which tool fits a task.

## Folder layout

```
tools/
├── grok/                 # Grok Imagine text→image / image→image / image→video + downloader
├── pixellab/             # PixelLab API/SDK — pixel art, sprites, UI, backgrounds
├── meshy/                # Meshy AI — text/image → 3D, rigging, animation, retexture
├── tripo/                # Tripo3D — text/image → 3D, rigging, animation (official + studio-scraped APIs)
├── chrome/               # Chrome DevTools Protocol launcher + network capture
├── blender/              # Blender FBX splitter + Mixamo bulk downloader
├── extract/              # Per-project asset extractors (extract_all, extract_single, extract_elven_duty)
├── media/                # Image/video utilities (pad_image, video_to_frames, png_to_pixel_array)
├── pixel_guy/            # Merged Pixel Guy project (Flutter character viewer + Python pipeline)
├── comic_translator/     # Merged Comic Translator project (Gemini-powered comic translation)
├── animation_generator/  # Merged 2D Animation Generator (CustomTkinter UI wrapping grok/tripo/media)
├── dart/                 # Dart/Flutter test-mode asset generators
└── character_creator/    # Godot character creator WIP (gitignored)
```

## When to use what

| Tool | Subfolder | Purpose | Notes |
|---|---|---|---|
| `grok_generate_image.py` | `grok/` | Text → image via Grok Imagine WebSocket | Use `--pro` for quality mode (4 imgs). Without `--pro` is faster but less faithful. |
| `grok_i2i.py` | `grok/` | Image → image (preserves character) | For deriving directional views, pose variants, stylistic edits while keeping face/outfit consistent. |
| `grok_animate.py` | `grok/` | Image → video (animation) | Defaults to 6s/480p (cheapest). Auto-runs downloader after. Read `GROK_ASSET_PIPELINE.md` BEFORE running. |
| `grok_downloader.py` | `grok/` | Sync favorited Grok media to disk | Auto-called by animate/i2i. Uses Playwright cookies. Renames files by prompt keywords. |
| `pad_image.py` | `media/` | Add background-matched horizontal padding | Run between grok image outputs and grok_animate inputs so swings don't clip. |
| `pixellab_*.py` | `pixellab/` | Pixel art generation via PixelLab API/SDK | For low-res pixel sprites, not photorealistic. |
| `meshy_*.py` | `meshy/` | 3D model generation via Meshy API | text-to-3D, image-to-3D, rigging, animation, retexture. |
| `blender_auto_splitter.py` | `blender/` | Split Blender FBX exports | Use after Mixamo or Meshy rigging. |
| `mixamo_bulk_download.py` | `blender/` | Bulk download Mixamo animations | Set `MIXAMO_OUTPUT_DIR` env or use `--output`. |
| `extract_*.py` | `extract/` | Extract assets from game projects | Per-project extractors. |
| `chrome_cdp_launcher.py` | `chrome/` | Launch Chrome with CDP for Playwright/automation | Keeps per-profile cookies so you only log in once. |
| `cdp_network_capture.py` | `chrome/` | Capture network traffic via CDP | Companion to the launcher. |
| `video_to_frames.py` | `media/` | Slice video → PNG frame sequence | Useful AFTER animating with grok_animate to make sprite sheets. |
| `png_to_pixel_array.py` | `media/` | Convert PNG → game-engine-friendly pixel data | Bridges asset pipeline → code. |

## API key storage

All API keys live in the **gitignored** `server/config/mcp_servers.json` at the repo root, under `{vendor}._api_key`. The client modules (`meshy_client.py`, `pixellab_client.py`) walk upward from their script directory to find it, so moving them between folders still works. Env-var fallbacks: `MESHY_API_KEY`, `PIXELLAB_SECRET`, `GEMINI_API_KEY`, `ELEVENLABS_API_KEY`.

**Never hardcode a key as a fallback literal in source** — that's how the Meshy key leaked into the public repo on 2026-04-13 and had to be rotated.

## Critical reading

**`GROK_ASSET_PIPELINE.md`** — full game-asset workflow from base character to animated sprite. Read this before generating ANY character + animation pack so you don't keep asking the same questions every time.

Key things that doc answers definitively:
- Aspect ratio (always 16:9 for animatable sources, never 9:16)
- Sexy character baseline (tasteful: corset + miniskirt + knee boots, normal proportions, NOT bikini-armor unless explicitly asked)
- Workflow order: south base → i2i to other directions → animate → review one before batching
- Animation prompt template (static camera locked side view ...)
- Default video settings (6s + 480p, never bump unless asked)
- The 4-candidate pick rule (prefer neutral pose, not hero shot, for derivation)

## Auth + persistence

- All Grok tools share `grok_download_history.json` for cookies + download history (gitignored).
- Playwright persistent profile lives at `~/.grok-playwright` — keeps you logged in across runs.
- If sso cookies expire, refresh by exporting from real Chrome → paste into the JSON file's `cached_cookies` field.

## Project context

- This folder is part of the **public** Auto Game Builder repo. NEVER commit:
  - `grok_download_history.json` (contains sso tokens)
  - `tripo_config.json`, `tripo_studio_token.json` (contain Tripo credentials)
  - Any `*.env` or API key files
  - Test outputs / generated media
- The tools serve multiple game projects across different engines (Flutter, Godot, Unity). Each script is engine-agnostic — point it at paths and it generates assets.
