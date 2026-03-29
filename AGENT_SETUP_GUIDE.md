# Auto Game Builder — Agent Configuration Guide

This file is meant to be read by an AI agent (Claude, Gemini, Codex, etc.) to automatically configure Auto Game Builder on a user's machine.

## Project Structure

```
auto-game-builder/
  setup_wizard.py          # First-run setup (you're helping with this)
  server/
    main.py                # Server entry point
    api/server.py           # FastAPI REST API
    config/
      settings.json         # USER CONFIG — you create/edit this
      settings.example.json # Template with empty values
      settings_loader.py    # Loads settings.json, auto-detects tools
      mcp_servers.json      # MCP server configs — you create/edit this
      constants.py          # App constants (don't edit)
      path_utils.py         # Cross-platform path utils
    core/                   # Engine modules (build, deploy, autofix, etc.)
    database/               # SQLite DB (auto-created on first run)
    requirements.txt        # Python dependencies
  app/                      # Flutter mobile app (don't touch)
```

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
    "npx_path": ""
  },
  "cloudflare": {
    "tunnel_enabled": false,
    "kv_namespace_id": "",
    "account_id": ""
  },
  "services": {
    "ollama_url": "http://localhost:11434"
  }
}
```

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
| `projects_root` | Ask the user where they keep game projects | `~/Projects` or `C:\Projects` |
| `keys_dir` | Ask the user where signing keystores are stored | `D:\keys` or `~/keys` |
| `tools_dir` | Directory with Python asset generation scripts (optional) | `C:\General Tools` |
| `service_account_key` | Path to Google Play API service account JSON (optional) | `~/keys/play-api.json` |

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
- **Cloud**: Provided by Claude Max subscription (Godot, Cloudflare). No local config needed.

**API key sources:**
- PixelLab: https://pixellab.ai/dashboard → API Keys
- ElevenLabs: https://elevenlabs.io → Profile → API Keys

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
- Server starts → Cloudflare tunnel → gets dynamic URL → writes to KV
- Phone connects to worker URL → worker reads KV → proxies to tunnel → reaches PC

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

Replace `DEVNAME` with the value from `settings.json` → `developer.developer_name`.

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
The exe will be at `app/build/windows/x64/runner/Release/app_manager_mobile.exe`

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

### 6. Verification

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

## Rules For The Agent

1. **Ask before changing** `projects_root` — this is where all game projects live, user must confirm.
2. **Never hardcode** user-specific paths. Always use `which`/`where` to detect.
3. **API keys are optional** — if the user doesn't have one, leave the field empty. Don't make one up.
4. **Don't modify** any Python code, Dart code, or server logic. Only edit `settings.json` and `mcp_servers.json`.
5. **Use the correct JSON structure** — settings.json has nested sections (server, paths, ai_agents, engines, system, cloudflare, services). Don't flatten it.
6. **Test paths exist** before writing them. Run `test -f /path/to/tool` or equivalent.
7. **On Windows**, be aware that `where` returns multiple lines. Use the first result.
8. **Report** a summary of what you found, what you configured, and what's still missing.
