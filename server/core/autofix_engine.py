"""Auto-fix engine: queue issues, build prompts, run AI sessions, track results."""

import threading
import time
import os
import subprocess
import re
from datetime import datetime
from typing import Callable, Optional
from database.db_manager import DBManager
from database.models import Issue, App
from core.ai_tools import AITools
from core.internet_monitor import InternetMonitor


# ── Prompt Templates ─────────────────────────────────────────────

FLUTTER_FIX_TEMPLATE = """You are fixing a {category} in {app_name}, a Flutter app.
Project path: {project_path}

{context_section}

## The Issue
Title: {title}
Category: {category}
Priority: {priority}
Description:
{description}

{raw_data_section}

## Instructions
1. Read the relevant source files in {project_path}/lib/
2. Identify the root cause — understand WHY it's broken, not just WHERE
3. Apply the minimal fix that resolves the issue
4. Verify the fix doesn't break related functionality (check callers/consumers of changed code)
5. Summarize what you changed and why

## Code Quality (Lead Programmer Standards)
- After every await, re-check that widgets are still mounted (if (!mounted) return;)
- Use typed variables and return types everywhere
- If the fix touches state management, verify the state flow is correct (data down, events up)
- If the fix touches UI, ensure touch targets >= 48x48dp and proper SafeArea handling

## Constraints
- Do NOT change the app version
- Do NOT modify pubspec.yaml dependencies unless directly related
- Prefer minimal, surgical fixes over large refactors
- Do NOT introduce placeholder assets — if an asset is needed, generate it or note it as a follow-up
"""

GODOT_FIX_TEMPLATE = """You are fixing a {category} in {app_name}, a Godot 4.6.1 game.
Project path: {project_path}

{context_section}

## The Issue
Title: {title}
Category: {category}
Description:
{description}

{raw_data_section}

## Instructions
1. Read the relevant scripts in {project_path}/scripts/
2. Identify the root cause — understand WHY it's broken, not just WHERE
3. Apply the fix using typed GDScript 4.6.1 syntax
4. Verify the fix doesn't break related systems (check signal connections, scene references)
5. Summarize what you changed

## Code Quality (Lead Programmer + Godot Specialist Standards)
- Always use is_instance_valid(node) before accessing nodes that may have been freed
- After every await, re-check that self and referenced nodes still exist
- Disconnect signals in _exit_tree() to prevent ghost callbacks
- Cache node references in _ready() — never get_node() in _process()
- Use typed variables (var speed: float = 100.0), typed arrays (Array[Enemy]), typed returns
- Dictionary access: use .get(key, default) — never dict[key] directly
- Never use := in lambdas (Godot 4.6.1 parser bug)

## Constraints
- Use typed GDScript: var speed: float = 100.0
- Use @export for editor-exposed vars
- Do NOT modify project.godot autoloads unless necessary
- Do NOT introduce placeholder assets — generate real assets or note as follow-up
"""

GENERIC_FIX_TEMPLATE = """You are fixing a {category} in {app_name}.
Project path: {project_path}

{context_section}

## The Issue
Title: {title}
Category: {category}
Priority: {priority}
Description:
{description}

{raw_data_section}

## Instructions
1. Read the relevant source files
2. Identify the root cause — understand WHY it's broken, not just WHERE
3. Apply the minimal fix that resolves the issue
4. Verify the fix doesn't break related functionality
5. Summarize what you changed and why

## Quality Standards
- Prefer minimal, surgical fixes over large refactors
- Use typed variables and proper error handling
- Ensure data-driven values come from config files, not hardcoded
- No placeholder assets — generate real ones or note as follow-up
"""

PRIORITY_NAMES = {1: "Critical", 2: "High", 3: "Medium", 4: "Low", 5: "Wishlist"}


class AutoFixEngine:
    def __init__(self, db: DBManager, internet: InternetMonitor, settings: dict):
        self.db = db
        self.internet = internet
        self.ai_tools = AITools(settings)
        self.settings = settings

        self._queue: list[int] = []  # issue IDs
        self._running = False
        self._cancel_requested = False
        self._current_session_id: Optional[int] = None
        self._thread: Optional[threading.Thread] = None
        self._callbacks: dict[str, list[Callable]] = {
            "session_started": [],
            "session_completed": [],
            "session_failed": [],
            "queue_changed": [],
            "output_line": [],
        }

    def on(self, event: str, callback: Callable):
        if event in self._callbacks:
            self._callbacks[event].append(callback)

    def _emit(self, event: str, *args):
        for cb in self._callbacks.get(event, []):
            try:
                cb(*args)
            except Exception:
                pass

    @property
    def is_running(self) -> bool:
        return self._running

    @property
    def queue(self) -> list[int]:
        return self._queue.copy()

    @property
    def current_session_id(self) -> Optional[int]:
        return self._current_session_id

    def enqueue_issue(self, issue_id: int):
        if issue_id not in self._queue:
            self._queue.append(issue_id)
            self.db.update_issue(issue_id, status="queued")
            self._emit("queue_changed")

    def dequeue_issue(self, issue_id: int):
        if issue_id in self._queue:
            self._queue.remove(issue_id)
            self.db.update_issue(issue_id, status="open")
            self._emit("queue_changed")

    def start_processing(self):
        if self._running:
            return
        self._running = True
        self._cancel_requested = False
        self._thread = threading.Thread(target=self._process_loop, daemon=True)
        self._thread.start()

    def stop_processing(self):
        self._running = False
        self._cancel_requested = True

    def cancel_current(self):
        self._cancel_requested = True

    def load_queued_issues(self):
        """Load issues with status 'queued' from DB into the queue.
        Also cleans up any stale sessions/issues from previous crashes."""
        self._cleanup_stale_sessions()
        issues = self.db.get_issues(status="queued")
        for issue in issues:
            if issue.id not in self._queue:
                self._queue.append(issue.id)
        # Reset any issues stuck in 'fixing' from a prior crashed session
        try:
            fixing = self.db.get_issues(status="fixing")
            for issue in fixing:
                self.db.update_issue(issue.id, status="open")
        except Exception:
            pass

    def _process_loop(self):
        while self._running and self._queue:
            if self._cancel_requested:
                self._cancel_requested = False
                continue

            issue_id = self._queue.pop(0)
            self._emit("queue_changed")
            self._process_single(issue_id)

            # Cooldown between sessions
            interval = int(self.settings.get("autofix_interval", "600"))
            for _ in range(interval):
                if not self._running:
                    break
                time.sleep(1)

        self._running = False

    def _process_single(self, issue_id: int):
        issue = self.db.get_issue(issue_id)
        if not issue:
            return

        app = self.db.get_app(issue.app_id)
        if not app:
            return

        # Wait for internet
        if not self.internet.is_online:
            self._emit("output_line", "[Waiting for internet...]")
            if not self.internet.wait_for_connection(timeout=300):
                self.db.update_issue(issue_id, status="open")
                self._emit("session_failed", issue_id, "No internet")
                return

        # Build prompt
        prompt = self._build_prompt(issue, app)

        # Create session record
        ai_tool = issue.assigned_ai or app.fix_strategy or "claude"
        log_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "logs")
        os.makedirs(log_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = os.path.join(log_dir, f"session_{app.slug}_{timestamp}.log")

        session_id = self.db.create_session(
            app_id=app.id,
            issue_id=issue_id,
            ai_tool=ai_tool,
            prompt_used=prompt,
            status="running",
            log_file_path=log_path,
            started_at=datetime.now().isoformat(),
        )
        self._current_session_id = session_id
        self.db.update_issue(issue_id, status="fixing")
        self._emit("session_started", session_id)

        # Open log file
        start_time = time.time()
        with open(log_path, "w", encoding="utf-8") as log_file:
            def on_output(line: str):
                # Strip ANSI codes
                clean = re.sub(r"\x1b\[[0-9;]*m", "", line)
                log_file.write(clean + "\n")
                log_file.flush()
                self._emit("output_line", clean)

            # Run AI
            timeout = int(self.settings.get("session_timeout", "1200"))
            if ai_tool == "claude":
                exit_code, output = self.ai_tools.run_claude(
                    prompt, app.project_path, app.mcp_config_path, on_output, timeout
                )
            elif ai_tool == "codex":
                exit_code, output = self.ai_tools.run_codex(
                    prompt, app.project_path, on_output, timeout
                )
            elif ai_tool == "gemini":
                exit_code, output = self.ai_tools.run_gemini(
                    prompt, app.project_path, on_output, timeout
                )
            elif ai_tool == "local":
                exit_code, output = self.ai_tools.run_local(
                    prompt, app.project_path, on_output, timeout
                )
            else:
                exit_code, output = -1, f"Unknown AI tool: {ai_tool}"
        duration = int(time.time() - start_time)

        # Get changed files (git)
        files_changed = self._get_changed_files(app.project_path)

        # Update session
        status = "completed" if exit_code == 0 else "failed"
        error_msg = ""
        if exit_code != 0:
            error_msg = self._classify_error(output, exit_code)

        self.db.update_session(
            session_id,
            status=status,
            exit_code=exit_code,
            duration_seconds=duration,
            error_message=error_msg,
            files_changed=str(files_changed),
            completed_at=datetime.now().isoformat(),
        )

        # Update issue
        if exit_code == 0:
            self.db.update_issue(issue_id, status="verified", fix_session_id=session_id, fix_result=f"Auto-fixed in session #{session_id}")
            self._emit("session_completed", session_id, True)
        else:
            self.db.update_issue(issue_id, status="open")
            self._emit("session_failed", session_id, error_msg)

        # Cleanup: mark any lingering "fixing" issues for this app as "open"
        # (handles cases where AI crashed mid-run without proper cleanup)
        self._cleanup_stale_issues(app.id)

        self._current_session_id = None

    def _build_prompt(self, issue: Issue, app: App) -> str:
        # Custom override takes precedence
        if issue.fix_prompt:
            return issue.fix_prompt

        # Read CLAUDE.md if exists
        context_section = ""
        if app.claude_md_path and os.path.isfile(app.claude_md_path):
            try:
                with open(app.claude_md_path, "r", encoding="utf-8") as f:
                    context_section = f"## Project Context (CLAUDE.md)\n{f.read()[:2000]}"
            except Exception:
                pass

        # Raw data section
        raw_data_section = ""
        if issue.raw_data:
            raw_data_section = f"## Raw Data\n```\n{issue.raw_data[:3000]}\n```"

        # Choose template
        if app.app_type == "flutter":
            template = FLUTTER_FIX_TEMPLATE
        elif app.app_type == "godot":
            template = GODOT_FIX_TEMPLATE
        else:
            template = GENERIC_FIX_TEMPLATE

        return template.format(
            app_name=app.name,
            project_path=app.project_path,
            context_section=context_section,
            title=issue.title,
            category=issue.category,
            priority=PRIORITY_NAMES.get(issue.priority, "Medium"),
            description=issue.description,
            raw_data_section=raw_data_section,
        )

    def _get_changed_files(self, project_path: str) -> list[str]:
        try:
            result = subprocess.run(
                ["git", "diff", "--name-only"],
                cwd=project_path,
                capture_output=True, text=True, timeout=10,
            )
            if result.returncode == 0:
                return [f.strip() for f in result.stdout.strip().split("\n") if f.strip()]
        except Exception:
            pass
        return []

    def _cleanup_stale_issues(self, app_id: int):
        """Mark any issues stuck in 'fixing' status back to 'open'."""
        try:
            issues = self.db.get_issues(app_id=app_id, status="fixing")
            for issue in issues:
                self.db.update_issue(issue.id, status="open")
        except Exception:
            pass

    def _cleanup_stale_sessions(self):
        """Mark any sessions stuck in 'running' status as 'failed'."""
        try:
            sessions = self.db.get_sessions(status="running")
            for session in sessions:
                self.db.update_session(
                    session.id,
                    status="failed",
                    error_message="stale_session_cleanup",
                    completed_at=datetime.now().isoformat(),
                )
        except Exception:
            pass

    def _classify_error(self, output: str, exit_code: int) -> str:
        lower = output.lower()
        if any(w in lower for w in ["rate limit", "too many requests", "429", "overloaded"]):
            return "rate_limited"
        if any(w in lower for w in ["401", "403", "unauthorized", "forbidden"]):
            return "auth_error"
        if any(w in lower for w in ["500", "502", "503", "server error"]):
            return "server_down"
        if "timeout" in lower:
            return "timeout"
        return f"exit_code_{exit_code}"
