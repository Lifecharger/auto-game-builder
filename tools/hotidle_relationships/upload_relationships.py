"""Encode + upload the Hot Idle Relationships art to the hotjigsaw bucket.

Keys match what the app already reads (CloudflareConfig.relationship*Url):
    relationships/<girl>/L<n>.webp         outfit still   (from L<n>.png,       720 px tall, q85)
    relationships/<girl>/L<n>_scene.webp   portrait       (from L<n>_scene.png, 1024 px tall, q85)
    relationships/<girl>/L<n>_loop.webp    animated loop  (from L<n>_loop_rgba.webm, 384 px wide, 12 fps, q60, alpha)

    python upload_relationships.py stills portraits      # encode + upload those kinds
    python upload_relationships.py loops
    python upload_relationships.py stills --dry          # list what would change
    python upload_relationships.py portraits --immutable # final art: 90-day immutable header

Resume-safe: a state file remembers the sha of every uploaded key, so re-runs
only push files whose bytes changed. Uploads go through `wrangler r2 object
put` (OAuth login, same as tools/r2/characters_sync.py).

Cache header: while the art is still under review the objects go up with the
MUTABLE header (6 h fresh + 1 day stale-while-revalidate) so a re-render
reaches the CDN; pass --immutable for the final approved set. Note that the
app's own disk cache never re-fetches a URL it has, so a replaced picture
needs a new key (bump the level URL in CloudflareConfig) to reach a device
that already cached the old one.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "r2"))
import r2_s3  # noqa: E402  (stdlib-only server-side copy)

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r"C:/Reusable Assets/Images/Hot Idle/relationships"
OUT = os.path.join(SRC, "_delivery")
# 2026-09-17 (R2 reorganization, see C:/Cloudflare Workers/R2_MAP.md): relationship art lives in
# the `characters` bucket as <girl>/relationships/<file>, served from
# https://characters.lifechargergames.com. Until the legacy `hotcardgames` bucket is retired
# (about 2026-10-20) every file is ALSO written to its legacy key relationships/<girl>/<file>, so
# builds that still read the hotcardgames worker keep seeing new art. After the retirement delete
# LEGACY_BUCKET and the legacy copy in put().
BUCKET = "characters"
LEGACY_BUCKET = "hotcardgames"
STATE = os.path.join(SRC, "_delivery", f"upload_state_{LEGACY_BUCKET}.json")
WRANGLER = (shutil.which("wrangler.cmd") or shutil.which("wrangler")
            or r"C:\Users\caca_\AppData\Roaming\npm\wrangler.cmd")
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"

CACHE_MUTABLE = "public, max-age=21600, stale-while-revalidate=86400"
CACHE_IMMUTABLE = "public, max-age=7776000, immutable"

KINDS = {
    "stills":    {"key": "L{n}.webp",       "levels": range(1, 11)},
    "portraits": {"key": "L{n}_scene.webp", "levels": range(1, 11)},
    "loops":     {"key": "L{n}_loop.webp",  "levels": range(1, 11)},
    # living portraits (2026-09-16): opaque 6 s loop of the painting itself
    "sceneloops": {"key": "L{n}_scene_loop.webp", "levels": range(1, 11)},
}
REFS = r"C:/Reusable Assets/Images/Hot Idle/cashiers_side/refs"
FRONT = r"C:/Projects/Hot Idle/assets/images/cashiers_front"


def order() -> dict:
    """order.json: delivered level -> source outfit key ('base' or 'Lk')."""
    with open(os.path.join(HERE, "order.json"), encoding="utf-8") as f:
        return json.load(f)["order"]


def source_for(girl: str, kind: str, level: int, ranking: dict) -> str | None:
    """Master file behind delivered level `level` of `girl`, after the 2026-09-15
    re-ranking (least -> most revealing). 'base' is the original cashier art:
    still = cut-out of her reference (base_cut.png, made by cutout_stills.py
    --base), portrait = the scene made from the reference (old L1_scene), loop =
    her bundled desk frames (the cashiers_front frame folder, encoded directly
    so the alpha never passes through a lossy video)."""
    key = ranking[girl][level - 1]
    d = os.path.join(SRC, girl)
    # Loops deliver from the MATTED master (*_loop_rgba.webm, alpha), never the
    # white-background mp4; and only a matte made with the final recipe counts.
    if key == "base":
        if kind == "stills":
            return os.path.join(d, "base_cut.png")
        if kind == "portraits":
            return os.path.join(d, "L1_scene.png")
        if kind == "sceneloops":
            return os.path.join(d, "L1_scene_loop.mp4")
        return os.path.join(d, "base_loop_rgba.webm")
    k = int(key[1:])
    if kind == "stills":
        return os.path.join(d, f"L{k}_cut.png")
    if kind == "portraits":
        return os.path.join(d, f"L{k}_scene.png")
    if kind == "sceneloops":
        return os.path.join(d, f"L{k}_scene_loop.mp4")
    return os.path.join(d, f"L{k}_loop_rgba.webm")


def girls() -> list[str]:
    with open(os.path.join(HERE, "ladders.json"), encoding="utf-8") as f:
        return list(json.load(f)["girls"])


def sha8(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:8]


def encode_image(src: str, dst: str, height: int) -> None:
    # Stills are cut-outs (RGBA, cutout_stills.py); portraits are opaque scenes.
    # `height` bounds the LONG side: landscape portraits (frames 6, 7, 10) are
    # wider than tall since 2026-09-16.
    im = Image.open(src)
    im = im.convert("RGBA" if "A" in im.getbands() else "RGB")
    long_side = max(im.width, im.height)
    if long_side > height:
        s = height / long_side
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    im.save(dst, "WEBP", quality=85, method=6)


def encode_scene_loop(src: str, dst: str) -> None:
    """Opaque living portrait: mp4 -> animated WebP, 384 px wide, 12 fps, q60."""
    tmp = dst + ".tmp"
    subprocess.run([FFMPEG, "-v", "error", "-y", "-i", src, "-an",
                    "-vf", "fps=12,scale=384:-2:flags=lanczos",
                    "-c:v", "libwebp_anim", "-lossless", "0", "-q:v", "60",
                    "-loop", "0", "-f", "webp", tmp], check=True)
    os.replace(tmp, dst)


def encode_loop(src: str, dst: str) -> None:
    # Living Walls settings (hotidle_wall_webp): 256 px wide, 12 fps, q60, no audio.
    tmp = dst + ".tmp"
    # Matted VP9 webm with alpha in, animated WebP with alpha out. 384 px wide
    # (user 2026-09-15: 256 was too soft for a full-screen profile loop).
    inp = ["-c:v", "libvpx-vp9", "-i", src]
    vf = "fps=12,scale=384:-2:flags=lanczos,format=rgba"
    subprocess.run([FFMPEG, "-v", "error", "-y", *inp, "-an",
                    "-vf", vf,
                    "-c:v", "libwebp_anim", "-lossless", "0", "-q:v", "60",
                    "-loop", "0", "-f", "webp", tmp], check=True)
    os.replace(tmp, dst)


def load_state() -> dict:
    if os.path.isfile(STATE):
        with open(STATE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, STATE)


def put(key: str, path: str, cache: str) -> bool:
    ctype = "video/mp4" if key.endswith(".mp4") else "image/webp"
    # key arrives in its legacy shape relationships/<girl>/<file>
    _, girl, name = key.split("/", 2)
    new_key = f"{girl}/relationships/{name}"
    if not _put_one(f"{BUCKET}/{new_key}", path, ctype, cache):
        return False
    # The legacy twin is a server-side copy: the bytes are uploaded once.
    try:
        r2_s3.copy_object(BUCKET, new_key, LEGACY_BUCKET, key)
    except (RuntimeError, OSError) as e:
        print(f"  legacy copy failed {key}: {e}", flush=True)
        return False
    return True


def _put_one(target: str, path: str, ctype: str, cache: str) -> bool:
    cmd = [WRANGLER, "r2", "object", "put", target, "--remote",
           "--file", path, "--content-type", ctype, "--cache-control", cache]
    for attempt in range(3):
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode == 0:
            return True
        print(f"  retry {attempt + 1} {target}: {(r.stderr or r.stdout).strip()[-160:]}", flush=True)
        time.sleep(3)
    return False


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("kinds", nargs="+", choices=list(KINDS))
    ap.add_argument("--girls", default="", help="comma list, default all")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--immutable", action="store_true",
                    help="final approved art: 90-day immutable cache header")
    ap.add_argument("--parallel", type=int, default=4)
    ap.add_argument("--approved", default="",
                    help="approved.json from approve.py: upload only these girl/level/kind items")
    a = ap.parse_args()
    approved = None
    if a.approved:
        with open(a.approved, encoding="utf-8") as f:
            approved = json.load(f)   # {girl: ["L3_still", "L7_portrait", ...]}
    cache = CACHE_IMMUTABLE if a.immutable else CACHE_MUTABLE
    names = [g for g in a.girls.split(",") if g] or girls()
    state = load_state()

    # 1. encode everything that exists (skip when the delivery file is newer than the master)
    ranking = order()
    jobs: list[tuple[str, str]] = []   # (key, delivery path)
    missing = 0
    for kind in a.kinds:
        spec = KINDS[kind]
        for g in names:
            for n in spec["levels"]:
                if approved is not None:
                    tag = {"stills": "still", "portraits": "portrait", "loops": "loop",
                           "sceneloops": "sceneloop"}[kind]
                    if f"L{n}_{tag}" not in approved.get(g, []):
                        continue
                src = source_for(g, kind, n, ranking)
                if not os.path.isfile(src):
                    missing += 1
                    continue
                if kind == "loops" and os.path.getmtime(src) < 1789509128:
                    missing += 1          # matte predates the final recipe: not yet
                    continue
                dst = os.path.join(OUT, g, spec["key"].format(n=n))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                if not os.path.isfile(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
                    if kind == "loops":
                        encode_loop(src, dst)
                    elif kind == "sceneloops":
                        encode_scene_loop(src, dst)
                    else:
                        encode_image(src, dst, 1024 if kind == "portraits" else 720)
                    print(f"  encoded {g}/{os.path.basename(dst)} "
                          f"{os.path.getsize(dst) / 1024:.0f} KB", flush=True)
                jobs.append((f"relationships/{g}/{spec['key'].format(n=n)}", dst))
                if kind == "sceneloops":
                    # MP4 twin for the full-screen player (tap on the frame),
                    # the LTX master as rendered, same key with .mp4.
                    jobs.append((f"relationships/{g}/L{n}_scene_loop.mp4", src))
    print(f"{len(jobs)} files ready, {missing} masters not rendered yet", flush=True)

    # 2. upload what changed
    todo = [(k, p) for k, p in jobs
            if state.get(k, {}).get("sha") != sha8(p) or state.get(k, {}).get("cache") != cache]
    print(f"{len(todo)} to upload ({len(jobs) - len(todo)} unchanged) with '{cache}'", flush=True)
    if a.dry:
        for k, _ in todo:
            print("  would put", k)
        return
    ok = fail = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, a.parallel)) as pool:
        futs = {pool.submit(put, k, p, cache): (k, p) for k, p in todo}
        for fut in concurrent.futures.as_completed(futs):
            k, p = futs[fut]
            if fut.result():
                ok += 1
                state[k] = {"sha": sha8(p), "cache": cache, "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
                if ok % 20 == 0:
                    save_state(state)
                    print(f"  {ok}/{len(todo)}", flush=True)
            else:
                fail += 1
                print(f"  FAIL {k}", flush=True)
    save_state(state)
    print(f"upload done: {ok} ok, {fail} failed", flush=True)
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
