"""Yerel ComfyUI uretim koprusu.

Telefondan gelen istek -> bu modul -> yerel ComfyUI (localhost:8188) -> cikti
dosyasi server/data/generated/ altina duser ve tunel uzerinden servis edilir.

ComfyUI kapaliysa istek reddedilir; sunucu ayaga kalkmadan is kuyruga girmez.
Isler bellekte tutulur, cikti dosyalari diskte kalir.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime

COMFY = "http://127.0.0.1:8188"
COMFY_ROOT = r"C:\ComfyUI"
COMFY_SCRIPTS = os.path.join(COMFY_ROOT, "scripts")
COMFY_IN = os.path.join(COMFY_ROOT, "input")
COMFY_OUT = os.path.join(COMFY_ROOT, "output")
WFDIR = os.path.join(COMFY_ROOT, "user", "default", "workflows")

_HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # server/
OUT_DIR = os.path.join(_HERE, "data", "generated")

MANIFEST = os.path.join(_HERE, "config", "generate_tasks.json")

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
                })
        except Exception as e:  # bozuk manifest sunucuyu dusurmesin
            print("[comfy_gen] manifest okunamadi, yedek liste kullaniliyor: %s" % e)
    if not entries:
        for key, (wf, ni, iv, size) in _FALLBACK.items():
            entries.append({"id": key, "label": key, "workflow": wf,
                            "needs_image": ni, "is_video": iv,
                            "width": size[0], "height": size[1], "duration": 5})
    # is akisi diskte yoksa gorevi gizle
    entries = [e for e in entries if os.path.isfile(os.path.join(WFDIR, e["workflow"]))]
    _manifest_cache = (mtime, entries)
    return entries


def _task(task_id: str) -> dict | None:
    return next((t for t in _load_manifest() if t["id"] == task_id), None)


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

_jobs: dict[str, dict] = {}
_lock = threading.Lock()


# ------------------------------------------------------------------ altyapi
def _convert():
    """wf2api.convert'i gec yukle - ComfyUI kurulu degilse modul yine de import edilir."""
    if COMFY_SCRIPTS not in sys.path:
        sys.path.insert(0, COMFY_SCRIPTS)
    from wf2api import convert  # noqa: WPS433
    return convert


def comfy_up(timeout: float = 2.0) -> bool:
    try:
        urllib.request.urlopen(COMFY + "/", timeout=timeout)
        return True
    except Exception:
        return False


def _post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=180).read())


def _get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(COMFY + path, timeout=180).read())


def tasks() -> list[dict]:
    """Telefonun gosterecegi gorev listesi (manifest'ten)."""
    return [{"id": t["id"], "label": t["label"], "needs_image": t["needs_image"],
             "is_video": t["is_video"], "default_width": t["width"],
             "default_height": t["height"], "default_duration": t["duration"]}
            for t in _load_manifest()]


# ------------------------------------------------------------------ isler
def _snapshot(job: dict) -> dict:
    j = {k: v for k, v in job.items() if k != "_thread"}
    if j.get("file"):
        j["file_name"] = os.path.basename(j["file"])
    return j


def get_job(job_id: str) -> dict | None:
    with _lock:
        j = _jobs.get(job_id)
        return _snapshot(j) if j else None


def list_jobs(limit: int = 30, client: str | None = None) -> list[dict]:
    """client verilirse sadece o cihazin isleri doner."""
    with _lock:
        items = sorted(_jobs.values(), key=lambda j: j["created_at"], reverse=True)
        if client:
            items = [j for j in items if j.get("client") == client]
        return [_snapshot(j) for j in items[:limit]]


def job_file(job_id: str) -> str | None:
    with _lock:
        j = _jobs.get(job_id)
    if j and j.get("file") and os.path.isfile(j["file"]):
        return j["file"]
    return None


def submit(task: str, prompt: str, *, negative: str = "", width: int = 0, height: int = 0,
           duration: int = 5, seed: int | None = None, turbo: bool = True,
           image_path: str | None = None, source_job: str | None = None,
           client: str | None = None) -> dict:
    """Yeni uretim isi kuyruga alir; job kaydini doner.

    Girdi gorseli iki yoldan gelebilir:
      * image_path  - masaustunden gelen mutlak dosya yolu
      * source_job  - daha once uretilmis bir isin id'si (telefon bunu kullanir,
                      dosya zaten sunucuda oldugu icin yukleme gerekmez)
    """
    spec = _task(task)
    if spec is None:
        raise ValueError("bilinmeyen gorev: %s" % task)
    need_img, is_vid = spec["needs_image"], spec["is_video"]

    if source_job and not image_path:
        src = job_file(source_job)
        if not src:
            raise ValueError("kaynak is bulunamadi veya ciktisi yok: %s" % source_job)
        if os.path.splitext(src)[1].lower() in (".mp4", ".webm", ".mov"):
            raise ValueError("kaynak bir video - girdi olarak gorsel gerekiyor")
        image_path = src

    if need_img and not (image_path and os.path.isfile(image_path)):
        raise ValueError("bu gorev bir girdi gorseli istiyor")
    if not comfy_up():
        raise RuntimeError("ComfyUI calismiyor (127.0.0.1:8188)")

    job_id = uuid.uuid4().hex[:12]
    job = {
        "id": job_id, "task": task, "prompt": prompt,
        "status": "queued", "created_at": datetime.now().isoformat(),
        "started_at": None, "finished_at": None, "seconds": None,
        "file": None, "error": None, "is_video": is_vid,
        "source_job": source_job,
        "client": client,          # isteyen cihaz - galeri bununla filtrelenir
    }
    with _lock:
        _jobs[job_id] = job

    args = dict(prompt=prompt, negative=negative or (NEG_VID if is_vid else NEG_IMG),
                width=width or spec["width"] or 1024, height=height or spec["height"] or 1024,
                duration=duration or spec["duration"], seed=seed, turbo=turbo, image_path=image_path)
    t = threading.Thread(target=_worker, args=(job_id, task, args), daemon=True)
    job["_thread"] = t
    t.start()
    return _snapshot(job)


def _worker(job_id: str, task: str, a: dict) -> None:
    import random
    spec = _task(task)
    wf_name, need_img, is_vid = spec["workflow"], spec["needs_image"], spec["is_video"]
    t0 = time.time()

    def upd(**kw):
        with _lock:
            _jobs[job_id].update(kw)

    upd(status="running", started_at=datetime.now().isoformat())
    try:
        convert = _convert()
        wf = json.load(open(os.path.join(WFDIR, wf_name), encoding="utf-8"))
        seed = a["seed"] if a["seed"] is not None else random.randint(1, 2 ** 31)
        ov = {"seed": seed, "noise_seed": seed, "width": a["width"], "height": a["height"]}
        if is_vid:
            ov.update({"prompt": a["prompt"], "duration": a["duration"],
                       "frame_rate": 24, "prompt_enhance": False})
        else:
            ov.update({"prompt": a["prompt"], "positive_prompt": a["prompt"],
                       "negative_prompt": a["negative"], "enable_turbo_mode": a["turbo"]})
        graph = convert(wf, ov)

        img_name = None
        if need_img:
            ext = os.path.splitext(a["image_path"])[1] or ".png"
            img_name = "agb_%s%s" % (job_id, ext)
            os.makedirs(COMFY_IN, exist_ok=True)
            shutil.copy(a["image_path"], os.path.join(COMFY_IN, img_name))
        for n in graph.values():
            ct = n["class_type"]
            if ct == "LoadImage" and img_name:
                n["inputs"]["image"] = img_name
            if ct.startswith(("SaveImage", "SaveVideo")):
                n["inputs"]["filename_prefix"] = "agb_gen"

        pid = _post("/prompt", {"prompt": graph, "client_id": "agb-" + job_id})["prompt_id"]
        upd(comfy_prompt_id=pid)

        out = None
        while time.time() - t0 < 5400:
            time.sleep(3)
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
                            os.makedirs(OUT_DIR, exist_ok=True)
                            dst = os.path.join(OUT_DIR, job_id + os.path.splitext(src)[1])
                            shutil.copy(src, dst)
                            out = dst
            break

        if not out:
            raise RuntimeError("cikti alinamadi (zaman asimi olabilir)")
        upd(status="done", file=out, finished_at=datetime.now().isoformat(),
            seconds=round(time.time() - t0, 1))
    except Exception as e:  # noqa: BLE001
        upd(status="error", error=str(e)[:500],
            finished_at=datetime.now().isoformat(), seconds=round(time.time() - t0, 1))
