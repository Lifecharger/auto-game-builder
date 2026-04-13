# Comic Translator

CustomTkinter desktop app that extracts comic pages (.cbr/.cbz), sends each page to the Gemini CLI for bubble detection + English→Turkish translation, and re-renders the translated text back into each speech bubble's shape.

Originally lived at `C:/Projects/Comic Translator` as a standalone repo; merged into Auto Game Builder's `tools/comic_translator/` on 2026-04-13.

## Setup

```bash
cd "/c/Projects/Auto Game Builder/tools/comic_translator"
pip install -r requirements.txt

# Gemini CLI (used for vision + translation)
npm install -g @google/gemini-cli
gemini auth  # one-time auth flow
```

## Running

```bash
python main.py
```

The UI asks for a comic archive (.cbr / .cbz / .cb7) or a folder of PNG/JPG pages, extracts them via 7-Zip, then runs the Gemini pipeline page-by-page.

## Dependencies on external binaries

- **7-Zip** — used to extract `.cbr` (RAR) archives. The extractor looks in order:
  1. `SEVEN_ZIP` env var
  2. `7z` / `7z.exe` on `PATH`
  3. `%ProgramFiles%/7-Zip/7z.exe`
  4. `%ProgramFiles(x86)%/7-Zip/7z.exe`
- **Gemini CLI** — `gemini.cmd` under `%APPDATA%/npm/` on Windows, or anywhere on `PATH` elsewhere. Auth is handled by the CLI itself — no key lives in this repo.
- **Fonts** — `assets/fonts/Bangers-Regular.ttf` is bundled. Falls back to Arial/Comic/DejaVu from the system fonts dir.

## Files

```
comic_translator/
  main.py          Entry point — launches the CTk UI
  pipeline.py      Gemini CLI bridge — sends page to CLI, parses JSON response
  detector.py      Bubble detection (opencv contour-based)
  extractor.py     CBR/CBZ/CB7 archive extraction via 7-Zip
  renderer.py      Turkish text layout inside bubble contours (auto-sized)
  contour.py       Contour width sampling for text fitting
  config.json      User prefs (font, uppercase toggle, window size) — defaults shipped empty
  ui/              CTk widgets (app, preview, settings, table, toolbar)
  assets/fonts/    Bundled Bangers-Regular.ttf
```

## Notes

- Comics themselves live outside the repo — the user opens them from their `Downloads/` (or wherever). `config.json` ships with empty defaults; runtime changes are user-local and not committed (use `config.local.json` if you want to override and gitignore your personal state).
- Translation prompt template is in `pipeline.py:48` — defaults to "everyday spoken Turkish" with SFX localized (BOOM → GUM, CRASH → CARS).
