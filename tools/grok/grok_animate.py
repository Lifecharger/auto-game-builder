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
    4. Tool keeps the page open, grabs the rendered mp4 URL off it, and downloads
       the video directly to --output (default: the r2manager Incoming folder)

Retrieval deliberately does NOT use favorites / grok_downloader.py. That path
scrapes grok.com/imagine/saved and breaks every time Grok reworks that UI.

Usage:
    python grok_animate.py -i character.png -d "idle breathing"
    python grok_animate.py -i char.png -d "punch attack" --length 10 --resolution 720p
    python grok_animate.py -i char.png -d "hair in the wind" -o out/467.mp4 --show-browser

Defaults: 6s / 480p (cheapest = fastest = least credits)
"""
import argparse
import json
import os
import re
import sys
import tempfile
import time
import uuid
from pathlib import Path

from playwright.sync_api import sync_playwright

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(_SCRIPT_DIR, "grok_download_history.json")
PROFILE_DIR = str(Path.home() / ".grok-playwright")
IMAGINE_URL = "https://grok.com/imagine"

# Rendered videos land in the r2manager Incoming folder, same as generated images.
OUTPUT_DIR = os.environ.get("GROK_OUTPUT_DIR") or os.path.join(
    os.path.expanduser("~"), "Desktop", "Asset Generation Pipeline", "_Incoming"
)


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


# A finished render lives at
# assets.grok.com/users/<uid>/generated/<uuid>/generated_video.mp4
# Anything else on the page (media.x.ai promos, storage.googleapis.com
# agent-skill covers) is decoration and must never be picked up.
GENERATED_VIDEO_RE = re.compile(
    r"assets\.grok\.com/.+/generated/[^/]+/generated_video\.mp4", re.I
)

# Grayscale MSE between an i2v result's first frame and the still it was made
# from. Measured on real Hot Jigsaw renders: true pairs scored 191 and 631,
# unrelated clips 6609, 14398 and 15589. The threshold sits in the middle of
# that 10x gap, so it tolerates i2v drift without ever accepting a stray clip.
FIRST_FRAME_MSE_MAX = 2000

REFUSAL_PHRASES = (
    "can't help", "cannot help", "can't generate", "cannot generate",
    "unable to generate", "violates", "content policy", "guidelines",
    "not allowed", "inappropriate", "flagged",
)


def _first_frame_mse(video_path: str, image_path: str) -> float | None:
    """Grayscale MSE between the video's first frame and the source still.

    Returns None if the comparison can't be made (missing cv2, unreadable file),
    which callers must treat as "unverified", not as "match".
    """
    try:
        import cv2
        import numpy as np
    except ImportError:
        return None

    cap = cv2.VideoCapture(video_path)
    ok, frame = cap.read()
    cap.release()
    if not ok:
        return None
    src = cv2.imread(image_path)
    if src is None:
        return None

    size = (128, 256)
    a = cv2.cvtColor(cv2.resize(frame, size), cv2.COLOR_BGR2GRAY).astype("float32")
    b = cv2.cvtColor(cv2.resize(src, size), cv2.COLOR_BGR2GRAY).astype("float32")
    return float(np.mean((a - b) ** 2))


def _dom_video_srcs(page):
    """Any <video>/<source> src currently in the DOM (blob: URLs filtered out)."""
    try:
        srcs = page.eval_on_selector_all(
            "video, video source",
            "els => els.map(e => e.currentSrc || e.src).filter(Boolean)",
        )
    except Exception:
        return []
    return [s for s in srcs if s.startswith("http") and ".mp4" in s.lower()]


def animate(image_path: str, prompt: str, video_length: int = 6,
            resolution: str = "480p", headless: bool = True,
            output_path: str | None = None, wait_seconds: int = 240) -> str | None:
    """Submit an i2v job and download the rendered video directly.

    Returns the saved video path, or None on failure.

    The result is pulled straight off the generation page — we do NOT go through
    favorites/grok_downloader.py, which depends on scraping grok.com/imagine/saved
    and breaks whenever that UI changes.
    """
    image_path = os.path.abspath(image_path)
    if not os.path.isfile(image_path):
        print(f"ERROR: Image not found: {image_path}")
        return None

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

        # Collect every rendered .mp4 the page pulls, in arrival order. This is
        # how we get the result without touching favorites.
        video_urls: list[str] = []
        def on_response(resp):
            url = resp.url
            if ".mp4" in url.lower() and url.startswith("http") and url not in video_urls:
                video_urls.append(url)
        page.on("response", on_response)

        print(f"Navigating to {IMAGINE_URL}...")
        page.goto(IMAGINE_URL, wait_until="load", timeout=60000)

        # Dismiss ALL cookie consent banners. Grok keeps inventing new ones —
        # this purges every variant we've seen plus a generic text-match fallback.
        # Also dismiss the Radix dialog-portal overlay (upgrade/announcement modals)
        # which intercepts pointer events and blocks every click below it.
        # The OneTrust SDK observes the DOM and re-injects its banner after
        # removal. Solution: kill the elements AND inject a permanent style
        # rule that hides + disables pointer events on any future re-injections.
        page.add_style_tag(content="""
            #onetrust-consent-sdk, #onetrust-button-group, #onetrust-banner-sdk,
            #CybotCookiebotDialog, [data-nosnippet="true"],
            [data-cookie-banner="true"] { display: none !important; pointer-events: none !important; }
            #dialog-portal { pointer-events: none !important; }
            body { pointer-events: auto !important; overflow: auto !important; }
        """)
        page.evaluate("""() => {
            ['onetrust-consent-sdk', 'onetrust-button-group', 'onetrust-banner-sdk',
             'CybotCookiebotDialog', 'dialog-portal'].forEach(id => {
                const el = document.getElementById(id);
                if (el) { try { el.remove(); } catch(e) { el.style.display='none'; el.style.pointerEvents='none'; } }
            });
            document.querySelectorAll('[data-cookie-banner="true"]').forEach(el => el.remove());
            document.querySelectorAll('[role="dialog"]').forEach(el => el.remove());
            document.querySelectorAll('[data-state="open"][aria-hidden="true"]').forEach(el => el.remove());
            document.querySelectorAll('[data-nosnippet="true"]').forEach(el => el.remove());
            const consentTextRe = /Tümünü Reddet|Reject All|Accept All|Tüm Tanımlama|Cookie/i;
            document.querySelectorAll('div, section, aside').forEach(el => {
                const cs = window.getComputedStyle(el);
                if (cs.position !== 'fixed') return;
                if (consentTextRe.test(el.innerText || '')) {
                    const r = el.getBoundingClientRect();
                    if (r.width < 700 && r.height < 600) el.remove();
                }
            });
            document.body.style.pointerEvents = 'auto';
            document.body.style.overflow = 'auto';
            document.body.removeAttribute('data-scroll-locked');
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
        # (name="files") which is the multi-ref-i2i path for animation references.
        # Wait for it to mount: the file input is added to the DOM by React after
        # the Video mode switch, and .count() does NOT auto-wait.
        print(f"Uploading {os.path.basename(image_path)}...")
        try:
            file_input = page.locator('input[type="file"][name="files"]').first
            file_input.wait_for(state="attached", timeout=15000)
            file_input.set_input_files(image_path, timeout=15000)
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
        # Everything the page has loaded up to now is furniture: Grok's own promo
        # clips plus the gallery of past generations. Only URLs that appear AFTER
        # this line can be our result.
        pre_submit_urls = set(video_urls) | set(_dom_video_srcs(page))
        print(f"Baseline: {len(pre_submit_urls)} pre-existing video URL(s) on the page")

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
            return None

        # Wait for renders that were not already on the page before we submitted.
        # Grok makes an unprompted baseline clip from the uploaded still on top of
        # the prompted one, so expect up to two; we keep waiting through a quiet
        # period so the prompted result (the slower of the two) is included.
        def fresh():
            pool = list(dict.fromkeys(video_urls + _dom_video_srcs(page)))
            return [u for u in pool
                    if u not in pre_submit_urls and GENERATED_VIDEO_RE.search(u)]

        print(f"Waiting up to {wait_seconds}s for a new render...")
        deadline = time.time() + wait_seconds
        seen_count = 0
        settle_until = None
        while time.time() < deadline:
            found = fresh()
            if len(found) > seen_count:
                seen_count = len(found)
                print(f"  {seen_count} new render(s) seen; waiting for stragglers...")
                settle_until = time.time() + 25
            elif found and settle_until and time.time() > settle_until:
                break
            time.sleep(2)

        candidates = fresh()
        if not candidates:
            page_text = ""
            try:
                page_text = (page.inner_text("body") or "").lower()
            except Exception:
                pass
            hit = next((p for p in REFUSAL_PHRASES if p in page_text), None)
            if hit:
                print(f"\nREFUSED: Grok declined this prompt (matched '{hit}').")
            else:
                print("\nFAILED: no new render appeared before the timeout.")
            page.screenshot(path=str(Path.home() / "grok_animate_debug.png"))
            print(f"Debug screenshot: {Path.home() / 'grok_animate_debug.png'}")
            ctx.close()
            return None

        print(f"{len(candidates)} new render(s) to verify (newest first):")

        if output_path:
            dest = Path(os.path.abspath(output_path))
        else:
            dest = Path(OUTPUT_DIR) / f"{Path(image_path).stem}.mp4"
        dest.parent.mkdir(parents=True, exist_ok=True)

        # Newest first: the prompted render finishes after the auto baseline clip.
        for url in reversed(candidates):
            short = url.split("/generated/")[-1][:36]
            try:
                resp = ctx.request.get(url, timeout=120000)
                if not resp.ok:
                    print(f"  [{short}] HTTP {resp.status} — skipping")
                    continue
                body = resp.body()
            except Exception as e:
                print(f"  [{short}] download failed: {e} — skipping")
                continue

            if len(body) < 10000:
                print(f"  [{short}] only {len(body)} bytes — skipping")
                continue

            tmp = Path(tempfile.gettempdir()) / f"grok_verify_{uuid.uuid4().hex}.mp4"
            tmp.write_bytes(body)
            try:
                mse = _first_frame_mse(str(tmp), image_path)
                if mse is None:
                    print(f"  [{short}] UNVERIFIED (cv2 unavailable or unreadable) — "
                          f"accepting on position alone")
                elif mse > FIRST_FRAME_MSE_MAX:
                    print(f"  [{short}] MSE {mse:.0f} — not from this image, skipping")
                    continue
                else:
                    print(f"  [{short}] MSE {mse:.0f} — verified match")

                dest.write_bytes(body)
            finally:
                tmp.unlink(missing_ok=True)

            print(f"Saved {len(body) // 1024} KB -> {dest}")
            ctx.close()
            return str(dest)

        print("\nFAILED: new renders appeared but none came from this image.")
        ctx.close()
        return None


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
    parser.add_argument("--output", "-o",
                        help=f"Where to write the mp4 (default: {OUTPUT_DIR}\\<image-stem>.mp4)")
    parser.add_argument("--wait-seconds", type=int, default=240,
                        help="How long to wait for the render before giving up (default 240s)")
    args = parser.parse_args()

    saved = animate(args.image, args.description, args.length, args.resolution,
                    headless=not args.show_browser, output_path=args.output,
                    wait_seconds=args.wait_seconds)
    if not saved:
        sys.exit(1)

    print(f"\nDone: {saved}")


if __name__ == "__main__":
    main()
