# Auto Game Builder

A self-hosted game project management system for indie developers. Manage builds, deployments, AI-powered bug fixes, and automation — all from your phone.

## Features

- **Multi-Agent AI**: Use Claude, Gemini, Codex, or Aider to fix bugs, implement features, and automate tasks
- **Build & Deploy**: One-tap builds for Flutter and Godot projects, auto-upload to Google Play
- **Issue Tracking**: Create issues, queue them for AI auto-fix, track results
- **Task Automation**: Continuous automation loops with configurable intervals
- **MCP Integration**: PixelLab (pixel art), ElevenLabs (audio), Mobile (device testing)
- **Asset Pipeline**: Automated asset processing and cataloging
- **Remote Access**: Cloudflare tunnel for phone-to-PC connection

## Architecture

- **Server** (`server/`): Python/FastAPI backend that runs on your development PC
- **App** (`app/`): Flutter mobile app (Android + Windows) that connects to your server

## Quick Start

### Server Setup
```bash
git clone https://github.com/cagatayozer/auto-game-builder.git
cd auto-game-builder
pip install -r server/requirements.txt
python server/setup_wizard.py
python server/main.py
```

### Mobile App
Install from [Google Play](https://play.google.com/store/apps/details?id=com.lifecharger.appmanager) or build from source:
```bash
cd app
flutter pub get
flutter run
```

## Setup Wizard

The server setup wizard automatically:
- Detects installed AI agents (Claude, Gemini, Codex, Aider)
- Detects game engines (Flutter, Godot)
- Installs MCP servers (PixelLab, ElevenLabs, Mobile)
- Configures optional services (Cloudflare tunnel, Google Play API)

## License

This project is licensed under the GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
