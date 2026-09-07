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


def _ticket(label: str, kind: str) -> dict:
    return {"id": uuid.uuid4().hex[:8], "label": label, "kind": kind,
            "queued_at": datetime.now().isoformat(timespec="seconds"), "t0": time.time()}


@contextmanager
def hold(label: str, kind: str = "gpu"):
    """Seridi FIFO sirayla al; blok bitince birak."""
    global _current
    t = _ticket(label, kind)
    with _cv:
        _waiting.append(t)
        while _current is not None or _waiting[0] is not t:
            _cv.wait()
        _waiting.remove(t)
        t["started_at"] = datetime.now().isoformat(timespec="seconds")
        t["t1"] = time.time()
        _current = t
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


def busy() -> bool:
    with _cv:
        return _current is not None or bool(_waiting)
