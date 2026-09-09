"""Prompt Smith - butun kiplerin ortak yerel LLM prompt yazari (gorev #337).

Neden tek modul: jigsaw, cbn, kart, karakter ve free kipleri ayni isi farkli
sekillerde yapiyordu (ya da hic yapmiyordu). Kart kipinde tema tek satir olarak
basa ekleniyor, gorunus ise jenerik ten/sac/kiyafet listelerinden doniyordu -
"Queens and Princesses" temasina "tactical crop vest" dusuyordu. Burasi o isi
yapan TEK yer; her kip ayni sozlesmeyi cagirir.

Bes is:
  looks(...)     kart/karakter: tema -> her rutbe icin {age, skin, hair, outfit, pose}
  enrich(...)    free: kisa bir cumleyi zengin bir uretim prompt'una cevirir
  normalize(...) jigsaw/cbn: prompt'u kipin ev uslubuna oturtur, cop terimleri atar
  variants(...)  herhangi bir prompt'tan N ayri varyant
  motion(...)    video: kisa bir hareket ipucundan i2v hareket cumlesi

Kurallar (hepsinde gecerli):
  * Model YEREL (Ollama, varsayilan gemma3:12b) - disari veri gitmez, ucret yok.
  * LLM yoksa/patlarsa cagiran taraf BOZULMAZ: girdi aynen geri doner (fallback).
  * Is biter bitmez ollama_unload() - 12B model ~8 GB VRAM tutar, ComfyUI'nin
    sirasi gelmeden birakmasi sart (#337).
  * Kadin uretiminde yas HER ZAMAN yetiskin: 20-26 arasi tam sayi (bkz. YAS_ALT).
"""

from __future__ import annotations

import json
import re
import urllib.request

from . import jigsaw_flow as JF

# Yas araligi tek yerde: kullanici "20'den baslasin" dedi (#337).
YAS_ALT, YAS_UST = 20, 26

# Her cagriya eklenen degismez kurallar - modelin kacamayacagi cerceve.
EVRENSEL = (
    "Every person you describe is an ADULT woman between %d and %d years old; never a child, "
    "teenager or minor. Never anime, cartoon, illustration, 3d render or CGI - always "
    "photographic realism. Write in English. Output ONLY the requested JSON, no commentary."
    % (YAS_ALT, YAS_UST)
)

_TIMEOUT = 180


def ready() -> bool:
    """Yerel LLM ayakta mi (yoksa cagiran taraf fallback'e duser)."""
    return JF.ollama_ready()


def model_adi() -> str:
    return JF._ollama_cfg()[1]


def _chat(system: str, user: str, json_mode: bool = True, timeout: int = _TIMEOUT) -> str:
    """Tek turlu sohbet. Hata = bos string (cagiran taraf fallback yapar)."""
    url, model = JF._ollama_cfg()
    govde = {
        "model": model,
        "messages": [{"role": "system", "content": system + "\n" + EVRENSEL},
                     {"role": "user", "content": user}],
        "stream": False,
        "options": {"temperature": 0.85, "top_p": 0.9},
    }
    if json_mode:
        govde["format"] = "json"
    try:
        req = urllib.request.Request(url + "/api/chat",
                                     data=json.dumps(govde).encode("utf-8"),
                                     headers={"Content-Type": "application/json"})
        ham = urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8")
        return ((json.loads(ham) or {}).get("message") or {}).get("content") or ""
    except Exception:
        return ""


def _json_coz(metin: str):
    """Modelin ciktisindan JSON cikar - bazen ```json cite ya da on soz ekler."""
    s = (metin or "").strip()
    if not s:
        return None
    s = re.sub(r"^```(?:json)?|```$", "", s, flags=re.M).strip()
    try:
        return json.loads(s)
    except Exception:
        pass
    for ac, kap in (("{", "}"), ("[", "]")):
        i, j = s.find(ac), s.rfind(kap)
        if i >= 0 and j > i:
            try:
                return json.loads(s[i:j + 1])
            except Exception:
                continue
    return None


def _bitir() -> None:
    """VRAM'i hemen birak - sirada ComfyUI var (#337)."""
    try:
        JF.ollama_unload()
    except Exception:
        pass


# --------------------------------------------------------------- 1) looks
LOOKS_SYS = (
    "You are a casting and wardrobe director for a premium glamour photo series. "
    "Given a collection THEME and a list of card RANKS, you invent one distinct woman per rank. "
    "Hard rules: every outfit must unmistakably belong to the THEME - never borrow wardrobe from "
    "another theme. The women must differ from each other in skin tone, hair colour and hair "
    "length, outfit silhouette and pose; no two may read as the same person. Vary ethnicity "
    "naturally across the set. Poses are full body, standing or stepping, facing the camera. "
    "WARDROBE RULES (hard): every outfit is short and revealing with bare legs - a mini skirt, "
    "micro dress, corset, bodysuit, shorts or a high-slit dress. NEVER trousers, jeans, leggings "
    "or a pantsuit. A floor-length skirt or gown is allowed ONLY when it is split by a slit that "
    "runs almost to the hip so a whole bare leg is on show while she stands - a plain, closed, "
    "unslit long skirt is forbidden. NEVER a coat, blazer, "
    "cardigan or anything buttoned to the throat. Every outfit has a deep neckline. Do not make "
    "an outfit more modest than the theme asks - the series is glamour pin-up, not eveningwear. "
    "Each outfit must also carry the THEME's signature props and silhouette, not just its colours. "
    'Answer as JSON: {"ranks": {"<RANK>": {"age": <int>, "skin": "...", "hair": "...", '
    '"outfit": "...", "pose": "..."}}}. Each field is a short comma-free phrase; "outfit" may '
    "name garment, fabric, colour and footwear."
)


def looks(theme: str, ranks: list[str], kind: str = "card", extra: str = "") -> dict:
    """Tema -> {rutbe: {age, skin, hair, outfit, pose}}. LLM yoksa {} doner."""
    if not ready() or not (theme or "").strip() or not ranks:
        return {}
    kadraj = (
        # Krupiye kesilip oyunun KENDI masasinin uzerine biniyor: still'de masa
        # OLMAMALI, yoksa eller boslukta kalir ve masa altindaki govde eksilir.
                "Framing: a WIDE HORIZONTAL 3:2 picture. She is framed from the waist up and fills the "
        "whole width of the frame - this is a landscape banner, not a tall portrait. She holds a "
        "small fan of playing cards in ONE hand, raised out to her side away from her body; her "
        "chest and neckline are completely unobstructed. "
        "There is NO table, desk or counter in the picture. Wardrobe: a glamorous casino dealer "
        "outfit fitting the theme, fitted at the waist with a deep plunging neckline showing "
        "generous cleavage, bare shoulders or arms - never a modest office outfit, never a "
        "buttoned-up blouse, never a blazer."
        if kind == "dealer" else
        "Framing: full body head to feet including footwear.")
    user = ("THEME: %s\nRANKS: %s\n%s\n%s\nInvent one woman per rank."
            % (theme.strip(), ", ".join(str(r).upper() for r in ranks), kadraj, extra.strip()))
    try:
        d = _json_coz(_chat(LOOKS_SYS, user)) or {}
    finally:
        _bitir()
    ham = d.get("ranks") if isinstance(d, dict) else None
    if not isinstance(ham, dict) and isinstance(d, dict):
        # Tek rutbede (krupiye) model bazen "ranks" sarmalayicisini atlar ya da
        # rutbeyi baska adlandirir; alanlar dogrudan kokte olabilir.
        if any(a in d for a in ("outfit", "hair", "skin")):
            ham = {str(ranks[0]).upper(): d}
        elif len(ranks) == 1:
            tek = next((v for v in d.values() if isinstance(v, dict)
                        and any(a in v for a in ("outfit", "hair", "skin"))), None)
            if tek:
                ham = {str(ranks[0]).upper(): tek}
    if not isinstance(ham, dict):
        return {}
    if len(ranks) == 1 and not any(
            str(r).upper() in ham or str(r).lower() in ham for r in ranks):
        # Tek rutbe: model ne ad verdiyse versin, tek girdiyi o rutbeye bagla.
        tek = next((v for v in ham.values() if isinstance(v, dict)), None)
        if tek:
            ham = {str(ranks[0]).upper(): tek}
    out = {}
    for r in ranks:
        v = ham.get(str(r).upper()) or ham.get(str(r).lower()) or ham.get(str(r))
        if not isinstance(v, dict):
            continue
        yas = v.get("age")
        try:
            yas = int(yas)
        except Exception:
            yas = YAS_ALT + 2
        yas = max(YAS_ALT, min(YAS_UST, yas))
        # Model bazen alt ogeleri ";" ile ayirir - prompt dilinde ayrac virguldur.
        parca = [str(v.get(a) or "").replace(";", ",").strip(" ,") for a in
                 ("skin", "hair", "outfit")]
        parca = [re.sub(r"\s*,\s*", ", ", p) for p in parca if p]
        if not parca:
            continue
        out[str(r).upper()] = {
            "age": yas,
            "look": "%d year old, %s" % (yas, ", ".join(parca)),
            "pose": re.sub(r"\s*[;,]\s*", ", ", str(v.get("pose") or "").strip(" ;,")),
        }
    return out


# --------------------------------------------------------------- 2) enrich
ENRICH_SYS = (
    "You turn a short image idea into ONE rich text-to-image prompt. Keep the user's subject and "
    "intent exactly; add only what a photographer would decide: wardrobe detail, pose, lighting, "
    "focal length, background and mood. Never add text, logos or watermarks. Never name camera "
    "brands or film stock (no Leica, Canon, Sony, Kodak, 'film grain') and never add quality-spam "
    "words like masterpiece, best quality, 8k, ultra detailed. One sentence-like line, "
    "comma separated, under 80 words. "
    'Answer as JSON: {"prompt": "..."}'
)


def enrich(prompt: str, mode: str = "free", hint: str = "") -> str:
    """Kisa fikri zengin prompt'a cevirir. LLM yoksa girdi aynen doner."""
    p = (prompt or "").strip()
    if not p or not ready():
        return p
    user = "IDEA: %s\nTARGET MODE: %s\n%s" % (p, mode, hint.strip())
    try:
        d = _json_coz(_chat(ENRICH_SYS, user)) or {}
    finally:
        _bitir()
    y = (d.get("prompt") if isinstance(d, dict) else "") or ""
    return y.strip() or p


# ------------------------------------------------------------ 3) normalize
NORMALIZE_SYS = (
    "You rewrite an image prompt so it fits a house style, without changing what is depicted. "
    "Remove contradictions, duplicated adjectives, negative phrasing (that belongs in a negative "
    "prompt), camera-brand noise and quality-spam words like 'masterpiece' or '8k'. Keep every "
    "concrete subject detail the author wrote. Return a clean comma separated prompt. "
    'Answer as JSON: {"prompt": "..."}'
)

EV_USLUBU = {
    "jigsaw": "House style: one beautiful adult woman, photographic realism, vertical composition, "
              "rich colourful scene that reads well as a jigsaw puzzle.",
    "cbn": "House style: FLAT vector illustration for colour-by-number - clean closed shapes, "
           "large flat colour areas, no gradients, no photographic texture, no shading noise.",
    "card": "House style: ultra realistic glamour photography, full body, plain light gray studio "
            "background, vertical 2:3.",
    "character": "House style: photographic realism, character standing straight, neutral relaxed "
                 "pose, plain studio background.",
    "free": "House style: none - keep the author's direction.",
}


def normalize(prompt: str, mode: str = "free") -> str:
    """Prompt'u kipin ev uslubuna oturtur. LLM yoksa girdi aynen doner."""
    p = (prompt or "").strip()
    if not p or not ready():
        return p
    user = "PROMPT: %s\n%s" % (p, EV_USLUBU.get(mode, EV_USLUBU["free"]))
    try:
        d = _json_coz(_chat(NORMALIZE_SYS, user)) or {}
    finally:
        _bitir()
    y = (d.get("prompt") if isinstance(d, dict) else "") or ""
    return y.strip() or p


# ------------------------------------------------------------- 4) variants
VARIANTS_SYS = (
    "You write variations of an image prompt. Each variation keeps the same subject and the same "
    "overall intent, but changes wardrobe details, pose, lighting or setting enough that the "
    "resulting images are clearly different pictures - not the same picture twice. "
    'Answer as JSON: {"variants": ["...", "..."]}'
)


def variants(prompt: str, n: int = 3, mode: str = "free") -> list[str]:
    """Prompt'tan n ayri varyant. LLM yoksa [] doner (cagiran taraf tek prompt kullanir)."""
    p = (prompt or "").strip()
    n = max(1, min(8, int(n or 1)))
    if not p or not ready():
        return []
    user = ("PROMPT: %s\nCOUNT: %d\n%s" % (p, n, EV_USLUBU.get(mode, EV_USLUBU["free"])))
    try:
        d = _json_coz(_chat(VARIANTS_SYS, user)) or {}
    finally:
        _bitir()
    ham = d.get("variants") if isinstance(d, dict) else None
    if not isinstance(ham, list):
        return []
    return [str(x).strip() for x in ham if str(x).strip()][:n]


# --------------------------------------------------------------- 5) motion
MOTION_SYS = (
    "You write the motion line for an image-to-video clip. The camera is LOCKED: never describe "
    "camera movement, zoom, push in, dolly, pan or a framing change - only what the subject does. "
    "The clip is a seamless 6 second loop, so the motion must end where it began. Describe one "
    "small, natural, continuous movement. Under 40 words. "
    'Answer as JSON: {"motion": "..."}'
)


def motion(hint: str, subject: str = "") -> str:
    """Kisa ipucu (Turkce olabilir) -> i2v hareket cumlesi. LLM yoksa ipucu aynen doner."""
    h = (hint or "").strip()
    if not h or not ready():
        return h
    user = "MOTION HINT: %s\nSUBJECT IN THE IMAGE: %s" % (h, (subject or "a standing woman").strip())
    try:
        d = _json_coz(_chat(MOTION_SYS, user)) or {}
    finally:
        _bitir()
    y = (d.get("motion") if isinstance(d, dict) else "") or ""
    return y.strip() or h
