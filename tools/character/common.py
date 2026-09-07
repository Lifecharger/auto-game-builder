r"""Karakter Modu araclarinin ortak zemini: ayarlar, yollar, ComfyUI istemcisi.

Depo herkese acik -> hicbir mutlak yol koda gomulmez. Sirasiyla ortam
degiskeni, `server/config/settings.json`, sonra makul varsayilan okunur
(tools/comfyui/kid_cbn.py ile ayni kalip).

Ayar anahtarlari:
  comfyui.url        ComfyUI adresi (varsayilan http://127.0.0.1:8188)
  comfyui.root       ComfyUI kok klasoru (input/ output/ user/default/workflows)
  character.root     karakter kutuphanesi (varsayilan C:/Reusable Assets/Realistic Women)
  character.blender  blender.exe
  character.isnet    isnet onnx modeli (yalniz yedek/kenar rotusu)

ComfyUI PAYLASIMLIDIR: yalniz POST /prompt ile kuyruga is birakilir; restart
yok, calisan is iptal edilmez (feedback-comfyui-shared).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent
SETTINGS = AGB_ROOT / "server" / "config" / "settings.json"


def setting(key: str, env: str = "", default: str = "") -> str:
    """settings.json'daki noktali anahtar; ortam degiskeni kazanir."""
    if env:
        v = os.environ.get(env, "").strip()
        if v:
            return v
    try:
        d = json.loads(SETTINGS.read_text(encoding="utf-8")) or {}
        for part in key.split("."):
            d = (d or {}).get(part)
        if isinstance(d, str) and d.strip():
            return d.strip()
    except Exception:
        pass
    return default


COMFY_URL = setting("comfyui.url", "COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
COMFY_ROOT = Path(setting("comfyui.root", "COMFYUI_ROOT", "C:/ComfyUI"))
COMFY_IN, COMFY_OUT = COMFY_ROOT / "input", COMFY_ROOT / "output"
WORKFLOWS = COMFY_ROOT / "user" / "default" / "workflows"

CHAR_ROOT = Path(setting("character.root", "CHARACTER_ROOT", "C:/Reusable Assets/Realistic Women"))
MIXAMO_DIR = Path(setting("character.mixamo_dir", "CHARACTER_MIXAMO_DIR",
                          str(AGB_ROOT / "tools" / "mixamo_downloader" / "animations")))
BLENDER = setting("character.blender", "BLENDER_BIN",
                  r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
ISNET = setting("character.isnet", "ISNET_MODEL",
                os.path.expanduser("~/.u2net/isnet-general-use.onnx"))

# Wan / manken is akislari
GEN_WORKFLOW = "Image Z Turbo.json"
EDIT_WORKFLOW = "Image Qwen Image.json"
SAM_CKPT = "sam3.1_multiplex_fp16.safetensors"
# Sprite buyutmesi (rev6): models/upscale_models altindaki ESRGAN modeli.
UPSCALE_MODEL = setting("character.upscale_model", "CHARACTER_UPSCALE_MODEL", "4x-UltraSharp.pth")

# 8 YON - TEK TANIM YERI (rev2). Sira sabittir: saat yonunde, karakterin
# SAGINA dogru donerek. Azimut manken kamerasinin karakterin kendi ileri
# yonune gore acisidir (mixamo_manken_render --azimuth).
# character_flow.DIRS bunu aynen disa acar; uygulama /flow/dirs_list ile alir.
DIRS = (
    ("front",       "On",         0),
    ("front_right", "On-sag",    45),
    ("right",       "Sag",       90),
    ("back_right",  "Arka-sag", 135),
    ("back",        "Arka",     180),
    ("back_left",   "Arka-sol", 225),
    ("left",        "Sol",      270),
    ("front_left",  "On-sol",   315),
)
DIR_ORDER = tuple(d[0] for d in DIRS)
DIRECTIONS = {d[0]: d[2] for d in DIRS}      # yon -> azimut
DIR_LABELS = {d[0]: d[1] for d in DIRS}

# Fon cumlesi: still ve videoda AYNI - kesim (SAM/isnet) icin duz acik gri.
BG_CLAUSE = ("plain solid flat uniform light gray seamless studio background, no floor shadow, "
             "no gradient, even soft lighting")


# ---------------------------------------------------------------- ComfyUI
def post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(COMFY_URL + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=180).read())


def get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(COMFY_URL + path, timeout=180).read())


def queue_depth() -> tuple[int, int]:
    """(calisan, bekleyen) - is birakmadan once bakilir."""
    try:
        q = get("/queue")
        return len(q.get("queue_running") or []), len(q.get("queue_pending") or [])
    except Exception:
        return 0, 0


def enqueue(graph: dict, tag: str = "char") -> str:
    try:
        return post("/prompt", {"prompt": graph, "client_id": "%s-%s" % (tag, uuid.uuid4().hex[:8])})["prompt_id"]
    except urllib.error.HTTPError as e:
        raise RuntimeError("ComfyUI grafigi reddetti: " + e.read().decode(errors="replace")[:600])


def history(pid: str) -> dict | None:
    """Bitmis isin gecmis kaydi; henuz bitmediyse None, hata olursa raise."""
    try:
        h = get("/history/" + pid)
    except Exception:
        return None
    if pid not in h:
        return None
    st = h[pid].get("status", {})
    if st.get("status_str") == "error":
        msgs = [m for m in st.get("messages", []) if m and m[0] == "execution_error"]
        raise RuntimeError("ComfyUI hatasi: " + json.dumps(msgs, ensure_ascii=False)[:600])
    return h[pid]


def wait(pid: str, timeout: int = 3600, poll: float = 2.0) -> dict:
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(poll)
        h = history(pid)
        if h is not None:
            return h
    raise RuntimeError("ComfyUI zaman asimi (%ds)" % timeout)


def run(graph: dict, tag: str = "char", timeout: int = 3600) -> dict:
    return wait(enqueue(graph, tag), timeout)


def outputs(hist: dict, keys=("images", "videos", "gifs")) -> list[Path]:
    files: list[Path] = []
    for _n, o in (hist.get("outputs") or {}).items():
        for k in keys:
            for f in o.get(k, []) or []:
                files.append(COMFY_OUT / f.get("subfolder", "") / f["filename"])
    return [f for f in files if f.is_file()]


def stage_input(src, prefix: str = "char") -> str:
    """Dosyayi ComfyUI input klasorune benzersiz adla kopyalar, adi doner."""
    src = Path(src)
    name = "%s_%s%s" % (prefix, uuid.uuid4().hex[:8], src.suffix)
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    shutil.copy(str(src), str(COMFY_IN / name))
    return name


def converter():
    """wf2api.convert - once bu paketteki kopya, yoksa ComfyUI/scripts."""
    if str(HERE) not in sys.path:
        sys.path.insert(0, str(HERE))
    from wf2api import convert  # noqa: WPS433
    return convert


# -------------------------------------------------------------------- ffmpeg
def ffmpeg(args: list[str]) -> None:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def frame_count(path) -> int:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-count_frames",
                          "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True).stdout.strip()
    try:
        return int(out.split(",")[0])
    except Exception:
        return 0
