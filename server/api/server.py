"""AppManager REST API — exposes full DB to mobile app via Cloudflare Tunnel."""

import os
import sys
import json
import secrets
import shlex
import subprocess
import signal
import threading
import tempfile
import shutil
import random
from pathlib import Path
import time
import psutil
from datetime import datetime
from typing import Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from pydantic import BaseModel

# Add parent to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database.db_manager import DBManager
from config.settings_loader import get_settings
from config.path_utils import to_unix_path

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app_manager.db")
DEATHPIN_DIR = ""  # Legacy — disabled
DIRECTIVES_FILE = os.path.join(DEATHPIN_DIR, "user_directives.json")


def _get_tool_paths() -> dict:
    """Get resolved tool paths from settings."""
    s = get_settings()
    return {
        "claude_bin": s.get("claude_path", "") or "claude",
        "gemini_bin": s.get("gemini_path", "") or "gemini",
        "codex_bin": s.get("codex_path", "") or "codex",
        "aider_bin": s.get("aider_path", "") or "aider",
        "bash_exe": s.get("bash_path", "") or "bash",
        "flutter_path": s.get("flutter_path", "") or "flutter",
        "godot_path": s.get("godot_path", "") or "godot",
    }


from core.autofix_engine import AutoFixEngine
from core.deploy_engine import DeployEngine
from core.internet_monitor import InternetMonitor


def _cleanup_stale_db_state(db_inst: DBManager):
    """Reset DB records stuck from a previous crash (zombie state cleanup)."""
    # Reset apps stuck in "building" or "fixing" back to "idle"
    try:
        for a in db_inst.get_all_apps():
            if a.status in ("building", "fixing"):
                print(f"[Startup] Resetting stuck app '{a.name}' from '{a.status}' to 'idle'")
                db_inst.update_app(a.id, status="idle")
    except Exception as e:
        print(f"[Startup] App cleanup warning: {e}")

    # Reset builds stuck in "running" to "failed"
    try:
        for a in db_inst.get_all_apps():
            builds = db_inst.get_builds(app_id=a.id, limit=5)
            for b in builds:
                if b.status == "running":
                    print(f"[Startup] Marking stuck build #{b.id} as failed")
                    db_inst.update_build(b.id, status="failed",
                                         log_output=(b.log_output or "") + "\n[AppManager restarted - build interrupted]",
                                         completed_at=datetime.now().isoformat())
    except Exception as e:
        print(f"[Startup] Build cleanup warning: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.db = DBManager(DB_PATH)
    _cleanup_stale_db_state(app.state.db)
    settings = get_settings()
    app.state.internet = InternetMonitor(
        check_url=settings.get("internet_check_url", "https://api.anthropic.com"),
        interval=int(settings.get("internet_check_interval", "30")),
    )
    app.state.internet.start()
    app.state.autofix = AutoFixEngine(app.state.db, app.state.internet, settings)
    app.state.autofix.load_queued_issues()
    app.state.deploy = DeployEngine(app.state.db, settings)
    # Auto-setup MCP presets if not yet populated
    if not _load_mcp_servers():
        try:
            auto_setup_mcp_presets()
        except Exception:
            pass
    yield
    app.state.deploy.shutdown()
    app.state.internet.stop()
    app.state.autofix.stop_processing()


app = FastAPI(title="AppManager API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"], expose_headers=["*"])


class ApiKeyMiddleware(BaseHTTPMiddleware):
    """Validate X-API-Key header on all /api/* routes (except health & pair)."""

    # Routes that don't require auth (public endpoints)
    OPEN_PATHS = {"/", "/docs", "/openapi.json", "/api/health", "/api/pair"}

    async def dispatch(self, request: Request, call_next):
        path = request.url.path.rstrip("/")
        # Skip auth for non-API routes, health, pair, and OPTIONS (CORS preflight)
        if request.method == "OPTIONS" or path in self.OPEN_PATHS or not path.startswith("/api"):
            return await call_next(request)

        settings = get_settings()
        expected_key = settings.get("api_key", "")
        if not expected_key:
            # No key configured yet — allow all (first-run grace)
            return await call_next(request)

        provided_key = request.headers.get("X-API-Key", "")
        if provided_key != expected_key:
            return JSONResponse(
                status_code=401,
                content={"error": "Unauthorized", "message": "Invalid or missing API key"},
            )
        return await call_next(request)


app.add_middleware(ApiKeyMiddleware)


def db() -> DBManager:
    return app.state.db

def autofix() -> AutoFixEngine:
    return app.state.autofix


# ── Pydantic Models ──────────────────────────────────────────

class IssueCreate(BaseModel):
    app_id: int
    title: str
    description: str = ""
    category: str = "bug"
    priority: int = 3
    source: str = "mobile"
    assigned_ai: str = ""

class IssueUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[int] = None
    status: Optional[str] = None
    assigned_ai: Optional[str] = None
    fix_prompt: Optional[str] = None

class AppUpdate(BaseModel):
    notes: Optional[str] = None
    status: Optional[str] = None
    publish_status: Optional[str] = None
    fix_strategy: Optional[str] = None
    package_name: Optional[str] = None
    project_path: Optional[str] = None
    github_url: Optional[str] = None
    play_store_url: Optional[str] = None
    website_url: Optional[str] = None
    console_url: Optional[str] = None

class DirectiveCreate(BaseModel):
    message: str
    priority: str = "normal"  # normal|urgent
    target_app: str = ""  # empty = general, or app slug

class TaskCreate(BaseModel):
    app_id: Optional[int] = None
    title: str
    description: str = ""
    task_type: str = "issue"  # issue|idea|feature|fix
    priority: str = "normal"  # normal|urgent
    attachments: Optional[list] = None  # base64-encoded images from mobile

class GddUpdate(BaseModel):
    content: str

class AppCreate(BaseModel):
    name: str
    app_type: str = "flutter"  # flutter|godot|python|web
    fix_strategy: str = "claude"

class AutomationCreate(BaseModel):
    app_id: int
    ai_agent: str = "claude"  # claude|gemini|codex
    interval_minutes: int = 10
    prompt: str = ""  # master prompt for each session
    max_session_minutes: int = 18
    mcp_servers: Optional[list] = None  # MCP server names to use

class AutomationUpdate(BaseModel):
    ai_agent: Optional[str] = None
    interval_minutes: Optional[int] = None
    prompt: Optional[str] = None
    max_session_minutes: Optional[int] = None
    mcp_servers: Optional[list] = None

class BuildTrigger(BaseModel):
    app_id: int
    build_type: str = "appbundle"

class DeployRequest(BaseModel):
    track: str = "internal"  # internal|alpha|beta|production
    build_target: str = "aab"  # apk|aab|exe|web|ios (flutter) / apk|aab|windows|web|linux (godot)
    upload: bool = False  # upload to Google Play after build


def deploy_engine() -> DeployEngine:
    return app.state.deploy


# ── Root & Health ─────────────────────────────────────────────

@app.get("/")
def root():
    return {"name": "AppManager API", "version": "1.0.0", "status": "running", "docs": "/docs"}

@app.get("/api/health")
def health():
    return {"status": "ok", "time": datetime.now().isoformat()}


@app.get("/api/sync")
def sync_delta(since: str = ""):
    """Return all records changed since the given ISO timestamp.
    If since is empty, returns everything (full sync)."""
    if since:
        apps = [_app_dict(a) for a in db.get_apps_since(since)]
        issues = [_issue_dict(i) for i in db.get_issues_since(since)]
        builds = [_build_dict(b) for b in db.get_builds_since(since)]
        sessions = [_session_dict(s) for s in db.get_sessions_since(since)]
        deleted = db.get_deleted_since(since)
    else:
        apps = [_app_dict(a) for a in db.get_all_apps(include_archived=True)]
        issues = [_issue_dict(i) for i in db.get_all_issues()]
        builds = [_build_dict(b) for b in db.get_all_builds()]
        sessions = [_session_dict(s) for s in db.get_all_sessions()]
        deleted = []
    return {
        "apps": apps,
        "issues": issues,
        "builds": builds,
        "sessions": sessions,
        "deleted": deleted,
        "server_time": datetime.now().isoformat(),
    }


@app.get("/api/pair")
def pair():
    """Return pairing data (API key + worker URL) for QR code display.
    Only accessible from localhost — blocks remote access."""
    import base64
    settings = get_settings()
    api_key = settings.get("api_key", "")
    worker_url = settings.get("worker_url", "")
    if not api_key:
        raise HTTPException(500, "API key not generated yet — restart server")
    payload = json.dumps({"api_key": api_key, "worker_url": worker_url})
    return {"pair_data": base64.b64encode(payload.encode()).decode(), "worker_url": worker_url}


# ── Apps ──────────────────────────────────────────────────────

@app.get("/api/apps")
def list_apps(include_archived: bool = False):
    apps = db().get_all_apps(include_archived=include_archived)
    return [_app_dict(a) for a in apps]

@app.get("/api/apps/{app_id}")
def get_app(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    result = _app_dict(a)
    result["open_issues"] = db().count_issues(app_id, status="open")
    result["total_issues"] = db().count_issues(app_id)
    return result

@app.patch("/api/apps/{app_id}")
def update_app(app_id: int, body: AppUpdate):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    if updates:
        db().update_app(app_id, **updates)
    return {"ok": True}


# ── Per-App MCP Config ──────────────────────────────────────
APP_MCP_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "app_mcp.json")


def _load_app_mcp() -> dict:
    if os.path.isfile(APP_MCP_FILE):
        try:
            with open(APP_MCP_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {}


def _save_app_mcp(data: dict):
    os.makedirs(os.path.dirname(APP_MCP_FILE), exist_ok=True)
    with open(APP_MCP_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def _get_app_mcp_servers(app_id: int) -> list:
    """Get MCP server names configured for an app."""
    return _load_app_mcp().get(str(app_id), [])


@app.get("/api/apps/{app_id}/mcp")
def get_app_mcp(app_id: int):
    """Get MCP servers configured for this app."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    return {"app_id": app_id, "mcp_servers": _get_app_mcp_servers(app_id)}


class AppMcpUpdate(BaseModel):
    mcp_servers: list


@app.put("/api/apps/{app_id}/mcp")
def set_app_mcp(app_id: int, body: AppMcpUpdate):
    """Set MCP servers for this app. All scripts/tasks will use these."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    data = _load_app_mcp()
    data[str(app_id)] = body.mcp_servers
    _save_app_mcp(data)

    # Generate mcp_config.json for this app
    if body.mcp_servers:
        mcp_data = _build_mcp_config_file(body.mcp_servers)
        if mcp_data["mcpServers"]:
            mcp_file = os.path.join(a.project_path, "mcp_config.json")
            os.makedirs(os.path.dirname(mcp_file), exist_ok=True)
            with open(mcp_file, "w", encoding="utf-8") as f:
                json.dump(mcp_data, f, indent=2)
            db().update_app(app_id, mcp_config_path=mcp_file)
    else:
        # Clear mcp_config if no servers selected
        mcp_file = os.path.join(a.project_path, "mcp_config.json")
        if os.path.isfile(mcp_file):
            os.remove(mcp_file)
        db().update_app(app_id, mcp_config_path="")

    # Regenerate automation script if exists
    configs = _load_automation_configs()
    key = str(app_id)
    if key in configs:
        configs[key]["mcp_servers"] = body.mcp_servers
        _save_automation_configs(configs)
        # Refetch app to get updated mcp_config_path
        a = db().get_app(app_id)
        script = _generate_auto_build_script(a, configs[key])
        script_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_auto.sh")
        with open(script_path, "w", newline="\n", encoding="utf-8") as f:
            f.write(script)

    return {"ok": True}

@app.post("/api/apps/scan")
def scan_projects():
    """Scan projects_root for existing projects and register them."""
    from core.app_detector import AppDetector
    detector = AppDetector()
    s = get_settings()
    projects_root = s.get("projects_root", os.path.join(str(Path.home()), "Projects"))

    if not os.path.isdir(projects_root):
        return {"ok": False, "error": f"Projects root not found: {projects_root}", "found": 0, "imported": 0}

    found = 0
    imported = 0
    skipped = []
    results = []

    for entry in sorted(os.listdir(projects_root)):
        project_path = os.path.join(projects_root, entry)
        if not os.path.isdir(project_path):
            continue
        # Skip hidden/system folders
        if entry.startswith(".") or entry.startswith("_"):
            continue

        found += 1
        slug = detector.generate_slug(entry)

        # Skip if already registered
        existing = db().get_app_by_slug(slug)
        if existing:
            skipped.append(entry)
            continue

        # Detect project type (also check subfolders for monorepos)
        info = detector.detect(project_path)
        if info["app_type"] == "custom":
            # Check subfolders for known project types
            type_markers = {
                "pubspec.yaml": "flutter",
                "project.godot": "godot",
                "package.json": "react_native",
                "pyproject.toml": "python",
                "requirements.txt": "python",
            }
            extra_markers = ["Cargo.toml", "main.py", "setup_wizard.py"]

            # First check root for python markers
            for marker, mtype in type_markers.items():
                if os.path.isfile(os.path.join(project_path, marker)):
                    if mtype == "python" or info["app_type"] == "custom":
                        info["app_type"] = mtype
                    break

            # If still custom, check one level deep
            if info["app_type"] == "custom":
                for sub in os.listdir(project_path):
                    sub_path = os.path.join(project_path, sub)
                    if not os.path.isdir(sub_path) or sub.startswith("."):
                        continue
                    for marker, mtype in type_markers.items():
                        if os.path.isfile(os.path.join(sub_path, marker)):
                            info["app_type"] = mtype
                            break
                    if info["app_type"] != "custom":
                        break

            # If still custom, check if it has any code at all
            if info["app_type"] == "custom":
                has_code = any(
                    os.path.isfile(os.path.join(project_path, f))
                    for f in extra_markers
                )
                if not has_code:
                    has_code = any(
                        os.path.isfile(os.path.join(project_path, sub, f))
                        for sub in os.listdir(project_path)
                        if os.path.isdir(os.path.join(project_path, sub)) and not sub.startswith(".")
                        for f in extra_markers
                    )
                if not has_code:
                    skipped.append(entry)
                    continue

        # If no package name found, check subfolders
        if not info.get("package_name") and info["app_type"] in ("flutter", "react_native"):
            for sub in os.listdir(project_path):
                sub_path = os.path.join(project_path, sub)
                if os.path.isdir(sub_path) and not sub.startswith("."):
                    sub_info = detector.detect(sub_path)
                    if sub_info.get("package_name"):
                        info["package_name"] = sub_info["package_name"]
                        if not info.get("version") and sub_info.get("version"):
                            info["version"] = sub_info["version"]
                        break

        # Register in DB
        app_id = db().create_app(
            name=entry,
            slug=slug,
            project_path=project_path,
            app_type=info["app_type"],
            current_version=info.get("version", ""),
            package_name=info.get("package_name", ""),
            status="idle",
            publish_status="development",
        )
        imported += 1
        results.append({
            "id": app_id,
            "name": entry,
            "type": info["app_type"],
            "version": info.get("version", ""),
            "package": info.get("package_name", ""),
        })

    return {
        "ok": True,
        "found": found,
        "imported": imported,
        "skipped": len(skipped),
        "apps": results,
    }


@app.post("/api/apps")
def create_new_app(body: AppCreate):
    """Create a new app: makes folder, tasklist.json, and DB entry."""
    import re
    slug = re.sub(r'[^a-z0-9]+', '-', body.name.lower()).strip('-')
    # Project path: {projects_root}\{Name with spaces}
    folder_name = body.name.strip()
    projects_root = get_settings().get("projects_root", os.path.join(str(Path.home()), "Projects"))
    project_path = f"{projects_root}/{folder_name}"
    project_path_win = project_path.replace("/", "\\")

    # Check if already exists in DB
    existing = db().get_app_by_slug(slug)
    if existing:
        raise HTTPException(400, f"App '{body.name}' already exists (id={existing.id})")

    # Create project folder
    os.makedirs(project_path_win, exist_ok=True)

    # Create tasklist.json with a welcome task
    tasklist_path = os.path.join(project_path_win, "tasklist.json")
    if not os.path.isfile(tasklist_path):
        with open(tasklist_path, "w", encoding="utf-8") as f:
            json.dump({"tasks": [
                {
                    "id": 1,
                    "title": f"Initialize {body.name} project structure",
                    "description": f"Set up the {body.app_type} project structure. Read gdd.md if it exists for design guidance. Create the core directory structure: screens/scenes, scripts/lib, assets (sprites, audio, data), and a config/ folder for data-driven values. If gdd.md exists, create initial data files (e.g., config.json) for any economy values mentioned in the GDD.",
                    "type": "feature",
                    "priority": "urgent",
                    "status": "pending",
                    "source": "auto",
                    "response": "",
                    "created_at": datetime.now().isoformat(),
                },
                {
                    "id": 2,
                    "title": f"Create GDD for {body.name} if missing",
                    "description": f"If gdd.md does not exist, create one following the 8-section standard: 1. Overview, 2. Player Fantasy/User Value, 3. Core Loop, 4. Detailed Mechanics, 5. Formulas & Data, 6. Edge Cases, 7. Dependencies, 8. Monetization & Retention. Base it on the project name and app type ({body.app_type}). If gdd.md already exists, verify it has all 8 sections and add any missing ones with [SUGGESTED] defaults.",
                    "type": "feature",
                    "priority": "urgent",
                    "status": "pending",
                    "source": "auto",
                    "response": "",
                    "created_at": datetime.now().isoformat(),
                },
            ]}, f, indent=2)

    # Create CLAUDE.md with base conventions
    claude_md_path = os.path.join(project_path_win, "CLAUDE.md")
    if not os.path.isfile(claude_md_path):
        is_godot = body.app_type == "godot"
        is_flutter = body.app_type == "flutter"
        is_phaser = body.app_type == "phaser"
        lines = [f"# {body.name}\n"]
        lines.append("## Conventions\n")
        lines.append("### Global Rules\n")
        lines.append("- Prices must ALWAYS be dynamically loaded. NEVER hardcode prices.\n")
        lines.append("- All apps are for mobile phones. Design, test, and optimize for mobile. Touch-friendly UI, responsive layouts, portrait mode unless specified otherwise.\n")
        lines.append("- Always account for Android system navigation bar. Use SafeArea/padding.bottom to prevent UI from being hidden behind the system nav bar.\n")
        _keys = get_settings().get("keys_dir", "")
        if _keys:
            lines.append(f"- All signing keys are in `{_keys}/` with master reference at `{_keys}/ALL_KEYS_MASTER.txt`.\n")
        lines.append("\n### NEVER Use Placeholders\n")
        lines.append("- NEVER use placeholder art, placeholder images, placeholder icons, colored rectangles, or TODO comments for visual assets\n")
        lines.append("- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT:\n")
        lines.append("  - Use PixelLab MCP tools if available (create_character, topdown_tilesets, tiles_pro, create_map_object, etc.)\n")
        _td = get_settings().get("tools_dir", "")
        if _td:
            lines.append(f"  - Use Python scripts in `{_td}/pixellab/`: pixellab_generate_image.py, pixellab_generate_background.py, pixellab_generate_ui.py\n")
            lines.append(f"  - Grok image/video tools live in `{_td}/grok/`; pad_image + video_to_frames in `{_td}/media/`\n")
        lines.append("- If you cannot generate the asset (no credits, rate limited, tool error), mark the task as \"failed\" — do NOT substitute a placeholder\n")
        lines.append("- This rule applies to ALL assets: icons, sprites, backgrounds, UI elements, buttons, textures, tiles\n")
        lines.append("- NEVER use animation fallbacks (static sprites, single-frame \"animations\", or skipping animations). If a task needs an animation, GENERATE IT using PixelLab MCP (animate_character) or SDK tools. If generation fails, mark the task as \"failed\".\n")
        lines.append("\n### Game Studio Design Standards\n")
        lines.append("- **Player Experience First**: Think like a player, not a developer. Every change should make the experience better.\n")
        lines.append("- **Feedback on Every Action**: Buttons need click sounds + scale tweens. Rewards need chimes + particles. Errors need visual indicators.\n")
        lines.append("- **Data-Driven Values**: Economy values (prices, rewards, XP, timers) MUST come from config/JSON files, never hardcoded in scripts.\n")
        lines.append("- **Empty States**: Never show a blank screen. Empty inventories say 'No items yet!', empty lists show helpful guidance.\n")
        lines.append("- **Error Recovery**: User-friendly error messages, automatic retry for network failures, graceful degradation.\n")
        lines.append("- **Single Responsibility**: One script = one system. Scripts over 500 lines should be split.\n")
        lines.append("- **Architecture**: Data flows DOWN (parent to child), events flow UP (signals/callbacks). No circular dependencies.\n")
        lines.append("- **GDD Compliance**: Always check gdd.md before implementing features. Follow the spec. Note assumptions in task response.\n")
        if is_flutter:
            lines.append("\n### Flutter\n")
            lines.append(f"- Flutter path: `{_get_tool_paths()['flutter_path']}`\n")
            lines.append("- Always run `flutter analyze` after changes.\n")
            lines.append("- Use test ads during development, production ads only in release.\n")
            lines.append("\n### Testing\n")
            lines.append("- When a test task is assigned, build debug APK, install on emulator via mobile MCP, and test all screens and core gameplay.\n")
            lines.append("- For each problem found (crash, layout issue, missing element, broken navigation, off-screen content), create a separate new task in tasklist.json with a clear description.\n")
            lines.append("- If everything works fine, report \"All tests passed\" with no new tasks created.\n")
            lines.append("- IGNORE on emulator: dynamic price loading, Google Play Billing, Google sign-in, cloud save, IAP functionality. These only work on real devices.\n")
        if is_godot:
            lines.append("\n### Godot\n")
            lines.append(f"- Godot path: `{_get_tool_paths()['godot_path']}`\n")
            lines.append("- Never use `:=` inferred typing in GDScript lambdas (Godot 4.6.1 parser bug).\n")
            lines.append("- CRITICAL: When using MOUSE_FILTER_STOP on overlay/popup Controls, NEVER rely on _unhandled_input() for tap detection. Instead connect gui_input signal on the Control itself.\n")
            lines.append("- All games must have a bottom navigation bar for screen navigation (e.g., Home, Play, Shop, Settings). Never rely on only back buttons or menu buttons in headers.\n")
            lines.append("- CRITICAL: GDScript JSON.parse() converts all dictionary int keys to strings. When saving/loading dictionaries with int keys, always use str() keys for storage and check both int and str(int) when reading. Example: `dict.get(key, dict.get(str(key), default))`\n")
            lines.append("- **PixelLab MCP available** — use appropriate tools: `topdown_tilesets`, `sidescroller_tilesets`, `isometric_tiles`, `tiles_pro` for terrain; `create_character` for sprites; `animate_character` for animations. Choose based on game perspective.\n")
            lines.append("- **ElevenLabs MCP available** — use for sound effects and music.\n")
            lines.append("- **Meshy AI MCP available** — use for 3D model generation: `create_text_to_3d_task`, `create_image_to_3d_task`, `create_text_to_texture_task`, `create_remesh_task`, `create_rigging_task`, `create_animation_task`. Stream/retrieve results with corresponding stream/retrieve tools.\n")
            _tools_dir = get_settings().get("tools_dir", "")
            if _tools_dir:
                _pl = f"{_tools_dir}/pixellab"
                lines.append("\n### PixelLab Python SDK & Tools\n")
                lines.append(f"- Ready-to-use scripts at `{_pl}/` — use these for direct SDK/API access beyond MCP:\n")
                lines.append(f"  - `pixellab_generate_image.py` — text-to-pixel-art (Pixflux). Usage: `python \"{_pl}/pixellab_generate_image.py\" -d \"description\" -W 64 -H 64 --no-background -o sprite.png`\n")
                lines.append(f"  - `pixellab_generate_ui.py` — generate UI elements (health bars, buttons, menus). Usage: `python \"{_pl}/pixellab_generate_ui.py\" -d \"description\" -W 64 -H 32 -o button.png`\n")
                lines.append(f"  - `pixellab_image_to_pixelart.py` — convert any image to pixel art. Usage: `python \"{_pl}/pixellab_image_to_pixelart.py\" -i photo.png -o pixel.png -W 64 -H 64`\n")
                lines.append(f"  - `pixellab_edit_image.py` — inpaint/edit existing sprites with mask. Usage: `python \"{_pl}/pixellab_edit_image.py\" -i sprite.png -m mask.png -d \"edit description\" -o edited.png`\n")
                lines.append(f"  - `pixellab_generate_background.py` — generate full game backgrounds (up to 400x400). Presets: `topdown`, `sidescroller`, `parallax` (3 layers), `menu`, `battle`, `isometric`. Usage: `python \"{_pl}/pixellab_generate_background.py\" -d \"scene description\" --preset topdown -o bg.png`\n")
            lines.append("  - `pixellab_balance.py` — check PixelLab credit balance\n")
            lines.append("- Shared client: `from pixellab_client import get_client, api_post` (auto-reads API key)\n")
            lines.append("- SDK supports v1 (pixflux, bitforge, rotate, inpaint, animate) and v2 API (UI elements, image-to-pixelart, pro inpainting, map generation)\n")
            lines.append("\n### Testing\n")
            lines.append("- When a test task is assigned, build debug APK, install on emulator via mobile MCP, and test all screens and core gameplay.\n")
            lines.append("- For each problem found (crash, layout issue, missing element, broken navigation, off-screen content), create a separate new task in tasklist.json with a clear description.\n")
            lines.append("- If everything works fine, report \"All tests passed\" with no new tasks created.\n")
            lines.append("- IGNORE on emulator: dynamic price loading, Google Play Billing, Google sign-in, cloud save, IAP functionality. These only work on real devices.\n")
        if is_phaser:
            lines.append("\n### Phaser 3 + TypeScript + Vite + Capacitor\n")
            lines.append("- Engine: **Phaser 3** (2D game framework) with **TypeScript** (strict mode) and **Vite** (build tool).\n")
            lines.append("- Mobile wrapper: **Capacitor** produces a signed Android AAB from the web build. Output path: `android/app/build/outputs/bundle/release/app-release.aab`.\n")
            lines.append("- Signing: keystore + passwords are wired into `capacitor.config.ts` at scaffold time. That file is gitignored — contains secrets.\n")
            lines.append("- **NEVER use setTimeout / setInterval** for game logic. Use `this.time.delayedCall()` and `this.time.addEvent()` — they are scene-scoped and auto-torn-down on scene shutdown.\n")
            lines.append("- **NEVER use raw tweens outside scenes.** Use `this.tweens.add()` — auto-killed on scene shutdown.\n")
            lines.append("- **Object pooling is mandatory** for projectiles, particles, enemies spawned at runtime. Use `Phaser.GameObjects.Group` or a simple typed array pool. Never allocate mid-gameplay.\n")
            lines.append("- **Scene lifecycle:** every Scene MUST register cleanup via `this.events.once('shutdown', cleanup, this)`. Release pools, websockets, custom timers, audio refs. Phaser handles its own display objects.\n")
            lines.append("- **Assets via TextureManager:** `this.load.image(key, path)` in `preload()`, reference by key. Never keep raw Image refs in long-lived state.\n")
            lines.append("- **TypeScript is strict**: no `any`, no unused locals/params (tsconfig enforces this). Fix the warning — don't suppress it.\n")
            lines.append("- **Portrait mobile first**: game width 400, height 700 in `main.ts`. Use `Phaser.Scale.FIT` + `CENTER_BOTH`.\n")
            lines.append("- **Input**: use `pointerdown` / `pointermove` on the scene input — works for both touch and mouse.\n")
            lines.append("\n### Phaser Build Commands\n")
            lines.append("- Dev server: `npm run dev` (opens on http://localhost:5173/)\n")
            lines.append("- Type check + prod build: `npm run build` (outputs to `dist/`)\n")
            lines.append("- First-time Android setup: `npx cap add android` (creates `android/` folder — only needed once)\n")
            lines.append("- Sync web build into Android: `npm run cap:sync`\n")
            lines.append("- Build AAB for Play Store: `npm run android:aab`\n")
            lines.append("- Open Android Studio for debugging: `npm run cap:open`\n")
            lines.append("\n### Testing (Phaser)\n")
            lines.append("- Test in browser first via `npm run dev` — fastest iteration loop.\n")
            lines.append("- For device testing, build debug APK (`npm run android:apk`), install via mobile MCP.\n")
            lines.append("- For each problem found (crash, layout issue, missing element, broken navigation, off-screen content), create a separate new task in tasklist.json.\n")
        with open(claude_md_path, "w", encoding="utf-8") as f:
            f.writelines(lines)

    # Generate package name from developer identity
    s = get_settings()
    import re as _re
    dev_name = _re.sub(r'[^a-z0-9]', '', s.get("developer_name", "").lower())
    clean_slug = _re.sub(r'[^a-z0-9]', '', slug.lower())
    package_name = f"com.{dev_name}.{clean_slug}" if dev_name else ""

    # Auto-generate signing keystore for Android apps
    keystore_path = ""
    key_alias = ""
    key_password = ""
    if body.app_type in ("flutter", "godot", "phaser") and package_name:
        keys_dir = s.get("keys_dir", "")
        if not keys_dir:
            keys_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "keys")
        os.makedirs(keys_dir, exist_ok=True)

        keystore_name = f"{slug}-upload.jks"
        keystore_path = os.path.join(keys_dir, keystore_name)
        key_alias = clean_slug
        key_password = secrets.token_urlsafe(16)

        if not os.path.isfile(keystore_path):
            try:
                keytool_cmd = [
                    "keytool", "-genkeypair",
                    "-v",
                    "-keystore", keystore_path,
                    "-keyalg", "RSA",
                    "-keysize", "2048",
                    "-validity", "18250",  # 50 years
                    "-alias", key_alias,
                    "-storepass", key_password,
                    "-keypass", key_password,
                    "-dname", f"CN={body.name}, O={dev_name or 'Developer'}, C=US",
                ]
                subprocess.run(
                    keytool_cmd, capture_output=True, text=True, timeout=30,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
                )

                # Save key.properties in the project (for Flutter)
                if body.app_type == "flutter":
                    key_props_dir = os.path.join(project_path_win, "android")
                    os.makedirs(key_props_dir, exist_ok=True)
                    key_props_path = os.path.join(key_props_dir, "key.properties")
                    with open(key_props_path, "w", encoding="utf-8") as f:
                        f.write(f"storePassword={key_password}\n")
                        f.write(f"keyPassword={key_password}\n")
                        f.write(f"keyAlias={key_alias}\n")
                        f.write(f"storeFile={keystore_path.replace(os.sep, '/')}\n")

                # Save key info to txt for reference
                key_info_path = os.path.join(keys_dir, f"{slug}-keyinfo.txt")
                with open(key_info_path, "w", encoding="utf-8") as f:
                    f.write(f"App: {body.name}\n")
                    f.write(f"Package: {package_name}\n")
                    f.write(f"Keystore: {keystore_path}\n")
                    f.write(f"Alias: {key_alias}\n")
                    f.write(f"Password: {key_password}\n")
                    f.write(f"Validity: 50 years\n")
                    f.write(f"Created: {datetime.now().isoformat()}\n")

                print(f"[AutoGameBuilder] Generated keystore: {keystore_path}")
            except Exception as e:
                print(f"[AutoGameBuilder] Keystore generation failed: {e}")

    # Scaffold Phaser project template files
    if body.app_type == "phaser":
        try:
            from core.phaser_scaffold import scaffold_phaser_project
            keystore_exists = bool(keystore_path) and os.path.isfile(keystore_path)
            scaffold_phaser_project(
                project_path=project_path_win,
                slug=slug,
                app_name=body.name,
                package_name=package_name,
                keystore_path=keystore_path if keystore_exists else None,
                key_alias=key_alias if keystore_exists else None,
                key_password=key_password if keystore_exists else None,
            )
            print(f"[AutoGameBuilder] Scaffolded Phaser project at: {project_path_win}")
        except Exception as e:
            print(f"[AutoGameBuilder] Phaser scaffold failed: {e}")

    # Create DB entry
    app_id = db().create_app(
        name=body.name,
        slug=slug,
        project_path=project_path,
        app_type=body.app_type,
        current_version="0.0.1",
        package_name=package_name,
        status="idle",
        publish_status="development",
        fix_strategy=body.fix_strategy,
    )

    return {
        "id": app_id,
        "slug": slug,
        "project_path": project_path_win,
        "package_name": package_name,
        "keystore_path": keystore_path,
        "ok": True,
    }


def _resolve_flutter_root(project_path: str) -> str:
    """Find the directory containing pubspec.yaml, checking subdirectories if needed."""
    if os.path.isfile(os.path.join(project_path, "pubspec.yaml")):
        return project_path
    for subdir in ("app", "src", "client", "frontend", "mobile"):
        candidate = os.path.join(project_path, subdir)
        if os.path.isfile(os.path.join(candidate, "pubspec.yaml")):
            return candidate
    return project_path


def _read_project_version(a) -> str:
    """Read the actual version from project files (pubspec.yaml or export_presets.cfg)."""
    import re as _re
    try:
        if a.app_type == "flutter":
            flutter_root = _resolve_flutter_root(a.project_path)
            pubspec = os.path.join(flutter_root, "pubspec.yaml")
            if os.path.isfile(pubspec):
                with open(pubspec, "r", encoding="utf-8") as f:
                    content = f.read()
                match = _re.search(r"version:\s*(\d+\.\d+\.\d+\+\d+)", content)
                if match:
                    return match.group(1)
        elif a.app_type == "godot":
            cfg = os.path.join(a.project_path, "export_presets.cfg")
            if os.path.isfile(cfg):
                with open(cfg, "r", encoding="utf-8") as f:
                    content = f.read()
                name_match = _re.search(r'version/name="([^"]+)"', content)
                code_match = _re.search(r'version/code=(\d+)', content)
                if name_match and code_match:
                    return f"{name_match.group(1)}+{code_match.group(1)}"
                elif name_match:
                    return name_match.group(1)
        elif a.app_type == "phaser":
            pkg_json = os.path.join(a.project_path, "package.json")
            if os.path.isfile(pkg_json):
                with open(pkg_json, "r", encoding="utf-8") as f:
                    content = f.read()
                name_match = _re.search(r'"version":\s*"(\d+\.\d+\.\d+)"', content)
                # Pair with Android versionCode if available, for parity with flutter/godot format
                gradle = os.path.join(a.project_path, "android", "app", "build.gradle")
                code_match = None
                if os.path.isfile(gradle):
                    with open(gradle, "r", encoding="utf-8") as f:
                        gc = f.read()
                    code_match = _re.search(r'versionCode\s+(\d+)', gc)
                if name_match and code_match:
                    return f"{name_match.group(1)}+{code_match.group(1)}"
                elif name_match:
                    return name_match.group(1)
    except Exception:
        pass
    return ""


def _app_dict(a) -> dict:
    version = a.current_version
    real_version = _read_project_version(a)
    if real_version and real_version != version:
        version = real_version
        try:
            db().update_app(a.id, current_version=real_version)
        except Exception:
            pass
    return {
        "id": a.id, "name": a.name, "slug": a.slug,
        "project_path": a.project_path, "app_type": a.app_type,
        "current_version": version, "package_name": a.package_name,
        "status": a.status, "publish_status": a.publish_status,
        "fix_strategy": a.fix_strategy, "notes": a.notes,
        "group_name": a.group_name, "icon_path": a.icon_path,
        "last_build_at": a.last_build_at, "last_fix_at": a.last_fix_at,
        "automation_script_path": a.automation_script_path,
        "github_url": a.github_url, "play_store_url": a.play_store_url,
        "website_url": a.website_url, "console_url": a.console_url,
        "created_at": a.created_at, "updated_at": a.updated_at,
        "open_issues": db().count_issues(a.id, status="open"),
    }


# ── Issues ────────────────────────────────────────────────────

@app.get("/api/issues")
def list_issues(
    app_id: Optional[int] = None,
    status: Optional[str] = None,
    category: Optional[str] = None,
    priority: Optional[int] = None,
):
    issues = db().get_issues(app_id=app_id, status=status, category=category, priority=priority)
    return [_issue_dict(i) for i in issues]

@app.post("/api/issues")
def create_issue(body: IssueCreate):
    a = db().get_app(body.app_id)
    if not a:
        raise HTTPException(404, "App not found")
    issue_id = db().create_issue(**body.model_dump())

    # Auto-queue for fixing
    engine = autofix()
    engine.enqueue_issue(issue_id)
    if not engine.is_running:
        engine.start_processing()

    # For Deathpin: also write as directive so auto-builder picks it up
    if a.slug and "deathpin" in a.slug.lower():
        directive = {
            "message": f"[ISSUE #{issue_id}] {body.category.upper()}: {body.title}\n{body.description}",
            "priority": "urgent" if body.priority <= 2 else "normal",
            "target_app": "deathpin",
            "created_at": datetime.now().isoformat(),
            "read": False,
        }
        directives = []
        if os.path.isfile(DIRECTIVES_FILE):
            try:
                with open(DIRECTIVES_FILE, "r", encoding="utf-8") as f:
                    directives = json.load(f)
            except Exception:
                directives = []
        directives.append(directive)
        with open(DIRECTIVES_FILE, "w", encoding="utf-8") as f:
            json.dump(directives, f, indent=2)

    return {"id": issue_id, "queued": True, "ok": True}

@app.get("/api/issues/{issue_id}")
def get_issue(issue_id: int):
    i = db().get_issue(issue_id)
    if not i:
        raise HTTPException(404, "Issue not found")
    return _issue_dict(i)

@app.patch("/api/issues/{issue_id}")
def update_issue(issue_id: int, body: IssueUpdate):
    i = db().get_issue(issue_id)
    if not i:
        raise HTTPException(404, "Issue not found")
    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    if updates:
        db().update_issue(issue_id, **updates)
    return {"ok": True}

@app.delete("/api/issues/{issue_id}")
def delete_issue(issue_id: int):
    db().delete_issue(issue_id)
    return {"ok": True}

def _issue_dict(i) -> dict:
    return {
        "id": i.id, "app_id": i.app_id,
        "title": _repair_mojibake(i.title or ""),
        "description": _repair_mojibake(i.description or ""),
        "category": i.category,
        "priority": i.priority, "status": i.status,
        "source": i.source, "assigned_ai": i.assigned_ai,
        "fix_prompt": _repair_mojibake(i.fix_prompt or ""),
        "fix_result": _repair_mojibake(i.fix_result or ""),
        "created_at": i.created_at, "updated_at": i.updated_at,
    }


# ── Builds ────────────────────────────────────────────────────

@app.get("/api/builds")
def list_builds(app_id: Optional[int] = None, limit: int = 20):
    builds = db().get_builds(app_id=app_id, limit=limit)
    return [_build_dict(b) for b in builds]

@app.get("/api/builds/{build_id}")
def get_build(build_id: int):
    b = db().get_build(build_id)
    if not b:
        raise HTTPException(404, "Build not found")
    return _build_dict(b)

def _build_dict(b) -> dict:
    return {
        "id": b.id, "app_id": b.app_id, "build_type": b.build_type,
        "version": b.version, "status": b.status,
        "output_path": b.output_path, "duration_seconds": b.duration_seconds,
        "started_at": b.started_at, "completed_at": b.completed_at,
        "created_at": b.created_at, "updated_at": b.updated_at,
    }


# ── Deploy ─────────────────────────────────────────────────────

@app.get("/api/apps/{app_id}/build-targets")
def get_build_targets(app_id: int):
    """Return available build targets for an app."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    targets = deploy_engine().get_targets(a.app_type)
    return {"app_type": a.app_type, "targets": {k: v["label"] for k, v in targets.items()}}


@app.post("/api/apps/{app_id}/deploy")
def deploy_app(app_id: int, body: DeployRequest):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    result = deploy_engine().deploy(
        a, track=body.track, build_target=body.build_target, upload=body.upload
    )
    if "error" in result:
        raise HTTPException(400, result["error"])
    return result

@app.post("/api/apps/{app_id}/deploy/cancel")
def cancel_deploy(app_id: int):
    """Cancel an active build/deploy for the given app."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    # Cancel in deploy engine (kills build subprocess tree)
    result = deploy_engine().cancel(app_id)

    # Also stop any automation processes for this app (catches claude/godot children)
    try:
        stop_automation(app_id)
    except Exception:
        pass

    return result

@app.get("/api/apps/{app_id}/deploy/status")
def deploy_status(app_id: int):
    status = deploy_engine().get_status(app_id)
    if not status:
        return {"phase": "none", "message": "No active deploy"}
    return status


@app.post("/api/apps/{app_id}/deploy/retry-upload")
def retry_upload(app_id: int, body: DeployRequest):
    """Retry uploading the last built AAB without rebuilding."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    de = deploy_engine()
    aab_path = de._get_build_output(a, "aab")
    if not aab_path or not os.path.isfile(aab_path):
        raise HTTPException(404, f"No AAB found at {aab_path}. Build first.")

    import threading
    def _do_upload():
        de._update_status(a.id, phase="uploading", message=f"Re-uploading to {body.track}...")
        result = de._upload_to_play(a, aab_path, body.track)
        if result.get("ok"):
            de._update_status(a.id, phase="done", message=f"Upload succeeded to {body.track}")
            db().update_app(a.id, status="idle")
        else:
            de._update_status(a.id, phase="failed", message=f"Upload failed: {result.get('error', '?')}")

    de._active_deploys[a.id] = {"app_id": a.id, "phase": "uploading", "message": "Starting re-upload..."}
    threading.Thread(target=_do_upload, daemon=True).start()
    return {"ok": True, "message": f"Re-uploading AAB to {body.track}"}


# ── Autofix Sessions ─────────────────────────────────────────

@app.get("/api/sessions")
def list_sessions(app_id: Optional[int] = None, status: Optional[str] = None, limit: int = 50):
    sessions = db().get_sessions(app_id=app_id, status=status, limit=limit)
    return [_session_dict(s) for s in sessions]

def _session_dict(s) -> dict:
    return {
        "id": s.id, "app_id": s.app_id, "issue_id": s.issue_id,
        "ai_tool": s.ai_tool, "status": s.status,
        "exit_code": s.exit_code, "duration_seconds": s.duration_seconds,
        "error_message": s.error_message,
        "files_changed": s.files_changed_list(),
        "started_at": s.started_at, "completed_at": s.completed_at,
        "created_at": s.created_at, "updated_at": s.updated_at,
    }


# ── Universal Tasklist (per-app) ──────────────────────────────

def _tasklist_path(a) -> str:
    return os.path.join(a.project_path, "tasklist.json")


# Per-app locks to prevent concurrent read-modify-write on the same tasklist.json
_tasklist_locks: dict[str, threading.Lock] = {}
_tasklist_locks_lock = threading.Lock()


def _get_tasklist_lock(path: str) -> threading.Lock:
    """Get or create a lock for a specific tasklist.json file path."""
    with _tasklist_locks_lock:
        if path not in _tasklist_locks:
            _tasklist_locks[path] = threading.Lock()
        return _tasklist_locks[path]


def _repair_mojibake(text: str) -> str:
    """Fix UTF-8 text that was corrupted by being read as cp1252/latin-1.

    Detects the telltale 'Ã' or 'â€' patterns (multi-byte UTF-8 chars misread
    as single-byte Windows encoding) and reverses the damage by re-encoding
    back to cp1252 bytes and decoding as UTF-8.
    """
    if not isinstance(text, str) or not text:
        return text
    # Common mojibake signatures: â€" (em-dash), â€™ (right quote), Ã© (é), etc.
    # \u00e2\u0080 = Latin-1 decoded; \u00e2\u20ac = CP1252 decoded (0x80 → €)
    if "\u00e2\u0080" in text or "\u00e2\u20ac" in text or "\u00c3" in text:
        try:
            return text.encode("cp1252").decode("utf-8")
        except (UnicodeDecodeError, UnicodeEncodeError):
            pass
    return text


def _repair_task_text(task: dict) -> dict:
    """Repair mojibake in user-visible text fields of a task."""
    for key in ("title", "description", "response", "ai_response"):
        if key in task and isinstance(task[key], str):
            task[key] = _repair_mojibake(task[key])
    return task


def _load_tasklist(a) -> list:
    path = _tasklist_path(a)
    if os.path.isfile(path):
        try:
            # Be tolerant to accidental non-UTF encodings written by external agents/tools.
            # We prefer UTF-8, then common Windows fallbacks.
            data = None
            for enc in ("utf-8", "utf-8-sig", "cp1252", "latin-1"):
                try:
                    with open(path, "r", encoding=enc) as f:
                        raw = f.read()
                    if not raw.strip():
                        return []
                    data = json.loads(raw)
                    break
                except (json.JSONDecodeError, UnicodeDecodeError):
                    data = None
                except Exception:
                    data = None
            if data is None:
                # All encodings failed - file may be corrupted. Try backup.
                backup_path = path + ".bak"
                if os.path.isfile(backup_path):
                    try:
                        with open(backup_path, "r", encoding="utf-8") as f:
                            data = json.load(f)
                        # Restore from backup
                        shutil.copy2(backup_path, path)
                        print(f"WARNING: Restored tasklist.json from backup: {path}")
                    except Exception:
                        return []
                else:
                    return []
            tasks = data.get("tasks", data) if isinstance(data, dict) else data
            # Normalize "done" → "completed" (some AI agents use "done" instead)
            # Also repair any mojibake from prior encoding bugs (UTF-8 read as cp1252)
            for t in tasks:
                if isinstance(t, dict):
                    if t.get("status", "").lower() == "done":
                        t["status"] = "completed"
                    _repair_task_text(t)
            return tasks
        except Exception:
            pass
    return []


def _normalize_task(t: dict, agent: str = "") -> dict:
    """Normalize tasklist.json fields to match mobile app expectations."""
    result = dict(t)
    result["task_type"] = t.get("type", t.get("task_type", "issue"))
    result["ai_response"] = t.get("response", t.get("ai_response", ""))
    # Prefer the agent recorded in the task itself
    result["agent"] = t.get("completed_by", t.get("agent", agent))
    return result


def _save_tasklist(a, tasks: list):
    """Atomically save tasklist.json: write to temp file, then rename over original.
    Also keeps a .bak backup of the previous version for recovery."""
    path = _tasklist_path(a)
    dir_path = os.path.dirname(path)

    # Validate tasks data before writing
    payload = json.dumps({"tasks": tasks}, indent=2, ensure_ascii=False)
    # Verify we can parse what we just serialized (catch corruption before write)
    json.loads(payload)

    # Keep backup of current file
    if os.path.isfile(path):
        try:
            shutil.copy2(path, path + ".bak")
        except Exception:
            pass

    # Atomic write: write to temp file in same directory, then rename
    try:
        fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp", prefix=".tasklist_")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(payload)
            f.flush()
            os.fsync(f.fileno())
        # On Windows, os.rename fails if target exists; use os.replace instead
        os.replace(tmp_path, path)
    except Exception:
        # Clean up temp file on failure
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
        raise


@app.get("/api/apps/{app_id}/tasks")
def get_app_tasks(app_id: int, status: Optional[str] = None):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    tasks = _load_tasklist(a)
    if status:
        tasks = [t for t in tasks if t.get("status") == status]
    # Get agent from automation config
    configs = _load_automation_configs()
    agent = configs.get(str(app_id), {}).get("ai_agent", "")
    normalized = [_normalize_task(t, agent) for t in tasks]
    # Sort by created_at descending (newest first) for consistent ordering
    normalized.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return normalized


@app.post("/api/apps/{app_id}/tasks")
def add_app_task(app_id: int, body: TaskCreate):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    lock = _get_tasklist_lock(_tasklist_path(a))
    with lock:
        tasks = _load_tasklist(a)
        new_id = max((t.get("id", 0) for t in tasks), default=0) + 1
        task = {
            "id": new_id,
            "title": body.title,
            "description": body.description,
            "type": body.task_type,
            "priority": body.priority,
            "status": "pending",
            "source": "mobile",
            "response": "",
            "created_at": datetime.now().isoformat(),
        }

        # Save image attachments to disk
        MAX_ATTACHMENT_SIZE = 10 * 1024 * 1024  # 10 MB per attachment
        MAX_ATTACHMENTS = 10
        if body.attachments:
            import base64
            if len(body.attachments) > MAX_ATTACHMENTS:
                raise HTTPException(status_code=400, detail=f"Too many attachments (max {MAX_ATTACHMENTS})")
            attach_dir = os.path.join(a.project_path, "task_attachments", str(new_id))
            os.makedirs(attach_dir, exist_ok=True)
            saved_paths = []
            for idx, b64 in enumerate(body.attachments):
                try:
                    img_bytes = base64.b64decode(b64)
                    if len(img_bytes) > MAX_ATTACHMENT_SIZE:
                        logger.warning("Attachment %d exceeds size limit (%d bytes), skipping", idx, len(img_bytes))
                        continue
                    img_path = os.path.join(attach_dir, f"image_{idx}.png")
                    with open(img_path, "wb") as img_f:
                        img_f.write(img_bytes)
                    saved_paths.append(img_path)
                except Exception:
                    pass
            if saved_paths:
                task["attachments"] = saved_paths

        tasks.append(task)

        # Auto-archive: keep active tasks + last 100 done tasks, archive the rest
        done_statuses = ("completed", "built", "divided", "archived")
        active = [t for t in tasks if t.get("status") not in done_statuses]
        done = [t for t in tasks if t.get("status") in done_statuses]
        if len(done) > 100:
            overflow = done[:-100]
            keep_done = done[-100:]
            archive_dir = os.path.join(a.project_path, "task_archives")
            os.makedirs(archive_dir, exist_ok=True)
            archive_file = os.path.join(archive_dir, f"archived_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
            with open(archive_file, "w", encoding="utf-8") as af:
                json.dump({"archived_tasks": overflow, "archived_at": datetime.now().isoformat()}, af, indent=2, ensure_ascii=False)
            tasks = active + keep_done
            tasks.sort(key=lambda t: t.get("id", 0))

        _save_tasklist(a, tasks)

    # Also create as DB issue for tracking
    db().create_issue(
        app_id=app_id, title=body.title, description=body.description,
        category="idea" if body.task_type == "idea" else "bug",
        priority=2 if body.priority == "urgent" else 3,
        source="mobile",
    )

    return {"id": new_id, "ok": True}


@app.patch("/api/apps/{app_id}/tasks/{task_id}")
def update_app_task(app_id: int, task_id: int, updates: dict):
    """Update a task's fields (status, response, completed_by, etc.)."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    lock = _get_tasklist_lock(_tasklist_path(a))
    with lock:
        tasks = _load_tasklist(a)
        task = next((t for t in tasks if t.get("id") == task_id), None)
        if not task:
            raise HTTPException(404, f"Task {task_id} not found")
        allowed = {"status", "response", "completed_by", "priority", "title", "description"}
        for key, val in updates.items():
            if key in allowed:
                task[key] = val
        _save_tasklist(a, tasks)
    return {"ok": True}


@app.delete("/api/apps/{app_id}/tasks/{task_id}")
def delete_app_task(app_id: int, task_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    lock = _get_tasklist_lock(_tasklist_path(a))
    with lock:
        tasks = _load_tasklist(a)

        task_to_delete = next((t for t in tasks if t.get("id") == task_id), None)
        if not task_to_delete:
            raise HTTPException(404, "Task not found")

        title = task_to_delete.get("title")

        new_tasks = [t for t in tasks if t.get("id") != task_id]
        _save_tasklist(a, new_tasks)

    # Also delete DB issue if it exists (matched by title and app_id)
    issues = db().get_issues(app_id=app_id)
    for i in issues:
        if i.title == title:
            db().delete_issue(i.id)
            break
            
    return {"ok": True}


@app.get("/api/apps/{app_id}/tasks/status")
def app_tasks_status(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    tasks = _load_tasklist(a)
    return {
        "total": len(tasks),
        "completed": sum(1 for t in tasks if t.get("status") == "completed"),
        "built": sum(1 for t in tasks if t.get("status") == "built"),
        "divided": sum(1 for t in tasks if t.get("status") == "divided"),
        "pending": sum(1 for t in tasks if t.get("status") == "pending"),
        "in_progress": sum(1 for t in tasks if t.get("status") in ("in_progress", "partial")),
        "failed": sum(1 for t in tasks if t.get("status") == "failed"),
    }


@app.post("/api/apps/{app_id}/tasks/archive")
def archive_app_tasks(app_id: int):
    """Force-archive completed/built tasks, keeping only active + last 100 done."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    tasks = _load_tasklist(a)
    done_statuses = ("completed", "built", "divided", "archived")
    active = [t for t in tasks if t.get("status") not in done_statuses]
    done = [t for t in tasks if t.get("status") in done_statuses]
    if len(done) <= 100:
        return {"ok": True, "archived": 0, "remaining": len(tasks)}
    overflow = done[:-100]
    keep_done = done[-100:]
    archive_dir = os.path.join(a.project_path, "task_archives")
    os.makedirs(archive_dir, exist_ok=True)
    archive_file = os.path.join(archive_dir, f"archived_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json")
    with open(archive_file, "w", encoding="utf-8") as af:
        json.dump({"archived_tasks": overflow, "archived_at": datetime.now().isoformat()}, af, indent=2, ensure_ascii=False)
    tasks = active + keep_done
    tasks.sort(key=lambda t: t.get("id", 0))
    _save_tasklist(a, tasks)
    return {"ok": True, "archived": len(overflow), "remaining": len(tasks)}


# ── Logs (unified across all apps) ──────────────────────────

@app.get("/api/logs")
def get_all_logs(app_id: Optional[int] = None, limit: int = 50):
    """Get structured logs from auto_build_logs/completions.log for any app."""
    logs = []
    if app_id:
        apps = [db().get_app(app_id)]
    else:
        apps = db().get_all_apps()

    # Get automation configs for agent info
    configs = _load_automation_configs()

    for a in apps:
        if not a:
            continue
        agent = configs.get(str(a.id), {}).get("ai_agent", "")
        # Check auto_build_logs
        log_file = os.path.join(a.project_path, "auto_build_logs", "completions.log")
        if not os.path.isfile(log_file):
            log_file = os.path.join(a.project_path, "build_logs", "task_completions.log")
        if os.path.isfile(log_file):
            try:
                with open(log_file, "r", encoding="utf-8") as f:
                    lines = f.readlines()[-limit:]
                for line in lines:
                    parsed = _parse_log_line(line.strip(), a.name, a.id, agent)
                    if parsed:
                        logs.append(parsed)
            except Exception:
                pass

    logs.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    return logs[:limit]


def _parse_log_line(line: str, app_name: str, app_id: int, agent: str) -> dict:
    """Parse a log line like '[2026-03-05 22:24:29] Session 1 completed (exit: 0)' into structured data."""
    if not line:
        return None
    import re
    timestamp = ""
    message = line
    # Extract timestamp from [YYYY-MM-DD HH:MM:SS] prefix
    ts_match = re.match(r'\[(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})\]\s*(.*)', line)
    if ts_match:
        timestamp = ts_match.group(1).replace(' ', 'T')
        message = ts_match.group(2)
    
    # Try to extract agent from line if it's there like "(claude)"
    line_agent = agent
    agent_match = re.search(r'\((\w+)\)', message)
    if agent_match:
        line_agent = agent_match.group(1)

    # Determine log level from content
    level = "info"
    lower = message.lower()
    
    # Exit code check
    exit_match = re.search(r'exit: (\d+)', lower)
    exit_code = int(exit_match.group(1)) if exit_match else None

    if any(w in lower for w in ("error", "failed", "fail", "exception", "crash")):
        level = "error"
    elif any(w in lower for w in ("warning", "warn", "rate limit", "retry")):
        level = "warning"
    elif exit_code is not None:
        level = "success" if exit_code == 0 else "error"
    elif any(w in lower for w in ("completed", "success", "done", "finished")):
        level = "success"

    return {
        "app_name": app_name,
        "app_id": app_id,
        "message": message,
        "level": level,
        "timestamp": timestamp,
        "source": line_agent,
    }


@app.get("/api/apps/{app_id}/logs")
def get_app_logs(app_id: int, limit: int = 50):
    return get_all_logs(app_id=app_id, limit=limit)


# ── Ideas (tasks with type=idea that have AI responses) ──────

@app.get("/api/ideas")
def get_all_ideas(app_id: Optional[int] = None):
    if app_id:
        apps = [db().get_app(app_id)]
    else:
        apps = db().get_all_apps()

    ideas = []
    configs = _load_automation_configs()
    for a in apps:
        if not a:
            continue
        agent = configs.get(str(a.id), {}).get("ai_agent", "")
        tasks = _load_tasklist(a)
        for t in tasks:
            if t.get("type") == "idea":
                normalized = _normalize_task(t, agent)
                normalized["app_name"] = a.name
                normalized["app_id"] = a.id
                ideas.append(normalized)
    ideas.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return ideas


@app.delete("/api/ideas/{idea_id}")
def delete_idea(idea_id: int):
    apps = db().get_all_apps()
    for a in apps:
        lock = _get_tasklist_lock(_tasklist_path(a))
        with lock:
            tasks = _load_tasklist(a)
            # We look for a task that is an idea and has this ID
            task_to_delete = next((t for t in tasks if t.get("id") == idea_id and t.get("type") == "idea"), None)
            if task_to_delete:
                title = task_to_delete.get("title")
                new_tasks = [t for t in tasks if t != task_to_delete]
                _save_tasklist(a, new_tasks)

                # Also delete DB issue if it exists
                issues = db().get_issues(app_id=a.id)
                for i in issues:
                    if i.title == title:
                        db().delete_issue(i.id)
                        break
                return {"ok": True}
    raise HTTPException(404, "Idea not found")


# ── GDD (Game/App Design Document) ────────────────────────────

@app.get("/api/apps/{app_id}/gdd")
def get_gdd(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    gdd_path = os.path.join(a.project_path, "gdd.md")
    if os.path.isfile(gdd_path):
        with open(gdd_path, "r", encoding="utf-8") as f:
            return {"content": f.read(), "exists": True}
    return {"content": "", "exists": False}

@app.put("/api/apps/{app_id}/gdd")
def update_gdd(app_id: int, body: GddUpdate):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    gdd_path = os.path.join(a.project_path, "gdd.md")
    with open(gdd_path, "w", encoding="utf-8") as f:
        f.write(body.content)
    return {"ok": True}


# ── CLAUDE.md (Project Instructions) ─────────────────────────

@app.get("/api/apps/{app_id}/claude-md")
def get_claude_md(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    claude_path = os.path.join(a.project_path, "CLAUDE.md")
    if os.path.isfile(claude_path):
        with open(claude_path, "r", encoding="utf-8") as f:
            return {"content": f.read()}
    return {"content": ""}

@app.put("/api/apps/{app_id}/claude-md")
def update_claude_md(app_id: int, body: GddUpdate):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")
    claude_path = os.path.join(a.project_path, "CLAUDE.md")
    with open(claude_path, "w", encoding="utf-8") as f:
        f.write(body.content)
    return {"status": "ok"}


# ── Async Enhance (background thread, no timeout issues) ─────

_enhance_status: dict[int, dict] = {}  # app_id -> {type, status, error}


class EnhanceRequest(BaseModel):
    type: str = "gdd"  # "gdd" or "claude-md"


@app.post("/api/apps/{app_id}/enhance")
def enhance_doc(app_id: int, body: EnhanceRequest):
    """Fire-and-forget enhance: runs AI in background, saves result directly."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    doc_type = body.type
    if doc_type == "gdd":
        doc_path = os.path.join(a.project_path, "gdd.md")
    elif doc_type == "claude-md":
        doc_path = os.path.join(a.project_path, "CLAUDE.md")
    else:
        raise HTTPException(400, "type must be 'gdd' or 'claude-md'")

    if not os.path.isfile(doc_path):
        raise HTTPException(404, f"{doc_type} file not found")

    with open(doc_path, "r", encoding="utf-8") as f:
        content = f.read().strip()
    if not content:
        raise HTTPException(400, "Document is empty — nothing to enhance")

    # Check if already running
    existing = _enhance_status.get(app_id)
    if existing and existing.get("status") == "running" and existing.get("type") == doc_type:
        return {"ok": True, "status": "already_running"}

    _enhance_status[app_id] = {"type": doc_type, "status": "running", "error": None}

    def _enhance_worker():
        try:
            if doc_type == "gdd":
                gdd_template = _load_studio_knowledge("gdd_template")
                prompt = f"""Enhance and restructure the following design document into a professional Game/App Design Document.

The document MUST contain these 8 required sections (add any that are missing with reasonable defaults based on context):
{gdd_template}

Rules:
- Preserve all existing design intent and specifics from the original
- Fill in gaps with reasonable suggestions clearly marked as [SUGGESTED]
- All economy values (prices, rewards, timers) must reference data files, never hardcoded
- Include a Q&A section at the end for any ambiguities you identified

Current design document:
{content}

Return ONLY the enhanced document text. No extra commentary."""
            else:
                prompt = f"""Enhance and restructure the following CLAUDE.md project instructions file. Make it well-organized with clear sections, better structure, and more detail. Preserve all existing rules and conventions.

Apply these Game Studio standards if not already present:
- Player Experience First: think like a player, not a developer
- Feedback on Every Action: visual + audio + state change
- Data-Driven Values: economy values from config files, never hardcoded
- Single Responsibility: one script = one system
- Architecture: data flows down, events flow up, no circular dependencies
- Asset Quality: no placeholders, generate real assets or fail the task

Also, identify any gaps or missing areas that would help an AI assistant work more effectively on this project. For each gap, write a relevant suggestion and provide recommended content.

Current CLAUDE.md:
{content}

Return ONLY the enhanced CLAUDE.md content. No extra commentary."""

            claude_bin = _get_tool_paths()["claude_bin"]
            bash_exe = _get_tool_paths()["bash_exe"]
            clean_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

            cmd = f'"{claude_bin}" -p --model sonnet --output-format json'
            proc = subprocess.Popen(
                [bash_exe, "-l", "-c", cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=clean_env,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            stdout, _ = proc.communicate(input=prompt.encode("utf-8"), timeout=600)
            output = stdout.decode("utf-8", errors="replace").strip() if stdout else ""

            # Parse response
            response_text = output
            try:
                data = json.loads(output)
                response_text = data.get("result", output)
            except (json.JSONDecodeError, ValueError):
                pass

            if response_text and len(response_text.strip()) > 50:
                # Save enhanced content
                with open(doc_path, "w", encoding="utf-8") as f:
                    f.write(response_text.strip())
                _enhance_status[app_id] = {"type": doc_type, "status": "done", "error": None}
            else:
                _enhance_status[app_id] = {"type": doc_type, "status": "failed", "error": "AI returned empty or too short response"}

        except subprocess.TimeoutExpired:
            _enhance_status[app_id] = {"type": doc_type, "status": "failed", "error": "Timed out after 10 minutes"}
            try:
                proc.kill()
            except Exception:
                pass
        except Exception as e:
            _enhance_status[app_id] = {"type": doc_type, "status": "failed", "error": str(e)}

    thread = threading.Thread(target=_enhance_worker, daemon=True)
    thread.start()
    return {"ok": True, "status": "started"}


@app.get("/api/apps/{app_id}/enhance/status")
def enhance_status(app_id: int):
    """Check enhance status for an app."""
    status = _enhance_status.get(app_id)
    if not status:
        return {"status": "idle"}
    # Evict terminal statuses after they've been read once
    if status.get("status") in ("done", "failed"):
        _enhance_status.pop(app_id, None)
    return status


# ── Deathpin Auto-Builder (legacy compat) ─────────────────────

@app.get("/api/deathpin/status")
def deathpin_status():
    tasks_file = os.path.join(DEATHPIN_DIR, "tasks.json")
    result = {"running": False, "total": 0, "completed": 0, "pending": 0, "in_progress": 0}
    try:
        with open(tasks_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        tasks = data.get("tasks", [])
        result["total"] = len(tasks)
        result["completed"] = sum(1 for t in tasks if t["status"] == "completed")
        result["pending"] = sum(1 for t in tasks if t["status"] == "pending")
        result["in_progress"] = sum(1 for t in tasks if t["status"] in ("in_progress", "partial"))
        # Check if auto-builder is running (recent log file modified in last 15 min)
        log_dir = os.path.join(DEATHPIN_DIR, "build_logs")
        if os.path.isdir(log_dir):
            logs = sorted(
                [f for f in os.listdir(log_dir) if f.startswith("session_") and f.endswith(".log")],
                reverse=True,
            )
            if logs:
                latest = os.path.join(log_dir, logs[0])
                mtime = os.path.getmtime(latest)
                if (datetime.now().timestamp() - mtime) < 900:
                    result["running"] = True
                result["latest_session"] = logs[0]
    except Exception as e:
        result["error"] = str(e)
    return result

@app.get("/api/deathpin/tasks")
def deathpin_tasks(status: Optional[str] = None, limit: int = 50):
    tasks_file = os.path.join(DEATHPIN_DIR, "tasks.json")
    try:
        with open(tasks_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        tasks = data.get("tasks", [])
        if status:
            tasks = [t for t in tasks if t["status"] == status]
        return tasks[-limit:]
    except Exception as e:
        raise HTTPException(500, str(e))

@app.get("/api/deathpin/log")
def deathpin_log(lines: int = 50):
    log_file = os.path.join(DEATHPIN_DIR, "build_logs", "task_completions.log")
    try:
        with open(log_file, "r", encoding="utf-8") as f:
            all_lines = f.readlines()
        return {"lines": [l.strip() for l in all_lines[-lines:]]}
    except FileNotFoundError:
        return {"lines": []}

@app.post("/api/deathpin/directive")
def send_directive(body: DirectiveCreate):
    directives = []
    if os.path.isfile(DIRECTIVES_FILE):
        try:
            with open(DIRECTIVES_FILE, "r", encoding="utf-8") as f:
                directives = json.load(f)
        except (json.JSONDecodeError, Exception):
            directives = []
    directives.append({
        "message": body.message,
        "priority": body.priority,
        "target_app": body.target_app,
        "created_at": datetime.now().isoformat(),
        "read": False,
    })
    with open(DIRECTIVES_FILE, "w", encoding="utf-8") as f:
        json.dump(directives, f, indent=2)
    return {"ok": True, "total_directives": len(directives)}

@app.get("/api/deathpin/directives")
def get_directives():
    if not os.path.isfile(DIRECTIVES_FILE):
        return []
    try:
        with open(DIRECTIVES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []


# ── Dashboard Summary ─────────────────────────────────────────

@app.get("/api/dashboard")
def dashboard():
    apps = db().get_all_apps()
    total_open = 0
    app_summaries = []
    for a in apps:
        open_count = db().count_issues(a.id, status="open")
        total_open += open_count
        version = _read_project_version(a) or a.current_version
        app_summaries.append({
            "id": a.id, "name": a.name, "slug": a.slug,
            "app_type": a.app_type, "status": a.status,
            "publish_status": a.publish_status, "current_version": version,
            "open_issues": open_count, "fix_strategy": a.fix_strategy,
            "icon_path": a.icon_path,
        })
    return {
        "total_apps": len(apps),
        "total_open_issues": total_open,
        "apps": app_summaries,
    }


# ── Delta Sync ───────────────────────────────────────────────

@app.get("/api/sync")
def delta_sync(since: str = ""):
    """Return all records changed since the given ISO timestamp.

    First call (no since): returns everything for initial cache population.
    Subsequent calls: returns only records created/updated/deleted after `since`.
    """
    d = db()
    server_time = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    if not since:
        apps = d.get_all_apps(include_archived=True)
        issues = d.get_all_issues()
        builds = d.get_all_builds()
        sessions = d.get_all_sessions()
        deleted = []
    else:
        apps = d.get_apps_since(since)
        issues = d.get_issues_since(since)
        builds = d.get_builds_since(since)
        sessions = d.get_sessions_since(since)
        deleted = d.get_deleted_since(since)

    return {
        "apps": [_app_dict(a) for a in apps],
        "issues": [_issue_dict(i) for i in issues],
        "builds": [_build_dict(b) for b in builds],
        "sessions": [_session_dict(s) for s in sessions],
        "deleted": deleted,
        "server_time": server_time,
    }


# ── Automations ───────────────────────────────────────────────

AUTOMATIONS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "automations")
AUTOMATIONS_FILE = os.path.join(AUTOMATIONS_DIR, "configs.json")
os.makedirs(AUTOMATIONS_DIR, exist_ok=True)

# ── Process tracking with thread safety ──────────────────────
_proc_lock = threading.Lock()

# Track running automation processes: {app_id: subprocess.Popen}
_running_automations: dict[int, subprocess.Popen] = {}

# Track running task processes: {(app_id, task_id): (subprocess.Popen, deadline_time)}
_running_task_processes: dict[tuple, tuple] = {}

# Track run-once processes: {app_id: subprocess.Popen}
_running_oneshots: dict[int, subprocess.Popen] = {}

# Track chat processes: {thread_id: subprocess.Popen}
_running_chat_procs: dict[int, subprocess.Popen] = {}


def _kill_process_tree(proc: subprocess.Popen, timeout: int = 5):
    """Kill a process and ALL its children (entire tree) using psutil."""
    pid = proc.pid
    try:
        parent = psutil.Process(pid)
        children = parent.children(recursive=True)
        # Kill children first (bottom-up)
        for child in reversed(children):
            try:
                child.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        # Then kill parent
        try:
            parent.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
        # Wait for all to die
        gone, alive = psutil.wait_procs(children + [parent], timeout=timeout)
        # Force kill any survivors
        for p in alive:
            try:
                p.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except psutil.NoSuchProcess:
        pass  # Already dead
    except Exception:
        # Fallback: try basic kill
        try:
            proc.kill()
        except Exception:
            pass


def _stop_tracked_proc(proc: subprocess.Popen):
    """Terminate a tracked process and its entire tree."""
    if proc and proc.poll() is None:
        _kill_process_tree(proc)


def _automation_subprocess_env() -> dict:
    """Clean environment for automation subprocesses."""
    env = dict(os.environ)
    for key in list(env.keys()):
        if key.startswith("CODEX_"):
            env.pop(key, None)
    return env


def _load_automation_configs() -> dict:
    if os.path.isfile(AUTOMATIONS_FILE):
        try:
            with open(AUTOMATIONS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def _save_automation_configs(configs: dict):
    with open(AUTOMATIONS_FILE, "w", encoding="utf-8") as f:
        json.dump(configs, f, indent=2)


def _load_automation_instructions() -> str:
    """Load general automation instructions from config/automation_claude.md."""
    instructions_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config", "automation_claude.md")
    if os.path.isfile(instructions_path):
        try:
            with open(instructions_path, "r", encoding="utf-8") as f:
                return f"\n{f.read().strip()}\n"
        except Exception:
            pass
    return ""


def _load_studio_knowledge(focus_key: str) -> str:
    """Load Game Studios specialist knowledge for a given focus area.
    focus_key: 'visual_audit', 'gameplay_ux', 'code_quality', 'polish_ideas', 'brainstorm', 'gdd_template', 'specialist_routing'
    """
    studio_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config", "studio")
    filepath = os.path.join(studio_dir, f"{focus_key}.md")
    if os.path.isfile(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return f"\n{f.read().strip()}\n"
        except Exception:
            pass
    return ""


def _resolve_mcp_config(a, config: dict, project_path_unix: str) -> str:
    """Resolve MCP config path: use per-app MCP servers, fall back to automation config, then app's existing one."""
    # Priority: per-app MCP setting > automation config > app's mcp_config_path
    mcp_servers_list = _get_app_mcp_servers(a.id)
    if not mcp_servers_list:
        mcp_servers_list = config.get("mcp_servers", [])
    if mcp_servers_list:
        mcp_data = _build_mcp_config_file(mcp_servers_list)
        if mcp_data["mcpServers"]:
            mcp_file = os.path.join(a.project_path, "mcp_config.json")
            os.makedirs(os.path.dirname(mcp_file), exist_ok=True)
            with open(mcp_file, "w", encoding="utf-8") as f:
                json.dump(mcp_data, f, indent=2)
            return f"{project_path_unix}/mcp_config.json"
    elif a.mcp_config_path:
        return f"{project_path_unix}/mcp_config.json"
    return ""


def _generate_auto_build_script(a, config: dict) -> str:
    """Generate an auto_build.sh for any app."""
    app_id = str(config["app_id"])
    ai_agent = config.get("ai_agent", "claude")
    interval = config.get("interval_minutes", 10) * 60
    timeout = config.get("max_session_minutes", 18) * 60
    prompt = config.get("prompt", "")
    project_path_unix = to_unix_path(a.project_path)
    project_path_win = a.project_path.replace("/", "\\")
    log_dir = f"{project_path_unix}/auto_build_logs"
    claude_bin = _get_tool_paths()["claude_bin"]
    gemini_bin = _get_tool_paths()["gemini_bin"]
    codex_bin = _get_tool_paths()["codex_bin"]

    # Check if GDD exists
    gdd_path = os.path.join(a.project_path, "gdd.md")
    gdd_section = ""
    if os.path.isfile(gdd_path):
        gdd_section = f"""
IMPORTANT: Read gdd.md in the project root. This is the Game Design Document / App Design Document.
Follow its vision, goals, and specifications when working on tasks or generating ideas.
"""

    status_contract = f"""
CRITICAL — MANDATORY TASK STATUS CONTRACT (APPLIES TO EVERY TASK YOU PICK):
You MUST follow these steps IN ORDER for EVERY task. Skipping any step is a failure.
1. FIRST ACTION for each task: Open tasklist.json, find the task, set "status" to "in_progress", SAVE THE FILE. Do this BEFORE reading any source code or making any changes.
2. Work on exactly ONE task at a time. Do not start another task until the current one is marked completed or failed.
3. When task is DONE: set "status" to "completed", set "completed_by" to "{ai_agent}", write a concrete summary in "response". SAVE immediately.
4. When task CANNOT be finished: set "status" to "failed", set "completed_by" to "{ai_agent}", explain the blocker in "response". SAVE immediately.
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
"""

    # --- Weighted random session focus (roll 1-100) ---
    # Load specialist knowledge from Game Studios config/studio/ files
    focus_roll = random.randint(1, 100)
    if focus_roll <= 35:
        session_focus = "VISUAL / ASSET AUDIT"
        studio_knowledge = _load_studio_knowledge("visual_audit")
        session_focus_details = f"""Generate tasks about VISUAL and ASSET issues:
- Cross-reference all files in assets/ directory vs code references. Are all sprites actually loaded?
- Are animations wired up and playing? Or are static fallback sprites shown instead?
- Does the UI fit the target viewport (check project resolution)? Any text overflow or clipping?
- Are there generated assets sitting in assets/ that no code references?
- Do buttons, panels, labels render correctly without overlapping?
- Think like a PLAYER looking at the screen, not a developer reading code.
{studio_knowledge}"""
    elif focus_roll <= 65:
        session_focus = "GAMEPLAY / UX"
        studio_knowledge = _load_studio_knowledge("gameplay_ux")
        session_focus_details = f"""Generate tasks about GAMEPLAY and UX issues:
- Do game mechanics work correctly? State machines in sync?
- Are touch targets at least 48px for mobile?
- Do buttons give visual/audio feedback when pressed?
- Is the game flow logical? Can the player get stuck anywhere?
- Are error messages user-friendly? Are loading states shown?
- Test edge cases: what happens with 0 resources, max level, empty states?
{studio_knowledge}"""
    elif focus_roll <= 85:
        session_focus = "CODE QUALITY"
        studio_knowledge = _load_studio_knowledge("code_quality")
        session_focus_details = f"""Generate tasks about CODE QUALITY:
- Null checks after await, is_instance_valid guards
- Signal cleanup in _exit_tree
- Memory leaks, resource cleanup
- Error handling at system boundaries
{studio_knowledge}"""
    else:
        session_focus = "POLISH / NEW IDEAS"
        studio_knowledge = _load_studio_knowledge("polish_ideas")
        session_focus_details = f"""Generate tasks about POLISH and NEW IDEAS:
- Small quality-of-life improvements
- Performance optimizations (only if measurable)
- Missing juice/feedback (particles, tweens, sound effects)
- Features that would make the game more fun or the app more useful
{studio_knowledge}"""

    if not prompt:
        prompt = f"""You are autonomously working on {a.name} ({a.app_type} project).
Project path: {a.project_path}
{gdd_section}
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
- Set "completed_by" to "{ai_agent}"
Do this IMMEDIATELY after each task, not at the end.

STEP 4B - FAILURE HANDLING:
If you start a task but cannot complete it in this run, update tasklist.json immediately:
- Set "status" to "failed"
- Set "completed_by" to "{ai_agent}"
- Write the blocker/error clearly in "response"

STEP 5 - GENERATE NEW TASKS:
After completing existing tasks, generate new tasks based on this session's focus area.
Add them to tasklist.json with status "pending" and a clear title + description.
Generate as many tasks as you see fit — there is no limit. Create every useful task you can identify.

IMPORTANT — TASK PRIORITY RULES (always apply):
- Crashes and build failures are ALWAYS top priority regardless of focus area.
- ALWAYS work on existing pending tasks before generating new ones.
- Work on oldest tasks first (lowest ID).

THIS SESSION'S FOCUS AREA: {session_focus}
{session_focus_details}

STEP 6 - BUILD (if applicable):
If this is a buildable project, attempt a build to verify nothing is broken.

REPEAT: The system will call you again after a break. Leave the project in a good state.
"""
    automation_instructions = _load_automation_instructions()
    prompt = f"""{prompt}

{status_contract}
{automation_instructions}
"""

    mcp_config_path = _resolve_mcp_config(a, config, project_path_unix)
    ai_cmd = _build_ai_command(ai_agent, timeout, claude_bin, gemini_bin, codex_bin, project_path_unix, a, mcp_config_path)

    script = f'''#!/bin/bash
# Auto-generated automation for {a.name}
# AI Agent: {ai_agent} | Interval: {config.get("interval_minutes", 10)}min

set +e
trap '' HUP
trap 'echo "STOPPED"; exit 0' INT TERM

PROJECT_DIR="{project_path_unix}"
LOG_DIR="{log_dir}"
CLAUDE_BIN="{claude_bin}"
INTERVAL={interval}

mkdir -p "$LOG_DIR"

SESSION=0
echo "=== AUTOMATION STARTED: {a.name} ({ai_agent}) ==="
echo "=== Interval: {config.get("interval_minutes", 10)}min | Timeout: {config.get("max_session_minutes", 18)}min ==="

while true; do
    SESSION=$((SESSION + 1))
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="$LOG_DIR/session_${{SESSION}}_${{TIMESTAMP}}.log"

    echo ""
    echo ">>> SESSION $SESSION started at $(date) <<<"

    # Wait for internet
    while ! curl -s --connect-timeout 5 {get_settings().get("internet_check_url", "https://api.anthropic.com")} > /dev/null 2>&1; do
        echo ">>> No internet. Retrying in 30s... <<<"
        sleep 30
    done

    cd "$PROJECT_DIR"
    PROMPT_FILE=$(mktemp /tmp/{a.slug}_prompt_XXXXXX.txt 2>/dev/null) || PROMPT_FILE="$LOG_DIR/.prompt_tmp.txt"
    cat > "$PROMPT_FILE" << 'ENDPROMPT'
{prompt}
ENDPROMPT

    {ai_cmd}
    EXIT_CODE=${{PIPESTATUS[0]}}
    # Kill orphaned MCP stdio servers (e.g. elevenlabs-mcp) left by claude
    pkill -f "elevenlabs-mcp" 2>/dev/null || true
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
    with open(tl, encoding="utf-8") as f:
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
                t['response'] = 'Completed by {ai_agent} (no details provided).'
        t['completed_by'] = '{ai_agent}'
        changed = True
if changed:
    shutil.copy2(tl, tl + '.bak')
    payload = json.dumps(data, indent=2, ensure_ascii=False)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(tl), suffix='.tmp')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(payload)
    os.replace(tmp, tl)
" 2>/dev/null || true

    # Handle errors
    if [ "$EXIT_CODE" -ne 0 ]; then
        if grep -qi "rate.limit\\|429\\|overloaded\\|usage.limit" "$LOG_FILE" 2>/dev/null; then
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

    echo ">>> Sleeping ${{INTERVAL}}s until next session... <<<"
    sleep $INTERVAL
done
'''
    return script


def _generate_one_shot_script(a, config: dict) -> str:
    """Generate a single-run script (no loop)."""
    ai_agent = config.get("ai_agent", "claude")
    timeout = config.get("max_session_minutes", 18) * 60
    prompt = config.get("prompt", "")
    project_path_unix = to_unix_path(a.project_path)
    log_dir = f"{project_path_unix}/auto_build_logs"
    claude_bin = _get_tool_paths()["claude_bin"]
    gemini_bin = _get_tool_paths()["gemini_bin"]
    codex_bin = _get_tool_paths()["codex_bin"]

    gdd_path = os.path.join(a.project_path, "gdd.md")
    gdd_section = ""
    if os.path.isfile(gdd_path):
        gdd_section = "\nIMPORTANT: Read gdd.md in the project root for design guidance.\n"

    status_contract = f"""
CRITICAL — MANDATORY TASK STATUS CONTRACT (APPLIES TO EVERY TASK YOU PICK):
You MUST follow these steps IN ORDER for EVERY task. Skipping any step is a failure.
1. FIRST ACTION for each task: Open tasklist.json, find the task, set "status" to "in_progress", SAVE THE FILE. Do this BEFORE reading any source code or making any changes.
2. Work on exactly ONE task at a time. Do not start another task until the current one is marked completed or failed.
3. When task is DONE: set "status" to "completed", set "completed_by" to "{ai_agent}", write a concrete summary in "response". SAVE immediately.
4. When task CANNOT be finished: set "status" to "failed", set "completed_by" to "{ai_agent}", explain the blocker in "response". SAVE immediately.
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
"""

    # --- Weighted random session focus (roll 1-100) ---
    focus_roll_b = random.randint(1, 100)
    if focus_roll_b <= 35:
        session_focus_b = "VISUAL / ASSET AUDIT"
        _sk = _load_studio_knowledge("visual_audit")
        session_focus_details_b = f"Focus new tasks on: asset-vs-code cross-reference, are all sprites loaded and displaying? UI viewport fit? Text overflow? Think like a player, not a code reviewer.\n{_sk}"
    elif focus_roll_b <= 65:
        session_focus_b = "GAMEPLAY / UX"
        _sk = _load_studio_knowledge("gameplay_ux")
        session_focus_details_b = f"Focus new tasks on: do mechanics work? Touch targets >= 48px? Button feedback? Game flow? Edge cases (0 resources, max level, empty states)?\n{_sk}"
    elif focus_roll_b <= 85:
        session_focus_b = "CODE QUALITY"
        _sk = _load_studio_knowledge("code_quality")
        session_focus_details_b = f"Focus new tasks on: null guards, signal cleanup, memory leaks, error handling. Max 3 code quality tasks.\n{_sk}"
    else:
        session_focus_b = "POLISH / NEW IDEAS"
        _sk = _load_studio_knowledge("polish_ideas")
        session_focus_details_b = f"Focus new tasks on: QoL improvements, missing juice/feedback, performance, fun features.\n{_sk}"

    if not prompt:
        prompt = f"""You are autonomously working on {a.name} ({a.app_type} project).
Project path: {a.project_path}
{gdd_section}
Read tasklist.json, fix pending tasks. Work in this order: urgent first, then oldest (lowest ID) first. Crashes and build failures ALWAYS come first.
Before starting each task, set its "status" to "in_progress" in tasklist.json immediately.
After completing each task, set "status" to "completed", write what you did in "response", and set "completed_by" to "{ai_agent}".
If you cannot complete a task you started, set "status" to "failed", set "completed_by" to "{ai_agent}", and explain why in "response".
ONLY generate new tasks if fewer than 5 pending tasks remain. If generating: 3-5 new tasks. SESSION FOCUS: {session_focus_b}. {session_focus_details_b}
Never generate more than 1 code-quality task (null checks, signal cleanup) per session. ALWAYS prioritize existing tasks over creating new ones."""
    automation_instructions = _load_automation_instructions()
    prompt = f"""{prompt}

{status_contract}
{automation_instructions}
"""

    mcp_config_path = _resolve_mcp_config(a, config, project_path_unix)
    ai_cmd = _build_ai_command(ai_agent, timeout, claude_bin, gemini_bin, codex_bin, project_path_unix, a, mcp_config_path)

    return f'''#!/bin/bash
# One-shot run for {a.name} ({ai_agent})
set +e
PROJECT_DIR="{project_path_unix}"
LOG_DIR="{log_dir}"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/oneshot_${{TIMESTAMP}}.log"
PROMPT_FILE=$(mktemp /tmp/{a.slug}_prompt_XXXXXX.txt 2>/dev/null) || PROMPT_FILE="$LOG_DIR/.prompt_tmp.txt"
cd "$PROJECT_DIR"
cat > "$PROMPT_FILE" << 'ENDPROMPT'
{prompt}
ENDPROMPT
echo "[$(date '+%Y-%m-%d %H:%M:%S')] One-shot run started ({ai_agent})" >> "$LOG_DIR/completions.log"
{ai_cmd}
EXIT_CODE=${{PIPESTATUS[0]}}
# Kill orphaned MCP stdio servers (e.g. elevenlabs-mcp) left by claude
pkill -f "elevenlabs-mcp" 2>/dev/null || true
rm -f "$PROMPT_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] One-shot run completed (exit: $EXIT_CODE)" >> "$LOG_DIR/completions.log"

# Fallback: reset any tasks stuck in "in_progress" after AI exit (atomic write)
python3 -c "
import json, os, sys, tempfile, shutil
tl = os.path.join('$PROJECT_DIR', 'tasklist.json')
if not os.path.isfile(tl):
    sys.exit(0)
try:
    with open(tl, encoding="utf-8") as f:
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
                t['response'] = 'Completed by {ai_agent} (no details provided).'
        t['completed_by'] = '{ai_agent}'
        changed = True
if changed:
    shutil.copy2(tl, tl + '.bak')
    payload = json.dumps(data, indent=2, ensure_ascii=False)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(tl), suffix='.tmp')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(payload)
    os.replace(tmp, tl)
" 2>/dev/null || true
'''


def _generate_task_script(a, config: dict, task: dict) -> str:
    """Generate a script to work on a specific task."""
    ai_agent = config.get("ai_agent", "claude")
    timeout = config.get("max_session_minutes", 18) * 60
    project_path_unix = to_unix_path(a.project_path)
    log_dir = f"{project_path_unix}/auto_build_logs"
    claude_bin = _get_tool_paths()["claude_bin"]
    gemini_bin = _get_tool_paths()["gemini_bin"]
    codex_bin = _get_tool_paths()["codex_bin"]
    task_id = task.get("id", 0)
    task_title = task.get("title", "").replace("'", "'\\''")
    task_desc = task.get("description", "").replace("'", "'\\''")
    task_type = task.get("type", "issue")
    is_idea_generation_task = (
        "idea" in f"{task.get('title', '')} {task.get('description', '')}".lower()
        and "generate" in f"{task.get('title', '')} {task.get('description', '')}".lower()
    )

    gdd_path = os.path.join(a.project_path, "gdd.md")
    gdd_section = ""
    if os.path.isfile(gdd_path):
        gdd_section = "\nIMPORTANT: Read gdd.md in the project root for design guidance.\n"

    idea_generation_rules = ""
    if is_idea_generation_task:
        brainstorm_knowledge = _load_studio_knowledge("brainstorm")
        idea_generation_rules = f"""
5. This task explicitly asks to generate ideas. You MUST append each generated idea as a NEW task entry in tasklist.json:
   - "type": "idea"
   - "status": "pending"
   - Include clear "title" and "description"
   - Assign incremental unique "id" values
   - Do not only write a summary in response; the ideas must exist as separate task objects.
6. Use this Game Studio brainstorming framework for higher quality ideas:
{brainstorm_knowledge}
7. Every idea must connect to the core loop or directly improve retention/engagement. No feature creep."""

    prompt = f"""You are working on {a.name} ({a.app_type} project).
Project path: {a.project_path}
{gdd_section}
YOU HAVE ONE SPECIFIC TASK TO DO:

Task #{task_id}: in progress
Type: {task_type}
Description: {task_desc}

INSTRUCTIONS:
1. Focus ONLY on this specific task. Do not work on other tasks.
2. Fix/implement what is described above.
3. If completed, update tasklist.json:
   - Find the task with id={task_id}
   - Set "status" to "completed"
   - Write what you did in the "response" field
   - Set "completed_by" to "{ai_agent}"
4. If you cannot complete this task, update tasklist.json:
   - Find the task with id={task_id}
   - Set "status" to "failed"
   - Write blocker/error details in the "response" field
   - Set "completed_by" to "{ai_agent}"
5. Do not leave this task in "in_progress" at the end of the run.
6. If this is a buildable project, verify the build still works.
7. If this task is too large to finish in one session: FIRST create the sub-tasks as new entries in tasklist.json with status "pending" and SAVE. THEN mark this task "divided" with response listing the sub-task IDs. Sub-tasks MUST exist before marking divided.{idea_generation_rules}"""
    automation_instructions = _load_automation_instructions()
    prompt = f"""{prompt}

{automation_instructions}
"""

    mcp_config_path = _resolve_mcp_config(a, config, project_path_unix)
    ai_cmd = _build_ai_command(ai_agent, timeout, claude_bin, gemini_bin, codex_bin, project_path_unix, a, mcp_config_path)

    return f'''#!/bin/bash
# Task-specific run for {a.name}: Task #{task_id} ({ai_agent})
set +e
PROJECT_DIR="{project_path_unix}"
LOG_DIR="{log_dir}"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$LOG_DIR/task_{task_id}_${{TIMESTAMP}}.log"
PROMPT_FILE=$(mktemp /tmp/{a.slug}_task_XXXXXX.txt 2>/dev/null) || PROMPT_FILE="$LOG_DIR/.prompt_tmp.txt"
cd "$PROJECT_DIR"
cat > "$PROMPT_FILE" << 'ENDPROMPT'
{prompt}
ENDPROMPT
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Task #{task_id} run started ({ai_agent}): {task_title}" >> "$LOG_DIR/completions.log"
{ai_cmd}
EXIT_CODE=${{PIPESTATUS[0]}}
# Kill orphaned MCP stdio servers (e.g. elevenlabs-mcp) left by claude
pkill -f "elevenlabs-mcp" 2>/dev/null || true
rm -f "$PROMPT_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Task #{task_id} run completed (exit: $EXIT_CODE)" >> "$LOG_DIR/completions.log"

# Fallback: if AI failed to update tasklist.json, mark task as failed (atomic write)
python3 -c "
import json, os, sys, tempfile, shutil
tl = os.path.join('$PROJECT_DIR', 'tasklist.json')
if not os.path.isfile(tl):
    sys.exit(0)
try:
    with open(tl, encoding="utf-8") as f:
        data = json.load(f)
except (json.JSONDecodeError, IOError):
    sys.exit(0)
tasks = data.get('tasks', data) if isinstance(data, dict) else data
changed = False
for t in (tasks if isinstance(tasks, list) else tasks.values()):
    if t.get('id') == {task_id} and t.get('status') == 'in_progress':
        if $EXIT_CODE != 0:
            t['status'] = 'failed'
            t['response'] = 'AI agent exited with error (exit code $EXIT_CODE). Check logs.'
        else:
            t['status'] = 'completed'
            if not t.get('response'):
                t['response'] = 'Completed by {ai_agent} (no details provided).'
        t['completed_by'] = '{ai_agent}'
        changed = True
        break
if changed:
    shutil.copy2(tl, tl + '.bak')
    payload = json.dumps(data, indent=2, ensure_ascii=False)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(tl), suffix='.tmp')
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(payload)
    os.replace(tmp, tl)
" 2>/dev/null || true
'''


def _build_ai_command(ai_agent: str, timeout: int, claude_bin: str, gemini_bin: str, codex_bin: str, project_path_unix: str, a, mcp_config_path: str = "") -> str:
    """Build the AI command string for any agent."""
    mcp_flag = f'--mcp-config "{mcp_config_path}"' if mcp_config_path else ""
    aider_bin = _get_tool_paths()["aider_bin"]
    local_model = "ollama/qwen2.5-coder:7b"

    if ai_agent == "claude":
        return f'''timeout --kill-after=30 {timeout} "{claude_bin}" \\
        -p \\
        --dangerously-skip-permissions \\
        --verbose \\
        {mcp_flag} \\
        < "$PROMPT_FILE" \\
        2>&1 | tee "$LOG_FILE"'''
    elif ai_agent == "gemini":
        return f'''GEMINI_NO_EXTENSIONS=1 timeout {timeout} "{gemini_bin}" \\
        -p "$(cat $PROMPT_FILE)" \\
        --sandbox=off \\
        --yolo \\
        2>&1 | tee "$LOG_FILE"'''
    elif ai_agent == "codex":
        return f'''timeout {timeout} "{codex_bin}" \\
        exec \\
        -s danger-full-access \\
        -c approval_policy="never" \\
        --skip-git-repo-check \\
        -C "{project_path_unix}" \\
        "$(cat $PROMPT_FILE)" \\
        2>&1 | tee "$LOG_FILE"'''
    elif ai_agent == "local":
        ollama_url = get_settings().get("ollama_url", "http://localhost:11434")
        return f'''export OLLAMA_API_BASE="{ollama_url}" && \\
        timeout {timeout} "{aider_bin}" \\
        --model {local_model} \\
        --message "$(cat $PROMPT_FILE)" \\
        --yes-always \\
        --no-git \\
        --no-show-release-notes \\
        --no-show-model-warnings \\
        --no-pretty \\
        --no-fancy-input \\
        2>&1 | tee "$LOG_FILE"'''
    else:
        return f'echo "Unknown AI agent: {ai_agent}" | tee "$LOG_FILE"'


@app.get("/api/automations")
def list_automations():
    configs = _load_automation_configs()
    result = []
    for app_id_str, config in configs.items():
        app_id = int(app_id_str)
        a = db().get_app(app_id)
        running = app_id in _running_automations and _running_automations[app_id].poll() is None
        result.append({
            "app_id": app_id,
            "app_name": a.name if a else "Unknown",
            "app_type": a.app_type if a else "",
            "ai_agent": config.get("ai_agent", "claude"),
            "interval_minutes": config.get("interval_minutes", 10),
            "max_session_minutes": config.get("max_session_minutes", 18),
            "prompt_preview": config.get("prompt", "")[:100],
            "mcp_servers": config.get("mcp_servers", []),
            "running": running,
        })
    return result


@app.post("/api/automations")
def create_automation(body: AutomationCreate):
    a = db().get_app(body.app_id)
    if not a:
        raise HTTPException(404, "App not found")

    configs = _load_automation_configs()
    config = {
        "app_id": body.app_id,
        "ai_agent": body.ai_agent,
        "interval_minutes": body.interval_minutes,
        "prompt": body.prompt,
        "max_session_minutes": body.max_session_minutes,
        "mcp_servers": body.mcp_servers or [],
        "created_at": datetime.now().isoformat(),
    }
    configs[str(body.app_id)] = config
    _save_automation_configs(configs)

    # Generate the script
    script = _generate_auto_build_script(a, config)
    script_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_auto.sh")
    with open(script_path, "w", newline="\n", encoding="utf-8") as f:
        f.write(script)

    # Save script path to app
    db().update_app(body.app_id, automation_script_path=script_path)

    return {"ok": True, "script_path": script_path}


@app.patch("/api/automations/{app_id}")
def update_automation(app_id: int, body: AutomationUpdate):
    configs = _load_automation_configs()
    key = str(app_id)
    if key not in configs:
        raise HTTPException(404, "Automation not found")

    updates = {k: v for k, v in body.model_dump().items() if v is not None}
    configs[key].update(updates)
    _save_automation_configs(configs)

    # Regenerate script
    a = db().get_app(app_id)
    if a:
        script = _generate_auto_build_script(a, configs[key])
        script_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_auto.sh")
        with open(script_path, "w", newline="\n", encoding="utf-8") as f:
            f.write(script)

    return {"ok": True}


def _kill_script_processes(script_name: str):
    """Kill all processes whose command line contains the given script name."""
    if not script_name:
        return
    try:
        for proc in psutil.process_iter(["pid", "cmdline"]):
            try:
                cmdline = " ".join(proc.info.get("cmdline") or [])
                if script_name in cmdline and proc.pid != os.getpid():
                    children = proc.children(recursive=True)
                    for child in reversed(children):
                        try:
                            child.kill()
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                    proc.kill()
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    except Exception:
        pass


@app.post("/api/automations/{app_id}/start")
def start_automation(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    configs = _load_automation_configs()
    key = str(app_id)
    if key not in configs:
        raise HTTPException(404, "No automation configured. Create one first.")

    script_name = f"{a.slug}_auto.sh"
    script_path = os.path.join(AUTOMATIONS_DIR, script_name)
    if not os.path.isfile(script_path):
        raise HTTPException(404, "Script not found. Recreate automation.")

    with _proc_lock:
        # Kill any existing instances of this script first (prevents duplication)
        _kill_script_processes(script_name)

        # Also kill tracked process if it exists
        if app_id in _running_automations:
            _stop_tracked_proc(_running_automations[app_id])
            del _running_automations[app_id]

        # Kill any tracked one-shot for this app too
        if app_id in _running_oneshots:
            _stop_tracked_proc(_running_oneshots[app_id])
            del _running_oneshots[app_id]

        # Launch via Git Bash
        bash_exe = _get_tool_paths()["bash_exe"]
        script_unix = to_unix_path(script_path)
        proc = subprocess.Popen(
            [bash_exe, "-l", "-c", f"cd {shlex.quote(to_unix_path(a.project_path))} && {shlex.quote(script_unix)}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=_automation_subprocess_env(),
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
        )
        _running_automations[app_id] = proc  # Track immediately under lock

    return {"ok": True, "pid": proc.pid}


@app.post("/api/automations/{app_id}/stop")
def stop_automation(app_id: int):
    a = db().get_app(app_id)
    script_name = f"{a.slug}_auto.sh" if a else None

    with _proc_lock:
        # Kill tracked automation process (entire tree)
        if app_id in _running_automations:
            _stop_tracked_proc(_running_automations.pop(app_id))

        # Kill tracked one-shot process
        if app_id in _running_oneshots:
            _stop_tracked_proc(_running_oneshots.pop(app_id))

        # Kill any running task processes for this app (entire tree)
        for key in [k for k in _running_task_processes if k[0] == app_id]:
            proc, _ = _running_task_processes.pop(key, (None, None))
            _stop_tracked_proc(proc)

    # Also kill any orphaned instances by script name (outside lock - may be slow)
    if script_name:
        _kill_script_processes(script_name)
        # Also kill one-shot script orphans
        _kill_script_processes(script_name.replace("_auto.sh", "_oneshot.sh"))
        # Kill task script orphans
        _kill_script_processes(f"{a.slug}_task_" if a else "")

    # Kill any processes referencing this app's project path (catches claude, godot, timeout children)
    if a and a.project_path:
        _kill_script_processes(a.project_path.replace("\\", "/"))
        _kill_script_processes(a.project_path.replace("/", "\\"))

    return {"ok": True}


@app.delete("/api/automations/{app_id}")
def delete_automation(app_id: int):
    # Stop if running
    stop_automation(app_id)

    configs = _load_automation_configs()
    key = str(app_id)
    if key in configs:
        del configs[key]
        _save_automation_configs(configs)

    # Remove script
    a = db().get_app(app_id)
    if a:
        script_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_auto.sh")
        if os.path.isfile(script_path):
            os.remove(script_path)

    return {"ok": True}


@app.post("/api/automations/{app_id}/run-once")
def run_once_automation(app_id: int):
    """Run a single automation session (non-recurring)."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    configs = _load_automation_configs()
    key = str(app_id)
    if key not in configs:
        raise HTTPException(404, "No automation configured. Create one first.")

    script_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_auto.sh")
    if not os.path.isfile(script_path):
        raise HTTPException(404, "Script not found. Recreate automation.")

    # Generate a one-shot script (same prompt but no loop)
    config = configs[key]
    one_shot = _generate_one_shot_script(a, config)
    one_shot_path = os.path.join(AUTOMATIONS_DIR, f"{a.slug}_oneshot.sh")
    with open(one_shot_path, "w", newline="\n", encoding="utf-8") as f:
        f.write(one_shot)

    bash_exe = _get_tool_paths()["bash_exe"]
    script_unix = to_unix_path(one_shot_path)

    with _proc_lock:
        # Kill existing one-shot if still running
        if app_id in _running_oneshots:
            _stop_tracked_proc(_running_oneshots.pop(app_id))

        proc = subprocess.Popen(
            [bash_exe, "-l", "-c", f"cd {shlex.quote(to_unix_path(a.project_path))} && {shlex.quote(script_unix)}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=_automation_subprocess_env(),
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
        )
        _running_oneshots[app_id] = proc  # Track immediately

    # Cleanup thread: remove from tracking when process finishes naturally
    def _oneshot_cleanup(aid, p):
        try:
            p.wait()
        except Exception:
            pass
        with _proc_lock:
            if _running_oneshots.get(aid) is p:
                del _running_oneshots[aid]
    threading.Thread(target=_oneshot_cleanup, args=(app_id, proc), daemon=True).start()

    return {"ok": True, "pid": proc.pid, "message": f"One-time run started for {a.name}"}


@app.post("/api/apps/{app_id}/tasks/{task_id}/run")
def run_specific_task(app_id: int, task_id: int):
    """Run AI on a specific task from tasklist.json."""
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    # Get automation config or use defaults
    configs = _load_automation_configs()
    key = str(app_id)
    config = dict(configs.get(key, {
        "app_id": app_id,
        "ai_agent": a.fix_strategy or "claude",
        "interval_minutes": 10,
        "max_session_minutes": 60,
        "prompt": "",
        "mcp_servers": [],
    }))
    # Use per-app MCP servers
    app_mcp = _get_app_mcp_servers(app_id)
    if app_mcp:
        config["mcp_servers"] = app_mcp

    lock = _get_tasklist_lock(_tasklist_path(a))
    with lock:
        tasks = _load_tasklist(a)
        task = next((t for t in tasks if t.get("id") == task_id), None)
        if not task:
            raise HTTPException(404, f"Task {task_id} not found")
        # Set task status to in_progress immediately so mobile UI reflects it
        task["status"] = "in_progress"
        _save_tasklist(a, tasks)

    one_shot = _generate_task_script(a, config, task)
    script_name = f"{a.slug}_task_{task_id}.sh"
    one_shot_path = os.path.join(AUTOMATIONS_DIR, script_name)
    with open(one_shot_path, "w", newline="\n", encoding="utf-8") as f:
        f.write(one_shot)

    bash_exe = _get_tool_paths()["bash_exe"]
    script_unix = to_unix_path(one_shot_path)

    with _proc_lock:
        # Kill existing task process for this task if still running
        task_key = (app_id, task_id)
        if task_key in _running_task_processes:
            old_proc, _ = _running_task_processes.pop(task_key)
            _stop_tracked_proc(old_proc)

        proc = subprocess.Popen(
            [bash_exe, "-l", "-c", f"cd {shlex.quote(to_unix_path(a.project_path))} && {shlex.quote(script_unix)}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=_automation_subprocess_env(),
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
        )

        # Track immediately under lock
        timeout_secs = config.get("max_session_minutes", 18) * 60
        deadline = time.time() + timeout_secs + 120  # 2 min grace beyond timeout
        _running_task_processes[task_key] = (proc, deadline)

    # Spawn watchdog thread to kill if it exceeds deadline
    # Capture script_name by value to avoid closure bug
    def _watchdog(key, p, dl, sname):
        try:
            remaining = dl - time.time()
            if remaining > 0:
                p.wait(timeout=remaining)
            if p.poll() is None:
                _kill_process_tree(p)
                _kill_script_processes(sname)
        except Exception:
            pass
        finally:
            with _proc_lock:
                if _running_task_processes.get(key, (None,))[0] is p:
                    _running_task_processes.pop(key, None)
    threading.Thread(target=_watchdog, args=(task_key, proc, deadline, script_name), daemon=True).start()

    return {"ok": True, "pid": proc.pid, "task_id": task_id, "message": f"Running task: {task.get('title', '')}"}


@app.get("/api/automations/{app_id}/status")
def automation_status(app_id: int):
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    with _proc_lock:
        running = app_id in _running_automations and _running_automations[app_id].poll() is None
        pid = _running_automations[app_id].pid if running else None

        # Check for running task processes
        running_tasks = []
        for key, (proc, deadline) in list(_running_task_processes.items()):
            if key[0] == app_id and proc.poll() is None:
                running_tasks.append({"task_id": key[1], "pid": proc.pid})

        # Check for running one-shot
        oneshot_running = app_id in _running_oneshots and _running_oneshots[app_id].poll() is None

    # Read completion log (outside lock - file I/O)
    log_dir = os.path.join(a.project_path, "auto_build_logs")
    log_lines = []
    comp_log = os.path.join(log_dir, "completions.log")
    if os.path.isfile(comp_log):
        try:
            with open(comp_log, "r", encoding="utf-8") as f:
                log_lines = [l.strip() for l in f.readlines()[-20:]]
        except Exception:
            pass

    return {
        "app_id": app_id,
        "running": running or oneshot_running,
        "pid": pid,
        "running_tasks": running_tasks,
        "log": log_lines,
    }


# ── Server Reset ──────────────────────────────────────────────

@app.post("/api/reset")
def reset_server():
    """Stop all automations and restart the server process."""
    stopped = []
    for app_id in list(_running_automations.keys()):
        try:
            stop_automation(app_id)
            stopped.append(app_id)
        except Exception:
            pass

    with _proc_lock:
        # Kill all running task processes (tree kill)
        for key in list(_running_task_processes.keys()):
            proc, _ = _running_task_processes.pop(key, (None, None))
            _stop_tracked_proc(proc)

        # Kill all running one-shot processes (tree kill)
        for app_id in list(_running_oneshots.keys()):
            _stop_tracked_proc(_running_oneshots.pop(app_id))

        # Kill all running chat processes (tree kill)
        for tid in list(_running_chat_procs.keys()):
            _stop_tracked_proc(_running_chat_procs.pop(tid))

    # Schedule server exit after response is sent (bat loop will restart it)
    def _shutdown():
        time.sleep(1)
        os.kill(os.getpid(), signal.SIGTERM)
    threading.Thread(target=_shutdown, daemon=True).start()

    return {
        "ok": True,
        "message": f"Server restarting. Stopped {len(stopped)} automation(s).",
        "stopped_automations": stopped,
    }


# ── Agent Chat ────────────────────────────────────────────────

class ChatRequest(BaseModel):
    question: str
    agent: str = "claude"  # claude|gemini|codex|local
    app_id: Optional[int] = None
    context: Optional[str] = None  # app context from mobile client
    session_id: Optional[str] = None  # CLI session ID for --resume
    history: Optional[list] = None  # Compacted conversation context on session reset
    model: Optional[str] = None  # model override (e.g. "sonnet", "opus")
    timeout: Optional[int] = None  # timeout in seconds (default 120)


@app.post("/api/chat")
def agent_chat(body: ChatRequest):
    """Ask an AI agent a question, optionally scoped to an app."""
    context = ""
    project_path = None

    if body.app_id:
        a = db().get_app(body.app_id)
        if a:
            project_path = a.project_path
            context = f"You are answering questions about {a.name} ({a.app_type} project at {a.project_path}).\n"
            gdd_path = os.path.join(a.project_path, "gdd.md")
            if os.path.isfile(gdd_path):
                try:
                    with open(gdd_path, "r", encoding="utf-8") as f:
                        gdd = f.read().strip()
                    if gdd:
                        context += f"\nProject design document:\n{gdd}\n"
                except Exception:
                    pass

            # Auto-route specialist knowledge based on question keywords
            question_lower = body.question.lower()
            specialist_keys = []
            if any(w in question_lower for w in ["visual", "art", "sprite", "ui", "layout", "asset", "icon", "animation"]):
                specialist_keys.append("visual_audit")
            if any(w in question_lower for w in ["gameplay", "mechanic", "ux", "flow", "player", "loop", "design", "feature"]):
                specialist_keys.append("gameplay_ux")
            if any(w in question_lower for w in ["code", "bug", "crash", "performance", "refactor", "architecture", "memory"]):
                specialist_keys.append("code_quality")
            if any(w in question_lower for w in ["polish", "juice", "sound", "audio", "economy", "balance", "reward", "monetiz"]):
                specialist_keys.append("polish_ideas")
            if any(w in question_lower for w in ["idea", "brainstorm", "concept", "new game", "new app"]):
                specialist_keys.append("brainstorm")
            if any(w in question_lower for w in ["gdd", "design doc", "document"]):
                specialist_keys.append("gdd_template")

            if specialist_keys:
                specialist_ctx = "\n".join(_load_studio_knowledge(k) for k in specialist_keys[:2])  # max 2 to save context
                context += f"\n## Specialist Knowledge (Game Studio):\n{specialist_ctx}\n"

    # Append client-provided context if available
    if body.context:
        context += f"\n{body.context}\n"

    agent = body.agent.lower()
    claude_bin = _get_tool_paths()["claude_bin"]
    gemini_bin = _get_tool_paths()["gemini_bin"]
    codex_bin = _get_tool_paths()["codex_bin"]
    bash_exe = _get_tool_paths()["bash_exe"]
    timeout = body.timeout if hasattr(body, 'timeout') and body.timeout else 120

    clean_env = {
        k: v
        for k, v in os.environ.items()
        if k != "CLAUDECODE" and not k.startswith("CODEX_")
    }

    if body.session_id:
        # Resuming existing session — just send the question
        prompt_text = body.question
    else:
        # New session — include context and compacted history if available
        history_block = ""
        if body.history:
            lines = [f"{'User' if m.get('role')=='user' else 'Assistant'}: {m.get('content','')}"
                     for m in body.history]
            history_block = f"\nRecent conversation context:\n" + "\n".join(lines) + "\n"
        prompt_text = f"{context}{history_block}\nUser question: {body.question}\n\nAnswer concisely and helpfully. Do NOT make code changes unless explicitly asked."

    proc = None
    track_id = threading.current_thread().ident  # unique per request thread

    try:
        if agent == "claude":
            cmd_parts = [f'"{claude_bin}" -p --output-format json']
            if body.model:
                cmd_parts.append(f'--model {body.model}')
            if body.session_id:
                cmd_parts.append(f'--resume "{body.session_id}"')
            if project_path:
                pp_unix = to_unix_path(project_path)
                cmd_parts.append(f'--add-dir "{pp_unix}"')
            full_cmd = " ".join(cmd_parts)
            proc = subprocess.Popen(
                [bash_exe, "-l", "-c", full_cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=clean_env,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            with _proc_lock:
                _running_chat_procs[track_id] = proc
            stdout, _ = proc.communicate(input=prompt_text.encode("utf-8"), timeout=timeout)

        elif agent == "gemini":
            cmd_parts = [f'"{gemini_bin}" -p --output-format json']
            if body.session_id:
                cmd_parts.append(f'--resume "{body.session_id}"')
            if project_path:
                pp_unix = to_unix_path(project_path)
                cmd_parts.append(f'--include-directories "{pp_unix}"')
            full_cmd = " ".join(cmd_parts)
            proc = subprocess.Popen(
                [bash_exe, "-l", "-c", full_cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=clean_env,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            with _proc_lock:
                _running_chat_procs[track_id] = proc
            stdout, _ = proc.communicate(input=prompt_text.encode("utf-8"), timeout=timeout)

        elif agent == "codex":
            cmd_parts = [f'"{codex_bin}" exec -s danger-full-access -c approval_policy="never" --skip-git-repo-check']
            if project_path:
                pp_unix = to_unix_path(project_path)
                cmd_parts.append(f'-C "{pp_unix}"')
            cmd_parts.append(f'"{prompt_text.replace(chr(34), chr(92)+chr(34))}"')
            full_cmd = " ".join(cmd_parts)
            proc = subprocess.Popen(
                [bash_exe, "-l", "-c", full_cmd],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                env=clean_env,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
            with _proc_lock:
                _running_chat_procs[track_id] = proc
            stdout, _ = proc.communicate(timeout=timeout)

        elif agent == "local":
            # Use Ollama HTTP API directly — no terminal escape codes
            import urllib.request
            local_model = "qwen2.5-coder:7b"
            payload = json.dumps({
                "model": local_model,
                "prompt": prompt_text,
                "stream": False,
            }).encode("utf-8")
            req = urllib.request.Request(
                get_settings().get("ollama_url", "http://localhost:11434") + "/api/generate",
                data=payload,
                headers={"Content-Type": "application/json"},
            )
            resp = urllib.request.urlopen(req, timeout=timeout)
            data = json.loads(resp.read().decode("utf-8"))
            response_text = data.get("response", "")
            return {"ok": True, "response": response_text, "agent": "local", "session_id": None}

        else:
            raise HTTPException(400, f"Unknown agent: {body.agent}")

        output = stdout.decode("utf-8", errors="replace").strip() if stdout else ""

        # Parse JSON output (Claude and Gemini with --output-format json)
        session_id = None
        response_text = output
        if agent in ("claude", "gemini"):
            try:
                data = json.loads(output)
                response_text = data.get("result", output)
                session_id = data.get("session_id")
            except (json.JSONDecodeError, ValueError):
                pass

        if not response_text:
            response_text = "(No response from agent)"

        return {"ok": True, "response": response_text, "agent": agent, "session_id": session_id}

    except subprocess.TimeoutExpired:
        if proc:
            _kill_process_tree(proc)
        raise HTTPException(504, f"Agent {agent} timed out after {timeout}s")
    except FileNotFoundError:
        raise HTTPException(500, f"Agent CLI not found for '{agent}'")
    except Exception as e:
        if proc and proc.poll() is None:
            _kill_process_tree(proc)
        raise HTTPException(500, f"Chat error: {str(e)}")
    finally:
        # Always remove from tracking
        with _proc_lock:
            _running_chat_procs.pop(track_id, None)


# ── MCP Server Config ────────────────────────────────────────

MCP_CONFIG_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config")
MCP_SERVERS_FILE = os.path.join(MCP_CONFIG_DIR, "mcp_servers.json")

# Pre-defined MCP server presets — users just toggle + add API key
# "cloud": True means available via Claude Max subscription without local config
MCP_PRESETS = {
    "pixellab": {
        "label": "PixelLab",
        "description": "AI pixel art generation (characters, animations, tilesets)",
        "config": {
            "type": "http",
            "url": "https://api.pixellab.ai/mcp",
        },
        "auth_type": "bearer",
        "key_hint": "API key from pixellab.ai dashboard",
        "cloud": False,
    },
    "elevenlabs": {
        "label": "ElevenLabs",
        "description": "AI voice, TTS, sound effects, music",
        "config": {
            "command": "uvx",
            "args": ["elevenlabs-mcp"],
        },
        "auth_type": "env",
        "key_env": "ELEVENLABS_API_KEY",
        "key_hint": "API key from elevenlabs.io",
        "cloud": False,
    },
    "godot": {
        "label": "Godot",
        "description": "Godot engine editor & project tools (cloud via Claude Max)",
        "config": {},
        "auth_type": "none",
        "cloud": True,
    },
    "cloudflare": {
        "label": "Cloudflare",
        "description": "Workers, KV, R2, D1 database (cloud via Claude Max)",
        "config": {},
        "auth_type": "none",
        "cloud": True,
    },
    "mobile": {
        "label": "Mobile Testing",
        "description": "Android emulator/device control (tap, swipe, screenshot, install APK)",
        "config": {
            "command": "npx",
            "args": ["-y", "@mobilenext/mobile-mcp"],
        },
        "auth_type": "none",
        "cloud": False,
    },
    "meshy": {
        "label": "Meshy AI",
        "description": "3D model generation (text-to-3D, image-to-3D, texturing, remeshing, rigging, animation)",
        "config": {
            "command": "npx",
            "args": ["-y", "meshy-ai-mcp-server"],
        },
        "auth_type": "env",
        "key_env": "MESHY_API_KEY",
        "key_hint": "API key from meshy.ai dashboard",
        "cloud": False,
    },
}


def _load_mcp_servers() -> dict:
    if os.path.isfile(MCP_SERVERS_FILE):
        with open(MCP_SERVERS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def _save_mcp_servers(servers: dict):
    os.makedirs(MCP_CONFIG_DIR, exist_ok=True)
    with open(MCP_SERVERS_FILE, "w", encoding="utf-8") as f:
        json.dump(servers, f, indent=2)


def _build_mcp_config_file(server_names: list) -> dict:
    """Build Claude CLI mcp_config.json content from selected server names."""
    servers = _load_mcp_servers()
    mcp_servers = {}
    for name in server_names:
        # Skip cloud-hosted servers — they work via Claude Max without local config
        preset = MCP_PRESETS.get(name, {})
        if preset.get("cloud", False):
            continue

        if name not in servers:
            continue
        cfg = dict(servers[name])
        api_key = cfg.pop("_api_key", "")
        cfg.pop("preset", None)

        # Skip servers with empty config (no command/url)
        if not cfg.get("command") and not cfg.get("url") and not cfg.get("type"):
            continue

        auth_type = preset.get("auth_type", "none")
        if api_key:
            if auth_type == "bearer":
                cfg["headers"] = {"Authorization": f"Bearer {api_key}"}
            elif auth_type == "env":
                key_env = preset.get("key_env", "API_KEY")
                cfg.setdefault("env", {})[key_env] = api_key

        mcp_servers[name] = cfg
    return {"mcpServers": mcp_servers}


@app.get("/api/mcp/servers")
def list_mcp_servers():
    servers = _load_mcp_servers()
    return [{"name": name, **{k: v for k, v in config.items() if not k.startswith("_")}} for name, config in servers.items()]


@app.get("/api/mcp/presets")
def list_mcp_presets():
    """Return all MCP presets with configured status."""
    servers = _load_mcp_servers()
    result = []
    for name, preset in MCP_PRESETS.items():
        configured = name in servers
        has_key = bool(servers.get(name, {}).get("_api_key"))
        result.append({
            "name": name,
            "label": preset["label"],
            "description": preset["description"],
            "auth_type": preset.get("auth_type", "none"),
            "key_hint": preset.get("key_hint", ""),
            "configured": configured,
            "has_key": has_key,
        })
    return result


@app.post("/api/mcp/presets/auto-setup")
def auto_setup_mcp_presets():
    """Auto-enable all presets, scanning existing configs for API keys."""
    servers = _load_mcp_servers()
    found_keys = {}

    # Scan existing mcp_config.json files for keys
    for a in db().get_all_apps():
        mcp_file = os.path.join(a.project_path, "mcp_config.json")
        if os.path.isfile(mcp_file):
            try:
                with open(mcp_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                for name, cfg in data.get("mcpServers", {}).items():
                    auth_header = cfg.get("headers", {}).get("Authorization", "")
                    if auth_header.startswith("Bearer "):
                        found_keys[name] = auth_header.replace("Bearer ", "")
                    for env_key, env_val in cfg.get("env", {}).items():
                        preset_match = next((n for n, p in MCP_PRESETS.items() if p.get("key_env") == env_key), None)
                        if preset_match:
                            found_keys[preset_match] = env_val
            except (json.JSONDecodeError, IOError):
                pass

    # Enable all presets, applying found keys
    for name, preset in MCP_PRESETS.items():
        config = dict(preset["config"])
        config["preset"] = True
        if name in found_keys:
            config["_api_key"] = found_keys[name]
        elif name in servers and servers[name].get("_api_key"):
            config["_api_key"] = servers[name]["_api_key"]
        servers[name] = config

    _save_mcp_servers(servers)
    return {"ok": True, "found_keys": list(found_keys.keys())}


class McpPresetEnable(BaseModel):
    api_key: Optional[str] = None


@app.post("/api/mcp/presets/{name}/enable")
def enable_mcp_preset(name: str, body: McpPresetEnable = None):
    """Enable a preset MCP server, optionally saving its API key."""
    if name not in MCP_PRESETS:
        raise HTTPException(404, f"Unknown preset: {name}")
    preset = MCP_PRESETS[name]
    servers = _load_mcp_servers()
    config = dict(preset["config"])
    config["preset"] = True
    api_key = (body.api_key if body else None) or ""
    if api_key:
        config["_api_key"] = api_key
    elif name in servers and servers[name].get("_api_key"):
        config["_api_key"] = servers[name]["_api_key"]
    servers[name] = config
    _save_mcp_servers(servers)
    return {"ok": True}


@app.delete("/api/mcp/presets/{name}")
def disable_mcp_preset(name: str):
    """Disable/remove a preset MCP server."""
    servers = _load_mcp_servers()
    if name in servers:
        del servers[name]
        _save_mcp_servers(servers)
    return {"ok": True}


class McpServerCreate(BaseModel):
    name: str
    command: Optional[str] = None
    args: Optional[list] = None
    env: Optional[dict] = None
    url: Optional[str] = None


@app.post("/api/mcp/servers")
def configure_mcp_server(body: McpServerCreate):
    servers = _load_mcp_servers()
    config = {}
    if body.command:
        config["command"] = body.command
    if body.args:
        config["args"] = body.args
    if body.env:
        config["env"] = body.env
    if body.url:
        config["url"] = body.url
    servers[body.name] = config
    _save_mcp_servers(servers)
    return {"ok": True}


@app.delete("/api/mcp/servers/{name}")
def delete_mcp_server(name: str):
    servers = _load_mcp_servers()
    if name not in servers:
        raise HTTPException(404, f"MCP server '{name}' not found")
    del servers[name]
    _save_mcp_servers(servers)
    return {"ok": True}


# ── Game Studio Endpoints ────────────────────────────────────
# All studio actions work through tasklist.json — they create enriched tasks
# that get executed by the automation loop or manual task runs.


def _studio_task_description(action: str, app_name: str, app_type: str) -> tuple[str, str]:
    """Build enriched task title + description with Game Studio specialist knowledge."""

    if action == "design-review":
        studio_knowledge = _load_studio_knowledge("gdd_template") + _load_studio_knowledge("gameplay_ux")
        title = f"Design Review: {app_name}"
        desc = f"""Perform a Game Studio design review of {app_name} ({app_type}).

ROLE: You are a Game Designer and Systems Designer.

INSTRUCTIONS:
1. Read gdd.md and evaluate it against the 8-section standard (Overview, Player Fantasy, Core Loop, Detailed Mechanics, Formulas & Data, Edge Cases, Dependencies, Monetization & Retention)
2. Check for: missing sections, vague mechanics, undefined formulas, unhandled edge cases
3. Verify economy values are data-driven (not hardcoded in scripts)
4. Check progression curve issues (too fast? too slow? dead zones?)
5. Evaluate core loop clarity — is the 30-second loop satisfying?
6. Check monetization design for ethics (no predatory patterns)

For EACH issue found, create a separate NEW task in tasklist.json with:
- type: "issue"
- Clear title starting with a verb (Fix, Add, Update, Remove)
- Specific description referencing files/sections to change

Write your overall review summary in this task's response field.
{studio_knowledge}"""
        return title, desc

    elif action == "code-review":
        studio_knowledge = _load_studio_knowledge("code_quality")
        title = f"Code Review: {app_name}"
        desc = f"""Perform a Game Studio code review of {app_name} ({app_type}).

ROLE: You are a Lead Programmer and QA Lead.

INSTRUCTIONS:
1. Read the main source files in the project
2. Check for: crash risks (null access, missing guards), memory leaks, circular dependencies
3. Verify architecture: single responsibility, proper data flow, no god scripts (>500 lines)
4. Check typing: are variables, arrays, and returns properly typed?
5. Check signal/event cleanup in destructors
6. Verify economy values come from data files, not hardcoded
7. Look for common anti-patterns: magic numbers, string-typing, copy-paste code

For EACH issue found, create a separate NEW task in tasklist.json with:
- type: "bug" for crash risks, "fix" for code quality issues
- Clear title starting with a verb (Fix, Add, Refactor, Extract)
- Specific description with file path and line number when possible

Write your overall review summary (Health Score X/10) in this task's response field.
{studio_knowledge}"""
        return title, desc

    elif action == "balance-check":
        studio_knowledge = _load_studio_knowledge("gameplay_ux") + _load_studio_knowledge("polish_ideas")
        title = f"Balance Check: {app_name}"
        desc = f"""Perform a Game Studio balance analysis of {app_name} ({app_type}).

ROLE: You are a Systems Designer and Economy Designer.

INSTRUCTIONS:
1. Find ALL data/config files with economy values (prices, rewards, XP curves, timers)
2. Check progression curves: is XP scaling reasonable? Are there dead zones?
3. Analyze resource sinks vs faucets: is currency inflating or deflating?
4. Check reward pacing: are rewards frequent enough for engagement?
5. Verify difficulty ramp: is it gradual or are there sudden spikes?
6. Check monetization balance: can free players progress reasonably?

For EACH balance issue found, create a separate NEW task in tasklist.json with:
- type: "fix"
- Clear title starting with a verb (Update, Rebalance, Add, Adjust)
- Specific description with the config file, current value, and recommended new value

Write your overall analysis (Economy Health X/10) in this task's response field.
{studio_knowledge}"""
        return title, desc

    else:
        return f"Studio: {action}", f"Run Game Studio {action} on {app_name}"


@app.post("/api/apps/{app_id}/studio/{action}")
def run_studio_action(app_id: int, action: str):
    """Create a Game Studio specialist task in the app's tasklist.json.
    Actions: design-review, code-review, balance-check
    The task gets executed when the automation runs or when manually triggered.
    """
    a = db().get_app(app_id)
    if not a:
        raise HTTPException(404, "App not found")

    valid_actions = ["design-review", "code-review", "balance-check"]
    if action not in valid_actions:
        raise HTTPException(400, f"Invalid action. Must be one of: {valid_actions}")

    title, description = _studio_task_description(action, a.name, a.app_type)

    # Create task via existing tasklist.json mechanism
    lock = _get_tasklist_lock(_tasklist_path(a))
    with lock:
        tasks = _load_tasklist(a)
        max_id = max((t.get("id", 0) for t in tasks), default=0)
        new_task = {
            "id": max_id + 1,
            "title": title,
            "description": description,
            "type": "issue",
            "priority": "high",
            "status": "pending",
            "source": "studio",
            "response": "",
            "created_at": datetime.now().isoformat(),
        }
        tasks.append(new_task)
        _save_tasklist(a, tasks)

    return {"ok": True, "task_id": new_task["id"], "action": action}


class BrainstormRequest(BaseModel):
    concept: str = ""  # optional seed concept
    genre: str = ""  # optional genre hint
    platform: str = "mobile"
    app_type: str = "godot"  # godot or flutter
    name: str = ""  # optional project name


@app.post("/api/studio/brainstorm")
def studio_brainstorm(body: BrainstormRequest):
    """Create a new app project with a brainstorm task that generates a full GDD.
    Creates the project folder, tasklist.json, CLAUDE.md, and DB entry, then adds
    a brainstorm task that the AI will execute to generate the complete GDD.
    """
    brainstorm_knowledge = _load_studio_knowledge("brainstorm")
    gdd_template = _load_studio_knowledge("gdd_template")

    concept_hint = ""
    if body.concept:
        concept_hint = f"Seed concept: {body.concept}\n"
    if body.genre:
        concept_hint += f"Target genre: {body.genre}\n"

    # If no name given, use concept or generate a placeholder
    project_name = body.name.strip() if body.name.strip() else (
        body.concept.strip().title()[:30] if body.concept.strip() else "New Game Concept"
    )

    # Create the project via existing create_new_app flow
    import re
    slug = re.sub(r'[^a-z0-9]+', '-', project_name.lower()).strip('-')
    existing = db().get_app_by_slug(slug)
    if existing:
        raise HTTPException(400, f"App '{project_name}' already exists (id={existing.id})")

    projects_root = get_settings().get("projects_root", os.path.join(str(Path.home()), "Projects"))
    project_path = f"{projects_root}/{project_name}"
    project_path_win = project_path.replace("/", "\\")
    os.makedirs(project_path_win, exist_ok=True)

    # Create tasklist.json with brainstorm task
    tasklist_path = os.path.join(project_path_win, "tasklist.json")
    brainstorm_desc = f"""Generate a complete Game Design Document (gdd.md) for {project_name}.

ROLE: You are a Creative Director and Game Designer at a game studio.

{concept_hint}Platform: {body.platform}
Engine: {body.app_type}

{brainstorm_knowledge}

STEP 1 — Generate GDD:
Write a complete gdd.md following this template:
{gdd_template}

STEP 2 — Generate Initial Tasks:
After saving gdd.md, create 8-10 micro-tasks in tasklist.json to scaffold the project:
- Task for project structure setup
- Task for main scene/screen creation
- Task for core mechanic implementation
- Task for UI layout
- Task for data config files (economy values)
- Task for basic audio (generate with ElevenLabs if available)
- Task for basic art assets (generate with PixelLab if available)
- Additional tasks based on the specific game concept

Each task must be micro-sized (completable in 30 min), with specific file paths.

Be creative but PRACTICAL. Everything must be buildable by AI automation.
Every asset must be AI-generated (PixelLab, ElevenLabs, Grok tools)."""

    with open(tasklist_path, "w", encoding="utf-8") as f:
        json.dump({"tasks": [{
            "id": 1,
            "title": f"Brainstorm and create GDD for {project_name}",
            "description": brainstorm_desc,
            "type": "feature",
            "priority": "urgent",
            "status": "pending",
            "source": "studio",
            "response": "",
            "created_at": datetime.now().isoformat(),
        }]}, f, indent=2)

    # Create CLAUDE.md (reuse the create_new_app template logic)
    claude_md_path = os.path.join(project_path_win, "CLAUDE.md")
    is_godot = body.app_type == "godot"
    is_flutter = body.app_type == "flutter"
    lines = [f"# {project_name}\n"]
    lines.append("## Conventions\n")
    lines.append("### Global Rules\n")
    lines.append("- Prices must ALWAYS be dynamically loaded. NEVER hardcode prices.\n")
    lines.append("- All apps are for mobile phones. Design, test, and optimize for mobile. Touch-friendly UI, responsive layouts, portrait mode unless specified otherwise.\n")
    lines.append("- Always account for Android system navigation bar. Use SafeArea/padding.bottom to prevent UI from being hidden behind the system nav bar.\n")
    _kd = get_settings().get("keys_dir", "")
    if _kd:
        lines.append(f"- All signing keys are in `{_kd}/` with master reference at `{_kd}/ALL_KEYS_MASTER.txt`.\n")
    lines.append("\n### NEVER Use Placeholders\n")
    lines.append("- NEVER use placeholder art, placeholder images, placeholder icons, colored rectangles, or TODO comments for visual assets\n")
    _td2 = get_settings().get("tools_dir", "")
    _tools_hint = f" or Python scripts in `{_td2}/pixellab/` (pixel art), `{_td2}/grok/` (Grok image/video), `{_td2}/meshy/` (3D), `{_td2}/tripo/` (3D)" if _td2 else ""
    lines.append(f"- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT using PixelLab MCP{_tools_hint}\n")
    lines.append("- If you cannot generate the asset, mark the task as \"failed\" — do NOT substitute a placeholder\n")
    lines.append("\n### Game Studio Design Standards\n")
    lines.append("- **Player Experience First**: Think like a player, not a developer. Every change should make the experience better.\n")
    lines.append("- **Feedback on Every Action**: Buttons need click sounds + scale tweens. Rewards need chimes + particles. Errors need visual indicators.\n")
    lines.append("- **Data-Driven Values**: Economy values (prices, rewards, XP, timers) MUST come from config/JSON files, never hardcoded in scripts.\n")
    lines.append("- **Empty States**: Never show a blank screen. Empty inventories say 'No items yet!', empty lists show helpful guidance.\n")
    lines.append("- **Single Responsibility**: One script = one system. Scripts over 500 lines should be split.\n")
    lines.append("- **GDD Compliance**: Always check gdd.md before implementing features. Follow the spec.\n")
    if is_flutter:
        lines.append("\n### Flutter\n")
        lines.append("- Flutter path: `{flutter_path}`\n")
        lines.append("- Always run `flutter analyze` after changes.\n")
    if is_godot:
        lines.append("\n### Godot\n")
        lines.append("- Godot path: `{godot_path}`\n")
        lines.append("- Never use `:=` inferred typing in GDScript lambdas (Godot 4.6.1 parser bug).\n")
        lines.append("- **PixelLab MCP available** — use for sprites, tilesets, animations.\n")
        lines.append("- **ElevenLabs MCP available** — use for sound effects and music.\n")
        lines.append("- **Meshy AI MCP available** — use for 3D model generation: `create_text_to_3d_task`, `create_image_to_3d_task`, `create_text_to_texture_task`, `create_remesh_task`, `create_rigging_task`, `create_animation_task`.\n")
    with open(claude_md_path, "w", encoding="utf-8") as f:
        f.writelines(lines)

    # Create initial gdd.md with available info so it exists from the start
    gdd_path = os.path.join(project_path_win, "gdd.md")
    gdd_lines = [f"# {project_name} — Game Design Document\n\n"]
    gdd_lines.append("## 1. Overview\n")
    overview_parts = [f"**{project_name}**"]
    if body.concept:
        overview_parts.append(f" — {body.concept.strip()}")
    overview_parts.append(f"\n\n- **Platform:** {body.platform}\n")
    overview_parts.append(f"- **Engine:** {body.app_type}\n")
    if body.genre:
        overview_parts.append(f"- **Genre:** {body.genre}\n")
    gdd_lines.extend(overview_parts)
    gdd_lines.append("\n## 2. Player Fantasy / User Value\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 3. Core Loop / Core Flow\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 4. Detailed Mechanics / Features\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 5. Formulas & Data\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 6. Edge Cases & Error Handling\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 7. Dependencies & Technical Notes\n*To be defined during brainstorm.*\n")
    gdd_lines.append("\n## 8. Monetization & Retention\n*To be defined during brainstorm.*\n")
    with open(gdd_path, "w", encoding="utf-8") as f:
        f.writelines(gdd_lines)

    # Create DB entry
    app_id = db().create_app(
        name=project_name,
        slug=slug,
        project_path=project_path,
        app_type=body.app_type,
        current_version="0.0.1",
        status="idle",
        publish_status="development",
        fix_strategy="auto",
    )

    return {
        "ok": True,
        "app_id": app_id,
        "slug": slug,
        "project_path": project_path_win,
        "message": f"Project '{project_name}' created with brainstorm task. Start automation or run the task to generate the GDD.",
    }


@app.get("/api/studio/knowledge")
def list_studio_knowledge():
    """List all available Game Studio specialist knowledge files."""
    studio_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "studio")
    files = []
    if os.path.isdir(studio_dir):
        for fname in sorted(os.listdir(studio_dir)):
            if fname.endswith(".md"):
                fpath = os.path.join(studio_dir, fname)
                name = fname.replace(".md", "").replace("_", " ").title()
                size = os.path.getsize(fpath)
                files.append({"filename": fname, "name": name, "key": fname.replace(".md", ""), "size": size})
    return {"files": files}


@app.get("/api/studio/knowledge/{key}")
def get_studio_knowledge(key: str):
    """Read a specific Game Studio knowledge file."""
    content = _load_studio_knowledge(key)
    if not content:
        raise HTTPException(404, f"Knowledge file '{key}' not found")
    return {"key": key, "content": content.strip()}


@app.put("/api/studio/knowledge/{key}")
def update_studio_knowledge(key: str, body: GddUpdate):
    """Update a Game Studio knowledge file."""
    studio_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "config", "studio")
    os.makedirs(studio_dir, exist_ok=True)
    filepath = os.path.join(studio_dir, f"{key}.md")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(body.content)
    return {"ok": True}


if __name__ == "__main__":
    import uvicorn
    _s = get_settings()
    uvicorn.run("server:app", host=_s.get("host", "0.0.0.0"), port=int(_s.get("port", 8000)), reload=True)
