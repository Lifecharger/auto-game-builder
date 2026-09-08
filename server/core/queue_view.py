r"""#299: TEK Sira gorunumu - "istisnasiz her is siraya girer".

Telefondaki Sira ekrani bugune kadar iki ayri yere bakiyordu: comfy_gen'in
uretim kuyrugu (`/api/generate/queue`) ve ekran karti seridi (`/api/gpu/queue`).
Yon uretimi gibi ComfyUI'ye dogrudan is birakan akislar ikisinde de gorunmuyor,
kullanici "sira bos" yaziyorken 14 gorselin bitmesini bekliyordu.

Bu modul ucunu tek bir cerceveden verir:

  * calisan / bekleyen GPU seridi biletleri (gpu_lane) - her bilet artik
    op_id / job_id tasir, ilerleme (done/total/message) op defterinden
    eslestirilir,
  * comfy_gen kuyrugunda BEKLEYEN isler (calisan is zaten seridi tuttugu icin
    ustteki "running" biletidir).

Disk taramasi yok: her sey bellekteki kayitlardan okunur.
"""
from __future__ import annotations


def _op_progress(op_id: str) -> dict | None:
    """Op defterinden ilerleme. Uc akis (jigsaw/cbn/karakter) AYNI defteri
    kullanir; yine de her birine sirayla soruluyor ki biri yuklenemese bile
    diger ikisi calissin."""
    if not op_id:
        return None
    import importlib
    for mod in ("jigsaw_flow", "cbn_flow", "character_flow"):
        try:
            m = importlib.import_module("." + mod, __package__)
            o = m.op_status(op_id)
        except Exception:
            o = None
        if o:
            return {"id": o.get("id"), "kind": o.get("kind"), "status": o.get("status"),
                    "done": o.get("done"), "total": o.get("total"),
                    "ok": o.get("ok"), "failed": o.get("failed"),
                    "message": o.get("message") or ""}
    return None


def _job_card(job_id: str) -> dict | None:
    """Calisan comfy_gen isinin kisa karti (kuyruk kartinda gosterilir)."""
    if not job_id:
        return None
    try:
        from . import comfy_gen as G
        j = G.get_job(job_id)
    except Exception:
        return None
    if not j:
        return None
    return {k: j.get(k) for k in ("id", "task", "mode", "category", "client",
                                  "status", "progress", "node", "is_video")}


def _bilet(t: dict) -> dict:
    """Serit biletine op ilerlemesini (ve varsa is kartini) ekler."""
    b = {k: v for k, v in t.items() if k not in ("t0", "t1")}   # ham zaman damgalari gitsin
    b["op"] = _op_progress(b.get("op_id") or "")
    b["job"] = _job_card(b.get("job_id") or "")
    # Istemci (QueueTicket.fromJson) done/total/message'i biletin KOKUNDE
    # okur; op varsa oradan duzlestir, yoksa hold(total=...) degeri kalsin.
    if b["op"]:
        for k in ("done", "total", "message"):
            if b["op"].get(k) not in (None, ""):
                b[k] = b["op"][k]
    elif b["job"]:
        b.setdefault("message", "%s %s" % (b["job"].get("task") or "", b["job"].get("category") or "")).strip()
    return b


def snapshot() -> dict:
    """GET /api/queue govdesi."""
    from . import comfy_gen as G
    from . import gpu_lane

    st = gpu_lane.status()
    running = _bilet(st["running"]) if st.get("running") else None
    waiting = [_bilet(w) for w in (st.get("waiting") or [])]
    try:
        pending = (G.queue_state() or {}).get("pending") or []
    except Exception:
        pending = []
    return {
        "running": running,
        "waiting": waiting,
        "comfy_pending": pending,
        "depth": len(waiting) + len(pending) + (1 if running else 0),
        "recent": st.get("recent") or [],
    }
