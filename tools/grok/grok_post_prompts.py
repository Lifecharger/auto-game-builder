"""Read the prompt of Grok Imagine generations by their UUID.

The browser extension saves generations UUID-named with no prompt in the file
(EXIF carries only a signature). The account's post page
https://grok.com/imagine/post/<uuid> shows the prompt, so this tool opens the
pages in the logged-in Playwright profile (grok_animate's PROFILE_DIR or
GROK_PROFILE_DIR) and writes prompts.tsv: uuid <tab> prompt. Files whose
prompts start with a `TAG <token>` can then be filed by token.

    python grok_post_prompts.py <uuid> [<uuid> ...]
    python grok_post_prompts.py --dir "D:/Reusable Assets/Grok/images" --since "2026-09-22 00:21" --out prompts.tsv
    python grok_post_prompts.py --items "D:/.../items.json" --out prompts.tsv   # stills + videos of a review set
"""
from __future__ import annotations

import argparse
import glob
import io
import json
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from grok_animate import PROFILE_DIR, _load_sso_cookies  # noqa: E402
from playwright.sync_api import sync_playwright  # noqa: E402

POST = "https://grok.com/imagine/post/{uuid}?scope=asset"
UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def uuids_from_dir(folder: str, since: float) -> list[str]:
    out = []
    for f in sorted(glob.glob(os.path.join(folder, "*")), key=os.path.getmtime):
        if os.path.getmtime(f) <= since or "_original" in f:
            continue
        m = UUID_RE.search(os.path.basename(f))
        if m and m.group(0) not in out:
            out.append(m.group(0))
    return out


def read_prompt(page, uuid: str, timeout_s: int = 25) -> str:
    """The prompt text as the post page shows it; '' when not found."""
    page.goto(POST.format(uuid=uuid), wait_until="domcontentloaded", timeout=60000)
    deadline = time.time() + timeout_s
    body = ""
    while time.time() < deadline:
        try:
            body = page.inner_text("body") or ""
        except Exception:
            body = ""
        if "TAG " in body or "Prompt" in body or "prompt" in body:
            break
        time.sleep(1)
    # Prefer a line that starts with the tag token; otherwise the longest line that
    # reads like a prompt.
    lines = [l.strip() for l in body.splitlines() if l.strip()]
    for l in lines:
        if l.startswith("TAG "):
            return l
    # some layouts render the prompt under a label; take the longest line >60 chars
    cands = [l for l in lines if len(l) > 60]
    return max(cands, key=len) if cands else ""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("uuids", nargs="*")
    ap.add_argument("--dir", action="append", help="folder(s) of UUID-named files")
    ap.add_argument("--since", default=None, help='"YYYY-MM-DD HH:MM" cut-off for --dir')
    ap.add_argument("--items", default=None, help="review items.json (stills + videos)")
    ap.add_argument("--out", default="prompts.tsv")
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()

    uuids = list(args.uuids)
    since = time.mktime(time.strptime(args.since, "%Y-%m-%d %H:%M")) if args.since else 0
    for d in args.dir or []:
        uuids += [u for u in uuids_from_dir(d, since) if u not in uuids]
    if args.items:
        for it in json.load(open(args.items)):
            for p in (it.get("still"), it.get("video")):
                if p:
                    m = UUID_RE.search(os.path.basename(p))
                    if m and m.group(0) not in uuids:
                        uuids.append(m.group(0))
    if not uuids:
        sys.exit("no uuids")

    done = {}
    out = Path(args.out)
    if out.exists():
        for line in io.open(out, encoding="utf-8"):
            u, _, p = line.rstrip("\n").partition("\t")
            if u and p:
                done[u] = p
    todo = [u for u in uuids if u not in done]
    print(f"{len(uuids)} uuids, {len(done)} already known, {len(todo)} to read")

    with sync_playwright() as pw:
        ctx = pw.chromium.launch_persistent_context(
            PROFILE_DIR, headless=not args.headed, viewport={"width": 1280, "height": 900},
            args=["--disable-blink-features=AutomationControlled"])
        try:
            cookies = _load_sso_cookies()
            if cookies:
                ctx.add_cookies(cookies)
            page = ctx.new_page()
            with io.open(out, "a", encoding="utf-8") as fh:
                for n, u in enumerate(todo, 1):
                    try:
                        prompt = read_prompt(page, u)
                    except Exception as e:
                        prompt = ""
                        print(f"  {u[:8]} error {e}")
                    if prompt:
                        fh.write(f"{u}\t{prompt}\n")
                        fh.flush()
                    print(f"[{n}/{len(todo)}] {u[:8]} {prompt[:70]!r}")
        finally:
            ctx.close()


if __name__ == "__main__":
    main()
