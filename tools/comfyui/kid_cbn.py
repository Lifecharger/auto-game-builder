"""Kid CBN — the single-colour-per-region Color-By-Number flow (named 2026-09-07).

prompt -> flat image -> vision model lists the things in it -> SAM3 segments
-> regions. Every region takes exactly ONE flat colour, so it suits children
and any picture drawn in a flat style; the adult flow with a different end
result is a separate, later design.

Pipeline (all local, ComfyUI does the GPU work through its single queue):

  1. generate  Z-Image-Turbo renders a flat, thick-outline illustration from the
               subject prompt (profile "hot" or "kid"; square / portrait / landscape).
  2. segment   SAM 3.1 (text-prompted) returns one mask per *thing* — hair, face,
               dress, tree, cloud... — so regions follow meaning, not just colour.
  3. build     inside every segment the colours are clustered, connected areas
               become regions, specks are merged into their neighbours, a palette
               is fitted, adjacent same-colour regions fuse, lines are the borders.
  4. write     <out>/<slug>/  00_source.png · 01_segments.png · 02_regions.png
               (24-bit region id) · 03_preview.png · 04_numbered.png · 05_lineart.png ·
               asset.svg (one <path data-c> per region, fill-opacity 0) · asset.json
               (palette, regions, label points, metrics).

    python kid_cbn.py --subject "a friendly unicorn under a rainbow" --profile kid --aspect square
    python kid_cbn.py --source some.png --profile hot            # skip generation
    python kid_cbn.py --matrix                                    # the 6-asset test set

Paths come from AGB's settings.json (comfyui.*, jigsaw.pool_root) / env vars,
never from this file — the repo is public.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
AGB_ROOT = HERE.parent.parent
SETTINGS = AGB_ROOT / "server" / "config" / "settings.json"


def _setting(key: str, env: str, default: str = "") -> str:
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


COMFY_ROOT = Path(_setting("comfyui.root", "COMFYUI_ROOT"))
COMFY_URL = _setting("comfyui.url", "COMFYUI_URL", "http://127.0.0.1:8188").rstrip("/")
COMFY_IN, COMFY_OUT = COMFY_ROOT / "input", COMFY_ROOT / "output"
WORKFLOWS = COMFY_ROOT / "user" / "default" / "workflows"
POOL_ROOT = Path(_setting("jigsaw.pool_root", "JIGSAW_POOL_ROOT"))
OUT_ROOT = Path(_setting("kid_cbn.root", "KID_CBN_ROOT",
                         str(POOL_ROOT.parent / "Kid CBN" / "_proto") if str(POOL_ROOT) != "." else ""))

SAM_CKPT = "sam3.1_multiplex_fp16.safetensors"
GEN_WORKFLOW = "Image Z Turbo.json"

SIZES = {"square": (1024, 1024), "portrait": (832, 1216), "landscape": (1216, 832)}

# --------------------------------------------------------------- profiles
# The prompt only asks for the *style*; what makes the result a CBN asset is the
# measurement below (region count, speck ratio) — a render that fails it is
# rejected, however pretty it is.
STYLE = {
    "hot": ("{}, flat vector illustration in coloring-book style, thick uniform "
            "black outlines around every shape, large simple shapes, solid flat "
            "colors, no gradients, no shading, no texture, clean edges, limited "
            "palette of 14 colors, simple background made of a few large shapes"),
    "kid": ("{}, cute children's coloring-book illustration, flat vector art, bold "
            "thick black outlines, big simple rounded shapes, solid flat colors, no "
            "gradients, no shading, no texture, cheerful, simple background made of "
            "a few large shapes"),
}
# What SAM is asked to find, fine things first: a pixel claimed by "eyes" is
# never handed to "face", a pixel claimed by "face" never to "hair", and so on.
# The subject's own nouns are prepended at run time.
CONCEPTS = {
    "hot": ["eyes", "lips", "eyebrows", "teeth", "earring", "necklace", "bracelet",
            "hand", "face", "hat", "sunglasses", "hair", "shoes", "bag", "belt",
            "arm", "leg", "skin", "dress", "top", "skirt", "pants", "jacket", "clothing",
            "flower", "chair", "table", "umbrella", "cup", "car", "window", "door",
            "wall", "tree", "building", "water", "sand", "grass", "cloud", "sky"],
    "kid": ["eyes", "nose", "mouth", "face", "ear", "horn", "wing", "tail", "hoof",
            "paw", "mane", "hat", "helmet", "animal", "cat", "dog", "bird", "fish",
            "cow", "unicorn", "flower", "leaf", "mushroom", "balloon", "star", "moon",
            "sun", "rainbow", "cloud", "planet", "rocket", "car", "tractor", "wheel",
            "boat", "house", "barn", "roof", "window", "door", "fence", "tree", "bush",
            "rock", "mountain", "water", "grass", "field", "road", "sky"],
}
PALETTE_TARGET = {"hot": 16, "kid": 12}
MIN_REGION_FRAC = 0.0006          # below this share of the image a region is a speck
MIN_REGION_PX = 140
# Inside one SAM segment only a change of HUE/CHROMA makes a new region; a change
# of lightness alone (the shaded half of a white ball) does not — the ball is one
# region and the shadow is painted over when its number is filled. L is
# down-weighted in the clustering, and clusters closer than AB_MERGE in a/b fuse.
L_WEIGHT = 0.25
AB_MERGE = 11.0
LABEL_MIN_PX = 900                # regions smaller than this get no number in the template
GOOD_REGIONS = (30, 320)          # prototype acceptance window
GOOD_COLORS = (8, 24)

MATRIX = [
    ("hot", "portrait", "beautiful adult woman with long wavy hair in an elegant red evening dress standing on a balcony at sunset"),
    ("hot", "square", "glamorous adult woman with a bob haircut, sunglasses and a wide summer hat at a beach cafe"),
    ("hot", "landscape", "elegant adult woman in a flowing blue gown walking through a rose garden"),
    ("kid", "square", "a friendly unicorn under a rainbow with clouds and flowers"),
    ("kid", "landscape", "a red tractor on a farm with a barn, a cow and a sunflower field"),
    ("kid", "portrait", "a smiling astronaut cat floating among planets and stars"),
]


# ---------------------------------------------------------------- comfyui
def _post(path: str, payload: dict) -> dict:
    req = urllib.request.Request(COMFY_URL + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=180).read())


def _get(path: str) -> dict:
    return json.loads(urllib.request.urlopen(COMFY_URL + path, timeout=180).read())


def comfy_run(graph: dict, timeout: int = 1800) -> dict:
    """Queue an API graph and return its history entry (outputs) once done."""
    try:
        pid = _post("/prompt", {"prompt": graph, "client_id": "cbn-" + uuid.uuid4().hex[:8]})["prompt_id"]
    except urllib.error.HTTPError as e:
        raise RuntimeError("comfy refused the graph: " + e.read().decode(errors="replace")[:600])
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(2)
        try:
            hist = _get("/history/" + pid)
        except Exception:
            continue
        if pid not in hist:
            continue
        st = hist[pid].get("status", {})
        if st.get("status_str") == "error":
            msgs = [m for m in st.get("messages", []) if m and m[0] == "execution_error"]
            raise RuntimeError("comfy error: " + json.dumps(msgs, ensure_ascii=False)[:600])
        return hist[pid]
    raise RuntimeError("comfy timed out")


def _saved_files(hist: dict, key: str = "images") -> list[Path]:
    files: list[Path] = []
    for _n, o in hist.get("outputs", {}).items():
        for f in o.get(key, []) or []:
            if f.get("type") == "output":
                files.append(COMFY_OUT / f.get("subfolder", "") / f["filename"])
    return files


def _converter():
    scripts = str(COMFY_ROOT / "scripts")
    if scripts not in sys.path:
        sys.path.insert(0, scripts)
    from wf2api import convert  # noqa: WPS433 — lives beside ComfyUI
    return convert


def generate(subject: str, profile: str, aspect: str, dest: Path, seed: int | None = None) -> Path:
    """Z-Image-Turbo through the studio's own workflow file; returns the PNG."""
    w, h = SIZES[aspect]
    prompt = STYLE[profile].format(subject)
    wf = json.loads((WORKFLOWS / GEN_WORKFLOW).read_text(encoding="utf-8"))
    seed = seed if seed is not None else random.randint(1, 2 ** 31)
    graph = _converter()(wf, {"prompt": prompt, "text": prompt, "width": w, "height": h,
                              "seed": seed, "noise_seed": seed})
    for n in graph.values():
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "kid_cbn/gen"
    print(f"  generating {w}x{h} (seed {seed}) ...", flush=True)
    t0 = time.time()
    files = _saved_files(comfy_run(graph))
    if not files:
        raise RuntimeError("generation produced no image")
    shutil.copy(files[-1], dest)
    print(f"  image in {time.time() - t0:.0f}s -> {dest.name}")
    return dest


def segment(image: Path, concepts: list[str], threshold: float = 0.45) -> list[tuple[str, np.ndarray, float]]:
    """SAM 3.1 text-prompted masks, one queued prompt per concept (a concept SAM
    does not find yields an empty batch, which would abort a shared graph). All
    prompts are queued at once; ComfyUI runs them back to back with the model
    cached. Returns (concept, bool mask, area share) in the order given — that
    order is the claim priority downstream."""
    name = f"cbn_{uuid.uuid4().hex[:8]}{image.suffix}"
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    shutil.copy(image, COMFY_IN / name)
    print(f"  segmenting with {len(concepts)} concepts ...", flush=True)
    t0 = time.time()
    pids: list[tuple[str, str]] = []
    for i, c in enumerate(concepts):
        g = {
            "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": SAM_CKPT}},
            "2": {"class_type": "LoadImage", "inputs": {"image": name}},
            "3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": c}},
            "4": {"class_type": "SAM3_Detect", "inputs": {
                "model": ["1", 0], "image": ["2", 0], "conditioning": ["3", 0],
                "threshold": threshold, "refine_iterations": 2, "individual_masks": True}},
            "5": {"class_type": "MaskToImage", "inputs": {"mask": ["4", 0]}},
            "6": {"class_type": "SaveImage", "inputs": {
                "images": ["5", 0], "filename_prefix": f"kid_cbn/sam/{i:02d}_{re.sub(r'[^a-z]', '_', c)}"}},
        }
        try:
            pids.append((c, _post("/prompt", {"prompt": g, "client_id": "cbn-sam"})["prompt_id"]))
        except urllib.error.HTTPError as e:
            raise RuntimeError("comfy refused the SAM graph: " + e.read().decode(errors="replace")[:400])
    out: list[tuple[str, np.ndarray, float]] = []
    pending = dict(pids)
    deadline = time.time() + 900
    while pending and time.time() < deadline:
        time.sleep(1.0)
        for c, pid in list(pending.items()):
            try:
                hist = _get("/history/" + pid)
            except Exception:
                continue
            if pid not in hist:
                continue
            del pending[c]
            h = hist[pid]
            if h.get("status", {}).get("status_str") == "error":
                continue                      # nothing found for this concept
            for f in _saved_files(h):
                m = cv2.imread(str(f), cv2.IMREAD_GRAYSCALE)
                if m is None:
                    continue
                mask = m > 127
                share = float(mask.mean())
                if 0.0005 < share < 0.97:     # empty and "whole image" hits are noise
                    out.append((c, mask, share))
    out.sort(key=lambda t: concepts.index(t[0]))
    print(f"  {len(out)} masks in {time.time() - t0:.0f}s: "
          + ", ".join(f"{c}:{s:.0%}" for c, _m, s in out[:16]) + (" ..." if len(out) > 16 else ""))
    return out


# ------------------------------------------------------- object discovery
DISCOVER_PROMPT = (
    "Read the image file at {path} with the Read tool and look at it carefully. "
    "It will become a color-by-number picture, so I need the list of THINGS in it "
    "that a child would color as separate areas. Return ONLY a JSON array of short "
    "lowercase English nouns (1-2 words each), no prose: every distinct visible "
    "object, body part, garment, accessory and background element, ordered from the "
    "smallest and finest (eyes, mouth, buttons) to the largest (dress, tree, sky, "
    "ground). Use plain generic words SAM can find (\"hair\", \"dress\", \"cloud\", "
    "\"sunflower\"), one entry per kind of thing, at most 40 entries."
)


OLLAMA_URL = (os.environ.get("OLLAMA_URL", "") or _setting("ollama.url", "OLLAMA_URL_", "http://127.0.0.1:11434")).rstrip("/")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "") or _setting("ollama.model", "OLLAMA_MODEL_", "gemma3:12b")
DISCOVER_PROMPT_VLM = (
    "Look at the attached picture. It will become a color-by-number page, so list the THINGS "
    "in it that would be colored as separate areas. Return ONLY a JSON object {\"things\": [...]} "
    "with short lowercase English nouns (1-2 words each): every distinct visible object, body "
    "part, garment, accessory and background element, ordered from the smallest and finest "
    "(eyes, mouth, buttons) to the largest (dress, tree, sky, ground). Plain generic words "
    "(\"hair\", \"dress\", \"cloud\"), one entry per kind of thing, at most 40 entries.")


def ollama_ready(timeout: float = 2.0) -> bool:
    try:
        urllib.request.urlopen(OLLAMA_URL + "/api/tags", timeout=timeout).read()
        return True
    except Exception:
        return False


def ollama_unload() -> None:
    try:
        req = urllib.request.Request(OLLAMA_URL + "/api/generate",
                                     data=json.dumps({"model": OLLAMA_MODEL, "keep_alive": 0}).encode(),
                                     headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=30).read()
    except Exception:
        pass


def _discover_ollama(image: Path, timeout: int = 180) -> list[str]:
    """Local VLM object list (Ollama). Empty on failure."""
    import base64
    import io
    from PIL import Image
    with Image.open(image) as im:
        im = im.convert("RGB")
        w, h = im.size
        s = 1024 / float(max(w, h))
        if s < 1:
            im = im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
    body = {"model": OLLAMA_MODEL, "stream": False, "format": "json", "keep_alive": "5m",
            "options": {"temperature": 0.2, "num_predict": 600},
            "messages": [{"role": "user", "content": DISCOVER_PROMPT_VLM,
                          "images": [base64.b64encode(buf.getvalue()).decode()]}]}
    try:
        req = urllib.request.Request(OLLAMA_URL + "/api/chat", data=json.dumps(body).encode(),
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            text = (json.loads(resp.read().decode("utf-8")).get("message") or {}).get("content") or ""
        obj = json.loads(text)
    except Exception as e:
        print(f"  ollama discover failed: {e}")
        return []
    arr = obj.get("things") if isinstance(obj, dict) else obj
    out = []
    for x in arr or []:
        w = re.sub(r"[^a-z ]", "", str(x).lower()).strip()
        if w and w not in out:
            out.append(w)
    return out[:40]


def discover_concepts(image: Path, timeout: int = 180) -> list[str]:
    """Ask a vision model what is IN the picture, the way r2manager's EXIF tagger
    does, and hand those nouns to SAM — an object finder instead of a fixed
    guess list. Local Ollama VLM first (free, offline); the Claude CLI headless
    (Opus, subscription quota) only as fallback. Empty list on any failure — the
    caller falls back to the profile list."""
    if ollama_ready():
        found = _discover_ollama(image, timeout)
        if found:
            return found
    exe = shutil.which("claude.cmd") or shutil.which("claude")
    if not exe:
        return []
    try:
        proc = subprocess.run(
            [exe, "-p", "--model", "opus", "--output-format", "json",
             "--permission-mode", "bypassPermissions", "--add-dir", str(image.parent)],
            input=DISCOVER_PROMPT.format(path=str(image.resolve())),
            capture_output=True, text=True, timeout=timeout, cwd=str(image.parent),
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except Exception as e:
        print(f"  discover: {e}")
        return []
    text = proc.stdout or ""
    try:
        wrapper = json.loads(text)
        if isinstance(wrapper, dict):
            text = str(wrapper.get("result") or wrapper.get("response") or text)
    except json.JSONDecodeError:
        pass
    m = re.search(r"\[[^\[\]]*\]", text, re.S)
    if not m:
        return []
    try:
        arr = json.loads(m.group(0))
    except json.JSONDecodeError:
        return []
    out = []
    for x in arr:
        w = re.sub(r"[^a-z ]", "", str(x).lower()).strip()
        if w and w not in out:
            out.append(w)
    return out[:40]


# ---------------------------------------------------------------- building
def order_masks_by_center(masks, H: int, W: int):
    """Claim order = distance of the mask's centre of mass to the image centre,
    nearest first (the user's "centre pivot" rule): the subject in the middle
    wins overlaps, background things lose. Ties broken by size (smaller first
    so eyes beat faces beat hair)."""
    cy, cx = H / 2.0, W / 2.0
    diag = (H * H + W * W) ** 0.5
    keep = []
    for t in masks:
        # a "thing" covering more than half the picture is a SAM hallucination
        # (house 96%, road 56% on a unicorn...) unless it is a backdrop word
        if t[2] > 0.5 and t[0] not in BACKDROP_WORDS:
            continue
        keep.append(t)
    def key(t):
        ys, xs = np.where(t[1])
        if len(ys) == 0:
            return (99, 0)
        dist = ((ys.mean() - cy) ** 2 + (xs.mean() - cx) ** 2) ** 0.5
        # backdrops (sky, ground, background...) always LAST whatever their
        # centre; other things by distance in 10%-of-diagonal buckets, and
        # inside a bucket smaller first, so the eyes are claimed before the face
        return (1 if t[0] in BACKDROP_WORDS else 0, int(dist / (0.1 * diag)), len(ys))
    return sorted(keep, key=key)


BACKDROP_WORDS = ("background", "sky", "ground", "floor", "wall", "grass", "field", "sand",
                  "water", "sea", "ocean", "road", "table", "bed", "sheet", "backdrop")


def save_masks(path, masks) -> None:
    """masks.npz: names, shares, m0..mN (bool). Stage output of the SAM step."""
    arrays = {"names": np.array([m[0] for m in masks], dtype=object),
              "shares": np.array([m[2] for m in masks], dtype=np.float32)}
    for i, m in enumerate(masks):
        arrays["m%d" % i] = np.packbits(m[1].astype(np.uint8), axis=None)
    if masks:
        arrays["shape"] = np.array(masks[0][1].shape)
    np.savez_compressed(str(path), **arrays)


def load_masks(path):
    z = np.load(str(path), allow_pickle=True)
    names = list(z["names"])
    if not names:
        return []
    shape = tuple(int(x) for x in z["shape"])
    out = []
    for i, n in enumerate(names):
        m = np.unpackbits(z["m%d" % i])[: shape[0] * shape[1]].reshape(shape).astype(bool)
        out.append((str(n), m, float(z["shares"][i])))
    return out


def mask_names(path) -> list[str]:
    """#318: masks.npz icindeki kavram adlari - maskeleri acmadan (on izleme
    icin ucuz sayim)."""
    z = np.load(str(path), allow_pickle=True)
    return [str(n) for n in list(z["names"])]


def masks_to_seg(masks, H: int, W: int):
    """#318: SAM maskeleri -> bolum haritasi. build()'in 1. adimiyla AYNI talep
    sirasi (merkez once, zeminler sonra) ve ayni acma/eleme kurallari - Gelen
    on izlemesinde gorunen bolumler insa sonucuyla ortusur."""
    min_px = max(MIN_REGION_PX, int(H * W * MIN_REGION_FRAC))
    seg = np.full((H, W), -1, dtype=np.int32)
    names: list[str] = []
    for concept, mask, _s in order_masks_by_center(masks, H, W):
        m = mask & (seg == -1)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
        if m.sum() < min_px:
            continue
        seg[m] = len(names)
        names.append(concept)
    rest = seg == -1
    if rest.any():
        seg[rest] = len(names)
        names.append("rest")
    return seg, names


def segments_overlay(img_bgr: np.ndarray, seg: np.ndarray, seg_names: list[str],
                     seed: int = 7, scale: float = 0.55, borders: bool = False) -> np.ndarray:
    """#318: bolum kaplamasi - kaynak uzerine yari saydam renk + bolum adi.
    write_asset (kid + hot) ve Gelen on izlemesi ayni goruntuyu uretir."""
    cols = np.random.default_rng(seed).integers(40, 230, size=(max(1, len(seg_names)), 3)).astype(np.uint8)
    over = (img_bgr * 0.35 + cols[seg] * 0.65).astype(np.uint8)
    if borders:
        # ince sinir: komsusu farkli bolum olan pikseller
        b = np.zeros(seg.shape, bool)
        b[:, :-1] |= seg[:, :-1] != seg[:, 1:]
        b[:-1, :] |= seg[:-1, :] != seg[1:, :]
        k = max(1, int(round(min(seg.shape) / 700.0)))
        if k > 1:
            b = cv2.dilate(b.astype(np.uint8), np.ones((k, k), np.uint8)).astype(bool)
        over[b] = 20
    for s, name in enumerate(seg_names):
        ys, xs = np.where(seg == s)
        if len(ys):
            cv2.putText(over, name, (int(xs.mean()) - 20, int(ys.mean())), cv2.FONT_HERSHEY_SIMPLEX, scale, (0, 0, 0), 3)
            cv2.putText(over, name, (int(xs.mean()) - 20, int(ys.mean())), cv2.FONT_HERSHEY_SIMPLEX, scale, (255, 255, 255), 1)
    return over


def palette_by_object(labels: np.ndarray, seg: np.ndarray, lab_img: np.ndarray, line: np.ndarray,
                      per_object_k: int, max_colors: int, merge_de: float):
    """Numbers per OBJECT: every semantic segment (in claim order = centre-first)
    clusters its own region colours and gets its own run of palette numbers;
    the background ("rest", last segment) comes last. A global cap merges the
    closest pairs across objects only if there are too many colours.

    Returns (cen_lab [K,3], color_of [n_regions], owner [K] segment index)."""
    n = labels.max() + 1
    keep = (~line).ravel().astype(np.float32)
    kept = np.bincount(labels.ravel(), weights=keep, minlength=n)
    means = np.zeros((n, 3), np.float32)
    for c in range(3):
        means[:, c] = np.bincount(labels.ravel(), weights=lab_img[..., c].ravel() * keep, minlength=n) / np.maximum(kept, 1)
    means[kept == 0] = np.array([20, 128, 128], np.float32)
    counts = np.bincount(labels.ravel(), minlength=n).astype(np.float32)
    # which segment owns each region (majority)
    reg_seg = np.zeros(n, dtype=np.int32)
    for r in range(n):
        vals = seg[labels == r]
        reg_seg[r] = np.bincount(vals).argmax() if vals.size else 0
    centers, owner, color_of = [], [], np.zeros(n, dtype=np.int32)
    for s in range(int(seg.max()) + 1):
        regs = np.where(reg_seg == s)[0]
        if len(regs) == 0:
            continue
        pts = means[regs]
        k = min(per_object_k, len(regs))
        if k > 1:
            rep = np.clip((np.sqrt(counts[regs]) / np.sqrt(counts[regs]).max() * 8).astype(int), 1, 8)
            _l, cen = _kmeans(np.repeat(pts, rep, axis=0), k, attempts=4)
        else:
            cen = pts.mean(axis=0, keepdims=True)
        # dedupe inside the object
        kept_c = []
        for c in cen:
            if all(_delta_e(c, kc) >= merge_de for kc in kept_c):
                kept_c.append(c)
        base = len(centers)
        d = np.linalg.norm(pts[:, None, :] - np.array(kept_c)[None, :, :], axis=2)
        color_of[regs] = base + np.argmin(d, axis=1)
        centers.extend(kept_c)
        owner.extend([s] * len(kept_c))
    cen = np.array(centers, np.float32)
    owner = np.array(owner)
    # global cap: merge the closest pair until under the limit
    while len(cen) > max_colors:
        d = np.linalg.norm(cen[:, None, :] - cen[None, :, :], axis=2)
        np.fill_diagonal(d, np.inf)
        i, j = np.unravel_index(np.argmin(d), d.shape)
        a, b = min(i, j), max(i, j)
        cen[a] = (cen[a] + cen[b]) / 2
        color_of[color_of == b] = a
        color_of[color_of > b] -= 1
        cen = np.delete(cen, b, axis=0)
        owner = np.delete(owner, b)
    return cen, color_of, owner


def _kmeans(samples: np.ndarray, k: int, attempts: int = 3) -> tuple[np.ndarray, np.ndarray]:
    crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5)
    _c, lbl, cen = cv2.kmeans(samples.astype(np.float32), k, None, crit, attempts, cv2.KMEANS_PP_CENTERS)
    return lbl.ravel(), cen


def _merge_small(labels: np.ndarray, min_px: int, lab_img: np.ndarray, rounds: int = 6) -> np.ndarray:
    """Fold regions smaller than min_px into the neighbour that shares the most
    border (ties -> closest colour). Works on bounding boxes so thousands of
    specks stay cheap."""
    for _ in range(rounds):
        _n, lab = _relabel(labels)
        areas = np.bincount(lab.ravel())
        small = [i for i in range(len(areas)) if 0 < areas[i] < min_px]
        if not small:
            return lab
        # colour per label for tie-breaking
        H, W = lab.shape
        for i in small:
            ys, xs = np.where(lab == i)
            if len(ys) == 0:
                continue
            y0, y1 = max(ys.min() - 1, 0), min(ys.max() + 2, H)
            x0, x1 = max(xs.min() - 1, 0), min(xs.max() + 2, W)
            win = lab[y0:y1, x0:x1]
            me = win == i
            ring = cv2.dilate(me.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & ~me
            neigh = win[ring]
            neigh = neigh[neigh != i]
            if len(neigh) == 0:
                continue
            cand, cnt = np.unique(neigh, return_counts=True)
            best = cand[np.argmax(cnt)]
            lab[y0:y1, x0:x1][me] = best
        labels = lab
    return _relabel(labels)[1]


def _relabel(labels: np.ndarray):
    """Connected components over an arbitrary label image -> (count, labels)."""
    # cv2.connectedComponents needs a binary image per value; do it per value.
    out = np.zeros_like(labels, dtype=np.int32)
    nxt = 0
    for v in np.unique(labels):
        n, cc = cv2.connectedComponents((labels == v).astype(np.uint8), connectivity=4)
        cc = cc.astype(np.int32)
        m = cc > 0
        out[m] = cc[m] + nxt
        nxt += n - 1
    # make labels dense 0..N-1
    _u, inv = np.unique(out, return_inverse=True)
    return len(_u), inv.reshape(out.shape).astype(np.int32)


def _delta_e(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm(a.astype(np.float32) - b.astype(np.float32)))


def build(img_bgr: np.ndarray, masks: list[tuple[str, np.ndarray, float]], profile: str) -> dict:
    """Image + SAM masks -> region label map, palette, per-region colour ids."""
    H, W = img_bgr.shape[:2]
    area = H * W
    min_px = max(MIN_REGION_PX, int(area * MIN_REGION_FRAC))
    smooth = cv2.bilateralFilter(img_bgr, 9, 40, 9)
    lab_img = cv2.cvtColor(smooth, cv2.COLOR_BGR2LAB)

    # The render's own black outlines are LINES, not things to colour: thin dark
    # low-chroma strokes are lifted out before clustering and handed to the
    # nearest region at the end. Thick dark blobs (an eye, a black shoe) survive
    # the opening and stay regions with a black palette entry.
    chroma = np.hypot(lab_img[..., 1].astype(np.float32) - 128, lab_img[..., 2].astype(np.float32) - 128)
    dark = ((lab_img[..., 0] < 70) & (chroma < 28)).astype(np.uint8)
    # A dark component is a blob (kept) only if something round fits inside it:
    # its largest inscribed radius must beat the stroke half-width. A 14 px
    # rainbow outline has radius 7 and is a line; a 22 px eye has 11 and stays.
    k = max(7, int(0.012 * min(H, W))) | 1
    dist = cv2.distanceTransform(dark, cv2.DIST_L2, 5)
    ncomp, comp = cv2.connectedComponents(dark, connectivity=8)
    maxr = np.zeros(ncomp, np.float32)
    np.maximum.at(maxr, comp.ravel(), dist.ravel())
    blobs = (maxr[comp] > 0.62 * k).astype(np.uint8) * dark
    line = (dark > 0) & (blobs == 0)

    # 1) semantic segments by claim priority; leftover pixels form the "rest"
    seg = np.full((H, W), -1, dtype=np.int32)
    seg_names: list[str] = []
    for concept, mask, _s in order_masks_by_center(masks, H, W):
        m = mask & (seg == -1)
        m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
        if m.sum() < min_px:
            continue
        seg[m] = len(seg_names)
        seg_names.append(concept)
    rest = seg == -1
    if rest.any():
        seg[rest] = len(seg_names)
        seg_names.append("rest")

    # 2) colour clusters inside each segment -> provisional regions
    prov = np.zeros((H, W), dtype=np.int32)
    nxt = 0
    feat_img = lab_img.astype(np.float32).copy()
    feat_img[..., 0] *= L_WEIGHT
    blob = blobs > 0
    for s in range(len(seg_names)):
        m = (seg == s) & ~line & ~blob
        px = feat_img[m]
        share = px.shape[0] / area
        k = 1 if share < 0.004 else 3 if share < 0.02 else 6 if share < 0.1 else 8
        if k > 1 and px.shape[0] > 50:
            lbl, cen = _kmeans(px, k)
            # fuse clusters that differ only in lightness (shading), keep hue splits
            owner = list(range(k))
            for i in range(k):
                for j in range(i):
                    if owner[j] == j and owner[i] == i and                             float(np.linalg.norm(cen[i][1:] - cen[j][1:])) < AB_MERGE:
                        owner[i] = j
                        break
            lbl = np.array([owner[v] for v in range(k)])[lbl]
            prov[m] = nxt + lbl
        else:
            prov[m] = nxt
        nxt += k
        mb = (seg == s) & blob                 # black eye on a white face stays a region
        if mb.any():
            prov[mb] = nxt
            nxt += 1
    # line pixels take the label of the nearest coloured pixel
    if line.any():
        _d, idx = cv2.distanceTransformWithLabels((line).astype(np.uint8), cv2.DIST_L2, 3, labelType=cv2.DIST_LABEL_PIXEL)
        flat_ids = np.zeros(idx.max() + 1, dtype=np.int32)
        ys, xs = np.where(~line)
        flat_ids[idx[~line]] = prov[~line]
        prov = np.where(line, flat_ids[idx], prov)
    # majority-vote smoothing kills salt-and-pepper before component labelling
    prov = cv2.medianBlur(prov.astype(np.uint16), 5).astype(np.int32)

    # 3) connected regions, specks folded into neighbours
    labels = _merge_small(prov, min_px, lab_img)

    # 4) palette PER OBJECT (centre-first order, background last), then fuse
    #    touching same-colour regions inside one object
    n = labels.max() + 1
    cen, color_of, _owner = palette_by_object(labels, seg, lab_img, line, per_object_k=4,
                                              max_colors=PALETTE_TARGET[profile] * 2, merge_de=10.0)
    color_map = color_of[labels]
    # fuse touching same-colour regions ONLY inside one semantic segment — the
    # white unicorn must stay a separate region from the white sky behind it
    labels = _merge_small(color_map + (seg + 1) * 10000, min_px, lab_img)
    labels = _merge_unlined(labels, color_map, line)
    n = labels.max() + 1
    counts = np.bincount(labels.ravel(), minlength=n)
    region_color = np.zeros(n, dtype=np.int32)
    for r in range(n):
        vals = color_map[labels == r]
        region_color[r] = np.bincount(vals).argmax()

    pal_bgr = cv2.cvtColor(cen.reshape(1, -1, 3).astype(np.uint8), cv2.COLOR_LAB2BGR).reshape(-1, 3)
    palette = [f"#{b[2]:02x}{b[1]:02x}{b[0]:02x}" for b in pal_bgr]

    # 5) label points: deepest interior pixel (distance transform), not centroid
    points = []
    for r in range(n):
        m = (labels == r).astype(np.uint8)
        ys, xs = np.where(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        dt = cv2.distanceTransform(np.pad(m[y0:y1, x0:x1], 1), cv2.DIST_L2, 3)
        iy, ix = np.unravel_index(np.argmax(dt), dt.shape)
        points.append((int(x0 + ix - 1), int(y0 + iy - 1), float(dt.max())))

    metrics = {
        "regions": int(n), "colors": len(palette),
        "min_region_px": int(counts.min()), "median_region_px": int(np.median(counts)),
        "largest_region_share": round(float(counts.max()) / area, 3),
        "labeled_regions": int((counts >= LABEL_MIN_PX).sum()),
        "segments": seg_names,
    }
    metrics["verdict"] = ("pass" if GOOD_REGIONS[0] <= n <= GOOD_REGIONS[1]
                          and GOOD_COLORS[0] <= len(palette) <= GOOD_COLORS[1]
                          and metrics["largest_region_share"] < 0.6 else "fail")
    return {"labels": labels, "region_color": region_color, "palette": palette,
            "points": points, "counts": counts, "seg": seg, "seg_names": seg_names,
            "metrics": metrics}


def _merge_unlined(labels: np.ndarray, color_map: np.ndarray, line: np.ndarray) -> np.ndarray:
    """Two touching regions of the same colour with NO drawn outline along their
    shared border are the same object cut by SAM (head vs body) — merge them.
    Where the artist drew a line (cloud in front of cloud) they stay apart."""
    near_line = cv2.dilate(line.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    pairs, lined = [], []
    for a, b, nl in ((labels[:, :-1], labels[:, 1:], near_line[:, :-1] | near_line[:, 1:]),
                     (labels[:-1, :], labels[1:, :], near_line[:-1, :] | near_line[1:, :])):
        d = a != b
        lo, hi = np.minimum(a[d], b[d]), np.maximum(a[d], b[d])
        pairs.append(lo.astype(np.int64) * (labels.max() + 1) + hi)
        lined.append(nl[d])
    pairs, lined = np.concatenate(pairs), np.concatenate(lined)
    if len(pairs) == 0:
        return labels
    uniq, inv = np.unique(pairs, return_inverse=True)
    total = np.bincount(inv)
    on_line = np.bincount(inv, weights=lined.astype(np.float32))
    n = labels.max() + 1
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    rc = np.zeros(n, dtype=np.int64)
    for r in range(n):
        vals = color_map[labels == r]
        rc[r] = np.bincount(vals).argmax() if vals.size else -1
    for k, code in enumerate(uniq):
        a, b = int(code // n), int(code % n)
        if rc[a] == rc[b] and total[k] >= 12 and on_line[k] / total[k] < 0.35:
            parent[find(a)] = find(b)
    roots = np.array([find(r) for r in range(n)])
    _u, inv2 = np.unique(roots, return_inverse=True)
    return inv2[labels].astype(np.int32)


# ----------------------------------------------------------------- writing
def _border_lines(labels: np.ndarray, thick: int = 2) -> np.ndarray:
    edge = np.zeros(labels.shape, np.uint8)
    edge[:, 1:] |= (labels[:, 1:] != labels[:, :-1])
    edge[1:, :] |= (labels[1:, :] != labels[:-1, :])
    if thick > 1:
        edge = cv2.dilate(edge, np.ones((thick, thick), np.uint8))
    return edge.astype(bool)


def _svg_paths(labels: np.ndarray, region_color: np.ndarray, palette: list[str], eps: float = 0.8) -> list[str]:
    paths = []
    for r in range(labels.max() + 1):
        m = (labels == r).astype(np.uint8)
        contours, hier = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
        d = []
        for c in contours:
            if len(c) < 3:
                continue
            c = cv2.approxPolyDP(c, eps, True).reshape(-1, 2)
            if len(c) < 3:
                continue
            d.append("M" + " ".join(f"{x},{y}" for x, y in c) + "Z")
        if not d:
            continue
        cid = int(region_color[r])
        paths.append(f'<path id="r{r}" data-c="{cid + 1}" fill="{palette[cid]}" d="{"".join(d)}"/>')
    return paths


def write_asset(slug: str, img_bgr: np.ndarray, res: dict, out: Path, meta: dict) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    H, W = img_bgr.shape[:2]
    labels, rc, pal = res["labels"], res["region_color"], res["palette"]
    n = labels.max() + 1
    cv2.imwrite(str(out / "00_source.png"), img_bgr)

    # segments overlay (#318: ortak yardimci - Gelen on izlemesiyle ayni goruntu)
    over = segments_overlay(img_bgr, res["seg"], res["seg_names"], seed=7, scale=0.55)
    cv2.imwrite(str(out / "01_segments.png"), over)

    # region id map (24-bit)
    idmap = np.zeros((H, W, 3), np.uint8)
    idmap[..., 2] = (labels >> 16) & 255
    idmap[..., 1] = (labels >> 8) & 255
    idmap[..., 0] = labels & 255
    cv2.imwrite(str(out / "02_regions.png"), idmap)

    # preview (flat colours + lines) and lineart
    pal_bgr = np.array([[int(p[5:7], 16), int(p[3:5], 16), int(p[1:3], 16)] for p in pal], np.uint8)
    flat = pal_bgr[rc[labels]]
    lines = _border_lines(labels, 2)
    preview = flat.copy()
    preview[lines] = 0
    cv2.imwrite(str(out / "03_preview.png"), preview)
    lineart = np.full((H, W, 3), 255, np.uint8)
    lineart[lines] = 0
    cv2.imwrite(str(out / "05_lineart.png"), lineart)

    # numbered template
    numbered = lineart.copy()
    for r in range(n):
        if res["counts"][r] < LABEL_MIN_PX:
            continue
        x, y, depth = res["points"][r]
        scale = 0.42 if depth < 14 else 0.55 if depth < 30 else 0.7
        txt = str(int(rc[r]) + 1)
        (tw, th), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, scale, 1)
        cv2.putText(numbered, txt, (x - tw // 2, y + th // 2), cv2.FONT_HERSHEY_SIMPLEX, scale, (90, 90, 90), 1, cv2.LINE_AA)
    cv2.imwrite(str(out / "04_numbered.png"), numbered)

    # SVG: regions as paths (final colour baked in, invisible until tapped)
    paths = _svg_paths(labels, rc, pal)
    labels_svg = []
    for r in range(n):
        if res["counts"][r] < LABEL_MIN_PX:
            continue
        x, y, depth = res["points"][r]
        fs = 11 if depth < 14 else 14 if depth < 30 else 18
        labels_svg.append(f'<text x="{x}" y="{y + fs // 3}" font-size="{fs}">{int(rc[r]) + 1}</text>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">\n'
           f'<rect width="{W}" height="{H}" fill="#fff"/>\n'
           f'<g id="regions" fill-opacity="0" stroke="#111" stroke-width="1.6" stroke-linejoin="round" fill-rule="evenodd">\n'
           + "\n".join(paths) +
           f'\n</g>\n<g id="labels" font-family="Arial, sans-serif" fill="#555" text-anchor="middle" pointer-events="none">\n'
           + "\n".join(labels_svg) + "\n</g>\n</svg>\n")
    (out / "asset.svg").write_text(svg, encoding="utf-8")

    data = {
        **meta, "width": W, "height": H,
        "palette": [{"id": i + 1, "hex": p} for i, p in enumerate(pal)],
        "regions": [{"id": r, "color": int(rc[r]) + 1, "area": int(res["counts"][r]),
                     "label_at": [res["points"][r][0], res["points"][r][1]],
                     "labeled": bool(res["counts"][r] >= LABEL_MIN_PX)} for r in range(n)],
        "metrics": res["metrics"],
        "files": ["00_source.png", "01_segments.png", "02_regions.png", "03_preview.png",
                  "04_numbered.png", "05_lineart.png", "asset.svg"],
    }
    (out / "asset.json").write_text(json.dumps(data, indent=1), encoding="utf-8")
    return data


# -------------------------------------------------------------------- main
def slugify(s: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s[:48] or "asset"


def run_one(subject: str, profile: str, aspect: str, source: Path | None, seed: int | None) -> dict:
    slug = f"{profile}_{aspect}_{slugify(subject)}"
    out = OUT_ROOT / slug
    out.mkdir(parents=True, exist_ok=True)
    print(f"\n=== {slug}")
    src = out / "00_source.png"
    if source:
        img = cv2.imread(str(source))
        if img is None:
            raise RuntimeError(f"cannot read {source}")
        cv2.imwrite(str(src), img)
    elif not src.exists():
        generate(subject, profile, aspect, src, seed)
    img = cv2.imread(str(src))
    nouns = [w for w in re.findall(r"[a-z]+", subject.lower())
             if len(w) > 3 and w not in ("with", "under", "among", "adult", "beautiful", "glamorous",
                                         "elegant", "friendly", "smiling", "flowing", "standing",
                                         "walking", "floating", "wide", "long", "wavy", "evening")]
    found = discover_concepts(src)
    print(f"  vision model found {len(found)}: {', '.join(found[:20])}{' ...' if len(found) > 20 else ''}")
    concepts = list(dict.fromkeys(found + nouns + CONCEPTS[profile]))
    masks = segment(src, concepts)
    t0 = time.time()
    res = build(img, masks, profile)
    data = write_asset(slug, img, res, out, {"subject": subject, "profile": profile, "aspect": aspect})
    m = res["metrics"]
    print(f"  build {time.time() - t0:.0f}s -> {m['regions']} regions, {m['colors']} colors, "
          f"min {m['min_region_px']} px, largest {m['largest_region_share']:.0%}, "
          f"labeled {m['labeled_regions']} -> {m['verdict'].upper()}   ({out})")
    return data


def main() -> int:
    for s in (sys.stdout, sys.stderr):
        try:
            s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--subject", default="")
    ap.add_argument("--profile", choices=list(STYLE), default="kid")
    ap.add_argument("--aspect", choices=list(SIZES), default="square")
    ap.add_argument("--source", type=Path, help="use this image instead of generating")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--matrix", action="store_true", help="run the 6-asset test set")
    a = ap.parse_args()
    if not COMFY_ROOT.exists():
        print("comfyui.root is not configured"); return 1
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    jobs = MATRIX if a.matrix else [(a.profile, a.aspect, a.subject or "a friendly unicorn under a rainbow")]
    results = []
    for profile, aspect, subject in jobs:
        try:
            results.append(run_one(subject, profile, aspect, a.source, a.seed))
        except Exception as e:  # keep the batch going, report at the end
            print(f"  FAILED: {e}")
            results.append({"subject": subject, "profile": profile, "aspect": aspect, "error": str(e)[:300]})
    (OUT_ROOT / "_last_run.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    print(f"\nresults -> {OUT_ROOT / '_last_run.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
