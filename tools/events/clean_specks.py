"""Mechanical alignment repair for live v2 packs: keyed sprites carry stray specks (a few
pixels the chroma key left far from the object), and the trim then includes them, so the
object sits off-centre in its box and never lines up with the game's anchor (Valentine's
ring rode outside its heart orbit because of one speck in the corner).

For every still sprite in a pack (not backgrounds, not strips): drop alpha islands smaller
than 1.5 % of the biggest one, trim to what is left, re-save under a new revision with the
w/h in field units, and publish. Strips and backgrounds are left alone.

    python clean_specks.py [event ...] [--dry]
"""
from __future__ import annotations

import io
import json
import re
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "C:/Projects/Auto Game Builder/tools/r2")
import r2_s3  # noqa: E402
from build_v2_pack import ART_SCALE, BUCKET, CACHE_IMG, CACHE_JSON, MIRROR, ROOT  # noqa: E402
from pack_lock import pack_lock  # noqa: E402

SKIP_ROLES = {"background"}
EVENTS = ["winter_queen", "valentine", "carnival", "cherry_blossom", "spring_bunny", "midsummer", "summer",
          "oktoberfest", "halloween", "vampire_ball", "christmas", "newyear", "season_spring", "season_summer",
          "season_autumn", "season_winter"]


def clean(im: Image.Image) -> tuple[Image.Image, int]:
    a = np.asarray(im.convert("RGBA")).copy()
    alpha = a[..., 3]
    mask = (alpha > 24).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if n <= 2:
        dropped = 0
    else:
        areas = stats[1:, cv2.CC_STAT_AREA]
        keep_min = areas.max() * 0.015
        dropped = 0
        for lab in range(1, n):
            if stats[lab, cv2.CC_STAT_AREA] < keep_min:
                a[labels == lab, 3] = 0
                dropped += 1
    # also clear the faint alpha haze that is not near any kept pixel
    keep = cv2.dilate((a[..., 3] > 24).astype(np.uint8), np.ones((5, 5), np.uint8))
    a[..., 3] = np.where(keep > 0, a[..., 3], 0)
    ys, xs = np.where(a[..., 3] > 8)
    if len(xs) == 0:
        return im, 0
    # re-centre the object in the SAME canvas: size and aspect stay (views draw
    # sprites into fixed boxes), only the offset a speck caused goes
    h, w = a.shape[:2]
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    obj = a[y0:y1, x0:x1]
    nx, ny = (w - (x1 - x0)) // 2, (h - (y1 - y0)) // 2
    shift = abs(nx - x0) + abs(ny - y0)
    if dropped == 0 and shift <= 3:
        return im, 0
    canvas = np.zeros_like(a)
    canvas[ny:ny + obj.shape[0], nx:nx + obj.shape[1]] = obj
    return Image.fromarray(canvas, "RGBA"), dropped + (1 if shift > 3 else 0)


def next_rev(pack: dict) -> int:
    revs = [int(m) for m in re.findall(r"\.r(\d+)\.webp", json.dumps(pack))]
    return (max(revs) if revs else 0) + 1


def run(event: str, dry: bool) -> None:
    pack = json.loads(r2_s3.get_object(BUCKET, f"minigames/v2/{event}/pack.json"))
    base = pack.get("base") or f"minigames/v2/{event}/"
    rev = next_rev(pack)
    out_dir = ROOT / event
    out_dir.mkdir(parents=True, exist_ok=True)
    uploads = []
    report = []
    for key, row in pack.get("assets", {}).items():
        if row.get("role") in SKIP_ROLES or int(row.get("frames") or 1) > 1:
            continue
        if key in ("girl_idle", "girl_kiss", "hub_bg") or key.startswith("bg_"):
            continue
        f = row["file"]
        path = f if f.startswith("minigames/") else base + f
        try:
            data = r2_s3.get_object(BUCKET, path)
        except Exception as ex:  # noqa: BLE001
            report.append(f"{key}: fetch failed {ex}")
            continue
        im = Image.open(io.BytesIO(data)).convert("RGBA")
        new, changed = clean(im)
        if not changed:
            continue
        # keep the SAME scale: field units per pixel stay ART_SCALE
        name = f"{key}.r{rev}.webp"
        dst = out_dir / name
        new.save(dst, "WEBP", quality=90, method=6)
        row.update({"file": f"{base}{name}", "w": round(new.width / ART_SCALE, 2), "h": round(new.height / ART_SCALE, 2),
                    "px": {"w": new.width, "h": new.height}, "bytes": dst.stat().st_size})
        uploads.append((dst, f"{base}{name}"))
        report.append(f"{key}: {im.size} -> {new.size}")
    # hub icons too (they sit in hub.icons)
    for name_, icon in (pack.get("hub", {}).get("icons") or {}).items():
        f = icon["file"]
        path = f if f.startswith("minigames/") else base + f
        try:
            im = Image.open(io.BytesIO(r2_s3.get_object(BUCKET, path))).convert("RGBA")
        except Exception:  # noqa: BLE001
            continue
        new, changed = clean(im)
        if not changed:
            continue
        name = f"icon_{name_}.r{rev}.webp"
        dst = out_dir / name
        new.save(dst, "WEBP", quality=90, method=6)
        icon.update({"file": f"{base}{name}", "w": round(new.width / ART_SCALE, 2), "h": round(new.height / ART_SCALE, 2),
                     "bytes": dst.stat().st_size})
        uploads.append((dst, f"{base}{name}"))
        report.append(f"icon {name_}: {im.size} -> {new.size}")
    print(f"== {event}: {len(uploads)} cleaned")
    for r in report:
        print("  ", r)
    if dry or not uploads:
        return
    pack["version"] = int(pack.get("version") or 2) + 1
    manifest = out_dir / "pack.json"
    manifest.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    for f, key in uploads:
        r2_s3._call("PUT", BUCKET, key, headers={"content-type": "image/webp", "cache-control": CACHE_IMG}, body=f.read_bytes())
    r2_s3._call("PUT", BUCKET, base + "pack.json", headers={"content-type": "application/json", "cache-control": CACHE_JSON},
                body=manifest.read_bytes())
    if MIRROR.exists():
        for f, key in uploads + [(manifest, base + "pack.json")]:
            d = MIRROR / key
            d.parent.mkdir(parents=True, exist_ok=True)
            d.write_bytes(Path(f).read_bytes())
    print(f"   published v{pack['version']}")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry" in sys.argv
    for ev in args or EVENTS:
        with pack_lock(ev):
            run(ev, dry)
