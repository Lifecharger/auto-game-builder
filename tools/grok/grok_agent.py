"""Grok Imagine AGENT runs: start from a brief, watch, download into the Grok folder.

Imagine has three creation modes (Görsel / Video / Ajan). Agent mode takes one long
brief and produces the whole set on its own: one render per prompt, no duplicates,
sizes and framing chosen by the agent. This tool drives it with the logged-in
Playwright profile grok_animate uses.

What the site gives us (mapped 2026-09-22):
- submitting the brief navigates to /imagine/post/<first>?conversation=<conv>
- GET /rest/app-chat/conversations/<conv>/responses?conversationKind=CONVERSATION_KIND_IMAGINE
  returns the run; the ASSISTANT response's `cardAttachmentsJson` holds one
  generated_image_card per render with `image_chunk.imageUuid` and
  `image_chunk.imagePrompt.prompt` (which starts with our TAG token), and
  `fileAttachments` lists the same uuids in order
- the file itself is https://assets.grok.com/users/<uid>/generated/<uuid>/image.jpg

Downloads go where the browser extension puts them - `D:/Reusable Assets/Grok/images/<uuid>.jpg`
(never overwritten) - and the uuid -> prompt map is written to
`D:/Reusable Assets/Grok/_agent_runs/<conv>.json`, so gather/parse tools that key on the uuid
keep working and the extension's own copy is never duplicated.

    python grok_agent.py start --brief brief.txt [--ref img.png ...] [--watch 30]
    python grok_agent.py watch --conversation <conv> [--minutes 30]     # resume watching / download
    python grok_agent.py fetch --conversation <conv>                    # one pass: map + download what exists

`--ref` attaches reference images to the brief (the composer's Yükle input).
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grok_animate import IMAGINE_URL, _launch  # noqa: E402
from playwright.sync_api import sync_playwright  # noqa: E402

POST_RE = re.compile(r"/imagine/post/([0-9a-f-]{36})")
CONV_RE = re.compile(r"[?&]conversation=([0-9a-f-]{36})")
GROK_DIR = Path(os.environ.get("GROK_LOCAL_DIR") or r"D:/Reusable Assets/Grok")
IMAGES_DIR = GROK_DIR / "images"
VIDEOS_DIR = GROK_DIR / "videos"
RUNS_DIR = GROK_DIR / "_agent_runs"
AGENT_LABELS = ("Ajan", "Agent")

BANNER_CSS = """
    #onetrust-consent-sdk, #onetrust-button-group, #onetrust-banner-sdk,
    #CybotCookiebotDialog, [data-nosnippet="true"],
    [data-cookie-banner="true"] { display: none !important; pointer-events: none !important; }
    #dialog-portal { pointer-events: none !important; }
    body { pointer-events: auto !important; overflow: auto !important; }
"""

RESPONSES_JS = """async (conv) => {
  const r = await fetch(`/rest/app-chat/conversations/${conv}/responses?conversationKind=CONVERSATION_KIND_IMAGINE`, {credentials: 'include'});
  if (!r.ok) return {status: r.status, items: [], done: false, error: (await r.text()).slice(0, 200)};
  const d = await r.json();
  const items = [];
  let partial = false, uid = null;
  for (const resp of d.responses || []) {
    if (resp.sender !== 'ASSISTANT' && !/agent/i.test(String(resp.sender || ''))) continue;
    if (resp.partial) partial = true;
    for (const s of resp.cardAttachmentsJson || []) {
      let c; try { c = JSON.parse(s); } catch (e) { continue; }
      const ch = c.image_chunk || c.video_chunk || {};
      const url = ch.imageUrl || ch.videoUrl || '';
      const m = url.match(/users\\/([0-9a-f-]{36})\\//); if (m) uid = m[1];
      const id = ch.imageUuid || ch.videoUuid;
      if (!id) continue;
      items.push({uuid: id, kind: ch.videoUuid ? 'video' : 'image', mime: ch.mimeType || '',
                  prompt: (ch.imagePrompt && ch.imagePrompt.prompt) || (ch.prompt) || c.prompt || '',
                  width: (ch.resolution || {}).width, height: (ch.resolution || {}).height, progress: ch.progress});
    }
  }
  const seen = new Set(); const uniq = [];
  for (const it of items) { if (!seen.has(it.uuid)) { seen.add(it.uuid); uniq.push(it); } }
  return {status: 200, uid, items: uniq, partial};
}"""

DOWNLOAD_JS = """async (url) => {
  const r = await fetch(url, {credentials: 'include'});
  if (!r.ok) return {status: r.status};
  const buf = await r.arrayBuffer();
  let bin = ''; const bytes = new Uint8Array(buf); const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  return {status: 200, b64: btoa(bin), type: r.headers.get('content-type') || ''};
}"""


def _tag_of(prompt: str) -> str:
    m = re.match(r"\s*TAG\s+([A-Za-z0-9_]+)", prompt or "")
    return m.group(1) if m else ""


DISMISS_JS = """() => {
  let hit = 0;
  const pat = /^(got it|tamam|kapat|close|skip|later|anlad[iı]m|devam|dismiss|not now|daha sonra|reddet|reject all|t[üu]m[üu]n[üu] reddet|accept all|kabul et)/i;
  for (const d of document.querySelectorAll('[role=dialog], [data-state=open][role=alertdialog]')) {
    for (const b of d.querySelectorAll('button')) {
      const t = (b.getAttribute('aria-label') || b.textContent || '').trim();
      if (pat.test(t)) { b.click(); hit++; break; }
    }
  }
  return hit;
}"""


def _dismiss_dialogs(page, rounds: int = 4) -> None:
    """Close promo tours and cookie dialogs that sit over the composer."""
    for _ in range(rounds):
        page.keyboard.press("Escape")
        page.wait_for_timeout(300)
        try:
            hit = page.evaluate(DISMISS_JS)
        except Exception:
            hit = 0
        page.wait_for_timeout(400)
        if not hit and not page.evaluate("() => document.querySelectorAll('[role=dialog]').length"):
            return
    # whatever is left is hidden from pointer events by the banner css
    page.add_style_tag(content="[role=dialog], [role=alertdialog] { display: none !important; }")


def _pick_agent_mode(page, tries: int = 40) -> bool:
    """Click the Ajan/Agent radio, waiting up to ~20 s for the composer to render."""
    js = """() => {
      const r = [...document.querySelectorAll('[role=radio]')]
        .find(x => /^(ajan|agent)$/i.test((x.getAttribute('aria-label') || x.textContent || '').trim()));
      if (!r) return 'none';
      r.click();
      return r.getAttribute('aria-checked');
    }"""
    probe = "() => { const r = [...document.querySelectorAll('[role=radio]')].find(x => /^(ajan|agent)$/i.test((x.getAttribute('aria-label') || x.textContent || '').trim())); return r ? r.getAttribute('aria-checked') : 'none'; }"
    for attempt in range(tries):
        state = page.evaluate(probe)
        if state == 'true':
            return True
        if state != 'none':
            # a REAL pointer click: React ignores a synthetic DOM click here
            loc = page.locator('[role="radio"]').filter(has_text=re.compile(r"^(Ajan|Agent)$")).first
            if not loc.count():
                loc = page.locator('[role="radio"][aria-label="Ajan"], [role="radio"][aria-label="Agent"]').first
            try:
                loc.click(force=True, timeout=3000)
            except Exception:
                page.evaluate(js)
            page.wait_for_timeout(600)
            if page.evaluate(probe) == 'true':
                return True
        page.wait_for_timeout(500)
    return False


def _attach_refs(page, refs: list[str]) -> int:
    """Attach reference images through the composer's hidden file input."""
    if not refs:
        return 0
    # the composer form owns `input[type=file][name=files][multiple]`; the other file
    # inputs on the page belong to avatar/profile widgets
    inputs = page.locator('form input[type="file"][name="files"]')
    if not inputs.count():
        inputs = page.locator('input[type="file"][multiple]')
    if not inputs.count():
        raise RuntimeError("no composer file input; cannot attach references")
    inputs.first.set_input_files([str(Path(r).resolve()) for r in refs])
    # wait for the upload request(s) to finish: the thumbnails appear in the composer
    page.wait_for_timeout(1500 + 1500 * len(refs))
    return len(refs)


def _save_items(page, conv: str, uid: str | None, items: list[dict]) -> tuple[int, int]:
    """Download new files into the Grok folder; return (new, total)."""
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    new = 0
    for it in items:
        ext = "mp4" if it["kind"] == "video" else ("png" if "png" in (it.get("mime") or "") else "jpg")
        folder = VIDEOS_DIR if it["kind"] == "video" else IMAGES_DIR
        dest = folder / f"{it['uuid']}.{ext}"
        it["file"] = str(dest)
        if dest.exists() or not uid:
            continue
        url = f"https://assets.grok.com/users/{uid}/generated/{it['uuid']}/" + ("generated_video.mp4" if it["kind"] == "video" else f"image.{ext}")
        got = page.evaluate(DOWNLOAD_JS, url)
        if got.get("status") != 200:
            # 404 = still rendering (the card exists before the file does); report and retry next pass
            print(f"  {it['uuid'][:8]} not ready ({got.get('status')})")
            it["file"] = None
            continue
        import base64
        dest.write_bytes(base64.b64decode(got["b64"]))
        new += 1
        print(f"  saved {dest.name}  {_tag_of(it['prompt']) or '-'}")
    run = {"conversation": conv, "url": f"https://grok.com/imagine/post/{conv}", "uid": uid,
           "savedAt": time.strftime("%Y-%m-%d %H:%M:%S"),
           "items": [{"uuid": i["uuid"], "kind": i["kind"], "tag": _tag_of(i["prompt"]), "prompt": i["prompt"],
                      "file": i.get("file"), "width": i.get("width"), "height": i.get("height")} for i in items]}
    (RUNS_DIR / f"{conv}.json").write_text(json.dumps(run, ensure_ascii=False, indent=1), encoding="utf-8")
    return new, len(items)


def watch(page, conv: str, minutes: float, quiet_minutes: float = 4.0) -> dict:
    deadline = time.time() + minutes * 60
    last_count, last_change = -1, time.time()
    info = {"items": [], "uid": None}
    while True:
        info = page.evaluate(RESPONSES_JS, conv)
        n = len(info.get("items", []))
        if n != last_count:
            last_count, last_change = n, time.time()
        new, total = _save_items(page, conv, info.get("uid"), info.get("items", []))
        left = int((deadline - time.time()) / 60)
        extra = f" status={info.get('status')} {info.get('error', '')}" if info.get('status') != 200 else ""
        print(f"  {left:3d} min left  renders={total} new={new} partial={info.get('partial')}{extra}", flush=True)
        if total and not info.get("partial") and time.time() - last_change > quiet_minutes * 60:
            break
        if time.time() > deadline:
            break
        page.wait_for_timeout(20000)
    return info


def cmd_start(args) -> int:
    brief = io.open(args.brief, encoding="utf-8").read().strip()
    if not brief:
        sys.exit("empty brief")
    with sync_playwright() as pw:
        ctx = _launch(pw, headless=not args.headed)
        try:
            page = ctx.new_page()
            page.goto(IMAGINE_URL, wait_until="load", timeout=60000)
            page.add_style_tag(content=BANNER_CSS)
            page.wait_for_timeout(1500)
            _dismiss_dialogs(page)
            if not _pick_agent_mode(page):
                print("agent mode radio not found (Ajan/Agent)")
                print("  url:", page.url, "| title:", page.title())
                try:
                    print("  radios:", page.evaluate("() => [...document.querySelectorAll('[role=radio]')].map(r => r.getAttribute('aria-label') || r.textContent.trim())"))
                    print("  body:", page.evaluate("() => document.body.innerText.slice(0, 300).replace(/\\n+/g, ' | ')"))
                except Exception as e:
                    print("  probe failed:", e)
                return 2
            n = _attach_refs(page, args.ref or [])
            if n:
                print(f"attached {n} reference image(s)")
                # An upload can flip the composer back to image mode; take
                # agent mode again and make sure the attachment survived.
                _dismiss_dialogs(page)
                if not _pick_agent_mode(page):
                    print("agent mode lost after attaching references")
                    return 2
                still = page.evaluate("() => document.querySelectorAll('form img, form [class*=thumb], form [class*=attachment]').length")
                print(f"attachments visible after re-selecting agent: {still}")
            # No Escape here: it resets the composer's mode and attachment.
            page.add_style_tag(content="[role=dialog], [role=alertdialog], [data-radix-popper-content-wrapper] { display: none !important; }")
            focused = page.evaluate("""() => {
              const t = document.querySelector('[role="textbox"]');
              if (!t) return false;
              t.scrollIntoView({block: 'center'});
              t.focus();
              return document.activeElement === t;
            }""")
            if not focused:
                print("composer textbox could not be focused")
                return 3
            if page.evaluate("() => { const r = [...document.querySelectorAll('[role=radio]')].find(x => /^(ajan|agent)$/i.test((x.getAttribute('aria-label') || x.textContent || '').trim())); return r ? r.getAttribute('aria-checked') : 'none'; }") != 'true':
                print("agent mode is not selected; refusing to submit (would run as image/video)")
                return 4
            before = page.url
            page.keyboard.insert_text(brief)
            page.wait_for_timeout(500)
            typed = page.evaluate("() => (document.querySelector('[role=\"textbox\"]').innerText || '').length")
            print(f"typed {typed} chars")
            page.keyboard.press("Enter")
            try:
                page.wait_for_url(lambda u: u != before and "/imagine/post/" in u, timeout=90000)
            except Exception:
                print("submit did not navigate to a post page; url:", page.url)
                return 3
            # The post page adds `?conversation=<conv>` a moment after it lands;
            # the bare post id is NOT the conversation id, so wait for it.
            for _ in range(30):
                if CONV_RE.search(page.url):
                    break
                page.wait_for_timeout(500)
            m = CONV_RE.search(page.url) or POST_RE.search(page.url)
            conv = m.group(1)
            print(f"started: {page.url}")
            print(f"conversation: {conv}")
            if args.watch > 0:
                watch(page, conv, args.watch)
            return 0
        finally:
            ctx.close()


def _with_page(fn, headed: bool):
    with sync_playwright() as pw:
        ctx = _launch(pw, headless=not headed)
        try:
            page = ctx.new_page()
            page.goto(IMAGINE_URL, wait_until="load", timeout=60000)
            return fn(page)
        finally:
            ctx.close()


def cmd_watch(args) -> int:
    _with_page(lambda p: watch(p, args.conversation, args.minutes), args.headed)
    return 0


def cmd_fetch(args) -> int:
    def one(page):
        info = page.evaluate(RESPONSES_JS, args.conversation)
        new, total = _save_items(page, args.conversation, info.get("uid"), info.get("items", []))
        print(f"renders={total} new={new} partial={info.get('partial')}")
        for it in info.get("items", []):
            print(f"  {it['uuid']}  {_tag_of(it['prompt']) or '-'}  {it.get('width')}x{it.get('height')}")
    _with_page(one, args.headed)
    return 0


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start"); s.add_argument("--brief", required=True); s.add_argument("--ref", action="append")
    s.add_argument("--watch", type=float, default=0, help="minutes to watch + download after starting")
    s.add_argument("--headed", action="store_true")
    w = sub.add_parser("watch"); w.add_argument("--conversation", required=True); w.add_argument("--minutes", type=float, default=30)
    w.add_argument("--headed", action="store_true")
    f = sub.add_parser("fetch"); f.add_argument("--conversation", required=True); f.add_argument("--headed", action="store_true")
    args = ap.parse_args()
    sys.exit({"start": cmd_start, "watch": cmd_watch, "fetch": cmd_fetch}[args.cmd](args))


if __name__ == "__main__":
    main()
