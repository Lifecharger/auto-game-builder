"""
Tripo Studio network capture via CDP attach to an already-running Chrome.

Unlike tripo_capture.py (which launches its own Playwright Chrome that Google
blocks for login), this version ATTACHES to your real Chrome that you launched
yourself with --remote-debugging-port=9222. No automation detection, full
session, already logged in.

User flow:
    1. Close ALL Chrome windows completely
    2. Launch Chrome with the remote debugging flag (see START_CHROME_CMD below)
    3. Chrome opens with your normal profile — all tabs, cookies, logins intact
    4. In that Chrome, navigate to studio.tripo3d.ai (you're already logged in)
    5. Run THIS script in the terminal
    6. Script attaches, starts listening for network traffic
    7. In Chrome, trigger one 3D generation (any prompt → click Generate)
    8. Back in terminal, press Enter
    9. Script saves tripo_capture.json and exits
"""
import json
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

CAPTURE_FILE = Path(__file__).parent / "tripo_capture.json"
CDP_URL = "http://localhost:9222"

IGNORE_HOSTS = {
    "google-analytics.com", "googletagmanager.com",
    "fonts.googleapis.com", "fonts.gstatic.com",
    "stats.g.doubleclick.net", "cdn.cookielaw.org",
    "sentry.io", "clarity.ms", "hotjar.com",
    "segment.io", "amplitude.com", "intercom.io",
    "www.google-analytics.com", "doubleclick.net",
}
IGNORE_EXTS = (".css", ".woff", ".woff2", ".ttf", ".otf", ".svg", ".png",
                ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".mp4", ".webm")


def should_skip(url: str) -> bool:
    from urllib.parse import urlparse
    u = urlparse(url)
    if any(h in u.netloc for h in IGNORE_HOSTS):
        return True
    p = u.path.lower()
    if any(p.endswith(ext) for ext in IGNORE_EXTS):
        return True
    if "_next/static" in p:
        return True
    return False


def main():
    print(f"Attaching to Chrome at {CDP_URL}...")
    with sync_playwright() as pw:
        try:
            browser = pw.chromium.connect_over_cdp(CDP_URL)
        except Exception as e:
            print(f"ERROR: Can't attach to Chrome at {CDP_URL}")
            print(f"  {e}")
            print()
            print("Did you launch Chrome with the --remote-debugging-port=9222 flag?")
            print("See the script docstring for the exact command.")
            sys.exit(1)

        # Find the Tripo Studio tab (or use first tab if not found)
        contexts = browser.contexts
        if not contexts:
            print("ERROR: No browser contexts found.")
            sys.exit(1)

        # Look for a tab on studio.tripo3d.ai across all contexts
        target_page = None
        for ctx in contexts:
            for page in ctx.pages:
                url = page.url
                if "tripo3d.ai" in url:
                    target_page = page
                    print(f"Found Tripo tab: {url}")
                    break
            if target_page:
                break

        if not target_page:
            # No Tripo tab — use the first tab
            target_page = contexts[0].pages[0] if contexts[0].pages else None
            if not target_page:
                print("ERROR: No pages found in Chrome. Open a tab first.")
                sys.exit(1)
            print(f"No tripo3d.ai tab found — capturing on: {target_page.url}")
            print("→ Navigate that tab to studio.tripo3d.ai before triggering a generation")

        captured = []

        def on_request(req):
            if should_skip(req.url):
                return
            pd = None
            try:
                if req.method in ("POST", "PUT", "PATCH"):
                    pd = req.post_data
            except Exception:
                pass
            captured.append({
                "type": "request", "method": req.method, "url": req.url,
                "headers": dict(req.headers),
                "post_data": pd[:5000] if pd else None,
                "time": time.time(),
            })

        def on_response(resp):
            if should_skip(resp.url):
                return
            body = None
            try:
                ct = resp.headers.get("content-type", "")
                if "json" in ct or "text" in ct:
                    b = resp.body()
                    if b:
                        body = b[:5000].decode("utf-8", errors="replace")
            except Exception:
                pass
            captured.append({
                "type": "response", "status": resp.status, "url": resp.url,
                "headers": dict(resp.headers), "body_preview": body,
                "time": time.time(),
            })

        # Attach listeners to ALL existing pages + any new ones
        def attach_listeners(page):
            try:
                page.on("request", on_request)
                page.on("response", on_response)
            except Exception as e:
                print(f"  listener error: {e}")

        for ctx in contexts:
            for page in ctx.pages:
                attach_listeners(page)
            ctx.on("page", attach_listeners)

        print()
        print("=" * 70)
        print("LISTENING FOR NETWORK EVENTS on all Chrome tabs")
        print("=" * 70)
        print("1. In your Chrome window, go to studio.tripo3d.ai if not already there")
        print("2. Trigger ONE 3D generation — type a prompt, click Generate")
        print("3. Wait for it to START (progress bar / loading appears)")
        print("4. Come back to THIS terminal and press Enter")
        print("=" * 70)
        print()
        input("Press Enter when done... ")

        print(f"\nCaptured {len(captured)} non-static network events")
        CAPTURE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CAPTURE_FILE, "w", encoding="utf-8") as f:
            json.dump(captured, f, indent=2, ensure_ascii=False)
        print(f"Saved to: {CAPTURE_FILE}")

        # Don't close — user's real Chrome, we're just attached
        browser.close()


if __name__ == "__main__":
    main()
