"""AGB acilirken yaninda kalkmasi gereken yerel servisler.

  * ComfyUI   (127.0.0.1:8188) - uretim motoru; comfy_gen bunu surer
  * LAN sitesi (0.0.0.0:8080)  - ayni WiFi'daki cihazlar icin arayuz

Ikisi de ZATEN AYAKTAYSA yeniden baslatilmaz; port yoklanir, cevap veren
servise dokunulmaz. AGB kapanirken bunlar OLDURULMEZ - ComfyUI'nin model
yuklemesi dakikalar suruyor, AGB'nin her yeniden baslatilisinda onu da
dusurmek pahaliya mal olur.

Ayarlar `settings.json` -> `side_services`:

    "side_services": {
      "enabled": true,
      "comfyui": {"enabled": true, "python": "<ComfyUI>/.venv/Scripts/python.exe",
                  "script": "main.py", "cwd": "<ComfyUI>",
                  "url": "http://127.0.0.1:8188"},
      "lan_site": {"enabled": true, "python": "",
                   "script": "<scripts>/lan_server.py", "cwd": "<scripts>",
                   "url": "http://127.0.0.1:8080"}
    }

Anahtar yoksa asagidaki varsayilanlar kullanilir.
"""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SETTINGS = os.path.join(_HERE, "config", "settings.json")

# Varsayilanlarda MAKINEYE OZEL YOL YOK - depo herkese acik. Yollar
# settings.json -> side_services altinda tutulur (o dosya gitignore'da).
# Yol verilmemisse servis baslatilmaz, sebebi konsola yazilir.
VARSAYILAN = {
    "enabled": True,
    "comfyui": {
        "enabled": True,
        "python": "",                     # bos = AGB'nin kendi python'u
        "script": "",                     # orn: <ComfyUI>/main.py
        "cwd": "",
        "url": "http://127.0.0.1:8188",
        "wait": 180,
    },
    "lan_site": {
        "enabled": True,
        "python": "",
        "script": "",                     # orn: <scripts>/lan_server.py
        "cwd": "",
        "url": "http://127.0.0.1:8080",
        "wait": 20,
    },
}

_durum: dict[str, dict] = {}


def _ayar() -> dict:
    try:
        import json
        with open(SETTINGS, encoding="utf-8") as fh:
            s = (json.load(fh) or {}).get("side_services") or {}
    except Exception:
        s = {}
    out = {"enabled": s.get("enabled", VARSAYILAN["enabled"])}
    for ad in ("comfyui", "lan_site"):
        birlesik = dict(VARSAYILAN[ad])
        birlesik.update(s.get(ad) or {})
        out[ad] = birlesik
    return out


def _ayakta(url: str, timeout: float = 2.0) -> bool:
    try:
        urllib.request.urlopen(url, timeout=timeout)
        return True
    except urllib.error.HTTPError:
        return True                       # cevap veriyor, kod onemli degil
    except Exception:
        return False


def _port_dolu(port: int) -> bool:
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", port)) == 0


def _baslat(ad: str, cfg: dict) -> dict:
    """Bir servisi baslatir. Zaten ayaktaysa dokunmaz."""
    url = cfg.get("url") or ""
    if url and _ayakta(url):
        return {"service": ad, "state": "zaten calisiyor", "url": url}

    py = cfg.get("python") or sys.executable
    script = cfg.get("script") or ""
    cwd = cfg.get("cwd") or os.path.dirname(script) or None

    if not script:
        return {"service": ad, "state": "yapilandirilmamis",
                "error": "settings.json -> side_services.%s.script bos" % ad}
    if not os.path.isfile(py):
        return {"service": ad, "state": "hata", "error": "python bulunamadi: %s" % py}
    hedef = script if os.path.isabs(script) else os.path.join(cwd or "", script)
    if not os.path.isfile(hedef):
        return {"service": ad, "state": "hata", "error": "betik bulunamadi: %s" % hedef}

    try:
        # Pencere acilmasin, AGB kapaninca cocuk surec olmesin: yeni surec grubu.
        bayrak = 0
        if os.name == "nt":
            bayrak = (getattr(subprocess, "CREATE_NO_WINDOW", 0)
                      | getattr(subprocess, "DETACHED_PROCESS", 0))
        p = subprocess.Popen([py, hedef], cwd=cwd,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             stdin=subprocess.DEVNULL, creationflags=bayrak,
                             env={**os.environ, "PYTHONIOENCODING": "utf-8"})
    except Exception as e:
        return {"service": ad, "state": "hata", "error": str(e)[:200]}

    # Ayaga kalkmasini bekle - ComfyUI model yukledigi icin uzun surebilir.
    bitis = time.time() + float(cfg.get("wait") or 30)
    while time.time() < bitis:
        if p.poll() is not None:
            return {"service": ad, "state": "hata", "pid": p.pid,
                    "error": "surec cikti (kod %s)" % p.returncode}
        if url and _ayakta(url):
            return {"service": ad, "state": "baslatildi", "pid": p.pid, "url": url}
        time.sleep(1.5)
    return {"service": ad, "state": "baslatildi (yanit yok)", "pid": p.pid,
            "url": url, "error": "sure icinde cevap vermedi"}


def start_all(background: bool = True) -> None:
    """AGB acilisinda cagrilir. Bloke etmemesi icin ayri bir thread'de calisir -
    ComfyUI'nin acilmasi dakikalar surebilir, sunucu bunu beklememeli."""
    cfg = _ayar()
    if not cfg.get("enabled"):
        print("[yan_servisler] kapali (settings.json -> side_services.enabled)")
        return

    def calis():
        for ad in ("comfyui", "lan_site"):
            c = cfg[ad]
            if not c.get("enabled"):
                _durum[ad] = {"service": ad, "state": "kapali"}
                continue
            r = _baslat(ad, c)
            _durum[ad] = r
            print("[yan_servisler] %s: %s%s"
                  % (ad, r.get("state"),
                     ("  (%s)" % r["error"]) if r.get("error") else ""))

    if background:
        threading.Thread(target=calis, daemon=True, name="yan-servisler").start()
    else:
        calis()


def status() -> dict:
    """Anlik durum - istemci gorebilsin diye."""
    cfg = _ayar()
    out = {"enabled": cfg.get("enabled"), "services": []}
    for ad in ("comfyui", "lan_site"):
        c = cfg[ad]
        url = c.get("url") or ""
        out["services"].append({
            "name": ad,
            "enabled": bool(c.get("enabled")),
            "url": url,
            "up": _ayakta(url, 1.0) if url else False,
            "last": _durum.get(ad, {}),
        })
    return out
