"""Build the data for the Relationships Art Review board (the claude.ai artifact).

Reads order.json (delivered level -> source outfit) and the masters, writes
<out>/data.js plus small alpha previews of the matted loops in <out>/loops/, and
<out>/files_map.json listing what to publish. An item is only reviewable once
its final form exists:
  still     RVM cut (*_cut.png tagged "rvm"); base needs base.png first
  portrait  L<k>_scene.png (base = L1_scene.png)
  loop      *_loop_rgba.webm (RVM matte); base needs base_loop_rgba.webm
Anything else ships as {"waiting": "<why>"} so the board shows a waiting tile.

    python build_review.py <out_dir>
"""
from __future__ import annotations

import base64
import concurrent.futures
import io
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"C:/Reusable Assets/Images/Hot Idle/relationships"
FFMPEG = "ffmpeg"


def thumb(path: str, h: int, q: int, rgba: bool) -> str:
    im = Image.open(path)
    im = im.convert("RGBA" if rgba else "RGB")
    im = im.resize((round(im.width * h / im.height), h), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, "WEBP", quality=q, method=6)
    return "data:image/webp;base64," + base64.b64encode(b.getvalue()).decode()


MA_TS = 1789537000  # loop mattes older than this were made by the old RVM recipe (2026-09-16)


def is_rvm(path: str) -> bool:
    """True for a cut made by the current recipe (BiRefNet, tag ma1)."""
    try:
        return Image.open(path).info.get("matte") == "ma1"
    except OSError:
        return False


def loop_preview(src_webm: str, dst: str) -> None:
    if os.path.isfile(dst) and os.path.getmtime(dst) >= os.path.getmtime(src_webm):
        return
    dec = [] if src_webm.endswith(".mp4") else ["-c:v", "libvpx-vp9"]   # opaque living portrait vs alpha webm
    subprocess.run([FFMPEG, "-v", "error", "-y", *dec, "-i", src_webm, "-an",
                    "-vf", "fps=12,scale=192:-2:flags=lanczos,format=rgba",
                    "-c:v", "libwebp_anim", "-lossless", "0", "-q:v", "60", "-loop", "0",
                    "-f", "webp", dst], check=True)


def main() -> None:
    out = sys.argv[1]
    os.makedirs(os.path.join(out, "loops"), exist_ok=True)
    with open(os.path.join(HERE, "order.json"), encoding="utf-8") as f:
        order = json.load(f)["order"]
    approved = {}
    ap_path = os.path.join(HERE, "approved.json")
    if os.path.isfile(ap_path):
        with open(ap_path, encoding="utf-8") as f:
            approved = json.load(f)   # approved items leave the board for good
    pending = {}
    pr_path = os.path.join(HERE, "pending_redo.json")
    if os.path.isfile(pr_path):
        with open(pr_path, encoding="utf-8") as f:
            pending = json.load(f)   # {girl: {item_id: stamp}}: hidden until master newer than stamp
    girls = []
    previews = []
    for g, keys in order.items():
        d = os.path.join(SRC, g)
        items = []
        for n, key in enumerate(keys, 1):
            base = key == "base"
            still = os.path.join(d, "base_cut.png" if base else f"{key}_cut.png")
            scene = os.path.join(d, "L1_scene.png" if base else f"{key}_scene.png")
            loop = os.path.join(d, "base_loop_rgba.webm" if base else f"{key}_loop_rgba.webm")
            # still
            it = {"id": f"L{n}_still", "kind": "still", "level": n, "from": key}
            if base and not os.path.isfile(os.path.join(d, "base.png")):
                it["waiting"] = "sharp re-render"
            elif os.path.isfile(still) and is_rvm(still):
                it["src"] = thumb(still, 360, 70, True)
            else:
                it["waiting"] = "background removal"
            items.append(it)
            # portrait
            it = {"id": f"L{n}_portrait", "kind": "portrait", "level": n, "from": key}
            if os.path.isfile(scene):
                it["src"] = thumb(scene, 480, 72, False)
            else:
                it["waiting"] = "render"
            items.append(it)
            # loop
            it = {"id": f"L{n}_loop", "kind": "loop", "level": n, "from": key}
            if os.path.isfile(loop) and os.path.getmtime(loop) < MA_TS:
                it["waiting"] = "new background removal"
            elif os.path.isfile(loop):
                rel = f"loops/{g}_L{n}.webp"
                previews.append((loop, os.path.join(out, rel)))
                # version stamp: same path, fresh bytes -> browsers must refetch
                it["src"] = rel + "?v=" + str(int(os.path.getmtime(loop)))
            elif os.path.isfile(loop.replace("_rgba.webm", ".mp4")):
                it["waiting"] = "background removal"
            else:
                it["waiting"] = "render"
            items.append(it)
            # living portrait (2026-09-16): opaque loop of the painting
            sloop = os.path.join(d, "L1_scene_loop.mp4" if base else f"{key}_scene_loop.mp4")
            it = {"id": f"L{n}_sceneloop", "kind": "sceneloop", "level": n, "from": key}
            if os.path.isfile(sloop):
                rel = f"loops/{g}_L{n}_scene.webp"
                previews.append((sloop, os.path.join(out, rel)))
                it["src"] = rel + "?v=" + str(int(os.path.getmtime(sloop)))
            else:
                it["waiting"] = "render"
            items.append(it)
        done = set(approved.get(g, []))
        items = [i for i in items if i["id"] not in done]
        # A redo I have taken on: the old version leaves the board and the
        # item is back only when its replacement master is newer than the
        # moment the redo started (user 2026-09-16).
        pend = pending.get(g, {})
        kept = []
        for i in items:
            stamp = pend.get(i["id"])
            if stamp is None:
                kept.append(i); continue
            key = keys[i["level"] - 1]; base = key == "base"
            master = {"sceneloop": os.path.join(d, "L1_scene_loop.mp4" if base else f"{key}_scene_loop.mp4"),
                      "still": os.path.join(d, "base_cut.png" if base else f"{key}_cut.png"),
                      "portrait": os.path.join(d, "L1_scene.png" if base else f"{key}_scene.png"),
                      "loop": os.path.join(d, "base_loop_rgba.webm" if base else f"{key}_loop_rgba.webm")}[i["kind"]]
            if os.path.isfile(master) and os.path.getmtime(master) > stamp and "src" in i:
                i["fresh"] = True          # replacement landed: show it, verdict to be cleared
                kept.append(i)
        items = kept
        girls.append({"name": g, "items": items, "approved": len(done)})
    with concurrent.futures.ThreadPoolExecutor(4) as pool:
        list(pool.map(lambda p: loop_preview(*p), previews))
    with open(os.path.join(out, "data.js"), "w", encoding="utf-8") as f:
        f.write("window.REVIEW_DATA=" + json.dumps({"girls": girls}, ensure_ascii=False) + ";")
    # Stamp the page's script tag too, so a rebuilt data.js is never served
    # from the browser cache under the old name.
    import re, time
    page = os.path.join(out, "index.html")
    if os.path.isfile(page):
        html = open(page, encoding="utf-8").read()
        html = re.sub(r'src="data\.js[^"]*"', 'src="data.js?v=%d"' % int(time.time()), html)
        open(page, "w", encoding="utf-8", newline="").write(html)
    files = {"data.js": "data.js"}
    for _, dst in previews:
        rel = os.path.relpath(dst, out).replace("\\", "/")
        files[rel] = rel
    with open(os.path.join(out, "files_map.json"), "w", encoding="utf-8") as f:
        json.dump(files, f)
    fresh = [(g["name"], i["id"]) for g in girls for i in g["items"] if i.get("fresh")]
    with open(os.path.join(out, "fresh.json"), "w", encoding="utf-8") as f:
        json.dump(fresh, f)
    ready = sum(1 for g in girls for i in g["items"] if "src" in i)
    waiting = sum(1 for g in girls for i in g["items"] if "waiting" in i)
    print(f"ready {ready} waiting {waiting} previews {len(previews)}")
    print(json.dumps(files))


if __name__ == "__main__":
    main()
