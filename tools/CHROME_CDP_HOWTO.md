# Chrome CDP Toolkit — How to reverse-engineer any website

Reusable workflow for automating websites that block Playwright / headless Chrome (Google OAuth, Cloudflare, Tripo Studio, Grok, etc.).

## The problem

When Playwright launches its own Chromium:
- Google detects automation flags and blocks OAuth login
- Cloudflare serves JS challenges that headless Chromium can't solve
- Some sites refuse to render entirely (Studio subscriptions, Notion, etc.)

Even `--use-system-chrome` (Playwright's `channel="chrome"`) gets detected because Playwright still sets automation flags under the hood.

## The solution — launch your own Chrome, then attach

1. **You** launch a real Chrome with `--remote-debugging-port=9222` (using an isolated user-data-dir so the flag is honored)
2. **You** log into the target site normally — no automation signals, Google/Cloudflare are happy
3. **Playwright** then ATTACHES to that Chrome via CDP (Chrome DevTools Protocol)
4. Playwright can now see all tabs, record network traffic, drive the UI — **as if you were doing it yourself**, because from Chrome's perspective it literally is you

The isolated profile persists across runs, so you log in **once per site** and never again.

## Critical pitfall — why `--remote-debugging-port` sometimes silently fails

Chrome ignores the debug port flag if:
- Another Chrome process is already using the same user-data-dir (even background helpers count)
- Your main User Data directory has policies/extensions blocking it
- A Chrome update helper process is holding a lock

**Fix:** always use a **fresh isolated `--user-data-dir`** pointing at a path outside your main profile. `chrome_cdp_launcher.py` does this automatically via named profiles at `~/.chrome-cdp-profiles/<name>/`.

If the port STILL doesn't come up, pass `--kill-first` to force-kill every chrome.exe process before launching.

## Files in this toolkit

| File | Purpose |
|---|---|
| `chrome_cdp_launcher.py` | Launches Chrome with CDP enabled. Creates a named isolated profile per site so cookies persist but stay separated. |
| `cdp_network_capture.py` | Attaches to a running CDP-enabled Chrome via Playwright and records network traffic to JSON. |

## Typical workflow

### Step 1 — Launch Chrome for a specific site

```bash
python chrome_cdp_launcher.py --profile tripo --kill-first
```

Chrome opens with a fresh profile. You navigate to the target site (e.g. `studio.tripo3d.ai`) and log in — **once**. The profile is saved at `~/.chrome-cdp-profiles/tripo/`.

Subsequent launches don't need `--kill-first` and Chrome remembers your login:

```bash
python chrome_cdp_launcher.py --profile tripo
```

### Step 2 — Capture traffic while you use the site

```bash
python cdp_network_capture.py --port 9222 --out tripo_capture.json
```

Go back to your Chrome window, do whatever you want to reverse-engineer (click Generate, submit a form, upload a file), come back to the terminal, press Enter. The capture file has every request + response (JSON bodies included up to 10KB each).

### Step 3 — Analyze the capture

Open `tripo_capture.json`, find the POST request that looks like the action you triggered. Copy its URL, headers, and body. Replicate in Python `requests` with the same cookies (Playwright's attached browser shares them with your real Chrome, so the cookies are already there).

### Step 4 — Build a wrapper

Write a tool that uses `playwright.sync_api.sync_playwright().chromium.connect_over_cdp("http://localhost:9222")` to reuse the same session, OR copy cookies into a plain `requests.Session()` for pure-HTTP automation.

## Running multiple sites in parallel

Each site gets its own profile + port:

```bash
python chrome_cdp_launcher.py --profile tripo   --port 9222
python chrome_cdp_launcher.py --profile grok    --port 9223
python chrome_cdp_launcher.py --profile openai  --port 9224
```

All three Chrome instances run simultaneously with separate cookies, extensions, and sessions. You can capture traffic from any of them independently.

## Security note

The CDP port (default 9222) is bound to `localhost` only, so remote attackers can't hit it. BUT any local process can attach — don't run untrusted code while Chrome is in CDP mode.

## When this doesn't work

- **Cloudflare interactive challenge**: if the site serves a "I'm not a robot" checkbox or a JS puzzle, you solve it manually in Chrome once. The `cf_clearance` cookie persists in the profile afterward.
- **Static cookie extraction**: if you just need cookies for a Python `requests` script (no Playwright), use `browser_cookie3` pointing at the isolated profile dir instead.
- **Rate limiting**: driving the UI is still subject to the site's rate limits. This technique doesn't help you go faster than the web UI allows.

## Sites this approach has worked on

| Site | Profile name suggestion | Notes |
|---|---|---|
| `studio.tripo3d.ai` | `tripo` | Subscription credits accessible via web UI |
| `grok.com` | `grok` | Used instead for Grok Imagine i2v/i2i — works with or without CDP |
| `mixamo.com` | `mixamo` | For manual upload + animation batching |
| `sketchfab.com` | `sketchfab` | For downloading asset packs |

Add more as you reverse-engineer them.
