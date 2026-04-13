```markdown
# Auto Game Builder — Claude Code Instructions

> **Platform summary**: Open-source, self-hosted game project management platform.
> FastAPI backend orchestrates AI agents, builds, and deployments. Flutter mobile app
> is a remote-control UI only — no business logic lives in the app.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Backend Server Reference](#2-backend-server-reference)
3. [API Endpoints](#3-api-endpoints)
4. [Status Values & Enums](#4-status-values--enums)
5. [Key Files](#5-key-files)
6. [Configuration & Paths](#6-configuration--paths)
7. [Game Studio Standards](#7-game-studio-standards)
8. [Flutter Conventions](#8-flutter-conventions)
9. [Python / Backend Conventions](#9-python--backend-conventions)
10. [Asset Pipeline Rules](#10-asset-pipeline-rules)
11. [Testing Protocol](#11-testing-protocol)
12. [Task Completion Checklist](#12-task-completion-checklist)
13. [Security Rules](#13-security-rules)
14. [Error Handling Policy](#14-error-handling-policy)
15. [Critical: No Fallback Policy](#15-critical-no-fallback-policy)

---

## 1. Architecture Overview

```
Mobile App (Flutter)
    └── Remote-control UI only. No business logic. No local data store.
          │
          ▼  HTTPS via Cloudflare Worker proxy
Backend Server (FastAPI, port 8000)
    ├── server/api/server.py         — all API routes
    ├── server/config/settings.json  — user-specific config (gitignored)
    ├── server/config/mcp_servers.json — MCP + API keys (gitignored)
    └── Tunnel URL → Cloudflare KV
```

**Data flow rule**: Data flows DOWN (server → app). Events flow UP (app → server via HTTP).
No circular dependencies. The app never holds authoritative state — always re-fetch from server.

**Before touching any mobile API call**:
1. Open `server/api/server.py` and confirm the endpoint exists.
2. Confirm the request/response shape matches exactly.
3. If the endpoint is missing, implement it server-side first, then wire the mobile side.

---

## 2. Backend Server Reference

- **Runtime**: FastAPI (Python), port `8000`
- **Proxy**: Cloudflare Worker — tunnel URL stored in Cloudflare KV
- **Config key**: `server/config/settings.json` → `cloudflare`
- **Restart**: `POST /api/reset` — stops all automations and restarts cleanly

---

## 3. API Endpoints

### Health & Dashboard
| Method | Path | Body / Params | Response |
|--------|------|---------------|----------|
| GET | `/` | — | `{name, version, status}` |
| GET | `/api/health` | — | `{status:"ok", time:ISO}` |
| GET | `/api/dashboard` | — | Full stats for all apps |
| GET | `/api/sync` | `?since=ISO_TIMESTAMP` | `{apps, issues, builds, sessions, deleted, server_time}` — omit `since` for full initial sync |

### Apps (CRUD)
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/apps` | `?include_archived=bool` |
| GET | `/api/apps/{app_id}` | — |
| POST | `/api/apps` | `{name, app_type, fix_strategy}` |
| PATCH | `/api/apps/{app_id}` | `{notes, status, publish_status, fix_strategy, package_name, project_path, github_url, play_store_url, website_url, console_url}` |

### Issues
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/issues` | `?app_id=int&status=str` |
| GET | `/api/issues/{issue_id}` | — |
| POST | `/api/issues` | `{app_id, title, description, category, priority, source, assigned_ai}` |
| PATCH | `/api/issues/{issue_id}` | `{title, description, category, priority, status, assigned_ai, fix_prompt}` |
| DELETE | `/api/issues/{issue_id}` | — |

### Tasks (tasklist.json per app)
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/apps/{app_id}/tasks` | `?status=str` |
| GET | `/api/apps/{app_id}/tasks/status` | — (task statistics) |
| POST | `/api/apps/{app_id}/tasks` | `{app_id, title, description, task_type, priority, attachments}` — attachments = base64 list; 120 s timeout |
| PATCH | `/api/apps/{app_id}/tasks/{task_id}` | any field |
| DELETE | `/api/apps/{app_id}/tasks/{task_id}` | — |
| POST | `/api/apps/{app_id}/tasks/archive` | — (force-archive, keeps last 100) |
| POST | `/api/apps/{app_id}/tasks/{task_id}/run` | — (run AI on task) |

### Builds & Deploy
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/builds` | `?app_id=int&limit=20` |
| GET | `/api/builds/{build_id}` | — |
| GET | `/api/apps/{app_id}/build-targets` | — |
| POST | `/api/apps/{app_id}/deploy` | `{track, build_target, upload}` |
| POST | `/api/apps/{app_id}/deploy/cancel` | — |
| POST | `/api/apps/{app_id}/deploy/retry-upload` | — (retry AAB upload, no rebuild) |
| GET | `/api/apps/{app_id}/deploy/status` | — |

### Automations
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/sessions` | `?app_id=int&status=str&limit=50` |
| POST | `/api/automations` | `{app_id, ai_agent, interval_minutes, prompt, max_session_minutes, mcp_servers}` |
| GET | `/api/automations` | — |
| PATCH | `/api/automations/{app_id}` | partial update |
| DELETE | `/api/automations/{app_id}` | — |
| POST | `/api/automations/{app_id}/start` | — |
| POST | `/api/automations/{app_id}/stop` | — |
| POST | `/api/automations/{app_id}/run-once` | — |
| GET | `/api/automations/{app_id}/status` | — |

### MCP Configuration
| Method | Path | Body / Params |
|--------|------|---------------|
| GET | `/api/apps/{app_id}/mcp` | — |
| PUT | `/api/apps/{app_id}/mcp` | `{mcp_servers: [names]}` |
| GET | `/api/mcp/servers` | — |
| POST | `/api/mcp/servers` | add server |
| DELETE | `/api/mcp/servers/{name}` | — |
| GET | `/api/mcp/presets` | — |
| POST | `/api/mcp/presets/auto-setup` | — |
| POST | `/api/mcp/presets/{name}/enable` | `{api_key}` (optional) |
| DELETE | `/api/mcp/presets/{name}` | — |

### AI Chat
| Method | Path | Body | Response |
|--------|------|------|----------|
| POST | `/api/chat` | `{question, agent, app_id, context, session_id, history, model}` | `{response, session_id}` |

Available agents: `claude`, `gemini`, `codex`, `local`

### GDD & CLAUDE.md
| Method | Path | Body |
|--------|------|------|
| GET | `/api/apps/{app_id}/gdd` | — |
| PUT | `/api/apps/{app_id}/gdd` | `{content}` |
| GET | `/api/apps/{app_id}/claude-md` | — → `{content:"..."}` |
| PUT | `/api/apps/{app_id}/claude-md` | `{content:"..."}` → `{status:"ok"}` |

### Ideas
| Method | Path | Params |
|--------|------|--------|
| GET | `/api/ideas` | `?app_id=int` |
| DELETE | `/api/ideas/{idea_id}` | — |

### Logs
| Method | Path | Params |
|--------|------|--------|
| GET | `/api/logs` | `?app_id=int&limit=50` |
| GET | `/api/apps/{app_id}/logs` | — |

### Asset Pipeline
```
GET  /api/pipeline/scan
POST /api/pipeline/sessions              {source_folder, rating}
GET  /api/pipeline/sessions
GET  /api/pipeline/assets                ?session_id,status,rating,collection,offset,limit
GET  /api/pipeline/assets/{id}
GET  /api/pipeline/assets/{id}/thumbnail
GET  /api/pipeline/assets/{id}/image
POST /api/pipeline/match
POST /api/pipeline/tag
POST /api/pipeline/accept
POST /api/pipeline/reject
POST /api/pipeline/generate-music
POST /api/pipeline/push
GET  /api/pipeline/collections
POST /api/pipeline/collections
GET  /api/pipeline/ops/{op_id}
POST /api/pipeline/ops/{op_id}/cancel
POST /api/pipeline/grok/run
POST /api/pipeline/grok/seed
GET  /api/pipeline/grok/status
GET  /api/pipeline/grok/catalog
GET  /api/pipeline/grok/catalog/collections
POST /api/pipeline/catalog/import
```

### Server Control
| Method | Path | Effect |
|--------|------|--------|
| POST | `/api/reset` | Stop all automations and restart server |

---

## 4. Status Values & Enums

| Domain | Values |
|--------|--------|
| Tasks | `pending` · `in_progress` · `completed` · `built` · `failed` |
| Apps | `idle` · `building` · `fixing` |
| Builds | `running` · `failed` · `success` |
| Deploy tracks | `internal` · `alpha` · `beta` · `production` |

---

## 5. Key Files

| File | Purpose |
|------|---------|
| `server/api/server.py` | All FastAPI routes — source of truth for the API |
| `server/config/settings.json` | User-specific runtime config (gitignored) |
| `server/config/mcp_servers.json` | MCP server configs + API keys (gitignored) |
| `server/config/settings_loader.py` | Loads settings; auto-detects tools on PATH |
| `app/lib/services/api_service.dart` | All HTTP calls from the mobile app |
| `app/lib/config.dart` | Mobile app configuration constants |
| `app/pubspec.yaml` | Flutter dependencies (NOT at repo root) |

---

## 6. Configuration & Paths

All tool paths and directories come from `server/config/settings.json`. **Never hardcode paths.**

```python
from config.settings_loader import get_settings

s = get_settings()
flutter  = s.get("flutter_path", "flutter")
godot    = s.get("godot_path",   "godot")
projects = s.get("projects_root", "~/Projects")
keys     = s.get("keys_dir", "")
tools    = s.get("tools_dir", "")
```

`settings_loader` will auto-detect tools on `PATH` if not explicitly configured.
Never use `os.path.expanduser("~/…")` directly for project paths — always go through settings.

### settings.json Structure Reference

```json
{
  "cloudflare":  { ... },
  "engines":     { "flutter_path": "...", "godot_path": "..." },
  "paths":       { "keys_dir": "...", "tools_dir": "...", "projects_root": "..." }
}
```

---

## 7. Game Studio Standards

These rules apply to every game and app built or managed by this system.

### 7.1 Player Experience First

Think like a player, not a developer.

- Every UI decision must answer: *"Does this feel good to play?"*
- Latency, responsiveness, and visual clarity take priority over code elegance.
- If a feature works technically but feels bad, it is not done.
- Frame rate stability > visual fidelity when there is a conflict.
- Default to portrait mode. Landscape requires explicit justification.

### 7.2 Feedback on Every Action

Every meaningful player action must produce **all three**:

1. **Visual feedback** — animation, color change, particle, shake, flash, etc.
2. **Audio feedback** — sound effect matched to the action's weight.
3. **State change** — the game world must visibly reflect the result.

Silent, invisible actions are bugs. "It works in code" is not enough.

### 7.3 Data-Driven Values

Economy, balance, and tuning values must come from config files — never from code literals.

- XP amounts, costs, cooldowns, damage values, spawn rates → config file.
- In Flutter, load from server or local JSON; never `const int goldReward = 50;`.
- In Godot/game engine scripts, load from a `GameConfig` resource or exported variable.
- Config files live in the app's project directory; path resolved via `settings.json`.
- If a config value is missing, **fail loudly** — do not silently substitute a magic number.

### 7.4 Single Responsibility

One script / widget / module = one system.

- A `PlayerController` handles movement. It does not also manage inventory or UI.
- A Flutter widget renders UI. It does not contain API calls or game logic.
- If a file needs to import more than ~3 unrelated systems, split it.
- Utility files are acceptable only when shared by 3+ callers.

### 7.5 Architecture: Data Down, Events Up

- **Data flows down**: parent passes data to children via constructors / props.
- **Events flow up**: children notify parents via callbacks / event buses — never direct parent references.
- **No circular dependencies**: A → B → A is always a design error; restructure.
- In Flutter: use `Provider` / `Riverpod` / `BLoC` for cross-widget state. Do not pass deeply nested callbacks.
- In Godot: signals flow up; exported variables / `autoload` singletons flow down.

### 7.6 Asset Quality — No Placeholders

- **NEVER** use placeholder art, colored rectangles, missing-texture defaults, or TODO image slots.
- If a visual asset is needed → generate it with PixelLab MCP or a Python script under the appropriate vendor subfolder in `tools/` (`tools/pixellab/`, `tools/grok/`, `tools/meshy/`, `tools/tripo/`). See `tools/CLAUDE.md` for the full per-tool reference.
- If generation fails (no credits, API error) → mark the task **failed** with the reason. Do not ship a placeholder.
- Animations must be real multi-frame animations. Static-sprite "animation" = task failed.
- Audio assets must be real sound files. Silence is not a sound effect.

---

## 8. Flutter Conventions

### Project Layout
- `pubspec.yaml` is in `app/`, not the repo root. Always `cd app/` before Flutter commands.
- Flutter binary path: `settings.json` → `engines.flutter_path` (fallback: `flutter` on PATH).

### After Every Code Change
```bash
flutter analyze          # must produce zero errors
flutter test             # run if tests exist for the changed area
```
Never submit a task as complete if `flutter analyze` has errors.

### Mobile UI Rules
- **Touch targets**: minimum 48 × 48 dp for all interactive elements.
- **Bottom navigation**: every app/game must have a `BottomNavigationBar` (or `NavigationBar`). Never rely solely on back buttons or drawer menus.
- **System navigation bar**: always wrap root scaffold with `SafeArea`, or apply `MediaQuery.of(context).padding.bottom` to avoid content hidden under the Android gesture bar.
- **Responsive layouts**: use `LayoutBuilder` / `MediaQuery` for breakpoints. Test at 360 dp width minimum.
- **Portrait-first**: default orientation is portrait. Landscape must be explicitly requested.

### Pricing & IAP
- Prices ALWAYS come from the platform at runtime (Google Play Billing / App Store).
- If price is not yet loaded, show a `CircularProgressIndicator` — **never** a hardcoded string like `"$0.99"`.
- Test ads (`ca-app-pub-3940256099942544/…`) during development; production ad unit IDs only in release builds.

### State Management
- Use the state management solution already present in the project (check `pubspec.yaml`).
- Do not introduce a second state management library.
- Ephemeral widget state → `setState`. Cross-widget / persistent state → existing solution.

### Signing
- Signing key directory: `settings.json` → `paths.keys_dir`.
- Never commit keystore files or `key.properties` to git.

---

## 9. Python / Backend Conventions

### File Encoding
Always specify `encoding="utf-8"` when opening files. Windows defaults to the locale encoding (e.g., `cp1254` for Turkish) which silently corrupts non-ASCII characters.

```python
# Correct
with open(path, "r", encoding="utf-8") as f:
    data = f.read()

# Wrong — omitting encoding
with open(path, "r") as f:
    data = f.read()
```

### Settings Access
Never import `settings.json` directly. Always use:

```python
from config.settings_loader import get_settings
s = get_settings()
```

### Adding New Endpoints
1. Define the Pydantic request/response models first.
2. Add the route to `server/api/server.py`.
3. Keep business logic in helper functions/modules — routes stay thin.
4. Return consistent error shapes: `{"detail": "human-readable message"}` with appropriate HTTP status codes.
5. Update `CLAUDE.md` Section 3 with the new endpoint.

### Logging
- Use Python's `logging` module — never raw `print()` for server-side diagnostics.
- Log level conventions: `DEBUG` = developer detail, `INFO` = normal operations, `WARNING` = degraded but continuing, `ERROR` = operation failed, `CRITICAL` = server cannot continue.
- Include `app_id` and `task_id` in log messages where applicable for traceability.

### Long-running Operations
- Any operation expected to exceed 30 s must be async and return an operation ID.
- The client polls `GET /api/pipeline/ops/{op_id}` for status.
- Never block the FastAPI event loop with synchronous subprocess calls — use `asyncio.create_subprocess_exec`.

---

## 10. Asset Pipeline Rules

The asset pipeline (`/api/pipeline/…`) manages generated and imported game assets.

- **Scan before push**: always `GET /api/pipeline/scan` to verify source assets before starting a session.
- **Operation tracking**: long-running pipeline ops return an `op_id`. Poll `/api/pipeline/ops/{op_id}` until `status` is `completed` or `failed`.
- **Collections**: assets must be assigned to a collection before push. Uncollected assets are not shippable.
- **Music generation**: `POST /api/pipeline/generate-music` is async; treat it like any other long-running op.
- **Grok catalog**: import via `POST /api/pipeline/catalog/import` after confirming catalog state with `GET /api/pipeline/grok/catalog`.

---

## 11. Testing Protocol

### When a Test Task Is Assigned
1. Build the debug APK: `flutter build apk --debug`
2. Install on the emulator via mobile MCP.
3. Test **all screens** and **core gameplay loops** manually.
4. For each problem found: create a **separate new task** in `tasklist.json` with a clear title and reproduction steps.
5. If everything passes: report **"All tests passed"** — do not create tasks.

### Emulator Exclusions (real device only)
Do not test or report failures for these on an emulator:
- Dynamic price loading
- Google Play Billing / IAP
- Google Sign-In
- Cloud save / remote config
- Push notifications

### Analyze Before Submitting
```bash
flutter analyze    # zero errors required
```
A task is not complete if analysis fails.

---

## 12. Task Completion Checklist

Before marking any task `completed`, verify:

- [ ] Feature works end-to-end (server + mobile) as described.
- [ ] `flutter analyze` returns zero errors.
- [ ] No hardcoded prices, paths, or magic numbers introduced.
- [ ] All new visual elements have real assets — no placeholders.
- [ ] All player actions have visual + audio + state feedback.
- [ ] New API endpoints are documented in Section 3 of this file.
- [ ] New config values are loaded from `settings.json`, not hardcoded.
- [ ] File encoding is `utf-8` for all new Python file I/O.
- [ ] No `print()` statements left in server code.
- [ ] No `TODO` comments left in shipped code.

---

## 13. Security Rules

- **API keys** live in `server/config/mcp_servers.json` (gitignored). Never hardcode them.
- **Signing keystores** live in the directory specified by `paths.keys_dir`. Never commit them.
- **Never log secrets**: API keys, tokens, and passwords must not appear in log output.
- **Input validation**: all user-supplied values that reach the filesystem or a subprocess must be sanitized. No shell injection.
- **Cloudflare tunnel**: the tunnel URL is fetched from Cloudflare KV at runtime; never cache it to disk in a way that could be stale after a tunnel restart.
- **No `--no-verify`**: never skip git hooks. Fix the underlying issue instead.

---

## 14. Error Handling Policy

- **Fail loudly at boundaries**: validate at system edges (user input, external APIs, file I/O). Trust internal code contracts.
- **No silent swallowing**: a bare `except: pass` or `catch (_) {}` that hides an error is a bug, not error handling.
- **Propagate with context**: when re-raising, add context. `raise RuntimeError(f"Failed to load asset {path}") from e`
- **No fallback magic numbers**: if a config value is missing, raise — do not substitute a default that silently alters game balance.
- **Task failure is honest**: if a task cannot be completed correctly, set status to `failed` with a clear reason. A broken "completed" task is worse than an honest failure.

---

## 15. Critical: No Fallback Policy

These rules override any instinct toward "just get something on screen":

| Situation | Wrong | Right |
|-----------|-------|-------|
| Asset missing | Show colored rectangle | Generate it or mark task `failed` |
| Asset generation fails | Show default icon | Mark task `failed` with reason |
| Animation fails | Ship static sprite | Mark task `failed` |
| Feature half-done | Leave TODO comment | Complete it or mark task `failed` |
| Config value missing | Use magic number fallback | Raise and surface the error |
| Error caught silently | `except: pass` | Log + propagate or handle explicitly |

**"Fallback exists" is not a definition of done.**
**A try-catch that swallows exceptions is hiding a problem, not solving it.**
```