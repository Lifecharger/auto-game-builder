"""
Animate a character image using Grok Imagine's image-to-video.

CRITICAL — INPUT IMAGE ASPECT RATIO:
    The base image MUST be 16:9 (preferred) or 1:1 (square). NEVER 9:16
    portrait. Grok i2v preserves the input frame's aspect ratio in the
    output video, so a tall narrow base leaves no horizontal room for
    sword swings, walk cycles, jump arcs — limbs/weapons fall out of
    frame and the animation looks cropped. This was a hard-learned lesson.

    When you generate the base via grok_generate_image.py:
        --aspect 16:9   ← USE THIS for side-scroller character sheets
        --aspect 1:1    ← acceptable compromise (top-down or isometric)
        --aspect 9:16   ← ONLY for static portraits / store screenshots,
                          never for things that will be animated

Workflow:
    1. Generate base with grok_generate_image.py --pro --aspect 16:9
    2. Pass the local PNG to this tool with an animation prompt
    3. Tool uploads to Grok, sets 6s + 480p (cheapest), submits via UI
    4. Grok auto-favorites the input + output
    5. (default) After --wait-seconds, runs grok_downloader to fetch result
       to ~/Downloads/grok-favorites/

Usage:
    python grok_animate.py -i character.png -d "idle breathing"
    python grok_animate.py -i char.png -d "punch attack" --length 10 --resolution 720p
    python grok_animate.py -i char.png -d "walk cycle" --no-download --show-browser

Defaults: 6s / 480p (cheapest = fastest = least credits)
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


def animate(image_path: str, prompt: str, video_length: int = 6,
            resolution: str = "480p", headless: bool = True) -> bool:
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

        # Watch for the key requests that confirm the generation actually fired
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

        # Dismiss ALL cookie consent banners. Grok keeps inventing new ones —
        # this purges every variant we've seen plus a generic text-match fallback.
        page.evaluate("""() => {
            // Known IDs / data attributes
            ['onetrust-consent-sdk', 'CybotCookiebotDialog'].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.remove();
            });
            document.querySelectorAll('[data-cookie-banner="true"]').forEach(el => el.remove());
            // Generic fallback: any fixed-position dialog containing the words
            // "Tümünü Reddet" / "Reject All" / "Accept All" / "Tüm Tanımlama"
            const consentTextRe = /Tümünü Reddet|Reject All|Accept All|Tüm Tanımlama|Cookie/i;
            document.querySelectorAll('div, section, aside').forEach(el => {
                const cs = window.getComputedStyle(el);
                if (cs.position !== 'fixed') return;
                if (consentTextRe.test(el.innerText || '')) {
                    // Only remove if it's small (a popup, not the whole page)
                    const r = el.getBoundingClientRect();
                    if (r.width < 700 && r.height < 600) el.remove();
                }
            });
        }""")
        time.sleep(1)

        body_text = page.evaluate("() => document.body.innerText")
        if "Oturum aç" in body_text and "Üye ol" in body_text and "Imagine" not in body_text[:100]:
            print("ERROR: Not logged in. Refresh sso cookies in grok_download_history.json")
            ctx.close()
            return False

        # Step 1: Switch to Video mode
        print("Switching to Video mode...")
        try:
            # The Video tab is a [role="radio"] inside the "Oluşturma modu" radiogroup
            page.locator('[role="radiogroup"][aria-label="Oluşturma modu"] [role="radio"]').filter(has_text="Video").click(timeout=5000)
            time.sleep(0.5)
            print("  Switched to Video mode")
        except Exception as e:
            print(f"  WARNING: Could not click Video tab ({e})")

        # Step 2: Set duration if not default (6s)
        if video_length != 6:
            try:
                page.locator('[role="radiogroup"][aria-label="Video Süresi"] [role="radio"]').filter(has_text=f"{video_length}s").click(timeout=3000)
                time.sleep(0.3)
                print(f"  Set duration to {video_length}s")
            except Exception:
                print(f"  WARNING: Could not set duration to {video_length}s")

        # Step 3: Set resolution if not default (480p)
        if resolution != "480p":
            try:
                page.locator('[role="radiogroup"][aria-label="Video Çözünürlüğü"] [role="radio"]').filter(has_text=resolution).click(timeout=3000)
                time.sleep(0.3)
                print(f"  Set resolution to {resolution}")
            except Exception:
                print(f"  WARNING: Could not set resolution to {resolution}")

        # Step 4: Upload the image via the file input — use the MULTI input
        # (name="files") which is the multi-ref-i2i path for animation references
        print(f"Uploading {os.path.basename(image_path)}...")
        try:
            file_input = page.locator('input[type="file"][name="files"]').first
            if file_input.count() == 0:
                file_input = page.locator('input[type="file"][accept*="image"]').first
            file_input.set_input_files(image_path, timeout=10000)
            print("  Upload triggered, waiting for upload-file to complete...")
            # Wait for upload-file to complete. media/post/create fires later
            # as part of the submit chain, not the upload chain.
            upload_deadline = time.time() + 30
            while time.time() < upload_deadline:
                if "/rest/app-chat/upload-file" in seen_endpoints:
                    break
                time.sleep(0.3)
            time.sleep(2)  # buffer for React state + thumbnail render
            print("  Image attached")
        except Exception as e:
            print(f"  ERROR: Could not upload image: {e}")
            page.screenshot(path=str(Path.home() / "grok_animate_debug.png"))
            ctx.close()
            return False

        # Step 5: Type the animation prompt into the contenteditable input
        print(f"Typing prompt: {prompt!r}")
        prompt_box = page.locator('div[contenteditable="true"]').first
        prompt_box.click(timeout=5000)
        time.sleep(0.3)
        page.keyboard.type(prompt, delay=15)
        time.sleep(1)

        # Step 6: Submit. Try multiple strategies because React forms can ignore
        # clicks if state isn't fully synced. Strategy order:
        #   1. Click the submit button directly
        #   2. Ctrl+Enter (chat-app standard shortcut)
        #   3. Programmatic form.requestSubmit()
        print("Submitting...")

        def _submitted():
            return "/rest/app-chat/conversations/new" in seen_endpoints

        # Strategy 1: click the button
        try:
            page.locator('button[type="submit"][aria-label="Gönder"]').first.click(
                timeout=4000, force=True
            )
            print("  [strategy 1] Clicked submit button")
        except Exception as e:
            print(f"  [strategy 1] Click failed: {e}")

        time.sleep(2)
        if not _submitted():
            # Strategy 2: Ctrl+Enter from prompt
            print("  [strategy 2] Ctrl+Enter in prompt input")
            prompt_box.focus()
            page.keyboard.press("Control+Enter")
            time.sleep(2)

        if not _submitted():
            # Strategy 3: programmatic form submit
            print("  [strategy 3] form.requestSubmit() via JS")
            page.evaluate("""() => {
                const btn = document.querySelector('button[type="submit"][aria-label="Gönder"]');
                if (!btn) return 'no button';
                const form = btn.closest('form');
                if (!form) return 'no form';
                if (form.requestSubmit) {
                    form.requestSubmit();
                    return 'requestSubmit fired';
                } else {
                    form.submit();
                    return 'submit fired';
                }
            }""")
            time.sleep(2)

        # Wait for the canonical success-chain endpoints to all fire
        print("Waiting for generation request + auto-favorite...")
        deadline = time.time() + 30
        target_endpoints = {
            "/rest/app-chat/conversations/new",
            "/rest/media/post/like",
        }
        while time.time() < deadline and not target_endpoints.issubset(seen_endpoints):
            time.sleep(0.5)

        for ep in ["/rest/app-chat/upload-file", "/rest/media/post/create",
                   "/rest/app-chat/conversations/new", "/rest/media/post/like"]:
            mark = "OK" if ep in seen_endpoints else "MISSING"
            print(f"  [{mark}] {ep}")

        if "/rest/app-chat/conversations/new" not in seen_endpoints:
            print("\nERROR: Generation request never fired. Submit failed silently.")
            page.screenshot(path=str(Path.home() / "grok_animate_debug.png"))
            print(f"Debug screenshot: {Path.home() / 'grok_animate_debug.png'}")
            ctx.close()
            return False

        # Let the request complete
        print("Letting the server start processing for 5s...")
        time.sleep(5)
        ctx.close()
        return True


def main():
    parser = argparse.ArgumentParser(description="Animate a character image via Grok image-to-video")
    parser.add_argument("--image", "-i", required=True, help="Path to local image (PNG/JPG)")
    parser.add_argument("--description", "-d", required=True, help="Animation prompt (e.g. 'punch attack')")
    parser.add_argument("--length", type=int, default=6, choices=[6, 10],
                        help="Video length in seconds (default 6 = cheapest)")
    parser.add_argument("--resolution", default="480p", choices=["480p", "720p"],
                        help="Video resolution (default 480p = cheapest)")
    parser.add_argument("--show-browser", action="store_true",
                        help="Show the browser window (debugging)")
    parser.add_argument("--no-download", action="store_true",
                        help="Skip the auto-download step (you'll need to run grok_downloader.py manually)")
    parser.add_argument("--wait-seconds", type=int, default=120,
                        help="How long to wait before running the downloader (default 120s for video)")
    args = parser.parse_args()

    ok = animate(args.image, args.description, args.length, args.resolution,
                 headless=not args.show_browser)
    if not ok:
        sys.exit(1)

    print("\nAnimation request submitted.")
    if args.no_download:
        print("Skipping auto-download (--no-download). Run grok_downloader.py to fetch.")
        return

    print(f"Waiting {args.wait_seconds}s for Grok to render the video...")
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
