"""Encode Hot Idle / Hot Jigsaw wall videos to animated WebP and upload to R2.

Source: original (pre-recompress) MP4 backups at D:/Backup/hotjigsaw_r2/
        (flat names: collections__<id>__videos__N.mp4)
Output: D:/Backup/hotjigsaw_r2_webp/ (same flat names, .webp)
R2 key: collections/<id>/videos_webp/N.webp  (hotjigsaw bucket)

The r2-scanner worker ignores .webp files outside images//thumbs/, so these
uploads never appear in the manifest; the app derives the URL from the MP4
URL (/videos/N.mp4 -> /videos_webp/N.webp).

Settings match the in-app frame extractor's display size (256px wide) at its
24fps target. `encode_file()` is the shared entry point — r2manager imports it
so accepted assets encode identically. Reads the Cloudflare Global API Key from D:/keys at
runtime (NEVER embed it). Resume-safe in both phases: encode skips existing
non-empty outputs, upload skips keys whose remote size already matches.

Usage:
    python encode_upload.py              # encode then upload
    python encode_upload.py --encode-only
    python encode_upload.py --upload-only
    python encode_upload.py --fps 24 --out D:/Backup/hotjigsaw_r2_webp24
"""
import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import imageio_ffmpeg

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

SRC_DIR = Path(r"D:/Backup/hotjigsaw_r2")
# Mutable so --out / --fps can retarget a run (e.g. the 24fps re-encode)
# without disturbing the previous output set, which doubles as rollback.
OUT_DIR = Path(r"D:/Backup/hotjigsaw_r2_webp")

# 24fps matches what is actually in the bucket today (sampled objects decode to
# 241 frames over 10s). The original 12fps pass was superseded by the 24fps
# re-encode; --fps still overrides for one-off experiments.
FPS = 24
WIDTH = 256
QUALITY = 60
PARALLEL = max(2, (os.cpu_count() or 4) // 2)

ACC = "25d974e94beddd70f6923d50e7222e68"
BUCKET = "hotjigsaw"
KEY_FILE = r"D:/keys/cloudflare_global_api_key.txt"
EMAIL = "koplayer17@gmail.com"


def r2_key_for(flat_name: str) -> str:
    # collections__air_mage__videos__1.webp -> collections/air_mage/videos_webp/1.webp
    key = flat_name.replace("__", "/")
    return key.replace("/videos/", "/videos_webp/")


def encode_file(src: Path, dest: Path, fps: int = None, width: int = None,
                quality: int = None) -> tuple[bool, str]:
    """Encode one mp4 to an animated WebP. Returns (ok, error-text).

    Single source of truth for the wall-video encode settings — r2manager calls
    this too, so accepted assets get byte-comparable WebPs to the bucket's
    existing ones. Writes via a .tmp file so a killed run can't leave a
    half-written WebP that later looks like a finished one.
    """
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".webp.tmp")
    proc = subprocess.run(
        [FFMPEG, "-y", "-i", str(src),
         "-vf", f"fps={fps or FPS},scale={width or WIDTH}:-2:flags=lanczos",
         "-c:v", "libwebp_anim", "-q:v", str(quality or QUALITY),
         "-loop", "0", "-an", "-f", "webp", str(tmp)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0 or not tmp.exists() or tmp.stat().st_size == 0:
        tmp.unlink(missing_ok=True)
        return (False, proc.stderr[-300:])
    tmp.replace(dest)
    return (True, "")


def encode_one(src: Path) -> tuple[str, bool, str]:
    dest = OUT_DIR / (src.stem + ".webp")
    if dest.exists() and dest.stat().st_size > 0:
        return (src.name, True, "skip")
    ok, err = encode_file(src, dest)
    return (src.name, ok, "ok" if ok else err)


def encode_all() -> bool:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sources = sorted(SRC_DIR.glob("collections__*__videos__*.mp4"))
    print(f"encode: {len(sources)} sources, {PARALLEL} parallel", flush=True)
    failed = []
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=PARALLEL) as ex:
        for name, ok, msg in ex.map(encode_one, sources):
            done += 1
            if not ok:
                failed.append(name)
                print(f"FAIL {name}: {msg}", flush=True)
            if done % 100 == 0:
                print(f"  {done}/{len(sources)}", flush=True)
    total_mb = sum(f.stat().st_size for f in OUT_DIR.glob("*.webp")) / 1e6
    print(f"encode done: {done - len(failed)} ok, {len(failed)} failed, "
          f"total {total_mb:.0f} MB", flush=True)
    return not failed


def headers() -> dict:
    key = open(KEY_FILE).read().strip()
    return {"X-Auth-Email": EMAIL, "X-Auth-Key": key}


def base_url() -> str:
    return f"https://api.cloudflare.com/client/v4/accounts/{ACC}/r2/buckets/{BUCKET}/objects"


def remote_sizes() -> dict:
    sizes, cursor = {}, None
    while True:
        url = base_url() + "?per_page=1000" + (f"&cursor={cursor}" if cursor else "")
        d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers=headers())))
        for o in d.get("result", []):
            sizes[o["key"]] = o["size"]
        cursor = d.get("result_info", {}).get("cursor")
        if not cursor or not d.get("result"):
            return sizes


def put(key: str, data: bytes) -> None:
    req = urllib.request.Request(
        f"{base_url()}/{urllib.parse.quote(key, safe='')}",
        data=data, method="PUT",
        headers={**headers(), "Content-Type": "image/webp"},
    )
    urllib.request.urlopen(req, timeout=300).read()


def upload_all() -> bool:
    files = sorted(OUT_DIR.glob("collections__*__videos__*.webp"))
    print(f"upload: {len(files)} files", flush=True)
    existing = remote_sizes()
    print(f"  bucket has {len(existing)} objects", flush=True)
    uploaded = skipped = errors = 0
    for f in files:
        key = r2_key_for(f.name)
        size = f.stat().st_size
        if existing.get(key) == size:
            skipped += 1
            continue
        for attempt in (1, 2, 3):
            try:
                put(key, f.read_bytes())
                uploaded += 1
                break
            except Exception as e:
                if attempt == 3:
                    errors += 1
                    print(f"FAIL {key}: {e}", flush=True)
        if (uploaded + skipped) % 100 == 0:
            print(f"  {uploaded + skipped}/{len(files)} (up {uploaded}, skip {skipped})", flush=True)
    print(f"upload done: {uploaded} uploaded, {skipped} skipped, {errors} errors", flush=True)
    return errors == 0


def main() -> None:
    global FPS, OUT_DIR
    ap = argparse.ArgumentParser()
    ap.add_argument("--encode-only", action="store_true")
    ap.add_argument("--upload-only", action="store_true")
    ap.add_argument("--fps", type=int, default=FPS)
    ap.add_argument("--out", type=Path, default=OUT_DIR)
    args = ap.parse_args()
    FPS = args.fps
    OUT_DIR = args.out
    print(f"fps={FPS} out={OUT_DIR}", flush=True)

    ok = True
    if not args.upload_only:
        ok = encode_all()
    if not args.encode_only:
        ok = upload_all() and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
