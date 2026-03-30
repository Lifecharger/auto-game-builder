# Auto Game Builder — System Design Document

## Overview

Auto Game Builder is a portable, open-source developer automation platform designed to manage the full lifecycle of multiple software applications from a single interface. It combines a FastAPI REST backend with a Flutter mobile app and exposes its API remotely via a Cloudflare Tunnel, enabling control from a mobile device anywhere.

The system targets solo or small-team developers who maintain several apps simultaneously (Flutter, Godot, Python, Web) and want to automate repetitive tasks — building, fixing bugs, deploying, and iterating — using AI agents.

---

## Architecture

```
Mobile App  ──►  Cloudflare Worker Proxy
                        │
                        ▼
              Cloudflare Tunnel
                        │
                        ▼
        ┌───────────────────────────────┐
        │    FastAPI REST API (Python)  │
        │    server/api/server.py       │
        │                               │
        │  ┌──────────────────────┐    │
        │  │  AutoFix Engine      │    │
        │  │  Deploy Engine       │    │
        │  │  Pipeline Engine     │    │
        │  │  Internet Monitor    │    │
        │  └──────────────────────┘    │
        │              │               │
        │    SQLite Database           │
        └───────────────────────────────┘
```

### Components

| Component | Description |
|---|---|
| `server/api/server.py` | FastAPI REST API. Core orchestration layer. |
| `server/core/autofix_engine.py` | Queues and processes issues automatically via AI agents. |
| `server/core/deploy_engine.py` | Builds and uploads artifacts to Google Play or other targets. |
| `server/core/pipeline_engine.py` | Asset pipeline for processing game/app resources. |
| `server/core/internet_monitor.py` | Polls connectivity; gates AI actions behind internet availability. |
| `server/database/db_manager.py` | SQLite abstraction layer. |
| `server/database/models.py` | ORM models: App, Build, Task, etc. |
| `server/automations/` | Per-app automation shell scripts and config (`configs.json`). |
| `server/config/` | MCP server definitions, per-app MCP assignments, settings. |
| `app/` | Flutter mobile companion app. |

---

## Supported App Types

| Type | Build Targets | Notes |
|---|---|---|
| `flutter` | APK, AAB, EXE, Web, iOS | Reads version from `pubspec.yaml`. |
| `godot` | APK, AAB, Windows, Web, Linux | Reads version from `export_presets.cfg`. |
| `python` | — | Managed for automation/task tracking. |
| `web` | Web | Static or server-rendered. |

---

## Core Features

### 1. App Management

- Create apps with auto-generated `slug`, project folder, initial `tasklist.json`, and a pre-populated `CLAUDE.md` with type-specific conventions.
- Track metadata: `status`, `publish_status`, `current_version`, `package_name`, `project_path`, `github_url`, `play_store_url`, `website_url`, `console_url`.
- App statuses: `idle`, `building`, `fixing`.
- Publish statuses: `development`, `internal`, `alpha`, `beta`, `production`.
- On server startup, any app stuck in `building` or `fixing` (from a crash) is automatically reset to `idle`.

### 2. Build & Deploy System

- Trigger builds per app with a chosen target (APK, AAB, EXE, etc.) and deploy track (`internal`, `alpha`, `beta`, `production`).
- Optionally upload the resulting AAB directly to Google Play after build.
- Cancel active builds, which kills the entire subprocess tree via `psutil`.
- Retry upload of the last built AAB without rebuilding.
- Build records are stored in the database with duration, output path, status, and timestamps.
- Stale `running` build records from previous crashes are automatically marked `failed` on startup.

### 3. Issue Tracker

- Create issues with: `title`, `description`, `category` (bug/feature/etc.), `priority` (1–5), `source`, and optional `assigned_ai`.
- Issues are automatically enqueued in the AutoFix Engine on creation.
- The AutoFix Engine processes the queue using the configured AI agent (Claude, Gemini, or Codex), applying an AI-generated fix and storing the result.

### 4. Task System (Per-App Tasklist)

- Each app has a `tasklist.json` file in its project folder.
- Tasks have types: `issue`, `idea`, `feature`, `fix`.
- Tasks have statuses: `pending`, `in_progress`, `partial`, `completed`, `built`, `divided`, `failed`, `archived`.
- Tasks support image attachments (base64-encoded, saved to `task_attachments/`).
- Completed tasks are auto-archived (kept to the last 100 done tasks; excess moved to `task_archives/`).
- File writes are atomic (temp file + `os.replace`) with `.bak` backup to prevent corruption.
- Per-file locks prevent concurrent read-modify-write race conditions.
- The Ideas feed is a filtered view of tasks with `type=idea` that have an AI response.

### 5. AI Automation Engine

- Each app can have an automation configuration: `ai_agent` (claude/gemini/codex), `interval_minutes`, `max_session_minutes`, `prompt`, and `mcp_servers`.
- A shell script (`{slug}_auto.sh`) is auto-generated from the config and lives in `server/automations/`.
- The script runs the chosen AI agent on the app's task list in a loop, with configurable session timeouts and intervals.
- Three process categories are tracked: recurring automation loops, one-shot runs, and per-task runs.
- Processes are tracked in-memory with full tree kill support on cancel.
- Session records (in the database) track: `ai_tool`, `status`, `exit_code`, `duration_seconds`, `files_changed`, and timestamps.

### 6. MCP Server Integration

- A registry of available MCP servers is maintained in `server/config/mcp_servers.json`.
- Each app can have a custom set of MCP servers assigned (`server/config/app_mcp.json`).
- When MCP servers are assigned, an `mcp_config.json` is generated in the app's project folder and passed to the AI agent.
- Resolution priority: per-app assignment → automation config → app's existing `mcp_config_path`.
- Known integrations: PixelLab (pixel art generation), ElevenLabs (audio/sound effects), mobile testing MCP.
- Auto-setup of MCP presets occurs on first server startup if the registry is empty.

### 7. Design Document Management

- Each app can have a `gdd.md` (Game/App Design Document) — editable via API and mobile app.
- Each app has a `CLAUDE.md` — the AI instruction file, pre-populated with type-specific rules and editable via API.
- An AI-powered "Enhance" feature runs Claude in the background to rewrite and improve either document, saving the result directly to disk.

### 8. Connectivity & Monitoring

- `InternetMonitor` periodically polls a configurable URL (default: `api.anthropic.com`) to verify connectivity.
- AI automation is gated behind internet availability.
- The check interval is configurable via settings (`internet_check_interval`).

### 9. Logging

- Per-app build logs are written to `auto_build_logs/completions.log` within each project folder.
- Logs are parsed into structured entries with `app_name`, `app_id`, `level` (info/success/warning/error), `source` (agent name), `message`, and `timestamp`.
- A unified `/api/logs` endpoint aggregates logs across all apps.

### 10. Dashboard

- A single `/api/dashboard` endpoint returns a summary of all apps: status, publish status, version, and open issue count.

---

## Data Models

| Model | Key Fields |
|---|---|
| `App` | `id`, `name`, `slug`, `app_type`, `status`, `publish_status`, `current_version`, `package_name`, `project_path`, `fix_strategy`, `mcp_config_path`, `automation_script_path`, `github_url`, `play_store_url`, `website_url`, `console_url`, `group_name`, `icon_path` |
| `Issue` | `id`, `app_id`, `title`, `description`, `category`, `priority`, `status`, `source`, `assigned_ai`, `fix_prompt`, `fix_result` |
| `Build` | `id`, `app_id`, `build_type`, `version`, `status`, `output_path`, `duration_seconds`, `started_at`, `completed_at` |
| `Session` | `id`, `app_id`, `issue_id`, `ai_tool`, `status`, `exit_code`, `duration_seconds`, `error_message`, `files_changed`, `started_at`, `completed_at` |
| `Settings` | Key-value store for global configuration (loaded from `server/config/settings.json`). |

---

## API Reference (Key Endpoints)

| Method | Path | Description |
|---|---|---|
| GET | `/api/apps` | List all apps |
| POST | `/api/apps` | Create app (generates folder, CLAUDE.md, tasklist.json, DB entry) |
| PATCH | `/api/apps/{id}` | Update app metadata |
| GET/PUT | `/api/apps/{id}/mcp` | Get/set per-app MCP servers |
| POST | `/api/apps/{id}/deploy` | Trigger build + optional Play Store upload |
| POST | `/api/apps/{id}/deploy/cancel` | Cancel active build |
| POST | `/api/apps/{id}/deploy/retry-upload` | Re-upload last AAB |
| GET | `/api/apps/{id}/tasks` | List per-app tasks |
| POST | `/api/apps/{id}/tasks` | Add task (with optional image attachments) |
| PATCH | `/api/apps/{id}/tasks/{task_id}` | Update task |
| DELETE | `/api/apps/{id}/tasks/{task_id}` | Delete task |
| GET/PUT | `/api/apps/{id}/gdd` | Read/write GDD document |
| GET/PUT | `/api/apps/{id}/claude-md` | Read/write CLAUDE.md |
| POST | `/api/apps/{id}/enhance` | AI-enhance GDD or CLAUDE.md (async) |
| GET | `/api/apps/{id}/enhance/status` | Poll enhance job status |
| GET/POST | `/api/issues` | List/create issues (auto-queues autofix) |
| GET | `/api/sessions` | List AI fix sessions |
| GET | `/api/builds` | List build records |
| GET | `/api/logs` | Unified log feed across all apps |
| GET | `/api/ideas` | All tasks of type `idea` with AI responses |
| GET | `/api/dashboard` | Global summary |
| GET | `/api/health` | Health check |

---

## Key Paths & Conventions

| Item | Location |
|---|---|
| Database | `server/app_manager.db` |
| Settings | `server/config/settings.json` |
| App projects | Configurable via `projects_root` in settings |
| Task list | `{project_path}/tasklist.json` |
| Design document | `{project_path}/gdd.md` |
| AI instructions | `{project_path}/CLAUDE.md` |
| Task archives | `{project_path}/task_archives/` |
| Task attachments | `{project_path}/task_attachments/{task_id}/` |
| Build artifacts | `{project_path}/build/` (engine-managed) |
| Build logs | `{project_path}/auto_build_logs/completions.log` |
| MCP config (per app) | `{project_path}/mcp_config.json` |
| Automation scripts | `server/automations/{slug}_auto.sh` |
| Automation configs | `server/automations/configs.json` |
| MCP server registry | `server/config/mcp_servers.json` |
| Per-app MCP assignments | `server/config/app_mcp.json` |
| Signing keys | Configurable via `keys_dir` in settings |

---

## External Integrations

| Integration | Purpose |
|---|---|
| Cloudflare Tunnel | Exposes local API to mobile app over HTTPS without port forwarding |
| Cloudflare Worker | Proxy layer that routes mobile requests to the tunnel |
| Google Play Console | Build upload and track management |
| Claude (Anthropic) | Primary AI agent for autofix, automation, and document enhancement |
| Gemini (Google) | Secondary AI agent option for automation |
| Codex (OpenAI) | Tertiary AI agent option for automation |
| PixelLab | Pixel art generation for games (MCP + Python SDK) |
| ElevenLabs | Sound effects and music generation (MCP) |
| GitHub | Source control link per app (URL stored, not managed directly) |
