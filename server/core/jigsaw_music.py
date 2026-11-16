"""Koleksiyon muzigi - ComfyUI/ACE-Step ile YEREL uretim.

r2manager muzigi ElevenLabs'tan aliyordu; o kredi tabanli ve tukeniyor. Burada
ayni isi makinedeki ComfyUI'nin ACE-Step destegiyle yapiyoruz: sinirsiz, cevrimdisi
ve ayni kuyruk. ComfyUI istemleri sirayla isler, dolayisiyla muzik isi gorsel/video
uretimiyle ayni anda RAM'e binmez.

Dosya adlandirmasi r2manager ile AYNI: `<koleksiyon>_00001_.mp3`. Push tarafi
tematik koleksiyonun .mp3'unu `collections/<k>/music/` altina yolluyor (Generic'in
muzigi olmaz), o kural degismedi.

Model: ACE-Step 1.5 XL Turbo - `models/diffusion_models/acestep_v1.5_xl_turbo_bf16.safetensors`,
text encoders `qwen_0.6b_ace15` + `qwen_4b_ace15`, VAE `ace_1.5_vae` (Comfy-Org/ace_step_1.5_ComfyUI_files).
Model yoksa uc bunu acikca soyler. (Eski ACE-Step v1 3.5B 2026-11-09 silindi.)
"""
from __future__ import annotations

import json
import os
import random
import time
import urllib.request

from . import comfy_gen as G

MODEL = "acestep_v1.5_xl_turbo_bf16.safetensors"
CLIP_1 = "qwen_0.6b_ace15.safetensors"
CLIP_2 = "qwen_4b_ace15.safetensors"
VAE = "ace_1.5_vae.safetensors"
SANIYE = 30.0                    # r2manager ile ayni: 30 sn dongu
ADIM = 8                         # turbo model: 8 adim, cfg 1
CFG = 1.0
BPM = 90

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
    yol = os.path.join(kok, "models", "diffusion_models", MODEL)
    if not os.path.isfile(yol):
        return False, ("ACE-Step 1.5 modeli yok: %s\nComfy-Org/ace_step_1.5_ComfyUI_files "
                       "icinden %s dosyasini indir." % (yol, MODEL))
    if os.path.getsize(yol) < 1_000_000_000:
        return False, "ACE-Step 1.5 modeli eksik/yarim inmis: %s" % yol
    return True, ""


def _graph(tags: str, seconds: float, seed: int) -> dict:
    """ACE-Step 1.5 Turbo API grafigi ("T2M ACE-Step 1.5 Turbo.json" ile ayni dugumler).
    Negatif = sifirlanmis pozitif (turbo model cfg 1 ile calisir)."""
    return {
        "1": {"class_type": "UNETLoader",
              "inputs": {"unet_name": MODEL, "weight_dtype": "default"}},
        "2": {"class_type": "DualCLIPLoader",
              "inputs": {"clip_name1": CLIP_1, "clip_name2": CLIP_2, "type": "ace",
                         "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "4": {"class_type": "TextEncodeAceStepAudio1.5",
              "inputs": {"clip": ["2", 0], "tags": tags, "lyrics": "[Instrumental]",
                         "seed": seed, "bpm": BPM, "duration": seconds,
                         "timesignature": "4", "language": "en", "keyscale": "C major",
                         "generate_audio_codes": True, "cfg_scale": 2.0,
                         "temperature": 0.85, "top_p": 0.9, "top_k": 0, "min_p": 0.0}},
        "5": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["4", 0]}},
        "6": {"class_type": "EmptyAceStep1.5LatentAudio",
              "inputs": {"seconds": seconds, "batch_size": 1}},
        "7": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.0}},
        "8": {"class_type": "KSampler",
              "inputs": {"model": ["7", 0], "positive": ["4", 0], "negative": ["5", 0],
                         "latent_image": ["6", 0], "seed": seed, "steps": ADIM,
                         "cfg": CFG, "sampler_name": "euler", "scheduler": "simple",
                         "denoise": 1.0}},
        "9": {"class_type": "VAEDecodeAudio",
              "inputs": {"samples": ["8", 0], "vae": ["3", 0]}},
        "10": {"class_type": "SaveAudioMP3",
               "inputs": {"audio": ["9", 0], "filename_prefix": "agb_music",
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
             seed: int | None = None, timeout: int = 1800, op_id: str = "",
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
    with gpu_lane.hold("muzik: %s" % coll, kind="music", op_id=op_id):   # #299
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
