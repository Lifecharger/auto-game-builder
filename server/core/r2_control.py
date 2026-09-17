"""Kovalar: R2 kovalarinin kendisini yoneten kat (#381).

Jigsaw / kart / karakter akislari YEREL klasorleri gorur; push'tan sonra kovada ne
oldugunu AGB'den goremiyorduk. Bu modul kovalarin icine bakar:

  * kayit defteri  server/config/r2_buckets.json - kova, dosya alan adi, rol ve
    ESKI IKIZ ile anahtar eslemesi (gallery-hot <-> hotjigsaw, promo <-> hotjigsaw
    promo/, characters <-> hotcardgames relationships/<kiz>/ ...)
  * gezinme       klasor gibi listeleme (delimiter "/"), basliklar, kucuk onizleme
  * silme         yazili onay + ikiz kovadan da silme (strike yanitinin YENI ve
                  ESKI kopyayi birlikte dusurmesi gerekir)
  * kopyalama     sunucu tarafi (Cloudflare icinde) - bu hattan bayt gecmez
  * baslik onarimi onbellek standardina uymayan Cache-Control'u yerinde duzeltir
  * fark          yerel "Pushed" klasoru <-> kova, ve YENI kova <-> ESKI ikizi

Uzun isler arka planda calisir ve `op_status` ile izlenir (akis modulleriyle ayni
govde). Kimlik bilgisi depoya girmez: `r2.credentials_file` ayari (yoksa
D:/keys/cloudflare_r2_s3_credentials.json).
"""
from __future__ import annotations

import fnmatch
import hashlib
import importlib.util
import io
import json
import os
import re
import sys
import threading
import uuid
from datetime import datetime

# tools/r2/r2_s3.py TEK uygulamadir; kopyasini cikarmiyoruz, dosya yolundan
# yukluyoruz (duz `import r2_s3` sunucunun sys.path'inde yok).
_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SETTINGS = os.path.join(_ROOT, "server", "config", "settings.json")
_REGISTRY_FILE = os.path.join(_ROOT, "server", "config", "r2_buckets.json")
_DATA_DIR = os.path.join(_ROOT, "server", "data")
_STATS_FILE = os.path.join(_DATA_DIR, "r2_bucket_stats.json")
_AUDIT_FILE = os.path.join(_DATA_DIR, "r2_audit.log")
_THUMB_DIR = os.path.join(_DATA_DIR, "r2_thumbs")

DEFAULT_CREDENTIALS = "D:/keys/cloudflare_r2_s3_credentials.json"

# Telefon sayacli hatta: onizleme bir gorseli BIR KEZ indirebilir, videoyu /
# hareketli webp'i / 2 MB ustunu ASLA. Istemci ikon + boyut gosterir.
THUMB_MAX_BYTES = 2 * 1024 * 1024
STILL_EXTS = (".jpg", ".jpeg", ".png", ".webp")

# Silme korkuluklari: yazili onay olmadan hicbir sey silinmez ve tek cagrida
# 500 anahtardan fazlasi kabul edilmez (yanlis secim tum kovayi goturmesin).
MAX_DELETE_KEYS = 500


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


def credentials_file() -> str:
    return os.environ.get("R2_CREDENTIALS_FILE", "").strip() or \
        _setting("r2.credentials_file") or DEFAULT_CREDENTIALS


_s3_cache = None


def s3():
    """tools/r2/r2_s3.py - kimlik dosyasi ayardan verilir."""
    global _s3_cache
    if _s3_cache is None:
        yol = os.path.join(_ROOT, "tools", "r2", "r2_s3.py")
        if not os.path.isfile(yol):
            raise ValueError("r2_s3.py bulunamadi: %s" % yol)
        spec = importlib.util.spec_from_file_location("r2_s3_client", yol)
        mod = importlib.util.module_from_spec(spec)
        sys.modules["r2_s3_client"] = mod
        spec.loader.exec_module(mod)
        _s3_cache = mod
    _s3_cache.set_credentials_file(credentials_file())
    return _s3_cache


# ------------------------------------------------------------------ kayit defteri
_registry_cache = None


def registry() -> dict:
    global _registry_cache
    if _registry_cache is None:
        with open(_REGISTRY_FILE, encoding="utf-8") as fh:
            _registry_cache = json.load(fh)
    return _registry_cache


def bucket_info(name: str) -> dict:
    for b in registry().get("buckets") or []:
        if b.get("name") == name:
            return b
    raise ValueError("kayitli olmayan kova: %s" % name)


def bucket_names() -> list[str]:
    return [b["name"] for b in registry().get("buckets") or []]


def public_url(bucket: str, key: str) -> str:
    """Kovanin dosya alan adindaki genel adres (ozel kovada bos)."""
    alan = (bucket_info(bucket).get("files_domain") or "").rstrip("/")
    if not alan:
        return ""
    import urllib.parse
    return alan + "/" + urllib.parse.quote(key, safe="/-_.~")


# ------------------------------------------------------------------ ikiz esleme
# Sablon: {ad} TEK yol parcasini, {ad...} anahtarin GERI KALANINI yakalar. Iki
# yon de ayni kuraldan turetilir, boylece esleme tek yerde tanimli kalir.
_PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)(\.\.\.)?\}")


def _pattern(sablon: str) -> re.Pattern:
    out, son = [], 0
    for m in _PLACEHOLDER.finditer(sablon):
        out.append(re.escape(sablon[son:m.start()]))
        out.append("(?P<%s>%s)" % (m.group(1), ".+" if m.group(2) else "[^/]+"))
        son = m.end()
    out.append(re.escape(sablon[son:]))
    return re.compile("^" + "".join(out) + "$")


def _fill(sablon: str, alanlar: dict) -> str:
    return _PLACEHOLDER.sub(lambda m: alanlar[m.group(1)], sablon)


def _literal_prefix(sablon: str) -> str:
    """Sablonun ilk yer tutucudan onceki sabit basi ("promo/{r...}" -> "promo/").

    Ikiz farkinda ESKI kovanin yalniz bu onekleri listelenir: hotjigsaw'in
    `collections/` agaci promo'nun isi degildir.
    """
    m = _PLACEHOLDER.search(sablon)
    return sablon if not m else sablon[:m.start()]


def _rules(bucket: str) -> list[dict]:
    """Bu kovadan cikan esleme kurallari: {"to", "from", "to_key"}.

    Kova YENI tarafsa kendi `twin` kurallari; ESKI tarafsa kendisini ikiz
    gosteren yeni kovalarin kurallari TERS cevrilerek - esleme tek yerde,
    r2_buckets.json'da tanimli kalir. Bir eski kova birden cok yeni kovayi
    besleyebilir (hotjigsaw -> gallery-hot + promo).
    """
    twin = bucket_info(bucket).get("twin") or {}
    if twin.get("bucket"):
        return [{"to": twin["bucket"], "from": r["new"], "to_key": r["legacy"]}
                for r in twin.get("rules") or []]
    ters = []
    for b in registry().get("buckets") or []:
        t = b.get("twin") or {}
        if t.get("bucket") == bucket:
            ters += [{"to": b["name"], "from": r["legacy"], "to_key": r["new"]}
                     for r in t.get("rules") or []]
    return ters


def twin_buckets(bucket: str) -> list[str]:
    """Bu kovanin ikiz(ler)i - sirasi kayit defterindeki sira."""
    out = []
    for r in _rules(bucket):
        if r["to"] not in out:
            out.append(r["to"])
    return out


def twin_bucket(bucket: str) -> str:
    """Tek ikiz (yoksa bos, birden coksa virgulle)."""
    return ", ".join(twin_buckets(bucket))


def twin_key(bucket: str, key: str) -> tuple[str, str]:
    """(ikiz kova, ikiz anahtar). Kural yoksa ("", "") - esleme uydurulmaz."""
    for r in _rules(bucket):
        m = _pattern(r["from"]).match(key)
        if m:
            return r["to"], _fill(r["to_key"], m.groupdict())
    return "", ""


def twin_map(bucket: str) -> list[dict]:
    """Arayuzde gosterilen esleme tablosu."""
    return [{"bucket": r["to"], "from": r["from"], "to": r["to_key"]} for r in _rules(bucket)]


# ------------------------------------------------------------------ onbellek standardi
def expected_cache_control(bucket: str, key: str) -> dict:
    """Anahtarin tasimasi gereken Cache-Control + neden.

    Standart (2026-08-10): varliklar 90 gun immutable, *.json 6 saat taze +
    1 gun bayat-sun. `characters/*/relationships/` bilerek degisken - deneme
    asamasinda, son immutable gecise kadar dokunulmaz.
    """
    std = registry().get("cache_standard") or {}
    tam = "%s/%s" % (bucket, key)
    for p in std.get("mutable_prefixes") or []:
        if fnmatch.fnmatch(tam, p + "*"):
            return {"kind": "mutable", "expected": ""}
    if key.lower().endswith(".json"):
        return {"kind": "json", "expected": std.get("json", "")}
    return {"kind": "asset", "expected": std.get("asset", "")}


def header_check(bucket: str, key: str, cache_control: str) -> dict:
    """{kind, expected, actual, ok} - degisken anahtarlar her zaman uygundur."""
    e = expected_cache_control(bucket, key)
    actual = (cache_control or "").strip()
    ok = True if e["kind"] == "mutable" else (_norm(actual) == _norm(e["expected"]))
    return {"kind": e["kind"], "expected": e["expected"], "actual": actual, "ok": ok}


def _norm(cc: str) -> str:
    return ", ".join(p.strip().lower() for p in (cc or "").split(",") if p.strip())


# ------------------------------------------------------------------ listeleme
def list_prefix(bucket: str, prefix: str = "", cursor: str = "", limit: int = 200) -> dict:
    """Klasor gibi gezinme: alt klasorler + bu klasordeki nesneler."""
    bucket_info(bucket)
    page = s3().list_objects_v2(bucket, prefix=prefix, delimiter="/",
                                token=cursor, max_keys=max(1, min(1000, limit)))
    nesneler = []
    for o in page["objects"]:
        uz = os.path.splitext(o["key"])[1].lower()
        nesneler.append(dict(o,
                             name=o["key"][len(prefix):],
                             url=public_url(bucket, o["key"]),
                             # Istemci onizlemeyi YALNIZ bu bayrakta ister; video
                             # ve buyuk dosya hic sorulmaz (sayacli hat).
                             preview=(uz in STILL_EXTS and o["size"] <= THUMB_MAX_BYTES)))
    klasorler = [{"prefix": p, "name": p[len(prefix):].rstrip("/")} for p in page["prefixes"]]
    return {"bucket": bucket, "prefix": prefix, "folders": klasorler, "objects": nesneler,
            "cursor": page["cursor"], "truncated": page["truncated"]}


def head(bucket: str, key: str) -> dict:
    """Bir nesnenin basliklari + onbellek standardina uygunlugu."""
    bucket_info(bucket)
    if not key:
        raise ValueError("anahtar bos")
    h = s3().head_object(bucket, key)
    tb, tk = twin_key(bucket, key)
    return dict(h, bucket=bucket, url=public_url(bucket, key),
                header=header_check(bucket, key, h["cache_control"]),
                twin_bucket=tb, twin_key=tk)


# ------------------------------------------------------------------ onizleme
class NoPreview(RuntimeError):
    """Onizleme URETILMEZ: video, hareketli webp ya da 2 MB ustu nesne.

    Sayacli hatta bunlari indirmek yasak; istemci ikon + boyut gosterir. `reason`
    alani nedeni tasir (video / animated / too_large / not_image)."""

    def __init__(self, reason: str, size: int, content_type: str):
        super().__init__(reason)
        self.reason, self.size, self.content_type = reason, size, content_type


def _animated_webp(bucket: str, key: str) -> bool:
    """Ilk 32 bayt: VP8X baslikta ANIMATION biti (0x02) varsa hareketlidir."""
    bas = s3().get_object(bucket, key, 0, 31)
    if len(bas) < 21 or bas[:4] != b"RIFF" or bas[8:12] != b"WEBP":
        return False
    return bas[12:16] == b"VP8X" and bool(bas[20] & 0x02)


def thumb(bucket: str, key: str, size: int = 220) -> str:
    """Kucuk JPEG onizleme (diskte bucket+key+etag ile onbelleklenir).

    Once HEAD - trafik harcamadan tur ve boyut ogrenilir. Sadece 2 MB altindaki
    duragan gorseller indirilir; digerleri NoPreview firlatir.
    """
    h = s3().head_object(bucket, key)
    uz = os.path.splitext(key)[1].lower()
    if uz not in STILL_EXTS:
        neden = "video" if h["content_type"].startswith("video/") else "not_image"
        raise NoPreview(neden, h["size"], h["content_type"])
    if h["size"] > THUMB_MAX_BYTES:
        raise NoPreview("too_large", h["size"], h["content_type"])

    anahtar = hashlib.sha1(("%s|%s|%s|%d" % (bucket, key, h["etag"], size)).encode()).hexdigest()
    hedef = os.path.join(_THUMB_DIR, anahtar + ".jpg")
    if os.path.isfile(hedef):
        return hedef

    if uz == ".webp" and _animated_webp(bucket, key):
        raise NoPreview("animated", h["size"], h["content_type"])

    from PIL import Image
    ham = s3().get_object(bucket, key)
    os.makedirs(_THUMB_DIR, exist_ok=True)
    with Image.open(io.BytesIO(ham)) as f:
        if getattr(f, "n_frames", 1) > 1:
            f.seek(0)
        im = f.convert("RGB")
    im.thumbnail((size, size * 3))
    tmp = hedef + ".tmp"
    im.save(tmp, "JPEG", quality=82)
    os.replace(tmp, hedef)
    return hedef


# ------------------------------------------------------------------ sayimlar
def _count(bucket: str) -> dict:
    n, bayt = 0, 0
    for o in s3().list_all(bucket):
        n += 1
        bayt += o["size"]
    return {"objects": n, "bytes": bayt,
            "counted_at": datetime.now().isoformat(timespec="seconds")}


def _stats_cache() -> dict:
    try:
        with open(_STATS_FILE, encoding="utf-8") as fh:
            d = json.load(fh)
        return d if isinstance(d, dict) else {}
    except FileNotFoundError:
        return {}
    except Exception as e:
        raise ValueError("kova sayim onbellegi okunamadi (%s): %s" % (_STATS_FILE, e))


def _stats_save(d: dict) -> None:
    os.makedirs(_DATA_DIR, exist_ok=True)
    tmp = _STATS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(d, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, _STATS_FILE)


def buckets(refresh: bool = False, only: str = "") -> dict:
    """Kayit defteri + canli nesne sayisi / toplam bayt (diskte onbellekli).

    Sayim listeleme ile yapilir (ucuz API trafigi, bayt inmez); `refresh` yeniden
    hesaplar. `only` verilirse yalniz o kova sayilir.
    """
    reg = registry()
    onbellek = _stats_cache()
    degisti = False
    satirlar = []
    for b in reg.get("buckets") or []:
        ad = b["name"]
        st = onbellek.get(ad)
        if refresh and (not only or only == ad):
            st = _count(ad)
            onbellek[ad] = st
            degisti = True
        satirlar.append({
            "name": ad,
            "files_domain": b.get("files_domain", ""),
            "worker": b.get("worker", ""),
            "role": b.get("role", "content"),
            "holds": b.get("holds", ""),
            "layout": b.get("layout", ""),
            "legacy_prefixes": b.get("legacy_prefixes") or [],
            "twin": twin_bucket(ad),
            "twin_map": twin_map(ad),
            "objects": (st or {}).get("objects"),
            "bytes": (st or {}).get("bytes"),
            "counted_at": (st or {}).get("counted_at", ""),
        })
    if degisti:
        _stats_save(onbellek)
    return {"buckets": satirlar,
            "legacy_retires_on": reg.get("legacy_retires_on", ""),
            "cache_standard": reg.get("cache_standard") or {}}


# ------------------------------------------------------------------ denetim defteri
def _audit(client: str, action: str, bucket: str, keys: list[str]) -> None:
    """Yalniz EKLENEN defter: ne zaman, kim, ne, hangi kovada, hangi anahtarlar."""
    os.makedirs(_DATA_DIR, exist_ok=True)
    kayit = {"time": datetime.now().isoformat(timespec="seconds"),
             "client": client or "bilinmiyor", "action": action,
             "bucket": bucket, "keys": list(keys)}
    with open(_AUDIT_FILE, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(kayit, ensure_ascii=False) + "\n")


def audit_tail(limit: int = 50) -> list[dict]:
    try:
        with open(_AUDIT_FILE, encoding="utf-8") as fh:
            satirlar = fh.read().splitlines()
    except FileNotFoundError:
        return []
    out = []
    for s in satirlar[-max(1, min(500, limit)):]:
        try:
            out.append(json.loads(s))
        except ValueError:
            continue
    return list(reversed(out))


# ------------------------------------------------------------------ silme
def delete(bucket: str, keys: list[str], takedown: bool = False,
           confirm: str = "", client: str = "") -> dict:
    """Nesneleri siler. GERI ALINAMAZ.

    `confirm` kova adinin AYNISI olmali - yanlis kovada yanlis secimle silmeyi
    bir yazim adimi durdurur. `takedown` ayrica ESKI ikizdeki karsiligini da
    siler: strike yaniti YENI ve ESKI kopyayi birlikte dusurmek zorunda.
    Sunucu asla "onekle" silmez; istemci once listeler, sonra anahtar gonderir.
    """
    bucket_info(bucket)
    keys = [str(k) for k in keys if str(k).strip()]
    if not keys:
        raise ValueError("anahtar secilmedi")
    if len(keys) > MAX_DELETE_KEYS:
        raise ValueError("tek cagrida en fazla %d anahtar silinir (%d gonderildi)"
                         % (MAX_DELETE_KEYS, len(keys)))
    if confirm != bucket:
        raise ValueError("onay yazisi kova adiyla ayni olmali: '%s'" % bucket)

    c = s3()
    _audit(client, "takedown" if takedown else "delete", bucket, keys)
    sonuc = c.delete_objects(bucket, keys)
    out = {"bucket": bucket, "deleted": len(sonuc["deleted"]), "errors": sonuc["errors"],
           "twins": [], "unmapped": []}
    if not takedown:
        return out

    ikiz: dict[str, list[str]] = {}
    for k in keys:
        tb, tk = twin_key(bucket, k)
        if tb and tk:
            ikiz.setdefault(tb, []).append(tk)
        else:
            out["unmapped"].append(k)
    for tb, tkeys in ikiz.items():
        _audit(client, "takedown-twin", tb, tkeys)
        r = c.delete_objects(tb, tkeys)
        out["twins"].append({"bucket": tb, "keys": tkeys,
                             "deleted": len(r["deleted"]), "errors": r["errors"]})
    return out


def takedown_plan(bucket: str, keys: list[str]) -> dict:
    """Silmeden ONCE: hangi kovada hangi anahtarlar gidecek.

    Istemci yazili onay penceresinde bunu aynen gosterir - kullanici neyin
    silinecegini gormeden onay yazmaz.
    """
    bucket_info(bucket)
    keys = [str(k) for k in keys if str(k).strip()]
    ikiz: dict[str, list[str]] = {}
    eslenmeyen = []
    for k in keys:
        tb, tk = twin_key(bucket, k)
        if tb and tk:
            ikiz.setdefault(tb, []).append(tk)
        else:
            eslenmeyen.append(k)
    return {"bucket": bucket, "keys": keys, "limit": MAX_DELETE_KEYS,
            "twins": [{"bucket": b, "keys": ks} for b, ks in ikiz.items()],
            "unmapped": eslenmeyen}


# ------------------------------------------------------------- arka plan isleri
# Govde akis modulleriyle ayni: istemciler ayni op izleyicisini kullanir.
_ops: dict[str, dict] = {}
_ops_lock = threading.Lock()


class OpCancelled(RuntimeError):
    """Kullanici islemi iptal etti - `_op()` bir sonraki ilerleme adiminda firlatir."""


def _op_new(kind: str, total: int) -> str:
    op_id = uuid.uuid4().hex[:12]
    with _ops_lock:
        _ops[op_id] = {"id": op_id, "kind": kind, "status": "running",
                       "done": 0, "total": total, "ok": 0, "failed": 0,
                       "message": "", "log": [], "cancel": False,
                       "started_at": datetime.now().isoformat(timespec="seconds")}
    return op_id


def _op(op_id: str, **kw):
    iptal = False
    with _ops_lock:
        o = _ops.get(op_id)
        if not o:
            return
        kayit = kw.pop("log", None)
        if kayit:
            o["log"] = (o["log"] + [kayit])[-200:]
        o.update(kw)
        iptal = bool(o.get("cancel")) and o.get("status") == "running"
    if iptal:
        raise OpCancelled("iptal edildi")


def _bitir_op(op_id: str, durum: str, mesaj: str) -> None:
    with _ops_lock:
        o = _ops.get(op_id)
        if not o:
            return
        o["status"] = durum
        if mesaj:
            o["message"] = mesaj
        o["finished_at"] = datetime.now().isoformat(timespec="seconds")


def _run(op_id: str, fn):
    def sarmal():
        try:
            fn()
            _bitir_op(op_id, "done", "")
        except OpCancelled:
            _bitir_op(op_id, "cancelled", "iptal edildi")
        except Exception as e:
            with _ops_lock:
                iptal = bool((_ops.get(op_id) or {}).get("cancel"))
            _bitir_op(op_id, "cancelled" if iptal else "error",
                      "iptal edildi" if iptal else str(e)[:400])
    threading.Thread(target=sarmal, daemon=True).start()


def op_status(op_id: str) -> dict | None:
    with _ops_lock:
        o = _ops.get(op_id)
        return dict(o) if o else None


def ops() -> list[dict]:
    with _ops_lock:
        return sorted((dict(o) for o in _ops.values()),
                      key=lambda o: o["started_at"], reverse=True)[:20]


def cancel_op(op_id: str) -> dict:
    with _ops_lock:
        o = _ops.get(op_id)
        if not o:
            return {"ok": False, "detail": "islem yok"}
        if o.get("status") != "running":
            return {"ok": False, "detail": "islem zaten bitmis (%s)" % o.get("status")}
        o["cancel"] = True
        o["message"] = "iptal ediliyor..."
    return {"ok": True, "op": op_id}


# ------------------------------------------------------------------ kopyalama
def copy(src_bucket: str, dst_bucket: str, src_key: str = "", dst_key: str = "",
         src_prefix: str = "", dst_prefix: str = "", client: str = "") -> str:
    """Sunucu tarafi kopya (Cloudflare icinde calisir - bu hattan bayt gecmez).

    Tek anahtar (src_key/dst_key) ya da onek (src_prefix/dst_prefix) verilir;
    onekte kaynagin altindaki her nesne hedef onegin altina ayni goreli yolla
    yazilir. Arka plan islemi, `op_status` ile izlenir.
    """
    bucket_info(src_bucket)
    bucket_info(dst_bucket)
    if src_key and src_prefix:
        raise ValueError("ya anahtar ya onek verilir, ikisi birden degil")
    if not src_key and not src_prefix:
        raise ValueError("kaynak anahtar ya da onek gerekli")
    if src_key and not dst_key:
        raise ValueError("hedef anahtar gerekli")
    if src_prefix and not dst_prefix:
        raise ValueError("hedef onek gerekli")

    c = s3()
    if src_key:
        isler = [(src_key, dst_key)]
    else:
        if not src_prefix.endswith("/"):
            src_prefix += "/"
        if not dst_prefix.endswith("/"):
            dst_prefix += "/"
        isler = [(o["key"], dst_prefix + o["key"][len(src_prefix):])
                 for o in c.list_all(src_bucket, prefix=src_prefix)]
    if not isler:
        raise ValueError("kopyalanacak nesne yok: %s/%s" % (src_bucket, src_prefix or src_key))

    op_id = _op_new("r2copy", len(isler))
    _audit(client, "copy", src_bucket, ["%s -> %s/%s" % (s, dst_bucket, d) for s, d in isler[:MAX_DELETE_KEYS]])

    def calis():
        for i, (s, d) in enumerate(isler, 1):
            _op(op_id, message="kopyalaniyor %d/%d  %s" % (i, len(isler), s))
            try:
                c.copy_object(src_bucket, s, dst_bucket, d)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="KOPYALANAMADI %s: %s" % (s, str(e)[:150]))
                continue
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="+ %s/%s" % (dst_bucket, d))

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ baslik onarimi
def fix_headers(bucket: str, prefix: str = "", client: str = "") -> str:
    """Onbellek standardindan sapan Cache-Control'u yerinde duzeltir.

    Her nesne HEAD edilir (bayt inmez); sapan nesne KENDI uzerine REPLACE ile
    kopyalanir, Content-Type korunur. Bilerek degisken birakilan onekler
    (characters/*/relationships/) atlanir.
    """
    bucket_info(bucket)
    c = s3()
    anahtarlar = [o["key"] for o in c.list_all(bucket, prefix=prefix)]
    if not anahtarlar:
        raise ValueError("bu onekte nesne yok: %s/%s" % (bucket, prefix))
    op_id = _op_new("r2headers", len(anahtarlar))
    _audit(client, "fix-headers", bucket, [prefix or "(tum kova)"])

    def calis():
        duzeltilen = 0
        for i, k in enumerate(anahtarlar, 1):
            _op(op_id, message="baslik denetimi %d/%d" % (i, len(anahtarlar)))
            try:
                h = c.head_object(bucket, k)
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="BASLIK OKUNAMADI %s: %s" % (k, str(e)[:120]))
                continue
            d = header_check(bucket, k, h["cache_control"])
            if d["ok"]:
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i)
                continue
            try:
                c.copy_object(bucket, k, bucket, k,
                              content_type=h["content_type"] or "application/octet-stream",
                              cache_control=d["expected"])
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="DUZELTILEMEDI %s: %s" % (k, str(e)[:120]))
                continue
            duzeltilen += 1
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="~ %s  %s -> %s" % (k, d["actual"] or "(yok)", d["expected"]))
        _op(op_id, message="%d nesnenin basligi duzeltildi" % duzeltilen)

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ farklar
# Yerel "Pushed" duzeni -> kova anahtari: <koleksiyon>/<n>.jpg -> collections/
# <koleksiyon>/images/<n>.jpg. .json yan dosyasi YEREL kayittir, kovaya gitmez.
_PUSH_FOLDER = {".jpg": "images", ".jpeg": "images", ".mp4": "videos",
                ".webp": "videos_webp", ".mp3": "music"}

# Kovada URETILEN agac: gri thumb'lar yerelde hic olmaz, "yerelde eksik" degil.
# Ayri raporlanir ki gercek eksikler 1400 satirin altinda kaybolmasin.
_DERIVED_FOLDERS = ("thumbs",)


def _derived(key: str) -> bool:
    parcalar = key.split("/")
    return len(parcalar) > 2 and parcalar[2] in _DERIVED_FOLDERS


def diff(rating: str, collection: str = "") -> dict:
    """Yerel "Push edilmis" klasoru <-> kova: kovada eksik, yerelde eksik, boyut farki."""
    from . import jigsaw_flow as JF
    p = JF.paths(rating)
    kok, bucket = p["pushed"], p["bucket"]

    yerel: dict[str, int] = {}
    try:
        with os.scandir(kok) as it:
            kolleksiyonlar = sorted([e.name for e in it if e.is_dir()], key=str.lower)
    except OSError as e:
        raise ValueError("yerel klasor okunamadi (%s): %s" % (kok, e))
    if collection:
        kolleksiyonlar = [c for c in kolleksiyonlar if c.lower() == collection.lower()]
    if not kolleksiyonlar:
        raise ValueError("push edilmis koleksiyon yok: %s" % (collection or kok))
    for c in kolleksiyonlar:
        with os.scandir(os.path.join(kok, c)) as it:
            for e in it:
                if not e.is_file():
                    continue
                klasor = _PUSH_FOLDER.get(os.path.splitext(e.name)[1].lower())
                if not klasor:
                    continue                    # .json yan dosyasi ve digerleri yerel kalir
                yerel["collections/%s/%s/%s" % (c, klasor, e.name)] = e.stat().st_size

    onek = "collections/%s/" % kolleksiyonlar[0] if len(kolleksiyonlar) == 1 else "collections/"
    kovada = {o["key"]: o["size"] for o in s3().list_all(bucket, prefix=onek)}

    eksik_kovada = sorted(k for k in yerel if k not in kovada)
    fazla = sorted(k for k in kovada if k not in yerel)
    boyut = [{"key": k, "local": yerel[k], "bucket": kovada[k]}
             for k in sorted(yerel) if k in kovada and kovada[k] != yerel[k]]
    return {"rating": rating, "bucket": bucket, "local_root": kok,
            "collections": kolleksiyonlar, "local_count": len(yerel), "bucket_count": len(kovada),
            "missing_in_bucket": eksik_kovada,
            "missing_locally": [k for k in fazla if not _derived(k)],
            "derived_in_bucket": [k for k in fazla if _derived(k)],
            "size_mismatch": boyut}


def twin_diff(bucket: str) -> dict:
    """YENI kova <-> ESKI ikizi: ay sonu emeklilik listesinin ihtiyaci olan fark.

    Eslenmemis anahtarlar ayri raporlanir - kural yoksa esleme uydurulmaz.
    """
    hedefler = twin_buckets(bucket)
    if not hedefler:
        raise ValueError("%s kovasinin ikizi yok" % bucket)
    if bucket_info(bucket).get("role") == "legacy":
        raise ValueError("ikiz farki YENI kovadan alinir: %s" % ", ".join(hedefler))
    hedef = hedefler[0]
    c = s3()
    yeni = {o["key"]: o["size"] for o in c.list_all(bucket)}
    eski = {}
    for onek in sorted({_literal_prefix(r["to_key"]) for r in _rules(bucket) if r["to"] == hedef}):
        for o in c.list_all(hedef, prefix=onek):
            eski[o["key"]] = o["size"]

    eksik_eskide, boyut, eslenmeyen = [], [], []
    beklenen: dict[str, str] = {}                # ikiz anahtar -> yeni anahtar
    for k, boy in yeni.items():
        tb, tk = twin_key(bucket, k)
        if not tk or tb != hedef:
            eslenmeyen.append(k)
            continue
        beklenen[tk] = k
        if tk not in eski:
            eksik_eskide.append(k)
        elif eski[tk] != boy:
            boyut.append({"key": k, "twin_key": tk, "new": boy, "legacy": eski[tk]})
    fazla_eskide = sorted(k for k in eski if k not in beklenen)
    return {"bucket": bucket, "twin": hedef, "map": twin_map(bucket),
            "new_count": len(yeni), "legacy_count": len(eski),
            "missing_in_legacy": sorted(eksik_eskide),
            "only_in_legacy": fazla_eskide,
            "size_mismatch": boyut, "unmapped": sorted(eslenmeyen)}
