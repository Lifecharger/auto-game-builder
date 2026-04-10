"""
Image-to-image with Grok Imagine — for character consistency across views.

The use case this is built for:
    1. Generate a base character with grok_generate_image.py --pro
       (e.g. south-facing pixel art warrior)
    2. Use this tool to derive the OTHER directional views from that single base:
        - "same character, west facing"
        - "same character, east facing"
        - "same character, north facing / back view"
    3. Each derivation preserves character consistency because Grok uses the
       reference image to keep face/colors/outfit identical across angles.
    4. THEN animate each directional view with grok_animate.py (i2v).

How it works:
    - Drives grok.com/imagine via Playwright (persistent profile + sso cookies)
    - Switches to Görsel (Image) mode — NOT Video mode
    - Uploads the base image as a reference via the file input
    - Types the variation prompt
    - Submits via Ctrl+Enter (button click silently fails in headless React)
    - Walks away. Result auto-favorites in your library so the favorites
      downloader Chrome extension picks it up.

Usage:
    python grok_i2i.py -i base_south.png -d "same character, west facing"
    python grok_i2i.py -i base_south.png -d "same character, north facing back view"
    python grok_i2i.py -i base.png -d "same character, attack pose, sword raised"
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(_SCRIPT_DIR, "grok_download_history.json")
PROFILE_DIR = str(Path.home() / ".grok-playwright")
IMAGINE_URL = "https://grok.com/imagine"


def _load_sso_cookies():
    if not os.path.isfile(HISTORY_FILE):
        return None
    with open(HISTORY_FILE, encoding="utf-8") as f:
        cached = json.load(f).get("cached_cookies", {})
    if not cached.get("sso"):
        return None
    return [
        {
            "name": k, "value": str(v), "domain": ".grok.com",
            "path": "/", "secure": True,
            "httpOnly": k in ("sso", "sso-rw", "cf_clearance", "__cf_bm"),
            "sameSite": "None",
        }
        for k, v in cached.items() if v
    ]


def i2i(image_path: str, prompt: str, headless: bool = True) -> bool:
    image_path = os.path.abspath(image_path)
    if not os.path.isfile(image_path):
        print(f"ERROR: Image not found: {image_path}")
        return False

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

        seen_endpoints = set()
        def on_request(req):
            if req.method != "POST": return
            for sig in ("/rest/app-chat/upload-file", "/rest/media/post/create",
                          "/rest/app-chat/conversations/new", "/rest/media/post/like"):
                if sig in req.url:
                    seen_endpoints.add(sig)
        page.on("request", on_request)

        print(f"Navigating to {IMAGINE_URL}...")
        page.goto(IMAGINE_URL, wait_until="networkidle", timeout=60000)

        # Dismiss both cookie consent banners
        page.evaluate("""() => {
            ['onetrust-consent-sdk'].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.remove();
            });
            document.querySelectorAll('[data-cookie-banner="true"]').forEach(el => el.remove());
        }""")
        time.sleep(1)

        body_text = page.evaluate("() => document.body.innerText")
        if "Oturum aç" in body_text and "Üye ol" in body_text and "Imagine" not in body_text[:100]:
            print("ERROR: Not logged in. Refresh sso cookies in grok_download_history.json")
            ctx.close()
            return False

        # Step 1: Switch to GÖRSEL (Image) mode — opposite of grok_animate.py
        print("Switching to Görsel (Image) mode...")
        try:
            page.locator(
                '[role="radiogroup"][aria-label="Oluşturma modu"] [role="radio"]'
            ).filter(has_text="Görsel").click(timeout=5000)
            time.sleep(0.5)
            print("  Switched to Image mode")
        except Exception as e:
            print(f"  WARNING: Could not click Görsel tab ({e}); may already be selected")

        # Step 2: Upload the base image
        print(f"Uploading {os.path.basename(image_path)}...")
        try:
            file_input = page.locator('input[type="file"][name="files"]').first
            if file_input.count() == 0:
                file_input = page.locator('input[type="file"][accept*="image"]').first
            file_input.set_input_files(image_path, timeout=10000)
            print("  Upload triggered, waiting for upload-file to complete...")
            upload_deadline = time.time() + 30
            while time.time() < upload_deadline:
                if "/rest/app-chat/upload-file" in seen_endpoints:
                    break
                time.sleep(0.3)
            time.sleep(2)
            print("  Image attached")
        except Exception as e:
            print(f"  ERROR: Could not upload image: {e}")
            page.screenshot(path=str(Path.home() / "grok_i2i_debug.png"))
            ctx.close()
            return False

        # Step 3: Type prompt
        print(f"Typing prompt: {prompt!r}")
        prompt_box = page.locator('div[contenteditable="true"]').first
        prompt_box.click(timeout=5000)
        time.sleep(0.3)
        page.keyboard.type(prompt, delay=15)
        time.sleep(1)

        # Step 4: Submit (multi-strategy — Ctrl+Enter is the reliable one)
        print("Submitting...")
        try:
            page.locator('button[type="submit"][aria-label="Gönder"]').first.click(
                timeout=4000, force=True
            )
        except Exception:
            pass

        time.sleep(2)
        if "/rest/app-chat/conversations/new" not in seen_endpoints:
            prompt_box.focus()
            page.keyboard.press("Control+Enter")
            time.sleep(2)

        if "/rest/app-chat/conversations/new" not in seen_endpoints:
            page.evaluate("""() => {
                const btn = document.querySelector('button[type="submit"][aria-label="Gönder"]');
                if (btn) {
                    const form = btn.closest('form');
                    if (form && form.requestSubmit) form.requestSubmit();
                }
            }""")
            time.sleep(2)

        # Wait for the success-chain endpoints
        print("Waiting for generation request + auto-favorite...")
        deadline = time.time() + 30
        target = {
            "/rest/app-chat/conversations/new",
            "/rest/media/post/like",
        }
        while time.time() < deadline and not target.issubset(seen_endpoints):
            time.sleep(0.5)

        for ep in ["/rest/app-chat/upload-file", "/rest/media/post/create",
                   "/rest/app-chat/conversations/new", "/rest/media/post/like"]:
            mark = "OK" if ep in seen_endpoints else "MISSING"
            print(f"  [{mark}] {ep}")

        if "/rest/app-chat/conversations/new" not in seen_endpoints:
            print("\nERROR: Generation request never fired. Submit failed silently.")
            page.screenshot(path=str(Path.home() / "grok_i2i_debug.png"))
            ctx.close()
            return False

        time.sleep(3)
        ctx.close()
        return True


def main():
    parser = argparse.ArgumentParser(
        description="Image-to-image with Grok Imagine — for character consistency across views"
    )
    parser.add_argument("--image", "-i", required=True,
                        help="Path to base image (PNG/JPG) — the reference for the variation")
    parser.add_argument("--description", "-d", required=True,
                        help='Variation prompt, e.g. "same character, west facing"')
    parser.add_argument("--show-browser", action="store_true",
                        help="Show the browser window (debugging)")
    parser.add_argument("--no-download", action="store_true",
                        help="Skip the auto-download step")
    parser.add_argument("--wait-seconds", type=int, default=45,
                        help="How long to wait before running the downloader (default 45s for image)")
    args = parser.parse_args()

    ok = i2i(args.image, args.description, headless=not args.show_browser)
    if not ok:
        sys.exit(1)

    print("\nImage-to-image request submitted.")
    if args.no_download:
        print("Skipping auto-download (--no-download). Run grok_downloader.py to fetch.")
        return

    print(f"Waiting {args.wait_seconds}s for Grok to render the image...")
    time.sleep(args.wait_seconds)
    print("Running downloader...")
    from grok_downloader import GrokDownloader
    result = GrokDownloader().run(since_hours=0.5)
    if result.get("ok"):
        print(f"Downloaded {result.get('new_downloads', 0)} new items to {result.get('folder', '?')}")
    else:
        print(f"Downloader error: {result.get('error', '?')}")
        sys.exit(1)


if __name__ == "__main__":
    main()
