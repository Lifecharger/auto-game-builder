"""CBN (Color-By-Number) yayin hatti - jigsaw_flow'un CBN karsiligi.

Iki derece, iki farkli varlik tipi, ayni dort akis:

  1 Uretim        comfy_gen isleri, mode="cbn" (Uretim ekrani)
  2 Gelen         <kok>\\_Incoming\\<derece>\\<is>.jpg (+ .json), EXIF etiketli
  3 Hazir         <kok>\\<Hot CBN | Kid CBN>\\<Koleksiyon>\\<n>\\  insa edilmis varlik
  4 Push edilmis  <kok>\\<... - Pushed>\\<Koleksiyon>\\<n>\\

  hot = Hot CBN  : "reveal" - sonuc bitmis golgeli resim; Qwen Edit cizgi
                   sayfasi, Opus+SAM3 bolgeler, 80 renge kadar palet, reveal mp4
  kid = Kid CBN  : her bolge tek duz renk; Opus+SAM3 bolgeler, SVG

Insa adimi tools/comfyui/kid_cbn.py ve hot_cbn.py'yi kutuphane gibi kullanir
(ComfyUI'ye dogrudan is verirler; ComfyUI istemleri zaten sirayla isler).
Uzun isler (etiket, insa, push) arka planda calisir, jigsaw_flow ile AYNI
op kayit defterini paylasir - istemci /op/{id} ile izler.

Varlik klasoru (3 ve 4. akis):
  source.jpg   kaynak (hot'ta oyunun "sonuc" resmi)
  lineart.png  cizgi sayfasi (hot: Qwen; kid: bolge sinirlari)
  regions.png  24-bit bolge id haritasi
  numbered.png numarali sablon
  preview.jpg  bitmis gorunum
  segments.jpg SAM bolumleri (inceleme icin)
  reveal.mp4   hot: cizgi -> boyama -> sonuc
  asset.svg    kid: bolge = <path data-c>, fill-opacity 0
  asset.json   palet, bolgeler, olcum
  meta.json    prompt, etiket, kaynak is
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import sys
import threading
from datetime import datetime
from pathlib import Path

from . import comfy_gen as G
from . import gpu_lane
from . import jigsaw_flow as JF
from .jigsaw_flow import _op, _op_new, _ops, _ops_lock, _run, _tag, _has_tags, _r2_put  # noqa: F401

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_TOOLS = os.path.join(_ROOT, "tools", "comfyui")
THUMB_DIR = os.path.join(G.OUT_DIR, "_cbn_thumbs")

RATINGS = [("hot", "Hot CBN"), ("kid", "Kid CBN")]
STAGES = ("incoming", "staging", "pushed")
DEFAULT_COLL = "Generic"
_ID_RE = re.compile(r"^(?:[^\\/:*?\"<>|]{1,120}/)?[^\\/:*?\"<>|]{1,120}$")

# kind -> varlik klasorundeki dosya adi
FILES = {"image": "source.jpg", "source": "source.jpg", "lineart": "lineart.png",
         "regions": "regions.png", "numbered": "numbered.png", "preview": "preview.jpg",
         "segments": "segments.jpg", "video": "reveal.mp4", "svg": "asset.svg", "lineart_svg": "lineart.svg",
         "json": "asset.json", "meta": "meta.json"}

# Insa GPU seridinden (gpu_lane) gecer: uretim, etiketleme ve muzikle ayni FIFO.


# ------------------------------------------------------------------ ayarlar
def _setting(key: str, default: str = "") -> str:
    try:
        with open(os.path.join(_ROOT, "server", "config", "settings.json"), encoding="utf-8") as fh:
            d = json.load(fh) or {}
        for part in key.split("."):
            d = (d or {}).get(part)
        if isinstance(d, str) and d.strip():
            return d.strip()
    except Exception:
        pass
    return default


def root() -> str:
    r = os.environ.get("CBN_ROOT", "").strip() or _setting("cbn.root")
    if not r:
        base = G.JIGSAW_ROOT and os.path.dirname(G.JIGSAW_ROOT)
        if not base:
            raise ValueError("cbn.root ayari yok (settings.json)")
        r = base
    return r


def ratings() -> list[dict]:
    return [{"id": r, "label": l} for r, l in RATINGS]


def paths(rating: str) -> dict:
    if rating not in dict(RATINGS):
        raise ValueError("bilinmeyen derece: %s" % rating)
    r = root()
    ad = dict(RATINGS)[rating]
    try:
        wrangler = str(JF._cfg().WRANGLER_BIN or "")
    except Exception:
        wrangler = ""
    return {"incoming": os.path.join(r, "_Incoming CBN", rating),
            "staging": os.path.join(r, ad),
            "pushed": os.path.join(r, ad + " - Pushed"),
            "bucket": _setting("cbn.bucket", "cbn"),
            "wrangler": wrangler}


def profiles() -> dict:
    yol = os.environ.get("CBN_OPTIONS_FILE", "").strip() or _setting("cbn.options_file") \
        or os.path.join(_ROOT, "server", "config", "cbn_options.json")
    try:
        with open(yol, encoding="utf-8") as fh:
            return {"profiles": json.load(fh), "source": yol, "error": ""}
    except Exception as e:
        return {"profiles": {}, "source": yol, "error": str(e)}


# ---------------------------------------------------------------- listeleme
def _root_for(rating: str, stage: str) -> str:
    if stage not in STAGES:
        raise ValueError("bilinmeyen akis: %s" % stage)
    return paths(rating)[stage]


def _safe_id(item_id: str) -> str:
    item_id = (item_id or "").replace("\\", "/").strip("/")
    if not _ID_RE.match(item_id) or ".." in item_id.split("/"):
        raise ValueError("gecersiz oge: %s" % item_id)
    return item_id


def _inside(rootdir: str, p: str) -> str:
    if os.path.commonpath([os.path.abspath(rootdir), os.path.abspath(p)]) != os.path.abspath(rootdir):
        raise ValueError("gecersiz oge")
    return p


def item_path(rating: str, stage: str, item_id: str, kind: str = "image") -> str | None:
    """Bir ogenin diskteki dosyasi. incoming: <stem>.jpg/.json; diger akislar:
    <koleksiyon>/<n>/<FILES[kind]>."""
    rootdir = _root_for(rating, stage)
    iid = _safe_id(item_id)
    if stage == "incoming":
        stem = _inside(rootdir, os.path.join(rootdir, iid))
        uz = {"image": (".jpg", ".jpeg"), "source": (".jpg", ".jpeg"), "json": (".json",),
              "meta": (".json",)}.get(kind, ())
        for u in uz:
            if os.path.isfile(stem + u):
                return stem + u
        return None
    d = _inside(rootdir, os.path.join(rootdir, iid.replace("/", os.sep)))
    ad = FILES.get(kind)
    if not ad:
        return None
    p = os.path.join(d, ad)
    return p if os.path.isfile(p) else None


def _asset_row(d: str, coll: str, n: str) -> dict:
    files = set()
    try:
        with os.scandir(d) as it:
            files = {e.name for e in it if e.is_file()}
    except OSError:
        return {}
    m, meta = {}, {}
    try:
        with open(os.path.join(d, "asset.json"), encoding="utf-8") as fh:
            m = (json.load(fh) or {}).get("metrics") or {}
    except Exception:
        pass
    try:
        with open(os.path.join(d, "meta.json"), encoding="utf-8") as fh:
            meta = json.load(fh) or {}
    except Exception:
        pass
    return {"id": "%s/%s" % (coll, n), "name": n, "collection": coll, "stem": n,
            "built": "asset.json" in files, "video": "reveal.mp4" in files,
            "svg": "asset.svg" in files, "regions": m.get("regions", 0),
            "colors": m.get("colors", 0), "verdict": m.get("verdict", ""),
            "tags": meta.get("tags", ""), "mtime": int(os.stat(d).st_mtime)}


def _incoming_items(folder: str) -> list[dict]:
    out = []
    try:
        with os.scandir(folder) as it:
            ents = [(e.name, e.stat()) for e in it if e.is_file()]
    except OSError:
        return out
    for ad, st in ents:
        kok, uz = os.path.splitext(ad)
        if uz.lower() not in (".jpg", ".jpeg"):
            continue
        p = os.path.join(folder, ad)
        meta = {}
        try:
            with open(os.path.join(folder, kok + ".json"), encoding="utf-8") as fh:
                meta = json.load(fh) or {}
        except Exception:
            pass
        w = os.path.join(folder, kok + ".work")
        out.append({"id": kok, "name": ad, "collection": "", "stem": kok, "built": False,
                    "video": False, "svg": False, "tagged": _has_tags(p),
                    "objects": os.path.isfile(os.path.join(w, "objects.json")),
                    "masks": os.path.isfile(os.path.join(w, "masks.npz")),
                    "lineart": os.path.isfile(os.path.join(w, "lineart.png")),
                    "prompt": (meta.get("prompt") or "")[:160], "size": st.st_size,
                    "mtime": int(st.st_mtime)})
    return out


def _sort_key(o: dict):
    s = o["stem"]
    return (0, int(s), "") if s.isdigit() else (1, 0, s.lower())


def _collection_dirs(rootdir: str) -> list[str]:
    try:
        with os.scandir(rootdir) as it:
            return sorted([e.name for e in it if e.is_dir() and not e.name.startswith("_")], key=str.lower)
    except OSError:
        return []


def _asset_dirs(coll_dir: str) -> list[str]:
    try:
        with os.scandir(coll_dir) as it:
            return [e.name for e in it if e.is_dir() and e.name.isdigit()]
    except OSError:
        return []


def next_number(rating: str, collection: str) -> int:
    p = paths(rating)
    nums = []
    for kok in (p["staging"], p["pushed"]):
        nums += [int(n) for n in _asset_dirs(os.path.join(kok, collection))]
    return (max(nums) + 1) if nums else 1


def collections(rating: str) -> dict:
    p = paths(rating)
    out = {}
    for stage in ("staging", "pushed"):
        rows = []
        for n in _collection_dirs(p[stage]):
            cnt = len(_asset_dirs(os.path.join(p[stage], n)))
            tot = cnt + len(_asset_dirs(os.path.join(p["pushed" if stage == "staging" else "staging"], n)))
            rows.append({"name": n, "count": cnt, "total": tot, "full": False,
                         "next": next_number(rating, n)})
        out[stage] = rows
    out["limit"] = 0
    out["default"] = DEFAULT_COLL
    return out


def list_items(rating: str, stage: str, collection: str = "", limit: int = 200, offset: int = 0) -> dict:
    rootdir = _root_for(rating, stage)
    if stage == "incoming":
        items = _incoming_items(rootdir)
    else:
        adlar = [collection] if collection and collection != "*" else _collection_dirs(rootdir)
        items = []
        for c in adlar:
            cd = os.path.join(rootdir, c)
            for n in _asset_dirs(cd):
                row = _asset_row(os.path.join(cd, n), c, n)
                if row:
                    items.append(row)
    items.sort(key=_sort_key, reverse=(stage == "pushed"))
    total = len(items)
    offset, limit = max(0, offset), max(1, min(1000, limit))
    return {"items": items[offset:offset + limit], "total": total, "offset": offset, "limit": limit}


def resolve_collection(rating: str, ad: str) -> str:
    ad = (ad or DEFAULT_COLL).strip() or DEFAULT_COLL
    if "/" in ad or "\\" in ad or ".." in ad or ad.startswith("_"):
        raise ValueError("gecersiz koleksiyon adi")
    for e in _collection_dirs(paths(rating)["staging"]):
        if e.lower() == ad.lower():
            return e
    return ad


# ------------------------------------------------------------------ onizleme
def thumb(rating: str, stage: str, item_id: str, kind: str = "image", size: int = 360) -> str | None:
    src = item_path(rating, stage, item_id, kind if kind in ("image", "lineart", "numbered", "preview", "segments") else "image")
    if not src:
        return None
    st = os.stat(src)
    key = hashlib.sha1(("%s|%d|%d|%d" % (src, st.st_size, int(st.st_mtime), size)).encode()).hexdigest()
    dest = os.path.join(THUMB_DIR, key + ".jpg")
    if os.path.isfile(dest):
        return dest
    try:
        from PIL import Image
        os.makedirs(THUMB_DIR, exist_ok=True)
        with Image.open(src) as f:
            f.thumbnail((size, size))
            im = f.convert("RGB")
        tmp = dest + ".tmp"
        im.save(tmp, "JPEG", quality=84)
        os.replace(tmp, dest)
        return dest
    except Exception:
        return None


def _still_native(src: str, dest: str) -> None:
    """CBN kaynagi uretim boyutunda, oran ve piksel birebir (gorev #285): bes
    oran tam oranli uretilir, Qwen cizgi sayfasi esnemesin diye buyutme/kucultme
    yapilmaz; 2x buyutme SAM asamasinda ESRGAN ile olur."""
    from PIL import Image
    with Image.open(src) as f:
        f.convert("RGB").save(dest, "JPEG", quality=95)


# ------------------------------------------------------------------ 1 -> 2
def stage_jobs(job_ids: list[str], rating: str, agent: str = "Gemini") -> str:
    """Uretim islerini Gelen'e yazar (oran korunur, uzun kenar 1280) ve EXIF
    etiketler; basarili isler galeriden silinir."""
    incoming = paths(rating)["incoming"]
    op_id = _op_new("cbn-stage", len(job_ids))

    def calis():
        os.makedirs(incoming, exist_ok=True)
        for i, jid in enumerate(job_ids, 1):
            j = G.get_job(jid)
            src = G.job_file(jid) if j else None
            if not j or j.get("status") != "done" or j.get("is_video") or not src:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: tamamlanmis gorsel degil" % jid[:8])
                continue
            stem = os.path.join(incoming, jid)
            try:
                _still_native(src, stem + ".jpg")
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: jpg yazilamadi (%s)" % (jid[:8], e))
                continue
            try:
                with open(stem + ".json", "w", encoding="utf-8") as fh:
                    json.dump({"prompt": j.get("prompt") or "", "prompt2": j.get("prompt2") or "",
                               "combined": j.get("combined") or "", "negative": j.get("negative") or "",
                               "seed": j.get("seed"), "job": jid, "rating": rating, "mode": "cbn",
                               "width": j.get("width"), "height": j.get("height"),
                               "created_at": j.get("created_at") or ""}, fh, ensure_ascii=False, indent=1)
            except Exception:
                pass
            _op(op_id, message="%d/%d etiketleniyor (%s)" % (i, len(job_ids), agent))
            ok, bilgi = _tag(stem + ".jpg", agent)
            with _ops_lock:
                _ops[op_id]["ok" if ok else "failed"] += 1
            _op(op_id, done=i, log=("%s -> Gelen  etiket: %s" % (jid[:8], bilgi[:60])) if ok
                else ("%s etiketlenemedi: %s" % (jid[:8], bilgi)))
            try:
                G.delete_job(jid)
            except Exception:
                pass
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def retag(rating: str, item_ids: list[str], agent: str = "Gemini") -> str:
    """Gelen'deki varliklari yeniden etiketler (jigsaw_flow.retag ile ayni op)."""
    return JF.retag(rating, item_ids, agent, "incoming", item_path, "cbn-retag")


# ------------------------------------------------------------------ 2 -> 3
def _pipeline_modules():
    if _TOOLS not in sys.path:
        sys.path.insert(0, _TOOLS)
    import kid_cbn  # noqa: WPS433
    import hot_cbn  # noqa: WPS433
    return kid_cbn, hot_cbn


def _read_tags(jpg: str) -> str:
    try:
        import piexif  # noqa: WPS433
        ham = (piexif.load(jpg).get("0th") or {}).get(0x9C9E) or b""
        return bytes(ham).decode("utf-16le", "ignore").strip(chr(0)).strip()
    except Exception:
        return ""


def _work_dir(jpg: str) -> str:
    return os.path.splitext(jpg)[0] + ".work"


def _batch(rating: str, item_ids: list[str], kind: str, label: str, needs_gpu: bool, fn) -> str:
    """Bir asamayi SECILI varliklarin hepsinde arka arkaya calistirir - model
    bir kez yuklenir, N gorsel islenir. GPU isteyen asamalar seridi tek bir
    kez, partinin tamami icin alir (kullanicinin kurali: 10 etiket, sonra 10
    SAM, sonra 10 cizgi - gorsel basina yukle/bosalt yok)."""
    op_id = _op_new(kind, len(item_ids))

    def calis():
        def run():
            for i, iid in enumerate(item_ids, 1):
                jpg = item_path(rating, "incoming", iid, "image")
                if not jpg:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s: bulunamadi" % iid)
                    continue
                _op(op_id, message="%s %d/%d  %s" % (label, i, len(item_ids), iid[:8]))
                try:
                    bilgi = fn(jpg, lambda m, _i=i, _id=iid: _op(op_id, message="%s %d/%d  %s: %s" % (label, _i, len(item_ids), _id[:8], m)))
                except Exception as e:
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="%s: %s" % (iid[:8], str(e)[:200]))
                    continue
                with _ops_lock:
                    _ops[op_id]["ok"] += 1
                _op(op_id, done=i, log="%s %s" % (iid[:8], bilgi))
        if needs_gpu:
            with gpu_lane.hold("%s (%d)" % (label, len(item_ids)), kind="cbn"):
                run()
        else:
            run()
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def stage_objects(rating: str, item_ids: list[str]) -> str:
    """Asama A: nesne listesi (yerel VLM / Claude) -> <stem>.work/objects.json."""
    kid_cbn, _hot = _pipeline_modules()
    use_ollama = kid_cbn.ollama_ready()

    def fn(jpg, log):
        w = _work_dir(jpg)
        os.makedirs(w, exist_ok=True)
        if use_ollama and not getattr(fn, "_freed", False):
            G.free_comfy()
            fn._freed = True
        found = kid_cbn.discover_concepts(Path(jpg))
        with open(os.path.join(w, "objects.json"), "w", encoding="utf-8") as fh:
            json.dump({"things": found, "agent": "ollama" if use_ollama else "claude",
                       "at": datetime.now().isoformat(timespec="seconds")}, fh, ensure_ascii=False, indent=1)
        return "%d nesne: %s" % (len(found), ", ".join(found[:8]))

    def wrapped(jpg, log):
        return fn(jpg, log)
    op = _batch(rating, item_ids, "cbn-objects", "nesneler", use_ollama, wrapped)
    # model partinin sonunda birakilir (op bittikten sonra da olsa zarari yok)
    if use_ollama:
        threading.Thread(target=_unload_after, args=(op, kid_cbn.ollama_unload), daemon=True).start()
    return op


def _unload_after(op_id: str, fn) -> None:
    import time
    while True:
        o = JF.op_status(op_id)
        if not o or o.get("status") != "running":
            break
        time.sleep(3)
    fn()


def stage_sam(rating: str, item_ids: list[str]) -> str:
    """Asama B: SAM3 maskeleri -> <stem>.work/masks.npz. Kavramlar objects.json
    + profil listesi; SAM checkpoint'i ComfyUI'de parti boyunca yuklu kalir."""
    kid_cbn, hot_cbn = _pipeline_modules()
    base = hot_cbn.CONCEPTS_HOT if rating == "hot" else kid_cbn.CONCEPTS["kid"]

    def fn(jpg, log):
        w = _work_dir(jpg)
        os.makedirs(w, exist_ok=True)
        found = []
        try:
            with open(os.path.join(w, "objects.json"), encoding="utf-8") as fh:
                found = (json.load(fh) or {}).get("things") or []
        except Exception:
            pass
        # Nesne listesi varsa SAM'e yalniz onu + birkac zemin sozcugu sor:
        # profil listesindeki alakasiz kavramlar (boat, house, road...) SAM'de
        # koca sahte maskeler uretiyor. Liste yoksa profil listesi yedek.
        concepts = list(dict.fromkeys(found + ["background", "sky", "ground"])) if found else list(base)
        log("SAM3 %d kavram" % len(concepts))
        masks = kid_cbn.segment(Path(jpg), concepts)
        kid_cbn.save_masks(os.path.join(w, "masks.npz"), masks)
        if rating == "hot":
            # boyanacak resim: ESRGAN x2 (uzun kenar 2560) - GPU seridi zaten bizde
            up = os.path.join(w, "source_2x.png")
            if not os.path.isfile(up):
                log("x2 buyutme")
                hot_cbn.upscale(Path(jpg), Path(up))
        return "%d maske" % len(masks)

    return _batch(rating, item_ids, "cbn-sam", "SAM", True, fn)


def stage_lineart(rating: str, item_ids: list[str]) -> str:
    """Asama C (yalniz hot): Qwen Edit cizgi sayfasi -> <stem>.work/lineart.png."""
    if rating != "hot":
        raise ValueError("cizgi sayfasi yalniz Hot CBN icin")
    _kid, hot_cbn = _pipeline_modules()

    def fn(jpg, log):
        w = _work_dir(jpg)
        os.makedirs(w, exist_ok=True)
        hot_cbn.qwen_lineart(Path(jpg), Path(os.path.join(w, "lineart.png")))
        return "cizgi hazir"

    return _batch(rating, item_ids, "cbn-lineart", "cizgi", True, fn)


def _build_from_work(rating: str, jpg: str, work: str, dest: str, log) -> dict:
    """Asama D (CPU): masks.npz (+ lineart.png) -> bolgeler, palet, varlik dosyalari."""
    import cv2  # noqa: WPS433
    from pathlib import Path as _P
    kid_cbn, hot_cbn = _pipeline_modules()
    img = cv2.imread(jpg)
    if img is None:
        raise ValueError("kaynak okunamadi")
    mp = os.path.join(work, "masks.npz")
    if not os.path.isfile(mp):
        raise ValueError("SAM asamasi yapilmamis")
    masks = kid_cbn.load_masks(mp)
    tmp = _P(dest) / "_work"
    tmp.mkdir(parents=True, exist_ok=True)
    if rating == "hot":
        up = os.path.join(work, "source_2x.png")
        if not os.path.isfile(up):
            raise ValueError("x2 buyutme yapilmamis (SAM asamasini yeniden calistir)")
        img = cv2.imread(up)
        if img is None:
            raise ValueError("x2 kaynak okunamadi")
    src = tmp / "00_source.png"
    cv2.imwrite(str(src), img)
    log("bolgeler")
    if rating == "hot":
        # Kontur kaynagi: varsayilan SAM bolum sinirlari (kaynakla piksel-piksel
        # hizali, yalniz nesneler arasinda); settings hot_cbn.lineart="qwen" ve
        # cizgi asamasi yapilmissa Qwen sayfasi kullanilir (gorev #281).
        la = None
        lp = os.path.join(work, "lineart.png")
        if _setting("hot_cbn.lineart", "sam").lower() == "qwen" and os.path.isfile(lp):
            la = cv2.imread(lp, cv2.IMREAD_GRAYSCALE)   # build() olcekler + kaynaga hizalar
            log("bolgeler (Qwen cizgi)")
        else:
            log("bolgeler (SAM konturu)")
        res = hot_cbn.build(img, la, masks)
        data = hot_cbn.write_asset(img, res, tmp, {"flow": "hot_cbn"}, reveal=True)
    else:
        res = kid_cbn.build(img, masks, "kid")
        data = kid_cbn.write_asset("asset", img, res, tmp, {"flow": "kid_cbn"})

    def mv(a, b):
        p = tmp / a
        if p.exists():
            shutil.move(str(p), os.path.join(dest, b))
    cv2.imwrite(os.path.join(dest, "source.jpg"), img, [cv2.IMWRITE_JPEG_QUALITY, 92])
    mv("05_lineart.png", "lineart.png")
    mv("02_regions.png", "regions.png")
    mv("04_numbered.png", "numbered.png")
    prev = cv2.imread(str(tmp / "03_preview.png"))
    if prev is not None:
        cv2.imwrite(os.path.join(dest, "preview.jpg"), prev, [cv2.IMWRITE_JPEG_QUALITY, 88])
    seg = cv2.imread(str(tmp / "01_segments.png"))
    if seg is not None:
        cv2.imwrite(os.path.join(dest, "segments.jpg"), seg, [cv2.IMWRITE_JPEG_QUALITY, 80])
    mv("06_reveal.mp4", "reveal.mp4")
    mv("05_lineart.svg", "lineart.svg")
    mv("asset.svg", "asset.svg")
    data["files"] = sorted(f for f in os.listdir(dest) if not f.startswith("_"))
    with open(os.path.join(dest, "asset.json"), "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1)
    shutil.rmtree(tmp, ignore_errors=True)
    return data


def build(rating: str, item_ids: list[str], collection: str) -> str:
    """Asama D: bolgele + varlik yaz (CPU; GPU seridi gerekmez). SAM (ve hot'ta
    cizgi) asamalari onceden yapilmis olmali."""
    coll = resolve_collection(rating, collection)
    p = paths(rating)
    op_id = _op_new("cbn-build", len(item_ids))

    def calis():
        for i, iid in enumerate(item_ids, 1):
            jpg = item_path(rating, "incoming", iid, "image")
            if not jpg:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: bulunamadi" % iid)
                continue
            work = _work_dir(jpg)
            n = next_number(rating, coll)
            dest = os.path.join(p["staging"], coll, str(n))
            os.makedirs(dest, exist_ok=True)

            def log(m, _i=i, _n=n):
                _op(op_id, message="insa %d/%d  %s/%d: %s" % (_i, len(item_ids), coll, _n, m))
            try:
                data = _build_from_work(rating, jpg, work, dest, log)
            except Exception as e:
                shutil.rmtree(dest, ignore_errors=True)
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s insa edilemedi: %s" % (iid[:8], str(e)[:200]))
                continue
            meta = {}
            js = os.path.splitext(jpg)[0] + ".json"
            try:
                with open(js, encoding="utf-8") as fh:
                    meta = json.load(fh) or {}
            except Exception:
                pass
            try:
                with open(os.path.join(work, "objects.json"), encoding="utf-8") as fh:
                    meta["objects"] = (json.load(fh) or {}).get("things") or []
            except Exception:
                pass
            meta.update({"tags": _read_tags(jpg), "rating": rating, "collection": coll, "number": n,
                         "built_at": datetime.now().isoformat(timespec="seconds")})
            with open(os.path.join(dest, "meta.json"), "w", encoding="utf-8") as fh:
                json.dump(meta, fh, ensure_ascii=False, indent=1)
            for f in (jpg, js):
                try:
                    os.remove(f)
                except OSError:
                    pass
            shutil.rmtree(work, ignore_errors=True)
            m = data.get("metrics", {})
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, log="%s -> %s/%d  %s bolge, %s renk, %s" % (
                iid[:8], coll, n, m.get("regions"), m.get("colors"), m.get("verdict", "").upper()))
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ 3 -> 4
def push(rating: str, item_ids: list[str]) -> str:
    """3 -> 4. Varlik klasorunu R2'ye yukler (cbn/<derece>/<koleksiyon>/<n>/<dosya>),
    sonra Pushed'a tasir. Bir dosya yuklenemezse o varlik durur, tasinmaz."""
    p = paths(rating)
    if not p["wrangler"] or not os.path.isfile(p["wrangler"]):
        raise ValueError("wrangler bulunamadi: %s" % p["wrangler"])
    op_id = _op_new("cbn-push", len(item_ids))

    def calis():
        for i, iid in enumerate(item_ids, 1):
            src = item_path(rating, "staging", iid, "json")
            if not src:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: insa edilmemis" % iid)
                continue
            d = os.path.dirname(src)
            coll, n = iid.split("/", 1)
            _op(op_id, message="push %d/%d  %s" % (i, len(item_ids), iid))
            ok_all = True
            for f in sorted(os.listdir(d)):
                if f.startswith("_") or f == "meta.json":
                    continue
                key = "cbn/%s/%s/%s/%s" % (rating, coll, n, f)
                ok, err = _r2_put(p["wrangler"], p["bucket"], key, os.path.join(d, f))
                if not ok:
                    ok_all = False
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="YUKLENEMEDI %s: %s" % (key, err[:150]))
                    break
                _op(op_id, log="+ %s" % key)
            if not ok_all:
                _op(op_id, message="yukleme hatasi - islem durduruldu")
                return
            hedef = os.path.join(p["pushed"], coll)
            os.makedirs(hedef, exist_ok=True)
            shutil.move(d, os.path.join(hedef, n))
            cd = os.path.join(p["staging"], coll)
            try:
                if os.path.isdir(cd) and not os.listdir(cd):
                    os.rmdir(cd)
            except OSError:
                pass
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i)

    _run(op_id, calis)
    return op_id


def remove(rating: str, stage: str, item_ids: list[str]) -> dict:
    silinen = 0
    for iid in item_ids:
        if stage == "incoming":
            jpg = item_path(rating, stage, iid, "image")
            if not jpg:
                continue
            for uz in (".jpg", ".jpeg", ".json"):
                try:
                    os.remove(os.path.splitext(jpg)[0] + uz)
                    silinen += 1
                except OSError:
                    pass
            shutil.rmtree(_work_dir(jpg), ignore_errors=True)
        else:
            rootdir = _root_for(rating, stage)
            d = _inside(rootdir, os.path.join(rootdir, _safe_id(iid).replace("/", os.sep)))
            if os.path.isdir(d):
                shutil.rmtree(d, ignore_errors=True)
                silinen += 1
    return {"deleted": silinen}
