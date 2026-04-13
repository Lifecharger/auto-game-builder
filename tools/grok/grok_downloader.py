"""Grok Favorites Auto-Downloader.

Calls Grok REST API to fetch favorited (liked) media and downloads new items.
Uses browser-cookie3 to read fresh cookies from your real Chrome each run,
which keeps cf_clearance + sso valid (no anti-bot 403).

Tracks history in grok_download_history.json so it never re-downloads.

CLI usage:
    python grok_downloader.py                # download new items from last 3 days
    python grok_downloader.py --since-hours 1  # only items from the last hour
    python grok_downloader.py --dry-run      # list what would be downloaded
    python grok_downloader.py --seed         # mark all current favorites as
                                             # already-downloaded (first-time setup
                                             # so you don't grab months of backlog)

Library usage (called from other tools after a wait):
    from grok_downloader import GrokDownloader
    GrokDownloader().run(since_hours=1)
"""
import argparse
import json
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

try:
    import browser_cookie3
    HAVE_BC3 = True
except ImportError:
    HAVE_BC3 = False

_SCRIPT_DIR = Path(__file__).parent.resolve()
HISTORY_FILE = _SCRIPT_DIR / "grok_download_history.json"
DOWNLOADS_DIR = Path(os.path.expanduser("~")) / "Downloads" / "grok-favorites"
GROK_API_URL = "https://grok.com/rest/media/post/list"


class GrokDownloader:
    def __init__(self):
        self._history = self._load_history()
        self._running = False
        self._status = {"phase": "idle", "message": ""}

    # ── History tracking ─────────────────────────────────

    def _load_history(self) -> dict:
        try:
            if HISTORY_FILE.is_file():
                with open(HISTORY_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return {"downloaded_urls": [], "last_run": None, "total_downloaded": 0}

    def _save_history(self):
        HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
        save_data = {k: v for k, v in self._history.items() if k != "downloaded_urls_set"}
        tmp_file = HISTORY_FILE.with_suffix(".tmp")
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(save_data, f, indent=2)
        tmp_file.replace(HISTORY_FILE)

    def _mark_downloaded(self, url: str):
        if url not in self._history["downloaded_urls"]:
            self._history["downloaded_urls"].append(url)

    # ── Cookie extraction ────────────────────────────────

    def _get_cookies(self) -> dict:
        """Extract Grok cookies. Tries (in order):
        1. Playwright persistent profile (~/.grok-playwright) — gives fresh
           cf_clearance because Chromium just navigated grok.com
        2. browser-cookie3 against real Chrome (often needs admin)
        3. Cached cookies in history file (may be stale)
        """
        # Strategy 1: Playwright profile
        try:
            cookies = self._cookies_from_playwright()
            if cookies and cookies.get("sso"):
                self._history["cached_cookies"] = cookies
                self._save_history()
                print(f"[GrokDownloader] Got {len(cookies)} cookies via Playwright profile")
                return cookies
        except Exception as e:
            print(f"[GrokDownloader] Playwright cookie extraction failed: {e}")

        # Strategy 2: browser_cookie3
        if HAVE_BC3:
            try:
                cj = browser_cookie3.chrome(domain_name=".grok.com")
                cookies = {c.name: c.value for c in cj}
                if cookies and cookies.get("sso"):
                    self._history["cached_cookies"] = cookies
                    self._save_history()
                    print(f"[GrokDownloader] Got {len(cookies)} cookies via browser-cookie3")
                    return cookies
            except Exception as e:
                print(f"[GrokDownloader] browser-cookie3 failed: {e}")

        # Strategy 3: cache fallback
        stored = self._history.get("cached_cookies", {})
        if stored.get("sso"):
            print(f"[GrokDownloader] Using cached cookies (may be stale)")
            return stored
        raise RuntimeError("Cannot get fresh cookies. Run any grok_animate / grok_i2i first.")

    def _cookies_from_playwright(self) -> dict:
        """Open the persistent Playwright profile, navigate grok.com (refreshes
        cf_clearance), and dump all cookies."""
        from playwright.sync_api import sync_playwright
        profile = Path(os.path.expanduser("~")) / ".grok-playwright"
        if not profile.is_dir():
            return {}
        with sync_playwright() as pw:
            ctx = pw.chromium.launch_persistent_context(
                str(profile),
                headless=True,
                viewport={"width": 1280, "height": 900},
                args=["--disable-blink-features=AutomationControlled"],
                user_agent=(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
                ),
            )
            # Inject sso seed cookies if profile is fresh — gives Cloudflare
            # something to attach a fresh cf_clearance to
            seed = self._history.get("cached_cookies", {})
            if seed.get("sso"):
                ctx.add_cookies([
                    {"name": k, "value": str(v), "domain": ".grok.com",
                     "path": "/", "secure": True,
                     "httpOnly": k in ("sso", "sso-rw", "cf_clearance", "__cf_bm"),
                     "sameSite": "None"}
                    for k, v in seed.items() if v
                ])
            page = ctx.new_page()
            page.goto("https://grok.com/imagine/saved", wait_until="networkidle", timeout=60000)
            time.sleep(2)
            cookies_raw = ctx.cookies("https://grok.com")
            ctx.close()
            return {c["name"]: c["value"] for c in cookies_raw}

    # ── API calls ────────────────────────────────────────

    def _fetch_favorites(self, cookies: dict, since: datetime = None) -> list:
        """Fetch favorites from Grok API with pagination."""
        all_posts = []
        cursor = None
        cookie_str = "; ".join(f"{k}={v}" for k, v in cookies.items())

        headers = {
            "Content-Type": "application/json",
            "Referer": "https://grok.com/imagine",
            "Cookie": cookie_str,
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
            ),
        }

        while True:
            body = {
                "limit": 100,
                "filter": {"source": "MEDIA_POST_SOURCE_LIKED"},
            }
            if cursor:
                body["cursor"] = cursor

            try:
                resp = requests.post(GROK_API_URL, json=body, headers=headers, timeout=30)
                resp.raise_for_status()
                data = resp.json()
            except Exception as e:
                self._status["message"] = f"API error: {e}"
                print(f"[GrokDownloader] {e}")
                if hasattr(e, 'response') and e.response is not None:
                    print(f"  Response: {e.response.text[:300]}")
                break

            posts = data.get("posts", [])
            cursor = data.get("nextCursor")
            if not posts:
                break

            flat = self._flatten_posts(posts)
            if since:
                flat = [p for p in flat if self._parse_time(p.get("createTime", "")) >= since]
                if not flat and not cursor:
                    break

            all_posts.extend(flat)
            self._status["message"] = f"Fetched {len(all_posts)} favorites..."

            if not cursor:
                break
            time.sleep(0.3)

        return all_posts

    def _flatten_posts(self, posts: list) -> list:
        result = []
        for post in posts:
            children = post.pop("childPosts", [])
            result.append(post)
            result.extend(self._flatten_posts(children))
        return result

    @staticmethod
    def _slugify_prompt(text: str, max_len: int = 40) -> str:
        """Convert a free-text prompt into a short, filesystem-safe filename slug.
        Picks up the first N characters of meaningful words from the prompt so
        that the resulting filename hints at what the media actually is.
        """
        import re as _re
        if not text:
            return ""
        # Strip common boilerplate we always append to prompts
        noise = [
            "locked side profile view", "completely static camera",
            "no camera movement", "no pan", "no zoom", "no follow",
            "character stays centered", "in frame", "side profile",
            "photorealistic", "cinematic 8k", "sharp focus", "ultra detailed",
            "plain neutral grey studio background", "full body",
            "professional fantasy", "dramatic lighting",
        ]
        lowered = text.lower()
        for n in noise:
            lowered = lowered.replace(n, "")
        # Keep only alnum + space, collapse whitespace
        cleaned = _re.sub(r"[^a-z0-9\s]+", " ", lowered)
        cleaned = _re.sub(r"\s+", " ", cleaned).strip()
        # Truncate to max_len chars worth of words
        if len(cleaned) > max_len:
            cleaned = cleaned[:max_len].rsplit(" ", 1)[0]
        return cleaned.replace(" ", "_")

    def _parse_time(self, time_str: str) -> datetime:
        """Parse a Grok API timestamp into a UTC-aware datetime."""
        try:
            return datetime.fromisoformat(time_str.replace("Z", "+00:00"))
        except Exception:
            return datetime.min.replace(tzinfo=timezone.utc)

    # ── Download ─────────────────────────────────────────

    def run(self, dry_run: bool = False, since_hours: float = None) -> dict:
        if self._running:
            return {"error": "Already running"}
        self._running = True
        self._status = {"phase": "starting", "message": "Extracting cookies..."}

        try:
            cookies = self._get_cookies()
            if not cookies.get("sso"):
                return {"error": "No Grok auth cookies found. Log into Grok in Chrome first."}

            # Default lookback: 24h. We never fetch all-time because the
            # downloaded_urls history already filters duplicates.
            # IMPORTANT: use UTC, not local time — Grok API returns UTC timestamps.
            since = datetime.now(timezone.utc) - (
                timedelta(hours=since_hours) if since_hours else timedelta(hours=24)
            )
            self._status = {"phase": "fetching", "message": "Fetching favorites list..."}
            print(f"[GrokDownloader] Fetching favorites since {since.isoformat()}")
            posts = self._fetch_favorites(cookies, since)
            print(f"[GrokDownloader] Got {len(posts)} favorites total")

            url_set = set(self._history.get("downloaded_urls", []))
            new_posts = [p for p in posts if p.get("mediaUrl") and p["mediaUrl"] not in url_set]
            print(f"[GrokDownloader] {len(new_posts)} new, {len(posts) - len(new_posts)} already had")

            if dry_run:
                self._history["last_run"] = datetime.now().isoformat()
                self._save_history()
                return {"ok": True, "dry_run": True, "total": len(posts), "new": len(new_posts)}

            DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
            downloaded = 0
            errors = []

            for i, post in enumerate(new_posts):
                url = post["mediaUrl"]
                mime = post.get("mimeType", "image/jpeg")
                if "imagine-public.x.ai" in url:
                    uuid_part = url.split("/")[-1].rsplit(".", 1)[0]
                else:
                    uuid_part = url.split("/")[-2]
                ext = mime.split("/")[-1]
                if ext == "jpeg":
                    ext = "jpg"
                # Build a human-readable prefix from the prompt field.
                # Keeps first 40 chars of prompt, slugified, plus 8-char UUID tail.
                prompt_text = (post.get("prompt") or post.get("originalPrompt") or "").strip()
                slug = self._slugify_prompt(prompt_text)
                uuid_tail = uuid_part[:8] if uuid_part else "nouuid"
                if slug:
                    filename = f"{slug}__{uuid_tail}.{ext}"
                else:
                    filename = f"{uuid_part}.{ext}"
                self._status["message"] = f"Downloading {i + 1}/{len(new_posts)}: {filename}"
                print(f"[GrokDownloader] [{i + 1}/{len(new_posts)}] {filename}")

                try:
                    cookie_str = "; ".join(f"{k}={v}" for k, v in cookies.items())
                    dl_headers = {"Cookie": cookie_str} if "assets.grok.com" in url else {}
                    resp = requests.get(url, headers=dl_headers, timeout=120)
                    resp.raise_for_status()
                    dest = DOWNLOADS_DIR / filename
                    with open(dest, "wb") as f:
                        f.write(resp.content)
                    self._mark_downloaded(url)
                    downloaded += 1
                    self._history["total_downloaded"] = len(self._history.get("downloaded_urls", []))
                    self._save_history()
                except Exception as e:
                    errors.append(f"{filename}: {e}")
                    print(f"  ERROR: {e}")
                time.sleep(1)
                if downloaded > 0 and downloaded % 5 == 0:
                    print(f"[GrokDownloader] {downloaded} downloaded, brief pause...")
                    time.sleep(5)

            self._history["last_run"] = datetime.now().isoformat()
            self._save_history()
            self._status = {"phase": "done", "message": f"Downloaded {downloaded} new items"}

            return {
                "ok": True, "total": len(posts),
                "new_downloads": downloaded,
                "skipped": len(posts) - len(new_posts),
                "folder": str(DOWNLOADS_DIR) if downloaded > 0 else "",
                "errors": errors,
            }
        except Exception as e:
            self._status = {"phase": "failed", "message": str(e)}
            return {"error": str(e)}
        finally:
            self._running = False

    def seed_history(self) -> dict:
        """First-time setup: catalog all existing favorites without downloading
        (so we don't re-pull months of backlog)."""
        if self._running:
            return {"error": "Already running"}
        self._running = True
        try:
            cookies = self._get_cookies()
            if not cookies.get("sso"):
                return {"error": "No Grok auth cookies found"}
            posts = self._fetch_favorites(cookies)
            count = 0
            for post in posts:
                url = post.get("mediaUrl")
                if url and url not in self._history.get("downloaded_urls", []):
                    self._mark_downloaded(url)
                    count += 1
            self._history["last_run"] = datetime.now().isoformat()
            self._history["total_downloaded"] = len(self._history.get("downloaded_urls", []))
            self._save_history()
            return {"ok": True, "cataloged": count, "total": len(posts)}
        finally:
            self._running = False


def main():
    parser = argparse.ArgumentParser(description="Download new favorited media from Grok Imagine")
    parser.add_argument("--since-hours", type=float, default=None,
                        help="Only fetch items from the last N hours (default: 24)")
    parser.add_argument("--dry-run", action="store_true", help="List what would be downloaded")
    parser.add_argument("--seed", action="store_true",
                        help="One-time: mark all existing favorites as already-downloaded")
    args = parser.parse_args()

    dl = GrokDownloader()
    if args.seed:
        result = dl.seed_history()
    else:
        result = dl.run(dry_run=args.dry_run, since_hours=args.since_hours)
    print(json.dumps(result, indent=2, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
