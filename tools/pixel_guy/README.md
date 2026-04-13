# Pixel Guy — character asset viewer

Flutter desktop UI + Python pipeline for curating and processing character sprite animations (extract frames from MP4 via Grok, remove backgrounds with BiRefNet/u2net, assign directional bins for 8-way animation rigs).

Originally lived at `C:/Projects/Pixel Guy` as a standalone repo; merged into Auto Game Builder's `tools/pixel_guy/` on 2026-04-13.

## Layout

```
pixel_guy/
  lib/                 Flutter desktop UI
  pipeline/            Python asset pipeline (engine.py + db.py + server.py)
  extract_all.py       Batch MP4 → rembg'd PNG frames
  extract_single.py    Single-video extraction with BiRefNet
  sam_breathe_split.py SAM-based upper/lower body split for breathing idle anims
  art_pipeline.md      Workflow notes + prompt templates
  android/ ios/ macos/ linux/ web/ windows/  Flutter platform scaffolds
```

## Running the Flutter UI (dev mode)

```bash
export PATH="/c/flutter/bin:$PATH"
cd "/c/Projects/Auto Game Builder/tools/pixel_guy"
flutter pub get
flutter run -d windows
```

The UI walks up from the executable (or CWD) looking for a sibling `pubspec.yaml` to find the assets/characters folder. You can override via env var `PIXEL_GUY_CHARS_DIR`.

## Running the extract scripts

```bash
cd "/c/Projects/Auto Game Builder/tools/pixel_guy"

# Batch: extract every .mp4 in ~/Downloads + ./assets/characters
python extract_all.py

# Or point at custom dirs:
python extract_all.py --chars-dir ./my_chars --downloads-dir /path/to/videos

# Single video with BiRefNet:
python extract_single.py --input video.mp4 --output ./out

# Use a specific Python interpreter (one with CUDA onnxruntime):
export PIXEL_GUY_PYTHON="/c/Python312/python.exe"
python extract_single.py --input video.mp4 --output ./out
```

## API keys

- **Gemini** / **ElevenLabs** — `pipeline/engine.py` walks up to find Auto Game Builder's gitignored `server/config/mcp_servers.json` under `gemini._api_key` / `elevenlabs._api_key`. Env vars `GEMINI_API_KEY` / `ELEVENLABS_API_KEY` also work as fallbacks.

## User state (gitignored)

- `projects.json` — list of character asset roots (user-local paths)
- `state.json` — UI dock layout and last selection
- `tasklist.json` — Claude Code task list
- `build/` and `assets/characters/` — generated content

See `art_pipeline.md` for the full workflow, prompt templates, and style references.
