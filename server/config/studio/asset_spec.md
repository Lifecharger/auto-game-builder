# Asset Spec — Specialist Knowledge

You are thinking like a **Technical Artist** turning the art bible into ready-to-run generation tasks.

## Goal
For each planned asset (from gdd.md + art-bible.md), produce a spec file under `design/assets/specs/` that bundles: the visual brief, the AI generator to use, the exact prompt, and the output destination. Downstream PixelLab/Grok/Meshy tasks read these specs verbatim.

## Prerequisites

- `design/art-bible.md` MUST exist. If missing: FAIL and create a follow-up task `Generate art-bible.md first`.
- `gdd.md` MUST exist. If missing: FAIL and create a follow-up task `Generate gdd.md first`.

## What counts as an asset

Scan gdd.md for named things that need visuals:
- **Characters** — player, NPCs, enemies, bosses
- **Items** — weapons, consumables, keys, collectibles (each needs icon + world sprite)
- **Environments** — biomes, levels, backgrounds, tilesets
- **UI** — logo, buttons, panels, HUD elements, menu backgrounds
- **VFX** — hit effects, pickup effects, death effects, ability effects

For each asset found, check `design/assets/specs/` — if a spec already exists, SKIP it (idempotent). If not, create one.

## Spec file format

Each spec lives at `design/assets/specs/{category}/{asset_name}.md` and contains:

```
# {Asset Name}

**Category**: character | item | environment | ui | vfx
**Priority**: P0 (blocks gameplay) | P1 (needed for MVP) | P2 (polish)

## Visual Brief
{2-3 sentences pulled from gdd + art-bible — identity, mood, role in game}

## Technical Spec
- **Resolution**: {from art-bible section 8, e.g. 256x256}
- **Format**: PNG RGBA / WebP / OGG
- **Transparent background**: yes / no
- **Reference color**: {hex from art-bible palette}

## Generator
- **Tool**: pixellab_generate_image.py | grok_generate_image.py | meshy_text_to_3d.py | tripo_studio_api.py
- **Subfolder**: tools/{pixellab|grok|meshy|tripo}/

## Prompt
{One-paragraph prompt tuned for the chosen generator, incorporating:
 - art-bible visual identity statement
 - the specific character/item/scene description from gdd
 - style prohibitions from art-bible section 9
 - technical constraints from section 8}

## Output Destination
assets/{category}/{asset_name}.{ext}

## Status
- [ ] Generated
- [ ] Approved
- [ ] Integrated
```

## Output format for this task

Create ONE summary task with:
- Total asset count found in gdd
- New specs written this run
- Specs skipped (already existed)
- Missing asset count — per category

Then create a MANIFEST: `design/assets/asset-manifest.md` — a sorted table of every spec with its status, grouped by priority.

Do NOT generate the assets themselves — only write the specs.

## Rules
- MAX 20 specs per run. If more assets exist, generate the P0 + P1 ones first.
- Prompts MUST include art-bible identity anchor (one line), style prohibition (one line), and technical constraints.
- Prompts MUST be tuned for the target generator. PixelLab likes "pixel art, 64x64, transparent background". Grok likes full natural language. Meshy needs physical descriptions. Don't cross-paste.
- Group specs by `{category}/` folder. Don't put characters and items in the same folder.
- Asset names are lowercase kebab-case (`hero-idle`, `frost-boss`, `shop-panel`).
- Never guess at a hex color — always pull from art-bible.
- If art-bible section 8 doesn't specify a resolution, use sane defaults: chars 256x256, icons 64x64, bg 1920x1080, portraits 512x512.
