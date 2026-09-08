"""Yerel ComfyUI uretim koprusu.

Telefondan / masaustunden / LAN arayuzunden gelen istek -> bu modul -> yerel
ComfyUI (localhost:8188) -> cikti dosyasi server/data/generated/ altina duser.

ComfyUI kapaliysa istek reddedilir; sunucu ayaga kalkmadan is kuyruga girmez.
Is kayitlari diske yazilir (data/generated/_jobs.json), boylece AGB yeniden
baslatildiginda galeri kaybolmaz.

Iki uretim kipi vardir:
  * free    - serbest uretim, promptu kullanici tamamen yazar
  * jigsaw  - Hot Jigsaw is akisi: 9:16 dikey, ikinci pozitif prompt sablonu,
              cikti D:\\Asset Generation Pipeline altina jpg+mp4+webp ucllusu
              olarak numaralandirilir
"""
from __future__ import annotations

import json, re
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # server/
_SETTINGS = os.path.join(_HERE, "config", "settings.json")


def _yol(anahtar: str, env: str, varsayilan: str = "") -> str:
    """Makineye ozel bir yolu cozer: ortam degiskeni -> settings.json -> varsayilan.

    Depo herkese acik oldugu icin bu yollar KODA GOMULMEZ; kullanicinin kendi
    settings.json'inda durur (o dosya gitignore'dadir). Anahtar "a.b" seklinde
    ic ice okunur.
    """
    v = os.environ.get(env, "").strip()
    if v:
        return v
    try:
        with open(_SETTINGS, encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for par in anahtar.split("."):
            d = (d or {}).get(par)
        if isinstance(d, str) and d.strip():
            return d.strip()
    except Exception:
        pass
    return varsayilan


COMFY = _yol("comfyui.url", "COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
COMFY_WS = COMFY.replace("http://", "ws://").replace("https://", "wss://") + "/ws"
COMFY_ROOT = _yol("comfyui.root", "COMFYUI_ROOT")
COMFY_SCRIPTS = os.path.join(COMFY_ROOT, "scripts") if COMFY_ROOT else ""
COMFY_IN = os.path.join(COMFY_ROOT, "input") if COMFY_ROOT else ""
COMFY_OUT = os.path.join(COMFY_ROOT, "output") if COMFY_ROOT else ""
WFDIR = os.path.join(COMFY_ROOT, "user", "default", "workflows") if COMFY_ROOT else ""

OUT_DIR = os.path.join(_HERE, "data", "generated")
THUMB_DIR = os.path.join(OUT_DIR, "_thumbs")
STORE = os.path.join(OUT_DIR, "_jobs.json")

MANIFEST = os.path.join(_HERE, "config", "generate_tasks.json")

# Hot Jigsaw varlik havuzu - jigsaw kipinin ciktilari buraya numaralanarak duser
JIGSAW_ROOT = _yol("jigsaw.pool_root", "JIGSAW_POOL_ROOT")
JIGSAW_PUSHED = _yol("jigsaw.pushed_root", "JIGSAW_PUSHED_ROOT")
JIGSAW_STILL = (720, 1280)      # <n>.jpg
JIGSAW_WEBP = (320, 568)        # <n>.webp (hareketli onizleme)

# Manifest yoksa kullanilacak yedek liste (id -> is akisi, gorsel ister mi, video mu, olcu)
_FALLBACK = {
    "image_zimage": ("Image Z Turbo.json", False, False, (896, 1600)),
    "image_sdxl": ("Image SDXL Simple.json", False, False, (832, 1216)),
    "edit_qwen": ("Image Qwen Image.json", True, False, (0, 0)),
    "video_ltx": ("LTX2.5 I2V.json", True, True, (704, 1280)),
    "video_wan": ("Wan2.2 I2V.json", True, True, (704, 1280)),
}

_manifest_cache: tuple[float, list[dict]] | None = None


def _load_manifest() -> list[dict]:
    """Manifest'i diskten okur; dosya degisince kendiliginden tazelenir."""
    global _manifest_cache
    try:
        mtime = os.path.getmtime(MANIFEST)
    except OSError:
        mtime = 0.0
    try:
        mtime += os.path.getmtime(WFDIR)          # WFDIR'a dosya eklenince liste tazelensin
    except OSError:
        pass
    if _manifest_cache and _manifest_cache[0] == mtime:
        return _manifest_cache[1]

    entries: list[dict] = []
    if mtime:
        try:
            data = json.load(open(MANIFEST, encoding="utf-8"))
            for t in data.get("tasks", []):
                if not t.get("enabled", True) or not t.get("id") or not t.get("workflow"):
                    continue
                entries.append({
                    "id": t["id"],
                    "label": t.get("label", t["id"]),
                    "workflow": t["workflow"],
                    "needs_image": bool(t.get("needs_image")),
                    "is_video": bool(t.get("is_video")),
                    "width": int(t.get("width", 0)),
                    "height": int(t.get("height", 0)),
                    "duration": int(t.get("duration", 5)),
                    "modes": t.get("modes") or list(MODES),
                })
        except Exception as e:  # bozuk manifest sunucuyu dusurmesin
            print("[comfy_gen] manifest okunamadi, yedek liste kullaniliyor: %s" % e)
    if not entries:
        for key, (wf, ni, iv, size) in _FALLBACK.items():
            entries.append({"id": key, "label": key, "workflow": wf,
                            "needs_image": ni, "is_video": iv,
                            "width": size[0], "height": size[1], "duration": 5,
                            "modes": list(MODES)})
    # is akisi diskte yoksa gorevi gizle
    entries = [e for e in entries if os.path.isfile(os.path.join(WFDIR, e["workflow"]))]
    entries += _auto_workflows({e["workflow"] for e in entries})
    _manifest_cache = (mtime, entries)
    return entries


# Free kipinde WFDIR'daki HER is akisi gorunur (kullanici 2026-09-08: "free modda tum workflowlar
# gorunmelidir"). Manifest'te olmayanlar dosya on ekinden (T2I/I2I/I2V/FLF2V/V2V/S2V/UPS/I23D/T2M)
# turetilen ayarlarla yalniz "free" kipinde listelenir; id = wf_<slug>.
_IMG_PREFIX = ("I2I", "I2V", "FLF2V", "V2V", "S2V", "UPS", "I23D")
_VID_PREFIX = ("T2V", "I2V", "FLF2V", "V2V", "S2V")


def _auto_workflows(known: set[str]) -> list[dict]:
    out: list[dict] = []
    try:
        files = sorted(f for f in os.listdir(WFDIR) if f.lower().endswith(".json"))
    except OSError:
        return out
    for fn in files:
        if fn in known:
            continue
        stem = fn[:-5]
        pre = stem.split(" ", 1)[0].upper()
        up = stem.upper()
        needs_image = pre in _IMG_PREFIX or "EDIT" in up or "I2V" in up or "SEGMENT" in up
        is_video = pre in _VID_PREFIX or "VIDEO" in up or "I2V" in up or "ANIMATE" in up
        out.append({"id": "wf_" + re.sub(r"[^a-z0-9]+", "_", stem.lower()).strip("_"),
                    "label": stem, "workflow": fn, "needs_image": needs_image, "is_video": is_video,
                    "width": 0, "height": 0, "duration": 5, "modes": ["free"], "auto": True})
    return out


def _task(task_id: str) -> dict | None:
    return next((t for t in _load_manifest() if t["id"] == task_id), None)


# --- is akisi girdi yuvalari (gorev #287) --------------------------------
# Bir is akisi "bir gorsel + prompt"tan fazlasini isteyebilir: FLF2V ilk+son
# kare, V2V referans gorsel + surucu video, S2V gorsel + ses, UPS video.
# Asagidaki tablo ComfyUI'nin dosya okuyan dugumlerini tanir: her dugum bir
# YUVA olur, istemci her yuvaya ya Uretilenler galerisinden bir is ciktisi ya
# da bir dosya secer.  deger: (tur, dosya adini tutan widget)
_LOAD_NODES = {
    "LoadImage":         ("image", "image"),
    "LoadImageMask":     ("image", "image"),
    "LoadImageOutput":   ("image", "image"),
    "LoadAudio":         ("audio", "audio"),
    "LoadVideo":         ("video", "file"),
    "VHS_LoadVideo":     ("video", "video"),
    "VHS_LoadVideoPath": ("video", "video"),
    "VHS_LoadImagePath": ("image", "image"),
    "VHS_LoadAudio":     ("audio", "audio_file"),
    "VHS_LoadAudioUpload": ("audio", "audio"),
}
_KIND_EXT = {
    "image": (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"),
    "video": (".mp4", ".webm", ".mov", ".mkv", ".avi", ".gif"),
    "audio": (".mp3", ".wav", ".flac", ".ogg", ".m4a", ".aac", ".opus"),
}
_KIND_LABEL = {"image": "gorsel", "video": "video", "audio": "ses"}
_KIND_TITLE = {"image": "Gorsel", "video": "Video", "audio": "Ses"}
_SLOT_MARK = "__agb_slot_%s__"

# is akisi dosyasi -> (mtime, yuvalar); dosya degisince kendiliginden tazelenir
_inputs_cache: dict[str, tuple[float, list[dict]]] = {}


def input_extensions(kind: str = "") -> tuple:
    """Bir yuva turunun kabul ettigi dosya uzantilari (bos = hepsi)."""
    if kind:
        return _KIND_EXT.get(kind, ())
    return tuple(sorted({e for v in _KIND_EXT.values() for e in v}))


def _slot_nodes(wf: dict) -> list[dict]:
    """Is akisindaki (alt-grafikler dahil) tum dosya okuyan dugumler."""
    found: list[dict] = []

    def scan(nodes, scope: str) -> None:
        for n in nodes or []:
            spec = _LOAD_NODES.get(n.get("type"))
            if not spec:
                continue
            kind, widget = spec
            # Dugum widget girislerini bildiriyorsa adi oradan al; eski
            # kayitlarda "inputs" bos gelir (bkz. UPS SeedVR2 Video / LoadVideo).
            names = [i.get("name") for i in (n.get("inputs") or []) if i.get("widget")]
            w = widget if (widget in names or not names) else names[0]
            vals = list(n.get("widgets_values") or [])
            default = vals[0] if vals and isinstance(vals[0], str) else ""
            found.append({"scope": scope, "nid": n.get("id"), "class_type": n["type"],
                          "kind": kind, "widget": w, "default": default,
                          "title": (n.get("title") or "").strip()})

    scan(wf.get("nodes"), "")
    for sg in (wf.get("definitions", {}) or {}).get("subgraphs", []) or []:
        scan(sg.get("nodes"), str(sg.get("id")))
    found.sort(key=lambda n: (n["scope"], n["nid"] if isinstance(n["nid"], int) else 0))
    return found


def _apply_slot_files(wf: dict, slots: list[dict], files: dict) -> None:
    """Yuvalarin dosya adlarini is akisi JSON'una yazar (yerinde degistirir).

    Dolu olmayan yuva kendi varsayilan dosyasiyla kalir. Dugum widget girisini
    bildirmiyorsa burada eklenir - yoksa donusturucu (wf2api._widget_map)
    dosya adini API grafigine HIC yazmaz ve ComfyUI "file eksik" der.
    """
    index: dict[tuple, dict] = {}

    def idx(nodes, scope: str) -> None:
        for n in nodes or []:
            index[(scope, n.get("id"))] = n

    idx(wf.get("nodes"), "")
    for sg in (wf.get("definitions", {}) or {}).get("subgraphs", []) or []:
        idx(sg.get("nodes"), str(sg.get("id")))

    for s in slots:
        verilen = files.get(s["slot"])
        val = verilen or s.get("default") or ""
        if not val:
            continue
        for scope, nid, widget in s.get("nodes") or []:
            n = index.get((scope, nid))
            if n is None:
                continue
            # Sablonlarda girdi dugumu cogu zaman BYPASS (mode 4) kaydedilmistir
            # (ornek: Wan2.2 I2V'deki LoadImage). Donusturucu artik bypass'i
            # dogru uyguladigi icin (gorev #326) dugum grafige hic girmiyordu;
            # yuvaya gercek bir dosya koyduysak dugumu geri acariz.
            if verilen and n.get("mode") in (2, 4):
                n["mode"] = 0
            names = [i.get("name") for i in (n.get("inputs") or []) if i.get("widget")]
            if not names:
                n.setdefault("inputs", []).insert(
                    0, {"name": widget, "type": "COMBO", "widget": {"name": widget},
                        "link": None})
            wv = n.setdefault("widgets_values", [])
            if wv:
                wv[0] = val
            else:
                wv.append(val)


def _reachable_slots(wf: dict, slots: list[dict]) -> list[dict]:
    """Cikti dugumlerinden ulasilamayan (kopuk) yuvalari eler.

    Her yuvaya benzersiz bir isaret yazip is akisini API formatina cevirir;
    isareti grafikte gorunmeyen yuva hicbir ise yaramiyor demektir.
    """
    if not slots:
        return slots
    try:
        convert = _convert()
    except Exception:
        return slots                  # ComfyUI kurulu degil - hepsini birak
    import copy
    probe = copy.deepcopy(wf)
    marks = {s["slot"]: _SLOT_MARK % s["slot"] for s in slots}
    _apply_slot_files(probe, slots, marks)
    try:
        graph = convert(probe, {})
    except Exception as e:
        print("[comfy_gen] is akisi cozumlenemedi: %s" % e)
        return slots
    seen = set()
    for n in graph.values():
        for v in (n.get("inputs") or {}).values():
            if isinstance(v, str) and v.startswith("__agb_slot_"):
                seen.add(v)
    kept = [s for s in slots if marks[s["slot"]] in seen]
    return kept or slots


def workflow_inputs(wf_name: str) -> list[dict]:
    """Is akisinin girdi yuvalari, sirayla.

    [{"slot": "image_1", "kind": "image", "node_id": 189,
      "title": "Load Image (Reference Image)", "default": "ref.png",
      "class_type": "LoadImage", "nodes": [[scope, node_id, widget], ...]}]

    Ayni tur + ayni varsayilan dosyayi tasiyan dugumler TEK yuvadir: is
    akislarinda ayni girdi cogu zaman birden fazla kolda (yuksek/dusuk gurultu,
    bypass edilmis kopya) durur, kullaniciya iki kez sorulmaz.
    """
    path = os.path.join(WFDIR, wf_name) if WFDIR else wf_name
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        return []
    hit = _inputs_cache.get(wf_name)
    if hit and hit[0] == mtime:
        return [dict(s) for s in hit[1]]
    try:
        wf = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        print("[comfy_gen] is akisi okunamadi (%s): %s" % (wf_name, e))
        return []

    slots: list[dict] = []
    by_key: dict[tuple, dict] = {}
    for n in _slot_nodes(wf):
        key = (n["class_type"], n["default"])
        g = by_key.get(key)
        if g is None:
            by_key[key] = g = {"slot": "", "kind": n["kind"], "node_id": n["nid"],
                               "class_type": n["class_type"], "title": n["title"],
                               "default": n["default"], "nodes": []}
            slots.append(g)
        g["nodes"].append([n["scope"], n["nid"], n["widget"]])
        if not g["title"] and n["title"]:
            g["title"] = n["title"]
    # gecici ad (isaret koyabilmek icin), eleme sonrasi yeniden numaralanir
    for i, s in enumerate(slots):
        s["slot"] = "%s_%d" % (s["kind"], i + 1)
    slots = _reachable_slots(wf, slots)
    say: dict[str, int] = {}
    for s in slots:
        say[s["kind"]] = say.get(s["kind"], 0) + 1
        s["slot"] = "%s_%d" % (s["kind"], say[s["kind"]])
        # label = arayuzde her zaman anlamli olan kisa ad; title = is akisinin
        # kendi dugum basligi (yoksa varsayilan dosya adi) - ipucu olarak durur
        s["label"] = "%s %d" % (_KIND_TITLE[s["kind"]], say[s["kind"]])
        if not s["title"]:
            s["title"] = os.path.splitext(s["default"])[0]
    _inputs_cache[wf_name] = (mtime, slots)
    return [dict(s) for s in slots]


def slot_name(s: dict) -> str:
    """Hata mesajlarinda gecen yuva adi: "Gorsel 1 - Load Image (Reference)"."""
    t = (s.get("title") or "").strip()
    return "%s - %s" % (s.get("label") or s["slot"], t) if t else (s.get("label") or s["slot"])


def task_inputs(spec: dict) -> list[dict]:
    """Bir gorevin yuvalari + zorunlu mu bilgisi.

    Manifest'te tanimli gorevler "needs_image" ile yonetilir (eski davranis
    korunur); manifest disi - klasordeki her is akisi icin uretilen - gorevlerde
    HER yuva zorunludur, eksikse is bastan reddedilir.
    """
    slots = workflow_inputs(spec["workflow"])
    zorunlu = True if spec.get("auto") else bool(spec.get("needs_image"))
    for s in slots:
        s["required"] = zorunlu
    return slots


def task_needs_image(spec: dict, slots: list[dict] | None = None) -> bool:
    """Geriye donuk "needs_image": ilk gorsel yuvasi var mi.

    Manifest gorevlerinde manifest'in dedigi gecerlidir; otomatik listelenen is
    akislarinda dosya adi on ekinden tahmin yerine gercek yuvalara bakilir
    (ornek: FLF2V MiniMax H3 hicbir LoadImage tasimaz, gorsel istemez).
    """
    if not spec.get("auto"):
        return bool(spec.get("needs_image"))
    slots = task_inputs(spec) if slots is None else slots
    return any(s["kind"] == "image" for s in slots)


def available_workflows() -> list[dict]:
    """WFDIR'daki tum is akislari + manifest'te tanimli mi bilgisi."""
    known = {t["workflow"] for t in _load_manifest()}
    out = []
    try:
        for fn in sorted(os.listdir(WFDIR)):
            if fn.endswith(".json"):
                out.append({"workflow": fn, "configured": fn in known})
    except OSError:
        pass
    return out


NEG_IMG = ("blurry, low quality, deformed, disfigured, extra limbs, extra fingers, "
           "bad hands, bad anatomy, watermark, text, logo")
NEG_VID = ("cartoon, deformed, disfigured, extra limbs, extra arms, extra legs, "
           "fused fingers, bad hands, bad face, static image, watermark, text, blurry")

# --- jigsaw kipi varsayilanlari -------------------------------------------
# Ikinci pozitif prompt bir SABLONdur: {} birinci pozitifin yerine gecer.
# Kullanici "police officer" yazinca ortaya "cok guzel bir kadin polis" cikar.
JIGSAW_PROMPT2 = (
    "a breathtakingly beautiful young woman, {}, flawless symmetrical face, "
    "perfect makeup, big expressive eyes, full lips, long silky hair, slim toned "
    "figure, radiant glowing skin, supermodel looks, confident alluring pose, "
    "photorealistic, professional fashion photography, sharp focus, detailed "
    "realistic skin texture, cinematic lighting, shot on 85mm lens, high detail, "
    "full body vertical 9:16 composition"
)
JIGSAW_NEG = ("cartoon, anime, illustration, 3d render, cgi, deformed, disfigured, "
              "extra limbs, extra fingers, bad hands, bad anatomy, ugly face, "
              "asymmetric face, watermark, text, logo, blurry, low quality")
JIGSAW_MOTION2 = (
    "{}, she moves slowly and gracefully, hair and clothing flowing naturally, "
    "subtle camera push in, cinematic realistic motion, she looks into the camera"
)

# Prompt ekleri - arayuzlerde secilebilir dugmeler. Secilenlerin metni birlesik
# promptun sonuna eklenir. Tek kaynak burasi; uc arayuz de bunu okur.
EXTRAS = [
    {"id": "kadraj", "label": "Kadraj", "options": [
        {"id": "full", "label": "Tam boy",
         "prompt": "full body shot, head to toe, entire figure visible, feet in frame"},
        {"id": "knees_up", "label": "Diz ustu",
         "prompt": "three-quarter body shot, framed from the knees up"},
        {"id": "waist_up", "label": "Bel ustu",
         "prompt": "upper body shot, framed from the waist up"},
        {"id": "portrait", "label": "Portre",
         "prompt": "portrait shot, head and shoulders, shallow depth of field"},
        {"id": "closeup", "label": "Yakin plan",
         "prompt": "close-up of her face, intimate framing"},
    ]},
    {"id": "aci", "label": "Aci", "options": [
        {"id": "front", "label": "Onden", "prompt": "facing the camera, front view"},
        {"id": "three_quarter", "label": "3/4", "prompt": "three-quarter view, body turned slightly"},
        {"id": "side", "label": "Yandan", "prompt": "side view, profile, standing sideways"},
        {"id": "back", "label": "Arkadan",
         "prompt": "seen from behind, looking back over her shoulder at the camera"},
        {"id": "low", "label": "Alcak aci", "prompt": "low angle shot looking up at her"},
        {"id": "high", "label": "Yuksek aci", "prompt": "high angle shot looking down at her"},
    ]},
    {"id": "poz", "label": "Poz", "options": [
        {"id": "standing", "label": "Ayakta", "prompt": "standing confidently, hand on hip"},
        {"id": "walking", "label": "Yururken", "prompt": "walking toward the camera mid-stride"},
        {"id": "sitting", "label": "Otururken", "prompt": "sitting down, legs crossed"},
        {"id": "leaning", "label": "Yaslanmis", "prompt": "leaning back against a wall"},
        {"id": "kneeling", "label": "Diz cokmus", "prompt": "kneeling on the floor"},
        {"id": "lying", "label": "Uzanmis", "prompt": "lying down, propped up on one elbow"},
        {"id": "stretching", "label": "Gerinirken", "prompt": "stretching, arms raised above her head"},
        {"id": "looking_back", "label": "Donup bakarken",
         "prompt": "turning to look back over her shoulder"},
    ]},
    {"id": "sac_rengi", "label": "Sac rengi", "options": [
        {"id": "blonde", "label": "Sarisin", "prompt": "long blonde hair"},
        {"id": "brunette", "label": "Kumral", "prompt": "chestnut brown hair"},
        {"id": "black_hair", "label": "Siyah", "prompt": "jet black hair"},
        {"id": "red_hair", "label": "Kizil", "prompt": "deep red auburn hair"},
        {"id": "platinum", "label": "Platin", "prompt": "platinum silver hair"},
        {"id": "pink_hair", "label": "Pembe", "prompt": "pastel pink hair"},
        {"id": "blue_hair", "label": "Mavi", "prompt": "vivid blue dyed hair"},
    ]},
    {"id": "sac_stili", "label": "Sac stili", "options": [
        {"id": "straight_long", "label": "Uzun duz", "prompt": "long straight silky hair"},
        {"id": "wavy", "label": "Dalgali", "prompt": "long wavy hair"},
        {"id": "curly", "label": "Kivircik", "prompt": "voluminous curly hair"},
        {"id": "ponytail", "label": "At kuyrugu", "prompt": "hair in a high ponytail"},
        {"id": "bun", "label": "Topuz", "prompt": "hair in a neat bun"},
        {"id": "bob", "label": "Kisa bob", "prompt": "short bob haircut"},
        {"id": "wet_hair", "label": "Islak", "prompt": "wet slicked-back hair"},
    ]},
    {"id": "goz_rengi", "label": "Goz rengi", "options": [
        {"id": "blue_eyes", "label": "Mavi", "prompt": "striking blue eyes"},
        {"id": "green_eyes", "label": "Yesil", "prompt": "bright emerald green eyes"},
        {"id": "brown_eyes", "label": "Kahve", "prompt": "warm brown eyes"},
        {"id": "hazel_eyes", "label": "Ela", "prompt": "hazel eyes"},
        {"id": "grey_eyes", "label": "Gri", "prompt": "pale grey eyes"},
        {"id": "amber_eyes", "label": "Bal", "prompt": "amber eyes"},
    ]},
    {"id": "ten_rengi", "label": "Ten rengi", "options": [
        {"id": "fair", "label": "Acik", "prompt": "fair porcelain skin"},
        {"id": "light_tan", "label": "Bugday", "prompt": "light golden tanned skin"},
        {"id": "tanned", "label": "Bronz", "prompt": "deeply tanned bronzed skin"},
        {"id": "olive", "label": "Zeytin", "prompt": "olive mediterranean skin"},
        {"id": "brown_skin", "label": "Esmer", "prompt": "rich brown skin"},
        {"id": "dark_skin", "label": "Koyu", "prompt": "dark ebony skin"},
    ]},
    {"id": "vucut", "label": "Vucut", "options": [
        {"id": "slim", "label": "Ince", "prompt": "slim slender figure"},
        {"id": "athletic", "label": "Atletik", "prompt": "athletic toned figure, defined abs"},
        {"id": "curvy", "label": "Baliketi", "prompt": "curvy hourglass figure"},
        {"id": "tall", "label": "Uzun boylu", "prompt": "tall long-legged figure"},
        {"id": "petite", "label": "Ufak tefek", "prompt": "petite delicate figure"},
    ]},
    {"id": "yas", "label": "Yas", "options": [
        {"id": "early20s", "label": "20 basi", "prompt": "in her early twenties"},
        {"id": "mid20s", "label": "25 civari", "prompt": "in her mid twenties"},
        {"id": "late20s", "label": "20 sonu", "prompt": "in her late twenties"},
        {"id": "thirties", "label": "30lu", "prompt": "in her thirties, mature elegance"},
    ]},
    {"id": "ifade", "label": "Ifade", "options": [
        {"id": "smiling", "label": "Gulumseyen", "prompt": "warm genuine smile"},
        {"id": "seductive", "label": "Bastan cikarici",
         "prompt": "seductive sultry look, biting her lip"},
        {"id": "serious", "label": "Ciddi", "prompt": "serious confident expression"},
        {"id": "playful", "label": "Suh", "prompt": "playful cheeky expression, winking"},
        {"id": "surprised", "label": "Saskin", "prompt": "surprised wide-eyed expression"},
    ]},
    {"id": "mekan", "label": "Mekan", "options": [
        {"id": "beach", "label": "Sahil", "prompt": "on a tropical beach, turquoise sea behind her"},
        {"id": "city", "label": "Sehir", "prompt": "on a busy city street at night"},
        {"id": "office", "label": "Ofis", "prompt": "in a modern glass office, city skyline behind"},
        {"id": "bedroom", "label": "Yatak odasi", "prompt": "in a softly lit bedroom"},
        {"id": "gym", "label": "Spor salonu", "prompt": "in a modern gym"},
        {"id": "pool", "label": "Havuz", "prompt": "beside a luxury swimming pool"},
        {"id": "forest", "label": "Orman", "prompt": "in a sunlit forest"},
        {"id": "snow", "label": "Kar", "prompt": "in a snowy winter landscape"},
        {"id": "desert", "label": "Col", "prompt": "in a golden desert at sunset"},
        {"id": "club", "label": "Kulup", "prompt": "in a neon-lit nightclub"},
        {"id": "studio_bg", "label": "Studyo", "prompt": "in a photo studio against a plain backdrop"},
        {"id": "car", "label": "Araba", "prompt": "leaning against a sports car"},
    ]},
    {"id": "isik", "label": "Isik", "options": [
        {"id": "golden", "label": "Altin saat", "prompt": "warm golden hour light, soft rim light"},
        {"id": "studio_light", "label": "Studyo", "prompt": "clean studio lighting, softbox key light"},
        {"id": "neon", "label": "Neon", "prompt": "neon night lighting, colourful reflections"},
        {"id": "window", "label": "Pencere", "prompt": "soft daylight through a window"},
        {"id": "dark_light", "label": "Los", "prompt": "moody low-key lighting, deep shadows"},
        {"id": "backlit", "label": "Arkadan", "prompt": "backlit silhouette, glowing outline"},
    ]},
]

_EXTRA_TEXT = {o["id"]: o["prompt"] for g in EXTRAS for o in g["options"]}


def extras() -> list[dict]:
    return EXTRAS


def extras_text(ids) -> str:
    """Secilen ek dugmelerinin metinlerini sirayla birlestirir."""
    if not ids:
        return ""
    seen, parts = set(), []
    for i in ids:
        t = _EXTRA_TEXT.get(i)
        if t and t not in seen:
            seen.add(t)
            parts.append(t)
    return ", ".join(parts)


# CBN (Color-By-Number) kipi: uretim jigsaw gibi bir gorsel isidir; sablon ve
# negatif derece profilinden gelir (cbn_options.json), o yuzden burada bos.
# Kabul/insa/push akisi cbn_flow.py'dedir. "profiles" istemciye hangi secenek
# dosyasinin gectigini soyler; "aspects" oran secicisini acar.
CBN_NEG = ("blurry, low quality, deformed, extra limbs, text, watermark, logo, "
           "photo, noise, grain, muddy colors")

# CBN uretim boyutlari (gorev #285): bes oran, hepsi TAM oran ve 16'nin kati,
# ~1 MP, uzun kenar <= 1280. 2x buyutme ile uzun kenar 2560'a cikar. 2:3 ve
# 1:1 Qwen Edit'in Kontext kanvasiyla birebir (832x1248, 1024x1024); digerleri
# Qwen'e verilirken cbn_align.pad_for_edit ile tam Kontext oranina dolgulanir,
# boylece cizgi sayfasi esnemez/kaymaz.
CBN_ASPECTS = [
    {"id": "9:16", "label": "9:16", "width": 720, "height": 1280},
    {"id": "2:3", "label": "2:3", "width": 832, "height": 1248},
    {"id": "1:1", "label": "1:1", "width": 1024, "height": 1024},
    {"id": "3:2", "label": "3:2", "width": 1248, "height": 832},
    {"id": "16:9", "label": "16:9", "width": 1280, "height": 720},
]

# --- karakter kipi (Karakter Modu, gorev #286) ----------------------------
# Kullanicinin sarti: fon HEM stillde HEM videoda kolay silinsin. O yuzden iki
# sablon da ayni fon cumlesini tasir (duz, tek renk, acik gri, golgesiz) -
# SAM3/isnet kesimi bu fonda temiz calisiyor. {} = 1. prompt (kimlik + kostum).
CHARACTER_BG = ("plain solid flat uniform light gray seamless studio background, no floor shadow, "
                "no gradient, even soft lighting")
CHARACTER_PROMPT2 = (
    "{} standing straight facing the camera, neutral relaxed pose, arms at her sides, "
    "full body from head to feet with empty space above and below, " + CHARACTER_BG +
    ", photorealistic, sharp focus, 85mm"
)
# Video (i2v) sablonu: kadraj kilitli, karakter kareden TASMAZ - sprite kesimi
# ancak tum govde her karede iceride kalirsa ise yarar (rev3).
CHARACTER_MOTION2 = (
    "{}, static locked camera, no camera movement, the character stays fully inside the frame "
    "from head to feet at all times, never leaves or touches the frame edges, " + CHARACTER_BG
)
CHARACTER_NEG = ("anime, cartoon, illustration, drawing, painting, 3d render, cgi, child, teen, minor, "
                 "deformed, disfigured, extra limbs, extra fingers, bad hands, bad anatomy, "
                 "watermark, text, logo, cluttered background, props, furniture, "
                 "cropped feet, cropped head, camera pan, camera zoom")

# --- kart kipi (Kart Modu, gorev #321) -----------------------------------
# Hot Card Games koleksiyon kartlari. Metin roster.json'daki v5 formulunden
# (style_prompts.realistic + base_prompt) turer; TEK fark fon: chroma yesil
# YERINE karakter hattiyla ayni duz acik gri studyo fonu - kesim artik SAM3
# ile yapiliyor (bkz. design/kart_modu.md §3), o yuzden "yesil kiyafet yasagi"
# da kalkti. {} = 1. prompt (tema + gorunus + poz).
CARD_BG = ("standing in front of a plain solid flat uniform light gray seamless studio "
           "background, even studio lighting on the subject only, no shadows cast on the "
           "background, no floor shadow, no gradient")
CARD_STYLE = ("ultra realistic glamour photography, breathtakingly beautiful young woman in her "
              "mid 20s, captivating gorgeous face, playful seductive smile, alluring pin-up model "
              "look, cinematic studio lighting, 85mm lens")
CARD_PROMPT2 = (
    CARD_STYLE + ", {}, full body, entire figure visible head to feet including high heels, "
    "vertical 2:3 composition, centered, " + CARD_BG + ", sharp focus"
)
# Krupiye (dealer) varyanti: bel ustu kadraj, kumarhane masasi, eller masada.
CARD_DEALER_PROMPT2 = (
    CARD_STYLE + ", {}, waist-up framing, seen from the waist up behind a casino table, "
    "hands resting on the table, facing the camera, vertical 2:3 composition, centered, "
    + CARD_BG + ", sharp focus"
)
# Video (i2v): kadraj KILITLI - sheet kesimi ancak olcek/cerceve degismezse tutar.
CARD_MOTION2 = (
    "{}, locked static camera, no camera movement, no zoom, no push in, no dolly, "
    "framing never changes, same scale, the woman stays fully inside the frame at all times, "
    "the plain light gray background stays flat and unchanged"
)
# Negatif: karakter hattinin listesi; "green clothing" gibi yesil kurallari YOK (#321).
CARD_NEG = ("child, teen, minor, chibi, anime, cartoon, illustration, drawing, painting, "
            "3d render, cgi, deformed, disfigured, extra limbs, extra fingers, bad hands, "
            "bad anatomy, watermark, text, logo, cluttered background, furniture, "
            "cropped head, camera pan, camera zoom")

# #316: Free modda da oran secici - bes oran, ~1 MP, 16'nin kati (CBN ile ayni tablo).
FREE_ASPECTS = [
    {"id": "9:16", "label": "9:16", "width": 720, "height": 1280},
    {"id": "2:3", "label": "2:3", "width": 832, "height": 1248},
    {"id": "1:1", "label": "1:1", "width": 1024, "height": 1024},
    {"id": "3:2", "label": "3:2", "width": 1248, "height": 832},
    {"id": "16:9", "label": "16:9", "width": 1280, "height": 720},
]

MODES = {
    "free": {
        "id": "free", "label": "Free Mod",
        "prompt2": "", "negative": "", "motion2": "",
        "width": 0, "height": 0, "exports": False, "profiles": "", "aspects": True,
        "aspect_sizes": FREE_ASPECTS,
    },
    "jigsaw": {
        "id": "jigsaw", "label": "Jigsaw Modu",
        "prompt2": JIGSAW_PROMPT2, "negative": JIGSAW_NEG, "motion2": JIGSAW_MOTION2,
        "width": 896, "height": 1600, "exports": True, "profiles": "jigsaw", "aspects": False,
    },
    "cbn": {
        "id": "cbn", "label": "CBN Modu",
        "prompt2": "", "negative": CBN_NEG, "motion2": "",
        "width": 832, "height": 1248, "exports": True, "profiles": "cbn", "aspects": True,
        "aspect_sizes": CBN_ASPECTS,
    },
    # #321: Kart Modu, Karakter'den ONCE gelir (FlowHub sirasi: free, jigsaw,
    # cbn, card, character).
    "card": {
        "id": "card", "label": "Kart Modu",
        "prompt2": CARD_PROMPT2, "negative": CARD_NEG, "motion2": CARD_MOTION2,
        "width": 832, "height": 1248, "exports": True, "profiles": "card", "aspects": False,
    },
    "character": {
        "id": "character", "label": "Karakter Modu",
        "prompt2": CHARACTER_PROMPT2, "negative": CHARACTER_NEG, "motion2": CHARACTER_MOTION2,
        "width": 832, "height": 1472, "exports": True, "profiles": "character", "aspects": False,
    },
}


def modes() -> list[dict]:
    return list(MODES.values())


def combine(prompt: str, prompt2: str) -> str:
    """Iki pozitif promptu birlestirir.

    prompt2 icinde {} varsa birinci prompt oraya girer (sablon), yoksa arkaya
    virgulle eklenir. prompt2 bossa birinci prompt aynen kullanilir.
    """
    p1 = (prompt or "").strip()
    p2 = (prompt2 or "").strip()
    if not p2:
        return p1
    if "{}" in p2:
        return p2.replace("{}", p1) if p1 else p2.replace("{},", "").replace("{}", "").strip(" ,")
    return (p1 + ", " + p2).strip(" ,") if p1 else p2


_jobs: dict[str, dict] = {}
_lock = threading.Lock()

# Tek sirali kuyruk: her emir sirasini bekler, ayni anda tek is calisir.
# _cv, _lock uzerine kurulu - kuyruk ve is kayitlari ayni kilit altinda.
_cv = threading.Condition(_lock)
_queue: list[str] = []          # bekleyen is id'leri, sirayla
_current: str | None = None     # su an calisan isin id'si
_dispatcher_started = False

# diske yazilmayacak alanlar (thread nesnesi, is akisi argumanlari)
_TRANSIENT = ("_thread", "_args")


# ------------------------------------------------------------------ kalicilik
def _snapshot(job: dict) -> dict:
    """_lock TUTULURKEN cagrilmali (kuyruk sirasini da okur)."""
    j = {k: v for k, v in job.items() if k not in _TRANSIENT}
    if j.get("file"):
        j["file_name"] = os.path.basename(j["file"])
        j["has_file"] = os.path.isfile(j["file"])
    jid = j.get("id")
    if jid == _current:
        j["position"] = 0            # 0 = simdi calisiyor
    elif jid in _queue:
        j["position"] = _queue.index(jid) + 1
    else:
        j["position"] = None
    return j


def _persist_locked() -> None:
    """_lock TUTULURKEN cagrilir."""
    try:
        os.makedirs(OUT_DIR, exist_ok=True)
        data = [_snapshot(j) for j in _jobs.values()]
        tmp = STORE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)
        os.replace(tmp, STORE)
    except Exception as e:  # kalicilik hatasi uretimi durdurmasin
        print("[comfy_gen] is listesi yazilamadi: %s" % e)


def _persist() -> None:
    with _lock:
        _persist_locked()


def _bootstrap() -> None:
    """Diskteki is listesini yukler, sonra sahipsiz ciktilari kurtarir."""
    loaded = []
    try:
        if os.path.isfile(STORE):
            loaded = json.load(open(STORE, encoding="utf-8"))
    except Exception as e:
        print("[comfy_gen] is listesi okunamadi: %s" % e)

    for j in loaded:
        # sunucu kapandiginda calisan isler oldu; onlari bitmis sayamayiz
        if j.get("status") in ("queued", "running"):
            j["status"] = "error"
            j["error"] = "sunucu yeniden baslatildi"
        _jobs[j["id"]] = j

    # data/generated altinda kaydi olmayan cikti dosyalari -> kurtarilmis is
    known = {os.path.normcase(j["file"]) for j in _jobs.values() if j.get("file")}
    try:
        found = []
        for root, dirs, files in os.walk(OUT_DIR):
            dirs[:] = [d for d in dirs if not d.startswith("_")]
            for fn in files:
                found.append((root, fn))
        for root, fn in sorted(found, key=lambda x: x[1]):
            path = os.path.join(root, fn)
            if not os.path.isfile(path) or fn.startswith("_"):
                continue
            if os.path.normcase(path) in known:
                continue
            stem, ext = os.path.splitext(fn)
            if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp", ".mp4", ".webm"):
                continue
            if stem in _jobs:
                _jobs[stem]["file"] = path
                continue
            ts = datetime.fromtimestamp(os.path.getmtime(path)).isoformat()
            rec_mode = os.path.basename(root)
            if rec_mode not in MODES:
                rec_mode = "free"
            _jobs[stem] = {
                "id": stem, "task": "kurtarilan", "mode": rec_mode,
                "prompt": "", "prompt2": "", "negative": "", "combined": "",
                "status": "done", "created_at": ts, "started_at": ts,
                "finished_at": ts, "seconds": None, "file": path, "error": None,
                "is_video": ext.lower() in (".mp4", ".webm"),
                "source_job": None, "client": None, "seed": None,
                "width": 0, "height": 0, "duration": 0, "turbo": True,
                "favorite": False, "note": "", "recovered": True,
                "progress": 100, "node": "",
            }
    except OSError:
        pass
    _persist()
    print("[comfy_gen] %d is yuklendi (%d kurtarildi)"
          % (len(_jobs), sum(1 for j in _jobs.values() if j.get("recovered"))))


# ------------------------------------------------------------------ altyapi
def _wf2api():
    """wf2api modulunu gec yukle - ComfyUI kurulu degilse modul yine de import edilir."""
    if COMFY_SCRIPTS not in sys.path:
        sys.path.insert(0, COMFY_SCRIPTS)
    import wf2api  # noqa: WPS433
    return wf2api


def _convert():
    """wf2api.convert (geriye donuk kisayol)."""
    return _wf2api().convert


def comfy_up(timeout: float = 2.0) -> bool:
    try:
        urllib.request.urlopen(COMFY + "/", timeout=timeout)
        return True
    except Exception:
        return False


def _post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        body = urllib.request.urlopen(req, timeout=180).read()
    except urllib.error.HTTPError as e:
        # ComfyUI 400'de asil nedeni govdede soyler (node_errors) - is kaydina
        # yalniz "HTTP Error 400" dusuyordu, teshis imkansizdi.
        try:
            detay = e.read().decode("utf-8", "replace")[:900]
        except Exception:
            detay = ""
        raise RuntimeError("ComfyUI %s %s: %s" % (e.code, path, detay or e.reason)) from e
    return json.loads(body) if body else {}


def _get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(COMFY + path, timeout=180).read())


def queue_depth() -> int:
    """ComfyUI kuyrugunda bekleyen + calisan is sayisi."""
    try:
        q = _get("/queue")
        return len(q.get("queue_running", [])) + len(q.get("queue_pending", []))
    except Exception:
        return 0


def tasks(mode: str = "") -> list[dict]:
    """Istemcinin gosterecegi gorev listesi (manifest'ten)."""
    out = []
    for t in _load_manifest():
        # Manifest'te "modes" verilmemisse gorev her kipte gecerlidir; CBN
        # kipinde yalniz gorsel gorevleri (uretim + edit) sunulur - orada video
        # yok. (Eski varsayilan ["free","jigsaw"] CBN'i dislayip gorev
        # listesini bos birakiyordu: telefonda "gorev secilemiyor".)
        izinli = t.get("modes") or list(MODES)
        if mode and mode not in izinli:
            continue
        if mode == "cbn" and t.get("is_video"):
            continue
        slots = task_inputs(t)
        out.append({"id": t["id"], "label": t["label"],
                    "needs_image": task_needs_image(t, slots),
                    "is_video": t["is_video"], "default_width": t["width"],
                    "default_height": t["height"], "default_duration": t["duration"],
                    # gorevin girdi yuvalari - istemci her biri icin bir secici gosterir
                    "inputs": [{k: s[k] for k in
                                ("slot", "kind", "label", "title", "default", "required")}
                               for s in slots]})
    return out


# ------------------------------------------------------------------ isler
def get_job(job_id: str) -> dict | None:
    with _lock:
        j = _jobs.get(job_id)
        return _snapshot(j) if j else None


def list_jobs(limit: int = 30, client: str | None = None, mode: str | None = None,
              favorites: bool = False) -> list[dict]:
    """client verilirse sadece o cihazin isleri doner."""
    with _lock:
        items = sorted(_jobs.values(), key=lambda j: j.get("created_at") or "", reverse=True)
        if client:
            items = [j for j in items if j.get("client") == client]
        if mode:
            items = [j for j in items if (j.get("mode") or "free") == mode]
        if favorites:
            items = [j for j in items if j.get("favorite")]
        return [_snapshot(j) for j in items[:limit]]


def job_file(job_id: str) -> str | None:
    with _lock:
        j = _jobs.get(job_id)
    if j and j.get("file") and os.path.isfile(j["file"]):
        return j["file"]
    return None


def set_meta(job_id: str, *, favorite: bool | None = None, note: str | None = None) -> dict | None:
    with _lock:
        j = _jobs.get(job_id)
        if not j:
            return None
        if favorite is not None:
            j["favorite"] = bool(favorite)
        if note is not None:
            j["note"] = note[:300]
        _persist_locked()
        return _snapshot(j)


def delete_job(job_id: str, remove_file: bool = True) -> bool:
    with _cv:
        if job_id in _queue:            # bekleyen isi once siradan cikar
            _queue.remove(job_id)
        j = _jobs.pop(job_id, None)
        if not j:
            return False
        _persist_locked()
    if remove_file and j.get("file"):
        for p in (j["file"], _thumb_path(job_id)):
            try:
                if p and os.path.isfile(p):
                    os.remove(p)
            except OSError:
                pass
    return True


def cancel_job(job_id: str) -> bool:
    """Siradaki isi kuyruktan cikarir, calisan isi keser."""
    with _cv:
        j = _jobs.get(job_id)
        if not j or j.get("status") not in ("queued", "running"):
            return False
        j["cancel"] = True
        if job_id in _queue:            # henuz baslamamis - sadece siradan cikar
            _queue.remove(job_id)
            j.update(status="cancelled", error="iptal edildi",
                     finished_at=datetime.now().isoformat())
            j.pop("_args", None)
            _persist_locked()
            return True
        pid = j.get("comfy_prompt_id")
    if pid:
        try:
            _post("/queue", {"delete": [pid]})
        except Exception:
            pass
        try:
            running = _get("/queue").get("queue_running", [])
            if any(pid in json.dumps(r) for r in running):
                _post("/interrupt", {})
        except Exception:
            pass
    return True


# ------------------------------------------------------------------ kuyruk
def queue_state() -> dict:
    """Kuyrugun anlik hali - arayuzler bunu izler."""
    with _cv:
        running = _jobs.get(_current) if _current else None
        return {
            "running": _snapshot(running) if running else None,
            "pending": [_snapshot(_jobs[i]) for i in _queue if i in _jobs],
            "depth": len(_queue) + (1 if running else 0),
            "comfy_up": None,          # sunucu katmani dolduruyor (yavas cagri)
        }


def move_job(job_id: str, delta: int) -> bool:
    """Bekleyen bir isi kuyrukta yukari (-1) / asagi (+1) tasir."""
    with _cv:
        if job_id not in _queue:
            return False
        i = _queue.index(job_id)
        k = max(0, min(len(_queue) - 1, i + delta))
        if k == i:
            return False
        _queue.insert(k, _queue.pop(i))
        return True


def clear_queue() -> int:
    """Bekleyen tum isleri iptal eder; calisan is devam eder."""
    with _cv:
        ids, _queue[:] = list(_queue), []
        for jid in ids:
            j = _jobs.get(jid)
            if j:
                j.update(status="cancelled", error="kuyruk temizlendi",
                         finished_at=datetime.now().isoformat())
                j.pop("_args", None)
        _persist_locked()
    return len(ids)


def free_comfy() -> bool:
    """ComfyUI'nin yukledigi modelleri bosaltir (VRAM + RAM). Yalniz GPU
    seridi bizdeyken cagrilir - aksi halde calisan uretimi keser."""
    try:
        _post("/free", {"unload_models": True, "free_memory": True})
        return True
    except Exception:
        return False


def _dispatcher() -> None:
    """Kuyruktaki isleri tek tek, sirayla calistirir. Her is GPU seridini
    (gpu_lane) alir: etiketleme / CBN insa / muzik ile ayni FIFO'da."""
    global _current
    while True:
        with _cv:
            while not _queue:
                _cv.wait()
            job_id = _queue.pop(0)
            job = _jobs.get(job_id)
            if not job or job.get("cancel"):
                continue
            args = job.pop("_args", None)
            _current = job_id
        try:
            if args:
                from . import gpu_lane
                # #299: bilet isin id'sini tasir - Sira ekrani ilerlemeyi eslestirir.
                with gpu_lane.hold("uretim: %s" % job["task"], kind="comfy", job_id=job_id):
                    _run_job(job_id, job["task"], args)
        except Exception as e:  # noqa: BLE001 - dispatcher asla olmemeli
            print("[comfy_gen] dispatcher hatasi: %s" % e)
        finally:
            with _cv:
                _current = None
            _persist()


def _start_dispatcher() -> None:
    global _dispatcher_started
    with _cv:
        if _dispatcher_started:
            return
        _dispatcher_started = True
    threading.Thread(target=_dispatcher, name="comfy-dispatcher", daemon=True).start()


# ------------------------------------------------------------------ onizleme
def _ffmpeg() -> str | None:
    """ffmpeg'i PATH'te, WinGet baglantilarinda veya imageio paketinde arar."""
    cands = [
        shutil.which("ffmpeg"),
        os.path.join(os.environ.get("LOCALAPPDATA", ""),
                     r"Microsoft\WinGet\Links\ffmpeg.exe"),
    ]
    for c in cands:
        if c and os.path.isfile(c):
            return c
    try:
        import imageio_ffmpeg
        p = imageio_ffmpeg.get_ffmpeg_exe()
        return p if os.path.isfile(p) else None
    except Exception:
        return None


def _thumb_path(job_id: str) -> str:
    return os.path.join(THUMB_DIR, job_id + ".jpg")


def thumb(job_id: str, size: int = 360) -> str | None:
    """Isin kucuk JPEG onizlemesini uretir (bir kez) ve yolunu doner.

    Video isleri icin ilk kare ffmpeg ile alinir. Galeride tam boy PNG/MP4
    indirmemek icin var - telefon ve LAN tarafinda fark buyuk.
    """
    src = job_file(job_id)
    if not src:
        return None
    dst = _thumb_path(job_id)
    try:
        if os.path.isfile(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
            return dst
    except OSError:
        pass
    os.makedirs(THUMB_DIR, exist_ok=True)

    ext = os.path.splitext(src)[1].lower()
    try:
        if ext in (".mp4", ".webm", ".mov"):
            ff = _ffmpeg()
            if not ff:
                return None
            subprocess.run([ff, "-loglevel", "error", "-y", "-ss", "0.5", "-i", src,
                            "-frames:v", "1", "-vf", "scale=%d:-2" % size, dst],
                           check=True, timeout=60,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        else:
            from PIL import Image
            im = Image.open(src)
            if getattr(im, "n_frames", 1) > 1:
                im.seek(0)
            im = im.convert("RGB")
            im.thumbnail((size, size * 3))
            im.save(dst, "JPEG", quality=82)
        return dst if os.path.isfile(dst) else None
    except Exception as e:
        print("[comfy_gen] onizleme uretilemedi (%s): %s" % (job_id, e))
        return None


# ------------------------------------------------------------------ ilerleme
def _watch_progress(job_id: str, client_id: str) -> None:
    """ComfyUI websocket'inden adim adim ilerlemeyi okur.

    websocket-client kurulu degilse sessizce vazgecer; is yine calisir,
    sadece yuzdelik gostergesi olmaz.
    """
    try:
        import websocket  # noqa: WPS433
    except Exception:
        return
    try:
        ws = websocket.create_connection("%s?clientId=%s" % (COMFY_WS, client_id), timeout=10)
    except Exception:
        return
    try:
        ws.settimeout(5)
        while True:
            with _lock:
                j = _jobs.get(job_id)
                if not j or j.get("status") not in ("queued", "running"):
                    return
            try:
                raw = ws.recv()
            except Exception:
                continue
            if not isinstance(raw, str):
                continue
            try:
                msg = json.loads(raw)
            except Exception:
                continue
            kind, d = msg.get("type"), msg.get("data") or {}
            with _lock:
                j = _jobs.get(job_id)
                if not j:
                    return
                if kind == "progress" and d.get("max"):
                    j["progress"] = int(d.get("value", 0) / d["max"] * 100)
                elif kind == "executing":
                    j["node"] = str(d.get("node") or "")
                elif kind == "execution_cached":
                    j["progress"] = max(j.get("progress") or 0, 2)
    finally:
        try:
            ws.close()
        except Exception:
            pass


# ------------------------------------------------------------------ uretim

# Gorselden video: cikti boyutu KAYNAGIN oranindan turer. Sabit 704x1280
# dayatmak yatay/kare kaynaklari ortadan kirpiyordu (LTX latent'e sigdirirken
# center-crop yapar) - kafasi kesik plaj videolari boyle cikti (gorev #268).
VIDEO_PIXEL_BUDGET = 704 * 1280     # dikey varsayilanla ayni piksel yuku
VIDEO_LONG_SIDE_MAX = 1280
VIDEO_STEP = 32                     # LTX her iki kenari 32'nin kati ister


def video_size_for(image_path: str, budget: int = VIDEO_PIXEL_BUDGET,
                   step: int = VIDEO_STEP, long_max: int = VIDEO_LONG_SIDE_MAX) -> tuple[int, int]:
    """Kaynak gorselin oranini koruyan, piksel butcesine sigan (w, h)."""
    from PIL import Image
    with Image.open(image_path) as im:
        w, h = im.size
    scale = (budget / float(w * h)) ** 0.5
    if max(w, h) * scale > long_max:
        scale = long_max / float(max(w, h))
    rw = max(step, int(round(w * scale / step)) * step)
    rh = max(step, int(round(h * scale / step)) * step)
    return rw, rh

def submit(task: str, prompt: str, *, prompt2: str = "", negative: str = "",
           width: int = 0, height: int = 0, duration: int = 5, seed: int | None = None,
           turbo: bool = True, image_path: str | None = None,
           source_job: str | None = None, client: str | None = None,
           mode: str = "free", category: str = "",
           extras: list | None = None, inputs: dict | None = None) -> dict:
    """Yeni uretim isi kuyruga alir; job kaydini doner.

    Girdi dosyalari uc yoldan gelebilir:
      * inputs      - yuva -> {"job_id": ...} | {"path": ...} (gorev #287).
                      Yuvalar workflow_inputs() ile is akisindan cikarilir:
                      FLF2V ilk+son kare, V2V referans + surucu video, S2V
                      gorsel + ses...
      * image_path  - masaustunden gelen mutlak dosya yolu (eski istemciler)
      * source_job  - daha once uretilmis bir isin id'si (telefon/LAN bunu
                      kullanir, dosya zaten sunucuda oldugu icin yukleme yok)

    prompt2 ikinci pozitif prompttur; jigsaw kipinde guzellik sablonudur.
    """
    spec = _task(task)
    if spec is None:
        raise ValueError("bilinmeyen gorev: %s" % task)
    slots = task_inputs(spec)
    need_img, is_vid = task_needs_image(spec, slots), spec["is_video"]
    mode = mode if mode in MODES else "free"
    md = MODES[mode]

    if source_job and not image_path:
        src = job_file(source_job)
        if not src:
            raise ValueError("kaynak is bulunamadi veya ciktisi yok: %s" % source_job)
        if os.path.splitext(src)[1].lower() in (".mp4", ".webm", ".mov"):
            raise ValueError("kaynak bir video - girdi olarak gorsel gerekiyor")
        image_path = src

    # --- yuvalari coz: is ciktisi ya da dosya yolu -> yerel mutlak yol
    cozulen: dict[str, str] = {}
    for slot, ref in (inputs or {}).items():
        s = next((x for x in slots if x["slot"] == slot), None)
        if s is None:
            raise ValueError("bu gorevde '%s' diye bir girdi yuvasi yok" % slot)
        if isinstance(ref, str):
            yol, kaynak = ref, ref
        elif isinstance(ref, dict) and ref.get("job_id"):
            kaynak = str(ref["job_id"])
            yol = job_file(kaynak)
            if not yol:
                raise ValueError("kaynak is bulunamadi veya ciktisi yok: %s" % kaynak)
        elif isinstance(ref, dict):
            yol = kaynak = ref.get("path") or ""
        else:
            raise ValueError("'%s' yuvasi icin gecersiz girdi" % slot)
        if not yol or not os.path.isfile(yol):
            raise ValueError("'%s' yuvasinin dosyasi bulunamadi: %s" % (slot_name(s), kaynak))
        if os.path.splitext(yol)[1].lower() not in _KIND_EXT[s["kind"]]:
            raise ValueError("'%s' yuvasi %s dosyasi istiyor (%s verildi)"
                             % (slot_name(s), _KIND_LABEL[s["kind"]], os.path.basename(yol)))
        cozulen[slot] = yol

    img_slots = [s for s in slots if s["kind"] == "image"]
    # Eski istemciler tek bir gorsel yollar: is akisindaki TUM gorsel yuvalari
    # onunla dolar (eskiden her LoadImage ayni dosyaya ayarlaniyordu).
    if image_path and not any(s["slot"] in cozulen for s in img_slots):
        for s in img_slots:
            cozulen[s["slot"]] = image_path
    if not image_path:
        ilk = next((s for s in img_slots if s["slot"] in cozulen), None)
        if ilk:
            image_path = cozulen[ilk["slot"]]

    eksik = [s for s in slots if s.get("required") and s["slot"] not in cozulen]
    if eksik:
        raise ValueError("Bu is akisi eksik girdi ile calismaz - eksik olanlar: %s"
                         % ", ".join(slot_name(s) for s in eksik))
    if need_img and not (image_path and os.path.isfile(image_path)):
        raise ValueError("bu gorev bir girdi gorseli istiyor")

    # kip varsayilanlari: istemci bos birakirsa devreye girer
    # Kip sablonu yalniz METINDEN uretimde ve videoda devreye girer: bir edit
    # isinde (girdi gorseli olan, video olmayan) prompt bir degisiklik
    # talimatidir - "a breathtakingly beautiful young woman, {}" kalibina
    # sarilmasi anlamsiz olur (goruntuleyicideki Duzenle dugmesi, gorev #274).
    is_edit = need_img and not is_vid
    if not prompt2 and mode in ("jigsaw", "character", "card") and not is_edit:   # #321
        prompt2 = md["motion2"] if is_vid else md["prompt2"]
    if not negative:
        negative = md["negative"] or (NEG_VID if is_vid else NEG_IMG)
    if is_vid and image_path and not (width and height):
        # Istemci boyut vermediyse kaynagin orani belirler (yatay, kare, dikey).
        try:
            width, height = video_size_for(image_path)
        except Exception:
            width, height = 0, 0
    if md.get("width") and not (width and height):
        width, height = (704, 1280) if is_vid else (md["width"], md["height"])

    combined = combine(prompt, prompt2)
    extra_txt = extras_text(extras)
    if extra_txt:
        combined = (combined + ", " + extra_txt).strip(" ,")
    if not combined:
        raise ValueError("prompt bos")

    job_id = uuid.uuid4().hex[:12]
    job = {
        "id": job_id, "task": task, "mode": mode, "category": category,
        "prompt": prompt, "prompt2": prompt2, "combined": combined,
        "negative": negative, "extras": list(extras or []),
        "status": "queued", "created_at": datetime.now().isoformat(),
        "started_at": None, "finished_at": None, "seconds": None,
        "file": None, "error": None, "is_video": is_vid,
        "source_job": source_job, "client": client,
        "seed": seed, "width": width or spec["width"], "height": height or spec["height"],
        "duration": duration or spec["duration"], "turbo": turbo,
        "favorite": False, "note": "", "progress": 0, "node": "",
        # galeride/kuyrukta gosterilebilsin diye yuva -> dosya adi
        "inputs": {k: os.path.basename(v) for k, v in cozulen.items()},
        "_args": dict(prompt=combined, negative=negative,
                      width=width or spec["width"] or 1024,
                      height=height or spec["height"] or 1024,
                      duration=duration or spec["duration"], seed=seed, turbo=turbo,
                      image_path=image_path, inputs=cozulen),
    }
    _start_dispatcher()
    with _cv:
        _jobs[job_id] = job
        _queue.append(job_id)
        _persist_locked()
        snap = _snapshot(job)
        _cv.notify()
    return snap


def _run_job(job_id: str, task: str, a: dict) -> None:
    """Tek bir isi bastan sona calistirir. Dispatcher tarafindan cagrilir."""
    import random
    spec = _task(task)
    wf_name, is_vid = spec["workflow"], spec["is_video"]
    with _lock:
        mode = (_jobs.get(job_id, {}).get("mode") or "free")
    t0 = time.time()

    def upd(**kw):
        with _lock:
            if job_id in _jobs:
                _jobs[job_id].update(kw)

    def cancelled() -> bool:
        with _lock:
            return bool(_jobs.get(job_id, {}).get("cancel"))

    upd(status="running", started_at=datetime.now().isoformat())
    try:
        # ComfyUI kapaliysa is kuyrukta olmeye devam etmesin - kisa sure bekle
        if not comfy_up():
            upd(node="ComfyUI bekleniyor")
            for _ in range(60):          # ~5 dk
                time.sleep(5)
                if cancelled() or comfy_up():
                    break
            if not comfy_up():
                raise RuntimeError("ComfyUI calismiyor (127.0.0.1:8188)")
            upd(node="")
        w2a = _wf2api()
        convert = w2a.convert
        wf = json.load(open(os.path.join(WFDIR, wf_name), encoding="utf-8"))
        seed = a["seed"] if a["seed"] is not None else random.randint(1, 2 ** 31)
        upd(seed=seed)
        ov = {"seed": seed, "noise_seed": seed, "width": a["width"], "height": a["height"]}
        if is_vid:
            ov.update({"prompt": a["prompt"], "duration": a["duration"],
                       "frame_rate": 24, "prompt_enhance": False})
        else:
            ov.update({"prompt": a["prompt"], "positive_prompt": a["prompt"],
                       "negative_prompt": a["negative"], "enable_turbo_mode": a["turbo"]})
        # --- girdi yuvalari: her dosya ComfyUI/input'a ise ozgu adla kopyalanir
        # ve YALNIZ kendi dugumune yazilir (gorev #287). Donusturucu dugum
        # numaralarini yeniden uretir, o yuzden eslestirme is akisi JSON'u
        # uzerinde, cevirmeden ONCE yapilir.
        slots = workflow_inputs(wf_name)
        kopyalar: dict[str, str] = {}
        if slots:
            os.makedirs(COMFY_IN, exist_ok=True)
        for s in slots:
            src = (a.get("inputs") or {}).get(s["slot"])
            if not src or not os.path.isfile(src):
                continue
            ext = os.path.splitext(src)[1] or os.path.splitext(s.get("default") or "")[1] or ".png"
            ad = "agb_%s_%s%s" % (job_id, s["slot"], ext)
            shutil.copy(src, os.path.join(COMFY_IN, ad))
            kopyalar[s["slot"]] = ad
        # Dolu olmayan yuva is akisinin kendi varsayilaniyla kalir; yine de
        # yaziyoruz ki widget girisi bildirmeyen dugumlerde (LoadVideo) dosya
        # adi API grafigine dussun.
        _apply_slot_files(wf, slots, kopyalar)

        graph = convert(wf, ov)

        for n in graph.values():
            ct = n["class_type"]
            if ct.startswith(("SaveImage", "SaveVideo")):
                n["inputs"]["filename_prefix"] = "agb_gen"

        # Grafigi GONDERMEDEN once denetle (gorev #326): ComfyUI'nin 400'u
        # "prompt_outputs_failed_validation" diye gelip is kaydina anlamsiz
        # dusuyordu; burada hangi dugumde ne eksik oldugunu soyluyoruz.
        sorun = w2a.validate_graph(graph)
        if sorun:
            raise RuntimeError("is akisi gecersiz (%s): %s"
                               % (wf_name, " | ".join(sorun[:4])))

        cid = "agb-" + job_id
        threading.Thread(target=_watch_progress, args=(job_id, cid), daemon=True).start()
        pid = _post("/prompt", {"prompt": graph, "client_id": cid})["prompt_id"]
        upd(comfy_prompt_id=pid)

        out = None
        while time.time() - t0 < 5400:
            time.sleep(3)
            if cancelled():
                raise RuntimeError("kullanici iptal etti")
            try:
                hist = _get("/history/" + pid)
            except Exception:
                continue
            if pid not in hist:
                continue
            st = hist[pid].get("status", {})
            if st.get("status_str") == "error":
                msgs = [m for m in st.get("messages", []) if m and m[0] == "execution_error"]
                raise RuntimeError(json.dumps(msgs, ensure_ascii=False)[:400])
            for _k, o in hist[pid].get("outputs", {}).items():
                for key in ("images", "videos", "gifs"):
                    for f in o.get(key, []) or []:
                        src = os.path.join(COMFY_OUT, f.get("subfolder", ""), f["filename"])
                        if os.path.isfile(src):
                            # Cikti kipin kendi klasorune duser: free/ ve jigsaw/
                            # ayri kalsin, galeriler karismasin.
                            d = os.path.join(OUT_DIR, mode)
                            os.makedirs(d, exist_ok=True)
                            dst = os.path.join(d, job_id + os.path.splitext(src)[1])
                            shutil.copy(src, dst)
                            out = dst
            break

        if not out:
            raise RuntimeError("cikti alinamadi (zaman asimi olabilir)")
        upd(status="done", file=out, finished_at=datetime.now().isoformat(),
            progress=100, node="", seconds=round(time.time() - t0, 1))
        threading.Thread(target=thumb, args=(job_id,), daemon=True).start()
    except Exception as e:  # noqa: BLE001
        cancel = cancelled()
        upd(status="cancelled" if cancel else "error",
            error=("iptal edildi" if cancel else str(e)[:500]),
            finished_at=datetime.now().isoformat(), seconds=round(time.time() - t0, 1))
    finally:
        _persist()


# ------------------------------------------------------------------ jigsaw
# Jigsaw kipi r2manager'in Incoming -> Accept akisini taklit eder: uretim bir
# koleksiyon SECMEZ; biten gorsel+video ciftleri "kabul bekliyor" listesine
# duser, orada koleksiyon secilip Accept'e basilinca havuza numaralanarak yazilir.


def jigsaw_collections() -> list[dict]:
    """Havuzdaki koleksiyonlar + her birinin siradaki numarasi."""
    names: set[str] = set()
    for root in (JIGSAW_ROOT, JIGSAW_PUSHED):
        try:
            names.update(d for d in os.listdir(root)
                         if os.path.isdir(os.path.join(root, d)))
        except OSError:
            pass
    return [{"name": n, "next": _jigsaw_next(n), "count": _jigsaw_count(n)}
            for n in sorted(names, key=str.lower)]


# geriye donuk ad - eski istemciler bu ucu cagiriyor
jigsaw_categories = jigsaw_collections


def _resolve_collection(requested: str) -> str:
    """Yazilan adi gercek klasor adina esler (r2manager ile ayni kural).

    Bos veya 'generic' -> Generic. Var olan bir klasorle buyuk/kucuk harf
    farkiyla eslesiyorsa o klasor kullanilir; yoksa yeni ad aynen gecer.
    """
    name = (requested or "").strip()
    if not name or name.lower() == "generic":
        return "Generic"
    if any(c in name for c in '\\/:*?"<>|'):
        raise ValueError("koleksiyon adi gecersiz")
    for root in (JIGSAW_ROOT, JIGSAW_PUSHED):
        try:
            for d in os.listdir(root):
                if d.lower() == name.lower() and os.path.isdir(os.path.join(root, d)):
                    return d
        except OSError:
            pass
    return name


def _jigsaw_nums(collection: str) -> list[int]:
    """Numara havuzu hem sahnelenen hem gonderilmis klasorden okunur.

    Ikisini birden taramak sart: Generic'te numaralar R2 genelinde benzersiz
    olmali, gonderilmis olanlar sahneleme klasorunde durmuyor.
    """
    nums: list[int] = []
    for root in (JIGSAW_ROOT, JIGSAW_PUSHED):
        d = os.path.join(root, collection)
        try:
            for fn in os.listdir(d):
                stem = os.path.splitext(fn)[0].split("-")[0]
                if stem.isdigit():
                    nums.append(int(stem))
        except OSError:
            pass
    return nums


def _jigsaw_next(collection: str) -> int:
    nums = _jigsaw_nums(collection)
    return (max(nums) + 1) if nums else 1


def _jigsaw_count(collection: str) -> int:
    return len(set(_jigsaw_nums(collection)))


def jigsaw_pending() -> list[dict]:
    """Kabul bekleyen gorsel+video ciftleri.

    Bir cift = jigsaw kipinde uretilmis, havuza gonderilmemis bir GORSEL isi ve
    ondan turetilmis videolar (source_job ile baglilar). Video henuz yoksa cift
    yine listelenir - kullanici once videosunu uretir.
    """
    with _lock:
        jobs = [_snapshot(j) for j in _jobs.values()]
    by_src: dict[str, list[dict]] = {}
    for j in jobs:
        if j.get("is_video") and j.get("status") == "done" and j.get("source_job"):
            by_src.setdefault(j["source_job"], []).append(j)

    out = []
    for j in sorted(jobs, key=lambda x: x.get("created_at") or "", reverse=True):
        if (j.get("mode") != "jigsaw" or j.get("is_video")
                or j.get("status") != "done" or j.get("exported")):
            continue
        vids = [v for v in by_src.get(j["id"], []) if not v.get("exported")]
        vids.sort(key=lambda v: v.get("created_at") or "")
        out.append({"image": j, "videos": vids})
    return out


def jigsaw_accept(image_job: str, video_job: str | None, collection: str,
                  number: int | None = None) -> dict:
    """Cifti havuza <n>.jpg / <n>.mp4 / <n>.webp olarak yazar (r2manager Accept).

    Numara koleksiyonda bos olan ilk sirada; webp, r2manager'in da cagirdigi
    ortak kodlayiciyla uretilir ki kovadakilerle ayni ayarda olsun.
    """
    coll = _resolve_collection(collection)

    img = job_file(image_job)
    if not img:
        raise ValueError("gorsel isin ciktisi yok")
    if os.path.splitext(img)[1].lower() in (".mp4", ".webm"):
        raise ValueError("gorsel yerine video secildi")

    vid = job_file(video_job) if video_job else None
    if video_job and not vid:
        raise ValueError("video isin ciktisi yok")

    dest = os.path.join(JIGSAW_ROOT, coll)
    os.makedirs(dest, exist_ok=True)
    n = number or _jigsaw_next(coll)
    if os.path.isfile(os.path.join(dest, "%d.jpg" % n)):
        raise ValueError("%d numarasi %s icinde zaten dolu" % (n, coll))

    written, warnings = [], []

    # 1) hareketsiz gorsel -> <n>.jpg (oran korunur; dikey 720x1280, yatay
    #    1280x720, kare 1280x1280). Eskiden 720x1280'e ortadan kirpiliyordu ve
    #    genis gorsellerin yalnizca ortasi kaliyordu (gorev #268).
    still_to_pool(img, os.path.join(dest, "%d.jpg" % n))
    written.append("%d.jpg" % n)

    if vid:
        shutil.copy(vid, os.path.join(dest, "%d.mp4" % n))
        written.append("%d.mp4" % n)
        ok, err = _encode_webp(vid, os.path.join(dest, "%d.webp" % n))
        if ok:
            written.append("%d.webp" % n)
        else:
            warnings.append("webp uretilemedi: %s" % err[:200])
    else:
        warnings.append("video yok - sadece jpg yazildi")

    with _lock:
        for jid in (image_job, video_job):
            if jid and jid in _jobs:
                _jobs[jid]["exported"] = "%s/%d" % (coll, n)
        _persist_locked()

    return {"collection": coll, "category": coll, "number": n, "folder": dest,
            "written": written, "warnings": warnings, "next": _jigsaw_next(coll)}


def still_to_pool(src: str, dest: str) -> None:
    """Havuz jpg'si: kaynagin orani korunur, uzun kenar JIGSAW_STILL'in uzun
    kenarina (1280) olceklenir, kirpma yok, q92. r2manager/jigsaw_flow ile
    ayni islem ki iki yoldan gelen varliklar kovada ayni olcude olsun."""
    from PIL import Image
    with Image.open(src) as f:
        im = f.convert("RGB")
    long_side = max(JIGSAW_STILL)
    scale = long_side / float(max(im.width, im.height))
    if scale != 1.0:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))),
                       Image.LANCZOS)
    im.save(dest, "JPEG", quality=92)


def _encode_webp(src: str, dest: str) -> tuple[bool, str]:
    """Hareketli WebP - r2manager'in kullandigi ortak kodlayici.

    Ayni fonksiyon: kabul edilen varliklar kovadakilerle ayni ayarlarda
    kodlanir (24 fps, 320 px, libwebp_anim q80). Modul bulunamazsa yerel bir
    ffmpeg cagrisina duser.
    """
    tools = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__)))), "tools", "hotidle_wall_webp")
    try:
        if tools not in sys.path:
            sys.path.insert(0, tools)
        from encode_upload import encode_file  # noqa: WPS433
        from pathlib import Path
        return encode_file(Path(src), Path(dest))
    except Exception as e:
        ff = _ffmpeg()
        if not ff:
            return False, "ortak kodlayici yok (%s) ve ffmpeg bulunamadi" % e
        try:
            subprocess.run(
                [ff, "-y", "-loglevel", "error", "-i", src,
                 "-vf", "fps=24,scale=%d:-2:flags=lanczos" % JIGSAW_WEBP[0],
                 "-c:v", "libwebp_anim", "-q:v", "80", "-loop", "0", "-an",
                 "-f", "webp", dest],
                check=True, timeout=900,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            return True, ""
        except Exception as e2:
            return False, str(e2)


def jigsaw_reject(image_job: str) -> dict:
    """Cifti tumuyle siler (r2manager Reject): gorsel + ona bagli videolar."""
    with _lock:
        vids = [j["id"] for j in _jobs.values()
                if j.get("source_job") == image_job and not j.get("exported")]
    removed = 0
    for jid in vids + [image_job]:
        if delete_job(jid):
            removed += 1
    return {"deleted": removed}


# geriye donuk ad
export_jigsaw = jigsaw_accept


_bootstrap()
