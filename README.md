# Auto Game Builder

[![Google Play](https://img.shields.io/badge/Google%20Play-Download-green?logo=google-play)](https://play.google.com/store/apps/details?id=com.lifecharger.appmanager)

A self-hosted game project management system for indie developers. Manage builds, deployments, AI-powered bug fixes, and automation — all from your phone.

## See It in Action

**[Lifecharger on Google Play](https://play.google.com/store/apps/developer?id=Lifecharger)** — [Arcade Snake](https://play.google.com/store/apps/details?id=com.lifecharger.arcadesnake) was built and deployed entirely through Auto Game Builder's automation pipeline. Check it out as a demo of what this tool can do.

**[In-Progress APKs (Google Drive)](https://drive.google.com/drive/folders/1p29egH2JkXLpU-o7IqdnH5IIsy2a9sE3?usp=drive_link)** — Raw development builds of games and apps currently being made with Auto Game Builder. **Fair warning:**
- These are **not playtested** — expect rough edges and broken flows
- These are **not audited** — no security or quality review has been done
- Several are **in the middle of a refactor** by Claude Code (via Auto Game Builder) using templates from [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) — features may be half-implemented or temporarily broken as the AI agents restructure and improve them
- Treat these as a snapshot of active development, not finished products

## Features

- **Multi-Agent AI**: Use Claude, Gemini, Codex, or Aider to fix bugs, implement features, and automate tasks
- **Build & Deploy**: One-tap builds for Flutter and Godot projects, auto-upload to Google Play
- **Issue Tracking**: Create issues, queue them for AI auto-fix, track results
- **Task Automation**: Continuous automation loops with configurable intervals
- **MCP Integration**: PixelLab (pixel art), ElevenLabs (audio), Mobile (device testing)
- **Remote Access**: Cloudflare Worker proxy for permanent phone-to-PC connection

## Architecture

- **Server** (`server/`): Python/FastAPI backend that runs on your development PC
- **App** (`app/`): Flutter mobile app (Android + Windows) that connects to your server

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
  - [Aider](https://aider.chat/)

### Optional (for full functionality)
- **Flutter SDK** — [flutter.dev](https://flutter.dev/docs/get-started/install) (for building Flutter games)
- **Godot Engine** — [godotengine.org](https://godotengine.org/download) (for building Godot games)
- **Node.js** — [nodejs.org](https://nodejs.org/) (for Mobile MCP and wrangler)

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

### MCP Servers (optional, for AI capabilities)
- **[PixelLab](https://github.com/pixellab-code/pixellab-mcp)** — AI pixel art generation. Get API key at [pixellab.ai/dashboard](https://pixellab.ai/dashboard)
- **[ElevenLabs](https://github.com/elevenlabs/elevenlabs-mcp)** — AI audio/music. Get API key at [elevenlabs.io](https://elevenlabs.io). Requires [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- **[Meshy AI](https://github.com/pasie15/meshy-ai-mcp-server)** — 3D model generation (text-to-3D, image-to-3D, rigging, animation). Get API key at [meshy.ai](https://www.meshy.ai/)
- **[Mobile MCP](https://github.com/mobile-next/mobile-mcp)** — Device testing. Requires Node.js
- **Godot MCP** — Cloud-based, requires [Claude Max](https://claude.ai) subscription
- **Cloudflare MCP** — Cloud-based, requires [Claude Max](https://claude.ai) subscription

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

**Maintainer:** Cagatay Ozer ([@Lifecharger](https://github.com/Lifecharger))

## Make It Yours

This project is meant to be forked and customized. Change the app name, the theme, the package name, the features — whatever fits your workflow. The setup wizard handles developer identity and package naming so your build is truly yours, not a clone.

Some ideas:
- Add your own AI prompts and automation scripts
- Swap the color scheme in `app/lib/theme.dart`
- Add new build targets or deploy pipelines
- Integrate your own MCP servers for specialized tools

## Your Creations

Games and apps you build with Auto Game Builder are **entirely yours**. You own all rights to your creations — sell them, publish them, modify them, do whatever you want. No attribution required, no revenue sharing, no restrictions. Auto Game Builder is just the tool; what you make with it belongs to you.

## Roadmap

- [x] **Meshy MCP Integration** — 3D model generation (text-to-3D, image-to-3D, auto-rigging, animation) via [Meshy AI](https://www.meshy.ai/)
- [ ] **Experimental Unity Support** — Unity engine project creation, build pipeline, and deployment
- [ ] **Genre Selection & Database** — Genre-based project templates with curated mechanics, assets, and configurations

## License

This project (Auto Game Builder itself) is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details. This license applies to the tool, not to what you create with it.
