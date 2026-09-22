"""Delivery Mod (#363): uygulamalara ne sunulacaginin kural anahtarlari.

Kullanicinin amaci: olasi bir Google Play strike'ina HIZLI tepki. Generic
havuzundaki her gorselin EXIF'inde rating / safety / voyeur / skin / risk ...
alanlari var; bu modul o alanlarin degerleri uzerinde uygulama basina ac/kapa
anahtarlarini dagitim worker'ina yazar. Worker manifesti uygulama
basina filtreler ve kural degisince kenar onbellegini kendiliginden dusurur -
uygulama guncellemesi gerekmez, sonraki manifest isteginde canli.

Topolojinin tamami `settings.json` -> `delivery` altindadir ve depoya GIRMEZ:
`worker_url`, `card_worker_url`, `admin_key_file` (yonetim anahtarinin yolu) ve
`apps` / `card_apps` uygulama listeleri. Sekli icin `settings.example.json`.
Ayar yoksa kod bir alan adi uydurmaz, acik bir hata verir.
"""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request

from . import card_flow as _CF

# Dagitim TOPOLOJISI kodda DURMAZ: worker adresleri, yonetim anahtarinin yolu
# ve hangi uygulamanin hangi havuzdan manifest cektigi `settings.json`'dan
# okunur (o dosya gitignore'da). Depoda yalnizca sekli vardir -
# `settings.example.json` -> `delivery`. Ayar yoksa liste bos gelir ve arayuz
# "uygulama tanimlanmamis" der; kod bir alan adi uydurmaz.
_SETTINGS_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                              "config", "settings.json")


def _ayar(anahtar: str, default=None):
    """settings.json'dan herhangi bir deger - `_CF._setting` yalniz METIN dondurur."""
    try:
        with open(_SETTINGS_FILE, encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for part in anahtar.split("."):
            d = (d or {}).get(part)
        return default if d is None else d
    except Exception:  # noqa: BLE001
        return default


def _liste(anahtar: str) -> list[dict]:
    """settings.json'daki uygulama listesi: [{"package": ..., "name": ...}]."""
    ham = _ayar(anahtar) or []
    out = []
    for x in ham if isinstance(ham, list) else []:
        if isinstance(x, dict) and x.get("package"):
            out.append({"package": str(x["package"]), "name": str(x.get("name") or x["package"])})
    return out


POOLS = ("jigsaw", "cards", "events")

# Havuz -> (ayar anahtari, uygulama listesi anahtari). #385: `events` havuzu
# etkinlik sunucusu Celeste'in seviye gorsellerini tasir.
_POOL_AYAR = {"jigsaw": ("delivery.worker_url", "delivery.apps"),
              "cards": ("delivery.card_worker_url", "delivery.card_apps"),
              "events": ("delivery.event_worker_url", "delivery.event_apps")}


def apps(pool: str = "jigsaw") -> list[dict]:
    """Bu havuzdan manifest ceken uygulamalar (paket -> ad).

    Uygulama manifest istegine `?app=<paket>` ekledikce kendi kural setini alir;
    eklemeyen (eski surum) `default` kuralini alir.
    """
    if pool not in _POOL_AYAR:
        raise ValueError("Unknown delivery pool: " + pool)
    return _liste(_POOL_AYAR[pool][1])

# Alan etiketleri + siralama (arayuz bu sirayla cizer; listede olmayan alanlar
# sona eklenir). Ilk grup "strike" acisindan en onemli olanlar.
FIELDS = [
    ("rating", "Rating (Play yas siniri)"),
    ("safety", "Guvenlik seviyesi"),
    ("voyeur", "Roontgen / voyeur riski"),
    ("flags", "Politika bayraklari"),
    ("risk", "Risk etkenleri"),
    ("skin", "Ten gorunurlugu"),
    ("coverage", "Kiyafet ortusu"),
    ("adult", "Adult (1-5)"),
    ("racy", "Racy (1-5)"),
    ("violence", "Siddet (1-5)"),
    ("pose", "Poz"),
    ("context", "Baglam"),
    ("framing", "Kadraj"),
    ("camera", "Kamera acisi"),
    ("view", "Gorunum"),
    ("fit", "Kiyafet kesimi"),
    ("clothing", "Kiyafet turu"),
    ("body", "Gorunen vucut bolgeleri"),
    ("mood", "Ruh hali"),
    ("style", "Sanat stili"),
    ("setting", "Mekan"),
    ("focus", "Gorsel odak"),
]

# Hizli on ayarlar - "strike geldi, hemen kis" icin.
PRESETS = {
    "hepsi_acik": {"label": "Hepsi acik", "values": {}},
    "orta": {"label": "Orta: risky + adult kapali",
             "values": {"safety": {"risky": False}, "rating": {"adult": False},
                        "voyeur": {"medium": False, "high": False}}},
    "siki": {"label": "Siki: yalniz safe + teen/kid, voyeur yok",
             "values": {"safety": {"borderline": False, "risky": False},
                        "rating": {"mature": False, "adult": False},
                        "voyeur": {"low": False, "medium": False, "high": False},
                        "flags": {"sexualized_content": False, "sexual_suggestiveness": False,
                                  "suggestive_content": False},
                        "pose": {"suggestive": False}}},
}


def worker_url(pool: str = "jigsaw") -> str:
    if pool not in _POOL_AYAR:
        raise ValueError("Unknown delivery pool: " + pool)
    anahtar = _POOL_AYAR[pool][0]
    url = _CF._setting(anahtar) or ""
    if not url:
        raise ValueError("delivery worker adresi tanimsiz (settings.json -> %s)" % anahtar)
    return url.rstrip("/")


def admin_key() -> str:
    yol = _CF._setting("delivery.admin_key_file") or ""
    if not yol:
        return ""
    try:
        with open(yol, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return ""


# Bu makinede workers.dev'e IPv6 baglantisi 7 sn asili kaliyor (urllib once
# IPv6 dener, birkac adres -> 40 sn). curl IPv4'e aninda baglaniyor. Adres
# cozumunu IPv4'e zorlayan baglanti sinifi; SNI/hostname degismez.
import http.client
import socket


def _ipv4_addr(host: str, port: int):
    ai = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
    return ai[0][4] if ai else (host, port)


class _IPv4HTTPSConnection(http.client.HTTPSConnection):
    def connect(self):
        self._create_connection = lambda addr, timeout=None, source_address=None:             socket.create_connection(_ipv4_addr(*addr), timeout, source_address)
        super().connect()


class _IPv4HTTPSHandler(urllib.request.HTTPSHandler):
    def https_open(self, req):
        return self.do_open(_IPv4HTTPSConnection, req, context=self._context)


_opener = urllib.request.build_opener(_IPv4HTTPSHandler())


def _call(path: str, body: dict | None = None, method: str | None = None, timeout: int = 60, pool: str = "jigsaw") -> dict:
    key = admin_key()
    if not key:
        raise ValueError("delivery yonetim anahtari yok (delivery.admin_key_file)")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(worker_url(pool) + path, data=data,
                                 headers={"X-Admin-Key": key, "Content-Type": "application/json",
                                          "User-Agent": "agb-delivery/1"},
                                 method=method or ("PUT" if data is not None else "GET"))
    try:
        with _opener.open(req, timeout=timeout) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise ValueError("worker %s: %s" % (e.code, (e.read() or b"")[:200].decode("utf-8", "replace")))


# ------------------------------------------------------------- #385 ENGEL
# Kural tablosu ALANLARA gore filtreler; engel listesi TEK TEK ogeye gore.
# Kural bir sey kacirirsa engel emniyet kemeridir: kullanici AGB'den resmi,
# koleksiyonu, karti, desteyi ya da sunucu seviyesini kapatir ve o oge hicbir
# manifeste girmez. Worker KV/kova anahtari `serve_block`:
#   {updated, global: LISTELER, apps: {"<paket>": LISTELER}}
#   LISTELER = {pictures:["<koleksiyon>/<dosya>"], collections:[], cards:[],
#               decks:[], hostLevels:[]}
# Bir uygulamanin gordugu engel = global + o uygulamanin listesi (BIRLESIM);
# `updated` damgasi kural damgasi gibi kenar onbellek anahtarina girer.
BLOCK_LISTS = ("pictures", "collections", "cards", "decks", "hostLevels")

# Havuz basina anlami olan listeler - arayuz yalnizca bunlari gosterir.
POOL_BLOCK_LISTS = {"jigsaw": ("pictures", "collections"),
                    "cards": ("cards", "decks"),
                    "events": ("hostLevels",)}


def _block_lists(ham) -> dict:
    ham = ham if isinstance(ham, dict) else {}
    out = {}
    for ad in BLOCK_LISTS:
        gorulen, liste = set(), []
        for x in (ham.get(ad) or []):
            deger = str(x).strip()
            if deger and deger not in gorulen:
                gorulen.add(deger)
                liste.append(deger)
        out[ad] = liste
    return out


def block(pool: str = "jigsaw") -> dict:
    """Worker'daki engel listesi (+ hangi listeler bu havuzda anlamli)."""
    b = _call("/serve-block", pool=pool)
    out = {"updated": int(b.get("updated") or 0),
           "global": _block_lists(b.get("global")),
           "apps": {str(pk): _block_lists(v) for pk, v in (b.get("apps") or {}).items()},
           "lists": list(POOL_BLOCK_LISTS.get(pool) or BLOCK_LISTS),
           "pool": pool}
    return out


def save_block(body: dict, pool: str = "jigsaw") -> dict:
    """Engel listesini worker'a yazar - kural kaydi gibi anlik canli."""
    if not isinstance(body, dict):
        raise ValueError("engel govdesi sozluk olmali")
    temiz = {"global": _block_lists(body.get("global")), "apps": {}}
    for pk, v in (body.get("apps") or {}).items():
        liste = _block_lists(v)
        if any(liste[a] for a in BLOCK_LISTS):      # bos uygulama kaydi tutulmaz
            temiz["apps"][str(pk)] = liste
    out = _call("/serve-block", temiz, pool=pool)
    return {"ok": True, "updated": out.get("updated"),
            "block": dict(temiz, updated=out.get("updated"),
                          lists=list(POOL_BLOCK_LISTS.get(pool) or BLOCK_LISTS), pool=pool)}


def put_serve_index(collection: str, index: dict) -> dict:
    """#385: gallery-hot'un kompakt sunum indeksini worker'a YAZAR.

    Worker o indeksi yalnizca OKUR (`loadServeIndex`); daha once yalnizca kendi
    `metadata_rich_*` kayitlarindan uretebiliyordu, bu yuzden Generic disindaki
    koleksiyonlar filtrelenemiyordu. Normalizer her koleksiyon icin buraya
    yazar -> kurallar ve engeller HER koleksiyonda gecerli olur.
    """
    if not isinstance(index, dict):
        raise ValueError("indeks sozluk olmali")
    return _call("/serve-index", {"collection": str(collection), "index": index},
                 method="PUT", timeout=180)


def catalog(pool: str = "jigsaw") -> dict:
    """Engel tarayicisinin listesi: koleksiyon/deste/seviye + kapak gorseli.

    Worker'in kendi `/serve-catalog` ucundan gelir - tek kaynak, uc istemci
    ayni listeyi gorur.
    """
    return _call("/serve-catalog", pool=pool, timeout=120)


def rules(pool: str = "jigsaw") -> dict:
    r = _call("/serve-rules", pool=pool)
    r.setdefault("default", {"enabled": True, "untagged": True, "values": {}})
    r.setdefault("apps", {})
    if pool == "cards":     # eski KV kaydinda kapsam yok - istemciler hep ayni sekli gorsun
        for rs in [r["default"], *(r["apps"] or {}).values()]:
            if isinstance(rs, dict):
                rs.setdefault("collections", {"mode": "all", "ids": []})
    return r


def save_rules(body: dict, pool: str = "jigsaw") -> dict:
    """Kurallari worker'a yazar (updated damgasini worker koyar) - anlik canli."""
    if not isinstance(body, dict):
        raise ValueError("kural govdesi sozluk olmali")
    temiz = {"default": _ruleset(body.get("default"), pool), "apps": {}}
    for pk, rs in (body.get("apps") or {}).items():
        if isinstance(rs, dict):
            temiz["apps"][str(pk)] = _ruleset(rs, pool)
    out = _call("/serve-rules", temiz, pool=pool)
    return {"ok": True, "updated": out.get("updated"), "rules": dict(temiz, updated=out.get("updated"))}


def _kapsam(rs) -> dict:
    """Uygulamanin gordugu KOLEKSIYONLAR (yalniz kart havuzu).

    `all` manifest'teki her koleksiyonu verir; `only` yalniz sayilanlari verir,
    yani sonradan yayinlanan bir koleksiyon o uygulamaya kendiliginden GECMEZ.
    Bos bir `only` listesi uygulamayi bos katalogla birakirdi - `all`a duser.
    """
    k = rs.get("collections")
    k = k if isinstance(k, dict) else {}
    ids, gorulen = [], set()
    for x in (k.get("ids") or []):
        ad = str(x).strip()
        if ad and ad not in gorulen:
            gorulen.add(ad)
            ids.append(ad)
    return {"mode": "only", "ids": ids} if k.get("mode") == "only" and ids else {"mode": "all", "ids": []}


def _ruleset(rs, pool: str = "jigsaw") -> dict:
    rs = rs if isinstance(rs, dict) else {}
    values = {}
    for alan, tablo in (rs.get("values") or {}).items():
        if isinstance(tablo, dict):
            # yalniz KAPALI olanlar saklanir - tablo kisa kalir, yeni deger acik dogar
            kapali = {str(v): False for v, on in tablo.items() if on is False}
            if kapali:
                values[str(alan)] = kapali
    out = {"enabled": rs.get("enabled", True) is not False,
           "untagged": rs.get("untagged", True) is not False,
           "values": values}
    if pool == "cards":     # koleksiyon kapsami yalniz kart katalogunda anlamli
        out["collections"] = _kapsam(rs)
    return out


def values(collection: str = "", pool: str = "jigsaw") -> dict:
    """Alan -> deger -> sayi (havuzdaki gercek etiket dagilimi).

    #385: jigsaw havuzunda artik HER koleksiyon filtrelenebiliyor, o yuzden
    varsayilan dagilim da butun havuzdur (`*`), yalniz Generic degil.
    """
    collection = collection or ("host" if pool == "events" else "*")
    d = _call("/serve-values?collection=" + urllib.parse.quote(collection), pool=pool)
    sira = [f for f, _ in FIELDS]
    alanlar = d.get("fields") or {}
    d["order"] = [f for f in sira if f in alanlar] + sorted(a for a in alanlar if a not in sira)
    d["labels"] = dict(FIELDS)
    return d


def preview(app: str = "", pool: str = "jigsaw") -> dict:
    return _call("/serve-preview?app=" + urllib.parse.quote(app or ""), timeout=120, pool=pool)


def preview_all(pool: str = "jigsaw") -> dict:
    """Varsayilan + butun uygulamalar TEK cagrida (worker metadata'yi bir kez yukler)."""
    q = ",".join([""] + [a["package"] for a in apps(pool)])
    return (_call("/serve-preview?apps=" + urllib.parse.quote(q), timeout=120, pool=pool) or {}).get("apps") or {}


def overview(pool: str = "jigsaw") -> dict:
    """Tek ekran icin her sey: kurallar, degerler, uygulama listesi, on izleme sayilari."""
    worker_url(pool)
    r = rules(pool)
    v = values(pool=pool)
    try:
        pv = preview_all(pool)
    except Exception as e:  # noqa: BLE001
        pv = {"_error": str(e)[:120]}
    try:
        blk = block(pool)
    except Exception as e:  # noqa: BLE001
        blk = {"updated": 0, "global": _block_lists({}), "apps": {},
               "lists": list(POOL_BLOCK_LISTS.get(pool) or BLOCK_LISTS), "pool": pool,
               "error": str(e)[:160]}
    satirlar = []
    for a in apps(pool):
        st = pv.get(a["package"]) or {}
        engel = blk.get("apps", {}).get(a["package"]) or {}
        satirlar.append(dict(a, custom=a["package"] in (r.get("apps") or {}),
                             served=st.get("served"), total=st.get("total"), blocked=st.get("blocked") or {},
                             collections=st.get("collections") or {},
                             blocks=sum(len(engel.get(x) or []) for x in BLOCK_LISTS)))
    return {"pool": pool, "worker": worker_url(pool), "rules": r, "values": v, "apps": satirlar,
            "collections": v.get("collections") or [],
            "default_stats": pv.get("default") or {}, "block": blk,
            "presets": {k: {"label": p["label"]} for k, p in PRESETS.items()}}


def preset(name: str) -> dict:
    p = PRESETS.get(name)
    if not p:
        raise ValueError("bilinmeyen on ayar: %s (%s)" % (name, ", ".join(PRESETS)))
    return {"enabled": True, "untagged": True, "values": json.loads(json.dumps(p["values"]))}


def reindex(collection: str = "generic", names: list[str] | None = None, all_: bool = False) -> dict:
    """#363b: bucket'taki EXIF'i degisen gorselleri yeniden okutur (worker /serve-reindex).

    Worker isleyicisi yalniz KV'de adi olmayan (yeni) gorselleri okur; mevcut bir
    gorselin EXIF'i degisince KV ve sunulan manifest DEGISMEZDI. Bu cagri KV'yi
    ezer, kompakt indeksi dusurur ve kural damgasini yeniler -> her uygulamanin
    manifesti sonraki istekte yeniden filtrelenir. all_=True butun koleksiyonu
    50'lik partilerle gezer.
    """
    col = (collection or "generic").lower()
    if not all_:
        adlar = [str(n).strip() for n in (names or []) if str(n).strip()]
        if not adlar:
            raise ValueError("ad listesi bos (names) ya da all=true ver")
        out = _call("/serve-reindex", {"collection": col, "names": adlar}, method="POST", timeout=180)
        return {"collection": col, "reindexed": out.get("reindexed", 0), "missing": out.get("missing") or []}
    toplam, eksik, off = 0, [], 0
    while True:
        out = _call("/serve-reindex", {"collection": col, "all": True, "offset": off, "limit": 50},
                    method="POST", timeout=180)
        toplam += int(out.get("reindexed") or 0)
        eksik += out.get("missing") or []
        if out.get("next_offset") is None:
            break
        off = int(out["next_offset"])
    return {"collection": col, "reindexed": toplam, "missing": eksik, "total": out.get("total")}

