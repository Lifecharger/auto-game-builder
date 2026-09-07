"""One-off Hot CBN probes: (a) Qwen Edit 2511 turns a finished painting into a
clean coloring-page lineart, (b) Z-Image renders a new source in the reference
"clean semi-realistic illustration" style. Both go through ComfyUI's queue."""
import json
import random
import shutil
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kid_cbn import COMFY_IN, WORKFLOWS, POOL_ROOT, _converter, _saved_files, comfy_run  # noqa: E402

OUT = POOL_ROOT.parent / "Hot CBN" / "_proto"
OUT.mkdir(parents=True, exist_ok=True)

LINEART_PROMPT = (
    "Convert this picture into a clean black-and-white line art coloring page: crisp uniform "
    "black outlines on a pure white background, every object and every fold, strand group and "
    "facial feature outlined as closed shapes, no shading, no hatching, no gray, no color, keep "
    "the exact composition and proportions"
)
LINEART_NEG = "color, gray, shading, hatching, gradient, blur, photo, texture, noise"

STYLE_PROMPT = (
    "{}, clean semi-realistic digital illustration, smooth cel shading with soft gradients, "
    "crisp clean edges, glossy highlights, vivid saturated colors, detailed hair strands, "
    "beautiful adult woman, glamorous, high detail, vertical composition"
)


def qwen_lineart(src: Path, dest: Path, seed: int | None = None) -> Path:
    wf = json.loads((WORKFLOWS / "Image Qwen Image.json").read_text(encoding="utf-8"))
    seed = seed or random.randint(1, 2 ** 31)
    g = _converter()(wf, {"positive_prompt": LINEART_PROMPT, "prompt": LINEART_PROMPT,
                          "negative_prompt": LINEART_NEG, "enable_turbo_mode": True,
                          "seed": seed, "noise_seed": seed})
    name = f"hotcbn_{uuid.uuid4().hex[:8]}{src.suffix}"
    COMFY_IN.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, COMFY_IN / name)
    for n in g.values():
        if n["class_type"] == "LoadImage":
            n["inputs"]["image"] = name
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "hot_cbn/lineart"
    t0 = time.time()
    files = _saved_files(comfy_run(g))
    shutil.copy(files[-1], dest)
    print(f"  qwen lineart {time.time() - t0:.0f}s -> {dest.name}")
    return dest


def zimage(subject: str, dest: Path, w: int = 832, h: int = 1216, seed: int | None = None) -> Path:
    wf = json.loads((WORKFLOWS / "Image Z Turbo.json").read_text(encoding="utf-8"))
    seed = seed or random.randint(1, 2 ** 31)
    p = STYLE_PROMPT.format(subject)
    g = _converter()(wf, {"prompt": p, "text": p, "width": w, "height": h, "seed": seed, "noise_seed": seed})
    for n in g.values():
        if n["class_type"].startswith("SaveImage"):
            n["inputs"]["filename_prefix"] = "hot_cbn/gen"
    t0 = time.time()
    files = _saved_files(comfy_run(g))
    shutil.copy(files[-1], dest)
    print(f"  z-image {time.time() - t0:.0f}s -> {dest.name}")
    return dest


if __name__ == "__main__":
    ref = POOL_ROOT.parent / "Hot CBN" / "_reference" / "07_final_art.jpg"
    qwen_lineart(ref, OUT / "ref_qwen_lineart.png")
    src = zimage("woman with long wavy honey-brown hair in a white halter bikini and a blue sarong, "
                 "leaning on a wooden cafe table with a cup of coffee, tropical beach and palm trunk behind",
                 OUT / "gen1_source.png")
    qwen_lineart(src, OUT / "gen1_qwen_lineart.png")
