"""Jigsaw dort akisli yayin hatti - r2manager boru hattinin sunucu tarafi.

Masaustundeki Uretim Studyosu ile ayni akis; buradaki uclar sayesinde telefon
(AGB companion) da ayni isi yapabilir.

  1 Uretim        comfy_gen isleri (bu modul disinda)
  2 Etiketli      _Incoming\\<stem>.jpg (+ .mp4, + .json yan dosya), EXIF etiketli
  3 Push bekleyen <Derece>\\<Koleksiyon>\\<n>.jpg / .mp4 / .webp
  4 Push edilmis  <Derece> - Pushed\\<Koleksiyon>\\...

Numaralama, webp kodlayicisi ve EXIF semasi r2manager ile birebir aynidir:
numara staging + pushed birlikte taranarak bulunur, webp ortak kodlayiciyla
(24 fps / 320 px / q80) uretilir, etiket r2manager'in tag_image'i ile yazilir.

Uzun suren isler (etiketleme, webp, push) arka planda calisir ve `op_status`
ile izlenir - istemci bloke olmaz.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import uuid
from datetime import datetime

from . import comfy_gen as G

# r2manager kokleri: tools/r2manager/config.py tek kaynak.
_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
R2M_DIR = os.path.join(_ROOT, "tools", "r2manager")
THUMB_DIR = os.path.join(G.OUT_DIR, "_flow_thumbs")

# Dropdown secenek dosyasi MAKINEYE OZELDIR - depo herkese acik oldugu icin
# yolu koda gommuyoruz. Sirasiyla: ortam degiskeni, settings.json
# (gitignore'da), sonra depo icindeki ornek dosya.
_SETTINGS = os.path.join(_ROOT, "server", "config", "settings.json")


def _opts_file() -> str:
    yol = os.environ.get("JIGSAW_OPTIONS_FILE", "").strip()
    if yol:
        return yol
    try:
        with open(_SETTINGS, encoding="utf-8") as fh:
            yol = ((json.load(fh) or {}).get("jigsaw") or {}).get("options_file") or ""
    except Exception:
        yol = ""
    return yol.strip() or os.path.join(_ROOT, "server", "config", "jigsaw_options.example.json")

RATINGS = [("hot", "Hot Jigsaw"), ("kid", "Kid Jigsaw")]
STAGES = ("incoming", "staging", "pushed")

# Tematik koleksiyonlar 10 varlikta dolar (kovadaki 56 koleksiyonun hepsi tam
# 10). Dolu koleksiyon kabul secenegi olarak sunulmaz; Generic sinirsizdir.
COLL_LIMIT = 10
DEFAULT_COLL = "Generic"

# <stem> ya da <koleksiyon>/<stem> - baska hicbir sey kabul edilmez.
# Yol kacisini (.., surucu harfi, ters bolu) bastan eler.
_ID_RE = re.compile(r"^(?:[^\\/:*?\"<>|]{1,120}/)?[^\\/:*?\"<>|]{1,120}$")


_cfg_cache = None


def _cfg():
    """r2manager'in config.py'sini DOSYA YOLUNDAN yukler.

    Duz `import config` burada calismaz: AGB'nin kendi `server/config/` paketi
    zaten `sys.modules["config"]` icinde oturuyor, o yuzden import AGB'ninkini
    dondurup INCOMING/STAGING_ROOTS yok diye patliyordu (500).
    """
    global _cfg_cache
    if _cfg_cache is not None:
        return _cfg_cache
    import importlib.util
    yol = os.path.join(R2M_DIR, "config.py")
    if not os.path.isfile(yol):
        raise ValueError("r2manager config.py bulunamadi: %s" % yol)
    spec = importlib.util.spec_from_file_location("r2m_config", yol)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["r2m_config"] = mod
    spec.loader.exec_module(mod)
    _cfg_cache = mod
    return mod


def ratings() -> list[dict]:
    return [{"id": r, "label": l} for r, l in RATINGS]


def paths(rating: str) -> dict:
    """Bir derecenin akis klasorleri, kovasi ve wrangler yolu."""
    if rating not in dict(RATINGS):
        raise ValueError("bilinmeyen derece: %s" % rating)
    c = _cfg()
    ck = "Teen" if rating == "hot" else "Kid"
    pk = "Hot Jigsaw (teen)" if rating == "hot" else "Kid Jigsaw (kid)"
    return {"incoming": str(c.INCOMING),
            "staging": str(c.STAGING_ROOTS[ck]),
            "pushed": str(c.PUSHED_ROOTS[pk]),
            "bucket": c.BUCKET_BY_RATING[ck],
            "wrangler": str(c.WRANGLER_BIN or "")}


def profiles() -> dict:
    """Dropdown profilleri (hot/kid). Masaustuyle TEK dosya paylasilir."""
    yol = _opts_file()
    try:
        with open(yol, encoding="utf-8") as fh:
            return {"profiles": json.load(fh), "source": yol, "error": ""}
    except Exception as e:
        # Sessizce bos donmuyoruz: istemci bunu kullaniciya gosterir.
        return {"profiles": {}, "source": yol, "error": str(e)}


# ------------------------------------------------------------------ listeleme
def _root_for(rating: str, stage: str) -> str:
    if stage not in STAGES:
        raise ValueError("bilinmeyen akis: %s" % stage)
    return paths(rating)[stage]


def _safe_id(item_id: str) -> str:
    item_id = (item_id or "").replace("\\", "/").strip("/")
    if not _ID_RE.match(item_id) or ".." in item_id.split("/"):
        raise ValueError("gecersiz oge: %s" % item_id)
    return item_id


def item_path(rating: str, stage: str, item_id: str, kind: str = "image") -> str | None:
    """Bir ogenin diskteki yolu. kind: image | video | webp | json."""
    root = _root_for(rating, stage)
    stem = os.path.join(root, _safe_id(item_id).replace("/", os.sep))
    # Kok disina cikilmadigini dogrula (sembolik bag / kacis).
    if os.path.commonpath([os.path.abspath(root),
                           os.path.abspath(stem)]) != os.path.abspath(root):
        raise ValueError("gecersiz oge")
    uz = {"image": (".jpg", ".jpeg"), "video": (".mp4",),
          "webp": (".webp",), "json": (".json",)}.get(kind, (".jpg",))
    for u in uz:
        if os.path.isfile(stem + u):
            return stem + u
    return None


def _has_tags(jpg: str) -> bool:
    """XPKeywords dolu mu? r2manager'in app.py'si ice alinmiyor - o modul de
    `import config` yaptigi icin AGB'nin config paketiyle cakisiyor. Etiketin
    yazildigi alan tek ve sabit (0x9C9E), dogrudan okumak yeterli."""
    try:
        import piexif                    # noqa: WPS433
        ex = piexif.load(jpg)
        ham = (ex.get("0th") or {}).get(0x9C9E)
        if not ham:
            return False
        return bool(bytes(ham).decode("utf-16le", "ignore").strip(chr(0)).strip())
    except Exception:
        return False


def _folder_items(folder: str, coll: str, tags: bool) -> list[dict]:
    """Klasoru TEK geciste okur - dosya basina ayri stat cagirmak 2000+
    varlikli koleksiyonda listeyi dakikalara cikariyor."""
    try:
        with os.scandir(folder) as it:
            girdiler = [(e.name, e.stat()) for e in it if e.is_file()]
    except OSError:
        return []
    uzantilar: dict[str, set] = {}
    for ad, _st in girdiler:
        kok, uz = os.path.splitext(ad)
        uzantilar.setdefault(kok, set()).add(uz.lower())

    out = []
    for ad, st in girdiler:
        kok, uz = os.path.splitext(ad)
        if uz.lower() not in (".jpg", ".jpeg"):
            continue
        u = uzantilar.get(kok, set())
        oge = {"id": ("%s/%s" % (coll, kok)) if coll else kok,
               "name": ad, "collection": coll, "stem": kok,
               "video": ".mp4" in u, "webp": ".webp" in u,
               "size": st.st_size, "mtime": int(st.st_mtime)}
        if tags:
            oge["tagged"] = _has_tags(os.path.join(folder, ad))
        out.append(oge)
    return out


def _sort_key(oge: dict):
    s = oge["stem"].split("-")[0]
    return (0, int(s), "") if s.isdigit() else (1, 0, oge["stem"].lower())


def coll_total(rating: str, coll: str) -> int:
    """Bir koleksiyondaki varlik sayisi - staging VE pushed birlikte.

    Tematik koleksiyonun yarisi kovaya gitmis olabilir; dolu mu degil mi
    karari iki kokun toplamina bakar.
    """
    p = paths(rating)
    nums = set()
    for kok in (p["staging"], p["pushed"]):
        d = os.path.join(kok, coll)
        try:
            with os.scandir(d) as it:
                for e in it:
                    k, u = os.path.splitext(e.name)
                    k = k.split("-")[0]
                    if u.lower() in (".jpg", ".jpeg") and k.isdigit():
                        nums.add(int(k))
        except OSError:
            continue
    return len(nums)


def collections(rating: str) -> dict:
    """Her akisin koleksiyonlari + varlik sayilari.

    `total` iki kokun toplami, `full` ise "10'a ulasti, yeni varlik alma"
    demektir (Generic haric). Istemci kabul listesinde dolulari gizler.
    """
    p = paths(rating)
    out = {}
    for stage in ("staging", "pushed"):
        adlar = []
        try:
            with os.scandir(p[stage]) as it:
                adlar = sorted([e.name for e in it if e.is_dir()], key=str.lower)
        except OSError:
            pass
        satirlar = []
        for n in adlar:
            toplam = coll_total(rating, n)
            satirlar.append({
                "name": n,
                "count": len(_folder_items(os.path.join(p[stage], n), n, False)),
                "total": toplam,
                "full": (toplam >= COLL_LIMIT and n.lower() != DEFAULT_COLL.lower()),
                "next": next_number(rating, n)})
        out[stage] = satirlar
    out["limit"] = COLL_LIMIT
    out["default"] = DEFAULT_COLL
    return out


def list_items(rating: str, stage: str, collection: str = "",
               limit: int = 200, offset: int = 0) -> dict:
    """Bir akisin varliklari. Sayfali - telefon 2000 kaydi bir kerede cekmesin."""
    root = _root_for(rating, stage)
    if stage == "incoming":
        items = _folder_items(root, "", True)
    else:
        if collection and collection != "*":
            adlar = [collection]
        else:
            try:
                with os.scandir(root) as it:
                    adlar = sorted([e.name for e in it if e.is_dir()], key=str.lower)
            except OSError:
                adlar = []
        items = []
        for c in adlar:
            items += _folder_items(os.path.join(root, c), c, False)
    # Push edilmislerde en yeni varlik ustte olsun - aranan hep sonuncular.
    items.sort(key=_sort_key, reverse=(stage == "pushed"))
    total = len(items)
    offset = max(0, offset)
    limit = max(1, min(1000, limit))
    return {"items": items[offset:offset + limit], "total": total,
            "offset": offset, "limit": limit}


def next_number(rating: str, collection: str) -> int:
    """Bos ilk numara - staging VE pushed birlikte taranir (r2manager kurali),
    boylece kovadaki numaralarla asla cakismaz."""
    p = paths(rating)
    nums: list[int] = []
    for kok in (p["staging"], p["pushed"]):
        d = os.path.join(kok, collection)
        try:
            with os.scandir(d) as it:
                for e in it:
                    s = os.path.splitext(e.name)[0].split("-")[0]
                    if s.isdigit():
                        nums.append(int(s))
        except OSError:
            continue
    return (max(nums) + 1) if nums else 1


def resolve_collection(rating: str, ad: str) -> str:
    """Yazilan adi mevcut klasore esler (buyuk/kucuk harf farkini yutar)."""
    ad = (ad or "Generic").strip() or "Generic"
    if "/" in ad or "\\" in ad or ".." in ad:
        raise ValueError("gecersiz koleksiyon adi")
    root = paths(rating)["staging"]
    try:
        with os.scandir(root) as it:
            for e in it:
                if e.is_dir() and e.name.lower() == ad.lower():
                    return e.name
    except OSError:
        pass
    return ad


# ------------------------------------------------------------------ onizleme
def thumb(rating: str, stage: str, item_id: str, size: int = 360) -> str | None:
    """Kucuk JPEG onizleme (diskte onbelleklenir)."""
    src = item_path(rating, stage, item_id, "image")
    if not src:
        return None
    st = os.stat(src)
    anahtar = hashlib.sha1(
        ("%s|%d|%d|%d" % (src, st.st_size, int(st.st_mtime), size)).encode()).hexdigest()
    hedef = os.path.join(THUMB_DIR, anahtar + ".jpg")
    if os.path.isfile(hedef):
        return hedef
    try:
        from PIL import Image
        os.makedirs(THUMB_DIR, exist_ok=True)
        with Image.open(src) as f:
            f.thumbnail((size, size))
            im = f.convert("RGB")
        tmp = hedef + ".tmp"
        im.save(tmp, "JPEG", quality=82)
        os.replace(tmp, hedef)
        return hedef
    except Exception:
        return None


# ------------------------------------------------------------- arka plan isleri
_ops: dict[str, dict] = {}
_ops_lock = threading.Lock()


def _op_new(kind: str, total: int) -> str:
    op_id = uuid.uuid4().hex[:12]
    with _ops_lock:
        _ops[op_id] = {"id": op_id, "kind": kind, "status": "running",
                       "done": 0, "total": total, "ok": 0, "failed": 0,
                       "message": "", "log": [],
                       "started_at": datetime.now().isoformat(timespec="seconds")}
    return op_id


def _op(op_id: str, **kw):
    with _ops_lock:
        o = _ops.get(op_id)
        if not o:
            return
        kayit = kw.pop("log", None)
        if kayit:
            o["log"] = (o["log"] + [kayit])[-200:]
        o.update(kw)


def op_status(op_id: str) -> dict | None:
    with _ops_lock:
        o = _ops.get(op_id)
        return dict(o) if o else None


def ops() -> list[dict]:
    with _ops_lock:
        return sorted((dict(o) for o in _ops.values()),
                      key=lambda o: o["started_at"], reverse=True)[:20]


def _run(op_id: str, fn):
    def sarmal():
        try:
            fn()
            _op(op_id, status="done")
        except Exception as e:
            _op(op_id, status="error", message=str(e)[:400])
    threading.Thread(target=sarmal, daemon=True).start()


# ------------------------------------------------------------------ 1 -> 2
_TAG_KOD = (
    "import sys;"
    "sys.path.insert(0, sys.argv[1]);"
    "from pathlib import Path;"
    "import app;"
    "sys.exit(0 if app.tag_image(Path(sys.argv[2]), sys.argv[3]) else 1)"
)


def _tag(jpg: str, agent: str) -> tuple[bool, str]:
    """r2manager'in EXIF etiketleyicisini AYRI BIR SURECTE calistirir.

    Ice almiyoruz: r2manager'in app.py'si `import config` yapiyor ve AGB'nin
    kendi config paketiyle cakisiyor; ayrica cv2 gibi agir bagimliliklari
    sunucu surecine tasimanin anlami yok. cwd=R2M_DIR oldugu icin alt surecte
    `config` dogru dosyaya cozuluyor.

    Yazdiktan sonra EXIF geri okunup etiketin gercekten dustugu dogrulanir.
    """
    # Format sonrasi Gemini CLI kurulu degilse istemcinin varsayilani bos
    # dondurmesin: elde olan etiketleyiciye (Claude CLI) dus.
    if agent == "Gemini" and not (shutil.which("gemini.cmd") or shutil.which("gemini")):
        if shutil.which("claude.cmd") or shutil.which("claude"):
            agent = "Claude"
    try:
        proc = subprocess.run(
            [sys.executable, "-c", _TAG_KOD, R2M_DIR, jpg, agent],
            cwd=R2M_DIR, capture_output=True, text=True, timeout=300,
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except subprocess.TimeoutExpired:
        return False, "%s zaman asimina ugradi (300 sn)" % agent
    except Exception as e:
        return False, "etiketleyici calistirilamadi: %s" % e
    if proc.returncode != 0:
        ayrinti = (proc.stderr or proc.stdout or "").strip().splitlines()
        return False, "%s basarisiz: %s" % (agent, ayrinti[-1][:200] if ayrinti else "kod %d" % proc.returncode)
    if not _has_tags(jpg):
        return False, "etiketleyici bitti ama EXIF'e etiket dusmedi"
    try:
        import piexif                    # noqa: WPS433
        ham = (piexif.load(jpg).get("0th") or {}).get(0x9C9E) or b""
        return True, bytes(ham).decode("utf-16le", "ignore").strip(chr(0)).strip()
    except Exception:
        return True, "yazildi"


def stage_jobs(job_ids: list[str], rating: str, agent: str = "Gemini") -> str:
    """1 -> 2. Secili gorselleri _Incoming'e yazar, EXIF etiketini isler,
    varsa videosunu yanina alir ve AGB islerini temizler."""
    p = paths(rating)
    incoming = p["incoming"]
    op_id = _op_new("stage", len(job_ids))

    def calis():
        os.makedirs(incoming, exist_ok=True)
        tum = G.list_jobs(limit=1000)
        for i, jid in enumerate(job_ids, 1):
            j = G.get_job(jid)
            if not j or j.get("status") != "done" or j.get("is_video"):
                _op(op_id, done=i, failed=_ops[op_id]["failed"] + 1,
                    log="%s: tamamlanmis gorsel degil" % jid[:8])
                continue
            src = G.job_file(jid)
            if not src:
                _op(op_id, done=i, failed=_ops[op_id]["failed"] + 1,
                    log="%s: cikti dosyasi yok" % jid[:8])
                continue

            stem = os.path.join(incoming, jid)
            try:
                _to_still(src, stem + ".jpg")
            except Exception as e:
                _op(op_id, done=i, failed=_ops[op_id]["failed"] + 1,
                    log="%s: jpg yazilamadi (%s)" % (jid[:8], e))
                continue

            silinecek = [jid]
            for v in tum:
                if (v.get("source_job") == jid and v.get("is_video")
                        and v.get("status") == "done"):
                    vp = G.job_file(v["id"])
                    if vp:
                        try:
                            shutil.copy(vp, stem + ".mp4")
                            silinecek.append(v["id"])
                        except Exception:
                            pass
                    break

            try:
                with open(stem + ".json", "w", encoding="utf-8") as fh:
                    json.dump({"prompt": j.get("prompt") or "",
                               "prompt2": j.get("prompt2") or "",
                               "combined": j.get("combined") or "",
                               "negative": j.get("negative") or "",
                               "seed": j.get("seed"), "job": jid,
                               "rating": rating,
                               "created_at": j.get("created_at") or ""},
                              fh, ensure_ascii=False, indent=1)
            except Exception:
                pass

            _op(op_id, message="%d/%d etiketleniyor (%s)" % (i, len(job_ids), agent))
            ok, bilgi = _tag(stem + ".jpg", agent)
            with _ops_lock:
                o = _ops[op_id]
                if ok:
                    o["ok"] += 1
                else:
                    o["failed"] += 1
            _op(op_id, done=i,
                log=("%s -> %s.jpg  etiket: %s" % (jid[:8], jid, bilgi[:60])) if ok
                    else ("%s etiketlenemedi: %s" % (jid[:8], bilgi)))

            for x in silinecek:
                try:
                    G.delete_job(x)
                except Exception:
                    pass
        _op(op_id, message="bitti")

    _run(op_id, calis)
    return op_id


def _to_still(src: str, dest: str) -> None:
    """Havuz jpg'si: oran korunur, uzun kenar 1280, kirpma yok - AGB'nin
    jigsaw_accept'i ile ayni islem (comfy_gen.still_to_pool)."""
    G.still_to_pool(src, dest)


# ------------------------------------------------------------------ 2. akis
_pending_videos: dict[str, str] = {}      # comfy_gen is id -> yazilacak mp4 yolu
_watcher_started = False


def video_templates(rating: str) -> dict:
    """Bir derecenin hazir video sablonlari + varsayilan negatifi."""
    prof = (profiles().get("profiles") or {}).get(rating) or {}
    v = prof.get("video") or {}
    sablonlar = [{"ad": str(x.get("ad") or ""), "prompt": str(x.get("prompt") or "")}
                 for x in (v.get("sablonlar") or []) if str(x.get("prompt") or "").strip()]
    return {"rating": rating, "templates": sablonlar,
            "negative": str(v.get("negatif") or ""),
            "motion_default": (G.MODES.get("jigsaw") or {}).get("motion2") or ""}


def _combine(p1: str, p2: str) -> str:
    """AGB'nin kuralinin aynisi: p2'de {} varsa p1 oraya girer."""
    p1, p2 = (p1 or "").strip(), (p2 or "").strip()
    if not p2:
        return p1
    if "{}" in p2:
        return p2.replace("{}", p1) if p1 else p2.replace("{},", "").replace("{}", "").strip(" ,")
    return (p1 + ", " + p2).strip(" ,") if p1 else p2


def make_videos(rating: str, item_ids: list[str], duration: int = 5,
                turbo: bool = True, prompt: str = "", prompt2: str = "",
                negative: str = "", rotate_templates: bool = False,
                task: str = "") -> dict:
    """2. akis: secili jpg'ler icin LTX video isi acar.

    prompt   : bos ise her varligin kendi yan dosyasindaki konu prompt'u kullanilir
    prompt2  : hareket sablonu ({} = konu). Bos ve rotate_templates ise hazir
               sablonlar SIRAYLA dagitilir ("Que All" davranisi).
    negative : bos ise derecenin varsayilan video negatifi kullanilir

    Is bitince mp4 jpg'nin yanina yazilir (arka plan gozcusu).
    """
    gorevler = [t for t in G.tasks("jigsaw") if t.get("is_video") and t.get("needs_image")]
    if not gorevler:
        raise ValueError("video gorevi bulunamadi")
    # LTX varsayilan: "sesli" olan is akisi; istemci baskasini secebilir.
    gorev = next((t for t in gorevler if t["id"] == task), None)         or next((t for t in gorevler if "ltx" in t["id"].lower()), gorevler[0])

    vt = video_templates(rating)
    sablonlar = [x["prompt"] for x in vt["templates"]]
    neg = negative.strip() or vt["negative"]
    varsayilan_motion = (prompt2.strip() or vt["motion_default"])

    acilan, atlanan, sira = [], 0, 0     # sira: yalniz gercekten acilan isler
    for iid in item_ids:
        jpg = item_path(rating, "incoming", iid, "image")
        if not jpg or item_path(rating, "incoming", iid, "video"):
            atlanan += 1
            continue                      # yok ya da zaten videosu var
        yan = {}
        try:
            with open(os.path.splitext(jpg)[0] + ".json", encoding="utf-8") as fh:
                yan = json.load(fh)
        except Exception:
            pass
        konu = prompt.strip() or (yan.get("prompt") or "")
        if rotate_templates and sablonlar and not prompt2.strip():
            # Atlanan varlik sablon harcamasin: sayac yalniz acilan iste artar.
            motion = sablonlar[sira % len(sablonlar)]
        else:
            motion = varsayilan_motion

        j = G.submit(task=gorev["id"], prompt=konu, prompt2=motion, negative=neg,
                     duration=duration, turbo=turbo, image_path=jpg,
                     mode="jigsaw", client="flow", category="")
        jid = j.get("id") if isinstance(j, dict) else getattr(j, "id", None)
        if jid:
            _pending_videos[jid] = os.path.splitext(jpg)[0] + ".mp4"
            acilan.append(jid)
            sira += 1
    _start_watcher()
    return {"queued": len(acilan), "skipped": atlanan, "jobs": acilan,
            "task": gorev["id"], "templates_used": len(sablonlar) if rotate_templates else 0}


def _start_watcher():
    global _watcher_started
    if _watcher_started:
        return
    _watcher_started = True

    def gozcu():
        while True:
            time.sleep(6)
            for jid, hedef in list(_pending_videos.items()):
                try:
                    j = G.get_job(jid)
                except Exception:
                    continue
                if not j:
                    _pending_videos.pop(jid, None)
                    continue
                if j.get("status") in ("error", "cancelled"):
                    _pending_videos.pop(jid, None)
                    continue
                if j.get("status") != "done":
                    continue
                src = G.job_file(jid)
                if src and os.path.isdir(os.path.dirname(hedef)):
                    try:
                        shutil.copy(src, hedef)
                        G.delete_job(jid)
                    except Exception:
                        pass
                _pending_videos.pop(jid, None)

    threading.Thread(target=gozcu, daemon=True).start()


def pending_videos() -> dict:
    return {"pending": len(_pending_videos), "jobs": list(_pending_videos)}


# ------------------------------------------------------------------ 2 -> 3
def accept(rating: str, item_ids: list[str], collection: str) -> str:
    """2 -> 3. Varliklari koleksiyona <n>.jpg / .mp4 / .webp olarak tasir.
    Video zorunlu degildir; yoksa yalniz jpg yazilir."""
    coll = resolve_collection(rating, collection)
    hedef_dir = os.path.join(paths(rating)["staging"], coll)
    op_id = _op_new("accept", len(item_ids))

    def calis():
        os.makedirs(hedef_dir, exist_ok=True)
        for i, iid in enumerate(item_ids, 1):
            jpg = item_path(rating, "incoming", iid, "image")
            if not jpg:
                _op(op_id, done=i, log="%s: bulunamadi" % iid)
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                continue
            n = next_number(rating, coll)
            stem = os.path.splitext(jpg)[0]
            try:
                shutil.move(jpg, os.path.join(hedef_dir, "%d.jpg" % n))
            except Exception as e:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s tasinamadi: %s" % (iid, e))
                continue

            mp4 = stem + ".mp4"
            if os.path.isfile(mp4):
                shutil.move(mp4, os.path.join(hedef_dir, "%d.mp4" % n))
                ok, err = G._encode_webp(os.path.join(hedef_dir, "%d.mp4" % n),
                                         os.path.join(hedef_dir, "%d.webp" % n))
                if not ok:
                    _op(op_id, log="%d.webp uretilemedi: %s" % (n, err[:120]))
            js = stem + ".json"
            if os.path.isfile(js):
                shutil.move(js, os.path.join(hedef_dir, "%d.json" % n))
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i, message="%s -> %s/%d" % (iid, coll, n),
                log="%s -> %s/%d" % (iid, coll, n))

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ 3 -> 4
def _r2_put(wrangler: str, bucket: str, key: str, dosya: str,
            timeout: int = 240) -> tuple[bool, str]:
    try:
        proc = subprocess.run(
            [wrangler, "r2", "object", "put", "%s/%s" % (bucket, key),
             "--file", dosya, "--remote"],
            capture_output=True, text=True, timeout=timeout,
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except subprocess.TimeoutExpired:
        return False, "zaman asimi"
    except FileNotFoundError:
        return False, "wrangler bulunamadi"
    if proc.returncode != 0:
        return False, (proc.stderr or proc.stdout or "")[:400]
    return True, ""


def collection_music(rating: str, coll: str, stage: str = "staging") -> str | None:
    """Koleksiyondaki .mp3 (varsa). r2manager kurali: tematik koleksiyonun
    muzigi varliklarla birlikte kovaya gider; Generic'in muzigi olmaz."""
    if coll.lower() == DEFAULT_COLL.lower():
        return None
    d = os.path.join(paths(rating)[stage], coll)
    try:
        with os.scandir(d) as it:
            for e in it:
                if e.is_file() and e.name.lower().endswith(".mp3"):
                    return os.path.join(d, e.name)
    except OSError:
        pass
    return None


def push(rating: str, item_ids: list[str]) -> str:
    """3 -> 4. Varliklari R2'ye yukler, sonra 'Pushed' klasorune tasir.

    r2manager'in push kurallari aynen gecerlidir:
      * anahtar duzeni  collections/<koleksiyon>/images|videos|videos_webp/<n>.<uz>
      * tematik koleksiyonun .mp3'u de gider (collections/<k>/music/<ad>.mp3);
        Generic'in muzigi olmaz
      * .json yan dosyasi YEREL kayittir, asla yuklenmez - yalniz tasinir
      * videosu olup webp'i olmayan varlik uyarilir (uygulama webp'i oynatiyor)
      * bir dosya yuklenemezse islem DURUR; o varlik tasinmaz, yarim yayin olmaz
      * koleksiyon klasoru bosaldiysa silinir

    Bu bir YAYIN islemidir ve geri alinamaz.
    """
    p = paths(rating)
    if not p["wrangler"] or not os.path.isfile(p["wrangler"]):
        raise ValueError("wrangler bulunamadi: %s" % p["wrangler"])
    op_id = _op_new("push", len(item_ids))

    def calis():
        dokunulan: set[str] = set()
        for i, iid in enumerate(item_ids, 1):
            jpg = item_path(rating, "staging", iid, "image")
            if not jpg:
                with _ops_lock:
                    _ops[op_id]["failed"] += 1
                _op(op_id, done=i, log="%s: bulunamadi" % iid)
                continue
            coll = os.path.basename(os.path.dirname(jpg))
            stem = os.path.splitext(jpg)[0]

            isler = [("images", jpg)]
            if os.path.isfile(stem + ".mp4"):
                isler.append(("videos", stem + ".mp4"))
                if os.path.isfile(stem + ".webp"):
                    isler.append(("videos_webp", stem + ".webp"))
                else:
                    # Uygulama duvarlarda webp oynatiyor; mp4 tek basina yetmez.
                    _op(op_id, log="! %s: webp ikizi yok - uygulama oynatamaz"
                        % os.path.basename(stem))

            _op(op_id, message="push %d/%d  %s" % (i, len(item_ids), iid))
            basarili = True
            for klasor, dosya in isler:
                key = "collections/%s/%s/%s" % (coll, klasor, os.path.basename(dosya))
                ok, err = _r2_put(p["wrangler"], p["bucket"], key, dosya)
                if not ok:
                    basarili = False
                    with _ops_lock:
                        _ops[op_id]["failed"] += 1
                    _op(op_id, done=i, log="YUKLENEMEDI %s: %s" % (key, err[:150]))
                    break
                _op(op_id, log="+ %s" % key)
            if not basarili:
                _op(op_id, message="yukleme hatasi - islem durduruldu")
                return

            hedef = os.path.join(p["pushed"], coll)
            os.makedirs(hedef, exist_ok=True)
            # .json yuklenmez ama varlikla birlikte tasinir (yerel kayit).
            for uz in (".jpg", ".mp4", ".webp", ".json"):
                if os.path.isfile(stem + uz):
                    try:
                        shutil.move(stem + uz,
                                    os.path.join(hedef, os.path.basename(stem) + uz))
                    except Exception as e:
                        _op(op_id, log="tasima uyarisi: %s" % e)
            dokunulan.add(coll)
            with _ops_lock:
                _ops[op_id]["ok"] += 1
            _op(op_id, done=i)

        # --- koleksiyon muzigi + klasor temizligi
        for coll in sorted(dokunulan):
            mp3 = collection_music(rating, coll)
            if mp3:
                key = "collections/%s/music/%s" % (coll, os.path.basename(mp3))
                ok, err = _r2_put(p["wrangler"], p["bucket"], key, mp3)
                if ok:
                    _op(op_id, log="+ %s" % key)
                    hedef = os.path.join(p["pushed"], coll)
                    os.makedirs(hedef, exist_ok=True)
                    try:
                        shutil.move(mp3, os.path.join(hedef, os.path.basename(mp3)))
                    except Exception as e:
                        _op(op_id, log="mp3 tasima uyarisi: %s" % e)
                else:
                    _op(op_id, log="mp3 YUKLENEMEDI %s: %s" % (key, err[:150]))
            # Bosalan koleksiyon klasoru kalmasin.
            d = os.path.join(p["staging"], coll)
            try:
                if os.path.isdir(d) and not os.listdir(d):
                    os.rmdir(d)
                    _op(op_id, log="bos koleksiyon klasoru silindi: %s" % coll)
            except OSError:
                pass

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ muzik
def music_status(rating: str) -> dict:
    """Hangi koleksiyonun muzigi var, hangisinin yok."""
    from . import jigsaw_music as MZ
    hazir, hata = MZ.model_ready()
    p = paths(rating)
    satirlar = []
    for stage in ("staging", "pushed"):
        try:
            with os.scandir(p[stage]) as it:
                adlar = sorted([e.name for e in it if e.is_dir()], key=str.lower)
        except OSError:
            adlar = []
        for c in adlar:
            if c.lower() == DEFAULT_COLL.lower():
                continue                 # Generic'in muzigi olmaz
            mp3 = collection_music(rating, c, stage)
            satirlar.append({"name": c, "stage": stage,
                             "music": os.path.basename(mp3) if mp3 else "",
                             "has_music": bool(mp3)})
    return {"model_ready": hazir, "model_error": hata,
            "default_collection": DEFAULT_COLL, "collections": satirlar}


def make_music(rating: str, collections: list[str], tags: str = "",
               seconds: float = 30.0, overwrite: bool = False) -> str:
    """Secili koleksiyonlar icin ACE-Step ile mp3 uretir (arka planda).

    Generic atlanir - kovada Generic'in muzigi yok. Muzigi olan koleksiyon
    overwrite=False iken atlanir.
    """
    from . import jigsaw_music as MZ
    hazir, hata = MZ.model_ready()
    if not hazir:
        raise ValueError(hata)
    p = paths(rating)
    op_id = _op_new("music", len(collections))

    def calis():
        for i, c in enumerate(collections, 1):
            if c.lower() == DEFAULT_COLL.lower():
                _op(op_id, done=i, log="%s atlandi (Generic'in muzigi olmaz)" % c)
                continue
            d = os.path.join(p["staging"], c)
            if not os.path.isdir(d):
                d2 = os.path.join(p["pushed"], c)
                d = d2 if os.path.isdir(d2) else d
            if not overwrite and collection_music(rating, c, "staging"):
                _op(op_id, done=i, log="%s atlandi (muzigi zaten var)" % c)
                continue
            _op(op_id, message="%s icin muzik uretiliyor (%d/%d)" % (c, i, len(collections)))
            yol, err = MZ.generate(d, c, tags=tags, seconds=seconds,
                                   log=lambda s, c=c: _op(op_id, log="%s: %s" % (c, s)))
            with _ops_lock:
                _ops[op_id]["ok" if yol else "failed"] += 1
            _op(op_id, done=i,
                log=("+ %s" % os.path.basename(yol)) if yol else ("%s: %s" % (c, err[:160])))

    _run(op_id, calis)
    return op_id


# ------------------------------------------------------------------ silme
def remove(rating: str, stage: str, item_ids: list[str]) -> dict:
    """Varliklari tumuyle siler (jpg + mp4 + webp + json)."""
    silinen = 0
    for iid in item_ids:
        jpg = item_path(rating, stage, iid, "image")
        if not jpg:
            continue
        stem = os.path.splitext(jpg)[0]
        for uz in (".jpg", ".jpeg", ".mp4", ".webp", ".json"):
            try:
                os.remove(stem + uz)
                silinen += 1
            except OSError:
                pass
    return {"deleted": silinen}


def webp_missing(rating: str, collection: str = "") -> str:
    """Videosu olup webp'i olmayan varliklar icin webp uretir."""
    liste = list_items(rating, "staging", collection, limit=1000)["items"]
    eksik = [i for i in liste if i["video"] and not i["webp"]]
    op_id = _op_new("webp", len(eksik))

    def calis():
        for i, oge in enumerate(eksik, 1):
            jpg = item_path(rating, "staging", oge["id"], "image")
            if not jpg:
                continue
            stem = os.path.splitext(jpg)[0]
            ok, err = G._encode_webp(stem + ".mp4", stem + ".webp")
            with _ops_lock:
                _ops[op_id]["ok" if ok else "failed"] += 1
            _op(op_id, done=i, log=("+ %s.webp" % oge["stem"]) if ok
                else ("%s: %s" % (oge["stem"], err[:120])))

    _run(op_id, calis)
    return op_id
