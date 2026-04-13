"""
Refresh the Tripo Studio JWT by sniffing it out of a running CDP Chrome.

The Tripo Studio API uses a Bearer JWT (eyJ...) that expires periodically.
This script attaches to a Chrome that's already running with remote debugging
enabled, reloads the active studio.tripo3d.ai tab so it re-issues API calls,
watches requests for an `Authorization: Bearer eyJ...` header, and writes the
captured token to tripo_studio_token.json (gitignored).

Pairs with tools/chrome/chrome_cdp_launcher.py.

Flow:
    1. Launch Chrome with CDP (once per session, persistent profile):
        python ../chrome/chrome_cdp_launcher.py --profile tripo --port 9222 \\
            --start-url https://studio.tripo3d.ai/

    2. In the Chrome window, log into studio.tripo3d.ai if not already.
       (The 'tripo' profile persists, so you only do this once ever.)

    3. Run this script:
        python refresh_studio_token.py

       It reloads the tab, waits for an api.tripo3d.ai request to fire,
       extracts the Bearer header, and saves it.

    4. Verify:
        python tripo_studio_api.py --balance

Options:
    --port <n>        CDP port (default 9222)
    --wait <seconds>  How long to wait after reload for API calls (default 15)
    --no-reload       Do not reload — just listen passively. Use this when the
                      page is already making requests (e.g. a generation is in
                      progress) and you don't want to disturb it.
"""
import argparse
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

_SCRIPT_DIR = Path(__file__).parent.resolve()
TOKEN_FILE = _SCRIPT_DIR / "tripo_studio_token.json"


def refresh(port: int = 9222, wait_seconds: int = 15, reload: bool = True) -> str | None:
    captured: dict[str, str | None] = {"token": None, "url": None}
    host_log: list[str] = []

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(f"http://localhost:{port}")
        except Exception as e:
            print(f"[!] Could not attach to Chrome on port {port}: {e}", file=sys.stderr)
            print(
                f"    Launch Chrome first:\n"
                f"    python ../chrome/chrome_cdp_launcher.py --profile tripo "
                f"--port {port} --start-url https://studio.tripo3d.ai/",
                file=sys.stderr,
            )
            return None

        ctx = browser.contexts[0]
        if not ctx.pages:
            print("[!] No open tabs in the CDP browser.", file=sys.stderr)
            return None

        # Prefer a studio.tripo3d.ai tab if one exists, else use the first tab.
        page = next(
            (pg for pg in ctx.pages if "studio.tripo3d.ai" in pg.url),
            ctx.pages[0],
        )
        print(f"[+] Attached to tab: {page.url}")

        def on_request(req):
            host_log.append(urlparse(req.url).netloc)
            auth = req.headers.get("authorization", "")
            if auth.lower().startswith("bearer eyj") and not captured["token"]:
                captured["token"] = auth.split(" ", 1)[1].strip()
                captured["url"] = req.url
                print(f"[+] Captured JWT from {req.url}")

        page.on("request", on_request)

        if reload:
            print("[*] Reloading the tab to force fresh API calls...")
            try:
                page.reload(wait_until="domcontentloaded", timeout=30000)
            except Exception as e:
                print(f"[!] Reload failed: {e} — continuing to listen anyway", file=sys.stderr)

        print(f"[*] Listening for up to {wait_seconds}s...")
        deadline_ms = wait_seconds * 1000
        tick = 500
        elapsed = 0
        while elapsed < deadline_ms and not captured["token"]:
            page.wait_for_timeout(tick)
            elapsed += tick

    print(f"[*] Saw {len(host_log)} requests across {len(set(host_log))} hosts")
    if not captured["token"]:
        print("[!] No Bearer eyJ... header seen.")
        print("    Try --no-reload while a generation is running, or")
        print("    click anything in the Studio UI to fire an API call.")
        return None

    TOKEN_FILE.write_text(
        json.dumps({"bearer_token": captured["token"]}, indent=2),
        encoding="utf-8",
    )
    print(f"[+] Saved {len(captured['token'])}-char JWT to {TOKEN_FILE}")
    return captured["token"]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Refresh the Tripo Studio JWT from a running CDP Chrome",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--port", type=int, default=9222, help="CDP port (default 9222)")
    parser.add_argument("--wait", type=int, default=15, help="Seconds to wait after reload (default 15)")
    parser.add_argument("--no-reload", action="store_true", help="Listen passively without reloading")
    args = parser.parse_args()

    token = refresh(port=args.port, wait_seconds=args.wait, reload=not args.no_reload)
    return 0 if token else 1


if __name__ == "__main__":
    raise SystemExit(main())
