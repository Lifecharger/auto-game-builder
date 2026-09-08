r"""#322 Kart Modu kesim + paketleme: video -> RGBA kareler -> sprite sheet.

`design/kart_modu.md` §3'un aracidir. Grok'a bagli `Hot Card Games/tools/cardpipe`
hattinin (chroma key) yerine gecer; CIKTI SOZLESMESI ayni kalir - 6 sn, 12 fps,
72 kare, 12x6 izgara WebP + thumb + (yeni) hi-res still.

Iki kesim kipi
  sam     VARSAYILAN. Yeni uretimlerde fon duz acik gri; alfa yalniz SAM3
          maskesinden gelir. Kenar 2 px guided-filter ile yumusatilir, maske
          sinirindaki 3 px bantta sac telleri luminance farkiyla geri kazanilir,
          bant icindeki fon rengi hem alfadan hem RGB'den temizlenir.
  hybrid  ESKI yesil fonlu Grok masterlari. chroma alfa (kosede olculen GERCEK
          fon rengi, SIKI 0.10 benzerlik) yalniz SAM maskesinin 4 px genisletilmis
          alani icinde gecerlidir; disi sifir. Maske ICINDE alfasi 0.15'in altina
          dusen pikseller 1'e cekilir - tene vuran yesil isik yuzunden figurun
          eriyip gitmesi (shipped scarlett ~%50 alfa) boylece imkansiz.

Neden SAM maskesi chroma'yi sinirliyor: benzerlik yaricapi UV uzayinda mesafedir,
sabit 0.10 soluk yesilde figurun yarisina kadar uzanabiliyordu. Maske disini pesinen
sifirlayip icini pesinen doldurunca yaricap artik yalnizca KENARI belirler, govdeyi
degil - o yuzden sabit siki deger guvenli.

Alfa fonksiyonlari yalnizca ALFA dondurur (sozlesme boyle). RGB tarafindaki iki
temizlik ayri yardimcilarda ve `cut_video` ikisini de uygular:
  defringe_rgb  yari saydam kenarda fon renginin un-premultiply ile cikarilmasi
  despill_rgb   yesil tasmasinin kenar bandinda bastirilmasi (hybrid)

Guard'lar (`metrics.json` -> verdict): ilk kare - still farki (yanlis kadin /
reframe), kare basina opak oran araligi (i2v zoom - "sabit bir kart ~2 puan
icinde durur, zoom yapan as %15.9 -> %37.4 kosmustu"), maske kapsama surekliligi,
yari-alfa orani (over-key), artik yesil (under-key).

Kullanim
    python cut.py --video master.mp4 --out D:/.../ace --mode sam
    python cut.py --video master.mp4 --out D:/.../ace --mode hybrid --still still.png
    python cut.py --compare --video master.mp4 --out D:/.../_cut_test/ace

Kutuphane olarak
    from tools.cardpipe_local.cut import cut_video, build_sheet, sam_masks
    res = cut_video(mp4, kart_klasoru, mode="sam", concept="woman")

ComfyUI PAYLASIMLIDIR: yalniz kuyruga is birakilir, restart/iptal yok. gpu_lane
bileti almak cagiranin (sunucunun) isidir, bu modulun degil.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent

# --------------------------------------------------------------- sabitler
FPS = 12
SECONDS = 6
# Cozunurluk (doc "Cozunurluk"): varsayilan 512x768 -> 12x6 = 6144x4608.
# 448x672 (Grok masterlarinin oz cozunurlugu) ve 320x480 (krupiye v1) parametre
# ile secilebilir - eski yollar yeniden paketlenebilsin diye.
FRAME = (512, 768)
GRID = (12, 6)
THUMB = (640, 960)
STILL = (832, 1248)
SHEET_Q = 85
THUMB_Q = 88
STILL_Q = 90
# Pillow WebP sikistirma emegi. 6144x4608 sheet'te method=6, method=4'e gore
# 19.4s / 2.37 MB, method=4 ise 2.9s / 2.43 MB - %2.5 bayt icin 6.7 kat sure.
# 54 kartlik bir partide fark ~15 dk, o yuzden varsayilan 4.
WEBP_METHOD = 4

SAM_THRESHOLD = 0.45
SAM_CHUNK = 48
MIN_SHARE = 0.004          # bu paydan kucuk maske gurultudur
MAX_SHARE = 0.92           # tum kareyi kaplayan maske = fon yakalanmis
CLOSE_PX = 2               # maske kapama yaricapi
FEATHER_PX = 2             # kenar yumusatma yaricapi (guided filter)
BAND_PX = 3                # sac/kenar bandi
DILATE_PX = 4              # hybrid: chroma'nin gecerli oldugu genisletilmis alan
CHROMA_SIM = 0.10          # SIKI - maske sinirladigi icin guvenli
CHROMA_BLEND = 0.08
LOW_ALPHA_FILL = 0.15      # maske icinde bunun altindaki alfa 1'e cekilir
LUM_LO, LUM_HI = 8.0, 38.0  # bantta saci ayiran luminance farki (0..255)
FRINGE_TOL = 12.0          # bantta fon rengine bu kadar yakin piksel = fon
LOCAL_BG_R = 24            # yerel fon tahmininin yaricapi (piksel)
BG_CHROMA = 0.06           # fonun UV doygunlugu bunun ustundeyse "renkli fon"

# guard esikleri
G_FIRSTFRAME = 25.0        # guard_firstframe.py ile ayni olcek (64x96 mean abs RGB)
G_OPAQUE_SPREAD = 0.35     # (max-min)/median
G_DROPOUT = 0.70           # min < median * bu -> figur kayboldu
G_COVER_JUMP = 0.40        # ardisik kareler arasi kapsama sicramasi
G_SEMI = 0.06              # yari saydam piksel orani (over-key)
G_GREEN = 0.01             # artik yesil orani (under-key)
GREEN_DOM = 40             # check_keying.py ile ayni tanim


def _ffmpeg() -> str:
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"


def _comfy():
    """ComfyUI istemcisi: tools/character/common.py (SAM3 ckpt, kuyruk, gecmis)."""
    root = str(AGB_ROOT / "tools")
    if root not in sys.path:
        sys.path.insert(0, root)
    from character import common as C  # noqa: WPS433 - GPU yoksa import edilmesin
    return C


def _run(cmd: list[str], timeout: int = 900) -> None:
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                       encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout or "")[-500:])


# ------------------------------------------------------------------ kareler
def extract_frames(video, out_dir, fps: int = FPS, seconds: float = SECONDS) -> list[Path]:
    """Videodan TAM `fps*seconds` kare. Kaynak 12 fps degilse yeniden orneklenir.

    Kaynak kisa ise son kare tekrarlanarak doldurulur ve bu metriklerde
    `padded_frames` olarak raporlanir (sessizce yutulmaz - guard FAIL verir).
    """
    video, out_dir = Path(video), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("f_*.png"):
        old.unlink()
    want = int(round(fps * seconds))
    _run([_ffmpeg(), "-y", "-v", "error", "-t", str(seconds), "-i", str(video),
          "-vf", "fps=%d" % fps, "-frames:v", str(want), "-start_number", "0",
          str(out_dir / "f_%03d.png")])
    files = sorted(out_dir.glob("f_*.png"))
    if not files:
        raise RuntimeError("videodan kare cikmadi: %s" % video)
    for extra in files[want:]:
        extra.unlink()
    files = files[:want]
    while len(files) < want:
        dest = out_dir / ("f_%03d.png" % len(files))
        shutil.copy(str(files[-1]), str(dest))
        files.append(dest)
    return files


def still_first_frame(video, dest=None) -> Path:
    """Ilk kareyi PNG olarak yazar (yeniden canlandirma yolunun girdisi).

    `dest` verilmezse gecici klasore yazilir - kaynak master klasoru ASLA
    kirletilmez.
    """
    video = Path(video)
    if dest is None:
        dest = Path(tempfile.mkdtemp(prefix="cardcut_")) / (video.stem + "_f0.png")
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    _run([_ffmpeg(), "-y", "-v", "error", "-i", str(video), "-frames:v", "1", str(dest)], 180)
    return dest


# --------------------------------------------------------------------- SAM3
def _sam_graph(ckpt: str, image_name: str, concept: str, prefix: str, threshold: float) -> dict:
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": concept}},
        "4": {"class_type": "SAM3_Detect", "inputs": {
            "model": ["1", 0], "image": ["2", 0], "conditioning": ["3", 0],
            "threshold": threshold, "refine_iterations": 2, "individual_masks": True}},
        "5": {"class_type": "MaskToImage", "inputs": {"mask": ["4", 0]}},
        "6": {"class_type": "SaveImage", "inputs": {"images": ["5", 0],
                                                    "filename_prefix": prefix}},
    }


def _pick(masks: list[np.ndarray]) -> np.ndarray | None:
    """En buyuk + en merkezi maske (sam_frames.py ile ayni secim)."""
    best, best_score = None, -1.0
    for m in masks:
        share = float(m.mean())
        if not (MIN_SHARE < share < MAX_SHARE):
            continue
        _ys, xs = np.nonzero(m)
        if xs.size == 0:
            continue
        w = m.shape[1]
        dx = abs(xs.mean() - w / 2.0) / (w / 2.0)
        score = share * (1.0 - 0.5 * min(1.0, dx))
        if score > best_score:
            best, best_score = m, score
    return best


def _sam_raw(frames: list[Path], concept: str, threshold: float, chunk: int,
             log) -> list[np.ndarray | None]:
    """Kare basina ham SAM maskesi. Butun kareler TEK partide kuyruga birakilir:
    checkpoint bir kez yuklenir, N kare arka arkaya islenir (#281 parti kurali)."""
    C = _comfy()
    out: list[np.ndarray | None] = [None] * len(frames)
    for c0 in range(0, len(frames), max(1, chunk)):
        part = list(enumerate(frames))[c0:c0 + chunk]
        run, pend = C.queue_depth()
        log("SAM3 %d-%d/%d '%s' (ComfyUI kuyrugu: %d/%d)"
            % (c0 + 1, c0 + len(part), len(frames), concept, run, pend))
        pids: dict[int, str] = {}
        for i, f in part:
            name = C.stage_input(f, "cardsam")
            pids[i] = C.enqueue(_sam_graph(C.SAM_CKPT, name, concept,
                                           "cardpipe/sam/f%05d" % i, threshold), "cardsam")
        pending, t0 = dict(pids), time.time()
        while pending and time.time() - t0 < 2400:
            time.sleep(1.0)
            for i, pid in list(pending.items()):
                try:
                    h = C.history(pid)
                except RuntimeError:
                    del pending[i]           # bu karede kavram bulunamadi
                    continue
                if h is None:
                    continue
                del pending[i]
                cand = []
                for p in C.outputs(h, ("images",)):
                    g = cv2.imread(str(p), cv2.IMREAD_GRAYSCALE)
                    if g is not None:
                        cand.append(g > 127)
                out[i] = _pick(cand)
        if pending:
            raise RuntimeError("SAM3 zaman asimi: %d kare donmedi" % len(pending))
    return out


def _temporal_median(stack: np.ndarray) -> np.ndarray:
    """3 kare medyan: bir piksel komsu ucluden en az ikisinde varsa var.

    Tek karelik titremeyi (SAM'in bir karede eli birakip digerinde yakalamasi)
    siler; gercek hareket iki ardisik karede zaten mevcuttur.
    """
    s = stack.astype(np.uint8)
    out = s.copy()
    if len(s) >= 3:
        out[1:-1] = ((s[:-2] + s[1:-1] + s[2:]) >= 2).astype(np.uint8)
    return out.astype(bool)


def _largest_linked(mask: np.ndarray, prev: np.ndarray | None) -> np.ndarray:
    """Onceki karenin maskesine DEGEN en buyuk bilesen. Degen yoksa en buyuk.

    Tek bilesen birakmak, arka planda bir karede parlayan "ada"larin sprite'a
    sizmasini imkansiz kilar.
    """
    n, lab, stats, _c = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if n <= 1:
        return np.zeros_like(mask, dtype=bool)
    ids = list(range(1, n))
    if prev is not None and prev.any():
        touching = {int(x) for x in np.unique(lab[prev]) if x}
        ids = [k for k in ids if k in touching] or ids
    best = max(ids, key=lambda k: int(stats[k, cv2.CC_STAT_AREA]))
    return lab == best


def sam_masks(frames, concept: str = "woman", threshold: float = SAM_THRESHOLD,
              chunk: int = SAM_CHUNK, log=print) -> np.ndarray:
    """Kare listesi -> [N,H,W] bool maske yigini.

    SAM3 (tek model yuklemesi ile parti) -> maskesi olmayan kare en yakin saglam
    kareden kopyalanir -> 3 kare zamansal medyan -> 2 px kapama -> onceki kareye
    degen en buyuk bilesen.
    """
    frames = [Path(f) for f in frames]
    raw = _sam_raw(frames, concept, threshold, chunk, log)
    good = [i for i, m in enumerate(raw) if m is not None]
    if not good:
        raise RuntimeError("hicbir karede SAM maskesi uretilemedi (kavram: %s)" % concept)
    missing = [i for i, m in enumerate(raw) if m is None]
    for i in missing:
        src = min(good, key=lambda j: abs(j - i))
        raw[i] = raw[src].copy()
    if missing:
        log("SAM: %d kare bos dondu, en yakin kareden kopyalandi %s" % (len(missing), missing[:12]))

    stack = _temporal_median(np.stack(raw))
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * CLOSE_PX + 1, 2 * CLOSE_PX + 1))
    out = np.zeros_like(stack)
    prev: np.ndarray | None = None
    for i in range(len(stack)):
        m = cv2.morphologyEx(stack[i].astype(np.uint8), cv2.MORPH_CLOSE, k) > 0
        m = _largest_linked(m, prev)
        out[i] = m
        if m.any():
            prev = m
    return out


# ------------------------------------------------------------- alfa yardimci
def bg_color(frame_rgb: np.ndarray, patch: int = 10) -> np.ndarray:
    """GERCEK fon rengi: dort kosedeki patch'lerin medyani (float32 RGB).

    Sabit 0x00FF00 varsaymak eski hattin hatasiydi - Grok'un yesili renk olarak
    kayiyor, "magenta" pembeye donuyordu. Olculen renk her fonda dogrudur.
    """
    f = frame_rgb.astype(np.float32)
    h, w = f.shape[:2]
    p = max(2, min(patch, h // 4, w // 4))
    corners = np.concatenate([
        f[:p, :p].reshape(-1, 3), f[:p, w - p:].reshape(-1, 3),
        f[h - p:, :p].reshape(-1, 3), f[h - p:, w - p:].reshape(-1, 3)])
    return np.median(corners, axis=0).astype(np.float32)


def _bg3(bg) -> np.ndarray:
    """Fon rengi tek RGB de olabilir, piksel basina harita da - ikisini de
    (1,1,3) / (H,W,3) olarak yayinlanabilir hale getirir."""
    a = np.asarray(bg, dtype=np.float32)
    return a if a.ndim == 3 else a.reshape(1, 1, 3)


def local_bg(frame_rgb: np.ndarray, mask: np.ndarray, dilate_px: int = BAND_PX + 2,
             radius: int = LOCAL_BG_R, fallback: np.ndarray | None = None) -> np.ndarray:
    """Piksel basina YEREL fon rengi: maskenin disindaki komsularin ortalamasi.

    Tek bir kose rengi yaniltir - yesil masterda saca degen fon, kosedekinden
    belirgin bicimde daha parlak (vinyet/isik dususu). Kose rengiyle olculen
    luminance farki o yuzden fonun kendisini "sac" sanip yesil bir hale
    biraktiriyordu. Yerel tahminde fonun kendi parlakligi referans olur.
    """
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * dilate_px + 1, 2 * dilate_px + 1))
    outside = (cv2.dilate((mask.astype(np.uint8)) * 255, k) < 128).astype(np.float32)
    ksz = (2 * radius + 1, 2 * radius + 1)
    cnt = cv2.boxFilter(outside, -1, ksz, normalize=False)
    f = frame_rgb.astype(np.float32)
    acc = [cv2.boxFilter(f[..., c] * outside, -1, ksz, normalize=False) for c in range(3)]
    loc = np.dstack([a / np.maximum(cnt, 1.0) for a in acc])
    if fallback is None:
        fallback = bg_color(frame_rgb)
    blind = (cnt < 1.0)[..., None]
    return np.where(blind, _bg3(fallback), loc).astype(np.float32)


def _luma(rgb: np.ndarray) -> np.ndarray:
    f = rgb.astype(np.float32)
    return 0.299 * f[..., 0] + 0.587 * f[..., 1] + 0.114 * f[..., 2]


def _uv(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """ffmpeg chromakey ile AYNI UV uzayi (0..1 normalize)."""
    f = np.atleast_3d(np.asarray(rgb, dtype=np.float32))
    y = _luma(f)
    u = (0.492 * (f[..., 2] - y) + 128.0) / 255.0
    v = (0.877 * (f[..., 0] - y) + 128.0) / 255.0
    return u, v


def bg_chroma(bg) -> float:
    """Fonun notr griden UV uzakligi. Duz gri studyo fonunda ~0, yesil ekranda
    ~0.15+. Renkli fon her zaman kenara tasar - despill'i buna gore aciyoruz."""
    u, v = _uv(_bg3(bg))
    return float(np.hypot(u - 0.5, v - 0.5).mean())


def _guided(guide: np.ndarray, src: np.ndarray, radius: int, eps: float) -> np.ndarray:
    """Guided filter (cv2.ximgproc bu kurulumda yok - 8 satirlik oz hali).

    Yumusatma goruntunun KENDI kenarlarini takip eder: maske sinirinden 2 px
    tasan yumusama, sacin/omzun gercek kenarina oturur, duz gaussian gibi
    fon icine kaymaz.
    """
    ksz = (2 * radius + 1, 2 * radius + 1)
    mean_i = cv2.boxFilter(guide, -1, ksz)
    mean_p = cv2.boxFilter(src, -1, ksz)
    corr_i = cv2.boxFilter(guide * guide, -1, ksz)
    corr_ip = cv2.boxFilter(guide * src, -1, ksz)
    var_i = corr_i - mean_i * mean_i
    cov_ip = corr_ip - mean_i * mean_p
    a = cov_ip / (var_i + eps)
    b = mean_p - a * mean_i
    return cv2.boxFilter(a, -1, ksz) * guide + cv2.boxFilter(b, -1, ksz)


def _band(mask_u8: np.ndarray, px: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """(bant, dis sinir, ic cekirdek) - maske sinirinin +-px pikselik seridi."""
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * px + 1, 2 * px + 1))
    dil = cv2.dilate(mask_u8, k) > 127
    ero = cv2.erode(mask_u8, k) > 127
    return (dil & ~ero), dil, ero


def alpha_sam(frame_rgb: np.ndarray, mask: np.ndarray, bg: np.ndarray | None = None,
              feather: int = FEATHER_PX, band_px: int = BAND_PX) -> np.ndarray:
    """SAM maskesi -> 0..1 float alfa (duz fon, chroma YOK).

    1) 2 px guided-filter yumusatma (kenar goruntuye oturur),
    2) sinirdaki `band_px` bantta luminance-fark tabanli yumusak alfa: fonun
       parlakligindan yeterince ayrilan piksel (tek tek sac telleri) maskenin
       disinda kalsa bile geri gelir - duz fon bunu mumkun kilar,
    3) ayni bantta fon rengine cok yakin piksellerin alfasi sifirlanir (de-fringe;
       RGB tarafi `defringe_rgb`).
    """
    m8 = (mask.astype(np.uint8)) * 255
    guide = (_luma(frame_rgb) / 255.0).astype(np.float32)
    base = np.clip(_guided(guide, (m8 / 255.0).astype(np.float32), feather, 1e-4), 0.0, 1.0)

    if bg is None:
        bg = local_bg(frame_rgb, mask, band_px + 2)
    bgv = _bg3(bg)
    band, dil, ero = _band(m8, band_px)
    d = np.abs(_luma(frame_rgb) - _luma(bgv))
    lum = np.clip((d - LUM_LO) / max(LUM_HI - LUM_LO, 1e-6), 0.0, 1.0)

    a = base.copy()
    a[band] = np.maximum(base[band], lum[band])
    fringe = np.max(np.abs(frame_rgb.astype(np.float32) - bgv), axis=2)
    a[band & (fringe < FRINGE_TOL)] = 0.0
    a[~dil] = 0.0
    a[ero] = np.maximum(a[ero], 1.0)
    return np.clip(a, 0.0, 1.0).astype(np.float32)


def alpha_hybrid(frame_rgb: np.ndarray, mask: np.ndarray, bg: np.ndarray | None = None,
                 sim: float = CHROMA_SIM, blend: float = CHROMA_BLEND,
                 dilate_px: int = DILATE_PX, fill: float = LOW_ALPHA_FILL) -> np.ndarray:
    """ESKI yesil masterlar: chroma alfa x SAM maskesi -> 0..1 float alfa.

    chroma yalniz maskenin `dilate_px` genisletilmis alani icinde gecerli, disi
    sifir; maske ICINDE `fill` altina dusen alfa 1'e cekilir. Yesil isigin tene
    vurdugu yerlerde chroma figuru eritiyordu - maske "burasi kadin" dedigi icin
    o kararin geri alinmasi guvenli.
    """
    if bg is None:
        bg = bg_color(frame_rgb)
    u, v = _uv(frame_rgb)
    ub, vb = _uv(bg.reshape(1, 1, 3))
    d = np.hypot(u - float(ub[0, 0]), v - float(vb[0, 0]))
    key = np.clip((d - sim) / max(blend, 1e-6), 0.0, 1.0).astype(np.float32)

    m8 = (mask.astype(np.uint8)) * 255
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * dilate_px + 1, 2 * dilate_px + 1))
    grown = cv2.dilate(m8, k) > 127

    a = np.where(grown, key, 0.0).astype(np.float32)
    inside = mask.astype(bool)
    a[inside & (a < fill)] = 1.0
    return np.clip(a, 0.0, 1.0)


def defringe_rgb(frame_rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Yari saydam piksellerden fon rengini cikar (un-premultiply).

    Kenardaki piksel fon ile figurun karisimidir; alfa ile bolup fon katkisini
    dusurmezsek sac cevresinde fon renginde bir hale kalir.
    """
    f = frame_rgb.astype(np.float32)
    a = alpha[..., None]
    clean = np.clip((f - _bg3(bg) * (1.0 - a)) / np.maximum(a, 1e-3), 0, 255)
    return np.where(a > 0.02, clean, f).astype(np.float32)


def despill_rgb(frame_rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray,
                band_px: int = BAND_PX) -> np.ndarray:
    """Fonun baskin kanalinin kenar bandindaki tasmasini bastir (despill).

    ffmpeg'in `despill=type=green` filtresinin ayni isi, ama TUM karede degil
    yalniz sinir bandinda: figurun icindeki gercek yesil (uniforma) korunur.
    """
    f = np.array(frame_rgb, dtype=np.float32)
    ch = int(np.argmax(np.asarray(bg, dtype=np.float32).reshape(-1, 3).mean(0)))
    others = [c for c in (0, 1, 2) if c != ch]
    m8 = ((alpha > 0.5).astype(np.uint8)) * 255
    band, _dil, _ero = _band(m8, band_px)
    band = band | ((alpha > 0.02) & (alpha < 0.98))
    limit = (f[..., others[0]] + f[..., others[1]]) * 0.5
    over = band & (f[..., ch] > limit)
    f[..., ch] = np.where(over, limit, f[..., ch])
    return f


# --------------------------------------------------------------- paketleme
def _crop23(im: Image.Image) -> Image.Image:
    """2:3'e merkez kirpma - postprocess/build_sheets ile AYNI kural."""
    w, h = im.size
    if w * 3 > h * 2:
        cw, ch = int(h * 2 / 3), h
    else:
        cw, ch = w, int(w * 3 / 2)
    left, top = (w - cw) // 2, (h - ch) // 2
    return im.crop((left, top, left + cw, top + ch))


def _fit(im: Image.Image, size: tuple[int, int]) -> tuple[Image.Image, bool]:
    im = _crop23(im)
    up = im.width < size[0]
    if im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return im, up


def build_sheet(frames_dir, sheet, thumb, frame: tuple[int, int] = FRAME,
                grid: tuple[int, int] = GRID, thumb_size: tuple[int, int] = THUMB,
                still=None, still_out=None, still_size: tuple[int, int] = STILL,
                fps: int = FPS, quality: int = SHEET_Q,
                method: int = WEBP_METHOD) -> dict:
    """`alpha_*.png` kareleri -> tek WebP sheet + thumb (+ istege bagli hi-res still).

    Kaynak buyukse LANCZOS ile kucultulur; kucukse yine LANCZOS ile buyutulur ama
    `upscaled` bayragi metrikte gorunur - "detay" gibi davranilmaz.
    """
    frames_dir = Path(frames_dir)
    sheet, thumb = Path(sheet), Path(thumb)
    files = sorted(frames_dir.glob("alpha_*.png"))
    if not files:
        raise RuntimeError("kesilmis kare yok: %s" % frames_dir)
    cols, rows_max = grid
    rows = math.ceil(len(files) / cols)
    if rows > rows_max:
        raise RuntimeError("%d kare %dx%d izgaraya sigmiyor" % (len(files), cols, rows_max))
    fw, fh = frame

    canvas = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    upscaled = False
    first: Image.Image | None = None
    for i, fp in enumerate(files):
        with Image.open(fp) as im:
            tile, up = _fit(im.convert("RGBA"), frame)
        upscaled = upscaled or up
        if i == 0:
            first = tile.copy()
        canvas.paste(tile, ((i % cols) * fw, (i // cols) * fh))
    sheet.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(sheet, quality=quality, method=method)

    thumb_img, _up = _fit(first, thumb_size)
    thumb.parent.mkdir(parents=True, exist_ok=True)
    thumb_img.save(thumb, quality=THUMB_Q, method=method)

    meta = {
        "sheet": str(sheet), "thumb": str(thumb),
        "frames": len(files), "fps": fps, "cols": cols, "rows": rows,
        "frameW": fw, "frameH": fh, "thumbW": thumb_size[0], "thumbH": thumb_size[1],
        "sheetBytes": sheet.stat().st_size, "thumbBytes": thumb.stat().st_size,
        "upscaled": upscaled, "quality": quality, "method": method,
    }

    # hi-res still: kart detay ekraninin tam cozunurluklu gorseli. Kaynak still
    # varsa ONDAN uretilir (sheet karesinden degil) - orada 832x1248 gercek detay.
    if still_out is not None:
        still_out = Path(still_out)
        src = Path(still) if still else None
        with (Image.open(src) if src and src.is_file() else Image.open(files[0])) as im:
            base = im.convert("RGBA")
            still_img, up = _fit(base, still_size)
        still_out.parent.mkdir(parents=True, exist_ok=True)
        still_img.save(still_out, quality=STILL_Q, method=method)
        meta.update({"still": str(still_out), "stillW": still_size[0],
                     "stillH": still_size[1], "stillBytes": still_out.stat().st_size,
                     "stillUpscaled": up,
                     "stillFrom": "still" if (src and src.is_file()) else "frame0"})
    return meta


# ------------------------------------------------------------------ guard'lar
def first_frame_diff(frame_rgb: np.ndarray, still) -> float:
    """guard_firstframe.py ile ayni olcu: 2:3 kirp, 64x96, ortalama mutlak RGB."""
    with Image.open(still) as si:
        a = _crop23(si.convert("RGB")).resize((64, 96), Image.BILINEAR)
    b = _crop23(Image.fromarray(frame_rgb.astype(np.uint8))).resize((64, 96), Image.BILINEAR)
    return float(np.abs(np.asarray(a, dtype=np.float32) - np.asarray(b, dtype=np.float32)).mean())


def _frame_stats(rgb: np.ndarray, alpha: np.ndarray) -> dict:
    opaque = alpha > 0.94
    semi = (alpha > 0.08) & ~opaque
    cover = alpha > 0.03
    f = rgb.astype(np.float32)
    green = opaque & ((f[..., 1] - f[..., 0]) > GREEN_DOM) & ((f[..., 1] - f[..., 2]) > GREEN_DOM)
    n = float(alpha.size)
    return {"opaque": float(opaque.sum()) / n, "semi": float(semi.sum()) / n,
            "coverage": float(cover.sum()) / n, "green": float(green.sum()) / n}


def _verdict(per_frame: list[dict], expected: int, padded: int, mode: str,
             ff_diff: float | None) -> dict:
    op = [p["opaque"] for p in per_frame]
    cov = [p["coverage"] for p in per_frame]
    med = sorted(op)[len(op) // 2] if op else 0.0
    spread = (max(op) - min(op)) / med if med > 1e-6 else 1.0
    jumps = [abs(cov[i] - cov[i - 1]) / max(cov[i - 1], 1e-6) for i in range(1, len(cov))]
    reasons: list[str] = []
    if len(per_frame) != expected:
        reasons.append("kare sayisi %d, beklenen %d" % (len(per_frame), expected))
    if padded:
        reasons.append("kaynak kisa: %d kare son kareden cogaltildi" % padded)
    if ff_diff is not None and ff_diff >= G_FIRSTFRAME:
        reasons.append("ilk kare - still farki %.1f (>=%.0f): yanlis kadin ya da reframe"
                       % (ff_diff, G_FIRSTFRAME))
    if spread > G_OPAQUE_SPREAD:
        reasons.append("opak oran araligi %.0f%%-%.0f%% (yayilim %.2f > %.2f): i2v zoom/kayma"
                       % (min(op) * 100, max(op) * 100, spread, G_OPAQUE_SPREAD))
    if med > 1e-6 and min(op) < med * G_DROPOUT:
        reasons.append("kare %d'de figur kayboldu (opak %.0f%%, medyan %.0f%%)"
                       % (op.index(min(op)), min(op) * 100, med * 100))
    if jumps and max(jumps) > G_COVER_JUMP:
        reasons.append("maske kapsama sicramasi %.0f%% (kare %d): maske titriyor"
                       % (max(jumps) * 100, jumps.index(max(jumps)) + 1))
    semi_max = max((p["semi"] for p in per_frame), default=0.0)
    if semi_max > G_SEMI:
        reasons.append("yari saydam piksel %.1f%% (over-key)" % (semi_max * 100))
    green_max = max((p["green"] for p in per_frame), default=0.0)
    if green_max > G_GREEN:
        reasons.append("artik yesil %.2f%% (under-key)" % (green_max * 100))
    return {
        "pass": not reasons, "reasons": reasons,
        "opaque_min": min(op) if op else 0.0, "opaque_max": max(op) if op else 0.0,
        "opaque_median": med, "opaque_spread": spread,
        "coverage_jump_max": max(jumps) if jumps else 0.0,
        "semi_max": semi_max, "green_max": green_max,
        "first_frame_diff": ff_diff,
    }


# --------------------------------------------------------------------- akis
def cut_video(video, out_dir, mode: str = "sam", concept: str = "woman",
              fps: int = FPS, seconds: float = SECONDS, still=None,
              masks: np.ndarray | None = None, masks_npz=None,
              frame: tuple[int, int] = FRAME,
              grid: tuple[int, int] = GRID, thumb_size: tuple[int, int] = THUMB,
              still_size: tuple[int, int] = STILL, quality: int = SHEET_Q,
              keep_raw: bool = False, log=print) -> dict:
    """Video -> `cut/alpha_%03d.png` + `metrics.json` + `sheet.webp`/`thumb.webp`
    (+ `still.webp`). Sozlesme: {frames_dir, sheet, thumb, metrics}.

    `masks` verilirse SAM tekrar calistirilmaz (ayni klipten iki kip uretmek
    icin: bir kez segmentle, iki kez alfa hesapla).
    """
    if mode not in ("sam", "hybrid"):
        raise ValueError("mode 'sam' ya da 'hybrid' olmali")
    video, out_dir = Path(video), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = out_dir / "_raw"
    cut_dir = out_dir / "cut"
    shutil.rmtree(cut_dir, ignore_errors=True)
    cut_dir.mkdir(parents=True)

    t0 = time.time()
    frames = extract_frames(video, raw_dir, fps, seconds)
    want = int(round(fps * seconds))
    padded = max(0, want - _real_frame_count(video, fps, seconds))
    t_extract = time.time() - t0

    t0 = time.time()
    if masks is None and masks_npz and Path(masks_npz).is_file():
        masks = np.load(str(masks_npz))["m"].astype(bool)
        log("maskeler onbellekten: %s" % masks_npz)
    if masks is None:
        masks = sam_masks(frames, concept, log=log)
        if masks_npz:
            Path(masks_npz).parent.mkdir(parents=True, exist_ok=True)
            np.savez_compressed(str(masks_npz), m=masks)
    if len(masks) != len(frames):
        raise RuntimeError("maske sayisi kare sayisiyla uyusmuyor")
    t_sam = time.time() - t0

    t0 = time.time()
    per_frame: list[dict] = []
    ff_diff = None
    bg = None
    chromatic = False
    for i, fp in enumerate(frames):
        with Image.open(fp) as im:
            rgb = np.asarray(im.convert("RGB"), dtype=np.uint8)
        if bg is None:
            bg = bg_color(rgb)                      # fon ilk kareden bir kez olculur
            chromatic = bg_chroma(bg) > BG_CHROMA
            if still:
                ff_diff = first_frame_diff(rgb, still)
        if mode == "sam":
            # yerel fon haritasi bir kez: hem alfa hem de-fringe ayni referansi
            # kullanmali, yoksa kenar renginde tutarsizlik olur
            bgmap = local_bg(rgb, masks[i], BAND_PX + 2, fallback=bg)
            a = alpha_sam(rgb, masks[i], bgmap)
            clean = defringe_rgb(rgb, a, bgmap)
            if chromatic:                      # gri fonda argmax(bg) rastgeledir
                clean = despill_rgb(clean, a, bgmap)
        else:
            a = alpha_hybrid(rgb, masks[i], bg)
            clean = despill_rgb(defringe_rgb(rgb, a, bg), a, bg)
        per_frame.append(_frame_stats(clean, a))
        rgba = np.dstack([np.clip(clean, 0, 255), a * 255.0]).astype(np.uint8)
        Image.fromarray(rgba, "RGBA").save(cut_dir / ("alpha_%03d.png" % i))
    t_alpha = time.time() - t0

    t0 = time.time()
    pack = build_sheet(cut_dir, out_dir / "sheet.webp", out_dir / "thumb.webp",
                       frame=frame, grid=grid, thumb_size=thumb_size,
                       still=still, still_out=out_dir / "still.webp",
                       still_size=still_size, fps=fps, quality=quality)
    t_sheet = time.time() - t0

    verdict = _verdict(per_frame, want, padded, mode, ff_diff)
    with Image.open(frames[0]) as _im:          # handle kapali kalmali: _raw silinecek
        src_size = list(_im.size)
    metrics = {
        "video": str(video), "mode": mode, "concept": concept,
        "fps": fps, "seconds": seconds, "frames": len(frames),
        "padded_frames": padded, "bg": [round(float(c), 1) for c in bg],
        "bg_chroma": round(bg_chroma(bg), 4), "chromatic_bg": bool(chromatic),
        "source_size": src_size,
        "per_frame": [{k: round(v, 5) for k, v in p.items()} for p in per_frame],
        "verdict": verdict, "sheet": pack,
        "timings_s": {"extract": round(t_extract, 2), "sam": round(t_sam, 2),
                      "alpha": round(t_alpha, 2), "sheet": round(t_sheet, 2)},
        "per_frame_ms": {"sam": round(t_sam * 1000 / max(len(frames), 1), 1),
                         "alpha": round(t_alpha * 1000 / max(len(frames), 1), 1)},
        "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    (out_dir / "metrics.json").write_text(json.dumps(metrics, indent=1, ensure_ascii=False),
                                          encoding="utf-8")
    if not keep_raw:
        shutil.rmtree(raw_dir, ignore_errors=True)
    log("%s: %d kare, opak %.1f%%-%.1f%%, sheet %.2f MB -> %s"
        % (mode, len(frames), verdict["opaque_min"] * 100, verdict["opaque_max"] * 100,
           pack["sheetBytes"] / 1e6, "GECTI" if verdict["pass"] else "KALDI: "
           + "; ".join(verdict["reasons"])))
    return {"frames_dir": str(cut_dir), "sheet": pack["sheet"], "thumb": pack["thumb"],
            "still": pack.get("still"), "metrics": metrics}


def _real_frame_count(video, fps: int, seconds: float) -> int:
    """Kaynagin `seconds` icinde gercekten kac kare verebilecegi (dolgu olcusu)."""
    try:
        out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0",
                              "-show_entries", "format=duration", "-of", "csv=p=0", str(video)],
                             capture_output=True, text=True, timeout=60).stdout.strip()
        dur = float(out.split(",")[0])
    except Exception:
        return int(round(fps * seconds))
    return min(int(round(fps * seconds)), int(math.floor(dur * fps + 1e-6)))


# ------------------------------------------------------------ karsilastirma
def _checker(size: tuple[int, int]) -> Image.Image:
    """check_keying.py ile ayni damali zemin: magenta/koyu - hem hale hem delik
    ciplak gozle gorunur."""
    w, h = size
    a = np.zeros((h, w, 3), dtype=np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    on = ((xx // 12) + (yy // 12)) % 2 == 1
    a[on] = (255, 0, 255)
    a[~on] = (40, 40, 40)
    return Image.fromarray(a, "RGB")


def legacy_chroma(frame_png, dest) -> Path:
    """ESKI postprocess.py mantigi birebir: ffmpeg chromakey 0x00FF00:0.28:0.08
    + despill=green. Karsilastirma icin - urun yolunda kullanilmaz."""
    dest = Path(dest)
    _run([_ffmpeg(), "-y", "-v", "error", "-i", str(frame_png),
          "-vf", "chromakey=0x00FF00:0.28:0.08,despill=type=green,format=rgba",
          str(dest)], 180)
    return dest


def build_compare(video, out_dir, concept: str = "woman", fps: int = FPS,
                  seconds: float = SECONDS, samples: int = 3, still=None,
                  cell: tuple[int, int] = (260, 390), reuse: bool = False,
                  masks_npz=None, log=print) -> dict:
    """Kaynak | eski chroma | SAM | hybrid yan yana, damali zeminde tek JPG.

    SAM bir kez calisir, iki kip ayni maskeleri kullanir (GPU iki katina cikmasin).
    `reuse=True` ise onceki kesim klasorleri oldugu gibi kullanilir - JPG'yi
    yeniden duzenlemek icin GPU harcanmaz.
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = out_dir / "_raw"
    frames = extract_frames(video, raw_dir, fps, seconds)
    done = all((out_dir / m / "metrics.json").is_file() for m in ("sam", "hybrid"))
    res = {}
    if reuse and done:
        log("onceki kesim kullaniliyor (SAM atlandi)")
        for mode in ("sam", "hybrid"):
            met = json.loads((out_dir / mode / "metrics.json").read_text(encoding="utf-8"))
            res[mode] = {"frames_dir": str(out_dir / mode / "cut"), "metrics": met}
    else:
        if masks_npz and Path(masks_npz).is_file():
            masks = np.load(str(masks_npz))["m"].astype(bool)
            log("maskeler onbellekten: %s" % masks_npz)
        else:
            masks = sam_masks(frames, concept, log=log)
            if masks_npz:
                Path(masks_npz).parent.mkdir(parents=True, exist_ok=True)
                np.savez_compressed(str(masks_npz), m=masks)
        for mode in ("sam", "hybrid"):
            res[mode] = cut_video(video, out_dir / mode, mode=mode, concept=concept,
                                  fps=fps, seconds=seconds, still=still, masks=masks,
                                  log=log)

    idx = [round(i * (len(frames) - 1) / max(samples - 1, 1)) for i in range(samples)]
    zoom_i = idx[len(idx) // 2]
    cols = ["kaynak", "eski chroma", "SAM", "hybrid"]
    cw, ch = cell
    pad, head = 6, 22
    rows = len(idx) + 1                      # + 1:1 sac/kenar detayi
    gap = 18                                 # detay satirinin basligina yer
    grid = Image.new("RGB", (len(cols) * (cw + pad) + pad,
                             head + rows * (ch + pad) + gap + pad), (16, 16, 16))
    draw = ImageDraw.Draw(grid)
    for c, name in enumerate(cols):
        draw.text((pad + c * (cw + pad) + 4, 6), name, fill=(235, 235, 235))
    tmp = Path(tempfile.mkdtemp(prefix="cardcmp_"))
    try:
        legacy = {i: legacy_chroma(frames[i], tmp / ("legacy_%03d.png" % i))
                  for i in sorted(set(idx) | {zoom_i})}
        srcs = {"kaynak": lambda i: frames[i], "eski chroma": lambda i: legacy[i],
                "SAM": lambda i: Path(res["sam"]["frames_dir"]) / ("alpha_%03d.png" % i),
                "hybrid": lambda i: Path(res["hybrid"]["frames_dir"]) / ("alpha_%03d.png" % i)}
        for r, i in enumerate(idx):
            for c, name in enumerate(cols):
                with Image.open(srcs[name](i)) as im:
                    tile = _fit(im.convert("RGBA"), cell)[0]
                back = _checker(cell)
                back.paste(tile, (0, 0), tile)
                grid.paste(back, (pad + c * (cw + pad), head + r * (ch + pad)))

        # 1:1 detay: kesimin ustunden (sac cizgisi) alinan pencere - hale, yesil
        # sacak ve yenen sac telleri ancak bu olcekte gorunur.
        with Image.open(srcs["SAM"](zoom_i)) as im:
            a = np.asarray(im.convert("RGBA"))[..., 3]
        ys, xs = np.nonzero(a > 24)
        cx = int(xs.mean()) if xs.size else a.shape[1] // 2
        top = int(ys.min()) if ys.size else 0
        box = (max(0, cx - cw // 2), max(0, top - 24))
        y = head + len(idx) * (ch + pad) + gap
        draw.text((pad + 4, y - 15), "detay 1:1 (kare %d, sac cizgisi)" % zoom_i, fill=(190, 190, 190))
        for c, name in enumerate(cols):
            with Image.open(srcs[name](zoom_i)) as im:
                crop = im.convert("RGBA").crop((box[0], box[1], box[0] + cw, box[1] + ch))
            back = _checker(cell)
            back.paste(crop, (0, 0), crop)
            grid.paste(back, (pad + c * (cw + pad), y))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    shutil.rmtree(raw_dir, ignore_errors=True)
    dest = out_dir / "compare.jpg"
    grid.save(dest, quality=90)
    log("karsilastirma -> %s (kareler %s)" % (dest, idx))
    return {"compare": str(dest), "frames": idx,
            "sam": res["sam"]["metrics"]["verdict"], "hybrid": res["hybrid"]["metrics"]["verdict"]}


def main() -> None:
    ap = argparse.ArgumentParser(description="#322 Kart Modu kesim + paketleme")
    ap.add_argument("--video", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--mode", default="sam", choices=["sam", "hybrid"])
    ap.add_argument("--concept", default="woman")
    ap.add_argument("--fps", type=int, default=FPS)
    ap.add_argument("--seconds", type=float, default=SECONDS)
    ap.add_argument("--still", default=None, help="reframe guard'i icin kaynak still")
    ap.add_argument("--frame", default="%dx%d" % FRAME, help="kare boyu, orn 448x672")
    ap.add_argument("--thumb", default="%dx%d" % THUMB)
    ap.add_argument("--still-size", default="%dx%d" % STILL)
    ap.add_argument("--quality", type=int, default=SHEET_Q)
    ap.add_argument("--compare", action="store_true",
                    help="kaynak|eski chroma|SAM|hybrid karsilastirma JPG'si")
    ap.add_argument("--reuse", action="store_true",
                    help="--compare: onceki kesimi kullan, SAM'i tekrar calistirma")
    ap.add_argument("--masks", default=None,
                    help="maske onbellegi (.npz); varsa okunur, yoksa yazilir")
    a = ap.parse_args()

    def wh(s: str) -> tuple[int, int]:
        x, y = s.lower().split("x")
        return int(x), int(y)

    if a.compare:
        out = build_compare(a.video, a.out, a.concept, a.fps, a.seconds,
                            still=a.still, reuse=a.reuse, masks_npz=a.masks)
    else:
        out = cut_video(a.video, a.out, a.mode, a.concept, a.fps, a.seconds,
                        still=a.still, masks_npz=a.masks,
                        frame=wh(a.frame), thumb_size=wh(a.thumb),
                        still_size=wh(a.still_size), quality=a.quality)
        out = {k: v for k, v in out.items() if k != "metrics"} | {
            "verdict": out["metrics"]["verdict"]}
    print(json.dumps(out, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
