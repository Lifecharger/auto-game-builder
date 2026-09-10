"""Kart Modu - uretim hattinin 5. kipi (gorev #321).

Hot Card Games'in koleksiyon kartlari. Grok'a bagli `Hot Card Games/tools/cardpipe`
hattinin yerine gecer; cikti sozlesmesi (R2 kovasi `hotcardgames`, manifest semasi,
sprite sheet geometrisi) DEGISMEZ - yalniz uretim tamamen yerellesir.

Kullanicinin tanimladigi DORT ASAMA (design/kart_modu.md §0):

  1 Still    koleksiyon acilinca 13 (+2 joker) rutbe icin 1'er still (image_zimage,
             mode "card"), otomatik kabul -> <rutbe>/still.png; ✎ Duzenle / ↻ Yeniden uret
  2 Video    still -> LTX-2.5 i2v 6 sn (video_ltx), jest promptu + kilitli kamera,
             guard (ilk kare - still farki), otomatik kabul -> <rutbe>/video.mp4
  3 WebP     SAM3 kesim + 12x6 sheet + thumb + hi-res still (tools/cardpipe_local/cut.py)
  4 Push     once dosyalar sonra manifest; manifest push'un ICINDE uretilir, geri alinamaz

Iki tur vardir (avatar YOK): `card` (Normal, tam boy, koleksiyon = 13 rutbe + 2 joker)
ve `dealer` (Krupiye, bel ustu, `_Dealers/<ad>/` tek oge, rutbe yok).

Kutuphane duzeni (`card.root`, vars. D:\\Asset Generation Pipeline\\Hot Card Games):

  _Incoming Kart/<is>.png              Uretilenler'den rutbesiz sahnelenen still
  <koleksiyon>/collection.json         {id, name, theme, style, kind, ranks, jokers, created}
  <koleksiyon>/<rutbe>/still.png       secili still 832x1248 (+ adaylar still_NN.png)
  <koleksiyon>/<rutbe>/still.webp      hi-res still 832x1248 q90 (manifest `still`)
  <koleksiyon>/<rutbe>/video.mp4       i2v master 832x1248
  <koleksiyon>/<rutbe>/video_grok.mp4  eski Grok masteri (goc ile KOPYALANIR, silinmez)
  <koleksiyon>/<rutbe>/cut/            kesim kareleri (RGBA)
  <koleksiyon>/<rutbe>/sheet.webp thumb.webp   paket
  <koleksiyon>/<rutbe>/state.json      asama kayitlari (geometri, jest, guard, metrics)
  <koleksiyon>/_pushed.json            R2'ye giden dosya adlari + surum eki
  _Dealers/<ad>/...                    ayni yapi (bel ustu)

v3 cozunurlugu (design/kart_modu.md "Cozunurluk"): sheet karesi 512x768 (12x6),
thumb 640x960, hi-res still 832x1248; yayin adlari `_sheet_v3` / `_thumb_v3` /
`_still_v3` - eski v2 girdileri manifest'te DURUR (istemciler bayti sonsuza dek
saklar, ustune yazilmaz). Krupiye sheet'i varsayilan olarak v1 geometrisinde
(320x480) kalir; `dealers_v3` bayragi ile 512x768'e gecer (once APK'daki gomulu
scarlett'in yolunu degistiren uygulama surumu cikmali).

#299 - HER IS SIRAYA GIRER: butun ComfyUI isleri comfy_gen'in tek kuyruguna
birakilir (client="flow", category=<koleksiyon>), Sira ekraninda gorunur. Kesim
gibi ComfyUI disi agir isler gpu_lane'den TEK parti halinde gecer (op_id ile).
Uzun isler jigsaw/cbn/karakter ile AYNI op defterini kullanir (/api/card/flow/op/{id}).
"""
from __future__ import annotations

import json
import math
import os
import random
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime

from . import comfy_gen as G
from . import prompt_smith as PS
from . import gpu_lane
from .jigsaw_flow import _op, _op_new, _ops, _ops_lock, _run, op_status, ops  # noqa: F401

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_TOOLS = os.path.join(_ROOT, "tools")
_SETTINGS = os.path.join(_ROOT, "server", "config", "settings.json")
THUMB_DIR = os.path.join(G.OUT_DIR, "_card_thumbs")

DEFAULT_ROOT = r"D:\Asset Generation Pipeline\Hot Card Games"
DEFAULT_GROK = r"C:\Projects\Hot Card Games\design\characters"
DEFAULT_ROSTER = r"C:\Projects\Hot Card Games\tools\cardpipe\roster.json"
DEFAULT_MANIFEST_SRC = r"C:\Projects\Hot Card Games\tools\cardpipe\out\manifest.json"
DEFAULT_BUCKET = "hotcardgames"

INCOMING = "_Incoming Kart"

# --------------------------------------------------------------- sozlesme
RANK_ORDER = ("A", "K", "Q", "J", "10", "9", "8", "7", "6", "5", "4", "3", "2")
JOKER_RANKS = ("J1", "J2")
# #348: kart ARKASI - destenin sirt deseni. Rutbe degil, koleksiyonun 16. yuvasi;
# manifest'te kart olarak GECMEZ, kendi anahtariyla yayinlanir.
BACK_RANK = "BACK"
BACK_EKSENLER = ("motif", "palette", "finish")
BACK_ETIKET = {"motif": "Motif", "palette": "Palet", "finish": "Yuzey"}
RARITY_BY_RANK = {"A": "epic", "K": "rare", "Q": "rare", "J": "rare"}
DEFAULT_RARITY = "common"
JOKER_RARITY = "legendary"
PRICES = {"common": 400, "rare": 1200, "epic": 3000, "legendary": 8000}

FPS = 12
SECONDS = 6
COLS = 12
ROWS = 6                        # izgara 12x6 (#322 `grid`)
FRAMES = FPS * SECONDS          # 72
SUFFIX = "_v3"                  # yayin adi eki - yol degisir, ustune yazilmaz

STILL_SIZE = (832, 1248)        # hi-res still + i2v master olcusu
FRAME_V3 = (512, 768)           # sheet karesi (12x6 -> 6144x4608)
THUMB_V3 = (640, 960)
DEALER_FRAME_V1 = (320, 480)    # APK'da gomulu scarlett'in geometrisi
# Krupiye YATAY olmali (#340): oyunda krupiye bandi tum genisligi kaplayan alcak
# bir seritdir (casino_table.dart: dealerHeightRatio 0.3, submerge 0.3 -> ornek
# 400x257 px kutu). Dikey 2:3 sprite oraya `contain` ile oturunca kadin bandin
# ancak %43'unu doldurur, iki yani bos kalir. 3:2 yatayda ayni kutuda ~%96 dolar.
DEALER_FRAME_V3 = (768, 512)    # sheet karesi 12x6 -> 9216x3072 (WebP 16383 sinirinda)
DEALER_THUMB_V3 = (960, 640)
DEALER_STILL = (1248, 832)      # hi-res still + i2v master (yatay)
SHEET_QUALITY = 85
RESTILL_BG = (212, 212, 208)    # #325 duz acik gri studyo fonu (cut.RESTILL_BG)

# --------------------------------------------------------------- turler
KINDS = {
    "card": {"id": "card", "label": "Normal", "folder": "", "concept": "woman",
             "profile": "card", "ranked": True, "key": "collections"},
    "dealer": {"id": "dealer", "label": "Krupiye", "folder": "_Dealers", "concept": "woman",
               "profile": "dealer", "ranked": False, "key": "dealers"},
}
DEFAULT_KIND = "card"

# Jest metinleri profil dosyasindan gelir; asagisi yedek (roster.gesture_prompts).
FALLBACK_GESTURES = {
    "card": {"idle": "subtle idle breathing, gentle hair sway, soft smile, seamless loop",
             "wink": "playful wink at the viewer, slight head tilt, confident smirk",
             "kiss": "blows a kiss toward the viewer, hand to lips then extends, charming smile",
             "hair": "runs hand through hair and flips it, elegant motion",
             "pose": "shifts weight to one hip, strikes a glamour pose"},
    "dealer": {"idle": "subtle idle breathing, gentle head movement, soft welcoming smile, seamless loop",
               "shuffle": "shuffles a deck of playing cards over the table with both hands",
               "deal": "deals a playing card across the table toward the viewer",
               "wink": "playful wink at the viewer, slight head tilt, confident smirk",
               "smile": "warm delighted smile at the viewer, small nod"},
}
DEFAULT_GESTURE = "idle"
MAIN = "main"          # krupiyenin tek ogesinin rutbe adi (#323 istemcisi bunu yollar)
CUT_MODES = ("sam", "hybrid")

STILL_TASK = "image_zimage"
# #353: koleksiyon basina MODEL secimi. Kullanici ikisini deneyip kendi karar
# verecek: Z-Image hizli (8 adim, cfg 1 - negatif prompt ETKISIZ) ve fonu temiz;
# Qwen yavas (20 adim, cfg 4 - negatifi KULLANIR) ve kostum sadakati daha iyi
# ama arka plana studyo ekipmani koymaya egilimli.
MODELLER = {"zimage": "image_zimage", "qwen": "wf_t2i_qwen_image"}
DEFAULT_MODEL = "zimage"
EDIT_TASK = "edit_qwen"
VIDEO_TASK = "video_ltx"
# Kart videosu bir DONGUDUR (sprite sheet 6 sn basa sarar): FLF2V ile ayni still
# hem ilk hem son kare olarak verilir - klip basladigi kadrajla bitmek zorunda
# kalir, boylece LTX'in icine dogru kaymasi (push-in) kapanir ve dongu dikissiz
# kapanir. Gorev manifest'te yoksa eski i2v'ye duser.
VIDEO_TASK_LOOP = "video_ltx_flf"

GUARD_THRESHOLD = 25.0          # guard_firstframe.py ile ayni esik
ZOOM_TOLERANCE = 0.08           # ilk->son kare figur buyumesi (#337): %8 ustu "kontrol"


# ------------------------------------------------------------------ ayarlar
def _setting(key: str, default: str = "") -> str:
    """settings.json'dan makineye ozel yol (depo herkese acik - yol koda gomulmez)."""
    try:
        with open(_SETTINGS, encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for part in key.split("."):
            d = (d or {}).get(part)
        if isinstance(d, str) and d.strip():
            return d.strip()
    except Exception:
        pass
    return default


def root() -> str:
    return os.environ.get("CARD_ROOT", "").strip() or _setting("card.root") or DEFAULT_ROOT


def grok_root() -> str:
    return os.environ.get("CARD_GROK_ROOT", "").strip() or _setting("card.grok_root") or DEFAULT_GROK


def roster_path() -> str:
    return os.environ.get("CARD_ROSTER", "").strip() or _setting("card.roster") or DEFAULT_ROSTER


def manifest_src() -> str:
    """Devralinacak mevcut manifest (dealers bolumu buradan aynen tasinir)."""
    yerel = os.path.join(root(), "manifest.json")
    if os.path.isfile(yerel):
        return yerel
    return os.environ.get("CARD_MANIFEST_SRC", "").strip() or _setting("card.manifest_src") \
        or DEFAULT_MANIFEST_SRC


def bucket() -> str:
    return _setting("card.bucket") or DEFAULT_BUCKET


def _wrangler() -> str:
    """r2manager'in config'indeki wrangler yolu (jigsaw_flow ile ayni kaynak)."""
    try:
        from . import jigsaw_flow as JF
        return str(JF._cfg().WRANGLER_BIN or "")
    except Exception:
        return shutil.which("wrangler.cmd") or shutil.which("wrangler") or ""


def _options_file() -> str:
    return os.environ.get("CARD_OPTIONS_FILE", "").strip() or _setting("card.options_file") \
        or os.path.join(_ROOT, "server", "config", "card_options.json")


_opts_cache: tuple[float, dict] | None = None


def _options() -> dict:
    global _opts_cache
    yol = _options_file()
    try:
        mt = os.path.getmtime(yol)
    except OSError:
        return {}
    if _opts_cache and _opts_cache[0] == mt:
        return _opts_cache[1]
    try:
        with open(yol, encoding="utf-8") as fh:
            d = json.load(fh) or {}
    except Exception:
        d = {}
    _opts_cache = (mt, d)
    return d


def _presets_file() -> str:
    return os.environ.get("CARD_PRESETS_FILE", "").strip() or _setting("card.presets_file")         or os.path.join(_ROOT, "server", "config", "card_presets.json")


def presets() -> dict:
    """#339: hazir koleksiyon kartlari. Diskten CANLI okunur - dosyaya yeni bir
    satir yazmak yeter, sunucu yeniden baslatilmaz.

    Her kart {id, name, emoji, theme}; `theme` secilince tema alanina yazilir ve
    kullanici ELLE degistirebilir (sablon zorunlu degil, sadece hizlandirici).
    """
    yol = _presets_file()
    out = {"file": yol, "presets": [], "dealer_presets": [], "error": ""}
    try:
        with open(yol, encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for a in ("presets", "dealer_presets"):
            ham = d.get(a) or []
            out[a] = [{"id": str(x.get("id") or ""), "name": str(x.get("name") or ""),
                       "emoji": str(x.get("emoji") or ""), "theme": str(x.get("theme") or "")}
                      for x in ham if isinstance(x, dict) and x.get("theme")]
    except FileNotFoundError:
        out["error"] = "sablon dosyasi yok"
    except Exception as e:
        out["error"] = str(e)[:200]
    return out


def profiles() -> dict:
    """Dropdown profilleri + turler + jestler + rutbe sirasi (istemci bunu okur)."""
    yol = _options_file()
    out = {"profiles": {}, "source": yol, "root": root(), "error": "",
           "kinds": kinds(), "ranks": list(RANK_ORDER), "jokers": list(JOKER_RANKS),
           "cut_modes": list(CUT_MODES), "main": MAIN,
           # #323: `gestures` KART jestleri, krupiyeninki ayri alanda
           "gestures": gestures("card"), "dealer_gestures": gestures("dealer"),
           "presets": presets(),
           "gestures_by_kind": {k: gestures(k) for k in KINDS},
           "geometry": {"fps": FPS, "seconds": SECONDS, "cols": COLS, "frames": FRAMES,
                        "still": list(STILL_SIZE), "frame": list(FRAME_V3),
                        "thumb": list(THUMB_V3), "dealer_frame_v1": list(DEALER_FRAME_V1),
                        # #340: krupiye YATAY - istemciler kadraji buradan okur
                        "dealer_frame": list(DEALER_FRAME_V3),
                        "dealer_thumb": list(DEALER_THUMB_V3),
                        "dealer_still": list(DEALER_STILL),
                        "suffix": SUFFIX}}
    try:
        with open(yol, encoding="utf-8") as fh:
            out["profiles"] = json.load(fh)
    except Exception as e:
        out["error"] = str(e)
    return out


def kinds() -> list[dict]:
    return [{"id": k["id"], "label": k["label"], "ranked": k["ranked"]} for k in KINDS.values()]


def kind_id(kind: str = "") -> str:
    k = (kind or "").strip().lower()
    return k if k in KINDS else DEFAULT_KIND


def gestures(kind: str = "") -> dict:
    """Turun jest metinleri: profil dosyasi, yoksa yedek liste."""
    k = kind_id(kind)
    prof = (_options().get(KINDS[k]["profile"]) or {})
    jest = prof.get("jestler") or {}
    return {a: b for a, b in jest.items() if isinstance(b, str)} or dict(FALLBACK_GESTURES[k])


def gesture_text(kind: str, gesture: str) -> str:
    """Jest metni: hazir anahtar -> profil cumlesi, aksi halde SERBEST METIN (#335).

    Telefondan/studyodan "hafifce kalca sallama, kollar sabit" gibi kisa bir
    cumle gelebilir. Anahtar listesinde yoksa oldugu gibi hareket cumlesi olarak
    kullanilir (eskiden sessizce idle'a duserdi - yazim hatasi da gizlenirdi).
    """
    g = (gesture or "").strip()
    jestler = gestures(kind)
    if g in jestler:
        return jestler[g]
    if g:
        return g[:400]
    return jestler.get(DEFAULT_GESTURE) or "subtle idle breathing"


def _prompt2(kind: str) -> str:
    prof = (_options().get(KINDS[kind_id(kind)]["profile"]) or {})
    return (prof.get("sablon") or "").strip() or \
        (G.CARD_DEALER_PROMPT2 if kind_id(kind) == "dealer" else G.CARD_PROMPT2)


def _negative(kind: str) -> str:
    prof = (_options().get(KINDS[kind_id(kind)]["profile"]) or {})
    return (prof.get("negatif") or "").strip() or G.CARD_NEG


def _motion2(kind: str) -> str:
    prof = (_options().get(KINDS[kind_id(kind)]["profile"]) or {})
    return (prof.get("video_sablon") or "").strip() or G.CARD_MOTION2


# -------------------------------------------------------------------- yollar
_BAD = '\\/:*?"<>|'


def _safe(ad: str, alan: str = "ad") -> str:
    ad = (ad or "").strip()
    if not ad or len(ad) > 80 or any(c in ad for c in _BAD) or ad.startswith(".") or ".." in ad:
        raise ValueError("gecersiz %s: %s" % (alan, ad))
    return ad


def _inside(base: str, p: str) -> str:
    b, q = os.path.abspath(base), os.path.abspath(p)
    if not (q == b or q.startswith(b + os.sep)):
        raise ValueError("yol kutuphane disinda")
    return q


def col_dir(collection: str, kind: str = "", create: bool = False) -> str:
    """Koleksiyon klasoru.

    Kart: <root>/<koleksiyon>. Krupiye: <root>/_Dealers/<ad> - telefon
    istemcisi (#323) her krupiyeyi TEK OGELI bir koleksiyon gibi gosterir
    (rutbe listesi ["main"]), diskteki duzen de doc §2 ile ayni kalir.
    """
    k = kind_id(kind)
    ad = _safe(collection, "koleksiyon")
    if KINDS[k]["folder"]:
        return _mk(os.path.join(root(), KINDS[k]["folder"], ad), create)
    return _mk(os.path.join(root(), ad), create)


def _mk(d: str, create: bool) -> str:
    if create:
        os.makedirs(d, exist_ok=True)
    return d


def rank_dir(collection: str, rank: str, kind: str = "", create: bool = False) -> str:
    """Krupiyede rutbe yok: dosyalar dogrudan _Dealers/<ad>/ icinde durur."""
    if kind_id(kind) == "dealer":
        r = str(rank or MAIN).lower()
        if r not in (MAIN, "", "idle"):
            raise ValueError("krupiyede rutbe yok (main bekleniyordu): %s" % rank)
        return col_dir(collection, kind, create)
    return _mk(os.path.join(col_dir(collection, kind), _safe(str(rank).lower(), "rutbe")), create)


# ------------------------------------------------- animasyon deposu (#338)
# Bugune kadar her rutbede TEK animasyon vardi: <rutbe>/video.mp4 + sheet.webp +
# thumb.webp. Artik her rutbe birden fazla animasyon tasiyabilir:
#   <rutbe>/anim/<ad>/video.mp4 | sheet.webp | thumb.webp
# KOKTEKI dosyalar "idle" animasyonudur ve YERINDE KALIR - istemciler dosya
# baytlarini sonsuza dek sakliyor, tasimak eski surumleri kirar.
IDLE_ANIM = "idle"
ANIM_DIR = "anim"


def anim_id(name: str = "") -> str:
    """Animasyon adi: bos/idle -> IDLE_ANIM; digerleri dosya adina uygun."""
    a = (name or "").strip().lower()
    if not a or a == IDLE_ANIM:
        return IDLE_ANIM
    return _safe(a, "animasyon")


def anim_dir(collection: str, rank: str, kind: str = "", anim: str = "",
             create: bool = False) -> str:
    """Bir animasyonun klasoru. idle = rutbe klasorunun KENDISI (geriye uyum)."""
    d = rank_dir(collection, rank, kind, create)
    a = anim_id(anim)
    if a == IDLE_ANIM:
        return d
    return _mk(os.path.join(d, ANIM_DIR, a), create)


def anims_of(collection: str, rank: str, kind: str = "") -> list[dict]:
    """Rutbenin animasyonlari: idle once, sonra anim/<ad> klasorleri (alfabetik).

    Her oge: {name, video, sheet, thumb, stage} - stage 0 bos, 2 video, 3 sheet.
    """
    d = rank_dir(collection, rank, kind)
    out = []

    def satir(ad: str, klasor: str) -> dict:
        v = os.path.isfile(os.path.join(klasor, "video.mp4"))
        sh = os.path.isfile(os.path.join(klasor, "sheet.webp"))
        th = os.path.isfile(os.path.join(klasor, "thumb.webp"))
        return {"name": ad, "video": v, "sheet": sh, "thumb": th,
                "dir": _rel(klasor), "stage": 3 if (sh and th) else (2 if v else 0),
                "gesture": (state(collection, rank, kind).get("video") or {}).get("gesture", "")
                if ad == IDLE_ANIM else
                (_read_json(os.path.join(klasor, "state.json"), {}) or {}).get("gesture", "")}

    out.append(satir(IDLE_ANIM, d))
    kok = os.path.join(d, ANIM_DIR)
    if os.path.isdir(kok):
        for ad in sorted(os.listdir(kok)):
            alt = os.path.join(kok, ad)
            if os.path.isdir(alt):
                out.append(satir(ad, alt))
    return out


def anim_delete(collection: str, rank: str, anim: str, kind: str = "") -> dict:
    """Bir animasyonu siler. idle SILINMEZ - o kartin kendisidir."""
    a = anim_id(anim)
    if a == IDLE_ANIM:
        raise ValueError("idle silinemez - kartin ana animasyonu")
    d = anim_dir(collection, rank, kind, a)
    if not os.path.isdir(d):
        raise ValueError("animasyon yok: %s" % a)
    shutil.rmtree(d)
    return {"deleted": a, "anims": [x["name"] for x in anims_of(collection, rank, kind)]}


def _rel(p: str) -> str:
    """card.root'a gore yol (istemci /file ve /thumb uclarina bunu yollar)."""
    try:
        return os.path.relpath(p, root()).replace("\\", "/")
    except Exception:
        return p.replace("\\", "/")


def file_path(rel: str) -> str | None:
    """card.root'a gore yolu cozer.

    #343 uyum koprusu: krupiyede rutbe klasoru YOKTUR (dosyalar dogrudan
    `_Dealers/<ad>/` icindedir), ama istemci rutbeli kalibi kurabiliyor
    (`<ad>/MAIN/<dosya>`). O kalip cozulmezse krupiye yoluna dusulur - boylece
    eski istemci surumleri de dogru dosyayi bulur.
    """
    yol = (rel or "").replace("\\", "/").strip("/")
    p = _inside(root(), os.path.join(root(), yol))
    if os.path.isfile(p):
        return p
    parca = [x for x in yol.split("/") if x]
    if len(parca) == 3 and parca[1].lower() in (MAIN, "main"):
        alt = os.path.join(root(), KINDS["dealer"]["folder"], parca[0], parca[2])
        alt = _inside(root(), alt)
        if os.path.isfile(alt):
            return alt
    return None


VIDEO_EXT = (".mp4", ".webm", ".mov")


def thumb(rel: str, size: int = 360) -> str | None:
    """Onbellekli onizleme (video/webp'in ilk karesi cikarilir)."""
    src = file_path(rel)
    if not src:
        return None
    import hashlib
    st = os.stat(src)
    key = hashlib.sha1(("%s|%d|%d|%d" % (src, st.st_size, int(st.st_mtime), size)).encode()).hexdigest()
    dest = os.path.join(THUMB_DIR, key + ".jpg")
    if os.path.isfile(dest):
        return dest
    os.makedirs(THUMB_DIR, exist_ok=True)
    tmp = dest + ".tmp"
    try:
        if os.path.splitext(src)[1].lower() in VIDEO_EXT:
            ff = G._ffmpeg() or "ffmpeg"
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-frames:v", "1",
                            "-vf", "scale=%d:-1" % size, tmp], check=True, timeout=300,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        else:
            from PIL import Image
            with Image.open(src) as f:
                f.seek(0)
                f.thumbnail((size, size))
                im = f.convert("RGB")
            im.save(tmp, "JPEG", quality=84)
        os.replace(tmp, dest)
        return dest
    except Exception:
        try:
            os.remove(tmp)
        except OSError:
            pass
        return None


def _read_json(p: str, default=None):
    try:
        with open(p, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def _write_json(p: str, data) -> None:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, p)


def _serbest_ad(dest_dir: str, kalip: str) -> str:
    """'still_%02d.png' kalibi icin bos numara (ustune YAZMAZ)."""
    os.makedirs(dest_dir, exist_ok=True)
    k = 1
    while os.path.isfile(os.path.join(dest_dir, kalip % k)):
        k += 1
    return os.path.join(dest_dir, kalip % k)


# ------------------------------------------------------------------ roster
_roster_cache: tuple[float, dict] | None = None


def roster() -> dict:
    global _roster_cache
    yol = roster_path()
    try:
        mt = os.path.getmtime(yol)
    except OSError:
        return {}
    if _roster_cache and _roster_cache[0] == mt:
        return _roster_cache[1]
    d = _read_json(yol, {}) or {}
    _roster_cache = (mt, d)
    return d


def rarity_of(rank: str, jokers: bool = False) -> str:
    r = str(rank).upper()
    if jokers or r in JOKER_RANKS:
        return JOKER_RARITY
    return RARITY_BY_RANK.get(r, DEFAULT_RARITY)


def price_of(rarity: str) -> int:
    prices = (roster().get("prices") or {}) or PRICES
    return int(prices.get(rarity, PRICES.get(rarity, 0)))


def card_id(collection: str, rank: str, kind: str = "") -> str:
    """Kart kimligi: <koleksiyon>_<rutbe kucuk>; krupiyede sadece <ad>."""
    if kind_id(kind) == "dealer":
        return str(collection).lower()
    return "%s_%s" % (collection, str(rank).lower())


def slots_of(kind: str, jokers: int = 0) -> list[str]:
    """#348: Koleksiyon Karti ekraninin 16 yuvasi = 13 rutbe + 2 joker + kart arkasi.

    `ranks_of` URETIM rutbelerini verir (manifest, roster, sheet); bu ise
    duzenleme ekraninin yuva listesidir.
    """
    if kind_id(kind) == "dealer":
        return [MAIN.upper()]
    # Duzenleme ekrani HER ZAMAN 16 yuva gosterir: 13 rutbe + 2 joker + arka.
    # Koleksiyonun `jokers` ayari uretim/manifest tarafini ilgilendirir; joker
    # yuvasina gorsel uretilirse ayar kendiliginden 2'ye cekilir (bkz. stills).
    return list(RANK_ORDER) + list(JOKER_RANKS) + [BACK_RANK]


def is_back(rank: str) -> bool:
    return str(rank or "").strip().upper() == BACK_RANK


def ranks_of(kind: str, jokers: int = 0) -> list[str]:
    if kind_id(kind) == "dealer":
        return []
    n = 2 if int(jokers or 0) >= 2 else (1 if int(jokers or 0) == 1 else 0)
    return list(RANK_ORDER) + list(JOKER_RANKS[:n])


# --------------------------------------------------- gorunum rotasyonu (v4/v5)
def _tohum(metin: str) -> int:
    """Sabit (surumler arasi degismeyen) tam sayi tohum - hash() rastgeledir."""
    h = 0
    for ch in metin or "":
        h = (h * 131 + ord(ch)) & 0xFFFFFFFF
    return h


def look_for(collection: str, kind: str, rank: str, index: int) -> dict:
    """Rutbe basina FARKLI gorunus: ten/sac/kiyafet/poz listeleri dondurulur.

    cardpipe v4 kurali: bir koleksiyondaki 13 kart birbirine benzemez. Listeler
    13 ogeli oldugu icin (offset + index) % len her eksende 13 ayri deger verir;
    offset koleksiyon adindan turer, yani ayni koleksiyon her zaman ayni diziyi
    uretir (yeniden uretim tekrarlanabilir).
    """
    prof = (_options().get(KINDS[kind_id(kind)]["profile"]) or {})
    sec = prof.get("secenekler") or {}
    out = {}
    for i, alan in enumerate(("skin", "hair", "outfit", "pose")):
        liste = [x for x in (sec.get(alan) or []) if isinstance(x, str)]
        if not liste:
            continue
        off = _tohum("%s|%s" % (collection, alan)) % len(liste)
        out[alan] = liste[(off + index) % len(liste)]
    return out


def look_text(theme: str, look: dict) -> str:
    # "look" = birlesik gorunus (goc edilmis koleksiyonlar ve #337 LLM ciktisi);
    # skin/hair/outfit = jenerik rotasyonun ayri alanlari. Hangisi varsa o girer.
    parca = [(theme or "").strip()]
    for alan in ("look", "skin", "hair", "outfit", "pose"):
        if look.get(alan):
            parca.append(look[alan].strip())
    return ", ".join(x for x in parca if x)


# ------------------------------------------------------------ koleksiyon.json
def collection_meta(collection: str, kind: str = "") -> dict:
    d = col_dir(collection, kind)
    m = _read_json(os.path.join(d, "collection.json"), None)
    if not isinstance(m, dict):
        raise ValueError("koleksiyon yok: %s" % collection)
    return m


def _save_collection(collection: str, kind: str, m: dict) -> dict:
    _write_json(os.path.join(col_dir(collection, kind, create=True), "collection.json"), m)
    return m


def state(collection: str, rank: str, kind: str = "") -> dict:
    return _read_json(os.path.join(rank_dir(collection, rank, kind), "state.json"), {}) or {}


def _set_state(collection: str, rank: str, kind: str, **kw) -> dict:
    p = os.path.join(rank_dir(collection, rank, kind, create=True), "state.json")
    s = _read_json(p, {}) or {}
    s.update(kw)
    s["rank"] = str(rank).upper()
    _write_json(p, s)
    return s


# ------------------------------------------------------------------ listeleme
def _rank_row(collection: str, kind: str, rank: str, pushed: dict) -> dict:
    d = rank_dir(collection, rank, kind)
    s = state(collection, rank, kind)
    cid = card_id(collection, rank, kind)
    var = lambda ad: os.path.isfile(os.path.join(d, ad))   # noqa: E731
    sheet = s.get("sheet") or {}
    row = {
        "rank": str(rank).upper(), "id": cid, "dir": _rel(d),
        "still": var("still.png"), "still_rel": _rel(os.path.join(d, "still.png")),
        "still_webp": var("still.webp"), "still_webp_rel": _rel(os.path.join(d, "still.webp")),
        "video": var("video.mp4"), "video_rel": _rel(os.path.join(d, "video.mp4")),
        "grok": var("video_grok.mp4"), "grok_rel": _rel(os.path.join(d, "video_grok.mp4")),
        "sheet": var("sheet.webp"), "sheet_rel": _rel(os.path.join(d, "sheet.webp")),
        "thumb": var("thumb.webp"), "thumb_rel": _rel(os.path.join(d, "thumb.webp")),
        "pushed": cid in (pushed.get("cards") or {}),
        "gesture": (s.get("video") or {}).get("gesture") or "",
        "guard": (s.get("video") or {}).get("guard") or None,
        "verdict": sheet.get("verdict") or "",
        "metrics": sheet.get("metrics") or {},
        "rev": _rev(d),
        "cut_mode": sheet.get("mode") or "",
        # #345: LLM'in yazdigi son prompt istemciye de gitsin - kullanici hangi
        # metnin bu gorseli urettigini gormeden duzeltemez.
        "prompt": "", "look": "", "pose": "", "age": 0,
        "frameW": sheet.get("frameW") or 0, "frameH": sheet.get("frameH") or 0,
        "frames": sheet.get("frames") or 0,
        "candidates": [],
    }
    try:
        m = collection_meta(collection, kind)
        gor = (m.get("ranks") or {}).get(str(rank).upper()) or {}
        row["prompt"] = str(gor.get("prompt") or "")
        row["look"] = str(gor.get("look") or "")
        row["pose"] = str(gor.get("pose") or "")
        row["age"] = int(gor.get("age") or 0)
        row["prompts_by"] = str(m.get("prompts_by") or "")
    except Exception:
        pass
    try:
        row["candidates"] = sorted(_rel(os.path.join(d, a)) for a in os.listdir(d)
                                   if a.startswith("still_") and a.endswith(".png")
                                   and a not in ADAY_DISI)
    except OSError:
        pass
    # Asama numarasi: 0 bos, 1 still, 2 video, 3 sheet, 4 push
    row["stage"] = 4 if row["pushed"] else (3 if row["sheet"] else
                                            (2 if row["video"] else (1 if row["still"] else 0)))
    return row


def _rev(d: str) -> int:
    """Onbellek kirici: klasordeki varliklarin en yeni degisiklik zamani (saniye).

    Istemci (#323) thumb/file uclarina `v=<rev>` ekler; yol degismeden goruntu
    tazelensin diye.
    """
    en = 0
    for a in ("still.png", "still.webp", "video.mp4", "sheet.webp", "thumb.webp"):
        try:
            en = max(en, int(os.path.getmtime(os.path.join(d, a))))
        except OSError:
            pass
    return en


def _sec(istek, tum: list[str]) -> list[str]:
    """Istenen rutbeleri diskteki listeye eslestirir (bos istek = hepsi)."""
    if not istek:
        return list(tum)
    esle = {x.lower(): x for x in tum}
    out = [esle[str(r).lower()] for r in istek if str(r).lower() in esle]
    return out or list(tum)


def pushed_of(collection: str, kind: str = "") -> dict:
    return _read_json(os.path.join(col_dir(collection, kind), "_pushed.json"), {}) or {}


def _collection_ranks(collection: str, kind: str) -> list[str]:
    """Diskteki rutbeler, sozlesme sirasinda. Krupiyede tek oge: ["main"]."""
    d = col_dir(collection, kind)
    if kind_id(kind) == "dealer":
        return [MAIN] if os.path.isdir(d) else []
    try:
        adlar = [a for a in os.listdir(d) if os.path.isdir(os.path.join(d, a))
                 and not a.startswith("_") and a != "cut"]
    except OSError:
        return []
    sira = {r.lower(): i for i, r in enumerate(list(RANK_ORDER) + list(JOKER_RANKS))}
    return sorted(adlar, key=lambda a: (sira.get(a.lower(), 99), a))


def dealer_names() -> list[str]:
    """_Dealers altindaki krupiyeler (her biri kendi koleksiyonu)."""
    d = os.path.join(root(), KINDS["dealer"]["folder"])
    try:
        return sorted((a for a in os.listdir(d)
                       if os.path.isdir(os.path.join(d, a)) and not a.startswith("_")),
                      key=str.lower)
    except OSError:
        return []


def collection(collection_id: str, kind: str = "") -> dict:
    """Koleksiyon detayi: 13 (+joker) kartin asama bayraklari."""
    k = kind_id(kind)
    m = collection_meta(collection_id, k)
    pushed = pushed_of(collection_id, k)
    ranks = _collection_ranks(collection_id, k) or \
        [r.lower() for r in ranks_of(k, m.get("jokers", 0))]
    cards = [_rank_row(collection_id, k, r, pushed) for r in ranks]
    kapak = next((c for c in cards if c["rank"] == "A" and c["thumb"]), None) \
        or next((c for c in cards if c["thumb"]), None) \
        or next((c for c in cards if c["still"]), None)
    # #323: istemci `ranks` haritasini okur (kart) / `state` (krupiye).
    # #345: prompt/look/pose/age da haritaya girer - kullanici hangi metnin bu
    # gorseli urettigini gormeden duzeltemez.
    harita = {c["rank"]: {a: c.get(a) for a in ("still", "video", "sheet", "pushed",
                                                "verdict", "rev", "gesture", "metrics",
                                                "prompt", "look", "pose", "age")}
              for c in cards}
    out = {"id": m.get("id") or collection_id, "name": m.get("name") or collection_id,
           "kind": k, "style": m.get("style") or "realistic", "theme": m.get("theme") or "",
           "jokers": int(m.get("jokers") or 0), "created": m.get("created") or "",
           "dir": _rel(col_dir(collection_id, k)),
           # #327: thumb yalniz gercekten varsa; yoksa still (Jokers: yalniz J1/J2).
           "cover": ((kapak or {}).get("thumb_rel") if (kapak or {}).get("thumb")
                     else (kapak or {}).get("still_rel")) or "",
           "rev": max([0] + [c["rev"] for c in cards]),
           "ranks": harita, "cards": cards,
           "prompts_by": m.get("prompts_by") or "",
           "counts": {"total": len(cards),
                      "still": sum(1 for c in cards if c["still"]),
                      "video": sum(1 for c in cards if c["video"]),
                      "sheet": sum(1 for c in cards if c["sheet"]),
                      "pushed": sum(1 for c in cards if c["pushed"]),
                      "check": sum(1 for c in cards if c["verdict"] == "kontrol")}}
    if k == "dealer":
        tek = cards[0] if cards else {}
        out["gesture"] = tek.get("gesture") or (m.get("gesture") or DEFAULT_GESTURE)
        out["state"] = {a: tek.get(a) for a in ("still", "video", "sheet", "pushed", "verdict")}
    return out


def collections(kind: str = "") -> dict:
    """Kutuphanedeki koleksiyonlar (kart) + krupiyeler. Kart detayi tasimaz."""
    r = root()
    os.makedirs(r, exist_ok=True)
    out = []
    istek = kind_id(kind) if kind else ""
    if not istek or istek == "card":
        try:
            for a in sorted(os.listdir(r), key=str.lower):
                d = os.path.join(r, a)
                if not os.path.isdir(d) or a.startswith("_"):
                    continue
                if not os.path.isfile(os.path.join(d, "collection.json")):
                    continue
                c = collection(a, "card")
                c.pop("cards", None)
                out.append(c)
        except OSError:
            pass
    if not istek or istek == "dealer":
        # #323: HER KRUPIYE ayri bir satir (tek ogeli koleksiyon).
        for ad in dealer_names():
            try:
                c = collection(ad, "dealer")
            except ValueError:
                continue
            c.pop("cards", None)
            out.append(c)
    return {"root": r, "kinds": kinds(), "collections": out,
            "incoming": _incoming_list()}


def _incoming_list() -> list[dict]:
    d = os.path.join(root(), INCOMING)
    try:
        return [{"file": a, "rel": _rel(os.path.join(d, a))}
                for a in sorted(os.listdir(d))
                if a.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))]
    except OSError:
        return []


# --------------------------------------------------------- comfy_gen kuyrugu
def _await_job(job_id: str, op_id: str, etiket: str, timeout: int = 3 * 3600) -> str:
    """#299: tek comfy_gen isini bekler, cikti dosyasinin yolunu doner."""
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(3)
        j = G.get_job(job_id)
        if not j:
            raise RuntimeError("is kayboldu: %s" % job_id[:8])
        st = j.get("status")
        if st == "done":
            f = G.job_file(job_id)
            if not f:
                raise RuntimeError("is bitti ama cikti yok")
            return f
        if st in ("error", "cancelled"):
            raise RuntimeError(j.get("error") or st)
        _op(op_id, message="%s  %s %%%d" % (etiket, st, j.get("progress") or 0))
    raise RuntimeError("zaman asimi: %s" % etiket)


def _is_sil(jid: str, tasindi: bool = False) -> None:
    """Ara cikti galeride kalmasin. tasindi=True ise DOSYAYA DOKUNULMAZ (#314)."""
    try:
        G.delete_job(jid, remove_file=not tasindi)
    except Exception:
        pass
    if tasindi:
        try:
            t = G._thumb_path(jid)
            if t and os.path.isfile(t):
                os.remove(t)
        except Exception:
            pass


def _tasi(src: str, dest: str) -> str:
    """Cikti dosyasini hedefe TASIR (kes); ustundekini adaya cevirmez."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.abspath(src) == os.path.abspath(dest):
        return dest
    if os.path.isfile(dest):
        os.remove(dest)
    shutil.move(src, dest)
    return dest


def _to_png(src: str, dest: str) -> str:
    """Cikti PNG degilse cevirir (Z-Image png verir, yine de garanti)."""
    if os.path.splitext(src)[1].lower() == ".png":
        return _tasi(src, dest)
    from PIL import Image
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with Image.open(src) as f:
        f.convert("RGB").save(dest, "PNG")
    try:
        os.remove(src)
    except OSError:
        pass
    return dest


def _dealer_reframe(png: str) -> dict:
    """#342: krupiye still'ini BEL USTU kadraja otomatik kirpar.

    Neden gerekli: prompt'a "medium shot, waist up" yazmak yetmiyor - Z-Image
    insan figurunu her turlu tam boy ciziyor, 3:2 tuvalde kadin ortada kucuk
    kaliyor, iki yani bos. Oyunun krupiye bandi genis ve alcak oldugu icin bu
    kadraj bandi doldurmuyor. Cozum modelden bagimsiz: figuru bul, bastan bele
    kadar kes, hedef orana getir.

    Fon duz acik gri oldugu icin figur esikle bulunur. Islem YERINDE yapilir;
    figur bulunamazsa dosyaya DOKUNULMAZ.
    """
    from PIL import Image
    hedef_w, hedef_h = DEALER_STILL
    oran = hedef_w / float(hedef_h)
    try:
        with Image.open(png) as f:
            im = f.convert("RGB")
    except Exception as e:
        return {"ok": False, "note": str(e)[:120]}
    W, H = im.size
    gri = im.convert("L")
    px = gri.load()
    # Fon rengi kose ortalamasindan; figur = fondan belirgin sapma.
    kose = [px[2, 2], px[W - 3, 2], px[2, H - 3], px[W - 3, H - 3]]
    fon = sum(kose) / 4.0
    xs, ys = [], []
    adim = max(1, W // 260)
    for y in range(0, H, adim):
        for x in range(0, W, adim):
            if abs(px[x, y] - fon) > 26:
                xs.append(x)
                ys.append(y)
    if len(xs) < 80:
        return {"ok": False, "note": "figur bulunamadi"}
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    boy = y1 - y0
    if boy < H * 0.25:
        return {"ok": False, "note": "figur cok kucuk"}
    # Oyun sprite'in alt %30'unu feltin arkasina gomuyor. Kullanicinin sarti:
    # GORUNEN bant gogsun ALTINDA bitsin. Gorunen kisim = kirpimin ust %70'i, o
    # yuzden kirpim figurun ust %67'sine kadar iner: 0.7*0.67 - 0.018 ~= 0.45,
    # yani gorunen alt sinir figurun %45'i (gogus altina denk gelir).
    ust = max(0, y0 - int(boy * 0.06))
    alt = min(H, y0 + int(boy * 0.67))
    yeni_h = alt - ust
    yeni_w = int(round(yeni_h * oran))
    orta = (x0 + x1) // 2
    sol = orta - yeni_w // 2
    if yeni_w > W:                      # kaynak yeterince genis degil: yukseklikten ver
        yeni_w = W
        yeni_h = int(round(yeni_w / oran))
        sol = 0
        alt = min(H, ust + yeni_h)
        yeni_h = alt - ust
    sol = max(0, min(sol, W - yeni_w))
    kutu = (sol, ust, sol + yeni_w, ust + yeni_h)
    try:
        # Ham hali BIR KEZ saklanir - kirpim orani ileride degisirse kaynaktan
        # yeniden kirpilir, yeniden uretim gerekmez.
        ham = os.path.join(os.path.dirname(png), "still_raw.png")
        if not os.path.isfile(ham):
            im.save(ham, "PNG")
        kirp = im.crop(kutu).resize((hedef_w, hedef_h), Image.LANCZOS)
        kirp.save(png, "PNG")
    except Exception as e:
        return {"ok": False, "note": str(e)[:120]}
    return {"ok": True, "box": list(kutu), "figure": [x0, y0, x1, y1],
            "fill": round(min(1.0, (x1 - x0) / float(yeni_w)), 3)}


def _still_webp(png: str, dest: str, kind: str = "card") -> str:
    """Hi-res still WebP q90 (manifest `still` alani).

    Kart 832x1248 dikey, krupiye 1248x832 YATAY (#340).
    """
    from PIL import Image
    hedef = still_size(kind)
    with Image.open(png) as f:
        im = f.convert("RGB")
        if im.size != hedef:
            im = im.resize(hedef, Image.LANCZOS)
        im.save(dest, "WEBP", quality=90, method=4)
    return dest


def _yedekle_still(d: str) -> None:
    """Kabul edilen still degistirilmeden once aday olarak saklanir (geri alinabilsin)."""
    p = os.path.join(d, "still.png")
    if os.path.isfile(p):
        shutil.copy(p, _serbest_ad(d, "still_%02d.png"))


# ------------------------------------------------ varlik cozumleyici (#323/#324)
# Telefon `kind=still|frame|thumb`, studyo `view=still|video|cut|sheet|cover`
# yollar; ikisi de ayni cozumleyiciye duser. `rel=` (card.root'a gore yol) de
# desteklenir - eski/dogrudan erisim icin.
VIEW_ALIAS = {"still": "still", "frame": "cut", "cut": "cut", "thumb": "thumb",
              "sheet": "sheet", "video": "video", "cover": "cover", "grok": "grok"}


def _asset_file(d: str, view: str) -> str:
    if view == "still":
        for a in ("still.webp", "still.png"):
            if os.path.isfile(os.path.join(d, a)):
                return os.path.join(d, a)
        return ""
    if view == "thumb":
        return os.path.join(d, "thumb.webp")
    if view == "sheet":
        return os.path.join(d, "sheet.webp")
    if view == "video":
        for a in ("video.mp4", "video_grok.mp4"):
            if os.path.isfile(os.path.join(d, a)):
                return os.path.join(d, a)
        return ""
    if view == "grok":
        return os.path.join(d, "video_grok.mp4")
    return ""


def cut_frame(collection: str, rank: str, kind: str = "") -> str | None:
    """Kesim onizlemesi: ILK KARE, RGBA (seffaf zemin - damali arka plan icin).

    Once kesim kareleri (cut/alpha_*.png), yoksa sheet'in ilk hucresi kirpilir
    ve `_frame0.png` olarak onbelleklenir.
    """
    d = rank_dir(collection, rank, kind)
    cd = os.path.join(d, "cut")
    try:
        kareler = sorted(a for a in os.listdir(cd) if a.lower().endswith(".png"))
    except OSError:
        kareler = []
    if kareler:
        return os.path.join(cd, kareler[0])
    sheet = os.path.join(d, "sheet.webp")
    if not os.path.isfile(sheet):
        return None
    onbellek = os.path.join(d, "_frame0.png")
    if os.path.isfile(onbellek) and os.path.getmtime(onbellek) >= os.path.getmtime(sheet):
        return onbellek
    st = (state(collection, rank, kind).get("sheet") or {})
    fw = int(st.get("frameW") or FRAME_V3[0])
    fh = int(st.get("frameH") or FRAME_V3[1])
    try:
        from PIL import Image
        with Image.open(sheet) as f:
            im = f.convert("RGBA").crop((0, 0, min(fw, f.width), min(fh, f.height)))
        im.save(onbellek, "PNG")
        return onbellek
    except Exception:
        return None


def asset(collection: str, rank: str = "", view: str = "still", kind: str = "",
          rel: str = "") -> dict | None:
    """(koleksiyon, rutbe, gorunum) -> {path, media, rel, alpha}.

    `cover` koleksiyon duzeyindedir: A rutbesinin thumb'i (yoksa ilk bulunan).
    """
    if rel:
        p = file_path(rel)
        return {"path": p, "media": _media(p), "rel": rel, "alpha": p.endswith(".png")} \
            if p else None
    k = kind_id(kind)
    v = VIEW_ALIAS.get((view or "still").strip().lower(), "still")
    if v == "cover":
        det = collection_state(collection, k)
        for r in det:
            for aday in ("thumb", "still"):
                pp = _asset_file(rank_dir(collection, r, k), aday)
                if pp and os.path.isfile(pp):
                    return {"path": pp, "media": _media(pp), "rel": _rel(pp),
                            "alpha": pp.endswith((".png", ".webp"))}
        return None
    r = str(rank or (MAIN if k == "dealer" else "A"))
    if v == "cut":
        pp = cut_frame(collection, r, k)
        return {"path": pp, "media": "image/png", "rel": _rel(pp), "alpha": True} if pp else None
    pp = _asset_file(rank_dir(collection, r, k), v)
    if not pp or not os.path.isfile(pp):
        return None
    return {"path": pp, "media": _media(pp), "rel": _rel(pp),
            "alpha": pp.lower().endswith((".png", ".webp"))}


def collection_state(collection: str, kind: str = "") -> list[str]:
    """Kapak arayisinda kullanilan rutbe sirasi (A once)."""
    rs = _collection_ranks(collection, kind)
    return sorted(rs, key=lambda a: (0 if a.lower() == "a" else 1, a))


_MEDIA = {".png": "image/png", ".webp": "image/webp", ".jpg": "image/jpeg",
          ".jpeg": "image/jpeg", ".mp4": "video/mp4", ".webm": "video/webm",
          ".json": "application/json"}


def _media(p: str) -> str:
    return _MEDIA.get(os.path.splitext(p or "")[1].lower(), "application/octet-stream")


# ------------------------------------------------------------------ 1 Still
def collection_model(m: dict) -> str:
    """Koleksiyonun secili modeli (gecersizse varsayilana duser)."""
    a = str((m or {}).get("model") or "").strip().lower()
    return a if a in MODELLER else DEFAULT_MODEL


def face_detail_on(m: dict) -> bool:
    """Yuz rotusu acik mi (koleksiyon ayari)."""
    return bool((m or {}).get("face_detail"))


def set_settings(collection: str, kind: str = "", model: str | None = None,
                 face_detail: bool | None = None) -> dict:
    """#353: koleksiyonun uretim ayarlari - model ve yuz rotusu."""
    k = kind_id(kind)
    m = collection_meta(collection, k)
    if model is not None:
        a = str(model).strip().lower()
        if a not in MODELLER:
            raise ValueError("bilinmeyen model: %s (%s)" % (model, ", ".join(MODELLER)))
        m["model"] = a
    if face_detail is not None:
        m["face_detail"] = bool(face_detail)
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "model": collection_model(m),
            "face_detail": face_detail_on(m), "models": list(MODELLER)}


def _still_job(collection: str, kind: str, rank: str, index: int, m: dict) -> dict:
    """Tek rutbenin still isi (image_zimage, mode 'card')."""
    # #347: Pozitif 1 (tema) + Pozitif 3 (sablon eksenleri + manuel metin).
    # Pozitif 2 (guzellik) ve negatif asagida prompt2/negative olarak gider.
    # #348: kart ARKASI kadin degil desen - kendi P2/negatifiyle uretilir.
    arka = is_back(rank)
    tpl = _sablonlar_oku(collection, kind, m, slots_of(kind, m.get("jokers", 0)))
    t = tpl.get(str(rank).upper()) or {}
    if arka:
        # Kart arkasina TEMA GIRMEZ: tema kadini tarif ediyor ("seductive young
        # vampire woman...") ve arkada kadin cikmasina sebep oluyordu. Arka
        # yalniz kendi eksenlerinden (motif/palet/yuzey) + manuel metinden kurulur.
        metin = template_text(t, True)
        olcu = still_size(kind)
        return G.submit(MODELLER[collection_model(m)], metin, prompt2=_back_prompt2(),
                        negative=_back_negative(),
                        width=olcu[0], height=olcu[1],
                        seed=random.randint(1, 2 ** 31), mode="card",
                        client="flow", category=collection)
    p3 = template_text(t)
    if p3:
        metin = look_text(m.get("theme") or "", {"look": p3})
    else:
        # Sablon yoksa eski yol: rutbeye yazilmis gorunus, o da yoksa rotasyon.
        look = (m.get("ranks") or {}).get(str(rank).upper()) or {}
        if not look:
            look = look_for(collection, kind, rank, index)
        metin = look.get("prompt") or look_text(m.get("theme") or "", look)
    olcu = still_size(kind)
    return G.submit(MODELLER[collection_model(m)], metin,
                    prompt2=_prompt2(kind), negative=_negative(kind),
                    width=olcu[0], height=olcu[1],
                    seed=random.randint(1, 2 ** 31), mode="card",
                    client="flow", category=collection)


def _kabul_still(collection: str, kind: str, rank: str, src: str, job_id: str = "") -> str:
    d = rank_dir(collection, rank, kind, create=True)
    _yedekle_still(d)
    p = _to_png(src, os.path.join(d, "still.png"))
    if kind_id(kind) == "dealer":
        _dealer_reframe(p)          # #342: bel ustu kadraja otomatik kirp
    try:
        _still_webp(p, os.path.join(d, "still.webp"), kind)
    except Exception:
        pass
    _set_state(collection, rank, kind,
               still={"at": datetime.now().isoformat(timespec="seconds"), "job": job_id})
    return p


ADAY_KALIP = ("still_%02d.png", "still_green.png", "still_anime.png")


def _aday_yolu(collection: str, rank: str, kind: str, file: str) -> str:
    """Aday dosyasinin tam yolu - rutbe klasorunun DISINA cikilamaz (#336)."""
    ad = os.path.basename((file or "").strip().replace("\\", "/"))
    if not ad.startswith("still_") or not ad.endswith(".png") or ad in ADAY_DISI:
        raise ValueError("aday dosyasi degil: %s" % ad)
    d = rank_dir(collection, rank, kind_id(kind))
    yol = _inside(d, os.path.join(d, ad))
    if not os.path.isfile(yol):
        raise ValueError("aday yok: %s" % ad)
    return yol


# Aday SAYILMAYAN "still_*" dosyalari: bunlar yedek/kaynak, secilecek gorsel degil.
ADAY_DISI = {"still_raw.png", "still_green.png", "still_anime.png"}


def candidates(collection: str, rank: str, kind: str = "") -> list[str]:
    """Rutbenin secilebilir adaylari.

    `still_raw.png` (krupiye kirpimindan onceki ham kare), `still_green.png` ve
    `still_anime.png` YEDEKTIR - aday listesine girmezler, yoksa secici ekranda
    secilemeyen bir kutu olarak gorunurler (#343).
    """
    d = rank_dir(collection, rank, kind_id(kind))
    try:
        return sorted(a for a in os.listdir(d)
                      if a.startswith("still_") and a.endswith(".png")
                      and a not in ADAY_DISI)
    except OSError:
        return []


def pick(collection: str, rank: str, file: str, kind: str = "") -> dict:
    """#336: bir adayi secili still yapar; onceki still aday olarak saklanir.

    Secilen aday dosyasi kopya birakmamak icin silinir - kartta her zaman TEK
    secili gorsel + adaylar durur.
    """
    k = kind_id(kind)
    src = _aday_yolu(collection, rank, k, file)
    d = rank_dir(collection, rank, k, create=True)
    _yedekle_still(d)
    hedef = os.path.join(d, "still.png")
    shutil.copy(src, hedef)
    try:
        _still_webp(hedef, os.path.join(d, "still.webp"), k)
    except Exception:
        pass
    try:
        os.remove(src)
    except OSError:
        pass
    _set_state(collection, rank, k,
               still={"at": datetime.now().isoformat(timespec="seconds"),
                      "job": "", "picked": os.path.basename(src)})
    return {"collection": collection, "rank": str(rank).upper(), "kind": k,
            "still": _rel(hedef), "candidates": candidates(collection, rank, k)}


def delete_candidate(collection: str, rank: str, file: str, kind: str = "") -> dict:
    """#336: bir adayi siler (secili still'e DOKUNMAZ)."""
    k = kind_id(kind)
    os.remove(_aday_yolu(collection, rank, k, file))
    return {"deleted": 1, "candidates": candidates(collection, rank, k)}


def _yuz_rotus(collection: str, kind: str, rank: str, op_id: str, etiket: str) -> bool:
    """#353: kabul edilmis still'in YUZUNU ayri bir gecisle netlestirir.

    Tam boy karede yuz ~100x130 piksele dusuyor; kirp -> 1024'e buyut ->
    edit_qwen (kimlik korur) -> yumusak kenarla geri yapistir. Basarisiz olursa
    still'e DOKUNULMAZ, op defterine not dusulur.

    SIRALAMA: video still'den, sheet de videodan uretildigi icin rotus BURADA
    (still asamasinda) yapilmali - sonra yapilirsa bosa gider.
    """
    try:
        from . import face_detail as FD
    except Exception as e:
        _op(op_id, log="%s: yuz rotusu modulu yok (%s)" % (etiket, str(e)[:80]))
        return False
    d = rank_dir(collection, rank, kind)
    still = os.path.join(d, "still.png")
    if not os.path.isfile(still):
        return False
    kutu = FD.face_box(still)
    if not kutu:
        _op(op_id, log="%s: yuz bulunamadi, rotus atlandi" % etiket)
        return False
    gecici = os.path.join(d, "_face_in.png")
    jid = ""
    try:
        FD.crop_face(still, gecici, kutu)
        job = G.submit(EDIT_TASK, FD.FACE_PROMPT, negative=FD.FACE_NEG,
                       seed=random.randint(1, 2 ** 31), turbo=True, image_path=gecici,
                       mode="free", client="flow", category=collection)
        jid = job["id"]
        out = _await_job(jid, op_id, "yuz %s" % etiket)
        FD.paste_face(still, out, tuple(kutu))
        try:
            _still_webp(still, os.path.join(d, "still.webp"), kind)
        except Exception:
            pass
        _op(op_id, log="%s -> yuz rotusu uygulandi" % etiket)
        return True
    except Exception as e:
        _op(op_id, log="%s: yuz rotusu basarisiz (%s)" % (etiket, str(e)[:120]))
        return False
    finally:
        if jid:
            _is_sil(jid, False)
        for f in (gecici,):
            try:
                os.remove(f)
            except OSError:
                pass


def stills(collection: str, ranks: list[str] | None = None, kind: str = "", n: int = 1) -> str:
    """op `card-still`: secili rutbeler icin yeni still uretir, OTOMATIK kabul eder.

    n>1 verilirse fazlalar aday olarak (still_NN.png) kalir - ilki kabul edilir.
    """
    k = kind_id(kind)
    m = collection_meta(collection, k)
    # #348: BACK yuvasi da uretilebilir - istemci ranks=["BACK"] yollar.
    tum = _collection_ranks(collection, k) or [r.lower() for r in ranks_of(k, m.get("jokers", 0))]
    if ranks:
        istek = {str(r).upper() for r in ranks}
        if istek & set(JOKER_RANKS):
            # Joker yuvasina uretiliyorsa koleksiyon jokerli hale gelir.
            tum = list(tum) + [r for r in JOKER_RANKS if r.upper() in istek
                               and r.lower() not in [x.lower() for x in tum]]
            if int(m.get("jokers") or 0) < 2:
                m["jokers"] = 2
                _save_collection(collection, k, m)
        if any(is_back(r) for r in istek):
            tum = list(tum) + [BACK_RANK]
    hedef = _sec(ranks, tum)
    n = max(1, min(4, int(n or 1)))
    op_id = _op_new("card-still", len(hedef) * n)

    def calis():
        sira = {str(r).lower(): i for i, r in enumerate(tum)}
        isler = []
        for r in hedef:
            for i in range(n):
                etiket = "%s %s" % (collection, str(r).upper())
                try:
                    job = _still_job(collection, k, r, sira.get(str(r).lower(), 0) + i * 7, m)
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
                    continue
                isler.append((job["id"], r, etiket, i == 0))
                _op(op_id, log="%s kuyrukta (%s)" % (etiket, job["id"][:8]))
        _op(op_id, total=len(isler), message="%d still kuyruga girdi" % len(isler))
        for i, (jid, r, etiket, kabul) in enumerate(isler, 1):
            _op(op_id, message="1/4 still  %d/%d  %s" % (i, len(isler), etiket))
            tasindi = False
            try:
                src = _await_job(jid, op_id, etiket)
                if kabul:
                    yol = _kabul_still(collection, k, r, src, jid)
                    # #353: koleksiyon ayari acikken yuz ayri gecisten gecer.
                    # Kart ARKASI desen oldugu icin atlanir.
                    if face_detail_on(m) and not is_back(r):
                        _yuz_rotus(collection, k, r, op_id, etiket)
                else:
                    yol = _to_png(src, _serbest_ad(rank_dir(collection, r, k, create=True),
                                                   "still_%02d.png"))
                tasindi = not os.path.isfile(src)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: %s" % (etiket, str(e)[:200]))
            else:
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i, log="%s -> %s" % (etiket, _rel(yol)))
            _is_sil(jid, tasindi)
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


# --------------------------------------------------- 13 sablon + karistiricilar
# #347: LLM prompt yazari BIRAKILDI - "llm yazinca bozuyor". Yerine jigsaw'daki
# gibi katmanli kurulum:
#   Pozitif 1  koleksiyonun temasi (topluca, tek metin)
#   Pozitif 2  guzellik sablonu (card_options `sablon`, {} ile sarar)
#   Pozitif 3  bu rutbenin SABLONU - karistiricilardan gelen eksenler
#   Manuel     kullanicinin serbest yazdigi ek
#   Negatif    sacma seyleri engelleyen liste
# Her eksen ayri ayri KILITLENEBILIR: kilitli eksen karistirmada degismez.
EKSENLER = ("race", "skin", "hair", "eyes", "outfit_style", "outfit", "outfit_color",
            "pose", "expression")
# Prompt'ta bu sirayla dizilir - kimlik once, kiyafet ortada, poz/ifade sonda.
EKSEN_SIRA = ("race", "skin", "hair", "eyes", "outfit_style", "outfit_color", "outfit",
              "pose", "expression")


def mixers(kind: str = "", back: bool = False) -> dict:
    """Karistiricilarin secenek listeleri (card_options `secenekler`).

    `back=True` ise kart ARKASI profili: motif / palet / yuzey (#348).
    """
    ad = "back" if back else KINDS[kind_id(kind)]["profile"]
    prof = (_options().get(ad) or {})
    sec = prof.get("secenekler") or {}
    eks = BACK_EKSENLER if back else EKSENLER
    return {a: [x for x in (sec.get(a) or []) if isinstance(x, str)] for a in eks}


def _back_prompt2() -> str:
    prof = (_options().get("back") or {})
    return (prof.get("sablon") or "").strip() or         "ornate playing card back design, {}, symmetrical pattern, no people, no text"


def _back_negative() -> str:
    prof = (_options().get("back") or {})
    return (prof.get("negatif") or "").strip() or         "person, face, text, letters, numbers, watermark, blurry, low quality"


def _sablon_uret(kind: str, tohum: int | None = None, back: bool = False) -> dict:
    """Bos bir sablonu karistiricilardan rastgele doldurur."""
    ms = mixers(kind, back)
    rnd = random.Random(tohum) if tohum is not None else random
    eks = BACK_EKSENLER if back else EKSENLER
    return {a: (rnd.choice(ms[a]) if ms.get(a) else "") for a in eks}


def template_text(t: dict, back: bool = False) -> str:
    """Sablondan Pozitif 3 metnini kurar (kilit/manuel alanlari disarida kalir)."""
    parca = []
    for a in (BACK_EKSENLER if back else EKSEN_SIRA):
        v = str((t or {}).get(a) or "").strip()
        if v:
            parca.append(v)
    el = str((t or {}).get("manual") or "").strip()
    if el:
        parca.append(el)
    return ", ".join(parca)


def _sablonlar_oku(collection: str, kind: str, m: dict, ranks: list[str]) -> dict:
    """Koleksiyonun 13 sablonu; eksik olan rutbe RASTGELE doldurulur.

    Tohum koleksiyon+rutbeden turer, yani ayni koleksiyon acildiginda ayni
    dizilim cikar (tekrarlanabilir) - kullanici karistirana kadar sabit kalir.
    """
    ham = m.get("templates")
    if not isinstance(ham, dict):
        ham = {}
    out = {}
    for i, r in enumerate(ranks):
        R = str(r).upper()
        t = ham.get(R)
        if not isinstance(t, dict):
            t = _sablon_uret(kind, _tohum("%s|%s" % (collection, R)) + i, is_back(R))
            t["locked"] = []
            t["manual"] = ""
        t.setdefault("locked", [])
        t.setdefault("manual", "")
        out[R] = t
    return out


def templates(collection: str, kind: str = "") -> dict:
    """#347: koleksiyonun sablonlari + karistirici listeleri (istemci bunu cizer)."""
    k = kind_id(kind)
    m = collection_meta(collection, k)
    # #348: 16 yuva - 13 rutbe + 2 joker + kart arkasi.
    yuvalar = slots_of(k, m.get("jokers", 0))
    tpl = _sablonlar_oku(collection, k, m, yuvalar)
    if m.get("templates") != tpl:                 # ilk acilista diske yazilir
        m["templates"] = tpl
        _save_collection(collection, k, m)
    tema = m.get("theme") or ""
    return {"collection": collection, "kind": k, "theme": tema,
            # #353: uretim ayarlari - istemci bunlari acilir liste + anahtar cizer
            "model": collection_model(m), "models": list(MODELLER),
            "face_detail": face_detail_on(m),
            "slots": yuvalar, "back_rank": BACK_RANK,
            "axes": list(EKSENLER), "labels": dict(EKSEN_ETIKET),
            "back_axes": list(BACK_EKSENLER), "back_labels": dict(BACK_ETIKET),
            "mixers": mixers(k), "back_mixers": mixers(k, True),
            "templates": tpl,
            "preview": {R: (template_text(t, True) if is_back(R)
                            else look_text(tema, {"look": template_text(t)}))
                        for R, t in tpl.items()}}


EKSEN_ETIKET = {"race": "Irk", "skin": "Ten", "hair": "Sac", "eyes": "Goz",
                "outfit_style": "Kiyafet stili", "outfit": "Kiyafet",
                "outfit_color": "Kiyafet rengi", "pose": "Poz", "expression": "Ifade"}


def roll_templates(collection: str, kind: str = "", ranks: list[str] | None = None,
                   axes: list[str] | None = None) -> dict:
    """#347: KILITLI OLMAYAN eksenleri yeniden karistirir.

    `ranks` bos = hepsi, `axes` bos = butun eksenler. Kilitli eksene ve manuel
    metne DOKUNULMAZ.
    """
    k = kind_id(kind)
    m = collection_meta(collection, k)
    tum = slots_of(k, m.get("jokers", 0))
    hedef = {str(r).upper() for r in (_sec(ranks, tum) or tum)}
    tpl = _sablonlar_oku(collection, k, m, tum)
    ms, msb = mixers(k), mixers(k, True)
    for R, t in tpl.items():
        if R not in hedef:
            continue
        arka = is_back(R)
        havuz = msb if arka else ms
        ekseni = [a for a in (axes or (BACK_EKSENLER if arka else EKSENLER))
                  if a in (BACK_EKSENLER if arka else EKSENLER)]
        kilit = set(t.get("locked") or [])
        for a in ekseni:
            if a in kilit or not havuz.get(a):
                continue
            t[a] = random.choice(havuz[a])
    m["templates"] = tpl
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "templates": tpl,
            "rolled": sorted(hedef)}


def set_axis(collection: str, axis: str, value: str, kind: str = "",
             lock: bool = True, ranks: list[str] | None = None) -> dict:
    """#347: BIR ekseni butun rutbelere birden yazar (ve istege bagli kilitler).

    Tema bir ekseni zaten belirliyorsa (ornek: gothic'te ten "porselen beyaz")
    karistiricinin ona rastgele "bronzed skin" atmasi temayla catisir. Bu uc o
    ekseni tek hamlede sabitler - 13 rutbeyi tek tek duzenlemek gerekmez.
    """
    k = kind_id(kind)
    if axis not in EKSENLER and axis not in BACK_EKSENLER:
        raise ValueError("bilinmeyen eksen: %s" % axis)
    m = collection_meta(collection, k)
    tum = slots_of(k, m.get("jokers", 0))
    hedef = {str(r).upper() for r in (_sec(ranks, tum) or tum)}
    tpl = _sablonlar_oku(collection, k, m, tum)
    for R, t in tpl.items():
        if R not in hedef:
            continue
        if is_back(R) != (axis in BACK_EKSENLER):
            continue                  # kart ekseni arkaya, arka ekseni karta yazilmaz
        t[axis] = str(value or "").strip()
        kilit = set(t.get("locked") or [])
        kilit.add(axis) if lock else kilit.discard(axis)
        t["locked"] = sorted(kilit)
    m["templates"] = tpl
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "axis": axis, "value": value,
            "locked": bool(lock), "ranks": sorted(hedef)}


def set_template(collection: str, rank: str, data: dict, kind: str = "") -> dict:
    """#347: tek bir sablonu yazar - eksen degerleri, kilitler ve manuel metin."""
    k = kind_id(kind)
    m = collection_meta(collection, k)
    tum = slots_of(k, m.get("jokers", 0))
    R = str(rank).upper()
    if R not in {str(x).upper() for x in tum}:
        raise ValueError("rutbe yok: %s" % rank)
    tpl = _sablonlar_oku(collection, k, m, tum)
    t = tpl.get(R) or {}
    for a in (BACK_EKSENLER if is_back(R) else EKSENLER):
        if a in (data or {}):
            t[a] = str(data[a] or "").strip()
    if "manual" in (data or {}):
        t["manual"] = str(data["manual"] or "").strip()
    if "locked" in (data or {}):
        gecerli = BACK_EKSENLER if is_back(R) else EKSENLER
        t["locked"] = [a for a in (data["locked"] or []) if a in gecerli]
    tpl[R] = t
    m["templates"] = tpl
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "rank": R, "template": t,
            "preview": (template_text(t, True) if is_back(R)
                        else look_text(m.get("theme") or "", {"look": template_text(t)}))}


def _looks_yaz(collection: str, kind: str, theme: str, ranks: list[str]) -> tuple[dict, str]:
    """Rutbe gorunusleri: once yerel LLM (#337), olmazsa jenerik rotasyon.

    LLM temayi okuyup her rutbeye TEMAYA AIT kiyafet yazar - eskiden gorunus
    jenerik ten/sac/kiyafet listelerinden donuyordu ve tema eziliyordu
    ("Queens and Princesses" -> "tactical crop vest"). Cikti sekli AYNI:
    {look, pose, prompt}, yani alt akista hicbir sey degismez.
    """
    yazan = "rotasyon"
    llm = {}
    try:
        llm = PS.looks(theme, ranks, kind)
    except Exception:
        llm = {}
    out = {}
    for i, r in enumerate(ranks):
        v = llm.get(str(r).upper())
        if v and v.get("look"):
            look = {"look": v["look"], "pose": v.get("pose") or "", "age": v.get("age")}
            yazan = "llm"
        else:
            look = look_for(collection, kind, r, i)
        look["prompt"] = look_text(theme, look)
        out[r] = look
    return out, yazan


def set_theme(collection: str, theme: str, kind: str = "") -> dict:
    """#346: koleksiyonun temasini degistirir - promptlara DOKUNMAZ.

    Tema koleksiyonun kimligidir ve sonradan fikir degisebilir. Yalniz metni
    yazar; yeni temaya gore gorunusleri uretmek icin ayrica rewrite_looks
    calistirilir (istemci "Kaydet" / "Kaydet + promptlari yaz" olarak sunar).
    """
    k = kind_id(kind)
    m = collection_meta(collection, k)
    t = (theme or "").strip()
    if not t:
        raise ValueError("tema bos olamaz")
    m["theme"] = _deanime(t)
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "theme": m["theme"]}


def rewrite_looks(collection: str, kind: str = "", theme: str = "") -> dict:
    """#337: mevcut koleksiyonun rutbe promptlarini yerel LLM'e yeniden yazdirir.

    Still/video/sheet DOSYALARINA DOKUNMAZ - yalnizca collection.json'daki
    gorunus metinleri degisir; sonra "1 Still" ile yeniden uretilir.
    """
    k = kind_id(kind)
    m = collection_meta(collection, k)
    tema = (theme or "").strip() or (m.get("theme") or "")
    if not tema:
        raise ValueError("tema bos")
    ranks = _collection_ranks(collection, k) or list((m.get("ranks") or {}).keys())
    if not ranks:
        raise ValueError("rutbe yok")
    yeni, yazan = _looks_yaz(collection, k, tema, ranks)
    if yazan != "llm":
        raise ValueError("yerel LLM yanit vermedi (Ollama kapali olabilir) - promptlar degismedi")
    m["theme"] = _deanime(tema)
    # _still_job rutbeyi str(rank).upper() ile arar; _collection_ranks() klasor
    # adlarini (kucuk harf) dondurdugu icin anahtarlar BURADA buyutulur - yoksa
    # arama iskalar ve sessizce jenerik rotasyona duserdi.
    m["ranks"] = {str(r).upper(): yeni[r] for r in ranks}
    m["prompts_by"] = "%s (%s)" % (PS.model_adi(), datetime.now().isoformat(timespec="seconds"))
    _save_collection(collection, k, m)
    return {"collection": collection, "kind": k, "ranks": list(ranks),
            "written_by": m["prompts_by"],
            "sample": (yeni.get(ranks[0]) or {}).get("prompt", "")[:300]}


def create(collection_id: str, name: str = "", theme: str = "", jokers: int = 0,
           kind: str = "", style: str = "realistic") -> dict:
    """Yeni koleksiyon: klasor + collection.json + 13 (+2) rutbe icin 1'er still.

    Rutbe basina gorunus rotasyonu (ten/sac/kiyafet/poz) collection.json'a yazilir,
    boylece ↻ Yeniden uret ayni gorunusu tekrar uretir. Onay yok - stiller
    otomatik kabul edilir (asama 1).
    """
    k = kind_id(kind)
    cid = _safe(collection_id, "koleksiyon")
    if k == "dealer":
        raise ValueError("krupiye koleksiyonu tektir - yeni krupiye icin dealer_create kullan")
    d = col_dir(cid, k)
    if os.path.isfile(os.path.join(d, "collection.json")):
        raise ValueError("koleksiyon zaten var: %s" % cid)
    theme = (theme or "").strip()
    if not theme:
        raise ValueError("tema bos - koleksiyonun konusu yazilmali")
    j = 2 if int(jokers or 0) >= 2 else 0
    ranks = ranks_of(k, j)
    # #325 "anime olmasin hic": Kart Modu'nda tek stil var, gelen deger yok sayilir.
    if (style or "").strip().lower() not in ("", "realistic"):
        style = "realistic"
    m = {"id": cid, "name": (name or cid).strip(), "theme": _deanime(theme),
         "style": "realistic", "kind": k,
         "jokers": j, "created": datetime.now().isoformat(timespec="seconds"),
         "ranks": {}}
    yeni, yazan = _looks_yaz(cid, k, theme, ranks)
    m["ranks"] = {str(r).upper(): yeni[r] for r in ranks}
    if yazan == "llm":
        m["prompts_by"] = "%s (%s)" % (PS.model_adi(),
                                       datetime.now().isoformat(timespec="seconds"))
    _save_collection(cid, k, m)
    for r in ranks:
        os.makedirs(rank_dir(cid, r, k), exist_ok=True)
    return {"collection": cid, "kind": k, "ranks": ranks,
            "op": stills(cid, ranks, k, 1)}


def dealer_create(dealer_id: str, name: str = "", theme: str = "",
                  gesture: str = DEFAULT_GESTURE, outfit: str = "") -> dict:
    """Yeni krupiye: `_Dealers/<ad>/` TEK OGELI koleksiyon (rutbe listesi ["main"]).

    Uretim krupiyeye ozeldir: bel ustu kadraj, kumarhane masasi, krupiye
    kiyafeti (card_options.json `dealer` profili).
    """
    ad = _safe(dealer_id or name, "krupiye").lower()
    d = col_dir(ad, "dealer", create=True)
    if os.path.isfile(os.path.join(d, "collection.json")):
        raise ValueError("krupiye zaten var: %s" % ad)
    theme = (theme or "elegant casino dealer at the blackjack table").strip()
    # #337: gorunusu yerel LLM yazar (temaya sadik, yas 20-26, acik kiyafet);
    # LLM yoksa eski jenerik rotasyona duser.
    yeni_look, yazan = _looks_yaz(ad, "dealer", theme, [MAIN])
    look = yeni_look.get(MAIN) or yeni_look.get(MAIN.upper()) or {}
    if not look:
        look = look_for(ad, "dealer", MAIN, _tohum(ad) % 6)
        look["prompt"] = look_text(theme, look)
    if (outfit or "").strip():
        look["outfit"] = outfit.strip()
        look["prompt"] = look_text(theme, look)
    look["gesture"] = gesture or DEFAULT_GESTURE
    m = {"id": ad, "name": (name or ad).strip(), "kind": "dealer", "style": "realistic",
         "theme": theme, "gesture": gesture or DEFAULT_GESTURE, "jokers": 0,
         "created": datetime.now().isoformat(timespec="seconds"),
         "ranks": {MAIN.upper(): look}}
    _save_collection(ad, "dealer", m)
    return {"collection": ad, "kind": "dealer", "dealer": ad, "ranks": [MAIN],
            "op": stills(ad, [MAIN], "dealer", 1)}


def stage(collection: str, rank: str = "", job_id: str = "", kind: str = "",
          file: str = "") -> dict:
    """Uretilenler'den bir isi kartin still'i yapar (rutbe verilmezse Gelen'e duser)."""
    src = file.strip() if file else (G.job_file(job_id) if job_id else "")
    if not src or not os.path.isfile(src):
        raise ValueError("kaynak is bulunamadi veya ciktisi yok")
    if os.path.splitext(src)[1].lower() in VIDEO_EXT:
        raise ValueError("kaynak bir video - still gerekiyor")
    if not rank:
        d = os.path.join(root(), INCOMING)
        os.makedirs(d, exist_ok=True)
        dest = os.path.join(d, os.path.basename(src))
        shutil.copy(src, dest)
        return {"staged": _rel(dest), "collection": "", "rank": ""}
    k = kind_id(kind)
    collection_meta(collection, k)                     # koleksiyon var mi
    d = rank_dir(collection, rank, k, create=True)
    _yedekle_still(d)
    from PIL import Image
    with Image.open(src) as f:
        f.convert("RGB").save(os.path.join(d, "still.png"), "PNG")
    try:
        _still_webp(os.path.join(d, "still.png"), os.path.join(d, "still.webp"), k)
    except Exception:
        pass
    _set_state(collection, rank, k,
               still={"at": datetime.now().isoformat(timespec="seconds"), "job": job_id or ""})
    return {"collection": collection, "kind": k, "rank": str(rank).upper(),
            "still": _rel(os.path.join(d, "still.png"))}


def edit(collection: str, rank: str, prompt: str, kind: str = "") -> str:
    """op `card-edit`: kabul edilmis still'i kisa bir cumleyle duzeltir (edit_qwen).

    Sonuc OTOMATIK kabul edilir; eski still aday olarak saklanir (geri alinabilir).
    """
    k = kind_id(kind)
    prompt = (prompt or "").strip()
    if not prompt:
        raise ValueError("duzeltme cumlesi bos")
    d = rank_dir(collection, rank, k)
    src = os.path.join(d, "still.png")
    if not os.path.isfile(src):
        raise ValueError("bu rutbenin still'i yok - once uret")
    keep = ("Keep the exact same woman, the same face, the same outfit, the same pose, "
            "the same framing and the same plain light gray background.")
    op_id = _op_new("card-edit", 1)

    def calis():
        _op(op_id, message="duzenle: %s %s" % (collection, str(rank).upper()))
        jid, tasindi = "", False
        try:
            job = G.submit(EDIT_TASK, "%s %s" % (prompt, keep), negative=_negative(k),
                           seed=random.randint(1, 2 ** 31), turbo=True, image_path=src,
                           mode="free", client="flow", category=collection)
            jid = job["id"]
            out = _await_job(jid, op_id, "duzenle %s" % str(rank).upper())
            _kabul_still(collection, k, rank, out, jid)
            tasindi = not os.path.isfile(out)
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log="duzenle: %s" % str(e)[:220])
            if jid:
                _is_sil(jid, tasindi)
            raise
        if jid:
            _is_sil(jid, tasindi)
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = {"collection": collection, "rank": str(rank).upper(),
                                     "still": _rel(os.path.join(d, "still.png"))}
        _op(op_id, done=1, message="bitti", log="%s -> still.png" % str(rank).upper())

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ 2 Video
def _first_frame(video: str, dest: str) -> bool:
    ff = G._ffmpeg()
    if not ff:
        return False
    try:
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", video, "-frames:v", "1", dest],
                       check=True, timeout=300,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        return os.path.isfile(dest)
    except Exception:
        return False


def _last_frame(video: str, dest: str) -> bool:
    """Klibin SON karesi (-sseof): zoom kaymasi ancak burada gorulur."""
    ff = G._ffmpeg()
    if not ff:
        return False
    try:
        subprocess.run([ff, "-y", "-loglevel", "error", "-sseof", "-0.2", "-i", video,
                        "-frames:v", "1", dest], check=True, timeout=300,
                       creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        return os.path.isfile(dest)
    except Exception:
        return False


def _figure_box(p: str) -> tuple[int, int] | None:
    """Karedeki figurun (fon disi piksellerin) genislik/yuksekligi.

    Fon duz acik gri ya da beyaz oldugu icin "fon disi" esikle bulunur; kutunun
    buyumesi = kameranin yaklasmasi.
    """
    from PIL import Image
    try:
        with Image.open(p) as f:
            im = f.convert("L").resize((208, 312), Image.BILINEAR)
    except Exception:
        return None
    px = im.load()
    xs, ys = [], []
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            if px[x, y] < 225:
                xs.append(x)
                ys.append(y)
    if len(xs) < 50:
        return None
    return (max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


def _probe_pixels(p: str, w: int = 64, h: int = 96):
    """guard_firstframe.py ile ayni olcum: 2:3 orta kirpim -> 64x96 RGB."""
    from PIL import Image
    with Image.open(p) as f:
        im = f.convert("RGB")
    iw, ih = im.size
    if iw * 3 > ih * 2:
        cw, ch = int(ih * 2 / 3), ih
    else:
        cw, ch = iw, int(iw * 3 / 2)
    l, t = (iw - cw) // 2, (ih - ch) // 2
    return im.crop((l, t, l + cw, t + ch)).resize((w, h), Image.BILINEAR)


def guard_video(still: str, video: str) -> dict:
    """Ilk kare - still farki (yanlis kadin / reframe / zoom kaymasi).

    score < 25 -> uyumlu; >= 25 -> "kontrol" rozeti (otomatik silme YOK, kullanici bakar).
    """
    out = {"score": None, "verdict": "ok", "note": ""}
    if not (still and os.path.isfile(still) and video and os.path.isfile(video)):
        out.update(verdict="kontrol", note="karsilastirma dosyasi yok")
        return out
    tmp = os.path.join(os.path.dirname(video), "_guard_f0.png")
    try:
        if not _first_frame(video, tmp):
            out.update(verdict="kontrol", note="ilk kare cikarilamadi")
            return out
        a, b = _probe_pixels(still), _probe_pixels(tmp)
        pa, pb = a.load(), b.load()
        toplam = 0
        for y in range(a.size[1]):
            for x in range(a.size[0]):
                ra, ga, ba = pa[x, y]
                rb, gb, bb = pb[x, y]
                toplam += abs(ra - rb) + abs(ga - gb) + abs(ba - bb)
        skor = toplam / float(a.size[0] * a.size[1] * 3)
        out["score"] = round(skor, 2)
        if skor >= GUARD_THRESHOLD:
            out.update(verdict="kontrol", note="ilk kare still'den uzak (%.1f)" % skor)
        # Kademeli zoom (push-in) ilk karede GORUNMEZ - ilk kare still'in aynisidir.
        # Figurun kutusu klip boyunca buyuyorsa kamera yaklasmistir (#337).
        z = _zoom_drift(video, tmp)
        if z is not None:
            out["zoom"] = z
            if z >= ZOOM_TOLERANCE:
                out.update(verdict="kontrol",
                           note=(out["note"] + "; " if out["note"] else "")
                           + "kamera yaklasmis (olcek +%%%.0f)" % (z * 100))
    except Exception as e:
        out.update(verdict="kontrol", note=str(e)[:150])
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
    return out


def _zoom_drift(video: str, first_png: str) -> float | None:
    """Ilk kare -> son kare figur olcegi degisimi (0.51 = %51 buyume).

    None = olculemedi (ffmpeg yok, kare cikmadi, figur bulunamadi).
    """
    son = os.path.join(os.path.dirname(video), "_guard_son.png")
    try:
        if not _last_frame(video, son):
            return None
        a, b = _figure_box(first_png), _figure_box(son)
        if not a or not b:
            return None
        # En/boy ayri ayri: kol acmak eni buyutur, gercek zoom IKISINI birden.
        return round(min(b[0] / a[0], b[1] / a[1]) - 1.0, 3)
    except Exception:
        return None
    finally:
        try:
            os.remove(son)
        except OSError:
            pass


def _video_job(collection: str, kind: str, rank: str, gesture: str) -> dict:
    """Tek rutbenin i2v isi (video_ltx, 6 sn, 832x1248, kilitli kamera)."""
    d = rank_dir(collection, rank, kind)
    still = os.path.join(d, "still.png")
    if not os.path.isfile(still):
        raise ValueError("still yok")
    jest = gesture_text(kind, gesture)
    # Olcu ACIKCA verilir: comfy_gen'in video_size_for butcesi (704x1280) 832x1248'i
    # kucultur; iki kenar da 32'nin kati oldugu icin LTX bu olcuyu dogrudan alir.
    gorev = VIDEO_TASK_LOOP if G._task(VIDEO_TASK_LOOP) else VIDEO_TASK
    # image_path TEK basina verilir: comfy_gen is akisindaki BUTUN gorsel
    # yuvalarini onunla doldurur, yani FLF2V'de ilk ve son kare ayni still olur.
    olcu = still_size(kind)
    return G.submit(gorev, jest, prompt2=_motion2(kind), negative=_negative(kind),
                    width=olcu[0], height=olcu[1], duration=SECONDS,
                    seed=random.randint(1, 2 ** 31), image_path=still, mode="card",
                    client="flow", category=collection)


def animate(collection: str, ranks: list[str] | None = None, gesture: str = DEFAULT_GESTURE,
            kind: str = "", anim: str = "") -> str:
    """op `card-video` (asama 2): still -> LTX-2.5 i2v 6 sn, guard, otomatik kabul.

    `anim` bos/idle ise cikti rutbe klasorunun kokune (eski davranis), aksi halde
    <rutbe>/anim/<ad>/ altina yazilir (#338).
    """
    k = kind_id(kind)
    collection_meta(collection, k)
    tum = _collection_ranks(collection, k)
    hedef = [r for r in _sec(ranks, tum)
             if os.path.isfile(os.path.join(rank_dir(collection, r, k), "still.png"))]
    if not hedef:
        raise ValueError("still'i olan rutbe yok - once asama 1")
    a = anim_id(anim)
    op_id = _op_new("card-video", len(hedef))
    _run(op_id, lambda: _animate_body(op_id, collection, k, hedef, gesture, "2/4 video", a))
    return op_id


def _animate_body(op_id: str, collection: str, kind: str, hedef: list[str],
                  gesture: str, etiket_on: str, anim: str = IDLE_ANIM) -> list[str]:
    """Butun i2v isleri TEK SEFERDE kuyruga birakir, ciktilari sirayla toplar.

    gpu_lane BURADA ALINMAZ - comfy_gen dispatcher'i her isi kendi bileti ile
    calistirir; serit burada tutulursa kilitlenir (#299).
    """
    isler = []
    for r in hedef:
        etiket = "%s %s" % (collection, str(r).upper())
        try:
            job = _video_job(collection, kind, r, gesture)
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
            continue
        isler.append((job["id"], r, etiket))
        _op(op_id, log="%s i2v kuyrukta (%s)" % (etiket, job["id"][:8]))
    _op(op_id, message="%s  %d is kuyruga girdi" % (etiket_on, len(isler)))
    olanlar = []
    for i, (jid, r, etiket) in enumerate(isler, 1):
        _op(op_id, message="%s %d/%d  %s" % (etiket_on, i, len(isler), etiket))
        tasindi = False
        try:
            src = _await_job(jid, op_id, etiket)
            d = rank_dir(collection, r, kind, create=True)
            ad = anim_dir(collection, r, kind, anim, create=True)
            dest = _tasi(src, os.path.join(ad, "video.mp4"))
            tasindi = not os.path.isfile(src)
            # Guard her zaman rutbenin still'ine bakar - animasyon adi ne olursa
            # olsun kadraj o still'den baslar.
            g = guard_video(os.path.join(d, "still.png"), dest)
            bilgi = {"at": datetime.now().isoformat(timespec="seconds"),
                     "job": jid, "gesture": gesture, "guard": g, "anim": anim}
            if anim == IDLE_ANIM:
                _set_state(collection, r, kind, video=bilgi)
            else:
                _write_json(os.path.join(ad, "state.json"), bilgi)
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=i, log="%s: %s" % (etiket, str(e)[:200]))
        else:
            olanlar.append(r)
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s -> video.mp4 (guard %s %s)"
                % (etiket, g.get("verdict"), g.get("score")))
        _is_sil(jid, tasindi)
    return olanlar


# ------------------------------------------------------------------ 3 WebP
def _cut_tool():
    """tools/cardpipe_local/cut.py'yi DOSYA YOLUNDAN yukler (gorev #322).

    Duz import kullanmiyoruz: `cut` cok yaygin bir ad, ayrica paketin
    __init__.py'si olmayabilir.
    """
    yol = os.path.join(_TOOLS, "cardpipe_local", "cut.py")
    if not os.path.isfile(yol):
        raise ValueError("kesim araci yok (gorev #322): %s" % yol)
    import importlib.util
    if _TOOLS not in sys.path:
        sys.path.insert(0, _TOOLS)
    spec = importlib.util.spec_from_file_location("cardpipe_local_cut", yol)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["cardpipe_local_cut"] = mod
    spec.loader.exec_module(mod)
    return mod


def frame_size(kind: str, v3: bool) -> tuple[int, int]:
    """Sheet kare olcusu: kart hep v3; krupiye v1 (320x480) - `dealers_v3` ile YATAY 768x512."""
    if kind_id(kind) == "dealer":
        return DEALER_FRAME_V3 if v3 else DEALER_FRAME_V1
    return FRAME_V3


def thumb_size(kind: str) -> tuple[int, int]:
    """Statik kucuk resim olcusu - krupiye yatay (#340)."""
    return DEALER_THUMB_V3 if kind_id(kind) == "dealer" else THUMB_V3


def still_size(kind: str) -> tuple[int, int]:
    """Still + i2v master olcusu - krupiye yatay (#340)."""
    return DEALER_STILL if kind_id(kind) == "dealer" else STILL_SIZE


def _cut_call(tool, video: str, out_dir: str, mode: str, concept: str,
              frame: tuple, thumb_size: tuple, still: str = "", kind: str = "card") -> dict:
    """#322 arayuzu: cut_video(video, out_dir, mode, concept, fps, seconds, still,
    frame, grid, thumb_size, still_size, quality) -> {frames_dir, sheet, thumb,
    still, metrics}.

    `still` bir DOSYA YOLUDUR (olcu degil): hem ilk kare guard'inin referansi hem
    de hi-res still.webp'in kaynagi odur. Arac bir parametreyi tanimiyorsa sessizce
    atlanir - #322 ile paralel gelistirildigi icin imza kontrol edilir.
    """
    import inspect
    kw = {"mode": mode, "concept": concept, "fps": FPS, "seconds": SECONDS,
          "still": still or None, "frame": tuple(frame), "grid": (COLS, ROWS),
          "thumb_size": tuple(thumb_size), "still_size": tuple(still_size(kind)),
          "quality": SHEET_QUALITY}
    try:
        sig = inspect.signature(tool.cut_video)
        if not any(x.kind == x.VAR_KEYWORD for x in sig.parameters.values()):
            kw = {a: b for a, b in kw.items() if a in sig.parameters}
    except (TypeError, ValueError):
        pass
    res = tool.cut_video(video, out_dir, **kw)
    return res if isinstance(res, dict) else {}


def _cut_one(tool, collection: str, kind: str, rank: str, mode: str, v3: bool,
             anim: str = IDLE_ANIM) -> dict:
    """Tek kartin kesimi + paketi. gpu_lane cagiran tarafta TUTULUR.

    `anim` idle disinda ise video/sheet/thumb <rutbe>/anim/<ad>/ altindadir (#338);
    still ve hi-res still HER ZAMAN rutbenin kokundedir (kart tek gorsele sahiptir).
    """
    kok = rank_dir(collection, rank, kind, create=True)
    d = anim_dir(collection, rank, kind, anim, create=True)
    video = os.path.join(d, "video.mp4")
    if mode == "hybrid" or not os.path.isfile(video):
        grok = os.path.join(d, "video_grok.mp4")
        if os.path.isfile(grok):
            video = grok
    if not os.path.isfile(video):
        raise ValueError("video yok")
    frame = frame_size(kind, v3)
    still = os.path.join(kok, "still.png")
    res = _cut_call(tool, video, d, mode, KINDS[kind_id(kind)]["concept"], frame,
                    thumb_size(kind), still if os.path.isfile(still) else "", kind)

    sheet = res.get("sheet") or os.path.join(d, "sheet.webp")
    th = res.get("thumb") or os.path.join(d, "thumb.webp")
    if os.path.isfile(sheet) and os.path.abspath(sheet) != os.path.abspath(os.path.join(d, "sheet.webp")):
        sheet = _tasi(sheet, os.path.join(d, "sheet.webp"))
    if os.path.isfile(th) and os.path.abspath(th) != os.path.abspath(os.path.join(d, "thumb.webp")):
        th = _tasi(th, os.path.join(d, "thumb.webp"))
    if not os.path.isfile(sheet):
        raise ValueError("kesim sheet uretmedi")
    # hi-res still: arac uretmediyse still.png'den kurulur
    hs = res.get("still") or os.path.join(kok, "still.webp")
    if not os.path.isfile(hs) and os.path.isfile(os.path.join(kok, "still.png")):
        try:
            hs = _still_webp(os.path.join(kok, "still.png"),
                             os.path.join(kok, "still.webp"), kind)
        except Exception:
            hs = ""

    # Guard sonucu #322'nin `metrics.verdict` sozlugunden gelir:
    # {"pass": bool, "reasons": [...]}. Eski/sade bir arac duz metin dondururse
    # o da anlasilir. FAIL = kart "kontrol" rozeti alir, DOSYA SILINMEZ.
    metrics = res.get("metrics") or {}
    v = metrics.get("verdict")
    if isinstance(v, dict):
        kotu, nedenler = (not v.get("pass", True)), list(v.get("reasons") or [])
    else:
        kotu = bool(metrics.get("fail")) or str(v or "").lower() in ("fail", "kontrol")
        nedenler = []
    pack = metrics.get("sheet") if isinstance(metrics.get("sheet"), dict) else {}
    frames = int(pack.get("frames") or metrics.get("frames") or FRAMES)
    rows = int(pack.get("rows") or math.ceil(frames / float(COLS)))
    kayit = {"at": datetime.now().isoformat(timespec="seconds"), "mode": mode,
             "frames": frames, "fps": int(pack.get("fps") or FPS),
             "cols": int(pack.get("cols") or COLS), "rows": rows,
             "frameW": int(pack.get("frameW") or frame[0]),
             "frameH": int(pack.get("frameH") or frame[1]),
             "thumbW": int(pack.get("thumbW") or thumb_size(kind)[0]),
             "thumbH": int(pack.get("thumbH") or thumb_size(kind)[1]),
             "stillW": int(pack.get("stillW") or still_size(kind)[0]),
             "stillH": int(pack.get("stillH") or still_size(kind)[1]),
             "v3": bool(v3 or kind_id(kind) == "card"),
             "bytes": os.path.getsize(sheet),
             "verdict": "kontrol" if kotu else "ok", "reasons": nedenler,
             "metrics": metrics,
             "frames_dir": _rel(res.get("frames_dir") or os.path.join(d, "cut")),
             "sheet": _rel(sheet), "thumb": _rel(th) if th else "",
             "still": _rel(hs) if hs else "", "anim": anim}
    if anim == IDLE_ANIM:
        _set_state(collection, rank, kind, sheet=kayit)
    else:
        y = _read_json(os.path.join(d, "state.json"), {}) or {}
        y["sheet"] = kayit
        _write_json(os.path.join(d, "state.json"), y)
    return kayit


def cut(collection: str, ranks: list[str] | None = None, mode: str = "sam",
        kind: str = "", dealers_v3: bool = False, anim: str = "") -> str:
    """op `card-cut` (asama 3): SAM3 kesim + 12x6 sheet + thumb + hi-res still.

    Butun parti TEK gpu_lane bileti altinda calisir (#299): SAM3 modeli bir kez
    yuklenir, arada baska GPU isi giremez.
    """
    k = kind_id(kind)
    collection_meta(collection, k)
    mode = (mode or "sam").strip().lower()
    if mode not in ("sam", "hybrid"):
        raise ValueError("bilinmeyen kesim kipi: %s" % mode)
    tum = _collection_ranks(collection, k)
    a = anim_id(anim)
    hedef = [r for r in _sec(ranks, tum)
             if os.path.isfile(os.path.join(anim_dir(collection, r, k, a), "video.mp4"))
             or (a == IDLE_ANIM
                 and os.path.isfile(os.path.join(rank_dir(collection, r, k), "video_grok.mp4")))]
    if not hedef:
        raise ValueError("videosu olan rutbe yok - once asama 2")
    op_id = _op_new("card-cut", len(hedef))
    _run(op_id, lambda: _cut_body(op_id, collection, k, hedef, mode, dealers_v3, "3/4 webp", a))
    return op_id


def _cut_body(op_id: str, collection: str, kind: str, hedef: list[str], mode: str,
              dealers_v3: bool, etiket_on: str, anim: str = IDLE_ANIM) -> None:
    tool = _cut_tool()
    with gpu_lane.hold("kart kesim %s (%d)" % (collection, len(hedef)), kind="card",
                       op_id=op_id, total=len(hedef)):                      # #299
        for i, r in enumerate(hedef, 1):
            etiket = "%s %s" % (collection, str(r).upper())
            _op(op_id, message="%s %d/%d  %s" % (etiket_on, i, len(hedef), etiket))
            try:
                kayit = _cut_one(tool, collection, kind, r, mode, dealers_v3, anim)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: %s" % (etiket, str(e)[:220]))
                continue
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s -> sheet %dx%d %d kare (%s%s)"
                % (etiket, kayit["frameW"], kayit["frameH"], kayit["frames"],
                   kayit["verdict"],
                   (": " + "; ".join(kayit["reasons"])[:160]) if kayit["reasons"] else ""))


# --------------------------------------------------- #325 restill: fonu griye al
def _restill_one(tool, collection: str, kind: str, rank: str, force: bool = False) -> dict:
    """Tek kartin still'ini duz acik gri fona tasir. gpu_lane cagiran tarafta TUTULUR.

    Yedek `still_green.png` BIR KEZ yazilir - ikinci kosuda ustune yazilmaz, yani
    ilk (yesil) hal her zaman geri alinabilir. Basarisiz kesimde still'e HIC
    dokunulmaz; cagiran taraf o rutbeyi "elle duzelt" listesine koyar.
    """
    d = rank_dir(collection, rank, kind, create=True)
    still = os.path.join(d, "still.png")
    if not os.path.isfile(still):
        raise ValueError("still yok")
    on = tool.still_bg(still)                       # GPU'suz on bakis
    if not on.get("chromatic") and not force:
        return {"skipped": True, "reason": "fon zaten gri (bg_chroma %.3f)"
                % float(on.get("bg_chroma") or 0.0), "bg_chroma": on.get("bg_chroma")}

    gecici = os.path.join(d, "still_gray.png")
    res = tool.restill(still, gecici, bg=RESTILL_BG, mode="auto",
                       concept=KINDS[kind_id(kind)]["concept"])
    v = res.get("verdict") or {}
    if not res.get("ok") or not v.get("pass", True):
        try:
            os.remove(gecici)
        except OSError:
            pass
        return {"failed": True, "reasons": list(v.get("reasons") or ["restill uretmedi"]),
                "coverage": res.get("coverage"), "metrics": res}

    yedek = os.path.join(d, "still_green.png")
    if not os.path.isfile(yedek):                   # YEDEGIN USTUNE ASLA YAZILMAZ
        shutil.copy(still, yedek)
    os.replace(gecici, still)
    try:
        _still_webp(still, os.path.join(d, "still.webp"), kind)
    except Exception:
        pass
    kayit = {"at": datetime.now().isoformat(timespec="seconds"), "mode": res.get("mode"),
             "bg_in": res.get("bg_in"), "bg_chroma_in": res.get("bg_chroma_in"),
             "bg_out": res.get("bg_out"), "coverage": res.get("coverage"),
             "green": res.get("green"), "spill": res.get("spill"),
             "backup": _rel(yedek)}
    _set_state(collection, rank, kind, restill=kayit)
    kayit.update({"ok": True, "rev": _rev(d)})
    return kayit


def _restill_body(op_id: str, collection: str, kind: str, hedef: list[str],
                  force: bool, etiket_on: str, taban: int = 0) -> dict:
    """Bir koleksiyonun rutbeleri TEK gpu_lane bileti altinda (kesimle ayni kural).

    `taban` cok koleksiyonlu op'ta ilerleme sayaci geri sarmasin diye onceki
    koleksiyonlarin rutbe sayisidir."""
    tool = _cut_tool()
    sonuc = {"ok": [], "skipped": [], "failed": []}
    with gpu_lane.hold("kart restill %s (%d)" % (collection, len(hedef)), kind="card",
                       op_id=op_id, total=len(hedef)):                      # #299
        for i, r in enumerate(hedef, 1):
            etiket = "%s %s" % (collection, str(r).upper())
            _op(op_id, message="%s %d/%d  %s" % (etiket_on, i, len(hedef), etiket))
            try:
                k = _restill_one(tool, collection, kind, r, force)
            except Exception as e:
                sonuc["failed"].append(etiket)
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=taban + i, log="%s: %s" % (etiket, str(e)[:220]))
                continue
            if k.get("skipped"):
                sonuc["skipped"].append(etiket)
                _op(op_id, done=taban + i, log="%s atlandi: %s" % (etiket, k.get("reason")))
            elif k.get("failed"):
                sonuc["failed"].append(etiket)
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=taban + i, log="%s ELLE DUZELT (still'e dokunulmadi): %s"
                    % (etiket, "; ".join(k.get("reasons") or [])[:200]))
            else:
                sonuc["ok"].append(etiket)
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=taban + i, log="%s -> gri fon (%s kip, kapsama %.1f%%, yedek %s)"
                    % (etiket, k.get("mode"), float(k.get("coverage") or 0) * 100,
                       os.path.basename(k.get("backup") or "")))
    return sonuc


def restill(collection: str = "all", kind: str = "", include_dealers: bool = False,
            force: bool = False, ranks: list[str] | None = None) -> str:
    """op `card-restill`: eski YESIL fonlu still'leri duz acik gri studyo fonuna cevirir.

    Neden (tasarim §3/§4): yeni hat still'i duz gri fonda uretiyor, kesim de ona
    gore. Eski Grok still'leri yesil oldugu icin LTX yeniden canlandirma yesil
    fonlu video uretiyordu. Fonu ONCEDEN griye alirsak hem i2v hem SAM3 kendi
    girdisini gorur; kadin pikselleri degismez.

    Zaten gri olan rutbeler (bg_chroma <= 0.06) `force` verilmedikce ATLANIR.
    SAM kapsamasi %5'in altinda kalan ya da verdict'i geceni rutbenin still'ine
    DOKUNULMAZ (Qwen otomatik cagrilmaz) - op mesajinda elle duzeltilecekler listelenir.
    """
    hedef = _targets(collection, kind, include_dealers)
    if ranks:
        istek = {str(r).lower() for r in ranks}
        hedef = [t for t in hedef if str(t[2]).lower() in istek]
    hedef = [(c, k, r) for c, k, r in hedef
             if os.path.isfile(os.path.join(rank_dir(c, r, k), "still.png"))]
    if not hedef:
        raise ValueError("still'i olan rutbe yok")
    op_id = _op_new("card-restill", len(hedef))

    def calis():
        gruplar: dict[tuple[str, str], list[str]] = {}
        for c, k, r in hedef:
            gruplar.setdefault((c, k), []).append(r)
        toplam = {"ok": [], "skipped": [], "failed": []}
        taban = 0
        for (c, k), rs in gruplar.items():
            s = _restill_body(op_id, c, k, rs, force, "gri fon %s" % c, taban)
            taban += len(rs)
            for a in toplam:
                toplam[a].extend(s[a])
        with _ops_lock:
            _ops[op_id]["result"] = toplam
        mesaj = "bitti: %d gri, %d atlandi" % (len(toplam["ok"]), len(toplam["skipped"]))
        if toplam["failed"]:
            mesaj += " - ELLE DUZELT: " + ", ".join(toplam["failed"])
        _op(op_id, message=mesaj)

    _run(op_id, calis)
    return op_id


# ------------------------------------------- #325 realify: anime -> gercekci kadin
REALIFY_PROMPT = (
    "Convert this anime illustration into a photorealistic photograph of the exact same "
    "young adult woman: same face structure, same hair colour and style, same outfit, "
    "colours and accessories, same pose and framing, same plain background. Ultra "
    "realistic glamour photography, natural skin texture, 85mm lens, sharp focus.")
REALIFY_NEG = ("anime, cartoon, illustration, cel shading, lineart, deformed, extra limbs, "
               "text, watermark, child")
_ANIME_RE = re.compile(r"\b(anime|manga|cel[- ]shaded|cartoon)\b\s*", re.IGNORECASE)


def _deanime(metin: str) -> str:
    """Metinden anime/manga sozcuklerini atar (kullanici: "anime olmasin hic").

    Koleksiyonun KIMLIGI ve ADI ASLA degismez - yalniz uretim metinleri temizlenir,
    yoksa "↻ Yeniden uret" yine anime bir still uretirdi.
    """
    out = _ANIME_RE.sub("", metin or "")
    return re.sub(r"\s{2,}", " ", out).strip(" ,")


def _realify_body(op_id: str, collection: str, kind: str, hedef: list[str],
                  etiket_on: str) -> list[str]:
    """Butun edit_qwen isleri TEK SEFERDE kuyruga, ciktilar sirayla toplanir.

    gpu_lane BURADA ALINMAZ - comfy_gen dispatcher'i her isi kendi bileti ile
    calistirir (#299, _animate_body ile ayni kural).
    """
    isler = []
    for r in hedef:
        etiket = "%s %s" % (collection, str(r).upper())
        src = os.path.join(rank_dir(collection, r, kind), "still.png")
        if not os.path.isfile(src):
            _op(op_id, log="%s: still yok, atlandi" % etiket)
            continue
        try:
            job = G.submit(EDIT_TASK, REALIFY_PROMPT, negative=REALIFY_NEG,
                           seed=random.randint(1, 2 ** 31), turbo=True, image_path=src,
                           mode="free", client="flow", category=collection)
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
            continue
        isler.append((job["id"], r, etiket))
        _op(op_id, log="%s gercekci kuyrukta (%s)" % (etiket, job["id"][:8]))
    _op(op_id, message="%s  %d is kuyruga girdi" % (etiket_on, len(isler)))

    olanlar = []
    for i, (jid, r, etiket) in enumerate(isler, 1):
        _op(op_id, message="%s %d/%d  %s" % (etiket_on, i, len(isler), etiket))
        tasindi = False
        try:
            out = _await_job(jid, op_id, etiket)
            d = rank_dir(collection, r, kind, create=True)
            still = os.path.join(d, "still.png")
            yedek = os.path.join(d, "still_anime.png")
            if os.path.isfile(still) and not os.path.isfile(yedek):
                shutil.copy(still, yedek)          # YEDEGIN USTUNE ASLA YAZILMAZ
            _to_png(out, still)
            tasindi = not os.path.isfile(out)
            try:
                _still_webp(still, os.path.join(d, "still.webp"), kind)
            except Exception:
                pass
            _set_state(collection, r, kind,
                       realify={"at": datetime.now().isoformat(timespec="seconds"),
                                "job": jid, "backup": _rel(yedek)})
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=i, log="%s: %s" % (etiket, str(e)[:200]))
        else:
            olanlar.append(r)
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s -> gercekci still (yedek still_anime.png)" % etiket)
        _is_sil(jid, tasindi)
    return olanlar


def _mark_realistic(collection: str, kind: str) -> dict:
    """collection.json: style -> "realistic", tema/prompt metinlerinden anime cikar.

    id ve name AYNEN KALIR (kullanici: "Neon Nurse" adi degismesin).
    """
    m = collection_meta(collection, kind)
    m["style"] = "realistic"
    if m.get("theme"):
        m["theme"] = _deanime(m["theme"])
    for r, look in (m.get("ranks") or {}).items():
        if isinstance(look, dict) and look.get("prompt"):
            look["prompt"] = _deanime(look["prompt"])
    m["realified"] = datetime.now().isoformat(timespec="seconds")
    return _save_collection(collection, kind, m)


def realify(collection: str, kind: str = "card", ranks: list[str] | None = None) -> str:
    """op `card-realify`: anime koleksiyonun still'lerini gercekci kadina cevirir.

    Rutbe basina bir `edit_qwen` isi; ciktilar otomatik kabul, eski hal
    `still_anime.png` olarak BIR KEZ saklanir. Butun rutbeler bitince
    collection.json `style` alani "realistic" olur ve tema/prompt metinlerinden
    anime sozcugu temizlenir - koleksiyonun id/ad'i degismez.
    """
    k = kind_id(kind)
    collection_meta(collection, k)
    tum = _collection_ranks(collection, k)
    hedef = [r for r in _sec(ranks, tum)
             if os.path.isfile(os.path.join(rank_dir(collection, r, k), "still.png"))]
    if not hedef:
        raise ValueError("still'i olan rutbe yok - once asama 1")
    op_id = _op_new("card-realify", len(hedef))

    def calis():
        olan = _realify_body(op_id, collection, k, hedef, "gercekci %s" % collection)
        if olan:
            _mark_realistic(collection, k)
            _op(op_id, log="collection.json: style -> realistic (%d rutbe)" % len(olan))
        with _ops_lock:
            _ops[op_id]["result"] = {"collection": collection, "kind": k, "ranks": olan}
        _op(op_id, message="bitti: %d rutbe gercekci" % len(olan))

    _run(op_id, calis)
    return op_id


# --------------------------------------------------- yeniden canlandirma / kesim
def _grok_still(video: str, dest: str) -> bool:
    """Grok masterinin ilk karesi -> still.png. Once #322'nin `still_first_frame`
    fonksiyonu denenir (ayni ffmpeg cagrisi), yoksa yerel yedek kullanilir."""
    try:
        tool = _cut_tool()
        if hasattr(tool, "still_first_frame"):
            tool.still_first_frame(video, dest)
            return os.path.isfile(dest)
    except Exception:
        pass
    return _first_frame(video, dest)


def _targets(collection: str, kind: str = "", include_dealers: bool = False) -> list[tuple[str, str, str]]:
    """(koleksiyon, tur, rutbe) uclulari. collection == "all" -> hepsi."""
    out = []
    istek = (collection or "").strip()
    if istek and istek.lower() != "all":
        k = kind_id(kind)
        for r in _collection_ranks(istek, k):
            out.append((istek, k, r))
        return out
    for c in collections("card")["collections"]:
        for r in _collection_ranks(c["id"], "card"):
            out.append((c["id"], "card", r))
    if include_dealers:
        for ad in dealer_names():
            out.append((ad, "dealer", MAIN))
    return out


def reanimate(collection: str = "all", gesture: str = DEFAULT_GESTURE, kind: str = "",
              include_dealers: bool = False, dealers_v3: bool = False,
              restill_first: bool = False, realify_first: bool = False) -> str:
    """op `card-reanimate` (GECE MODU): still -> i2v -> kesim, tek zincirde.

    Mevcut 54 kart (+ krupiyeler) icin varsayilan yol. Once Grok masterlari
    KOPYALANIR (`_migrate_grok`), still'i olmayan rutbeye Grok videosunun ilk
    karesi still yapilir; sonra butun i2v isleri kuyruga birakilir; en sonda
    kesimler TEK gpu_lane bileti altinda kosar. Ilerleme asama asama bildirilir
    ("1/4 still", "2/4 video", "3/4 webp") - sabaha kadar gozetimsiz caliabilir.

    #325 iki on adim (varsayilan KAPALI, sira bu):
      `realify_first`  anime stilli koleksiyonlarin still'leri gercekci kadina cevrilir
      `restill_first`  yesil fonlu still'ler duz acik gri studyo fonuna tasinir
    """
    op_id = _op_new("card-reanimate", 0)

    def calis():
        _op(op_id, message="0/4 goc: Grok masterlari kopyalaniyor")
        try:
            g = _migrate_grok(include_dealers=True)
            _op(op_id, log="goc: %d dosya kopyalandi, %d atlandi"
                % (g.get("copied", 0), g.get("skipped", 0)))
        except Exception as e:
            _op(op_id, log="goc uyarisi: %s" % str(e)[:200])
        hedef = _targets(collection, kind, include_dealers)
        if not hedef:
            raise ValueError("hedef yok")
        _op(op_id, total=len(hedef) * 2, message="%d kart: 3 asama" % len(hedef))

        # --- 1/4 still: eksik still'i Grok videosunun ilk karesinden kur
        eksik = []
        for c, k, r in hedef:
            d = rank_dir(c, r, k)
            if os.path.isfile(os.path.join(d, "still.png")):
                continue
            grok = os.path.join(d, "video_grok.mp4")
            if os.path.isfile(grok) and _grok_still(grok, os.path.join(d, "still.png")):
                try:
                    _still_webp(os.path.join(d, "still.png"), os.path.join(d, "still.webp"), k)
                except Exception:
                    pass
                _set_state(c, r, k, still={"at": datetime.now().isoformat(timespec="seconds"),
                                           "job": "", "from": "grok_first_frame"})
                _op(op_id, log="1/4 %s %s: still Grok videosunun ilk karesinden" % (c, r.upper()))
            else:
                eksik.append((c, k, r))
        for c, k, r in eksik:
            _op(op_id, log="1/4 %s %s: still YOK - atlanacak" % (c, str(r).upper()))
        hedef = [t for t in hedef if t not in eksik]

        kesilecek: dict[tuple[str, str], list[str]] = {}
        gruplar: dict[tuple[str, str], list[str]] = {}
        for c, k, r in hedef:
            gruplar.setdefault((c, k), []).append(r)

        # --- 1a/4 gercekci: yalniz style "anime" olan koleksiyonlar (#325)
        if realify_first:
            for (c, k), rs in gruplar.items():
                if str((collection_meta(c, k).get("style") or "")).lower() != "anime":
                    continue
                try:
                    _realify_body(op_id, c, k, rs, "1a/4 gercekci %s" % c)
                    _mark_realistic(c, k)
                except Exception as e:
                    _op(op_id, log="1a/4 %s: gercekci yapilamadi: %s" % (c, str(e)[:200]))

        # --- 1b/4 gri fon: yesil still'ler duz acik griye tasinir (#325)
        if restill_first:
            elle = []
            for (c, k), rs in gruplar.items():
                try:
                    elle += _restill_body(op_id, c, k, rs, False, "1b/4 gri fon %s" % c)["failed"]
                except Exception as e:
                    _op(op_id, log="1b/4 %s: gri fon yapilamadi: %s" % (c, str(e)[:200]))
            if elle:
                _op(op_id, log="1b/4 ELLE DUZELT (still'e dokunulmadi): %s" % ", ".join(elle))

        # --- 2/4 video: koleksiyon koleksiyon i2v (isler toplu kuyruga girer)
        for (c, k), rs in gruplar.items():
            jest = gesture or DEFAULT_GESTURE
            olan = _animate_body(op_id, c, k, rs, jest, "2/4 video %s" % c)
            if olan:
                kesilecek[(c, k)] = olan

        # --- 3/4 webp: butun kesimler TEK gpu_lane bileti (koleksiyon basina)
        for (c, k), rs in kesilecek.items():
            try:
                _cut_body(op_id, c, k, rs, "sam", dealers_v3, "3/4 webp %s" % c)
            except Exception as e:
                _op(op_id, log="3/4 %s: kesim yapilamadi: %s" % (c, str(e)[:200]))
        _op(op_id, message="bitti - 4/4 push elle yapilir")

    _run(op_id, calis)
    return op_id


def recut(collection: str = "all", kind: str = "", include_dealers: bool = False,
          dealers_v3: bool = False) -> str:
    """op `card-recut` (yedek yol): eski Grok videosunu HYBRID kiple yeniden keser."""
    op_id = _op_new("card-recut", 0)

    def calis():
        _op(op_id, message="goc: Grok masterlari kopyalaniyor")
        try:
            _migrate_grok(include_dealers=True)
        except Exception as e:
            _op(op_id, log="goc uyarisi: %s" % str(e)[:200])
        hedef = _targets(collection, kind, include_dealers)
        gruplar: dict[tuple[str, str], list[str]] = {}
        for c, k, r in hedef:
            d = rank_dir(c, r, k)
            if os.path.isfile(os.path.join(d, "video_grok.mp4")):
                gruplar.setdefault((c, k), []).append(r)
        _op(op_id, total=sum(len(v) for v in gruplar.values()))
        if not gruplar:
            raise ValueError("Grok masteri olan kart yok")
        for (c, k), rs in gruplar.items():
            _cut_body(op_id, c, k, rs, "hybrid", dealers_v3, "3/4 webp %s (hybrid)" % c)
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ goc
def _roster_collection(cid: str) -> dict | None:
    for c in (roster().get("collections") or []):
        if c.get("id") == cid:
            return c
    return None


def _collection_from_roster(cid: str) -> dict:
    """roster.json girdisinden collection.json turetir (goc)."""
    rc = _roster_collection(cid) or {}
    joker = bool(rc.get("rarity_override"))
    varyant = rc.get("variants") or []
    ranks = {}
    sira = list(JOKER_RANKS) if joker else list(RANK_ORDER)
    for i, v in enumerate(varyant):
        if i >= len(sira):
            break
        ranks[sira[i]] = {"look": v.get("look") or "", "pose": v.get("pose") or "",
                          "prompt": ", ".join(x for x in ((rc.get("theme") or ""),
                                                          v.get("look") or "",
                                                          v.get("pose") or "") if x)}
    return {"id": cid, "name": rc.get("name") or cid, "theme": rc.get("theme") or "",
            "style": "realistic", "kind": "card",       # #325: anime stili yok
            "jokers": len(ranks) if joker else 0,
            "created": datetime.now().isoformat(timespec="seconds"),
            "ranks": ranks, "from": "roster.json"}


def _migrate_grok(collection: str = "", include_dealers: bool = True,
                  dry_run: bool = False) -> dict:
    """Mevcut Grok masterlarini `card.root` altina KOPYALAR (kaynak SILINMEZ).

    `design/characters/<kol>/selected/<id>.png` -> `<kol>/<rutbe>/still.png`
    `design/characters/<kol>/videos/<id>.mp4`   -> `<kol>/<rutbe>/video_grok.mp4`
    Krupiye: `dealers/selected/<ad>.png` ve `dealers/videos/<ad>.mp4` (+ durum
    videolari `video_grok_<durum>.mp4` olarak saklanir, ileride kullanilmak uzere).
    Hedef dosya varsa DOKUNULMAZ (yeniden goc guvenlidir).
    """
    src_root = grok_root()
    plan, copied, skipped = [], 0, 0
    hedefler = []
    if collection and collection.lower() != "all":
        hedefler = [collection]
    else:
        hedefler = [c.get("id") for c in (roster().get("collections") or []) if c.get("id")]

    def kopyala(src: str, dest: str, etiket: str):
        nonlocal copied, skipped
        if not os.path.isfile(src):
            return
        plan.append({"src": src, "dest": _rel(dest), "what": etiket,
                     "exists": os.path.isfile(dest)})
        if os.path.isfile(dest):
            skipped += 1
            return
        if dry_run:
            copied += 1
            return
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        shutil.copy2(src, dest)
        copied += 1

    for cid in hedefler:
        sd = os.path.join(src_root, cid)
        if not os.path.isdir(sd):
            continue
        rc = _roster_collection(cid) or {}
        joker = bool(rc.get("rarity_override"))
        sira = list(JOKER_RANKS) if joker else list(RANK_ORDER)
        cj = os.path.join(col_dir(cid, "card"), "collection.json")
        if not os.path.isfile(cj):
            plan.append({"src": roster_path(), "dest": _rel(cj), "what": "collection.json",
                         "exists": False})
            if not dry_run:
                _save_collection(cid, "card", _collection_from_roster(cid))
        for r in sira:
            cid_rank = "%s_%s" % (cid, r.lower())
            d = rank_dir(cid, r, "card")
            kopyala(os.path.join(sd, "selected", cid_rank + ".png"),
                    os.path.join(d, "still.png"), "%s still" % cid_rank)
            kopyala(os.path.join(sd, "videos", cid_rank + ".mp4"),
                    os.path.join(d, "video_grok.mp4"), "%s grok video" % cid_rank)

    if include_dealers:
        sd = os.path.join(src_root, "dealers")
        if os.path.isdir(sd):
            try:
                adlar = sorted({os.path.splitext(a)[0]
                                for a in os.listdir(os.path.join(sd, "selected"))
                                if a.lower().endswith(".png")})
            except OSError:
                adlar = []
            for ad in adlar:
                cj = os.path.join(col_dir(ad, "dealer"), "collection.json")
                if not os.path.isfile(cj):
                    plan.append({"src": "", "dest": _rel(cj),
                                 "what": "collection.json (%s)" % ad, "exists": False})
                    if not dry_run:
                        _save_collection(ad, "dealer", {
                            "id": ad, "name": ad.capitalize(), "kind": "dealer",
                            "style": "realistic", "gesture": DEFAULT_GESTURE,
                            "theme": "elegant casino dealer at the blackjack table",
                            "jokers": 0, "created": datetime.now().isoformat(timespec="seconds"),
                            "ranks": {}, "from": "grok"})
                d = rank_dir(ad, MAIN, "dealer")
                kopyala(os.path.join(sd, "selected", ad + ".png"),
                        os.path.join(d, "still.png"), "%s still" % ad)
                kopyala(os.path.join(sd, "videos", ad + ".mp4"),
                        os.path.join(d, "video_grok.mp4"), "%s grok video" % ad)
                for durum in ("win", "lose", "deal"):
                    kopyala(os.path.join(sd, "videos", "%s_%s.mp4" % (ad, durum)),
                            os.path.join(d, "video_grok_%s.mp4" % durum),
                            "%s %s video" % (ad, durum))

    return {"root": root(), "source": src_root, "copied": copied, "skipped": skipped,
            "dry_run": bool(dry_run), "files": plan}


def migrate(collection: str = "", include_dealers: bool = True, dry_run: bool = False) -> dict:
    """Disa acilan goc ucu (kopyalama - kaynak asla silinmez)."""
    return _migrate_grok(collection, include_dealers, dry_run)


# ------------------------------------------------------------------ manifest
def r2_key(collection: str, kind: str, rank: str, what: str, anim: str = IDLE_ANIM) -> str:
    """Kovadaki anahtar. what: sheet | thumb | still.

    idle ESKI anahtari korur (istemciler o bayti onbellekte tutuyor); diger
    animasyonlar adlarini anahtara katar: <id>_<anim>_<what><surum>.webp (#338).
    """
    cid = card_id(collection, rank, kind)
    a = anim_id(anim)
    ad = ("%s_%s%s.webp" % (cid, what, SUFFIX) if a == IDLE_ANIM
          else "%s_%s_%s%s.webp" % (cid, a, what, SUFFIX))
    if kind_id(kind) == "dealer":
        return "dealers/%s" % ad
    return "collections/%s/%s" % (collection, ad)


def _card_entry(collection: str, kind: str, rank: str) -> dict | None:
    """Bir kartin manifest satiri (sheet yoksa None)."""
    d = rank_dir(collection, rank, kind)
    sheet = os.path.join(d, "sheet.webp")
    thumb_p = os.path.join(d, "thumb.webp")
    if not (os.path.isfile(sheet) and os.path.isfile(thumb_p)):
        return None
    s = (state(collection, rank, kind).get("sheet") or {})
    # Joker koleksiyonu (roster `rarity_override`) VE J1/J2 rutbeleri legendary.
    rc = _roster_collection(collection) or {}
    joker = bool(rc.get("rarity_override")) or str(rank).upper() in JOKER_RANKS
    rarity = rarity_of(rank, joker)
    girdi = {
        "id": card_id(collection, rank, kind),
        "rank": str(rank).lower(),
        "rarity": rarity,
        "price": price_of(rarity),
        "sheet": r2_key(collection, kind, rank, "sheet"),
        "thumb": r2_key(collection, kind, rank, "thumb"),
        "frames": int(s.get("frames") or FRAMES), "fps": int(s.get("fps") or FPS),
        "cols": int(s.get("cols") or COLS),
        "rows": int(s.get("rows") or math.ceil(FRAMES / float(COLS))),
        "frameW": int(s.get("frameW") or FRAME_V3[0]),
        "frameH": int(s.get("frameH") or FRAME_V3[1]),
        "thumbW": int(s.get("thumbW") or THUMB_V3[0]),
        "thumbH": int(s.get("thumbH") or THUMB_V3[1]),
        "sheetBytes": os.path.getsize(sheet),
    }
    if os.path.isfile(os.path.join(d, "still.webp")):
        girdi["still"] = r2_key(collection, kind, rank, "still")
    # #338: animasyon deposu. Ust duzey sheet/thumb alanlari idle'i gosterir
    # (eski istemciler aynen calisir); anims{} tum animasyonlari listeler.
    anims = {}
    for a in anims_of(collection, rank, kind):
        if not (a["sheet"] and a["thumb"]):
            continue
        ad = a["name"]
        ad_d = anim_dir(collection, rank, kind, ad)
        if ad == IDLE_ANIM:
            sa = s
        else:
            sa = ((_read_json(os.path.join(ad_d, "state.json"), {}) or {}).get("sheet") or {})
        anims[ad] = {
            "sheet": r2_key(collection, kind, rank, "sheet", ad),
            "thumb": r2_key(collection, kind, rank, "thumb", ad),
            "frames": int(sa.get("frames") or FRAMES), "fps": int(sa.get("fps") or FPS),
            "cols": int(sa.get("cols") or COLS),
            "rows": int(sa.get("rows") or math.ceil(FRAMES / float(COLS))),
            "frameW": int(sa.get("frameW") or FRAME_V3[0]),
            "frameH": int(sa.get("frameH") or FRAME_V3[1]),
            "thumbW": int(sa.get("thumbW") or THUMB_V3[0]),
            "thumbH": int(sa.get("thumbH") or THUMB_V3[1]),
            "sheetBytes": os.path.getsize(os.path.join(ad_d, "sheet.webp")),
        }
    if len(anims) > 1 or (anims and IDLE_ANIM not in anims):
        girdi["anims"] = anims
    if kind_id(kind) == "dealer":
        for a in ("rank", "rarity", "price"):
            girdi.pop(a, None)
    return girdi


def manifest(dealers_v3: bool = False, out_dir: str = "", published_only: bool = True,
             preview: bool = False) -> dict:
    """Manifest'i uretir (asama 4'un ICINDE cagrilir; ayri uc = kuru calisma).

    Mevcut manifest TABAN alinir: v3'e gecmemis kartlar ve `dealers[]` bolumu
    AYNEN korunur (istemciler eski baytlari saklamaya devam eder), yalniz
    yayina hazir v3 kartlari degistirilir/eklenir. Krupiyeler ancak
    `dealers_v3=True` ile v3 yollarina gecer (APK'da gomulu scarlett'in yolunu
    degistiren uygulama surumu cikmadan yapilmaz).
    """
    taban = _read_json(manifest_src(), None) or {"version": 1, "collections": []}
    out = {"version": int(taban.get("version") or 1),
           "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "collections": [dict(c) for c in (taban.get("collections") or [])]}
    if taban.get("dealers"):
        out["dealers"] = [dict(d) for d in taban["dealers"]]

    degisen, eklenen = 0, 0
    for c in collections("card")["collections"]:
        cid = c["id"]
        pushed = (pushed_of(cid, "card").get("cards") or {}) if published_only else None
        yeni = []
        for r in _collection_ranks(cid, "card"):
            if pushed is not None and card_id(cid, r, "card") not in pushed:
                continue
            e = _card_entry(cid, "card", r)
            if e:
                yeni.append(e)
        if not yeni:
            continue
        mevcut = next((x for x in out["collections"] if x.get("id") == cid), None)
        if mevcut is None:
            mevcut = {"id": cid, "name": c["name"], "style": c["style"],
                      "isJokers": bool(c.get("jokers")), "cards": []}
            out["collections"].append(mevcut)
            eklenen += 1
        kartlar = list(mevcut.get("cards") or [])
        idx = {k.get("id"): i for i, k in enumerate(kartlar)}
        for e in yeni:
            if e["id"] in idx:
                kartlar[idx[e["id"]]] = e
                degisen += 1
            else:
                kartlar.append(e)
                degisen += 1
        mevcut["cards"] = kartlar

    if dealers_v3:
        satirlar = []
        eski = {d.get("id"): d for d in (out.get("dealers") or [])}
        for ad in dealer_names():
            pushed = (pushed_of(ad, "dealer").get("cards") or {}) if published_only else None
            if pushed is not None and ad not in pushed:
                continue
            e = _card_entry(ad, "dealer", MAIN)
            if not e:
                continue
            # Reaksiyonlar (win/lose/deal) v3'te henuz uretilmiyor; eskisi tasinir.
            st = (eski.get(ad) or {}).get("states")
            if st:
                e["states"] = st
            satirlar.append(e)
        if satirlar:
            kalan = [d for d in (out.get("dealers") or [])
                     if d.get("id") not in {s["id"] for s in satirlar}]
            out["dealers"] = satirlar + kalan

    kart = sum(len(c.get("cards") or []) for c in out["collections"])
    if preview:                     # #323: salt okunur onizleme - DOSYA YAZILMAZ
        return {"file": "", "preview": True, "base": manifest_src(),
                "collections": len(out["collections"]), "cards": kart,
                "dealers": len(out.get("dealers") or []), "changed": degisen,
                "new_collections": eklenen, "dealers_v3": bool(dealers_v3),
                "published_only": bool(published_only), "manifest": out}
    hedef_dir = out_dir or root()
    os.makedirs(hedef_dir, exist_ok=True)
    yol = os.path.join(hedef_dir, "manifest.json")
    _write_json(yol, out)
    return {"file": yol, "base": manifest_src(), "collections": len(out["collections"]),
            "cards": kart, "dealers": len(out.get("dealers") or []),
            "changed": degisen, "new_collections": eklenen,
            "dealers_v3": bool(dealers_v3), "published_only": bool(published_only),
            "manifest": out}


# ------------------------------------------------------------------ 4 Push
def _r2_put(wrangler: str, key: str, dosya: str, timeout: int = 600) -> tuple[bool, str]:
    try:
        proc = subprocess.run(
            [wrangler, "r2", "object", "put", "%s/%s" % (bucket(), key),
             "--file", dosya, "--remote"],
            capture_output=True, text=True, timeout=timeout,
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except subprocess.TimeoutExpired:
        return False, "zaman asimi"
    except FileNotFoundError:
        return False, "wrangler bulunamadi"
    if proc.returncode != 0:
        return False, (proc.stderr or proc.stdout or "")[:400]
    return True, ""


def push(collection: str, kind: str = "", ranks: list[str] | None = None,
         dealers_v3: bool = False) -> str:
    """op `card-push` (asama 4): ONCE DOSYALAR, SONRA MANIFEST. GERI ALINAMAZ.

    Onbellek kurali: yollar `_v3` ekiyle YENI, ustune yazma yok. Bir dosya
    yuklenemezse o kart yayinlanmaz ve manifest'e girmez; manifest yalnizca
    tum dosyalari kovaya ulasan kartlari sayar (`_pushed.json`).
    """
    k = kind_id(kind)
    collection_meta(collection, k)
    wr = _wrangler()
    if not wr or not (os.path.isfile(wr) or shutil.which(wr)):
        raise ValueError("wrangler bulunamadi: %s" % wr)
    tum = _collection_ranks(collection, k)
    hedef = [r for r in _sec(ranks, tum)
             if os.path.isfile(os.path.join(rank_dir(collection, r, k), "sheet.webp"))]
    if not hedef:
        raise ValueError("sheet'i olan kart yok - once asama 3")
    op_id = _op_new("card-push", len(hedef) + 1)

    def calis():
        pushed = pushed_of(collection, k)
        pushed.setdefault("cards", {})
        for i, r in enumerate(hedef, 1):
            d = rank_dir(collection, r, k)
            cid = card_id(collection, r, k)
            _op(op_id, message="4/4 push %d/%d  %s" % (i, len(hedef), cid))
            isler = [("sheet", os.path.join(d, "sheet.webp")),
                     ("thumb", os.path.join(d, "thumb.webp"))]
            if os.path.isfile(os.path.join(d, "still.webp")):
                isler.append(("still", os.path.join(d, "still.webp")))
            # #338: idle disindaki animasyonlarin sheet/thumb'lari da yayina girer.
            ek_anim = []
            for a in anims_of(collection, r, k):
                if a["name"] == IDLE_ANIM or not (a["sheet"] and a["thumb"]):
                    continue
                ad_d = anim_dir(collection, r, k, a["name"])
                ek_anim.append((a["name"], "sheet", os.path.join(ad_d, "sheet.webp")))
                ek_anim.append((a["name"], "thumb", os.path.join(ad_d, "thumb.webp")))
            yazilan, hata = [], ""
            for what, dosya in isler:
                if not os.path.isfile(dosya):
                    hata = "%s dosyasi yok" % what
                    break
                key = r2_key(collection, k, r, what)
                ok, err = _r2_put(wr, key, dosya)
                if not ok:
                    hata = "%s: %s" % (key, err[:150])
                    break
                yazilan.append(key)
                _op(op_id, log="+ %s" % key)
            # #338: ek animasyonlar - biri yuklenemezse kart yine de yayinlanir,
            # yalnizca o animasyon manifest'e girmez (idle kartin kendisidir).
            if not hata:
                for anim_ad, what, dosya in ek_anim:
                    if not os.path.isfile(dosya):
                        continue
                    key = r2_key(collection, k, r, what, anim_ad)
                    ok, err = _r2_put(wr, key, dosya)
                    if ok:
                        yazilan.append(key)
                        _op(op_id, log="+ %s" % key)
                    else:
                        _op(op_id, log="! %s yuklenemedi: %s" % (key, err[:120]))
            if hata:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="YUKLENEMEDI %s: %s" % (cid, hata))
                continue
            pushed["cards"][cid] = {"at": datetime.now().isoformat(timespec="seconds"),
                                    "suffix": SUFFIX, "keys": yazilan}
            _write_json(os.path.join(col_dir(collection, k), "_pushed.json"), pushed)
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i)

        # --- manifest EN SON (dosyalar kovada olmadan manifest yayinlanmaz)
        _op(op_id, message="4/4 manifest")
        try:
            res = manifest(dealers_v3=dealers_v3, published_only=True)
            ok, err = _r2_put(wr, "manifest.json", res["file"])
            if not ok:
                raise RuntimeError(err[:200])
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=len(hedef) + 1, log="manifest YUKLENEMEDI: %s" % str(e)[:200])
            return
        pushed["manifest"] = {"at": datetime.now().isoformat(timespec="seconds"),
                              "cards": res["cards"], "dealers_v3": bool(dealers_v3)}
        _write_json(os.path.join(col_dir(collection, k), "_pushed.json"), pushed)
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = {k2: v for k2, v in res.items() if k2 != "manifest"}
        _op(op_id, done=len(hedef) + 1,
            log="+ manifest.json (%d kart, %d koleksiyon)" % (res["cards"], res["collections"]),
            message="bitti")

    _run(op_id, calis)
    return op_id
