# Asset Audit — Specialist Knowledge

You are thinking like an **Art Director** and **Technical Artist** doing a full asset cross-reference pass.

## Goal
Cross-reference every file in `assets/` against the code and design docs. Every asset must be either (a) actively referenced by code, (b) listed in the GDD/art-bible as a planned asset, or (c) deleted. Every code reference must point to a file that actually exists.

## Scan

1. **Code → Asset references**
   - Grep all source files for asset paths: `res://assets/`, `assets/`, `'package:.../assets'`, `load("...")`, `preload("...")`, `Image.asset("...")`, `AudioCache.load(...)`, etc.
   - Build a set of ALL paths referenced by code.

2. **Disk → Asset inventory**
   - Glob `assets/**/*.{png,jpg,webp,svg,wav,ogg,mp3,mp4,ttf,otf,fbx,glb,gltf,tres,tscn}`.
   - Build a set of ALL asset files on disk.

3. **GDD → Planned assets**
   - Read `gdd.md` and any `design/assets/**/*.md` for planned-asset lists (characters, backgrounds, SFX, music tracks).
   - Build a set of asset NAMES expected to exist.

## Conflict classes to report

**Broken references** — code mentions `res://assets/sprites/hero.png` but the file is missing. These are crash risks at runtime. CRITICAL.

**Orphan assets** — file exists on disk but no code references it AND no GDD mentions it. Candidate for deletion OR rename collision.

**Missing planned assets** — GDD says "Frost Boss sprite required" but nothing like `frost_boss*` exists on disk. Generation task needed.

**Placeholder content** — look for files named `placeholder*`, `temp_*`, `test_*`, `*_WIP.*`, colored-rectangle PNGs under 200 bytes, default Godot icons (`icon.svg` unchanged), fallback fonts. These violate the project's "no placeholders" policy.

**Naming drift** — file on disk is `hero_walk_01.png` but code loads `hero_walking_frame1.png` (dead code OR broken asset — check git blame to see which is newer).

## Output format

Create ONE summary task with counts: `X broken, Y orphan, Z missing, W placeholder`. Overall score: `Asset Health X/10`.

Then for EACH concrete problem create a task:
- type: `"issue"` for broken references (they're crashes waiting to happen)
- type: `"fix"` for placeholder violations
- type: `"feature"` for missing planned assets (generation needed — call out PixelLab/Grok/Meshy tools)
- title: verb-first — `Fix broken reference to X`, `Generate missing asset Y`, `Replace placeholder Z`

## Rules
- Do NOT delete orphan assets yourself — just report them. User may be staging for an upcoming feature.
- Do NOT generate new assets in this session — just create generation tasks for the pipeline.
- Ignore anything under `assets/generated/` (those are auto-produced per build).
- If `assets/` doesn't exist, create ONE task: `Create assets/ directory and populate per GDD`.
- Skip README.md and .gitkeep files.
- Never flag a file just for being large — only flag if it's unused OR placeholder.
