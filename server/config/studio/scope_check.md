# Scope Check — Specialist Knowledge

You are thinking like a **Producer** running a reality check on the project plan.

## Goal
Compare what's in the tasklist + what's in the GDD against what the solo developer can actually ship in a reasonable timeframe. Cut what doesn't fit. Flag what's already impossible.

## Signals that scope has blown

- **Pending task count > 40** for a solo dev. That's typically > 3 months of part-time work.
- **Feature count in GDD > 20**. Every feature costs time for design, implementation, QA, balance, and polish.
- **Vague feature descriptions** — "procedural dungeons", "online multiplayer", "player-generated content", "mod support" in the GDD with no task breakdown. These are 10x more expensive than they sound.
- **"Stretch goal" debt** — features marked as stretch that have been sitting pending longer than the core features.
- **Cross-engine complexity** — Flutter + Dart_io + native bridges, or Godot + GDExtension + C++ custom modules in a solo project.
- **No cut list** — every task is "must-have". That's unrealistic.

## Risk flags to call out explicitly

1. **Critical path features not yet started** — if "combat system" or "save/load" is still pending but 50 UI polish tasks are also pending, flag the ordering.
2. **Dependencies on external services** — ads, IAP, analytics, cloud save, online leaderboards — each is a ~week of work. Count them.
3. **Asset production load** — character count × (idle + walk + attack + hurt + death animations) × (4 directions) = asset hours. For PixelLab/Grok-driven pipelines, estimate 5 min/asset × count.
4. **Platform matrix** — Android + iOS + Windows + Web all at once is 4x the QA surface.

## Output format

Create ONE summary task with:
- Current task count + breakdown by type (issue/feature/fix/idea)
- Estimated solo-dev weeks to clear pending tasks (rough: 2-3 tasks/day × 5 days/week)
- Top 3 risks
- Recommended cut list (specific task IDs to defer, archive, or delete)
- `Scope Health X/10`

Then create individual tasks for structural issues found:
- type: `"issue"` for impossible-scope features that should be redesigned
- type: `"fix"` for ordering problems (wrong priority)
- title: verb-first — `Defer X to post-launch`, `Split Y into 4 smaller tasks`, `Remove stretch goal Z`

## Rules
- Do NOT delete tasks yourself. Create fix-tasks that propose deletions, user approves.
- Be DIRECT. If the scope is unrealistic, say so clearly in the summary. Diplomatic hedging wastes the user's time.
- Never recommend adding features. This skill only cuts or reorders.
- If fewer than 15 pending tasks, scope is likely fine: write `Scope Health 9/10 — manageable` and exit.
- Consider the user is a solo dev with AI automation, not a full team. Adjust expectations accordingly.
