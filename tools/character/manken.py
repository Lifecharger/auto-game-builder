r"""Manken (Blender) surucu videosu - `mixamo_manken_render.py`'yi kutuphane gibi cagirir.

Blender headless bir alt surectir; sunucu bu modulun `render()` fonksiyonunu
kullanir (CPU isi, GPU seridi ALMAZ).

    python manken.py --fbx "Great Sword Slash [c9cc7d9c].fbx" --out manken.mp4 \
           --azimuth 45 [--canvas 640] [--prop sword --prop_len 0.95] [--bbox_fbx a.fbx b.fbx]
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path

try:
    from . import common as C
except ImportError:
    import common as C

SCRIPT = C.HERE / "mixamo_manken_render.py"
KEEP = ("MANKEN", "FG_RATIO", "TAMAM", "HATA", "Error", "Traceback")


def fbx_path(name: str) -> Path:
    """Arsivdeki tam dosya adi ya da tam yol."""
    p = Path(name)
    if p.is_file():
        return p
    p = C.MIXAMO_DIR / name
    if not p.is_file():
        raise ValueError("Mixamo klibi bulunamadi: %s" % name)
    return p


def render(fbx: str, out, azimuth: float = 0.0, canvas: int = 640, pad: float = 0.06,
           fps: int = 30, prop: str = "", prop_len: float = 1.0, bbox_fbx=None,
           elev: float = 0.0, log=print) -> dict:
    """Bir klip icin manken videosu + yaninda <out>.json (kamera bilgisi)."""
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if not os.path.isfile(C.BLENDER):
        raise ValueError("Blender bulunamadi: %s (ayar: character.blender)" % C.BLENDER)
    cmd = [C.BLENDER, "-b", "--python", str(SCRIPT), "--",
           "--fbx", str(fbx_path(fbx)), "--out", str(out),
           "--w", str(canvas), "--h", str(canvas),
           "--azimuth", str(azimuth), "--elev", str(elev), "--pad", str(pad), "--fps", str(fps)]
    if prop:
        cmd += ["--prop", prop, "--prop_len", str(prop_len)]
    if bbox_fbx:
        cmd += ["--bbox_fbx"] + [str(fbx_path(b)) for b in bbox_fbx]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    kayit = [l for l in (r.stdout + r.stderr).splitlines() if any(k in l for k in KEEP)]
    for l in kayit[-4:]:
        log(l.strip()[:200])
    if r.returncode != 0 or not out.is_file():
        raise RuntimeError("manken render basarisiz: " + (kayit[-1][:300] if kayit else "cikti yok"))
    meta = {}
    js = out.with_suffix(".json")
    if js.is_file():
        try:
            meta = json.loads(js.read_text(encoding="utf-8"))
        except Exception:
            meta = {}
    meta.update({"fbx": fbx, "azimuth": azimuth, "canvas": canvas, "prop": prop, "prop_len": prop_len})
    js.write_text(json.dumps(meta, indent=1), encoding="utf-8")
    return meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--azimuth", type=float, default=0.0)
    ap.add_argument("--canvas", type=int, default=640)
    ap.add_argument("--pad", type=float, default=0.06)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--prop", default="")
    ap.add_argument("--prop_len", type=float, default=1.0)
    ap.add_argument("--bbox_fbx", nargs="*", default=[])
    a = ap.parse_args()
    print(json.dumps(render(a.fbx, a.out, a.azimuth, a.canvas, a.pad, a.fps,
                            a.prop, a.prop_len, a.bbox_fbx), indent=1))


if __name__ == "__main__":
    main()
