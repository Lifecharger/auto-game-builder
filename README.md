# Auto Game Builder

[![Google Play](https://img.shields.io/badge/Google%20Play-Download-green?logo=google-play)](https://play.google.com/store/apps/details?id=com.lifecharger.appmanager)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A self-hosted game project management system for indie developers. Manage builds, deployments, AI-powered bug fixes, and automation — all from your phone.

## See It in Action

**[Lifecharger on Google Play](https://play.google.com/store/apps/developer?id=Lifecharger)** — [Arcade Snake](https://play.google.com/store/apps/details?id=com.lifecharger.arcadesnake) was built and deployed entirely through Auto Game Builder's automation pipeline. Check it out as a demo of what this tool can do.

**[In-Progress APKs (Google Drive)](https://drive.google.com/drive/folders/1p29egH2JkXLpU-o7IqdnH5IIsy2a9sE3?usp=drive_link)** — Raw development builds of games and apps currently being made with Auto Game Builder. **Fair warning:**
- These are **not playtested** — expect rough edges and broken flows
- These are **not audited** — no security or quality review has been done
- Several are **in the middle of a refactor** by Claude Code (via Auto Game Builder) using templates from [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) — features may be half-implemented or temporarily broken as the AI agents restructure and improve them
- Treat these as a snapshot of active development, not finished products

## Features

### Multi-Agent AI
- **Claude Code**, **Gemini CLI**, **Codex CLI**, and **Aider** for bug fixes, feature implementation, and task automation
- **Local AI** via Aider + Ollama for offline/private work (default model: `qwen2.5-coder:7b`)
- Smart prompt templates per engine (Flutter, Godot, generic) with code quality standards baked in

### Game Studio
One-tap Studio Actions — each button creates an enriched task in your project's `tasklist.json` that the next autonomous AI run consumes. Distilled from the [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) skill framework into a condensed, autonomous-first shape.

**Studio Reviews** (Issues screen → `🧪` popup):
- **Design Review** — GDD section audit against 8-section standard + mechanic clarity + monetization ethics
- **Code Review** — per-engine code quality, crash risks, memory leaks, architecture smells
- **Balance Check** — economy, progression curves, reward pacing, ethical monetization patterns
- **Consistency Check** — cross-document drift scanner (GDD ↔ code ↔ data files) catching conflicting stats, prices, and formulas
- **Tech Debt Scan** — Tier 1/2/3 debt triage for god scripts, duplicates, dead code, stale TODOs
- **Asset Audit** — cross-reference `assets/` against code references and GDD plans — broken refs, orphans, missing planned, placeholders
- **Content Audit** — walk every shippable surface (levels, characters, items, dialogue, UI) for completeness and dead ends
- **Scope Check** — producer reality-check with cut list and weeks-to-clear estimate
- **Performance Profile** — player-felt bottleneck analysis (frame drops, memory, load time) — no micro-optimization noise

**Art & Assets** (Issues screen → `🎨` popup):
- **Art Bible** — one-time authoring of `design/art-bible.md`, the 9-section visual identity anchor (color palette, character direction, UI language, style prohibitions) that every future asset-generation task reads as a constraint
- **Asset Specs** — per-asset spec generator — bundles the art bible + GDD entry into a ready-to-run prompt tuned for the target generator (PixelLab / Grok / Meshy / Tripo)

**Task creation**:
- **Brainstorm** — AI-generated game concepts with full GDD scaffolding (Dashboard → Brainstorm FAB)
- **Generate Ideas** — session-focused idea generation weighted by visual / gameplay / code / polish (Issues screen top bar)
- **Document Enhancement** — AI-powered improvement of `gdd.md` and `CLAUDE.md` files (App Detail screen)

**Built-in knowledge base** at `server/config/studio/*.md` — 15 condensed specialist files covering brainstorming, GDD templates, gameplay/UX, code quality, visual audit, polish, consistency scanning, tech debt, asset audit, content audit, scope, performance, art bible, asset specs. Each is ~40-60 lines, autonomous-first, and loads into task prompts automatically based on the action.

### Build & Deploy
- **One-tap builds** for Flutter, Godot, Phaser (Capacitor), and React Native projects
- **Build targets**: AAB, APK, EXE (Windows), IPA (iOS), APP (macOS), Web
- **Google Play deployment** — automatic version bumping, AAB upload, track selection (internal/alpha/beta/production)
- **Python projects** supported for `python -m build` workflows
- Auto-detected build commands and output paths per engine

### Issue Tracking & Auto-Fix
- Create issues (bug, ANR, crash, improvement, feature, idea) with priority levels
- Queue issues for AI auto-fix with engine-specific prompt templates
- Session tracking with 20-minute timeout, internet-aware scheduling
- ANR report parsing from Google Play Console crash data

### Task Automation
- Continuous automation loops with configurable intervals
- One-shot and per-task execution scripts
- Background process management with auto-restart on failure

### MCP Integration
Extend AI agent capabilities with Model Context Protocol servers:
- **[PixelLab](https://github.com/pixellab-code/pixellab-mcp)** — AI pixel art generation (characters, tilesets, UI, backgrounds)
- **[ElevenLabs](https://github.com/elevenlabs/elevenlabs-mcp)** — AI audio, music, and sound effects
- **[Meshy AI](https://github.com/pasie15/meshy-ai-mcp-server)** — 3D model generation (text-to-3D, image-to-3D, rigging, animation)
- **[Mobile MCP](https://github.com/mobile-next/mobile-mcp)** — Device testing and automation
- **Godot MCP** — Godot engine tools (cloud, requires Claude Max)
- **Cloudflare MCP** — Cloudflare management (cloud, requires Claude Max)
- Per-app MCP assignment — each project gets its own set of MCP servers
- Preset auto-setup and custom server registration via API

### Remote Access
- **Cloudflare Worker** proxy for a permanent phone-to-PC URL
- **Cloudflare Tunnel** with auto-registration to KV
- Access your server from anywhere — the URL never changes even when the tunnel restarts

### AI Chat
- Conversational AI endpoint with context-aware specialist routing
- Automatically loads relevant knowledge (brainstorm, code quality, visual audit, polish, gameplay) based on the question

### Asset Generation Tools
Python scripts in `tools/`, organized by vendor/category subfolders:
- **`tools/pixellab/`** — pixel art generation, UI elements, backgrounds, image-to-pixel conversion, inpainting
- **`tools/meshy/`** — text-to-3D, image-to-3D, retexturing, remeshing, rigging, animation
- **`tools/tripo/`** — Tripo3D text/image → 3D, rigging, animation (official SDK + Studio JWT path with `refresh_studio_token.py`)
- **`tools/grok/`** — Grok (xAI) image/video generation + favorites downloader
- **`tools/chrome/`** — Chrome DevTools Protocol launcher and network capture
- **`tools/blender/`** — automatic mesh splitting and Mixamo bulk animation download
- **`tools/media/`** — pad_image, video_to_frames, png_to_pixel_array
- **`tools/extract/`** — per-project asset extractors
- **`tools/pixel_guy/`** — merged Pixel Guy character viewer app + Python pipeline
- **`tools/comic_translator/`** — merged Gemini-powered comic translator
- **`tools/animation_generator/`** — merged 2D Animation Generator UI (wraps the grok + media + tripo subfolders)
- **ElevenLabs** — accessed via MCP only (no standalone scripts)

All vendor API keys live in the gitignored `server/config/mcp_servers.json` under `{vendor}._api_key`. Client modules walk upward from their script directory to find it, so moving tools between depths just works. See `tools/CLAUDE.md` for the full per-tool reference.

## Security

Auto Game Builder takes security seriously. Your development PC is exposed to the internet via Cloudflare tunnels, so multiple layers of protection are in place:

### How It Works

```
Phone ──X-API-Key──> Worker ──verify HMAC──> Tunnel ──validate key──> PC Server
```

| Layer | Threat | Protection |
|-------|--------|------------|
| **API Key Authentication** | Unauthorized access to your server | Every request requires a shared secret (`X-API-Key` header). Both the Cloudflare Worker and the PC server independently validate it. |
| **HMAC-Signed Tunnel URLs** | KV poisoning / man-in-the-middle | When the server writes its tunnel URL to Cloudflare KV, it also writes an HMAC-SHA256 signature. The Worker verifies this signature before proxying — a poisoned URL fails verification. |
| **QR Code Pairing** | Secure key exchange | The API key is transferred from PC to phone via QR code scan (physical/local channel). The key never travels through the internet during setup. |
| **Worker Secrets** | Key leakage | API key and HMAC secret are stored as Cloudflare Worker secrets (encrypted, never visible in dashboards or logs). |

### Pairing Your Phone

1. **Start the server** — keys are auto-generated on first run and saved to `settings.json`
2. **On the desktop app** — go to Settings > "Show Pairing QR Code"
3. **On your phone** — go to Settings > "Scan QR Code to Pair"
4. Done. Your phone is now authenticated for all future requests.

### What's Protected

- All `/api/*` endpoints require a valid API key (except `/api/health`)
- The Worker rejects requests without a valid key before they ever reach your PC
- Tunnel URLs in KV are cryptographically signed — even with Cloudflare account access, an attacker cannot redirect traffic without the HMAC secret
- The health endpoint no longer leaks the raw tunnel URL

## Architecture

```
auto-game-builder/
  server/              Python/FastAPI backend (runs on your dev PC)
    api/server.py        REST API (apps, issues, tasks, builds, studio, chat)
    core/                Engine modules (build, deploy, autofix, AI tools)
    config/              Settings, MCP servers, studio knowledge base
    database/            SQLite with WAL mode (thread-safe, auto-migrating)
  app/                 Flutter mobile app (Android + Windows)
  worker/              Cloudflare Worker proxy (JS)
  tools/               Asset generation toolkit, organized by vendor:
    grok/ pixellab/ meshy/ tripo/ chrome/ blender/ media/ extract/
    pixel_guy/ comic_translator/ animation_generator/ dart/
```

### Supported Tech Stacks

| Engine | Detection | Build Targets | Scaffold |
|--------|-----------|---------------|----------|
| **Flutter** | `pubspec.yaml` | AAB, APK, EXE, IPA, Web | `flutter create` |
| **Godot 4.x** | `project.godot` | APK, AAB, Windows, Web, Linux | — |
| **Phaser** | `capacitor.config.ts` | AAB, APK, Web | Custom template |
| **React Native** | `package.json` | AAB, APK | `npx react-native init` |
| **Python** | `pyproject.toml` | `dist/` | — |
| **Custom** | Manual | User-defined | — |

## Quick Start

### Server Setup
```bash
git clone https://github.com/Lifecharger/auto-game-builder.git
cd auto-game-builder
pip install -r server/requirements.txt
python setup_wizard.py
python server/main.py
```

The setup wizard offers two modes:
1. **Agent mode** (recommended): Generates a prompt — paste it into Claude/Gemini/Codex and the AI configures everything automatically
2. **Manual mode**: Walk through each step interactively

### Mobile App
Install from [Google Play](https://play.google.com/store/apps/details?id=com.lifecharger.appmanager) or build from source:
```bash
cd app
flutter pub get
flutter build windows --release   # Windows desktop
flutter build apk --release       # Android APK
flutter build appbundle --release  # Android AAB (Google Play)
```

## Prerequisites

### Required
- **Python 3.10+** — [python.org](https://www.python.org/downloads/)
- **At least one AI agent**:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (recommended)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)
  - [Codex CLI](https://github.com/openai/codex)
  - [Aider](https://aider.chat/) (also powers local AI mode with Ollama)

### Optional (for full functionality)
- **Flutter SDK** — [flutter.dev](https://flutter.dev/docs/get-started/install) (for building Flutter games)
- **Godot Engine** — [godotengine.org](https://godotengine.org/download) (for building Godot games)
- **Node.js** — [nodejs.org](https://nodejs.org/) (for Phaser/Capacitor builds, React Native, Mobile MCP, wrangler)
- **Ollama** — [ollama.com](https://ollama.com/) (for local/offline AI via Aider)

### Remote Access (phone outside local network)
To access your server from your phone over the internet:

1. **Install cloudflared**:
   - Windows: `winget install Cloudflare.cloudflared`
   - macOS: `brew install cloudflared`
   - Linux: [Cloudflare docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/)

2. **Install and authenticate wrangler** (for Cloudflare KV — stores your tunnel URL):
   ```bash
   npm install -g wrangler
   wrangler login
   ```
   This opens a browser to authenticate with your Cloudflare account. After login, the setup wizard can auto-configure tunnel settings.

3. **Deploy the worker and set secrets** (after first server start generates keys):
   ```bash
   cd worker && npx wrangler deploy
   # Read keys from server/config/settings.json, then:
   echo "YOUR_API_KEY" | npx wrangler secret put API_KEY
   echo "YOUR_HMAC_SECRET" | npx wrangler secret put HMAC_SECRET
   ```

4. **Pair your phone** — see [Security > Pairing Your Phone](#pairing-your-phone) above

### MCP Servers (optional, for AI capabilities)
- **[PixelLab](https://github.com/pixellab-code/pixellab-mcp)** — AI pixel art generation. Get API key at [pixellab.ai/dashboard](https://pixellab.ai/dashboard)
- **[ElevenLabs](https://github.com/elevenlabs/elevenlabs-mcp)** — AI audio/music. Get API key at [elevenlabs.io](https://elevenlabs.io). Requires [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- **[Meshy AI](https://github.com/pasie15/meshy-ai-mcp-server)** — 3D model generation (text-to-3D, image-to-3D, rigging, animation). Get API key at [meshy.ai](https://www.meshy.ai/)
- **[Mobile MCP](https://github.com/mobile-next/mobile-mcp)** — Device testing. Requires Node.js
- **Godot MCP** — Cloud-based, requires [Claude Max](https://claude.ai) subscription
- **Cloudflare MCP** — Cloud-based, requires [Claude Max](https://claude.ai) subscription

## API Reference

### Core Endpoints

| Group | Endpoints | Description |
|-------|-----------|-------------|
| **Apps** | `GET/POST/PATCH /api/apps` | CRUD for game projects, auto-scan for projects |
| **Issues** | `GET/POST/PATCH/DELETE /api/issues` | Bug tracking with priority, category, status |
| **Tasks** | `GET/POST/PATCH/DELETE /api/apps/{id}/tasks` | Task management with archiving and statistics |
| **Builds** | `GET /api/builds`, `POST /api/apps/{id}/deploy` | Build orchestration, Google Play upload, retry |
| **Automations** | `GET/POST/PATCH/DELETE /api/automations` | Continuous automation loops, start/stop/run-once |
| **Studio** | `POST /api/studio/brainstorm`, `POST /api/apps/{id}/studio/{action}` | Game studio — brainstorm + 11 one-tap skill actions (`design-review`, `code-review`, `balance-check`, `consistency-check`, `tech-debt`, `asset-audit`, `content-audit`, `scope-check`, `perf-profile`, `art-bible`, `asset-spec`) |
| **Chat** | `POST /api/chat` | Context-aware AI conversation |
| **MCP** | `GET/POST/DELETE /api/mcp/servers` | MCP server management, presets, per-app config |
| **GDD** | `GET/PUT /api/apps/{id}/gdd` | Game Design Document read/write |
| **Enhance** | `POST /api/apps/{id}/enhance` | AI-powered document improvement |
| **Logs** | `GET /api/logs` | Build and automation log viewer |
| **Health** | `GET /api/health` | Server status (no auth required) |

## Configuration

All configuration is stored in gitignored files (never committed):
- `server/config/settings.json` — tool paths, server settings, credentials
- `server/config/mcp_servers.json` — MCP server configs and API keys

Template files with empty values are committed for reference:
- `server/config/settings.example.json`

## For AI Agents

If you're an AI agent configuring this project, read [`AGENT_SETUP_GUIDE.md`](AGENT_SETUP_GUIDE.md) for complete instructions on JSON formats, tool search strategies, and configuration rules.

## Contributing

Contributions are welcome! Whether it's bug fixes, new features, documentation improvements, or translations — all pull requests are thoroughly reviewed. Feel free to open an issue to discuss ideas before submitting.

If you build something you think every user would benefit from, open a pull request — we'd love to see it.

**Maintainer:** [@Lifecharger](https://github.com/Lifecharger)

## Make It Yours

This project is meant to be forked and customized. Change the app name, the theme, the package name, the features — whatever fits your workflow. The setup wizard handles developer identity and package naming so your build is truly yours, not a clone.

Some ideas:
- Add your own AI prompts and automation scripts
- Swap the color scheme in `app/lib/theme.dart`
- Add new build targets or deploy pipelines
- Integrate your own MCP servers for specialized tools
- Add custom studio knowledge files for your genre

## Your Creations

Games and apps you build with Auto Game Builder are **entirely yours**. You own all rights to your creations — sell them, publish them, modify them, do whatever you want. No attribution required, no revenue sharing, no restrictions. Auto Game Builder is just the tool; what you make with it belongs to you.

## Roadmap

- [x] **Meshy MCP Integration** — 3D model generation via Meshy AI
- [x] **Phaser Engine Support** — Full build pipeline for Phaser + Capacitor
- [x] **React Native Support** — Detection, build pipeline, and scaffolding
- [x] **Game Studio System** — AI-powered brainstorming, design review, and code review
- [x] **AI Chat** — Context-aware conversational interface with specialist routing
- [x] **Local AI** — Offline AI mode via Aider + Ollama
- [x] **Tools Reorganization** — Vendor subfolders (grok, pixellab, meshy, tripo, chrome, blender, media, extract) + merged standalone projects (pixel_guy, comic_translator, animation_generator) + Tripo Studio JWT browser-path refresher
- [x] **Studio Actions Expansion** — 8 new one-tap skill buttons (consistency, tech-debt, asset-audit, content-audit, scope, perf, art-bible, asset-spec) distilled from the Claude Code Game Studios framework
- [ ] **Experimental Unity Support** — Unity engine project creation, build pipeline, and deployment
- [ ] **Genre Selection & Database** — Genre-based project templates with curated mechanics, assets, and configurations

## License

This project (Auto Game Builder itself) is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details. This license applies to the tool, not to what you create with it.
