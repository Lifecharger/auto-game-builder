"""Tek serit: ekran karti kuyrugu.

ComfyUI kuyrugu yalnizca ComfyUI'nin kendi islerini sirala r; oysa ayni karti
kullanan baska isler de var - Ollama etiketleme / nesne bulma, CBN insa (Qwen
cizgi + SAM3), koleksiyon muzigi. Bunlar birbirine karisirsa ya VRAM tasar ya
da bir `/free` cagrisi calisan uretimi keser. Bu modul GPU'ya dokunan HER
eylemi tek bir FIFO seridinden gecirir: kim once geldiyse o calisir, sonraki
bekler. Kullanicinin tarifi: "ComfyUI kuyrugu gibi degil, ekran karti
kuyrugu gibi dusun."

    with gpu_lane.hold("etiketleme (8)", kind="tag"):
        ...   # burada GPU senin

`status()` calisan isi ve bekleyenleri verir (/api/gpu/queue) - uygulamadaki
Sira ekrani bunu gosterebilir.
"""
from __future__ import annotations

import threading
import time
import uuid
from contextlib import contextmanager
from datetime import datetime

_cv = threading.Condition()
_waiting: list[dict] = []          # FIFO biletler
_current: dict | None = None
_history: list[dict] = []          # son 30 tamamlanan


class LaneCancelled(RuntimeError):
    """#352: bilet daha serit alinmadan kullanici tarafindan dusuruldu."""


def cancel_ticket(ticket_id: str = "", op_id: str = "", job_id: str = "") -> dict:
    """#352: BEKLEYEN bir bileti dusurur (bilet id'si, op id'si ya da is id'si ile).

    Calisan bilet buradan kesilmez - onun isi (comfy isi ya da op govdesi)
    kendi kanalindan iptal edilir: comfy_gen.cancel_job / jigsaw_flow.cancel_op.
    Bekleyen bileti tutan is parcacigi hold() icinde uyanir ve LaneCancelled
    ile cikar; serit hic alinmaz.
    """
    with _cv:
        hedef = [w for w in _waiting
                 if (ticket_id and w["id"] == ticket_id)
                 or (op_id and w.get("op_id") == op_id)
                 or (job_id and w.get("job_id") == job_id)]
        for w in hedef:
            w["cancelled"] = True
        _cv.notify_all()
        return {"cancelled": len(hedef), "ids": [w["id"] for w in hedef]}

# #349: serit el degistirirken bellek birakma.
# Kullanicinin tarifi: "islem ve model degistikce free eder". Ayni turden
# arka arkaya gelen isler (ornegin 75 still) ARADA BOSALTMAZ - yalnizca tur
# degisince bir kez cagrilir, yani model yeniden yukleme bedeli en aza iner.
# gpu_lane hicbir uretim modulunu IMPORT ETMEZ (dairesel bagimlilik olmasin):
# bosaltmayi yapan taraf kendini buraya kaydeder.
_last_kind: str = ""
_release_hook = None
_lock_hook = threading.Lock()


def set_release_hook(fn) -> None:
    """Tur degisiminde cagrilacak bellek birakma islevi (fn(eski, yeni))."""
    global _release_hook
    with _lock_hook:
        _release_hook = fn


def _tur_degisti(yeni: str) -> None:
    global _last_kind
    eski = _last_kind
    _last_kind = yeni
    if not eski or eski == yeni:
        return
    with _lock_hook:
        fn = _release_hook
    if fn is None:
        return
    try:
        fn(eski, yeni)
    except Exception as e:                       # bosaltma ASLA isi dusurmez
        print("[gpu_lane] bellek birakma atlandi (%s -> %s): %s" % (eski, yeni, str(e)[:150]))


def _ticket(label: str, kind: str, op_id: str = "", job_id: str = "", total: int = 0) -> dict:
    # #299: bilet artik hangi op/isten geldigini tasir - Sira ekrani ilerlemeyi
    # (done/total/message) op defterinden bu alanla buluyor.
    return {"id": uuid.uuid4().hex[:8], "label": label, "kind": kind,
            "op_id": op_id or "", "job_id": job_id or "", "total": int(total or 0),
            "queued_at": datetime.now().isoformat(timespec="seconds"), "t0": time.time()}


@contextmanager
def hold(label: str, kind: str = "gpu", *, op_id: str = "", job_id: str = "", total: int = 0):
    """Seridi FIFO sirayla al; blok bitince birak.

    #299: op_id / job_id / total istege baglidir (eski cagiranlar degismedi).
    """
    global _current
    t = _ticket(label, kind, op_id, job_id, total)
    with _cv:
        _waiting.append(t)
        while _current is not None or _waiting[0] is not t:
            if t.get("cancelled"):
                # #352: kullanici Sira ekranindan bekleyen bileti dusurdu -
                # serit hic alinmaz, is govdesi hic baslamaz.
                _waiting.remove(t)
                _cv.notify_all()
                raise LaneCancelled("sirada iptal edildi: %s" % label)
            _cv.wait()
        if t.get("cancelled"):
            _waiting.remove(t)
            _cv.notify_all()
            raise LaneCancelled("sirada iptal edildi: %s" % label)
        _waiting.remove(t)
        t["started_at"] = datetime.now().isoformat(timespec="seconds")
        t["t1"] = time.time()
        _current = t
    # Serit alindi, is HENUZ baslamadi: onceki turden kalan bellek burada birakilir.
    _tur_degisti(kind)
    try:
        yield t
    finally:
        with _cv:
            t["finished_at"] = datetime.now().isoformat(timespec="seconds")
            t["seconds"] = round(time.time() - t["t1"], 1)
            _history.append(t)
            del _history[:-30]
            _current = None
            _cv.notify_all()


def status() -> dict:
    with _cv:
        cur = dict(_current) if _current else None
        if cur:
            cur["running_seconds"] = round(time.time() - cur["t1"], 1)
        return {"running": cur,
                "waiting": [{k: v for k, v in w.items() if k != "t0"} | {"waited_seconds": round(time.time() - w["t0"], 1)}
                            for w in _waiting],
                "recent": [{k: v for k, v in h.items() if k not in ("t0", "t1")} for h in reversed(_history)]}


def enqueue_position(ticket_id: str) -> int:
    """#299: biletin siradaki yeri - 0 calisiyor, 1.. bekliyor, -1 yok."""
    with _cv:
        if _current is not None and _current["id"] == ticket_id:
            return 0
        for i, w in enumerate(_waiting, 1):
            if w["id"] == ticket_id:
                return i
    return -1


def busy() -> bool:
    with _cv:
        return _current is not None or bool(_waiting)
