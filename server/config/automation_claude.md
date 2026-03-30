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
1. Generate 3-5 micro-tasks per session (not 1-3 big ones)
2. Each task title must start with a verb: Add, Fix, Create, Connect, Remove, Rename, Refactor, Update, Extract
3. Each task description must specify EXACTLY which file(s) to modify
4. If an improvement needs multiple steps, create separate tasks for each step — they will be done in sequence by future sessions
5. Prefer tasks that can be verified by building successfully (no runtime/visual verification needed)

## NEVER Use Placeholders — Generate Real Assets
- NEVER use placeholder art, placeholder text, placeholder icons, or TODO comments for assets
- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT using the tools in `{tools_dir}/`:
  - `pixellab_generate_image.py` — pixel art sprites, icons, items
  - `pixellab_generate_background.py` — full game backgrounds (topdown, sidescroller, parallax, menu, battle, isometric)
  - `pixellab_generate_ui.py` — UI elements (buttons, health bars, panels)

- If you cannot generate the asset (no credits, rate limited, tool error), mark the task as "failed" with a clear explanation. Do NOT substitute a colored rectangle or placeholder file.
- If a task requires art you cannot generate, create a follow-up task specifically for asset generation.
- NEVER use animation fallbacks (static sprites, single-frame "animations", or skipping animations). If a task needs an animation, GENERATE IT using PixelLab MCP (animate_character) or SDK tools. If generation fails, mark the task as "failed".

## Code Quality Rules
- Always verify the project builds after your changes
- Do NOT leave debug prints or placeholder comments
- Do NOT add features that aren't described in the task
- Stay focused — one task, one change, move on

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
- Pick ONE pending task, do it, mark it done, generate ideas, stop
- Do not attempt to do multiple tasks in a single session unless they are trivially small
- If a task is taking too long or seems bigger than expected, STOP immediately — mark it "divided", create micro sub-tasks, then move on
- Never spend more than 20 minutes on a single task. If you're stuck, divide it and split it.

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
