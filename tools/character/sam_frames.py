r"""Wan Animate 2 klibi -> SAM3 ile KARE KARE kesilmis seffaf sprite kareleri.

Kullanicinin sarti: "arkaplan silme uygulamalari perfect calismiyor, SAM daha
guvenilir" -> birincil kesici SAM 3.1 (ComfyUI, CBN hattindaki ayni checkpoint),
isnet yalnizca (a) SAM'in patladigi kare icin yedek, (b) istege bagli kenar
rotusu icin kullanilir.

    python sam_frames.py --video wan.mp4 --out_dir <klip klasoru> [--fps 15]
           [--prompt woman] [--height 0] [--mirror] [--no-refine] [--chunk 48]

Akis
  1. ffmpeg  video -> _raw/f_%04d.png (fps kadar seyreltilir)
  2. SAM3    her kare icin bir /prompt grafigi; hepsi TEK SEFERDE kuyruga
             birakilir -> checkpoint bir kez yuklenir, N kare arka arkaya
             islenir (CBN #281 parti kurali). Her karede birden cok maske
             donebilir; en buyuk + en merkezi olan secilir.
  3. Zaman   maske alani komsularinin medyanindan %40'tan fazla sapiyorsa o
     tutarlilik  kare SUPHELI sayilir ve isnet yedegine dusulur.
  4. Kenar   isnet matte'i yalnizca SAM sinirinin +-BAND pikselik seridinde
     rotusu   yumusatma icin kullanilir (sac telleri); govde karari SAM'indir.
  5. Cikti   frames/*.png (RGBA, TUVAL KIRPILMAZ -> pivot sabit),
             anim.webp (loop), sheet.png (yatay serit), sprite.json.

ComfyUI paylasimlidir: kuyruga birakilir, restart/iptal yok.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import time
from pathlib import Path

import numpy as np

try:
    from . import common as C
except ImportError:                              # dogrudan script olarak
    import common as C

MIN_SHARE = 0.004          # bu paydan kucuk maske gurultudur
MAX_SHARE = 0.92           # tum kareyi kaplayan maske = fon yakalanmis
JUMP = 0.40                # komsulara gore kabul edilen en buyuk alan sicramasi
BAND = 4                   # kenar rotusu seridi (piksel)
TOUCH = 6                  # ek kavram govdeye bu kadar piksel yakinsa eklenir
PROJECTILE_MAX = 0.03      # kopuk ama bu paydan kucuk ek maske = mermi/ok, kalir


# ------------------------------------------------------------------ isnet
_sess = None


def isnet_session(model: str = ""):
    """isnet oturumu (yedek/kenar rotusu). Model yoksa None doner."""
    global _sess
    if _sess is not None:
        return _sess or None
    path = model or C.ISNET
    if not os.path.isfile(path):
        _sess = False
        return None
    try:
        import onnxruntime as ort
        prov = (["CUDAExecutionProvider", "CPUExecutionProvider"]
                if "CUDAExecutionProvider" in ort.get_available_providers() else ["CPUExecutionProvider"])
        _sess = ort.InferenceSession(path, providers=prov)
    except Exception:
        _sess = False
        return None
    return _sess


def isnet_matte(im) -> np.ndarray | None:
    """0..255 float matte (sprite_cikart.py ile ayni normalizasyon)."""
    from PIL import Image
    s = isnet_session()
    if s is None:
        return None
    inp = im.resize((1024, 1024), Image.BILINEAR)
    x = (np.asarray(inp).astype(np.float32) / 255.0 - 0.5).transpose(2, 0, 1)[None]
    out = s.run(None, {s.get_inputs()[0].name: x})[0][0][0]
    out = (out - out.min()) / (out.max() - out.min() + 1e-8)
    a = Image.fromarray((out * 255).astype(np.uint8)).resize(im.size, Image.BILINEAR)
    return np.asarray(a).astype(np.float32)


# -------------------------------------------------------------------- SAM3
def _sam_graph(image_name: str, prompt: str, prefix: str, threshold: float) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": C.SAM_CKPT}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": prompt}},
        "4": {"class_type": "SAM3_Detect", "inputs": {
            "model": ["1", 0], "image": ["2", 0], "conditioning": ["3", 0],
            "threshold": threshold, "refine_iterations": 2, "individual_masks": True}},
        "5": {"class_type": "MaskToImage", "inputs": {"mask": ["4", 0]}},
        "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0], "filename_prefix": prefix}},
    }


def _pick(masks: list[np.ndarray]) -> np.ndarray | None:
    """En buyuk + en merkezi maske. Alan agirlikli, merkeze uzaklik cezali."""
    best, best_score = None, -1.0
    for m in masks:
        share = float(m.mean())
        if not (MIN_SHARE < share < MAX_SHARE):
            continue
        ys, xs = np.nonzero(m)
        if xs.size == 0:
            continue
        h, w = m.shape
        dx = abs(xs.mean() - w / 2) / (w / 2)
        score = share * (1.0 - 0.5 * min(1.0, dx))
        if score > best_score:
            best, best_score = m, score
    return best


def _attach(main: np.ndarray, cand: list[np.ndarray]) -> np.ndarray:
    """Ek kavramlarin (kilic/asa/yay/ok) govdeye DEGEN parcalari eklenir; kopuk
    ama KUCUK olanlar da kalir (havadaki ok - rev7). Buyuk kopuk maskeler arka
    plandan gelmis sayilir ve atilir."""
    import cv2
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * TOUCH + 1, 2 * TOUCH + 1))
    grown = cv2.dilate((main.astype(np.uint8)) * 255, k) > 127
    out = np.zeros_like(main)
    for m in cand:
        share = float(m.mean())
        if not (0.0002 < share < MAX_SHARE):
            continue
        if (m & grown).any() or share <= PROJECTILE_MAX:
            out |= m
    return out


def sam_masks(frames: list[Path], concepts: list[str], chunk: int = 48, threshold: float = 0.45,
              log=print) -> list[tuple]:
    """Kare basina (govde, govde+ekler, yalniz ekler) - bulunamazsa (None, None, None).

    concepts[0] ANA kavramdir ("woman"): en buyuk + en merkezi maske secilir.
    Sonrakiler (prop: "sword"/"staff"/"bow") govdeye degdigi olcude eklenir.
    Butun kareler x butun kavramlar TEK partide kuyruga birakilir: SAM
    checkpoint'i bir kez yuklenir (CBN #281 kurali)."""
    import cv2
    main: list[np.ndarray | None] = [None] * len(frames)
    extra: list[list[np.ndarray]] = [[] for _ in frames]
    for c0 in range(0, len(frames), max(1, chunk)):
        part = list(enumerate(frames))[c0:c0 + chunk]
        run, pend = C.queue_depth()
        log("SAM3 %d-%d/%d x %d kavram (ComfyUI kuyrugu: %d/%d)"
            % (c0 + 1, c0 + len(part), len(frames), len(concepts), run, pend))
        pids = {}
        for i, f in part:
            name = C.stage_input(f, "chsam")
            for ci, c in enumerate(concepts):
                pids[(i, ci)] = C.enqueue(
                    _sam_graph(name, c, "character/sam/f%05d_%d" % (i, ci), threshold), "chsam")
        t0, pending = time.time(), dict(pids)
        while pending and time.time() - t0 < 2400:
            time.sleep(1.0)
            for (i, ci), pid in list(pending.items()):
                try:
                    h = C.history(pid)
                except RuntimeError:
                    del pending[(i, ci)]      # bu karede bu kavram bulunamadi
                    continue
                if h is None:
                    continue
                del pending[(i, ci)]
                cand = []
                for p in C.outputs(h, ("images",)):
                    g = cv2.imread(str(p), cv2.IMREAD_GRAYSCALE)
                    if g is not None:
                        cand.append(g > 127)
                if ci == 0:
                    main[i] = _pick(cand)
                else:
                    extra[i] += cand
    out = []
    for i, m in enumerate(main):
        if m is None:
            out.append((None, None, None))
            continue
        ek = _attach(m, extra[i])
        out.append((m, m | ek, ek))
    return out


# --------------------------------------------------------- alfa birlestirme
def _clean(mask: np.ndarray, keep: np.ndarray | None = None) -> np.ndarray:
    """Kucuk delikleri kapat, lekeleri at. En buyuk bilesenin %3'unden kucuk
    parcalar atilir; `keep` (SAM'in silah/ok maskeleri) bu elemeden MUAF -
    havada ucan ok kaybolmasin (rev7)."""
    import cv2
    m = (mask.astype(np.uint8)) * 255
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k)
    n, lab, stats, _ = cv2.connectedComponentsWithStats((m > 127).astype(np.uint8), 8)
    if n > 1:
        areas = stats[1:, cv2.CC_STAT_AREA]
        tut = set((1 + np.nonzero(areas >= max(60, 0.03 * areas.max()))[0]).tolist())
        if keep is not None and keep.any():
            tut |= {int(x) for x in np.unique(lab[keep]) if x}
        m = np.where(np.isin(lab, sorted(tut)), 255, 0).astype(np.uint8)
    return m


def alpha_from(mask: np.ndarray, matte: np.ndarray | None, refine: bool,
               keep: np.ndarray | None = None) -> np.ndarray:
    """SAM maskesi -> 0..255 alfa. Kenar seridinde isnet matte'i yumusatir."""
    import cv2
    m = _clean(mask, keep)
    soft = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 1.2)
    if refine and matte is not None:
        k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * BAND + 1, 2 * BAND + 1))
        band = (cv2.dilate(m, k) > 127) & (cv2.erode(m, k) < 128)
        blend = np.minimum(soft, np.maximum(matte, soft * 0.35))
        soft = np.where(band, blend, soft)
    return np.clip(soft, 0, 255)


# ------------------------------------------------------ olcek normalizasyonu
def upscale_rgb(frames: list, factor: int = 4, model: str = "", log=print) -> list:
    """RGB'yi ComfyUI upscale modeliyle buyutur (ESRGAN). Alfa BURAYA GIRMEZ -
    model uc kanalli; alfa ayrica Lanczos ile olceklenir (rev6). Kareler tek
    grafikte degil, tek tek kuyruga birakilir; model parti boyunca yuklu kalir."""
    from PIL import Image
    model = model or C.UPSCALE_MODEL
    pids = []
    for i, fr in enumerate(frames):
        name = "chup_%d_%s.png" % (i, os.urandom(4).hex())
        C.COMFY_IN.mkdir(parents=True, exist_ok=True)
        fr.convert("RGB").save(str(C.COMFY_IN / name))
        g = {"1": {"class_type": "LoadImage", "inputs": {"image": name}},
             "2": {"class_type": "UpscaleModelLoader", "inputs": {"model_name": model}},
             "3": {"class_type": "ImageUpscaleWithModel", "inputs": {"upscale_model": ["2", 0], "image": ["1", 0]}},
             "4": {"class_type": "SaveImage", "inputs": {"images": ["3", 0],
                                                         "filename_prefix": "character/up/f%05d" % i}}}
        pids.append(C.enqueue(g, "chup"))
    log("ESRGAN x%d: %d kare kuyrukta" % (factor, len(frames)))
    out = []
    for i, pid in enumerate(pids):
        files = C.outputs(C.wait(pid, 1800), ("images",))
        if not files:
            raise RuntimeError("upscale ciktisi yok (kare %d)" % i)
        out.append(Image.open(str(files[0])).convert("RGB"))
    return out


def normalize(frames: list, crop: float = 0.0, canvas: int = 0, log=print) -> tuple[list, dict]:
    """rev6+rev7: karakter olcegini SABITLE, ama hicbir seyi KESME.

    - Olcek yalnizca uretimdeki dolguya (padding) baglidir:
      scale = canvas / ((1 - 2*padding) * kare_kenari). Boylece padding 0.2 ile
      uretilen klip, padding 0 ile uretilenle AYNI piksel boyunda cikar.
    - Kadraj icerige gore KIRPILMAZ. Standart tuval (canvas x canvas) kare
      merkezine (pivot ekseni) oturur; klibin tum karelerinin birlesik alfa
      sinir kutusu bu tuvale sigmiyorsa tuval merkez etrafinda SIMETRIK BUYUR
      (640x640 -> 640x768 gibi). Karakter kucultulmez, icerik kesilmez.
    - Buyutme: RGB ESRGAN (gpu seridi cagiranin elinde) + alfa Lanczos, sonra
      tam olcuye Lanczos. Kucultme: duz Lanczos.
    """
    from PIL import Image
    w, h = frames[0].size
    info = {"padding": float(crop or 0.0), "canvas": [w, h], "scale": 1.0, "upscaler": "",
            "grown": False}
    if not canvas:
        return frames, info
    eff = max(0.2, 1.0 - 2.0 * float(crop or 0.0))
    scale = canvas / (eff * float(max(w, h)))
    info["scale"] = round(scale, 4)
    if scale > 1.02:
        rgb = upscale_rgb(frames, log=log)
        info["upscaler"] = C.UPSCALE_MODEL
        frames = [Image.merge("RGBA", (*r.split(), f.split()[3].resize(r.size, Image.LANCZOS)))
                  for r, f in zip(rgb, frames)]
    hedef = (max(1, int(round(w * scale))), max(1, int(round(h * scale))))
    if frames[0].size != hedef:
        frames = [f.resize(hedef, Image.LANCZOS) for f in frames]
    sw, sh = hedef

    A = np.stack([np.asarray(f)[..., 3] for f in frames]).max(0)
    ys, xs = np.where(A > 8)
    if xs.size == 0:
        return frames, info
    cx, cy = sw / 2.0, sh / 2.0
    need_w = 2 * max(cx - int(xs.min()), int(xs.max()) + 1 - cx)
    need_h = 2 * max(cy - int(ys.min()), int(ys.max()) + 1 - cy)
    cw = max(canvas, int(np.ceil(need_w / 2.0)) * 2)
    ch = max(canvas, int(np.ceil(need_h / 2.0)) * 2)
    info["grown"] = (cw, ch) != (canvas, canvas)
    x0, y0 = int(round(cx - cw / 2.0)), int(round(cy - ch / 2.0))
    frames = [f.crop((x0, y0, x0 + cw, y0 + ch)) for f in frames]   # disari tasan alan seffaf dolar
    info["canvas"] = [cw, ch]
    log("tuval %dx%d (olcek x%.2f%s)" % (cw, ch, scale, ", buyutuldu" if info["grown"] else ""))
    return frames, info


def cut(im, alpha: np.ndarray, bg) -> "object":
    """Fon rengine karsi un-premultiply (sprite_cikart.py'deki kesim)."""
    from PIL import Image
    a = np.clip((alpha - 24) * (255.0 / (255 - 24)), 0, 255)
    rgb = np.asarray(im).astype(np.float32)
    af = (a / 255.0)[..., None]
    bgc = np.array(bg, dtype=np.float32)[None, None, :]
    clean = np.clip((rgb - bgc * (1 - af)) / np.maximum(af, 1e-3), 0, 255)
    return Image.fromarray(np.dstack([np.where(af > 0.02, clean, rgb), a]).astype(np.uint8), "RGBA")


# -------------------------------------------------------------------- akis
def extract(video, out_dir, fps: int = 15, prompt: str = "woman", height: int = 0,
            mirror: bool = False, refine: bool = True, chunk: int = 48,
            bg: tuple | None = None, crop: float = 0.0, canvas: int = 0, log=print) -> dict:
    """Video -> RGBA kareler + anim.webp + sheet.png + sprite.json. Ozet doner."""
    from PIL import Image
    video, out_dir = Path(video), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw = out_dir / "_raw"
    shutil.rmtree(raw, ignore_errors=True)
    raw.mkdir()
    C.ffmpeg(["-i", str(video), "-vf", "fps=%d" % fps, str(raw / "f_%04d.png")])
    files = [Path(p) for p in sorted(glob.glob(str(raw / "f_*.png")))]
    if not files:
        raise RuntimeError("videodan kare cikmadi: %s" % video)
    concepts = [c.strip() for c in str(prompt).split(",") if c.strip()] or ["woman"]
    log("%d kare, SAM3 (%s)" % (len(files), " + ".join(concepts)))

    pairs = sam_masks(files, concepts, chunk=chunk, log=log)
    masks = [p[1] for p in pairs]                      # kesimde kullanilan: govde + prop
    body = [p[0] for p in pairs]                       # tutarlilik olcusu: yalniz govde
    extras = [p[2] for p in pairs]                     # kopuk mermiler burada korunur
    areas = np.array([float(m.mean()) if m is not None else 0.0 for m in body])

    # zaman tutarliligi: GOVDE alani komsularin medyanindan cok sapiyorsa supheli
    # (prop savrulurken alan degisir, o yuzden govde uzerinden bakilir)
    suspect = []
    for i, a in enumerate(areas):
        nb = [areas[j] for j in (i - 2, i - 1, i + 1, i + 2) if 0 <= j < len(areas) and areas[j] > 0]
        if masks[i] is None:
            suspect.append(i)
        elif nb and abs(a - float(np.median(nb))) / max(float(np.median(nb)), 1e-6) > JUMP:
            suspect.append(i)

    fdir = out_dir / "frames"
    shutil.rmtree(fdir, ignore_errors=True)
    fdir.mkdir(parents=True)
    first = Image.open(files[0]).convert("RGB")
    if bg is None:
        bg = tuple(int(v) for v in np.asarray(first)[2:12, 2:12].reshape(-1, 3).mean(0))
    frames, alphas, method = [], [], []
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB")
        matte = isnet_matte(im) if (refine or i in suspect) else None
        if i in suspect:
            if matte is None:
                # ne SAM ne isnet: en yakin saglam karenin maskesi
                src = min((j for j in range(len(masks)) if masks[j] is not None and j not in suspect),
                          key=lambda j: abs(j - i), default=None)
                if src is None:
                    raise RuntimeError("hicbir karede maske uretilemedi (SAM ve isnet yok)")
                al = alpha_from(masks[src], None, False, extras[src])
                method.append("copy%d" % src)
            else:
                al = np.clip(matte, 0, 255)
                method.append("isnet")
        else:
            al = alpha_from(masks[i], matte, refine, extras[i])
            method.append("sam" + ("+edge" if (refine and matte is not None) else ""))
        rgba = cut(im, al, bg)
        if mirror:
            rgba = rgba.transpose(Image.FLIP_LEFT_RIGHT)
        frames.append(rgba)

    # rev6: fon silindikten SONRA normalizasyon - sabit kirpma + ortak tuval.
    # Icerige gore kirpma YOK; pivot ve karakter olcegi klipler arasi sabit.
    frames, norm = normalize(frames, crop, int(canvas or height or 0), log=log)
    for i, fr in enumerate(frames):
        fr.save(str(fdir / ("%04d.png" % i)))
    alphas = [np.asarray(fr)[..., 3] for fr in frames]

    A = np.stack(alphas)
    ys, xs = np.where(A.max(0) > 8)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    w, h = frames[0].size
    frames[0].save(str(out_dir / "anim.webp"), save_all=True, append_images=frames[1:],
                   duration=int(1000 / fps), loop=0, quality=88, method=4)
    sheet = Image.new("RGBA", (w * len(frames), h))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * w, 0))
    sheet.save(str(out_dir / "sheet.png"), optimize=True)
    info = {"frames": len(frames), "fps": fps, "w": w, "h": h, "bbox": bbox,
            # pivot: yatayda tuval merkezi (uretim ekseni), dikeyde ayak cizgisi
            "pivot": [w // 2, bbox[3]], "feet": bbox[3], "mirror": mirror, "bg": list(bg),
            "cutout": "sam3", "prompt": ", ".join(concepts), "refine": bool(refine),
            "fallback_frames": suspect, "method": method,
            "coverage": round(float((A > 8).mean()), 4),
            "src": video.name, "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    info.update(norm)                      # padding, scale, canvas, upscaler, grown
    (out_dir / "sprite.json").write_text(json.dumps(info, indent=1), encoding="utf-8")
    shutil.rmtree(raw, ignore_errors=True)
    log("TAMAM %d kare %dx%d bbox=%s  yedek kare: %d" % (len(frames), w, h, bbox, len(suspect)))
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--video", required=True)
    ap.add_argument("--out_dir", required=True)
    ap.add_argument("--fps", type=int, default=15)
    ap.add_argument("--prompt", default="woman", help="virgulle: ana kavram + prop (woman,sword)")
    ap.add_argument("--height", type=int, default=0)
    ap.add_argument("--crop", type=float, default=0.0, help="uretimde kullanilan padding")
    ap.add_argument("--canvas", type=int, default=0, help="ortak sprite tuvali (640)")
    ap.add_argument("--chunk", type=int, default=48)
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--no-refine", dest="refine", action="store_false")
    ap.add_argument("--bg", default="")
    a = ap.parse_args()
    bg = tuple(int(v) for v in a.bg.split(",")) if a.bg else None
    info = extract(a.video, a.out_dir, a.fps, a.prompt, a.height, a.mirror, a.refine,
                   a.chunk, bg, a.crop, a.canvas)
    print(json.dumps(info, indent=1))


if __name__ == "__main__":
    main()
