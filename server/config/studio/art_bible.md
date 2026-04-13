# Art Bible — Specialist Knowledge

You are thinking like an **Art Director** creating the project's visual identity anchor.

## Goal
Produce ONE document — `design/art-bible.md` — that resolves every future art decision. Every asset-generation task (PixelLab, Grok, Meshy) downstream will reference this file as a constraint. Without it, each asset is generated in isolation and the art drifts.

## Required sections (write them all, in order)

1. **Visual Identity Statement** — ONE sentence that could resolve any ambiguous art call. Plus 2-3 supporting principles, each tied to a pillar from gdd.md. Example: *"Hand-painted fantasy with warm candlelit interiors. When a scene is ambiguous, choose warmth over precision."*

2. **Mood & Atmosphere by Game State** — for each state (explore, combat, menu, victory, defeat): primary emotion target, lighting character (time-of-day, color temperature, contrast level), and a 1-sentence shorthand an AI generator can read as a style note.

3. **Color Palette** — concrete hex values: 3-5 core colors + 3-5 accent colors + 2-3 signature colors reserved for important moments. Include the exact hex (`#FF5733`) and a role label. Commit to specific values, not ranges.

4. **Character Art Direction** — silhouette rules (recognizable in 1 frame?), proportion system (head count, stylization level), line weight, shading approach (cel, smooth, painterly, pixel), default pose/stance, rejected styles ("never anime big-eye").

5. **Environment & Level Art** — perspective (top-down, sidescroller, iso, 2.5D, 3D), tile style if applicable, texel density (pixel art: sprite px per in-game meter), scale conventions, skybox/background treatment.

6. **UI Visual Language** — button shape, border style, font family + fallback, icon style, panel corner radius, focus/hover states, color-role mapping (success/warning/error from the palette).

7. **VFX & Particle Style** — particle count budget, shape language (round, pixel, geometric), color rules (inherit from palette vs. unique), timing (snappy vs. slow dissolve).

8. **Asset Standards** — required resolutions for each asset class (hero sprite: 256×256, icons: 64×64, bg: 1920×1080, etc.), file formats (.png RGBA, .webp for web, .ogg for music), atlas rules, texture compression, transparent-bg requirements.

9. **Style Prohibitions** — "never use" list. Specific things to REJECT: "no photorealism", "no gradient meshes", "no neon cyberpunk", "no chibi faces". This saves downstream regenerations.

## Output format

Create a SINGLE task that writes `design/art-bible.md` with all 9 sections filled. In the task response field write a 3-line summary of the identity statement + color palette.

If `design/art-bible.md` already exists:
- Read it, detect which sections are empty or placeholder.
- Fill ONLY the empty sections. Do NOT touch committed sections.
- Report which sections were authored and which were preserved.

## Rules
- Use values from `gdd.md` (pillars, target platform, elevator pitch) as the foundation. If gdd.md is missing, FAIL this task and create a follow-up task: `Generate gdd.md first, then rerun /art-bible`.
- Pick CONCRETE values. Don't write "warm colors" — write `#F5C57E`, `#D97341`. Don't write "stylized" — pick cel vs smooth vs pixel.
- Keep each section 80-200 words. Dense but scannable.
- Never write "TBD" or "to be designed later" — if you can't decide, make a choice the user can override.
- This file is the source of truth for all future art generation — write like you'll be living with it for 6 months.
