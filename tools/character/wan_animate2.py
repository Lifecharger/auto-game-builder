r"""Wan Animate 2: referans karakter gorseli + surucu (manken) videosu -> karakter
ayni hareketi yapar.

    python wan_animate2.py --ref turnaround/right.png --video manken.mp4 --out wan.mp4
           [--prompt "..."] [--pose_prompt "..."] [--w 640 --h 640] [--fps 30]
           [--seed N] [--length N]

Grafik elle kuruludur (UI is akisi yok): wan_animate_2_int8_convrot + lightx2v
LoRA, 6 adim, lcm. Referans KIRPILMAZ - `letterbox` kenar pikselini uzatarak
kare tuvale oturtur, boylece pivot ve olcek her yonde ayni kalir.
ComfyUI paylasimlidir: once /queue'ya bakilir, sonra kuyruga birakilir.
"""
from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import time
from pathlib import Path

try:
    from . import common as C
except ImportError:
    import common as C

NEG = ("色调艳丽，过曝，静态，细节模糊不清，字幕，风格，作品，画作，画面，静止，整体发灰，最差质量，低质量，"
       "JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，"
       "手指融合，静止不动的画面，杂乱的背景，三条腿，背景人很多，倒着走")

REF_PROMPT = ("Character Description: a realistic adult woman, exactly as in the reference image, same face, "
              "same hair, same outfit.\nBackground description: " + C.BG_CLAUSE +
              ", static camera, full body always visible.")
POSE_PROMPT = ("A person performs the motion with the whole body, static camera, full body visible, "
               + C.BG_CLAUSE + ".")


def letterbox(src, dst, w: int, h: int, margin: float = 0.04) -> None:
    """Referansi KIRPMADAN tuvale sigdirir; bosluk kenar pikselinin uzatilmasiyla
    dolar (gorunur bant yok, Wan fonu duz gri sayar)."""
    import numpy as np
    from PIL import Image
    im = Image.open(str(src)).convert("RGB")
    r = min(w * (1 - 2 * margin) / im.width, h * (1 - 2 * margin) / im.height)
    im = im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.LANCZOS)
    a = np.asarray(im)
    top, left = (h - a.shape[0]) // 2, (w - a.shape[1]) // 2
    a = np.pad(a, ((top, h - a.shape[0] - top), (left, w - a.shape[1] - left), (0, 0)), mode="edge")
    Image.fromarray(a).save(str(dst))


def graph(ref, vid, prompt, pose_prompt, w, h, length, fps, seed, prefix) -> dict:
    return {
     "1":  {"class_type": "UNETLoader", "inputs": {"unet_name": "wan_animate_2_int8_convrot.safetensors", "weight_dtype": "default"}},
     "2":  {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors", "strength_model": 1.0}},
     "3":  {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan", "device": "default"}},
     "4":  {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": prompt}},
     "5":  {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": NEG}},
     "6":  {"class_type": "CLIPTextEncode", "inputs": {"clip": ["3", 0], "text": pose_prompt}},
     "7":  {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": "clip_vision_h.safetensors"}},
     "8":  {"class_type": "VAELoader", "inputs": {"vae_name": "Wan2_1_VAE_bf16.safetensors"}},
     "9":  {"class_type": "LoadImage", "inputs": {"image": ref}},
     "10": {"class_type": "LoadVideo", "inputs": {"file": vid}},
     "11": {"class_type": "GetVideoComponents", "inputs": {"video": ["10", 0]}},
     "12": {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["11", 0], "resize_type": "scale dimensions",
            "resize_type.width": w, "resize_type.height": h, "resize_type.crop": "center", "scale_method": "area"}},
     "13": {"class_type": "ResizeImageMaskNode", "inputs": {"input": ["9", 0], "resize_type": "scale dimensions",
            "resize_type.width": w, "resize_type.height": h, "resize_type.crop": "center", "scale_method": "area"}},
     "14": {"class_type": "CLIPVisionEncode", "inputs": {"clip_vision": ["7", 0], "image": ["13", 0], "crop": "none"}},
     "15": {"class_type": "ImageFromBatch", "inputs": {"image": ["12", 0], "batch_index": 0, "length": 1}},
     "16": {"class_type": "CLIPVisionEncode", "inputs": {"clip_vision": ["7", 0], "image": ["15", 0], "crop": "none"}},
     "17": {"class_type": "WanAnimate2Cache", "inputs": {"model": ["2", 0], "device": "cpu", "dtype": "int8"}},
     "18": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["17", 0], "shift": 5.0}},
     "19": {"class_type": "BasicScheduler", "inputs": {"model": ["17", 0], "scheduler": "simple", "steps": 6, "denoise": 1.0}},
     "20": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "lcm"}},
     "21": {"class_type": "WanAnimate2ToVideo", "inputs": {"positive": ["4", 0], "negative": ["5", 0], "vae": ["8", 0],
            "width": w, "height": h, "length": length, "batch_size": 1, "video_frame_offset": 0,
            "pose_strength": 1.0, "pose_start_percent": 0.0, "pose_end_percent": 1.0, "reference_image_strength": 1.0,
            "reference_image": ["13", 0], "pose_video": ["12", 0], "clip_vision_output": ["14", 0],
            "positive_pose": ["6", 0], "clip_vision_output_pose": ["16", 0]}},
     "22": {"class_type": "SamplerCustom", "inputs": {"model": ["18", 0], "add_noise": True, "noise_seed": seed, "cfg": 1.0,
            "positive": ["21", 0], "negative": ["21", 1], "sampler": ["20", 0], "sigmas": ["19", 0], "latent_image": ["21", 2]}},
     "23": {"class_type": "TrimVideoLatent", "inputs": {"samples": ["22", 0], "trim_amount": ["21", 3]}},
     "24": {"class_type": "VAEDecode", "inputs": {"samples": ["23", 0], "vae": ["8", 0]}},
     "25": {"class_type": "CreateVideo", "inputs": {"images": ["24", 0], "fps": float(fps)}},
     "26": {"class_type": "SaveVideo", "inputs": {"video": ["25", 0], "filename_prefix": prefix, "format": "auto", "format.codec": "auto"}},
    }


def animate(ref, video, out, prompt: str = "", pose_prompt: str = "", w: int = 640, h: int = 640,
            fps: int = 30, seed: int = 0, length: int = 0, prefix: str = "", margin: float = 0.04,
            log=print) -> dict:
    """Tek bir Wan Animate 2 isi. {out, seed, length, seconds} doner.

    margin = referansin kenar dolgusu (rev5 padding): figur tuvalin
    (1 - 2*margin) kadarini kaplar, bosluk kenar pikseliyle doldurulur."""
    ref, video, out = Path(ref), Path(video), Path(out)
    run, pend = C.queue_depth()
    log("ComfyUI kuyrugu: calisan %d, bekleyen %d" % (run, pend))
    lb = C.COMFY_IN / ("wa2_%s_%dx%d_m%02d.png" % (ref.stem, w, h, int(round(margin * 100))))
    C.COMFY_IN.mkdir(parents=True, exist_ok=True)
    letterbox(ref, lb, w, h, max(0.0, min(0.45, float(margin))))
    vid_name = C.stage_input(video, "wa2")
    n = C.frame_count(video)
    length = length or (((n - 1) // 4) * 4 + 1)
    seed = seed or random.randint(1, 2 ** 31)
    name = prefix or out.stem
    g = graph(lb.name, vid_name, prompt or REF_PROMPT, pose_prompt or POSE_PROMPT,
              w, h, length, fps, seed, "character/wan/" + name)
    t0 = time.time()
    log("%s: kuyrukta (%d kare -> length %d, seed %d)" % (name, n, length, seed))
    files = C.outputs(C.wait(C.enqueue(g, "wa2"), 3 * 3600, poll=5.0), ("videos", "gifs", "images"))
    if not files:
        raise RuntimeError("Wan cikti vermedi: %s" % name)
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(str(files[0]), str(out))
    info = {"out": str(out), "seed": seed, "length": length, "fps": fps, "w": w, "h": h,
            "prompt": prompt or REF_PROMPT, "pose_prompt": pose_prompt or POSE_PROMPT,
            "src": video.name, "ref": ref.name, "margin": margin,
            "seconds": round(time.time() - t0, 1)}
    log("%s: TAMAM %.0fs -> %s" % (name, info["seconds"], out))
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--video", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--prompt", default="")
    ap.add_argument("--pose_prompt", default="")
    ap.add_argument("--w", type=int, default=640)
    ap.add_argument("--h", type=int, default=640)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--length", type=int, default=0)
    ap.add_argument("--prefix", default="")
    ap.add_argument("--margin", type=float, default=0.04)
    a = ap.parse_args()
    print(json.dumps(animate(a.ref, a.video, a.out, a.prompt, a.pose_prompt, a.w, a.h,
                             a.fps, a.seed, a.length, a.prefix, a.margin), indent=1))


if __name__ == "__main__":
    main()
