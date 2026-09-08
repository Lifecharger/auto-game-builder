r"""8 yon (turnaround) uretimi: kabul edilen gorunusten Qwen Image Edit 2511 ile
front disindaki 7 gorunus.

    python yon_uret.py --src "<...>/outfits/freya_signature.png" \
                       --out_dir "<...>/turnaround" [--n 2] [--dirs right,back,left]

- front = kaynagin kendisi (kopyalanir), uretilmez.
- Uc-ceyrek yonler (front_right, back_right, ...) icin kamera cumlesi ACIKTIR:
  hangi omuz one geliyor, karakter kac derece donuyor - yoksa Qwen tam profil
  ile uc-ceyregi karistiriyor.
- Kimlik kilidi (KEEP) her istemde aynen tekrarlanir; fon cumlesi common.BG_CLAUSE.
ComfyUI paylasimlidir: yalniz kuyruga is birakilir (feedback-comfyui-shared).
"""
from __future__ import annotations

import argparse
import json
import os
import random
import shutil
from pathlib import Path

try:
    from . import common as C
except ImportError:
    import common as C

# #314: metinler artik SABLON - ozne/zamir jetonlari karakterin turunden gelir
# (sunucu: server/core/character_flow.KIND_PROFILES, tek kaynak). Asagidaki
# FEMALE jetonlari yalniz komut satiri kullanimi ve geriye uyumluluk icindir;
# render(profil) ile uretilen female metni ESKI metinle BIREBIR AYNIDIR.
FEMALE = {
    "subject": "woman", "subj": "she", "Subj": "She", "poss": "her", "Poss": "Her",
    "obj": "her", "garb": "outfit", "pose": "standing pose with arms relaxed",
    "frame": "full body from head to feet",
    "identity": "same face, same hair, same skin, same body proportions",
    "neg_id": "different face, different hair colour, different outfit",
}

KEEP_TMPL = ("Keep the exact same {subject}: {identity}, the exact same {garb} "
             "and accessories, same {pose}, same framing ({frame}), "
             "same " + C.BG_CLAUSE + ". Photorealistic.")

# Yon -> kamera cumlesi. 3/4 yonlerde hem kamera hem govde acisi soylenir.
# #304: kamera GUNEYDE, pusula: E = resmin SAG kenarina bakar, W = SOL kenara.
# Eski metinler celiskiliydi ("sag yanindan goster" + "sol kenara bakiyor") ve
# model iki cumleden birini rastgele seciyordu - East hep farkli cikiyordu.
# Her yonde hem hangi yani gordugumuz hem de hangi kenara baktigi soylenir.
PROMPT_TMPL = {
    "front_right": ("Rotate the camera to a THREE-QUARTER VIEW from {poss} FRONT-RIGHT: {subj} is turned 45 degrees "
                    "toward the RIGHT edge of the image, {poss} right shoulder is closer to the camera, we still see "
                    "most of {poss} face and the front of {poss} {garb}. {Subj} faces toward the right edge of the image."),
    "right":       ("Rotate the camera to show {obj} from {poss} RIGHT SIDE in a strict 90 degree side profile view: "
                    "we see {poss} right side, {poss} nose points to the RIGHT edge of the image, {subj} faces the right edge."),
    "back_right":  ("Rotate the camera to a THREE-QUARTER VIEW from {poss} BACK-RIGHT: {subj} is turned 135 degrees away "
                    "toward the RIGHT edge of the image, we mostly see {poss} back and the right side of {poss} body, "
                    "only a sliver of {poss} cheek on the right."),
    "back":        ("Rotate the camera to show {obj} from BEHIND in a strict back view, we see the back of {poss} head, "
                    "{poss} back and the back of {poss} {garb}."),
    "back_left":   ("Rotate the camera to a THREE-QUARTER VIEW from {poss} BACK-LEFT: {subj} is turned 135 degrees away "
                    "toward the LEFT edge of the image, we mostly see {poss} back and the left side of {poss} body, "
                    "only a sliver of {poss} cheek on the left."),
    "left":        ("Rotate the camera to show {obj} from {poss} LEFT SIDE in a strict 90 degree side profile view: "
                    "we see {poss} left side, {poss} nose points to the LEFT edge of the image, {subj} faces the left edge."),
    "front_left":  ("Rotate the camera to a THREE-QUARTER VIEW from {poss} FRONT-LEFT: {subj} is turned 45 degrees "
                    "toward the LEFT edge of the image, {poss} left shoulder is closer to the camera, we still see "
                    "most of {poss} face and the front of {poss} {garb}. {Subj} faces toward the left edge of the image."),
}
NEG_TMPL = ("anime, cartoon, illustration, 3d render, deformed, extra limbs, bad hands, bad anatomy, watermark, text, "
            "{neg_id}, cropped head, cropped feet, front view")


def render(kind_profile: dict | None = None) -> dict:
    """#314: sablonlari bir tur profiliyle doldurur.

    kind_profile = character_flow.KIND_PROFILES[<tur>] (ya da ondan turetilmis
    ozne degistirilmis kopya). Eksik alanlar FEMALE'den tamamlanir, yani
    render() (bos cagri) eski female metinlerini aynen verir.
    """
    t = dict(FEMALE)
    t.update({k: v for k, v in (kind_profile or {}).items() if isinstance(v, str) and v})
    return {"prompts": {k: v.format(**t) for k, v in PROMPT_TMPL.items()},
            "keep": KEEP_TMPL.format(**t), "neg": NEG_TMPL.format(**t)}


_FEMALE_RENDER = render()
PROMPTS = _FEMALE_RENDER["prompts"]      # geriye uyumluluk (female render'i)
KEEP = _FEMALE_RENDER["keep"]
NEG = _FEMALE_RENDER["neg"]


def submit(image_name: str, prompt: str, seed: int) -> str:
    wf = json.loads((C.WORKFLOWS / C.EDIT_WORKFLOW).read_text(encoding="utf-8"))
    g = C.converter()(wf, {"positive_prompt": "%s %s" % (prompt, KEEP), "negative_prompt": NEG,
                           "seed": seed, "enable_turbo_mode": True})
    for n in g.values():
        if n["class_type"] == "LoadImage":
            n["inputs"]["image"] = image_name
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "character/turnaround"
    return C.enqueue(g, "chdir")


def generate(src, out_dir, dirs=None, n: int = 2, log=print) -> dict:
    """Secili yonler icin n aday uretir; {yon: [dosya...]} doner. front kopyalanir."""
    src, out_dir = Path(src), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    dirs = [d for d in (dirs or [d for d in C.DIR_ORDER if d != "front"]) if d in PROMPTS]
    if not out_dir.joinpath("front.png").is_file():
        shutil.copy(str(src), str(out_dir / "front.png"))
    image_name = C.stage_input(src, "chyon")
    jobs = []
    for d in dirs:
        for i in range(1, max(1, n) + 1):
            seed = random.randint(1, 2 ** 31)
            jobs.append((d, i, submit(image_name, PROMPTS[d], seed), seed))
            log("%s_%02d kuyrukta (seed %d)" % (d, i, seed))
    out: dict[str, list[str]] = {}
    for d, i, pid, seed in jobs:
        try:
            files = C.outputs(C.wait(pid, 1800), ("images",))
        except Exception as e:
            log("%s_%02d HATA: %s" % (d, i, str(e)[:160]))
            continue
        if not files:
            log("%s_%02d cikti yok" % (d, i))
            continue
        # bos numara bul (mevcut adaylarin ustune yazma)
        k = i
        while (out_dir / ("%s_%02d.png" % (d, k))).is_file():
            k += 1
        dst = out_dir / ("%s_%02d.png" % (d, k))
        shutil.copy(str(files[0]), str(dst))
        out.setdefault(d, []).append(dst.name)
        log("%s -> %s" % (d, dst.name))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out_dir", required=True)
    ap.add_argument("--n", type=int, default=2)
    ap.add_argument("--dirs", default=",".join(d for d in C.DIR_ORDER if d != "front"))
    a = ap.parse_args()
    res = generate(a.src, a.out_dir, [d for d in a.dirs.split(",") if d], a.n)
    print(json.dumps(res, indent=1))
    print("BITTI")


if __name__ == "__main__":
    main()
