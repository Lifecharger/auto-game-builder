# Tools Folder — Claude Reference

This folder is the user's general-purpose toolkit for asset generation, content creation, and automation. Each tool is self-contained and can be invoked from any project. Read this before reaching for an existing-tool or when unsure which tool fits a task.

## When to use what

| Tool | Purpose | Notes |
|---|---|---|
| `grok_generate_image.py` | Text → image via Grok Imagine WebSocket | Use `--pro` for quality mode (4 imgs, follows prompts well). Without `--pro` is faster but less faithful. |
| `grok_i2i.py` | Image → image (preserves character) | For deriving directional views, pose variants, or stylistic edits while keeping face/outfit consistent. |
| `grok_animate.py` | Image → video (animation) | Defaults to 6s/480p (cheapest). Auto-runs downloader after. Read `GROK_ASSET_PIPELINE.md` BEFORE running. |
| `grok_downloader.py` | Sync favorited Grok media to disk | Auto-called by animate/i2i. Standalone for manual sweeps. Uses Playwright cookies, not browser_cookie3. Renames files by prompt keywords for readability. |
| `pad_image.py` | Add background-matched horizontal padding | Always run between `grok_generate_image.py` / `grok_i2i.py` outputs and `grok_animate.py` inputs, so sword swings don't clip. Auto-samples bg color from image corners. |
| `pixellab_*.py` | Pixel art generation via PixelLab API/SDK | For low-res pixel sprites, not photorealistic. |
| `meshy_*.py` | 3D model generation via Meshy API | text-to-3D, image-to-3D, rigging, animation, retexture. |
| `blender_auto_splitter.py` | Split Blender FBX exports | Use after Mixamo or Meshy rigging. |
| `mixamo_bulk_download.py` | Bulk download Mixamo animations | Automation for character animation packs. |
| `extract_*.py` | Extract assets from game projects | Per-project extractors. |
| `video_to_frames.py` | Slice video → PNG frame sequence | Useful AFTER animating with grok_animate to make sprite sheets. |
| `png_to_pixel_array.py` | Convert PNG → game-engine-friendly pixel data | Bridges asset pipeline → code. |

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
  - Any `*.env` or API key files
  - Test outputs / generated media
- The user is Çağatay, an indie game dev shipping multiple Flutter/Godot games. Tools here serve all his projects (Animashift, Deathpin, Arcade Snake, etc.).
