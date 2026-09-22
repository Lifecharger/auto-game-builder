"""Varlik normalizeri (#385): UC icerik havuzundaki HER gorsel ayni semayla
etiketli, ayni kurallarla sunulur ve AGB'den engellenebilir olur.

Havuzlar ve indeks mekanizmasi (her havuz icin TEK mekanizma, bilincli secim):

* ``gallery-hot`` - `collections/<id>/images/<n>.jpg`. Etiket gorselin
  KENDI EXIF'inde durur (XPKeywords / XPSubject / XPTitle - `exif_writer`'in
  yazdigi bicim, worker'in `parseEXIFRich`'inin okudugu bicim). Worker'in
  filtreledigi kompakt indeks `serve_index_<collection>` KV anahtarinda durur
  ve BURADAN yazilir (`PUT /serve-index`): worker yalniz OKUR, sunucu YAZAR.
  EXIF guvenilir (hepsi jpg), o yuzden yan dosya yok.

* ``cards`` - kovada `_still_*` anahtari YOK (2026-09-22 listesi), bu yuzden
  etiket kaynagi sheet'in ILK KARESI (cols/rows/frameW/frameH ile kirpilir).
  Animasyonlu/grid webp'e EXIF yazmak guvenilir degil; indeks bu yuzden
  `manifest.json` icindeki kart/dealer girdilerinin `metadata` alanidir -
  worker zaten manifest'i okuyor, ikinci bir kaynak gerekmez.

* ``events`` - sunucu sahibi Celeste'in `host/L<n>.webp` durus gorselleri.
  Yine webp; indeks kovadaki YAN DOSYA `_meta/host.json`:
  ``{updated, levels: {"<n>": {subject_fields, title_fields, ...}}}``.
  events worker'in KV baglantisi yok, kovayi okuyor - indeks de orada durur.

Calisma sekli: her havuz bir OP'tur (jigsaw_flow op defteri -> `/api/queue`
ilerlemesi, `/api/queue/cancel` ile iptal). sha256 ile atlanabilir, yani yarida
kesilen bir kosu bastan baslatilabilir. `dry_run` yalniz rapor uretir.

Etiketleyici YEREL Ollama'dir (asla bulut): GPU seridi (`gpu_lane`) parti
basina BIR kez alinir, model parti boyunca bellekte kalir, parti bitince
birakilir - `jigsaw_flow._tag_batch` ile ayni sozlesme.
"""
from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.request
from datetime import datetime

from . import jigsaw_flow as JF

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SETTINGS = os.path.join(_ROOT, "server", "config", "settings.json")
_DATA_DIR = os.path.join(_ROOT, "server", "data")
_REPORT_FILE = os.path.join(_DATA_DIR, "normalize_reports.json")

POOLS = ("gallery-hot", "cards", "events")

# Havuz -> (kova, indeks mekanizmasi acikamasi)
POOL_INFO = {
    "gallery-hot": {"bucket": "gallery-hot", "label": "Jigsaw koleksiyonlari",
                    "index": "EXIF (jpg) + KV serve_index_<collection>"},
    "cards": {"bucket": "cards", "label": "Kart desteleri + dealer/joker",
              "index": "manifest.json icindeki metadata alani"},
    "events": {"bucket": "events", "label": "Etkinlik sunucusu (host L<n>)",
               "index": "kovada _meta/host.json yan dosyasi"},
}

# ------------------------------------------------------------------ sema
# Etiketin EXIF'e / metadata'ya yazilan alan adlari. tagging_schema'daki
# uzun adlarin KISA karsiligi; worker ikisini de bu adlarla okur.
_SUBJECT_MAP = {"rating": "rating", "safety": "safety_level", "voyeur": "voyeur_risk",
                "skin": "skin_exposure", "adult": "adult", "racy": "racy",
                "violence": "violence", "camera": "camera_angle", "view": "view_type",
                "pose": "pose_type", "framing": "framing", "mood": "mood",
                "context": "context_flag"}
_TITLE_MAP = {"coverage": "clothing_coverage", "fit": "clothing_fit", "risk": "risk_factors",
              "flags": "policy_flags", "body": "body_parts", "clothing": "clothing_type",
              "style": "art_style", "setting": "setting", "focus": "visual_focus"}

# Kisa ad -> izinli degerler (sema enum'larinin kisa ad karsiligi). Listede
# olmayan alan (mood, camera, ...) serbest metindir, yalniz DOLU olmali.
_ENUMS = {"rating": ("kid", "teen", "adult"),
          "safety": ("safe", "borderline", "risky"),
          "voyeur": ("none", "low", "medium", "high"),
          "skin": ("low", "medium", "high", "very_high"),
          "framing": ("full_body", "upper_body", "portrait", "close_up"),
          "context": ("ok", "mismatch"),
          "coverage": ("minimal", "revealing", "moderate", "modest"),
          "fit": ("loose", "fitted", "tight")}
_INTS = ("adult", "racy", "violence")
# Bos LISTE gecerli bir cevaptir (risk/flags bos olabilir) - exif_writer bunu
# "none" olarak yazar, okurken tekrar bos listeye cevrilir.
_LIST_FIELDS = ("risk", "flags", "body", "clothing", "style", "setting", "focus")


def _schema():
    """tagging_schema.py'yi ice alir (r2manager'in app.py'si ice ALINMAZ - o
    modul `import config` yaptigi icin AGB'nin config paketiyle cakisiyor)."""
    yol = os.path.join(_ROOT, "tools", "r2manager", "tagging_schema.py")
    spec = importlib.util.spec_from_file_location("agb_tagging_schema", yol)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def validate_tags(data: dict) -> None:
    """Ollama'nin dondurdugu TAM semayi dogrular; ihlalde ValueError.

    card_metadata.tag_still ile ayni kurallar - eksik alan varsayilana
    DUSMEZ, hata olur (rapor satiri olur, sessiz varsayilan olmaz).
    """
    sema = _schema()._OLLAMA_TAG_SCHEMA
    for alan in sema["required"]:
        if alan not in data:
            raise ValueError("eksik alan: " + alan)
    for alan, kural in sema["properties"].items():
        deger = data[alan]
        if "enum" in kural and deger not in kural["enum"]:
            raise ValueError("gecersiz deger %s=%r" % (alan, deger))
        if kural["type"] == "string" and not isinstance(deger, str):
            raise ValueError("metin bekleniyordu: " + alan)
        if kural["type"] == "integer" and (type(deger) is not int or not 1 <= deger <= 5):
            raise ValueError("1-5 arasi sayi bekleniyordu: " + alan)
        if kural["type"] == "array" and (not isinstance(deger, list)
                                        or any(not isinstance(x, str) for x in deger)):
            raise ValueError("metin listesi bekleniyordu: " + alan)


def fields_from_tags(data: dict) -> tuple[dict, dict]:
    """Sema cevabini worker'in okudugu kisa alan adlarina cevirir."""
    return ({kisa: data[uzun] for kisa, uzun in _SUBJECT_MAP.items()},
            {kisa: data[uzun] for kisa, uzun in _TITLE_MAP.items()})


def conforms(entry: dict | None) -> tuple[bool, str]:
    """Bir indeks girdisi semaya uyuyor mu? (uyar, uymuyorsa NEDEN)."""
    if not isinstance(entry, dict):
        return False, "metadata yok"
    subj = entry.get("subject_fields")
    title = entry.get("title_fields")
    if not isinstance(subj, dict) or not isinstance(title, dict):
        return False, "subject/title alanlari yok"
    for kisa in _SUBJECT_MAP:
        if kisa not in subj:
            return False, "subject eksik: " + kisa
    for kisa in _TITLE_MAP:
        if kisa not in title:
            return False, "title eksik: " + kisa
    for kaynak in (subj, title):
        for kisa, deger in kaynak.items():
            if kisa in _INTS:
                if not isinstance(deger, int) or not 1 <= deger <= 5:
                    return False, "%s sayisi gecersiz: %r" % (kisa, deger)
                continue
            if kisa in _ENUMS:
                if str(deger) not in _ENUMS[kisa]:
                    return False, "%s degeri gecersiz: %r" % (kisa, deger)
                continue
            if kisa in _LIST_FIELDS:
                continue                      # liste ya da "none" - ikisi de gecerli
            if not str(deger or "").strip():
                return False, "%s bos" % kisa
    return True, ""


# ------------------------------------------------------------------ EXIF
def _pipe(metin: str | None, sayisal: tuple = ()) -> dict:
    """`a:1|b:x,y` -> {"a":1,"b":["x","y"]} - worker'in parsePipeDelimitedFields'i
    ile BIRE BIR ayni; iki taraf ayni metni ayni sekilde cozmek zorunda."""
    out: dict = {}
    if not metin:
        return out
    for parca in metin.split("|"):
        i = parca.find(":")
        if i < 0:
            continue
        k, v = parca[:i].strip(), parca[i + 1:].strip()
        if k in sayisal:
            try:
                out[k] = int(v)
            except ValueError:
                out[k] = v
        elif "," in v:
            out[k] = [x.strip() for x in v.split(",") if x.strip()]
        else:
            out[k] = v
    return out


def exif_entry(jpg: str) -> dict | None:
    """Gorselin EXIF'indeki indeks girdisi ya da None (EXIF yok/bozuk)."""
    try:
        import piexif                              # noqa: WPS433
        sifir = piexif.load(jpg).get("0th") or {}
    except Exception:
        return None

    def oku(tag: int) -> str:
        ham = sifir.get(tag)
        if not ham:
            return ""
        return bytes(ham).decode("utf-16le", "ignore").strip("\x00").strip()

    konu, baslik = oku(0x9C9F), oku(0x9C9B)
    if not (konu or baslik):
        return None
    aciklama = sifir.get(0x010E)
    return {"subject_fields": _pipe(konu, _INTS), "title_fields": _pipe(baslik),
            "tags": oku(0x9C9E),
            "description": bytes(aciklama).decode("utf-8", "replace").strip("\x00")
            if aciklama else ""}


def write_exif(jpg: str, data: dict) -> None:
    """exif_writer'i ice alip EXIF'i yerinde yazar (piksel DEGISMEZ)."""
    yol = os.path.join(_ROOT, "tools", "r2manager", "exif_writer.py")
    spec = importlib.util.spec_from_file_location("agb_exif_writer", yol)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    from pathlib import Path
    mod.write_exif(Path(jpg), data)


# ------------------------------------------------------------------ Ollama
def tag_image(yol: str, op_id: str = "") -> dict:
    """Bir gorseli YEREL Ollama ile etiketler ve semayi dogrular.

    GPU seridini ALMAZ - cagiran `_tag_batch` ile parti basina bir kez alir,
    yoksa 2000 gorsel 2000 bilet uretirdi. `keep_alive` parti boyunca modeli
    bellekte tutar; seridi birakan `_tag_batch.__exit__` unload eder.
    """
    sema = _schema()
    url, model = JF._ollama_cfg()
    govde = {"model": model, "stream": False, "format": sema._OLLAMA_TAG_SCHEMA,
             "keep_alive": "10m", "options": {"temperature": 0.2, "num_predict": 1200},
             "messages": [{"role": "user",
                           "content": sema._build_tag_prompt(os.path.basename(yol)),
                           "images": [sema._image_b64_for_vlm(yol)]}]}
    istek = urllib.request.Request(url.rstrip("/") + "/api/chat",
                                   data=json.dumps(govde).encode(),
                                   headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(istek, timeout=300) as cevap:
        icerik = json.load(cevap)["message"]["content"]
    data = json.loads(icerik)
    validate_tags(data)
    return data


# ------------------------------------------------------------------ R2
def _r2():
    sys.path.insert(0, os.path.join(_ROOT, "tools", "r2"))
    import r2_s3                                   # noqa: WPS433
    from . import r2_control
    r2_s3.set_credentials_file(r2_control.credentials_file())
    return r2_s3


def mirror_root() -> str:
    return _ayar("r2.mirror_root") or "D:/Reusable Assets/r2buckets"


def _ayar(anahtar: str, default=None):
    try:
        with open(_SETTINGS, encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for p in anahtar.split("."):
            d = (d or {}).get(p)
        return default if d is None else d
    except Exception:                              # noqa: BLE001
        return default


def _wrangler() -> str:
    from . import card_flow
    wr = card_flow._wrangler()
    if not wr or not (os.path.isfile(wr) or shutil.which(wr)):
        raise ValueError("wrangler bulunamadi (%s) - kovaya yazilamaz" % wr)
    return wr


_JSON_CC = "public, max-age=21600, stale-while-revalidate=86400"
_ASSET_CC = "public, max-age=7776000, immutable"


def r2_put(bucket: str, key: str, dosya: str, content_type: str, cache_control: str,
           timeout: int = 600) -> None:
    """wrangler ile kovaya yazar (card_flow'un `_r2_put`'uyla ayni yol).
    Basarisizsa YUKARI ATAR - sessiz gecis yok."""
    wr = _wrangler()
    proc = subprocess.run(
        [wr, "r2", "object", "put", "%s/%s" % (bucket, key), "--file", dosya, "--remote",
         "--content-type", content_type, "--cache-control", cache_control],
        capture_output=True, text=True, timeout=timeout, encoding="utf-8", errors="replace",
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if proc.returncode != 0:
        raise RuntimeError("wrangler put %s: %s" % (key, (proc.stderr or proc.stdout or "")[:300]))


def _yerel(bucket: str, key: str) -> str:
    return os.path.join(mirror_root(), bucket, key.replace("/", os.sep))


def fetch(bucket: str, key: str, boyut: int) -> str:
    """Nesnenin YEREL yolu. Ayna (D:/Reusable Assets/r2buckets) ayni boyutta
    tutuyorsa indirme yapilmaz; yoksa indirilir ve AYNAYA yazilir - ayna
    kovayla bayt bayt ayni kalir."""
    yol = _yerel(bucket, key)
    if os.path.isfile(yol) and (boyut <= 0 or os.path.getsize(yol) == boyut):
        return yol
    ham = _r2().get_object(bucket, key)
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    gecici = yol + ".part"
    with open(gecici, "wb") as fh:
        fh.write(ham)
    os.replace(gecici, yol)
    return yol


def _sha(yol: str) -> str:
    h = hashlib.sha256()
    with open(yol, "rb") as fh:
        for parca in iter(lambda: fh.read(1 << 20), b""):
            h.update(parca)
    return h.hexdigest()


def first_frame_jpg(webp: str, hedef: str, frame_w: int = 0, frame_h: int = 0) -> None:
    """Sheet'in ILK KARESINI jpg olarak yazar.

    Kart/dealer sheet'i bir IZGARA (cols x rows) - ilk kare sol ust kirpim.
    Olculer verilmezse (host webp'i gibi) kare olarak ilk animasyon karesi
    kullanilir.
    """
    from PIL import Image
    with Image.open(webp) as im:
        try:
            im.seek(0)
        except Exception:                          # noqa: BLE001
            pass
        kare = im.convert("RGB")
        if frame_w > 0 and frame_h > 0:
            kare = kare.crop((0, 0, min(frame_w, kare.width), min(frame_h, kare.height)))
        kare.save(hedef, "JPEG", quality=92)


# ------------------------------------------------------------------ rapor
_rapor_kilit = threading.Lock()


def _rapor_oku() -> dict:
    try:
        with open(_REPORT_FILE, encoding="utf-8") as fh:
            return json.load(fh) or {}
    except Exception:                              # noqa: BLE001
        return {}


def _rapor_yaz(pool: str, rapor: dict) -> None:
    with _rapor_kilit:
        d = _rapor_oku()
        d[pool] = rapor
        os.makedirs(_DATA_DIR, exist_ok=True)
        gecici = _REPORT_FILE + ".tmp"
        with open(gecici, "w", encoding="utf-8") as fh:
            json.dump(d, fh, ensure_ascii=False, indent=1)
        os.replace(gecici, _REPORT_FILE)


def report(pool: str = "") -> dict:
    d = _rapor_oku()
    return d.get(pool, {}) if pool else d


# Havuz -> calisan op kimligi (ayni havuz iki kez baslatilamaz).
_calisan: dict[str, str] = {}
_calisan_kilit = threading.Lock()


def _isaretle(pool: str, op_id: str) -> None:
    with _calisan_kilit:
        eski = _calisan.get(pool)
        if eski:
            o = JF.op_status(eski)
            if o and o.get("status") == "running":
                raise ValueError("%s havuzu icin normalizasyon zaten calisiyor (%s)" % (pool, eski))
        _calisan[pool] = op_id


def status() -> dict:
    """Her havuz icin: calisan op (ilerleme) + son rapor."""
    out = {"pools": {}}
    raporlar = _rapor_oku()
    for p in POOLS:
        op_id = _calisan.get(p, "")
        op = JF.op_status(op_id) if op_id else None
        out["pools"][p] = dict(POOL_INFO[p], pool=p, op=op,
                               running=bool(op and op.get("status") == "running"),
                               last=raporlar.get(p) or None)
    out["ollama"] = JF.ollama_ready()
    return out


def pools() -> dict:
    """Havuz listesi + kovadaki gorsel sayisi (etiket durumu icin rapora bakilir)."""
    out = []
    for p in POOLS:
        try:
            n = len(_enumerate(p))
        except Exception as e:                     # noqa: BLE001
            out.append(dict(POOL_INFO[p], pool=p, images=None, error=str(e)[:200]))
            continue
        out.append(dict(POOL_INFO[p], pool=p, images=n))
    return {"pools": out}


# ------------------------------------------------------------------ sayim
def _enumerate(pool: str) -> list[dict]:
    """Havuzdaki normalize edilecek gorseller - KOVA LISTESI kaynaktir
    (ayna bayat olabilir, kova olamaz).

    Ortak sekil: {"id", "group", "key", "size", "name"}
    """
    s3 = _r2()
    kova = POOL_INFO[pool]["bucket"]
    if pool == "gallery-hot":
        out = []
        for o in s3.list_all(kova, "collections/"):
            p = o["key"].split("/")
            if len(p) == 4 and p[2] == "images" and p[3].lower().endswith((".jpg", ".jpeg")):
                out.append({"id": "%s/%s" % (p[1], p[3]), "group": p[1], "name": p[3],
                            "key": o["key"], "size": o["size"]})
        return sorted(out, key=lambda x: x["id"])
    if pool == "cards":
        katalog = read_catalog()
        out = []
        for c in katalog.get("collections") or []:
            for kart in c.get("cards") or []:
                if not kart.get("sheet"):
                    continue
                out.append({"id": kart.get("id") or "", "group": c.get("id") or "",
                            "name": kart.get("id") or "", "key": kart["sheet"], "size": 0,
                            "frameW": int(kart.get("frameW") or 0),
                            "frameH": int(kart.get("frameH") or 0)})
        for d in katalog.get("dealers") or []:
            if not d.get("sheet"):
                continue
            out.append({"id": d.get("id") or "", "group": "dealers", "name": d.get("id") or "",
                        "key": d["sheet"], "size": 0,
                        "frameW": int(d.get("frameW") or 0), "frameH": int(d.get("frameH") or 0)})
        return [x for x in out if x["id"]]
    if pool == "events":
        out = []
        for o in s3.list_all(kova, "host/"):
            ad = o["key"].split("/")[-1]
            kok = os.path.splitext(ad)[0]
            if not (kok.startswith("L") and kok[1:].isdigit()):
                continue                           # yalniz durus gorseli (L<n>.webp)
            out.append({"id": kok, "group": "host", "name": kok, "key": o["key"],
                        "size": o["size"]})
        return sorted(out, key=lambda x: int(x["id"][1:]))
    raise ValueError("bilinmeyen havuz: " + pool)


def read_catalog() -> dict:
    """Kovadaki CANLI manifest.json (yerel kopya degil - baska bir surec de
    yaziyor olabilir, yazmadan hemen once yine okunur)."""
    ham = _r2().get_object("cards", "manifest.json")
    return json.loads(ham.decode("utf-8"))


# ------------------------------------------------------------------ kosu
def run(pool: str, dry_run: bool = False, limit: int = 0, force: bool = False) -> str:
    """Havuzu normalize eden op'u baslatir ve op kimligini dondurur."""
    if pool not in POOLS:
        raise ValueError("bilinmeyen havuz: %s (%s)" % (pool, ", ".join(POOLS)))
    ogeler = _enumerate(pool)
    if limit > 0:
        ogeler = ogeler[:limit]
    op_id = JF._op_new("normalize-" + pool, len(ogeler))
    _isaretle(pool, op_id)
    JF._op(op_id, message="%s: %d gorsel" % (pool, len(ogeler)))

    def calis():
        rapor = {"pool": pool, "dry_run": bool(dry_run), "started_at":
                 datetime.now().isoformat(timespec="seconds"), "total": len(ogeler),
                 "valid": 0, "tagged": 0, "failed": 0, "skipped": 0,
                 "failures": [], "groups": {}, "op": op_id}
        try:
            if pool == "gallery-hot":
                _gallery(ogeler, rapor, dry_run, force, op_id)
            elif pool == "cards":
                _cards(ogeler, rapor, dry_run, force, op_id)
            else:
                _events(ogeler, rapor, dry_run, force, op_id)
            rapor["status"] = "completed"
        except JF.OpCancelled:
            rapor["status"] = "cancelled"
            raise
        except Exception as e:                     # noqa: BLE001
            rapor["status"] = "error"
            rapor["error"] = str(e)[:400]
            raise
        finally:
            rapor["finished_at"] = datetime.now().isoformat(timespec="seconds")
            _rapor_yaz(pool, rapor)
        JF._op(op_id, message="bitti: %d gecerli, %d etiketlendi, %d basarisiz"
               % (rapor["valid"], rapor["tagged"], rapor["failed"]))

    JF._run(op_id, calis)
    return op_id


def _hata(rapor: dict, op_id: str, oge_id: str, neden: str) -> None:
    rapor["failed"] += 1
    rapor["failures"].append({"id": oge_id, "reason": neden[:300]})
    # Op defterindeki sayaclar Sira ekraninda gorunur - rapor ile ayni kalmali.
    JF._op(op_id, failed=rapor["failed"], log="BASARISIZ %s: %s" % (oge_id, neden[:200]))


def _sayac(rapor: dict, op_id: str) -> None:
    """Op defterinin ok/failed sayaclarini rapordan tazeler."""
    JF._op(op_id, ok=rapor["valid"] + rapor["tagged"], failed=rapor["failed"])


def _grup(rapor: dict, ad: str) -> dict:
    return rapor["groups"].setdefault(ad, {"total": 0, "valid": 0, "tagged": 0, "failed": 0})


# ---- gallery-hot ---------------------------------------------------------
def _gallery(ogeler: list[dict], rapor: dict, dry_run: bool, force: bool, op_id: str) -> None:
    """Her koleksiyon icin: EXIF'i eksik/uyumsuz olanlari etiketle, EXIF'i
    gorsele yaz, ayni anahtara geri yukle, sonra koleksiyonun kompakt
    `serve_index`'ini worker'a yaz."""
    from . import delivery
    per: dict[str, list[dict]] = {}
    for o in ogeler:
        per.setdefault(o["group"], []).append(o)

    sirali = sorted(per.items())
    etiketlenecek = 0
    indeksler: dict[str, dict] = {}
    yapildi = 0

    for koleksiyon, liste in sirali:
        g = _grup(rapor, koleksiyon)
        g["total"] = len(liste)
        indeks: dict[str, dict | None] = {}
        eksikler: list[dict] = []
        for o in liste:
            yapildi += 1
            JF._op(op_id, done=yapildi, message="%s okunuyor (%d/%d)"
                   % (koleksiyon, yapildi, rapor["total"]))
            try:
                yol = fetch("gallery-hot", o["key"], o["size"])
            except Exception as e:                 # noqa: BLE001
                _hata(rapor, op_id, o["id"], "indirilemedi: %s" % e)
                g["failed"] += 1
                continue
            girdi = exif_entry(yol)
            uygun, neden = conforms(girdi)
            if uygun and not force:
                indeks[o["name"]] = {"subject_fields": girdi["subject_fields"],
                                     "title_fields": girdi["title_fields"]}
                rapor["valid"] += 1
                g["valid"] += 1
                continue
            eksikler.append(dict(o, path=yol, reason=neden))
        etiketlenecek += len(eksikler)
        indeksler[koleksiyon] = indeks
        per[koleksiyon] = eksikler

    # 2. asama: ilerleme sayaci ETIKETLENECEK sayiya doner - okuma bitti,
    # ekranda "2140/2140" donup kalmasin (Sira ekrani bu iki alani cizer).
    _sayac(rapor, op_id)
    JF._op(op_id, message="%d gorsel etiketlenecek" % etiketlenecek,
           done=0, total=etiketlenecek)
    if etiketlenecek and not dry_run:
        if not JF.ollama_ready():
            raise RuntimeError("Ollama yanit vermiyor - etiketleme yapilamaz")
        sayac = 0
        with JF._tag_batch("Ollama", etiketlenecek, op_id):
            for koleksiyon, eksikler in sorted(per.items()):
                g = _grup(rapor, koleksiyon)
                for o in eksikler:
                    sayac += 1
                    JF._op(op_id, done=sayac,
                           message="%s etiketleniyor (%d/%d): %s"
                                   % (koleksiyon, sayac, etiketlenecek, o["name"]))
                    try:
                        data = tag_image(o["path"], op_id)
                        write_exif(o["path"], data)
                        yeni = exif_entry(o["path"])
                        uygun, neden = conforms(yeni)
                        if not uygun:
                            raise RuntimeError("EXIF yazildi ama uyumsuz: " + neden)
                        r2_put("gallery-hot", o["key"], o["path"], "image/jpeg", _ASSET_CC)
                        indeksler[koleksiyon][o["name"]] = {
                            "subject_fields": yeni["subject_fields"],
                            "title_fields": yeni["title_fields"]}
                        rapor["tagged"] += 1
                        g["tagged"] += 1
                        _sayac(rapor, op_id)
                        JF._op(op_id, log="etiketlendi %s" % o["id"])
                    except Exception as e:         # noqa: BLE001
                        _hata(rapor, op_id, o["id"], str(e))
                        g["failed"] += 1
    elif etiketlenecek:
        for koleksiyon, eksikler in per.items():
            rapor["skipped"] += len(eksikler)
            for o in eksikler:
                rapor["failures"].append({"id": o["id"], "reason": "dry-run: " + o["reason"]})

    # --- indeksleri worker'a yaz (worker OKUR, sunucu YAZAR)
    yazilan = 0
    for koleksiyon, indeks in sorted(indeksler.items()):
        if dry_run:
            continue
        if not indeks:
            JF._op(op_id, log="indeks bos, yazilmadi: %s" % koleksiyon)
            continue
        try:
            delivery.put_serve_index(koleksiyon, indeks)
            yazilan += 1
        except Exception as e:                     # noqa: BLE001
            _hata(rapor, op_id, "serve_index/" + koleksiyon, str(e))
    rapor["indexes_published"] = yazilan
    rapor["collections"] = len(indeksler)


# ---- cards --------------------------------------------------------------
def _cards(ogeler: list[dict], rapor: dict, dry_run: bool, force: bool, op_id: str) -> None:
    """Sheet'in ilk karesini etiketler ve manifest.json'daki `metadata`
    alanlarini doldurur. Manifest yazmadan hemen once TEKRAR okunur ve yalniz
    `metadata` alanlari birlestirilir - baska bir surec manifest'i yenilemis
    olabilir, onun isini ezmeyiz."""
    katalog = read_catalog()
    mevcut: dict[str, dict] = {}
    for c in katalog.get("collections") or []:
        for kart in c.get("cards") or []:
            mevcut[kart.get("id") or ""] = kart
    for d in katalog.get("dealers") or []:
        mevcut[d.get("id") or ""] = d

    yeni_meta: dict[str, dict] = {}
    gecici = tempfile.mkdtemp(prefix="agb-normalize-")
    try:
        eksikler = []
        for i, o in enumerate(ogeler, 1):
            JF._op(op_id, done=i, message="kart okunuyor (%d/%d) %s" % (i, len(ogeler), o["id"]))
            g = _grup(rapor, o["group"])
            g["total"] += 1
            girdi = (mevcut.get(o["id"]) or {}).get("metadata")
            uygun, neden = conforms(girdi)
            if uygun and not force:
                rapor["valid"] += 1
                g["valid"] += 1
                continue
            eksikler.append(dict(o, reason=neden))
        _sayac(rapor, op_id)
        JF._op(op_id, message="%d kart etiketlenecek" % len(eksikler),
               done=0, total=len(eksikler))
        if eksikler and dry_run:
            rapor["skipped"] = len(eksikler)
            for o in eksikler:
                rapor["failures"].append({"id": o["id"], "reason": "dry-run: " + o["reason"]})
            return
        if eksikler:
            if not JF.ollama_ready():
                raise RuntimeError("Ollama yanit vermiyor - etiketleme yapilamaz")
            _, model = JF._ollama_cfg()
            sayac = 0
            with JF._tag_batch("Ollama", len(eksikler), op_id):
                for o in eksikler:
                    g = _grup(rapor, o["group"])
                    sayac += 1
                    JF._op(op_id, done=sayac,
                           message="kart etiketleniyor (%d/%d): %s"
                                   % (sayac, len(eksikler), o["id"]))
                    try:
                        sheet = fetch("cards", o["key"], 0)
                        still = os.path.join(gecici, o["id"] + ".jpg")
                        first_frame_jpg(sheet, still, o.get("frameW") or 0, o.get("frameH") or 0)
                        data = tag_image(still, op_id)
                        subj, title = fields_from_tags(data)
                        yeni_meta[o["id"]] = {"source_sha256": _sha(sheet), "model": model,
                                              "source": o["key"], "subject_fields": subj,
                                              "title_fields": title,
                                              "description": data["description"],
                                              "tags": data["tags"]}
                        rapor["tagged"] += 1
                        g["tagged"] += 1
                        _sayac(rapor, op_id)
                        JF._op(op_id, log="etiketlendi %s" % o["id"])
                    except Exception as e:         # noqa: BLE001
                        _hata(rapor, op_id, o["id"], str(e))
                        g["failed"] += 1
    finally:
        shutil.rmtree(gecici, ignore_errors=True)

    if not yeni_meta:
        rapor["manifest_written"] = False
        return
    guncel = read_catalog()                        # yazmadan hemen once TEKRAR
    dokunulan = 0
    for c in guncel.get("collections") or []:
        for kart in c.get("cards") or []:
            m = yeni_meta.get(kart.get("id") or "")
            if m:
                kart["metadata"] = m
                dokunulan += 1
    for d in guncel.get("dealers") or []:
        m = yeni_meta.get(d.get("id") or "")
        if m:
            d["metadata"] = m
            dokunulan += 1
    yol = os.path.join(_DATA_DIR, "normalize_cards_manifest.json")
    os.makedirs(_DATA_DIR, exist_ok=True)
    with open(yol, "w", encoding="utf-8") as fh:
        json.dump(guncel, fh, ensure_ascii=False, indent=1)
    r2_put("cards", "manifest.json", yol, "application/json", _JSON_CC)
    rapor["manifest_written"] = True
    rapor["manifest_entries"] = dokunulan
    JF._op(op_id, log="+ manifest.json (%d girdiye metadata)" % dokunulan)


# ---- events -------------------------------------------------------------
_HOST_INDEX_KEY = "_meta/host.json"


def read_host_index() -> dict:
    try:
        ham = _r2().get_object("events", _HOST_INDEX_KEY)
        d = json.loads(ham.decode("utf-8"))
        return d if isinstance(d, dict) else {}
    except Exception:                              # noqa: BLE001
        return {}


def _events(ogeler: list[dict], rapor: dict, dry_run: bool, force: bool, op_id: str) -> None:
    """host/L<n>.webp: ilk kareyi etiketler, indeksi kovadaki
    `_meta/host.json` yan dosyasina yazar (events worker'in KV'si yok)."""
    indeks = read_host_index()
    seviyeler = dict(indeks.get("levels") or {})
    gecici = tempfile.mkdtemp(prefix="agb-normalize-host-")
    try:
        eksikler = []
        for i, o in enumerate(ogeler, 1):
            JF._op(op_id, done=i, message="host okunuyor (%d/%d) %s" % (i, len(ogeler), o["id"]))
            g = _grup(rapor, "host")
            g["total"] += 1
            n = o["id"][1:]
            uygun, neden = conforms(seviyeler.get(n))
            if uygun and not force:
                rapor["valid"] += 1
                g["valid"] += 1
                continue
            eksikler.append(dict(o, reason=neden, level=n))
        _sayac(rapor, op_id)
        JF._op(op_id, message="%d host gorseli etiketlenecek" % len(eksikler),
               done=0, total=len(eksikler))
        if eksikler and dry_run:
            rapor["skipped"] = len(eksikler)
            for o in eksikler:
                rapor["failures"].append({"id": o["id"], "reason": "dry-run: " + o["reason"]})
            return
        if eksikler:
            if not JF.ollama_ready():
                raise RuntimeError("Ollama yanit vermiyor - etiketleme yapilamaz")
            _, model = JF._ollama_cfg()
            sayac = 0
            with JF._tag_batch("Ollama", len(eksikler), op_id):
                for o in eksikler:
                    g = _grup(rapor, "host")
                    sayac += 1
                    JF._op(op_id, done=sayac,
                           message="host etiketleniyor (%d/%d): %s"
                                   % (sayac, len(eksikler), o["id"]))
                    try:
                        webp = fetch("events", o["key"], o["size"])
                        still = os.path.join(gecici, o["id"] + ".jpg")
                        first_frame_jpg(webp, still)
                        data = tag_image(still, op_id)
                        subj, title = fields_from_tags(data)
                        seviyeler[o["level"]] = {"source_sha256": _sha(webp), "model": model,
                                                 "source": o["key"], "subject_fields": subj,
                                                 "title_fields": title,
                                                 "description": data["description"],
                                                 "tags": data["tags"]}
                        rapor["tagged"] += 1
                        g["tagged"] += 1
                        _sayac(rapor, op_id)
                        JF._op(op_id, log="etiketlendi %s" % o["id"])
                    except Exception as e:         # noqa: BLE001
                        _hata(rapor, op_id, o["id"], str(e))
                        g["failed"] += 1
    finally:
        shutil.rmtree(gecici, ignore_errors=True)

    if dry_run:
        return
    govde = {"updated": int(datetime.now().timestamp() * 1000), "levels": seviyeler}
    yol = os.path.join(_DATA_DIR, "normalize_host_index.json")
    os.makedirs(_DATA_DIR, exist_ok=True)
    with open(yol, "w", encoding="utf-8") as fh:
        json.dump(govde, fh, ensure_ascii=False, indent=1)
    r2_put("events", _HOST_INDEX_KEY, yol, "application/json", _JSON_CC)
    rapor["host_index_written"] = True
    rapor["host_levels"] = len(seviyeler)
    JF._op(op_id, log="+ %s (%d seviye)" % (_HOST_INDEX_KEY, len(seviyeler)))


def cancel(op_id: str) -> dict:
    return JF.cancel_op(op_id)
