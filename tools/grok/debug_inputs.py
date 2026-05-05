"""Quick debug: dump all file/input elements on the Imagine video page."""
import json, os, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HISTORY_FILE = os.path.join(_SCRIPT_DIR, "grok_download_history.json")
PROFILE_DIR = str(Path.home() / ".grok-playwright")


def cookies():
    with open(HISTORY_FILE, encoding="utf-8") as f:
        cached = json.load(f).get("cached_cookies", {})
    return [
        {"name": k, "value": str(v), "domain": ".grok.com", "path": "/", "secure": True,
         "httpOnly": k in ("sso", "sso-rw", "cf_clearance", "__cf_bm"), "sameSite": "None"}
        for k, v in cached.items() if v
    ]


with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        PROFILE_DIR, headless=True,
        viewport={"width": 1280, "height": 900},
        args=["--disable-blink-features=AutomationControlled"],
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
    )
    ctx.add_cookies(cookies())
    page = ctx.new_page()
    page.goto("https://grok.com/imagine", wait_until="networkidle", timeout=60000)

    page.evaluate("""() => {
        const portal = document.getElementById('dialog-portal');
        if (portal) portal.innerHTML = '';
        document.querySelectorAll('[role="dialog"]').forEach(el => el.remove());
        document.querySelectorAll('[data-state="open"][aria-hidden="true"]').forEach(el => el.remove());
        document.body.style.pointerEvents = 'auto';
        document.body.removeAttribute('data-scroll-locked');
    }""")
    time.sleep(1)

    try:
        page.locator('[role="radiogroup"][aria-label="Oluşturma modu"] [role="radio"]').filter(has_text="Video").click(timeout=5000)
        print("Switched to Video mode")
    except Exception as e:
        print(f"Video switch fail: {e}")
    time.sleep(2)

    inputs = page.evaluate("""() => Array.from(document.querySelectorAll('input')).map(i => ({
        type: i.type, name: i.name, accept: i.accept, id: i.id,
        cls: i.className, hidden: i.hidden, display: window.getComputedStyle(i).display,
        outerHTML: i.outerHTML.slice(0, 300)
    }))""")
    print(f"\n=== ALL INPUTS ({len(inputs)}) ===")
    for inp in inputs:
        print(json.dumps(inp, indent=2))

    buttons = page.evaluate("""() => Array.from(document.querySelectorAll('button[aria-label]')).slice(0, 20).map(b => ({
        label: b.getAttribute('aria-label'),
        text: (b.innerText || '').slice(0, 50),
        outerHTML: b.outerHTML.slice(0, 200)
    }))""")
    print(f"\n=== BUTTONS WITH aria-label ({len(buttons)}) ===")
    for b in buttons:
        print(json.dumps(b, indent=2))

    ctx.close()
