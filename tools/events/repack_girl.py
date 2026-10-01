"""Put a REAL girl into a live v2 pack: the keyed full-body still and her idle / kiss
strips cut from Imagine-agent videos, published under a new revision.

    python repack_girl.py <event> --still img.jpg --idle idle.mp4 --kiss kiss.mp4
        [--kiss-start 0.3 --kiss-end 3.0] [--idle-frames 16] [--kiss-frames 10] [--no-upload]

Reads the pack.json that is live for the event (downloaded to <event>/_live/pack.json),
writes girl/idle_south_<n>f.r<R>.webp + girl/kiss_south_<n>f.r<R>.webp (one padded cell,
height 384 px) and girl_idle.r<R>.webp / girl_kiss.r<R>.webp (the keyed still), rewrites
the `girl` rig block and the two asset rows, bumps `version`, uploads, mirrors.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
from build_v2_pack import ART_SCALE, BUCKET, CACHE_IMG, CACHE_JSON, MIRROR, ROOT, pad_rig, scene, sprite  # noqa: E402

CDN = "https://events.lifechargergames.com/"


def live_pack(event: str) -> dict:
    """The pack as it is on R2 right now (never the CDN copy, which may be up to 6 h old
    and would drop another pipeline's changes)."""
    dst = ROOT / event / "_live" / "pack.json"
    dst.parent.mkdir(parents=True, exist_ok=True)
    data = r2_s3.get_object(BUCKET, f"minigames/v2/{event}/pack.json")
    dst.write_bytes(data)
    return json.loads(data)


def next_rev(pack: dict) -> int:
    revs = [int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))]
    return (max(revs) if revs else 0) + 1


def cut(src: str, dst: Path, frames: int, height: int, start: float, end: float | None, loop: bool) -> None:
    cmd = [sys.executable, str(HERE / "video_to_strip.py"), src, str(dst), "--frames", str(frames),
           "--height", str(height), "--start", str(start)]
    if end is not None:
        cmd += ["--end", str(end)]
    if loop:
        # a breathing idle: the best-matching window, but never shorter than 3 s,
        # or the picker settles on a near-still half second
        cmd += ["--loop", "--min-span", "3", "--max-span", "6"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0 or not dst.exists():
        raise SystemExit(f"strip failed for {src}: {out.stderr[-400:]}")
    print(" ", out.stdout.strip().splitlines()[-1][:120])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("--still", required=True)
    ap.add_argument("--idle", required=True)
    ap.add_argument("--kiss", required=True)
    ap.add_argument("--idle-frames", type=int, default=16)
    ap.add_argument("--kiss-frames", type=int, default=10)
    ap.add_argument("--kiss-start", type=float, default=0.3)
    ap.add_argument("--kiss-end", type=float, default=3.0)
    ap.add_argument("--idle-fps", type=int, default=10)
    ap.add_argument("--kiss-fps", type=int, default=6)
    ap.add_argument("--still-box", default="108x192", help="units WxH the still is fitted into")
    ap.add_argument("--hub-bg", help="a new painted hub scene (9:16); replaces hub.bg and assets.hub_bg")
    ap.add_argument("--no-upload", action="store_true")
    a = ap.parse_args()

    event = a.event
    pack = live_pack(event)
    rev = next_rev(pack)
    base = pack.get("base") or f"minigames/v2/{event}/"
    out = ROOT / event
    girl_dir = out / "girl"
    girl_dir.mkdir(parents=True, exist_ok=True)
    print(f"{event}: live v{pack.get('version')} -> rev r{rev}")

    # 1. the strips (cell height 384 like every painted rig)
    idle_name = f"idle_south_{a.idle_frames}f.webp"
    kiss_name = f"kiss_south_{a.kiss_frames}f.webp"
    cut(a.idle, girl_dir / idle_name, a.idle_frames, 384, 0.0, None, loop=True)
    cut(a.kiss, girl_dir / kiss_name, a.kiss_frames, 384, a.kiss_start, a.kiss_end, loop=False)

    # 2. one padded cell for both, written as .r<rev>
    import build_v2_pack as b
    b.REV = rev
    clips = {"idle": {"south": (idle_name, a.idle_fps, "loop")}, "kiss": {"south": (kiss_name, a.kiss_fps, "once")}}
    # keep every OTHER clip the rig already has (run, shoot, dance...): a new hub
    # girl must not wipe the game's own clips (it did, for summer)
    for anim, dirs in (pack.get("girl") or {}).get("animations", {}).items():
        if anim in clips:
            continue
        for direction, row in dirs.items():
            plain = re.sub(r"\.r\d+\.webp$", ".webp", Path(row["file"]).name)
            if (girl_dir / plain).exists():
                clips.setdefault(anim, {})[direction] = (plain, row.get("fps", 8), row.get("play", "loop"))
            else:
                print(f"  WARN clip {anim}/{direction} has no source strip on disk ({plain}); it is dropped")
    cell_w, cell_h, info = pad_rig(girl_dir, clips)
    anims = {}
    uploads: list[tuple[Path, str, str]] = []
    for anim, dirs in clips.items():
        anims[anim] = {}
        for direction, (file, fps, play) in dirs.items():
            rfile = file.replace(".webp", f".r{rev}.webp")
            anims[anim][direction] = {"file": f"{base}girl/{rfile}", "frames": info[file]["frames"],
                                      "fps": fps, "play": play, "bytes": info[file]["bytes"]}
            uploads.append((girl_dir / rfile, f"{base}girl/{rfile}", "image/webp"))
    star = pack.get("star") or (pack.get("girl") or {}).get("id") or "girl"
    pack["girl"] = {
        "id": star, "base": f"{base}girl/",
        "frameWidth": round(cell_w / ART_SCALE, 2), "frameHeight": round(cell_h / ART_SCALE, 2),
        "pixelFrame": {"w": cell_w, "h": cell_h},
        "pivot": {"x": round(cell_w / 2 / ART_SCALE, 2), "y": round((cell_h - 6) / ART_SCALE, 2)},
        "animations": anims,
    }

    # 3. the keyed still for girl_idle / girl_kiss asset rows
    bw, bh = (int(v) for v in a.still_box.lower().split("x"))
    w, h, nb = sprite(a.still, out / f"girl_idle.r{rev}.webp", (bw, bh))
    assets = pack.setdefault("assets", {})
    for key in ("girl_idle", "girl_kiss"):
        assets[key] = {"file": f"{base}girl_idle.r{rev}.webp", "role": "character",
                       "w": round(w / ART_SCALE, 2), "h": round(h / ART_SCALE, 2),
                       "px": {"w": w, "h": h}, "bytes": nb}
    uploads.append((out / f"girl_idle.r{rev}.webp", f"{base}girl_idle.r{rev}.webp", "image/webp"))

    # 4. a new hub scene, when one was rendered
    if a.hub_bg:
        hw, hh, hb = scene(a.hub_bg, out / f"hub_bg.r{rev}.webp")
        row = {"file": f"{base}hub_bg.r{rev}.webp", "role": "background",
               "w": round(hw / ART_SCALE, 2), "h": round(hh / ART_SCALE, 2), "px": {"w": hw, "h": hh}, "bytes": hb}
        assets["hub_bg"] = row
        pack.setdefault("hub", {})["bg"] = {"file": row["file"], "w": row["w"], "h": row["h"], "bytes": hb}
        uploads.append((out / f"hub_bg.r{rev}.webp", f"{base}hub_bg.r{rev}.webp", "image/webp"))

    pack["version"] = int(pack.get("version") or 2) + 1
    pack["totalBytes"] = sum(v.get("bytes", 0) for v in assets.values()) + sum(
        s["bytes"] for d in anims.values() for s in d.values())
    manifest = out / "pack.json"
    manifest.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  rig {cell_w}x{cell_h} px, still {w}x{h}, pack v{pack['version']} -> {manifest}")

    if MIRROR.exists():
        for f, key, _ in uploads + [(manifest, base + "pack.json", "")]:
            dst = MIRROR / key
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, dst)
    if a.no_upload:
        return
    for f, key, ctype in uploads:
        body = f.read_bytes()
        r2_s3._call("PUT", BUCKET, key, headers={"content-type": ctype, "cache-control": CACHE_IMG}, body=body)
        print(f"  put {len(body):8d}  {key}")
    body = manifest.read_bytes()
    r2_s3._call("PUT", BUCKET, base + "pack.json",
                headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
    print(f"  put {len(body):8d}  {base}pack.json")


if __name__ == "__main__":
    from pack_lock import pack_lock
    with pack_lock(sys.argv[1]):
        main()
