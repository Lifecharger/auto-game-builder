r"""Karakter ADAYLARI (Z-Image-Turbo): kimlik prompt'undan n gorsel.

Sunucu (Uretim ekrani, mode="character") normalde bu isi comfy_gen ile yapar;
bu script komut satirindan hizli aday uretmek ve MODES["character"] sablonunu
tek yerde tutmak icin durur.

    python karakter_adaylari.py --name Freya --identity "..." --outfit "..." [--n 5]
    python karakter_adaylari.py --name Freya --set neutral --n 3

Cikti: <character.root>/<Isim>/candidates/<set>_<nn>.png
"""
from __future__ import annotations

import argparse
import json
import random
import shutil
from pathlib import Path

try:
    from . import common as C
except ImportError:
    import common as C

W, H = 832, 1472

# MODES["character"]["prompt2"] ile AYNI cumle - fon her iki uctan da ayni.
STUDIO = ("{} standing straight facing the camera, neutral relaxed pose, arms at her sides, full body from "
          "head to feet with empty space above and below, " + C.BG_CLAUSE +
          ", photorealistic, sharp focus, 85mm")
NEG = ("anime, cartoon, illustration, drawing, painting, 3d render, cgi, child, teen, minor, "
       "deformed, disfigured, extra limbs, extra fingers, bad hands, bad anatomy, "
       "watermark, text, logo, cluttered background, props, furniture, cropped feet, cropped head")

SETS = {"neutral": "wearing a simple plain black bikini",
        "costume": ""}          # costume = --outfit ile gelir


def submit(prompt: str, seed: int) -> str:
    wf = json.loads((C.WORKFLOWS / C.GEN_WORKFLOW).read_text(encoding="utf-8"))
    g = C.converter()(wf, {"prompt": prompt, "text": prompt, "negative_prompt": NEG,
                           "width": W, "height": H, "seed": seed, "noise_seed": seed})
    for n in g.values():
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "character/candidate"
    return C.enqueue(g, "chcand")


def generate(dest, identity: str, outfit: str = "", kind: str = "costume", n: int = 5,
             log=print) -> list[str]:
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    body = ", ".join(x for x in (identity.strip(" ,"), (outfit or SETS.get(kind, "")).strip(" ,")) if x)
    prompt = STUDIO.format(body)
    jobs = []
    for i in range(1, max(1, n) + 1):
        seed = random.randint(1, 2 ** 31)
        jobs.append((i, submit(prompt, seed), seed))
        log("%s_%02d kuyrukta (seed %d)" % (kind, i, seed))
    out = []
    for i, pid, seed in jobs:
        try:
            files = C.outputs(C.wait(pid, 1800), ("images",))
        except Exception as e:
            log("%s_%02d HATA: %s" % (kind, i, str(e)[:160]))
            continue
        if not files:
            continue
        k = i
        while dest.joinpath("%s_%02d.png" % (kind, k)).is_file():
            k += 1
        dst = dest / ("%s_%02d.png" % (kind, k))
        shutil.copy(str(files[0]), str(dst))
        out.append(dst.name)
        log("%s -> %s" % (kind, dst.name))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--identity", default="a stunning adult woman in her late 20s, athletic hourglass figure")
    ap.add_argument("--outfit", default="")
    ap.add_argument("--set", dest="kind", default="costume", choices=list(SETS))
    ap.add_argument("--n", type=int, default=5)
    a = ap.parse_args()
    dest = C.CHAR_ROOT / a.name / "candidates"
    print(json.dumps(generate(dest, a.identity, a.outfit, a.kind, a.n), indent=1))
    print("BITTI")


if __name__ == "__main__":
    main()
