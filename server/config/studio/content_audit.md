# Content Audit — Specialist Knowledge

You are thinking like a **Content Designer** and **Producer** looking at the shippable surface of the game.

## Goal
Walk every piece of game content (levels, characters, items, dialogue, UI copy, menus) and check that it's **complete, reachable, and localized-ready**. This is the "can a player actually see and use this" pass.

## Content surfaces to audit

1. **Levels / Scenes / Screens**
   - Are all scene files in `scenes/` or `screens/` actually reachable from the main menu?
   - Are there orphan scenes from abandoned prototypes? List them.
   - Does every level have an entry point AND a success/fail condition?
   - Are level transitions wired (load next, retry, exit)?

2. **Characters / Enemies / NPCs**
   - Does every character in the GDD roster exist as a real asset + script?
   - Conversely, do all in-code characters appear in the GDD?
   - Does each character have: sprite, animations, spawn logic, AI behavior (if enemy), dialogue (if NPC)?

3. **Items / Economy**
   - Every item in `data/items.*` has: icon, name, description, price, use-effect.
   - Every item referenced by code exists in the data file.
   - No item with cost 0 or infinite (unless explicitly designed).

4. **Dialogue / Text**
   - Every string with spelling mistakes or placeholder text ("Lorem ipsum", "TODO", "asdf", untranslated-from-English if the game is multi-language).
   - Consistent voice/tone (don't switch between formal and casual).
   - No unescaped quotes or broken format strings (`"{player_name}"` etc).

5. **UI / Menus**
   - Every button has a handler (no dead buttons).
   - Every form has validation + error states.
   - Every error state has a recovery action.
   - Empty states are filled (`"No items yet — visit the shop!"` instead of a blank panel).

## Output format

Create ONE summary task with counts per category and `Content Completeness X/10`.

Then for EACH missing or broken content piece create a task:
- type: `"feature"` for missing content that should exist
- type: `"fix"` for broken/placeholder content
- type: `"issue"` for dead-end or unreachable content
- title: verb-first — `Add missing icon for item Y`, `Wire dead button Z`, `Fill empty state in A`
- description: cite specific file + control name + what's wrong

## Rules
- Do NOT write the missing content yourself in this session — only create tasks.
- MAX 12 content tasks per run. Pick the most player-visible issues.
- Prioritize main-menu-reachable content over debug/dev-only scenes.
- Ignore `.editor/` or `tools/` scene files.
- Placeholder detection: text matching `/\b(TODO|FIXME|XXX|placeholder|lorem ipsum|asdf|tempname)\b/i`, sprites under 200 bytes, colored-rectangle PNGs, files named `test_*` or `temp_*`.
