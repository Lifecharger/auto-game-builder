"""First-run setup wizard — detects tools, installs MCPs, creates settings.json."""

import json
import os
import platform
import shutil
import subprocess
import sys
import time

_ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
_SERVER_DIR = os.path.join(_ROOT_DIR, "server")
_CONFIG_DIR = os.path.join(_SERVER_DIR, "config")

sys.path.insert(0, _SERVER_DIR)

from config.settings_loader import (
    _detect_bash,
    _detect_tool,
    save_settings,
)


# ── Helpers ────────────────────────────────────────────────────────

def _ask(prompt: str, default: str = "") -> str:
    """Prompt user for input with an optional default."""
    if default:
        raw = input(f"  {prompt} [{default}]: ").strip()
        return raw if raw else default
    else:
        raw = input(f"  {prompt} (press Enter to skip): ").strip()
        return raw


def _ask_secret(prompt: str) -> str:
    """Prompt for a secret value (API key, etc). Shows hint but no default."""
    raw = input(f"  {prompt}: ").strip()
    return raw


def _ask_bool(prompt: str, default: bool = False) -> bool:
    """Prompt user for yes/no."""
    hint = "Y/n" if default else "y/N"
    raw = input(f"  {prompt} [{hint}]: ").strip().lower()
    if not raw:
        return default
    return raw in ("y", "yes")


def _run_quiet(cmd: list[str], timeout: int = 30) -> tuple[int, str]:
    """Run a command quietly, return (exit_code, output)."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        return result.returncode, result.stdout + result.stderr
    except FileNotFoundError:
        return -1, f"Command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return -2, "Timeout"
    except Exception as e:
        return -3, str(e)


def _print_header(text: str):
    print()
    print(f"  ── {text} {'─' * max(1, 50 - len(text))}")
    print()


def _print_status(name: str, path: str, width: int = 18):
    tag = "\033[32m[OK]\033[0m" if path else "\033[90m[--]\033[0m"
    display = path if path else "(not found)"
    print(f"    {tag} {name:<{width}} {display}")


# ── Prerequisites ──────────────────────────────────────────────────

def _check_prerequisites() -> dict:
    """Check system prerequisites. Returns dict of findings."""
    results = {}

    # Python version
    ver = sys.version_info
    results["python"] = f"{ver.major}.{ver.minor}.{ver.micro}"
    results["python_ok"] = ver >= (3, 10)

    # pip
    code, out = _run_quiet([sys.executable, "-m", "pip", "--version"])
    results["pip"] = code == 0

    # Node.js / npm / npx
    results["node"] = bool(_detect_tool("node"))
    results["npm"] = bool(_detect_tool("npm"))
    results["npx"] = bool(_detect_tool("npx"))

    # uvx (Python uv tool runner)
    results["uvx"] = bool(_detect_tool("uvx"))

    # git
    results["git"] = bool(_detect_tool("git"))

    return results


def _install_requirements():
    """Install Python requirements from requirements.txt."""
    req_file = os.path.join(_SERVER_DIR, "requirements.txt")
    if not os.path.isfile(req_file):
        print("    \033[33m[!]\033[0m requirements.txt not found, skipping")
        return False

    print("    Installing Python dependencies...")
    code, out = _run_quiet(
        [sys.executable, "-m", "pip", "install", "-r", req_file, "--quiet"],
        timeout=120,
    )
    if code == 0:
        print("    \033[32m[OK]\033[0m Dependencies installed")
        return True
    else:
        print(f"    \033[31m[!!]\033[0m pip install failed: {out[:200]}")
        return False


# ── MCP Installation ───────────────────────────────────────────────

def _install_mcp_servers(detections: dict, credentials: dict) -> dict:
    """Install and configure MCP servers. Returns mcp_servers config dict."""
    mcp_servers = {}

    _print_header("MCP Server Setup")

    # Mobile MCP (requires npx)
    if detections.get("npx"):
        print("  Installing Mobile MCP...")
        code, out = _run_quiet(["npx", "-y", "@mobilenext/mobile-mcp", "--version"], timeout=60)
        if code in (0, 1):  # Some tools return 1 for --version but are installed
            mcp_servers["mobile"] = {
                "command": "npx",
                "args": ["-y", "@mobilenext/mobile-mcp"],
                "preset": True,
            }
            print("    \033[32m[OK]\033[0m Mobile MCP ready")
        else:
            print(f"    \033[33m[!]\033[0m Mobile MCP failed to install (needs Node.js)")
    else:
        print("    \033[90m[--]\033[0m Mobile MCP skipped (npx not found — install Node.js)")

    # PixelLab MCP (HTTP — no install needed, just config)
    pixellab_key = credentials.get("pixellab_api_key", "")
    if pixellab_key:
        mcp_servers["pixellab"] = {
            "type": "http",
            "url": "https://api.pixellab.ai/mcp",
            "preset": True,
            "_api_key": pixellab_key,
        }
        print("    \033[32m[OK]\033[0m PixelLab MCP configured (HTTP)")
    else:
        mcp_servers["pixellab"] = {
            "type": "http",
            "url": "https://api.pixellab.ai/mcp",
            "preset": True,
        }
        print("    \033[90m[--]\033[0m PixelLab MCP saved (no API key — add later in settings)")

    # ElevenLabs MCP (requires uvx)
    elevenlabs_key = credentials.get("elevenlabs_api_key", "")
    if detections.get("uvx"):
        config = {
            "command": "uvx",
            "args": ["elevenlabs-mcp"],
            "preset": True,
        }
        if elevenlabs_key:
            config["_api_key"] = elevenlabs_key
            config["env"] = {"ELEVENLABS_API_KEY": elevenlabs_key}
        mcp_servers["elevenlabs"] = config
        print("    \033[32m[OK]\033[0m ElevenLabs MCP ready" + (" (with key)" if elevenlabs_key else " (no key)"))
    else:
        print("    \033[90m[--]\033[0m ElevenLabs MCP skipped (uvx not found — install uv: https://docs.astral.sh/uv/)")

    # Godot MCP (cloud — no install needed)
    mcp_servers["godot"] = {"preset": True, "cloud": True}
    print("    \033[32m[OK]\033[0m Godot MCP (cloud-based, no setup needed)")

    # Cloudflare MCP (cloud — no install needed)
    mcp_servers["cloudflare"] = {"preset": True, "cloud": True}
    print("    \033[32m[OK]\033[0m Cloudflare MCP (cloud-based, no setup needed)")

    # Write MCP config
    mcp_path = os.path.join(_CONFIG_DIR, "mcp_servers.json")
    os.makedirs(_CONFIG_DIR, exist_ok=True)
    with open(mcp_path, "w", encoding="utf-8") as f:
        json.dump(mcp_servers, f, indent=2)
    print(f"\n    MCP config saved to config/mcp_servers.json")

    return mcp_servers


# ── Self-Test ──────────────────────────────────────────────────────

def _self_test(host: str, port: int) -> bool:
    """Start API server briefly and test /api/health."""
    import urllib.request

    _print_header("Self-Test")
    print("  Starting server for health check...")

    api_dir = os.path.join(_SERVER_DIR, "api")
    proc = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "server:app", "--host", host, "--port", str(port)],
        cwd=api_dir,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
    )

    # Wait for server to start
    url = f"http://localhost:{port}/api/health"
    success = False
    for i in range(10):
        time.sleep(1)
        try:
            req = urllib.request.Request(url)
            resp = urllib.request.urlopen(req, timeout=3)
            if resp.status == 200:
                success = True
                break
        except Exception:
            pass

    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()

    if success:
        print("    \033[32m[OK]\033[0m Server health check passed!")
    else:
        print("    \033[31m[!!]\033[0m Server health check failed")
        print("         This might be OK — try running 'python server/main.py' manually")

    return success


# ── Agent-Assisted Repair ──────────────────────────────────────────

def _offer_agent_repair(detections: dict, errors: list[str]):
    """If an AI agent is available, offer to fix setup issues."""
    agent = None
    agent_name = None
    for name in ("claude", "gemini", "codex"):
        if detections.get(name):
            agent = detections[name]
            agent_name = name
            break

    if not agent or not errors:
        return

    _print_header("Auto-Repair")
    print(f"  Issues detected. {agent_name.title()} is available.")
    print(f"  Errors: {', '.join(errors)}")

    if _ask_bool(f"  Want me to use {agent_name.title()} to diagnose and fix?"):
        prompt = (
            f"I'm setting up Auto Game Builder server at {_SERVER_DIR}. "
            f"The following issues occurred during setup: {'; '.join(errors)}. "
            f"Please diagnose and fix these issues. Check requirements.txt, "
            f"Python version ({sys.version}), and OS ({platform.system()})."
        )
        print(f"  Running {agent_name.title()}...")
        if agent_name == "claude":
            cmd = [agent, "-p", "--dangerously-skip-permissions", prompt]
        elif agent_name == "gemini":
            cmd = [agent, "-p", prompt]
        elif agent_name == "codex":
            cmd = [agent, "exec", "--full-auto", prompt]
        else:
            return

        try:
            subprocess.run(cmd, cwd=_SERVER_DIR, timeout=120)
            print("  Agent finished. Re-run the wizard to verify fixes.")
        except Exception as e:
            print(f"  Agent failed: {e}")


# ── Agent-Assisted Configuration ──────────────────────────────────

def _generate_agent_prompt() -> str:
    """Generate a comprehensive prompt for an AI agent to configure everything."""
    guide_path = os.path.join(_ROOT_DIR, "AGENT_SETUP_GUIDE.md")
    config_path = os.path.join(_CONFIG_DIR, "settings.json")
    example_path = os.path.join(_CONFIG_DIR, "settings.example.json")
    mcp_path = os.path.join(_CONFIG_DIR, "mcp_servers.json")
    req_path = os.path.join(_SERVER_DIR, "requirements.txt")

    prompt = f"""Configure Auto Game Builder on my machine. Follow the guide exactly.

PROJECT ROOT: {_ROOT_DIR}
GUIDE FILE: {guide_path}
OS: {platform.system()} {platform.release()}
Python: {sys.version.split()[0]}

YOUR TASK:
1. Read the guide file at {guide_path} — it explains everything.
2. Install Python dependencies: pip install -r {req_path}
3. Search my system for all tools (claude, gemini, codex, aider, flutter, godot, bash, cloudflared, npx, wrangler).
4. Create {config_path} using {example_path} as template. Fill in every tool path you found.
5. Ask me for projects_root (where I keep game projects).
6. Ask me for optional API keys (PixelLab, ElevenLabs) — I can skip these.
7. Ask me for optional Cloudflare config — I can skip this too.
8. Create {mcp_path} with all MCP servers configured (see guide for format).
9. Verify the setup works by running the test command from the guide.
10. Report what you configured and what's still missing.

IMPORTANT: Read {guide_path} first — it has the exact JSON formats, search strategies, and rules."""

    return prompt


def _copy_to_clipboard(text: str) -> bool:
    """Try to copy text to system clipboard. Returns True on success."""
    try:
        if platform.system() == "Windows":
            subprocess.run(["clip"], input=text.encode("utf-8"),
                         creationflags=subprocess.CREATE_NO_WINDOW, check=True)
            return True
        elif platform.system() == "Darwin":
            subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)
            return True
        else:
            subprocess.run(["xclip", "-selection", "clipboard"],
                         input=text.encode("utf-8"), check=True)
            return True
    except Exception:
        return False


def _offer_agent_setup() -> bool:
    """Offer agent-assisted setup at the beginning. Returns True if user chose agent mode."""
    _print_header("Setup Method")
    print("  How would you like to configure Auto Game Builder?")
    print()
    print("    \033[36m1)\033[0m Let your AI agent do it (recommended)")
    print("       Generates a prompt — paste it into Claude, Gemini, or Codex")
    print("       and the agent will find tools, set paths, and configure everything.")
    print()
    print("    \033[36m2)\033[0m Manual setup")
    print("       Walk through each step interactively.")
    print()

    choice = input("  Choose [1/2]: ").strip()
    if choice != "1":
        return False

    # Agent mode
    prompt = _generate_agent_prompt()

    print()
    print("  \033[1m" + "─" * 58 + "\033[0m")
    print("  \033[1m  PASTE THIS INTO YOUR AI AGENT:\033[0m")
    print("  \033[1m" + "─" * 58 + "\033[0m")
    print()
    print(prompt)
    print()
    print("  \033[1m" + "─" * 58 + "\033[0m")
    print()

    if _copy_to_clipboard(prompt):
        print("  \033[32m[OK]\033[0m Copied to clipboard!")
    else:
        print("  \033[33mTip:\033[0m Select and copy the prompt above manually.")

    print()
    print("  After your agent finishes, start the server with:")
    print(f"    python {os.path.join(_SERVER_DIR, 'main.py')}")
    print()
    print("  You can re-run this wizard anytime to reconfigure.")
    print()

    input("  Press Enter to exit...")
    return True


# ══════════════════════════════════════════════════════════════════
#  MAIN WIZARD
# ══════════════════════════════════════════════════════════════════

def run_wizard():
    """Interactive CLI wizard — full setup for Auto Game Builder."""
    errors = []

    print()
    print("  \033[1m" + "=" * 58 + "\033[0m")
    print("  \033[1m     AUTO GAME BUILDER — Server Setup Wizard\033[0m")
    print("  \033[1m" + "=" * 58 + "\033[0m")
    print()
    print("  This wizard will configure your server by detecting tools,")
    print("  installing MCP servers, and setting up credentials.")
    print()

    # ── Agent or Manual? ──────────────────────────────────────
    if _offer_agent_setup():
        return  # Agent mode — user will paste prompt into their agent

    print("  Press Enter to accept defaults. All credentials are optional.")
    print()

    # ── Step 1: Prerequisites ──────────────────────────────────
    _print_header("Step 1: Prerequisites")

    prereqs = _check_prerequisites()

    _print_status("Python " + prereqs["python"], "OK" if prereqs["python_ok"] else "")
    if not prereqs["python_ok"]:
        print("    \033[31m[!!]\033[0m Python 3.10+ required")
        errors.append("Python version too old")

    _print_status("pip", "OK" if prereqs["pip"] else "")
    _print_status("Node.js", "OK" if prereqs["node"] else "")
    _print_status("npm", "OK" if prereqs["npm"] else "")
    _print_status("npx", "OK" if prereqs["npx"] else "")
    _print_status("uvx", "OK" if prereqs["uvx"] else "")
    _print_status("git", "OK" if prereqs["git"] else "")

    if not prereqs["node"]:
        print("\n    \033[33mTip:\033[0m Install Node.js for Mobile MCP: https://nodejs.org/")
    if not prereqs["uvx"]:
        print("    \033[33mTip:\033[0m Install uv for ElevenLabs MCP: https://docs.astral.sh/uv/")

    # Install Python dependencies
    if prereqs["pip"]:
        print()
        _install_requirements()

    # ── Step 2: Detect AI Agents ───────────────────────────────
    _print_header("Step 2: AI Agents")

    agents = {
        "claude": _detect_tool("claude"),
        "gemini": _detect_tool("gemini"),
        "codex": _detect_tool("codex"),
        "aider": _detect_tool("aider"),
    }
    for name, path in agents.items():
        _print_status(name.title(), path)

    if not any(agents.values()):
        print("\n    \033[33m[!]\033[0m No AI agents found. Install at least one:")
        print("        Claude: https://docs.anthropic.com/en/docs/claude-code")
        print("        Gemini: https://github.com/google-gemini/gemini-cli")

    # Let user override/provide paths for agents not found
    missing_agents = [n for n in agents if not agents[n]]
    if missing_agents:
        print(f"\n  Enter paths for missing agents, or press Enter to skip:")
        for name in missing_agents:
            manual = _ask(f"    {name.title()} path", "")
            if manual:
                agents[name] = manual
                _print_status(name.title(), manual)

    # ── Step 3: Game Engines ──────────────────────────────────
    _print_header("Step 3: Game Engines")

    engines = {
        "flutter": _detect_tool("flutter"),
        "godot": _detect_tool("godot"),
    }
    for name, path in engines.items():
        _print_status(name.title(), path)

    # Let user provide/override engine paths
    print(f"\n  Enter paths or press Enter to {'keep' if any(engines.values()) else 'skip'}:")
    for name in list(engines.keys()):
        current = engines[name]
        if current:
            override = _ask(f"    {name.title()} path", current)
            engines[name] = override
        else:
            manual = _ask(f"    {name.title()} path", "")
            if manual:
                engines[name] = manual

    # Also detect system tools
    _print_header("Step 3b: System Tools")

    system_tools = {
        "bash": _detect_bash(),
        "cloudflared": _detect_tool("cloudflared"),
        "wrangler": _detect_tool("wrangler"),
        "npx": _detect_tool("npx"),
    }
    for name, path in system_tools.items():
        _print_status(name, path)

    # ── Step 4: Configure Paths ────────────────────────────────
    _print_header("Step 4: Paths")

    projects_root = _ask("Projects root directory", "~/Projects")
    keys_dir = _ask("Keys directory (for signing keystores)", "")
    tools_dir = _ask("Tools directory (Python scripts for asset generation)", "")

    # ── Step 5: Optional Credentials ───────────────────────────
    _print_header("Step 5: Credentials (all optional — press Enter to skip)")

    credentials = {}

    print("  \033[36mPixelLab\033[0m — AI pixel art generation")
    print("  Get your API key at: https://pixellab.ai/dashboard")
    credentials["pixellab_api_key"] = _ask_secret("  PixelLab API key")

    print()
    print("  \033[36mElevenLabs\033[0m — AI audio/music generation")
    print("  Get your API key at: https://elevenlabs.io")
    credentials["elevenlabs_api_key"] = _ask_secret("  ElevenLabs API key")

    print()
    print("  \033[36mGoogle Play\033[0m — Auto-deploy to Play Store")
    service_account_key = _ask("  Service account JSON key path", "")

    # ── Step 6: Cloudflare (optional) ──────────────────────────
    _print_header("Step 6: Remote Access (optional)")
    print("  Cloudflare Tunnel lets you access your server from anywhere.")
    print("  Required for phone access outside your local network.")

    tunnel_enabled = False
    kv_namespace_id = ""
    account_id = ""

    if system_tools["cloudflared"]:
        tunnel_enabled = _ask_bool("Enable Cloudflare tunnel?", False)
        if tunnel_enabled:
            kv_namespace_id = _ask("Cloudflare KV namespace ID", "")
            account_id = _ask("Cloudflare account ID", "")
    else:
        print("  \033[90mcloudflared not found — tunnel disabled\033[0m")
        print("  Install: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/")

    # ── Step 7: Server Settings ────────────────────────────────
    _print_header("Step 7: Server")

    host = _ask("API host", "0.0.0.0")
    port_str = _ask("API port", "8000")
    try:
        port = int(port_str)
    except ValueError:
        port = 8000

    ollama_url = _ask("Ollama URL (for local AI models)", "http://localhost:11434")

    # ── Step 8: Install MCP Servers ────────────────────────────
    all_detections = {**agents, **engines, **system_tools}
    _install_mcp_servers(all_detections, credentials)

    # ── Step 9: Save Settings ──────────────────────────────────
    _print_header("Saving Configuration")

    settings = {
        "host": host,
        "port": port,
        "projects_root": projects_root,
        "keys_dir": keys_dir,
        "tools_dir": tools_dir,
        "service_account_key": service_account_key,
        "claude_path": agents["claude"],
        "gemini_path": agents["gemini"],
        "codex_path": agents["codex"],
        "aider_path": agents["aider"],
        "godot_path": engines["godot"],
        "flutter_path": engines["flutter"],
        "bash_path": system_tools["bash"],
        "cloudflared_path": system_tools["cloudflared"],
        "wrangler_path": system_tools["wrangler"],
        "npx_path": system_tools["npx"],
        "tunnel_enabled": tunnel_enabled,
        "kv_namespace_id": kv_namespace_id,
        "account_id": account_id,
        "ollama_url": ollama_url,
    }

    save_settings(settings)
    print("    \033[32m[OK]\033[0m config/settings.json saved")

    # ── Step 9: Self-Test ──────────────────────────────────────
    test_ok = False
    if _ask_bool("Run a quick server health check?", True):
        test_ok = _self_test(host, port)
        if not test_ok:
            errors.append("Server health check failed")

    # ── Step 10: Agent Repair (if needed) ─────────────────────
    if errors:
        _offer_agent_repair(all_detections, errors)

    # ── Done ───────────────────────────────────────────────────
    print()
    print("  \033[1m" + "=" * 58 + "\033[0m")
    print("  \033[1m  Setup Complete!\033[0m")
    print("  \033[1m" + "=" * 58 + "\033[0m")
    print()
    print("  \033[36mNext steps:\033[0m")
    print(f"    1. Start the server:  python {os.path.join(_SERVER_DIR, 'main.py')}")
    print(f"    2. Open in browser:   http://localhost:{port}")
    print(f"    3. Install the app:   https://play.google.com/store/apps/details?id=com.lifecharger.appmanager")
    print()

    if not any(agents.values()):
        print("  \033[33mNote:\033[0m No AI agents detected. Install Claude, Gemini, or Codex")
        print("        to use AI-powered features (auto-fix, chat, automation).")
        print()

    summary_items = []
    for name in ("claude", "gemini", "codex", "aider"):
        if agents[name]:
            summary_items.append(f"{name.title()}")
    for name in ("flutter", "godot"):
        if engines[name]:
            summary_items.append(f"{name.title()}")
    if summary_items:
        print(f"  Detected: {', '.join(summary_items)}")

    mcp_items = []
    mcp_path = os.path.join(_CONFIG_DIR, "mcp_servers.json")
    if os.path.isfile(mcp_path):
        with open(mcp_path, "r") as f:
            mcp_data = json.load(f)
        for name in mcp_data:
            mcp_items.append(name.title())
    if mcp_items:
        print(f"  MCP servers: {', '.join(mcp_items)}")

    print()


if __name__ == "__main__":
    run_wizard()
