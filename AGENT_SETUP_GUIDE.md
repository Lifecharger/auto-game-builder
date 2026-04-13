# Auto Game Builder — Agent Configuration Guide

This file is meant to be read by an AI agent (Claude, Gemini, Codex, etc.) to automatically configure Auto Game Builder on a user's machine.

## Project Structure

```
auto-game-builder/
  setup_wizard.py          # First-run setup (you're helping with this)
  server/
    main.py                # Server entry point (auto-generates security keys)
    api/server.py          # FastAPI REST API (apps, issues, tasks, builds, studio, chat)
    config/
      settings.json         # USER CONFIG — you create/edit this (gitignored)
      settings.example.json # Template with empty values
      settings_loader.py    # Loads settings.json, auto-detects tools
      mcp_servers.json      # MCP server configs — you create/edit this (gitignored)
      app_mcp.json          # Per-app MCP server assignments
      constants.py          # Tech stacks, build targets, statuses (don't edit)
      path_utils.py         # Cross-platform path utils
      automation_claude.md  # Automation prompt template
      studio/studio/        # Game Studio specialist knowledge base
        brainstorm.md         # Game concept generation framework
        gdd_template.md       # GDD structure template
        gameplay_ux.md        # Gameplay and UX review guidance
        code_quality.md       # Code audit criteria
        visual_audit.md       # Art/visual quality standards
        polish_ideas.md       # Polish and refinement checklist
        specialist_routing.md # AI specialist assignment logic
    core/                   # Engine modules
      ai_tools.py             # AI agent invokers (Claude, Gemini, Codex, Aider)
      autofix_engine.py       # Auto-fix issue queue + execution
      build_engine.py         # Build orchestration (Flutter, Godot, Phaser, React Native, Python)
      deploy_engine.py        # Deploy to Google Play (AAB upload, version bumping)
      app_detector.py         # Auto-detect project types from marker files
      local_agent.py          # Local AI (Aider + Ollama) process management
      internet_monitor.py     # Connection status tracking
      phaser_scaffold.py      # Phaser project scaffolding
      version_manager.py      # Semantic version bumping
      anr_parser.py           # Google Play ANR report parsing
      log_manager.py          # Log management + archiving
    database/               # SQLite DB (auto-created on first run, WAL mode)
      db_manager.py           # Thread-safe CRUD manager
      models.py               # Dataclass models (App, Issue, Build, etc.)
      migrations.py           # Schema migrations (auto-applied)
    prompts/                # Fix prompt templates per engine
      flutter_fix.txt
      godot_fix.txt
      anr_fix.txt
    automations/            # Generated automation scripts (auto-managed)
  app/                      # Flutter mobile app (don't touch during setup)
  worker/                   # Cloudflare Worker proxy
    index.js                  # Worker code (HMAC verification + API key validation)
    wrangler.toml             # Worker deployment config (gitignored)
    wrangler.toml.example     # Template
  tools/                    # Asset generation toolkit, organized by vendor
    pixellab/                 # PixelLab SDK wrappers (pixel art, backgrounds, UI)
    meshy/                    # Meshy AI 3D generation (text/image → 3D, rig, animate)
    tripo/                    # Tripo3D (official SDK + Studio JWT browser path)
    grok/                     # Grok Imagine image/video + downloader + cookies
    chrome/                   # Chrome DevTools Protocol launcher + network capture
    blender/                  # Blender auto-splitter + Mixamo bulk downloader
    media/                    # pad_image, video_to_frames, png_to_pixel_array
    extract/                  # Per-project asset extractors
    pixel_guy/                # Merged Pixel Guy character viewer (Flutter + Python)
    comic_translator/         # Merged Gemini comic translator
    animation_generator/      # Merged 2D Animation Generator UI (wraps grok/media/tripo)
    dart/                     # Flutter test-mode asset generators
    character_creator/        # Godot character creator WIP (gitignored)
    CLAUDE.md                 # Per-tool reference — read this to pick the right tool
    GROK_ASSET_PIPELINE.md    # Hand-written grok prompting/workflow playbook
    CHROME_CDP_HOWTO.md       # CDP launcher + capture how-to
```

API keys for all vendors live in the gitignored `server/config/mcp_servers.json` under `{vendor}._api_key`. ElevenLabs is accessed via MCP only — no standalone scripts.

## What You Need To Configure

### 1. settings.json (`server/config/settings.json`)

This is the main config file. Create it from `settings.example.json` or edit the existing one.

**Format:**
```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8000
  },
  "paths": {
    "projects_root": "~/Projects",
    "keys_dir": "",
    "tools_dir": "",
    "service_account_key": ""
  },
  "ai_agents": {
    "claude_path": "",
    "gemini_path": "",
    "codex_path": "",
    "aider_path": ""
  },
  "engines": {
    "godot_path": "",
    "flutter_path": ""
  },
  "system": {
    "bash_path": "",
    "cloudflared_path": "",
    "npx_path": "",
    "wrangler_path": ""
  },
  "cloudflare": {
    "tunnel_enabled": false,
    "kv_namespace_id": "",
    "account_id": "",
    "worker_url": ""
  },
  "services": {
    "ollama_url": "http://localhost:11434"
  },
  "developer": {
    "developer_name": ""
  },
  "security": {
    "api_key": "",
    "hmac_secret": ""
  }
}
```

> **Note:** Leave `security.api_key` and `security.hmac_secret` empty — they are auto-generated on first server start. See [3c. Security Setup](#3c-security-setup-api-key--hmac-signing) for post-setup steps.

**How to find each value:**

| Field | How to find | Example |
|-------|-------------|---------|
| `claude_path` | Run: `which claude` or `where claude` | `/usr/local/bin/claude` or `C:\Users\user\.claude\local\claude.exe` |
| `gemini_path` | Run: `which gemini` or `where gemini` | `/usr/local/bin/gemini` |
| `codex_path` | Run: `which codex` or `where codex` | `/usr/local/bin/codex` |
| `aider_path` | Run: `which aider` or `where aider` | `/home/user/.local/bin/aider` |
| `flutter_path` | Run: `which flutter` or `where flutter` | `/opt/flutter/bin/flutter` or `C:\flutter\bin\flutter` |
| `godot_path` | Run: `which godot` or `where godot`, or search for `Godot_v*` | `C:\Godot\Godot_v4.6.1-stable_win64_console.exe` |
| `bash_path` | Run: `which bash` or check `C:\Program Files\Git\bin\bash.exe` | `/bin/bash` |
| `cloudflared_path` | Run: `which cloudflared` or `where cloudflared` | `/usr/local/bin/cloudflared` |
| `npx_path` | Run: `which npx` or `where npx` | `/usr/local/bin/npx` |
| `wrangler_path` | Run: `which wrangler` or `where wrangler` | `/usr/local/bin/wrangler` |
| `projects_root` | Ask the user where they keep game projects | `~/Projects` or `C:\Projects` |
| `keys_dir` | Ask the user where signing keystores are stored | `D:\keys` or `~/keys` |
| `tools_dir` | Override path to asset generation scripts. Leave unset to use the repo's own `tools/` folder (recommended). | `~/Projects/auto-game-builder/tools` |
| `service_account_key` | Path to Google Play API service account JSON (optional) | `~/keys/play-api.json` |
| `ollama_url` | Default: `http://localhost:11434`. Only change if Ollama runs on a different host/port | `http://localhost:11434` |

**On Windows**, use forward slashes or escaped backslashes in JSON: `"C:/flutter/bin/flutter"` or `"C:\\flutter\\bin\\flutter"`.

**Search strategy for tools not on PATH:**
- Windows: Search `C:\`, `C:\Program Files\`, `%LOCALAPPDATA%\`, `%APPDATA%\`, `%USERPROFILE%\.local\bin\`
- macOS: Search `/usr/local/bin/`, `/opt/homebrew/bin/`, `~/.local/bin/`
- Linux: Search `/usr/local/bin/`, `/usr/bin/`, `~/.local/bin/`, `~/bin/`
- For Flutter specifically: search for `flutter` or `flutter.bat` in common locations
- For Godot specifically: search for `Godot_v*` or `godot` executables

### 2. mcp_servers.json (`server/config/mcp_servers.json`)

MCP (Model Context Protocol) servers extend AI agent capabilities. Configure what's available.

**Format:**
```json
{
  "pixellab": {
    "type": "http",
    "url": "https://api.pixellab.ai/mcp",
    "preset": true,
    "_api_key": "YOUR_PIXELLAB_KEY"
  },
  "elevenlabs": {
    "command": "uvx",
    "args": ["elevenlabs-mcp"],
    "preset": true,
    "_api_key": "YOUR_ELEVENLABS_KEY",
    "env": { "ELEVENLABS_API_KEY": "YOUR_ELEVENLABS_KEY" }
  },
  "mobile": {
    "command": "npx",
    "args": ["-y", "@mobilenext/mobile-mcp"],
    "preset": true
  },
  "godot": { "preset": true, "cloud": true },
  "cloudflare": { "preset": true, "cloud": true }
}
```

**Server types:**
- **HTTP**: Remote API (PixelLab). Needs `type`, `url`, and `_api_key`.
- **Command**: Local subprocess (ElevenLabs, Mobile). Needs `command` and `args`. May need `_api_key` and `env`.
- **Cloud**: Provided by Claude Max subscription (Godot, Cloudflare). No local config needed — just mark `cloud: true`.

**Available presets:**

| Server | Type | Requires | Purpose |
|--------|------|----------|---------|
| `pixellab` | HTTP | API key ([pixellab.ai/dashboard](https://pixellab.ai/dashboard)) | AI pixel art generation |
| `elevenlabs` | Command | API key ([elevenlabs.io](https://elevenlabs.io)), [uv](https://docs.astral.sh/uv/) | AI audio/music/SFX |
| `mobile` | Command | Node.js | Device testing and automation |
| `meshy` | Command | API key ([meshy.ai](https://www.meshy.ai/)) | 3D model generation |
| `godot` | Cloud | Claude Max subscription | Godot engine tools |
| `cloudflare` | Cloud | Claude Max subscription | Cloudflare management |

**Per-app MCP assignment:**
Each app can have its own set of MCP servers. This is stored in `app_mcp.json`:
```json
{
  "1": ["pixellab", "mobile"],
  "5": ["elevenlabs", "pixellab"]
}
```
The API manages this via `GET/PUT /api/apps/{app_id}/mcp`. When automation runs for an app, only its assigned MCP servers are included in the Claude session.

**Verifying command-based servers:**
- Mobile MCP: Run `npx -y @mobilenext/mobile-mcp --version` (needs Node.js)
- ElevenLabs: Run `uvx elevenlabs-mcp --help` (needs Python uv: https://docs.astral.sh/uv/)

### 3. Cloudflare Setup (for remote access)

If the user wants to access the server from their phone over the internet, they need Cloudflare Tunnel.

**Install cloudflared:**
- Windows: `winget install Cloudflare.cloudflared`
- macOS: `brew install cloudflared`
- Linux: See https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/

**Install and authenticate wrangler** (for KV — stores the tunnel URL so the phone can find the server):
```bash
npm install -g wrangler
wrangler login
```
`wrangler login` opens a browser for Cloudflare OAuth. After login, `wrangler whoami` shows the account.

**Get the account_id:**
```bash
wrangler whoami
```
Look for the Account ID in the output.

**Get or create a KV namespace:**
```bash
wrangler kv namespace list
```
If none exist, create one:
```bash
wrangler kv namespace create "auto_game_builder"
```
Use the returned namespace ID in settings.json under `cloudflare.kv_namespace_id`.

**Settings to fill:**
```json
"cloudflare": {
    "tunnel_enabled": true,
    "kv_namespace_id": "the-namespace-id",
    "account_id": "the-account-id"
}
```

If the user doesn't need remote access (only local network), set `tunnel_enabled` to `false` and leave the IDs empty.

### 3b. Deploy Cloudflare Worker (for phone access)

The worker gives the user a permanent URL that always proxies to their PC server, even when the tunnel URL changes on restart.

**Steps:**
1. Copy the worker config template:
   ```bash
   cd worker
   cp wrangler.toml.example wrangler.toml
   ```

2. Edit `wrangler.toml` — fill in `account_id` and the KV namespace `id` (same values from settings.json).

3. Deploy the worker:
   ```bash
   cd worker
   wrangler deploy
   ```

4. The output shows the worker URL (e.g., `https://auto-game-builder.USERNAME.workers.dev`).

5. Save this URL in settings.json under a new field:
   ```json
   "cloudflare": {
       "tunnel_enabled": true,
       "kv_namespace_id": "...",
       "account_id": "...",
       "worker_url": "https://auto-game-builder.USERNAME.workers.dev"
   }
   ```

6. The user enters this worker URL in the phone app. It never changes.

**How it works:**
- Server starts -> Cloudflare tunnel -> gets dynamic URL -> writes URL + HMAC signature to KV
- Phone connects to worker URL -> worker verifies API key + HMAC signature -> proxies to tunnel -> PC server validates API key again

### 3c. Security Setup (API key + HMAC signing)

The server auto-generates an API key and HMAC secret on first start. These are stored in `settings.json` under `security`:

```json
"security": {
    "api_key": "auto-generated-on-first-run",
    "hmac_secret": "auto-generated-on-first-run"
}
```

**After the first server start**, you must push these secrets to the Cloudflare Worker:

```bash
cd worker
# Read the values from server/config/settings.json -> security section
echo "THE_API_KEY" | npx wrangler secret put API_KEY
echo "THE_HMAC_SECRET" | npx wrangler secret put HMAC_SECRET
```

**How security works:**
- **API key**: Shared secret between phone and server. The phone sends it as `X-API-Key` header. Both the Worker and the server validate it independently. Transferred via QR code scan (never through the internet).
- **HMAC signature**: When the server writes the tunnel URL to KV, it also writes `HMAC-SHA256(hmac_secret, tunnel_url)` as `tunnel_sig`. The Worker verifies this signature before proxying. This prevents KV poisoning attacks where an attacker redirects traffic to a malicious server.
- **QR pairing**: The desktop app shows a QR code containing the API key + worker URL (base64-encoded JSON). The phone app scans it to configure itself. This avoids transmitting the key over the internet.

**Protected endpoints:**
- All `/api/*` routes require `X-API-Key` header (except `/api/health` and `/api/pair`)
- `/api/pair` returns the pairing QR data (accessible from localhost for desktop app)
- `/worker/health` is public but no longer leaks the raw tunnel URL

**If the user doesn't need remote access**, security is optional — set `tunnel_enabled: false` and leave security keys empty. The server allows all requests when no API key is configured (local-only mode).

### 4. Python Dependencies

Run from the repo root:
```bash
pip install -r server/requirements.txt
```

If this fails, read the error and fix it. Common issues:
- Missing C++ build tools on Windows: Install Visual Studio Build Tools
- Old pip: Run `python -m pip install --upgrade pip`

### 5. Developer Identity (for building from source)

If the user provided a `developer_name` in settings.json, update the Android package name so their builds use `com.DEVNAME.appname` instead of the default `com.lifecharger.appmanager`.

**How to change the Android package name:**
```bash
cd app
flutter pub add --dev change_app_package_name
flutter pub run change_app_package_name:main com.DEVNAME.autogamebuilder
```

Replace `DEVNAME` with the value from `settings.json` -> `developer_name` (under the `developer` section).

This updates:
- `android/app/build.gradle.kts` (namespace + applicationId)
- `AndroidManifest.xml` (package)
- Kotlin directory structure + package declaration

**Only do this for users building from source.** The Play Store version keeps `com.lifecharger.appmanager`.

### 6. Flutter SDK (for building the app from source)

The mobile/desktop app is built with Flutter. If Flutter is not installed:

**Windows:**
```bash
git clone https://github.com/flutter/flutter.git -b stable C:\flutter
set PATH=C:\flutter\bin;%PATH%
flutter doctor
```

**macOS:**
```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
flutter doctor
```

**Linux:**
```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
export PATH="$HOME/flutter/bin:$PATH"
flutter doctor
```

After installing, run `flutter doctor` to check for any missing dependencies (Android SDK, etc).

**Building the Windows desktop app:**
```bash
cd app
flutter pub get
flutter build windows --release
```
The exe will be at `app/build/windows/x64/runner/Release/` (named after the project).

**Building the Android APK:**
```bash
cd app
flutter pub get
flutter build apk --release
```
The APK will be at `app/build/app/outputs/flutter-apk/app-release.apk`

**Building the Android AAB (for Google Play):**
```bash
cd app
flutter pub get
flutter build appbundle --release
```
The AAB will be at `app/build/app/outputs/bundle/release/app-release.aab`

### 7. Local AI Setup (optional)

For offline or private AI work, Auto Game Builder supports local models via Aider + Ollama.

**Install Ollama:**
- Download from [ollama.com](https://ollama.com/)
- Pull the default model: `ollama pull qwen2.5-coder:7b`

**Install Aider:**
```bash
pip install aider-chat
```
Or: `pipx install aider-chat`

**Configuration:**
- Set `aider_path` in `settings.json` -> `ai_agents`
- The default `ollama_url` is `http://localhost:11434` (change in `services` if Ollama runs elsewhere)
- The default model is `ollama/qwen2.5-coder:7b` — the local agent module handles model selection

**How it works:**
- The local agent (`core/local_agent.py`) spawns Aider with the Ollama backend
- It auto-selects relevant files for context to stay within the model's context window
- Used when the user explicitly chooses local AI or when internet is unavailable

### 8. Supported Tech Stacks

The server auto-detects project types based on marker files:

| Stack | Marker File | Build Command | Scaffold |
|-------|-------------|---------------|----------|
| **Flutter** | `pubspec.yaml` | `flutter build appbundle --release` | `flutter create {slug}` |
| **Godot 4.x** | `project.godot` | `godot --headless --export-release "Android" build/{slug}.apk` | None |
| **Phaser** | `capacitor.config.ts` | `npm install && npm run build && npx cap sync android && cd android && gradlew bundleRelease` | Custom (via `phaser_scaffold.py`) |
| **React Native** | `package.json` (with RN deps) | `npx react-native build-android --mode=release` | `npx react-native init {name}` |
| **Python** | `pyproject.toml` | `python -m build` | None |
| **Custom** | None (manual) | User-defined | None |

### 9. Verification

After configuring, verify the setup works:

```bash
cd server
python -c "
from config.settings_loader import get_settings
s = get_settings()
print('Settings loaded OK')
for k, v in s.items():
    if 'path' in k:
        import os
        exists = os.path.isfile(v) if v else False
        status = 'OK' if exists else ('empty' if not v else 'NOT FOUND')
        print(f'  {k}: {status} ({v})')
"
```

Then start the server:
```bash
python main.py
```

It should print `Server running at http://localhost:8000`. Test with:
```bash
curl http://localhost:8000/api/health
```

### 10. Key API Endpoints (for integration)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/health` | Health check (no auth) |
| `GET` | `/api/apps` | List all apps |
| `POST` | `/api/apps` | Create new app |
| `POST` | `/api/apps/scan` | Auto-discover projects in projects_root |
| `POST` | `/api/apps/{id}/deploy` | Build + optional Google Play upload |
| `GET/POST` | `/api/apps/{id}/tasks` | List/create tasks |
| `GET/POST` | `/api/issues` | List/create issues |
| `POST` | `/api/automations` | Create automation job |
| `POST` | `/api/automations/{id}/start` | Start automation loop |
| `POST` | `/api/studio/brainstorm` | AI game brainstorm |
| `POST` | `/api/apps/{id}/studio/{action}` | Studio action (design-review, code-review, balance-check) |
| `POST` | `/api/apps/{id}/enhance` | AI-enhance GDD or CLAUDE.md |
| `POST` | `/api/chat` | AI chat with specialist routing |
| `GET/PUT` | `/api/apps/{id}/mcp` | Get/set per-app MCP servers |
| `GET` | `/api/mcp/servers` | List configured MCP servers |
| `POST` | `/api/mcp/presets/auto-setup` | Auto-configure preset MCPs |

## Rules For The Agent

1. **Ask before changing** `projects_root` — this is where all game projects live, user must confirm.
2. **Never hardcode** user-specific paths. Always use `which`/`where` to detect.
3. **API keys are optional** — if the user doesn't have one, leave the field empty. Don't make one up.
4. **Don't modify** any Python code, Dart code, or server logic. Only edit `settings.json` and `mcp_servers.json`.
5. **Use the correct JSON structure** — settings.json has nested sections (server, paths, ai_agents, engines, system, cloudflare, services, developer, security). Don't flatten it.
6. **Test paths exist** before writing them. Run `test -f /path/to/tool` or equivalent.
7. **On Windows**, be aware that `where` returns multiple lines. Use the first result.
8. **On Windows**, Flutter is often a bash script (`flutter`) not an exe. The deploy engine handles `.bat` resolution automatically — just point `flutter_path` to the SDK's `bin/flutter`.
9. **File encoding**: Always use `encoding="utf-8"` when reading/writing files in Python on Windows. The default locale encoding (e.g. cp1254 for Turkish) will silently corrupt non-ASCII characters.
10. **Monorepo layout**: The Flutter app is in `app/`, not the repo root. `pubspec.yaml` is at `app/pubspec.yaml`. The server handles this automatically via `_resolve_flutter_root()`.
11. **Security keys are auto-generated** — never manually set `api_key` or `hmac_secret`. Start the server once and it fills them in.
12. **MCP servers are optional** — only configure servers the user has API keys for. Cloud MCPs (godot, cloudflare) require Claude Max.
13. **Report** a summary of what you found, what you configured, and what's still missing.
