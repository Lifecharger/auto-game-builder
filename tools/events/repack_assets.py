"""Add or replace IN-GAME art in a live v2 pack from Imagine-agent outputs, under a new revision.

    python repack_assets.py <event> --plan plan.json [--no-upload]

plan.json:
{
  "stills":   {"throne": {"src": "img.jpg", "box": [48, 64], "role": "sprite"}, ...},
  "fx":       {"shatter_8f": {"src": "clip.mp4", "frames": 8, "box": [48, 48], "start": 0.2, "end": 3.0,
                              "fps": 10, "play": "once", "loop": false}, ...},
  "girl":     {"run": {"src": "clip.mp4", "frames": 8, "fps": 10, "play": "loop", "start": 0, "end": null,
                       "loop": true}, ...},
  "npc":      {"id": "crow", "clips": {"peck": {...}, "flee": {...}}}
}
Stills are keyed and fitted into `box` units (sprite()); fx clips become horizontal strips whose
cell is `box` units tall; girl/npc clips join the rig (all clips re-padded to one cell, height 384).
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

from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
import build_v2_pack as b  # noqa: E402
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


def cut(src: str, dst: Path, frames: int, height: int, start: float, end, loop: bool) -> dict:
    cmd = [sys.executable, str(HERE / "video_to_strip.py"), src, str(dst), "--frames", str(frames),
           "--height", str(height), "--start", str(start)]
    if end is not None:
        cmd += ["--end", str(end)]
    if loop:
        cmd += ["--loop", "--min-span", "2", "--max-span", "6"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0 or not dst.exists():
        raise SystemExit(f"strip failed for {src}: {out.stderr[-500:]}")
    return json.loads(out.stdout.strip().splitlines()[-1])


def rig_folder_clips(folder: Path) -> dict:
    """Existing unrevisioned clips in a rig folder: {anim: {dir: (file, fps, play)}} read from the live pack."""
    return {}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("event")
    ap.add_argument("--plan", required=True)
    ap.add_argument("--no-upload", action="store_true")
    a = ap.parse_args()
    event = a.event
    plan = json.loads(Path(a.plan).read_text(encoding="utf-8"))
    pack = live_pack(event)
    rev = next_rev(pack)
    b.REV = rev
    base = pack.get("base") or f"minigames/v2/{event}/"
    out = ROOT / event
    out.mkdir(parents=True, exist_ok=True)
    assets = pack.setdefault("assets", {})
    uploads: list[tuple[Path, str, str]] = []
    print(f"{event}: live v{pack.get('version')} -> rev r{rev}")

    def add(key, file, w, h, nb, role, **extra):
        assets[key] = {"file": f"{base}{file}", "role": role, "w": round(w / ART_SCALE, 2), "h": round(h / ART_SCALE, 2),
                       "px": {"w": w, "h": h}, "bytes": nb, **extra}
        uploads.append((out / file, f"{base}{file}", "image/webp"))

    # scenes: full 9:16 backgrounds (bg_field_portrait, bg_screen_portrait, hub_bg)
    for key, src in plan.get("scenes", {}).items():
        file = f"{key}.r{rev}.webp"
        w, h, nb = scene(src, out / file)
        add(key, file, w, h, nb, "background")
        if key == "hub_bg":
            pack.setdefault("hub", {})["bg"] = {"file": f"{base}{file}", "w": round(w / ART_SCALE, 2),
                                                "h": round(h / ART_SCALE, 2), "bytes": nb}
        print(f"  scene {key} {w}x{h}")

    # hub icons: keyed, 32 units tall, into hub.icons
    for name, src in plan.get("hub_icons", {}).items():
        file = f"icon_{name}.r{rev}.webp"
        w, h, nb = sprite(src, out / file, (32, 32))
        pack.setdefault("hub", {}).setdefault("icons", {})[name] = {
            "file": f"{base}{file}", "w": round(w / ART_SCALE, 2), "h": round(h / ART_SCALE, 2), "bytes": nb}
        uploads.append((out / file, f"{base}{file}", "image/webp"))
        print(f"  hub icon {name} {w}x{h}")

    # stills: keyed, fitted into the box
    for key, spec in plan.get("stills", {}).items():
        file = f"{key}.r{rev}.webp"
        w, h, nb = sprite(spec["src"], out / file, tuple(spec.get("box", [40, 40])))
        add(key, file, w, h, nb, spec.get("role", "sprite"))
        print(f"  still {key} {w}x{h}")

    # fx strips: a keyed video cut into N cells
    for key, spec in plan.get("fx", {}).items():
        frames = spec["frames"]
        box = spec.get("box", [40, 40])
        file = f"{key}.r{rev}.webp"
        meta = cut(spec["src"], out / file, frames, box[1] * ART_SCALE, spec.get("start", 0.0), spec.get("end"),
                   spec.get("loop", False))
        im = Image.open(out / file)
        add(key, file, im.width // frames, im.height, (out / file).stat().st_size, spec.get("role", "effect"),
            frames=frames, fps=spec.get("fps", 10), play=spec.get("play", "once"))
        print(f"  fx {key} {frames}f cell {im.width // frames}x{im.height} (src fps {meta.get('fps')})")

    # rigs: new clips join the existing ones, everything re-padded to one cell
    for rig_name in ("girl", "npc"):
        spec = plan.get(rig_name)
        if not spec:
            continue
        clips_in = spec["clips"] if rig_name == "npc" else spec
        # {"_repad": true}: no new clip, just re-pad and republish the rig from its plain sources
        # (after a strip was cleaned in place, e.g. strip_sea_leak.py)
        clips_in = {k: v for k, v in clips_in.items() if not k.startswith("_")}
        folder = out / rig_name
        folder.mkdir(exist_ok=True)
        block = pack.get(rig_name) or {}
        clips: dict = {}
        # keep what the pack already has, when its unrevisioned source is on disk
        for anim, dirs in block.get("animations", {}).items():
            for direction, row in dirs.items():
                fname = Path(row["file"]).name
                plain = re.sub(r"\.r\d+\.webp$", ".webp", fname)
                if (folder / plain).exists():
                    clips.setdefault(anim, {})[direction] = (plain, row.get("fps", 8), row.get("play", "loop"))
        direction_default = "south" if rig_name == "girl" else "east"
        for anim, c in clips_in.items():
            frames = c["frames"]
            plain = f"{anim}_{direction_default}_{frames}f.webp"
            cut(c["src"], folder / plain, frames, 384 if rig_name == "girl" else c.get("height", 200),
                c.get("start", 0.0), c.get("end"), c.get("loop", c.get("play", "loop") == "loop"))
            clips.setdefault(anim, {})[direction_default] = (plain, c.get("fps", 8), c.get("play", "loop"))
            print(f"  {rig_name} clip {anim} {frames}f")
        cell_w, cell_h, info = pad_rig(folder, clips)
        anims = {}
        for anim, dirs in clips.items():
            anims[anim] = {}
            for direction, (file, fps, play) in dirs.items():
                rfile = file.replace(".webp", f".r{rev}.webp")
                anims[anim][direction] = {"file": f"{base}{rig_name}/{rfile}", "frames": info[file]["frames"],
                                          "fps": fps, "play": play, "bytes": info[file]["bytes"]}
                uploads.append((folder / rfile, f"{base}{rig_name}/{rfile}", "image/webp"))
        pack[rig_name] = {
            "id": block.get("id") or spec.get("id") or (pack.get("star") if rig_name == "girl" else "npc"),
            "base": f"{base}{rig_name}/",
            "frameWidth": round(cell_w / ART_SCALE, 2), "frameHeight": round(cell_h / ART_SCALE, 2),
            "pixelFrame": {"w": cell_w, "h": cell_h},
            "pivot": {"x": round(cell_w / 2 / ART_SCALE, 2), "y": round((cell_h - 6) / ART_SCALE, 2)},
            "animations": anims,
        }
        print(f"  {rig_name} rig {cell_w}x{cell_h}: {sorted(anims)}")

    pack["version"] = int(pack.get("version") or 2) + 1
    manifest = out / "pack.json"
    manifest.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"  pack v{pack['version']} -> {manifest}")
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
    body = manifest.read_bytes()
    r2_s3._call("PUT", BUCKET, base + "pack.json",
                headers={"content-type": "application/json", "cache-control": CACHE_JSON}, body=body)
    print(f"  uploaded {len(uploads)} files + pack.json")


if __name__ == "__main__":
    from pack_lock import pack_lock
    with pack_lock(sys.argv[1]):
        main()
