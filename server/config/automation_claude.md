# Automation General Instructions

## Task Size Rules — MICRO TASKS ONLY
Every task you generate MUST be completable in a SINGLE session (max 30 minutes of AI work).

### What makes a good micro-task:
- ONE specific, clearly scoped change
- Touches at most 2-3 files
- Has a clear "done" condition that doesn't require visual testing
- Example: "Add health bar UI node to player scene" NOT "Implement full health system"
- Example: "Create inventory data model with item slots" NOT "Build inventory screen"
- Example: "Add jump animation state to player AnimationTree" NOT "Polish all player animations"
- Example: "Fix null check crash in score_manager.gd line 45" NOT "Fix all bugs on colony screen"

### What to NEVER generate:
- Vague tasks like "fill empty screen" or "implement X system end-to-end"
- Tasks that say "complete", "full", "entire", "all" — these are too big
- Tasks requiring multiple unrelated changes bundled together
- Tasks that need visual/manual testing to verify (the AI cannot see the screen)
- Tasks like "fix colony screen" — instead break into: "add colony list UI nodes", "connect colony data to UI labels", "add colony selection signal handler", etc.

### Task Generation Rules:
1. Generate as many micro-tasks as you can identify — there is no cap. Create every useful task you see.
2. Each task title must start with a verb: Add, Fix, Create, Connect, Remove, Rename, Refactor, Update, Extract
3. Each task description must specify EXACTLY which file(s) to modify
4. If an improvement needs multiple steps, create separate tasks for each step — they will be done in sequence by future sessions
5. Prefer tasks that can be verified by building successfully (no runtime/visual verification needed)

## NEVER Use Placeholders — Generate Real Assets
- NEVER use placeholder art, placeholder text, placeholder icons, or TODO comments for assets
- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT using the tools in `{tools_dir}/pixellab/`:
  - `pixellab_generate_image.py` — pixel art sprites, icons, items
  - `pixellab_generate_background.py` — full game backgrounds (topdown, sidescroller, parallax, menu, battle, isometric)
  - `pixellab_generate_ui.py` — UI elements (buttons, health bars, panels)
  For photorealistic / non-pixel art, use `{tools_dir}/grok/grok_generate_image.py` instead.
  For 3D models, use `{tools_dir}/meshy/` or `{tools_dir}/tripo/` scripts.

- If you cannot generate the asset (no credits, rate limited, tool error), mark the task as "failed" with a clear explanation. Do NOT substitute a colored rectangle or placeholder file.
- If a task requires art you cannot generate, create a follow-up task specifically for asset generation.
- NEVER use animation fallbacks (static sprites, single-frame "animations", or skipping animations). If a task needs an animation, GENERATE IT using PixelLab MCP (animate_character) or SDK tools. If generation fails, mark the task as "failed".

## Code Quality Rules — APPLY WHILE WRITING, NOT AFTER
These rules MUST be followed as you write code. Do NOT write sloppy code and expect a later code review to clean it up — write it correctly the first time. A later review is a safety net, not an excuse.

### General
- Always verify the project builds after your changes — ALWAYS wrap build commands in `timeout 300` (e.g. `timeout 300 <build cmd> 2>&1 | tail -50`). Godot's Android export on Windows can hang post-APK, and Gradle daemons can stall. If the timeout fires but the artifact (APK/AAB) exists with a recent mtime, the build succeeded.
- Do NOT leave debug prints or placeholder comments
- Do NOT add features that aren't described in the task
- Stay focused — one task, one change, move on
- NEVER bump the app version (do NOT edit `version:` in pubspec.yaml, `version/name`/`version/code` in export_presets.cfg, or `version` in package.json/build.gradle). The deploy pipeline bumps the version automatically on every build — bumping it here causes a double-bump.

### Crash Safety (write these guards AS you write the code, not as a later fix)
- Null/validity guards: check `is_instance_valid(node)` before accessing nodes that could be freed.
- After every `await`: re-check that `self` and referenced nodes still exist.
- Disconnect signals in `_exit_tree()` to prevent ghost callbacks.
- Validate array index against `.size()` before access; use `.get(key, default)` for dictionaries, not `dict[key]`.
- Use typed variables, typed arrays (`Array[Enemy]`), and typed return values.

### Architecture (write the code right the first time)
- Single Responsibility: one script/widget/module = ONE system. Never mix player movement + inventory + UI in one file.
- Data flows DOWN (parent → child via props/exports), events flow UP (signals/callbacks). Never direct parent references.
- No circular dependencies between scripts/modules.
- Cache node refs in `_ready()` — never call `get_node()` or `find_child()` inside `_process()`/`_physics_process()`.
- Keep scripts under ~500 lines. If a new change would push past 500, split BEFORE the change, not after.

### Anti-Patterns to AVOID while writing (not just flag in review)
- Magic numbers: use a named constant (`const LOW_HEALTH_THRESHOLD := 50`), never `if health < 50`.
- String-typed state: use enums, never `state == "running"`.
- Deep nesting: if you pass 3 levels of if/for indentation, extract a function instead.
- Copy-paste: if you are about to duplicate a 3rd similar block, extract a function first.
- Silent `except: pass` / `catch (_) {}`: log and propagate, or handle explicitly.
- Hardcoded economy/balance values: always load from a config/data file.

### Mobile UI (Flutter)
- Touch targets minimum 48x48 dp.
- Every meaningful action needs visual + audio + state feedback.
- Never show hardcoded prices — load at runtime from Google Play Billing / App Store.
- Wrap root scaffolds in `SafeArea` so content is not hidden under the system gesture bar.

If you finish writing a change and any of the above rules are violated, fix them in the same session BEFORE marking the task completed. Do not leave the fix for a future review pass.

## Handling Oversized Tasks
When you pick up a pending task that is TOO BIG to finish in one session:
1. Do NOT attempt it and waste the session
2. FIRST create the sub-tasks as new entries in tasklist.json (status "pending", type same as parent). Each sub-task must be micro-sized (completable in 30 min). Write them to the file and SAVE immediately.
3. THEN mark the parent task's "status" to "divided" with response listing the sub-task IDs you created. SAVE immediately.
4. Then pick one of the new sub-tasks and work on it.
CRITICAL: Sub-tasks MUST exist in tasklist.json BEFORE you mark the parent as "divided". If you mark divided without creating sub-tasks, the task is lost.

Signs a task is too big:
- It mentions multiple screens, systems, or features
- It says words like "complete", "full", "entire", "all", "implement X system"
- It would require touching 5+ files
- It has no clear single "done" condition
- Previous attempts failed on this task (check the response field for failure history)

## Session Efficiency
- Work through as many pending tasks as you can within the session timeout.
- If a task is taking too long or seems bigger than expected, mark it "divided", create micro sub-tasks, then move on to the next task.
- If you're stuck on a task for more than 20 minutes, divide it and move on.

## Game Studio Quality Standards

### Design-First Thinking
- Before implementing a feature, check if gdd.md describes the expected behavior. If it does, follow the spec exactly.
- If the GDD is silent on a mechanic, implement the simplest reasonable version and note the assumption in the task response.
- Economy values (prices, rewards, XP curves, timers) MUST be loaded from data files (JSON/config), NEVER hardcoded.
- Every player-facing change should improve one of: engagement, retention, monetization, or accessibility.

### Player Experience Lens
- Think like a PLAYER, not a developer. Ask "is this fun?" and "is this clear?" before "is this elegant?"
- Every action needs feedback: visual (tween/animation), audio (click/chime), and state change (UI update).
- Touch targets minimum 48x48dp on mobile. No exceptions.
- Empty states need content ("No items yet!"), not blank screens.
- Error messages must be human-readable, not error codes.
- Loading states must be visible — never leave the player staring at a frozen screen.

### Code Architecture Rules
- Single Responsibility: one script = one system. Don't let scripts grow beyond 500 lines.
- Data flows DOWN (parent → child), events flow UP (signals/callbacks). Never reverse this.
- No circular dependencies between scripts.
- Cache node references in _ready(), never call get_node() in _process().
- Use typed variables, typed arrays, typed function signatures everywhere.

### Visual Quality Gate
- No placeholder art in committed code — generate real assets or mark the task as failed.
- Sprites in the same scene must share pixel density. Mixing 16px and 32px art = visual bug.
- UI elements must have consistent padding, alignment, and font sizes.
- Z-order must be correct: UI above gameplay, gameplay above backgrounds.

### Audio Quality Gate
- Every button needs a click sound. Every reward needs a chime. Every error needs a thud.
- Music and SFX must have separate volume controls.
- Audio must stop/pause correctly on scene transitions and app backgrounding.

### Specialist Knowledge Loading
When the session focus is set, also read the corresponding specialist file from config/studio/:
- VISUAL / ASSET AUDIT → Read config/studio/visual_audit.md for Art Director + Technical Artist expertise
- GAMEPLAY / UX → Read config/studio/gameplay_ux.md for Game Designer + UX Designer expertise
- CODE QUALITY → Read config/studio/code_quality.md for Lead Programmer + QA Lead expertise
- POLISH / NEW IDEAS → Read config/studio/polish_ideas.md for Creative Director + Economy Designer expertise
These files contain detailed checklists and expert knowledge to improve task quality.
