"""
Generate videos via Grok Imagine using a persistent Playwright Chromium session.

Why Playwright?
    Grok's REST chat endpoint is protected by Cloudflare anti-bot AND xAI's
    own statsig-id signing (computed in the frontend per-request). A plain
    Python `requests` call gets 403 "Request rejected by anti-bot rules"
    every time. Playwright drives a real Chromium so:
      - Cloudflare cf_clearance cookies are issued + rotated naturally
      - The page's fetch() interceptor adds x-statsig-id automatically
      - We submit the video gen request via page.evaluate(() => fetch(...))

Auth: We don't OAuth (Google blocks automation). Instead, we INJECT the
sso/sso-rw cookies from grok_download_history.json into the Playwright
context. Cloudflare then issues fresh cf_clearance/__cf_bm naturally on
the first navigation. The persistent profile keeps everything across runs.

Usage:
    python grok_generate_video.py -d "your prompt"
    python grok_generate_video.py -d "ocean waves" --aspect 16:9 --length 10 --resolution 720p

If the sso cookies in grok_download_history.json expire, refresh them by
logging into grok.com in your real Chrome and re-exporting that file.
"""
import argparse
import json
import os
import sys
import time
import uuid
from pathlib import Path

from playwright.sync_api import sync_playwright

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(_SCRIPT_DIR, "grok_download_history.json")
PROFILE_DIR = str(Path.home() / ".grok-playwright")
LOGIN_URL = "https://grok.com/imagine"


def _load_sso_cookies():
    """Read sso/sso-rw and other auth cookies from the existing history file."""
    if not os.path.isfile(HISTORY_FILE):
        return None
    with open(HISTORY_FILE, encoding="utf-8") as f:
        cached = json.load(f).get("cached_cookies", {})
    if not cached.get("sso"):
        return None
    # Build playwright cookie objects. Most cookies live on .grok.com (root).
    # cf_clearance / __cf_bm are scoped to grok.com (no leading dot).
    cookies = []
    for k, v in cached.items():
        if not v:
            continue
        cookies.append({
            "name": k,
            "value": str(v),
            "domain": ".grok.com",
            "path": "/",
            "secure": True,
            "httpOnly": k in ("sso", "sso-rw", "cf_clearance", "__cf_bm"),
            "sameSite": "None",
        })
    return cookies


def generate_video(prompt: str, aspect_ratio: str, video_length: int, resolution: str,
                    headless: bool = True) -> bool:
    """Drive the grok.com/imagine UI to submit a video generation request.

    We click through the actual interface (Video tab → prompt input → Send button)
    so the page's own JS makes the API call with proper x-statsig-id signing.
    Then we walk away. Grok auto-favorites the result and the user's
    favorites downloader extension picks it up.
    """
    print(f"Launching Chromium (headless={headless})...")
    with sync_playwright() as pw:
        ctx = pw.chromium.launch_persistent_context(
            PROFILE_DIR,
            headless=headless,
            viewport={"width": 1280, "height": 900},
            args=[
                "--disable-blink-features=AutomationControlled",
                "--disable-features=IsolateOrigins,site-per-process",
            ],
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
            ),
        )

        sso_cookies = _load_sso_cookies()
        if sso_cookies:
            try:
                ctx.add_cookies(sso_cookies)
                print(f"  Injected {len(sso_cookies)} cookies")
            except Exception as e:
                print(f"  Cookie inject warning: {e}")

        page = ctx.new_page()

        # Capture outgoing chat-API requests so we can confirm submission
        captured_requests = []
        def on_request(req):
            url = req.url
            if "/rest/app-chat/conversations" in url or "/rest/imagine" in url:
                captured_requests.append({"url": url, "method": req.method})

        page.on("request", on_request)

        print(f"Navigating to {LOGIN_URL}...")
        page.goto(LOGIN_URL, wait_until="networkidle", timeout=60000)

        body_text = page.evaluate("() => document.body.innerText")
        if "Oturum aç" in body_text and "Üye ol" in body_text and "Imagine" not in body_text:
            print("ERROR: Not logged in. Refresh sso cookies in grok_download_history.json")
            ctx.close()
            return False

        # Dismiss the OneTrust cookie consent banner if present
        # (it intercepts pointer events on everything below it)
        try:
            page.evaluate("""() => {
                const banner = document.getElementById('onetrust-consent-sdk');
                if (banner) banner.remove();
            }""")
            print("  Dismissed cookie consent banner")
        except Exception:
            pass

        print("Logged in. Switching to Video mode...")

        # Step 1: Click the Video tab
        # The tab is a button with text "Video" (Turkish UI shows the same word)
        try:
            video_tab = page.get_by_role("button", name="Video", exact=True).first
            video_tab.click(timeout=5000)
            print("  Clicked Video tab")
        except Exception as e:
            # Fallback: try by text
            try:
                page.get_by_text("Video", exact=True).first.click(timeout=5000)
                print("  Clicked Video (by text fallback)")
            except Exception as e2:
                print(f"  WARNING: Could not click Video tab ({e2}). May already be selected.")

        time.sleep(1)

        # Step 2: Click the prompt input (contenteditable div) and type the prompt
        print("  Typing prompt...")
        # Find the contenteditable div near the bottom
        prompt_box = page.locator('div[contenteditable="true"]').first
        prompt_box.click(timeout=5000)
        time.sleep(0.3)
        page.keyboard.type(prompt, delay=15)
        time.sleep(0.5)

        # Step 3: Click the submit button
        # The button has aria-label="Gönder" (Turkish for "Send")
        print("  Submitting...")
        try:
            send_btn = page.get_by_role("button", name="Gönder").first
            send_btn.click(timeout=5000)
            print("  Clicked Gönder (send)")
        except Exception:
            # Fallback: press Enter in the prompt box
            print("  Could not find Gönder button, pressing Enter")
            prompt_box.focus()
            page.keyboard.press("Enter")

        # Step 4: Wait for the request to actually fire to the chat API
        print("  Waiting for chat-API request to fire...")
        deadline = time.time() + 15
        while time.time() < deadline and not captured_requests:
            time.sleep(0.3)

        if captured_requests:
            print(f"  >>> Captured {len(captured_requests)} chat-API request(s):")
            for r in captured_requests[:5]:
                print(f"      {r['method']} {r['url']}")
        else:
            print("  WARNING: No chat-API request was captured within 15s.")
            print("  The submit click may not have triggered. Re-run with --show-browser to debug.")
            page.screenshot(path=str(Path.home() / "grok_video_debug.png"))
            print(f"  Screenshot saved: {Path.home() / 'grok_video_debug.png'}")
            ctx.close()
            return False

        # Step 5: Wait a bit longer to let the streaming response start
        print("  Letting the request settle for 5s...")
        time.sleep(5)

        ctx.close()
        return True


def main():
    parser = argparse.ArgumentParser(description="Generate videos with Grok Imagine via Playwright")
    parser.add_argument("--description", "-d", required=True, help="Video description/prompt")
    parser.add_argument("--aspect", default="16:9", choices=["2:3", "3:2", "16:9", "9:16", "1:1"])
    parser.add_argument("--resolution", default="720p", choices=["480p", "720p"])
    parser.add_argument("--length", type=int, default=6, choices=[6, 10], help="Video length in seconds")
    parser.add_argument("--show-browser", action="store_true",
                        help="Run in a visible browser window (helpful for debugging)")
    args = parser.parse_args()

    ok = generate_video(args.description, args.aspect, args.length, args.resolution,
                          headless=not args.show_browser)
    if ok:
        print("\nVideo generation request submitted successfully.")
        print("Grok will auto-favorite the result. Run your favorites downloader")
        print("extension on grok.com/imagine/favorites to fetch it.")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
