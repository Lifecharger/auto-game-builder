"""
Tripo Studio network capture helper.

Launches a visible Chrome window, navigates to studio.tripo3d.ai, and records
every network request the page makes. Designed so a non-technical user can
reverse-engineer the backend by just using the UI normally.

Flow:
    1. You run this script
    2. A Chrome window opens on studio.tripo3d.ai
    3. Log in (if you're not already logged in)
    4. Do ONE normal generation — type any prompt, click Generate, wait for
       it to start. You can cancel/delete afterwards.
    5. Come back to the terminal, press Enter
    6. Script saves the captured requests + responses to
       tripo_capture.json (and stops)

A persistent profile at ~/.tripo-capture-profile is reused across runs, so
you only log in once ever.
"""
import argparse
import json
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

PROFILE_DIR = str(Path.home() / ".tripo-capture-profile")
CAPTURE_FILE = Path(__file__).parent / "tripo_capture.json"
STUDIO_URL = "https://studio.tripo3d.ai/"

# Ignore noise — static files, analytics, fonts
IGNORE_HOSTS = {
    "google-analytics.com",
    "googletagmanager.com",
    "fonts.googleapis.com",
    "fonts.gstatic.com",
    "www.googletagmanager.com",
    "stats.g.doubleclick.net",
    "cdn.cookielaw.org",
    "sentry.io",
    "clarity.ms",
    "hotjar.com",
    "segment.io",
    "amplitude.com",
    "intercom.io",
}
IGNORE_EXTS = {".css", ".woff", ".woff2", ".ttf", ".otf", ".svg", ".png", ".jpg",
                ".jpeg", ".gif", ".webp", ".ico", ".mp4", ".webm"}


def should_skip(url: str) -> bool:
    from urllib.parse import urlparse
    u = urlparse(url)
    if any(h in u.netloc for h in IGNORE_HOSTS):
        return True
    path = u.path.lower()
    if any(path.endswith(ext) for ext in IGNORE_EXTS):
        return True
    if "_next/static" in path:
        return True
    if "/assets/" in path and any(path.endswith(e) for e in (".js", ".css")):
        return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--headed", action="store_true", default=True,
                        help="Show browser window (default; needed so you can log in)")
    parser.add_argument("--use-system-chrome", action="store_true",
                        help="Use the user's installed Chrome instead of Playwright's bundled Chromium. "
                             "Helps bypass Google login automation detection.")
    args = parser.parse_args()

    captured = []

    def on_request(req):
        try:
            if should_skip(req.url):
                return
            post_body = None
            try:
                if req.method in ("POST", "PUT", "PATCH"):
                    post_body = req.post_data
            except Exception:
                pass
            captured.append({
                "type": "request",
                "method": req.method,
                "url": req.url,
                "headers": dict(req.headers),
                "post_data": post_body[:5000] if post_body else None,
                "time": time.time(),
            })
        except Exception as e:
            print(f"  [capture error] {e}")

    def on_response(resp):
        try:
            if should_skip(resp.url):
                return
            body_preview = None
            try:
                ct = resp.headers.get("content-type", "")
                if "json" in ct or "text" in ct:
                    body = resp.body()
                    body_preview = body[:5000].decode("utf-8", errors="replace") if body else None
            except Exception:
                pass
            captured.append({
                "type": "response",
                "status": resp.status,
                "url": resp.url,
                "headers": dict(resp.headers),
                "body_preview": body_preview,
                "time": time.time(),
            })
        except Exception as e:
            print(f"  [capture error] {e}")

    with sync_playwright() as pw:
        launch_kwargs = {
            "headless": not args.headed,
            "viewport": {"width": 1400, "height": 900},
            "args": ["--disable-blink-features=AutomationControlled"],
        }
        if args.use_system_chrome:
            launch_kwargs["channel"] = "chrome"
        print(f"Launching browser (persistent profile: {PROFILE_DIR})...")
        ctx = pw.chromium.launch_persistent_context(PROFILE_DIR, **launch_kwargs)
        page = ctx.new_page()

        page.on("request", on_request)
        page.on("response", on_response)

        print(f"Navigating to {STUDIO_URL}...")
        try:
            page.goto(STUDIO_URL, wait_until="domcontentloaded", timeout=60000)
        except Exception as e:
            print(f"  nav issue (not fatal): {e}")

        print()
        print("=" * 70)
        print("NOW DO THIS IN THE BROWSER WINDOW:")
        print("=" * 70)
        print("1. If not logged in, log into Tripo Studio")
        print("2. Go to the Generate page / your workspace")
        print("3. Trigger ONE 3D generation — any prompt, click Generate")
        print("4. Wait for it to start (not necessarily finish)")
        print("5. Come back to THIS terminal window and press Enter")
        print("=" * 70)
        print()
        input("Press Enter when done to save the capture and exit... ")

        print(f"\nCaptured {len(captured)} non-static network events")
        CAPTURE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CAPTURE_FILE, "w", encoding="utf-8") as f:
            json.dump(captured, f, indent=2, ensure_ascii=False)
        print(f"Saved to: {CAPTURE_FILE}")

        ctx.close()


if __name__ == "__main__":
    main()
