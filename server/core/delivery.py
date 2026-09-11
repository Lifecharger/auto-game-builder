"""Delivery Mod (#363): uygulamalara ne sunulacaginin kural anahtarlari.

Kullanicinin amaci: olasi bir Google Play strike'ina HIZLI tepki. Generic
havuzundaki her gorselin EXIF'inde rating / safety / voyeur / skin / risk ...
alanlari var; bu modul o alanlarin degerleri uzerinde uygulama basina ac/kapa
anahtarlarini hotjigsaw-scanner worker'ina yazar. Worker manifesti uygulama
basina filtreler ve kural degisince kenar onbellegini kendiliginden dusurur -
uygulama guncellemesi gerekmez, sonraki manifest isteginde canli.

Yonetim anahtari depoya girmez: `delivery.admin_key_file` ayari (yoksa
D:/keys/serve_admin_key.txt). Worker ucu: `delivery.worker_url` (yoksa
hotjigsaw-scanner).
"""
from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request

from . import card_flow as _CF

DEFAULT_WORKER = "https://hotjigsaw-scanner.lifecharger.workers.dev"
DEFAULT_KEY_FILE = r"D:\keys\serve_admin_key.txt"

# Bu worker'dan manifest ceken uygulamalar (paket -> ad). Uygulama manifest
# istegine `?app=<paket>` ekledikce kendi kural setini alir; eklemeyen
# (eski surum) `default` kuralini alir.
APPS = [
    {"package": "com.lifecharger.hotjigsaw", "name": "Hot Jigsaw"},
    {"package": "com.lifecharger.hotcharm", "name": "Hot Charm"},
    {"package": "com.lifecharger.hotidle", "name": "Hot Idle"},
    {"package": "com.lifecharger.hotslider", "name": "Hot Slider"},
    {"package": "com.lifecharger.sentience", "name": "Sentience"},
]

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


def worker_url() -> str:
    return (_CF._setting("delivery.worker_url") or DEFAULT_WORKER).rstrip("/")


def admin_key() -> str:
    yol = _CF._setting("delivery.admin_key_file") or DEFAULT_KEY_FILE
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


def _call(path: str, body: dict | None = None, method: str | None = None, timeout: int = 60) -> dict:
    key = admin_key()
    if not key:
        raise ValueError("delivery yonetim anahtari yok (delivery.admin_key_file)")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(worker_url() + path, data=data,
                                 headers={"X-Admin-Key": key, "Content-Type": "application/json",
                                          "User-Agent": "agb-delivery/1"},
                                 method=method or ("PUT" if data is not None else "GET"))
    try:
        with _opener.open(req, timeout=timeout) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise ValueError("worker %s: %s" % (e.code, (e.read() or b"")[:200].decode("utf-8", "replace")))


def rules() -> dict:
    r = _call("/serve-rules")
    r.setdefault("default", {"enabled": True, "untagged": True, "values": {}})
    r.setdefault("apps", {})
    return r


def save_rules(body: dict) -> dict:
    """Kurallari worker'a yazar (updated damgasini worker koyar) - anlik canli."""
    if not isinstance(body, dict):
        raise ValueError("kural govdesi sozluk olmali")
    temiz = {"default": _ruleset(body.get("default")), "apps": {}}
    for pk, rs in (body.get("apps") or {}).items():
        if isinstance(rs, dict):
            temiz["apps"][str(pk)] = _ruleset(rs)
    out = _call("/serve-rules", temiz)
    return {"ok": True, "updated": out.get("updated"), "rules": dict(temiz, updated=out.get("updated"))}


def _ruleset(rs) -> dict:
    rs = rs if isinstance(rs, dict) else {}
    values = {}
    for alan, tablo in (rs.get("values") or {}).items():
        if isinstance(tablo, dict):
            # yalniz KAPALI olanlar saklanir - tablo kisa kalir, yeni deger acik dogar
            kapali = {str(v): False for v, on in tablo.items() if on is False}
            if kapali:
                values[str(alan)] = kapali
    return {"enabled": rs.get("enabled", True) is not False,
            "untagged": rs.get("untagged", True) is not False,
            "values": values}


def values(collection: str = "generic") -> dict:
    """Alan -> deger -> sayi (Generic havuzunun gercek EXIF dagilimi)."""
    d = _call("/serve-values?collection=" + urllib.parse.quote(collection))
    sira = [f for f, _ in FIELDS]
    alanlar = d.get("fields") or {}
    d["order"] = [f for f in sira if f in alanlar] + sorted(a for a in alanlar if a not in sira)
    d["labels"] = dict(FIELDS)
    return d


def preview(app: str = "") -> dict:
    return _call("/serve-preview?app=" + urllib.parse.quote(app or ""), timeout=120)


def preview_all() -> dict:
    """Varsayilan + butun uygulamalar TEK cagrida (worker metadata'yi bir kez yukler)."""
    q = ",".join([""] + [a["package"] for a in APPS])
    return (_call("/serve-preview?apps=" + urllib.parse.quote(q), timeout=120) or {}).get("apps") or {}


def overview() -> dict:
    """Tek ekran icin her sey: kurallar, degerler, uygulama listesi, on izleme sayilari."""
    r = rules()
    v = values()
    try:
        pv = preview_all()
    except Exception as e:  # noqa: BLE001
        pv = {"_error": str(e)[:120]}
    apps = []
    for a in APPS:
        st = pv.get(a["package"]) or {}
        apps.append(dict(a, custom=a["package"] in (r.get("apps") or {}),
                         served=st.get("served"), total=st.get("total"), blocked=st.get("blocked") or {}))
    return {"worker": worker_url(), "rules": r, "values": v, "apps": apps,
            "default_stats": pv.get("default") or {},
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

