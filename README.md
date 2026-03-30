# Auto Game Builder

A self-hosted game project management system for indie developers. Manage builds, deployments, AI-powered bug fixes, and automation — all from your phone.

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

2. **Install wrangler** (for Cloudflare KV — stores your tunnel URL):
   ```bash
   npm install -g wrangler
   wrangler login
   ```

3. **Authenticate wrangler**:
   ```bash
   wrangler login
   ```
   This opens a browser to authenticate with your Cloudflare account. After login, the setup wizard can auto-configure tunnel settings.

### MCP Servers (optional, for AI capabilities)
- **PixelLab** — AI pixel art generation. Get API key at [pixellab.ai/dashboard](https://pixellab.ai/dashboard)
- **ElevenLabs** — AI audio/music. Get API key at [elevenlabs.io](https://elevenlabs.io). Requires [uv](https://docs.astral.sh/uv/) (`pip install uv`)
- **Mobile MCP** — Device testing. Requires Node.js
- **Godot MCP** — Cloud-based, included with Claude Max subscription
- **Cloudflare MCP** — Cloud-based, included with Claude Max subscription

## Configuration

All configuration is stored in gitignored files (never committed):
- `server/config/settings.json` — tool paths, server settings, credentials
- `server/config/mcp_servers.json` — MCP server configs and API keys

Template files with empty values are committed for reference:
- `server/config/settings.example.json`

## For AI Agents

If you're an AI agent configuring this project, read [`AGENT_SETUP_GUIDE.md`](AGENT_SETUP_GUIDE.md) for complete instructions on JSON formats, tool search strategies, and configuration rules.

## Your Creations

Games and apps you build with Auto Game Builder are **entirely yours**. You own all rights to your creations — sell them, publish them, modify them, do whatever you want. No attribution required, no revenue sharing, no restrictions. Auto Game Builder is just the tool; what you make with it belongs to you.

## License

This project (Auto Game Builder itself) is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details. This license applies to the tool, not to what you create with it.
