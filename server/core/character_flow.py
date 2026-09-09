"""Karakter Modu - uretim hattinin 4. kipi (gorev #286).

Jigsaw/CBN'in kabul-etiket-push kalibini KOPYALAMAZ; kendi uc asamasi var:

  1 Karakter    aday uret (mode="character") -> birini kabul et -> isim ver
  2 8 Yon       kabul edilen gorunusten Qwen Image Edit ile 8 gorunus
  3 Animasyon   yon x klip -> manken (Blender) / saf i2v -> Wan -> kabul ->
                SAM3 kare kare kesim -> anim.webp + sheet.png

Kutuphane duzeni v2 (#305 - `character.root`, vars. C:/Reusable Assets/Realistic Women):

  <Isim>/
    character.json   {name, class, created, layout: 2, base: "base/base.png",
                      portrait: "portrait/portrait.png", prompt: {...}, padding,
                      sprite_canvas, pipeline: {status, op, started, finished, step}}
    card.md  card_proposals.json  anims.json
    candidates/                 base adaylari (bikini/underwear, Z-Image)
    base/base.png               kabul edilen base = SOUTH gorunusu (kart gorseli)
    base/dirs/<yon>.png         base'in 8 yonu (front.png = base.png kopyasi)
    base/dirs/<yon>_NN.png      o yonun adaylari
    portrait/portrait.png       KARE vesikalik ; adaylar portrait_NN.png
    skins/<slug>/skin.json      {slug, name, prompt, created}
    skins/<slug>/outfit.png     kiyafet referansi = giydirilmis SOUTH
    skins/<slug>/dirs/<yon>.png giydirilmis 8 yon (+ <yon>_NN.png adaylari)
    skins/<slug>/anims/...      skin animasyonlari (base skininki: anims/)

  <root>/_outfits/<slug>.png + <slug>.json   karakterden BAGIMSIZ kiyafet kutuphanesi
  (hayalet manken urun fotografi; ayni kiyafet birden cok karaktere giydirilir)
    anims/<yon>/<klip>/
        v01/{manken.mp4, manken.json, wan.mp4, wan.json}   her uretim yeni surum
        meta.json   {"accepted": "v02"}
        frames/  anim.webp  sheet.png  sprite.json         yalniz kabul edilenden

  Skin listesinde `base` de bir skindir (dirs = base/dirs/, anims = anims/).
  Layout 1 (look/outfits/turnaround) ilk okumada bir kez layout 2'ye tasinir;
  eski dosyalar SILINMEZ, kopyalanir (bkz. _migrate).

Uzun isler arka planda calisir ve jigsaw/cbn ile AYNI op defterini kullanir
(istemci /op/{id} ile izler).

#299 - HER IS SIRAYA GIRER:
  * Aday uretimi (yon / base / portre) ve saf i2v artik comfy_gen'in TEK
    kuyruguna is birakir: her aday AYRI bir is kaydidir, telefondaki Sira
    ekraninda gorunur, tasinabilir ve iptal edilebilir. Bu ops gpu_lane'i
    KENDISI ALMAZ - comfy_gen dispatcher'i her isi kendi bileti ile calistirir
    (yoksa kilitlenir).
  * ComfyUI disinda kalan agir asamalar (Blender manken, Wan Animate 2, SAM3
    sprite, Ollama kart/prompt) gpu_lane'den TEK parti halinde gecer; manken
    CPU isidir ama yine de seridi alir ki GPU isiyle ust uste binmesin.

Araclar tools/character/ altinda kutuphane gibi cagrilir (CBN'de kid_cbn gibi).
"""
from __future__ import annotations

import json
import os
import random
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from datetime import datetime

from . import comfy_gen as G
from . import gpu_lane
from . import jigsaw_flow as JF
from .jigsaw_flow import _op, _op_new, _ops, _ops_lock, _run  # noqa: F401

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_TOOLS = os.path.join(_ROOT, "tools")
_SETTINGS = os.path.join(_ROOT, "server", "config", "settings.json")
THUMB_DIR = os.path.join(G.OUT_DIR, "_char_thumbs")

DEFAULT_ROOT = r"C:\Reusable Assets\Realistic Women"

# 8 YON - TEK TANIM YERI (rev2). Saat yonunde, karakterin SAGINA dogru.
# Azimut = manken kamerasinin karakterin kendi ileri yonune gore acisi.
# #301: gorunen adlar PUSULA (tools/character/common.DIRS ile ayni): kameraya
# bakan durus South, arka North, sag East, sol West. Kimlikler diskte degismez.
DIRS = (
    {"id": "front",       "label": "S South",       "azimuth": 0},
    {"id": "front_right", "label": "SE South-East", "azimuth": 45},
    {"id": "right",       "label": "E East",        "azimuth": 90},
    {"id": "back_right",  "label": "NE North-East", "azimuth": 135},
    {"id": "back",        "label": "N North",       "azimuth": 180},
    {"id": "back_left",   "label": "NW North-West", "azimuth": 225},
    {"id": "left",        "label": "W West",        "azimuth": 270},
    {"id": "front_left",  "label": "SW South-West", "azimuth": 315},
)
DIR_IDS = tuple(d["id"] for d in DIRS)
DIR_AZ = {d["id"]: d["azimuth"] for d in DIRS}
# rev3: 4 ikon dugmesi BASE ve PORTRE kucuk resimlerinin altinda da var, yani
# bu ikisi de "yon" gibi davranir (animasyon kumesi, yenile, sil).
PSEUDO_DIRS = ("base", "portrait")
ALL_DIRS = DIR_IDS + PSEUDO_DIRS

PADDINGS = (0.0, 0.1, 0.2, 0.3)     # rev5: referans kenar dolgusu
BIG_CANVAS = 832                    # padding >= 0.2 -> daha genis tuval
VIDEO_TASK = "video_wan"            # i2v varsayilan motoru (comfy_gen gorevi)

# #305: kutuphane duzeni v2 sabitleri
LAYOUT = 2
BASE_REL = "base/base.png"
BASE_DIRS = "base/dirs"
PORTRAIT_REL = "portrait/portrait.png"
SKINS = "skins"
BASE_SKIN = "base"                  # base skini sanaldir: dirs = base/dirs, anims = anims/
OUTFITS = "_outfits"                # karakterden BAGIMSIZ kiyafet kutuphanesi (<root>/_outfits)
# #305: hat BASE SECIMIYLE baslar - base adimi hatta yoktur, kullanici secer.
PIPELINE_STEPS = ("portrait", "story", "dirs")

# #305: skin giydirme IKI GORSELLI duzenleme gorevi. Tasarim dokumani
# wf_i2i_flux2_klein_9b_edit diyor; o (ve 4B kardesi) is akisi ComfyUI'nin
# alt-grafik (subgraph) sinir yuvalarini SIRA ile eslestiren wf2api ile
# cozulemiyor (host dugumu 3 giris bildiriyor, alt-grafik 7 - prompt/vae/clip
# yuvalari kayiyor, CLIPTextEncode metinsiz kaliyor). Bu yuzden ayni isi
# yapan, tek dalli ve iki LoadImage'li bir Qwen-Image-Edit-2511 is akisi
# tools/character/workflows/ altinda durur ve ilk kullanimda ComfyUI'nin
# is akisi klasorune kopyalanir (_ensure_skin_workflow). Gorsel 1 = hedef poz
# (base yon goruntusu, cikti geometrisi bundan gelir), Gorsel 2 = kiyafet.
SKIN_WORKFLOW = "I2I Qwen Edit 2511 Two Image.json"
SKIN_DIR_TASK = "wf_i2i_qwen_edit_2511_two_image"

_NAME_RE = re.compile(r"^[^\\/:*?\"<>|]{1,60}$")
_VER_RE = re.compile(r"^v\d{2,3}$")
_SLUG_RE = re.compile(r"^[a-z0-9_]{1,40}$")


# ------------------------------------------------------- #314 KARAKTER TURU
# Tasarim: design/karakter_hatti_v2.md 3c. Tur TEK YERDE (KIND_PROFILES)
# tanimlanir; base, yon, portre, hikaye, giydirme ve duzenleme istemlerinin
# hepsi buradaki jetonlarla uretilir.
#
# ALTIN KURAL: female render'i eski (tur oncesi) metinlerle BIREBIR AYNI olmak
# zorunda - bu yuzden asagidaki sablonlarin female cikti metni degistirilemez.
# Jetonlar:
#   subject  ozne ("woman" / "man" / hayvan turu / "robot")
#   subj/Subj/poss/Poss/obj  zamirler (she/She/her/Her/her)
#   garb     "uzerindeki" ("outfit" / "body" / "chassis")
#   pose     durus cumlesi   arms  base uretiminde kol/bacak cumlesi
#   stance   base uretiminde durus  body  base uretiminde kadraj
#   parts    kimlik parcalari ("face, hair, skin, body")
#   parts2   yon giydirmede kimlik parcalari ("body, face, hair")
#   identity KEEP kimlik kilidi     neg_id  negatifteki kimlik kacagi
#   hands    silah tutan uzuv       neutral base'in notr set cumlesi
DEFAULT_KIND = "female"
KIND_LABELS = (("female", "Kadin"), ("male", "Erkek"),
               ("animal", "Hayvan"), ("machine", "Makine"))

# #314: hayvan turu kimlik prompt'undan cikarilir. Once irk takma adlari
# (retriever -> dog), sonra dogrudan tur sozcukleri taranir; bulunmazsa "animal".
ANIMAL_ALIASES = {
    "retriever": "dog", "labrador": "dog", "husky": "dog", "corgi": "dog",
    "poodle": "dog", "terrier": "dog", "bulldog": "dog", "shepherd": "dog",
    "dachshund": "dog", "beagle": "dog", "chihuahua": "dog", "pug": "dog",
    "doberman": "dog", "rottweiler": "dog", "hound": "dog", "puppy": "dog",
    "kitten": "cat", "siamese": "cat", "persian": "cat", "tabby": "cat",
    "pony": "horse", "stallion": "horse", "mare": "horse", "foal": "horse",
    "raven": "crow", "hawk": "eagle", "falcon": "eagle",
}
ANIMAL_WORDS = (
    "dog", "cat", "wolf", "fox", "horse", "dragon", "bear", "lion", "tiger",
    "panther", "leopard", "cheetah", "lynx", "rabbit", "deer", "elk", "boar",
    "bull", "cow", "goat", "sheep", "pig", "donkey", "camel", "elephant",
    "rhino", "hippo", "giraffe", "zebra", "monkey", "ape", "gorilla",
    "eagle", "owl", "crow", "raven", "parrot", "penguin", "chicken", "duck",
    "snake", "lizard", "crocodile", "turtle", "frog", "spider", "scorpion",
    "shark", "whale", "dolphin", "fish", "octopus", "crab", "bat", "rat",
    "mouse", "squirrel", "otter", "badger", "weasel", "ferret", "hedgehog",
    "raccoon", "hyena", "jackal", "coyote", "moose", "bison", "buffalo",
)


def animal_subject(text: str) -> str:
    """#314: kimlik prompt'undaki hayvan turu ("a golden retriever dog" -> dog).

    Sozcukler sirayla taranir; ilk eslesen tur (ya da irk takma adinin turu)
    ozne olur. Hicbiri yoksa genel "animal" doner.
    """
    for w in re.findall(r"[a-z]+", (text or "").lower()):
        w = w[:-1] if (w.endswith("s") and w[:-1] in ANIMAL_WORDS) else w
        if w in ANIMAL_ALIASES:
            return ANIMAL_ALIASES[w]
        if w in ANIMAL_WORDS:
            return w
    return "animal"


KIND_PROFILES = {
    "female": {
        "id": "female", "label": "Kadin",
        "subject": "woman", "subj": "she", "Subj": "She", "poss": "her",
        "Poss": "Her", "obj": "her", "garb": "outfit",
        "stance": "standing straight facing the camera",
        "arms": "arms at her sides",
        "body": "full body from head to feet",
        "pose": "standing pose with arms relaxed",
        "frame": "full body from head to feet",
        "parts": "face, hair, skin, body",
        "parts2": "body, face, hair",
        "identity": "same face, same hair, same skin, same body proportions",
        "neg_id": "different face, different hair colour, different outfit",
        "hands": "her hand or hands",
        # base notr set cumlesi = karakter_adaylari.SETS["neutral"] (ayni metin)
        "neutral": "wearing a simple plain black bikini",
        "neg_extra": "",
        "portrait": ("Re-frame to a PASSPORT-STYLE HEAD-AND-SHOULDERS PORTRAIT of the exact same {subject}: "
                     "same face, same hair, same skin, same makeup, same outfit collar. {Poss} WHOLE head is "
                     "visible with a little empty space above {poss} hair, {poss} chin and neck are fully "
                     "visible, the top of {poss} shoulders at the bottom of the frame, face centered, {subj} "
                     "looks straight at the camera. Keep the plain solid flat uniform light gray seamless "
                     "studio background, no shadow, even soft lighting. Photorealistic, sharp focus, "
                     "85mm portrait lens."),
        "story": "",
        "mannequin": "an invisible ghost mannequin",
        # #314 gardirop: bos = mevcut (female) varsayilanlari kullan
        "prop_categories": (), "nouns": {}, "outfit_neg": "", "outfit_neg_prop": "",
        "anim_modes": ("i2v", "mixamo"),
    },
    "male": {
        "id": "male", "label": "Erkek",
        "subject": "man", "subj": "he", "Subj": "He", "poss": "his",
        "Poss": "His", "obj": "him", "garb": "outfit",
        "stance": "standing straight facing the camera",
        "arms": "arms at his sides",
        "body": "full body from head to feet",
        "pose": "standing pose with arms relaxed",
        "frame": "full body from head to feet",
        "parts": "face, hair, beard, skin, body",
        "parts2": "body, face, hair, beard",
        "identity": "same face, same hair, same beard, same skin, same body proportions",
        "neg_id": "different face, different hair colour, different outfit",
        "hands": "his hand or hands",
        "neutral": "wearing plain black boxer briefs, bare torso",
        "neg_extra": "",
        "portrait": ("Re-frame to a PASSPORT-STYLE HEAD-AND-SHOULDERS PORTRAIT of the exact same {subject}: "
                     "same face, same hair, same beard, same skin, same outfit collar. {Poss} WHOLE head is "
                     "visible with a little empty space above {poss} hair, {poss} chin and neck are fully "
                     "visible, the top of {poss} shoulders at the bottom of the frame, face centered, {subj} "
                     "looks straight at the camera. Keep the plain solid flat uniform light gray seamless "
                     "studio background, no shadow, even soft lighting. Photorealistic, sharp focus, "
                     "85mm portrait lens."),
        "story": "",
        "mannequin": "an invisible male ghost mannequin",
        # #314 gardirop: parcalar female ile ayni, manken erkek
        "prop_categories": (), "nouns": {}, "outfit_neg": "", "outfit_neg_prop": "",
        "anim_modes": ("i2v", "mixamo"),
    },
    "animal": {
        "id": "animal", "label": "Hayvan",
        "subject": "animal", "subj": "it", "Subj": "It", "poss": "its",
        "Poss": "Its", "obj": "it", "garb": "body",
        "stance": "standing naturally facing the camera",
        "arms": "all four legs visible",
        "body": "the whole animal from nose to tail",
        "pose": "natural standing pose",
        "frame": "the whole animal from head to tail",
        "parts": "head, fur, markings, body",
        "parts2": "body, head, fur",
        "identity": "same species, same fur pattern, same colours, same body shape",
        "neg_id": "different species, different fur colour, different markings",
        "hands": "its mouth or its harness",
        "neutral": "no clothing and no accessories, natural fur or skin",
        # feedback_no_minors_no_chibi: hayvanda da cocuksu/chibi yok
        "neg_extra": "chibi, cute cartoon mascot, plush toy, baby animal, human, humanoid",
        "portrait": ("Re-frame to a CLOSE-UP HEAD-AND-NECK PORTRAIT of the exact same {subject}: same head "
                     "shape, same fur pattern, same colours, same markings. {Poss} WHOLE head is visible with "
                     "a little empty space above {poss} ears, {poss} muzzle and neck are fully visible, the "
                     "top of {poss} shoulders at the bottom of the frame, head centered, {subj} looks "
                     "straight at the camera. Keep the plain solid flat uniform light gray seamless studio "
                     "background, no shadow, even soft lighting. Photorealistic, sharp focus, "
                     "85mm portrait lens."),
        "story": ("Bu bir HAYVAN karakter: turunu, huyunu, sahibini ya da oyundaki gorevini anlat; "
                  "insan gibi konusturma, insan yasi/kokeni yazma."),
        "mannequin": "an invisible animal mannequin",
        # #314 gardirop: tasma/kosum/pelerin de HAYVAN mankeni uzerinde durur;
        # yalniz silah mankensiz urun fotografidir.
        "prop_categories": ("weapon",),
        "nouns": {"set": "a complete pet costume",
                  "top": "a pet vest",
                  "bottom": "a pair of pet leg wraps",
                  "shoes": "a set of pet booties",
                  "socks": "a set of pet leg socks",
                  "hat": "a pet hat",
                  "headgear": "a pet head accessory",
                  "accessory": "a pet accessory (collar, harness, bandana, cape or saddle)",
                  "weapon": "a weapon",
                  "other": "a pet item"},
        "outfit_neg": "live animal, real pet, person, face, hands, text, watermark",
        "outfit_neg_prop": "live animal, real pet, person, face, hands, body, mannequin, text, watermark",
        "anim_modes": ("i2v",),
    },
    "machine": {
        "id": "machine", "label": "Makine",
        "subject": "robot", "subj": "it", "Subj": "It", "poss": "its",
        "Poss": "Its", "obj": "it", "garb": "chassis",
        "stance": "standing straight facing the camera",
        "arms": "arms or manipulators at its sides",
        "body": "the whole robot from head to feet",
        "pose": "standing pose",
        "frame": "the whole robot from head to feet",
        "parts": "head, panels, colours, body",
        "parts2": "body, head, panels",
        "identity": "same chassis shape, same panels, same joints, same colours",
        "neg_id": "different chassis, different colours, different panels",
        "hands": "its manipulator or hand",
        "neutral": "bare chassis, no extra armour and no additional paint",
        "neg_extra": "chibi, cute toy mascot, plush, organic skin, human face",
        "portrait": ("Re-frame to a CLOSE-UP PORTRAIT of the head and sensor unit of the exact same "
                     "{subject}: same chassis shape, same panels, same joints, same colours. {Poss} WHOLE "
                     "head unit is visible with a little empty space above it, {poss} neck joint is fully "
                     "visible, the top of {poss} shoulders at the bottom of the frame, head centered, the "
                     "main sensor faces the camera. Keep the plain solid flat uniform light gray seamless "
                     "studio background, no shadow, even soft lighting. Photorealistic, sharp focus, "
                     "85mm portrait lens."),
        "story": ("Bu bir MAKINE karakter: modelini, islevini, yapimcisini ve calisma bicimini anlat; "
                  "insan bedeni ve insan yasi yok."),
        # makine kiyafeti = ek donanim: manken yok, duz urun fotografi
        "mannequin": "",
        # #314 gardirop: makine kiyafeti = EK DONANIM; manken yok, robot yok.
        "prop_categories": ("set", "top", "bottom", "shoes", "socks", "hat",
                            "headgear", "accessory", "weapon", "other"),
        "nouns": {"set": "a complete attachment kit for a robot (armor plating and paint scheme)",
                  "top": "a torso armor plate attachment for a robot",
                  "bottom": "a leg armor attachment for a robot",
                  "shoes": "a pair of foot thruster attachments for a robot",
                  "socks": "a pair of joint sleeve attachments for a robot",
                  "hat": "a head module attachment for a robot",
                  "headgear": "an antenna or sensor attachment for a robot",
                  "accessory": "an attachment for a robot (jetpack, shield generator or LED strip)",
                  "weapon": "a weapon mount attachment for a robot",
                  "other": "an attachment part for a robot"},
        "outfit_neg": "robot, person, face, hands, body, mannequin, text, watermark",
        "outfit_neg_prop": "robot, person, face, hands, body, mannequin, text, watermark",
        "anim_modes": ("i2v",),
    },
}
KIND_IDS = tuple(k for k, _ in KIND_LABELS)


def kinds() -> list[dict]:
    """#314: tur listesi - istemci bu listeyi kaynak alir."""
    return [{"id": i, "label": l} for i, l in KIND_LABELS]


def kind_id(kind: str = "") -> str:
    """#314: tur dogrulama - bos ise female, bilinmeyen ise hata (400)."""
    k = (kind or "").strip().lower()
    if not k:
        return DEFAULT_KIND
    if k not in KIND_IDS:
        raise ValueError("bilinmeyen karakter turu: %s" % kind)
    return k


def kind_profile(kind: str = "", subject: str = "") -> dict:
    """#314: turun profili; `subject` verilirse ozne onunla degistirilir."""
    p = dict(KIND_PROFILES[kind_id(kind)])
    if (subject or "").strip():
        p["subject"] = subject.strip()
    return p


def _tok(kind: str = "", subject: str = "") -> dict:
    """#314: sablon jetonlari (profilin yalniz metin alanlari)."""
    return {k: v for k, v in kind_profile(kind, subject).items() if isinstance(v, str)}


def render_kind(tmpl: str, kind: str = "", subject: str = "") -> str:
    """#314: bir istem sablonunu turun jetonlariyla doldurur."""
    return (tmpl or "").format(**_tok(kind, subject))


def anim_modes(kind: str = "") -> list[str]:
    """#314: turun desteklenen animasyon kipleri (animal/machine: yalniz i2v)."""
    return list(KIND_PROFILES[kind_id(kind)]["anim_modes"])


def kind_of(m: dict) -> str:
    """#314: character.json'daki tur - eksikse female (geriye uyumluluk)."""
    k = ((m or {}).get("kind") or "").strip().lower()
    return k if k in KIND_IDS else DEFAULT_KIND


def subject_of(m: dict) -> str:
    """#314: karakterin oznesi - kayitli `subject`, yoksa turden/prompt'tan."""
    k = kind_of(m)
    s = ((m or {}).get("subject") or "").strip()
    if s:
        return s
    if k == "animal":
        p = (m or {}).get("prompt") or {}
        return animal_subject(p.get("prompt") or p.get("combined") or "")
    return KIND_PROFILES[k]["subject"]


# ------------------------------------------------------------------ ayarlar
def _setting(key: str, default: str = "") -> str:
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
    return os.environ.get("CHARACTER_ROOT", "").strip() or _setting("character.root") or DEFAULT_ROOT


def dirs_list() -> list[dict]:
    """8 yon, sabit sira - uygulama bu listeyi kaynak alir."""
    return [dict(d) for d in DIRS]


def paddings() -> list[float]:
    return list(PADDINGS)


def profiles() -> dict:
    """Dropdown profilleri + sinif presetleri + kutuphane koku."""
    yol = os.environ.get("CHARACTER_OPTIONS_FILE", "").strip() or _setting("character.options_file") \
        or os.path.join(_ROOT, "server", "config", "character_options.json")
    out = {"profiles": {}, "presets": {}, "source": yol, "root": root(),
           "dirs": dirs_list(), "paddings": paddings(),
           "kinds": kinds(),                                  # #314
           "anim_modes": {k: anim_modes(k) for k in KIND_IDS},  # #314
           "error": ""}
    try:
        with open(yol, encoding="utf-8") as fh:
            out["profiles"] = json.load(fh)
    except Exception as e:
        out["error"] = str(e)
    try:
        with open(_presets_file(), encoding="utf-8") as fh:
            out["presets"] = {k: v for k, v in (json.load(fh) or {}).items() if not k.startswith("_")}
    except Exception as e:
        out["error"] = (out["error"] + " | " + str(e)).strip(" |")
    return out


def _presets_file() -> str:
    return os.environ.get("CHARACTER_PRESETS_FILE", "").strip() or _setting("character.presets_file") \
        or os.path.join(_ROOT, "server", "config", "character_presets.json")


def presets() -> dict:
    try:
        with open(_presets_file(), encoding="utf-8") as fh:
            return {k: v for k, v in (json.load(fh) or {}).items() if not k.startswith("_")}
    except Exception:
        return {}


def _tools():
    """tools/character paketini kutuphane olarak yukler."""
    if _TOOLS not in sys.path:
        sys.path.insert(0, _TOOLS)
    from character import common, manken, sam_frames, wan_animate2, yon_uret  # noqa: WPS433
    return common, manken, sam_frames, wan_animate2, yon_uret


# -------------------------------------------------------------------- yollar
def _safe_name(name: str) -> str:
    name = (name or "").strip().strip(".")
    if not name or not _NAME_RE.match(name) or ".." in name or name.startswith(("_", ".")):
        raise ValueError("gecersiz karakter adi: %s" % name)
    return name


def char_dir(name: str, create: bool = False) -> str:
    d = os.path.join(root(), _safe_name(name))
    if create:
        os.makedirs(d, exist_ok=True)
    elif not os.path.isdir(d):
        raise ValueError("karakter yok: %s" % name)
    return d


def _inside(base: str, p: str) -> str:
    a, b = os.path.abspath(base), os.path.abspath(p)
    if os.path.commonpath([a, b]) != a:
        raise ValueError("gecersiz yol")
    return b


def resolve(name: str, rel: str) -> str:
    """<karakter>/<rel> - klasor disina cikamaz."""
    d = char_dir(name)
    rel = (rel or "").replace("\\", "/").strip("/")
    if not rel or ".." in rel.split("/"):
        raise ValueError("gecersiz dosya: %s" % rel)
    return _inside(d, os.path.join(d, *rel.split("/")))


def _slug(s: str, n: int = 40) -> str:
    s = re.sub(r"[^a-z0-9]+", "_", (s or "").lower()).strip("_")
    return (s[:n].strip("_") or "clip")


# #305: skin yardimcilari - "" ve "base" ayni sey (base skini).
def skin_slug(skin: str) -> str:
    s = (skin or "").strip().lower()
    if not s or s == BASE_SKIN:
        return BASE_SKIN
    s = _slug(s)
    if not _SLUG_RE.match(s):
        raise ValueError("gecersiz skin: %s" % skin)
    return s


def dirs_root(d: str, skin: str = "") -> str:
    """#305: yon gorsellerinin klasoru - base skini base/dirs, digerleri skins/<slug>/dirs."""
    s = skin_slug(skin)
    return os.path.join(d, "base", "dirs") if s == BASE_SKIN else os.path.join(d, SKINS, s, "dirs")


def anims_root(d: str, skin: str = "") -> str:
    """#305: animasyon klasoru - base skini anims/, digerleri skins/<slug>/anims."""
    s = skin_slug(skin)
    return os.path.join(d, "anims") if s == BASE_SKIN else os.path.join(d, SKINS, s, "anims")


def _rel(d: str, p: str) -> str:
    return os.path.relpath(p, d).replace("\\", "/")


def _ensure_skin_workflow() -> str:
    """#305: iki gorselli giydirme is akisini ComfyUI klasorune kurar (bir kez).

    Depoda tools/character/workflows/ altinda durur; ComfyUI'de yoksa ya da
    depodaki surum daha yeniyse kopyalanir. comfy_gen gorev listesini WFDIR
    mtime'ina bakarak tazeledigi icin kopyadan sonra gorev kendiliginden gorunur.
    """
    src = os.path.join(_TOOLS, "character", "workflows", SKIN_WORKFLOW)
    wfdir = getattr(G, "WFDIR", "") or ""
    if not os.path.isfile(src) or not wfdir or not os.path.isdir(wfdir):
        return ""
    dest = os.path.join(wfdir, SKIN_WORKFLOW)
    try:
        if not os.path.isfile(dest) or os.stat(src).st_mtime > os.stat(dest).st_mtime + 1:
            shutil.copy(src, dest)
    except OSError as e:
        print("[character_flow] skin is akisi kopyalanamadi: %s" % e)
    return dest


def _read_json(p: str, default=None):
    try:
        with open(p, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {} if default is None else default


def _write_json(p: str, data) -> None:
    os.makedirs(os.path.dirname(p), exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, p)


def _ilk_gorsel(d: str, sub: str, kosul=lambda a: True) -> str:
    try:
        for a in sorted(os.listdir(os.path.join(d, sub))):
            if a.lower().endswith((".png", ".jpg")) and kosul(a):
                return "%s/%s" % (sub, a)
    except OSError:
        pass
    return ""


def _sinif_tahmin(d: str) -> str:
    fbx = ((_read_json(os.path.join(d, "anims.json")).get("clips") or {}).get("idle") or {}).get("fbx") or ""
    for k, p in presets().items():
        if fbx and ((p.get("clips") or {}).get("idle") or {}).get("fbx") == fbx:
            return k
    return ""


def _migrate(d: str, m: dict) -> tuple[dict, list[str]]:
    """#305: layout 1 -> 2 tasima. TEK SEFERLIK, KAYIPSIZ (hicbir dosya silinmez).

      base/<slug>_base_master.png -> base/base.png   (yoksa look gorseli base olur)
      outfits/<slug>_signature.png + turnaround/ + anims/ -> skins/signature/
      look ve dirs alanlari kaldirilir; layout: 2 yazilir.

    base/dirs/ yalniz front.png ile acilir (front = base'in kendisi); kalan 7
    yonu kullanici "Eksikleri uret" ya da pipeline rebuild ile uretir.
    """
    m = dict(m or {})
    yapilan: list[str] = []
    look = m.get("look") or _ilk_gorsel(d, "outfits") or _ilk_gorsel(d, "turnaround", lambda a: a == "front.png")
    base = m.get("base") or _ilk_gorsel(d, "base", lambda a: not a.startswith("_"))
    # --- 1. base/base.png
    hedef = os.path.join(d, BASE_REL)
    if not os.path.isfile(hedef):
        kaynak = ""
        for rel in (base, look):
            if rel and os.path.isfile(os.path.join(d, rel)):
                kaynak = rel
                break
        if kaynak:
            _convert(os.path.join(d, kaynak), hedef)
            yapilan.append("%s -> %s" % (kaynak, BASE_REL))
    m["base"] = BASE_REL if os.path.isfile(hedef) else ""
    # --- 2. base/dirs/front.png = base'in kendisi
    if m["base"]:
        fr = os.path.join(d, BASE_DIRS, "front.png")
        os.makedirs(os.path.join(d, BASE_DIRS), exist_ok=True)
        if not os.path.isfile(fr):
            shutil.copy(hedef, fr)
            yapilan.append("base/dirs/front.png")
    # --- 3. eski gorunus (look) + turnaround + anims -> skins/signature
    ta = os.path.join(d, "turnaround")
    ak = os.path.join(d, "anims")
    var_tur = os.path.isdir(ta) and any(a.lower().endswith((".png", ".jpg")) for a in os.listdir(ta))
    var_anim = os.path.isdir(ak) and any(os.scandir(ak))
    if (look and os.path.isfile(os.path.join(d, look))) or var_tur or var_anim:
        sd = os.path.join(d, SKINS, "signature")
        sdd = os.path.join(sd, "dirs")
        os.makedirs(sdd, exist_ok=True)
        if look and os.path.isfile(os.path.join(d, look)) and not os.path.isfile(os.path.join(sd, "outfit.png")):
            _convert(os.path.join(d, look), os.path.join(sd, "outfit.png"))
            yapilan.append("%s -> skins/signature/outfit.png" % look)
        say = 0
        for a in sorted(os.listdir(ta) if os.path.isdir(ta) else []):
            if not a.lower().endswith((".png", ".jpg")) or a.startswith("_"):
                continue
            if not os.path.isfile(os.path.join(sdd, a)):
                shutil.copy(os.path.join(ta, a), os.path.join(sdd, a))
                say += 1
        if say:
            yapilan.append("turnaround -> skins/signature/dirs (%d dosya)" % say)
        if not os.path.isfile(os.path.join(sdd, "front.png")) and os.path.isfile(os.path.join(sd, "outfit.png")):
            shutil.copy(os.path.join(sd, "outfit.png"), os.path.join(sdd, "front.png"))
        if var_anim and not os.path.isdir(os.path.join(sd, "anims")):
            shutil.copytree(ak, os.path.join(sd, "anims"))
            yapilan.append("anims -> skins/signature/anims")
        if not os.path.isfile(os.path.join(sd, "skin.json")):
            _write_json(os.path.join(sd, "skin.json"),
                        {"slug": "signature", "name": "Signature", "prompt": "",
                         "created": datetime.now().isoformat(timespec="seconds"),
                         "migrated_from": look or "turnaround"})
    # --- 4. alanlar
    m.pop("look", None)
    m.pop("dirs", None)
    m["layout"] = LAYOUT
    if not m.get("portrait"):
        m["portrait"] = PORTRAIT_REL if os.path.isfile(os.path.join(d, PORTRAIT_REL)) else ""
    if not m.get("class"):
        m["class"] = _sinif_tahmin(d)
    m.setdefault("name", os.path.basename(d))
    m.setdefault("created", datetime.now().isoformat(timespec="seconds"))
    m["kind"] = kind_of(m)                    # #314: eski karakterler = female
    m.setdefault("subject", subject_of(m))
    yapilan.append("layout 2")
    return m, yapilan


def _infer(d: str, m: dict) -> dict:
    """character.json'u tamamlar; layout 1 ise TASIR ve diske yazar (#305).

    Elle olusmus klasorler (Ivy/Vesper prototipleri) character.json'suz da
    calisir - alanlar diskten cikarilir.
    """
    m = dict(m or {})
    if int(m.get("layout") or 0) < LAYOUT:
        m, yapilan = _migrate(d, m)
        try:
            _write_json(os.path.join(d, "character.json"), m)
            print("[character_flow] #305 tasima %s: %s" % (os.path.basename(d), ", ".join(yapilan)))
        except OSError as e:
            print("[character_flow] %s tasinamadi: %s" % (d, e))
        return m
    m.setdefault("name", os.path.basename(d))
    m["kind"] = kind_of(m)                    # #314: eksikse female
    if not (m.get("subject") or "").strip():  # #314: ozne (hayvanda tur adi)
        m["subject"] = subject_of(m)
    if not m.get("base") or not os.path.isfile(os.path.join(d, m["base"])):
        m["base"] = BASE_REL if os.path.isfile(os.path.join(d, BASE_REL)) else ""
    if not m.get("portrait") or not os.path.isfile(os.path.join(d, m["portrait"])):
        m["portrait"] = PORTRAIT_REL if os.path.isfile(os.path.join(d, PORTRAIT_REL)) else ""
    if not m.get("class"):
        m["class"] = _sinif_tahmin(d)
    return m


def meta(name: str) -> dict:
    d = char_dir(name)
    return _infer(d, _read_json(os.path.join(d, "character.json")))


def _save_meta(name: str, m: dict) -> None:
    _write_json(os.path.join(char_dir(name), "character.json"), m)


def char_kind(name: str) -> tuple[str, str]:
    """#314: karakterin (tur, ozne) ikilisi - butun istemler bundan uretilir."""
    m = meta(name)
    return kind_of(m), subject_of(m)


def _ensure_kind(name: str) -> tuple[str, str]:
    """#314: tur/ozne character.json'da yoksa yazar (create/pick aninda)."""
    m = meta(name)
    k, ozne = kind_of(m), subject_of(m)
    if m.get("kind") != k or (m.get("subject") or "") != ozne:
        m["kind"], m["subject"] = k, ozne
        _save_meta(name, m)
    return k, ozne


def settings(name: str, padding=None, sprite_canvas=None) -> dict:
    """Karakter basina varsayilanlar (character.json): padding, sprite_canvas."""
    m = meta(name)
    if padding is not None and padding != "":
        m["padding"] = min(PADDINGS, key=lambda p: abs(p - float(padding)))
    if sprite_canvas:
        m["sprite_canvas"] = max(128, min(2048, int(sprite_canvas)))
    _save_meta(name, m)
    return {"name": name, "padding": float(m.get("padding") or 0.0),
            "sprite_canvas": int(m.get("sprite_canvas") or 640)}


def anims(name: str) -> dict:
    return _read_json(os.path.join(char_dir(name), "anims.json"))


def save_anims(name: str, data: dict) -> dict:
    if not isinstance(data, dict) or not isinstance(data.get("clips"), dict):
        raise ValueError("anims.json 'clips' sozlugu istiyor")
    _write_json(os.path.join(char_dir(name), "anims.json"), data)
    return data


# ---------------------------------------------------------------- listeleme
def _dir_state(d: str, skin: str = "") -> tuple[dict, dict, dict]:
    """(kabul edilen yonler, yon basina aday sayisi, yon basina aday rel yollari).

    #305: yonler artik base/dirs/ (base skini) ya da skins/<slug>/dirs/ altinda.
    """
    ta = dirs_root(d, skin)
    kok = _rel(d, ta)
    kabul, aday, dosya = {}, {}, {}
    try:
        adlar = sorted(os.listdir(ta))
    except OSError:
        adlar = []
    for y in DIR_IDS:
        kabul[y] = ("%s.png" % y) in adlar
        # #300: TAM eslesme - "front" yonu front_left_*/front_right_*'i,
        # "back" yonu back_left/right'i saymasin (on ek eslesmesi yanlisti).
        dosya[y] = ["%s/%s" % (kok, a) for a in adlar
                    if re.fullmatch(re.escape(y) + "_[0-9]+[.](png|jpg)", a.lower())]
        aday[y] = len(dosya[y])
    return kabul, aday, dosya


def _anim_state(d: str, skin: str = "") -> dict:
    """{klip: {yon: {manken, wan, sprite, versions, accepted}}}"""
    out: dict[str, dict] = {}
    ak = anims_root(d, skin)
    if not os.path.isdir(ak):
        return out
    for y in DIR_IDS:
        yd = os.path.join(ak, y)
        if not os.path.isdir(yd):
            continue
        for clip in sorted(os.listdir(yd)):
            cd = os.path.join(yd, clip)
            if not os.path.isdir(cd):
                continue
            vs = _versions(cd)
            acc = (_read_json(os.path.join(cd, "meta.json")) or {}).get("accepted") or ""
            out.setdefault(clip, {})[y] = {
                "manken": os.path.isfile(os.path.join(cd, "manken.mp4")),
                "wan": any(v["has_wan"] for v in vs),
                "sprite": os.path.isfile(os.path.join(cd, "anim.webp")),
                "versions": len(vs), "accepted": acc}
    return out


def _rev_of(d: str, m: dict, skin: str = "") -> int:
    """#302: karakterin sabit adli gorsellerinin en yeni degisiklik zamani (ms).
    #305: yonler base/dirs (ya da skins/<slug>/dirs) altindan okunur."""
    kok = _rel(d, dirs_root(d, skin))
    yollar = [m.get("base") or "", m.get("portrait") or ""]
    yollar += ["%s/%s.png" % (kok, y) for y in DIR_IDS]
    en_yeni = 0
    for rel in yollar:
        if not rel:
            continue
        try:
            en_yeni = max(en_yeni, os.stat(os.path.join(d, rel)).st_mtime_ns // 1_000_000)
        except OSError:
            pass
    return int(en_yeni)


def _pipeline_state(m: dict) -> dict:
    """#305: character.json.pipeline - eksik alanlar tamamlanir."""
    p = dict(m.get("pipeline") or {})
    return {"status": p.get("status") or "idle", "op": p.get("op") or "",
            "step": p.get("step") or "", "started": p.get("started") or "",
            "finished": p.get("finished") or "", "error": p.get("error") or ""}


def _set_pipeline(name: str, **kw) -> dict:
    """#305: pipeline alanini gunceller (character.json'a yazar)."""
    m = meta(name)
    p = _pipeline_state(m)
    p.update({k: v for k, v in kw.items() if v is not None})
    m["pipeline"] = p
    _save_meta(name, m)
    return p


def _skin_rows(d: str) -> list[dict]:
    """#305: karakterin skinleri - ILK ELEMAN HER ZAMAN base (sanal skin)."""
    rows = [{"slug": BASE_SKIN, "name": "Base", "prompt": "", "created": ""}]
    sk = os.path.join(d, SKINS)
    try:
        adlar = sorted(e.name for e in os.scandir(sk) if e.is_dir() and not e.name.startswith(("_", ".")))
    except OSError:
        adlar = []
    for a in adlar:
        if a == BASE_SKIN:
            continue
        j = _read_json(os.path.join(sk, a, "skin.json"))
        rows.append({"slug": a, "name": j.get("name") or a, "prompt": j.get("prompt") or "",
                     "created": j.get("created") or ""})
    return rows


def list_characters() -> list[dict]:
    r = root()
    rows = []
    try:
        adlar = sorted(e.name for e in os.scandir(r) if e.is_dir() and not e.name.startswith(("_", ".")))
    except OSError:
        return rows
    for name in adlar:
        d = os.path.join(r, name)
        m = _infer(d, _read_json(os.path.join(d, "character.json")))
        kabul, aday, dosya = _dir_state(d)
        rows.append({
            "name": name,
            "class": m.get("class") or "",
            # #314: karakter turu, oznesi ve desteklenen animasyon kipleri
            "kind": kind_of(m),
            "subject": subject_of(m),
            "anim_modes": anim_modes(kind_of(m)),
            "layout": int(m.get("layout") or LAYOUT),
            "base": m.get("base") or "",
            # #305: kart gorseli = base'in South'u ("look"/"look_thumb" KALDIRILDI)
            "south_thumb": m.get("base") or "",
            "portrait": m.get("portrait") or "",
            "padding": float(m.get("padding") or 0.0),
            "pipeline": _pipeline_state(m),                 # #305
            "skins": [s["slug"] for s in _skin_rows(d)],    # #305
            "dirs": kabul,
            "dir_candidates": aday,
            "dir_files": dosya,
            "anims": _anim_state(d),
            "clips": sorted((anims_of_file(d).get("clips") or {}).keys()),
            # #302: sabit adli dosyalar (look/base/portrait/<yon>.png) degisince
            # URL'ler ayni kaldigi icin telefon eski gorseli gosteriyordu; rev
            # kucuk resim URL'sine eklenir, secim degisince gorsel de degisir.
            "rev": _rev_of(d, m),
            "candidates": len(_candidate_files(d)),
            "candidate_files": _candidate_files(d),
            "portraits": _portrait_files(d),   # #296: portre adaylari (rel)
            "sprite_canvas": int(m.get("sprite_canvas") or 640),
            "card": os.path.isfile(os.path.join(d, "card.md")),
            "proposals": len(_proposal_rows(d)),   # #299: bekleyen kart onerisi
            "mtime": int(os.stat(d).st_mtime),
        })
    return rows


def anims_of_file(d: str) -> dict:
    return _read_json(os.path.join(d, "anims.json"))


def _candidate_files(d: str) -> list[str]:
    """candidates/ altindaki adaylarin REL yollari - istemci dogrudan
    thumb/file uclarina verir (stage dosyalari <job_id[:8]>.png adiyla duser)."""
    cand = os.path.join(d, "candidates")
    try:
        return ["candidates/%s" % a for a in sorted(os.listdir(cand))
                if a.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and not a.startswith("_")]
    except OSError:
        return []


def _portrait_files(d: str) -> list[str]:
    """#296: portrait/ altindaki ADAYLARIN rel yollari. Secilen portrait.png ve
    '_' ile baslayanlar disarida kalir - istemci bunlari thumb/pick'e verir."""
    pd = os.path.join(d, "portrait")
    try:
        return ["portrait/%s" % a for a in sorted(os.listdir(pd))
                if a.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
                and not a.startswith("_") and a.lower() != "portrait.png"]
    except OSError:
        return []


# ------------------------------------------------------------- 1  karakter
CARD_TEMPLATE = """# {name} — {cls}

- **Yas / Koken:**
- **Gorunum kilidi:**
- **Kisilik:**
- **Hikaye:**
- **Rol:**
- **Sesi (UI/diyalog tonu):**
"""


def _job_image(job_id: str) -> str:
    j = G.get_job(job_id)
    f = G.job_file(job_id) if j else None
    if not j or j.get("status") != "done" or j.get("is_video") or not f:
        raise ValueError("%s: tamamlanmis gorsel degil" % job_id[:8])
    return f


def create(name: str, cls: str = "", job_id: str = "", file: str = "", prompt: str = "",
           kind: str = "") -> dict:
    """#305: klasor agaci + character.json + card.md + sinif preseti.

    BASE'I KULLANICI SECER; otomasyon secim aninda baslar:
      * `job_id` / `file` - o gorsel candidates/'a alinir ve DOGRUDAN base olur,
        hat (portre + hikaye + 7 yon) hemen koser -> donen "op" izlenir.
      * `prompt`          - yalniz 1 base adayi kuyruga girer (image_zimage,
        Karakter Modu, neutral set); OTOMATIK SECILMEZ, kullanici "Base yap"
        (pick kind="base") deyince hat baslar.
      * ikisi de yoksa    - bos karakter; kullanici sonra aday ekler.

    #314: `kind` (female|male|animal|machine, bos = female) character.json'a
    yazilir; hayvanda ozne kimlik prompt'undan cikarilir ("a golden retriever
    dog" -> "dog") ve `subject` olarak saklanir - butun istemler ondan uretilir.
    """
    name = _safe_name(name)
    tur = kind_id(kind)                                   # #314
    d = os.path.join(root(), name)
    if os.path.isdir(d):
        raise ValueError("bu isimde karakter zaten var: %s" % name)
    src = _job_image(job_id) if job_id else (file if file and os.path.isfile(file) else "")
    kimlik = (prompt or "").strip()
    pr = _prompt_of(job_id) if job_id else {"prompt": kimlik, "prompt2": "",
                                            "combined": kimlik, "negative": "", "seed": None}
    # #314: hayvan oznesi kimlik prompt'undan; diger turlerde profilin oznesi
    ozne = (animal_subject(pr.get("prompt") or pr.get("combined") or "") if tur == "animal"
            else KIND_PROFILES[tur]["subject"])
    for sub in ("candidates", BASE_DIRS, "portrait", SKINS, "anims"):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    m = {"name": name, "class": (cls or "").strip(), "layout": LAYOUT,
         "kind": tur, "subject": ozne,                    # #314
         "created": datetime.now().isoformat(timespec="seconds"),
         "base": "", "portrait": "", "padding": 0.0,
         "prompt": pr,
         "pipeline": {"status": "idle", "op": "", "step": "", "started": "", "finished": "", "error": ""}}
    _save_meta(name, m)
    with open(os.path.join(d, "card.md"), "w", encoding="utf-8") as fh:
        fh.write(CARD_TEMPLATE.format(name=name, cls=(cls or "-")))
    p = presets().get((cls or "").strip().lower())
    if p:
        _write_json(os.path.join(d, "anims.json"), dict(p, ref=BASE_REL))
    op, steps = "", []
    if src:
        # kullanicinin sectigi gorsel: adaylara koy + base yap + hat basla
        cand = os.path.join(d, "candidates", "%s_01.png" % _slug(name))
        _convert(src, cand)
        _accept_base(name, cand)
        steps = list(PIPELINE_STEPS)
        op = run_pipeline(name, steps)
    elif kimlik:
        op = generate_base(name, 1)      # tek aday, OTOMATIK SECILMEZ
    return {"name": name, "dir": d, "base": meta(name).get("base") or "",
            "kind": tur, "subject": ozne,                 # #314
            "preset": bool(p), "op": op, "steps": steps}


def _prompt_of(job_id: str) -> dict:
    j = G.get_job(job_id) or {}
    return {k: j.get(k) or "" for k in ("prompt", "prompt2", "combined", "negative")} | {"seed": j.get("seed")}


def _convert(src: str, dest: str) -> str:
    """Kaynagi PNG olarak hedefe yazar (jpg gelirse cevirir)."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.splitext(src)[1].lower() == os.path.splitext(dest)[1].lower():
        shutil.copy(src, dest)
        return dest
    from PIL import Image
    with Image.open(src) as f:
        f.convert("RGB").save(dest)
    return dest


def stage(name: str, job_ids: list[str]) -> dict:
    """Uretim ciktilarini candidates/'a kopyalar."""
    d = char_dir(name)
    cand = os.path.join(d, "candidates")
    os.makedirs(cand, exist_ok=True)
    ok, hata = [], []
    for jid in job_ids:
        try:
            src = _job_image(jid)
        except ValueError as e:
            hata.append(str(e))
            continue
        dest = os.path.join(cand, "%s%s" % (jid[:8], os.path.splitext(src)[1].lower()))
        shutil.copy(src, dest)
        ok.append(os.path.basename(dest))
    return {"added": ok, "errors": hata}


def _find(name: str, file: str) -> str:
    """Aday dosyasini bulur: rel yol ya da bilinen klasorlerde dosya adi (#305)."""
    d = char_dir(name)
    if "/" in file or "\\" in file:
        p = resolve(name, file)
        if os.path.isfile(p):
            return p
        raise ValueError("dosya yok: %s" % file)
    for sub in ("candidates", BASE_DIRS, "portrait", "base", "turnaround", "outfits"):
        p = os.path.join(d, sub, file)
        if os.path.isfile(p):
            return p
    raise ValueError("dosya yok: %s" % file)


def _temizle_adaylar(folder: str, kalip: str) -> int:
    """#302: klasordeki kaliba uyan aday dosyalarini siler, sayiyi doner."""
    silinen = 0
    try:
        adlar = os.listdir(folder)
    except OSError:
        return 0
    for a in adlar:
        if re.fullmatch(kalip, a.lower()):
            try:
                os.remove(os.path.join(folder, a))
                silinen += 1
            except OSError:
                pass
    return silinen


def _accept_base(name: str, src: str) -> str:
    """#305: bir adayi base yapar (base/base.png + base/dirs/front.png)."""
    d = char_dir(name)
    _convert(src, os.path.join(d, BASE_REL))
    _convert(src, os.path.join(d, BASE_DIRS, "front.png"))
    m = meta(name)
    m["base"] = BASE_REL
    _save_meta(name, m)
    a = anims(name)
    if a:
        a["ref"] = BASE_REL
        _write_json(os.path.join(d, "anims.json"), a)
    return BASE_REL


def _base_degisti(name: str) -> None:
    """#305: base secilince turetilmis her sey gecersizdir - eski yonler,
    portre ve KABUL EDILMEMIS kart onerileri temizlenir (skinler kalir)."""
    d = char_dir(name)
    _temizle_adaylar(os.path.join(d, BASE_DIRS),
                     r"(%s)([_][0-9]+)?[.](png|jpg)" % "|".join(re.escape(y) for y in DIR_IDS if y != "front"))
    _temizle_adaylar(os.path.join(d, "portrait"), r"portrait([_][0-9]+)?[.](png|jpg)")
    m = meta(name)
    m["portrait"] = ""
    _save_meta(name, m)
    with _prop_lock:
        rows = [r for r in _proposals(name) if r.get("accepted")]
        _save_proposals(name, rows)


def delete_candidate(name: str, file: str) -> dict:
    """#310: candidates/ altindaki bir base adayini siler (kabul edilmis
    gorsellere dokunmaz)."""
    d = char_dir(name)
    rel = (file or "").replace("\\", "/").strip("/")
    if not rel.startswith("candidates/") or "/" in rel[len("candidates/"):]:
        raise ValueError("yalniz candidates/ altindaki adaylar silinebilir")
    p = _inside(d, os.path.join(d, rel))
    if not os.path.isfile(p):
        raise ValueError("aday yok: %s" % rel)
    os.remove(p)
    return {"name": name, "deleted": 1, "file": rel}


def pick(name: str, file: str, kind: str = "base") -> dict:
    """kind: base | portrait | dir:<yon> | skin:<slug>:<yon>  (#305).

    "look" KALDIRILDI. BASE SECIMI OTOMASYONU BASLATIR: eski yonler/portre ve
    kabul edilmemis oneriler silinir, hat (portre + hikaye + 7 yon) koser;
    donen sozlukte "op" alani bulunur.
    """
    d = char_dir(name)
    src = _find(name, file)
    op = ""
    if kind == "look":
        raise ValueError("look kaldirildi - base sec")
    if kind == "base":
        rel = _accept_base(name, src)
        _ensure_kind(name)                     # #314: tur/ozne character.json'a yazilir
        _base_degisti(name)
        op = run_pipeline(name, list(PIPELINE_STEPS))
    elif kind == "portrait":
        rel = PORTRAIT_REL
        _convert(src, os.path.join(d, rel))
        m = meta(name)
        m["portrait"] = rel
        _save_meta(name, m)
        # #302: secim yapildi - diger portre adaylari yer kaplamasin.
        _temizle_adaylar(os.path.join(d, "portrait"), "portrait_[0-9]+[.](png|jpg)")
    elif kind.startswith("dir:") or kind.startswith("skin:"):
        if kind.startswith("skin:"):
            _s, slug, y = (kind.split(":", 2) + ["", ""])[:3]
            slug = skin_slug(slug)
        else:
            slug, y = BASE_SKIN, kind.split(":", 1)[1]
        if y not in DIR_IDS:
            raise ValueError("bilinmeyen yon: %s" % y)
        dr = dirs_root(d, slug)
        rel = "%s/%s.png" % (_rel(d, dr), y)
        _convert(src, os.path.join(d, rel))
        if y == "front" and slug != BASE_SKIN:
            _convert(src, os.path.join(d, SKINS, slug, "outfit.png"))
        # #302: secim yapildi - o yonun diger adaylari silinir.
        _temizle_adaylar(dr, re.escape(y) + "_[0-9]+[.](png|jpg)")
    else:
        raise ValueError("bilinmeyen kind: %s" % kind)
    return {"name": name, "kind": kind, "file": rel, "op": op}


def delete_dir(name: str, y: str, skin: str = "") -> dict:
    """Bir yonun kabul edilen gorselini ve adaylarini siler (#305: skin destegi).
    base/portrait icin yalnizca SECIM temizlenir (adaylar candidates/'ta kalir)."""
    if y not in ALL_DIRS:
        raise ValueError("bilinmeyen yon: %s" % y)
    d = char_dir(name)
    if y == "front" and skin_slug(skin) == BASE_SKIN:
        raise ValueError("front yonu base'in kendisidir, silinemez")
    if y in PSEUDO_DIRS:
        m = meta(name)
        rel = m.get(y) or ""
        m[y] = ""
        _save_meta(name, m)
        if rel:
            try:
                os.remove(os.path.join(d, rel))
            except OSError:
                pass
        return {"deleted": 1 if rel else 0, "dir": y}
    dr = dirs_root(d, skin)
    silinen = _temizle_adaylar(dr, re.escape(y) + r"([_][0-9]+)?[.](png|jpg)")
    return {"deleted": silinen, "dir": y, "skin": skin_slug(skin)}


# ------------------------------------------------------------------ 2  yon
# #299: yon / base / portre adaylari artik comfy_gen'in TEK kuyruguna girer.
# Her aday AYRI bir is kaydidir; Sira ekraninda gorunur, sirasi degistirilebilir
# ve iptal edilebilir. Op yalniz ciktilari toplar - gpu_lane BURADA ALINMAZ,
# comfy_gen dispatcher'i her isi kendi bileti ile calistirir (yoksa kilitlenir).
def _serbest_ad(dest_dir: str, kalip: str) -> str:
    """#299: 'left_%02d.png' kalibi icin bos numarayi bulur (ustune yazmaz)."""
    os.makedirs(dest_dir, exist_ok=True)
    k = 1
    while os.path.isfile(os.path.join(dest_dir, kalip % k)):
        k += 1
    return os.path.join(dest_dir, kalip % k)


def _is_sil(jid: str, tasindi: bool = False) -> None:
    """#314: comfy_gen is kaydini siler.

    `tasindi=True` ise isin cikti dosyasi zaten KESILIP kutuphaneye tasinmistir;
    dosyaya dokunulmaz (yalniz kayit ve onizleme silinir). Boylece hicbir yolda
    "once sil sonra kopyala" olmaz (#311 hatasi).
    """
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


def _yerlestirici(dest_dir: str, kalip: str):
    """#299: bir isin ciktisini bos numarali dosyaya TASIYAN islev doner.
    #314: kopyala-sonra-sil yerine KES (shutil.move) - ayni dosya iki yerde
    durmaz ve cikti hicbir zaman yerlestirilmeden silinmez."""
    def yerlestir(src: str) -> str:
        p = _serbest_ad(dest_dir, kalip)
        _tasi_dene(src, p)                           # #328: thumb kilidine karsi yeniden dene
        return os.path.basename(p)
    return yerlestir


def _kuyruk_op(kind: str, total: int, uret) -> str:
    """#299: op ac, arka planda comfy_gen'e isleri birak, ciktilari topla.

    uret(op_id) -> [(job_id, etiket, yerlestir)] listesi doner. Isler SIRAYLA
    beklenir; biten isin ciktisi yerlestir() ile kutuphaneye kopyalanir ve is
    galeriyi doldurmasin diye silinir (jigsaw gozcusuyle ayni kural).
    """
    op_id = _op_new(kind, total)

    def calis():
        isler = uret(op_id)
        _op(op_id, total=len(isler), message="%d is kuyruga girdi" % len(isler))
        _topla(op_id, isler)

    _run(op_id, calis)
    return op_id


def _topla(op_id: str, isler: list, timeout: int = 3 * 3600) -> None:
    """#299: kuyruga birakilan comfy_gen islerini sirayla bekler ve yerlestirir."""
    for i, (jid, etiket, yerlestir) in enumerate(isler, 1):
        _op(op_id, message="%d/%d  %s" % (i, len(isler), etiket))
        tasindi = False
        try:
            src = _await_job(jid, op_id, "%d/%d %s" % (i, len(isler), etiket), timeout)
            ad = yerlestir(src)                      # #314: yerlestirme = KES
            tasindi = not os.path.isfile(src)        # placer tasidiysa dosya gitti
        except Exception as e:                       # iptal/hata = basarisiz
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=i, log="%s: %s" % (etiket, str(e)[:200]))
        else:
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s -> %s" % (etiket, ad))
        # ara cikti galeride kalmasin; tasindiysa DOSYAYA DOKUNULMAZ (#314)
        _is_sil(jid, tasindi)
    _op(op_id, message="bitti")


def base_image(name: str) -> str:
    """#305: base/base.png (yoksa hata) - yon/portre/skin uretiminin kaynagi."""
    d = char_dir(name)
    p = os.path.join(d, (meta(name).get("base") or BASE_REL))
    if not os.path.isfile(p):
        raise ValueError("bu karakterin base gorseli yok - once bir base sec")
    return p


def generate_dirs(name: str, dirs: list[str], n: int = 2, skin: str = "") -> str:
    """op: secili yonlerin adaylarini uretir (Qwen Image Edit, comfy_gen kuyrugu).

    rev3: "yenile" ikonu BASE ve PORTRE altinda da var -> dirs ["base"] yeni
    kimlik adaylari (Z-Image), ["portrait"] portre adaylari uretir.
    #299: her (yon, aday) ciftine bir comfy_gen isi acilir.
    #305: `skin` doluysa is BASE yonlerine degil, o skinin giydirilmis
    yonlerine gider (iki gorselli gorev, bkz. generate_skin_dirs)."""
    istek = list(dirs or [])
    if "portrait" in istek and len(istek) == 1:
        return generate_portrait(name, n)
    if "base" in istek and len(istek) == 1:
        return generate_base(name, n)
    if skin_slug(skin) != BASE_SKIN:
        return generate_skin_dirs(name, skin, istek, n)
    d = char_dir(name)
    base = base_image(name)
    hedef = [y for y in istek if y in DIR_IDS and y != "front"]
    if not hedef:
        raise ValueError("yon secilmedi (front base'in kendisidir; base/portrait tek basina gonderilir)")
    _c, _mk, _sf, _wa, yon_uret = _tools()
    tur, ozne = char_kind(name)                       # #314
    n = max(1, min(8, int(n or 1)))
    dr = dirs_root(d, BASE_SKIN)
    os.makedirs(dr, exist_ok=True)
    if not os.path.isfile(os.path.join(dr, "front.png")):
        shutil.copy(base, os.path.join(dr, "front.png"))   # front = base'in kendisi

    def uret(op_id):
        isler = []
        for y in hedef:
            for i in range(1, n + 1):
                etiket = "%s_%02d" % (y, i)
                try:
                    job = _yon_job(name, base, y, yon_uret, tur, ozne)      # #314
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
                    continue
                isler.append((job["id"], etiket, _yerlestirici(dr, y + "_%02d.png")))
                _op(op_id, log="%s kuyrukta (%s)" % (etiket, job["id"][:8]))
        return isler

    return _kuyruk_op("char-dirs", len(hedef) * n, uret)


def _yon_job(name: str, base: str, y: str, yon_uret, kind: str = "", subject: str = "") -> dict:
    """#305: tek yon adayi icin comfy_gen isi.

    mode="free": Karakter Modu sablonu (CHARACTER_PROMPT2) ve 832x1472
    zorlamasi bir DUZENLEME isine girmesin - grafik yon_uret.submit ile
    birebir ayni kalsin.
    #314: istem/KEEP/negatif yon_uret.render(<tur profili>) ile turden uretilir;
    female render'i eski metinle birebir aynidir.
    """
    R = yon_uret.render(kind_profile(kind, subject))
    return G.submit("edit_qwen", "%s %s" % (R["prompts"][y], R["keep"]),
                    negative=R["neg"], seed=random.randint(1, 2 ** 31),
                    turbo=True, image_path=base, mode="free",
                    client="flow", category=name)


# #305: portre artik "vesikalik" - sikica bas-omuz, cikti ustten KARE kirpilir.
# #308: cene kesiliyordu - bas kadraji doldurmasin: sac ustunde bosluk, cene ve
# boyun gorunur, omuz basi altta. Kare kirpma da ustten %78 alir (_square_top).
# #314: metin artik TURE gore uretilir (KIND_PROFILES[<tur>]["portrait"]);
# asagidaki sabit female render'idir ve eski metinle BIREBIR AYNIDIR.
def portrait_prompt(kind: str = "", subject: str = "") -> str:
    """#314: turun vesikalik/yakin plan portre istemi."""
    return render_kind(kind_profile(kind, subject)["portrait"], kind, subject)


PORTRAIT_PROMPT = portrait_prompt(DEFAULT_KIND)

# #305: kimlik/poz/fon kilidi - Duzenle ucunda kullanicinin cumlesine eklenir.
# #314: ozne ve kimlik parcalari turden gelir.
EDIT_KEEP_TMPL = ("Keep the exact same {subject}: {identity}, the same pose, "
                  "the same camera angle and framing, and the same plain solid flat uniform light gray seamless "
                  "studio background with no shadow. Change nothing else. Photorealistic.")


def edit_keep(kind: str = "", subject: str = "") -> str:
    """#314: Duzenle ucundaki kimlik/poz/fon kilidi."""
    return render_kind(EDIT_KEEP_TMPL, kind, subject)


EDIT_KEEP = edit_keep(DEFAULT_KIND)

# #305: kiyafet kutuphanesi istemleri (hayalet manken urun fotografi)
# #313: artik KATEGORIYE gore kurulur - giysi/ayakkabi/corap/sapka hayalet manken
# uzerinde, silah/aksesuar/kafalik ise mankensiz duz urun fotografi olarak uretilir.
OUTFIT_PROMPT = ("{}, a complete outfit displayed on an invisible ghost mannequin, front view, centered, "
                 "plain solid flat uniform light gray seamless studio background, product photo, "
                 "photorealistic, sharp focus")
OUTFIT_NEG = "person, face, hands, text, watermark"
# #313: mankensiz (prop) kategorilerde manken de negatife girer
OUTFIT_NEG_PROP = "person, face, hands, body, mannequin, text, watermark"

# #313: kategori kimlikleri SABIT; kutuphane kaydinda `category` alani tutulur.
# Kategorisi olmayan eski kayit = "set" (geriye uyumluluk, DEFAULT_CATEGORY).
OUTFIT_CATEGORIES = (
    ("set",       "Set"),
    ("top",       "Ust"),
    ("bottom",    "Alt"),
    ("shoes",     "Ayakkabi"),
    ("socks",     "Corap"),
    ("hat",       "Sapka"),
    ("headgear",  "Kafalik"),
    ("accessory", "Aksesuar"),
    ("weapon",    "Silah"),
    ("other",     "Diger"),
)
OUTFIT_CATEGORY_IDS = tuple(c for c, _ in OUTFIT_CATEGORIES)
OUTFIT_CATEGORY_LABELS = dict(OUTFIT_CATEGORIES)
DEFAULT_CATEGORY = "set"
# #313: uretim istemindeki parca adi (ghost mannequin cumlesinin oznesi)
OUTFIT_NOUNS = {
    "set":       "a complete outfit",
    "top":       "a single top garment",
    "bottom":    "a single bottom garment",
    "shoes":     "a pair of shoes",
    "socks":     "a pair of socks",
    "hat":       "a hat",
    "headgear":  "a head accessory",
    "accessory": "an accessory",
    "weapon":    "a weapon",
    "other":     "an item",
}
# #313: mankensiz uretilen kategoriler (esya/prop); geri kalan hepsi hayalet manken.
OUTFIT_PROP_CATEGORIES = ("weapon", "accessory", "headgear")
# #313: Hot modifier YALNIZ giysi kategorilerine eklenir (silah/aksesuar/kafalikta anlamsiz).
OUTFIT_HOT_CATEGORIES = ("set", "top", "bottom", "shoes", "socks", "hat")
# #314: manken cumlesi TURDEN gelir (KIND_PROFILES[<tur>]["mannequin"]):
# female "an invisible ghost mannequin", male "an invisible male ghost mannequin",
# animal "an invisible animal mannequin", machine yok (hep mankensiz urun fotografi).
OUTFIT_GHOST_TMPL = ("{p}, {n} displayed on {mnq}, front view, centered, "
                     "plain solid flat uniform light gray seamless studio background, product photo, "
                     "photorealistic, sharp focus")
OUTFIT_PROP_TMPL = ("{p}, {n}, product photo, centered, plain solid flat uniform light gray seamless "
                    "studio background, no person, no mannequin, photorealistic, sharp focus")


def outfit_prop_categories(kind: str = "") -> tuple:
    """#314: o turde MANKENSIZ uretilen kategoriler (female = eski liste)."""
    return tuple(KIND_PROFILES[kind_id(kind)].get("prop_categories") or ()) or OUTFIT_PROP_CATEGORIES


def outfit_noun(category: str, kind: str = "") -> str:
    """#314: uretim istemindeki parca adi - turun kendi adlari, yoksa female."""
    c = category if category in OUTFIT_CATEGORY_IDS else DEFAULT_CATEGORY
    ozel = KIND_PROFILES[kind_id(kind)].get("nouns") or {}
    return ozel.get(c) or OUTFIT_NOUNS.get(c, OUTFIT_NOUNS[DEFAULT_CATEGORY])


def outfit_category(c: str) -> str:
    """#313: kategori dogrulama - bos ise 'set', bilinmeyen ise hata."""
    c = (c or "").strip().lower()
    if not c:
        return DEFAULT_CATEGORY
    if c not in OUTFIT_CATEGORY_IDS:
        raise ValueError("bilinmeyen kiyafet kategorisi: %s" % c)
    return c


def outfit_prompt(prompt: str, category: str = DEFAULT_CATEGORY, kind: str = "") -> str:
    """#313: kategoriye gore uretim istemi (manken / mankensiz).
    #314: manken cumlesi ve parca adi TURE gore secilir; makinede hep mankensiz."""
    c = category if category in OUTFIT_CATEGORY_IDS else DEFAULT_CATEGORY
    prof = KIND_PROFILES[kind_id(kind)]
    mnq = prof.get("mannequin") or ""
    prop = (c in outfit_prop_categories(kind)) or not mnq
    tmpl = OUTFIT_PROP_TMPL if prop else OUTFIT_GHOST_TMPL
    return tmpl.format(p=prompt, n=outfit_noun(c, kind), mnq=mnq)


def outfit_negative(category: str = DEFAULT_CATEGORY, kind: str = "") -> str:
    """#313: mankensiz kategorilerde manken de negatife girer.
    #314: turun kendi negatifi varsa o kullanilir (female = eski metin)."""
    prof = KIND_PROFILES[kind_id(kind)]
    prop = (category in outfit_prop_categories(kind)) or not (prof.get("mannequin") or "")
    if prop:
        return prof.get("outfit_neg_prop") or OUTFIT_NEG_PROP
    return prof.get("outfit_neg") or OUTFIT_NEG
# #312: "Hot" modifier - seksi kiyafet sablonu (yetiskin kadin kiyafeti; ciplaklik yok,
# kural: feedback_no_minors_no_chibi / hot negatiflerine nude eklenmez).
OUTFIT_STYLES = {
    "hot": ("revealing sexy skimpy design, form-fitting, bare midriff, deep plunging neckline, "
            "high-cut, thigh-high slit, sheer accents, glamorous adult woman's outfit"),
}
# #312: hazir kiyafet sablonlari - id, etiket, grup, prompt.
# #313: her sablona KATEGORI eklendi -> (id, etiket, grup, kategori, prompt).
# Eski (gunluk/fantastik/etkinlik) sablonlarin hepsi "set"tir; parca sablonlarinda
# grup = kategori kimligi. Kullanicinin kendi prompt'u sablonun arkasina virgulle
# eklenir; ad bos birakilirsa etiket ad olur.
# #314: liste artik TURE gore bolundu - asagidaki female sablonlari DEGISMEDI;
# male/animal/machine kumeleri altta eklenir (bkz. _TPL_MALE / _TPL_ANIMAL /
# _TPL_MACHINE). Satir bicimi: (id, etiket, grup, kategori, prompt).
_TPL_FEMALE = [
    # gunluk (set)
    ("tshirt_jeans",  "Tisort + jean",        "gunluk",   "set", "casual fitted white t-shirt and blue denim jeans"),
    ("skirt_top",     "Etek + ust",           "gunluk",   "set", "short pleated mini skirt with a fitted crop top"),
    ("dress",         "Elbise",               "gunluk",   "set", "elegant fitted evening dress"),
    ("summer_dress",  "Yazlik elbise",        "gunluk",   "set", "light floral summer dress with thin straps"),
    ("bikini",        "Bikini",               "gunluk",   "set", "two-piece bikini swimsuit"),
    ("sportswear",    "Spor",                 "gunluk",   "set", "sports bra and high-waisted leggings athletic set"),
    ("office",        "Ofis",                 "gunluk",   "set", "fitted office blazer, silk blouse and pencil skirt"),
    ("leather",       "Deri ceket",           "gunluk",   "set", "black leather biker jacket, tank top and skinny jeans"),
    ("gown",          "Gece elbisesi",        "gunluk",   "set", "long silk evening gown with a high slit"),
    # fantastik (set)
    ("knight",        "Sovalye zirhi",        "fantastik", "set", "polished steel plate armour with a tabard and gauntlets"),
    ("mage",          "Buyucu cubbesi",       "fantastik", "set", "flowing mage robe with arcane embroidery and a hood"),
    ("archer",        "Okcu derisi",          "fantastik", "set", "green leather ranger outfit with hood, bracers and quiver straps"),
    ("rogue",         "Haydut",               "fantastik", "set", "dark leather assassin outfit with belts, straps and hidden blades"),
    ("priestess",     "Rahibe",               "fantastik", "set", "white and gold ceremonial priestess gown"),
    ("barbarian",     "Barbar",               "fantastik", "set", "fur and leather barbarian outfit with bone ornaments"),
    ("elf",           "Elf ipegi",            "fantastik", "set", "elven silk gown with leaf motifs and silver embroidery"),
    ("witch",         "Cadi",                 "fantastik", "set", "black witch dress with corset and a pointed hat"),
    ("valkyrie",      "Valkyrie",             "fantastik", "set", "winged valkyrie armour with a feathered cloak"),
    ("pirate",        "Korsan",               "fantastik", "set", "pirate captain outfit with tricorn hat, corset and boots"),
    # etkinlik (set)
    ("valentine",     "Sevgililer Gunu",      "etkinlik", "set", "red heart-themed Valentine's outfit with lace and ribbons"),
    ("santa",         "Santa / Noel",         "etkinlik", "set", "red Santa Claus themed outfit with white fur trim and a Santa hat"),
    ("halloween",     "Cadilar Bayrami",      "etkinlik", "set", "Halloween costume, dark gothic vampire dress"),
    ("easter",        "Paskalya",             "etkinlik", "set", "pastel Easter bunny themed outfit with bunny ears"),
    ("new_year",      "Yilbasi partisi",      "etkinlik", "set", "sparkling sequin New Year party dress"),
    ("beach",         "Plaj",                 "etkinlik", "set", "summer beach outfit with a sarong and a straw hat"),
    ("bride",         "Gelin",                "etkinlik", "set", "white lace wedding dress with a veil"),
    ("cheerleader",   "Ponpon kiz",           "etkinlik", "set", "cheerleader uniform with a pleated skirt and pom-poms"),
    ("nurse",         "Hemsire",              "etkinlik", "set", "nurse costume with a white dress and cap"),
    ("maid",          "Hizmetci",             "etkinlik", "set", "black and white maid costume with an apron"),
    ("police",        "Polis",                "etkinlik", "set", "police officer uniform costume with a cap"),
    ("oktoberfest",   "Oktoberfest",          "etkinlik", "set", "Bavarian dirndl dress with a laced bodice"),
    # #313 ust (top)
    ("top_tshirt",    "Tisort",               "top", "top", "a fitted plain cotton t-shirt"),
    ("top_crop",      "Crop top",             "top", "top", "a short fitted crop top"),
    ("top_blouse",    "Bluz",                 "top", "top", "a silk button-up blouse"),
    ("top_corset",    "Korse",                "top", "top", "a laced corset bustier top"),
    ("top_tank",      "Askili",               "top", "top", "a thin-strap tank top"),
    ("top_sweater",   "Kazak",                "top", "top", "a soft oversized knit sweater"),
    ("top_jacket",    "Ceket",                "top", "top", "a fitted cropped jacket"),
    # #313 alt (bottom)
    ("bottom_mini_skirt",    "Mini etek",     "bottom", "bottom", "a short pleated mini skirt"),
    ("bottom_jeans",         "Jean",          "bottom", "bottom", "blue denim skinny jeans"),
    ("bottom_shorts",        "Sort",          "bottom", "bottom", "high-waisted denim shorts"),
    ("bottom_leggings",      "Tayt",          "bottom", "bottom", "high-waisted athletic leggings"),
    ("bottom_long_skirt",    "Uzun etek",     "bottom", "bottom", "a long flowing maxi skirt"),
    ("bottom_leather_pants", "Deri pantolon", "bottom", "bottom", "tight black leather pants"),
    # #313 ayakkabi (shoes)
    ("shoes_heels",       "Topuklu",          "shoes", "shoes", "a pair of high-heeled stiletto shoes"),
    ("shoes_boots",       "Cizme",            "shoes", "shoes", "a pair of leather ankle boots"),
    ("shoes_sneakers",    "Spor ayakkabi",    "shoes", "shoes", "a pair of white sneakers"),
    ("shoes_thigh_boots", "Diz ustu cizme",   "shoes", "shoes", "a pair of thigh-high heeled boots"),
    # #313 corap (socks)
    ("socks_garter",  "Jartiyerli corap",     "socks", "socks", "a pair of thigh-high stockings with garter straps"),
    ("socks_knee",    "Diz alti corap",       "socks", "socks", "a pair of knee-high socks"),
    ("socks_fishnet", "File corap",           "socks", "socks", "a pair of fishnet stockings"),
    # #313 sapka (hat)
    ("hat_witch", "Cadi sapkasi",             "hat", "hat", "a tall pointed black witch hat"),
    ("hat_crown", "Tac",                      "hat", "hat", "a golden royal crown with gemstones"),
    ("hat_tiara", "Tiara",                    "hat", "hat", "a delicate jewelled silver tiara"),
    ("hat_beret", "Bere",                     "hat", "hat", "a soft wool beret"),
    ("hat_cap",   "Sapka",                    "hat", "hat", "a baseball cap"),
    # #313 kafalik (headgear)
    ("head_bunny", "Tavsan kulagi",           "headgear", "headgear", "a pair of bunny ears on a headband"),
    ("head_cat",   "Kedi kulagi",             "headgear", "headgear", "a pair of cat ears on a headband"),
    ("head_horns", "Boynuz",                  "headgear", "headgear", "a pair of curved demon horns on a headband"),
    ("head_halo",  "Hale",                    "headgear", "headgear", "a glowing golden halo ring"),
    ("head_band",  "Sac bandi",               "headgear", "headgear", "a decorative hair band"),
    # #313 aksesuar (accessory)
    ("acc_necklace",  "Kolye",                "accessory", "accessory", "an elegant pendant necklace"),
    ("acc_glasses",   "Gozluk",               "accessory", "accessory", "a pair of glasses"),
    ("acc_gloves",    "Eldiven",              "accessory", "accessory", "a pair of long opera gloves"),
    ("acc_wings",     "Kanat",                "accessory", "accessory", "a pair of large feathered wings"),
    ("acc_cape",      "Pelerin",              "accessory", "accessory", "a flowing hooded cape"),
    ("acc_scarf",     "Atki",                 "accessory", "accessory", "a knitted scarf"),
    ("acc_belt",      "Kemer",                "accessory", "accessory", "a leather belt with an ornate buckle"),
    ("acc_earrings",  "Kupe",                 "accessory", "accessory", "a pair of drop earrings"),
    # #313 silah (weapon)
    ("wpn_sword",      "Kilic",               "weapon", "weapon", "a steel longsword"),
    ("wpn_greatsword", "Buyuk kilic",         "weapon", "weapon", "a massive two-handed greatsword"),
    ("wpn_dagger",     "Hancer",              "weapon", "weapon", "an ornate curved dagger"),
    ("wpn_staff",      "Asa",                 "weapon", "weapon", "a wooden magic staff with a glowing crystal"),
    ("wpn_bow",        "Yay",                 "weapon", "weapon", "a recurve bow"),
    ("wpn_spear",      "Mizrak",              "weapon", "weapon", "a long steel spear"),
    ("wpn_axe",        "Balta",               "weapon", "weapon", "a heavy double-bladed battle axe"),
    ("wpn_shield",     "Kalkan",              "weapon", "weapon", "a round metal shield with engravings"),
    ("wpn_pistol",     "Tabanca",             "weapon", "weapon", "a semi-automatic pistol"),
    ("wpn_rifle",      "Tufek",               "weapon", "weapon", "a modern assault rifle"),
    ("wpn_scythe",     "Orak",                "weapon", "weapon", "a large curved war scythe"),
    ("wpn_hammer",     "Cekic",               "weapon", "weapon", "a huge two-handed war hammer"),
]

# #314 ERKEK sablonlari (setler + birkac parca; etiketler Turkce, promptlar Ingilizce)
_TPL_MALE = [
    ("m_tshirt_jeans", "Tisort + jean",     "gunluk",    "set", "casual fitted white t-shirt and blue denim jeans, men's outfit"),
    ("m_suit",         "Takim elbise",      "gunluk",    "set", "tailored dark three-piece business suit with a tie, men's outfit"),
    ("m_leather",      "Deri ceket",        "gunluk",    "set", "black leather biker jacket, plain tee and dark jeans, men's outfit"),
    ("m_hoodie",       "Kapusonlu",         "gunluk",    "set", "grey hoodie with cargo pants and sneakers, men's outfit"),
    ("m_sportswear",   "Spor",              "gunluk",    "set", "athletic training top and shorts, men's sportswear"),
    ("m_knight",       "Sovalye zirhi",     "fantastik", "set", "polished steel plate armour with a tabard and gauntlets, men's armour"),
    ("m_mage",         "Buyucu cubbesi",    "fantastik", "set", "flowing mage robe with arcane embroidery and a hood, men's outfit"),
    ("m_archer",       "Okcu derisi",       "fantastik", "set", "green leather ranger outfit with hood, bracers and quiver straps, men's outfit"),
    ("m_barbarian",    "Barbar",            "fantastik", "set", "fur and leather barbarian outfit with bone ornaments, men's outfit"),
    ("m_pirate",       "Korsan",            "fantastik", "set", "pirate captain outfit with tricorn hat, coat and boots, men's outfit"),
    ("m_santa",        "Santa / Noel",      "etkinlik",  "set", "red Santa Claus suit with white fur trim, belt and a Santa hat"),
    ("m_police",       "Polis",             "etkinlik",  "set", "police officer uniform with a cap and duty belt, men's uniform"),
    ("m_firefighter",  "Itfaiyeci",         "etkinlik",  "set", "firefighter turnout gear with reflective stripes and a helmet"),
    ("m_doctor",       "Doktor",            "etkinlik",  "set", "white doctor's coat over a shirt and tie, with a stethoscope"),
    ("m_top_tshirt",   "Tisort",            "top",       "top", "a fitted plain cotton men's t-shirt"),
    ("m_top_shirt",    "Gomlek",            "top",       "top", "a button-up men's dress shirt"),
    ("m_top_jacket",   "Ceket",             "top",       "top", "a men's fitted jacket"),
    ("m_bottom_jeans", "Jean",              "bottom",    "bottom", "men's blue denim jeans"),
    ("m_bottom_cargo", "Kargo pantolon",    "bottom",    "bottom", "men's cargo trousers"),
    ("m_shoes_boots",  "Bot",               "shoes",     "shoes", "a pair of men's leather boots"),
    ("m_shoes_sneak",  "Spor ayakkabi",     "shoes",     "shoes", "a pair of men's white sneakers"),
    ("m_hat_cap",      "Sapka",             "hat",       "hat", "a men's baseball cap"),
    ("m_acc_cape",     "Pelerin",           "accessory", "accessory", "a flowing hooded cape"),
    ("m_acc_gloves",   "Eldiven",           "accessory", "accessory", "a pair of leather gloves"),
    ("m_wpn_sword",    "Kilic",             "weapon",    "weapon", "a steel longsword"),
    ("m_wpn_axe",      "Balta",             "weapon",    "weapon", "a heavy double-bladed battle axe"),
    ("m_wpn_bow",      "Yay",               "weapon",    "weapon", "a recurve bow"),
    ("m_wpn_rifle",    "Tufek",             "weapon",    "weapon", "a modern assault rifle"),
]

# #314 HAYVAN sablonlari (tasma/kosum/bandana/pelerin/sapka/kostum/zirh/eyer/kanat)
_TPL_ANIMAL = [
    ("a_collar",     "Tasma",              "pet", "accessory", "a leather pet collar with a name tag"),
    ("a_harness",    "Kosum",              "pet", "accessory", "a padded pet harness with straps and buckles"),
    ("a_bandana",    "Bandana",            "pet", "accessory", "a folded pet bandana neckerchief"),
    ("a_cape",       "Pelerin",            "pet", "accessory", "a small pet cape with a clasp"),
    ("a_hero_cape",  "Super kahraman pelerini", "pet", "accessory", "a red superhero cape sized for a pet"),
    ("a_saddle",     "Eyer",               "pet", "accessory", "a leather riding saddle with stirrups"),
    ("a_wings",      "Kanat",              "pet", "accessory", "a pair of strap-on feathered wings for a pet"),
    ("a_hat",        "Sapka",              "pet", "hat", "a small pet hat with a chin strap"),
    ("a_santa",      "Santa kostumu",      "pet", "set", "a red Santa Claus pet costume with white fur trim"),
    ("a_armor",      "Zirh",               "pet", "set", "a set of steel barding armour plates for an animal"),
]

# #314 MAKINE sablonlari (ek donanim; robot cizdirilmez)
_TPL_MACHINE = [
    ("r_armor",   "Zirh plakasi",      "kit", "set",       "a set of armour plating panels for a robot chassis"),
    ("r_paint",   "Boya kiti",         "kit", "set",       "a paint scheme kit with painted panel samples for a robot"),
    ("r_weapon",  "Silah montaji",     "kit", "weapon",    "a shoulder weapon mount with a cannon for a robot"),
    ("r_antenna", "Anten",             "kit", "headgear",  "a sensor antenna array module for a robot head"),
    ("r_jetpack", "Jetpack",           "kit", "accessory", "a back-mounted jetpack thruster module"),
    ("r_shield",  "Kalkan jeneratoru", "kit", "accessory", "an arm-mounted shield generator module"),
    ("r_led",     "LED seridi",        "kit", "accessory", "a strip of glowing LED light modules"),
]


def _tpl_rows(kind: str, rows: list) -> list[dict]:
    """#314: (id, etiket, grup, kategori, prompt) -> sozluk + tur alani."""
    return [{"id": i, "label": l, "group": g, "category": c, "kind": kind, "prompt": pr}
            for i, l, g, c, pr in rows]


# #313/#314: tum sablonlar tek listede; her satir `kind` tasir (eskiler female).
OUTFIT_TEMPLATES = (_tpl_rows("female", _TPL_FEMALE) + _tpl_rows("male", _TPL_MALE)
                    + _tpl_rows("animal", _TPL_ANIMAL) + _tpl_rows("machine", _TPL_MACHINE))
OUTFIT_TEMPLATE_MAP = {t["id"]: t for t in OUTFIT_TEMPLATES}


def outfit_templates(kind: str = "") -> dict:
    """#312/#313: GET /outfits/templates - kategoriler + sablonlar + modifier'lar.
    #314: `kind` doluysa yalniz o turun sablonlari doner; yanit `kinds` tasir."""
    k = kind_id(kind) if (kind or "").strip() else ""
    rows = [t for t in OUTFIT_TEMPLATES if not k or t["kind"] == k]
    return {"categories": [{"id": i, "label": l} for i, l in OUTFIT_CATEGORIES],
            "kinds": kinds(),                                   # #314
            "kind": k,
            "templates": [dict(t) for t in rows],
            "styles": [{"id": "hot", "label": "Hot"}]}
OUTFIT_W, OUTFIT_H = 832, 1472

# #305: giydirme istemleri - ikisi de IKI GORSELLI gorevde kullanilir.
# Gorsel 1 = giydirilecek karakter (cikti geometrisi bundan gelir), Gorsel 2 = kiyafet.
# #314: ozne ve zamirler TURDEN gelir; asagidaki sabitler female render'idir
# (eski metinlerle birebir ayni).
DRESS_SOUTH_TMPL = ("Dress the {subject} in the first image in the outfit shown in the second image. "
                    "Keep {poss} {parts}, standing pose, framing and background exactly; "
                    "only the clothing changes.")
DRESS_DIR_TMPL = ("Put the outfit worn by the {subject} in the second image onto the {subject} in the first image. "
                  "Keep the first image's pose, camera angle, {parts2} and background exactly; "
                  "only the clothing changes.")

# #313: PARCA giydirme istemleri - Gorsel 1 = o anki South, Gorsel 2 = parca gorseli.
# Her parca bir onceki adimin ciktisinin ustune eklenir, bu yuzden "all her other
# clothing exactly" cumlesi sart (yoksa model onceki parcayi siliyor).
# #331 equip testi: 8 ardisik giydirmede kadraj adim adim yaklasip bacaklari
# kesiyordu (cizme/corap kayboldu) - tam boy + ayni kamera mesafesi kilidi.
_KEEP_REST_TMPL = ("keep {poss} {parts}, standing pose, the full-body framing from head to feet at "
                   "the same camera distance (do not zoom in, do not crop), background and all "
                   "{poss} other clothing and items exactly, including any headwear, crown or "
                   "accessories already worn")
_PIECE_TMPL = {
    "set":       "Dress the {subject} in the first image in the complete outfit shown in the second image; "
                 "%s; only that outfit changes.",
    "top":       "Put the top garment from the second image on the {subject} in the first image; "
                 "%s; only add or replace that garment.",
    "bottom":    "Put the bottom garment from the second image on the {subject} in the first image; "
                 "%s; only add or replace that garment.",
    "socks":     "Put the socks from the second image on the legs of the {subject} in the first image; "
                 "%s; only add or replace that garment.",
    "shoes":     "Put the shoes from the second image on the feet of the {subject} in the first image; "
                 "%s; only add or replace that garment.",
    "hat":       "Put the hat from the second image on the head of the {subject} in the first image; "
                 "%s; only add or replace that headwear.",
    "headgear":  "Put the head accessory from the second image on the head of the {subject} in the first image, "
                 "keeping any hat or crown already worn; %s; only add that head accessory.",
    "accessory": "Make the {subject} in the first image wear the accessory from the second image; "
                 "%s; only add that accessory.",
    "weapon":    "Make the {subject} in the first image hold the weapon from the second image in {hands} "
                 "in a natural ready grip; %s; only add the weapon.",
    "other":     "Add the item from the second image to the {subject} in the first image; "
                 "%s; only add that item.",
}
# #313: parcalarin uygulanma SIRASI (kategori sirasi) - once giysi, sonra takilar.
PIECE_ORDER = ("set", "top", "bottom", "socks", "shoes", "hat", "headgear", "accessory", "weapon", "other")


def dress_south(kind: str = "", subject: str = "") -> str:
    """#314: SET giydirme istemi (Gorsel 1 = karakter, Gorsel 2 = kiyafet)."""
    return render_kind(DRESS_SOUTH_TMPL, kind, subject)


def dress_dir(kind: str = "", subject: str = "") -> str:
    """#314: yon giydirme istemi (Gorsel 1 = base yonu, Gorsel 2 = giydirilmis South).
    #328: skin yonleri artik bunu KULLANMAZ (_yon_job ile South'tan dondurulur);
    geriye uyumluluk icin duruyor."""
    return render_kind(DRESS_DIR_TMPL, kind, subject)


def piece_prompt(category: str, kind: str = "", subject: str = "") -> str:
    """#313: parcanin kategorisine ozel giydirme istemi. #314: ozne turden."""
    tmpl = _PIECE_TMPL.get(category or "", _PIECE_TMPL["other"])
    return render_kind(tmpl % render_kind(_KEEP_REST_TMPL, kind, subject), kind, subject)


def dress_pieces(kind: str = "", subject: str = "") -> dict:
    """#314: turun butun parca istemleri (istemci/dogrulama icin)."""
    return {c: piece_prompt(c, kind, subject) for c in _PIECE_TMPL}


# geriye uyumluluk: modul sabitleri female render'idir (#314)
DRESS_SOUTH_PROMPT = dress_south(DEFAULT_KIND)
DRESS_DIR_PROMPT = dress_dir(DEFAULT_KIND)
_KEEP_REST = render_kind(_KEEP_REST_TMPL, DEFAULT_KIND)
DRESS_PIECE_PROMPTS = dress_pieces(DEFAULT_KIND)


PORTRAIT_TOP_FRAC = 0.78     # #308: karenin kapsadigi ust yukseklik orani


def _square_top(src: str, dest: str) -> str:
    """#305/#308: vesikalik icin USTTEN kare kirpma.

    Qwen ciktisi 9:16 dikeydir (orn. 752x1344); genislik kadar kare alinca
    yuksekligin yalniz %56'si giriyor ve cene kesiliyordu (#308). Simdi kare
    kenari = min(genislik, %78 yukseklik) degil, DOGRUDAN %78 yukseklik: kare
    genislikten buyukse iki yan, fonun duz gri rengiyle (kose ortalamasi)
    doldurulur. Fon zaten duz oldugu icin dolgu gorunmez.
    """
    from PIL import Image, ImageOps
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with Image.open(src) as f:
        im = f.convert("RGB")
        w, h = im.size
        k = int(round(h * PORTRAIT_TOP_FRAC))
        if k <= w:
            x = (w - k) // 2
            im.crop((x, 0, x + k, k)).save(dest)
            return dest
        # kose renk ortalamasi = fon
        px = im.load()
        pts = [(i, j) for i in (2, 6, 10) for j in (2, 6, 10)] +               [(w - 1 - i, j) for i in (2, 6, 10) for j in (2, 6, 10)]
        r = sum(px[p][0] for p in pts) // len(pts)
        g = sum(px[p][1] for p in pts) // len(pts)
        b = sum(px[p][2] for p in pts) // len(pts)
        pad = (k - w + 1) // 2
        genis = ImageOps.expand(im, border=(pad, 0, pad, 0), fill=(r, g, b))
        x = (genis.size[0] - k) // 2
        genis.crop((x, 0, x + k, k)).save(dest)
    return dest


def generate_base(name: str, n: int = 1) -> str:
    """op: karakterin kimlik prompt'undan YENI aday gorseller (Z-Image).
    Adaylar candidates/ altina duser; kullanici 'Base yap' ile birini secer.
    #299: her aday ayri bir comfy_gen isidir (Karakter Modu = mode 'character',
    sablon/negatif/olcu karakter_adaylari.generate ile birebir ayni)."""
    d = char_dir(name)
    m = meta(name)
    kimlik = ((m.get("prompt") or {}).get("prompt") or "").strip()
    if not kimlik:
        raise ValueError("bu karakterin kayitli kimlik prompt'u yok - yeni adaylari "
                         "Uretim sekmesinden (Karakter Modu) uretip 'Adaylara ekle' ile ekle")
    _c, _mk, _sf, _wa, _yu = _tools()
    from character import karakter_adaylari as KA  # noqa: WPS433
    n = max(1, min(8, int(n or 1)))
    cand = os.path.join(d, "candidates")
    os.makedirs(cand, exist_ok=True)
    kind = "neutral"
    tur, ozne = char_kind(name)                                 # #314
    prof = kind_profile(tur, ozne)
    # KA.generate'in govdesi: kimlik + setin NOTR kiyafeti (#314: tur profilinden;
    # female'de KA.SETS["neutral"] ile ayni metin).
    govde = ", ".join(x for x in (kimlik.strip(" ,"), prof["neutral"].strip(" ,")) if x)
    # #314: female'de prompt2 BOS birakilir - comfy_gen Karakter Modu sablonunu
    # (CHARACTER_PROMPT2) aynen uygular, yani eski davranis degismez. Diger
    # turlerde o sablon "arms at her sides / full body from head to feet" dedigi
    # icin studyo cumlesi burada turden kurulur (KA.studio).
    prompt2 = "" if tur == DEFAULT_KIND else KA.studio(prof["stance"], prof["arms"], prof["body"])
    negatif = KA.NEG + ((", " + prof["neg_extra"]) if prof.get("neg_extra") else "")

    def uret(op_id):
        isler = []
        for i in range(1, n + 1):
            etiket = "%s_%02d" % (kind, i)
            try:
                job = G.submit("image_zimage", govde, prompt2=prompt2, negative=negatif,
                               width=KA.W, height=KA.H, seed=random.randint(1, 2 ** 31),
                               mode="character", client="flow", category=name)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
                continue
            isler.append((job["id"], etiket, _yerlestirici(cand, kind + "_%02d.png")))
            _op(op_id, log="%s kuyrukta (%s)" % (etiket, job["id"][:8]))
        return isler

    return _kuyruk_op("char-base", n, uret)


def _portre_job(name: str, base: str, yon_uret, kind: str = "", subject: str = "") -> dict:
    """#305: tek portre isi (base'ten, Qwen Edit).
    #314: portre istemi ve negatif TURDEN gelir (hayvan/makine icin yakin plan)."""
    R = yon_uret.render(kind_profile(kind, subject))
    return G.submit("edit_qwen", portrait_prompt(kind, subject), negative=R["neg"],
                    seed=random.randint(1, 2 ** 31), turbo=True,
                    image_path=base, mode="free", client="flow", category=name)


def _portre_yerlestir(dest_dir: str):
    """#305: portre ciktisini ustten KARE kirpip bos numarali adaya yazar."""
    def yerlestir(src: str) -> str:
        p = _serbest_ad(dest_dir, "portrait_%02d.png")
        _square_top(src, p)
        return os.path.basename(p)
    return yerlestir


def generate_portrait(name: str, n: int = 2) -> str:
    """op: base'ten KARE vesikalik portre adaylari (Qwen Edit + ustten kare kirpma).
    #299: her portre ayri bir comfy_gen isidir."""
    d = char_dir(name)
    base = base_image(name)
    _c, _mk, _sf, _wa, yon_uret = _tools()
    tur, ozne = char_kind(name)                       # #314
    dest = os.path.join(d, "portrait")
    os.makedirs(dest, exist_ok=True)
    n = max(1, min(8, int(n or 1)))

    def uret(op_id):
        isler = []
        for i in range(1, n + 1):
            etiket = "portre %d" % i
            try:
                job = _portre_job(name, base, yon_uret, tur, ozne)      # #314
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
                continue
            yer = _portre_yerlestir(dest)
            if n == 1:
                # #309: tek aday = otomatik kabul (kural: tek adaysa secici yok);
                # portrait.png dolar, ust kutuda hemen gorunur.
                def yer_kabul(src, _yer=yer):
                    ad = _yer(src)
                    try:
                        pick(name, "portrait/" + ad, "portrait")
                    except Exception as e:
                        _op(op_id, log="portre kabul edilemedi: %s" % str(e)[:120])
                    return ad
                yer = yer_kabul
            isler.append((job["id"], etiket, yer))
            _op(op_id, log="%s kuyrukta (%s)" % (etiket, job["id"][:8]))
        return isler

    return _kuyruk_op("char-portrait", n, uret)


# ------------------------------------------------- #305 otomatik hat + skinler
def _tmp_dir() -> str:
    """#311: is ciktilarinin gecici kopyalari; 1 saatten eski dosyalar silinir."""
    d = os.path.join(root(), "_tmp")
    os.makedirs(d, exist_ok=True)
    esik = time.time() - 3600
    try:
        for a in os.listdir(d):
            fp = os.path.join(d, a)
            try:
                if os.path.isfile(fp) and os.path.getmtime(fp) < esik:
                    os.remove(fp)
            except OSError:
                pass
    except OSError:
        pass
    return d


def _bekle(op_id: str, job: dict, etiket: str, timeout: int = 3 * 3600) -> str:
    """#305: tek comfy_gen isini bekler, ciktisini doner, is kaydini siler.

    #311: delete_job ciktiyi da siliyordu ve cagiran kopyalamaya kalkinca
    "dosya yok" aliyordu (kiyafet/skin/duzenle akislari).
    #314: cikti artik KOPYALANMIYOR, KESILIYOR: dosya generated/ altindan
    <root>/_tmp/ icine TASINIR, sonra is kaydi remove_file=False ile silinir -
    yani dosya hicbir anda "silinmis ama yerlestirilmemis" olmaz. Donen yol
    gecici dosyadir; cagiran onu hedefe kopyalar/cevirir (_tmp saatte temizlenir).
    """
    jid = job["id"]
    tmp = ""
    try:
        src = _await_job(jid, op_id, etiket, timeout)
        tmp = os.path.join(_tmp_dir(), "%s_%s%s" % (jid[:8], uuid.uuid4().hex[:6],
                                                    os.path.splitext(src)[1] or ".png"))
        _tasi_dene(src, tmp)                         # KES (kopyalama yok)
        return tmp
    finally:
        _is_sil(jid, bool(tmp))                      # tasindiysa dosyaya dokunma


def _tasi_dene(src: str, dst: str, sure: float = 30.0) -> None:
    """#328 (buyucu_cubbesi): comfy_gen isi "done" olur olmaz kucuk resim is
    parcacigi (comfy_gen.thumb) ciktiyi PIL ile aciyor; biz ayni anda tasimaya
    kalkinca Windows "[WinError 32] dosya baska bir islem tarafindan
    kullaniliyor" veriyordu ve kiyafet/skin isi bosa gidiyordu. Kilit gecici
    (thumb birkac yuz ms surer): PermissionError'da 0,5 sn arayla `sure`
    saniyeye kadar yeniden denenir, sonra hata oldugu gibi yukari cikar.
    """
    t0 = time.time()
    while True:
        try:
            shutil.move(src, dst)
            return
        except PermissionError:
            if time.time() - t0 >= sure:
                raise
            time.sleep(0.5)


def _adim_sonu(op_id: str, i: int, ok: bool, mesaj: str) -> None:
    with _ops_lock:
        _ops[op_id]["ok" if ok else "failed"] += 1
    _op(op_id, done=i, log=mesaj)


def run_pipeline(name: str, steps: list[str] | None = None) -> str:
    """#305: otomatik hat (op kind `char-pipeline`) - BASE SECILDIKTEN SONRA.

    Adimlar: portrait (1) / story (1) / dirs (7x1); hepsi otomatik kabul edilir,
    onay yok.

    #314: BAGIMSIZ ComfyUI isleri (portre + 7 yon; hepsi yalniz base'e bagli)
    op basinda TEK SEFERDE kuyruga birakilir - kullanici Sira ekraninda 8 isi
    birden gorur (eskiden her is bir oncekinin bitmesini bekledigi icin sirada
    tek is gorunuyor, "hicbir sey olmuyor" saniliyordu). Ciktilar yine SIRAYLA
    toplanir (_bekle); Ollama'li hikaye adimi isler kuyruktayken koser.
    Skin uretimi SIRALI kalir (her parca bir oncekinin South'una biner).
    """
    d = char_dir(name)
    secili = [s for s in (steps or PIPELINE_STEPS) if s in PIPELINE_STEPS]
    if not secili:
        raise ValueError("adim secilmedi")
    total = (1 if "portrait" in secili else 0) + (1 if "story" in secili else 0) \
        + (7 if "dirs" in secili else 0)
    op_id = _op_new("char-pipeline", total)
    _set_pipeline(name, status="running", op=op_id, step=secili[0], error="",
                  started=datetime.now().isoformat(timespec="seconds"), finished="")

    def calis():
        _c, _mk, _sf, _wa, yon_uret = _tools()
        tur, ozne = char_kind(name)                      # #314
        yonler = [x for x in DIR_IDS if x != "front"]
        i = 0
        try:
            # --- 0 BAGIMSIZ ISLERI KUYRUGA BIRAK (#314): portre + 7 yon
            base = base_image(name) if ("portrait" in secili or "dirs" in secili) else ""
            portre_is, portre_hata = None, ""
            if "portrait" in secili:
                try:
                    portre_is = _portre_job(name, base, yon_uret, tur, ozne)
                    _op(op_id, log="portre kuyrukta (%s)" % portre_is["id"][:8])
                except Exception as e:
                    portre_hata = str(e)[:200]
            yon_isler = []
            if "dirs" in secili:
                dr = dirs_root(d, BASE_SKIN)
                os.makedirs(dr, exist_ok=True)
                if not os.path.isfile(os.path.join(dr, "front.png")):
                    shutil.copy(base, os.path.join(dr, "front.png"))
                for y in yonler:
                    try:
                        job = _yon_job(name, base, y, yon_uret, tur, ozne)
                        yon_isler.append((y, job, ""))
                        _op(op_id, log="yon %s kuyrukta (%s)" % (y, job["id"][:8]))
                    except Exception as e:
                        yon_isler.append((y, None, str(e)[:200]))
            kuyruk = (1 if portre_is else 0) + len([1 for _y, j, _e in yon_isler if j])
            _op(op_id, message="%d is kuyruga girdi (toplam %d adim)" % (kuyruk, total))
            # --- 1 portre (1 adet, ustten kare) -> otomatik kabul
            if "portrait" in secili:
                i += 1
                _set_pipeline(name, step="portrait")
                _op(op_id, message="%d/%d portre" % (i, total))
                try:
                    if not portre_is:
                        raise ValueError(portre_hata or "portre isi kuyruga girmedi")
                    src = _bekle(op_id, portre_is, "portre")
                    aday = _serbest_ad(os.path.join(d, "portrait"), "portrait_%02d.png")
                    _square_top(src, aday)
                    pick(name, _rel(d, aday), "portrait")
                except Exception as e:
                    _adim_sonu(op_id, i, False, "portre: %s" % str(e)[:200])
                else:
                    _adim_sonu(op_id, i, True, "portre -> %s" % PORTRAIT_REL)
            # --- 2 hikaye (Ollama, 1 oneri) -> otomatik kabul
            #     ComfyUI isleri kuyrukta beklerken koser (ayri motor).
            if "story" in secili:
                i += 1
                _set_pipeline(name, step="story")
                _op(op_id, message="%d/%d hikaye (Ollama)" % (i, total))
                try:
                    res = _enrich_text(name, op_id=op_id)
                    pid = _add_proposal(name, res.get("card") or "", res.get("model") or "")
                    accept_proposal(name, pid)
                except Exception as e:
                    _adim_sonu(op_id, i, False, "hikaye: %s" % str(e)[:200])
                else:
                    _adim_sonu(op_id, i, True, "hikaye -> kart (oneri %s KABUL)" % pid)
            # --- 3 yedi yon (her biri 1 aday, isler ZATEN kuyrukta) -> otomatik kabul
            if "dirs" in secili:
                _set_pipeline(name, step="dirs")
                dr = dirs_root(d, BASE_SKIN)
                for y, job, hata in yon_isler:
                    i += 1
                    _op(op_id, message="%d/%d yon %s" % (i, total, y))
                    try:
                        if not job:
                            raise ValueError(hata or "yon isi kuyruga girmedi")
                        src = _bekle(op_id, job, "yon %s" % y)
                        _convert(src, os.path.join(dr, "%s.png" % y))
                    except Exception as e:
                        _adim_sonu(op_id, i, False, "%s: %s" % (y, str(e)[:200]))
                    else:
                        _adim_sonu(op_id, i, True, "%s -> %s/%s.png" % (y, _rel(d, dr), y))
        except Exception as e:
            _set_pipeline(name, status="error", step="", error=str(e)[:300],
                          finished=datetime.now().isoformat(timespec="seconds"))
            raise
        _set_pipeline(name, status="done", step="",
                      finished=datetime.now().isoformat(timespec="seconds"))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def rebuild(name: str, steps: list[str] | None = None) -> str:
    """#305: POST /pipeline/rebuild - varsayilan portrait+story+dirs."""
    return run_pipeline(name, steps or list(PIPELINE_STEPS))


# ------------------------------------------------------------ #305 Duzenle
def _edit_target(name: str, target: str) -> tuple[str, str, str]:
    """Duzenleme hedefi -> (kaynak mutlak yol, kabul rel yolu, yedek klasoru)."""
    d = char_dir(name)
    t = (target or "").strip()
    if t == "base":
        return base_image(name), BASE_REL, "candidates"
    if t == "portrait":
        p = os.path.join(d, PORTRAIT_REL)
        if not os.path.isfile(p):
            raise ValueError("portre yok - once portre uret")
        return p, PORTRAIT_REL, "portrait"
    if t.startswith("dir:") or t.startswith("skin:"):
        if t.startswith("skin:"):
            _s, slug, y = (t.split(":", 2) + ["", ""])[:3]
            slug = skin_slug(slug)
        else:
            slug, y = BASE_SKIN, t.split(":", 1)[1]
        if y not in DIR_IDS:
            raise ValueError("bilinmeyen yon: %s" % y)
        dr = dirs_root(d, slug)
        p = os.path.join(dr, "%s.png" % y)
        if not os.path.isfile(p):
            raise ValueError("'%s' yonu kabul edilmemis - once bir aday sec" % y)
        return p, _rel(d, p), _rel(d, dr)
    raise ValueError("bilinmeyen hedef: %s" % target)


def edit(name: str, target: str, prompt: str) -> str:
    """#305: op kind `char-edit` - kabul edilmis gorseli kullanicinin cumlesiyle
    duzeltir (edit_qwen), sonucu OTOMATIK KABUL eder ve eskisini geri alinabilsin
    diye aday olarak saklar. Base duzenlenince 2-4. adimlar YENIDEN KOSMAZ."""
    d = char_dir(name)
    prompt = (prompt or "").strip()
    if not prompt:
        raise ValueError("duzeltme cumlesi bos")
    src, rel, yedek = _edit_target(name, target)
    _c, _mk, _sf, _wa, yon_uret = _tools()
    tur, ozne = char_kind(name)                            # #314
    R = yon_uret.render(kind_profile(tur, ozne))
    op_id = _op_new("char-edit", 1)

    def calis():
        _op(op_id, message="duzenle: %s" % target)
        try:
            job = G.submit("edit_qwen", "%s %s" % (prompt, edit_keep(tur, ozne)), negative=R["neg"],
                           seed=random.randint(1, 2 ** 31), turbo=True, image_path=src,
                           mode="free", client="flow", category=name)
            out = _bekle(op_id, job, "duzenle %s" % target)
            # eski kabul edilen gorsel aday olarak saklanir (geri alinabilsin)
            if target == "base":
                onceki = _serbest_ad(os.path.join(d, "candidates"), "base_prev_%02d.png")
            elif target == "portrait":
                onceki = _serbest_ad(os.path.join(d, "portrait"), "portrait_%02d.png")
            else:
                y = rel.rsplit("/", 1)[1][:-4]
                onceki = _serbest_ad(os.path.join(d, yedek), y + "_%02d.png")
            shutil.copy(src, onceki)
            if target == "portrait":
                _square_top(out, os.path.join(d, rel))
            elif target == "base":
                _accept_base(name, out)
            else:
                _convert(out, os.path.join(d, rel))
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log="%s: %s" % (target, str(e)[:220]))
            raise
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = {"target": target, "file": rel,
                                     "previous": _rel(d, onceki)}
        _op(op_id, done=1, log="%s -> %s (eski: %s)" % (target, rel, _rel(d, onceki)),
            message="bitti")

    _run(op_id, calis)
    return op_id


# ---------------------------------------------------- #305 kiyafet kutuphanesi
# Kiyafetler karakterden BAGIMSIZDIR: <root>/_outfits/<slug>.png + <slug>.json.
# Ayni kiyafet birden cok karaktere giydirilir; kullanici kutuphanede saklar.
# "_" ile basladigi icin list_characters() bu klasoru karakter saymaz.
def outfits_dir(create: bool = False) -> str:
    d = os.path.join(root(), OUTFITS)
    if create:
        os.makedirs(d, exist_ok=True)
    return d


def outfit_path(slug: str) -> str:
    s = _slug(slug)
    if not _SLUG_RE.match(s):
        raise ValueError("gecersiz kiyafet: %s" % slug)
    return os.path.join(outfits_dir(), s + ".png")


def outfit_meta(slug: str) -> dict:
    """#313: kutuphane kaydi - kategorisi olmayan eski kayit "set" sayilir."""
    s = _slug(slug)
    j = _read_json(os.path.join(outfits_dir(), s + ".json"))
    j["slug"] = s
    j["category"] = j.get("category") or DEFAULT_CATEGORY
    j["kind"] = kind_of(j)                      # #314: eski kayit = female
    j["ready"] = os.path.isfile(os.path.join(outfits_dir(), s + ".png"))
    return j


def outfits(category: str = "", kind: str = "") -> dict:
    """#305: GET /outfits - kutuphanedeki kiyafetler.

    #313: `category` doluysa yalniz o kategori doner (bos = hepsi).
    #314: `kind` doluysa yalniz o turun kiyafetleri doner (tur alani olmayan
    eski kiyafetler female sayilir).
    """
    kat = (category or "").strip().lower()
    if kat and kat not in OUTFIT_CATEGORY_IDS:
        raise ValueError("bilinmeyen kiyafet kategorisi: %s" % category)
    tur = kind_id(kind) if (kind or "").strip() else ""          # #314
    d = outfits_dir()
    rows = []
    adlar = sorted(os.listdir(d) if os.path.isdir(d) else [])
    pngler = {a[:-4] for a in adlar if a.lower().endswith(".png")}
    # #311: kuyrukta/basarisiz kiyafetler (json var, png yok) de listelenir -
    # kullanici "urettim ama gorunmuyor" demesin; ready=False ile gelir.
    sluglar = sorted(pngler | {a[:-5] for a in adlar if a.lower().endswith(".json")})
    for slug in sluglar:
        j = _read_json(os.path.join(d, slug + ".json"))
        hazir = slug in pngler
        # #313: kategorisi olmayan eski kayit = "set"
        kat_j = (j.get("category") or DEFAULT_CATEGORY).strip().lower()
        if kat_j not in OUTFIT_CATEGORY_IDS:
            kat_j = DEFAULT_CATEGORY
        if kat and kat_j != kat:
            continue
        tur_j = kind_of(j)                                      # #314
        if tur and tur_j != tur:
            continue
        rows.append({"slug": slug, "name": j.get("name") or slug, "prompt": j.get("prompt") or "",
                     "style": j.get("style") or "", "template": j.get("template") or "",
                     "category": kat_j, "kind": tur_j,          # #314
                     "created": j.get("created") or "", "ready": hazir,
                     "rel": ("%s/%s.png" % (OUTFITS, slug)) if hazir else ""})
    return {"outfits": rows, "dir": d, "category": kat, "kind": tur}


def create_outfit(name: str, prompt: str, style: str = "", template: str = "",
                  category: str = "", kind: str = "") -> dict:
    """#305: op kind `char-outfit` (1 is) - kutuphaneye tek bir kiyafet/parca gorseli.

    Karakter Modu DEGIL, mode "free": sablon insan figuru istiyor, burada
    yalniz kiyafet var.
    #313: `category` (set/top/bottom/...) istemi belirler - giysi kategorileri
    hayalet manken uzerinde, silah/aksesuar/kafalik mankensiz urun fotografi.
    Sablon secildiyse KATEGORI SABLONDAN gelir.
    #314: `kind` (female|male|animal|machine) kayda yazilir ve uretim istemini
    belirler: female/male hayalet manken, animal hayvan mankeni, machine
    mankensiz ek donanim. Sablon secildiyse TUR de sablondan gelir.
    """
    prompt = (prompt or "").strip()
    template = (template or "").strip().lower()
    if template and template not in OUTFIT_TEMPLATE_MAP:
        raise ValueError("bilinmeyen kiyafet sablonu: %s" % template)
    kat = outfit_category(category)                             # #313
    tur = kind_id(kind)                                         # #314
    if template:
        # #312: sablon + kullanicinin eki; ad bossa sablon etiketi
        # #313: sablonun kategorisi kullanicinin secimini EZER
        tpl = OUTFIT_TEMPLATE_MAP[template]
        prompt = ", ".join(x for x in (tpl["prompt"], prompt) if x)
        name = (name or "").strip() or tpl["label"]
        kat = tpl["category"]
        tur = tpl["kind"]                                       # #314
    if not prompt:
        raise ValueError("kiyafet prompt'u gerekiyor (ya da bir sablon sec)")
    style = (style or "").strip().lower()
    if style and style not in OUTFIT_STYLES:
        raise ValueError("bilinmeyen kiyafet stili: %s" % style)
    if style and (kat not in OUTFIT_HOT_CATEGORIES or tur not in ("female", "male")):
        # #313: Hot modifier yalniz giysi kategorilerinde anlamli - sessizce dusurulur
        # #314: ve yalniz female/male giysisinde (hayvan/makine kitinde anlamsiz)
        style = ""
    if style:
        prompt = "%s, %s" % (prompt, OUTFIT_STYLES[style])      # #312 modifier
    slug = _slug(name or prompt)
    if not _SLUG_RE.match(slug):
        raise ValueError("gecersiz kiyafet adi: %s" % name)
    d = outfits_dir(create=True)
    if os.path.isfile(os.path.join(d, slug + ".png")):
        raise ValueError("bu kiyafet zaten var: %s" % slug)
    _write_json(os.path.join(d, slug + ".json"),
                {"slug": slug, "name": (name or slug).strip(), "prompt": prompt,
                 "style": style, "template": template, "category": kat,   # #313
                 "kind": tur,                                             # #314
                 "created": datetime.now().isoformat(timespec="seconds")})
    op_id = _op_new("char-outfit", 1)

    def calis():
        _op(op_id, message="kiyafet: %s (%s/%s)" % (slug, tur, kat))
        try:
            # #313: istem ve negatif kategoriye gore kurulur (#314: + ture gore)
            job = G.submit("image_zimage", outfit_prompt(prompt, kat, tur),
                           negative=outfit_negative(kat, tur),
                           width=OUTFIT_W, height=OUTFIT_H, seed=random.randint(1, 2 ** 31),
                           mode="free", client="flow", category=OUTFITS)
            out = _bekle(op_id, job, "kiyafet %s" % slug)
            _convert(out, os.path.join(d, slug + ".png"))
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log="%s: %s" % (slug, str(e)[:220]))
            raise
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = {"slug": slug, "category": kat,      # #313
                                     "kind": tur,                        # #314
                                     "rel": "%s/%s.png" % (OUTFITS, slug)}
        _op(op_id, done=1, log="%s hazir" % slug, message="bitti")

    _run(op_id, calis)
    return {"slug": slug, "op": op_id, "kind": tur, "category": kat}   # #314


def edit_outfit(slug: str, prompt: str) -> dict:
    """#305: kiyafet gorselini kisa bir cumleyle duzeltir (edit_qwen, otomatik kabul)."""
    prompt = (prompt or "").strip()
    if not prompt:
        raise ValueError("duzeltme cumlesi bos")
    src = outfit_path(slug)
    if not os.path.isfile(src):
        raise ValueError("kiyafet yok: %s" % slug)
    om = outfit_meta(slug)
    kat = om.get("category") or DEFAULT_CATEGORY                     # #313
    tur = kind_of(om)                                                # #314
    mnq = KIND_PROFILES[tur].get("mannequin") or ""
    # #313: mankensiz kategoride "ghost mannequin" cumlesi manken cizdiriyordu
    # #314: manken cumlesi turden gelir (makinede hep mankensiz)
    koru = ("Keep it a product photo of the item alone, no person and no mannequin, same plain light "
            "gray background." if (kat in outfit_prop_categories(tur) or not mnq) else
            "Keep it a product photo of the outfit alone on %s, same plain "
            "light gray background." % mnq)
    op_id = _op_new("char-outfit", 1)

    def calis():
        _op(op_id, message="kiyafet duzenle: %s" % _slug(slug))
        try:
            job = G.submit("edit_qwen", "%s %s" % (prompt, koru),
                           negative=outfit_negative(kat, tur), seed=random.randint(1, 2 ** 31), turbo=True,
                           image_path=src, mode="free", client="flow", category=OUTFITS)
            out = _bekle(op_id, job, "kiyafet duzenle")
            _convert(out, src)
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log=str(e)[:220])
            raise
        with _ops_lock:
            _ops[op_id]["ok"] += 1
        _op(op_id, done=1, message="bitti")

    _run(op_id, calis)
    return {"slug": _slug(slug), "op": op_id}


# #329: baska bir gorselden kiyafet CIKARMA - kisi silinir, uzerindeki kiyafet
# hayalet manken urun fotografi olarak kalir (giysi kategorileri); silah/aksesuar
# gibi mankensiz kategorilerde yalniz o nesne kalir.
EXTRACT_GHOST_TMPL = ("Remove the person from this photo completely and keep only {n} they are wearing, "
                      "shown as an invisible-mannequin product photo: the clothes keep their worn 3D shape "
                      "but the body inside is invisible, so the neck opening, sleeve openings and hem show "
                      "empty space. Front view, centered, plain solid flat uniform light gray seamless "
                      "studio background. Keep every garment's cut, colors, materials, patterns and "
                      "details exactly as in the photo. Do not draw any mannequin, dummy, doll, head, "
                      "face, skin, hair, arms or legs. Photorealistic, sharp focus.")
EXTRACT_PROP_TMPL = ("Keep only {n} from this photo and remove everything else: show it alone as a "
                     "product photo, centered, plain solid flat uniform light gray seamless studio "
                     "background, no person, no mannequin. Keep its exact shape, colors, materials and "
                     "details. Photorealistic, sharp focus.")
# #329: cikarma negatifi - Qwen Edit "ghost mannequin" deyince BEYAZ MANKEN ciziyor
EXTRACT_NEG_EXTRA = "mannequin, dummy, doll, figure, head, face, arms, legs, hands, skin, hair"


def extract_prompt(category: str = DEFAULT_CATEGORY, kind: str = "", note: str = "") -> str:
    """#329: cikarma istemi - kategori/ture gore manken ya da mankensiz."""
    c = category if category in OUTFIT_CATEGORY_IDS else DEFAULT_CATEGORY
    prof = KIND_PROFILES[kind_id(kind)]
    mnq = prof.get("mannequin") or ""
    prop = (c in outfit_prop_categories(kind)) or not mnq
    tmpl = EXTRACT_PROP_TMPL if prop else EXTRACT_GHOST_TMPL
    p = tmpl.format(n=outfit_noun(c, kind), mnq=mnq)
    note = (note or "").strip()
    return ("%s %s" % (p, note)) if note else p


def _extract_source(job_id: str = "", rating: str = "", stage: str = "", item_id: str = "") -> str:
    """#329: kaynak gorsel - comfy_gen isi (her kip) YA DA Jigsaw akisi ogesi
    (incoming/staging/pushed). Yol her zaman sunucu tarafinda cozulur, istemci
    dosya yolu gondermez."""
    if (job_id or "").strip():
        return _job_image(job_id.strip())
    if (item_id or "").strip():
        p = JF.item_path(rating or "hot", stage or "pushed", item_id.strip(), "image")
        if not p:
            raise ValueError("akis ogesi yok: %s/%s/%s" % (rating, stage, item_id))
        return p
    raise ValueError("kaynak gorsel sec (job_id ya da akis ogesi)")


def extract_outfit(name: str, category: str = "", kind: str = "", job_id: str = "",
                   rating: str = "", stage: str = "", item_id: str = "", note: str = "") -> dict:
    """#329: op kind `char-outfit` (1 is) - secili gorseldeki kiyafeti gardiroba cikarir.

    edit_qwen (tek gorsel, kuyruk, mode "free"); cikti geometrisi kaynaktan
    gelir (yatay jigsaw karesi yatay kalir - manken ortada, fon duz gri).
    Kayit create_outfit ile ayni bicimde yazilir (+ `source`), listede ve skin
    birlestiricide diger kiyafetlerden farksizdir.
    """
    kat = outfit_category(category)                             # #313
    tur = kind_id(kind)                                         # #314
    src = _extract_source(job_id, rating, stage, item_id)
    name = (name or "").strip()
    if not name:
        raise ValueError("kiyafet adi gerekiyor")
    slug = _slug(name)
    if not _SLUG_RE.match(slug or ""):
        raise ValueError("gecersiz kiyafet adi: %s" % name)
    d = outfits_dir(create=True)
    if os.path.isfile(os.path.join(d, slug + ".json")):
        raise ValueError("bu kiyafet zaten var: %s (once sil)" % slug)
    kaynak = ("job:%s" % job_id.strip()) if (job_id or "").strip()         else ("flow:%s/%s/%s" % (rating or "hot", stage or "pushed", item_id.strip()))
    _write_json(os.path.join(d, slug + ".json"),
                {"slug": slug, "name": name, "prompt": (note or "").strip(),
                 "style": "", "template": "", "category": kat, "kind": tur,
                 "source": kaynak,                              # #329
                 "created": datetime.now().isoformat(timespec="seconds")})
    op_id = _op_new("char-outfit", 1)

    def calis():
        _op(op_id, message="kiyafet cikar: %s (%s/%s)" % (slug, tur, kat))
        try:
            job = G.submit("edit_qwen", extract_prompt(kat, tur, note),
                           negative="%s, %s" % (outfit_negative(kat, tur), EXTRACT_NEG_EXTRA),
                           seed=random.randint(1, 2 ** 31),
                           turbo=True, image_path=src, mode="free", client="flow", category=OUTFITS)
            out = _bekle(op_id, job, "kiyafet cikar %s" % slug)
            _convert(out, os.path.join(d, slug + ".png"))
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log="%s: %s" % (slug, str(e)[:220]))
            raise
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = {"slug": slug, "category": kat, "kind": tur,
                                     "rel": "%s/%s.png" % (OUTFITS, slug)}
        _op(op_id, done=1, log="%s hazir" % slug, message="bitti")

    _run(op_id, calis)
    return {"slug": slug, "op": op_id, "kind": tur, "category": kat, "source": kaynak}


def delete_outfit(slug: str) -> dict:
    """#305: kiyafeti kutuphaneden siler (giydirilmis skinler kalir)."""
    p = outfit_path(slug)
    say = 0
    for x in (p, os.path.splitext(p)[0] + ".json"):
        try:
            os.remove(x)
            say += 1
        except OSError:
            pass
    return {"deleted": _slug(slug), "files": say}


def outfit_thumb(slug: str, size: int = 360) -> str | None:
    """#305: GET /outfits/thumb - kiyafetin onizlemesi (thumb() ile ayni onbellek)."""
    src = outfit_path(slug)
    return _thumb_file(src, size) if os.path.isfile(src) else None


# ------------------------------------------------------------- #305 skinler
def skins(name: str) -> dict:
    """#305: karakterin skinleri; ILK ELEMAN her zaman `base`.
    #314: her satir karakterin turune gore `anim_modes` tasir (animal/machine:
    yalniz i2v - uygulamada Mixamo/manken dugmeleri gizlenir)."""
    d = char_dir(name)
    m = meta(name)
    tur = kind_of(m)                                    # #314
    kipler = anim_modes(tur)
    out = []
    for r in _skin_rows(d):
        slug = r["slug"]
        kabul, aday, dosya = _dir_state(d, slug)
        parcalar = []                                   # #313: skinin parca slug'lari
        if slug == BASE_SKIN:
            south, outfit_rel, outfit = m.get("base") or "", "", ""
        else:
            outfit_rel = "%s/%s/outfit.png" % (SKINS, slug)
            outfit_rel = outfit_rel if os.path.isfile(os.path.join(d, outfit_rel)) else ""
            fr = "%s/%s/dirs/front.png" % (SKINS, slug)
            south = fr if os.path.isfile(os.path.join(d, fr)) else outfit_rel
            # #305: satirda kutuphanedeki kiyafet SLUG'i doner (tasinmis eski
            # skinlerde kiyafet yok -> ""). #313: parca kombinasyonu da doner.
            sj = _read_json(os.path.join(d, SKINS, slug, "skin.json"))
            outfit = sj.get("outfit") or ""
            parcalar = [str(p) for p in (sj.get("pieces") or [])]
        out.append(dict(r, south=south, outfit=outfit, pieces=parcalar,
                        outfit_rel=outfit_rel, dirs=kabul,
                        kind=tur, anim_modes=kipler,            # #314
                        dir_candidates=aday, dir_files=dosya,
                        anims=_anim_state(d, slug), rev=_rev_of(d, m, slug)))
    return {"name": name, "skins": out, "kind": tur, "subject": subject_of(m),
            "anim_modes": kipler}


def _skin_dir(name: str, skin: str, create: bool = False) -> str:
    slug = skin_slug(skin)
    if slug == BASE_SKIN:
        raise ValueError("base skini sanaldir - base/dirs kullanilir")
    sd = os.path.join(char_dir(name), SKINS, slug)
    if create:
        os.makedirs(os.path.join(sd, "dirs"), exist_ok=True)
        os.makedirs(os.path.join(sd, "anims"), exist_ok=True)
    elif not os.path.isdir(sd):
        raise ValueError("skin yok: %s" % slug)
    return sd


def _piece_rows(pieces, kind: str = "") -> list[dict]:
    """#313: parca slug'larini dogrular ve KATEGORI SIRASINA dizer.

    Sira: set -> top -> bottom -> socks -> shoes -> hat -> headgear ->
    accessory(ler) -> weapon(lar) -> other. Ayni kategoride birden cok parca
    varsa kullanicinin verdigi sira korunur (kararli siralama).
    Bilinmeyen slug -> hata; gorseli hazir olmayan parca -> hata (400).
    #314: `kind` verilirse parcanin turu karakterin turuyle ayni olmali (400).
    """
    tur = kind_id(kind) if (kind or "").strip() else ""
    d = outfits_dir()
    rows, gorulen = [], set()
    for i, p in enumerate(pieces or []):
        s = _slug(p)
        if not _SLUG_RE.match(s or ""):
            raise ValueError("gecersiz parca: %s" % p)
        if s in gorulen:
            continue                                    # ayni parca iki kez secilmis
        gorulen.add(s)
        png = os.path.join(d, s + ".png")
        if not os.path.isfile(png):
            if os.path.isfile(os.path.join(d, s + ".json")):
                raise ValueError("'%s' parcasinin gorseli hazir degil - once uretimi bitsin" % s)
            raise ValueError("kutuphanede boyle bir parca yok: %s" % s)
        m = outfit_meta(s)
        kat = (m.get("category") or DEFAULT_CATEGORY).strip().lower()
        if kat not in OUTFIT_CATEGORY_IDS:
            kat = DEFAULT_CATEGORY
        tur_p = kind_of(m)                                       # #314
        if tur and tur_p != tur:
            raise ValueError("'%s' parcasi %s turu icin - bu karakter %s turunde"
                             % (s, KIND_PROFILES[tur_p]["label"], KIND_PROFILES[tur]["label"]))
        rows.append({"slug": s, "name": m.get("name") or s, "category": kat,
                     "kind": tur_p, "png": png, "sira": i})
    rows.sort(key=lambda r: (PIECE_ORDER.index(r["category"]) if r["category"] in PIECE_ORDER
                            else len(PIECE_ORDER), r["sira"]))
    return rows


def create_skin(name: str, skin_name: str = "", outfit: str = "", pieces=None) -> dict:
    """#305/#313: SKIN = (SET ve/veya PARCALAR) + BASE. op kind `char-skin`.

    1) South: kaynak base/base.png. `outfit` (set) verildiyse once o giydirilir
       (IKI GORSELLI gorev, Gorsel 1 = o anki South, Gorsel 2 = kiyafet gorseli).
    2) #313: `pieces` kategori sirasiyla SIRAYLA uygulanir; her parca yine iki
       gorselli bir duzenleme (Gorsel 1 = o anki South, Gorsel 2 = parca gorseli)
       ve kategoriye ozel istem (DRESS_PIECE_PROMPTS). Her adim front.png'yi
       gunceller, bir sonraki adimin girdisi olur.
    3) #329: yon YOK - skin olusturma South'ta biter. 7 yon skin sayfasindan
       "Eksikleri uret" ile (generate_skin_dirs) South'tan tek gorselli Qwen Edit
       "dondur" isiyle uretilir (#328; base yonleri skin icin girdi degildir).
    Op total = adim sayisi. Skin slug'i: skin_name > set slug'i > parcalardan
    turetilir ("top_x+bottom_y"); ayni slug tek skin (yeniden uretmek icin sil).
    """
    d = char_dir(name)
    base = base_image(name)
    tur, ozne = char_kind(name)                                 # #314
    set_slug, ok = "", {}
    kiyafet = ""
    if (outfit or "").strip():
        set_slug = _slug(outfit)
        if not _SLUG_RE.match(set_slug or ""):
            raise ValueError("gecersiz kiyafet: %s" % outfit)
        kiyafet = outfit_path(set_slug)
        if not os.path.isfile(kiyafet):
            if os.path.isfile(os.path.splitext(kiyafet)[0] + ".json"):
                raise ValueError("'%s' kiyafetinin gorseli hazir degil - once uretimi bitsin" % set_slug)
            raise ValueError("kutuphanede boyle bir kiyafet yok: %s" % set_slug)
        ok = outfit_meta(set_slug)
        if kind_of(ok) != tur:                                  # #314
            raise ValueError("'%s' kiyafeti %s turu icin - bu karakter %s turunde"
                             % (set_slug, KIND_PROFILES[kind_of(ok)]["label"],
                                KIND_PROFILES[tur]["label"]))
    prc = _piece_rows(pieces, tur)                              # #313/#314
    if not set_slug and not prc:
        raise ValueError("kiyafet (set) ya da en az bir parca sec")
    # #313: slug - skin adi > set slug'i > parcalardan turetme
    slug = _slug(skin_name) if (skin_name or "").strip() else ""
    if not slug:
        slug = set_slug or _slug("+".join(r["slug"] for r in prc))
    if not _SLUG_RE.match(slug or ""):
        raise ValueError("gecersiz skin adi: %s" % (skin_name or outfit))
    if slug == BASE_SKIN:
        raise ValueError("'base' ayrilmis bir skin adidir")
    if os.path.isdir(os.path.join(d, SKINS, slug)):
        raise ValueError("bu skin zaten var: %s (once sil)" % slug)
    # #313: gorunen ad - kullanicinin adi > setin adi > parca adlari
    ad = (skin_name or "").strip() or (ok.get("name") or "").strip() \
        or " + ".join(r["name"] for r in prc) or slug
    sd = _skin_dir(name, slug, create=True)
    parca_sluglari = [r["slug"] for r in prc]
    _write_json(os.path.join(sd, "skin.json"),
                {"slug": slug, "name": ad, "outfit": set_slug,
                 "pieces": parca_sluglari,                       # #313
                 "kind": tur,                                    # #314
                 "prompt": ok.get("prompt") or "",
                 "created": datetime.now().isoformat(timespec="seconds")})
    dr = os.path.join(sd, "dirs")
    front = os.path.join(dr, "front.png")
    # #313: South adimlari - once set (varsa), sonra parcalar kategori sirasiyla
    adimlar = []
    if set_slug:
        adimlar.append(("set %s" % set_slug, kiyafet, dress_south(tur, ozne)))    # #314
    for r in prc:
        adimlar.append(("%s %s" % (r["category"], r["slug"]), r["png"],
                        piece_prompt(r["category"], tur, ozne)))                  # #314
    # #329: skin olusturma YALNIZ South uretir; 7 yon kullanicinin skin
    # sayfasindaki "Eksikleri uret" dugmesiyle (POST /skins/dirs) South'tan
    # dondurulur - kullanici South'u begenmeden 7 yon kuyrugu harcanmaz.
    toplam = len(adimlar)
    op_id = _op_new("char-skin", toplam)

    def calis():
        i = 0
        kaynak = base                       # ilk girdi base; sonra o anki South
        for etiket, png, pr in adimlar:
            i += 1
            _op(op_id, message="%d/%d South: %s" % (i, toplam, etiket))
            try:
                out = _bekle(op_id, _giydir_job(name, kaynak, png, pr), "South %s" % etiket)
                _convert(out, front)
            except Exception as e:
                _adim_sonu(op_id, i, False, "South %s: %s" % (etiket, str(e)[:220]))
                _op(op_id, message="bitti")
                return
            kaynak = front                  # sonraki parca bunun ustune biner
            _adim_sonu(op_id, i, True, "%s -> skins/%s/dirs/front.png" % (etiket, slug))
        try:
            _convert(front, os.path.join(sd, "outfit.png"))      # kiyafet referansi = nihai South
        except Exception:
            pass
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return {"name": name, "slug": slug, "op": op_id, "steps": len(adimlar), "total": toplam,
            "outfit": set_slug, "pieces": parca_sluglari, "kind": tur}       # #314


def _giydir_job(name: str, hedef: str, kiyafet: str, prompt: str) -> dict:
    """#305: IKI GORSELLI giydirme isi (comfy_gen kuyrugu).

    Yuva adlari comfy_gen.workflow_inputs(SKIN_WORKFLOW)'dan gelir: is akisinda
    dugum sirasi Gorsel 1 = "target pose", Gorsel 2 = "outfit reference".
    Cikti geometrisi Gorsel 1'den turer (VAEEncode onun uzerinden), yani
    prompt'taki "first image" giydirilecek kadin, "second image" kiyafettir.
    """
    if not os.path.isfile(hedef):
        raise ValueError("giydirilecek gorsel yok: %s" % os.path.basename(hedef))
    if not os.path.isfile(kiyafet):
        raise ValueError("kiyafet gorseli yok: %s" % os.path.basename(kiyafet))
    _ensure_skin_workflow()
    return G.submit(SKIN_DIR_TASK, prompt, negative="",
                    seed=random.randint(1, 2 ** 31), turbo=True, mode="free",
                    client="flow", category=name,
                    inputs={"image_1": {"path": hedef}, "image_2": {"path": kiyafet}})


def generate_skin_dirs(name: str, skin: str, dirs: list[str], n: int = 1) -> str:
    """#305: POST /skins/dirs - secili yonlerin adaylarini uretir.

    #328: kaynak giydirilmis SOUTH (skins/<slug>/dirs/front.png), is base
    yonleriyle AYNI tek gorselli Qwen Edit "dondur" isidir (_yon_job). Base
    yonleri artik girdi degildir.
    """
    char_dir(name)
    sd = _skin_dir(name, skin)
    slug = skin_slug(skin)
    tur, ozne = char_kind(name)                                  # #314
    hedef = [y for y in (dirs or []) if y in DIR_IDS and y != "front"]
    if not hedef:
        raise ValueError("yon secilmedi (front kiyafetin kendisidir)")
    n = max(1, min(8, int(n or 1)))
    dr = os.path.join(sd, "dirs")
    os.makedirs(dr, exist_ok=True)
    # #328: kaynak giydirilmis SOUTH (yoksa nihai South kopyasi outfit.png)
    ref = os.path.join(dr, "front.png")
    if not os.path.isfile(ref):
        ref = os.path.join(sd, "outfit.png")
    if not os.path.isfile(ref):
        raise ValueError("'%s' skininin South'u yok - once skini uret" % slug)
    _c, _mk, _sf, _wa, yon_uret = _tools()

    def uret(op_id):
        isler = []
        for y in hedef:
            for i in range(1, n + 1):
                etiket = "%s/%s_%02d" % (slug, y, i)
                try:
                    job = _yon_job(name, ref, y, yon_uret, tur, ozne)      # #328
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, log="%s kuyruga girmedi: %s" % (etiket, str(e)[:200]))
                    continue
                isler.append((job["id"], etiket, _yerlestirici(dr, y + "_%02d.png")))
                _op(op_id, log="%s kuyrukta (%s)" % (etiket, job["id"][:8]))
        return isler

    return _kuyruk_op("char-skin-dirs", len(hedef) * n, uret)


def delete_skin(name: str, skin: str) -> dict:
    """#305: skini komple siler (base silinemez)."""
    slug = skin_slug(skin)
    if slug == BASE_SKIN:
        raise ValueError("base skini silinemez")
    sd = _skin_dir(name, slug)
    shutil.rmtree(sd, ignore_errors=True)
    return {"deleted": slug}


# rev7: SAM'e silahi da sor. Ana kavram "kadin + tuttugu silah" olur; ayrica
# silahin kendisi sorulur, govdeye degen parcalar birlestirilir, kopuk ama
# kucuk maskeler (ucan ok) korunur.
PROP_CONCEPTS = {
    "sword": ("woman holding a sword", "sword"),
    "dagger": ("woman holding a dagger", "dagger", "knife"),
    "staff": ("woman holding a staff", "staff"),
    "bow": ("woman holding a bow", "bow", "arrow"),
    "spear": ("woman holding a spear", "spear"),
    "hammer": ("woman holding a hammer", "hammer"),
    "shield": ("woman holding a shield", "shield", "sword"),
}


def sam_prompt(prop: str) -> str:
    return ",".join(PROP_CONCEPTS.get((prop or "").strip().lower(), ("woman",)))


# ------------------------------------------------------------- 3 animasyon
def mixamo(q: str = "", limit: int = 100, offset: int = 0) -> dict:
    """Mixamo arsivinde klip arar. [{name, hash, filename}] - sayfali."""
    common, _mk, _sf, _wa, _yu = _tools()
    d = str(common.MIXAMO_DIR)
    try:
        adlar = sorted(a for a in os.listdir(d) if a.lower().endswith(".fbx"))
    except OSError:
        return {"items": [], "total": 0, "offset": 0, "limit": limit, "dir": d}
    terimler = [t for t in re.split(r"\s+", (q or "").strip().lower()) if t]
    rows = []
    for a in adlar:
        mm = re.match(r"^(.*?)\s*\[([0-9a-f]+)\]\.fbx$", a, re.I)
        ad = (mm.group(1) if mm else os.path.splitext(a)[0]).strip()
        hs = mm.group(2) if mm else ""
        if terimler and not all(t in a.lower() for t in terimler):
            continue
        rows.append({"name": ad, "hash": hs, "filename": a})
    total = len(rows)
    offset, limit = max(0, int(offset or 0)), max(1, min(500, int(limit or 100)))
    return {"items": rows[offset:offset + limit], "total": total, "offset": offset,
            "limit": limit, "dir": d}


def _versions(clip_dir: str) -> list[dict]:
    out = []
    for a in sorted(os.listdir(clip_dir) if os.path.isdir(clip_dir) else []):
        if not _VER_RE.match(a) or not os.path.isdir(os.path.join(clip_dir, a)):
            continue
        vd = os.path.join(clip_dir, a)
        wj = _read_json(os.path.join(vd, "wan.json"))
        out.append({"v": a, "has_wan": os.path.isfile(os.path.join(vd, "wan.mp4")),
                    "has_manken": os.path.isfile(os.path.join(vd, "manken.mp4")),
                    "seed": wj.get("seed"), "mode": wj.get("mode") or "mixamo",
                    "padding": wj.get("padding"), "prompt": (wj.get("pose_prompt") or wj.get("prompt") or "")[:200],
                    "created": wj.get("at") or ""})
    return out


def _next_version(clip_dir: str) -> str:
    nums = [int(v["v"][1:]) for v in _versions(clip_dir)]
    return "v%02d" % ((max(nums) + 1) if nums else 1)


def anims_of(name: str, y: str, skin: str = "") -> dict:
    """Bir yonun klipleri, surumleri ve rel yollari (rev4: istemci yol hesaplamaz).
    #305: `skin` bos = base (anims/), doluysa skins/<slug>/anims/."""
    if y not in ALL_DIRS:
        raise ValueError("bilinmeyen yon: %s" % y)
    d = char_dir(name)
    cfg = anims(name)
    ak = anims_root(d, skin)
    yd = os.path.join(ak, y)
    adlar = sorted(a for a in (os.listdir(yd) if os.path.isdir(yd) else [])
                   if os.path.isdir(os.path.join(yd, a)))
    for c in (cfg.get("clips") or {}):
        if c not in adlar:
            adlar.append(c)
    rows = []
    for clip in adlar:
        cd = os.path.join(yd, clip)
        vs = _versions(cd)
        acc = (_read_json(os.path.join(cd, "meta.json")) or {}).get("accepted") or ""
        if acc and acc not in [v["v"] for v in vs]:
            acc = ""
        base = "%s/%s/%s" % (_rel(d, ak), y, clip)
        for v in vs:
            v["rel_wan"] = "%s/%s/wan.mp4" % (base, v["v"]) if v["has_wan"] else ""
            v["rel_manken"] = "%s/%s/manken.mp4" % (base, v["v"]) if v["has_manken"] else ""
        sprite = os.path.isfile(os.path.join(cd, "anim.webp"))
        rows.append({
            "clip": clip, "dir": y, "versions": vs, "accepted": acc,
            "has_sprite": sprite, "has_manken": os.path.isfile(os.path.join(cd, "manken.mp4")),
            "rel_dir": base,
            "rel_webp": "%s/anim.webp" % base if sprite else "",
            "rel_sheet": "%s/sheet.png" % base if os.path.isfile(os.path.join(cd, "sheet.png")) else "",
            "rel_accepted_wan": "%s/%s/wan.mp4" % (base, acc) if acc else "",
            "sprite": _read_json(os.path.join(cd, "sprite.json")) if sprite else {},
            "fbx": ((cfg.get("clips") or {}).get(clip) or {}).get("fbx") or "",
            "pose": ((cfg.get("clips") or {}).get(clip) or {}).get("pose") or "",
        })
    try:
        ref = _ref_image(name, y, skin)
    except ValueError:
        ref = ""
    return {"name": name, "dir": y, "skin": skin_slug(skin), "azimuth": DIR_AZ.get(y, 0),
            "accepted_image": bool(ref),
            "rel_image": os.path.relpath(ref, d).replace("\\", "/") if ref else "",
            "clips": rows}


def _ref_image(name: str, y: str, skin: str = "") -> str:
    """Yonun kabul edilen gorseli (#305: skinin yon gorseli Wan referansidir).
    base -> base/base.png, portrait -> portrait/portrait.png."""
    d = char_dir(name)
    if y in PSEUDO_DIRS:
        m = meta(name)
        rel = (m.get("base") or "") if y == "base" else (m.get("portrait") or "")
        p = os.path.join(d, rel) if rel else ""
        if not p or not os.path.isfile(p):
            raise ValueError("'%s' icin kabul edilmis gorsel yok" % y)
        return p
    p = os.path.join(dirs_root(d, skin), "%s.png" % y)
    if not os.path.isfile(p):
        raise ValueError("'%s' yonu kabul edilmemis - once bir aday sec" % y)
    return p


def _canvas_for(cfg: dict, padding: float) -> int:
    return BIG_CANVAS if padding >= 0.2 else int(cfg.get("canvas") or 640)


def _padding_of(name: str, padding) -> float:
    if padding is None or padding == "":
        padding = (meta(name) or {}).get("padding") or 0.0
    try:
        padding = float(padding)
    except Exception:
        padding = 0.0
    return min(PADDINGS, key=lambda p: abs(p - padding))


def render_manken(name: str, clips: list[str], dirs: list[str], skin: str = "") -> str:
    """op: Blender manken videolari. #299: CPU isi olsa da seridi ALIR -
    kullanicinin kurali "istisnasiz her is siraya girer, ust uste binmesin".
    #305: `skin` bos = base (anims/), doluysa skins/<slug>/anims/.
    #314: manken insansi iskelettir - animal/machine turunde 400."""
    _kip_dogrula(name, "mixamo")                   # #314
    d = char_dir(name)
    ak = anims_root(d, skin)
    cfg = anims(name)
    tanim = cfg.get("clips") or {}
    clips = [c for c in (clips or list(tanim)) if c in tanim]
    hedef = [y for y in (dirs or list(DIR_IDS)) if y in ALL_DIRS]
    if not clips or not hedef:
        raise ValueError("klip veya yon secilmedi")
    _c, manken, _sf, _wa, _yu = _tools()
    isler = [(y, c) for y in hedef for c in clips]
    op_id = _op_new("char-manken", len(isler))

    def calis():
        # #299: Blender render'i GPU isiyle ust uste binmesin diye tek serit.
        with gpu_lane.hold("karakter manken: %s (%d)" % (name, len(isler)), kind="cpu",
                           op_id=op_id, total=len(isler)):
            for i, (y, c) in enumerate(isler, 1):
                cd = os.path.join(ak, y, c)                       # #305
                os.makedirs(cd, exist_ok=True)
                _op(op_id, message="manken %d/%d  %s/%s" % (i, len(isler), y, c))
                try:
                    _manken_render(manken, cfg, tanim, c, cd, DIR_AZ.get(y, 0),
                                   log=lambda s, _y=y, _c=c: _op(op_id, message="%s/%s: %s" % (_y, _c, s)))
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s/%s: %s" % (y, c, str(e)[:200]))
                    continue
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i, log="%s/%s manken hazir" % (y, c))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def _manken_render(manken, cfg: dict, tanim: dict, clip: str, clip_dir: str,
                   azimuth: float, padding: float = 0.0, force: bool = False, log=print) -> str:
    """Klip duzeyinde manken videosu (ayni FBX + ayni azimut + ayni dolgu = ayni
    video, tekrar render edilmez). Grubun diger klipleri kadraja dahil (ortak
    tuval). Dolgu 0 degilse ayri dosya: manken_p10.mp4 gibi."""
    ad = "manken.mp4" if not padding else "manken_p%02d.mp4" % int(round(padding * 100))
    out = os.path.join(clip_dir, ad)
    if os.path.isfile(out) and not force:
        return out
    c = tanim.get(clip) or {}
    if not c.get("fbx"):
        raise ValueError("klip '%s' icin fbx tanimli degil" % clip)
    gruplar = cfg.get("groups") or {}
    grup = next((g for g, cs in gruplar.items() if clip in cs), "")
    kardes = [tanim[x]["fbx"] for x in gruplar.get(grup, []) if x != clip and x in tanim and tanim[x].get("fbx")]
    manken.render(c["fbx"], out, azimuth=azimuth,
                  canvas=_canvas_for(cfg, padding),
                  pad=float(cfg.get("pad") or 0.06) + float(padding or 0.0),
                  fps=int(cfg.get("fps") or 30),
                  prop=c.get("prop", cfg.get("prop", "")),
                  prop_len=float(c.get("prop_len", cfg.get("prop_len", 1.0))),
                  bbox_fbx=kardes, log=log)
    return out


def _kip_dogrula(name: str, mode: str) -> str:
    """#314: animasyon kipi turle uyumlu mu? Degilse ValueError (HTTP 400).

    manken/Mixamo hatti insansi bir iskelet (Blender manken + Wan Animate 2)
    kullanir; hayvan ve makine karakterlerde yalniz saf i2v anlamlidir.
    """
    kip = (mode or "").strip().lower() or "mixamo"
    kip = "mixamo" if kip in ("manken", "mixamo") else kip
    tur = kind_of(meta(name))
    if kip not in anim_modes(tur):
        raise ValueError("%s turunde Mixamo/manken animasyonu yok - yalniz i2v "
                         "(insansi iskelet gerektiriyor)" % KIND_PROFILES[tur]["label"])
    return kip


def animate(name: str, y: str, clips: list[str] | None = None, n: int = 1, mode: str = "mixamo",
            prompt: str = "", clip: str = "", engine: str = "", padding=None, skin: str = "") -> str:
    """op: her klip icin n YENI surum (vNN).

    mode="mixamo"  Blender manken -> Wan Animate 2 (gpu_lane, tek tek)
    mode="i2v"     yonun kabul edilen gorselinden saf i2v (comfy_gen kuyrugu;
                   o kuyruk seridi kendisi alir, burada ALINMAZ - kilitlenir)
    #314: manken/Mixamo INSANSI iskelet ister - animal/machine turunde 400.
    #305: animasyon SKIN uzerinde yapilir - `skin` bos = base skini (anims/),
    doluysa skins/<slug>/anims/ ve Wan referansi o skinin yon gorselidir.
    """
    if y not in ALL_DIRS:
        raise ValueError("bilinmeyen yon: %s" % y)
    _kip_dogrula(name, mode)                       # #314: animal/machine -> yalniz i2v
    ref = _ref_image(name, y, skin)                # kabul edilmemis yon animasyona giremez
    d = char_dir(name)
    ak = anims_root(d, skin)                       # #305
    cfg = anims(name)
    pad = _padding_of(name, padding)
    n = max(1, min(8, int(n or 1)))
    if mode == "i2v":
        ad = _slug(clip or prompt or "i2v")
        isler = [(ad, k) for k in range(n)]
        return _animate_i2v(name, y, ak, ref, isler, prompt, engine, pad)
    tanim = cfg.get("clips") or {}
    secili = [c for c in (clips or list(tanim)) if c in tanim]
    if not secili:
        raise ValueError("klip secilmedi (anims.json bos olabilir)")
    return _animate_mixamo(name, y, ak, ref, cfg, tanim, secili, n, pad)


def _animate_mixamo(name, y, ak, ref, cfg, tanim, clips, n, padding) -> str:
    _c, manken, _sf, wan, _yu = _tools()
    canvas = _canvas_for(cfg, padding)
    isler = [(c, k) for c in clips for k in range(n)]
    op_id = _op_new("char-animate", len(isler))

    def calis():
        # #299: parti TEK bilet - icindeki ComfyUI grafikleri arka arkaya kosar.
        with gpu_lane.hold("karakter animasyon: %s/%s (%d)" % (name, y, len(isler)),
                           kind="character", op_id=op_id, total=len(isler)):
            for i, (c, _k) in enumerate(isler, 1):
                cd = os.path.join(ak, y, c)                       # #305
                os.makedirs(cd, exist_ok=True)

                def log(s, _i=i, _c=c):
                    _op(op_id, message="%d/%d %s/%s: %s" % (_i, len(isler), y, _c, s))
                try:
                    mk = _manken_render(manken, cfg, tanim, c, cd, DIR_AZ.get(y, 0), padding, log=log)
                    v = _next_version(cd)
                    vd = os.path.join(cd, v)
                    os.makedirs(vd, exist_ok=True)
                    shutil.copy(mk, os.path.join(vd, "manken.mp4"))
                    mj = os.path.splitext(mk)[0] + ".json"
                    if os.path.isfile(mj):
                        shutil.copy(mj, os.path.join(vd, "manken.json"))
                    info = wan.animate(ref, mk, os.path.join(vd, "wan.mp4"),
                                       pose_prompt=(tanim.get(c) or {}).get("pose") or "",
                                       w=canvas, h=canvas, fps=int(cfg.get("fps") or 30),
                                       prefix="%s_%s_%s_%s" % (_slug(name), y, c, v),
                                       margin=padding or 0.04, log=log)
                    info.update({"mode": "mixamo", "dir": y, "clip": c, "version": v,
                                 "padding": padding, "canvas": canvas,
                                 "at": datetime.now().isoformat(timespec="seconds")})
                    _write_json(os.path.join(vd, "wan.json"), info)
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s/%s: %s" % (y, c, str(e)[:220]))
                    continue
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i, log="%s/%s %s hazir (seed %s)" % (y, c, v, info.get("seed")))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def _animate_i2v(name, y, ak, ref, isler, prompt, engine, padding) -> str:
    """Saf i2v: comfy_gen video hattina is verir, ciktiyi vNN/wan.mp4'e alir.
    gpu_lane BURADA ALINMAZ - comfy_gen isi calistirirken seridi kendisi alir."""
    task = engine or VIDEO_TASK
    md = G.MODES["character"]
    op_id = _op_new("char-i2v", len(isler))

    def calis():
        for i, (c, _k) in enumerate(isler, 1):
            cd = os.path.join(ak, y, c)                           # #305
            os.makedirs(cd, exist_ok=True)
            v = _next_version(cd)
            vd = os.path.join(cd, v)
            os.makedirs(vd, exist_ok=True)
            _op(op_id, message="i2v %d/%d  %s/%s %s" % (i, len(isler), y, c, v))
            try:
                pad_ref = os.path.join(vd, "ref.png")
                _pad_edge(ref, pad_ref, padding)
                job = G.submit(task, prompt or "the character performs a short looping motion",
                               prompt2=md["motion2"], negative=md["negative"],
                               image_path=pad_ref, mode="character",
                               client="flow", category=name)   # #299: Sira kartinda karakter adi
                out = _await_job(job["id"], op_id, "%s/%s %s" % (y, c, v))
                shutil.copy(out, os.path.join(vd, "wan.mp4"))
                _write_json(os.path.join(vd, "wan.json"), {
                    "mode": "i2v", "dir": y, "clip": c, "version": v, "task": task,
                    "prompt": prompt, "pose_prompt": G.combine(prompt, md["motion2"]),
                    "seed": (G.get_job(job["id"]) or {}).get("seed"), "job": job["id"],
                    "padding": padding, "ref": os.path.basename(ref),
                    "at": datetime.now().isoformat(timespec="seconds")})
            except Exception as e:
                shutil.rmtree(vd, ignore_errors=True)
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s/%s: %s" % (y, c, str(e)[:220]))
                continue
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s/%s %s hazir" % (y, c, v))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def _pad_edge(src: str, dest: str, padding: float) -> str:
    """rev5: figur tuvalin (1 - 2*padding) kadarini kaplasin; bosluk kenar
    pikselinin uzatilmasiyla dolar (wan_animate2.letterbox ile ayni yontem)."""
    if not padding:
        return _convert(src, dest)
    import numpy as np
    from PIL import Image
    with Image.open(src) as f:
        im = f.convert("RGB")
    w, h = im.size
    a = np.asarray(im)
    px, py = int(round(w * padding / (1 - 2 * padding))), int(round(h * padding / (1 - 2 * padding)))
    a = np.pad(a, ((py, py), (px, px), (0, 0)), mode="edge")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    Image.fromarray(a).save(dest)
    return dest


def _await_job(job_id: str, op_id: str, etiket: str, timeout: int = 3 * 3600) -> str:
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
    raise RuntimeError("i2v zaman asimi")


def accept(name: str, y: str, clip: str, version: str, skin: str = "") -> dict:
    """meta.json accepted; eski sprite ciktilari silinir (yeniden kabul serbest).
    #305: `skin` bos = base skini."""
    cd = _clip_dir(name, y, clip, skin)
    if not _VER_RE.match(version or "") or not os.path.isdir(os.path.join(cd, version)):
        raise ValueError("surum yok: %s" % version)
    onceki = (_read_json(os.path.join(cd, "meta.json")) or {}).get("accepted") or ""
    _write_json(os.path.join(cd, "meta.json"),
                {"accepted": version, "at": datetime.now().isoformat(timespec="seconds")})
    if onceki != version:
        _clear_sprite(cd)
    return {"clip": clip, "dir": y, "skin": skin_slug(skin),
            "accepted": version, "previous": onceki}


def _clear_sprite(cd: str) -> None:
    shutil.rmtree(os.path.join(cd, "frames"), ignore_errors=True)
    for a in ("anim.webp", "sheet.png", "sprite.json"):
        try:
            os.remove(os.path.join(cd, a))
        except OSError:
            pass


def _clip_dir(name: str, y: str, clip: str, skin: str = "") -> str:
    if y not in ALL_DIRS:
        raise ValueError("bilinmeyen yon: %s" % y)
    clip = (clip or "").strip()
    if not clip or "/" in clip or "\\" in clip or ".." in clip or clip.startswith("."):
        raise ValueError("gecersiz klip adi: %s" % clip)
    d = char_dir(name)
    cd = _inside(d, os.path.join(anims_root(d, skin), y, clip))   # #305
    if not os.path.isdir(cd):
        raise ValueError("klip yok: %s/%s" % (y, clip))
    return cd


def delete_version(name: str, y: str, clip: str, version: str, skin: str = "") -> dict:
    cd = _clip_dir(name, y, clip, skin)                           # #305
    if not _VER_RE.match(version or ""):
        raise ValueError("gecersiz surum: %s" % version)
    vd = os.path.join(cd, version)
    if not os.path.isdir(vd):
        raise ValueError("surum yok: %s" % version)
    shutil.rmtree(vd, ignore_errors=True)
    m = _read_json(os.path.join(cd, "meta.json")) or {}
    if m.get("accepted") == version:
        _write_json(os.path.join(cd, "meta.json"), {"accepted": ""})
        _clear_sprite(cd)
    return {"deleted": version}


def delete_clip(name: str, y: str, clip: str, skin: str = "") -> dict:
    cd = _clip_dir(name, y, clip, skin)                           # #305
    shutil.rmtree(cd, ignore_errors=True)
    return {"deleted": "%s/%s" % (y, clip)}


def sprites(name: str, y: str, clips: list[str] | None = None, skin: str = "") -> str:
    """op: kabul edilen surumlerden SAM3 kare kare kesim -> anim.webp + sheet.png.
    Serit TEK kez, partinin tamami icin alinir (CBN #281 kurali).
    #305: `skin` bos = base skini."""
    d = char_dir(name)
    ak = anims_root(d, skin)
    cfg = anims(name)
    bilgi = anims_of(name, y, skin)
    rows = [r for r in bilgi["clips"] if r["accepted"] and (not clips or r["clip"] in clips)]
    if not rows:
        raise ValueError("kabul edilmis surum yok")
    _c, _mk, sam_frames, _wa, _yu = _tools()
    prompt = cfg.get("sam_prompt") or sam_prompt(cfg.get("prop") or "")
    fps = int(cfg.get("fps_out") or 15)
    canvas = int((meta(name) or {}).get("sprite_canvas") or cfg.get("sprite_canvas") or 640)
    op_id = _op_new("char-sprites", len(rows))

    def calis():
        with gpu_lane.hold("karakter sprite: %s/%s (%d)" % (name, y, len(rows)),
                           kind="character", op_id=op_id, total=len(rows)):   # #299
            for i, r in enumerate(rows, 1):
                cd = os.path.join(ak, y, r["clip"])               # #305
                wan = os.path.join(cd, r["accepted"], "wan.mp4")
                if not os.path.isfile(wan):
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s: kabul edilen surumde wan.mp4 yok" % r["clip"])
                    continue
                # rev6/rev7: kirpma payi uretimde kullanilan padding'dir (icerige
                # gore DEGIL) - karakter olcegi ve pivot klipler arasi sabit kalir.
                pad = float((_read_json(os.path.join(cd, r["accepted"], "wan.json")) or {}).get("padding") or 0.0)
                _op(op_id, message="sprite %d/%d  %s/%s" % (i, len(rows), y, r["clip"]))
                try:
                    info = sam_frames.extract(
                        wan, cd, fps=fps, prompt=prompt, mirror=bool(cfg.get("mirror")),
                        height=0, crop=pad, canvas=canvas,
                        log=lambda s, _i=i, _c=r["clip"]: _op(
                            op_id, message="sprite %d/%d %s/%s: %s" % (_i, len(rows), y, _c, s)))
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s: %s" % (r["clip"], str(e)[:220]))
                    continue
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i, log="%s: %d kare, %d yedek" % (
                    r["clip"], info.get("frames"), len(info.get("fallback_frames") or [])))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


# --------------------------------------------------------------- dosya / kart
def file_path(name: str, rel: str) -> str | None:
    p = resolve(name, rel)
    return p if os.path.isfile(p) else None


VIDEO_EXT = (".mp4", ".webm", ".mov")


def thumb(name: str, rel: str, size: int = 360) -> str | None:
    """Onizleme: gorsel kucultulur, video/webp ilk karesi cikarilir (onbellekli)."""
    src = file_path(name, rel)
    return _thumb_file(src, size) if src else None


def _thumb_file(src: str, size: int = 360) -> str | None:
    """#305: mutlak yoldan onbellekli onizleme (kiyafet kutuphanesi de kullanir)."""
    if not src or not os.path.isfile(src):
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
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-frames:v", "1",
                            "-vf", "scale=%d:-1" % size, tmp], check=True,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        else:
            from PIL import Image
            with Image.open(src) as f:
                f.seek(0)                       # animasyonlu webp: ilk kare
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


def card(name: str) -> dict:
    p = os.path.join(char_dir(name), "card.md")
    try:
        with open(p, encoding="utf-8") as fh:
            text = fh.read()
    except Exception:
        text = ""
    return {"name": name, "card": text, "meta": meta(name)}


def save_card(name: str, text: str) -> dict:
    p = os.path.join(char_dir(name), "card.md")
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(text or "")
    return {"name": name, "bytes": len(text or "")}


ENRICH_PROMPT = """Sen bir oyun karakteri yazarisin. Asagidaki karakter kartini TURKCE olarak zenginlestir.

Karakter: {name}
Sinif: {cls}
Gorsel prompt (gorunumun kaynagi): {prompt}

Mevcut kart:
---
{card}
---

Ayni Markdown yapisini KORU (ayni basliklar, ayni madde adlari). Bos ya da kisa olan
"Yas / Koken", "Kisilik", "Hikaye", "Rol", "Sesi" maddelerini doldur ve genislet.
"Gorunum kilidi" maddesini DEGISTIRME (gorselden gelir); bossa gorsel prompt'tan cikar.
Hikaye 3-5 cumle olsun, klise olmasin. YALNIZ kartin son halini dondur, aciklama yazma."""


# ------------------------------------------------- kart onerileri (#299)
# #299: Ollama onerileri artik pop-up ile gelmiyor. Her oneri
# <karakter>/card_proposals.json icinde durur; kullanici listeden birini secip
# kabul eder (card.md'ye yazilir) ya da siler.
PROPOSALS_FILE = "card_proposals.json"
_prop_lock = threading.Lock()


def _proposal_rows(d: str) -> list:
    """#299: bir karakter KLASORUNDEKI oneriler (list_characters de kullanir)."""
    rows = _read_json(os.path.join(d, PROPOSALS_FILE), [])
    return [r for r in rows if isinstance(r, dict)] if isinstance(rows, list) else []


def _proposals(name: str) -> list:
    return _proposal_rows(char_dir(name))


def _save_proposals(name: str, rows: list) -> None:
    _write_json(os.path.join(char_dir(name), PROPOSALS_FILE), rows)   # tmp + replace


def _add_proposal(name: str, text: str, model: str = "") -> str:
    with _prop_lock:
        rows = _proposals(name)
        pid = uuid.uuid4().hex[:12]
        rows.append({"id": pid, "created": datetime.now().isoformat(timespec="seconds"),
                     "model": model or "", "card": text or "", "accepted": False})
        _save_proposals(name, rows)
    return pid


def card_proposals(name: str) -> dict:
    """#299: kayitli oneriler - en yenisi basta."""
    return {"name": name, "proposals": list(reversed(_proposals(name)))}


def accept_proposal(name: str, pid: str) -> dict:
    """#299: oneriyi card.md'ye yazar; yalniz o oneri accepted=true kalir."""
    with _prop_lock:
        rows = _proposals(name)
        hit = next((r for r in rows if r.get("id") == pid), None)
        if hit is None:
            raise ValueError("oneri yok: %s" % pid)
        save_card(name, hit.get("card") or "")
        for r in rows:
            r["accepted"] = (r.get("id") == pid)
        _save_proposals(name, rows)
    return {"name": name, "id": pid, "card": hit.get("card") or ""}


def delete_proposal(name: str, pid: str) -> dict:
    with _prop_lock:
        rows = _proposals(name)
        kalan = [r for r in rows if r.get("id") != pid]
        if len(kalan) != len(rows):
            _save_proposals(name, kalan)
    return {"deleted": len(rows) - len(kalan)}


def enrich_card(name: str, n: int = 2, timeout: int = 300) -> str:
    """#297/#299: op doner - Ollama ARKA PLANDA n oneri yazar (tunel 100 sn'de
    kesmesin). Oneriler pop-up ile DEGIL, card_proposals.json'a yazilarak
    saklanir; istemci listeden secip kabul eder. Op sonucu {"proposals":[id]}."""
    char_dir(name)                                  # karakter yoksa hemen 400
    if not JF.ollama_ready():
        raise ValueError("Ollama calismiyor (yerel gemma3 gerekiyor)")
    n = max(1, min(5, int(n or 1)))
    op_id = _op_new("char-enrich", n)

    def calis():
        ids = []
        for i in range(1, n + 1):
            _op(op_id, message="Ollama kart onerisi %d/%d" % (i, n))
            try:
                res = _enrich_text(name, timeout, op_id=op_id)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log=str(e)[:220])
                continue
            pid = _add_proposal(name, res.get("card") or "", res.get("model") or "")
            ids.append(pid)
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="oneri %s (%d karakter)" % (pid, len(res.get("card") or "")))
        with _ops_lock:
            _ops[op_id]["result"] = {"proposals": ids}   # op_status dict(o) ile doner
        if not ids:
            raise RuntimeError("hicbir oneri uretilemedi")
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def _enrich_text(name: str, timeout: int = 300, op_id: str = "") -> dict:
    """Kart metnini Ollama'ya yazdirir (diske YAZMAZ)."""
    if not JF.ollama_ready():
        raise ValueError("Ollama calismiyor (yerel gemma3 gerekiyor)")
    m = meta(name)
    cur = card(name)["card"]
    url, model = JF._ollama_cfg()
    # #314: hayvan/makine karakterde karta tur yonergesi eklenir (female/male
    # icin ipucu bostur, istem eski metinle birebir ayni kalir).
    ipucu = render_kind(KIND_PROFILES[kind_of(m)].get("story") or "", kind_of(m), subject_of(m))
    tmpl = ENRICH_PROMPT + (("\n\n" + ipucu) if ipucu else "")
    body = {"model": model, "stream": False, "keep_alive": "5m",
            "messages": [{"role": "user", "content": tmpl.format(
                name=name, cls=m.get("class") or "-",
                prompt=((m.get("prompt") or {}).get("combined") or (m.get("prompt") or {}).get("prompt") or "-")[:900],
                card=cur or "(bos)")}]}
    with gpu_lane.hold("karakter kart: %s" % name, kind="character", op_id=op_id):
        req = urllib.request.Request(url + "/api/chat", data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
        try:
            res = json.loads(urllib.request.urlopen(req, timeout=timeout).read())
        finally:
            JF.ollama_unload()
    text = ((res.get("message") or {}).get("content") or "").strip()
    if text.startswith("```"):
        text = re.sub(r"^```[a-z]*\n|\n```$", "", text).strip()
    if not text:
        raise ValueError("Ollama bos cevap dondu")
    return {"name": name, "card": text, "model": model, "current": cur}


# --------------------------------------------------- rev8: prompt genisletme
I2V_SYSTEM = """Sen bir 2D oyun animasyonu yonetmenisin. Kisa bir istegi, saf i2v
video modeline verilecek TEK bir INGILIZCE cumleye cevirirsin.

YALNIZ GOVDE HAREKETINI anlat: kollar, bacaklar, govde, kalca, bas, sac ve
kiyafetin hareketi, elindeki silahin izledigi yol, hareketin baslangici ve
bitisi (durusa donus).

KESINLIKLE YAZMA: kamera hareketi/acisi/zoom, arka plan, mekan, isik, yeni
nesne/efekt/parcacik, kiyafet ya da sac degisikligi, kesme/gecis, metin.
Tek cumle, en fazla 45 kelime, sadece cumleyi dondur."""

I2V_USER = """Karakter: {name} ({cls})
Elindeki: {prop}
Gorunum: {look}
Bakis yonu (kamera karsisindaki durus): {dir}
Istenen hareket: {text}"""

MIXAMO_SYSTEM = """Sen bir Mixamo animasyon arsivi kutuphanecisisin. Kullanicinin
istedigi harekete en uygun klipleri verilen ADAY LISTESINDEN secersin.
Yalniz JSON dondur: {"clips":[{"filename":"...","why":"tek cumle Turkce"}]}
En fazla 8 klip, en uygunu basta. Listede olmayan dosya adi UYDURMA."""


def _ollama_chat(messages: list[dict], fmt: str = "", timeout: int = 120) -> str:
    if not JF.ollama_ready():
        raise ConnectionError("Ollama calismiyor (yerel gemma3 gerekiyor)")
    url, model = JF._ollama_cfg()
    body = {"model": model, "stream": False, "keep_alive": "5m", "messages": messages}
    if fmt:
        body["format"] = fmt
    req = urllib.request.Request(url + "/api/chat", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    res = json.loads(urllib.request.urlopen(req, timeout=timeout).read())
    return ((res.get("message") or {}).get("content") or "").strip()


def _mixamo_candidates(text: str, limit: int = 60) -> list[dict]:
    """Anahtar kelime taramasi: istegin kelimeleri + yakin esanlamlilari."""
    ES = {"idle": ["idle", "breathing", "stand"], "attack": ["attack", "slash", "punch", "strike"],
          "hit": ["hit", "impact", "reaction", "stagger"], "death": ["death", "dying", "falling back"],
          "win": ["cheer", "victory", "celebrat", "clap"], "run": ["run", "sprint", "jog"],
          "walk": ["walk", "stroll"], "jump": ["jump", "leap", "hop"], "kick": ["kick"],
          "dance": ["dance", "danc"], "cast": ["magic", "spell", "cast"], "shoot": ["aim", "bow", "shoot"],
          "block": ["block", "guard", "shield"], "dodge": ["dodge", "evade", "roll"],
          "taunt": ["taunt", "provok"], "skill": ["spin", "combo", "power"]}
    kelime = [w for w in re.split(r"[^a-z]+", (text or "").lower()) if len(w) > 2]
    terimler = list(kelime)
    for k, v in ES.items():
        if any(k in w or w in k for w in kelime):
            terimler += v
    terimler = list(dict.fromkeys(terimler)) or ["idle"]
    tum = mixamo("", 5000, 0)["items"]
    puanli = []
    for r in tum:
        ad = r["name"].lower()
        p = sum(3 if ad.startswith(t) else 1 for t in terimler if t in ad)
        if p:
            puanli.append((p, r))
    puanli.sort(key=lambda t: (-t[0], t[1]["name"]))
    return [r for _p, r in puanli[:limit]]


def expand_prompt(name: str, y: str = "", text: str = "", mode: str = "i2v") -> str:
    """#297: op doner - enrich ile ayni tunel sorunu (Ollama 120-180 sn surebilir,
    tunel 100 sn'de keser). Ollama kapaliysa ConnectionError HEMEN atilir ki
    sunucu 503 dondursun (istemcideki sihirli degnek pasiflesir)."""
    char_dir(name)
    if not JF.ollama_ready():
        raise ConnectionError("Ollama calismiyor (yerel gemma3 gerekiyor)")
    op_id = _op_new("char-expand", 1)

    def calis():
        _op(op_id, message="Ollama %s onerisi yaziyor" % (mode or "i2v"))
        try:
            # #299: Ollama da GPU kullanir - seridi almadan kosmayacak.
            with gpu_lane.hold("karakter prompt: %s" % name, kind="character", op_id=op_id):
                try:
                    res = _expand_prompt_sync(name, y, text, mode)
                finally:
                    JF.ollama_unload()
        except Exception as e:
            with _ops_lock:
                _ops[op_id]["failed"] += 1
            _op(op_id, done=1, log=str(e)[:220])
            raise
        with _ops_lock:
            _ops[op_id]["ok"] += 1
            _ops[op_id]["result"] = res
        _op(op_id, done=1, message="bitti")

    _run(op_id, calis)
    return op_id


def _expand_prompt_sync(name: str, y: str = "", text: str = "", mode: str = "i2v") -> dict:
    """rev8: kisa istegi Ollama ile genisletir. #299: seridi CAGIRAN alir."""
    m = meta(name)
    cfg = anims(name)
    if mode == "mixamo":
        aday = _mixamo_candidates(text)
        if not aday:
            return {"clips": [], "note": "arsivde eslesen klip bulunamadi"}
        liste = "\n".join("%s | %s" % (r["filename"], r["name"]) for r in aday)
        try:
            ham = _ollama_chat([{"role": "system", "content": MIXAMO_SYSTEM},
                                {"role": "user", "content": "Istenen hareket: %s\nSinif: %s\n\nADAY LISTESI:\n%s"
                                 % (text, m.get("class") or "-", liste)}], fmt="json")
            secim = (json.loads(ham) or {}).get("clips") or []
        except ConnectionError:
            raise
        except Exception:
            secim = []
        ad_map = {r["filename"]: r for r in aday}
        out = []
        for s in secim:
            r = ad_map.get((s or {}).get("filename") or "")
            if r and r["filename"] not in [o["filename"] for o in out]:
                out.append(dict(r, why=(s.get("why") or "")[:200]))
        for r in aday:                      # Ollama az sectiyse listeyi tamamla
            if len(out) >= 8:
                break
            if r["filename"] not in [o["filename"] for o in out]:
                out.append(dict(r, why=""))
        return {"clips": out[:8], "query": text}
    prop = (cfg.get("prop") or "").strip() or "hicbir sey (eller bos)"
    etiket = next((d["label"] for d in DIRS if d["id"] == y), y or "on")
    p = _ollama_chat([{"role": "system", "content": I2V_SYSTEM},
                      {"role": "user", "content": I2V_USER.format(
                          name=name, cls=m.get("class") or "-", prop=prop, dir=etiket,
                          look=((m.get("prompt") or {}).get("prompt") or m.get("base") or "-")[:300],   # #305
                          text=text or "idle")}], timeout=180)
    p = re.sub(r'^["\']|["\']$', "", p.strip().splitlines()[0] if p.strip() else "").strip()
    if not p:
        raise ValueError("Ollama bos cevap dondu")
    return {"prompt": p, "input": text, "dir": y, "model": JF._ollama_cfg()[1]}


def remove(name: str) -> dict:
    """Karakteri komple siler (geri alinamaz)."""
    d = char_dir(name)
    shutil.rmtree(d, ignore_errors=True)
    return {"deleted": name}
