# Consistency Check — Specialist Knowledge

You are thinking like a **Technical Writer** and **QA Lead** hunting cross-document drift.

## Goal
Detect entities (items, characters, systems, formulas) that appear in multiple places with conflicting values. The longer a project runs, the more GDD and code drift apart — this skill closes that gap.

## What to scan
- `gdd.md` and any `design/**/*.md` docs for named entities: items, characters, enemies, weapons, upgrades, skills, levels, biomes.
- Code data files: `data/*.json`, `data/*.tres`, `data/*.yaml`, `scripts/**/*_config.gd`, `lib/**/*_data.dart` — anywhere prices, stats, or formulas live.
- String constants and enums that look like entity names (e.g. `ENEMY_TYPE_GOBLIN`, `ITEM_SWORD_BASIC`).

## Conflict types to flag

1. **Same name, different stats** — "Goblin" in gdd.md has HP 50, but `data/enemies.json` has HP 80.
2. **Same item, different prices** — "Iron Sword" costs 100 gold in the GDD narrative, 150 in the shop data file.
3. **Same formula, different variables** — damage formula uses `attack - defense` in docs but `attack * (1 - defense/100)` in code.
4. **Orphan references** — GDD mentions an enemy/item/system that has no corresponding data or script.
5. **Dangling data** — data file defines an entity that's never referenced in GDD or loaded in code.
6. **Unit drift** — "speed 200" in one file, "speed 200 px/s" in another, "speed 10 m/s" in a third. Pick one unit and enforce it.

## Output format

Create ONE summary task as the parent with overall health (`Consistency Score X/10`). Then create SEPARATE new tasks for each concrete fix:

- type: `"fix"`
- title: starts with verb — `Fix X value drift`, `Remove orphan reference to Y`, `Align Z formula between GDD and code`
- description: cite BOTH locations with file path and section/line, and say which value is the source of truth

## Rules
- Do NOT rewrite the GDD or data files yourself in this task. Only create fix-tasks.
- If the conflict count is zero, write `Consistency Score 10/10 — all checked entities aligned` and do not create fix-tasks.
- Skip cosmetic/spelling differences; focus on numeric + behavioral divergence.
- Prioritize player-facing drift (stats, prices, progression) over internal drift (debug flags, dev tools).
- Never generate tasks that just say "review for consistency" — every task must name a specific entity + a specific correction.
