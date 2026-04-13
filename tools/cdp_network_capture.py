"""
CDP Network Capture — attach to an already-running Chrome (via debug port)
and record every network request it makes, filtered to interesting traffic
(no static files, no analytics pixels).

Pairs with chrome_cdp_launcher.py — launcher opens Chrome with --remote-debugging-port,
you log into the target site, then run this to capture network activity while
you interact with the site.

Usage:
    # Default: port 9222, auto-detect active tab, save to cdp_capture.json
    python cdp_network_capture.py

    # Specific port + output file
    python cdp_network_capture.py --port 9222 --out tripo_capture.json

    # Filter to only a specific host
    python cdp_network_capture.py --only-host tripo3d.ai

    # Run for a fixed duration instead of waiting for Enter
    python cdp_network_capture.py --duration 60
"""
import argparse
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

from playwright.sync_api import sync_playwright

# Noise filters — same list used by tripo_capture.py
IGNORE_HOSTS = {
    "google-analytics.com", "googletagmanager.com",
    "www.google-analytics.com", "www.googletagmanager.com",
    "fonts.googleapis.com", "fonts.gstatic.com",
    "stats.g.doubleclick.net", "doubleclick.net",
    "cdn.cookielaw.org", "sentry.io", "o.clarity.ms", "clarity.ms",
    "hotjar.com", "static.hotjar.com",
    "segment.io", "amplitude.com", "intercom.io",
    "cdn.segment.com", "api.segment.io",
}
IGNORE_EXTS = (".css", ".woff", ".woff2", ".ttf", ".otf", ".svg", ".png",
                ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".mp4", ".webm",
                ".map")


def should_skip(url: str, only_host: str = None) -> bool:
    try:
        u = urlparse(url)
    except Exception:
        return True
    if only_host:
        if only_host not in u.netloc:
            return True
    if any(h in u.netloc for h in IGNORE_HOSTS):
        return True
    path = u.path.lower()
    if any(path.endswith(ext) for ext in IGNORE_EXTS):
        return True
    if "_next/static" in path:
        return True
    return False


def main():
    p = argparse.ArgumentParser(description="Capture network traffic from a running Chrome via CDP")
    p.add_argument("--port", type=int, default=9222, help="Chrome debug port")
    p.add_argument("--out", default="cdp_capture.json", help="Output JSON file")
    p.add_argument("--only-host", help="Only capture requests to URLs containing this string in host")
    p.add_argument("--duration", type=int, default=None,
                   help="Capture for N seconds then auto-save (default: wait for Enter)")
    p.add_argument("--max-body", type=int, default=10000, help="Max chars of response body to save per request")
    args = p.parse_args()

    captured = []
    start_time = time.time()

    def on_request(req):
        try:
            if should_skip(req.url, args.only_host):
                return
            post = None
            try:
                if req.method in ("POST", "PUT", "PATCH"):
                    post = req.post_data
            except Exception:
                pass
            captured.append({
                "type": "request",
                "method": req.method,
                "url": req.url,
                "headers": dict(req.headers),
                "post_data": post[:args.max_body] if post else None,
                "dt": round(time.time() - start_time, 2),
            })
        except Exception as e:
            print(f"  [req err] {e}")

    def on_response(resp):
        try:
            if should_skip(resp.url, args.only_host):
                return
            body = None
            try:
                ct = resp.headers.get("content-type", "")
                if "json" in ct or "text" in ct or "xml" in ct:
                    b = resp.body()
                    if b:
                        body = b[:args.max_body].decode("utf-8", errors="replace")
            except Exception:
                pass
            captured.append({
                "type": "response",
                "status": resp.status,
                "url": resp.url,
                "headers": dict(resp.headers),
                "body_preview": body,
                "dt": round(time.time() - start_time, 2),
            })
        except Exception as e:
            print(f"  [resp err] {e}")

    with sync_playwright() as pw:
        cdp_url = f"http://localhost:{args.port}"
        print(f"Attaching to Chrome at {cdp_url}...")
        try:
            browser = pw.chromium.connect_over_cdp(cdp_url)
        except Exception as e:
            print(f"ERROR: cannot attach — {e}")
            print(f"Launch Chrome first: python chrome_cdp_launcher.py --profile <name> --port {args.port}")
            sys.exit(1)

        contexts = browser.contexts
        if not contexts or not contexts[0].pages:
            print("ERROR: no open tabs in Chrome. Open a tab first.")
            sys.exit(1)

        # Attach listeners to all existing pages + new ones
        def attach(page):
            page.on("request", on_request)
            page.on("response", on_response)

        for ctx in contexts:
            for page in ctx.pages:
                attach(page)
            ctx.on("page", attach)

        n_pages = sum(len(ctx.pages) for ctx in contexts)
        print(f"Attached. Listening on {n_pages} tab(s). Interact with the site in Chrome now.")
        if args.only_host:
            print(f"  Filter: only requests to hosts containing '{args.only_host}'")

        if args.duration:
            print(f"Capturing for {args.duration} seconds...")
            time.sleep(args.duration)
        else:
            input("Press Enter in this terminal when you're done interacting... ")

        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(captured, f, indent=2, ensure_ascii=False)

        print(f"\nCaptured {len(captured)} events → {out_path.resolve()}")
        # List unique hosts hit
        hosts = sorted({urlparse(e["url"]).netloc for e in captured if "url" in e})
        print(f"Unique hosts: {len(hosts)}")
        for h in hosts[:20]:
            print(f"  {h}")
        if len(hosts) > 20:
            print(f"  ... and {len(hosts) - 20} more")

        browser.close()


if __name__ == "__main__":
    main()
