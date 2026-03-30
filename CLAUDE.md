# Auto Game Builder - Claude Code Instructions

## Project Overview
- Open-source, self-hosted game project management platform
- Flutter mobile companion app (`app/`) + FastAPI Python backend (`server/`)
- The mobile app is a **remote control UI** — it does NOT contain business logic. All data lives on the server.

## Backend Server Reference

The server is a **FastAPI** app at `server/api/server.py` running on port `8000`.
Mobile connects via Cloudflare Worker proxy. The tunnel URL is stored in Cloudflare KV (configured in `server/config/settings.json` under `cloudflare`).

**IMPORTANT**: Before adding or modifying any API call in the mobile app, check `server/api/server.py` to confirm:
1. The endpoint actually exists
2. The request/response shape matches what the server expects
3. If the endpoint doesn't exist, you must implement it server-side first

### API Endpoints (server.py)

#### Health & Dashboard
- `GET /` -> `{"name","version","status"}`
- `GET /api/health` -> `{"status":"ok","time":ISO}`
- `GET /api/dashboard` -> full dashboard summary with all app stats

#### Apps (CRUD)
- `GET /api/apps` -> list apps, `?include_archived=bool`
- `GET /api/apps/{app_id}` -> app details with issue counts
- `POST /api/apps` -> create app `{name, app_type, fix_strategy}`
- `PATCH /api/apps/{app_id}` -> update `{notes, status, publish_status, fix_strategy, package_name, project_path, github_url, play_store_url, website_url, console_url}`

#### Issues
- `GET /api/issues` -> `?app_id=int&status=str`
- `GET /api/issues/{issue_id}`
- `POST /api/issues` -> `{app_id, title, description, category, priority, source, assigned_ai}`
- `PATCH /api/issues/{issue_id}` -> `{title, description, category, priority, status, assigned_ai, fix_prompt}`
- `DELETE /api/issues/{issue_id}`

#### Tasks (tasklist.json per app)
- `GET /api/apps/{app_id}/tasks` -> `?status=str`
- `GET /api/apps/{app_id}/tasks/status` -> task statistics
- `POST /api/apps/{app_id}/tasks` -> `{app_id, title, description, task_type, priority, attachments}` (attachments = base64 list, 120s timeout)
- `PATCH /api/apps/{app_id}/tasks/{task_id}` -> update any field
- `DELETE /api/apps/{app_id}/tasks/{task_id}`
- `POST /api/apps/{app_id}/tasks/archive` -> force-archive, keep last 100
- `POST /api/apps/{app_id}/tasks/{task_id}/run` -> run AI on task

#### Builds & Deploy
- `GET /api/builds` -> `?app_id=int&limit=20`
- `GET /api/builds/{build_id}`
- `GET /api/apps/{app_id}/build-targets` -> available build targets
- `POST /api/apps/{app_id}/deploy` -> `{track, build_target, upload}` tracks: internal/alpha/beta/production
- `POST /api/apps/{app_id}/deploy/cancel`
- `POST /api/apps/{app_id}/deploy/retry-upload` -> retry AAB upload without rebuild
- `GET /api/apps/{app_id}/deploy/status`

#### Automations
- `GET /api/sessions` -> `?app_id=int&status=str&limit=50`
- `POST /api/automations` -> `{app_id, ai_agent, interval_minutes, prompt, max_session_minutes, mcp_servers}`
- `GET /api/automations`
- `PATCH /api/automations/{app_id}` -> partial update
- `DELETE /api/automations/{app_id}`
- `POST /api/automations/{app_id}/start`
- `POST /api/automations/{app_id}/stop`
- `POST /api/automations/{app_id}/run-once`
- `GET /api/automations/{app_id}/status`

#### MCP Configuration
- `GET /api/apps/{app_id}/mcp` -> MCP servers for app
- `PUT /api/apps/{app_id}/mcp` -> `{mcp_servers: [names]}`
- `GET /api/mcp/servers` -> all configured servers
- `POST /api/mcp/servers` -> add server
- `DELETE /api/mcp/servers/{name}`
- `GET /api/mcp/presets`
- `POST /api/mcp/presets/auto-setup`
- `POST /api/mcp/presets/{name}/enable` -> `{api_key}` optional
- `DELETE /api/mcp/presets/{name}`

#### AI Chat
- `POST /api/chat` -> `{question, agent, app_id, context, session_id, history, model}`
- Returns `{"response", "session_id"}`
- Agents: `claude`, `gemini`, `codex`, `local`

#### GDD & CLAUDE.md
- `GET /api/apps/{app_id}/gdd` -> game/app design document
- `PUT /api/apps/{app_id}/gdd` -> `{content}`
- `GET /api/apps/{app_id}/claude-md` -> `{"content":"..."}`
- `PUT /api/apps/{app_id}/claude-md` -> `{"content":"..."}` -> `{"status":"ok"}`

#### Ideas
- `GET /api/ideas` -> `?app_id=int`
- `DELETE /api/ideas/{idea_id}`

#### Logs
- `GET /api/logs` -> `?app_id=int&limit=50`
- `GET /api/apps/{app_id}/logs`

#### Asset Pipeline
- `GET /api/pipeline/scan`
- `POST /api/pipeline/sessions` -> `{source_folder, rating}`
- `GET /api/pipeline/sessions`
- `GET /api/pipeline/assets` -> `?session_id,status,rating,collection,offset,limit`
- `GET /api/pipeline/assets/{id}`, `/thumbnail`, `/image`
- `POST /api/pipeline/match`, `/tag`, `/accept`, `/reject`, `/generate-music`, `/push`
- `GET /api/pipeline/collections`, `POST /api/pipeline/collections`
- `GET /api/pipeline/ops/{op_id}`, `POST /api/pipeline/ops/{op_id}/cancel`
- `POST /api/pipeline/grok/run`, `/seed`
- `GET /api/pipeline/grok/status`, `/catalog`, `/catalog/collections`
- `POST /api/pipeline/catalog/import`

#### Server Control
- `POST /api/reset` -> stop all automations and restart

### Status Values
- Tasks: `pending`, `in_progress`, `completed`, `built`, `failed`
- Apps: `idle`, `building`, `fixing`
- Builds: `running`, `failed`, `success`
- Deploy tracks: `internal`, `alpha`, `beta`, `production`

### Key Files
- Server: `server/api/server.py`
- Server config: `server/config/settings.json` (gitignored, user-specific)
- MCP config: `server/config/mcp_servers.json` (gitignored, contains API keys)
- Settings loader: `server/config/settings_loader.py` (auto-detects tools)
- Mobile API service: `app/lib/services/api_service.dart`
- Mobile config: `app/lib/config.dart`

## Important: Paths Are Configurable

All tool paths and directories are configured in `server/config/settings.json`. **Never hardcode paths.** Read them from settings:

```python
from config.settings_loader import get_settings
s = get_settings()
flutter = s.get("flutter_path", "flutter")
godot = s.get("godot_path", "godot")
projects = s.get("projects_root", "~/Projects")
keys = s.get("keys_dir", "")
tools = s.get("tools_dir", "")
```

The settings_loader auto-detects tools on PATH if not explicitly configured.

## Conventions

### Global Rules
- Prices must ALWAYS be dynamically loaded — NEVER hardcode prices
- All apps managed by this system are for mobile phones. Design, test, and optimize for mobile. Touch-friendly UI, responsive layouts, portrait mode unless specified otherwise.
- If a store/IAP system exists, prices must come from the platform (Google Play Billing, App Store, etc.)
- If price not yet loaded, show a loading indicator — NOT a dollar amount
- All apps/games must have a bottom navigation bar for screen navigation. Never rely on only back buttons or header menus.
- Always account for Android system navigation bar (bottom bar/gesture area). Use SafeArea, padding.bottom, or MediaQuery.of(context).padding.bottom to prevent UI elements from being hidden behind the system nav bar.

### NEVER Use Placeholders
- NEVER use placeholder art, placeholder images, placeholder icons, colored rectangles, or TODO comments for visual assets
- If a task needs an image, icon, sprite, background, or any visual asset — GENERATE IT using PixelLab MCP tools if available, or Python scripts in the configured `tools_dir`
- If you cannot generate the asset (no credits, rate limited, tool error), mark the task as "failed" — do NOT substitute a placeholder
- NEVER use animation fallbacks (static sprites, single-frame "animations", or skipping animations). If generation fails, mark the task as "failed".

### Flutter Conventions
- Flutter path is configured in `server/config/settings.json` under `engines.flutter_path`
- The Flutter app lives in `app/` (monorepo layout — pubspec.yaml is in `app/`, not the repo root)
- Always run `flutter analyze` after changes
- Use test ads during development, production ads only in release
- Signing keys directory is configured in settings.json under `paths.keys_dir`

### File Encoding
- **Always use `encoding="utf-8"`** when opening files for read or write in Python. Windows defaults to locale encoding (e.g. cp1254 for Turkish) which silently corrupts non-ASCII characters.

### Testing
- When a test task is assigned, build debug APK, install on emulator via mobile MCP, and test all screens and core gameplay.
- For each problem found, create a separate new task in tasklist.json with a clear description.
- If everything works fine, report "All tests passed" with no new tasks created.
- IGNORE on emulator: dynamic price loading, Google Play Billing, Google sign-in, cloud save, IAP functionality. These only work on real devices.

## CRITICAL: No Fallback Policy
- NEVER use fallback/placeholder logic as an excuse to skip work
- If an asset is missing, GENERATE it — do not show a colored rectangle, default icon, or "fallback sprite"
- If a feature is partially implemented, COMPLETE it — do not mark it done with a TODO comment
- "Fallback exists" does NOT mean the task is complete
- If you cannot generate an asset (no API credits, tool error), mark the task as FAILED with the reason
- Try-catch that swallows errors silently = HIDING PROBLEMS
