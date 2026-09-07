"""Koleksiyon muzigi - ComfyUI/ACE-Step ile YEREL uretim.

r2manager muzigi ElevenLabs'tan aliyordu; o kredi tabanli ve tukeniyor. Burada
ayni isi makinedeki ComfyUI'nin ACE-Step destegiyle yapiyoruz: sinirsiz, cevrimdisi
ve ayni kuyruk. ComfyUI istemleri sirayla isler, dolayisiyla muzik isi gorsel/video
uretimiyle ayni anda RAM'e binmez.

Dosya adlandirmasi r2manager ile AYNI: `<koleksiyon>_00001_.mp3`. Push tarafi
tematik koleksiyonun .mp3'unu `collections/<k>/music/` altina yolluyor (Generic'in
muzigi olmaz), o kural degismedi.

Model: `models/checkpoints/ace_step_v1_3.5b.safetensors`
(Comfy-Org/ACE-Step_ComfyUI_repackaged). Model yoksa uc bunu acikca soyler.
"""
from __future__ import annotations

import json
import os
import random
import time
import urllib.request

from . import comfy_gen as G

MODEL = "ace_step_v1_3.5b.safetensors"
SANIYE = 30.0                    # r2manager ile ayni: 30 sn dongu
ADIM = 50
CFG = 5.0

# Koleksiyon adindan tur/atmosfer tahmini - promptu zenginlestirir.
_IPUCU = [
    (("viking", "warrior", "golden", "knight", "battle"), "epic nordic drums, heroic strings"),
    (("hell", "inferno", "demon", "dark", "graveyard", "necro"), "dark ambient, low brass, ominous"),
    (("ice", "winter", "snow", "frost"), "crystalline bells, airy pads, cold shimmer"),
    (("fire", "flame", "lava"), "warm percussion, smoldering low end"),
    (("forest", "elf", "glade", "druid", "nature", "farm"), "celtic flute, soft harp, woodland"),
    (("beach", "summer", "sun", "sand", "tropical"), "warm ukulele, gentle waves, breezy"),
    (("city", "urban", "cyber", "neon", "tactical"), "synthwave pads, subtle pulse"),
    (("space", "cosmic", "star"), "ambient synth, wide reverb, floating"),
    (("library", "knowledge", "serene", "temple"), "soft piano, calm strings"),
    (("christmas", "candy", "rainbow", "pixie", "fair"), "playful bells, twinkling celesta"),
    (("steampunk", "machine", "steel"), "clockwork percussion, brass textures"),
    (("anime", "cosplay", "idol"), "bright synth pop, light beat"),
]


def _tema(coll: str) -> str:
    ad = coll.replace("_", " ").replace("-", " ").strip()
    dusuk = ad.lower()
    for anahtarlar, renk in _IPUCU:
        if any(k in dusuk for k in anahtarlar):
            return "%s, %s" % (ad, renk)
    return ad


def tags_for(coll: str) -> str:
    """ACE-Step 'tags' alani - tur/enstruman/atmosfer, sarki sozu yok."""
    return ("instrumental, ambient, cinematic, loopable, no vocals, "
            "calm background music for a mobile jigsaw puzzle, %s" % _tema(coll))


def model_ready() -> tuple[bool, str]:
    kok = G.COMFY_ROOT
    if not kok:
        return False, "ComfyUI koku ayarli degil (settings.json -> comfyui.root)"
    yol = os.path.join(kok, "models", "checkpoints", MODEL)
    if not os.path.isfile(yol):
        return False, ("ACE-Step modeli yok: %s\nComfy-Org/ACE-Step_ComfyUI_repackaged "
                       "icindeki all_in_one/%s dosyasini indir." % (yol, MODEL))
    if os.path.getsize(yol) < 1_000_000_000:
        return False, "ACE-Step modeli eksik/yarim inmis: %s" % yol
    return True, ""


def _graph(tags: str, seconds: float, seed: int) -> dict:
    """ACE-Step API grafigi. UI is akisi dosyasina bagli degiliz - dugum adlari
    ComfyUI'nin kendi cekirdeginden geliyor, surum degisiminde kirilmiyor."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": MODEL}},
        "2": {"class_type": "TextEncodeAceStepAudio",
              "inputs": {"clip": ["1", 1], "tags": tags, "lyrics": "",
                         "lyrics_strength": 1.0}},
        "3": {"class_type": "TextEncodeAceStepAudio",
              "inputs": {"clip": ["1", 1],
                         "tags": "vocals, singing, speech, noise, distortion, clipping",
                         "lyrics": "", "lyrics_strength": 1.0}},
        "4": {"class_type": "EmptyAceStepLatentAudio",
              "inputs": {"seconds": seconds, "batch_size": 1}},
        "5": {"class_type": "KSampler",
              "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0],
                         "latent_image": ["4", 0], "seed": seed, "steps": ADIM,
                         "cfg": CFG, "sampler_name": "euler", "scheduler": "simple",
                         "denoise": 1.0}},
        "6": {"class_type": "VAEDecodeAudio",
              "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveAudioMP3",
              "inputs": {"audio": ["6", 0], "filename_prefix": "agb_music",
                         "quality": "V0"}},
    }


def next_music_path(coll_dir: str, coll: str) -> str:
    """`<koleksiyon>_00001_.mp3` - r2manager ile ayni adlandirma."""
    n = 1
    try:
        with os.scandir(coll_dir) as it:
            for e in it:
                kok, uz = os.path.splitext(e.name)
                if uz.lower() != ".mp3" or not kok.startswith(coll + "_"):
                    continue
                try:
                    n = max(n, int(kok[len(coll) + 1:].strip("_")) + 1)
                except ValueError:
                    pass
    except OSError:
        pass
    return os.path.join(coll_dir, "%s_%05d_.mp3" % (coll, n))


def generate(coll_dir: str, coll: str, tags: str = "", seconds: float = SANIYE,
             seed: int | None = None, timeout: int = 1800,
             log=lambda s: None) -> tuple[str | None, str]:
    """Bir koleksiyon icin mp3 uretir. Doner: (yol, hata)."""
    ok, hata = model_ready()
    if not ok:
        return None, hata
    if not G.comfy_up():
        return None, "ComfyUI calismiyor (127.0.0.1:8188)"

    tags = tags.strip() or tags_for(coll)
    seed = seed if seed is not None else random.randint(1, 2 ** 31)
    log("tags: %s" % tags[:150])
    from . import gpu_lane
    with gpu_lane.hold("muzik: %s" % coll, kind="music"):
        return _generate_locked(coll_dir, coll, tags, seconds, seed, timeout, log)


def _generate_locked(coll_dir, coll, tags, seconds, seed, timeout, log):
    try:
        pid = G._post("/prompt", {"prompt": _graph(tags, seconds, seed),
                                  "client_id": "agb-music"})["prompt_id"]
    except Exception as e:
        return None, "ComfyUI istemi reddetti: %s" % e

    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(3)
        try:
            hist = G._get("/history/" + pid)
        except Exception:
            continue
        if pid not in hist:
            continue
        st = hist[pid].get("status", {})
        if st.get("status_str") == "error":
            msgs = [m for m in st.get("messages", []) if m and m[0] == "execution_error"]
            return None, json.dumps(msgs, ensure_ascii=False)[:400]
        for _k, o in hist[pid].get("outputs", {}).items():
            for f in (o.get("audio") or []):
                src = os.path.join(G.COMFY_OUT, f.get("subfolder", ""), f["filename"])
                if not os.path.isfile(src):
                    continue
                os.makedirs(coll_dir, exist_ok=True)
                dest = next_music_path(coll_dir, coll)
                import shutil
                shutil.copy(src, dest)
                log("yazildi: %s (%d KB)" % (os.path.basename(dest),
                                             os.path.getsize(dest) // 1024))
                return dest, ""
        if hist[pid].get("outputs"):
            return None, "ComfyUI ses ciktisi dondurmedi"
    return None, "zaman asimi (%d sn)" % timeout
