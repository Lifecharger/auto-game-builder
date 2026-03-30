#!/bin/bash
# Auto-generated automation for testproject
# AI Agent: claude | Interval: 5min

set +e
trap '' HUP
trap 'echo "STOPPED"; exit 0' INT TERM

PROJECT_DIR="/c/Projects/testproject"
LOG_DIR="/c/Projects/testproject/auto_build_logs"
CLAUDE_BIN="C:/Users/caca_/.local/bin/claude.exe"
INTERVAL=300

mkdir -p "$LOG_DIR"

SESSION=0
echo "=== AUTOMATION STARTED: testproject (claude) ==="
echo "=== Interval: 5min | Timeout: 60min ==="

while true; do
    SESSION=$((SESSION + 1))
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="$LOG_DIR/session_${SESSION}_${TIMESTAMP}.log"

    echo ""
    echo ">>> SESSION $SESSION started at $(date) <<<"

    # Wait for internet
    while ! curl -s --connect-timeout 5 https://api.anthropic.com > /dev/null 2>&1; do
        echo ">>> No internet. Retrying in 30s... <<<"
        sleep 30
    done

    cd "$PROJECT_DIR"
    PROMPT_FILE=$(mktemp /tmp/testproject_prompt_XXXXXX.txt 2>/dev/null) || PROMPT_FILE="$LOG_DIR/.prompt_tmp.txt"
    cat > "$PROMPT_FILE" << 'ENDPROMPT'
You are autonomously working on testproject (flutter project).
Project path: C:\Projects/testproject

IMPORTANT: Read gdd.md in the project root. This is the Game Design Document / App Design Document.
Follow its vision, goals, and specifications when working on tasks or generating ideas.

STEP 1 - READ TASKS:
Read tasklist.json in the project root. It has a "tasks" array. Each task has: id, title, description, type, priority, status, response.
Focus on tasks with status "pending". Work on them in this order:
1. Priority "urgent" first
2. Then OLDEST tasks first (lowest ID = oldest = highest priority)
3. Do NOT skip old tasks to work on newer ones

STEP 2 - MARK IN PROGRESS:
Before starting work on a task, update tasklist.json immediately:
- Set "status" to "in_progress" for that task
This lets the mobile app show real-time progress.

STEP 3 - WORK:
For each task, fix the issue / implement the feature / explore the idea.
Write clean, working code. Test and verify your changes.

STEP 4 - UPDATE TASKS:
After completing each task, update tasklist.json:
- Set "status" to "completed"
- Write what you did in the "response" field
- Set "completed_by" to "claude"
Do this IMMEDIATELY after each task, not at the end.

STEP 4B - FAILURE HANDLING:
If you start a task but cannot complete it in this run, update tasklist.json immediately:
- Set "status" to "failed"
- Set "completed_by" to "claude"
- Write the blocker/error clearly in "response"

STEP 5 - GENERATE NEW TASKS (ONLY IF NEEDED):
Count the remaining pending tasks in tasklist.json.
- If there are 5 or MORE pending tasks: DO NOT generate new tasks. Focus on completing existing ones.
- If there are FEWER than 5 pending tasks: Generate 3-5 new tasks based on this session's focus area.
Add them to tasklist.json with status "pending" and a clear title + description.

IMPORTANT — TASK PRIORITY RULES (always apply):
- Crashes and build failures are ALWAYS top priority regardless of focus area.
- Never generate more than 1 code-quality task (null checks, signal cleanup, etc.) per session.
- ALWAYS work on existing pending tasks before generating new ones.
- Work on oldest tasks first (lowest ID).

THIS SESSION'S FOCUS AREA: GAMEPLAY / UX
Generate tasks about GAMEPLAY and UX issues:
- Do game mechanics work correctly? State machines in sync?
- Are touch targets at least 48px for mobile?
- Do buttons give visual/audio feedback when pressed?
- Is the game flow logical? Can the player get stuck anywhere?
- Are error messages user-friendly? Are loading states shown?
- Test edge cases: what happens with 0 resources, max level, empty states?


STEP 6 - BUILD (if applicable):
If this is a buildable project, attempt a build to verify nothing is broken.

REPEAT: The system will call you again after a break. Leave the project in a good state.



CRITICAL — MANDATORY TASK STATUS CONTRACT (APPLIES TO EVERY TASK YOU PICK):
You MUST follow these steps IN ORDER for EVERY task. Skipping any step is a failure.
1. FIRST ACTION for each task: Open tasklist.json, find the task, set "status" to "in_progress", SAVE THE FILE. Do this BEFORE reading any source code or making any changes.
2. Work on exactly ONE task at a time. Do not start another task until the current one is marked completed or failed.
3. When task is DONE: set "status" to "completed", set "completed_by" to "claude", write a concrete summary in "response". SAVE immediately.
4. When task CANNOT be finished: set "status" to "failed", set "completed_by" to "claude", explain the blocker in "response". SAVE immediately.
5. NEVER leave a task as "pending" or "in_progress" when moving to another task or ending the run.
6. The tasklist.json file write is MORE IMPORTANT than the code change. If you must choose, update the task status first.
7. CRITICAL — JSON CORRUPTION PREVENTION: When writing tasklist.json:
   - Always read the ENTIRE file first, parse it, modify in memory, then write back
   - After writing, re-read the file and verify it parses as valid JSON
   - If the file is corrupted when you read it (parse error), check for tasklist.json.bak and restore from it
   - NEVER write partial JSON. NEVER use string replacement on JSON — always parse, modify, serialize
   - Ensure no trailing commas in arrays or objects
8. FORBIDDEN ACTIONS — NEVER do any of these:
   - NEVER create backup/restore scripts or hooks for tasklist.json (the system already handles this)
   - NEVER modify .claude/settings.json or install hooks
   - NEVER create shell scripts (.sh, .bat, .py) that modify tasklist.json outside of your direct edits
   - NEVER create cron jobs, scheduled tasks, or file watchers
   - NEVER generate tasks about backing up or restoring tasklist.json


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
2. Immediately mark its "status" to "divided" with response listing the sub-tasks you created
3. Create those sub-tasks as separate new entries in tasklist.json (status "pending", type same as parent)
4. Each sub-task must be micro-sized (completable in 30 min)
5. Then pick one of the new sub-tasks and work on it

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


ENDPROMPT

    timeout 3600 "C:/Users/caca_/.local/bin/claude.exe" \
        -p \
        --dangerously-skip-permissions \
        --verbose \
         \
        < "$PROMPT_FILE" \
        2>&1 | tee "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    rm -f "$PROMPT_FILE"

    echo ">>> SESSION $SESSION finished (exit: $EXIT_CODE) at $(date) <<<"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session $SESSION completed (exit: $EXIT_CODE)" >> "$LOG_DIR/completions.log"

    # Fallback: reset any tasks stuck in "in_progress" after AI exit (atomic write)
    python3 -c "
import json, os, sys, tempfile, shutil
tl = os.path.join('$PROJECT_DIR', 'tasklist.json')
if not os.path.isfile(tl):
    sys.exit(0)
try:
    with open(tl) as f:
        data = json.load(f)
except (json.JSONDecodeError, IOError):
    sys.exit(0)
tasks = data.get('tasks', data) if isinstance(data, dict) else data
changed = False
for t in (tasks if isinstance(tasks, list) else tasks.values()):
    if t.get('status') == 'in_progress':
        if $EXIT_CODE != 0:
            t['status'] = 'failed'
            t['response'] = t.get('response', '') or 'AI agent crashed or exited with error (exit code $EXIT_CODE). Check logs.'
        else:
            t['status'] = 'completed'
            if not t.get('response'):
                t['response'] = 'Completed by claude (no details provided).'
        t['completed_by'] = 'claude'
        changed = True
if changed:
    shutil.copy2(tl, tl + '.bak')
    payload = json.dumps(data, indent=2, ensure_ascii=False)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(tl), suffix='.tmp')
    with os.fdopen(fd, 'w') as f:
        f.write(payload)
    os.replace(tmp, tl)
" 2>/dev/null || true

    # Handle errors
    if [ "$EXIT_CODE" -ne 0 ]; then
        if grep -qi "rate.limit\|429\|overloaded\|usage.limit" "$LOG_FILE" 2>/dev/null; then
            echo ">>> RATE LIMITED. Waiting 30 min... <<<"
            sleep 1800
            continue
        fi
        echo ">>> FAILED. Retrying in 60s... <<<"
        sleep 60
        continue
    fi

    # Cleanup old logs (keep last 30)
    ls -t "$LOG_DIR"/session_*.log 2>/dev/null | awk 'NR>30' | xargs rm -f 2>/dev/null

    echo ">>> Sleeping ${INTERVAL}s until next session... <<<"
    sleep $INTERVAL
done
